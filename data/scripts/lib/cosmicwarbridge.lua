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
    local totalHeat = 0
    local snapshotParts = {}

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local heat = CosmicWarBridge.computeWarHeatForFaction(f)
            snapshot[f.index] = heat
            -- v4.0.0 fix: tostring() on a very small float (e.g. a near-zero heat just
            -- past the rivalry threshold) renders as scientific notation ("1.2e-005"),
            -- and getWarHeatSnapshot()'s parse pattern below stops at the "e" -- so a
            -- near-zero heat could misread as >= 1.0 and unlock this mod's hardest
            -- tier. %.6f never enters scientific notation regardless of magnitude.
            table.insert(snapshotParts, tostring(f.index) .. ":" .. string.format("%.6f", heat))
            if heat > maxHeat then maxHeat = heat end
            totalHeat = totalHeat + heat
        end
    end

    -- global snapshot for bridge consumers (Cosmic Overhaul hooks / scripts)
    local snapshotStr = table.concat(snapshotParts, ",")
    server:setValue("cw_war_heat_snapshot", snapshotStr)
    server:setValue("cw_war_heat_max", maxHeat)

    -- v4.0.0: sum of every AI faction's current War Heat, published as a
    -- plain Server value so any Cosmic mod can read "how much overall warfare is
    -- happening right now" (Cosmic Vault's getGalacticHostilityIndex() soft-reads this
    -- same key) without taking a hard dependency on Cosmic War.
    server:setValue("cw_galactic_hostility_index", totalHeat)
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
-- v4.0.0 extended pass, Alliance War Councils: now thin wrappers around Cosmic Vault's
-- generic grantLedger/getLedger/spendLedger primitive (cosmicvaultfaction.lua). If the
-- player belongs to a Player Alliance, Intel is banked to (and spent from) the Alliance's
-- own shared pool instead of that one player individually -- co-belligerent Alliance
-- members now scout as one intelligence apparatus instead of N trackers that never talk to
-- each other, directly serving the suite's standing Alliance-compatibility requirement.
local function resolveIntelActor(player)
    if player and player.allianceIndex and player.allianceIndex > 0 then
        local alliance = Alliance(player.allianceIndex)
        if alliance then return alliance end
    end
    return player
end

function CosmicWarBridge.grantIntel(player, factionIndex, amount)
    local CosmicVaultFaction = include("cosmicvaultfaction")
    CosmicVaultFaction.grantLedger(resolveIntelActor(player), factionIndex, "intel", amount)
end

function CosmicWarBridge.getIntel(player, factionIndex)
    local CosmicVaultFaction = include("cosmicvaultfaction")
    return CosmicVaultFaction.getLedger(resolveIntelActor(player), factionIndex, "intel")
end

--- Returns true and deducts `amount` if the player (or their Alliance) had enough;
-- returns false and changes nothing otherwise.
function CosmicWarBridge.spendIntel(player, factionIndex, amount)
    local CosmicVaultFaction = include("cosmicvaultfaction")
    return CosmicVaultFaction.spendLedger(resolveIntelActor(player), factionIndex, "intel", amount)
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

    -- v4.0.0: kills are credited for ANY valid military kill between the two
    -- factions galaxy-wide, including ambient AI-vs-AI combat from this mod's own
    -- background events -- not just player action -- so kill volume alone could reach the
    -- Decisive Victory threshold far faster than 10 net territory swings, the opposite of
    -- "a territory swing should outweigh a long kill streak" above. Capping kills'
    -- contribution keeps them meaningful (they still move the visible score right up to
    -- the cap) without letting them alone cross the 250-point Decisive Victory threshold --
    -- a real territory swing is now always required to get there.
    local cappedKills = math.max(-100, math.min(100, kills))
    local netForLo = cappedKills + (territory * 25)

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

