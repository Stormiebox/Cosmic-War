package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- namespace CW_RiftHazard
CW_RiftHazard = CW_RiftHazard or {}

function CW_RiftHazard.initialize()
    -- Native Sector initialization
end

function CW_RiftHazard.getUpdateInterval()
    return 2.0
end

local soundTimer = 0
local soundInterval = 5

function CW_RiftHazard.updateClient(timeStep)
    soundTimer = soundTimer + timeStep
    if soundTimer > soundInterval then
        local localRand = Random(Seed(math.floor(Client().unpausedRuntime * 1000)))
        local craft = Player().craft
        if craft then
            -- Generate a random direction vector using local Random to prevent client PRNG corruption
            local rx = (localRand:getFloat() * 2) - 1
            local ry = (localRand:getFloat() * 2) - 1
            local rz = (localRand:getFloat() * 2) - 1
            local dir = normalize(vec3(rx, ry, rz))
            
            local position = craft.translationf + dir * 10000
            local sounds = {"distant-thunder1", "distant-thunder2", "distant-thunder3", "distant-thunder4"}
            local pick = sounds[localRand:getInt(1, #sounds)]
            
            -- Positional ambient sound; playSound() has no position parameter, only play3DSound() does.
            play3DSound(pick, SoundType.Other, position, 200000, 1)
        end
        soundInterval = 5 + (localRand:getFloat() * 10)
        soundTimer = 0
    end
end

function CW_RiftHazard.updateServer(timeStep)
    -- Drain shields by 5% every 2 seconds for ALL ships in the tear
    local sector = Sector()
    local hasTarget = false
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, entity in pairs(stations) do
        if entity:getValue("cw_mission_target") then
            hasTarget = true
            break
        end
    end
    if not hasTarget then
        local ships = {sector:getEntitiesByType(EntityType.Ship)}
        for _, entity in pairs(ships) do
            if entity:getValue("cw_mission_target") then
                hasTarget = true
                break
            end
        end
    end
    
    -- Terminate hazard if the target is destroyed or removed
    if not hasTarget then
        terminate()
        return
    end

    local entities = {sector:getEntitiesByType(EntityType.Ship)}
    for _, entity in pairs(entities) do
        -- Protect the Ancient Tech target structure (if it somehow has shields)
        if not entity:getValue("cw_mission_target") then
            if entity.shieldMaxDurability and entity.shieldMaxDurability > 0 then
                local drain = entity.shieldMaxDurability * 0.05
                entity.shieldDurability = math.max(0, entity.shieldDurability - drain)
            end
        end
    end
end
