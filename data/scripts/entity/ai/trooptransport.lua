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

function TroopTransport.initialize(stationIdStr)
    -- addScriptOnce is deferred, so the caller can't invokeFunction("setTarget") back into
    -- us within the same tick it attaches this script. The target is passed straight through
    -- here instead. Uuid values don't cross the addScriptOnce boundary directly, so the caller
    -- sends the string form and we reconstruct it.
    if stationIdStr then
        TroopTransport.targetStationId = Uuid(stationIdStr)
    end
end

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
            sector:broadcastChatMessage(ship, ChatMessageType.Warning, "Troop Transports have breached the hull of %1%! Boarding in progress!"%_T, target.translatedTitle or "a station")
        end

        if TroopTransport.boardingProgress >= TroopTransport.boardingRequired then
            -- Boarding complete!
            TroopTransport.captureStation(target, ship.factionIndex)
            -- Self destruct the transport after successful boarding
            local pos = ship.translationf
            local radius = ship.radius or 50
            broadcastInvokeClientFunction("spawnExplosion", pos, radius)
            ship:destroy(ship.id)
        end
    end
end

function TroopTransport.captureStation(station, newFactionIndex)
    local oldFactionIndex = station.factionIndex
    station.factionIndex = newFactionIndex

    -- v4.0.0 Expansion Momentum: a faction that just won a siege gets a temporary boost
    -- to its own organic (Imperialist/Entrenched) expansion rolls -- see
    -- cosmicwarexpansion.lua. 24 in-game hours of unpausedRuntime.
    Server():setValue("cw_expansion_momentum_" .. tostring(newFactionIndex), Server().unpausedRuntime + 86400)

    -- v4.0.0 War Score: a captured station is a territory swing, weighted far above a
    -- single kill (see CosmicWarBridge.getWarScore).
    include("cosmicwarbridge").recordWarScoreTerritory(oldFactionIndex, newFactionIndex)

    -- v4.0.0 Occupation & Insurgency: a captured sector isn't instantly settled --
    -- for 6 in-game hours it's marked Occupied, giving the dispossessed faction
    -- (oldFactionIndex) a chance to harass the new owner with insurgent raiders
    -- (cosmicwarcontroller.lua's applyInsurgency) and softening the new owner's War
    -- Contract payouts from this sector in the meantime (CosmicWarBridge.
    -- getSectorRewardMultiplier). Layered strictly on top of the capture that already
    -- happens above -- this never blocks or delays the ownership flip itself, since
    -- reconquest already exists independently of this mechanic.
    if oldFactionIndex and oldFactionIndex > 0 and oldFactionIndex ~= newFactionIndex then
        local ox, oy = Sector():getCoordinates()
        -- unpausedRuntime is a double (Server.lua confirms it), so it renders with a
        -- decimal point far more often than not -- math.floor() before storing keeps this a
        -- plain integer string, which is what CosmicWarBridge.getOccupationData()'s parser
        -- actually expects. Sub-second precision on a 6-hour window is meaningless anyway.
        local endTime = math.floor(Server().unpausedRuntime + 21600)
        Server():setValue("cw_occupation_" .. ox .. ":" .. oy,
            tostring(oldFactionIndex) .. "," .. tostring(newFactionIndex) .. "," .. tostring(endTime))
    end

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

    -- v4.0.0: only a captured HOME sector is rare and significant enough to
    -- warrant the "breaking" flag -- an ordinary station falling happens too often across
    -- a large war to interrupt every player for (see cosmicvaultnews.lua's own warning
    -- against a "breaking" article every few minutes).
    local oldFaction = Faction(oldFactionIndex)
    local oldFactionName = oldFaction and oldFaction.name or "an Unknown Faction"
    local isHomeSector = false
    if oldFaction then
        local homeX, homeY = oldFaction:getHomeSectorCoordinates()
        isHomeSector = homeX == x and homeY == y
    end

    local CosmicVaultNews = include("cosmicvaultnews")
    CosmicVaultNews.publishArticle({
        title = isHomeSector and ("Home Sector Falls: " .. oldFactionName .. " Loses Their Capital") or "Territory Conquered",
        content = isHomeSector
            and ("In a devastating blow, " .. oldFactionName .. "'s home sector " .. sectorName .. " has fallen to " .. factionName .. " via ground assault. The galaxy borders have officially shifted.")
            or ("The sector " .. sectorName .. " has been successfully annexed by " .. factionName .. " via ground assault. The galaxy borders have officially shifted."),
        category = "War",
        breaking = isHomeSector
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




function TroopTransport.spawnExplosion(pos, radius)
    if onServer() then return end
    Sector():createExplosion(pos, radius, false)
end
callable(TroopTransport, "spawnExplosion")

