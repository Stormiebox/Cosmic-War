package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarcaptainbridge")

local __CW_mine_calculatePrediction_original = MineCommand.calculatePrediction

function MineCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local prediction = __CW_mine_calculatePrediction_original(self, ownerIndex, shipName, area, config)
    if not prediction then return prediction end

    local factionRef = area and area.analysis and area.analysis.biggestFactionInArea
    local factionIndex = nil

    if type(factionRef) == "number" then
        factionIndex = factionRef
    elseif factionRef and type(factionRef) == "userdata" and factionRef.index then
        factionIndex = factionRef.index
    elseif factionRef and type(factionRef) == "table" and factionRef.index then
        factionIndex = factionRef.index
    end

    if not factionIndex then
        return prediction
    end

    if CosmicWarCaptainBridge and CosmicWarCaptainBridge.modifyPredictionByWarHeat then
        prediction = CosmicWarCaptainBridge.modifyPredictionByWarHeat(prediction, factionIndex)
    end

    return prediction
end
