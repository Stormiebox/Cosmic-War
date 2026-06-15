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
    -- Safety Guard: Ensure Cosmic Ascendancy is installed before unleashing The Eclipse
    local hasAscendancy = true; include("cosmicascendancybridge")
    if not hasAscendancy then
        print("[Cosmic War] Cosmic Ascendancy not detected. Skipping Eclipse Vanguard event.")
        return
    end


    local x, y = Sector():getCoordinates()
    -- Emulate a boss-level faction
    local eclipseFaction = Galaxy():getPirateFaction(0) 
    
    local dreadnought = ShipGenerator.createBossShip(eclipseFaction, SectorGenerator(x,y):getPositionInSector())
    dreadnought.title = "The Eclipse Vanguard"
    dreadnought:addScript("data/scripts/entity/ai/patrol.lua")
    dreadnought.damageMultiplier = 500.0 -- Unfair fixed scaling
    dreadnought.shieldMultiplier = 500.0
    
    Sector():broadcastChatMessage("Unknown", 2, "WARNING: MASSIVE ANOMALY DETECTED. THE ECLIPSE VANGUARD HAS ARRIVED.")

end

return CosmicWarEvent
