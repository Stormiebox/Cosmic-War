
package.path = package.path .. ";data/scripts/lib/?.lua"
-- Cosmic War sector hook
if onServer() then
    local sector = Sector()
    if sector then
        sector:addScriptOnce("data/scripts/sector/cosmicwarcontroller.lua")
        sector:addScriptOnce("data/scripts/sector/cw_bountypayouts.lua")
    end
end
