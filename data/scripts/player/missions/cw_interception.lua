package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

local MissionUT = include("missionut")
local ShipGenerator = include("shipgenerator")
local Balancing = include("galaxy")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Interception"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/crosshairs.png"
mission.data.autoTrackMission = true

local cw_interception_init = initialize
function initialize(factionIndex)
    if onServer() and not _restoring then
        -- Safely extract the argument passed from bulletinboard.lua
        local fIndex = factionIndex
        if type(factionIndex) == "table" then
            fIndex = factionIndex.giver or factionIndex[1]
        end

        local giverFaction = Faction(fIndex)
        if not giverFaction then
            terminate()
            return
        end

        -- Determine enemy faction via the active Cosmic War rivalry
        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        if enemyIndex == 0 then
            -- Fallback to local pirates if the rivalry decayed right after posting
            local x, y = Sector():getCoordinates()
            local pirateLevel = Balancing_GetPirateLevel(x, y)
            enemyIndex = Galaxy():getPirateFaction(pirateLevel).index
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.custom.enemyIndex = enemyIndex

        -- Find a nearby empty target sector
        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 12, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Intercept and destroy the supply convoy belonging to ${enemy}."%_T, arguments = { enemy = enemyName } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the convoy"%_T,                           bulletPoint = true, fulfilled = false, visible = false }
        }

        -- Establish reward based on current Cosmic War Heat level
        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        local baseReward = math.floor(25000 + heat * 50000)

        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 6000,
            paymentMessage = "Target destroyed. Contract payment transferred."%_T
        }

        cw_interception_init(factionIndex)
    else
        cw_interception_init(factionIndex)
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
        spawnConvoy(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    local giverFaction = Faction(mission.data.custom.giverIndex)
    if giverFaction then
        Player():sendChatMessage(giverFaction.name, 0, "We're tracking the convoy on your sensors. Take them out!"%_T)
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            -- Check if all ships spawned with our custom tracker are destroyed
            local targets = { Sector():getEntitiesByScriptValue("cw_interception_target") }
            return #targets == 0
        end,
        callback = function()
            finishAndReward()
        end
    }
}

function spawnConvoy(x, y)
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local numFreighters = random():getInt(1, 3)
    for i = 1, numFreighters do
        local pos = generator:createPositionInSector()
        local ship = ShipGenerator.createFreighterShip(enemyFaction, pos)

        -- Tag the ship so the trigger can track it
        ship:setValue("cw_interception_target", true)
        -- Prevent hyperspacing away immediately
        ship:addScriptOnce("ai/patrol.lua")
    end

    local numDefenders = random():getInt(2, 4)
    for i = 1, numDefenders do
        local pos = generator:createPositionInSector()
        local ship = ShipGenerator.createDefender(enemyFaction, pos)

        ship:setValue("cw_interception_target", true)
        ShipAI(ship.index):setAggressive()
    end
end

function finishAndReward()
    reward()
    accomplish()
end
