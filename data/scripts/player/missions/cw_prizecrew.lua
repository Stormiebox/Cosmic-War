package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

-- v4.0.0: capture an enemy escort ship intact instead of destroying it.
-- IMPORTANT DESIGN NOTE, kept here deliberately: this does NOT use vanilla's Boarding
-- component/AIState.Boarding at all -- ship-level capture through that system has never
-- been resolved anywhere in this workspace, and this contract sidesteps that uncertainty
-- entirely by reusing the exact mechanism this mod's OWN station captures already use
-- (trooptransport.lua): reduce the target below a durability threshold while it's still
-- alive, then flip its factionIndex directly. That mechanism is proven and shipped; only
-- the target TYPE (Ship instead of Station) is new here, which changes nothing about how
-- factionIndex reassignment itself works.
mission._Debug = 0
mission._Name = "War Contract: Prize Crew"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipCombat.png"
mission.data.autoTrackMission = true

local CAPTURE_DURABILITY_THRESHOLD = 0.25

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

        CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, insideBarrier)
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "${enemy} operates a valuable escort ship near sector (${x}:${y}). Disable it -- reduce it below 25% hull WITHOUT destroying it -- so our prize crew can bring it in intact."%_T, arguments = { enemy = enemyFaction.name, x = targetX, y = targetY } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Disable the target -- do not destroy it"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(160000 + heat * 200000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1),
            relations = 8000,
            paymentMessage = "The prize crew brought her in clean. A fine addition to our fleet."%_T
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
        spawnTarget(x, y)
        mission.data.custom.spawned = true
        sync()
    end
end

mission.phases[1].triggers = {
    {
        -- Failure: the target was destroyed instead of disabled.
        condition = function()
            if onClient() then return false end
            if not mission.data.custom.spawned or mission.data.custom.resolved then return false end
            local target = Entity(Uuid(mission.data.custom.targetId))
            return not valid(target)
        end,
        callback = function()
            mission.data.custom.resolved = true
            Player():sendChatMessage(Faction(mission.data.custom.giverIndex).name, 1, "You destroyed the target instead of disabling it. A wreck is worthless to us. Contract failed."%_T)
            fail()
        end
    },
    {
        -- Success: disabled, not destroyed, and the player is in-sector to secure the capture.
        condition = function()
            if onClient() then return false end
            if not mission.data.custom.spawned or mission.data.custom.resolved then return false end
            if not atTargetLocation() then return false end

            local target = Entity(Uuid(mission.data.custom.targetId))
            if not valid(target) then return false end
            if not target.maxDurability or target.maxDurability <= 0 then return false end

            return (target.durability / target.maxDurability) <= CAPTURE_DURABILITY_THRESHOLD
        end,
        callback = function()
            mission.data.custom.resolved = true
            local target = Entity(Uuid(mission.data.custom.targetId))
            local giverIndex = mission.data.custom.giverIndex
            local enemyIndex = mission.data.custom.enemyIndex

            if valid(target) then
                target.factionIndex = giverIndex
                -- The prize crew makes emergency repairs to keep her spaceworthy.
                target.durability = target.maxDurability * 0.5
                target:addScriptOnce("data/scripts/entity/ai/patrol.lua")
                Sector():broadcastChatMessage(Faction(giverIndex).name, 0, "Prize crew aboard. The vessel is ours."%_T)
            end

            if giverIndex and enemyIndex then
                CosmicWarBridge.recordWarScoreKill(enemyIndex)
                CosmicWarBridge.grantIntel(Player(), enemyIndex, 20)
            end

            local giverFaction = giverIndex and Faction(giverIndex)
            local enemyFaction = enemyIndex and Faction(enemyIndex)
            local article = {
                title = "Enemy Escort Captured Intact",
                content = "A " .. (enemyFaction and enemyFaction.name or "hostile") .. " escort ship has been disabled and boarded by a prize crew acting for " .. (giverFaction and giverFaction.name or "an independent faction") .. ", adding the vessel to their fleet.",
                category = "War"
            }
            local cv_news = include("cosmicvaultnews")
            cv_news.publishArticle(article)

            reward()
            accomplish()
        end
    }
}

function spawnTarget(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    local target = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
    target.title = "Prize Vessel"%_T
    ShipAI(target.index):setAggressive()
    mission.data.custom.targetId = target.id.string

    -- A light, non-target escort so the objective isn't a completely undefended solo ship.
    for i = 1, 2 do
        local guard = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ShipAI(guard.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.60 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 then return end

    local baseReward = math.floor(160000 + heat * 200000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 8000,
        paymentMessage = "The prize crew brought her in clean. A fine addition to our fleet."%_T
    }

    return {
        brief = "War Contract: Prize Crew"%_t,
        description = "One of the enemy's escort ships would make a fine addition to our fleet. Disable it, don't destroy it -- our prize crew will handle the rest.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction.",
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_prizecrew.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Bring her in alive. Don't get greedy with the trigger."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end

-- structuredmission.lua's abandon() dispatches to mission.currentPhase.onAbandon /
-- mission.globalPhase.onAbandon, never to a "mission.abandon" field -- that field doesn't
-- exist anywhere in the framework, so assigning one here would just create dead data nothing
-- ever calls. Use the real extension point instead.
mission.globalPhase.onAbandon = function()
    local player = Player()
    local giverIndex = mission.data.custom.giverIndex
    if giverIndex and giverIndex > 0 then
        CosmicVaultFaction.changeRelations(player.index, giverIndex, -25000)
        local giverFaction = Faction(giverIndex)
        local giverName = giverFaction and giverFaction.name or "Unknown"%_T
        player:sendChatMessage(giverName, 1, "You abandoned a critical war contract! Our trust in you is broken."%_T)
    end
end
