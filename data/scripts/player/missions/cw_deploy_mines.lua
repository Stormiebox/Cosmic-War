package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Deploy Minefield"

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

        local x, y = Sector():getCoordinates()
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Travel to the contested sector at (${location.x}:${location.y}) and deploy 5 tactical mines to deny enemy movement."%_T, arguments = { location = mission.data.location } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge and CosmicWarBridge.getFactionWarHeat and CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        -- Huge buff for v3.0.0
        local baseReward = math.floor(100000 + heat * 150000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
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
    end
end

function getUpdateInterval()
    return 1.0
end

mission.phases[1].triggers = {
    {
        condition = function()

            if onClient() then return false end
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end
            
            mission.data.custom.minesDeployed = (mission.data.custom.minesDeployed or 0) + 1
            if mission.data.custom.minesDeployed % 10 == 0 then
                local player = Player()
                if player then player:sendChatMessage("", 3, "Deploying mine " .. (mission.data.custom.minesDeployed / 10) .. "/5...") end
            end
            
            return mission.data.custom.minesDeployed >= 50

        end,
        callback = function()
            reward()
            accomplish()
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    mission.data.custom.minesDeployed = 0

end

function getBulletin(station)
    local heat = CosmicWarBridge and CosmicWarBridge.getFactionWarHeat and CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.25 then return end

    local baseReward = math.floor(100000 + heat * 150000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing.GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "Contract fulfilled. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Deploy Minefield"%_T,
        description = "Travel to the contested sector at (${location.x}:${location.y}) and deploy 5 tactical mines to deny enemy movement."%_T,
        difficulty = "Extreme"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_deploy_mines.lua",
        icon = "data/textures/icons/ShipRecon.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Set up a minefield and lock down that sector."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end

-- Added by Cosmic War v3.0.0: Massive reputation penalty on abandoning a War Contract
local cw_mission_abandon_original = mission.abandon
mission.abandon = function()
    if onServer() then
        local player = Player()
        local giverIndex = mission.data.custom.giverIndex
        if giverIndex and giverIndex > 0 then
            local rep = player:getRelations(giverIndex)
            Galaxy():setFactionRelations(Faction(player.index), Faction(giverIndex), math.max(-100000, rep - 25000))
            player:sendChatMessage(Faction(giverIndex).name, 1, "You abandoned a critical war contract! Our trust in you is broken.")
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
