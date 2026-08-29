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
        local escapedPrefix = string.gsub(x .. "__" .. y .. "__", "%-", "%%-")
        local pattern = escapedPrefix .. "([%-%w]+),"
        local factionStr = string.match(pendingFlips, pattern)
        
        if factionStr then
            local factionIndex = tonumber(factionStr)
            local entryToRemove = x .. "__" .. y .. "__" .. factionStr .. ","
            local escapedEntry = string.gsub(entryToRemove, "%-", "%%-")
            Server():setValue("CosmicVault_PendingFlips", string.gsub(pendingFlips, escapedEntry, ""))
            
            -- Trigger the flip natively
            Galaxy():invokeFunction("data/scripts/server/cosmicvaultterritory_server.lua", "flipSectorTerritory", x, y, factionIndex)
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
