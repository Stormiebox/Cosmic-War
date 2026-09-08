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
    end
end
