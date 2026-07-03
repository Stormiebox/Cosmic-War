package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("goods")

include("relations")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarController
CosmicWarController = {}

function CosmicWarController.initialize()
    if onServer() then
        CosmicWarController._tick = CosmicWarController._tick or 0
        CosmicWarController._lastEventAt = CosmicWarController._lastEventAt or 0
    end
end

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end

    return {
        sectorPressureInterval = 180,
        sectorPressureChance = 0.35,
        sectorPressureMinSpacing = 600,
        debugLogs = false
    }
end

function CosmicWarController.getUpdateInterval()
    local cfg = getCfg()
    return cfg.sectorPressureInterval or 180
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Sector", msg, ...)
        return
    end

    local cfg = getCfg()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Sector] " .. string.format(msg, ...))
end

local function getFactionByIndex(index)
    if not index or index <= 0 then return nil end
    return Faction(index)
end

local function getAliveWarFactionsInSector()
    local sector = Sector()
    local entities = { sector:getEntitiesByType(EntityType.Ship) }
    for _, s in pairs({ sector:getEntitiesByType(EntityType.Station) }) do
        table.insert(entities, s)
    end
    local present = {}
    local server = Server()

    for _, e in pairs(entities) do
        if valid(e) and e.factionIndex and e.factionIndex > 0 and e.durability > 0 then
            local f = getFactionByIndex(e.factionIndex)
            if f and f.isAIFaction then

                -- Self-heal any encountered factions that missed initialization
                if f:getValue("cw_enabled") == nil then
                    local seed = (server and server.seed or 0) + f.index * 101 + 17
                    local rnd = Random(seed)
                    local targetAggressive = rnd:getFloat(0.55, 1.0)
                    local mistrustful = rnd:getFloat(-0.25, 0.85)
                    local forgiving = rnd:getFloat(-0.25, 0.85)

                    if rnd:test(0.65) then
                        mistrustful = math.min(1.0, math.max(-1.0, mistrustful + rnd:getFloat(0.10, 0.35)))
                        forgiving = math.min(1.0, math.max(-1.0, forgiving - rnd:getFloat(0.05, 0.25)))
                    else
                        mistrustful = math.min(1.0, math.max(-1.0, mistrustful - rnd:getFloat(0.05, 0.20)))
                        forgiving = math.min(1.0, math.max(-1.0, forgiving + rnd:getFloat(0.10, 0.30)))
                    end

                    f:setValue("cw_enabled", true)
                    f:setValue("cw_war_bias", math.floor(targetAggressive * 1000))
                    f:setValue("cw_diplomatic_polarity", math.floor((mistrustful - forgiving) * 1000))
                    if f:getValue("enemy_faction") == nil then
                        f:setValue("enemy_faction", 0)
                    end
                end

                -- Safely register faction with the Cosmic Vault index
                if server then
                    local factionStr = server:getValue("factions") or ""
                    local searchStr = "," .. tostring(f.index) .. ","
                    if factionStr == "" then
                        server:setValue("factions", tostring(f.index))
                    elseif not string.find("," .. factionStr .. ",", searchStr) then
                        server:setValue("factions", factionStr .. "," .. tostring(f.index))
                    end
                end

                if f:getValue("cw_enabled") then
                    present[f.index] = f
                end
            end
        end
    end

    local out = {}
    for _, f in pairs(present) do
        table.insert(out, f)
    end
    return out
end

local function chooseWarPair(factions, random)
    if #factions < 2 then return nil, nil end

    local bestA, bestB = nil, nil
    local bestScore = -1000000000

    for i = 1, #factions do
        for j = i + 1, #factions do
            local a = factions[i]
            local b = factions[j]
            local rel = a:getRelations(b.index) or 0

            local ap = a:getValue("cw_diplomatic_polarity") or 0
            local bp = b:getValue("cw_diplomatic_polarity") or 0
            local aw = a:getValue("cw_war_bias") or 0
            local bw = b:getValue("cw_war_bias") or 0

            -- lower relations and higher war-bias/polarity => more likely conflict
            local score = (-rel) + (aw + bw) * 0.25 + math.abs(ap - bp) * 0.15 + random:getInt(0, 350)

            if score > bestScore then
                bestScore = score
                bestA, bestB = a, b
            end
        end
    end

    return bestA, bestB
