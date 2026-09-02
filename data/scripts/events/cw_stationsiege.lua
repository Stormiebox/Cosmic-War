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
    -- getEntitiesByType() returns MULTIPLE VALUES (Entity, Entity, ...), not a table --
    -- assigning it straight to one local only keeps the first result. With exactly one
    -- station in the sector that first result is a bare Entity (userdata), and #targetStation
    -- below would crash with "attempt to get length of a userdata value". Wrapping the call
    -- in {} collects every returned value into an actual table, which is also what makes an
    -- empty table (rather than nil) the correct "no station" signal to check for below.
    local targetStation = {Sector():getEntitiesByType(EntityType.Station)}

    if #targetStation == 0 or not attackerFaction then
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
