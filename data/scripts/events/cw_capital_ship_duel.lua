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
    local facA = Galaxy():getNearestFaction(x + 10, y + 10)
    local facB = Galaxy():getNearestFaction(x - 10, y - 10)

    local dreadA = ShipGenerator.createMilitaryShip(facA, SectorGenerator(x,y):getPositionInSector())
    dreadA.title = facA.name .. " Dreadnought"

    local dreadB = ShipGenerator.createMilitaryShip(facB, SectorGenerator(x,y):getPositionInSector())
    dreadB.title = facB.name .. " Dreadnought"

    Sector():broadcastChatMessage("Scanner", 0, "Massive hyperspace signatures detected. Two capital ships are engaging!")

end

function initialize(...)
    if CosmicWarEvent.initialize then return CosmicWarEvent.initialize(...) end
end
