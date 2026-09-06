package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
include("galaxy")

-- namespace CW_DistressBeaconTrapEvent
CW_DistressBeaconTrapEvent = {}

function CW_DistressBeaconTrapEvent.initialize()
    if onServer() then
        CW_DistressBeaconTrapEvent.spawn()
    end
end

function CW_DistressBeaconTrapEvent.spawn()
    local sector = Sector()

    -- A lone distress signal only makes sense out in unclaimed space -- don't spring the
    -- trap in a neutral zone or in a sector any faction already controls (populated,
    -- station-heavy sectors are exactly where this shouldn't be able to fire).
    if sector:getValue("neutral_zone") then
        terminate()
        return
    end

    local x, y = sector:getCoordinates()
    if Galaxy():getControllingFaction(x, y) then
        terminate()
        return
    end

    local pirateFaction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))
    if not pirateFaction then
        terminate()
        return
    end

    local generator = SectorGenerator(x, y)

    -- A distress beacon is a small prop, not a derelict station. createBeacon() builds the
    -- real, purpose-built small beacon plan (PlanGenerator.makeBeaconPlan) -- the same call
    -- already used correctly by this mod's Wartime Propaganda Beacon (siegeevent.lua).
    local beacon = generator:createBeacon(generator:getPositionInSector(), pirateFaction,
        "This is Outrider-7... hull breached, losing life support... is anyone out there, please hurry...")
    beacon.title = "Distress Beacon"
    beacon:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    for i = 1, 10 do
        local pirate = ShipGenerator.createDefender(pirateFaction, generator:getPositionInSector())
        ShipAI(pirate.index):setAggressive()
        pirate:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    sector:broadcastChatMessage("Distress Beacon"%_T, ChatMessageType.Warning, "Ha ha! You fell for the oldest trick in the galaxy!"%_T)
    terminate()
end
