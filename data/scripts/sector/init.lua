package.path = package.path .. ";data/scripts/lib/?.lua"
-- Cosmic War sector hook
if onServer() then
    local sector = Sector()
    if sector then
        sector:addScriptOnce("data/scripts/sector/cosmicwarcontroller.lua")
    end
end
