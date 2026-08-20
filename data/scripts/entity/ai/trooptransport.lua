package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")
local ShipUtility = include("shiputility")

-- namespace TroopTransport
TroopTransport = {}

TroopTransport.targetStationId = nil
TroopTransport.boardingProgress = 0
TroopTransport.boardingRequired = 60 -- 60 seconds to board
TroopTransport.isBoarding = false
TroopTransport.boardingMessageSent = false
function TroopTransport.getUpdateInterval()
    return 1.0
end

if onServer() then

function TroopTransport.setTarget(stationId)
    TroopTransport.targetStationId = stationId
end

function TroopTransport.updateServer(timeStep)
    local ship = Entity()
    if not valid(ship) then return end

    if not TroopTransport.targetStationId then
        -- Find a station belonging to the enemy
        local sector = Sector()
        local stations = {sector:getEntitiesByType(EntityType.Station)}
        local myFaction = ship.factionIndex
        local galaxy = Galaxy()

        for _, station in pairs(stations) do
            local stationFaction = station.factionIndex
            if galaxy:getFactionRelations(myFaction, stationFaction) < -80000 then
                TroopTransport.targetStationId = station.id
                break
            end
        end
    end

    if not TroopTransport.targetStationId then
        -- No target found, idle or leave
        local ai = ShipAI()
        ai:setIdle()
        return
    end

    local target = Entity(TroopTransport.targetStationId)
    if not valid(target) then
        TroopTransport.targetStationId = nil
        TroopTransport.isBoarding = false
        TroopTransport.boardingMessageSent = false
        return
    end

    local dist = distance(ship.translationf, target.translationf)

    if dist > 200 then
        -- Fly to target
        local ai = ShipAI()
        ai:setFlyLinear(target.translationf, 0, false)
        TroopTransport.isBoarding = false
        TroopTransport.boardingMessageSent = false
    else
        -- We are close enough, begin boarding!
        if TroopTransport.boardingRequired == 60 and target.maxDurability then
            TroopTransport.boardingRequired = math.min(300, 60 + (target.maxDurability / 100000))
        end

        TroopTransport.isBoarding = true
        TroopTransport.boardingProgress = TroopTransport.boardingProgress + timeStep

        -- Inform player if in sector
        local sector = Sector()
        if not TroopTransport.boardingMessageSent then
            TroopTransport.boardingMessageSent = true
            sector:broadcastChatMessage(ship, ChatMessageType.Warning, "Troop Transports have breached the hull of %s! Boarding in progress!"%_T, target.translatedTitle or "a station")
        end

        if TroopTransport.boardingProgress >= TroopTransport.boardingRequired then
            -- Boarding complete!
            TroopTransport.captureStation(target, ship.factionIndex)
            -- Self destruct the transport after successful boarding
            ship:destroy(ship.id)
        end
    end
end

function TroopTransport.captureStation(station, newFactionIndex)
    local oldFactionIndex = station.factionIndex
    station.factionIndex = newFactionIndex

    local sector = Sector()
    sector:broadcastChatMessage(station, ChatMessageType.Warning, "The station has been captured by enemy forces!"%_T)

    local x, y = sector:getCoordinates()
    local sectorName = "\\s(" .. x .. ":" .. y .. ")"
    local factionName = Faction(newFactionIndex) and Faction(newFactionIndex).name or "an Unknown Faction"

        -- In vanilla, the SectorView natively updates its influence when the sector saves/unloads.
        -- This natively expands the Galaxy Map border.
    -- Forcefully update the global Galaxy Map borders instantly so the players can watch the invasion spread in real time
    local galaxy = Galaxy()
    -- galaxy:setFaction(x, y, newFactionIndex) -- Removed: Map borders update natively when stations change hands

    include("cosmicvaultdebug").info("Cosmic War", "[Cosmic War] Station " .. station.name .. " captured by faction " .. tostring(newFactionIndex) .. ". Sector borders updated.")

    local CosmicVaultNews = include("cosmicvaultnews")
    CosmicVaultNews.publishArticle({
        title = "Territory Conquered",
        content = "The sector " .. sectorName .. " has been successfully annexed by " .. factionName .. " via ground assault. The galaxy borders have officially shifted.",
        category = "War"
    })
end

function TroopTransport.secure()
    return {
        targetStationId = TroopTransport.targetStationId and tostring(TroopTransport.targetStationId) or nil,
        boardingProgress = TroopTransport.boardingProgress,
        boardingRequired = TroopTransport.boardingRequired,
        isBoarding = TroopTransport.isBoarding,
        boardingMessageSent = TroopTransport.boardingMessageSent
    }
end

function TroopTransport.restore(data)
    TroopTransport.targetStationId = data.targetStationId and Uuid(data.targetStationId) or nil
    TroopTransport.boardingProgress = data.boardingProgress or 0
    TroopTransport.boardingRequired = data.boardingRequired or 60
    TroopTransport.isBoarding = data.isBoarding or false
    TroopTransport.boardingMessageSent = data.boardingMessageSent or false
end

end



return TroopTransport
