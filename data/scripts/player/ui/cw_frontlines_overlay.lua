package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")

-- namespace CW_FrontlinesOverlay
CW_FrontlinesOverlay = {}

-- v4.0.0 Frontlines: a galaxy map overlay highlighting the sectors where two
-- warring AI factions' territories actually meet. Purely additive -- GalaxyMap()'s own
-- setHighlightedSectors/removeHighlightedArea are the same keyed-overlay mechanism vanilla's
-- own player/map/mapcommandareas.lua uses for ship command areas, confirmed via that file
-- and the API stubs; this never touches or overrides that file.

local activeKeys = {}
local refreshTimer = 0
local REFRESH_INTERVAL = 30 -- seconds between refreshes while the map stays open

function CW_FrontlinesOverlay.initialize()
    if onServer() then return end
    Player():registerCallback("onShowGalaxyMap", "onShowGalaxyMap")
    Player():registerCallback("onGalaxyMapUpdate", "onGalaxyMapUpdate")
end

function CW_FrontlinesOverlay.onShowGalaxyMap()
    if onServer() then return end
    refreshTimer = 0
    invokeServerFunction("requestFrontlines")
end

function CW_FrontlinesOverlay.onGalaxyMapUpdate(timeStep)
    if onServer() then return end
    refreshTimer = refreshTimer + timeStep
    if refreshTimer >= REFRESH_INTERVAL then
        refreshTimer = 0
        invokeServerFunction("requestFrontlines")
    end
end

function CW_FrontlinesOverlay.receiveFrontlines(frontlinePairs)
    if onServer() then return end
    local map = GalaxyMap()

    for _, key in pairs(activeKeys) do
        map:removeHighlightedArea(key)
    end
    activeKeys = {}

    if not frontlinePairs then return end

    for _, entry in pairs(frontlinePairs) do
        if entry.sectors and #entry.sectors > 0 then
            local highlighted = {}
            -- Translucent red fill, solid red border -- reads as "contested" without
            -- fighting for attention against the vanilla faction-color layer underneath.
            highlighted.borderColor = "80c0392b"
            for _, s in pairs(entry.sectors) do
                table.insert(highlighted, {x = s.x, y = s.y, color = "30c0392b"})
            end

            local key = "cw_frontline_" .. entry.pairKey
            map:setHighlightedSectors(highlighted, key)
            table.insert(activeKeys, key)
        end
    end
end

function CW_FrontlinesOverlay.requestFrontlines()
    if not onServer() then return end
    local player = Player(callingPlayer)
    if not player then return end

    local CosmicWarBridge = include("cosmicwarbridge")
    invokeClientFunction(player, "receiveFrontlines", CosmicWarBridge.getFrontlinePairs())
end
callable(CW_FrontlinesOverlay, "requestFrontlines")
