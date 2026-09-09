package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("relations")

-- namespace CW_BorderCheckpointEvent
-- v4.0.0 Final Pass: the first non-combat resolution path in this mod's dynamic
-- events -- every existing one only ever resolves through a fight. A customs
-- picket demands a toll; paying it or simply leaving it alone both work, fighting
-- it works too, and none of the three is the "wrong" answer.
CW_BorderCheckpointEvent = {}

function CW_BorderCheckpointEvent.getUpdateInterval()
    return 20 * 60 -- auto-expire after 20 minutes if left alone
end

function CW_BorderCheckpointEvent.initialize()
    if onClient() then return end

    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction or not faction:getValue("cw_enabled") then
        terminate()
        return
    end

    CW_BorderCheckpointEvent.factionIndex = faction.index
    CW_BorderCheckpointEvent.elapsed = 0

    local generator = SectorGenerator(x, y)
    local picket = ShipGenerator.createDefender(faction, generator:getPositionInSector())
    picket.title = "Customs Picket"%_T
    picket:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    -- The interaction (pay the toll) lives on the picket's own attached script --
    -- ScriptUI():registerInteraction() only works from a script attached to the
    -- entity itself, in that script's own initialize().
    picket:addScriptOnce("data/scripts/entity/cw_checkpoint_picket.lua", { faction.index })
    CW_BorderCheckpointEvent.picketId = picket.id

    picket:registerCallback("onDestroyed", "onPicketDestroyed")

    sector:broadcastChatMessage(faction.name, ChatMessageType.Warning,
        "This is a customs checkpoint. Pay the toll, or turn back -- your choice."%_T)
end

function CW_BorderCheckpointEvent.onPicketDestroyed(destroyedId, destroyerId)
    local sector = Sector()
    local faction = Faction(CW_BorderCheckpointEvent.factionIndex)
    if faction then
        local destroyer = sector:getEntity(destroyerId)
        if destroyer and destroyer.factionIndex and destroyer.factionIndex > 0 then
            CosmicWarBridge.recordWarScoreKill(CW_BorderCheckpointEvent.factionIndex)
        end
        for _, player in pairs({sector:getPlayers()}) do
            changeRelations(player, faction, -8000, RelationChangeType.General)
        end
    end
    terminate()
end

function CW_BorderCheckpointEvent.updateServer(timeStep)
    CW_BorderCheckpointEvent.elapsed = CW_BorderCheckpointEvent.elapsed + timeStep
    if CW_BorderCheckpointEvent.elapsed >= 20 * 60 then
        terminate()
    end
end

-- v4.0.0: paying the toll is handled entirely by the picket's own attached
-- script (cw_checkpoint_picket.lua), which deletes itself via
-- deleteEntityJumped() on success -- that call represents the ship "jumping
-- away," not being destroyed, so it does NOT fire onDestroyed above, and
-- correctly never applies the relations penalty a fight would. This event
-- script itself has nothing further to do at that point; it simply times out
-- via updateServer() above rather than needing its own explicit signal.

function CW_BorderCheckpointEvent.secure()
    return { factionIndex = CW_BorderCheckpointEvent.factionIndex, picketId = CW_BorderCheckpointEvent.picketId and CW_BorderCheckpointEvent.picketId.string, elapsed = CW_BorderCheckpointEvent.elapsed }
end

function CW_BorderCheckpointEvent.restore(data)
    CW_BorderCheckpointEvent.factionIndex = data.factionIndex
    CW_BorderCheckpointEvent.picketId = data.picketId and Uuid(data.picketId)
    CW_BorderCheckpointEvent.elapsed = data.elapsed or 0
end
