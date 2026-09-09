package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

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

        local flaggedSector = enemyFaction:getValue("cw_defense_generator_sector")
        if not flaggedSector then terminate() return end

        local sx, sy = string.match(flaggedSector, "(-?%d+):(-?%d+)")
        local targetX, targetY = tonumber(sx), tonumber(sy)
        if not targetX or not targetY then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex
        mission.data.location = { x = targetX, y = targetY }

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

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end

            local targetCoords = mission.data.location
            local x, y = Sector():getCoordinates()
            if x ~= targetCoords.x or y ~= targetCoords.y then return false end

            -- The generator is destroyed once no station in this sector carries the
            -- script anymore. It materializes the moment any player (this one included)
            -- first enters the sector (cw_siege_injector_persistent.lua), so by the time
            -- this condition can even be checked here, it is guaranteed to already exist.
            for _, station in pairs({ Sector():getEntitiesByType(EntityType.Station) }) do
                if station:hasScript("cw_planetary_defense.lua") then
                    return false
                end
            end
            return true
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
    if not enemyFaction:getValue("cw_defense_generator_sector") then return end

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
        description = "The enemy has fortified one of their sectors behind a Planetary Defense Generator, shielding every other station there from attack. Break it, and the whole sector opens up.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_shieldbreaker.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
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
