package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")
local CosmicVaultEconomy = include("cosmicvaulteconomy")
local CosmicVaultTerritory = include("cosmicvaultterritory")
local CosmicWarBridge = include("cosmicwarbridge")

include("randomext")
include("structuredmission")

-- v4.0.0: the first tie between Humanitarian Contracts and territorial
-- Expansion Momentum. Unlike Relief Convoy (delivers to the giver's own sector), the
-- destination here is a sector the faction is actively expanding toward -- the same
-- CosmicWarBridge.findExpansionCandidate() directional-walk the Imperialist trait's own
-- organic growth and the Intelligence Network's preview both already use. Successful
-- delivery directly settles that sector for the faction (cvt.expandToSector, the same
-- function the organic roll itself uses) -- a guaranteed, player-assisted expansion
-- instead of leaving it to chance, framed as resettling refugees rather than conquest.
mission._Debug = 0
mission._Name = "Refugee Resettlement"

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

        local targetX, targetY = CosmicWarBridge.findExpansionCandidate(giverFaction, 15)
        if not targetX or not targetY then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }

        local x, y = Sector():getCoordinates()
        mission.data.custom.giverCoords = { x = x, y = y }
        mission.data.custom.targetX = targetX
        mission.data.custom.targetY = targetY
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
        local materialAmount = random():getInt(3000, 8000)

        mission.data.custom.materialType = matType
        mission.data.custom.materialName = requiredMaterial.name
        mission.data.custom.materialAmount = materialAmount

        local server = Server()
        local famineScore = server and (server:getValue("cv_famine_" .. tostring(fIndex)) or 0) or 0
        mission.data.custom.famineScore = famineScore

        mission.data.description = {
            { text = "You accepted a Refugee Resettlement contract from ${giver}. They want to give their people fleeing famine a real fresh start."%_T, arguments = { giver = giverFaction.name } },
            { text = "Gather ${amount} ${material} and deliver it to sector (${x}:${y}) -- the site of a planned new settlement."%_T, arguments = { amount = materialAmount, material = requiredMaterial.name, x = targetX, y = targetY } },
            { text = "Deliver ${amount} ${material} to (${x}:${y})"%_T, arguments = { amount = materialAmount, material = requiredMaterial.name, x = targetX, y = targetY }, bulletPoint = true, fulfilled = false }
        }

        local baseReward = math.floor(60000 + famineScore * 900)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y),
            relations = 10000,
            paymentMessage = "Our people have a new home, thanks to you. We won't forget this."%_T
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

            local player = Player()
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount

            local resources = { player:getResources() }
            local current = resources[matType + 1] or 0

            local x, y = Sector():getCoordinates()

            return x == mission.data.custom.targetX and y == mission.data.custom.targetY and current >= requiredAmount
        end,
        callback = function()
            local player = Player()
            local matType = mission.data.custom.materialType
            local requiredAmount = mission.data.custom.materialAmount

            player:payResource("Resettlement supplies delivered", Material(matType), requiredAmount)

            local giverIndex = mission.data.custom.giverIndex
            if giverIndex and giverIndex > 0 then
                CosmicVaultEconomy.addFamineScore(giverIndex, -20)
                CosmicWarBridge.recordFamineReliefApplied(giverIndex, 20)

                -- Settle the sector for real, if it's still unclaimed -- another faction
                -- (or the giver's own organic roll) may have already reached it first.
                if not Galaxy():getControllingFaction(mission.data.custom.targetX, mission.data.custom.targetY) then
                    CosmicVaultTerritory.expandToSector(mission.data.custom.targetX, mission.data.custom.targetY, giverIndex, false)
                    Player():sendChatMessage(Faction(giverIndex).name, 0, "The settlement is founded. This sector is ours now."%_T)
                else
                    Player():sendChatMessage(Faction(giverIndex).name, 0, "Someone reached the sector first, but the supplies weren't wasted -- our people are still grateful."%_T)
                end
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

    -- Only makes narrative and mechanical sense for a faction actively pushing outward.
    local cvf = include("cosmicvaultfaction")
    if (cvf.getTrait(station.factionIndex, "cw_imperialist") or 0) <= 0 then return end

    local targetX, targetY = CosmicWarBridge.findExpansionCandidate(giverFaction, 15)
    if not targetX or not targetY then return end

    local baseReward = math.floor(60000 + famineScore * 900)
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates())
    local rewardStruct = {
        credits = rewardCredits,
        relations = 10000,
        paymentMessage = "Our people have a new home, thanks to you. We won't forget this."%_T
    }

    return {
        brief = "Refugee Resettlement"%_t,
        description = "Famine has left many of our people desperate for a fresh start. We've identified a promising sector to resettle them in -- we just need the supplies to get a foothold established."%_t,
        difficulty = "Moderate"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_refugeeresettlement.lua",
        icon = "data/textures/icons/ResourceSteal.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Thank you. A new home means everything to them right now."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
