package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

local MissionUT = include("missionut")
local ShipGenerator = include("shipgenerator")
local Balancing = include("galaxy")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

mission._Debug = 0
mission._Name = "War Contract: Border Skirmish"

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/combat.png"
mission.data.autoTrackMission = true

local cw_skirmish_init = initialize
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
            local x, y = Sector():getCoordinates()
            local pirateLevel = Balancing_GetPirateLevel(x, y)
            enemyIndex = Galaxy():getPirateFaction(pirateLevel).index
        end

        mission.data.custom.giverIndex = fIndex
        mission.data.custom.enemyIndex = enemyIndex

        local x, y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
        local targetX, targetY = MissionUT.getSector(x, y, 2, 10, false, false, false, false, insideBarrier)

        if not targetX or not targetY then
            terminate()
            return
        end

        mission.data.location = { x = targetX, y = targetY }

        local enemyFaction = Faction(enemyIndex)
        local enemyName = enemyFaction and enemyFaction.name or "hostiles" % _t

        mission.data.description = {
            "You accepted a skirmish contract from ${giver}." % _t % { giver = giverFaction.name },
            "Intercept and eliminate the border patrol belonging to ${enemy}." % _t % { enemy = enemyName },
            { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
            { text = "Destroy the patrol",                           bulletPoint = true, fulfilled = false, visible = false }
        }

        local heat = 0
        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
            heat = CosmicWarBridge.getFactionWarHeat(fIndex) or 0
        end
        mission.data.custom.heat = heat

        local baseReward = math.floor(20000 + heat * 30000)

        mission.data.reward = {
            credits = baseReward * Balancing.GetSectorRewardFactor(x, y),
            relations = 4000,
            paymentMessage = "Patrol eliminated. We will not be intimidated on our own borders. Payment transferred." %
            _t
        }

        cw_skirmish_init(factionIndex)
    else
        cw_skirmish_init(factionIndex)
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
        spawnSkirmish(x, y)
        mission.data.custom.spawned = true
    end
end

mission.phases[1].triggers = {
    {
        condition = function() return atTargetLocation() and mission.data.custom.spawned and
            #Sector():getEntitiesByScriptValue("cw_skirmish_target") == 0 end,
        callback = function()
            reward()
            accomplish()
        end
    }
}

function spawnSkirmish(x, y)
    local generator = SectorGenerator(x, y)
    local enemyFaction = Faction(mission.data.custom.enemyIndex)
    local numDefenders = math.floor(3 + ((mission.data.custom.heat or 0) * 4))

    for i = 1, numDefenders do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:createPositionInSector())
        ship:setValue("cw_skirmish_target", true)
    end
end
