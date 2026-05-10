package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local CosmicWarConfig = include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarBounties
CosmicWarBounties = {}

function CosmicWarBounties.getUpdateInterval()
    local cfg = CosmicWarConfig.get()
    return cfg.bountyInterval or 600 -- every 10 minutes
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Bounties", msg, ...)
        return
    end

    local cfg = CosmicWarConfig.get()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Bounties] " .. msg, ...)
end

function CosmicWarBounties.update(timeStep)
    if not onServer() then return end

    local galaxy = Galaxy()
    local server = Server()
    if not galaxy or not server then return end

    if type(galaxy.getFactions) ~= "function" then return end
    local factions = { galaxy:getFactions() }
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 60))
    local cfg = CosmicWarConfig.get()
    local rivalryThreshold = cfg.rivalryThreshold or -45000

    local spawned = 0
    local processedPairs = {}

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local enemyIndex = f:getValue("enemy_faction")
            if enemyIndex and enemyIndex > 0 then
                local e = Faction(enemyIndex)
                if e and e.isAIFaction then
                    local left = math.min(f.index, e.index)
                    local right = math.max(f.index, e.index)
                    local pairKey = tostring(left) .. ":" .. tostring(right)

                    if not processedPairs[pairKey] then
                        processedPairs[pairKey] = true

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
    end

    if spawned > 0 then
        cwlog("Refreshed %i active war bounties.", spawned)
    end
end
