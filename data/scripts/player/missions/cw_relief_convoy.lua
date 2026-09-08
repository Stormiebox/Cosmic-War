package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicVaultEconomy = include("cosmicvaulteconomy")

include("randomext")
include("structuredmission")

-- v4.0.0: Humanitarian Contract -- the first Cosmic War mission that isn't combat or an
-- act of war. Gated on a faction's Famine Score (missionbulletins.lua), not War Heat.
-- Delivering the relief supplies reduces that Famine Score directly -- Famine previously
-- had no player-facing way to go back down; it only ever accumulated from siege losses
-- and read into War Heat.
mission._Debug = 0
mission._Name = "Relief Convoy"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

local cw_relief_init = initialize
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

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }

        local x, y = Sector():getCoordinates()
        mission.data.custom.giverCoords = { x = x, y = y }

        -- Unlike the combat War Contracts, there's no adversarial "travel to a hostile
        -- sector first" phase here -- the player gathers materials from wherever they
        -- like and delivers them to the giver's own sector, so the mission location
        -- (and its map marker) is the giver's sector itself, not a synthetic waypoint.
        mission.data.location = { x = x, y = y }

        local d = length(vec2(x, y))
        local matType = MaterialType.Iron
        if d < 430 then matType = MaterialType.Titanium end
        if d < 350 then matType = MaterialType.Naonite end
        if d < 275 then matType = MaterialType.Trinium end
        if d < 150 then matType = MaterialType.Xanion end
        if d < 75 then matType = MaterialType.Ogonite end
        if d < 50 then matType = MaterialType.Avorion end

        local requiredMaterial = Material(matType)
        local materialAmount = random():getInt(3000, 8000)

        mission.data.custom.materialType = matType
        mission.data.custom.materialName = requiredMaterial.name
        mission.data.custom.materialAmount = materialAmount

        local server = Server()
        local famineScore = server and (server:getValue("cv_famine_" .. tostring(fIndex)) or 0) or 0
        mission.data.custom.famineScore = famineScore

        mission.data.description = {
            { text = "You accepted a Relief Convoy contract from ${giver}, whose people are struggling through famine."%_T, arguments = { giver = giverFaction.name } },
            { text = "Gather ${amount} ${material} and deliver it to sector (${x}:${y})."%_T, arguments = { amount = materialAmount, material = requiredMaterial.name, x = x, y = y } },
            { text = "Deliver ${amount} ${material} to (${x}:${y})"%_T, arguments = { amount = materialAmount, material = requiredMaterial.name, x = x, y = y }, bulletPoint = true, fulfilled = false }
        }

        local baseReward = math.floor(50000 + famineScore * 800)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y),
            relations = 8000,
            paymentMessage = "The relief supplies have saved lives. You have our deepest gratitude."%_T
        }

        cw_relief_init(factionIndex)
    else
        cw_relief_init(factionIndex)
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

            local player = Player()
            local giverCoords = mission.data.custom.giverCoords
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount

            local resources = { player:getResources() }
            local current = resources[matType + 1] or 0

            local x, y = Sector():getCoordinates()

            return x == giverCoords.x and y == giverCoords.y and current >= requiredAmount
        end,
        callback = function()
            local player = Player()
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount

            player:payResource("Relief Convoy delivered", Material(matType), requiredAmount)

            local giverIndex = mission.data.custom.giverIndex
            if giverIndex and giverIndex > 0 then
                -- -40 Famine per completed convoy -- a meaningful dent (Struggling starts
                -- at 50, Severe Famine at 100) without single-handedly solving a crisis.
                CosmicVaultEconomy.addFamineScore(giverIndex, -40)
            end

            mission.data.description[3].fulfilled = true
            sync()

            reward()
            accomplish()
        end
    }
}

function getBulletin(station)
    local server = Server()
    if not server then return end
    local famineScore = server:getValue("cv_famine_" .. tostring(station.factionIndex)) or 0
    if famineScore < 50 then return end -- Struggling or worse only

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local baseReward = math.floor(50000 + famineScore * 800)
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates())
    local rewardStruct = {
        credits = rewardCredits,
        relations = 8000,
        paymentMessage = "The relief supplies have saved lives. You have our deepest gratitude."%_T
    }

    return {
        brief = "Relief Convoy"%_t,
        description = "Our people are suffering through a severe resource shortage. We are asking independent captains to gather raw materials and deliver them directly to us -- no questions asked, no strings attached."%_t,
        difficulty = "Moderate"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_relief_convoy.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Thank you for hearing our call. Every shipment matters."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
