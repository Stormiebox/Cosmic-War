package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicVaultEconomy = include("cosmicvaulteconomy")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

local PATROL_DELAY = 45 -- seconds of mining time before patrols arrive, matching the mission's own "strip-mine ... before their patrols arrive" briefing

-- v4.0.0: the first War Contract that pushes a faction's Famine Score UP as
-- a direct combat-side action, mirroring Relief Convoy's pull down. Strip-mine ore from the
-- enemy's own contested territory and keep it -- unlike Resource Heist, nothing is handed
-- back to the giver; denying the enemy the resources (and profiting from them yourself) is
-- the entire point.
mission._Debug = 0
mission._Name = "War Contract: Scorched Earth"

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
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
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
        local materialAmount = random():getInt(4000, 10000)

        mission.data.custom.materialType = matType
        mission.data.custom.materialName = requiredMaterial.name
        mission.data.custom.materialAmount = materialAmount

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Travel to sector (${location.x}:${location.y}) and strip-mine ${amount} ${material} from their territory before their patrols arrive. Keep it -- denying them the resources is the mission."%_T, arguments = { location = mission.data.location, amount = materialAmount, material = requiredMaterial.name } },
            { text = "Head to sector (${location.x}:${location.y}) and mine ${amount} ${material}"%_T, arguments = { location = mission.data.location, amount = materialAmount, material = requiredMaterial.name }, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local baseReward = math.floor(100000 + heat * 125000)

        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1),
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
    if not mission.data.custom.spawned then
        spawnEvent(x, y)
        mission.data.custom.spawned = true
        mission.data.custom.spawnTime = Server().unpausedRuntime

        -- Unlike the delivery contracts (Resource Heist, Relief Convoy, etc.), this mission
        -- never pays the mined material away -- the player keeps it, that's the point. So the
        -- completion check can't just look at total current stock, or anyone already carrying
        -- this much of the target material (Iron/Titanium are common cargo) completes the
        -- contract the instant they arrive, without mining anything. Snapshot what they're
        -- carrying on arrival and require that much *more* on top of it.
        local player = Player()
        local matType = mission.data.custom.materialType
        local resources = { player:getResources() }
        mission.data.custom.baselineAmount = resources[matType + 1] or 0

        -- Live progress readout: swap the "head to sector" bullet for a running counter now
        -- that there's actual progress to show, matching the mission's own "strip-mine ore"
        -- framing rather than a generic delivery-quest checklist.
        mission.data.description[3].text = "Mining ${material}: ${progress}/${amount}"%_T
        mission.data.description[3].arguments = {
            material = mission.data.custom.materialName,
            progress = 0,
            amount = mission.data.custom.materialAmount
        }

        sync()
    end
end

