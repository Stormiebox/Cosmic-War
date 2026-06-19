package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("stringutility")

-- namespace CW_StrandedFlagshipEvent
CW_StrandedFlagshipEvent = {}

function CW_StrandedFlagshipEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_StrandedFlagshipEvent.finalize() terminate() end

function CW_StrandedFlagshipEvent.spawn()
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
        if heat >= 0.80 then table.insert(possibleFactions, idx) end
    end

    if #possibleFactions == 0 then
        terminate()
        return
    end
    CW_StrandedFlagshipEvent.flagshipFactionId = possibleFactions[random():getInt(1, #possibleFactions)]
    local flagshipFaction = Faction(CW_StrandedFlagshipEvent.flagshipFactionId)

    local generator = SectorGenerator(x, y)
    local ship = ShipGenerator.createMilitaryShip(flagshipFaction, generator:getPositionInSector(), 25.0) -- Volume factor x25

    ship:setTitle("Stranded Flagship"%_T, {})
    ship.name = flagshipFaction.name .. " Dreadnought"
    ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    ship:addScript("data/scripts/entity/ai/dreadnoughtboss.lua")

    -- Cripple the ship
    ship.durability = ship.durability * 0.15
    if ship.shieldMaxDurability and ship.shieldMaxDurability > 0 then
        ship.shieldDurability = 0
    end

    CW_StrandedFlagshipEvent.flagshipId = ship.id

    sector:broadcastChatMessage("Ship Computer"%_T, ChatMessageType.Warning,
        "Warning: Massive structural damage detected on an adrift Dreadnought. Its engines appear offline."%_T)
    deferredCallback(45.0, "spawnRepairFleet")

    local article = {
        title = "High-Value Flagship Stranded",
        content = "A massive flagship belonging to " .. flagshipFaction.name .. " has suffered critical engine failure and is stranded in sector [" .. x .. ":" .. y .. "]. Rival factions and opportunistic mercenaries are already moving in to capitalize on the vulnerability.",
        category = "Conflict"
    }
    Server():sendCallback("onCCNewsPublishArticle", article)
end

function CW_StrandedFlagshipEvent.spawnRepairFleet()
    local sector = Sector()
    local ship = sector:getEntity(CW_StrandedFlagshipEvent.flagshipId)
    if not ship then return end -- Player already secured the kill

    local faction = Faction(CW_StrandedFlagshipEvent.flagshipFactionId)
    sector:broadcastChatMessage(faction.name, ChatMessageType.Warning,
        "This is the repair fleet! We have arrived at the Flagship's location. Hostiles detected! Engage immediately!"%_T)

    local generator = SectorGenerator(sector:getCoordinates())
    for i = 1, 4 do
        local defender = ShipGenerator.createMilitaryShip(faction, generator:getPositionInSector())
        ShipAI(defender.index):setAggressive()
        defender:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end
end


function initialize(...)
    if CW_StrandedFlagshipEvent.initialize then return CW_StrandedFlagshipEvent.initialize(...) end
end
