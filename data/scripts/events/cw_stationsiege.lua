package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- namespace CW_StationsiegeEvent
CW_StationsiegeEvent = {}

function CW_StationsiegeEvent.initialize()
    if onServer() then
        CW_StationsiegeEvent.spawn()
    end
end

function CW_StationsiegeEvent.spawn()

    local x, y = Sector():getCoordinates()
    local attackerFaction = Galaxy():getNearestFaction(x, y)
    local targetStation = Sector():getEntitiesByType(EntityType.Station)

    if not targetStation or not attackerFaction then
        terminate()
        return
    end

    for i=1, 8 do
        local siegeShip = ShipGenerator.createMilitaryShip(attackerFaction, SectorGenerator(x,y):getPositionInSector())
        siegeShip.title = "Siege Dreadnought"
        ShipAI(siegeShip.index):setAggressive()
    end
    terminate()
end
