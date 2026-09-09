package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")

-- namespace CosmicWarSubspaceCorridors
CosmicWarSubspaceCorridors = {}

function CosmicWarSubspaceCorridors.getUpdateInterval()
    return 20 * 60 -- Check every 20 minutes
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

-- v4.0.0: at maximum War Heat (1.00, the same rare threshold that gates
-- Decapitation Strike/Champion Duel/Extract POW), a war has become intense enough that a
-- genuine subspace corridor tears open between the two factions' home sectors -- a real,
-- persistent wartime shortcut, not a cosmetic effect. Deliberately a lasting consequence of
-- the war rather than a timed one: forcibly removing a spawned entity later would require
-- that sector to be loaded again at the exact expiry moment, the same "can't touch an
-- unloaded sector" constraint the rest of this mod's territory system is built to avoid --
-- so once torn, a corridor stays open, framed as a permanent scar the war left in subspace.
-- Only the flag is set here; the actual wormhole entities are lazily materialized the first
-- time a player enters either endpoint sector (cw_siege_injector_persistent.lua), same
-- pattern as Planetary Defense Generators.
function CosmicWarSubspaceCorridors.update(timeStep)
    if not onServer() then return end

    local server = Server()
    if not server then return end

    local factions = getActiveFactions()
    local seenPairs = {}

    for _, faction in pairs(factions) do
        local enemyIdx = faction:getValue("enemy_faction") or 0
        if enemyIdx > 0 then
            local pairKey = tostring(math.min(faction.index, enemyIdx)) .. "_" .. tostring(math.max(faction.index, enemyIdx))
            if not seenPairs[pairKey] then
                seenPairs[pairKey] = true

                if not server:getValue("cw_subspace_corridor_" .. pairKey) then
                    local heat = CosmicWarBridge.getFactionWarHeat(faction.index) or 0
                    if heat >= 1.0 and random():test(0.10) then
                        local enemyFaction = Faction(enemyIdx)
                        local hx1, hy1 = faction:getHomeSectorCoordinates()
                        local hx2, hy2 = nil, nil
                        if enemyFaction then
                            hx2, hy2 = enemyFaction:getHomeSectorCoordinates()
                        end
                        if hx1 and hy1 and hx2 and hy2 then
                            local generator = SectorGenerator(hx1, hy1)
                            if generator:wormHoleAllowed({ x = hx1, y = hy1 }, { x = hx2, y = hy2 }) then
                                server:setValue("cw_subspace_corridor_" .. pairKey, hx1 .. ":" .. hy1 .. "|" .. hx2 .. ":" .. hy2)
                                -- Reverse lookups so onSectorEntered can check "is a corridor
                                -- endpoint here?" in O(1) without scanning every faction pair.
                                server:setValue("cw_corridor_at_" .. hx1 .. ":" .. hy1, hx2 .. ":" .. hy2)
                                server:setValue("cw_corridor_at_" .. hx2 .. ":" .. hy2, hx1 .. ":" .. hy1)
                                include("cosmicvaultdebug").info("Cosmic War", "[Cosmic War] A subspace corridor has torn open between (" .. hx1 .. ":" .. hy1 .. ") and (" .. hx2 .. ":" .. hy2 .. ").")

                                local CosmicVaultNews = include("cosmicvaultnews")
                                CosmicVaultNews.publishArticle({
                                    title = "Subspace Corridor Torn Open By War",
                                    content = "The sheer intensity of the conflict between " .. faction.name .. " and " .. enemyFaction.name .. " has torn a genuine subspace corridor between their home sectors -- a permanent, if dangerous, shortcut left behind by the war.",
                                    category = "War"
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end
