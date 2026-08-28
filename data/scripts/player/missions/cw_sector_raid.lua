package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

local MissionUT = include("missionutility")
local SectorSpecifics = include("sectorspecifics")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Sector Raid"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipCombat.png"
mission.data.autoTrackMission = true

local function findEnemySectorWithStations(startX, startY, enemyIndex)
    local specs = SectorSpecifics()
    local coords = specs.getShuffledCoordinates(random(), startX, startY, 2, 20)
    
    local galaxy = Galaxy()
    local serverSeed = Server().seed
    
    for _, coord in pairs(coords) do
        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)
        
        -- We want regular sectors, not offgrid, not blocked
        if regular and not offgrid and not blocked then
            -- We want sectors controlled by the enemy
            local controllingFaction = galaxy:getControllingFaction(coord.x, coord.y)
            if controllingFaction and controllingFaction.index == enemyIndex then
                specs:initialize(coord.x, coord.y, serverSeed)
                if specs.generationTemplate then
                    local contents = specs.generationTemplate.contents(coord.x, coord.y)
                    if contents and contents.stations and contents.stations > 0 then
                        return coord.x, coord.y
                    end
                end
            end
        end
    end
    
    return nil, nil
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
        if enemyIndex == 0 then
            terminate()
            return
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        local x, y = Sector():getCoordinates()
        
        -- Find an enemy sector with a station
        local targetX, targetY = findEnemySectorWithStations(x, y, enemyIndex)
        if not targetX or not targetY then terminate() return end

        mission.data.location = { x = targetX, y = targetY }
        
        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
        end

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat
        
        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a war contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "We need you to perform a tactical strike on an enemy installation in a nearby sector."%_T, arguments = {} },
            { text = "Travel to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy any ${enemy} station in the sector"%_T, arguments = { enemy = enemyName }, bulletPoint = true, fulfilled = false, visible = false }
        }

        local baseReward = math.floor(150000 + heat * 175000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 12000,
            paymentMessage = "Target destroyed. Contract fulfilled."%_T
        }

        cw_init(factionIndex)
    else
        cw_init(factionIndex)
    end
end

mission.globalPhase.noBossEncountersTargetSector = true

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true

mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    sync()
    
    if onServer() then
        if not mission.data.custom.initialStationCount then
            local count = 0
            for _, entity in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
                if entity.factionIndex == mission.data.custom.enemyIndex then
                    count = count + 1
                end
            end
            mission.data.custom.initialStationCount = count
            
            -- If there are no stations (e.g. destroyed by someone else before arrival), we can just auto-complete it
            if count == 0 then
                mission.data.custom.targetDestroyed = true
            end
        end
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() then return false end
            
            if mission.data.custom.targetDestroyed then return true end
            
            if mission.data.custom.initialStationCount then
                local count = 0
                for _, entity in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
                    if entity.factionIndex == mission.data.custom.enemyIndex then
                        count = count + 1
                    end
                end
                if count < mission.data.custom.initialStationCount then
                    return true
                end
            end
            
            return false
        end,
        callback = function()
            finishAndReward()
        end
    }
}

function finishAndReward()
    reward()
    accomplish()
end

function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.45 then return end

    local baseReward = math.floor(150000 + heat * 175000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 12000,
        paymentMessage = "Target destroyed. Contract fulfilled."%_T
    }

    return {
        brief = "War Contract: Sector Raid"%_T,
        description = "We're organizing a strike on an enemy-controlled sector. Your objective is simple: jump in and destroy at least one of their stations.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_T,
        difficulty = "Hard"%_T,
        reward = "¢${reward}"%_T,
        script = "data/scripts/player/missions/cw_sector_raid.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Hit them where it hurts. Dismissed."%_T,
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
