package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Interception"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipBounty.png"
mission.data.autoTrackMission = true

local cw_interception_init = initialize
function initialize(factionIndex)
    if onServer() and not _restoring then
        -- Safely extract the argument passed from bulletinboard.lua
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

        -- Determine enemy faction via the active Cosmic War rivalry
        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        if enemyIndex == 0 then
            -- Fallback to local pirates if the rivalry decayed right after posting
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
        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        local baseReward = math.floor(125000 + heat * 250000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
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
    if onClient() then return end
    local giverFaction = Faction(mission.data.custom.giverIndex)
    if giverFaction then
        Player():sendChatMessage(giverFaction.name, 0, "We're tracking the convoy on your sensors. Take them out!"%_T)
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            -- Check if all ships spawned with our custom tracker are destroyed
            local targets = { Sector():getEntitiesByScriptValue("cw_interception_target") }
            return #targets == 0
        end,
        callback = function()
            finishAndReward()
        end
    },
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            mission.data.custom.jumpTimer = (mission.data.custom.jumpTimer or 300) - 1

            if mission.data.custom.jumpTimer == 60 and not mission.data.custom.warned then
                mission.data.custom.warned = true
                local giverFaction = Faction(mission.data.custom.giverIndex)
                if giverFaction then
                    Player():sendChatMessage(giverFaction.name, 0, "The hostile convoy is spooling their hyperdrives! Stop them!"%_T)
                end
            end

            return mission.data.custom.jumpTimer <= 0
        end,
        callback = function()
            local targets = { Sector():getEntitiesByScriptValue("cw_interception_target") }
            for _, ship in pairs(targets) do
                ship:addScriptOnce("entity/deletejumped.lua")
            end
            local giverFaction = Faction(mission.data.custom.giverIndex)
            if giverFaction then
                Player():sendChatMessage(giverFaction.name, 0, "The convoy escaped! Mission failed."%_T)
            end
            fail()
        end
    }
}

function spawnConvoy(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local numFreighters = random():getInt(1, 3)
    for i = 1, numFreighters do
        local pos = generator:getPositionInSector()
        local ship = ShipGenerator.createFreighterShip(enemyFaction, pos)

        -- Tag the ship so the trigger can track it
        ship:setValue("cw_interception_target", true)
        -- Prevent hyperspacing away immediately
        ship:addScriptOnce("ai/patrol.lua")
    end

    local numDefenders = random():getInt(2, 4)
    for i = 1, numDefenders do
        local pos = generator:getPositionInSector()
        local ship = ShipGenerator.createDefender(enemyFaction, pos)

        ship:setValue("cw_interception_target", true)
        ShipAI(ship.index):setAggressive()
    end
end

function finishAndReward()
    local x, y = Sector():getCoordinates()
    local article = {
        title = "Black Ops Fleet Intercepted",
        content = "A classified black ops fleet moving through sector [" .. x .. ":" .. y .. "] has been completely wiped out by independent contractors.",
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

    local baseReward = math.floor(125000 + heat * 250000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 6000,
        paymentMessage = "Target destroyed. Contract payment transferred."%_T
    }

    return {
        brief = "War Contract: Interception"%_T,
        description = "Conflict has intensified. Intercept hostile supply movement in nearby sectors.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Extreme"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_interception.lua",
        icon = "data/textures/icons/ShipBounty.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "We need skilled captains to strike enemy supply lines immediately."%_T,
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

