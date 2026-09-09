package.path = package.path .. ";data/scripts/lib/?.lua"
local CosmicVaultTerritory = include("cosmicvaultterritory")

-- namespace CW_SiegeInjectorPersistent
CW_SiegeInjectorPersistent = CW_SiegeInjectorPersistent or {}

function CW_SiegeInjectorPersistent.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function CW_SiegeInjectorPersistent.onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        -- PROGRESSIVE MATERIALIZATION (Lag Fix)
        -- Check if this sector was mathematically conquered in the background
        local pendingFlips = Server():getValue("CosmicVault_PendingFlips") or ""
        -- Boundary-anchored token scan: e.g. prefix "5__10__" is a substring of entry
        -- "25__10__3,", so a raw string.find/match against the whole list can lock onto
        -- a neighboring sector's entry. Splitting on "," first and comparing each token's
        -- own leading prefix keeps the match confined to that sector's own entry.
        local prefix = x .. "__" .. y .. "__"
        local factionStr = nil
        local remaining = {}

        for entry in string.gmatch(pendingFlips, "([^,]+)") do
            if not factionStr and string.sub(entry, 1, #prefix) == prefix then
                factionStr = string.sub(entry, #prefix + 1)
            else
                table.insert(remaining, entry)
            end
        end

        if factionStr then
            local factionIndex = tonumber(factionStr)

            -- Captured before the flip below overwrites it -- the pre-flip controlling
            -- faction is the defender who just lost this sector.
            local previousController = Galaxy():getControllingFaction(x, y)

            Server():setValue("CosmicVault_PendingFlips", table.concat(remaining, ",") .. (#remaining > 0 and "," or ""))

            -- Trigger the flip natively
            Galaxy():invokeFunction("data/scripts/server/cosmicvaultterritory_server.lua", "flipSectorTerritory", x, y, factionIndex)

            -- v4.0.0 Expansion Momentum -- same boost as a physical siege win
            -- (trooptransport.lua), applied here too since a background-resolved siege
            -- is just as real a conquest. See cosmicwarexpansion.lua.
            Server():setValue("cw_expansion_momentum_" .. tostring(factionIndex), Server().unpausedRuntime + 86400)

            -- v4.0.0 War Score: same territory-swing credit as a physical siege win.
            if previousController and previousController.index ~= factionIndex then
                include("cosmicwarbridge").recordWarScoreTerritory(previousController.index, factionIndex)
            end
        end

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
        local controllingFaction = Galaxy():getControllingFaction(x, y)
        if controllingFaction and controllingFaction.isAIFaction then
            local flaggedSector = controllingFaction:getValue("cw_defense_generator_sector")
            if flaggedSector == (x .. ":" .. y) then
                local sector = Sector()
                if sector then
                    local alreadyPresent = false
                    for _, station in pairs({sector:getEntitiesByType(EntityType.Station)}) do
                        if station:hasScript("cw_planetary_defense.lua") then
                            alreadyPresent = true
                            break
                        end
                    end

                    if not alreadyPresent then
                        local SectorGenerator = include("SectorGenerator")
                        local station = SectorGenerator(x, y):createStation(controllingFaction, "data/scripts/entity/merchants/militaryoutpost.lua")
                        station:setTitle("Planetary Defense Generator"%_T, {})
                        station:addScriptOnce("data/scripts/entity/cw_planetary_defense.lua")
                    end
                end
            end
        end

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