end

local function applyWarPressure(a, b, random)
    if not a or not b then return end

    local rel = a:getRelations(b.index) or 0
    local worsen = random:getInt(1500, 5000)
    local delta = -math.abs(worsen)

    -- Vanilla changeRelations() ignores AI vs AI factions.
    -- We must use the Galaxy API to force the relation change between two AI entities.
    local cvf = include("cosmicvaultfaction")
    if cvf and cvf.changeRelations then
        cvf.changeRelations(a.index, b.index, delta)
    else
        local newRel = math.max(-100000, math.min(100000, rel + delta))
        Galaxy():setFactionRelations(a, b, newRel)
    end

    local newRelA = a:getRelations(b.index) or rel
    local newRelB = b:getRelations(a.index) or rel
    local effectiveRel = math.min(newRelA, newRelB)

    a:setValue("cw_target_faction", b.index)
    b:setValue("cw_target_faction", a.index)

    a:setValue("enemy_faction", b.index)
    b:setValue("enemy_faction", a.index)

    cwlog("War pressure applied: %s(%i) <-> %s(%i), rel %i -> %i (delta %i)",
        a.name or "A", a.index or -1,
        b.name or "B", b.index or -1,
        rel, effectiveRel, delta
    )
end

local function applyWarProfiteeringShortages(factions)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local didShortage = false

    for _, f in pairs(factions) do
        local heat = f:getValue("cw_war_bias") or 0
        local enemy = f:getValue("enemy_faction") or 0
        local rel = 0
        if enemy > 0 then rel = f:getRelations(enemy) end

        -- If at critical war heat (relations very low, bias high)
        if rel <= -80000 then
            local stations = {sector:getEntitiesByFaction(f.index)}
            for _, station in pairs(stations) do
                if station.isStation and (station:hasScript("tradingpost.lua") or station:hasScript("equipmentdock.lua") or station:hasScript("militaryoutpost.lua")) then
                    -- Artificially drain military goods
                    local goodsToDrain = {"Ammunition", "Medical Supplies", "Steel", "Weapon Components", "Energy Tubes"}
                    for _, goodName in pairs(goodsToDrain) do
                        local good = goods[goodName]
                        if good then
                            -- Soft Bridge: We just remove stock. If Cosmic Overhaul is installed,
                            -- its dynamic economy will naturally detect the deficit and amplify prices.
                            station:invokeFunction("tradingmanager.lua", "decreaseStock", goodName, random():getInt(500, 2000))
                            didShortage = true
                        end
                    end
                end
            end
        end
    end

    if didShortage then
        -- Soft Bridge to Cosmic Vault News
        local server = Server()
        local article = {
            title = "Wartime Shortage",
            category = "Trade Crisis",
            content = "The escalating conflict in sector (" .. x .. ":" .. y .. ") has drained local stations of vital military and medical supplies. Profiteers and smugglers are rushing to exploit the 300% margins."
        }
        local cvn = include("cosmicvaultnews")
        cvn.publishArticle(article)
    end
end

