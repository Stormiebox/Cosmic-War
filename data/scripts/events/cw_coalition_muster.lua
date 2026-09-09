package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
include("randomext")

-- namespace CW_CoalitionMusterEvent
-- v4.0.0 Final Pass: Coalition Ceasefires (cosmicwarceasefires.lua) change a
-- number and publish a news article -- nothing a player standing in the galaxy
-- actually SEES. This fires only when the sector's controlling faction is
-- currently one half of an active `cw_coalition_dampened_<pairKey>` pair (the
-- exact flag the ceasefire system itself maintains), and spawns a joint patrol
-- of both normally-hostile factions' ships flying together, unarmed toward
-- each other -- the clearest possible signal that something bigger than their
-- own war is happening.
CW_CoalitionMusterEvent = {}

function CW_CoalitionMusterEvent.initialize()
    if onClient() then return end

    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction or not faction:getValue("cw_enabled") then
        terminate()
        return
    end

    local enemyIndex = faction:getValue("enemy_faction") or 0
    local enemyFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not enemyFaction or not enemyFaction.isAIFaction then terminate() return end

    local left, right = math.min(faction.index, enemyIndex), math.max(faction.index, enemyIndex)
    local key = tostring(left) .. "_" .. tostring(right)
    local server = Server()
    local dampenedUntil = server and (server:getValue("cw_coalition_dampened_" .. key) or 0) or 0
    if dampenedUntil <= (server and server.unpausedRuntime or 0) then
        -- No active Coalition Ceasefire between these two right now.
        terminate()
        return
    end

    -- registerFriendFaction() explicitly overrides normal faction relations for
    -- this AI (confirmed in the stub: "This setting overrides normal faction
    -- relations") -- without it, these two factions' ships would still read each
    -- other as hostile via their real, unchanged relations and fight on sight
    -- despite the ceasefire, undercutting the entire point of this event.
    local generator = SectorGenerator(x, y)
    local sideA, sideB = {}, {}
    for i = 1, random():getInt(2, 3) do
        local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
        ship.title = "Coalition Patrol"%_T
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        table.insert(sideA, ship)
    end
    for i = 1, random():getInt(2, 3) do
        local ship = ShipGenerator.createDefender(enemyFaction, generator:getPositionInSector())
        ship.title = "Coalition Patrol"%_T
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        table.insert(sideB, ship)
    end
    for _, ship in pairs(sideA) do
        ShipAI(ship.index):registerFriendFaction(enemyFaction.index)
    end
    for _, ship in pairs(sideB) do
        ShipAI(ship.index):registerFriendFaction(faction.index)
    end

    sector:broadcastChatMessage("Unknown"%_T, ChatMessageType.Information,
        "%1% and %2% ships are patrolling this sector together -- side by side, not a shot fired between them. The Eclipse must be close."%_T, faction.name, enemyFaction.name)

    terminate()
end
