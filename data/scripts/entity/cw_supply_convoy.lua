package.path = package.path .. ";data/scripts/lib/?.lua"

-- namespace CW_SupplyConvoy
-- v4.0.0 Supply Lines: the attackable half of a distant siege. Destroying this
-- ship is a real win condition siegeevent.lua checks every tick (sector:getValue
-- "cw_supplyline_cut_<zoneStartTime>"), independent of how many troop transports are still
-- standing.
CW_SupplyConvoy = {}

local zoneStartTime = nil

function CW_SupplyConvoy.initialize(startTimeStr)
    zoneStartTime = startTimeStr
end

-- addScriptOnce's init argument isn't re-supplied after a sector unload/reload
-- cycle -- same reasoning as trooptransport.lua's own targetStationId, which persists
-- itself the identical way.
function CW_SupplyConvoy.secure()
    return { zoneStartTime = zoneStartTime }
end

function CW_SupplyConvoy.restore(data)
    zoneStartTime = data.zoneStartTime
end

function CW_SupplyConvoy.onDelete()
    if not onServer() then return end
    local sector = Sector()
    if not sector then return end

    -- Scoped to the specific siege instance (see siegeevent.lua's own comment on
    -- the matching scaling marker) so this flag can never bleed into an unrelated, later
    -- siege of the same sector.
    sector:setValue("cw_supplyline_cut_" .. tostring(zoneStartTime), true)
    sector:broadcastChatMessage("Server", ChatMessageType.Warning, "The invasion's supply convoy has been destroyed! Without reinforcements, the siege is collapsing."%_T)
end
