package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("relations")
include("stringutility")

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
        terminate()
        return
    end
    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if faction then
        terminate()
        return
    end

    local snapshot = CosmicWarBridge and CosmicWarBridge.getWarHeatSnapshot and CosmicWarBridge.getWarHeatSnapshot() or
    {}
    local possibleFactions = {}
    for idx, heat in pairs(snapshot) do
        if heat >= 0.20 and heat <= 0.80 then table.insert(possibleFactions, idx) end
    end

    if #possibleFactions == 0 then
        terminate()
        return
    end
    CW_DiplomaticSabotageEvent.envoyFactionId = possibleFactions[random():getInt(1, #possibleFactions)]
    local envoyFaction = Faction(CW_DiplomaticSabotageEvent.envoyFactionId)
    local pirateFaction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))

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
    if cv_news and cv_news.publishArticle then
        cv_news.publishArticle(article)
    else
        Server():sendCallback("onCCNewsPublishArticle", article)
    end
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
    terminate()
end


function initialize(...)
    if CW_DiplomaticSabotageEvent.initialize then return CW_DiplomaticSabotageEvent.initialize(...) end
end

return CW_DiplomaticSabotageEvent

