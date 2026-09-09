package.path = package.path .. ";data/scripts/lib/?.lua"

-- NOTE:
-- Chat command scripts in Avorion are expected to expose global entry points:
--   execute(sender, commandName, ...), getDescription(), getHelp()
-- To reduce global collision risk while preserving compatibility, helpers are scoped locally.

-- v4.0.0: a single convenience command listing this mod's other three. Vanilla's own
-- /help already lists every command, modded included, so this doesn't replace
-- anything -- it just saves a player who only remembers "/cosmicwar" from having to
-- scroll /help's full list to find the rest.
local COMMANDS = {
    { name = "/cosmicwarstatus", desc = "Server/admin health snapshot of the war simulation." },
    { name = "/cosmicwarbounties", desc = "Your own Bounty License status, plus the galaxy-wide bounty board." },
    { name = "/cosmicwarintel", desc = "Check banked Intel, or spend it to preview a faction's next expansion target." },
}

function execute(sender, commandName, ...)
    local player = Player(sender)
    if not player then
        return 1, "", "Player not found"
    end

    local parts = { "[Cosmic War] Available commands:" }
    for _, cmd in pairs(COMMANDS) do
        table.insert(parts, string.format("%s -- %s", cmd.name, cmd.desc))
    end

    return 0, table.concat(parts, "\n"), ""
end

function getDescription()
    return "Lists Cosmic War's other chat commands."
end

function getHelp()
    return "/cosmicwar"
end
