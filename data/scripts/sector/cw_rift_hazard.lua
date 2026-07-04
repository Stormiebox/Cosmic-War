package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

function initialize()
    -- Native Sector initialization
end

function getUpdateInterval()
    return 2.0
end

local soundTimer = 0
local soundInterval = 5

function updateClient(timeStep)
    soundTimer = soundTimer + timeStep
    if soundTimer > soundInterval then
        local craft = Player().craft
        if craft then
            -- Generate a random direction vector using math.random instead of global random() to prevent client PRNG corruption
            local rx = (math.random() * 2) - 1
            local ry = (math.random() * 2) - 1
            local rz = (math.random() * 2) - 1
            local dir = normalize(vec3(rx, ry, rz))
            
            local position = craft.translationf + dir * 10000
            local sounds = {"distant-thunder1", "distant-thunder2", "distant-thunder3", "distant-thunder4"}
            local pick = sounds[math.random(1, #sounds)]
            
            -- Avorion valid global audio API for client scripts
            playSound(pick, SoundType.Other, position)
        end
        soundInterval = 5 + (math.random() * 10)
        soundTimer = 0
    end
end

function updateServer(timeStep)
    -- Drain shields by 5% every 2 seconds for ALL ships in the tear
    local sector = Sector()
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
