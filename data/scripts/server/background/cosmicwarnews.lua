package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("cosmicwarconfig")
include("cosmicvaultdebug")
include("stringutility")

-- namespace CosmicWarNews
CosmicWarNews = {}

function CosmicWarNews.initialize()
end

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end
    return { ["debugLogs"] = false }
end

function CosmicWarNews.getUpdateInterval()
    local cfg = getCfg()
    return cfg.newsInterval or 420 -- every 7 minutes
end

local function getGalaxyFactions(server)
    if not server or type(server.getValue) ~= "function" then return {} end

    local factions = {}
    local factionStr = server:getValue("factions")
    local factionIndices = {}

    if type(factionStr) == "string" and factionStr ~= "" then
        for id in string.gmatch(factionStr, "([^,]+)") do
            table.insert(factionIndices, tonumber(id))
        end
    end

    for _, index in pairs(factionIndices) do
        local faction = Faction(index)
        if faction then
            table.insert(factions, faction)
        end
    end

    return factions
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-News", msg, ...)
        return
    end

    local cfg = getCfg()
    if not cfg.debugLogs then return end
    print("[Cosmic War][News] " .. msg, ...)
end

local function collectHotConflicts(server)
    local factions = getGalaxyFactions(server)
    local hot = {}
    local processedPairs = {}

    for _, a in pairs(factions) do
        if a and a.isAIFaction and a:getValue("cw_enabled") then
            local enemy = a:getValue("enemy_faction")
            if enemy and enemy > 0 then
                local b = Faction(enemy)
                if b and b.isAIFaction then
                    local left = math.min(a.index, b.index)
                    local right = math.max(a.index, b.index)
                    local pairKey = tostring(left) .. ":" .. tostring(right)

                    if not processedPairs[pairKey] then
                        processedPairs[pairKey] = true

                        local rel = a:getRelations(b.index) or 0
                        if rel <= -35000 then
                            table.insert(hot, { a = a, b = b, rel = rel })
                        end
                    end
                end
            end
        end
    end

    return hot
end

function CosmicWarNews.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local conflicts = collectHotConflicts(server)
    if #conflicts == 0 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 60) * 17)
    local pick = conflicts[random:getInt(1, #conflicts)]
    if not pick then return end

    local templates =
    {
        "War Bulletin: ${factionA} and ${factionB} relations deteriorated to ${rel}."%_T,
        "Conflict Watch: ${factionA} and ${factionB} are entering open hostility (${rel})."%_T,
        "Strategic Alert: tensions between ${factionA} and ${factionB} reached ${rel}."%_T,
    }

    local template = templates[random:getInt(1, #templates)] or templates[1]
    local msg = template % {
        factionA = pick.a.name or ("Faction " .. tostring(pick.a.index)),
        factionB = pick.b.name or ("Faction " .. tostring(pick.b.index)),
        rel = pick.rel
    }

    -- Server-wide chat style bulletin
    Server():broadcastChatMessage("Cosmic War"%_T, ChatMessageType.Information, msg)
    cwlog("%s", msg)
end