-- v4.0.0: Warbonds' famine-outcome-scaled payout can be gamed by buying a
-- bond then personally running the faction's own Humanitarian Contracts to manufacture a
-- "the war went well" famine reading, independent of how the war actually went. Every
-- humanitarian famine-relief action (Relief Convoy, Diplomatic Aid Package, Medical
-- Airlift) records itself here as a running, never-reset total; Warbonds snapshots this at
-- purchase and subtracts the delta at maturity, so relief actions still do their real job
-- of lowering the faction's live Famine Score everywhere else, but can no longer be read as
-- a war outcome for bond-payout purposes specifically.
-- v4.0.0: now a thin wrapper around Cosmic Vault's generalized
-- recordReliefApplied/getReliefApplied primitive (cosmicvaulteconomy.lua) -- same
-- behavior, shared mechanism any other mod's own payout-vs-tracked-score system can reuse.
function CosmicWarBridge.recordFamineReliefApplied(factionIndex, amount)
    include("cosmicvaulteconomy").recordReliefApplied("famine", factionIndex, amount)
end

function CosmicWarBridge.getFamineReliefApplied(factionIndex)
    return include("cosmicvaulteconomy").getReliefApplied("famine", factionIndex)
end

-- v4.0.0 Frontlines: recomputes and publishes, for every currently-warring AI
-- faction pair, the sectors where their territories actually meet -- via Cosmic Vault's
-- CosmicVaultTerritory.getBorderSectors(), a bounded scan, not a galaxy-wide one. Border
-- geometry only changes when a siege or expansion actually resolves, so this is driven from
-- cosmicwarbridgeupdate.lua's existing 5-minute cadence rather than a dedicated background
-- script. Publishes two shapes: one per-pair value (for the galaxy map overlay, which wants
-- to color-code by conflict) and one flat combined set (for the cheap single-sector lookups
-- applyWarHazardSpawns() and cw_eventscheduler.lua make every tick).
local function getGalaxyFactionsForFrontlines(server)
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

function CosmicWarBridge.updateFrontlines()
    if not onServer() then return end
    local server = Server()
    if not server then return end

    local cfg = CosmicWarConfig.get() or {}
    if cfg.enableFrontlines == false then
        server:setValue("cw_frontline_pairs", nil)
        server:setValue("cw_frontline_sectors", nil)
        return
    end

    local factionIndices = getGalaxyFactionsForFrontlines(server)
    local processedPairs = {}
    local pairKeys = {}
    local combinedParts = {}

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

                        local CosmicVaultTerritory = include("cosmicvaultterritory")
                        local border = CosmicVaultTerritory.getBorderSectors(left, right, 15)

                        if #border > 0 then
                            table.insert(pairKeys, pairKey)
                            local sectorParts = {}
                            for _, s in pairs(border) do
                                table.insert(sectorParts, s.x .. "," .. s.y)
                                table.insert(combinedParts, s.x .. "," .. s.y)
                            end
                            server:setValue("cw_frontline_sectors_" .. pairKey, table.concat(sectorParts, ";"))
                        else
                            server:setValue("cw_frontline_sectors_" .. pairKey, nil)
                        end
                    end
                end
            end
        end
    end

    server:setValue("cw_frontline_pairs", table.concat(pairKeys, ","))
    -- v4.0.0 fix: each entry is "x,y", so joining entries with "," too let a query's
    -- ";"-free boundary land ON a real coordinate's digits at the seam between two
    -- adjacent entries (e.g. entries "1,2" and "3,4" joined as "1,2,3,4" spuriously
    -- matches a query for (2,3), a sector that was never actually recorded). ";" never
    -- appears inside a coordinate, so it's a safe entry separator distinct from the ","
    -- used *within* one coordinate -- isFrontlineSector() below searches for
    -- ";x,y;" against this same delimiter scheme.
    server:setValue("cw_frontline_sectors", ";" .. table.concat(combinedParts, ";") .. ";")
end

