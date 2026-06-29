package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")

function initialize()
    if onServer() then
        deferredCallback(1.0, "updateServer", 1.0)
    end
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
            local position = craft.translationf + random():getDirection() * 10000
            local sounds = {"distant-thunder1", "distant-thunder2", "distant-thunder3", "distant-thunder4"}
            play3DSound(randomEntry(sounds), SoundType.Other, position, 200000, 1)
        end
        soundInterval = random():getFloat(5, 15)
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
