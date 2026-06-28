package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("stringutility")

-- namespace CW_FleetClashEvent
CW_FleetClashEvent = {}

function CW_FleetClashEvent.initialize()
    if onClient() then return end

    -- Give the player a couple of seconds to load into the sector before the chaos starts
    if not _restoring then
        deferredCallback(2.0, "spawn")
    end

    -- Terminate the event script after 15 minutes to clear memory (the spawned ships will remain)
    deferredCallback(15 * 60, "finalize")
end

function CW_FleetClashEvent.finalize()
    terminate()
end

function CW_FleetClashEvent.spawn()
    local sector = Sector()

    -- Do not start wars in neutral zones or sanctuaries
    if sector:getValue("neutral_zone") then
        terminate()
        return
    end

    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)

    -- Only trigger if the player jumped into AI Faction territory
    if not faction or not faction.isAIFaction then
        terminate()
        return
    end

    local enemyId = faction:getValue("enemy_faction")
    if not enemyId or enemyId <= 0 then
        terminate()
        return
    end

    local enemyFaction = Faction(enemyId)
    if not enemyFaction then
        terminate()
        return
    end

    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(faction.index) or 0
    end

    -- Only trigger massive flashpoints if tensions are extremely high
    if heat < 0.60 then
        terminate()
        return
    end

    local generator = SectorGenerator(x, y)
    local numAttackers = math.floor(4 + (heat * 5))
    local volumeMult = 1.0

    local CosmicVaultScaling = include("cosmicvaultscaling")
    if CosmicVaultScaling then
        local defenderStats = CosmicVaultScaling.calculateSectorDefenderStrength(enemyId)
        local baseVol = Balancing_GetSectorShipVolume(x, y)

        local spawnParams = CosmicVaultScaling.calculateInvaderSpawnParams(defenderStats, baseVol, 1.0)
        numAttackers = spawnParams.count
        volumeMult = spawnParams.volumeMultiplier
    end

    local random = Random(Seed(x .. y))
    local usedJammer = false
    if random:test(0.5) then
        usedJammer = true
        local shipsAndStations = {sector:getEntitiesByType(EntityType.Ship)}
        for _, s in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            table.insert(shipsAndStations, s)
        end
        for _, ent in pairs(shipsAndStations) do
            if ent.factionIndex ~= enemyId and ent.factionIndex > 0 then
                ent:addScriptOnce("data/scripts/entity/debuffs/cw_shieldjammer.lua")
            end
        end
    end

    -- Spawn the invading fleet
    for i = 1, numAttackers do
        local volume = Balancing_GetSectorShipVolume(x, y) * volumeMult
        local ship = ShipGenerator.createMilitaryShip(enemyFaction, generator:getPositionInSector(), volume)
        ShipAI(ship.index):setAggressive()
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    if usedJammer then
        sector:broadcastChatMessage(enemyFaction.name, ChatMessageType.Warning,
            "Target locked. Electronic warfare initialized. Suppressing all sector shields."%_T)
    end

    sector:broadcastChatMessage(faction.name, ChatMessageType.Warning,
        "Warning! Massive hostile fleet signature detected dropping out of hyperspace! All vessels to battle stations!"%_T)

    local article = {
        title = "Massive Fleet Clash Erupts",
        content = "A colossal hostile fleet signature has been detected dropping out of hyperspace in sector [" .. x .. ":" .. y .. "]. The " .. faction.name .. " military has declared a sector-wide state of emergency as they engage the invading " .. enemyFaction.name .. " forces.",
        category = "Conflict"
    }
    local cv_news = include("cosmicvaultnews")
    if cv_news and cv_news.publishArticle then
        cv_news.publishArticle(article)
    else
        Server():sendCallback("onCCNewsPublishArticle", article)
    end
end


function initialize(...)
    if CW_FleetClashEvent.initialize then return CW_FleetClashEvent.initialize(...) end
end

return CW_FleetClashEvent

