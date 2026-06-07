package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local Balancing = include("galaxy")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Resource Sabotage"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

local cw_sabotage_init = initialize
function initialize(factionIndex)
    if onServer() and not _restoring then
        local fIndex = factionIndex
        if type(factionIndex) == "table" then
            fIndex = factionIndex.giver or factionIndex[1]
        end

        local giverFaction = Faction(fIndex)
        if not giverFaction then
            terminate()
            return
        end

        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        if enemyIndex == 0 then
            local x, y = Sector():getCoordinates()
            local pirateLevel = Balancing_GetPirateLevel(x, y)
            enemyIndex = Galaxy():getPirateFaction(pirateLevel).index
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.custom.enemyIndex = enemyIndex

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 3, 12, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a sabotage contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "A mining fleet from ${enemy} has set up an extraction operation. Wipe them out."%_T, arguments = { enemy = enemyName } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the mining operation"%_T,                 bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        mission.data.custom.heat = heat

        local baseReward = math.floor(25000 + heat * 40000)

        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 5000,
            paymentMessage =
            "Mining operation destroyed. That will surely put a dent in their supply lines. Payment transferred."%_T
        }

        cw_sabotage_init(factionIndex)
    else
        cw_sabotage_init(factionIndex)
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
        spawnMiningOp(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function() 
            local targets = { Sector():getEntitiesByScriptValue("cw_sabotage_target") }
            return atTargetLocation() and mission.data.custom.spawned and #targets == 0 
        end,
        callback = function()
            reward()
            accomplish()
        end
    }
}

function spawnMiningOp(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    generator:createAsteroidField()

    local numTargets = math.floor(3 + ((mission.data.custom.heat or 0) * 5))
    for i = 1, numTargets do
        local ship = ShipGenerator.createMiningShip(enemyFaction, generator:getPositionInSector())
        ship:setValue("cw_sabotage_target", true)
    end
end

-- Added by Cosmic War for Avorion 2.0 Compatibility
function getBulletin(station)
    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    end
    if heat < 0.35 then return end

    return {
        brief = "War Contract: Resource Sabotage"%_T,
        description = "A hostile mining operation is extracting resources in contested space. Put an end to it."%_T,
        difficulty = "Extreme"%_T,
        script = "data/scripts/player/missions/cw_resourcesabotage.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        arguments = { { giver = station.factionIndex } },
        msg = "Crippling their resource flow now will save our fleets later. Destroy those miners."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
