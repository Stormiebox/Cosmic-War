-- Inject Cosmic War Dynamic Events into the global player event scheduler

-- Fleet Clash Flashpoint: Triggers roughly every 2-3 hours.
-- The event script itself handles checking if the sector is valid for a warzone.
table.insert(events,
    { schedule = random():getInt(120, 180) * 60, script = "sectoreventstarter", arguments = { "events/cw_fleetclash.lua" } })

-- Refugee Convoy Interception: Medium heat conflict.
table.insert(events,
    { schedule = random():getInt(120, 180) * 60, script = "sectoreventstarter", arguments = { "events/cw_refugeeconvoy.lua" } })

-- The Stranded Flagship: Climax boss encounter (Slightly rarer, 3-4 hours).
table.insert(events,
    { schedule = random():getInt(180, 240) * 60, script = "sectoreventstarter", arguments = { "events/cw_strandedflagship.lua" } })

-- Black Market Arms Deal: Early war escalation.
table.insert(events,
    { schedule = random():getInt(90, 150) * 60, script = "sectoreventstarter", arguments = { "events/cw_armsdeal.lua" } })

-- Diplomatic Sabotage: Cooling heat / Ceasefire push.
table.insert(events,
    { schedule = random():getInt(120, 180) * 60, script = "sectoreventstarter", arguments = { "events/cw_diplomaticsabotage.lua" } })
