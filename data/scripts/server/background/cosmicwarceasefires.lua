package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("relations")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarCeasefires
CosmicWarCeasefires = {}

local function getCfg()
    return CosmicWarConfig.get() or { debugLogs = false, rivalryThreshold = -45000, ceasefireInterval = 600, ceasefireChance = 0.25 }
end

function CosmicWarCeasefires.getUpdateInterval()
    local cfg = getCfg()
    return cfg.ceasefireInterval or 600 -- every 10 minutes
end

local function cwlog(msg, ...)
    CosmicVaultDebug.info("CosmicWar-Ceasefire", msg, ...)
end

-- v4.0.0 Coalition Ceasefires: when the Eclipse (Cosmic Ascendancy) poses a serious
-- galaxy-wide threat, every currently-warring AI faction pair is pulled into a temporary
-- truce -- "everyone bands together against the greater threat" made a real, general
-- mechanic instead of the one-off, single-pair Sanitization Protocol
-- (cosmicwarcontroller.lua) it grew out of. Runs on its own cooldown, independent of the
-- per-pair détente roll above. Galaxy-wide reach, scoped to factions actually affected
-- (i.e. currently at war) -- a faction with no war has nothing to be pulled out of.
local COALITION_THREAT_THRESHOLD = 5000 -- eclipse_threat is on a 0-10000 scale
local COALITION_CHECK_COOLDOWN = 1800   -- don't re-scan more than once per 30 min
local COALITION_DAMPEN_DURATION = 3600  -- truce holds for 1 hour once applied to a pair

