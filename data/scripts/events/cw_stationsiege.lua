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
    local sector = Sector()

    -- Roaming war events don't fire in neutral zones -- matches every sibling event
    -- (cw_armsdeal.lua, cw_diplomaticsabotage.lua, etc.).
    if sector:getValue("neutral_zone") then
        terminate()
        return
    end

    local x, y = sector:getCoordinates()
    -- getEntitiesByType() returns MULTIPLE VALUES (Entity, Entity, ...), not a table --
    -- assigning it straight to one local only keeps the first result. With exactly one
    -- station in the sector that first result is a bare Entity (userdata), and #targetStation
    -- below would crash with "attempt to get length of a userdata value". Wrapping the call
    -- in {} collects every returned value into an actual table, which is also what makes an
    -- empty table (rather than nil) the correct "no station" signal to check for below.
    local targetStation = {sector:getEntitiesByType(EntityType.Station)}

    if #targetStation == 0 then
        terminate()
        return
    end

    -- The besieged station's own owner is the defender; the attacker must be that
    -- defender's actual registered enemy, not whichever faction happens to be
    -- physically nearest (getNearestFaction(x,y) on the sector's own coordinates
    -- would almost always just return the defender itself, sieging its own station).
    local defenderFaction = Galaxy():getControllingFaction(x, y)
    if not defenderFaction or not defenderFaction.isAIFaction then
        terminate()
        return
    end

    local enemyIndex = defenderFaction:getValue("enemy_faction") or 0
    local attackerFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not attackerFaction or not attackerFaction.isAIFaction then
        terminate()
        return
    end

    -- The shared dreadnought package in lib/cosmicwardreadnought.lua, so a Siege
    -- Dreadnought here matches the one the capital ship duel and siegeevent.lua field.
    -- Volume is rolled per ship rather than once for the whole wave, so the besieging
    -- force reads as a fleet of individuals instead of identical hulls. Four of them at
    -- this size is a heavier wave than the previous eight were, at half the block count.
    local CosmicWarDreadnought = include("cosmicwardreadnought")
    for i=1, 4 do
        local siegeShip = ShipGenerator.createMilitaryShip(attackerFaction, SectorGenerator(x,y):getPositionInSector(), CosmicWarDreadnought.getVolume(x, y))
        siegeShip.title = "Siege Dreadnought"
        ShipAI(siegeShip.index):setAggressive()
        CosmicWarDreadnought.harden(siegeShip, x, y)
    end
    terminate()
end
