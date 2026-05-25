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
mission._Name = "War Contract: Frontline Siege"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/combat.png"
mission.data.autoTrackMission = true

local cw_frontlinesiege_init = initialize
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
        local targetX, targetY = MissionUT.getSector(x, y, 4, 15, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a siege contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "${enemy} has established a Forward Operating Base (FOB) in a nearby sector."%_T, arguments = { enemy = enemyName } },
            { text = "Jump to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the Forward Operating Base"%_T,           bulletPoint = true, fulfilled = false, visible = false }
        }

        -- Massive payout. Scales up to 4x base depending on War Heat
        local baseReward = math.floor(75000 + heat * 225000)
        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 12000,
            paymentMessage = "Target destroyed. Excellent work, commander. Payment transferred."%_T
        }

        cw_frontlinesiege_init(factionIndex)
    else
        cw_frontlinesiege_init(factionIndex)
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
        spawnSiegeTarget(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if enemyFaction then
        Player():sendChatMessage(enemyFaction.name, 1, "We are under attack! Scramble all defenders!"%_T)
    end
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end

    mission.data.custom.waveTimer = (mission.data.custom.waveTimer or 0) + timeStep
    -- Spawn reinforcements every 2.5 minutes
    if mission.data.custom.waveTimer > 150 then
        mission.data.custom.waveTimer = 0
        spawnReinforcements()
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            local targets = { Sector():getEntitiesByScriptValue("cw_siege_target") }
            return #targets == 0
        end,
        callback = function()
            finishAndReward()
        end
    }
}

function spawnSiegeTarget(x, y)
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    -- Create a standard military base
    local station = generator:createMilitaryBase(enemyFaction)

    station:setTitle("Forward Operating Base"%_T, {})
    station:setValue("cw_siege_target", true)

    -- Scale HP based on War Heat
    local heat = mission.data.custom.heat or 0
    local hpMult = 1.0 + (heat * 3.0) -- Up to 4x Health at max heat

    station.durability = station.durability * hpMult
    station.maxDurability = station.maxDurability * hpMult

    if station.shieldDurability then
        station.shieldDurability = station.shieldDurability * hpMult
        station.shieldMaxDurability = station.shieldMaxDurability * hpMult
    end

    -- Spawn Initial defenders
    local numDefenders = math.floor(3 + (heat * 4))
    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:createPositionInSector())
        ShipAI(ship):setAggressive()
    end
end

function spawnReinforcements()
    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    local heat = mission.data.custom.heat or 0
    local numReinforcements = math.floor(1 + (heat * 2))

    for i = 1, numReinforcements do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:createPositionInSector())
        ShipAI(ship):setAggressive()
    end

    Player():sendChatMessage(enemyFaction.name, 1, "Reinforcements have arrived! Destroy the attackers!"%_T)
end

function finishAndReward()
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if enemyFaction then
        -- Strike a strategic blow by reducing their war bias slightly!
        local currentBias = enemyFaction:getValue("cw_war_bias") or 550
        enemyFaction:setValue("cw_war_bias", math.max(400, currentBias - 30))
    end

    reward()
    accomplish()
end
