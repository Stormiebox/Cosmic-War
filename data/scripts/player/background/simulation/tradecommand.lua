package.path = package.path .. ";data/scripts/lib/?.lua"

-- Cosmic War bridge overlay for Cosmic Overhaul trade prediction.
-- This wrapper keeps CO's original prediction flow intact and only applies
-- bounded post-processing multipliers from Cosmic War bridge libraries.
include("cosmicwareconomybridge")

local __CW_trade_calculatePrediction_original = TradeCommand.calculatePrediction

function TradeCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local prediction = __CW_trade_calculatePrediction_original(self, ownerIndex, shipName, area, config)
    if not prediction then return prediction end

    local faction = area and area.analysis and area.analysis.biggestFactionInArea
    if not faction then
        return prediction
    end

    local profitMult = 1.0
    local riskMult = 1.0
    if CosmicWarEconomyBridge then
        if CosmicWarEconomyBridge.getTradeProfitMultiplier then
            profitMult = CosmicWarEconomyBridge.getTradeProfitMultiplier(faction.index)
        end
        if CosmicWarEconomyBridge.getTradeRiskMultiplier then
            riskMult = CosmicWarEconomyBridge.getTradeRiskMultiplier(faction.index)
        end
    end

    if prediction.profitPerFlight then
        if prediction.profitPerFlight.from then
            prediction.profitPerFlight.from = prediction.profitPerFlight.from * profitMult
        end
        if prediction.profitPerFlight.to then
            prediction.profitPerFlight.to = prediction.profitPerFlight.to * profitMult
        end
    end

    if prediction.attackChance and prediction.attackChance.value then
        prediction.attackChance.value = prediction.attackChance.value * riskMult
        if prediction.attackChance.value > 1 then
            prediction.attackChance.value = 1
        end
    end

    prediction.mcm = prediction.mcm or {}
    prediction.mcm.cosmicWar = {
        profitMultiplier = profitMult,
        riskMultiplier = riskMult
    }

    return prediction
end
