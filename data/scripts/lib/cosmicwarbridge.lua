package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarconfig")
include("randomext")


CosmicWarBridge = CosmicWarBridge or {}

--- Pure lookup: walks outward from `faction`'s home sector along a random heading and
-- returns the first unclaimed sector along that ray, or nil if the ray immediately runs
-- into someone else's territory or the faction has no home. Never claims anything itself.
-- Lives here (a lib/ file every context can safely include()) rather than in
-- cosmicwarexpansion.lua itself (a server/background/ lifecycle script with no proven
-- include-from-elsewhere path in this codebase) so both the real expansion tick and the
-- Intelligence Network's "preview a rival's likely next move" query (/cosmicwarintel)
-- can reach it.
-- @param faction (Faction) the Imperialist-style expanding faction
-- @param maxSteps (number|nil) walk length in sectors, defaults to 15
-- @param seed (number|nil) explicit Random seed; when supplied, the walk is deterministic
--        (used by the intel preview so every player asking about the same faction in the
--        same time window sees the same answer, rather than a fresh heading per query)
-- @return tx, ty (number, number) or nil if no candidate was found
function CosmicWarBridge.findExpansionCandidate(faction, maxSteps, seed)
    if not faction then return nil end
    local hx, hy = faction:getHomeSectorCoordinates()
    if not hx or not hy then return nil end

    local rnd = seed and Random(seed) or random()
    local angle = rnd:getFloat() * math.pi * 2
    local dx = math.cos(angle)
    local dy = math.sin(angle)
    local cx, cy = hx, hy

    for step = 1, (maxSteps or 15) do
        cx = cx + dx
        cy = cy + dy
        local tx, ty = math.floor(cx + 0.5), math.floor(cy + 0.5)

        local controllingFaction = Galaxy():getControllingFaction(tx, ty)
        if not controllingFaction then
            return tx, ty
        elseif controllingFaction.index ~= faction.index then
            -- Ran into someone else's territory -- stop here rather than hopping over
            -- it to claim something further out.
            return nil
        end
        -- controllingFaction.index == faction.index: already-owned sector, keep walking.
    end

    return nil
end

local function safeRelations(a, bIndex)
    if not a or not bIndex then return 0 end
    return a:getRelations(bIndex) or 0
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

function CosmicWarBridge.computeWarHeatForFaction(faction)
    if not faction or not faction.isAIFaction then return 0 end

    local cfg = CosmicWarConfig.get() or {}
    local threshold = cfg.rivalryThreshold or -45000

    local enemy = faction:getValue("enemy_faction") or 0
    if enemy <= 0 then return 0 end

    local enemyFaction = Faction(enemy)
    if not enemyFaction then return 0 end

    local rel = safeRelations(faction, enemyFaction.index)
    local depth = math.max(0, threshold - rel)
    local relHeat = math.min(1.0, depth / 50000)

    local bias = (faction:getValue("cw_war_bias") or 550) / 1000
    bias = math.min(1.0, math.max(0.0, bias))

    local pairBonus = 0
    if (enemyFaction:getValue("enemy_faction") or 0) == faction.index then
        pairBonus = 0.2
    end

    local server = Server()
    local famineA = server and (server:getValue("cv_famine_" .. tostring(faction.index)) or 0) or 0
    local famineB = server and (server:getValue("cv_famine_" .. tostring(enemyFaction.index)) or 0) or 0
    local maxFamine = math.max(famineA, famineB)
    local famineHeat = math.min(0.4, maxFamine / 250)
    
    local heat = relHeat * 0.6 + bias * 0.2 + pairBonus + famineHeat
    return math.min(1.0, math.max(0.0, heat))
end

function CosmicWarBridge.publishWarHeatSnapshot()
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factions = getGalaxyFactions(server)
    local snapshot = {}
    local maxHeat = 0
    local snapshotParts = {}

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local heat = CosmicWarBridge.computeWarHeatForFaction(f)
            snapshot[f.index] = heat
            table.insert(snapshotParts, tostring(f.index) .. ":" .. tostring(heat))
            if heat > maxHeat then maxHeat = heat end
        end
    end

    -- global snapshot for bridge consumers (Cosmic Overhaul hooks / scripts)
    local snapshotStr = table.concat(snapshotParts, ",")
    server:setValue("cw_war_heat_snapshot", snapshotStr)
    server:setValue("cw_war_heat_max", maxHeat)
end

function CosmicWarBridge.getWarHeatSnapshot()
    if not onServer() then return {}, 0 end
    local server = Server()
    if not server then return {}, 0 end

    local snapshotStr = server:getValue("cw_war_heat_snapshot")
    local snapshot = {}

    if type(snapshotStr) == "string" and snapshotStr ~= "" then
        for pair in string.gmatch(snapshotStr, "([^,]+)") do
            local idxStr, heatStr = string.match(pair, "(%d+):([%d%.]+)")
            if idxStr and heatStr then
                snapshot[tonumber(idxStr)] = tonumber(heatStr)
            end
        end
    end

    return snapshot, server:getValue("cw_war_heat_max") or 0
end

function CosmicWarBridge.getFactionWarHeat(factionIndex)
    local snapshot, _ = CosmicWarBridge.getWarHeatSnapshot()
    return snapshot[factionIndex] or 0
end

function CosmicWarBridge.computeCaptainRiskModifier(captain, factionIndex)
    local heat = CosmicWarBridge.getFactionWarHeat(factionIndex)
    local riskMult = 1.0 + heat * 0.5
    local rewardMult = 1.0 + heat * 0.35

    -- Keep bounds conservative
    riskMult = math.min(1.5, math.max(1.0, riskMult))
    rewardMult = math.min(1.35, math.max(1.0, rewardMult))

    return riskMult, rewardMult
