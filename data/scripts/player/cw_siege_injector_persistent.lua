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
                    -- Attach the siege event to the sector safely
                    sector:addScriptOnce("data/scripts/events/siegeevent.lua")
                    -- Note: addScriptOnce doesn't guarantee the script wasn't already there, 
                    -- so we invoke initialize just in case it's newly added. Wait, actually, 
                    -- if it already exists, invoking initialize might reset it. Let's just leave
                    -- invokeFunction out if addScriptOnce handles it natively, or check manually.
                    -- Avorion automatically calls initialize() when a script is added.

                end
            end
        end
    end
end