-- Live progress readout: mission.phases[N].updateServer is a real structuredmission.lua
-- lifecycle hook (dispatched from the framework's own updateServer(), which the engine already
-- guarantees only ever fires server-side -- see ExamplePhase.updateServer in the vanilla
-- framework's own template) polled on the phase's updateInterval (1 second by default, unset
-- here). Only syncs when the displayed number actually changes, so idle time between mining
-- runs doesn't spam a sync every second.
mission.phases[1].updateServer = function(timeStep)
    if not mission.data.custom.spawned or mission.data.description[3].fulfilled then return end

    local player = Player()
    local matType = mission.data.custom.materialType
    local requiredAmount = mission.data.custom.materialAmount
    local baselineAmount = mission.data.custom.baselineAmount or 0

    local resources = { player:getResources() }
    local current = resources[matType + 1] or 0
    local progress = math.max(0, math.min(requiredAmount, current - baselineAmount))

    if progress ~= mission.data.description[3].arguments.progress then
        mission.data.description[3].arguments.progress = progress
        sync()
    end
end

mission.phases[1].triggers = {
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

            local enemyIndex = mission.data.custom.enemyIndex
            if enemyIndex and enemyIndex > 0 then
                -- +20 Famine per completed raid -- the same magnitude as a single Relief
                -- Convoy delivery's -20, so one raid roughly offsets one relief run rather
                -- than dwarfing it in either direction.
                CosmicVaultEconomy.addFamineScore(enemyIndex, 20)

                local enemyFaction = Faction(enemyIndex)
                local article = {
                    title = "Territory Stripped in " .. (enemyFaction and enemyFaction.name or "Contested") .. " Space",
                    content = "An independent captain has strip-mined a contested sector belonging to " .. (enemyFaction and enemyFaction.name or "a local faction") .. ", hauling away the resources before patrols could respond. The loss deepens an already-strained supply situation.",
                    category = "War Crime"
                }
                local cv_news = include("cosmicvaultnews")
                cv_news.publishArticle(article)
            end

            sync()
            reward()
            accomplish()
        end
    },
    {
        -- The briefing promises the player a window to mine before patrols show up ("strip-mine
        -- ... before their patrols arrive"), but the defenders were being spawned immediately
        -- alongside the asteroid field in spawnEvent() -- there was never actually a window.
        -- Delayed here to match what the mission already tells the player.
        condition = function()
            if onClient() then return false end
            if not mission.data.custom.spawned or mission.data.custom.patrolsSpawned then return false end
            if (Server().unpausedRuntime - (mission.data.custom.spawnTime or 0)) < PATROL_DELAY then return false end

            -- spawnPatrols() spawns into Sector() implicitly (ShipGenerator.createDefender reads
            -- the CURRENT sector for turret/volume balancing) -- only fire once the player is
            -- actually back in the target sector to receive it, so a player who left before the
            -- delay elapsed doesn't get hostile ships spawned into whatever sector they're in
            -- instead. They'll simply get their patrols the moment they return.
            local x, y = Sector():getCoordinates()
            local targetCoords = mission.data.location
            return x == targetCoords.x and y == targetCoords.y
        end,
        callback = function()
            mission.data.custom.patrolsSpawned = true
            spawnPatrols(mission.data.location.x, mission.data.location.y)
        end
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)

    generator:createAsteroidField(0.2)

    -- createAsteroidField()'s resource-bearing asteroids each roll their material through
    -- AsteroidFieldGenerator:getAsteroidType() -- a weighted-random pick across every material
    -- plausible at this location (Balancing_GetMaterialProbability), never specifically this
    -- contract's own pre-chosen matType. A player could mine out every resource asteroid the
    -- ambient field spawned and still never find enough of -- or any of -- the one material this
    -- mission actually requires. Spawn a dedicated cluster of guaranteed-material asteroids on
    -- top of the ambient field, via the same AsteroidFieldGenerator:createSmallAsteroid() call
    -- vanilla's own field generation uses internally, so the requirement is always achievable
    -- regardless of what the ambient field happened to roll.
    local AsteroidFieldGenerator = include("asteroidfieldgenerator")
    local fieldGen = AsteroidFieldGenerator(x, y)
    local requiredMaterial = Material(mission.data.custom.materialType)
    for i = 1, 20 do
        local position = generator:getPositionInSector()
        fieldGen:createSmallAsteroid(position, 25.0, true, requiredMaterial)
    end
end

function spawnPatrols(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    for i = 1, 3 do
        local position = generator:getPositionInSector()
        local ship = ShipGenerator.createDefender(enemyFaction, position)
        ShipAI(ship.index):setAggressive()
    end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.35 then return end

    local baseReward = math.floor(100000 + heat * 125000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 1.5 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "Contract fulfilled. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Scorched Earth"%_t,
        description = "Enemy territory sits on resources they can't afford to lose. Get in there, strip-mine what you can, and get out before their patrols catch you. Keep everything you mine -- what they lose, you profit from.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Hard"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_scorched_earth.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Burn what you can't carry. Dismissed."%_T,
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
