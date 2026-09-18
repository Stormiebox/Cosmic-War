-- [Cosmic War] Distress Call Escalation

local cw_original_terminate = terminate

-- We intercept the terminate function, which is called when the event times out, completes, or the player abandons it.
function terminate(...)
    if onServer() then
        local player = Player()
        if player then
            local x, y = player:getSectorCoordinates()
            -- "target" is vanilla's own file-scope local (set in its initialize()) --
            -- this file is appended into the same VFS chunk, so it's a direct upvalue here,
            -- not a copy. It's only nil if vanilla's initialize() never found a valid sector.
            local tx, ty = target and target.x, target and target.y

            -- If we terminate and the player is not currently in the distress call sector, it means the distress call was ignored or timed out.
            if tx and ty and x and y and (tx ~= 0 or ty ~= 0) and (x ~= tx or y ~= ty) then
                local random = random()
                -- 20% chance that the pirates/Xsotan establish a FOB
                if random:test(0.20) then
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
