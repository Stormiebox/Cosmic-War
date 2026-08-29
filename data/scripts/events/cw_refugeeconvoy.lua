package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("relations")
include("stringutility")

-- namespace CW_RefugeeConvoyEvent
CW_RefugeeConvoyEvent = {}
CW_RefugeeConvoyEvent.transports = {}

function CW_RefugeeConvoyEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_RefugeeConvoyEvent.finalize()
    Sector():removeScript("events/cw_refugeeconvoy.lua")
    terminate()
end

function CW_RefugeeConvoyEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then
        Sector():removeScript("events/cw_refugeeconvoy.lua")
        terminate()
        return
    end
    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if faction then
        Sector():removeScript("events/cw_refugeeconvoy.lua")
        terminate()
        return
    end                                    -- Only spawn in empty/border sectors

    local snapshot = CosmicWarBridge.getWarHeatSnapshot() or {}
    local possibleFactions = {}
    for idx, heat in pairs(snapshot) do
        if heat >= 0.40 then table.insert(possibleFactions, idx) end
    end

    if #possibleFactions == 0 then
        Sector():removeScript("events/cw_refugeeconvoy.lua")
        terminate()
        return
    end
    CW_RefugeeConvoyEvent.victimId = possibleFactions[random():getInt(1, #possibleFactions)]
    local victimFaction = Faction(CW_RefugeeConvoyEvent.victimId)
    CW_RefugeeConvoyEvent.attackerId = victimFaction:getValue("enemy_faction")

    if not CW_RefugeeConvoyEvent.attackerId or CW_RefugeeConvoyEvent.attackerId <= 0 then
        Sector():removeScript("events/cw_refugeeconvoy.lua")
        terminate()
        return
    end

    local generator = SectorGenerator(x, y)
    local numTransports = random():getInt(2, 4)
    for i = 1, numTransports do
        local ship = ShipGenerator.createFreighterShip(victimFaction, generator:getPositionInSector())
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

        if ship:hasComponent(ComponentType.Shield) then
            ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 9.0)
            ship.shieldDurability = ship.shieldMaxDurability
        end
        if ship:hasComponent(ComponentType.Durability) then
            Durability(ship.index).maxDurabilityFactor = Durability(ship.index).maxDurabilityFactor * 10
            ship.durability = ship.maxDurability
        end

        table.insert(CW_RefugeeConvoyEvent.transports, ship.id)
    end

    sector:broadcastChatMessage(victimFaction.name, ChatMessageType.Warning,
        "Mayday, mayday! This is a civilian refugee convoy! We are being tracked by a hunter fleet! Anyone in the sector, please help us until our hyperdrives are charged!"%_T)

    deferredCallback(12.0, "spawnHunters")
    deferredCallback(90.0, "escapeTransports")

    local article = {
        title = "Refugee Convoy Hunted",
        content = "Tragic reports are coming in from sector [" .. x .. ":" .. y .. "]. A civilian refugee convoy belonging to " .. victimFaction.name .. " is being ruthlessly pursued and fired upon by hostile military forces.",
        category = "Conflict"
    }
    local cv_news = include("cosmicvaultnews")
    cv_news.publishArticle(article)
end

function CW_RefugeeConvoyEvent.spawnHunters()
    local attackerFaction = Faction(CW_RefugeeConvoyEvent.attackerId)
    if not attackerFaction then return end
    local generator = SectorGenerator(Sector():getCoordinates())
    local numHunters = random():getInt(3, 5)
    for i = 1, numHunters do
        local ship = ShipGenerator.createMilitaryShip(attackerFaction, generator:getPositionInSector())
        ShipAI(ship.index):setAggressive()
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end
    Sector():broadcastChatMessage(attackerFaction.name, ChatMessageType.Warning,
        "Target acquired. Leave no survivors."%_T)
end

function CW_RefugeeConvoyEvent.escapeTransports()
    local survived = 0
    for _, id in pairs(CW_RefugeeConvoyEvent.transports) do
        local ship = Sector():getEntity(id)
        if ship then
            survived = survived + 1; Sector():deleteEntityJumped(ship)
        end
    end
    if survived > 0 then
        Sector():broadcastChatMessage(Faction(CW_RefugeeConvoyEvent.victimId).name, ChatMessageType.Information,
            "Thank you! Our drives are charged and we are jumping to safety. We won't forget this!"%_T)

        local faction = Faction(CW_RefugeeConvoyEvent.victimId)
        if faction then
            for _, player in pairs({Sector():getPlayers()}) do
                changeRelations(player, faction, survived * 2500, RelationChangeType.General)
                
                -- Cosmic Vault Buff System: Grant "Hero of the People" buff
                player:addScriptOnce("cosmicvaultbuffs.lua")
                player:invokeFunction("cosmicvaultbuffs.lua", "addBuff", "Hero of the People", 3600, {tradePriceModifier = 0.10})
                player:sendChatMessage("System", ChatMessageType.Information, "You have received the 'Hero of the People' buff for 1 hour! (+10% Trade Prices at allied stations)"%_T)
            end
        end
    end
    Sector():removeScript("events/cw_refugeeconvoy.lua")
    terminate()
end

function CW_RefugeeConvoyEvent.secure()
    local savedTransports = {}
    for _, id in pairs(CW_RefugeeConvoyEvent.transports) do
        table.insert(savedTransports, id.string)
    end
    return {
        transports = savedTransports,
        victimId = CW_RefugeeConvoyEvent.victimId,
        attackerId = CW_RefugeeConvoyEvent.attackerId
    }
end

function CW_RefugeeConvoyEvent.restore(data)
    CW_RefugeeConvoyEvent.transports = {}
    if data.transports then
        for _, idStr in pairs(data.transports) do
            table.insert(CW_RefugeeConvoyEvent.transports, Uuid(idStr))
        end
    end
    CW_RefugeeConvoyEvent.victimId = data.victimId
    CW_RefugeeConvoyEvent.attackerId = data.attackerId
end


