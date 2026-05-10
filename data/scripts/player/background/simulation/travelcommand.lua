package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarcaptainbridge")

local __CW_travel_calculatePrediction_original = TravelCommand.calculatePrediction

function TravelCommand:calculatePrediction(...)
    local prediction = __CW_travel_calculatePrediction_original(self, ...)
    if not prediction then return prediction end

    local args = { ... }
    local area = args[3]
    local faction = area and area.analysis and area.analysis.biggestFactionInArea
    if not faction then
        return prediction
    end

    if CosmicWarCaptainBridge and CosmicWarCaptainBridge.modifyPredictionByWarHeat then
        prediction = CosmicWarCaptainBridge.modifyPredictionByWarHeat(prediction, faction.index)
    end

    return prediction
end
