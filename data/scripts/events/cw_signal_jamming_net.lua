package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("relations")

-- namespace CW_SignalJammingNetEvent
-- v4.0.0: a genuine "fight your way out" state this mod otherwise
-- lacks. A net of jammer drones periodically blocks hyperspace charge-up for
-- every present player, the same Entity:blockHyperspace(time) API and
-- continuous-reapplication pattern vanilla's own entity/blocker.lua uses --
-- while at least one drone survives, nobody present can jump away.
CW_SignalJammingNetEvent = {}

CW_SignalJammingNetEvent.droneIds = {}
CW_SignalJammingNetEvent.factionIndex = 0
CW_SignalJammingNetEvent.resolved = false

function CW_SignalJammingNetEvent.getUpdateInterval()
    return 2.0
end

function CW_SignalJammingNetEvent.initialize()
    if onServer() then
        if not _restoring then
            CW_SignalJammingNetEvent.spawn()
        end
    end
end

function CW_SignalJammingNetEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction or not faction:getValue("cw_enabled") then
        terminate()
        return
    end
    CW_SignalJammingNetEvent.factionIndex = faction.index

    local generator = SectorGenerator(x, y)
    for i = 1, random():getInt(3, 4) do
        local drone = ShipGenerator.createDefender(faction, generator:getPositionInSector())
        drone.title = "Jammer Drone"%_T
        ShipAI(drone.index):setAggressive()
        -- Without this, a player who leaves before the net is cleared leaves the drones --
        -- and this event's own updateServer polling -- running forever.
        drone:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        table.insert(CW_SignalJammingNetEvent.droneIds, drone.id)
    end

    sector:broadcastChatMessage(faction.name, ChatMessageType.Warning,
        "Signal jamming net active. Nobody's hyperdrive is charging until this net is down."%_T)
end

function CW_SignalJammingNetEvent.updateServer(timeStep)
    if not onServer() or CW_SignalJammingNetEvent.resolved then return end

    local sector = Sector()
    local anyDroneAlive = false
    for _, id in pairs(CW_SignalJammingNetEvent.droneIds) do
        local drone = sector:getEntity(id)
        if drone and valid(drone) then
            anyDroneAlive = true
            break
        end
    end

    if not anyDroneAlive then
        CW_SignalJammingNetEvent.resolved = true
        sector:broadcastChatMessage("Signal Jamming Net"%_T, ChatMessageType.Information,
            "The net is down. Hyperdrives are clear to charge again."%_T)
        terminate()
        return
    end

    for _, player in pairs({sector:getPlayers()}) do
        -- The drones' own combat AI already respects faction relations (ShipAI:setAggressive()
        -- won't fire on a player the controlling faction is at peace or allied with), but this
        -- jamming loop had no such check at all -- it applied to every player physically present
        -- in the sector, regardless of standing. That let this event spawn in a sector controlled
        -- by an ALLIED faction and trap the player indefinitely with no hostiles to fight and no
        -- escape but destroying the ally's own defensive drones (souring that relationship for
        -- nothing). Only jam players actually at war with the controlling faction, matching the
        -- "fight your way out of hostile territory" framing this event is meant to be.
        if player:getRelationStatus(CW_SignalJammingNetEvent.factionIndex) == RelationStatus.War then
            local ship = player.craftIndex and sector:getEntity(player.craftIndex)
            if ship and ship:hasComponent(ComponentType.HyperspaceEngine) then
                ship:blockHyperspace(2.5)
            end
        end
    end
end

function CW_SignalJammingNetEvent.secure()
    local savedDrones = {}
    for _, id in pairs(CW_SignalJammingNetEvent.droneIds) do
        table.insert(savedDrones, id.string)
    end
    return { droneIds = savedDrones, factionIndex = CW_SignalJammingNetEvent.factionIndex, resolved = CW_SignalJammingNetEvent.resolved }
end

function CW_SignalJammingNetEvent.restore(data)
    CW_SignalJammingNetEvent.droneIds = {}
    if data.droneIds then
        for _, idStr in pairs(data.droneIds) do
            table.insert(CW_SignalJammingNetEvent.droneIds, Uuid(idStr))
        end
    end
    CW_SignalJammingNetEvent.factionIndex = data.factionIndex or 0
    CW_SignalJammingNetEvent.resolved = data.resolved or false
end
