package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("cosmicwarconfig")
include("cosmicvaultdebug")
include("stringutility")

-- namespace CosmicWarNews
CosmicWarNews = {}

function CosmicWarNews.initialize()
    if onServer() then
        Server():registerCallback("onCCNewsRequestSeed", "onSeedNews")
    end
end

local function getCfg()
    return CosmicWarConfig.get() or { ["debugLogs"] = false }
end

function CosmicWarNews.getUpdateInterval()
    local cfg = getCfg()
    return cfg.newsInterval or 600 -- every 10 minutes
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
    CosmicVaultDebug.info("CosmicWar-News", msg, ...)
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

    local random = Random(server.seed+math.floor(server.unpausedRuntime/60)*17)
    local pick = conflicts[random:getInt(1, #conflicts)]
    if not pick then return end

    local aStance = pick.a:getValue("cw_diplomatic_stance") or "Balanced"
    local bStance = pick.b:getValue("cw_diplomatic_stance") or "Balanced"

    local templates =
    {
        "War Bulletin: %1% [%4%] and %2% [%5%] relations deteriorated to %3%."%_T,
        "Conflict Watch: %1% [%4%] and %2% [%5%] are entering open hostility. Relations at %3%."%_T,
        "Strategic Alert: tensions between %1% [%4%] and %2% [%5%] reached %3%."%_T,
    }

    local template = templates[random:getInt(1, #templates)] or templates[1]
    local factionA = pick.a.name or ("Faction " .. tostring(pick.a.index))
    local factionB = pick.b.name or ("Faction " .. tostring(pick.b.index))
    local relStr = tostring(pick.rel)

    -- Server-wide chat style bulletin (Deferred Translation using positional C++ varargs)
    Server():broadcastChatMessage("Cosmic War"%_T, ChatMessageType.Information, template, factionA, factionB, relStr, aStance, bStance)

    cwlog("War Bulletin: %s [%s] and %s [%s] relations deteriorated to %s.", factionA, aStance, factionB, bStance, relStr)
end

function CosmicWarNews.onSeedNews()
    local server = Server()
    if not server then return end

    local conflicts = collectHotConflicts(server)
    for _, pick in pairs(conflicts) do
        local factionA = pick.a.name or ("Faction " .. tostring(pick.a.index))
        local factionB = pick.b.name or ("Faction " .. tostring(pick.b.index))
        local aStance = pick.a:getValue("cw_diplomatic_stance") or "Balanced"
        local bStance = pick.b:getValue("cw_diplomatic_stance") or "Balanced"

        local article = {
            title = "Active Conflict: " .. factionA,
            category = "War Update",
            content = string.format("Diplomatic relations between the %s [%s] and the %s [%s] have severely deteriorated. Intelligence suggests active military deployments across sector borders.", factionA, aStance, factionB, bStance)
        }

        local cvn = include("cosmicvaultnews")
        cvn.publishArticle(article)
    end
end

return CosmicWarNews
