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
mission._Name = "War Contract: Force Recon"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipRecon.png"
mission.data.autoTrackMission = true

local cw_forcerecon_init = initialize
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
        local targetX, targetY = MissionUT.getSector(x, y, 2, 8, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a Force Recon contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Locate and scan the Covert Listening Post belonging to ${enemy}."%_T, arguments = { enemy = enemyName } },
            { text = "Head to sector (${location.x}:${location.y})"%_T,                   bulletPoint = true, fulfilled = false },
            { text = "Stay within 6km of the Listening Post until the scan completes"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        local baseReward = math.floor(15000 + heat * 20000)

        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 3000,
            paymentMessage = "Data received loud and clear. Good work out there, captain. Payment transferred."%_T
        }

        cw_forcerecon_init(factionIndex)
    else
        cw_forcerecon_init(factionIndex)
    end
end

function finishAndReward()
    local x, y = Sector():getCoordinates()
    local faction = Faction(mission.data.custom.enemyIndex)
    local article = {
        title = "Forward Outpost Obliterated",
        content = "Military intelligence confirms the total destruction of a fortified " .. (faction and faction.name or "unknown") .. " reconnaissance outpost in sector [" .. x .. ":" .. y .. "] following a surgical strike.",
        category = "War"
    }
    Server():sendCallback("onCCNewsPublishArticle", article)

    reward()
end

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true

mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if not mission.data.custom.spawned then
        spawnReconTarget(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end
    if mission.data.custom.finished then return end

    local giverFaction = Faction(mission.data.custom.giverIndex)

    local targets = { Sector():getEntitiesByScriptValue("cw_recon_target") }
    local station = targets[1]

    if not station then
        if giverFaction then
            Player():sendChatMessage(giverFaction.name, 1,
                "The Listening Post was destroyed before we could extract the intel! The contract is void."%_T)
        end
        fail()
        return
    end

    local craft = Player().craft
    if not craft then return end

    local dist = distance(craft.translationf, station.translationf)

    -- 600 units is roughly 6km
    if dist < 600 then
        if not mission.data.custom.scanning then
            mission.data.custom.scanning = true
            if giverFaction then
                Player():sendChatMessage(giverFaction.name, 0,
                    "You are in range. Establishing data link... Stay close!"%_T)
            end
        end

        mission.data.custom.scanTimer = (mission.data.custom.scanTimer or 0) + timeStep

        if mission.data.custom.scanTimer > 45 then
            mission.data.custom.finished = true
            reward()
            accomplish()
        end
    else
        if mission.data.custom.scanning then
            mission.data.custom.scanning = false
            if giverFaction then
                Player():sendChatMessage(giverFaction.name, 1,
                    "Data link lost! You are too far away from the station!"%_T)
            end
        end
    end
end

function spawnReconTarget(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local station = generator:createStation(enemyFaction, "data/scripts/entity/merchants/sensorarray.lua")
    station:setTitle("Covert Listening Post"%_T, {})
    station:setValue("cw_recon_target", true)

    local numDefenders = random():getInt(1, 3)
    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ShipAI(ship.index):setAggressive()
    end
end

-- Added by Cosmic War for Avorion 2.0 Compatibility
function getBulletin(station)
    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    end
    if heat < 0.15 then return end

    return {
        brief = "War Contract: Force Recon"%_T,
        description = "Tensions are rising. We need a discreet captain to scout a hostile sector and gather intel."%_T,
        difficulty = "Extreme"%_T,
        script = "data/scripts/player/missions/cw_forcerecon.lua",
        icon = "data/textures/icons/ShipRecon.png",
        arguments = { { giver = station.factionIndex } },
        msg = "This is a reconnaissance operation. Get in, gather the intel, and get out in one piece."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
