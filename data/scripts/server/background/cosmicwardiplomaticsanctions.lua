package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local CosmicWarConfig = include("cosmicwarconfig")

-- namespace CosmicWarDiplomaticSanctions
CosmicWarDiplomaticSanctions = {}

function CosmicWarDiplomaticSanctions.getUpdateInterval()
    return 600 -- every 10 minutes
end

local function cwlog(msg, ...)
    local cfg = CosmicWarConfig.get()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Sanctions] " .. msg, ...)
end

function CosmicWarDiplomaticSanctions.update(timeStep)
    if not onServer() then return end

    local galaxy = Galaxy()
    local server = Server()
    if not galaxy or not server then return end

    local factions = {galaxy:getFactions()}
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 120))
    local cfg = CosmicWarConfig.get()
    local threshold = cfg.rivalryThreshold or -45000

    local penalized = 0

    for _, a in pairs(factions) do
        if a and a.isAIFaction and a:getValue("cw_enabled") then
            local enemy = a:getValue("enemy_faction")
            if enemy and enemy > 0 then
                local b = Faction(enemy)
                if b and b.isAIFaction then
                    local rel = a:getRelations(b.index) or 0
                    if rel <= threshold and random:test(0.35) then
                        local loss = random:getInt(2500, 12000)
                        a:receive(-loss)
                        penalized = penalized + 1
                    end
                end
            end
        end
    end

    if penalized > 0 then
        cwlog("Applied wartime diplomatic sanctions to %i factions.", penalized)
    end
end
