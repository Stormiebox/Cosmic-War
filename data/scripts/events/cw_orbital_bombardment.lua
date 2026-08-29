package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- namespace CW_OrbitalBombardmentEvent
CW_OrbitalBombardmentEvent = {}

function CW_OrbitalBombardmentEvent.initialize()
    if onServer() then
        CW_OrbitalBombardmentEvent.spawn()
    end
end

function CW_OrbitalBombardmentEvent.spawn()

    local x, y = Sector():getCoordinates()
    local attackerFaction = Galaxy():getNearestFaction(x + 15, y + 15)

    for i=1, 5 do
        local bomber = ShipGenerator.createMilitaryShip(attackerFaction, SectorGenerator(x,y):getPositionInSector())
        bomber.title = "Orbital Bomber"
        ShipAI(bomber.index):setAggressive()
        -- In a full implementation, they would have scripts drawing laser lines to the planet mesh
    end

    Sector():broadcastChatMessage("Planetary Defense", 0, "Mayday! We are under intense orbital bombardment! Any available ships, please assist!")
    Sector():removeScript("events/cw_orbital_bombardment.lua")
    terminate()
end

