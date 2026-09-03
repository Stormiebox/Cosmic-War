package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Sensor Deployment"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipRecon.png"
mission.data.autoTrackMission = true

local cw_init = initialize
function initialize(factionIndex)
    if onServer() and not _restoring then
        local fIndex = factionIndex
        local precomputedReward = nil
        if type(factionIndex) == "table" then
            fIndex = factionIndex.giver or factionIndex[1]
            precomputedReward = factionIndex.reward
        end

        local giverFaction = Faction(fIndex)
        if not giverFaction then terminate() return end

        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        if enemyIndex == 0 then
            local x, y = Sector():getCoordinates()
            local pirateLevel = Balancing_GetPirateLevel(x, y)
            enemyIndex = Galaxy():getPirateFaction(pirateLevel).index
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
        end

        local x, y = Sector():getCoordinates()
        
        local targets = {}
        for i = 1, 3 do
            local tx, ty
            local valid = false
            for attempt = 1, 50 do
                tx, ty = MissionUT.getSector(x, y, 2, 12, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
                if tx and ty then
                    local isDuplicate = false
                    for _, t in pairs(targets) do
                        if t.x == tx and t.y == ty then
                            isDuplicate = true
                            break
                        end
                    end
                    if not isDuplicate then
                        valid = true
                        break
                    end
                end
            end
            if valid then
                table.insert(targets, {x = tx, y = ty})
            end
        end

        if #targets < 3 then terminate() return end

        mission.data.custom.targets = targets
        mission.data.custom.deployedCount = 0
        mission.data.location = { x = targets[1].x, y = targets[1].y }

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Deploy deep-space sensor buoys in 3 enemy sectors to monitor their fleet movements."%_T },
            { text = "Head to sector (${location.x}:${location.y})"%_T, arguments = { location = mission.data.location }, bulletPoint = true, fulfilled = false },
            { text = "Deploy the buoy at the exact center (0, 0, 0). (Fly within 500m)"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(100000 + heat * 125000)

        mission.data.reward = precomputedReward or {
            -- giverFaction is already resolved and confirmed non-nil above.
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 10000,
            paymentMessage = "All sensors deployed. We are receiving the telemetry now. Payment transferred."%_T
        }

        cw_init(factionIndex)
    else
        cw_init(factionIndex)
    end
end

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true

mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    
    local custom = mission.data.custom
    local key = "spawned_" .. tostring(x) .. "_" .. tostring(y)
    if not custom[key] then
        spawnEvent(x, y)
        custom[key] = true
    end
    sync()
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() then return false end
            
            local player = Player()
            if not player then return false end
            local craft = player.craft
            if not craft then return false end
            
            if length(craft.translationf) <= 500 then
                local x, y = Sector():getCoordinates()
                local key = "deployed_" .. tostring(x) .. "_" .. tostring(y)
                if not mission.data.custom[key] then
                    mission.data.custom[key] = true
                    return true
                end
            end
            
            return false
        end,
        callback = function()
            local x, y = Sector():getCoordinates()
            local generator = SectorGenerator(x, y)
            local faction = Faction(mission.data.custom.giverIndex)
            
            local buoy = generator:createStation(faction, nil)
            buoy.title = "Deep-Space Sensor Buoy"%_T
            
            local player = Player()
            if player then
                player:sendChatMessage(faction.name, 0, "Sensor buoy deployed successfully."%_T)
            end
            
            mission.data.custom.deployedCount = mission.data.custom.deployedCount + 1
            if mission.data.custom.deployedCount >= 3 then
                mission.data.description[4].fulfilled = true
                sync()
                reward()
                accomplish()
            else
                local nextTarget = mission.data.custom.targets[mission.data.custom.deployedCount + 1]
                mission.data.location = {x = nextTarget.x, y = nextTarget.y}
                mission.data.description[3].arguments = { location = mission.data.location }
                mission.data.description[3].fulfilled = false
                mission.data.description[4].visible = false
                sync()
            end
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    
    -- Spawn Navigation Beacon at 0,0,0
    local beacon = generator:createBeacon(Matrix(), nil, "Deploy Sensor Buoy Here"%_T)
    beacon:setValue("cw_buoy_target", true)
    
    -- Spawn some defenders near the center
    for i=1, 3 do
        local position = MatrixLookUpPosition(-vec3(0,1,0), vec3(1,0,0), vec3(random():getInt(-2000, 2000), random():getInt(-2000, 2000), random():getInt(-2000, 2000)))
        local ship = ShipGenerator.createMilitaryShip(enemyFaction, position)
        ship:addScriptOnce("data/scripts/entity/ai/patrol.lua")
        ship.title = "Sector Patrol"%_T
        
        local ai = ShipAI(ship.index)
        ai:setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.15 then return end

    local baseReward = math.floor(100000 + heat * 125000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "All sensors deployed. We are receiving the telemetry now. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Sensor Deployment"%_t,
        description = "We need greater visibility into enemy territory. We are contracting you to jump into 3 specific hostile sectors and drop stealth sensor buoys at their exact center coordinates (0, 0, 0). Expect heavy resistance.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Medium"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_sensor_deployment.lua",
        icon = "data/textures/icons/ShipRecon.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Get those sensors in place, pilot. Dismissed."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end

local cw_mission_abandon_original = mission.abandon
mission.abandon = function()
    if onServer() then
        local player = Player()
        local giverIndex = mission.data.custom.giverIndex
        if giverIndex and giverIndex > 0 then
            CosmicVaultFaction.changeRelations(player.index, giverIndex, -25000)
            local giverFaction = Faction(giverIndex)
            local giverName = giverFaction and giverFaction.name or "Unknown"%_T
            player:sendChatMessage(giverName, 1, "You abandoned a critical war contract! Our trust in you is broken."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end

