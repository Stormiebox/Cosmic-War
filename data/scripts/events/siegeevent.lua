package.path = package.path .. ";data/scripts/lib/?.lua"

local ShipGenerator = include("shipgenerator")
local CosmicVaultTerritory = include("cosmicvaultterritory")
local SectorGenerator = include("sectorgenerator")
include("galaxy")
include("randomext")

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
            
            for _, player in pairs({sector:getPlayers()}) do
                player:addScriptOnce("data/scripts/player/ui/cw_battlefieldhud.lua")
            end
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

    local x, y = sector:getCoordinates()
    
    -- Roll for Shield Jammer (35%)
    local random = Random(Seed(x .. y))
    local usedJammer = false
    if random:test(0.35) then
        usedJammer = true
        local shipsAndStations = {sector:getEntitiesByType(EntityType.Ship)}
        for _, s in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            table.insert(shipsAndStations, s)
        end
        for _, ent in pairs(shipsAndStations) do
            if ent.factionIndex ~= zoneData.invader and ent.factionIndex > 0 then
                -- Exclude Planetary Defense Generators from Electronic Warfare
                if not ent:hasScript("cw_planetary_defense.lua") then
                    ent:addScriptOnce("data/scripts/entity/debuffs/cw_shieldjammer.lua")
                end
            end
        end
    end

    if usedJammer then
        sector:broadcastChatMessage(invadingFaction.name, ChatMessageType.Warning,
            "Target locked. Electronic warfare initialized. Suppressing all sector shields."%_T)
    end

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
    
    -- Dynamic Scaling: Spawn Siege Dreadnoughts to escort the transports
    local cvScalingSuccess, CosmicVaultScaling = true, include("cosmicvaultscaling")
    if cvScalingSuccess and CosmicVaultScaling then
        local defenderStats = CosmicVaultScaling.calculateSectorDefenderStrength(zoneData.invader)
        local baseVol = Balancing_GetSectorShipVolume(x, y)
        
        local spawnParams = CosmicVaultScaling.calculateInvaderSpawnParams(defenderStats, baseVol, 1.0)
        local numDreadnoughts = math.max(1, spawnParams.count - 3) -- We already spawned 3 transports
        local volumeMult = spawnParams.volumeMultiplier
        
        for i = 1, numDreadnoughts do
            local dreadnought = ShipGenerator.createMilitaryShip(invadingFaction, generator:createPositionInSector(15000), baseVol * volumeMult)
            dreadnought.title = "Siege Dreadnought"
            dreadnought.name = "Invader"
            ShipAI(dreadnought.index):setAggressive()
            
            local dShield = Shield(dreadnought.id)
            if dShield then
                dShield.maximum = dShield.maximum * 10
                dShield.durability = dShield.maximum
            end
        end
    end
    
    -- Inject Eclipse Weather
    if invadingFaction.name == "The Eclipse" or invadingFaction:getValue("is_eclipse") then
        sector:addScriptOnce("data/scripts/sector/cv_weather_controller.lua", "DarkMatterFog", -1)
    end
end

function SiegeEvent.getUpdateInterval()
    return 2.0
end

function SiegeEvent.updateServer(timeStep)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    if CosmicVaultTerritory and CosmicVaultTerritory.getContestedZones then
        local zones = CosmicVaultTerritory.getContestedZones()
        local key = x .. "_" .. y
        local zone = zones[key]

        if zone then
            -- Check if there are any invader troop transports left
            local invadersPresent = false
            local ships = {sector:getEntitiesByType(EntityType.Ship)}
            for _, ship in pairs(ships) do
                if ship.factionIndex == zone.invader and ship:hasScript("trooptransport.lua") then
                    invadersPresent = true
                    break
                end
            end
            
            -- If no transports are left and time hasn't run out yet, the defenders won!
            if not invadersPresent then
                -- Remove the zone so it doesn't trigger resolveSiege in the background
                zones[key] = nil
                Server():setValue("CosmicVault_ContestedZones", zones)
                
                sector:broadcastChatMessage("Server", ChatMessageType.Information, "Defense successful! The invading forces have been routed."%_t)
                
                for _, player in pairs({sector:getPlayers()}) do
                    player:invokeFunction("cw_battlefieldhud.lua", "triggerDefenseSuccess")
                end
                
                -- Terminate the event script as the siege is over
                terminate()
            else
                -- Invaders are still present. Check if defenders lost (no stations left)
                local defenderStations = 0
                for _, station in pairs({sector:getEntitiesByType(EntityType.Station)}) do
                    if station.factionIndex == zone.defender then
                        defenderStations = defenderStations + 1
                    end
                end
                
                -- Also check if Planetary Shield Generators are destroyed
                local planetaryShields = 0
                for _, station in pairs({sector:getEntitiesByType(EntityType.Station)}) do
                    if station:hasScript("cw_planetary_defense.lua") then
                        planetaryShields = planetaryShields + 1
                    end
                end
                
                if defenderStations == 0 and planetaryShields == 0 then
                    -- Defenders lost!
                    local cv_economy_success, cv_economy = true, require("cosmicvaulteconomy")
                    if cv_economy_success then
                        -- Losing a sector applies 20 famine score to the defender
                        cv_economy.addFamineScore(zone.defender, 20)
                        print("[Cosmic War] Faction " .. tostring(zone.defender) .. " lost a sector! Famine score increased.")
                    end
                    
                    zones[key] = nil
                    Server():setValue("CosmicVault_ContestedZones", zones)
                    terminate()
                end
            end
        else
            -- Zone no longer exists (maybe it was conquered)
            terminate()
        end
    end
end

function SiegeEvent.onRemove()
    -- Always clear Eclipse weather when the event ends, regardless of outcome
    local sector = Sector()
    if sector and sector:hasScript("sector/cv_weather_controller.lua") then
        sector:removeScript("sector/cv_weather_controller.lua")
    end
end

return SiegeEvent