local function applyWeaponizedSubspaceTear(factions, random)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    for _, f in pairs(factions) do
        local heat = f:getValue("cw_war_bias") or 0
        local enemy = f:getValue("enemy_faction") or 0
        local rel = 0
        if enemy > 0 then rel = f:getRelations(enemy) end

        -- If at critical war heat (relations very low, bias high)
        if rel <= -80000 then
            -- Synergy: Eclipse Sanitization Protocol (10% chance)
            local EclipseGenerator = include("eclipsegenerator")
            if EclipseGenerator and Server():getValue("eclipse_fully_awake") and random:test(0.1) then
                local cvn = include("cosmicvaultnews")
                if cvn then
                    local article = {
                        title = "Sanitization Protocol",
                        category = "Eclipse Invasion",
                        content = "The immense chaos and subspace tearing in sector (" .. x .. ":" .. y .. ") has drawn the attention of the Eclipse. A multiversal sanitization fleet has warped in, forcing all warring factions into a desperate ceasefire!"
                    }
                    cvn.publishArticle(article)
                end

                local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random:getInt(-1000, 1000), 0, random:getInt(-1000, 1000)))
                local harbinger = EclipseGenerator.createShip(pos, "obelisk", 2.0, 30)
                if harbinger then
                    harbinger:addScriptOnce("ai/aggressiveship.lua")
                end

                for i = 1, 4 do
                    local mPos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random:getInt(-1000, 1000), 0, random:getInt(-1000, 1000)))
                    local defender = EclipseGenerator.createJuggernaut(mPos)
                    if defender then
                        defender:addScriptOnce("ai/aggressiveship.lua")
                    end
                end

                -- Ceasefire
                local enemyFaction = Faction(enemy)
                if enemyFaction then
                    local cvf = include("cosmicvaultfaction")
                    if cvf and cvf.changeRelations then
                        cvf.changeRelations(f.index, enemy, 40000) -- massive relation boost
                    else
                        local newRel = rel + 40000
                        Galaxy():setFactionRelations(f, enemyFaction, newRel)
                    end
                    f:setValue("cw_war_bias", 0)
                    enemyFaction:setValue("cw_war_bias", 0)
                end
                
                break -- only one intervention per sector update
            end

            -- Cosmic War - Weaponized Subspace Missions (Normal behavior, 10% chance)
            if random:test(0.1) then
                local cvn = include("cosmicvaultnews")
                if cvn then
                    local article = {
                        title = "Weaponized Subspace Tear",
                        category = "War Crime",
                        content = "In a desperate bid for victory in sector (" .. x .. ":" .. y .. "), experimental subspace charges were detonated. The fabric of space has torn, unleashing Rift hazards and Ancient constructs! War Contracts have been issued to contain the anomaly."
                    }
                    cvn.publishArticle(article)
                end

                -- Add visual Rift thunder
                sector:addScriptOnce("dlc/rift/sector/riftbackgroundthunder.lua")
                -- Add localized shield drain specific to Cosmic War (without relying on Ascendancy)
                sector:addScriptOnce("sector/cw_rift_hazard.lua")
                break -- Only tear the rift once per sector update
            end
        end
    end
end

function CosmicWarController.updateServer(timeStep)
    CosmicWarController._tick = (CosmicWarController._tick or 0) + timeStep

    local cfg = getCfg()
    local now = Server().unpausedRuntime
    local minSpacing = cfg.sectorPressureMinSpacing or 600

    if (CosmicWarController._lastEventAt or 0) + minSpacing > now then
        return
    end

    local factions = getAliveWarFactionsInSector()
    if #factions < 2 then
        return
    end

    local sx, sy = Sector():getCoordinates()
    local random = Random(SectorSeed(sx, sy) + math.floor(now / 60))

    if not random:test(cfg.sectorPressureChance or 0.35) then
        return
    end

    local a, b = chooseWarPair(factions, random)
    if not a or not b then return end

    applyWarPressure(a, b, random)
    applyWarProfiteeringShortages(factions)
    applyWeaponizedSubspaceTear(factions, random)
    CosmicWarController._lastEventAt = now
end




function initialize(...)
    if CosmicWarController.initialize then return CosmicWarController.initialize(...) end
end
function getUpdateInterval(...)
    if CosmicWarController.getUpdateInterval then return CosmicWarController.getUpdateInterval(...) end
end
function updateServer(...)
    if CosmicWarController.updateServer then return CosmicWarController.updateServer(...) end
end

return CosmicWarController
