package.path = package.path .. ";data/scripts/lib/?.lua"

local CosmicVaultTerritory = include("cosmicvaultterritory")

-- namespace CosmicWarSiegeServer
CosmicWarSiegeServer = {}

function CosmicWarSiegeServer.initialize()
    if onServer() then
        Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    end
end

function CosmicWarSiegeServer.onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    if player then
        player:registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function CosmicWarSiegeServer.onSectorEntered(playerIndex, x, y, sectorChangeType)
    -- When a player enters a sector, check if it's a contested zone
    if CosmicVaultTerritory and CosmicVaultTerritory.getContestedZones then
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        if zones[key] then
            local sector = Sector()
            -- Attach the siege event to the sector if it isn't already attached
            if not sector:hasScript("events/siegeevent.lua") then
                sector:addScript("data/scripts/events/siegeevent.lua")
                sector:invokeFunction("events/siegeevent.lua", "initialize")
            end
        end
    end
end


function initialize(...)
    if CosmicWarSiegeServer.initialize then return CosmicWarSiegeServer.initialize(...) end
end
function onPlayerLogIn(...)
    if CosmicWarSiegeServer.onPlayerLogIn then return CosmicWarSiegeServer.onPlayerLogIn(...) end
end
function onSectorEntered(...)
    if CosmicWarSiegeServer.onSectorEntered then return CosmicWarSiegeServer.onSectorEntered(...) end
end
