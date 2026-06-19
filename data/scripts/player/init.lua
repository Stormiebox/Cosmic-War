package.path = package.path .. ";data/scripts/lib/?.lua"

-- Initialize Cosmic War Custom Traits Registry
local cwt = include("cosmicwartraits")

if onServer() then
    local player = Player()
    player:addScriptOnce("data/scripts/player/ui/galacticpolitics_tab.lua")
    player:addScriptOnce("data/scripts/player/cw_eventscheduler.lua")
    player:addScriptOnce("data/scripts/player/cosmicwarcodex.lua")
end
