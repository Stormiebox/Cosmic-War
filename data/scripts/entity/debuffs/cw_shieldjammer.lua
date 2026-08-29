package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CW_ShieldJammer
CW_ShieldJammer = {}

CW_ShieldJammer.duration = 10.0

function CW_ShieldJammer.getUpdateInterval()
    return 0.5
end

function CW_ShieldJammer.initialize()
    if onServer() then
        -- Initial impact effect or sound could be played here
    end
end

function CW_ShieldJammer.updateServer(timeStep)
    CW_ShieldJammer.duration = CW_ShieldJammer.duration - timeStep

    local entity = Entity()
    if not valid(entity) then
        terminate()
        return
    end

    if entity:hasComponent(ComponentType.Shield) then
        -- Force shield durability to 0 constantly, preventing regeneration and keeping it vulnerable
        entity.shieldDurability = 0
    end

    if CW_ShieldJammer.duration <= 0 then
        -- The jammer duration has expired
        terminate()
    end
end

function CW_ShieldJammer.secure()
    return { duration = CW_ShieldJammer.duration }
end

function CW_ShieldJammer.restore(data)
    CW_ShieldJammer.duration = data.duration or 10.0
end

-- We can also send client updates if we want to render particles, but for now the mechanical effect is enough.

