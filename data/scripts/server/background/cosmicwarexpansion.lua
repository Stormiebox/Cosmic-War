package.path = package.path .. ";data/scripts/lib/?.lua"

local cvf = include("cosmicvaultfaction")
local cvt = include("cosmicvaultterritory")
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

function CosmicWarExpansion.update(timeStep)
    if not onServer() then return end

    local factions = getActiveFactions()
    for _, faction in pairs(factions) do

        local activeTrait = faction:getTrait("active") or 0
        local expansionMultiplier = math.max(0, 1.0 + activeTrait)

        -- Imperialist Logic
        if hasTrait(faction, "cw_imperialist") then
            -- 35% chance to expand borders outward, multiplied by active trait
            if random():test(0.35 * expansionMultiplier) then
                local hx, hy = faction:getHomeSectorCoordinates()
                if hx and hy then
                    local dx = random():getInt(-15, 15)
                    local dy = random():getInt(-15, 15)
                    local tx, ty = hx + dx, hy + dy
                    -- Expand natively using Cosmic Vault!
                    cvt.expandToSector(tx, ty, faction.index, false)
                end
            end
        end

        -- Entrenched Logic
        if hasTrait(faction, "cw_entrenched") then
            -- 20% chance to heavily fortify core territory, multiplied by active trait
            if random():test(0.20 * expansionMultiplier) then
                local hx, hy = faction:getHomeSectorCoordinates()
                if hx and hy then
                    local dx = random():getInt(-5, 5)
                    local dy = random():getInt(-5, 5)
                    local tx, ty = hx + dx, hy + dy
                    -- Expand natively inside their own core territory to build dense outposts
                    cvt.expandToSector(tx, ty, faction.index, false)
                end
            end
        end

    end
end