--- Returns the {x,y} sector list for one warring pair (pairKey = "min:max" faction
-- indices, matching cosmicwarceasefires.lua's own pairKey convention), for the galaxy map
-- overlay to render.
function CosmicWarBridge.getFrontlinePairs()
    if not onServer() then return {} end
    local server = Server()
    if not server then return {} end

    local pairsStr = server:getValue("cw_frontline_pairs")
    local result = {}
    if type(pairsStr) ~= "string" or pairsStr == "" then return result end

    for pairKey in string.gmatch(pairsStr, "([^,]+)") do
        local sectorsStr = server:getValue("cw_frontline_sectors_" .. pairKey)
        local sectors = {}
        if type(sectorsStr) == "string" and sectorsStr ~= "" then
            for x, y in string.gmatch(sectorsStr, "(-?%d+),(-?%d+)") do
                table.insert(sectors, {x = tonumber(x), y = tonumber(y)})
            end
        end
        table.insert(result, {pairKey = pairKey, sectors = sectors})
    end

    return result
end

--- Cheap single-sector check against the flat combined frontline set -- the lookup
-- applyWarHazardSpawns() and cw_eventscheduler.lua use every tick, so it stays a plain
-- string find rather than re-deriving faction pairs on every call.
function CosmicWarBridge.isFrontlineSector(x, y)
    if not onServer() or not x or not y then return false end
    local server = Server()
    if not server then return false end

    local sectorsStr = server:getValue("cw_frontline_sectors")
    if type(sectorsStr) ~= "string" or sectorsStr == "" then return false end

    return string.find(sectorsStr, ";" .. x .. "," .. y .. ";", 1, true) ~= nil
end

--- v4.0.0 Occupation & Insurgency: reads back the marker
-- trooptransport.lua's captureStation() sets, {oldFactionIndex, newFactionIndex, endTime}, or
-- nil if this sector was never captured or its 6-hour occupation window has already passed
-- (a lazily-expired marker -- nothing proactively clears it, the same "check the timestamp,
-- don't poll a countdown" pattern this mod's other lightweight markers already use).
function CosmicWarBridge.getOccupationData(x, y)
    if not onServer() or not x or not y then return nil end
    local server = Server()
    if not server then return nil end

    local raw = server:getValue("cw_occupation_" .. x .. ":" .. y)
    if type(raw) ~= "string" or raw == "" then return nil end

    local oldIdx, newIdx, endTime = string.match(raw, "^(%-?%d+),(%-?%d+),(%-?%d+)$")
    oldIdx, newIdx, endTime = tonumber(oldIdx), tonumber(newIdx), tonumber(endTime)
    if not oldIdx or not newIdx or not endTime then return nil end
    if endTime <= (server.unpausedRuntime or 0) then return nil end

    return { oldFactionIndex = oldIdx, newFactionIndex = newIdx, endTime = endTime }
end

function CosmicWarBridge.isSectorOccupied(x, y)
    return CosmicWarBridge.getOccupationData(x, y) ~= nil
end

--- Combines both of this pass's sector-level reward modifiers into the one
-- multiplier War Contract reward formulas actually chain in: a +15% premium on a
-- Frontlines sector, a -30% penalty on a freshly-Occupied one (the new owner's hold isn't
-- fully productive yet). The two are mutually exclusive in practice -- a sector inside
-- another faction's 6-hour occupation window isn't also a live frontline -- but the
-- multiplication is written to compose safely regardless.
function CosmicWarBridge.getSectorRewardMultiplier(x, y)
    local mult = CosmicWarBridge.isFrontlineSector(x, y) and 1.15 or 1.0
    if CosmicWarBridge.isSectorOccupied(x, y) then
        mult = mult * 0.70
    end
    return mult
end

--- v4.0.0 War Weariness: read accessor for the 0..100 counter
-- cosmicwarweariness.lua maintains. 0 if the faction has none recorded (never lost
-- ground in a war, or is at peace and fully decayed).
function CosmicWarBridge.getWarWeariness(factionIndex)
    if not onServer() or not factionIndex then return 0 end
    local server = Server()
    if not server then return 0 end
    return server:getValue("cw_weariness_" .. tostring(factionIndex)) or 0
end

return CosmicWarBridge

