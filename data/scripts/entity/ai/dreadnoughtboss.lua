package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
local ShipUtility = include("shiputility")

-- namespace DreadnoughtBoss
DreadnoughtBoss = {}

function DreadnoughtBoss.getUpdateInterval()
    return 0.5
end

if onClient() then

-- registerBoss(entityId) with a real Uuid tracks that entity's own durability/shield
-- natively (no bigaibehaviour.lua tag, no manual setBossHealth sync needed) and shows its
-- own Entity title as the boss name -- both spawners (cw_strandedflagship.lua,
-- cw_decapitationstrike.lua) already set one via setTitle() before attaching this script.
function DreadnoughtBoss.initialize()
    registerBoss(Entity().id)
end

end

if onServer() then

function DreadnoughtBoss.initialize()
    local ship = Entity()
    -- Make them immune to boarding. "boardable" lives on the Boarding component, not directly
    -- on Entity -- ship.boardable is not a real property and would silently no-op.
    Boarding(ship).boardable = false

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
    if ai.isAttackingSomething and DreadnoughtBoss.retargetTimer < 15 then
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
            if entity:getNumArmedTurrets() > 0 then threat = threat + 1000 end
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



