package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")


include("cosmicwarconfig")
include("cosmicvaultdebug")

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
    if CosmicVaultDebug and CosmicVaultDebug.info then
        CosmicVaultDebug.info("CosmicWar-Factions", msg, ...)
        return
    end

    local cfg = CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get() or { debugLogs = false }
    if not cfg.debugLogs then return end
    include("cosmicvaultdebug").info("Cosmic War", "[Cosmic War] " .. msg, ...)
end

function initializeAIFaction(faction, baseName, stateFormName)
    if cw_old_initializeAIFaction then
        cw_old_initializeAIFaction(faction, baseName, stateFormName)
    end

    if not faction then return end

    local seed = Server().seed + faction.index * 101 + 17
    local random = Random(seed)

    -- 1) Apply Custom Traits (Overrides old stance logic)
    local cwt = include("cosmicwartraits")
    if cwt and cwt.applyTraits then
        cwt.applyTraits(faction)
    end

    -- 2) Register enabled flag
    faction:setValue("cw_enabled", true)

    -- A marker used by player/alliance systems later.
    if faction:getValue("enemy_faction") == nil then
        faction:setValue("enemy_faction", 0)
    end

    -- Register this newly created faction with Cosmic Vault's faction index
    local server = Server()
    if server then
        local factionStr = server:getValue("factions") or ""
        local searchStr = "," .. tostring(faction.index) .. ","
        if factionStr == "" then
            server:setValue("factions", tostring(faction.index))
        elseif not string.find("," .. factionStr .. ",", searchStr) then
            server:setValue("factions", factionStr .. "," .. tostring(faction.index))
        end
    end

    cw_debug("Initialized faction '%s' (%i)",
        faction.name or "Unknown",
        faction.index or -1
    )
end
