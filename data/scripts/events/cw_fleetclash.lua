package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")

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

    -- Spawn the invading fleet
    for i = 1, numAttackers do
        local ship = ShipGenerator.createMilitaryShip(enemyFaction, generator:createPositionInSector())
        ShipAI(ship.index):setAggressive()
    end

    sector:broadcastChatMessage(faction.name, ChatMessageType.Warning,
        "Warning! Massive hostile fleet signature detected dropping out of hyperspace! All vessels to battle stations!" %
        _t)
end
