package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarBounties
CosmicWarBounties = {}

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end
    return { debugLogs = false, rivalryThreshold = -45000, bountyInterval = 600 }
end

function CosmicWarBounties.getUpdateInterval()
    local cfg = getCfg()
    return cfg.bountyInterval or 600 -- every 10 minutes
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Bounties", msg, ...)
        return
    end

    local cfg = getCfg()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Bounties] " .. string.format(msg, ...))
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

function CosmicWarBounties.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factions = getGalaxyFactions(server)
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 60))
    local cfg = getCfg()
    local rivalryThreshold = cfg.rivalryThreshold or -45000

    local spawned = 0

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local enemyIndex = f:getValue("enemy_faction")
            if enemyIndex and enemyIndex > 0 then
                local e = Faction(enemyIndex)
                if e and e.isAIFaction then
                    local rel = f:getRelations(e.index) or 0
                    if rel <= rivalryThreshold and random:test(0.30) then
                        local bounty = random:getInt(15000, 65000)
                        f:setValue("cw_bounty_enemy", e.index)
                        f:setValue("cw_bounty_reward", bounty)
                        f:setValue("cw_bounty_expires", server.unpausedRuntime + random:getInt(1800, 5400))
                        spawned = spawned + 1
                    end
                end
            end
        end
    end

    if spawned > 0 then
        cwlog("Refreshed %i active war bounties.", spawned)
    end
end
