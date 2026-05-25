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
mission._Name = "War Contract: High-Value Extraction"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/escort.png"
mission.data.autoTrackMission = true

local cw_extraction_init = initialize
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
            terminate()
            return
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.custom.enemyIndex = enemyIndex

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        mission.data.custom.heat = heat

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 3, 15, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a classified extraction contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "A high-ranking officer from ${enemy} is attempting to defect."%_T, arguments = { enemy = enemyName } },
            { text = "Rendezvous at sector (${location.x}:${location.y})"%_T,  bulletPoint = true, fulfilled = false },
            { text = "Protect the defector until their hyperdrive charges"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        -- Extremely high base reward due to the heat requirement
        local baseReward = math.floor(150000 + heat * 150000)

        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 18000,
            paymentMessage =
            "Target secured. You have struck a massive blow to the enemy command structure. Payment transferred."%_T
        }

        cw_extraction_init(factionIndex)
    else
        cw_extraction_init(factionIndex)
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
        spawnDefector(x, y)
        mission.data.custom.spawned = true
        mission.data.custom.jumpTimer = 0
        -- First wave spawns very quickly
        mission.data.custom.waveTimer = 35
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    local giverFaction = Faction(mission.data.custom.giverIndex)
    if giverFaction then
        Player():sendChatMessage(giverFaction.name, 0,
            "Thank goodness you arrived. My hyperdrive is damaged and needs 3 minutes to spool up. Don't let them take me!"%_T)
    end
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end
    if mission.data.custom.finished then return end

    local defectorShips = { Sector():getEntitiesByScriptValue("cw_defector") }

    if #defectorShips == 0 then
        local giverFaction = Faction(mission.data.custom.giverIndex)
        if giverFaction then
            Player():sendChatMessage(giverFaction.name, 1,
                "The defector's signal was lost... The mission is a failure."%_T)
        end
        fail()
        return
    end

    mission.data.custom.jumpTimer = (mission.data.custom.jumpTimer or 0) + timeStep
    mission.data.custom.waveTimer = (mission.data.custom.waveTimer or 0) + timeStep

    -- Give a 60 second warning
    if mission.data.custom.jumpTimer > 120 and not mission.data.custom.warned then
        mission.data.custom.warned = true
        Player():sendChatMessage(Faction(mission.data.custom.giverIndex).name, 0,
            "Hold them off! Hyperdrive is at 60 seconds!"%_T)
    end

    -- Defector jumps out after 3 minutes (180 seconds)
    if mission.data.custom.jumpTimer > 180 then
        mission.data.custom.finished = true

        for _, ship in pairs(defectorShips) do
            ship:addScript("ai/jumpout.lua")
        end

        finishAndReward()
    end

    -- Spawn hunters every 45 seconds
    if mission.data.custom.waveTimer > 45 then
        mission.data.custom.waveTimer = 0
        spawnHunters()
    end
end

function spawnDefector(x, y)
    local generator = SectorGenerator(x, y)
    local giverFaction = Faction(mission.data.custom.giverIndex)

    local pos = generator:createPositionInSector()
    local ship = ShipGenerator.createDefender(giverFaction, pos)

    ship:setValue("cw_defector", true)
    ship:setTitle("Defecting Officer"%_T, {})
end

function spawnHunters()
    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    local heat = mission.data.custom.heat or 0
    local numEnemies = math.floor(3 + (heat * 3))

    for i = 1, numEnemies do
        local pos = generator:createPositionInSector(1500)
        local ship = ShipGenerator.createDefender(enemyFaction, pos)
        ShipAI(ship):setAggressive()
    end

    Player():sendChatMessage(enemyFaction.name, 1, "There is the traitor! Execute them immediately!"%_T)
end

function finishAndReward()
    reward()
    accomplish()
end
