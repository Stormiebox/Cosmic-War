package.path = package.path .. ";data/scripts/lib/?.lua"

local ShipGenerator = include("shipgenerator")
local CosmicVaultTerritory = include("cosmicvaultterritory")
local SectorGenerator = include("sectorgenerator")

local SiegeEvent = {}

function SiegeEvent.initialize()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    -- Check if this sector is currently contested
    if CosmicVaultTerritory and CosmicVaultTerritory.getContestedZones then
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        
        if zones[key] then
            -- Sector is contested! Spawn the invasion fleet.
            SiegeEvent.startSiege(zones[key])
        end
    end
end

function SiegeEvent.startSiege(zoneData)
    local sector = Sector()
    local targetStation = nil
    
    -- Find a valid target station owned by the defender
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, station in pairs(stations) do
        if station.factionIndex == zoneData.defender then
            targetStation = station
            break
        end
    end
    
    if not targetStation then
        print("[Cosmic War] No valid target station found for Siege Event.")
        return
    end

    local invadingFaction = Faction(zoneData.invader)
    if not invadingFaction then return end
    
    local generator = SectorGenerator(sector:getCoordinates())
    local position = generator:createPositionInSector(15000) -- Spawn far away
    
    sector:broadcastChatMessage(targetStation, ChatMessageType.Warning, "WARNING! Enemy Troop Transports detected entering the sector! Defend the station!"%_T)

    -- Spawn massive Troop Transports
    for i = 1, 3 do
        local volume = 15000 -- Massive corvette/transport size
        local transport = ShipGenerator.createFreighterShip(invadingFaction, position, volume)
        transport.title = "Troop Transport"
        transport.name = "Invader"
        transport:addScript("data/scripts/entity/ai/trooptransport.lua")
        transport:invokeFunction("trooptransport.lua", "setTarget", targetStation.id)
        
        -- Give them heavy shields but no weapons (abstracted)
        local shield = Shield(transport.id)
        if shield then
            shield.maximum = shield.maximum * 5 -- 5x shields to survive point defense
            shield.durability = shield.maximum
        end
        
        position = generator:createPositionInSector(15000)
    end
end

return SiegeEvent
