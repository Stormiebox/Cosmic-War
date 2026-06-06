package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local player = Player()
    player:addScriptOnce("data/scripts/player/ui/galacticpolitics_tab.lua")
    player:addScriptOnce("data/scripts/player/cw_eventscheduler.lua")
end
