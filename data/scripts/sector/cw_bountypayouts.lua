package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

-- namespace CW_BountyPayouts
CW_BountyPayouts = CW_BountyPayouts or {}

function CW_BountyPayouts.initialize()
    if onServer() then
        Sector():registerCallback("onDestroyed", "onDestroyed")
        Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    end
end

function CW_BountyPayouts.onPlayerEntered(playerIndex)
    local player = Player(playerIndex)
    if not player then return end
    
    local x, y = Sector():getCoordinates()
    local sOwnerFaction = Galaxy():getControllingFaction(x, y)
    local sOwner = sOwnerFaction and sOwnerFaction.index or 0
    if not sOwner or sOwner <= 0 then return end
    
    local server = Server()
    if not server then return end
    
    local factionStr = server:getValue("factions")
    if type(factionStr) ~= "string" or factionStr == "" then return end
    
    for id in string.gmatch(factionStr, "([^,]+)") do
        local fIndex = tonumber(id)
        if fIndex then
            local f = Faction(fIndex)
            if f and f.isAIFaction then
                if f:getValue("cw_bounty_enemy") == sOwner then
                    if (f:getValue("cw_bounty_expires") or 0) > server.unpausedRuntime then
                        -- Active bounty on the sector owner!
                        local reward = f:getValue("cw_bounty_reward") or 0
                        if reward > 0 then
                            player:sendChatMessage("Bounty Network"%_T, 0, "Incoming Transmission: %1% has placed an active War Bounty on military assets in this sector!"%_T, f.name)
                            break
                        end
                    end
                end
            end
        end
    end
end

function CW_BountyPayouts.onDestroyed(destroyedId, destroyerId)
    local victim = Sector():getEntity(destroyedId)
    if not victim then return end

    if victim.type ~= EntityType.Ship and victim.type ~= EntityType.Station then return end
    
    -- Filter out civilians and miners
    if victim.type == EntityType.Ship then
        if victim:hasScript("civilship.lua") or victim:hasScript("miner.lua") or victim:hasScript("freighter.lua") or victim:hasScript("trader.lua") then 
            return 
        end
    end

    local victimFactionIndex = victim.factionIndex
    if not victimFactionIndex or victimFactionIndex <= 0 then return end

    local destroyer = Sector():getEntity(destroyerId)
    if not destroyer then return end
    if not destroyer.factionIndex then return end

    local killerFaction = Faction(destroyer.factionIndex)
    if not killerFaction then return end

    -- Only players or player alliances can claim bounties
    local killer
    if killerFaction.isPlayer then
        killer = Player(killerFaction.index)
    elseif killerFaction.isAlliance then
        killer = Alliance(killerFaction.index)
    else
        return
    end
    if not killer then return end

    local server = Server()
    if not server then return end

    local factionStr = server:getValue("factions")
    if type(factionStr) ~= "string" or factionStr == "" then return end

    for id in string.gmatch(factionStr, "([^,]+)") do
        local fIndex = tonumber(id)
        if fIndex then
            local f = Faction(fIndex)
            if f and f.isAIFaction then
                local bountyEnemy = f:getValue("cw_bounty_enemy")
                if bountyEnemy == victimFactionIndex then
                    local expires = f:getValue("cw_bounty_expires") or 0
                    if expires > server.unpausedRuntime then
                        -- Found a valid, unexpired global bounty
                        
                        local reward = f:getValue("cw_bounty_reward") or 0
                        if reward <= 0 then break end
                        
                        -- Scale reward by target significance
                        local multiplier = 1
                        if victim.type == EntityType.Station then
                            multiplier = 10
                        elseif victim:getValue("is_boss") or string.match(tostring(victim.title), "Battleship") or string.match(tostring(victim.title), "Dreadnought") then
                            multiplier = 5
                        end

                        local finalReward = reward * multiplier
                        
                        local scriptPath = "data/scripts/player/background/cw_bounty_tracker.lua"

                        if not killer:hasScript(scriptPath) then
                            -- First kill against this bounty: addScriptOnce is deferred (like
                            -- removeScript), so the tracker won't be attached yet if we tried to
                            -- invokeFunction("registerKill") on it within this same callback.
                            -- Pass the reward straight through initialize() instead.
                            killer:addScriptOnce(scriptPath, fIndex, victimFactionIndex, finalReward)
                        else
                            local invokeStatus, targetIdx = killer:invokeFunction(scriptPath, "getTargetFaction")
                            if invokeStatus == 0 and targetIdx == victimFactionIndex then
                                killer:invokeFunction(scriptPath, "registerKill", finalReward)
                            else
                                -- Player is already tracking a DIFFERENT bounty and cannot accept this one right now.
                                if killer.isPlayer then
                                    killer:sendChatMessage("Bounty Network"%_T, 1, "You cannot collect this bounty while another Bounty License is active. Use /cosmicwarbounties to check your current License."%_T)
                                end
                            end
                        end
                        
                        break -- Only process one bounty at a time
                    end
                end
            end
        end
    end
end
