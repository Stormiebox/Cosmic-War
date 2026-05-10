package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarcaptainbridge")

local __CW_salvage_calculatePrediction_original = SalvageCommand.calculatePrediction

function SalvageCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local prediction = __CW_salvage_calculatePrediction_original(self, ownerIndex, shipName, area, config)
    if not prediction then return prediction end

    local faction = area and area.analysis and area.analysis.biggestFactionInArea
    if not faction then
        return prediction
    end

    if CosmicWarCaptainBridge and CosmicWarCaptainBridge.modifyPredictionByWarHeat then
        prediction = CosmicWarCaptainBridge.modifyPredictionByWarHeat(prediction, faction.index)
    end

    return prediction
end
