local cw_old_sector_init = initialize
function initialize(...)
    if cw_old_sector_init then cw_old_sector_init(...) end

    -- Cosmic War sector hook
    if onServer() then
        local sector = Sector()
        if sector then
            sector:addScriptOnce("data/scripts/sector/cosmicwarcontroller.lua")
        end
    end
end
