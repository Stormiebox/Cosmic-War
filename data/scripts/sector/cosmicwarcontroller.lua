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
    return CosmicWarConfig.get() or {
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
    CosmicVaultDebug.info("CosmicWar-Sector", msg, ...)
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
    cvf.changeRelations(a.index, b.index, delta)

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

local function applyWarProfiteeringShortages(factions, random)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local didShortage = false

    for _, f in pairs(factions) do
        local enemy = f:getValue("enemy_faction") or 0
        local rel = 0
        if enemy > 0 then rel = f:getRelations(enemy) end

        -- If at critical war heat (relations very low, bias high)
        if rel <= -80000 then
            local stations = {sector:getEntitiesByFaction(f.index)}
            for _, station in pairs(stations) do
                -- Only tradingpost.lua exposes a TradingAPI namespace (decreaseGoods); equipmentdock.lua
                -- uses a different ShopAPI and militaryoutpost.lua has no trading manager at all.
                if station.isStation and station:hasScript("tradingpost.lua") then
                    -- Artificially drain military goods
                    local goodsToDrain = {"Ammunition", "Medical Supplies", "Steel", "Weapon Components", "Energy Tube"}
                    for _, goodName in pairs(goodsToDrain) do
                        local good = goods[goodName]
                        if good then
                            -- Soft Bridge: We just remove stock. If Cosmic Overhaul is installed,
                            -- its dynamic economy will naturally detect the deficit and amplify prices.
                            -- invokeFunction returns the call-status code as its first value, not a
                            -- table (see Avorion Stubs/Entity.lua) -- indexing it with [1] would try
                            -- to index a number and crash. "decreaseGoods" is also not currently a
                            -- callable() target on TradingPost, so this will report status ~= 0 until
                            -- tradingpost.lua exposes one; left safe-but-inert rather than guessing at
                            -- an internal TradingManager API to call instead.
                            local status = station:invokeFunction("tradingpost.lua", "decreaseGoods", goodName, random:getInt(500, 2000))
                            if status == 0 then
                                didShortage = true
                            end
                        end
                    end
                end
            end
        end
    end

    if didShortage then
        -- Soft Bridge to Cosmic Vault News
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
        local enemy = f:getValue("enemy_faction") or 0
        local rel = 0
        if enemy > 0 then rel = f:getRelations(enemy) end

        -- If at critical war heat (relations very low, bias high)
        if rel <= -80000 then

            if Server():getValue("eclipse_fully_awake") and random:test(0.1) then
                local EclipseGenerator = include("eclipsegenerator")
                local cvn = include("cosmicvaultnews")
                local article = {
                    title = "Sanitization Protocol",
                    category = "Eclipse Invasion",
                    content = "The immense chaos and subspace tearing in sector (" .. x .. ":" .. y .. ") has drawn the attention of the Eclipse. A multiversal sanitization fleet has warped in, forcing all warring factions into a desperate ceasefire!"
                }
                cvn.publishArticle(article)

                local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random:getInt(-1000, 1000), 0, random:getInt(-1000, 1000)))
                local harbinger = EclipseGenerator.createShip(pos, "obelisk", 2.0, 30)
                if harbinger then
                    harbinger:addScriptOnce("ai/patrol.lua")
                end

                for i = 1, 4 do
                    local mPos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random:getInt(-1000, 1000), 0, random:getInt(-1000, 1000)))
                    local defender = EclipseGenerator.createJuggernaut(mPos)
                    if defender then
                        defender:addScriptOnce("ai/patrol.lua")
                    end
                end

                -- Ceasefire
                local enemyFaction = Faction(enemy)
                if enemyFaction then
                    local cvf = include("cosmicvaultfaction")
                    cvf.changeRelations(f.index, enemy, 40000) -- massive relation boost
                    f:setValue("cw_war_bias", 0)
                    enemyFaction:setValue("cw_war_bias", 0)
                end

                break -- only one intervention per sector update
            end

            if random:test(0.1) then
                local cvn = include("cosmicvaultnews")
                local article = {
                    title = "Weaponized Subspace Tear",
                    category = "War Crime",
                    content = "In a desperate bid for victory in sector (" .. x .. ":" .. y .. "), experimental subspace charges were detonated. The fabric of space has torn, unleashing Rift hazards and Ancient constructs! War Contracts have been issued to contain the anomaly."
                }
                cvn.publishArticle(article)

                -- Add visual Rift thunder
                sector:addScriptOnce("dlc/rift/sector/riftbackgroundthunder.lua")
                -- Add localized shield drain specific to Cosmic War (without relying on Ascendancy)
                sector:addScriptOnce("sector/cw_rift_hazard.lua")
                break -- Only tear the rift once per sector update
            end
        end
    end
end

local function applyWarHazardSpawns(factions, random)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    for _, f in pairs(factions) do
        local enemy = f:getValue("enemy_faction") or 0
        local rel = 0
        if enemy > 0 then rel = f:getRelations(enemy) end

        -- If at critical war heat (relations very low)
        if rel <= -80000 then
            -- 20% chance to spawn an aggressive strike fleet
            if random:test(0.20) then
                local enemyFaction = Faction(enemy)
                if enemyFaction then
                    local ShipGenerator = include("shipgenerator")
                    local numShips = random:getInt(3, 7)
                    for i = 1, numShips do
                        local pos = MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(random:getInt(-1500, 1500), 0, random:getInt(-1500, 1500)))
                        local ship = ShipGenerator.createMilitaryShip(enemyFaction, pos)
                        if ship then
                            ship:addScriptOnce("ai/patrol.lua")
                        end
                    end

                    local cvn = include("cosmicvaultnews")
                    local article = {
                        title = "Frontline Siege",
                        category = "War Heat Escalation",
                        content = string.format("The intense hostility in sector (%d:%d) has triggered a massive offensive by the %s! A heavy strike fleet has dropped out of hyperspace and is assaulting all targets in sight.", x, y, enemyFaction.name)
                    }
                    cvn.publishArticle(article)
                    break -- Only spawn once per update
                end
            end
        end
    end
end

local function applyEclipseVanguardEvent(factions, random)
    local sector = Sector()

    if not Server():getValue("eclipse_fully_awake") then return end

    for _, f in pairs(factions) do
        local enemy = f:getValue("enemy_faction") or 0
        local rel = 0
        if enemy > 0 then rel = f:getRelations(enemy) end

        -- If at critical war heat while the Eclipse is fully awake, the Vanguard may intervene
        -- directly -- a rare, boss-tier escalation distinct from the Sanitization Protocol's
        -- ceasefire-forcing intervention in applyWeaponizedSubspaceTear above. cw_eclipse_vanguard.lua
        -- re-checks eclipse_fully_awake itself before spawning, so this stays safe even if that
        -- flag flips between the roll below and the script actually attaching.
        if rel <= -80000 then
            if random:test(0.08) then
                sector:addScriptOnce("data/scripts/events/cw_eclipse_vanguard.lua")
                break -- Only one Vanguard per sector update
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
    applyWarProfiteeringShortages(factions, random)
    applyWeaponizedSubspaceTear(factions, random)
    applyWarHazardSpawns(factions, random)
    applyEclipseVanguardEvent(factions, random)
    CosmicWarController._lastEventAt = now
end






