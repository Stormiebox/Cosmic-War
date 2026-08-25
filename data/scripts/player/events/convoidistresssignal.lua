-- [Cosmic War] Distress Call Escalation

local cw_original_terminate = terminate

local function cw_getDistressTarget()
    local tx, ty
    local orig_invoke = _G.invokeClientFunction
    local orig_calling = _G.callingPlayer
    
    _G.invokeClientFunction = function(p, funcName, t)
        if funcName == "receiveCoordinates" and t and type(t) == "table" then
            tx = t.x
            ty = t.y
        end
    end
    
    local player = Player()
    if player then
        _G.callingPlayer = player.index
        if sendCoordinates then
            pcall(sendCoordinates)
        end
    end
    
    _G.invokeClientFunction = orig_invoke
    _G.callingPlayer = orig_calling
    
    return tx, ty
end

-- We intercept the terminate function, which is called when the event times out, completes, or the player abandons it.
function terminate(...)
    if onServer() then
        local player = Player()
        if player then
            local x, y = player:getSectorCoordinates()
            local tx, ty = cw_getDistressTarget()

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
