package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarDiplomaticSanctions
CosmicWarDiplomaticSanctions = {}

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end
    return {
        ["debugLogs"] = false,
        ["rivalryThreshold"] = -45000
    }
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

function CosmicWarDiplomaticSanctions.getUpdateInterval()
    local cfg = getCfg()
    return cfg.sanctionsInterval or 600 -- every 10 minutes
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Sanctions", msg, ...)
        return
    end

    local cfg = getCfg()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Sanctions] " .. string.format(msg, ...))
end

function CosmicWarDiplomaticSanctions.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factions = getGalaxyFactions(server)
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 120))
    local cfg = getCfg()
    local threshold = cfg.rivalryThreshold or -45000

    local cv_task_success, cv_task = pcall(include, "cosmicvaulttask")
    if cv_task_success and cv_task and cv_task.RunAsync then
        cv_task.RunAsync("CosmicWarSanctions", function()
            local penalized = 0
            local iters = 0

            for _, a in pairs(factions) do
                iters = iters + 1
                if iters % 10 == 0 and cv_task.Yield then
                    cv_task.Yield()
                end

                if a and a.isAIFaction and a:getValue("cw_enabled") then
                    local enemy = a:getValue("enemy_faction")
                    if enemy and enemy > 0 then
                        local b = Faction(enemy)
                        if b and b.isAIFaction then
                            local rel = a:getRelations(b.index) or 0
                            if rel <= threshold then
                                local relationDepth = math.min(1.0, math.max(0.0, (threshold - rel) / 50000))
                                local warBias = (a:getValue("cw_war_bias") or 550) / 1000
                                warBias = math.min(1.0, math.max(0.0, warBias))

                                local baseChance = cfg.sanctionBaseChance or 0.35
                                local chance = baseChance + relationDepth * 0.25 + warBias * 0.20
                                chance = math.min(0.95, math.max(0.05, chance))

                                if random:test(chance) then
                                    local minLoss = 2500 + math.floor(relationDepth * 2000)
                                    local maxLoss = 12000 + math.floor(warBias * 6000)
                                    local loss = random:getInt(minLoss, maxLoss)

                                    a:pay("Diplomatic Sanctions"%_T, loss)
                                    penalized = penalized + 1
                                end
                            end
                        end
                    end
                end
            end

            if penalized > 0 then
                cwlog("Applied wartime diplomatic sanctions to %i factions.", penalized)
            end
        end)
    else
        local penalized = 0

        for _, a in pairs(factions) do
            if a and a.isAIFaction and a:getValue("cw_enabled") then
                local enemy = a:getValue("enemy_faction")
                if enemy and enemy > 0 then
                    local b = Faction(enemy)
                    if b and b.isAIFaction then
                        local rel = a:getRelations(b.index) or 0
                        if rel <= threshold then
                            local relationDepth = math.min(1.0, math.max(0.0, (threshold - rel) / 50000))
                            local warBias = (a:getValue("cw_war_bias") or 550) / 1000
                            warBias = math.min(1.0, math.max(0.0, warBias))

                            local baseChance = cfg.sanctionBaseChance or 0.35
                            local chance = baseChance + relationDepth * 0.25 + warBias * 0.20
                            chance = math.min(0.95, math.max(0.05, chance))

                            if random:test(chance) then
                                local minLoss = 2500 + math.floor(relationDepth * 2000)
                                local maxLoss = 12000 + math.floor(warBias * 6000)
                                local loss = random:getInt(minLoss, maxLoss)

                                a:pay("Diplomatic Sanctions"%_T, loss)
                                penalized = penalized + 1
                            end
                        end
                    end
                end
            end
        end

        if penalized > 0 then
            cwlog("Applied wartime diplomatic sanctions to %i factions.", penalized)
        end
    end
end
