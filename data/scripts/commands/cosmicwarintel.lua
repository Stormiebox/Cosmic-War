package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

-- NOTE:
-- Chat command scripts in Avorion are expected to expose global entry points:
--   execute(sender, commandName, ...), getDescription(), getHelp()
-- To reduce global collision risk while preserving compatibility, helpers are scoped locally.

local CosmicWarBridge = include("cosmicwarbridge")
local cvf = include("cosmicvaultfaction")
local CosmicWarConfig = include("cosmicwarconfig")

local INTEL_PREVIEW_COST = (CosmicWarConfig and CosmicWarConfig.get() or {}).intelPreviewCost or 50

local function getKnownAIFactions()
    local server = Server()
    if not server or type(server.getValue) ~= "function" then return {} end

    local factionStr = server:getValue("factions")
    local out = {}
    if type(factionStr) == "string" and factionStr ~= "" then
        for id in string.gmatch(factionStr, "([^,]+)") do
            local f = Faction(tonumber(id))
            if f and f.isAIFaction then table.insert(out, f) end
        end
    end
    return out
end

local function findFactionByName(query)
    if not query or query == "" then return nil end
    local lowerQuery = string.lower(query)
    local best = nil
    for _, f in pairs(getKnownAIFactions()) do
        if f.name and string.find(string.lower(f.name), lowerQuery, 1, true) then
            best = f
            break
        end
    end
    return best
end

local function listMyIntel(player)
    local lines = {}
    for _, f in pairs(getKnownAIFactions()) do
        local points = CosmicWarBridge.getIntel(player, f.index)
        if points > 0 then
            table.insert(lines, string.format("  %s -- %d Intel", f.name, points))
        end
    end
    return lines
end

function execute(sender, commandName, ...)
    local player = Player(sender)
    if not player then
        return 1, "", "Player not found"
    end

    local args = { ... }
    local query = table.concat(args, " ")

    if query == "" then
        local lines = listMyIntel(player)
        if #lines == 0 then
            return 0, "[Intel] No Intel banked yet. Complete Force Recon, Sensor Deployment, or Black Box Retrieval War Contracts to gather some.", ""
        end
        table.insert(lines, 1, string.format("[Intel] Your banked Intel (spend %d against a faction with '/cosmicwarintel <faction name>'):", INTEL_PREVIEW_COST))
        return 0, table.concat(lines, "\n"), ""
    end

    local faction = findFactionByName(query)
    if not faction then
        return 0, "[Intel] No known faction matches '" .. query .. "'.", ""
    end

    local points = CosmicWarBridge.getIntel(player, faction.index)
    if points < INTEL_PREVIEW_COST then
        return 0, string.format("[Intel] You have %d/%d Intel against %s -- not enough for a preview yet.", points, INTEL_PREVIEW_COST, faction.name), ""
    end

    if (cvf.getTrait(faction.index, "cw_imperialist") or 0) <= 0 then
        -- Spend it anyway -- the player asked for a read on this faction, and a
        -- non-Imperialist faction genuinely doesn't have a discernible expansion
        -- pattern to leak. Confirms the intel gathering wasn't wasted effort.
        CosmicWarBridge.spendIntel(player, faction.index, INTEL_PREVIEW_COST)
        return 0, string.format("[Intel] Spent %d Intel: %s shows no active expansionist pattern -- nothing concrete to report.", INTEL_PREVIEW_COST, faction.name), ""
    end

    -- Deterministic seed so every player asking about the same faction in the same
    -- 15-minute expansion-tick window gets the same answer, rather than each query
    -- rerolling a fresh random heading.
    local seed = Server().seed + faction.index * 101 + math.floor(Server().unpausedRuntime / 900)
    local tx, ty = CosmicWarBridge.findExpansionCandidate(faction, 15, seed)

    CosmicWarBridge.spendIntel(player, faction.index, INTEL_PREVIEW_COST)

    if tx and ty then
        return 0, string.format("[Intel] Spent %d Intel: scouting reports place %s's next expansion push toward sector (%d:%d).", INTEL_PREVIEW_COST, faction.name, tx, ty), ""
    else
        return 0, string.format("[Intel] Spent %d Intel: %s is currently boxed in on every scouted heading -- no clear expansion target.", INTEL_PREVIEW_COST, faction.name), ""
    end
end

function getDescription()
    return "Check your banked Intel, or spend it against a faction to preview their next likely expansion target."
end

function getHelp()
    return "/cosmicwarintel [faction name]"
end
