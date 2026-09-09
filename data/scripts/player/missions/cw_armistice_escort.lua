package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- v4.0.0: Decisive Push (already shipped) lets a player decide WHO wins
-- a war that's nearly over. Nothing lets them shape HOW it ends -- this is the
-- first contract where the outcome is a negotiated settlement rather than a body
-- count. Only offered once a war's War Score has reached 200-249 (close to, but
-- short of, the 250-point Decisive Victory threshold) -- succeeding before the
-- score actually crosses it sets a flag cosmicwarceasefires.lua's own Decisive
-- Victory block checks and consumes, softening the loser's famine penalty from a
-- war that ran its course (+15) to a negotiated one (+5).
mission._Debug = 0
mission._Name = "War Contract: Armistice Escort"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

local function warScorePairKey(a, b)
    local lo, hi = math.min(a, b), math.max(a, b)
    return tostring(lo) .. "_" .. tostring(hi)
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

        local score = math.abs(CosmicWarBridge.getWarScore(fIndex, enemyIndex) or 0)
        if score < 200 or score >= 250 then terminate() return end

        local ex, ey = enemyFaction:getHomeSectorCoordinates()
        if not ex or not ey then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex
        mission.data.custom.pairKey = warScorePairKey(fIndex, enemyIndex)

        mission.data.location = { x = ex, y = ey }

        mission.data.description = {
            { text = "You accepted a contract from ${giver} to escort armistice negotiators to ${enemy}'s home sector before this war decides itself by force."%_T, arguments = { giver = giverFaction.name, enemy = enemyFaction.name } },
            { text = "Reach (${x}:${y}) and hold while negotiations open. Expect resistance -- not everyone on either side wants peace."%_T, arguments = { x = ex, y = ey } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(200000 + heat * 250000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(ex, ey) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1) * CosmicWarBridge.getSectorRewardMultiplier(ex, ey),
            relations = 15000,
            paymentMessage = "Whatever happens next, it will be a little less costly for everyone. Thank you."%_T
        }

        mission.data.custom.timeRemaining = 90
        mission.data.custom.spawnTimer = 0

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
        spawnSpoilers()
        mission.data.custom.spawned = true
        table.insert(mission.data.description, { text = "Hold while negotiations open: 1:30"%_T, bulletPoint = true, fulfilled = false, visible = true })
    end
    sync()
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end

    local custom = mission.data.custom
    custom.timeRemaining = math.max(0, custom.timeRemaining - timeStep)
    custom.spawnTimer = custom.spawnTimer + timeStep

    local minutes = math.floor(custom.timeRemaining / 60)
    local seconds = math.floor(custom.timeRemaining % 60)
    local timeString = string.format("%d:%02d", minutes, seconds)

    if math.floor(custom.timeRemaining) ~= custom.lastTimeSec then
        custom.lastTimeSec = math.floor(custom.timeRemaining)
        mission.data.description[4].text = "Hold while negotiations open: ${time}"%_T % {time = timeString}
        sync()
    end

    if custom.spawnTimer >= 45 then
        custom.spawnTimer = 0
        spawnSpoilers()
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            return mission.data.custom.timeRemaining and mission.data.custom.timeRemaining <= 0 and atTargetLocation()
        end,
        callback = function()
            local server = Server()
            if server and mission.data.custom.pairKey then
                server:setValue("cw_armistice_" .. mission.data.custom.pairKey, true)
            end

            mission.data.description[4].fulfilled = true
            sync()
            reward()
            accomplish()
        end
    }
}

-- "Spoilers" -- factions/individuals on either side who don't want peace and try
-- to disrupt the negotiation. Drawn from the enemy faction's own defenders rather
-- than a separate identity, since this mod has no dedicated "war hawk splinter
-- faction" concept to draw from.
function spawnSpoilers()
    if onClient() then return end

    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local heat = mission.data.custom.heat or 0
    local waveSize = math.floor(2 + heat * 2)

    for i = 1, waveSize do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship.title = "War Hawk Spoiler"%_T
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 then return end

    local score = math.abs(CosmicWarBridge.getWarScore(station.factionIndex, enemyIndex) or 0)
    if score < 200 or score >= 250 then return end

    local enemyFaction = Faction(enemyIndex)
    if not enemyFaction then return end
    local ex, ey = enemyFaction:getHomeSectorCoordinates()
    if not ex or not ey then return end

    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    local baseReward = math.floor(200000 + heat * 250000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(ex, ey) * mult * CosmicWarBridge.getSectorRewardMultiplier(ex, ey)
    local rewardStruct = {
        credits = rewardCredits,
        relations = 15000,
        paymentMessage = "Whatever happens next, it will be a little less costly for everyone. Thank you."%_T
    }

    return {
        brief = "War Contract: Armistice Escort"%_t,
        description = "This war is close to deciding itself by force. We'd rather it end at a table instead. Escort our negotiators through and hold while they open communications."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_armistice_escort.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Get them there in one piece. Please."%_T,
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
            player:sendChatMessage(giverName, 1, "The negotiators were left exposed. This war continues."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
