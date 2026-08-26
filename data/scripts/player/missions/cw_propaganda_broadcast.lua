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
mission._Name = "War Contract: Propaganda Broadcast"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipEscort.png"
mission.data.autoTrackMission = true

function getUpdateInterval()
    return 5.0
end

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
            { text = "Escort our broadcasting ship to sector (${location.x}:${location.y}) and defend it while it transmits demoralizing propaganda to the enemy."%_T, arguments = { location = mission.data.location } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        -- Huge buff for v3.0.0
        local baseReward = math.floor(100000 + heat * 150000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 10000,
            paymentMessage = "Contract fulfilled. Payment transferred."%_T
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
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            local _raw_targets = { Sector():getEntitiesByScriptValue("cw_broadcaster") }

            local targets = {}

            for _, _t in pairs(_raw_targets) do

                if _t.type == EntityType.Ship or _t.type == EntityType.Station then

                    table.insert(targets, _t)

                end

            end
            if #targets == 0 then
                mission.data.custom.failed = true
                return true
            end

            mission.data.custom.broadcastTimer = (mission.data.custom.broadcastTimer or 180) - 1

            -- Spawn attackers periodically
            if mission.data.custom.broadcastTimer % 30 == 0 then
                local enemyFaction = Faction(mission.data.custom.enemyIndex)
                local escort = ShipGenerator.createDefender(enemyFaction, SectorGenerator(Sector():getCoordinates()):getPositionInSector())
                ShipAI(escort.index):setAggressive()
            end

            return mission.data.custom.broadcastTimer <= 0
        end,
        callback = function()
            if mission.data.custom.failed then
                local giverFaction = Faction(mission.data.custom.giverIndex)
                if giverFaction then
                    Player():sendChatMessage(giverFaction.name, 0, "The broadcaster was destroyed! The mission has failed."%_T)
                end
                fail()
            else
                local _raw_targets = { Sector():getEntitiesByScriptValue("cw_broadcaster") }

                local targets = {}

                for _, _t in pairs(_raw_targets) do

                    if _t.type == EntityType.Ship or _t.type == EntityType.Station then

                        table.insert(targets, _t)

                    end

                end
                for _, ship in pairs(targets) do
                    ship:addScriptOnce("entity/deletejumped.lua")
                end
                reward()
                accomplish()
            end
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local giverFaction = Faction(mission.data.custom.giverIndex)

    local broadcaster = ShipGenerator.createFreighterShip(giverFaction, generator:getPositionInSector())
    broadcaster.title = "Propaganda Broadcaster"
    broadcaster:addScriptOnce("data/scripts/entity/ai/patrol.lua")
    broadcaster:setValue("cw_broadcaster", true)

    mission.data.custom.broadcastTimer = 180 -- 3 minutes

end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.25 then return end

    local baseReward = math.floor(100000 + heat * 150000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "Contract fulfilled. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Propaganda Broadcast"%_T,
        description = "Escort our broadcasting ship to a contested sector and defend it while it transmits demoralizing propaganda to the enemy.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Extreme"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_propaganda_broadcast.lua",
        icon = "data/textures/icons/ShipEscort.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Defend the broadcaster. The psychological war is just as important as the physical one."%_T,
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
