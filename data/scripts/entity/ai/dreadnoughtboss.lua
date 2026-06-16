package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
local ShipUtility = include("shiputility")

-- namespace DreadnoughtBoss
DreadnoughtBoss = {}

function DreadnoughtBoss.getUpdateInterval()
    return 0.5
end

if onServer() then

function DreadnoughtBoss.initialize()
    local ship = Entity()
    -- Render the vanilla Boss Health Bar across the entire sector!
    ship:addScriptOnce("data/scripts/sector/story/bosshealthbar.lua")

    -- Make them immune to boarding
    ship.boardable = false

    -- Setup AI
    local ai = ShipAI()
    ai:setAggressive()
end

function DreadnoughtBoss.updateServer(timeStep)
    local ship = Entity()
    if not valid(ship) then return end

    local ai = ShipAI()
    if ai.isAttacking then return end -- Already busy

    -- Prioritize targeting military ships and stations over weak freighters
    local sector = Sector()
    local enemies = {sector:getEntitiesByFaction(sector.numPlayers > 0 and sector:getPlayers()[1].index or 0)} -- Generic check

    local bestTarget = nil
    local highestThreat = -1

    for _, entity in pairs({sector:getEntitiesByType(EntityType.Ship), sector:getEntitiesByType(EntityType.Station)}) do
        if ai:isEnemy(entity) then
            local threat = 0
            if entity.isStation then threat = threat + 500 end
            if entity.hasArmedTurrets then threat = threat + 1000 end
            threat = threat + (entity.firePower or 0)

            if threat > highestThreat then
                highestThreat = threat
                bestTarget = entity
            end
        end
    end

    if bestTarget then
        ai:setAttack(bestTarget)
    end
end

end

function getUpdateInterval(...)
    if DreadnoughtBoss.getUpdateInterval then return DreadnoughtBoss.getUpdateInterval(...) end
end
function initialize(...)
    if DreadnoughtBoss.initialize then return DreadnoughtBoss.initialize(...) end
end
function updateServer(...)
    if DreadnoughtBoss.updateServer then return DreadnoughtBoss.updateServer(...) end
end


return DreadnoughtBoss
