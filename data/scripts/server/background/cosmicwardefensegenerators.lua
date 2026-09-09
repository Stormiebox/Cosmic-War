package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicWarBridge = include("cosmicwarbridge")
include("cosmicwarconfig")
include("randomext")

-- namespace CosmicWarDefenseGenerators
CosmicWarDefenseGenerators = {}

function CosmicWarDefenseGenerators.getUpdateInterval()
    return 30 * 60 -- Run every 30 minutes
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

-- v4.0.0: gives Planetary Defense Generators (cw_planetary_defense.lua) an
-- actual way to exist. The script itself was always correct, but nothing anywhere ever
-- attached it to a station -- documented in the in-game Codex and PLAYER_GUIDE.md as a
-- real siege mechanic no player could ever actually encounter. A faction under meaningful
-- threat (War Heat >= 0.35) now has a rolling per-pass chance to commission one at its own
-- home sector. Only the flag is set here -- the actual station entity is deferred and
-- materialized the first time any player physically enters that sector
-- (cw_siege_injector_persistent.lua), the same lazy-materialization pattern this mod
-- already uses for background-resolved sieges, so this pass never has to load a sector
-- just to place a station in it.
function CosmicWarDefenseGenerators.update(timeStep)
    if not onServer() then return end

    local cfg = CosmicWarConfig.get() or {}
    local commissionChance = cfg.defenseGeneratorCommissionChance or 0.15

    local factions = getActiveFactions()
    for _, faction in pairs(factions) do
        if not faction:getValue("cw_defense_generator_sector") then
            local heat = CosmicWarBridge.getFactionWarHeat(faction.index) or 0
            if heat >= 0.35 and random():test(commissionChance) then
                local hx, hy = faction:getHomeSectorCoordinates()
                if hx and hy then
                    faction:setValue("cw_defense_generator_sector", hx .. ":" .. hy)
                    include("cosmicvaultdebug").info("Cosmic War", "[Cosmic War] Faction " .. tostring(faction.index) .. " commissioned a Planetary Defense Generator at (" .. hx .. ":" .. hy .. ").")

                    local cv_news = include("cosmicvaultnews")
                    cv_news.publishArticle({
                        title = tostring(faction.name) .. " Commissions Planetary Defense Generator",
                        content = "Facing mounting pressure, " .. tostring(faction.name) .. " has commissioned a Planetary Defense Generator to shield their home sector at (" .. hx .. ":" .. hy .. ") from siege.",
                        category = "Military"
                    })
                end
            end
        end
    end
end
