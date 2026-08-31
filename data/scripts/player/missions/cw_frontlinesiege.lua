package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local CosmicVaultFaction = include("cosmicvaultfaction")

include("randomext")
include("structuredmission")

function getUpdateInterval()
    return 5.0
end


local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")

local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")
local CosmicVaultWeather = include("cosmicvaultweather")

mission._Debug = 0
mission._Name = "War Contract: Frontline Siege"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipCombat.png"
mission.data.autoTrackMission = true

local cw_frontlinesiege_init = initialize
function initialize(factionIndex)
    if onServer() and not _restoring then
        local fIndex = factionIndex
        local precomputedReward = nil
        if type(factionIndex) == "table" then
            fIndex = factionIndex.giver or factionIndex[1]
            precomputedReward = factionIndex.reward
        end

        local giverFaction = Faction(fIndex)
        if not giverFaction then
            terminate()
            return
        end

        local enemyIndex = giverFaction:getValue("enemy_faction") or 0
        if enemyIndex == 0 then
            terminate()
            return
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.giver = { factionIndex = fIndex }
        mission.data.custom.enemyIndex = enemyIndex

        if enemyIndex and enemyIndex > 0 then
            CosmicVaultFaction.changeRelations(Player().index, enemyIndex, -200000)
            Player():sendChatMessage(giverFaction.name, 0, "By accepting this contract, you have openly declared war on our enemies."%_T)
        end

        local heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        mission.data.custom.heat = heat

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 4, 15, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles"%_T

        mission.data.description = {
            { text = "You accepted a siege contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "${enemy} has established a Forward Operating Base (FOB) in a nearby sector."%_T, arguments = { enemy = enemyName } },
            { text = "Jump to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the Forward Operating Base"%_T,           bulletPoint = true, fulfilled = false, visible = false }
        }

        -- Massive payout. Scales up to 4x base depending on War Heat
        local baseReward = math.floor(375000 + heat * 1125000)
        mission.data.reward = precomputedReward or {
            credits = baseReward * Balancing_GetSectorRewardFactor(x, y) * ((Faction(mission.data.custom.giverIndex or 0) and Faction(mission.data.custom.giverIndex or 0):getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1),
            relations = 12000,
            paymentMessage = "Target destroyed. Excellent work, commander. Payment transferred."%_T
        }

        cw_frontlinesiege_init(factionIndex)
    else
        cw_frontlinesiege_init(factionIndex)
    end
end

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true

mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if not mission.data.custom.spawned then
        spawnSiegeTarget(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    if onClient() then return end
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if enemyFaction then
        Player():sendChatMessage(enemyFaction.name, 1, "We are under attack! Scramble all defenders!"%_T)
    end
end

mission.phases[1].updateServer = function(timeStep)
    if not atTargetLocation() or not mission.data.custom.spawned then return end

    mission.data.custom.waveTimer = (mission.data.custom.waveTimer or 0) + timeStep
    -- Spawn reinforcements every 2.5 minutes
    if mission.data.custom.waveTimer > 150 then
        mission.data.custom.waveTimer = 0
        spawnReinforcements()
    end

    -- Synergy: Weather-Assisted Boarding Operations
    mission.data.custom.weatherTimer = (mission.data.custom.weatherTimer or 0) + timeStep
    if mission.data.custom.weatherTimer > 10 then
        mission.data.custom.weatherTimer = 0
        local x, y = Sector():getCoordinates()
        local weather = CosmicVaultWeather.getWeatherAt(x, y)
        
        local _raw_targetStations = { Sector():getEntitiesByScriptValue("cw_siege_target") }

        local targetStations = {}

        for _, _t in pairs(_raw_targetStations) do

            if _t.type == EntityType.Ship or _t.type == EntityType.Station then

                table.insert(targetStations, _t)

            end

        end
        for _, station in pairs(targetStations) do
            local boarding = Boarding(station.index)
            if boarding then
                local baseDefense = station:getValue("cw_base_boarding_defense")
                if not baseDefense then
                    -- Boarding has no "defenseMultiplier" property (see Boarding.lua stub);
                    -- the real scalable field is "defenseLevel".
                    baseDefense = boarding.defenseLevel
                    station:setValue("cw_base_boarding_defense", baseDefense)
                end

                if weather == "IonStorm" or weather == "DarkMatterFog" then
                    boarding.defenseLevel = baseDefense * 0.5
                else
                    boarding.defenseLevel = baseDefense
                end
            end
        end
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if onClient() then return false end
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            local _raw_targets = { Sector():getEntitiesByScriptValue("cw_siege_target") }

            local targets = {}

            for _, _t in pairs(_raw_targets) do

                if valid(_t) and (_t.type == EntityType.Ship or _t.type == EntityType.Station) and _t.factionIndex == mission.data.custom.enemyIndex and _t.durability > 0 then

                    table.insert(targets, _t)

                end

            end
            return #targets == 0
        end,
        callback = function()
            finishAndReward()
        end
    }
}

function spawnSiegeTarget(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    -- Create a standard military base
    local station = generator:createMilitaryBase(enemyFaction)

    station:setTitle("Forward Operating Base"%_T, {})
    station:setValue("cw_siege_target", true)

    -- Scale Damage based on War Heat (Safer than maxDurability since block damage recalculates HP)
    local heat = mission.data.custom.heat or 0
    local hpMult = 1.0 + (heat * 3.0) -- Up to 4x Damage at max heat

    station:addBaseMultiplier(StatsBonuses.FireRate, hpMult - 1.0)
    
    local boarding = Boarding(station.index)
    if boarding then
        -- Boarding has no "defenseMultiplier" property (see Boarding.lua stub); the real
        -- scalable field is "defenseLevel". Guard against a 0 base value so the boost applies.
        boarding.defenseLevel = math.max(boarding.defenseLevel, 1.0) * hpMult
    end

    -- Spawn Initial defenders
    local numDefenders = math.floor(3 + (heat * 4))
    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ShipAI(ship.index):setAggressive()
    end
end

function spawnReinforcements()
    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if not enemyFaction then return end

    local heat = mission.data.custom.heat or 0
    local numReinforcements = math.floor(1 + (heat * 2))

    for i = 1, numReinforcements do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ShipAI(ship.index):setAggressive()
    end

    Player():sendChatMessage(enemyFaction.name, 1, "Reinforcements have arrived! Destroy the attackers!"%_T)
end

function finishAndReward()
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if enemyFaction then
        -- Strike a strategic blow by reducing their war bias slightly!
        local currentBias = enemyFaction:getValue("cw_war_bias") or 550
        enemyFaction:setValue("cw_war_bias", math.max(400, currentBias - 30))
    end

    local x, y = Sector():getCoordinates()
    local giverFaction = Faction(mission.data.custom.giverIndex)
    local article = {
        title = "Siege Broken in Sector " .. x .. ":" .. y,
        content = "A brutal siege has been broken! Defending " .. (giverFaction and giverFaction.name or "unknown") .. " forces, bolstered by independent commanders, successfully routed the invading fleet.",
        category = "War"
    }
    local cv_news = include("cosmicvaultnews")
    cv_news.publishArticle(article)

    reward()
    accomplish()
end

-- Added by Cosmic War for Avorion 2.0 Compatibility
function getBulletin(station)
    local heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    if heat < 0.6 then return end

    local baseReward = math.floor(375000 + heat * 1125000)
    local giverFaction = Faction(station.factionIndex)
    local mult = (giverFaction and giverFaction:getValue("cosmic_trait_cw_mercantile") == 1) and 3 or 1
    local rewardCredits = baseReward * Balancing_GetSectorRewardFactor(Sector():getCoordinates()) * mult
    local rewardStruct = {
        credits = rewardCredits,
        relations = 12000,
        paymentMessage = "Target destroyed. Excellent work, commander. Payment transferred."%_T
    }

    return {
        brief = "War Contract: Frontline Siege"%_t,
        description = "The enemy has established a Forward Operating Base. We need it destroyed.\n\nWARNING: Accepting this contract is an act of war. You will immediately become hostile to the target faction."%_t,
        difficulty = "Extreme"%_t,
        reward = "¢${reward}"%_t,
        script = "data/scripts/player/missions/cw_frontlinesiege.lua",
        icon = "data/textures/icons/ShipCombat.png",
        formatArguments = { reward = createMonetaryString(rewardCredits) },
        arguments = { { giver = station.factionIndex, reward = rewardStruct } },
        msg = "Command has authorized a strike on an enemy FOB. Are you ready to lead the assault?"%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end


-- Added by Cosmic War v3.0.0: Massive reputation penalty on abandoning a War Contract
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
