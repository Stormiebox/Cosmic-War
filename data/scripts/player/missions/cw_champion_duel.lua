package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

local SectorGenerator = include("sectorgenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Champion Duel"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipBounty.png"
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
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "An enemy Champion has challenged us in sector (${location.x}:${location.y}). Defeat them in a duel."%_T, arguments = { location = mission.data.location } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(250000 + heat * 300000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 20000,
            paymentMessage = "The Champion is defeated! A massive victory for us. Payment transferred."%_T
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
    if not mission.data.custom.spawned then
        spawnEvent(x, y)
        mission.data.custom.spawned = true
    end
    sync()
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() or not mission.data.custom.spawned then return false end
            
            local _raw_targets = { Sector():getEntitiesByScriptValue("cw_champion_target") }
            local targets = {}
            for _, _t in pairs(_raw_targets) do
                if _t.type == EntityType.Ship then
                    table.insert(targets, _t)
                end
            end
            
            return #targets == 0
        end,
        callback = function()
            reward()
            accomplish()
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    local position = generator:getPositionInSector()

    -- Champion
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation() * 15.0
    local champion = ShipGenerator.createMilitaryShip(enemyFaction, position, volume)
    
    champion:setValue("cw_champion_target", true)
    champion:addScriptOnce("data/scripts/entity/ai/patrol.lua")
    champion.title = "Faction Champion"%_T
    ShipAI(champion.index):setAggressive()

    local player = Player()
    if player then
        local messages = {
            "I expected an army, but they sent a single mercenary? How insulting. Prepare to die."%_T,
            "You dare accept my challenge? I will crush your hull and mount your core as a trophy!"%_T,
            "Finally, a challenger! Let us see if you bleed as easily as the rest of your fleet."%_T,
            "So, the cowards hired you to do their dirty work. Let me show you what true power looks like."%_T
        }
        local msg = messages[random():getInt(1, #messages)]
        player:sendChatMessage(champion.name, 0, msg)
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.90 then return end

    local baseReward = math.floor(250000 + heat * 300000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 20000,
        paymentMessage = "The Champion is defeated! A massive victory for us. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Champion Duel"%_T,
        description = "An arrogant enemy commander has broadcasted an open challenge to our faction, demanding a 1-on-1 duel. Command doesn't want to risk official assets, so we are paying you to answer the call and humiliate them.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Extreme"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_champion_duel.lua",
        icon = "data/textures/icons/ShipBounty.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Make sure they regret challenging us. Dismissed."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end

local cw_mission_abandon_original = mission.abandon
mission.abandon = function()
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

