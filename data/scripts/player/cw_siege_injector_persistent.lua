package.path = package.path .. ";data/scripts/lib/?.lua"
local CosmicVaultTerritory = include("cosmicvaultterritory")
local DEFENSE_GENERATOR_SCRIPT = "data/scripts/entity/cw_planetary_defense.lua"
local DEFENSE_GENERATOR_STATION_SCRIPT = "data/scripts/entity/merchants/militaryoutpost.lua"
local DEFENSE_GENERATOR_PENDING_VALUE = "cw_defense_generator_pending"

-- namespace CW_SiegeInjectorPersistent
CW_SiegeInjectorPersistent = CW_SiegeInjectorPersistent or {}

local function flaggedOwner(x, y, expectedFactionIndex)
    local key = tostring(x) .. ":" .. tostring(y)

    if type(expectedFactionIndex) == "number" and expectedFactionIndex > 0 then
        local expected = Faction(expectedFactionIndex)
        if expected and expected.isAIFaction
                and expected:getValue("cw_defense_generator_sector") == key then
            return expected
        end
        return nil
    end

    local controlling = Galaxy():getControllingFaction(x, y)
    if controlling and controlling.isAIFaction
            and controlling:getValue("cw_defense_generator_sector") == key then
        return controlling
    end

    -- Influence can still be unresolved the first time an unexplored home sector
    -- loads. The commissioning flag is authoritative, so fall back to the same
    -- bounded faction registry used by the War background managers.
    local factionList = Server():getValue("factions")
    if type(factionList) == "string" then
        for rawIndex in string.gmatch(factionList, "([^,]+)") do
            local faction = Faction(tonumber(rawIndex))
            if faction and faction.isAIFaction
                    and faction:getValue("cw_defense_generator_sector") == key then
                return faction
            end
        end
    end
end

function CW_SiegeInjectorPersistent.materializeDefenseGenerator(x, y, expectedFactionIndex)
    if not onServer() then return nil, "server_only" end
    if type(x) ~= "number" or type(y) ~= "number" then return nil, "invalid_coordinates" end

    local sector = Sector()
    if not sector then return nil, "sector_unavailable" end
    local currentX, currentY = sector:getCoordinates()
    if currentX ~= x or currentY ~= y then return nil, "wrong_sector" end

    local owner = flaggedOwner(x, y, expectedFactionIndex)
    if not owner then return nil, "commission_missing" end

    for _, station in pairs({sector:getEntitiesByType(EntityType.Station)}) do
        if station.factionIndex == owner.index then
            if station:hasScript(DEFENSE_GENERATOR_SCRIPT) then
                station:setValue(DEFENSE_GENERATOR_PENDING_VALUE, nil)
                return true, nil, false
            elseif station:getValue(DEFENSE_GENERATOR_PENDING_VALUE) then
                -- addScriptOnce() is deferred. Reasserting it is safe and prevents a
                -- second station from being created while the first one's script is
                -- still waiting to initialize.
                station:addScriptOnce(DEFENSE_GENERATOR_SCRIPT)
                return true, nil, false
            end
        end
    end

    local SectorGenerator = include("SectorGenerator")
    local station = SectorGenerator(x, y):createStation(owner, DEFENSE_GENERATOR_STATION_SCRIPT)
    if not station then return nil, "station_creation_failed" end

    station:setTitle("Planetary Defense Generator"%_T, {})
    station:setValue(DEFENSE_GENERATOR_PENDING_VALUE, true)
    station:addScriptOnce(DEFENSE_GENERATOR_SCRIPT)
    return true, nil, true
end

function CW_SiegeInjectorPersistent.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function CW_SiegeInjectorPersistent.onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        -- When a player enters a sector, check if it's currently contested
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        if zones[key] then
            local sector = Sector()
            if sector then
                sector:addScriptOnce("data/scripts/events/siegeevent.lua")
            end
        end

        -- v4.0.0: PROGRESSIVE MATERIALIZATION for Planetary Defense
        -- Generators, same idea as the pending-flip check above -- cosmicwardefensegenerators.lua
        -- only ever sets a flag (no sector load required); the actual station entity is
        -- deferred until a player is physically here to see it appear.
        CW_SiegeInjectorPersistent.materializeDefenseGenerator(x, y)

        -- v4.0.0: Dynamic Wartime Subspace Corridors -- same lazy
        -- materialization idea as the Defense Generator above. cosmicwarsubspacecorridors.lua
        -- only ever flags a corridor pair; the actual wormhole entity here is created the
        -- first time a player is physically present at either endpoint.
        do
            local server = Server()
            local otherEndpoint = server and server:getValue("cw_corridor_at_" .. x .. ":" .. y)
            if otherEndpoint then
                local ox, oy = string.match(otherEndpoint, "(-?%d+):(-?%d+)")
                ox, oy = tonumber(ox), tonumber(oy)
                if ox and oy then
                    -- v4.0.0 fix: this used to check "is any EntityType.WormHole
                    -- present" as a proxy for "did I already materialize this
                    -- corridor?" -- but vanilla generation places wormholes in a great
                    -- many sectors regardless of this mod, so a faction home sector
                    -- with a pre-existing vanilla wormhole false-positived as "already
                    -- materialized" and silently never got its corridor endpoint,
                    -- after the news article announcing it had already gone out. A
                    -- dedicated per-sector marker, set only when THIS corridor actually
                    -- creates its own wormhole, is unambiguous regardless of what else
                    -- the sector contains.
                    local materializedKey = "cw_corridor_materialized_" .. x .. ":" .. y
                    if not server:getValue(materializedKey) then
                        local sector = Sector()
                        if sector then
                            sector:createWormHole(ox, oy, ColorRGB(0.6, 0.2, 1.0), 400)
                            sector:broadcastChatMessage("Unknown", 2, "Subspace readings spike -- a wartime corridor terminates here."%_T)
                            server:setValue(materializedKey, true)
                        end
                    end
                end
            end
        end
    end
end
