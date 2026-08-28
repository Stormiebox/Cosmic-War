package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

include("relations")
include("cosmicwarconfig")
include("cosmicvaultdebug")

local cvf = include("cosmicvaultfaction")
local cve = include("cosmicvaultevents")

-- namespace CosmicWarDiplomacy
CosmicWarDiplomacy = {}

function CosmicWarDiplomacy.initialize()
    if onServer() then
        CosmicWarDiplomacy._elapsed = CosmicWarDiplomacy._elapsed or 0
    end
end

local function getCfg()
    return CosmicWarConfig.get() or {
        ["diplomacyInterval"] = 300,
        ["diplomacyPairSteps"] = 50,
        ["rivalryThreshold"] = -45000,
        ["debugLogs"] = false
    }
end

function CosmicWarDiplomacy.getUpdateInterval()
    local cfg = getCfg()
    return cfg.diplomacyInterval or 300
end

local function cwlog(msg, ...)
    CosmicVaultDebug.info("CosmicWar-Diplomacy", msg, ...)
end

local function getWarFactionCandidates()
    local server = Server()
    if not server then return {} end

    if not server:getValue("factions_ready") then return {} end

    local out = {}
    local factionStr = server:getValue("factions")
    local factionIndices = {}

    if type(factionStr) == "string" and factionStr ~= "" then
        for id in string.gmatch(factionStr, "([^,]+)") do
            table.insert(factionIndices, tonumber(id))
        end
    end

    local FactionEradicationUtility = include("factioneradicationutility")

    for _, index in pairs(factionIndices) do
        local f = Faction(index)
        if f and f.isAIFaction and f:getValue("cw_enabled") and not FactionEradicationUtility.isFactionEradicated(index) then
            table.insert(out, f)
        end
    end

    return out
end

local function hasTrait(f, traitId)
    return (cvf.getTrait(f.index, traitId) or 0) > 0
end

