include("data/scripts/galaxy/server.lua")
local CosmicWar_old_init = initialize

function initialize(...)
    if CosmicWar_old_init then CosmicWar_old_init(...) end

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
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwarsiege_server.lua")
            galaxy:addScriptOnce("data/scripts/server/background/cosmicwarexpansion.lua")
        end
    end
end
