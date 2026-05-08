package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, ...)
    local player = Player(sender)
    if not player then
        return 1, "", "Player not found"
    end

    local galaxy = Galaxy()
    if not galaxy then
        return 1, "", "Galaxy unavailable"
    end

    if type(galaxy.getFactions) ~= "function" then
        return 1, "", "Galaxy API not ready"
    end

    local factions = {galaxy:getFactions()}
    local enabled = 0
    local rivalries = 0

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            enabled = enabled + 1
            local enemy = f:getValue("enemy_faction")
            if enemy and enemy > 0 then
                rivalries = rivalries + 1
            end
        end
    end

    local msg = string.format("[Cosmic War] Active AI factions: %d | Rivalry markers: %d", enabled, rivalries)
    return 0, msg, ""
end

function getDescription()
    return "Shows current Cosmic War status."
end

function getHelp()
    return "/cosmicwarstatus"
end
