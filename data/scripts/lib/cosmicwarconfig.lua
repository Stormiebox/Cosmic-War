package.path = package.path .. ";data/scripts/lib/?.lua"

local ccm = include("ccm")
local config = ccm and ccm.bind("Cosmic_War") or nil

include("cosmicvaultconfig")

CosmicWarConfig = CosmicWarConfig or {}

if ccm then
    ccm.register("Cosmic_War", {
        pages = {
            {
                title = "UI & Keybinds",
                options = {
                    { key = "hotkeyGalacticPolitics", type = "keybind", title = "Open Galactic Politics", description = "Hotkey to quickly open the Galactic Politics tab." },
                },
            },
            {
                title = "War & Skirmish Configurations",
                options = {
                    { key = "sectorPressureInterval", type = "number", title = "Sector Pressure Interval (s)", description = "Time between war skirmish spawn checks.", default = 180, min = 30, max = 1800 },
                    { key = "sectorPressureChance", type = "number", title = "Sector Pressure Chance (%)", description = "Base chance of skirmish spawn.", default = 35, min = 0, max = 100 },
                    { key = "sectorPressureMinSpacing", type = "number", title = "Skirmish Minimum Spacing (s)", description = "Cool-down for skirmishes in a single sector.", default = 600, min = 60, max = 7200 },
                },
            },
            {
                title = "Diplomacy Configurations",
                options = {
                    { key = "diplomacyInterval", type = "number", title = "Diplomacy Processing Interval (s)", description = "Time between periodic diplomacy updates.", default = 300, min = 30, max = 3600 },
                    { key = "diplomacyPairSteps", type = "number", title = "Diplomatic Pair Process Batch", description = "Number of faction pairs processed per tick.", default = 50, min = 1, max = 100 },
                    { key = "rivalryThreshold", type = "number", title = "Rivalry Relations Threshold", description = "Relation score when factions declare rivalry.", default = -45000, min = -100000, max = 0 },
                    { key = "warScoreDecisiveVictoryThreshold", type = "number", title = "War Score Decisive Victory Threshold", description = "How lopsided the War Score between two factions must become (either direction) before the war ends outright in a forced Decisive Victory.", default = 250, min = 50, max = 1000 },
                },
            },
            {
                title = "News & Event Configurations",
                options = {
                    { key = "newsInterval", type = "number", title = "News Dispatch Interval (s)", description = "How often news is dispatched to BBS.", default = 600, min = 60, max = 3600 },
                    { key = "sanctionsInterval", type = "number", title = "Sanction Dispatch Interval (s)", description = "How often trade sanctions are considered.", default = 600, min = 60, max = 3600 },
                    { key = "ceasefireInterval", type = "number", title = "Ceasefire Processing Interval (s)", description = "How often ceasefires are checked.", default = 600, min = 60, max = 7200 },
                    { key = "bountyInterval", type = "number", title = "Bounty Creation Interval (s)", description = "How often war bounties are listed.", default = 600, min = 60, max = 3600 },
                    { key = "sanctionBaseChance", type = "number", title = "Trade Sanction Chance (%)", description = "Base chance to enact sanctions between rivals.", default = 35, min = 0, max = 100 },
                    { key = "ceasefireChance", type = "number", title = "Ceasefire Negotiation Chance (%)", description = "Base chance for war fatigue to trigger a ceasefire.", default = 25, min = 0, max = 100 },
                    { key = "eventBudgetPerHour", type = "number", title = "War Event Budget (per hour)", description = "Maximum number of Cosmic War dynamic events (Fleet Clash, Headhunters, Eclipse Vanguard, etc.) that can fire per player per hour of playtime. Once the budget is spent, no more War events fire until it refills, though vanilla and other mods' own events are unaffected.", default = 15, min = 1, max = 60 },
                },
            },
            {
                title = "Mod Integrations",
                options = {
                    { key = "enableEconomyBridge", type = "bool", title = "Enable Cosmic Economy Bridge", description = "Enable dynamic trade routes affected by war.", default = true },
                    { key = "enableCaptainBridge", type = "bool", title = "Enable Cosmic Captain Bridge", description = "Enables simulation overrides for captain operations during wartime.", default = true },
                },
            },
            -- CCM's own settings-write pathway already restricts every option on
            -- this page (and every other) to server admins, and already appends an "Only
            -- server Administrators can change this option!" notice to every option's
            -- tooltip automatically -- confirmed in cosmicconfigmenu.lua's
            -- syncCCMSettings(), no per-option flag needed.
            {
                title = "Gameplay Systems",
                options = {
                    { key = "enableSubspaceCorridors", type = "bool", title = "Enable Dynamic Wartime Subspace Corridors", description = "A war at maximum War Heat has a rolling chance to tear open a genuine, PERMANENT wormhole between the two factions' home sectors. Once torn, a corridor cannot be removed -- disable here if you don't want this on your galaxy.", default = true },
                    { key = "subspaceCorridorHardCap", type = "number", title = "Subspace Corridor Hard Cap", description = "Maximum number of Subspace Corridors that can ever exist galaxy-wide. Once reached, no new ones will tear open regardless of War Heat.", default = 5, min = 0, max = 50 },
                    { key = "defenseGeneratorCommissionChance", type = "number", title = "Defense Generator Commission Chance (%)", description = "Rolled periodically for every faction under meaningful War Heat (>=0.35) that doesn't already have one commissioned.", default = 15, min = 0, max = 100 },
                    { key = "intelPreviewCost", type = "number", title = "Intel Preview Cost", description = "Intel Points spent via /cosmicwarintel to preview a faction's likely next expansion target.", default = 50, min = 1, max = 500 },
                    { key = "enableFrontlines", type = "bool", title = "Enable Frontlines", description = "Highlights the sectors where two warring factions' territories actually meet on the galaxy map, and makes those sectors genuinely more dangerous and more lucrative: higher hazard-spawn odds, faster War Event rerolls, and a reward bonus on War Contracts given from a frontline sector.", default = true },
                },
            },
        },
    })
