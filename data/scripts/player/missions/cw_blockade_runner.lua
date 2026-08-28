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
mission._Name = "War Contract: Blockade Runner"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipEscort.png"
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
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Deliver emergency supplies to our listening post blockaded in sector (${location.x}:${location.y})."%_T, arguments = { location = mission.data.location } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Fly within 2.5km of the Listening Post to deliver supplies"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(180000 + heat * 220000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 15000,
            paymentMessage = "Supplies delivered successfully. Payment transferred."%_T
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
    if not mission.data.custom.spawned then
        spawnEvent(x, y)
        mission.data.custom.spawned = true
    end
    sync()
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() or not mission.data.custom.spawned then return false end
            
            local player = Player()
            if not player then return false end
            local craft = player.craft
            if not craft then return false end
            
            local stations = {Sector():getEntitiesByType(EntityType.Station)}
            for _, station in pairs(stations) do
                if station:getValue("cw_blockade_runner_target") then
                    local distance = craft:getNearestDistance(station)
                    if distance <= 250 then
                        return true
                    end
                end
            end
            
            return false
        end,
        callback = function()
            mission.data.description[4].fulfilled = true
            sync()
            reward()
            accomplish()
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    -- Station
    local giverFaction = Faction(mission.data.custom.giverIndex)
    local station = generator:createStation(giverFaction, nil)
    station.title = "Covert Listening Post"%_T
    station.invincible = true
    station:setValue("cw_blockade_runner_target", true)

    -- Blockade
    for i=1, 6 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createMilitaryShip(enemyFaction, position)
        ship:addScriptOnce("data/scripts/entity/ai/patrol.lua")
        ship.title = "Blockade Defender"%_T
        
        local ai = ShipAI(ship.index)
        ai:setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.80 then return end

    local baseReward = math.floor(180000 + heat * 220000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 15000,
        paymentMessage = "Supplies delivered successfully. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Blockade Runner"%_T,
        description = "We have a deep-cover spy operating out of a hidden listening post deep inside hostile space. They are completely blockaded by the enemy and running out of supplies. Take this encrypted data drive and emergency supplies, break through the blockade, and deliver them.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Hard"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_blockade_runner.lua",
        icon = "data/textures/icons/ShipEscort.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Get those supplies through the blockade safely. Dismissed."%_T,
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

