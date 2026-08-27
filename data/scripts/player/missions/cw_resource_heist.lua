package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("sectorgenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Resource Heist"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
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

        local x, y = Sector():getCoordinates()
        mission.data.custom.giverCoords = {x = x, y = y}

        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
        end

        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }
        
        local d = length(vec2(targetX, targetY))
        local matType = MaterialType.Iron
        if d < 430 then matType = MaterialType.Titanium end
        if d < 350 then matType = MaterialType.Naonite end
        if d < 275 then matType = MaterialType.Trinium end
        if d < 150 then matType = MaterialType.Xanion end
        if d < 75 then matType = MaterialType.Ogonite end
        if d < 50 then matType = MaterialType.Avorion end
        
        local requiredMaterial = Material(matType)
        local materialAmount = math.random(5000, 15000)
        
        mission.data.custom.materialType = matType
        mission.data.custom.materialName = requiredMaterial.name
        mission.data.custom.materialAmount = materialAmount

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "We need you to disrupt enemy supply lines. Travel to sector (${location.x}:${location.y}), acquire ${amount} ${material}, and return here."%_T, arguments = { location = mission.data.location, amount = materialAmount, material = requiredMaterial.name } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(100000 + heat * 125000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 10000,
            paymentMessage = "Contract fulfilled. Payment transferred."%_T
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
    if not mission.data.custom.spawned then
        spawnEvent(x, y)
        mission.data.custom.spawned = true
        
        table.insert(mission.data.description, {
            text = "Return to sector (${x}:${y}) with ${amount} ${material}"%_T,
            arguments = { x = mission.data.custom.giverCoords.x, y = mission.data.custom.giverCoords.y, amount = mission.data.custom.materialAmount, material = mission.data.custom.materialName },
            bulletPoint = true,
            fulfilled = false
        })
        sync()
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not mission.data.custom.spawned then return false end
            
            local player = Player()
            local giverCoords = mission.data.custom.giverCoords
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount
            
            local resources = {player:getResources()}
            local current = resources[matType + 1] or 0
            
            local x, y = Sector():getCoordinates()
            
            if x == giverCoords.x and y == giverCoords.y and current >= requiredAmount then
                return true
            end
            
            return false
        end,
        callback = function()
            local player = Player()
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount
            
            player:payResource("Resource Heist complete", Material(matType), requiredAmount)
            
            reward()
            accomplish()
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    
    -- Spawn resource asteroid field
    generator:createAsteroidField(0.15)
    
    -- Spawn cargo ships to loot
    for i=1, 2 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createFreighterShip(enemyFaction, position)
        ship.title = "Resource Transport"
        ship:addScriptOnce("data/scripts/entity/ai/patrol.lua")
    end
    
    -- Spawn mining ships
    for i=1, 2 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createMiningShip(enemyFaction, position)
        ship.title = "Deep Space Miner"
        ship:addScriptOnce("data/scripts/entity/ai/mine.lua")
    end
    
    -- Spawn defenders
    for i=1, 3 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createDefender(enemyFaction, position)
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.35 then return end

    local baseReward = math.floor(100000 + heat * 125000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "Contract fulfilled. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Resource Heist"%_T,
        description = "Enemy logistics rely heavily on a nearby sector. We want you to go in there, disrupt their operations, and return with a haul of their resources. You can mine them from the sector or take them from destroyed transports.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Hard"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_resource_heist.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Bring those resources back to us. Dismissed."%_T,
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
            player:sendChatMessage(Faction(giverIndex).name, 1, "You abandoned a critical war contract! Our trust in you is broken.")
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