end

function CosmicWarBridge.forceDeclareWar(attackerFaction, defenderFaction)
    if not attackerFaction or not defenderFaction then return end
    
    attackerFaction:setValue("enemy_faction", defenderFaction.index)
    defenderFaction:setValue("enemy_faction", attackerFaction.index)
    
    attackerFaction:setValue("cw_war_bias", 1000)
    defenderFaction:setValue("cw_war_bias", 1000)
    
    local CosmicVaultFaction = include("cosmicvaultfaction")
    if CosmicVaultFaction and CosmicVaultFaction.changeRelations then
        CosmicVaultFaction.changeRelations(attackerFaction.index, defenderFaction.index, -200000)
    else
        Galaxy():setFactionRelations(attackerFaction, defenderFaction, -100000)
    end
end

-- v4.0.0 Intelligence Network: recon/sabotage War Contracts (Force Recon, Sensor
-- Deployment, Black Box Retrieval) bank Intel Points against their target faction on
-- completion. /cosmicwarintel spends them to preview that faction's likely next
-- expansion move (see findExpansionCandidate() above). Stored per-player,
-- per-target-faction as a plain custom value -- the same pattern used for every other
-- per-player War state in this mod (cw_mercenary_faction, cw_bounty_enemy, etc.).
function CosmicWarBridge.grantIntel(player, factionIndex, amount)
    if not player or not factionIndex or factionIndex <= 0 or not amount or amount <= 0 then return end
    local key = "cw_intel_" .. tostring(factionIndex)
    local current = player:getValue(key) or 0
    player:setValue(key, current + amount)
end

function CosmicWarBridge.getIntel(player, factionIndex)
    if not player or not factionIndex or factionIndex <= 0 then return 0 end
    return player:getValue("cw_intel_" .. tostring(factionIndex)) or 0
end

--- Returns true and deducts `amount` if the player had enough; returns false and
-- changes nothing otherwise.
function CosmicWarBridge.spendIntel(player, factionIndex, amount)
    if not player or not factionIndex or factionIndex <= 0 or not amount then return false end
    local key = "cw_intel_" .. tostring(factionIndex)
    local current = player:getValue(key) or 0
    if current < amount then return false end
    player:setValue(key, current - amount)
    return true
end

-- v4.0.0 War Score & Attrition: a legible, per-conflict scoreboard replacing "who's
-- winning this war" as a mental calculation from the raw relations number. Stored as two
-- signed counters per faction pair (kills, territory), always keyed from the
-- lower-indexed faction's perspective so there's exactly one canonical entry per pair
-- regardless of call order.
local function warScorePairKey(a, b)
    local lo, hi = math.min(a, b), math.max(a, b)
    return tostring(lo) .. "_" .. tostring(hi)
end

--- Call whenever a valid military kill happens between two factions actually at war
-- with each other. Credits the score to whichever side did NOT lose the unit,
-- regardless of who actually landed the killing blow (a player mercenary killing an
-- enemy ship is exactly as much "attrition against that faction" as an AI-vs-AI kill).
function CosmicWarBridge.recordWarScoreKill(victimFactionIndex)
    if not onServer() then return end
    local victim = Faction(victimFactionIndex)
    if not victim or not victim.isAIFaction then return end
    local enemyIdx = victim:getValue("enemy_faction") or 0
    if enemyIdx <= 0 then return end

    local server = Server()
    if not server then return end

    local lo = math.min(victimFactionIndex, enemyIdx)
    local delta = (enemyIdx == lo) and 1 or -1
    local key = "cw_ws_kills_" .. warScorePairKey(victimFactionIndex, enemyIdx)
    server:setValue(key, (server:getValue(key) or 0) + delta)
end

--- Call whenever a station changes hands between two AI factions via conquest (siege or
-- background flip). Territory swings are weighted far higher than a single kill when
-- getWarScore() combines them.
function CosmicWarBridge.recordWarScoreTerritory(loserFactionIndex, winnerFactionIndex)
    if not onServer() then return end
    if not loserFactionIndex or not winnerFactionIndex or loserFactionIndex == winnerFactionIndex then return end

    local server = Server()
    if not server then return end

    local lo = math.min(loserFactionIndex, winnerFactionIndex)
    local delta = (winnerFactionIndex == lo) and 1 or -1
    local key = "cw_ws_territory_" .. warScorePairKey(loserFactionIndex, winnerFactionIndex)
    server:setValue(key, (server:getValue(key) or 0) + delta)
end

--- Returns the combined War Score from factionA's perspective: positive means A is
-- winning. 1 point per net kill, 25 per net station capture -- a single territory swing
-- outweighs a long kill streak, matching how much more a captured station actually
-- changes the shape of a war than one more destroyed ship.
function CosmicWarBridge.getWarScore(factionA, factionB)
    local server = Server()
    if not server or not factionA or not factionB then return 0 end

    local key = warScorePairKey(factionA, factionB)
    local kills = server:getValue("cw_ws_kills_" .. key) or 0
    local territory = server:getValue("cw_ws_territory_" .. key) or 0
    local netForLo = kills + (territory * 25)

    local lo = math.min(factionA, factionB)
    if factionA == lo then return netForLo end
    return -netForLo
end

--- Clears both counters for a pair -- called once a war is decisively resolved so a
-- future war between the same two factions starts its scoreboard fresh.
function CosmicWarBridge.resetWarScore(factionA, factionB)
    local server = Server()
    if not server or not factionA or not factionB then return end
    local key = warScorePairKey(factionA, factionB)
    server:setValue("cw_ws_kills_" .. key, nil)
    server:setValue("cw_ws_territory_" .. key, nil)
end

return CosmicWarBridge

