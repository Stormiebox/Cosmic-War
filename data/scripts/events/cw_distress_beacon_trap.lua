package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local Balancing = include("galaxy")

local CosmicWarEvent = {}

function CosmicWarEvent.initialize()
    if onServer() then
        CosmicWarEvent.spawn()
    end
end

function CosmicWarEvent.spawn()

    local x, y = Sector():getCoordinates()
    local pirateFaction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x,y))

    local beacon = Sector():createWreckage(PlanGenerator.makeStationPlan(pirateFaction), SectorGenerator(x,y):getPositionInSector())
    beacon.title = "Distress Beacon"

    for i=1, 10 do
        local pirate = ShipGenerator.createDefender(pirateFaction, SectorGenerator(x,y):getPositionInSector())
        ShipAI(pirate.index):setAggressive()
    end

    Sector():broadcastChatMessage("Distress Beacon", 0, "Ha ha! You fell for the oldest trick in the galaxy!")

end

function initialize(...)
    if CosmicWarEvent.initialize then return CosmicWarEvent.initialize(...) end
end
