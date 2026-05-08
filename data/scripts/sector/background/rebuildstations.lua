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
        -- If a faction has a non-zero rebuild throttle timestamp, clear it so station reconstruction
        -- in active conflict areas can recover faster from repeated destruction.
        if RebuildStations.specsFactionIndex then
            local f = Faction(RebuildStations.specsFactionIndex)
            if f then
                local ts = f:getValue("rebuild_stations_timestamp")
                if ts and ts > 1 then
                    f:setValue("rebuild_stations_timestamp", 0)
                end
            end
        end

        return cw_oldUpdateServer(timeStep)
    end
end
