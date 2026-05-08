-- namespace TemporaryDefender

if onServer() then
    local cw_oldInitialize = TemporaryDefender.initialize

    function TemporaryDefender.initialize(...)
        local entity = Entity()
        if entity then
            -- Cleanup temporary war defenders once players leave to avoid sector bloat.
            entity:addScriptOnce("entity/deleteonplayersleft.lua")
        end

        if cw_oldInitialize then
            return cw_oldInitialize(...)
        end
    end
end
