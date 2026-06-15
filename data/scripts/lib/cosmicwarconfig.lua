package.path = package.path .. ";data/scripts/lib/?.lua"

local ccm = include("ccm")
local config = ccm and ccm.bind("Cosmic_War") or nil

include("cosmicvaultconfig")

CosmicWarConfig = CosmicWarConfig or {}

if ccm then
    ccm.register("Cosmic_War", {
        pages = {
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
                    { key = "diplomacyInterval", type = "number", title = "Diplomacy Processing Interval (s)", description = "Time between periodic diplomacy updates.", default = 1200, min = 30, max = 3600 },
                    { key = "diplomacyPairSteps", type = "number", title = "Diplomatic Pair Process Batch", description = "Number of faction pairs processed per tick.", default = 10, min = 1, max = 100 },
                    { key = "rivalryThreshold", type = "number", title = "Rivalry Relations Threshold", description = "Relation score when factions declare rivalry.", default = -45000, min = -100000, max = 0 },
                },
            },
            {
                title = "News & Event Configurations",
                options = {
                    { key = "newsInterval", type = "number", title = "News Dispatch Interval (s)", description = "How often news is dispatched to BBS.", default = 1200, min = 60, max = 3600 },
                    { key = "sanctionsInterval", type = "number", title = "Sanction Dispatch Interval (s)", description = "How often trade sanctions are considered.", default = 1200, min = 60, max = 3600 },
                    { key = "ceasefireInterval", type = "number", title = "Ceasefire Processing Interval (s)", description = "How often ceasefires are checked.", default = 1200, min = 60, max = 7200 },
                    { key = "bountyInterval", type = "number", title = "Bounty Creation Interval (s)", description = "How often war bounties are listed.", default = 1200, min = 60, max = 3600 },
                    { key = "sanctionBaseChance", type = "number", title = "Trade Sanction Chance (%)", description = "Base chance to enact sanctions between rivals.", default = 35, min = 0, max = 100 },
                    { key = "ceasefireChance", type = "number", title = "Ceasefire Negotiation Chance (%)", description = "Base chance for war fatigue to trigger a ceasefire.", default = 25, min = 0, max = 100 },
                },
            },
            {
                title = "Mod Integrations",
                options = {
                    { key = "enableEconomyBridge", type = "bool", title = "Enable Cosmic Economy Bridge", description = "Enable dynamic trade routes affected by war.", default = true },
                    { key = "enableCaptainBridge", type = "bool", title = "Enable Cosmic Captain Bridge", description = "Enables simulation overrides for captain operations during wartime.", default = true },
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

    diplomacyInterval = 1200,
    diplomacyPairSteps = 10,

    rivalryThreshold = -45000,
    warBiasFloor = 550,

    newsInterval = 1200,
    sanctionsInterval = 1200,
    ceasefireInterval = 1200,
    bountyInterval = 1200,

    sanctionBaseChance = 0.35, -- normalized 0..1
    ceasefireChance = 0.25,    -- normalized 0..1

    enableEconomyBridge = true,
    enableCaptainBridge = true,

    debugLogs = true,
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
    local success, value = pcall(config.get, key)
    if not success then return fallback end
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

    local vaultCfg = (CosmicVaultConfig and CosmicVaultConfig.get and CosmicVaultConfig.get()) or nil
    if vaultCfg and type(vaultCfg.debugEnabled) == "boolean" then
        out.debugLogs = vaultCfg.debugEnabled
    else
        out.debugLogs = readBool("debugLogs", defaults.debugLogs)
    end

    return out
end

function CosmicWarConfig.get()
    return build()
end

-- Explicitly return the table so scripts using local variable captures do not crash
return CosmicWarConfig
