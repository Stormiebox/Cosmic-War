package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")

local cvf = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

-- Server-side script attached to players who own Warbonds
local activeBonds = {} -- { [factionIndex] = { amount = X } }

-- namespace CW_Warbonds
CW_Warbonds = CW_Warbonds or {}

function CW_Warbonds.initialize()
    -- Nothing needed here
end

function CW_Warbonds.getUpdateInterval()
    return 600 -- Check every 10 minutes if the war has resolved
end

function CW_Warbonds.updateServer(timeStep)
    CW_Warbonds.checkWarbondStatus()
end

function CW_Warbonds.secure()
    return {activeBonds = activeBonds}
end

function CW_Warbonds.restore(data)
    activeBonds = data.activeBonds or {}
end

function CW_Warbonds.addBond(factionIndex, amount)
    if not activeBonds[factionIndex] then
        local server = Server()
        local initialFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
        activeBonds[factionIndex] = {
            amount = 0,
            initialFamine = initialFamine,
            -- v4.0.0: also snapshot how much Humanitarian-Contract famine
            -- relief this faction has ever received, so maturity can back it out of the
            -- payout calculation -- see checkWarbondStatus() below.
            initialReliefApplied = CosmicWarBridge.getFamineReliefApplied(factionIndex),
            timestamp = server.unpausedRuntime
        }
    end
    activeBonds[factionIndex].amount = activeBonds[factionIndex].amount + amount
end

function CW_Warbonds.getBondAmount(factionIndex)
    if activeBonds[factionIndex] then
        return activeBonds[factionIndex].amount
    end
    return 0
end

-- v4.0.0: bonds previously had exactly one exit -- wait for the war to fully resolve,
-- however long that takes, then take whatever the famine-scaled payout happens to be.
-- No way to cut losses on a war that's clearly going badly. Cashing out early pays a
-- flat 40% -- a real penalty versus holding to maturity (which can reach 300%), but
-- strictly better than the near-total loss a catastrophic famine swing can produce, and
-- gives players actual agency instead of a one-way lock-in.
-- @return payout (number) or nil, errorMessage if there's no active bond for factionIndex
function CW_Warbonds.cashOutEarly(factionIndex)
    local bond = activeBonds[factionIndex]
    if not bond then return nil, "No active Warbond with that faction." end

    local server = Server()
    local poolKey = "cw_warbond_pool_" .. tostring(factionIndex)
    local pool = server:getValue(poolKey) or 0
    server:setValue(poolKey, math.max(0, pool - (bond.amount or 0)))

    local payout = math.floor((bond.amount or 0) * 0.40)
    activeBonds[factionIndex] = nil

    return payout
end

function CW_Warbonds.checkWarbondStatus()
    local player = Player()

    local server = Server()
    local now = server.unpausedRuntime

        for factionIndex, bond in pairs(activeBonds) do
            local heat = CosmicWarBridge.getFactionWarHeat(factionIndex) or 0

            -- If war heat is back to 0, the war state has ended. Bond must be held for 2 hours (7200s)
            if heat <= 0 and (now - (bond.timestamp or 0)) >= 7200 then
                -- v4.0.0: the global investment pool tracks currently-outstanding bonds
                -- across all players -- maturing one (win or lose) always frees its room
                -- back up, whether or not the faction itself still exists.
                local poolKey = "cw_warbond_pool_" .. tostring(factionIndex)
                local pool = server:getValue(poolKey) or 0
                server:setValue(poolKey, math.max(0, pool - (bond.amount or 0)))

                local faction = Faction(factionIndex)
                if faction then
                    -- v4.0.0: the return used to be a hard binary -- any famine increase
                    -- at all meant total loss, otherwise a flat 300%. Now it scales
                    -- smoothly with how costly the war actually was: 0% at a catastrophic
                    -- +150 famine swing (the faction was effectively broken), up to the
                    -- full 300% originally promised if famine held steady or improved.
                    local currentFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
                    local rawFamineDelta = currentFamine - (bond.initialFamine or 0)

                    -- v4.0.0: a player could otherwise buy a bond, then fly
                    -- that same faction's own Humanitarian Contracts (Relief Convoy, etc.)
                    -- to manufacture a "the war went well" reading regardless of the war's
                    -- actual outcome. Add back whatever relief was applied during the hold,
                    -- so the payout tracks the war itself, not humanitarian action taken by
                    -- the very player holding the bond.
                    local reliefDuringHold = CosmicWarBridge.getFamineReliefApplied(factionIndex) - (bond.initialReliefApplied or 0)
                    local famineDelta = rawFamineDelta + reliefDuringHold
                    local outcomeQuality = 1.0 - math.min(1.0, math.max(0, famineDelta) / 150)
                    local payoutMultiplier = outcomeQuality * 3.0

                    if payoutMultiplier <= 0.05 then
                        player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into suffered catastrophic losses during the war. Your bonds are now worthless paper.")
                    else
                        local payout = math.floor(bond.amount * payoutMultiplier)
                        player:receive("Matured Warbonds Payout", payout)
                        player:sendChatMessage("Cosmic War Bank", 0, "Your Warbonds for %1% have matured following the war's end! Paid out %2% Credits (%3%% return, based on how costly the war was for them)."%_T, faction.name, createMonetaryString(payout), tostring(math.floor(payoutMultiplier * 100)))
                    end
                else
                    player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into has collapsed completely. Your bonds are now worthless paper.")
                end

                activeBonds[factionIndex] = nil
            end
        end
end
