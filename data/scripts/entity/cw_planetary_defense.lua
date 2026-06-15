package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

function initialize()
    if onServer() then
        -- Hook into all stations to give them invincibility
        local sector = Sector()
        for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            if entity.id ~= Entity().id then
                entity.invincible = true
            end
        end
        
        sector:registerCallback("onEntityCreated", "onEntityCreated")
    end
end

function onEntityCreated(id)
    local entity = Entity(id)
    if entity and entity.type == EntityType.Station and entity.id ~= Entity().id then
        entity.invincible = true
    end
end

function onRemove()
    if onServer() then
        local sector = Sector()
        for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            entity.invincible = false
        end
        sector:broadcastChatMessage("Server", 2, "WARNING: Planetary Shield Generator Destroyed! All stations are now vulnerable!")
    end
end
