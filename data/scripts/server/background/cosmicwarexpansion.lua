package.path = package.path .. ";data/scripts/lib/?.lua"

local cvf = include("cosmicvaultfaction")
local cvt = include("cosmicvaultterritory")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")

-- namespace CosmicWarExpansion
CosmicWarExpansion = {}

function CosmicWarExpansion.getUpdateInterval()
    return 15 * 60 -- Run every 15 minutes
end

local function hasTrait(f, traitId)
    return (cvf.getTrait(f.index, traitId) or 0) > 0
end

local function getActiveFactions()
    local server = Server()
    if not server or type(server.getValue) ~= "function" then return {} end

    local out = {}
    local factionStr = server:getValue("factions")
    local FactionEradicationUtility = include("factioneradicationutility")

    if type(factionStr) == "string" and factionStr ~= "" then
        for id in string.gmatch(factionStr, "([^,]+)") do
            local f = Faction(tonumber(id))
            if f and f.isAIFaction and f:getValue("cw_enabled") and not FactionEradicationUtility.isFactionEradicated(tonumber(id)) then
                table.insert(out, f)
            end
        end
    end
    return out
end

--- Expansion Momentum (v4.0.0): a faction that wins a siege gets a temporary boost to
-- its own organic expansion rolls -- previously, winning a war and growing faster
-- afterward were two completely disconnected systems. siegeevent.lua sets this value on
-- a successful invasion; it naturally expires on its own; readers never need to clear it.
local function getMomentumMultiplier(faction)
    local until_ = Server():getValue("cw_expansion_momentum_" .. tostring(faction.index)) or 0
    if until_ > Server().unpausedRuntime then
        return 2.0
    end
    return 1.0
end

-- v4.0.0: Counter-Intelligence Sweep sets this flag on a faction whose forward
-- listening post was destroyed -- blinding their next expansion roll rather than
-- blocking expansion outright, since the multiplier still composes with Momentum
-- above (a blinded faction's roll is 0 regardless of any simultaneous Momentum boost,
-- matching "blind their next expansion roll" rather than "pause expansion").
local function getExpansionBlindMultiplier(faction)
    local until_ = Server():getValue("cw_expansion_blinded_until_" .. tostring(faction.index)) or 0
    if until_ > Server().unpausedRuntime then
        return 0.0
    end
    return 1.0
end

function CosmicWarExpansion.update(timeStep)
    if not onServer() then return end

    local factions = getActiveFactions()
    for _, faction in pairs(factions) do

        local activeTrait = faction:getTrait("active") or 0
        local expansionMultiplier = math.max(0, 1.0 + activeTrait) * getMomentumMultiplier(faction) * getExpansionBlindMultiplier(faction)

        -- Imperialist Logic
        -- v4.0.0: was a single random point within a 15-sector radius, claimed if
        -- unclaimed. Replaced with a directional walk matching Cosmic Ascendancy's own
        -- expansion manager (ca_expansion_manager.lua): pick a heading, walk outward one
        -- sector at a time, and claim the FIRST unclaimed sector found along that ray --
        -- giving up (not skipping past) if the ray immediately runs into someone else's
        -- territory. This produces contiguous, frontier-shaped growth instead of an
        -- Imperialist faction randomly teleport-claiming an isolated pocket sector deep
        -- inside a radius it has no real presence in.
        if hasTrait(faction, "cw_imperialist") then
            -- 35% chance to expand borders outward, multiplied by active trait and any
            -- active expansion momentum
            if random():test(0.35 * expansionMultiplier) then
                -- Same deterministic per-faction, per-15-minute-window seed the
                -- Intelligence Network's /cosmicwarintel preview uses (cosmicwarbridge.lua
                -- documents the exact formula) -- without this, the "preview" and the real
                -- roll would pick unrelated random headings and the intel would just be a
                -- coincidentally-plausible guess rather than a genuine scouting result.
                local server = Server()
                local seed = server and (server.seed + faction.index * 101 + math.floor(server.unpausedRuntime / 900)) or nil
                local tx, ty = CosmicWarBridge.findExpansionCandidate(faction, 15, seed)
                if tx and ty then
                    cvt.expandToSector(tx, ty, faction.index, false)
                end
            end
        end

        -- Entrenched Logic
        if hasTrait(faction, "cw_entrenched") then
            -- 20% chance to heavily fortify core territory, multiplied by active trait
            -- and any active expansion momentum
            if random():test(0.20 * expansionMultiplier) then
                local hx, hy = faction:getHomeSectorCoordinates()
                if hx and hy then
                    local dx = random():getInt(-5, 5)
                    local dy = random():getInt(-5, 5)
                    local tx, ty = hx + dx, hy + dy
                    -- Same collision check -- an Entrenched faction fortifying its own
                    -- core should never be able to silently annex a neighbor's sector
                    -- that happens to fall within its home radius.
                    if not Galaxy():getControllingFaction(tx, ty) then
                        cvt.expandToSector(tx, ty, faction.index, false)
                    end
                end
            end
        end

    end
end
