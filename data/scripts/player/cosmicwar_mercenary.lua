package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")

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
            -- Double Bounty Payout!
            local baseBounty = 0
            if destroyedEntity.isShip then baseBounty = 25000 end
            if destroyedEntity.isStation then baseBounty = 250000 end
            
            if baseBounty > 0 then
                player:receive("Mercenary Bounty", baseBounty)
                -- Decrease player relation with the destroyed faction heavily
                local playerRelation = player:getRelations(destroyedFactionId)
                player:setRelation(destroyedFactionId, math.max(-100000, playerRelation - 5000))
            end
        end
    end
end
