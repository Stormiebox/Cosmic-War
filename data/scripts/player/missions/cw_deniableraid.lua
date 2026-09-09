package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

-- v4.0.0: unlike Border Skirmish (which only falls back to a pirate target
-- when the giver has no real registered enemy), Deniable Raid always flags the raid as
-- pirate activity, regardless of whether the giver has a real enemy -- the whole pitch is
-- deniability, not simply "no better target available." If the giver DOES have a real
-- enemy, the intelligence gathered during the raid is banked as Intel against that enemy
-- instead, extending Intel-earning beyond the three dedicated 0.15-tier recon missions.
mission._Debug = 0
mission._Name = "War Contract: Deniable Raid"

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

        -- Always pirate-flagged, regardless of whether the giver has a real enemy.
        local x, y = Sector():getCoordinates()
        local pirateLevel = Balancing_GetPirateLevel(x, y)
        local pirateFaction = Galaxy():getPirateFaction(pirateLevel)
        if not pirateFaction then terminate() return end

        -- Real enemy, if any -- Intel from this raid banks against them, not the pirates.
        local realEnemyIndex = giverFaction:getValue("enemy_faction") or 0

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = pirateFaction.index
        mission.data.custom.realEnemyIndex = realEnemyIndex

        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, insideBarrier)
        if not targetX or not targetY then terminate() return end

        -- Applied only after every other termination check above has passed --
        -- this is an irreversible "act of war" cost with no matching mission
        -- granted if getSector() had failed, so it must not fire on a dead end.
        CosmicVaultFaction.changeRelations(Player().index, pirateFaction.index, -200000)

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a deniable contract from ${giver}. Officially, this never happened."%_T, arguments = { giver = giverFaction.name } },
            { text = "Raid the target at sector (${x}:${y}), flagged as pirate activity. Nothing here traces back to ${giver}."%_T, arguments = { x = targetX, y = targetY, giver = giverFaction.name } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the target"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(150000 + heat * 200000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1),
            relations = 5000,
            paymentMessage = "Clean work. No one will trace this back to us."%_T
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
        spawnRaidTarget(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            local targets = {}
            for _, t in pairs({ Sector():getEntitiesByScriptValue("cw_deniable_target") }) do
                if t.type == EntityType.Ship or t.type == EntityType.Station then
                    table.insert(targets, t)
                end
            end
            return atTargetLocation() and mission.data.custom.spawned and #targets == 0
        end,
        callback = function()
            local realEnemyIndex = mission.data.custom.realEnemyIndex
            if realEnemyIndex and realEnemyIndex > 0 then
                CosmicWarBridge.grantIntel(Player(), realEnemyIndex, 20)
                local giverFaction = Faction(mission.data.custom.giverIndex)
                if giverFaction then
                    Player():sendChatMessage(giverFaction.name, 0, "The raid turned up useful intelligence. Banked 20 Intel."%_T)
                end
            end

            reward()
            accomplish()
        end
    }
}

function spawnRaidTarget(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    local numDefenders = math.floor(3 + ((mission.data.custom.heat or 0) * 4))

    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship:setValue("cw_deniable_target", true)
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.45 then return end

    local baseReward = math.floor(150000 + heat * 200000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 5000,
        paymentMessage = "Clean work. No one will trace this back to us."%_T
    }

    return {
        brief = "War Contract: Deniable Raid"%_t,
        description = "We need a target hit, but nothing that traces back to us. Fly under a pirate flag and make it look like the usual raiders.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the local pirate faction."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_deniableraid.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Fly the pirate colors. This never happened."%_T,
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
