package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("cosmicwarconfig")

-- namespace CosmicWarEconomyBridge
CosmicWarEconomyBridge = CosmicWarEconomyBridge or {}

function CosmicWarEconomyBridge.getTradeProfitMultiplier(factionIndex)
    local cfg = CosmicWarConfig.get() or {}
    if cfg.enableEconomyBridge == false then
        return 1.0
    end

    local heat = CosmicWarBridge.getFactionWarHeat(factionIndex) or 0

    -- modest positive pressure on profit where war heat is high
    local mult = 1.0 + (heat * 0.12)
    if mult < 1.0 then mult = 1.0 end
    if mult > 1.12 then mult = 1.12 end
    return mult
end

function CosmicWarEconomyBridge.getTradeRiskMultiplier(factionIndex)
    local cfg = CosmicWarConfig.get() or {}
    if cfg.enableEconomyBridge == false then
        return 1.0
    end

    local heat = CosmicWarBridge.getFactionWarHeat(factionIndex) or 0

    -- stronger risk growth than profit growth
    local mult = 1.0 + (heat * 0.25)
    if mult < 1.0 then mult = 1.0 end
    if mult > 1.25 then mult = 1.25 end
    return mult
end

return CosmicWarEconomyBridge
