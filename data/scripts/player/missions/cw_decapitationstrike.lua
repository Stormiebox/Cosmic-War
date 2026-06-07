package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")
include("relations")

local MissionUT = include("missionutility")
local ShipGenerator = include("shipgenerator")
local Balancing = include("galaxy")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Decapitation Strike"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/ShipBounty.png"
mission.data.autoTrackMission = true

local cw_decapitationstrike_init = initialize
function initialize(factionIndex)
    if onServer() and not _restoring then
        local fIndex = factionIndex
        if type(factionIndex) == "table" then
            fIndex = factionIndex.giver or factionIndex[1]
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
        mission.data.custom.enemyIndex = enemyIndex

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

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        mission.data.custom.heat = heat

        mission.data.description = {
            { text = "You accepted a Decapitation Strike contract from ${giver}."%_T, arguments = { giver = giverFaction.name } },
            { text = "${enemy} has deployed their Flagship to the frontline. Destroy it to end this war."%_T, arguments = { enemy = enemyName } },
            { text = "Jump to sector (${location.x}:${location.y})"%_T, bulletPoint = true, fulfilled = false },
            { text = "Destroy the Enemy Flagship"%_T,                   bulletPoint = true, fulfilled = false, visible = false }
        }

        -- Astronomical base reward for a boss fight
        local baseReward = math.floor(500000 + heat * 1000000)
        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 35000,
            paymentMessage =
                "The enemy Flagship is destroyed! Their fleet is completely broken! We are suing for peace immediately."%_T
        }

        cw_decapitationstrike_init(factionIndex)
    else
        cw_decapitationstrike_init(factionIndex)
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
        spawnFlagship(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    if onClient() then return end
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    if enemyFaction then
        Player():sendChatMessage(enemyFaction.name, 1,
            "You dare challenge our Dreadnought? We will crush you and your cowardly employers!"%_T)
    end
end

mission.phases[1].triggers = {
    {
        condition = function()
            if not atTargetLocation() then return false end
            if not mission.data.custom.spawned then return false end

            local targets = { Sector():getEntitiesByScriptValue("cw_flagship") }
            return #targets == 0
        end,
        callback = function()
            finishAndReward()
        end
    }
}

function spawnFlagship(x, y)
    if onClient() then return end
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    -- Create the Flagship (Massive Super Boss)
    local pos = generator:createPositionInSector()
    local flagship = ShipGenerator.createCarrier(enemyFaction, pos, 10.0) -- 3rd argument is volumeFactor, not raw volume

    flagship:setTitle("Flagship Dreadnought"%_T, {})
    flagship:setValue("cw_flagship", true)

    -- Give it boss properties
    flagship:addScript("data/scripts/entity/story/boss.lua")
    flagship.damageMultiplier = 3.0

    -- Scale HP immensely (up to 8x based on heat)
    local heat = mission.data.custom.heat or 1.0
    local hpMult = math.max(4.0, 8.0 * heat)

    flagship.durability = flagship.durability * hpMult
    flagship.maxDurability = flagship.maxDurability * hpMult

    if flagship.shieldDurability then
        flagship.shieldDurability = flagship.shieldDurability * hpMult
        flagship.shieldMaxDurability = flagship.shieldMaxDurability * hpMult
    end

    -- Spawn a massive defender fleet to protect it
    local numDefenders = math.floor(4 + (heat * 4))
    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:createPositionInSector(1500))
        ShipAI(ship.index):setAggressive()
    end
end

function finishAndReward()
    local giverFaction = Faction(mission.data.custom.giverIndex)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)

    if giverFaction and enemyFaction then
        -- Force an immediate ceasefire and relationship reset
        local rel = giverFaction:getRelations(enemyFaction.index) or 0
        local targetRel = 0 -- Neutral
        if rel < targetRel then
            Galaxy():setFactionRelations(giverFaction, enemyFaction, targetRel)
        end

        -- Clear war markers
        giverFaction:setValue("enemy_faction", 0)
        giverFaction:setValue("cw_target_faction", 0)
        giverFaction:setValue("cw_war_bias", 400) -- Severely damage aggressive tendencies

        enemyFaction:setValue("enemy_faction", 0)
        enemyFaction:setValue("cw_target_faction", 0)
        enemyFaction:setValue("cw_war_bias", 400)
    end

    reward()
    accomplish()
end

-- Added by Cosmic War for Avorion 2.0 Compatibility
function getBulletin(station)
    local heat = 0
    if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
        heat = CosmicWarBridge.getFactionWarHeat(station.factionIndex) or 0
    end
    if heat < 1 then return end

    return {
        brief = "War Contract: Decapitation Strike"%_T,
        description = "The enemy Flagship has entered the sector. This is our chance to end the war."%_T,
        difficulty = "Extreme"%_T,
        script = "data/scripts/player/missions/cw_decapitationstrike.lua",
        icon = "data/textures/icons/ShipBounty.png",
        arguments = { { giver = station.factionIndex } },
        msg = "Warning: This is a suicide mission. The enemy Flagship is heavily armed and escorted. Do not accept unless you have a fleet."%_T,
        onAccept = [[
            local self, player = ...
            local faction = Faction(self.arguments[1].giver)
            if faction and player then player:sendChatMessage(faction.name, 0, self.msg) end
        ]]
    }
end
