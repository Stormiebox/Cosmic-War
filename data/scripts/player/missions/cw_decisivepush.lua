package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

-- v4.0.0: the first War Contract gated on War Score itself rather than raw
-- War Heat. Only offered once a faction pair's War Score is already close to the 250-point
-- Decisive Victory threshold (150-249, giver ahead) -- giving the player direct agency to
-- finish what's nearly already decided, instead of only ever waiting for the background
-- roll. Completion credits a territory-weight (25-point) War Score contribution, the same
-- weight a real station capture gets, on top of the normal combat rewards.
mission._Debug = 0
mission._Name = "War Contract: Decisive Push"

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

        -- Applied only after every other termination check above has passed --
        -- this is an irreversible "act of war" cost with no matching mission
        -- granted if getSector() had failed, so it must not fire on a dead end.
        CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}. This war is nearly won -- one more decisive blow could end it outright."%_T, arguments = { giver = giverFaction.name } },
            { text = "Break ${enemy}'s last defense fleet at sector (${x}:${y})."%_T, arguments = { enemy = enemyFaction.name, x = targetX, y = targetY } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the fleet"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(300000 + heat * 350000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1),
            relations = 15000,
            paymentMessage = "This war is over. History will remember what you did here."%_T
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
        spawnFleet(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            local targets = {}
            for _, t in pairs({ Sector():getEntitiesByScriptValue("cw_decisive_target") }) do
                if t.type == EntityType.Ship or t.type == EntityType.Station then
                    table.insert(targets, t)
                end
            end
            return atTargetLocation() and mission.data.custom.spawned and #targets == 0
        end,
        callback = function()
            local giverIndex = mission.data.custom.giverIndex
            local enemyIndex = mission.data.custom.enemyIndex
            if giverIndex and enemyIndex then
                -- Credited the same 25-point weight a real station capture gets --
                -- the decisive blow this contract is named for.
                CosmicWarBridge.recordWarScoreTerritory(enemyIndex, giverIndex)
            end

            reward()
            accomplish()
        end
    }
}

function spawnFleet(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    local numDefenders = math.floor(4 + ((mission.data.custom.heat or 0) * 5))

    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship:setValue("cw_decisive_target", true)
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.60 then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 then return end

    -- Only offered when the giver is already ahead and close to, but short of, the
    -- 250-point Decisive Victory threshold -- this contract exists to close that gap.
    local warScore = CosmicWarBridge.getWarScore(station.factionIndex, enemyIndex) or 0
    if warScore < 150 or warScore >= 250 then return end

    local baseReward = math.floor(300000 + heat * 350000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 15000,
        paymentMessage = "This war is over. History will remember what you did here."%_T
    }

    return {
        brief = "War Contract: Decisive Push"%_t,
        description = "We have the enemy on the ropes. One more decisive strike and this war is over for good.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_decisivepush.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Finish this. End it for good."%_T,
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
