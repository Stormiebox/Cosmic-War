package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarNews
CosmicWarNews = {}

function CosmicWarNews.initialize()
end

function CosmicWarNews.getUpdateInterval()
    local cfg = getCfg()
    return cfg.newsInterval or 420 -- every 7 minutes
end

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end
    return { ["debugLogs"] = false }
end

local function getGalaxyFactions(galaxy)
    if not galaxy then return {} end
    if galaxy.getFactions then
        return { galaxy:getFactions() }
    end
    if galaxy.getPirateFactions then
        return { galaxy:getPirateFactions() }
    end
    return {}
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

local function collectHotConflicts()
    local galaxy = Galaxy()
    if not galaxy then return {} end

    local factions = getGalaxyFactions(galaxy)
    local hot = {}

    for _, a in pairs(factions) do
        if a and a.isAIFaction and a:getValue("cw_enabled") then
            local enemy = a:getValue("enemy_faction")
            if enemy and enemy > 0 then
                local b = Faction(enemy)
                if b and b.isAIFaction then
                    local rel = a:getRelations(b.index) or 0
                    if rel <= -35000 then
                        table.insert(hot, { a = a, b = b, rel = rel })
                    end
                end
            end
        end
    end

    return hot
end

function CosmicWarNews.update(timeStep)
    if not onServer() then return end

    local conflicts = collectHotConflicts()
    if #conflicts == 0 then return end

    local random = Random(Server().seed + math.floor(Server().unpausedRuntime / 60) * 17)
    local pick = conflicts[random:getInt(1, #conflicts)]
    if not pick then return end

    local templates =
    {
        "War Bulletin: %s and %s relations deteriorated to %d." % _t,
        "Conflict Watch: %s and %s are entering open hostility (%d)." % _t,
        "Strategic Alert: tensions between %s and %s reached %d." % _t,
    }

    local template = templates[random:getInt(1, #templates)] or templates[1]
    local msg = string.format(template,
        pick.a.name or ("Faction " .. tostring(pick.a.index)),
        pick.b.name or ("Faction " .. tostring(pick.b.index)),
        pick.rel
    )

    -- Server-wide chat style bulletin
    Server():broadcastChatMessage("Cosmic War", ChatMessageType.Information, msg)
    cwlog("%s", msg)
end
