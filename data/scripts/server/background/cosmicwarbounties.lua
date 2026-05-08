package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local CosmicWarConfig = include("cosmicwarconfig")

-- namespace CosmicWarBounties
CosmicWarBounties = {}

function CosmicWarBounties.getUpdateInterval()
    return 600 -- every 10 minutes
end

local function cwlog(msg, ...)
    local cfg = CosmicWarConfig.get()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Bounties] " .. msg, ...)
end

function CosmicWarBounties.update(timeStep)
    if not onServer() then return end

    local galaxy = Galaxy()
    local server = Server()
    if not galaxy or not server then return end

    local factions = {galaxy:getFactions()}
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 60))
    local cfg = CosmicWarConfig.get()
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
