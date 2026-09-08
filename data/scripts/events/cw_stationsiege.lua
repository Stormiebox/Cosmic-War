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

    -- v4.0.0: these carried the "Siege Dreadnought" title with no size or toughness
    -- premium over a default military ship. 8x volume + the same 5x shield multiplier
    -- siegeevent.lua's own Siege Dreadnoughts use (a distinct, lower tier than Stranded
    -- Flagship's 25x-volume true endgame dreadnought) makes the title match the ship.
    local volume = Balancing_GetSectorShipVolume(x, y) * Balancing_GetShipVolumeDeviation() * 8.0
    for i=1, 8 do
        local siegeShip = ShipGenerator.createMilitaryShip(attackerFaction, SectorGenerator(x,y):getPositionInSector(), volume)
        siegeShip.title = "Siege Dreadnought"
        ShipAI(siegeShip.index):setAggressive()
        if siegeShip:hasComponent(ComponentType.Shield) then
            siegeShip:addBaseMultiplier(StatsBonuses.ShieldDurability, 4.0)
            siegeShip.shieldDurability = siegeShip.shieldMaxDurability
        end
    end
    terminate()
end
