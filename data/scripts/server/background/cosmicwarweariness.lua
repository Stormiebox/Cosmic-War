package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicWarBridge = include("cosmicwarbridge")
local CosmicVaultEconomy = include("cosmicvaulteconomy")
include("cosmicwarconfig")

-- namespace CosmicWarWeariness
CosmicWarWeariness = {}

-- v4.0.0 War Weariness: a real per-faction counter (0..100), distinct from the
-- existing War Exhaustion clock (cosmicwarceasefires.lua's day-based ceasefire bonus, which
-- keeps working unchanged). Weariness rises only for whichever side of a war is currently
-- behind on War Score, scaled by how far behind, and passively decays back toward 0 via
-- Cosmic Vault's shared registerPassiveDecay/tickPassiveDecay registry whenever a faction
-- isn't actively losing this tick -- at peace, or currently winning or even. A weary faction
-- visibly pays for losing: smaller aggressive patrols (cosmicwarcontroller.lua), worse
-- station stock (the existing War Profiteering Shortages hook), and a real extra nudge
-- toward accepting peace (cosmicwarceasefires.lua).
local WEARINESS_KEY_PREFIX = "cw_weariness_"
local WEARINESS_DECAY_PER_HOUR = 8
local WEARINESS_GAIN_PER_HOUR_AT_MAX_DEFICIT = 15

function CosmicWarWeariness.initialize()
    if not onServer() then return end
    -- Vault's decay registry is a plain in-VM table, not persisted through
    -- secure()/restore() -- it needs a fresh registration every time this script's own VM
    -- starts, exactly like every other registerPassiveDecay() consumer would.
    CosmicVaultEconomy.registerPassiveDecay(WEARINESS_KEY_PREFIX, WEARINESS_DECAY_PER_HOUR, 0)
end

function CosmicWarWeariness.getUpdateInterval()
    local cfg = CosmicWarConfig.get() or {}
    return cfg.ceasefireInterval or 600 -- same cadence as the ceasefire pass this feeds
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
    return factionIndices
end

function CosmicWarWeariness.update(timeStep)
    if not onServer() then return end
    local server = Server()
    if not server then return end

    local cfg = CosmicWarConfig.get() or {}
    local threshold = cfg.warScoreDecisiveVictoryThreshold or 250

    local factionIndices = getGalaxyFactionIndices(server)
    local processedPairs = {}
    local losingThisTick = {}

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

                        -- getWarScore(left, right) is positive when `left` (the
                        -- lower faction index) is ahead, negative when `right` is ahead --
                        -- confirmed against cosmicwarbridge.lua's own warScorePairKey/
                        -- recordWarScoreKill/recordWarScoreTerritory convention.
                        local score = CosmicWarBridge.getWarScore(left, right)
                        local magnitude = math.min(1.0, math.abs(score) / threshold)

                        -- Ignore near-even scores as noise -- a faction barely behind
                        -- isn't meaningfully "losing" yet.
                        if magnitude > 0.05 then
                            local losingIndex = (score > 0) and right or left
                            losingThisTick[losingIndex] = true

                            local key = WEARINESS_KEY_PREFIX .. tostring(losingIndex)
                            local current = server:getValue(key) or 0
                            local gain = WEARINESS_GAIN_PER_HOUR_AT_MAX_DEFICIT * magnitude * (timeStep / 3600)
                            server:setValue(key, math.min(100, current + gain))
                        end
                    end
                end
            end
        end
    end

    -- Every enabled AI faction not actively losing this tick decays back toward 0 --
    -- covers both "at peace" and "at war but winning or even."
    for _, idx in pairs(factionIndices) do
        if not losingThisTick[idx] then
            local f = Faction(idx)
            if f and f.isAIFaction and f:getValue("cw_enabled") then
                CosmicVaultEconomy.tickPassiveDecay(WEARINESS_KEY_PREFIX, idx, timeStep)
            end
        end
    end
end
