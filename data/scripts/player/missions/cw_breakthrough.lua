package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

function getUpdateInterval()
    return 1.0
end


local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Breakthrough"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipEscort.png"
mission.data.autoTrackMission = true

local cw_breakthrough_init = initialize
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
            terminate()
            return
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

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
            { text = "You accepted an escort contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Defend their supply convoy from ${enemy} interceptors."%_T, arguments = { enemy = enemyName } },
            { text = "Jump to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Protect the convoy until they jump"%_T,           bulletPoint = true, fulfilled = false, visible = false }
        }

        local baseReward = math.floor(175000 + heat * 250000)
        mission.data.custom.baseReward = baseReward
        mission.data.custom.bonusPerShip = math.floor(75000 + heat * 100000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 4000,
            paymentMessage = "Convoy has escaped. Contract payment transferred."%_T
        }

        cw_breakthrough_init(factionIndex)
    else
        cw_breakthrough_init(factionIndex)
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
        mission.data.custom.jumpTimer = 0
        -- Pre-load wave timer so first wave arrives 15s after entering
        mission.data.custom.waveTimer = 30
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    if onClient() then return end
    local giverFaction = Faction(mission.data.custom.giverIndex)
    if giverFaction then
        Player():sendChatMessage(giverFaction.name, 0,
            "We are charging our hyperdrives. Hold them off until we can jump!"%_T)
    end
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end
    if mission.data.custom.finished then return end

    local convoyShips = { Sector():getEntitiesByScriptValue("cw_convoy") }

    if #convoyShips == 0 then
        local giverFaction = Faction(mission.data.custom.giverIndex)
        if giverFaction then
            Player():sendChatMessage(giverFaction.name, 1,
                "The convoy was completely destroyed! We are withdrawing your contract!"%_T)
        end
        fail()
        return
    end

    mission.data.custom.jumpTimer = (mission.data.custom.jumpTimer or 0) + timeStep
    mission.data.custom.waveTimer = (mission.data.custom.waveTimer or 0) + timeStep

    -- Convoy jumps after 2.5 minutes (150 seconds)
    if mission.data.custom.jumpTimer > 150 then
        mission.data.custom.finished = true

        for _, ship in pairs(convoyShips) do
            ship:addScriptOnce("entity/deletejumped.lua")
        end

        finishAndReward(#convoyShips)
    end

    if mission.data.custom.waveTimer > 45 then
        mission.data.custom.waveTimer = 0
        spawnInterceptors()
    end
end

function spawnConvoy(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local giverFaction = Faction(mission.data.custom.giverIndex)
    if not giverFaction then return end

    local numFreighters = 3
    for i = 1, numFreighters do
        local pos = generator:getPositionInSector()
        local ship = ShipGenerator.createFreighterShip(giverFaction, pos)

        ship:setValue("cw_convoy", true)
        ship:addScriptOnce("ai/patrol.lua")
    end
end

function spawnInterceptors()
    if onClient() then return end
    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local heat = mission.data.custom.heat or 0
    local numEnemies = math.floor(2 + (heat * 3))

    for i = 1, numEnemies do
        -- Spawn them further out so they have to fly in
        local pos = generator:getPositionInSector(1500)
        local ship = ShipGenerator.createDefender(enemyFaction, pos)
        ShipAI(ship):setAggressive()
    end

    Player():sendChatMessage(enemyFaction.name, 1, "Target acquired! Destroy the convoy!"%_T)
end

function finishAndReward(survivors)
    local x, y = Sector():getCoordinates()
    local rewardFactor = Balancing_GetSectorRewardFactor(x, y)

    local bonus = (mission.data.custom.bonusPerShip or 15000) * survivors * rewardFactor

    local giverFaction = Faction(mission.data.custom.giverIndex)
    if giverFaction then
        if survivors == 3 then
            Player():sendChatMessage(giverFaction.name, 0,
                "All ships safely away! Excellent work, commander. We've added a bonus to your payment."%_T)
        elseif survivors > 0 then
            Player():sendChatMessage(giverFaction.name, 0,
                "We took losses, but the convoy is away. Sending payment now."%_T)
        end
    end

    if bonus > 0 then
        mission.data.reward.credits = mission.data.reward.credits + bonus
        mission.data.reward.relations = mission.data.reward.relations + (survivors * 1500)
    end

    local article = {
        title = "Supply Convoy Breaks Blockade",
        content = "A vital supply convoy belonging to " .. (giverFaction and giverFaction.name or "an unknown faction") .. " successfully broke through enemy lines in sector [" .. x .. ":" .. y .. "] with the help of hired escorts.",
        category = "War"
    }
    local cv_news = include("cosmicvaultnews")
    cv_news.publishArticle(article)

    reward()
    accomplish()
end

-- Added by Cosmic War for Avorion 2.0 Compatibility
function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.45 then return end

    local baseReward = math.floor(175000 + heat * 250000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 4000,
        paymentMessage = "Convoy has escaped. Contract payment transferred."%_T
    }

    return {
        brief = "War Contract: Breakthrough"%_T,
        description = "We have a critical supply convoy moving through contested space. Defend them until they can jump."%_T,
        difficulty = "Extreme"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_breakthrough.lua",
        icon = "data/textures/icons/ShipEscort.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Our convoy is vulnerable. We need a capable escort to ensure they make it."%_T,
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
            player:sendChatMessage(Faction(giverIndex).name, 1, "You abandoned a critical war contract! Our trust in you is broken.")
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
