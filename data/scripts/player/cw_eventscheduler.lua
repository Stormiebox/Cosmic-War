package.path = package.path .. ";data/scripts/lib/?.lua"
include("randomext")

-- namespace CW_EventScheduler
CW_EventScheduler = {}

local events = {
    -- Fleet Clash Flashpoint: Triggers roughly every 2-3 hours.
    { schedule = random():getInt(120, 180) * 60, script = "events/cw_fleetclash.lua", timer = 0 },

    -- Refugee Convoy Interception: Medium heat conflict.
    { schedule = random():getInt(120, 180) * 60, script = "events/cw_refugeeconvoy.lua", timer = 0 },

    -- The Stranded Flagship: Climax boss encounter (Slightly rarer, 3-4 hours).
    { schedule = random():getInt(180, 240) * 60, script = "events/cw_strandedflagship.lua", timer = 0 },

    -- Black Market Arms Deal: Early war escalation.
    { schedule = random():getInt(90, 150) * 60, script = "events/cw_armsdeal.lua", timer = 0 },

    -- Wreckage Field Discovery: Aftermath of a massive fleet clash.
    { schedule = random():getInt(100, 160) * 60, script = "events/cw_wreckagefield.lua", timer = 0 },

    -- Elite Headhunters: Triggers if player is highly hated by a warring faction.
    { schedule = random():getInt(60, 120) * 60, script = "events/cw_headhunters.lua", timer = 0 },
    -- Trade Route Blockade: Hostile fleets cut off supply lines.
    { schedule = random():getInt(100, 160) * 60, script = "events/cw_blockade.lua", timer = 0 },
    -- Diplomatic Sabotage: Cooling heat / Ceasefire push.
    { schedule = random():getInt(120, 180) * 60, script = "events/cw_diplomaticsabotage.lua", timer = 0 }
}

function CW_EventScheduler.getUpdateInterval()
    return 60 -- Check every minute
end

function CW_EventScheduler.initialize()
    if onClient() then return end
    
    -- Initialize timers with a random offset so they don't all trigger at once
    for _, event in pairs(events) do
        event.timer = random():getInt(0, event.schedule)
    end
end

function CW_EventScheduler.updateServer(timeStep)
    local player = Player()
    
    for _, event in pairs(events) do
        event.timer = event.timer + timeStep
        
        if event.timer >= event.schedule then
            -- Reset timer and roll a new schedule
            event.timer = 0
            if event.script == "events/cw_strandedflagship.lua" then
                event.schedule = random():getInt(180, 240) * 60
            elseif event.script == "events/cw_armsdeal.lua" then
                event.schedule = random():getInt(90, 150) * 60
            else
                event.schedule = random():getInt(120, 180) * 60
            end
            
            -- Spawn event
            local sector = Sector()
            if sector then
                sector:addScriptOnce(event.script)
            end
        end
    end
end



