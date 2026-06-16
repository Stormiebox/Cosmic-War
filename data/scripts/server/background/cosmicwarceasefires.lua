package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("relations")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarCeasefires
CosmicWarCeasefires = {}

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end
    return { debugLogs = false, rivalryThreshold = -45000, ceasefireInterval = 900, ceasefireChance = 0.25 }
end

function CosmicWarCeasefires.getUpdateInterval()
    local cfg = getCfg()
    return cfg.ceasefireInterval or 900 -- every 15 minutes
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Ceasefire", msg, ...)
        return
    end

    local cfg = getCfg()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Ceasefire] " .. string.format(msg, ...))
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

function CosmicWarCeasefires.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factions = getGalaxyFactions(server)
    if #factions < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 180))
    local cfg = getCfg()
    local rivalryThreshold = cfg.rivalryThreshold or -45000

    local cv_task_success, cv_task = true, include("cosmicvaulttask")
    if cv_task_success and cv_task and cv_task.RunAsync then
        cv_task.RunAsync("CosmicWarCeasefires", function()
            local eased = 0
            local processedPairs = {}
            local iters = 0

            for _, a in pairs(factions) do
                iters = iters + 1
                if iters % 10 == 0 and cv_task.Yield then
                    cv_task.Yield()
                end

                if a and a.isAIFaction and a:getValue("cw_enabled") then
                    local enemyIndex = a:getValue("enemy_faction")
                    if enemyIndex and enemyIndex > 0 then
                        local b = Faction(enemyIndex)
                        if b and b.isAIFaction then
                            local left = math.min(a.index, b.index)
                            local right = math.max(a.index, b.index)
                            local pairKey = tostring(left) .. ":" .. tostring(right)

                            if not processedPairs[pairKey] then
                                processedPairs[pairKey] = true

                                local rel = a:getRelations(b.index) or 0

                                -- If relationship has recovered above rivalry threshold, allow détente chance.
                                local ceasefireChance = cfg.ceasefireChance or 0.25
                                if rel > rivalryThreshold and random:test(ceasefireChance) then
                                    local gain = random:getInt(2000, 6000)
                                    local cvf_success, cvf = true, include("cosmicvaultfaction")
                                    if cvf_success and cvf and cvf.changeRelations then
                                        cvf.changeRelations(a.index, b.index, gain)
                                    else
                                        local newRel = math.max(-100000, math.min(100000, rel + gain))
                                        Galaxy():setFactionRelations(a, b, newRel)
                                    end

                                    a:setValue("enemy_faction", 0)
                                    a:setValue("cw_target_faction", 0)

                                    if (b:getValue("enemy_faction") or 0) == a.index then
                                        b:setValue("enemy_faction", 0)
                                    end
                                    if (b:getValue("cw_target_faction") or 0) == a.index then
                                        b:setValue("cw_target_faction", 0)
                                    end

                                    eased = eased + 1
                                end
                            end
                        end
                    end
                end
            end

            if eased > 0 then
                cwlog("Resolved %i active rivalries through ceasefire drift.", eased)
            end
        end)
    else
        local eased = 0
        local processedPairs = {}

        for _, a in pairs(factions) do
            if a and a.isAIFaction and a:getValue("cw_enabled") then
                local enemyIndex = a:getValue("enemy_faction")
                if enemyIndex and enemyIndex > 0 then
                    local b = Faction(enemyIndex)
                    if b and b.isAIFaction then
                        local left = math.min(a.index, b.index)
                        local right = math.max(a.index, b.index)
                        local pairKey = tostring(left) .. ":" .. tostring(right)

                        if not processedPairs[pairKey] then
                            processedPairs[pairKey] = true

                            local rel = a:getRelations(b.index) or 0

                            -- If relationship has recovered above rivalry threshold, allow détente chance.
                            local ceasefireChance = cfg.ceasefireChance or 0.25
                            if rel > rivalryThreshold and random:test(ceasefireChance) then
                                local gain = random:getInt(2000, 6000)
                                local cvf_success, cvf = true, include("cosmicvaultfaction")
                                if cvf_success and cvf and cvf.changeRelations then
                                    cvf.changeRelations(a.index, b.index, gain)
                                else
                                    local newRel = math.max(-100000, math.min(100000, rel + gain))
                                    Galaxy():setFactionRelations(a, b, newRel)
                                end

                                a:setValue("enemy_faction", 0)
                                a:setValue("cw_target_faction", 0)

                                if (b:getValue("enemy_faction") or 0) == a.index then
                                    b:setValue("enemy_faction", 0)
                                end
                                if (b:getValue("cw_target_faction") or 0) == a.index then
                                    b:setValue("cw_target_faction", 0)
                                end

                                eased = eased + 1
                            end
                        end
                    end
                end
            end
        end

        if eased > 0 then
            cwlog("Resolved %i active rivalries through ceasefire drift.", eased)
        end
    end
end


function getUpdateInterval(...)
    if CosmicWarCeasefires.getUpdateInterval then return CosmicWarCeasefires.getUpdateInterval(...) end
end
function update(...)
    if CosmicWarCeasefires.update then return CosmicWarCeasefires.update(...) end
end
