if onServer() then
    local server = Server()
    if server then
        server:addScriptOnce("data/scripts/server/background/cosmicwarnews.lua")
        server:addScriptOnce("data/scripts/server/background/cosmicwardiplomaticsanctions.lua")
        server:addScriptOnce("data/scripts/server/background/cosmicwarceasefires.lua")
        server:addScriptOnce("data/scripts/server/background/cosmicwarbounties.lua")
        server:addCommand("cosmicwarstatus", "data/scripts/commands/cosmicwarstatus.lua", "Cosmic War status")
    end
end
