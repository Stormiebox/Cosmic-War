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

DreadnoughtBoss.retargetTimer = 0

function DreadnoughtBoss.updateServer(timeStep)
    local ship = Entity()
    if not valid(ship) then return end

    local ai = ShipAI()
    
    -- Increment timer for dynamic aggro swapping
    DreadnoughtBoss.retargetTimer = (DreadnoughtBoss.retargetTimer or 0) + timeStep
    
    -- Only evaluate if we have no target, OR if 15 seconds have passed
    if ai.isAttacking and DreadnoughtBoss.retargetTimer < 15 then 
        return 
    end
    
    DreadnoughtBoss.retargetTimer = 0 -- Reset timer

    -- Prioritize targeting military ships and stations over weak freighters
    local sector = Sector()
    local bestTarget = nil
    local highestThreat = -1

    local allEnemies = {sector:getEntitiesByType(EntityType.Ship)}
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, s in pairs(stations) do table.insert(allEnemies, s) end

    for _, entity in pairs(allEnemies) do
        if valid(entity) and ai:isEnemy(entity) then
            local threat = 0
            if entity.isStation then threat = threat + 500 end
            if entity.hasArmedTurrets then threat = threat + 1000 end
            threat = threat + (entity.firePower or 0)

            -- Apply distance penalty so the boss prioritizes targets actively engaging it at close range
            local dist = distance(ship.translationf, entity.translationf)
            threat = threat / (1 + (dist / 1500)) -- Halves threat for every 15km (1500 units) of distance

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
