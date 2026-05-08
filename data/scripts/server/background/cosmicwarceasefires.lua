package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local CosmicWarConfig = include("cosmicwarconfig")

-- namespace CosmicWarCeasefires
CosmicWarCeasefires = {}

function CosmicWarCeasefires.getUpdateInterval()
    return 900 -- every 15 minutes
end

local function cwlog(msg, ...)
    local cfg = CosmicWarConfig.get()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Ceasefire] " .. msg, ...)
end

function CosmicWarCeasefires.update(timeStep)
    if not onServer() then return end

    local galaxy = Galaxy()
    local server = Server()
    if not galaxy or not server then return end

    local factions = {galaxy:getFactions()}
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 180))
    local cfg = CosmicWarConfig.get()
    local rivalryThreshold = cfg.rivalryThreshold or -45000

    local eased = 0

    for _, a in pairs(factions) do
        if a and a.isAIFaction and a:getValue("cw_enabled") then
            local enemyIndex = a:getValue("enemy_faction")
            if enemyIndex and enemyIndex > 0 then
                local b = Faction(enemyIndex)
                if b and b.isAIFaction then
                    local rel = a:getRelations(b.index) or 0

                    -- If relationship has recovered above rivalry threshold, allow détente chance.
                    if rel > rivalryThreshold and random:test(0.25) then
                        local gain = random:getInt(2000, 6000)
                        a:changeRelations(b, gain, RelationChangeType.Diplomatic)
                        b:changeRelations(a, gain, RelationChangeType.Diplomatic)

                        a:setValue("enemy_faction", 0)
                        if (b:getValue("enemy_faction") or 0) == a.index then
                            b:setValue("enemy_faction", 0)
                        end

                        eased = eased + 1
                    end
                end
            end
        end
    end

    if eased > 0 then
        cwlog("Resolved %i active rivalries through ceasefire drift.", eased)
    end
end
