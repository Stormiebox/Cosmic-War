package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

function getUpdateInterval()
    return 5.0
end


local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

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
        local precomputedReward = nil
        if type(factionIndex) == "table" then
            fIndex = factionIndex.giver or factionIndex[1]
            precomputedReward = factionIndex.reward
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
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
        end

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
            { text = "Locate the Covert Listening Post belonging to ${enemy}."%_T, arguments = { enemy = enemyName } },
            { text = "Head to sector (${location.x}:${location.y})"%_T,                   bulletPoint = true, fulfilled = false },
            { text = "Fly within 15km of the Listening Post to establish a passive data link (No active scanner module required)"%_T, bulletPoint = true, fulfilled = false, visible = false },
            { text = "Data Link Progress: ${percent}%"%_T, arguments = { percent = "0" }, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        local baseReward = math.floor(75000 + heat * 100000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
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
    local cv_news = include("cosmicvaultnews")
    cv_news.publishArticle(article)

    reward()
end

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true

mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true

    if not mission.data.custom.spawned then
        spawnReconTarget(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end
    if mission.data.custom.finished then return end

    local giverFaction = Faction(mission.data.custom.giverIndex)

    local _raw_targets = { Sector():getEntitiesByScriptValue("cw_recon_target") }

    local targets = {}

    for _, _t in pairs(_raw_targets) do

        if _t.type == EntityType.Ship or _t.type == EntityType.Station then

            table.insert(targets, _t)

        end

    end
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

    -- 1500 units is roughly 15km
    if dist < 1500 then
        if not mission.data.custom.scanning then
            mission.data.custom.scanning = true
            if giverFaction then
                Player():sendChatMessage(giverFaction.name, 3,
                    "You are in range. Establishing passive data link... Stay within 15km!"%_T)
            end
        end

        mission.data.custom.scanTimer = (mission.data.custom.scanTimer or 0) + timeStep
        local percent = math.floor((mission.data.custom.scanTimer / 45.0) * 100)
        mission.data.description[5].arguments = { percent = tostring(percent) }
        sync()

        if mission.data.custom.scanTimer > 45 then
            mission.data.custom.finished = true
            mission.data.description[5].arguments = { percent = "100" }
            mission.data.description[5].fulfilled = true
            sync()
            finishAndReward()
            accomplish()
        end
    else
        if mission.data.custom.scanning then
            mission.data.custom.scanning = false
            if giverFaction then
                Player():sendChatMessage(giverFaction.name, 1,
                    "Data link lost! You are too far away from the station! Return to 15km range."%_T)
            end
        end
    end
end

function spawnReconTarget(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local station = generator:createStation(enemyFaction, "data/scripts/entity/merchants/militaryoutpost.lua")
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
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.15 then return end

    local baseReward = math.floor(75000 + heat * 100000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 3000,
        paymentMessage = "Data received loud and clear. Good work out there, captain. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Force Recon"%_t,
        description = "Tensions are rising. We need a discreet captain to scout a hostile sector and gather intel.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Extreme"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_forcerecon.lua",
        icon = "data/textures/icons/ShipRecon.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "This is a reconnaissance operation. Get in, gather the intel, and get out in one piece."%_T,
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
            CosmicVaultFaction.changeRelations(player.index, giverIndex, -25000)
            local giverFaction = Faction(giverIndex)
            local giverName = giverFaction and giverFaction.name or "Unknown"%_T
            player:sendChatMessage(giverName, 1, "You abandoned a critical war contract! Our trust in you is broken."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
