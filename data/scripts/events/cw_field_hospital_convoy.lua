package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
local CosmicVaultEconomy = include("cosmicvaulteconomy")
include("randomext")
include("relations")

-- namespace CW_FieldHospitalConvoyEvent
-- v4.0.0 Final Pass: same shape as cw_refugeeconvoy.lua, framed as a marked
-- medical convoy instead of civilian refugees. Defending it (surviving the
-- hunters) reduces the owner faction's Famine directly; destroying the convoy
-- itself -- whether by the hunters or the player -- is treated as a war crime,
-- a relations penalty and a Famine INCREASE, published under Cosmic Vault's
-- "War Crime" news category.
CW_FieldHospitalConvoyEvent = {}
CW_FieldHospitalConvoyEvent.transports = {}

function CW_FieldHospitalConvoyEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_FieldHospitalConvoyEvent.finalize()
    terminate()
end

function CW_FieldHospitalConvoyEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end
    local x, y = sector:getCoordinates()
    if Galaxy():getControllingFaction(x, y) then terminate() return end

    local snapshot = CosmicWarBridge.getWarHeatSnapshot() or {}
    local possibleFactions = {}
    for idx, heat in pairs(snapshot) do
        if heat >= 0.35 then table.insert(possibleFactions, idx) end
    end
    if #possibleFactions == 0 then terminate() return end

    CW_FieldHospitalConvoyEvent.victimId = possibleFactions[random():getInt(1, #possibleFactions)]
    local victimFaction = Faction(CW_FieldHospitalConvoyEvent.victimId)
    if not victimFaction then terminate() return end
    CW_FieldHospitalConvoyEvent.attackerId = victimFaction:getValue("enemy_faction")
    if not CW_FieldHospitalConvoyEvent.attackerId or CW_FieldHospitalConvoyEvent.attackerId <= 0 then
        terminate()
        return
    end

    local generator = SectorGenerator(x, y)
    local ship = ShipGenerator.createFreighterShip(victimFaction, generator:getPositionInSector())
    ship.title = "Field Hospital Convoy"%_T
    ship:setValue("cw_field_hospital_target", true)
    ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    if ship:hasComponent(ComponentType.Shield) then
        ship:addBaseMultiplier(StatsBonuses.ShieldDurability, 9.0)
        ship.shieldDurability = ship.shieldMaxDurability
    end
    if ship:hasComponent(ComponentType.Durability) then
        Durability(ship.index).maxDurabilityFactor = Durability(ship.index).maxDurabilityFactor * 10
        ship.durability = ship.maxDurability
    end

    ship:registerCallback("onDestroyed", "onConvoyDestroyed")
    table.insert(CW_FieldHospitalConvoyEvent.transports, ship.id)

    sector:broadcastChatMessage(victimFaction.name, ChatMessageType.Warning,
        "This is a marked field hospital convoy under the protection of the wounded! We are under attack -- someone, please help!"%_T)

    deferredCallback(12.0, "spawnHunters")
    deferredCallback(90.0, "escapeTransports")
end

function CW_FieldHospitalConvoyEvent.spawnHunters()
    local attackerFaction = Faction(CW_FieldHospitalConvoyEvent.attackerId)
    if not attackerFaction then return end
    local generator = SectorGenerator(Sector():getCoordinates())
    for i = 1, random():getInt(3, 5) do
        local ship = ShipGenerator.createMilitaryShip(attackerFaction, generator:getPositionInSector())
        ShipAI(ship.index):setAggressive()
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end
    Sector():broadcastChatMessage(attackerFaction.name, ChatMessageType.Warning,
        "A field hospital marking means nothing to us. Take it down."%_T)
end

-- v4.0.0: whoever lands the killing blow, destroying a marked medical convoy is
-- a war crime -- this doesn't distinguish "the hunters got there first" from "a
-- player did it," since the convoy dying at all is the violation, not who's
-- credited with the kill.
function CW_FieldHospitalConvoyEvent.onConvoyDestroyed(destroyedId, destroyerId)
    if CW_FieldHospitalConvoyEvent.resolved then return end
    CW_FieldHospitalConvoyEvent.resolved = true

    local victimFaction = Faction(CW_FieldHospitalConvoyEvent.victimId)
    if victimFaction then
        CosmicVaultEconomy.addFamineScore(CW_FieldHospitalConvoyEvent.victimId, 20)

        local sector = Sector()
        local destroyer = sector:getEntity(destroyerId)
        if destroyer and destroyer.playerOrAllianceOwned then
            for _, player in pairs({sector:getPlayers()}) do
                changeRelations(player, victimFaction, -30000, RelationChangeType.General)
            end
        end

        local cv_news = include("cosmicvaultnews")
        cv_news.publishArticle({
            title = "Marked Field Hospital Convoy Destroyed",
            content = "A convoy flying " .. victimFaction.name .. "'s field hospital markings has been destroyed in open space. Whatever the circumstances, this is being condemned across the galaxy as a war crime.",
            category = "War Crime"
        })
    end

    terminate()
end

function CW_FieldHospitalConvoyEvent.escapeTransports()
    if CW_FieldHospitalConvoyEvent.resolved then return end
    local survived = 0
    for _, id in pairs(CW_FieldHospitalConvoyEvent.transports) do
        local ship = Sector():getEntity(id)
        if ship then survived = survived + 1; Sector():deleteEntityJumped(ship) end
    end
    if survived > 0 then
        local faction = Faction(CW_FieldHospitalConvoyEvent.victimId)
        if faction then
            Sector():broadcastChatMessage(faction.name, ChatMessageType.Information,
                "The convoy made it through. Every one of those wounded owes you their life."%_T)
            CosmicVaultEconomy.addFamineScore(CW_FieldHospitalConvoyEvent.victimId, -25)
            CosmicWarBridge.recordFamineReliefApplied(CW_FieldHospitalConvoyEvent.victimId, 25)

            for _, player in pairs({Sector():getPlayers()}) do
                changeRelations(player, faction, 6000, RelationChangeType.General)
            end
        end
    end
    terminate()
end

function CW_FieldHospitalConvoyEvent.secure()
    local savedTransports = {}
    for _, id in pairs(CW_FieldHospitalConvoyEvent.transports) do
        table.insert(savedTransports, id.string)
    end
    return {
        transports = savedTransports,
        victimId = CW_FieldHospitalConvoyEvent.victimId,
        attackerId = CW_FieldHospitalConvoyEvent.attackerId,
        resolved = CW_FieldHospitalConvoyEvent.resolved,
    }
end

function CW_FieldHospitalConvoyEvent.restore(data)
    CW_FieldHospitalConvoyEvent.transports = {}
    if data.transports then
        for _, idStr in pairs(data.transports) do
            table.insert(CW_FieldHospitalConvoyEvent.transports, Uuid(idStr))
        end
    end
    CW_FieldHospitalConvoyEvent.victimId = data.victimId
    CW_FieldHospitalConvoyEvent.attackerId = data.attackerId
    CW_FieldHospitalConvoyEvent.resolved = data.resolved
end
