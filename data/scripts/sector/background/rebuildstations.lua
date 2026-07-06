package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarconfig")

function getUpdateInterval()
    return 60.0
end


-- namespace RebuildStations

if onServer() then
    local cw_oldUpdateServer = RebuildStations.updateServer

    function RebuildStations.updateServer(timeStep)
        if not cw_oldUpdateServer then return end

        local sector = Sector()
        if not sector then
            return cw_oldUpdateServer(timeStep)
        end

        -- Optimization tweak:
        -- In active war states only, reduce excessive rebuild throttle by lowering it to a near-term value,
        -- instead of forcing a full reset to zero each tick.
        local x, y = sector:getCoordinates()
        local controlling = Galaxy():getControllingFaction(x, y)
        local factions = { sector:getPresentFactions() }

        local factionMap = {}
        if controlling then factionMap[controlling.index] = controlling end
        for _, fIndex in pairs(factions) do
            if not factionMap[fIndex] then
                local f = Faction(fIndex)
                if f then factionMap[fIndex] = f end
            end
        end

        for _, f in pairs(factionMap) do
            if f.isAIFaction then
                local enemy = f:getValue("enemy_faction") or 0
                if enemy > 0 then
                    local ts = f:getValue("rebuild_stations_timestamp")
                    if ts and ts > 1 then
                        local server = Server()
                        local runtime = server and server.unpausedRuntime or 0
                        local cfg = CosmicWarConfig.get() or {}
                        local minSpacing = cfg.sectorPressureMinSpacing or 600
                        local targetTs = runtime + math.floor(minSpacing * 0.5)

                        -- only clamp down when current throttle is much farther out
                        if ts > targetTs then
                            f:setValue("rebuild_stations_timestamp", targetTs)
                        end
                    end
                end
            end
        end

        return cw_oldUpdateServer(timeStep)
    end
end

function updateServer(...)
    if RebuildStations.updateServer then return RebuildStations.updateServer(...) end
end
