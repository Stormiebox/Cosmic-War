package.path = package.path .. ";data/scripts/lib/?.lua"

if onServer() then
    local player = Player()
    -- Attach the Galactic Politics UI to the player window
    player:addScriptOnce("data/scripts/player/ui/galacticpolitics_tab.lua")
end