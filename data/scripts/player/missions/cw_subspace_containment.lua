package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")
local MissionUT = include("missionutility")
local RiftObjects = include("dlc/rift/lib/riftobjects")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Subspace Containment"
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/vortex.png"
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
        if enemyIndex == 0 then terminate() return end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
        end

        local x, y = Sector():getCoordinates()
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }
        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "Our experimental hyperspace weapons have torn a rift in sector (${location.x}:${location.y}). Ancient structures have emerged. Secure them."%_T, arguments = { location = mission.data.location } },
            { text = "Head to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false }
        }

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        if precomputedReward then
            mission.data.reward = precomputedReward
        else
            local mult = (giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
            local rewardCredits = math.floor((200000 + heat * 200000) * Balancing_GetSectorRewardFactor(x, y) * mult)
            mission.data.reward = {
                credits = rewardCredits,
                relations = 15000,
                paymentMessage = "Subspace contained. Excellent work."%_T
            }
        end

        mission.phases[1] = {
            onTargetLocationEntered = function(x, y)
                mission.data.description[3].fulfilled = true
                mission.data.description[4] = { text = "Destroy the Ancient Protection Platform."%_T, bulletPoint = true, fulfilled = false }
                
                local sector = Sector()
                -- Add rift hazards
                sector:addScriptOnce("dlc/rift/sector/riftbackgroundthunder.lua")
                local platform = RiftObjects.createProtectionPlatform(MatrixLookUpPosition(vec3(0,0,1), vec3(0,1,0), vec3(0,0,0)))
                platform:setValue("cw_mission_target", true)
                mission.data.custom.targetId = platform.id.string
                
                sector:broadcastChatMessage(giverFaction.name, 3, "The subspace anomaly has pulled an Ancient Protection Platform into normal space. Destroy it so we can harvest the data!"%_t)
            end,
            onTargetLocationLeft = function(x, y)
                mission.data.description[3].fulfilled = false
                mission.data.description[4] = nil
            end,
            onEntityDestroyed = function(id, lastDamageInflictor)
                if id.string == mission.data.custom.targetId then
                    finishAndReward()
                end
            end
        }
    end
    if cw_init then cw_init() end
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.8 then return end

    local baseReward = math.floor(200000 + heat * 200000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 15000,
        paymentMessage = "Subspace contained. Excellent work."%_T
    }

    return {
        brief = "War Contract: Subspace Containment"%_T,
        description = "Our experimental hyperspace weapons have torn a rift in a nearby sector. Ancient structures have emerged. Destroy them and secure the zone.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Extreme"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_subspace_containment.lua",
        icon = "data/textures/icons/vortex.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Do not let the enemy secure that Ancient Tech."%_T,
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
            local rep = player:getRelations(giverIndex)
            CosmicVaultFaction.changeRelations(player.index, giverIndex, -25000)
            local giverFaction = Faction(giverIndex)
            local giverName = giverFaction and giverFaction.name or "Unknown"%_T
            player:sendChatMessage(giverName, 1, "You abandoned a critical war contract! Our trust in you is broken."%_T)
        end
    end
    if cw_mission_abandon_original then cw_mission_abandon_original() end
end
