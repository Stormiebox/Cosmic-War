package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- v4.0.0: the enemy has been running the same playbook the
-- Intelligence Network gives the player. Destroying their forward listening post
-- blinds their next organic expansion roll (cosmicwarexpansion.lua's
-- getExpansionBlindMultiplier) for a real period -- Intel becomes a contested
-- resource with an adversary, not just a one-way currency with a single sink.
mission._Debug = 0
mission._Name = "War Contract: Counter-Intelligence Sweep"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

-- 24 hours of real playtime -- long enough to matter (the update loop this feeds
-- runs every 15 minutes, so this reliably blocks several real rolls), short enough
-- that a single contract doesn't permanently cripple a faction's growth.
local BLIND_DURATION = 24 * 3600

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

        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        local enemyFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
        if not enemyFaction then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, insideBarrier)
        if not targetX or not targetY then terminate() return end
        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a contract from ${giver} to blind ${enemy}'s scouts."%_T, arguments = { giver = giverFaction.name, enemy = enemyFaction.name } },
            { text = "${enemy} is running a forward listening post at sector (${x}:${y}). Destroy it before they see your fleet coming."%_T, arguments = { enemy = enemyFaction.name, x = targetX, y = targetY } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the listening post"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(125000 + heat * 175000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1) * CosmicWarBridge.getSectorRewardMultiplier(x, y),
            relations = 8000,
            paymentMessage = "Their eyes are blind now. Good work."%_T
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
        spawnListeningPost(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            local posts = {}
            for _, t in pairs({ Sector():getEntitiesByScriptValue("cw_listening_post_target") }) do
                if t.type == EntityType.Station then
                    table.insert(posts, t)
                end
            end
            return atTargetLocation() and mission.data.custom.spawned and #posts == 0
        end,
        callback = function()
            local enemyIndex = mission.data.custom.enemyIndex
            if enemyIndex and enemyIndex > 0 then
                local enemyFaction = Faction(enemyIndex)
                if enemyFaction then
                    local server = Server()
                    if server then
                        server:setValue("cw_expansion_blinded_until_" .. tostring(enemyIndex), (server.unpausedRuntime or 0) + BLIND_DURATION)
                    end
                    CosmicWarBridge.grantIntel(Player(), enemyIndex, 15)
                    local giverFaction = Faction(mission.data.custom.giverIndex)
                    if giverFaction then
                        Player():sendChatMessage(giverFaction.name, 0, "Their listening post is gone. They're blind to their own expansion options for a while -- and we picked up 15 Intel from the wreckage."%_T)
                    end
                end
            end

            mission.data.description[4].fulfilled = true
            sync()

            reward()
            accomplish()
        end
    }
}

function spawnListeningPost(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local post = generator:createStation(enemyFaction, "data/scripts/entity/merchants/militaryoutpost.lua")
    if post then
        post:setTitle("Forward Listening Post"%_T, {})
        post:setValue("cw_listening_post_target", true)
    end

    local heat = mission.data.custom.heat or 0
    local numGuards = math.floor(2 + heat * 3)
    for i = 1, numGuards do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.45 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 then return end

    local baseReward = math.floor(125000 + heat * 175000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local sx, sy = Sector():getCoordinates()
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(sx, sy) * mult * CosmicWarBridge.getSectorRewardMultiplier(sx, sy)
    local rewardStruct = {
        credits = rewardCredits,
        relations = 8000,
        paymentMessage = "Their eyes are blind now. Good work."%_T
    }

    return {
        brief = "War Contract: Counter-Intelligence Sweep"%_t,
        description = "The enemy has their own eyes on us. Find their forward listening post and burn it down before they see what we're planning next."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_counterintelligence_sweep.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Find it. Burn it. Quietly."%_T,
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
            CosmicVaultFaction.changeRelations(player.index, giverIndex, -25000)
            local giverFaction = Faction(giverIndex)
            local giverName = giverFaction and giverFaction.name or "Unknown"%_T
            player:sendChatMessage(giverName, 1, "You abandoned a critical war contract! Our trust in you is broken."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
