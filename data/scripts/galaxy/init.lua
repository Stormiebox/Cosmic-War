local cw_old_galaxy_init = initialize
function initialize(...)
    if cw_old_galaxy_init then cw_old_galaxy_init(...) end

    if onServer() then
        local galaxy = Galaxy()
        if galaxy then
            -- Attach background simulation scripts to the global galaxy loop
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwarnews.lua")
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwardiplomaticsanctions.lua")
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwarceasefires.lua")
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwarbounties.lua")
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwarbridgeupdate.lua")
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwardiplomacy.lua")
        end
    end
end
