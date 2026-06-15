package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")

-- Server-side script attached to players who own Warbonds
local activeBonds = {} -- { [factionIndex] = { amount = X } }

function initialize()
    if onServer() then
        -- Check every 10 minutes if the war has resolved
        Timer():create("checkWarbondStatus", 600)
    end
end

function secure()
    return {activeBonds = activeBonds}
end

function restore(data)
    activeBonds = data.activeBonds or {}
end

function addBond(factionIndex, amount)
    if not activeBonds[factionIndex] then
        activeBonds[factionIndex] = { amount = 0 }
    end
    activeBonds[factionIndex].amount = activeBonds[factionIndex].amount + amount
end

function checkWarbondStatus()
    local player = Player()
    
    local cw_success = true; include("cosmicwarbridge")
    if cw_success and CosmicWarBridge then
        for factionIndex, bond in pairs(activeBonds) do
            local heat = CosmicWarBridge.getFactionWarHeat(factionIndex) or 0
            
            -- If war heat is back to 0, the war state has ended.
            if heat <= 0 then
                -- Determine if they won or lost. For simplicity, we assume maturity if the faction still exists and is healthy.
                local faction = Faction(factionIndex)
                if faction then
                    local payout = bond.amount * 3 -- 300% payout
                    player:receive("Matured Warbonds Payout", payout)
                    player:sendChatMessage("Cosmic War Bank", 0, "Your Warbonds for %1% have fully matured following the conclusion of their war! Paid out %2% Credits.", faction.name, payout)
                else
                    player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into has collapsed. Your bonds are now worthless paper.")
                end
                
                activeBonds[factionIndex] = nil
            end
        end
    end
end
