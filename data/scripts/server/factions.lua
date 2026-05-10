package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
include ("galaxy")
include ("faction")
include ("cosmicwarconfig")

-- Cosmic War extension for server faction initialization.
-- This file is appended to/merged with vanilla data/scripts/server/factions.lua by Avorion mod loading.
-- It wraps initializeAIFaction from the currently loaded stack (vanilla + earlier mods).

local cw_old_initializeAIFaction = initializeAIFaction

local function cw_clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function cw_debug(msg, ...)
    local cfg = CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get() or {debugLogs = false}
    if not cfg.debugLogs then return end
    print("[Cosmic War] " .. msg, ...)
end

function initializeAIFaction(faction, baseName, stateFormName)
    if cw_old_initializeAIFaction then
        cw_old_initializeAIFaction(faction, baseName, stateFormName)
    end

    if not faction then return end

    local seed = Server().seed + faction.index * 101 + 17
    local random = Random(seed)

    -- 1) Strengthen war identity without relying on trait helper globals
    -- (those helpers are not guaranteed to exist in every runtime context/version).
    local targetAggressive = random:getFloat(0.55, 1.0)

    -- 2) Push diplomatic polarity seed: rivalry-prone vs alliance-prone blocs.
    local mistrustful = random:getFloat(-0.25, 0.85)
    local forgiving = random:getFloat(-0.25, 0.85)

    if random:test(0.65) then
        mistrustful = cw_clamp(mistrustful + random:getFloat(0.10, 0.35), -1.0, 1.0)
        forgiving = cw_clamp(forgiving - random:getFloat(0.05, 0.25), -1.0, 1.0)
    else
        mistrustful = cw_clamp(mistrustful - random:getFloat(0.05, 0.20), -1.0, 1.0)
        forgiving = cw_clamp(forgiving + random:getFloat(0.10, 0.30), -1.0, 1.0)
    end

    -- 3) War-state metadata used by future Cosmic War scripts.
    -- Keeping values in faction storage avoids save migration complexity.
    faction:setValue("cw_enabled", true)
    faction:setValue("cw_war_bias", math.floor(targetAggressive * 1000))
    faction:setValue("cw_diplomatic_polarity", math.floor((mistrustful - forgiving) * 1000))

    -- A marker used by player/alliance systems later.
    if faction:getValue("enemy_faction") == nil then
        faction:setValue("enemy_faction", 0)
    end

    cw_debug("Initialized faction '%s' (%i): war_bias=%i polarity=%i",
        faction.name or "Unknown",
        faction.index or -1,
        faction:getValue("cw_war_bias") or 0,
        faction:getValue("cw_diplomatic_polarity") or 0
    )
end
