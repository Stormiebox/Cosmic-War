package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
local cvf = include("cosmicvaultfaction")

-- Server-side script attached to players who enlist as a mercenary

function initialize()
    if onServer() then
        Player():registerCallback("onShipDestroyed", "onShipDestroyed")
    end
end

function onShipDestroyed(destroyedId, destroyerId)
    if not destroyerId then return end
    
    local player = Player()
    local craft = player.craft
    if not craft then return end
    if craft.id ~= destroyerId then return end
    
    local enlistedFactionId = player:getValue("cw_mercenary_faction")
    if not enlistedFactionId then return end
    
    local destroyedEntity = Entity(destroyedId)
    if not destroyedEntity then return end
    
    local destroyedFactionId = destroyedEntity.factionIndex
    if not destroyedFactionId then return end
    
    -- Check if destroyed faction is at war with enlisted faction
    local enlistedFaction = Faction(enlistedFactionId)
    local destroyedFaction = Faction(destroyedFactionId)
    
    if enlistedFaction and destroyedFaction then
        local relation = enlistedFaction:getRelations(destroyedFactionId)
        if relation <= -80000 then -- At war
            -- Determine if the target was a civilian ship
            local isCivilian = destroyedEntity:getValue("is_civilian") or destroyedEntity:getValue("is_freighter")
            local title = destroyedEntity.title or ""
            if title:match("Miner") or title:match("Freighter") or title:match("Trader") or title:match("Transport") then
                isCivilian = true
            end
            
            local sadisticTrait = enlistedFaction:getTrait("sadistic") or 0
            
            -- Sympathetic faction hates war crimes
            if isCivilian and sadisticTrait < 0 then
                local playerRelation = player:getRelations(destroyedFactionId)
                if playerRelation then
                    player:setRelation(enlistedFactionId, math.max(-100000, player:getRelations(enlistedFactionId) - 5000))
                    player:sendChatMessage(enlistedFaction.name, 1, "We do not pay mercenaries to slaughter unarmed civilians! Your standing with us has dropped.")
                end
                return -- No bounty payout!
            end

            -- Double Bounty Payout base
            local baseBounty = 0
            if destroyedEntity.isShip then baseBounty = 25000 end
            if destroyedEntity.isStation then baseBounty = 250000 end
            
            if baseBounty > 0 then
                -- Check for Mercantile trait
                local hasMercantile = false
                if cvf and cvf.getTrait then
                    hasMercantile = (cvf.getTrait(enlistedFaction.index, "cw_mercantile") or 0) > 0
                else
                    hasMercantile = (enlistedFaction:getValue("cosmic_trait_cw_mercantile") or 0) > 0
                end
                
                if hasMercantile then
                    baseBounty = baseBounty * 3
                end
                
                -- Sadistic faction loves war crimes
                if isCivilian and sadisticTrait > 0 then
                    baseBounty = baseBounty * (1.0 + sadisticTrait) -- Up to 2x more
                end
            
                player:receive("Mercenary Bounty", baseBounty)
                local playerRelation = player:getRelations(destroyedFactionId)
                -- Decrease relations safely with the destroyed faction
                if playerRelation then
                    player:setRelation(destroyedFactionId, math.max(-100000, playerRelation - 5000))
                end
            end
        end
    end
end
