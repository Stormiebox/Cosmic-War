package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultTerritory = include("cosmicvaultterritory")

-- namespace CosmicWarSiegeServer
CosmicWarSiegeServer = {}

function CosmicWarSiegeServer.initialize()
    if onServer() then
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    end
end

function CosmicWarSiegeServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:addScriptOnce("data/scripts/player/cw_siege_injector_persistent.lua")
    end
end


function initialize(...)
    if CosmicWarSiegeServer.initialize then return CosmicWarSiegeServer.initialize(...) end
end
function onPlayerLogIn(...)
    if CosmicWarSiegeServer.onPlayerLogIn then return CosmicWarSiegeServer.onPlayerLogIn(...) end
end

return CosmicWarSiegeServer
