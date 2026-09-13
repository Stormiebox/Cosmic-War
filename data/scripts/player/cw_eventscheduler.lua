package.path = package.path .. ";data/scripts/lib/?.lua"
include("cosmicwarconfig")
include("randomext")
include("stringutility")
local CosmicWarBridge = include("cosmicwarbridge")
local CosmicVaultRift = include("cosmicvaultrift")

-- namespace CW_EventScheduler
CW_EventScheduler = {}

-- v4.0.0: a rolling per-player hourly budget on how many of THIS scheduler's own
-- events can fire, per the CCM "War Event Budget" option -- twenty-two of them
-- (twelve original, ten added this Final Pass) on one shared 60-second tick could
-- otherwise fire far more often than any single tuned interval below intends.
-- Vanilla and other mods' own events are untouched; this only throttles this file's
-- own addScriptOnce() calls.
local eventsFiredThisHour = 0
local hourWindowStart = 0

local events = {
    { min = 120, max = 180, script = "data/scripts/events/cw_fleetclash.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "data/scripts/events/cw_refugeeconvoy.lua", timer = 0, schedule = 0 },
    { min = 180, max = 240, script = "data/scripts/events/cw_strandedflagship.lua", timer = 0, schedule = 0 },
    { min = 90,  max = 150, script = "data/scripts/events/cw_armsdeal.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "data/scripts/events/cw_wreckagefield.lua", timer = 0, schedule = 0 },
    { min = 60,  max = 120, script = "data/scripts/events/cw_headhunters.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "data/scripts/events/cw_blockade.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "data/scripts/events/cw_diplomaticsabotage.lua", timer = 0, schedule = 0 },
    { min = 150, max = 210, script = "data/scripts/events/cw_stationsiege.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "data/scripts/events/cw_capital_ship_duel.lua", timer = 0, schedule = 0 },
    { min = 90,  max = 150, script = "data/scripts/events/cw_distress_beacon_trap.lua", timer = 0, schedule = 0 },
    { min = 130, max = 190, script = "data/scripts/events/cw_orbital_bombardment.lua", timer = 0, schedule = 0 },
    -- v4.0.0: ten new events.
    { min = 80,  max = 140, script = "data/scripts/events/cw_border_checkpoint.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "data/scripts/events/cw_field_hospital_convoy.lua", timer = 0, schedule = 0 },
    { min = 110, max = 170, script = "data/scripts/events/cw_artillery_barrage.lua", timer = 0, schedule = 0 },
    { min = 130, max = 190, script = "data/scripts/events/cw_mutiny.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "data/scripts/events/cw_prisoner_transport.lua", timer = 0, schedule = 0 },
    { min = 140, max = 200, script = "data/scripts/events/cw_signal_jamming_net.lua", timer = 0, schedule = 0 },
    { min = 150, max = 210, script = "data/scripts/events/cw_scorched_retreat.lua", timer = 0, schedule = 0 },
    { min = 160, max = 220, script = "data/scripts/events/cw_defection_offer.lua", timer = 0, schedule = 0 },
    { min = 90,  max = 150, script = "data/scripts/events/cw_runner_intercept.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "data/scripts/events/cw_coalition_muster.lua", timer = 0, schedule = 0 }
}

function CW_EventScheduler.getUpdateInterval()
    return 60 -- Check every minute
end

function CW_EventScheduler.initialize()
    if onClient() then return end

    Player():registerCallback("onSectorEntered", "onSectorEntered")

    -- Initialize timers with a random offset so they don't all trigger at once
    local now = Player().playtime
    for _, event in pairs(events) do
        if event.schedule == 0 then
            event.schedule = random():getInt(event.min, event.max) * 60
            event.timer = now + random():getInt(0, event.schedule)
        end
    end
end

function CW_EventScheduler.onSectorEntered(playerIndex, x, y)
    local player = Player(playerIndex)
    if not player then return end

    -- Distress Call FOB Spawns
    local fobStr = player:getValue("cw_distress_fob_list")
    if fobStr and fobStr ~= "" then
        local entries = {}
        for coord in string.gmatch(fobStr, "([^;]+)") do
            table.insert(entries, coord)
        end

        local isFob = false
        local newEntries = {}
        for _, coord in pairs(entries) do
            if coord == x .. "," .. y then
                isFob = true
            else
                table.insert(newEntries, coord)
            end
        end

        if isFob then
            player:setValue("cw_distress_fob_list", table.concat(newEntries, ";") .. (#newEntries > 0 and ";" or ""))

            -- Spawn FOB
            include("galaxy")
            local SectorGenerator = include("SectorGenerator")
            local generator = SectorGenerator(x, y)
            local ShipGenerator = include("shipgenerator")
            local faction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))

            for i = 1, 3 do
                local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
                ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
            end

            local station = generator:createShipyard(faction)
            if station then
                station.title = "Forward Operating Base"%_T
                station:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
            end

            -- Canonical presentation-only Rift instability for the temporary FOB.
            -- A pre-existing Rift condition already supplies presentation, so this
            -- source does not replace a mechanically owned hazard.
            CosmicVaultRift.StartRiftHazard({
                sourceId = "cw-fob:" .. tostring(x) .. ":" .. tostring(y),
                x = x,
                y = y,
                duration = 1800,
                conflictPolicy = "reject"
            })

            player:sendChatMessage("System", ChatMessageType.Warning, "Warning! Hostiles have established a Forward Operating Base in this sector!"%_T)
        end
    end

    -- Bounty Hunter Ambush
    local pendingAmbushIndex = player:getValue("cw_pending_ambush")
    if pendingAmbushIndex and type(pendingAmbushIndex) == "number" then
        player:setValue("cw_pending_ambush", nil)

        local bestEnemy = Faction(pendingAmbushIndex)
        if bestEnemy then
            local random = Random(Seed(Server().unpausedRuntime))
            local dir = vec3(random:getFloat(-1, 1), 0, random:getFloat(-1, 1))
            if length(dir) == 0 then dir = vec3(1, 0, 0) end
            dir = normalize(dir)

            local distance = 3000
            local center = dir * distance

            include("galaxy")
            local ShipGenerator = include("shipgenerator")
            local ShipUtility = include("shiputility")
            local hx, hy = Sector():getCoordinates()

            -- Everything below is anchored to the sector's own balancing curves, so an
            -- elite stays proportionate to whatever region it ambushes the player in.
            local sectorVolume = Balancing_GetSectorShipVolume(hx, hy)
            local sectorTurrets = Balancing_GetEnemySectorTurrets(hx, hy)
            local sectorShipHP = Balancing_GetSectorShipHP(hx, hy)

            for i = 1, random:getInt(3, 6) do
                local pos = center + vec3(random:getFloat(-200, 200), random:getFloat(-200, 200), random:getFloat(-200, 200))
                local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)

                -- The hull is the foundation of the whole buff. Left to itself,
                -- createMilitaryShip() sizes the ship by Balancing_GetShipVolumeDeviation(),
                -- which is 1 + 10*f^4 on a random f -- a quartic that lands near the low end
                -- almost every roll, so an "elite" was usually just an average-sized warship.
                -- An explicit oversized volume gives more hull blocks (base HP), more shield
                -- generator blocks for the shield multipliers below to act on, and more
                -- surface to actually mount guns.
                local ship = ShipGenerator.createMilitaryShip(bestEnemy, matrix, sectorVolume * random:getFloat(3.5, 5.0))

                -- A second pass picks a different random armed template from the faction's
                -- inventory, so an elite fields a mixed loadout instead of one weapon type a
                -- player can hard-counter. addTurretsToCraft caps each call at 10 turrets and
                -- places them by line of sight, so this adds guns rather than replacing them.
                ship:addBaseMultiplier(StatsBonuses.ArmedTurrets, 1.0)
                ShipUtility.addArmedTurretsToCraft(ship, sectorTurrets)

                -- addBaseMultiplier is additive on top of the implicit base 1.0, so a factor
                -- of 3.0 is a 4.0x total -- not 3.0x. There is no Damage member in the
                -- StatsBonuses enum for ships or turrets, so FireRate is the only native DPS
                -- lever (see Avorion_Modding_Codex.md's "no per-damage-type stat" entry).
                ship:addBaseMultiplier(StatsBonuses.FireRate, 3.0)

                -- Shields were previously untouched entirely. The absolute bias is the part
                -- that matters for reliability: a multiplier on a plan that rolled zero shield
                -- generator blocks is still zero, which is a real outcome in low-material
                -- regions, so the flat term guarantees a shield pool regardless of what the
                -- plan generated.
                ship:addAbsoluteBias(StatsBonuses.ShieldDurability, sectorShipHP * 1.5)
                ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 3.0)
                ship:addBaseMultiplier(StatsBonuses.ShieldRecharge, 2.0)

                -- A bigger hull is naturally more sluggish, and an elite the player can simply
                -- outrun is back to being a nuisance. This offsets the volume increase rather
                -- than making them genuinely fast.
                ship:addBaseMultiplier(StatsBonuses.Velocity, 0.5)
                ship:addBaseMultiplier(StatsBonuses.Acceleration, 1.0)

                if ship:hasComponent(ComponentType.Durability) then
                    Durability(ship.index).maxDurabilityFactor = Durability(ship.index).maxDurabilityFactor * 5.0
                end

                -- Crew is recalculated after the extra turrets are mounted, otherwise the new
                -- guns sit undermanned and fire slower than the stats above suggest. The two
                -- refills top the ship up to the maxima the buffs just raised -- createMilitaryShip
                -- already did this once, but that was before any of the above applied.
                ship.crew = ship.idealCrew
                ship.durability = ship.maxDurability
                ship.shieldDurability = ship.shieldMaxDurability

                ship.title = "Elite Headhunter"%_T
                ship:addScriptOnce("ai/patrol.lua")
            end

            player:sendChatMessage("Alert", ChatMessageType.Warning, "Warning: Incoming elite headhunter fleet from " .. bestEnemy.name .. "!"%_T)
        end
    end
end

function CW_EventScheduler.secure()
    return {events = events, eventsFiredThisHour = eventsFiredThisHour, hourWindowStart = hourWindowStart}
end

function CW_EventScheduler.restore(data)
    if data.events then
        for i, savedEvent in pairs(data.events) do
            if events[i] and events[i].script == savedEvent.script then
                events[i].timer = savedEvent.timer
                events[i].schedule = savedEvent.schedule
            else
                for _, e in pairs(events) do
                    if e.script == savedEvent.script then
                        e.timer = savedEvent.timer
                        e.schedule = savedEvent.schedule
                        break
                    end
                end
            end
        end
    end
    eventsFiredThisHour = data.eventsFiredThisHour or 0
    hourWindowStart = data.hourWindowStart or 0
end

function CW_EventScheduler.updateServer(timeStep)
    local now = Player().playtime

    local cfg = CosmicWarConfig.get() or {}
    local budget = cfg.eventBudgetPerHour or 15
    if now - hourWindowStart >= 3600 then
        hourWindowStart = now
        eventsFiredThisHour = 0
    end

    for _, event in pairs(events) do
        if now >= event.timer then
            -- Reschedule regardless of whether the budget allows this one to
            -- actually fire -- an event skipped for budget reasons gets a fresh
            -- roll rather than firing the instant the hourly window resets.
            event.schedule = random():getInt(event.min, event.max) * 60

            -- v4.0.0 Frontlines: reroll faster while the player is sitting in a
            -- sector that's an actual frontline between two warring factions, so War
            -- Events genuinely cluster where the fighting is instead of firing at the
            -- same rate everywhere. Still counted against the same hourly budget below.
            local sector = Sector()
            if sector then
                local sx, sy = sector:getCoordinates()
                if CosmicWarBridge.isFrontlineSector(sx, sy) then
                    event.schedule = math.floor(event.schedule * 0.6)
                end
            end

            event.timer = now + event.schedule

            if eventsFiredThisHour < budget then
                if sector then
                    sector:addScriptOnce(event.script)
                end
                eventsFiredThisHour = eventsFiredThisHour + 1
            end
        end
    end
end



