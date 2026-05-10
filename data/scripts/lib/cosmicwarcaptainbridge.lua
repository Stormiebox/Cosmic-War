package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("cosmicwarconfig")

-- namespace CosmicWarCaptainBridge
CosmicWarCaptainBridge = CosmicWarCaptainBridge or {}

function CosmicWarCaptainBridge.modifyPredictionByWarHeat(prediction, factionIndex)
    if not prediction then return prediction end

    local cfg = CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get() or {}
    if cfg.enableCaptainBridge == false then
        return prediction
    end

    local riskMult = 1.0
    local rewardMult = 1.0
    if CosmicWarBridge and CosmicWarBridge.computeCaptainRiskModifier then
        riskMult, rewardMult = CosmicWarBridge.computeCaptainRiskModifier(nil, factionIndex)
    end

    if prediction.attackChance and prediction.attackChance.value then
        prediction.attackChance.value = prediction.attackChance.value * riskMult
        if prediction.attackChance.value > 1 then prediction.attackChance.value = 1 end
    end

    if prediction.reward and prediction.reward.value then
        prediction.reward.value = prediction.reward.value * rewardMult
    end

    prediction.mcm = prediction.mcm or {}
    prediction.mcm.cosmicWarCaptain = {
        riskMultiplier = riskMult,
        rewardMultiplier = rewardMult
    }

    return prediction
end
