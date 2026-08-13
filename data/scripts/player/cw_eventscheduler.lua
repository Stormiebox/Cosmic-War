package.path = package.path .. ";data/scripts/lib/?.lua"
include("randomext")

-- namespace CW_EventScheduler
CW_EventScheduler = {}

local events = {
    { min = 120, max = 180, script = "events/cw_fleetclash.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "events/cw_refugeeconvoy.lua", timer = 0, schedule = 0 },
    { min = 180, max = 240, script = "events/cw_strandedflagship.lua", timer = 0, schedule = 0 },
    { min = 90,  max = 150, script = "events/cw_armsdeal.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "events/cw_wreckagefield.lua", timer = 0, schedule = 0 },
    { min = 60,  max = 120, script = "events/cw_headhunters.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "events/cw_blockade.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "events/cw_diplomaticsabotage.lua", timer = 0, schedule = 0 }
}

function CW_EventScheduler.getUpdateInterval()
    return 60 -- Check every minute
end

function CW_EventScheduler.initialize()
    if onClient() then return end

    -- Initialize timers with a random offset so they don't all trigger at once
    local now = Player().playtime
    for _, event in pairs(events) do
        if event.schedule == 0 then
            event.schedule = random():getInt(event.min, event.max) * 60
            event.timer = now + random():getInt(0, event.schedule)
        end
    end
end

function CW_EventScheduler.secure()
    return {events = events}
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
end

function CW_EventScheduler.updateServer(timeStep)
    local now = Player().playtime
    for _, event in pairs(events) do
        if now >= event.timer then
            -- Reset timer and roll a new schedule
            event.schedule = random():getInt(event.min, event.max) * 60
            event.timer = now + event.schedule

            -- Spawn event
            local sector = Sector()
            if sector then
                sector:addScriptOnce(event.script)
            end
        end
    end
end

function getUpdateInterval(...) return CW_EventScheduler.getUpdateInterval(...) end
function initialize(...) return CW_EventScheduler.initialize(...) end
function updateServer(...) return CW_EventScheduler.updateServer(...) end
function secure(...) return CW_EventScheduler.secure(...) end
function restore(...) return CW_EventScheduler.restore(...) end

return CW_EventScheduler
