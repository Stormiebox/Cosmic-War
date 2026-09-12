package.path = package.path .. ";data/scripts/lib/?.lua"

include("galaxy")
local ShipUtility = include("shiputility")

CosmicWarDreadnought = CosmicWarDreadnought or {}

--- Shared tuning for every Cosmic War dreadnought-class capital ship.
-- The spawn sites used to each carry their own copy of these numbers and had already
-- drifted apart, so the stats live here once and the events call in.
--
-- Where this tier sits in the suite's size ladder, so it stays a distinct rung:
--   ordinary military ship   1x sector volume
--   Elite Headhunter       3.5x - 5x
--   dreadnought             14x - 18x   (this file)
--   Stranded Flagship        25x
--   Eclipse World-Eater    ~150x and up
CosmicWarDreadnought.VOLUME_MIN = 14.0
CosmicWarDreadnought.VOLUME_MAX = 18.0

--- Hull volume for a dreadnought spawning in sector (x, y).
-- Anchored to the sector's own average so a dreadnought stays proportionate to its
-- region. Deliberately does NOT use Balancing_GetShipVolumeDeviation(): that is
-- 1 + 10*f^4 on a random f, a quartic whose low end dominates almost every roll and
-- whose tail occasionally returns an absurd ship. A flat band gives a consistent
-- silhouette and a predictable block count for the server.
function CosmicWarDreadnought.getVolume(x, y)
    local span = CosmicWarDreadnought.VOLUME_MAX - CosmicWarDreadnought.VOLUME_MIN
    return Balancing_GetSectorShipVolume(x, y) * (CosmicWarDreadnought.VOLUME_MIN + math.random() * span)
end

--- Applies the dreadnought stat package to an already-created ship.
-- Safe to call on a ship of any volume, so an event whose size is set by its own
-- scaling system can still take the durability and firepower half of the treatment.
-- Call this AFTER the ship is fully built -- it refills crew and both health pools to
-- the maxima it raises.
function CosmicWarDreadnought.harden(ship, x, y)
    if not ship then return end

    -- A second pass draws a different random armed template from the faction's
    -- inventory, so a dreadnought fields mixed weapon types rather than one the player
    -- can hard-counter. addTurretsToCraft caps each call at 10 and places by line of
    -- sight, so this adds guns instead of replacing them; the slot bias makes sure the
    -- hull can actually mount them.
    ship:addBaseMultiplier(StatsBonuses.ArmedTurrets, 1.0)
    ShipUtility.addArmedTurretsToCraft(ship, Balancing_GetEnemySectorTurrets(x, y))

    -- addBaseMultiplier is additive on top of an implicit base of 1.0, so 2.5 here is a
    -- 3.5x total. FireRate is the only native DPS lever -- the StatsBonuses enum has no
    -- Damage member for ships or turrets (see Avorion_Modding_Codex.md).
    ship:addBaseMultiplier(StatsBonuses.FireRate, 2.5)

    -- The absolute bias is what makes shields reliable: a multiplier on a plan that
    -- rolled zero shield generator blocks is still zero, which is a real outcome in
    -- low-material regions. The flat term guarantees a pool regardless, and the
    -- multiplier then stacks on whatever blocks the hull does have.
    ship:addAbsoluteBias(StatsBonuses.ShieldDurability, Balancing_GetSectorShipHP(x, y) * 3.0)
    ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 4.0)
    ship:addBaseMultiplier(StatsBonuses.ShieldRecharge, 1.0)

    -- The hull itself. Previously nothing touched this at all, which is why stripping a
    -- dreadnought's shield left an ordinary military ship underneath.
    if ship:hasComponent(ComponentType.Durability) then
        Durability(ship.index).maxDurabilityFactor = Durability(ship.index).maxDurabilityFactor * 6.0
    end

    -- Speed is left alone on purpose. A hull this size is naturally sluggish and that
    -- suits the class -- a dreadnought is meant to be outmanoeuvred, just not survived.

    -- Crew is recalculated after the extra turrets are mounted, otherwise the new guns
    -- sit undermanned and fire slower than the stats above imply. The two refills top
    -- the ship up to the maxima this function just raised.
    ship.crew = ship.idealCrew
    ship.durability = ship.maxDurability
    ship.shieldDurability = ship.shieldMaxDurability
end

return CosmicWarDreadnought
