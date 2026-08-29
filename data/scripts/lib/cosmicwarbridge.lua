package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarconfig")


CosmicWarBridge = CosmicWarBridge or {}

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

return CosmicWarBridge

