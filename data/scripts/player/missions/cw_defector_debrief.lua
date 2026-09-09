package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- v4.0.0: the first War Contract gated ON Intel rather than granting
-- it -- Force Recon/Sensor Deployment/Black Box Retrieval/Deniable Raid/Counter-
-- Intelligence Sweep all pay Intel out; nothing before this spent it on
-- anything, which is what turns a ledger into a progression track instead of a
-- counter nobody ever draws down. Costs 50 Intel banked against the target
-- faction, spent on accept -- checked and spent in initialize() rather than
-- getBulletin(), since Intel is tracked per-player (or per-Alliance) and
-- getBulletin() only ever sees the giver station, never the specific player
-- about to accept.
mission._Debug = 0
mission._Name = "War Contract: Defector Debrief"

local INTEL_COST = 50

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
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

        local player = Player()
        if not player then terminate() return end

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, insideBarrier)
        if not targetX or not targetY then terminate() return end

        -- Spent only after every other termination check above has passed --
        -- this Intel cost is not refunded, so it must not be burned on a dead
        -- end that never actually grants the mission.
        if not CosmicWarBridge.spendIntel(player, enemyIndex, INTEL_COST) then
            player:sendChatMessage(giverFaction.name, 1, string.format("This op needs %d Intel against %s before we can move -- you don't have enough banked yet."%_T, INTEL_COST, enemyFaction.name))
            terminate()
            return
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        mission.data.location = { x = targetX, y = targetY }

        mission.data.description = {
            { text = "You spent 50 Intel against ${enemy} to unlock this op for ${giver} -- a defector wants out, and they're worth extracting alive."%_T, arguments = { enemy = enemyFaction.name, giver = giverFaction.name } },
            { text = "Break through the guard detail holding them at (${x}:${y}) and extract the defector."%_T, arguments = { x = targetX, y = targetY } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the guard detail"%_T, bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(150000 + heat * 175000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1) * CosmicWarBridge.getSectorRewardMultiplier(x, y),
            -- A notably larger relations grant than a typical contract, framed as a
            -- permanent standing bonus -- this is what "pays in reputation, not just
            -- credits" actually means mechanically: there's no separate persistent
            -- flag for it, the relations gain itself IS the standing, and relations
            -- decay/drift the same slow way every other gain in this mod already does.
            relations = 22000,
            paymentMessage = "What they told us is worth more than the credits. You have our lasting gratitude."%_T
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
        spawnGuardDetail(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            local guards = {}
            for _, t in pairs({ Sector():getEntitiesByScriptValue("cw_defector_guard_target") }) do
                if t.type == EntityType.Ship then
                    table.insert(guards, t)
                end
            end
            return atTargetLocation() and mission.data.custom.spawned and #guards == 0
        end,
        callback = function()
            mission.data.description[4].fulfilled = true
            sync()
            reward()
            accomplish()
        end
    }
}

function spawnGuardDetail(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local heat = mission.data.custom.heat or 0
    local numGuards = math.floor(3 + heat * 3)

    for i = 1, numGuards do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship:setValue("cw_defector_guard_target", true)
        ship.title = "Defector Guard Detail"%_T
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.60 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 then return end

    local baseReward = math.floor(150000 + heat * 175000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local sx, sy = Sector():getCoordinates()
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(sx, sy) * mult * CosmicWarBridge.getSectorRewardMultiplier(sx, sy)
    local rewardStruct = {
        credits = rewardCredits,
        relations = 22000,
        paymentMessage = "What they told us is worth more than the credits. You have our lasting gratitude."%_T
    }

    return {
        brief = "War Contract: Defector Debrief"%_t,
        description = "A defector wants out and knows things we need to hear. This costs 50 Intel against them to unlock -- if you have it banked, accepting spends it immediately."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_defector_debrief.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Get them out alive. Everything they know goes with them otherwise."%_T,
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
            CosmicVaultFaction.changeRelations(player.index, giverIndex, -20000)
            local giverFaction = Faction(giverIndex)
            local giverName = giverFaction and giverFaction.name or "Unknown"%_T
            player:sendChatMessage(giverName, 1, "The defector was left behind. That Intel is spent for nothing now."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
