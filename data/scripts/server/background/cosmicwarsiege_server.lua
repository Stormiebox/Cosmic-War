package.path = package.path .. ";data/scripts/lib/?.lua"

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




