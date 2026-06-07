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
mission._Name = "War Contract: Border Skirmish"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipCombat.png"
mission.data.autoTrackMission = true

local cw_skirmish_init = initialize
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
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a skirmish contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Intercept and eliminate the border patrol belonging to ${enemy}."%_T, arguments = { enemy = enemyName } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the patrol"%_T,                           bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        mission.data.custom.heat = heat

        local baseReward = math.floor(20000 + heat * 30000)

        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 4000,
            paymentMessage = "Patrol eliminated. We will not be intimidated on our own borders. Payment transferred."%_T
        }

        cw_skirmish_init(factionIndex)
    else
        cw_skirmish_init(factionIndex)
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
        spawnSkirmish(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function() 
            if onClient() then return false end
            local targets = { Sector():getEntitiesByScriptValue("cw_skirmish_target") }
            return atTargetLocation() and mission.data.custom.spawned and #targets == 0 
        end,
        callback = function()
            local x, y = Sector():getCoordinates()
            local faction = Faction(mission.data.custom.giverIndex)
            local article = {
                title = "Border Skirmish Resolved",
                content = "A violent border patrol clash in sector [" .. x .. ":" .. y .. "] has been decisively ended by independent mercenaries fighting on behalf of " .. (faction and faction.name or "an unknown faction") .. ".",
                category = "War"
            }
            Server():sendCallback("onCCNewsPublishArticle", article)
            
            reward()
            accomplish()
        end
    }
}

function spawnSkirmish(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    local numDefenders = math.floor(3 + ((mission.data.custom.heat or 0) * 4))

    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship:setValue("cw_skirmish_target", true)
        ShipAI(ship.index):setAggressive()
    end
end

-- Added by Cosmic War for Avorion 2.0 Compatibility
function getBulletin(station)
    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    end
    if heat < 0.25 then return end

    return {
        brief = "War Contract: Border Skirmish"%_T,
        description = "Border disputes are getting violent. Intercept and eliminate an enemy border patrol."%_T,
        difficulty = "Extreme"%_T,
        script = "data/scripts/player/missions/cw_borderskirmish.lua",
        icon = "data/textures/icons/ShipCombat.png",
        arguments = { { giver = station.factionIndex } },
        msg = "Take out their patrol. We need to show them we won't be intimidated."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
