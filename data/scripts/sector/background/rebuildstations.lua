package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarconfig")

-- namespace RebuildStations

if onServer() then
    local cw_oldUpdateServer = RebuildStations.updateServer

    function RebuildStations.updateServer(timeStep)
        if not cw_oldUpdateServer then return end

        local sector = Sector()
        if not sector then
            return cw_oldUpdateServer(timeStep)
        end

        -- Ensure specs are initialized before adjusting faction rebuild timestamp behavior.
        if not RebuildStations.specsInitialized then
            RebuildStations.initializeSpecs(sector:getCoordinates())
            RebuildStations.specsInitialized = true
        end

        -- Optimization tweak:
        -- In active war states only, reduce excessive rebuild throttle by lowering it to a near-term value,
        -- instead of forcing a full reset to zero each tick.
        if RebuildStations.specsFactionIndex then
            local f = Faction(RebuildStations.specsFactionIndex)
            if f then
                local enemy = f:getValue("enemy_faction") or 0
                if enemy > 0 then
                    local ts = f:getValue("rebuild_stations_timestamp")
                    if ts and ts > 1 then
                        local server = Server()
                        local runtime = server and server.unpausedRuntime or 0
                        local cfg = (CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get()) or {}
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
