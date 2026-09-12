package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")

local cvf = include("cosmicvaultfaction")
local CosmicWarBridge = include("cosmicwarbridge")

-- Server-side script attached to players who own Warbonds.
--
-- Keyed by the faction index as a STRING, not a number. secure()/restore() round-trips
-- this table through the engine's serializer, and no vanilla script pairs a sparse
-- numeric key with a table value in secured data: the ones storing tables key them by
-- string (shipappearances.lua's data.visibleShips[name], scrapyard.lua's
-- dockedWreckages[id.string]) or by contiguous array (factory.lua's currentProductions),
-- while the one using a sparse numeric key stores a bare scalar (scrapyard.lua's
-- licenses[factionIndex] = time). Every public function here still takes and returns a
-- numeric faction index; the string key is internal to this table.
local activeBonds = {} -- { ["<factionIndex>"] = { amount = X, ... } }

local function bondKey(factionIndex)
    return tostring(factionIndex)
end

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
    -- Re-key on the way in, so a portfolio saved under the old numeric keys carries over
    -- instead of being abandoned.
    activeBonds = {}
    for key, bond in pairs(data.activeBonds or {}) do
        if type(bond) == "table" then
            activeBonds[bondKey(key)] = bond
        end
    end
end

function CW_Warbonds.addBond(factionIndex, amount)
    local key = bondKey(factionIndex)
    if not activeBonds[key] then
        local server = Server()
        local initialFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
        activeBonds[key] = {
            amount = 0,
            initialFamine = initialFamine,
            -- v4.0.0: also snapshot how much Humanitarian-Contract famine
            -- relief this faction has ever received, so maturity can back it out of the
            -- payout calculation -- see checkWarbondStatus() below.
            initialReliefApplied = CosmicWarBridge.getFamineReliefApplied(factionIndex),
            timestamp = server.unpausedRuntime
        }
    end
    activeBonds[key].amount = (tonumber(activeBonds[key].amount) or 0) + amount
end

function CW_Warbonds.getBondAmount(factionIndex)
    local bond = activeBonds[bondKey(factionIndex)]
    if bond then
        return tonumber(bond.amount) or 0
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
    local key = bondKey(factionIndex)
    local bond = activeBonds[key]
    if not bond then return nil, "No active Warbond with that faction." end

    local bondAmount = tonumber(bond.amount)
    if not bondAmount then
        activeBonds[key] = nil
        return nil, "That Warbond certificate is unreadable and has been written off."
    end

    local server = Server()
    local poolKey = "cw_warbond_pool_" .. tostring(factionIndex)
    local pool = server:getValue(poolKey) or 0
    server:setValue(poolKey, math.max(0, pool - bondAmount))

    local payout = math.floor(bondAmount * 0.40)
    activeBonds[key] = nil

    return payout
end

-- v4.0.0: read-only preview for the Galactic Politics tab's War Room sub-tab -- "what
-- would this bond pay out if the war ended right now." Reuses checkWarbondStatus()'s
-- exact famine-outcome formula (including the relief-during-hold correction) so the
-- number shown is never just a plausible guess; it mutates nothing.
function CW_Warbonds.getActiveBonds()
    local server = Server()
    local out = {}
    for key, bond in pairs(activeBonds) do
        local factionIndex = tonumber(key)
        local currentFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
        local rawFamineDelta = currentFamine - (bond.initialFamine or 0)
        local reliefDuringHold = CosmicWarBridge.getFamineReliefApplied(factionIndex) - (bond.initialReliefApplied or 0)
        local famineDelta = rawFamineDelta + reliefDuringHold
        local outcomeQuality = 1.0 - math.min(1.0, math.max(0, famineDelta) / 150)
        local payoutMultiplier = outcomeQuality * 3.0

        table.insert(out, {
            factionIndex = factionIndex,
            amount = tonumber(bond.amount) or 0,
            projectedMultiplier = payoutMultiplier,
            projectedPayout = math.floor((tonumber(bond.amount) or 0) * payoutMultiplier)
        })
    end
    return out
end

function CW_Warbonds.checkWarbondStatus()
    local player = Player()
    local server = Server()
    local now = server.unpausedRuntime

    for key, bond in pairs(activeBonds) do
        local factionIndex = tonumber(key)
        -- Read the face value once, up front. Every other read of this field in the file
        -- already treats it as possibly missing; the payout below was the only one that
        -- didn't, and a missing value there threw before the cleanup at the end of the
        -- branch could run -- so a single unreadable bond re-threw on every update
        -- interval for as long as it sat in the portfolio.
        local bondAmount = tonumber(bond.amount)

        if not bondAmount then
            -- Nothing can be paid on a certificate with no face value, and nothing can
            -- recover it either, so clear it rather than leave it to fail again.
            activeBonds[key] = nil
            include("cosmicvaultdebug").warn("Cosmic War",
                "Warbond for faction %s had no readable amount; written off. Surviving fields: initialFamine=%s timestamp=%s initialReliefApplied=%s",
                tostring(key), tostring(bond.initialFamine), tostring(bond.timestamp), tostring(bond.initialReliefApplied))
            player:sendChatMessage("Cosmic War Bank", 1, "One of your Warbond certificates is unreadable and has been written off our books. No payout was possible on it."%_T)
        else
            local heat = CosmicWarBridge.getFactionWarHeat(factionIndex) or 0

            -- If war heat is back to 0, the war state has ended. Bond must be held for 2 hours (7200s)
            if heat <= 0 and (now - (bond.timestamp or 0)) >= 7200 then
                -- The global investment pool tracks currently-outstanding bonds across all
                -- players -- maturing one (win or lose) always frees its room back up,
                -- whether or not the faction itself still exists.
                local poolKey = "cw_warbond_pool_" .. tostring(factionIndex)
                local pool = server:getValue(poolKey) or 0
                server:setValue(poolKey, math.max(0, pool - bondAmount))

                local faction = Faction(factionIndex)
                if faction then
                    -- The return scales with how costly the war actually was: 0% at a
                    -- catastrophic +150 famine swing (the faction was effectively broken),
                    -- up to the full 300% if famine held steady or improved.
                    local currentFamine = server:getValue("cv_famine_" .. tostring(factionIndex)) or 0
                    local rawFamineDelta = currentFamine - (bond.initialFamine or 0)

                    -- Relief the bondholder delivered themselves is added back, so the
                    -- payout tracks the war rather than the Humanitarian Contracts the
                    -- player flew for that same faction while holding the bond.
                    local reliefDuringHold = CosmicWarBridge.getFamineReliefApplied(factionIndex) - (bond.initialReliefApplied or 0)
                    local famineDelta = rawFamineDelta + reliefDuringHold
                    local outcomeQuality = 1.0 - math.min(1.0, math.max(0, famineDelta) / 150)
                    local payoutMultiplier = outcomeQuality * 3.0

                    if payoutMultiplier <= 0.05 then
                        player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into suffered catastrophic losses during the war. Your bonds are now worthless paper."%_T)
                    else
                        local payout = math.floor(bondAmount * payoutMultiplier)
                        player:receive("Matured Warbonds Payout", payout)
                        player:sendChatMessage("Cosmic War Bank", 0, "Your Warbonds for %1% have matured following the war's end! Paid out %2% Credits (%3%% return, based on how costly the war was for them)."%_T, faction.name, createMonetaryString(payout), tostring(math.floor(payoutMultiplier * 100)))
                    end
                else
                    player:sendChatMessage("Cosmic War Bank", 1, "The faction you invested Warbonds into has collapsed completely. Your bonds are now worthless paper."%_T)
                end

                activeBonds[key] = nil
            end
        end
    end
end
