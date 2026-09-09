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

            local resources = { player:getResources() }
            local current = resources[matType + 1] or 0

            local x, y = Sector():getCoordinates()
            local targetCoords = mission.data.location

            return x == targetCoords.x and y == targetCoords.y and current >= requiredAmount
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
    }
}

function spawnEvent(x, y)
    if onClient() then return end

    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    generator:createAsteroidField(0.2)

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
