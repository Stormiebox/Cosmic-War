package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- namespace CW_CapitalShipDuelEvent
CW_CapitalShipDuelEvent = {}

function CW_CapitalShipDuelEvent.initialize()
    if onServer() then
        CW_CapitalShipDuelEvent.spawn()
    end
end

function CW_CapitalShipDuelEvent.spawn()

    local x, y = Sector():getCoordinates()
    local facA = Galaxy():getNearestFaction(x + 10, y + 10)
    local facB = Galaxy():getNearestFaction(x - 10, y - 10)

    -- Either lookup can land in no man's land and return nil; bail out cleanly instead of
    -- indexing a nil faction below.
    if not facA or not facB then
        terminate()
        return
    end

    local dreadA = ShipGenerator.createMilitaryShip(facA, SectorGenerator(x,y):getPositionInSector())
    dreadA.title = facA.name .. " Dreadnought"

    local dreadB = ShipGenerator.createMilitaryShip(facB, SectorGenerator(x,y):getPositionInSector())
    dreadB.title = facB.name .. " Dreadnought"

    Sector():broadcastChatMessage("Scanner", 0, "Massive hyperspace signatures detected. Two capital ships are engaging!")
    terminate()
end
