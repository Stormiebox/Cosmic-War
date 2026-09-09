package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
include("randomext")
include("relations")

-- namespace CW_MutinyEvent
-- v4.0.0: only fires against a faction with a serious Famine score --
-- one of its own warships turns on the fleet it was sailing with. Avorion's AI
-- doesn't support one ship attacking a same-faction ally directly, so the
-- mutineer's factionIndex is reassigned to the local pirate faction the instant
-- it spawns (the same direct-assignment mechanism trooptransport.lua already
-- uses for station capture) -- mechanically a defection, which is exactly what
-- a mutiny actually is. If it survives its own former fleet, it flies escort
-- for the player briefly before jumping out.
CW_MutinyEvent = {}

CW_MutinyEvent.mutineerId = nil
CW_MutinyEvent.loyalistIds = {}
CW_MutinyEvent.parentFactionIndex = 0
CW_MutinyEvent.escortTimer = 0
CW_MutinyEvent.escorting = false

function CW_MutinyEvent.getUpdateInterval()
    return 5.0
end

function CW_MutinyEvent.initialize()
    if onServer() then
        if not _restoring then
            CW_MutinyEvent.spawn()
        end
    end
end

function CW_MutinyEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction or not faction:getValue("cw_enabled") then
        terminate()
        return
    end

    local server = Server()
    local famineScore = server and (server:getValue("cv_famine_" .. tostring(faction.index)) or 0) or 0
    if famineScore < 100 then terminate() return end

    local pirateLevel = Balancing_GetPirateLevel(x, y)
    local pirateFaction = Galaxy():getPirateFaction(pirateLevel)
    if not pirateFaction then terminate() return end

    CW_MutinyEvent.parentFactionIndex = faction.index

    local generator = SectorGenerator(x, y)

    for i = 1, random():getInt(2, 3) do
        local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
        ship.title = "Loyalist Escort"%_T
        ShipAI(ship.index):setAggressive()
        table.insert(CW_MutinyEvent.loyalistIds, ship.id)
    end

    local mutineer = ShipGenerator.createMilitaryShip(faction, generator:getPositionInSector())
    mutineer.title = "Mutineer"%_T
    mutineer.factionIndex = pirateFaction.index
    ShipAI(mutineer.index):setAggressive()
    CW_MutinyEvent.mutineerId = mutineer.id

    sector:broadcastChatMessage(faction.name, ChatMessageType.Warning,
        "Mutiny! One of our own has turned on the fleet -- put them down before this spreads."%_T)
end

function CW_MutinyEvent.updateServer(timeStep)
    if not onServer() then return end

    local sector = Sector()

    if CW_MutinyEvent.escorting then
        CW_MutinyEvent.escortTimer = CW_MutinyEvent.escortTimer - CW_MutinyEvent.getUpdateInterval()
        local mutineer = CW_MutinyEvent.mutineerId and sector:getEntity(CW_MutinyEvent.mutineerId)
        if CW_MutinyEvent.escortTimer <= 0 or not mutineer or not valid(mutineer) then
            if mutineer and valid(mutineer) then
                sector:broadcastChatMessage("Mutineer"%_T, ChatMessageType.Information,
                    "I owe you my life. Fly safe -- I'm not sticking around."%_T)
                sector:deleteEntityJumped(mutineer)
            end
            terminate()
        end
        return
    end

    local mutineer = CW_MutinyEvent.mutineerId and sector:getEntity(CW_MutinyEvent.mutineerId)
    if not mutineer or not valid(mutineer) then
        -- The mutineer didn't make it -- nothing further to resolve.
        terminate()
        return
    end

    local anyLoyalistAlive = false
    for _, id in pairs(CW_MutinyEvent.loyalistIds) do
        local loyalist = sector:getEntity(id)
        if loyalist and valid(loyalist) then
            anyLoyalistAlive = true
            break
        end
    end

    if not anyLoyalistAlive then
        -- The mutineer survived its own former fleet -- reward the player and
        -- start the brief "escort you out" window before it jumps away.
        CW_MutinyEvent.escorting = true
        CW_MutinyEvent.escortTimer = 60

        local pirateFaction = Faction(mutineer.factionIndex)
        for _, player in pairs({sector:getPlayers()}) do
            if pirateFaction then
                changeRelations(player, pirateFaction, 8000, RelationChangeType.General)
            end
        end
        sector:broadcastChatMessage("Mutineer"%_T, ChatMessageType.Information,
            "They're gone. Thank you for the cover fire -- I'll stay close until we're both clear."%_T)
    end
end

function CW_MutinyEvent.secure()
    local savedLoyalists = {}
    for _, id in pairs(CW_MutinyEvent.loyalistIds) do
        table.insert(savedLoyalists, id.string)
    end
    return {
        mutineerId = CW_MutinyEvent.mutineerId and CW_MutinyEvent.mutineerId.string,
        loyalistIds = savedLoyalists,
        parentFactionIndex = CW_MutinyEvent.parentFactionIndex,
        escortTimer = CW_MutinyEvent.escortTimer,
        escorting = CW_MutinyEvent.escorting,
    }
end

function CW_MutinyEvent.restore(data)
    CW_MutinyEvent.mutineerId = data.mutineerId and Uuid(data.mutineerId)
    CW_MutinyEvent.loyalistIds = {}
    if data.loyalistIds then
        for _, idStr in pairs(data.loyalistIds) do
            table.insert(CW_MutinyEvent.loyalistIds, Uuid(idStr))
        end
    end
    CW_MutinyEvent.parentFactionIndex = data.parentFactionIndex or 0
    CW_MutinyEvent.escortTimer = data.escortTimer or 0
    CW_MutinyEvent.escorting = data.escorting or false
end
