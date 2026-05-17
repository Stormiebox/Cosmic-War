package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarconfig")

-- namespace CosmicWarBridge
CosmicWarBridge = CosmicWarBridge or {}

local function safeRelations(a, bIndex)
    if not a or not bIndex then return 0 end
    return a:getRelations(bIndex) or 0
end

local function getGalaxyFactions(server)
    if not server or type(server.getValue) ~= "function" then return {} end

    local factions = {}
    local factionIndices = server:getValue("factions")
    if type(factionIndices) ~= "table" then return factions end

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

    local cfg = (CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get()) or {}
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

    local heat = relHeat * 0.6 + bias * 0.2 + pairBonus
    return math.min(1.0, math.max(0.0, heat))
end

function CosmicWarBridge.publishWarHeatSnapshot()
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factions = getGalaxyFactions(server)
    local snapshot = {}
    local maxHeat = 0

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local heat = CosmicWarBridge.computeWarHeatForFaction(f)
            snapshot[f.index] = heat
            if heat > maxHeat then maxHeat = heat end
        end
    end

    -- global snapshot for bridge consumers (Cosmic Overhaul hooks / scripts)
    server:setValue("cw_war_heat_snapshot", snapshot)
    server:setValue("cw_war_heat_max", maxHeat)
end

function CosmicWarBridge.getWarHeatSnapshot()
    local server = Server()
    if not server then return {}, 0 end

    return server:getValue("cw_war_heat_snapshot") or {}, server:getValue("cw_war_heat_max") or 0
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
