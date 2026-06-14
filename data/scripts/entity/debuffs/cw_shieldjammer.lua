package.path = package.path .. ";data/scripts/lib/?.lua"

local duration = 60.0

-- namespace CW_ShieldJammer
CW_ShieldJammer = {}

function CW_ShieldJammer.getUpdateInterval()
    return 0.5
end

function CW_ShieldJammer.initialize()
    if onServer() then
        -- Initial impact effect or sound could be played here
    end
end

function CW_ShieldJammer.updateServer(timeStep)
    duration = duration - timeStep
    
    local entity = Entity()
    if not valid(entity) then
        terminate()
        return
    end

    local shield = Shield(entity.id)
    if shield then
        -- Force shield durability to 0 constantly, preventing regeneration and keeping it vulnerable
        shield.durability = 0
    end
    
    if duration <= 0 then
        -- The jammer duration has expired
        terminate()
    end
end

-- We can also send client updates if we want to render particles, but for now the mechanical effect is enough.

return CW_ShieldJammer
