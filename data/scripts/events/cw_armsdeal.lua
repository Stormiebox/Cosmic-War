package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local SectorTurretGenerator = include("sectorturretgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("galaxy")
include("stringutility")

-- namespace CW_ArmsDealEvent
CW_ArmsDealEvent = {}

function CW_ArmsDealEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_ArmsDealEvent.finalize() terminate() end

function CW_ArmsDealEvent.spawn()
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
        if heat >= 0.20 then table.insert(possibleFactions, idx) end
    end

    if #possibleFactions == 0 then
        terminate()
        return
    end
    local militaryFaction = Faction(possibleFactions[random():getInt(1, #possibleFactions)])
    local smugglerFaction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))

    local generator = SectorGenerator(x, y)

    local buyer = ShipGenerator.createMilitaryShip(militaryFaction, generator:getPositionInSector())
    buyer.title = "Covert Operative"%_T
    buyer:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    local seller = ShipGenerator.createFreighterShip(smugglerFaction, generator:getPositionInSector())
    seller.title = "Black Market Dealer"%_T
    seller:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    -- Guarantee high-rarity loot on the smuggler
    local turretGenerator = SectorTurretGenerator()
    turretGenerator.rarities = { [RarityType.Exceptional] = 1 }
    Loot(seller):insert(InventoryTurret(turretGenerator:generate(x, y)))
    if random():test(0.5) then Loot(seller):insert(InventoryTurret(turretGenerator:generate(x, y))) end

    sector:broadcastChatMessage(buyer.name, ChatMessageType.Warning,
        "We have company! The arms deal is compromised! Eradicate all witnesses!"%_T)

    ShipAI(buyer.index):setAggressive()
    ShipAI(seller.index):setAggressive()

    for i = 1, 2 do
        local e1 = ShipGenerator.createMilitaryShip(militaryFaction, generator:getPositionInSector())
        ShipAI(e1.index):setAggressive(); e1:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

        local e2 = ShipGenerator.createDefender(smugglerFaction, generator:getPositionInSector())
        ShipAI(e2.index):setAggressive(); e2:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    local article = {
        title = "Black Market Arms Deal Intercepted",
        content = "Military forces belonging to the " .. militaryFaction.name .. " have reportedly intercepted an illegal weapons transfer orchestrated by the " .. smugglerFaction.name .. " in sector [" .. x .. ":" .. y .. "]. Heavy fighting is ongoing.",
        category = "Conflict"
    }
    Server():sendCallback("onCCNewsPublishArticle", article)
end


function initialize(...)
    if CW_ArmsDealEvent.initialize then return CW_ArmsDealEvent.initialize(...) end
end

return CW_ArmsDealEvent