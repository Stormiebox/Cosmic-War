package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")
local DEFENSE_GENERATOR_SCRIPT = "data/scripts/entity/cw_planetary_defense.lua"
local DEFENSE_INJECTOR_SCRIPT = "data/scripts/player/cw_siege_injector_persistent.lua"
local MATERIALIZATION_RETRY_SECONDS = 3

include("randomext")
include("structuredmission")

-- v4.0.0: the mission this session's own investigation made possible.
-- Planetary Defense Generators (cw_planetary_defense.lua) were a correct, working script
-- that nothing ever actually attached to anything -- documented as a real siege mechanic
-- no player could ever encounter. cosmicwardefensegenerators.lua now gives eligible
-- factions a real one at their home sector; this mission sends the player to destroy it.
-- Only offered against a faction that actually has one commissioned -- no pirate fallback,
-- since pirates are never eligible for a generator in the first place.
mission._Debug = 0
mission._Name = "War Contract: Shield Breaker"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

local function parseFlaggedSector(value)
    if type(value) ~= "string" then return nil, nil end

    local sx, sy = string.match(value, "^(-?%d+):(-?%d+)$")
    return tonumber(sx), tonumber(sy)
end

local function targetSectorKey()
    local target = mission.data.location
    if not target then return nil end
    return tostring(target.x) .. ":" .. tostring(target.y)
end

local function targetCommissionStillActive()
    local enemyIndex = mission.data.custom.enemyIndex
    local enemyFaction = enemyIndex and enemyIndex > 0 and Faction(enemyIndex) or nil
    return enemyFaction
        and enemyFaction:getValue("cw_defense_generator_sector") == targetSectorKey()
end

local function findTargetGenerator()
    if not atTargetLocation() then return nil end

    local enemyIndex = mission.data.custom.enemyIndex
    for _, station in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
        if station.factionIndex == enemyIndex and station:hasScript(DEFENSE_GENERATOR_SCRIPT) then
            return station
        end
    end
end

