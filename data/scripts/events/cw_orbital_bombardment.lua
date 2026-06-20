package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

local CosmicWarEvent = {}

function CosmicWarEvent.initialize()
    if onServer() then
        CosmicWarEvent.spawn()
    end
end

function CosmicWarEvent.spawn()

    local x, y = Sector():getCoordinates()
    local attackerFaction = Galaxy():getNearestFaction(x + 15, y + 15)

    for i=1, 5 do
        local bomber = ShipGenerator.createMilitaryShip(attackerFaction, SectorGenerator(x,y):getPositionInSector())
        bomber.title = "Orbital Bomber"
        ShipAI(bomber.index):setAggressive()
        -- In a full implementation, they would have scripts drawing laser lines to the planet mesh
    end

    Sector():broadcastChatMessage("Planetary Defense", 0, "Mayday! We are under intense orbital bombardment! Any available ships, please assist!")

end

function initialize(...)
    if CosmicWarEvent.initialize then return CosmicWarEvent.initialize(...) end
end
