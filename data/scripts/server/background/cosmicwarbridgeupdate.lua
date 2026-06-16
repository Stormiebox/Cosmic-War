package.path = package.path .. ";data/scripts/lib/?.lua"

include("cosmicwarbridge")
include("cosmicwarconfig")
include("randomext")

-- namespace CosmicWarBridgeUpdate
CosmicWarBridgeUpdate = {}

function CosmicWarBridgeUpdate.getUpdateInterval()
    local cfg = (CosmicWarConfig and CosmicWarConfig.get and CosmicWarConfig.get()) or {}
    return cfg.diplomacyInterval or 300
end

local function retrofitMissingFactions()
    local server = Server()
    if not server or type(server.getValue) ~= "function" then return end

    local factionStr = server:getValue("factions")
    if type(factionStr) ~= "string" or factionStr == "" then return end

    for id in string.gmatch(factionStr, "([^,]+)") do
        local index = tonumber(id)
        local faction = Faction(index)

        -- Retrofit factions generated before Cosmic War was installed, or starter factions generated before the hook
        if faction and faction.isAIFaction and faction:getValue("cw_enabled") == nil then
            local seed = server.seed + faction.index * 101 + 17
            local random = Random(seed)

            local targetAggressive = random:getFloat(0.55, 1.0)
            local mistrustful = random:getFloat(-0.25, 0.85)
            local forgiving = random:getFloat(-0.25, 0.85)

            if random:test(0.65) then
                mistrustful = math.min(1.0, math.max(-1.0, mistrustful + random:getFloat(0.10, 0.35)))
                forgiving = math.min(1.0, math.max(-1.0, forgiving - random:getFloat(0.05, 0.25)))
            else
                mistrustful = math.min(1.0, math.max(-1.0, mistrustful - random:getFloat(0.05, 0.20)))
                forgiving = math.min(1.0, math.max(-1.0, forgiving + random:getFloat(0.10, 0.30)))
            end

            faction:setValue("cw_enabled", true)
            faction:setValue("cw_war_bias", math.floor(targetAggressive * 1000))
            faction:setValue("cw_diplomatic_polarity", math.floor((mistrustful - forgiving) * 1000))
            if faction:getValue("enemy_faction") == nil then
                faction:setValue("enemy_faction", 0)
            end
        end
    end
end

function CosmicWarBridgeUpdate.update(timeStep)
    if not onServer() then return end

    -- Self-heal any factions that are missing Cosmic War metadata
    retrofitMissingFactions()

    if CosmicWarBridge and CosmicWarBridge.publishWarHeatSnapshot then
        CosmicWarBridge.publishWarHeatSnapshot()
    end
end


function getUpdateInterval(...)
    if CosmicWarBridgeUpdate.getUpdateInterval then return CosmicWarBridgeUpdate.getUpdateInterval(...) end
end
function update(...)
    if CosmicWarBridgeUpdate.update then return CosmicWarBridgeUpdate.update(...) end
end