local function ensureTargetGenerator()
    local generator = findTargetGenerator()
    if generator then
        mission.data.custom.generatorConfirmed = true
        mission.data.custom.materializationError = nil
        return true
    end

    if not targetCommissionStillActive() then
        mission.data.custom.materializationError = "commission_missing"
        return false
    end

    local player = Player()
    player:addScriptOnce(DEFENSE_INJECTOR_SCRIPT)

    local target = mission.data.location
    local status, materialized, errorText = player:invokeFunction(
        DEFENSE_INJECTOR_SCRIPT,
        "materializeDefenseGenerator",
        target.x,
        target.y,
        mission.data.custom.enemyIndex
    )

    if status ~= 0 then
        mission.data.custom.materializationError = "injector_unavailable"
        return false
    end

    generator = findTargetGenerator()
    if generator then
        mission.data.custom.generatorConfirmed = true
        mission.data.custom.materializationError = nil
        return true
    end

    -- A successful materialization request may still be waiting for the
    -- deferred entity script attachment. The next bounded retry verifies it.
    mission.data.custom.materializationError = materialized and "generator_initializing"
        or (errorText or "materialization_failed")
    return false
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
        local enemyFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
        if not enemyFaction then terminate() return end

        local targetX, targetY = parseFlaggedSector(enemyFaction:getValue("cw_defense_generator_sector"))
        if not targetX or not targetY then terminate() return end

        local homeX, homeY = enemyFaction:getHomeSectorCoordinates()
        if targetX ~= homeX or targetY ~= homeY then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex
        mission.data.custom.generatorConfirmed = false
        mission.data.custom.materializationRetry = 0
        mission.data.location = { x = targetX, y = targetY }

        -- The persistent injector is normally attached at login. Ensure it is
        -- present for saves where this contract was accepted before that pass.
        Player():addScriptOnce(DEFENSE_INJECTOR_SCRIPT)

        local x, y = Sector():getCoordinates()

        CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
        Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "${enemy} has fortified sector (${x}:${y}) with a Planetary Defense Generator, shielding every other station there from harm. Destroy it."%_T, arguments = { enemy = enemyFaction.name, x = targetX, y = targetY } },
            { text = "Destroy the Planetary Defense Generator at (${x}:${y})"%_T, arguments = { x = targetX, y = targetY }, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(175000 + heat * 225000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1),
            relations = 12000,
            paymentMessage = "The choke point is broken. Our fleets can move freely now."%_T
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

mission.phases[1].onTargetLocationEntered = function()
    if onServer() then
        mission.data.custom.materializationRetry = 0
        if not ensureTargetGenerator()
                and targetCommissionStillActive()
                and not mission.data.custom.materializationNoticeSent then
            mission.data.custom.materializationNoticeSent = true
            Player():sendChatMessage(
                "Mission Control"%_T,
                0,
                "Defense Generator telemetry acquired. Hold position while local sensors resolve the station."%_T
            )
        end
        sync()
    end
end

mission.phases[1].updateTargetLocationServer = function(timeStep)
    if findTargetGenerator() then
        if not mission.data.custom.generatorConfirmed then
            mission.data.custom.generatorConfirmed = true
            mission.data.custom.materializationError = nil
            sync()
        end
        return
    end

    if not targetCommissionStillActive() then
        if mission.data.custom.generatorConfirmed then return end

        local giverFaction = Faction(mission.data.custom.giverIndex)
        Player():sendChatMessage(
            giverFaction and giverFaction.name or "Mission Control"%_T,
            1,
            "The Defense Generator commission is no longer active. This contract cannot be verified and has been withdrawn."%_T
        )
        fail()
        return
    end

    mission.data.custom.materializationRetry =
        (mission.data.custom.materializationRetry or 0) + timeStep
    if mission.data.custom.materializationRetry >= MATERIALIZATION_RETRY_SECONDS then
        mission.data.custom.materializationRetry = 0
        ensureTargetGenerator()
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end

            local targetCoords = mission.data.location
            local x, y = Sector():getCoordinates()
            if x ~= targetCoords.x or y ~= targetCoords.y then return false end

            if findTargetGenerator() then
                mission.data.custom.generatorConfirmed = true
                return false
            end

            -- Absence only proves destruction after this mission has observed the
            -- real generator script and its owning faction has cleared the exact
            -- commissioning flag. Arrival before a deferred/failed spawn can never
            -- satisfy both conditions.
            return mission.data.custom.generatorConfirmed == true
                and not targetCommissionStillActive()
        end,
        callback = function()
            mission.data.description[3].fulfilled = true

            local enemyIndex = mission.data.custom.enemyIndex
            if enemyIndex and enemyIndex > 0 then
                local enemyFaction = Faction(enemyIndex)
                if enemyFaction then
                    -- Clears the flag so this faction can be commissioned a new one by
                    -- cosmicwardefensegenerators.lua in the future, now that this one is
                    -- confirmed gone.
                    enemyFaction:setValue("cw_defense_generator_sector", nil)
                end
                CosmicWarBridge.recordWarScoreKill(enemyIndex)
            end

            sync()
            reward()
            accomplish()
        end
    }
}

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.60 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    local enemyFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not enemyFaction then return end
    local targetX, targetY = parseFlaggedSector(enemyFaction:getValue("cw_defense_generator_sector"))
    if not targetX or not targetY then return end

    local homeX, homeY = enemyFaction:getHomeSectorCoordinates()
    if targetX ~= homeX or targetY ~= homeY then return end

    local baseReward = math.floor(175000 + heat * 225000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 12000,
        paymentMessage = "The choke point is broken. Our fleets can move freely now."%_T
    }

    return {
        brief = "War Contract: Shield Breaker"%_t,
        description = "${enemy} has fortified its home sector at (${x}:${y}) behind a Planetary Defense Generator, shielding every other station there from attack. Break it, and the whole sector opens up.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_shieldbreaker.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = {
            enemy = enemyFaction.name,
            x = targetX,
            y = targetY,
            reward = createMonetaryString(rewardCredits)
        },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Break their shield. Dismissed."%_T,
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
