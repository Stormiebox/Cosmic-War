package.path = package.path .. ";data/scripts/lib/?.lua"

function initialize()
    if onServer() then
        Sector():registerCallback("onDestroyed", "onDestroyed")
    end
end

function onDestroyed(destroyedId, destroyerId)
    local victim = Sector():getEntity(destroyedId)
    if not victim then return end

    if victim.type ~= EntityType.Ship and victim.type ~= EntityType.Station then return end

    local victimFactionIndex = victim.factionIndex
    if not victimFactionIndex or victimFactionIndex <= 0 then return end

    local destroyer = Sector():getEntity(destroyerId)
    if not destroyer then return end
    if not destroyer.factionIndex then return end

    local killerFaction = Faction(destroyer.factionIndex)
    if not killerFaction then return end

    -- Only players or player alliances can claim bounties
    if not killerFaction.isPlayer and not killerFaction.isAlliance then return end

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
                        -- Found a valid, unexpired bounty placed by faction 'f' on 'victimFactionIndex'
                        
                        -- Base Reward
                        local reward = f:getValue("cw_bounty_reward") or 0
                        if reward <= 0 then break end
                        
                        -- Scale reward by target significance
                        local multiplier = 1
                        if victim.type == EntityType.Station then
                            multiplier = 5
                        elseif victim.isBoss or victim.title == "Battleship"%_t then
                            multiplier = 3
                        end

                        local finalReward = reward * multiplier

                        killerFaction:receive("Received %1% Credits for confirming a War Bounty."%_T, finalReward)
                        
                        -- Clear the bounty to prevent farming and restrict it to a "High-Profile Hit"
                        f:setValue("cw_bounty_enemy", nil)
                        f:setValue("cw_bounty_reward", nil)
                        f:setValue("cw_bounty_expires", nil)

                        local sx, sy = Sector():getCoordinates()
                        
                        -- Dispatch Galactic News event
                        pcall(function()
                            local article = {
                                title = "War Bounty Claimed",
                                category = "Conflict",
                                content = string.format("Freelance mercenaries successfully confirmed a high-profile kill on %s forces in sector (%d:%d). %s promptly wired the %d Credits bounty, proving once again that war is a highly profitable business.", 
                                    Faction(victimFactionIndex).name, sx, sy, f.name, finalReward)
                            }
                            local cvn_success, cvn = pcall(include, "cosmicvaultnews")
                            if cvn_success and cvn and cvn.publishArticle then
                                cvn.publishArticle(article)
                            else
                                server:sendCallback("onCCNewsPublishArticle", article)
                            end
                        end)

                        break -- Only claim one bounty at a time
                    end
                end
            end
        end
    end
end
