package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("relations")
include("stringutility")
include("galaxy")

-- namespace CW_DiplomaticSabotageEvent
CW_DiplomaticSabotageEvent = {}

function CW_DiplomaticSabotageEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_DiplomaticSabotageEvent.finalize() terminate() end

function CW_DiplomaticSabotageEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then
        Sector():removeScript("events/cw_diplomaticsabotage.lua")
        terminate()
        return
    end
    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if faction then
        Sector():removeScript("events/cw_diplomaticsabotage.lua")
        terminate()
        return
    end

    local snapshot = CosmicWarBridge.getWarHeatSnapshot() or {}
    local possibleFactions = {}
    for idx, heat in pairs(snapshot) do
        if heat >= 0.20 and heat <= 0.80 then table.insert(possibleFactions, idx) end
    end

    if #possibleFactions == 0 then
        Sector():removeScript("events/cw_diplomaticsabotage.lua")
        terminate()
        return
    end
    CW_DiplomaticSabotageEvent.envoyFactionId = possibleFactions[random():getInt(1, #possibleFactions)]
    local envoyFaction = Faction(CW_DiplomaticSabotageEvent.envoyFactionId)
    local pirateFaction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))

    if not envoyFaction or not pirateFaction then
        Sector():removeScript("events/cw_diplomaticsabotage.lua")
        terminate()
        return
    end

    local generator = SectorGenerator(x, y)
    local envoy = ShipGenerator.createFreighterShip(envoyFaction, generator:getPositionInSector())
    envoy.title = "Diplomatic Envoy"%_T
    envoy:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    CW_DiplomaticSabotageEvent.envoyId = envoy.id

    sector:broadcastChatMessage(envoyFaction.name, ChatMessageType.Warning,
        "Mayday! This is a diplomatic peace envoy! Extremists are trying to sabotage the ceasefire talks! We need immediate assistance!"%_T)

    local numAttackers = random():getInt(3, 5)
    for i = 1, numAttackers do
        local attacker = ShipGenerator.createMilitaryShip(pirateFaction, generator:getPositionInSector())
        attacker.title = "Hardliner Extremist"%_T
        attacker.name = "Saboteur"
        ShipAI(attacker.index):setAggressive()
        attacker:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    deferredCallback(60.0, "checkSurvival")

    local article = {
        title = "Diplomatic Convoy Under Attack",
        content = "An assassination attempt is currently underway! A diplomatic convoy belonging to " .. envoyFaction.name .. " is under heavy assault by " .. pirateFaction.name .. " forces in sector [" .. x .. ":" .. y .. "].",
        category = "Conflict"
    }
    local cv_news = include("cosmicvaultnews")
    cv_news.publishArticle(article)
end

function CW_DiplomaticSabotageEvent.checkSurvival()
    local envoy = Sector():getEntity(CW_DiplomaticSabotageEvent.envoyId)
    if envoy then
        Sector():broadcastChatMessage(Faction(CW_DiplomaticSabotageEvent.envoyFactionId).name, ChatMessageType.Information,
            "Thank you! With those extremists gone, we can proceed to the peace summit. We owe you our lives."%_T)

        local faction = Faction(CW_DiplomaticSabotageEvent.envoyFactionId)
        if faction then
            for _, player in pairs({Sector():getPlayers()}) do
                changeRelations(player, faction, 15000, RelationChangeType.General)
            end
        end
        Sector():deleteEntityJumped(envoy)
    end
    Sector():removeScript("events/cw_diplomaticsabotage.lua")
    terminate()
end

function CW_DiplomaticSabotageEvent.secure()
    return {
        envoyId = CW_DiplomaticSabotageEvent.envoyId and CW_DiplomaticSabotageEvent.envoyId.string or nil,
        envoyFactionId = CW_DiplomaticSabotageEvent.envoyFactionId
    }
end

function CW_DiplomaticSabotageEvent.restore(data)
    CW_DiplomaticSabotageEvent.envoyId = data.envoyId and Uuid(data.envoyId) or nil
    CW_DiplomaticSabotageEvent.envoyFactionId = data.envoyFactionId
end


