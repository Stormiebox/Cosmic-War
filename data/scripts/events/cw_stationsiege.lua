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
    local attackerFaction = Galaxy():getNearestFaction(x, y)
    local targetStation = Sector():getEntitiesByType(EntityType.Station)
    
    if not targetStation then return end
    
    for i=1, 8 do
        local siegeShip = ShipGenerator.createMilitaryShip(attackerFaction, SectorGenerator(x,y):getPositionInSector())
        siegeShip.title = "Siege Dreadnought"
        ShipAI(siegeShip.index):setAggressive()
    end

end

return CosmicWarEvent
