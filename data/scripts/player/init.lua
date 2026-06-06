package.path = package.path .. ";data/scripts/lib/?.lua"

local cw_old_init = initialize

function initialize(...)
    if cw_old_init then cw_old_init(...) end

    if onServer() then
        local player = Player()
        -- Attach the Galactic Politics UI to the player window
        player:addScriptOnce("data/scripts/player/ui/galacticpolitics_tab.lua")
        
        -- Safely attach the event scheduler
        player:addScriptOnce("data/scripts/player/cw_eventscheduler.lua")
    end
end