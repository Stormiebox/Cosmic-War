package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicVaultEconomy = include("cosmicvaulteconomy")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- v4.0.0: every existing Humanitarian Contract is delivery or a flat
-- credit payment -- a combat-focused player has no route into the Famine system at
-- all except making it worse (Scorched Earth). This is the combat mirror: a
-- blockade squadron is choking the giver's own supply lanes, and destroying it
-- reduces Famine directly, the same way a Relief Convoy delivery does, just earned
-- with a fight instead of a cargo hold.
mission._Debug = 0
mission._Name = "Famine Blockade Break"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipCombat.png"
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

        local server = Server()
        local famineScore = server and (server:getValue("cv_famine_" .. tostring(fIndex)) or 0) or 0
        mission.data.custom.famineScore = famineScore
        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }

        -- The blockade sits near the giver's own space, not deep in enemy
        -- territory -- it's choking THEIR supply lanes, not a raid.
        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 8, false, false, false, false, insideBarrier)
        if not targetX or not targetY then terminate() return end
        mission.data.location = { x = targetX, y = targetY }

        -- The blockade is crewed by whichever faction is actually starving this
        -- one, if one is registered -- otherwise generic pirate opportunists
        -- exploiting the famine, since a blockade needs SOME hostile crew and not
        -- every starving faction has an active war behind the famine.
        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        if enemyIndex <= 0 then
            local pirateLevel = Balancing_GetPirateLevel(targetX, targetY)
            local pirateFaction = Galaxy():getPirateFaction(pirateLevel)
            if not pirateFaction then terminate() return end
            enemyIndex = pirateFaction.index
        end
        mission.data.custom.enemyIndex = enemyIndex

        CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -150000)

        mission.data.description = {
            { text = "You accepted a contract from ${giver} -- a blockade squadron is choking their own supply lanes, and their famine is only getting worse for it."%_T, arguments = { giver = giverFaction.name } },
            { text = "Break the blockade at sector (${x}:${y})."%_T, arguments = { x = targetX, y = targetY } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the blockade squadron"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local baseReward = math.floor(120000 + famineScore * 1200)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * CosmicWarBridge.getSectorRewardMultiplier(x, y),
            relations = 8000,
            paymentMessage = "Our supply lines are open again. This will help more than you know."%_T
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
    mission.data.description[4].visible = true

    if not mission.data.custom.spawned then
        spawnBlockade(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            local targets = {}
            for _, t in pairs({ Sector():getEntitiesByScriptValue("cw_famine_blockade_target") }) do
                if t.type == EntityType.Ship or t.type == EntityType.Station then
                    table.insert(targets, t)
                end
            end
            return atTargetLocation() and mission.data.custom.spawned and #targets == 0
        end,
        callback = function()
            local giverIndex = mission.data.custom.giverIndex
            if giverIndex and giverIndex > 0 then
                -- -30 Famine per broken blockade -- a real dent (Relief Convoy's
                -- own delivery pays -20), reflecting that this is fought for, not
                -- flown in with a cargo hold.
                CosmicVaultEconomy.addFamineScore(giverIndex, -30)
                CosmicWarBridge.recordFamineReliefApplied(giverIndex, 30)
            end

            mission.data.description[4].fulfilled = true
            sync()

            reward()
            accomplish()
        end
    }
}

function spawnBlockade(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local famineScore = mission.data.custom.famineScore or 0
    local numShips = math.floor(3 + math.min(3, famineScore / 50))

    for i = 1, numShips do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship:setValue("cw_famine_blockade_target", true)
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local server = Server()
    if not server then return end
    local famineScore = server:getValue("cv_famine_" .. tostring(station.factionIndex)) or 0
    if famineScore < 100 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local baseReward = math.floor(120000 + famineScore * 1200)
    local sx, sy = Sector():getCoordinates()
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(sx, sy) * CosmicWarBridge.getSectorRewardMultiplier(sx, sy)
    local rewardStruct = {
        credits = rewardCredits,
        relations = 8000,
        paymentMessage = "Our supply lines are open again. This will help more than you know."%_T
    }

    return {
        brief = "Famine Blockade Break"%_t,
        description = "A blockade squadron is strangling our own supply lanes. We're starving because of it. Break it, and we can feed our people again."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_famine_blockade_break.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Please. Our people are counting on this."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end

-- Framework note: onAbandon() (structuredmission.lua) dispatches to
-- mission.currentPhase.onAbandon / mission.globalPhase.onAbandon, never to a
-- "mission.abandon" field -- that field was dead weight the framework never
-- read, so the relations penalty below never fired. globalPhase is used
-- since the penalty applies regardless of which phase is active.
local cw_mission_abandon_original = mission.globalPhase.onAbandon
mission.globalPhase.onAbandon = function()
    if onServer() then
        local player = Player()
        local giverIndex = mission.data.custom.giverIndex
        if giverIndex and giverIndex > 0 then
            CosmicVaultFaction.changeRelations(player.index, giverIndex, -15000)
            local giverFaction = Faction(giverIndex)
            local giverName = giverFaction and giverFaction.name or "Unknown"%_T
            player:sendChatMessage(giverName, 1, "You abandoned a humanitarian contract. Our people will remember."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