local function applyCoalitionCeasefires(server, factionIndices)
    if not server:getValue("eclipse_fully_awake") then return end
    if (server:getValue("eclipse_threat") or 0) < COALITION_THREAT_THRESHOLD then return end

    local lastCheck = server:getValue("cw_coalition_last_check") or 0
    if server.unpausedRuntime - lastCheck < COALITION_CHECK_COOLDOWN then return end
    server:setValue("cw_coalition_last_check", server.unpausedRuntime)

    local cvf = include("cosmicvaultfaction")
    local pulled = {}
    local processed = {}

    for _, idx in pairs(factionIndices) do
        local a = Faction(idx)
        if a and a.isAIFaction and a:getValue("cw_enabled") then
            local enemyIdx = a:getValue("enemy_faction")
            if enemyIdx and enemyIdx > 0 then
                local b = Faction(enemyIdx)
                if b and b.isAIFaction then
                    local left, right = math.min(a.index, b.index), math.max(a.index, b.index)
                    local key = tostring(left) .. "_" .. tostring(right)

                    if not processed[key] then
                        processed[key] = true
                        local rel = a:getRelations(b.index) or 0

                        -- Push relations comfortably clear of the rivalry threshold and
                        -- suppress new escalation for the dampening window
                        -- (cosmicwarcontroller.lua checks this same flag).
                        local rivalryThreshold = getCfg().rivalryThreshold or -45000
                        local target = rivalryThreshold + 5000
                        if rel < target then
                            cvf.changeRelations(a.index, b.index, target - rel)
                        end
                        server:setValue("cw_coalition_dampened_" .. key, server.unpausedRuntime + COALITION_DAMPEN_DURATION)
                        table.insert(pulled, a.name .. " / " .. b.name)
                    end
                end
            end
        end
    end

    if #pulled > 0 then
        local cv_news = include("cosmicvaultnews")
        if cv_news and cv_news.publishArticle then
            cv_news.publishArticle({
                title = "Coalition Ceasefire Declared",
                content = "With the Eclipse's advance threatening the entire galaxy, warring factions across known space have agreed to stand down, at least for now: " .. table.concat(pulled, "; ") .. ". Old grudges will have to wait.",
                category = "Politics"
            })
        end
        cwlog("Coalition Ceasefire pulled %i war pairs into a temporary truce.", #pulled)
    end
end

local function getGalaxyFactionIndices(server)
    if not server or type(server.getValue) ~= "function" then return {} end

    local factionIndices = {}
    local factionStr = server:getValue("factions")

    if type(factionStr) == "string" and factionStr ~= "" then
        for id in string.gmatch(factionStr, "([^,]+)") do
            table.insert(factionIndices, tonumber(id))
        end
    end

    local FactionEradicationUtility = include("factioneradicationutility")
    local validIndices = {}

    for _, index in pairs(factionIndices) do
        if not FactionEradicationUtility.isFactionEradicated(index) then
            table.insert(validIndices, index)
        end
    end

    return validIndices
end

function CosmicWarCeasefires.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factionIndices = getGalaxyFactionIndices(server)
    if #factionIndices < 2 then return end

    local random = Random(server.seed + math.floor(server.unpausedRuntime / 180))
    local cfg = getCfg()
    local rivalryThreshold = cfg.rivalryThreshold or -45000

    applyCoalitionCeasefires(server, factionIndices)

    local eased = 0
    local processedPairs = {}

    for _, idx in pairs(factionIndices) do
        local a = Faction(idx)
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

                        -- v4.0.0 Decisive Victory: a sufficiently lopsided War Score ends
                        -- the war outright, regardless of the normal détente roll below --
                        -- a clearly-beaten side doesn't fight on just because the dice
                        -- didn't favor peace this cycle.
                        local CosmicWarBridge = include("cosmicwarbridge")
                        local score = CosmicWarBridge.getWarScore(a.index, b.index)

                        if math.abs(score) >= 250 then
                            local winner, loser = a, b
                            if score < 0 then winner, loser = b, a end

                            local cvf = include("cosmicvaultfaction")
                            cvf.changeRelations(winner.index, loser.index, 45000 - rel)

                            winner:setValue("enemy_faction", 0)
                            winner:setValue("cw_target_faction", 0)
                            winner:setValue("cw_war_bias", 0)
                            loser:setValue("enemy_faction", 0)
                            loser:setValue("cw_target_faction", 0)
                            loser:setValue("cw_war_bias", 0)

                            local cv_economy = include("cosmicvaulteconomy")
                            cv_economy.addFamineScore(loser.index, 15)

                            CosmicWarBridge.resetWarScore(a.index, b.index)

                            local cv_news = include("cosmicvaultnews")
                            if cv_news and cv_news.publishArticle then
                                cv_news.publishArticle({
                                    title = "Decisive Victory: " .. tostring(winner.name) .. " Prevails Over " .. tostring(loser.name),
                                    content = "After a long and costly conflict, " .. tostring(winner.name) .. " has decisively broken " .. tostring(loser.name) .. "'s ability to continue the war. A peace has been forced, though " .. tostring(loser.name) .. " will feel the economic cost for some time.",
                                    category = "Politics"
                                })
                            end

                            eased = eased + 1

                        else
                            -- v4.0.0 War Exhaustion: the longer a war drags on, the readier
                            -- both sides are for peace -- +3% ceasefire chance per full day
                            -- at war, capped at +30%.
                            local exhaustionBonus = 0
                            local srv = Server()
                            if srv then
                                local startedAt = srv:getValue("cw_war_started_" .. tostring(left) .. "_" .. tostring(right))
                                if startedAt then
                                    local daysAtWar = (srv.unpausedRuntime - startedAt) / 86400
                                    exhaustionBonus = math.min(0.30, math.max(0, daysAtWar) * 0.03)
                                end
                            end

                            -- If relationship has recovered above rivalry threshold, allow détente chance.
                            local ceasefireChance = (cfg.ceasefireChance or 0.25) + exhaustionBonus
                            if rel > rivalryThreshold and random:test(ceasefireChance) then
                                local gain = random:getInt(2000, 6000)
                                local cvf = include("cosmicvaultfaction")
                                cvf.changeRelations(a.index, b.index, gain)

                                a:setValue("enemy_faction", 0)
                                a:setValue("cw_target_faction", 0)

                                if (b:getValue("enemy_faction") or 0) == a.index then
                                    b:setValue("enemy_faction", 0)
                                end
                                if (b:getValue("cw_target_faction") or 0) == a.index then
                                    b:setValue("cw_target_faction", 0)
                                end

                                local cv_news = include("cosmicvaultnews")
                                if cv_news and cv_news.publishArticle then
                                    cv_news.publishArticle({
                                        title = "Ceasefire Reached Between " .. tostring(a.name) .. " and " .. tostring(b.name),
                                        content = "After a prolonged period of hostility, diplomatic channels between " .. tostring(a.name) .. " and " .. tostring(b.name) .. " have thawed enough for both sides to formally stand down. Border patrols report a marked decrease in skirmishes, though analysts caution the peace remains fragile.",
                                        category = "Politics"
                                    })
                                end

                                eased = eased + 1
                            end
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




