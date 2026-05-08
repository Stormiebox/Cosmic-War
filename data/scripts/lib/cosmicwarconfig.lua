package.path = package.path .. ";data/scripts/lib/?.lua"

local mcm = include("mcm")
local config = mcm and mcm.bind("Cosmic_War") or nil

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

    -- currently script-only tuning (not exposed yet)
    out.warBiasFloor = defaults.warBiasFloor

    out.debugLogs = readBool("debugLogs", defaults.debugLogs)

    return out
end

function CosmicWarConfig.get()
    return build()
end
