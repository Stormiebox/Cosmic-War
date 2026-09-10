package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

-- v4.0.0: race a defended battlefield's wreckage before it's cleared away.
-- Reward scales with the giver/enemy pair's current War Score margin (lopsided.margin =
-- more to salvage) -- the first contract to tie a reward directly to that scoreboard.
mission._Debug = 0
mission._Name = "War Contract: Salvage Race"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

local WRECKAGE_TIMEOUT = 300 -- 5 minutes to salvage before the field is cleared

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

        local x, y = Sector():getCoordinates()

        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
        end

        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }

        local d = length(vec2(targetX, targetY))
        local matType = MaterialType.Iron
        if d < 430 then matType = MaterialType.Titanium end
        if d < 350 then matType = MaterialType.Naonite end
        if d < 275 then matType = MaterialType.Trinium end
        if d < 150 then matType = MaterialType.Xanion end
        if d < 75 then matType = MaterialType.Ogonite end
        if d < 50 then matType = MaterialType.Avorion end

        local requiredMaterial = Material(matType)
        local materialAmount = random():getInt(2500, 6000)

        mission.data.custom.materialType = matType
        mission.data.custom.materialName = requiredMaterial.name
        mission.data.custom.materialAmount = materialAmount

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "A recent battle left a wreckage field at sector (${location.x}:${location.y}). Salvage ${amount} ${material} from it before rival scavengers and enemy patrols clear it out -- you have %d minutes once you arrive."%_T, arguments = { location = mission.data.location, amount = materialAmount, material = requiredMaterial.name } },
            { text = "Salvage ${amount} ${material} from the wreckage field at (${x}:${y})"%_T, arguments = { x = targetX, y = targetY, amount = materialAmount, material = requiredMaterial.name }, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        -- Reward scales with how lopsided the giver/enemy War Score currently is --
        -- salvaging from a more decisively-fought battlefield yields more, capped at +50%.
        local warScore = CosmicWarBridge.getWarScore(fIndex, enemyIndex) or 0
        local scoreBonus = 1.0 + math.min(0.5, math.abs(warScore) / 400)
        mission.data.custom.scoreBonus = scoreBonus

        local baseReward = math.floor((100000 + heat * 125000) * scoreBonus)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1),
            relations = 8000,
            paymentMessage = "Good haul. The scrap alone was worth the trip."%_T
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
    if not mission.data.custom.spawned then
        spawnEvent(x, y)
        mission.data.custom.spawned = true
        mission.data.custom.spawnTime = Server().unpausedRuntime

        -- Same fix as Scorched Earth: this mission never pays the salvaged material away, so
        -- checking total current stock let anyone already carrying enough of the target
        -- material complete the contract the instant they arrived. Snapshot on arrival and
        -- require that much more salvaged on top of it.
        local player = Player()
        local matType = mission.data.custom.materialType
        local resources = { player:getResources() }
        mission.data.custom.baselineAmount = resources[matType + 1] or 0

        sync()
    end
end

mission.phases[1].triggers = {
    {
        -- Timeout: the field clears itself out if the player takes too long.
        condition = function()
            if onClient() then return false end
            if not mission.data.custom.spawned then return false end
            return (Server().unpausedRuntime - (mission.data.custom.spawnTime or 0)) > WRECKAGE_TIMEOUT
        end,
        callback = function()
            Player():sendChatMessage(Faction(mission.data.custom.giverIndex).name, 1, "The wreckage field was picked clean before you got there. Contract failed."%_T)
            fail()
        end
    },
    {
        condition = function()
            if onClient() then return false end
            if not mission.data.custom.spawned then return false end

            local player = Player()
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount
            local baselineAmount = mission.data.custom.baselineAmount or 0

            local resources = { player:getResources() }
            local current = resources[matType + 1] or 0

            local x, y = Sector():getCoordinates()
            local targetCoords = mission.data.location

            return x == targetCoords.x and y == targetCoords.y and (current - baselineAmount) >= requiredAmount
        end,
        callback = function()
            mission.data.description[3].fulfilled = true
            sync()
            reward()
            accomplish()
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    for i = 1, 5 do
        local position = generator:getPositionInSector()
        generator:createWreckage(enemyFaction, nil, 10, position)
    end

    -- Rival scavengers and a defensive patrol -- you're not the only one after this field.
    for i = 1, 2 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createMiningShip(enemyFaction, position)
        ship.title = "Rival Scavenger"%_T
        ship:addScriptOnce("data/scripts/entity/ai/mine.lua")
    end

    for i = 1, 2 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createDefender(enemyFaction, position)
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.35 then return end

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local enemyIndex = giverFaction:getValue("enemy_faction") or 0
    if enemyIndex == 0 then
        local x, y = Sector():getCoordinates()
        enemyIndex = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y)).index
    end

    local warScore = CosmicWarBridge.getWarScore(station.factionIndex, enemyIndex) or 0
    local scoreBonus = 1.0 + math.min(0.5, math.abs(warScore) / 400)

    local baseReward = math.floor((100000 + heat * 125000) * scoreBonus)
    local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 8000,
        paymentMessage = "Good haul. The scrap alone was worth the trip."%_T
    }

    return {
        brief = "War Contract: Salvage Race"%_t,
        description = "A recent battle left valuable wreckage drifting in a nearby sector. Get there before rival scavengers and enemy patrols clear it out.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Medium"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_salvagerace.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Move fast. Someone else is already headed there."%_T,
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
