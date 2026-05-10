package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("faction")
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
    print("[Cosmic War][Sector] " .. msg, ...)
end

local function getFactionByIndex(index)
    if not index or index <= 0 then return nil end
    return Faction(index)
end

local function getAliveWarFactionsInSector()
    local sector = Sector()
    local entities = { sector:getEntitiesByType(EntityType.Ship) }
    local present = {}

    for _, e in pairs(entities) do
        if valid(e) and e.factionIndex and e.factionIndex > 0 and e.durability > 0 then
            local f = getFactionByIndex(e.factionIndex)
            if f and f.isAIFaction and f:getValue("cw_enabled") then
                present[f.index] = f
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
    local newRel = math.max(-100000, rel - worsen)

    a:setRelations(b.index, newRel)
    b:setRelations(a.index, newRel)

    a:setValue("cw_target_faction", b.index)
    b:setValue("cw_target_faction", a.index)

    a:setValue("enemy_faction", b.index)
    b:setValue("enemy_faction", a.index)

    cwlog("War pressure applied: %s(%i) <-> %s(%i), rel %i -> %i",
        a.name or "A", a.index or -1,
        b.name or "B", b.index or -1,
        rel, newRel
    )
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
    CosmicWarController._lastEventAt = now
end
