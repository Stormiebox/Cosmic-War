package.path = package.path .. ";data/scripts/lib/?.lua"

local mcm = include("mcm")
local config = mcm and mcm.bind("Cosmic_War") or nil

include("cosmicvaultconfig")

CosmicWarConfig = CosmicWarConfig or {}

local defaults =
{
    sectorPressureInterval = 180,
    sectorPressureChance = 0.35, -- normalized 0..1
    sectorPressureMinSpacing = 600,

    diplomacyInterval = 300,
    diplomacyPairSteps = 10,

    rivalryThreshold = -45000,
    warBiasFloor = 550,

    newsInterval = 420,
    sanctionsInterval = 600,
    ceasefireInterval = 900,
    bountyInterval = 600,

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
    local value = config.get(key)
    if type(value) ~= "boolean" then return fallback end
    return value
end

local function build()
    local out = {}

    out.sectorPressureInterval = readNumber("sectorPressureInterval", 30, 1800, defaults.sectorPressureInterval)

    -- MCM stores chance as percent (0..100), convert to normalized 0..1
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
