package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicVaultEconomy = include("cosmicvaulteconomy")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

-- v4.0.0: a second Humanitarian Contract alongside Relief Convoy, gated at
-- Famine >= 100 ("Severe Famine") specifically -- for the worst-off factions, a smaller,
-- faster emergency delivery (framed as a critical airlift, not a bulk supply run) for a
-- bigger single-shot Famine reduction and a higher payout, so it doesn't compete with
-- Relief Convoy's own >=50 bulletin slot.
mission._Debug = 0
mission._Name = "Medical Airlift"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ResourceSteal.png"
mission.data.autoTrackMission = true

local cw_medical_init = initialize
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
        -- A smaller, faster load than Relief Convoy (3,000-8,000) -- an emergency airlift
        -- moves quickly, it doesn't wait to fill a bulk convoy.
        local materialAmount = random():getInt(1200, 3000)

        mission.data.custom.materialType = matType
        mission.data.custom.materialName = requiredMaterial.name
        mission.data.custom.materialAmount = materialAmount

        local server = Server()
        local famineScore = server and (server:getValue("cv_famine_" .. tostring(fIndex)) or 0) or 0
        mission.data.custom.famineScore = famineScore

        mission.data.description = {
            { text = "You accepted an emergency Medical Airlift contract from ${giver} -- their famine has reached crisis levels."%_T, arguments = { giver = giverFaction.name } },
            { text = "Gather ${amount} ${material} and deliver it to sector (${x}:${y}) immediately."%_T, arguments = { amount = materialAmount, material = requiredMaterial.name, x = x, y = y } },
            { text = "Deliver ${amount} ${material} to (${x}:${y})"%_T, arguments = { amount = materialAmount, material = requiredMaterial.name, x = x, y = y }, bulletPoint = true, fulfilled = false }
        }

        local baseReward = math.floor(100000 + famineScore * 1000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y),
            relations = 10000,
            paymentMessage = "You saved countless lives today. We will not forget this."%_T
        }

        cw_medical_init(factionIndex)
    else
        cw_medical_init(factionIndex)
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

            player:payResource("Medical Airlift delivered", Material(matType), requiredAmount)

            local giverIndex = mission.data.custom.giverIndex
            if giverIndex and giverIndex > 0 then
                -- -35 Famine per completed airlift -- a bigger single-shot dent than Relief
                -- Convoy's -20, reflecting both the higher >=100 severity gate and the
                -- higher reward, without single-handedly zeroing out a crisis.
                CosmicVaultEconomy.addFamineScore(giverIndex, -35)
                CosmicWarBridge.recordFamineReliefApplied(giverIndex, 35)
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
    if famineScore < 100 then return end -- Severe Famine only

    local giverFaction = Faction(station.factionIndex)
    if not giverFaction then return end

    local baseReward = math.floor(100000 + famineScore * 1000)
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates())
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "You saved countless lives today. We will not forget this."%_T
    }

    return {
        brief = "Medical Airlift"%_t,
        description = "Our famine has reached crisis levels. We need emergency supplies airlifted in immediately -- name your price, we'll pay it."%_t,
        difficulty = "Moderate"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_medical_airlift.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Thank the stars. Please, hurry."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