end

local defaults =
{
    sectorPressureInterval = 180,
    sectorPressureChance = 0.35, -- normalized 0..1
    sectorPressureMinSpacing = 600,

    diplomacyInterval = 300,
    diplomacyPairSteps = 50,

    rivalryThreshold = -45000,
    warBiasFloor = 550,

    newsInterval = 600,
    sanctionsInterval = 600,
    ceasefireInterval = 600,
    bountyInterval = 600,

    sanctionBaseChance = 0.35, -- normalized 0..1
    ceasefireChance = 0.25,    -- normalized 0..1

    enableEconomyBridge = true,
    enableCaptainBridge = true,

    debugLogs = true,

    enableSubspaceCorridors = true,
    subspaceCorridorHardCap = 5,
    eventBudgetPerHour = 15,
    defenseGeneratorCommissionChance = 0.15, -- normalized 0..1
    warScoreDecisiveVictoryThreshold = 250,
    intelPreviewCost = 50,
    enableFrontlines = true,
}

local function clampNumber(v, minV, maxV, fallback)
    if type(v) ~= "number" then return fallback end
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function readNumber(key, minV, maxV, fallback)
    if not config then return fallback end
    local value = config.get(key)
    return clampNumber(value, minV, maxV, fallback)
end

local function readBool(key, fallback)
    if not config then return fallback end
    local value = config.get(key)
    if value == nil then return fallback end
    if type(value) == "boolean" then return value end
    if type(value) == "string" then
        local lower = string.lower(value)
        if lower == "true" or lower == "1" then return true end
        if lower == "false" or lower == "0" then return false end
    end
    if type(value) == "number" then
        if value == 1 then return true end
        if value == 0 then return false end
    end
    return fallback
end

local function build()
    local out = {}

    out.sectorPressureInterval = readNumber("sectorPressureInterval", 30, 1800, defaults.sectorPressureInterval)

    -- CCM stores chance as percent (0..100), convert to normalized 0..1
    local chancePercent = readNumber("sectorPressureChance", 0, 100, defaults.sectorPressureChance * 100)
    out.sectorPressureChance = chancePercent / 100

    out.sectorPressureMinSpacing = readNumber("sectorPressureMinSpacing", 60, 7200, defaults.sectorPressureMinSpacing)

    out.diplomacyInterval = readNumber("diplomacyInterval", 30, 3600, defaults.diplomacyInterval)
    out.diplomacyPairSteps = readNumber("diplomacyPairSteps", 1, 100, defaults.diplomacyPairSteps)

    out.rivalryThreshold = readNumber("rivalryThreshold", -100000, 0, defaults.rivalryThreshold)

    -- currently script-only tuning
    out.warBiasFloor = defaults.warBiasFloor

    out.newsInterval = readNumber("newsInterval", 60, 3600, defaults.newsInterval)
    out.sanctionsInterval = readNumber("sanctionsInterval", 60, 3600, defaults.sanctionsInterval)
    out.ceasefireInterval = readNumber("ceasefireInterval", 60, 7200, defaults.ceasefireInterval)
    out.bountyInterval = readNumber("bountyInterval", 60, 3600, defaults.bountyInterval)

    local sanctionChancePercent = readNumber("sanctionBaseChance", 0, 100, defaults.sanctionBaseChance * 100)
    out.sanctionBaseChance = sanctionChancePercent / 100

    local ceasefireChancePercent = readNumber("ceasefireChance", 0, 100, defaults.ceasefireChance * 100)
    out.ceasefireChance = ceasefireChancePercent / 100

    out.enableEconomyBridge = readBool("enableEconomyBridge", defaults.enableEconomyBridge)
    out.enableCaptainBridge = readBool("enableCaptainBridge", defaults.enableCaptainBridge)

    local vaultCfg = CosmicVaultConfig and CosmicVaultConfig.get and CosmicVaultConfig.get() or nil
    if vaultCfg and type(vaultCfg.debugWar) == "boolean" then
        out.debugLogs = vaultCfg.debugWar
    else
        out.debugLogs = readBool("debugLogs", defaults.debugLogs)
    end

    out.enableSubspaceCorridors = readBool("enableSubspaceCorridors", defaults.enableSubspaceCorridors)
    out.subspaceCorridorHardCap = readNumber("subspaceCorridorHardCap", 0, 50, defaults.subspaceCorridorHardCap)
    out.eventBudgetPerHour = readNumber("eventBudgetPerHour", 1, 60, defaults.eventBudgetPerHour)

    -- CCM stores this as percent (0..100), convert to normalized 0..1 -- matching the
    -- convention every other chance value on this page already follows.
    local generatorChancePercent = readNumber("defenseGeneratorCommissionChance", 0, 100, defaults.defenseGeneratorCommissionChance * 100)
    out.defenseGeneratorCommissionChance = generatorChancePercent / 100

    out.warScoreDecisiveVictoryThreshold = readNumber("warScoreDecisiveVictoryThreshold", 50, 1000, defaults.warScoreDecisiveVictoryThreshold)
    out.intelPreviewCost = readNumber("intelPreviewCost", 1, 500, defaults.intelPreviewCost)
    out.enableFrontlines = readBool("enableFrontlines", defaults.enableFrontlines)

    return out
end

function CosmicWarConfig.get()
    return build()
end

-- Explicitly return the table so scripts using local variable captures do not crash
return CosmicWarConfig
