package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- v4.0.0 Final Pass: Subspace Corridors (cosmicwarsubspacecorridors.lua) were a
-- permanent galaxy change with no gameplay actually attached to them once torn --
-- this gives the mechanic a reason to exist beyond travel convenience. Only
-- offered against a faction whose OWN home sector is a real corridor endpoint
-- (`cw_corridor_at_<home>`, the exact value the corridor system itself already
-- maintains), so there's never a "no corridor to defend" dead end.
mission._Debug = 0
mission._Name = "War Contract: Corridor Interdiction"

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

        local hx, hy = giverFaction:getHomeSectorCoordinates()
        if not hx or not hy then terminate() return end

        local server = Server()
        if not server or not server:getValue("cw_corridor_at_" .. hx .. ":" .. hy) then terminate() return end

        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        local enemyFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
        if not enemyFaction then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        mission.data.location = { x = hx, y = hy }

        mission.data.description = {
            { text = "You accepted a contract from ${giver} to hold their subspace corridor against ${enemy}."%_T, arguments = { giver = giverFaction.name, enemy = enemyFaction.name } },
            { text = "${enemy} is running reinforcements straight through the corridor into (${x}:${y}). Hold the endpoint for four minutes."%_T, arguments = { enemy = enemyFaction.name, x = hx, y = hy } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(160000 + heat * 220000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(hx, hy) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1) * CosmicWarBridge.getSectorRewardMultiplier(hx, hy),
            relations = 10000,
            paymentMessage = "The corridor is secure. Their reinforcements never made it through."%_T
        }

        mission.data.custom.timeRemaining = 240
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
        spawnWave()
        mission.data.custom.spawned = true
        table.insert(mission.data.description, { text = "Hold the endpoint: 4:00"%_T, bulletPoint = true, fulfilled = false, visible = true })
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
        mission.data.description[4].text = "Hold the endpoint: ${time}"%_T % {time = timeString}
        sync()
    end

    if custom.spawnTimer >= 25 then
        custom.spawnTimer = 0
        spawnWave()
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            return mission.data.custom.timeRemaining and mission.data.custom.timeRemaining <= 0 and atTargetLocation()
        end,
        callback = function()
            mission.data.description[4].fulfilled = true
            sync()
            reward()
            accomplish()
        end
    }
}

function spawnWave()
    if onClient() then return end

    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local heat = mission.data.custom.heat or 0
    local waveSize = math.floor(2 + heat * 2)

    for i = 1, waveSize do
        local ship = ShipGenerator.createMilitaryShip(enemyFaction, generator:getPositionInSector())
        ship.title = "Corridor Reinforcement"%_T
        ShipAI(ship.index):setAggressive()
    end

    local player = Player()
    if player then
        player:sendChatMessage(enemyFaction.name, 1, "More of our forces are coming through the corridor -- hold them back!"%_T)
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.80 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local hx, hy = giverFaction:getHomeSectorCoordinates()
    if not hx or not hy then return end
    local server = Server()
    if not server or not server:getValue("cw_corridor_at_" .. hx .. ":" .. hy) then return end

    local baseReward = math.floor(160000 + heat * 220000)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(hx, hy) * mult * CosmicWarBridge.getSectorRewardMultiplier(hx, hy)
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "The corridor is secure. Their reinforcements never made it through."%_T
    }

    return {
        brief = "War Contract: Corridor Interdiction"%_t,
        description = "The enemy is running reinforcements straight through our own subspace corridor. Hold the endpoint until we can seal it off properly."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_corridor_interdiction.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Hold the line. Do not let them through."%_T,
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
