package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
local cvf = include("cosmicvaultfaction")

-- Server-side script attached to players who enlist as a mercenary

-- namespace CW_Mercenary
CW_Mercenary = CW_Mercenary or {}

function CW_Mercenary.initialize()
    if onServer() then
        Player():registerCallback("onShipDestroyed", "onShipDestroyed")
    end
end

function CW_Mercenary.onShipDestroyed(destroyedId, destroyerId)
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
                    cvf.changeRelations(player.index, enlistedFactionId, -5000)
                    player:sendChatMessage(enlistedFaction.name, 1, "We do not pay mercenaries to slaughter unarmed civilians! Your standing with us has dropped.")
                end
                return -- No bounty payout!
            end

            -- Hybrid Captain Scaling (Cross-Mod Synergy)
            local captainMultiplier = 1.0
            if craft:hasComponent(ComponentType.Crew) then
                local captain = craft.captain
                if captain then
                    -- Base multiplier for having any captain
                    captainMultiplier = 1.1 
                    
                    -- Tier bonus (0 for Common, 1 for Uncommon, 2 for Rare)
                    -- In Avorion API: tier is 0, 1, 2. (0=Common, 1=Uncommon, 2=Rare, 3=Epic)
                    local tier = captain.tier or 0
                    captainMultiplier = captainMultiplier + (tier * 0.15)
                    
                    -- Level bonus (0 to 5)
                    local level = captain.level or 0
                    captainMultiplier = captainMultiplier + (level * 0.05)
                else
                    -- Uncaptained ships (AI-driven drones/fighters) get penalized payouts
                    captainMultiplier = 0.5
                end
            end

            -- Balanced Bounty Payout base
            local baseBounty = 0
            if destroyedEntity.isShip then baseBounty = 10000 end
            if destroyedEntity.isStation then baseBounty = 100000 end
            
            if baseBounty > 0 then
                local sx, sy = Sector():getCoordinates()
                local dist = math.sqrt(sx * sx + sy * sy)
                local distFactor = math.max(0, (500 - dist) / 50)
                local scale = 1.0 + (distFactor * 2.5) -- Up to ~26x at the core
                baseBounty = math.floor(baseBounty * scale * captainMultiplier)
                local hasMercantile = (cvf.getTrait(enlistedFaction.index, "cw_mercantile") or 0) > 0
                if hasMercantile then
                    baseBounty = math.floor(baseBounty * 1.5)
                end
                
                -- Sadistic faction loves war crimes
                if isCivilian and sadisticTrait > 0 then
                    baseBounty = math.floor(baseBounty * (1.0 + sadisticTrait)) -- Up to 2x more
                end
            
                player:receive("Mercenary Bounty", baseBounty)
                local playerRelation = player:getRelations(destroyedFactionId)
                -- Decrease relations safely with the destroyed faction
                if playerRelation then
                    cvf.changeRelations(player.index, destroyedFactionId, -5000)
                end
            end
        end
    end
end
