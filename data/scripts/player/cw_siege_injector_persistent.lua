package.path = package.path .. ";data/scripts/lib/?.lua"
local CosmicVaultTerritory = include("cosmicvaultterritory")

function initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function onSectorEntered(playerIndex, x, y, sectorChangeType)
    if onServer() then
        -- When a player enters a sector, check if it's a contested zone
        if CosmicVaultTerritory and CosmicVaultTerritory.getContestedZones then
            local zones = CosmicVaultTerritory.getContestedZones()
            local key = x .. "_" .. y
            if zones[key] then
                -- Running in player/sector context, so Sector() is 100% legal here
                local sector = Sector()
                if sector then
                    -- Attach the siege event to the sector if it isn't already attached
                    if not sector:hasScript("events/siegeevent.lua") then
                        sector:addScript("data/scripts/events/siegeevent.lua")
                        sector:invokeFunction("events/siegeevent.lua", "initialize")
                    end
                end
            end
        end
    end
end
