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

    -- v4.0.0: these carried a "Dreadnought" title with no size or toughness premium
    -- over a default military ship. 8x volume + the same 5x shield multiplier
    -- siegeevent.lua's own Siege Dreadnoughts use makes the title match the ship.
    local volume = Balancing_GetSectorShipVolume(x, y) * Balancing_GetShipVolumeDeviation() * 8.0

    local dreadA = ShipGenerator.createMilitaryShip(facA, SectorGenerator(x,y):getPositionInSector(), volume)
    dreadA.title = facA.name .. " Dreadnought"
    ShipAI(dreadA.index):setAggressive()
    if dreadA:hasComponent(ComponentType.Shield) then
        dreadA:addBaseMultiplier(StatsBonuses.ShieldDurability, 4.0)
        dreadA.shieldDurability = dreadA.shieldMaxDurability
    end

    local dreadB = ShipGenerator.createMilitaryShip(facB, SectorGenerator(x,y):getPositionInSector(), volume)
    dreadB.title = facB.name .. " Dreadnought"
    ShipAI(dreadB.index):setAggressive()
    if dreadB:hasComponent(ComponentType.Shield) then
        dreadB:addBaseMultiplier(StatsBonuses.ShieldDurability, 4.0)
        dreadB.shieldDurability = dreadB.shieldMaxDurability
    end

    Sector():broadcastChatMessage("Scanner", 0, "Massive hyperspace signatures detected. Two capital ships are engaging!"%_T)
    terminate()
end
