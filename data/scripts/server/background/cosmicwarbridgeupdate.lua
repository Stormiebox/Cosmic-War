package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("cosmicwarconfig")

-- namespace CosmicWarBridgeUpdate
CosmicWarBridgeUpdate = {}

function CosmicWarBridgeUpdate.getUpdateInterval()
    local cfg = (CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get()) or {}
    return cfg.diplomacyInterval or 300
end

function CosmicWarBridgeUpdate.update(timeStep)
    if not onServer() then return end
    if CosmicWarBridge and CosmicWarBridge.publishWarHeatSnapshot then
        CosmicWarBridge.publishWarHeatSnapshot()
    end
end
