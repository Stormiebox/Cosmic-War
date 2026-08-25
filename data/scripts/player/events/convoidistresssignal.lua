-- [Cosmic War] Distress Call Escalation

-- Load vanilla script
include("data/scripts/player/events/convoidistresssignal")

local cw_original_terminate = terminate

-- We intercept the terminate function, which is called when the event times out, completes, or the player abandons it.
function terminate(...)
    if onServer() then
        local x, y = Sector():getCoordinates()
        local tx, ty = getMissionLocation()

        -- If we terminate and the player is not currently in the distress call sector, it means the distress call was ignored or timed out.
        if tx and ty and (tx ~= 0 or ty ~= 0) and (x ~= tx or y ~= ty) then
            local random = random()
            -- 20% chance that the pirates/Xsotan establish a FOB
            if random:test(0.20) then
                local player = Player()
                if player then
                    local fobStr = player:getValue("cw_distress_fob_list") or ""
                    fobStr = fobStr .. tx .. "," .. ty .. ";"
                    player:setValue("cw_distress_fob_list", fobStr)
                    print("[Cosmic War] Distress Call Ignored: FOB established at " .. tx .. ":" .. ty)
                end
            end
        end
    end
    
    if cw_original_terminate then cw_original_terminate(...) end
end
