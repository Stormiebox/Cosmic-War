package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("faction")
include("relations")
include("cosmicwarconfig")
include("cosmicvaultdebug")

-- namespace CosmicWarDiplomacy
CosmicWarDiplomacy = {}

function CosmicWarDiplomacy.initialize()
    if onServer() then
        CosmicWarDiplomacy._elapsed = CosmicWarDiplomacy._elapsed or 0
    end
end

local function getCfg()
    if CosmicWarConfig and CosmicWarConfig.get then
        return CosmicWarConfig.get()
    end

    return {
        ["diplomacyInterval"] = 300,
        ["diplomacyPairSteps"] = 10,
        ["rivalryThreshold"] = -45000,
        ["debugLogs"] = false
    }
end

function CosmicWarDiplomacy.getUpdateInterval()
    local cfg = getCfg()
    return cfg.diplomacyInterval or 300
end

local function cwlog(msg, ...)
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Diplomacy", msg, ...)
        return
    end

    local cfg = getCfg()
    if not cfg.debugLogs then return end
    print("[Cosmic War][Diplomacy] " .. msg, ...)
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

    for _, index in pairs(factionIndices) do
        local f = Faction(index)
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            table.insert(out, f)
        end
    end

    return out
end

local function maybeAdjustPair(a, b, random)
    if not a or not b or a.index == b.index then return end

    local rel = a:getRelations(b.index) or 0
    local ap = a:getValue("cw_diplomatic_polarity") or 0
    local bp = b:getValue("cw_diplomatic_polarity") or 0
    local aw = a:getValue("cw_war_bias") or 0
    local bw = b:getValue("cw_war_bias") or 0

    local polarityGap = math.abs(ap - bp)

    local warChance = 0.08
        + math.max(0, (-rel - 15000) / 180000)
        + math.max(0, (aw + bw - 1200) / 6000)
        + math.max(0, (polarityGap - 400) / 3000)

    local peaceChance = 0.05
        + math.max(0, (rel - 25000) / 220000)
        + math.max(0, (900 - (aw + bw)) / 8000)

    local didChange = false

    if random:test(math.min(0.55, warChance)) then
        local worsen = random:getInt(1000, 4500)
        local cvf_success, cvf = pcall(include, "cosmicvaultfaction")
        if cvf_success and cvf and cvf.changeRelations then
            cvf.changeRelations(a.index, b.index, -worsen)
        else
            local nr = math.max(-100000, rel - worsen)
            Galaxy():setFactionRelations(a, b, nr)
        end
        local nr = a:getRelations(b.index) or (rel - worsen)
        
        didChange = true

        local cfg = getCfg()
        if nr <= (cfg.rivalryThreshold or -45000) then
            a:setValue("enemy_faction", b.index)
            b:setValue("enemy_faction", a.index)
            a:setValue("cw_target_faction", b.index)
            b:setValue("cw_target_faction", a.index)
        end
    elseif random:test(math.min(0.40, peaceChance)) then
        local improve = random:getInt(500, 2200)
        local cvf_success, cvf = pcall(include, "cosmicvaultfaction")
        if cvf_success and cvf and cvf.changeRelations then
            cvf.changeRelations(a.index, b.index, improve)
        else
            local nr = math.min(100000, rel + improve)
            Galaxy():setFactionRelations(a, b, nr)
        end
        didChange = true
    end

    if didChange then
        cwlog("Adjusted relations: %s(%i) <-> %s(%i), now=%i",
            a.name or "A", a.index or -1,
            b.name or "B", b.index or -1,
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
    
    local cv_task_success, cv_task = pcall(include, "cosmicvaulttask")
    if cv_task_success and cv_task and cv_task.RunAsync then
        cv_task.RunAsync("CosmicWarDiplomacy", function()
            for i = 1, steps do
                if i % 10 == 0 and cv_task.Yield then
                    cv_task.Yield()
                end
                local a = factions[random:getInt(1, #factions)]
                local b = factions[random:getInt(1, #factions)]
                if a and b and a.index ~= b.index then
                    maybeAdjustPair(a, b, random)
                end
            end
        end)
    else
        for _ = 1, steps do
            local a = factions[random:getInt(1, #factions)]
            local b = factions[random:getInt(1, #factions)]
            if a and b and a.index ~= b.index then
                maybeAdjustPair(a, b, random)
            end
        end
    end
end
