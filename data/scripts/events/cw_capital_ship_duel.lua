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
    local sector = Sector()

    -- Roaming war events don't fire in neutral zones -- matches every sibling event
    -- (cw_armsdeal.lua, cw_diplomaticsabotage.lua, etc.).
    if sector:getValue("neutral_zone") then
        terminate()
        return
    end

    local x, y = sector:getCoordinates()
    local facA = Galaxy():getNearestFaction(x + 10, y + 10)

    -- getNearestFaction can land in no man's land (nil), and isn't restricted to AI
    -- factions -- a player faction/alliance could otherwise be cast as a "duelist."
    if not facA or not facA.isAIFaction then
        terminate()
        return
    end

    -- The second duelist must be facA's own registered enemy, not just "whichever
    -- faction is nearest a second offset point" -- that gave no guarantee the two
    -- ships were even hostile to each other, or even different factions.
    local enemyIndex = facA:getValue("enemy_faction") or 0
    local facB = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not facB or not facB.isAIFaction then
        terminate()
        return
    end

    -- Both duellists are built from the shared dreadnought package in
    -- lib/cosmicwardreadnought.lua, so this tier stays consistent across every event
    -- that fields one. Each rolls its own volume, so the two are visibly not clones.
    local CosmicWarDreadnought = include("cosmicwardreadnought")

    local dreadA = ShipGenerator.createMilitaryShip(facA, SectorGenerator(x,y):getPositionInSector(), CosmicWarDreadnought.getVolume(x, y))
    dreadA.title = facA.name .. " Dreadnought"
    ShipAI(dreadA.index):setAggressive()
    CosmicWarDreadnought.harden(dreadA, x, y)

    local dreadB = ShipGenerator.createMilitaryShip(facB, SectorGenerator(x,y):getPositionInSector(), CosmicWarDreadnought.getVolume(x, y))
    dreadB.title = facB.name .. " Dreadnought"
    ShipAI(dreadB.index):setAggressive()
    CosmicWarDreadnought.harden(dreadB, x, y)

    Sector():broadcastChatMessage("Scanner", 0, "Massive hyperspace signatures detected. Two capital ships are engaging!"%_T)
    terminate()
end
