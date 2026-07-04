package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

function initialize()
    if onServer() then
        -- Ensure the generator itself is always vulnerable to prevent mutual-invincibility exploits
        Entity().invincible = false

        -- Hook into all stations to give them invincibility
        local sector = Sector()
        for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            if entity.id ~= Entity().id and not entity:hasScript("cw_planetary_defense.lua") then
                entity.invincible = true
            end
        end
        
        sector:registerCallback("onEntityCreated", "onEntityCreated")
    end
end

function onEntityCreated(id)
    local entity = Entity(id)
    if entity and entity.type == EntityType.Station and entity.id ~= Entity().id then
        if not entity:hasScript("cw_planetary_defense.lua") then
            entity.invincible = true
        end
    end
end

function onRemove()
    if onServer() then
        local sector = Sector()
        
        -- Redundancy Check: Do not drop shields if another generator is active in the sector!
        for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            if entity.id ~= Entity().id and entity:hasScript("cw_planetary_defense.lua") then
                return
            end
        end

        for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
            if entity.id ~= Entity().id then
                entity.invincible = false
            end
        end
        sector:broadcastChatMessage("Server", 2, "WARNING: Planetary Shield Generator Destroyed! All stations are now vulnerable!")
    end
end
