package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")

local cvf = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

-- Server-side script attached to players who own Warbonds
local activeBonds = {} -- { [factionIndex] = { amount = X } }

function initialize()
    -- Nothing needed here
end

function getUpdateInterval()
    return 600 -- Check every 10 minutes if the war has resolved
end

function updateServer(timeStep)
    checkWarbondStatus()
end

function secure()
    return {activeBonds = activeBonds}
end

function restore(data)
    activeBonds = data.activeBonds or {}
end

function addBond(factionIndex, amount)
    if not activeBonds[factionIndex] then
        local server = Server()
        local initialFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
        activeBonds[factionIndex] = { 
            amount = 0, 
            initialFamine = initialFamine,
            timestamp = server.unpausedRuntime
        }
    end
    activeBonds[factionIndex].amount = activeBonds[factionIndex].amount + amount
end

function getBondAmount(factionIndex)
    if activeBonds[factionIndex] then
        return activeBonds[factionIndex].amount
    end
    return 0
end

function checkWarbondStatus()
    local player = Player()
    
    local server = Server()
    local now = server.unpausedRuntime
        
        for factionIndex, bond in pairs(activeBonds) do
            local heat = CosmicWarBridge.getFactionWarHeat(factionIndex) or 0
            
            -- If war heat is back to 0, the war state has ended. Bond must be held for 2 hours (7200s)
            if heat <= 0 and (now - (bond.timestamp or 0)) >= 7200 then
                local faction = Faction(factionIndex)
                if faction then
                    local currentFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
                    if currentFamine > (bond.initialFamine or 0) then
                        player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into suffered heavy territorial losses during the war. Your bonds are now worthless paper.")
                    else
                        local payout = bond.amount * 3 -- 300% payout
                        player:receive("Matured Warbonds Payout", payout)
                        player:sendChatMessage("Cosmic War Bank", 0, "Your Warbonds for %1% have fully matured following a successful war! Paid out %2% Credits.", faction.name, createMonetaryString(payout))
                    end
                else
                    player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into has collapsed completely. Your bonds are now worthless paper.")
                end
                
                activeBonds[factionIndex] = nil
            end
        end
end