local function maybeAdjustPair(a, b, random)
    if not a or not b or a.index == b.index then return end

    local rel = a:getRelations(b.index) or 0

    -- Base chances
    local warChance = 0.05 + math.max(0, (-rel - 15000) / 180000)
    local peaceChance = 0.05 + math.max(0, (rel - 25000) / 220000)

    -- Trait Interaction Matrix
    local wcMod = 0
    local pcMod = 0
    local aXeno = hasTrait(a, "cw_xenophobic")
    local bXeno = hasTrait(b, "cw_xenophobic")

    if aXeno or bXeno then
        wcMod = wcMod + 0.20
        pcMod = pcMod - 1.0 -- Absolute peace blocker
        -- Forced decay
        warChance = warChance + 0.3
        peaceChance = 0
    end

    if hasTrait(a, "cw_warmonger") or hasTrait(b, "cw_warmonger") then
        wcMod = wcMod + 0.15
        pcMod = pcMod - 0.10
    end

    local aPac = hasTrait(a, "cw_pacifist")
    local bPac = hasTrait(b, "cw_pacifist")
    if aPac and bPac then
        wcMod = wcMod - 1.0  -- Effectively immune to war
        pcMod = pcMod + 0.20
    elseif aPac or bPac then
        wcMod = wcMod - 0.05
        pcMod = pcMod + 0.10
    end

    if hasTrait(a, "cw_isolationist") or hasTrait(b, "cw_isolationist") then
        wcMod = wcMod - 0.04 -- Less likely to start unprovoked wars
        pcMod = pcMod - 0.15 -- Almost never make alliances
    end

    if hasTrait(a, "cw_opportunist") or hasTrait(b, "cw_opportunist") then
        if rel > 40000 then
            wcMod = wcMod + 0.05 -- More likely to backstab
            pcMod = pcMod - 0.05
        elseif rel < -40000 then
            pcMod = pcMod + 0.05 -- Try to surrender or negotiate
        end
    end

    if hasTrait(a, "cw_imperialist") or hasTrait(b, "cw_imperialist") then
        wcMod = wcMod + 0.10 -- Border friction
        pcMod = pcMod - 0.05
    end

    if hasTrait(a, "cw_entrenched") or hasTrait(b, "cw_entrenched") then
        wcMod = wcMod - 0.08 -- Rarely starts offensive wars
        pcMod = pcMod + 0.05
    end

    if hasTrait(a, "cw_mercantile") or hasTrait(b, "cw_mercantile") then
        wcMod = wcMod - 0.10 -- Prefers business
        pcMod = pcMod + 0.10
    end

    if hasTrait(a, "cw_vengeful") or hasTrait(b, "cw_vengeful") then
        if rel < 0 then
            pcMod = pcMod - 1.0 -- Never accepts ceasefires
        end
    end

    -- Dormant Vanilla Trait Evaluation (Strict vs Forgiving)
    local strictA = a:getTrait("strict") or 0
    local strictB = b:getTrait("strict") or 0
    wcMod = wcMod + (strictA * 0.10) + (strictB * 0.10)
    pcMod = pcMod - (strictA * 0.15) - (strictB * 0.15)

    -- Dormant Vanilla Trait Evaluation (Smart vs Dumb)
    local smartA = a:getTrait("smart") or 0
    local smartB = b:getTrait("smart") or 0

    -- Smart factions avoid war if it isn't an absolute necessity
    if smartA > 0.5 or smartB > 0.5 then
        if warChance < 0.4 then
            wcMod = wcMod - 0.20
        end
    end
    -- Dumb factions are highly volatile and easily provoked
    if smartA < -0.5 or smartB < -0.5 then
        wcMod = wcMod + 0.15
    end

    warChance = math.max(0, warChance + wcMod)
    peaceChance = math.max(0, peaceChance + pcMod)

    local didChange = false

    if random:test(math.min(0.75, warChance)) then
        local worsen = random:getInt(1000, 4500)
        cvf.changeRelations(a.index, b.index, -worsen)
        local nr = a:getRelations(b.index) or (rel - worsen)

        didChange = true

        local cfg = getCfg()
        if nr <= (cfg.rivalryThreshold or -45000) then
            local alreadyAtWar = a:getValue("enemy_faction") == b.index
            if not alreadyAtWar then
                a:setValue("enemy_faction", b.index)
                b:setValue("enemy_faction", a.index)
                a:setValue("cw_target_faction", b.index)
                b:setValue("cw_target_faction", a.index)

                -- Broadcast the War via Cosmic Vault Events (7 days duration default)
                cve.startEvent("cw_war_" .. a.index .. "_" .. b.index, 7 * 24 * 3600)
                cve.startEvent("cw_war_" .. b.index .. "_" .. a.index, 7 * 24 * 3600)
            end
        end
    elseif random:test(math.min(0.40, peaceChance)) then
        local improve = random:getInt(500, 2200)
        cvf.changeRelations(a.index, b.index, improve)
        didChange = true

        local nr = a:getRelations(b.index) or (rel + improve)
        local cfg = getCfg()
        if nr > (cfg.rivalryThreshold or -45000) then
            local wasAtWar = a:getValue("enemy_faction") == b.index
            if wasAtWar then
                a:setValue("enemy_faction", nil)
                b:setValue("enemy_faction", nil)
                a:setValue("cw_target_faction", nil)
                b:setValue("cw_target_faction", nil)

                -- End the war event early if peace is achieved
                cve.endEvent("cw_war_" .. a.index .. "_" .. b.index)
                cve.endEvent("cw_war_" .. b.index .. "_" .. a.index)
            end
        end
    end

    if didChange then
        cwlog("Adjusted relations: %s <-> %s, now=%i",
            a.name or "A",
            b.name or "B",
            a:getRelations(b.index) or rel
        )
    end
end

function CosmicWarDiplomacy.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local seed = server.seed + math.floor(server.unpausedRuntime / 300)
    local random = Random(seed)

    local factions = getWarFactionCandidates()
    if #factions < 2 then return end

    local cfg = getCfg()
    local steps = math.min(cfg.diplomacyPairSteps or 10, #factions)

    for _ = 1, steps do
        local a = factions[random:getInt(1, #factions)]
        local b = factions[random:getInt(1, #factions)]
        if a and b and a.index ~= b.index then
            maybeAdjustPair(a, b, random)
        end
    end
end



return CosmicWarDiplomacy
