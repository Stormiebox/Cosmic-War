package.path = package.path .. ";data/scripts/lib/?.lua"
include("relations")

-- namespace CW_CheckpointPicket
-- v4.0.0: the interaction-owning half of Border Checkpoint
-- (cw_border_checkpoint.lua). ScriptUI():registerInteraction() must be called from
-- a script attached to the entity itself, in that script's own initUI() -- the
-- sector event that spawns this ship has no entity-level UI context of its own to
-- register an interaction from. initUI() is its own engine-invoked lifecycle callback,
-- distinct from initialize() -- ScriptUI() is not yet bound during initialize() and
-- crashes with "attempt to call global 'ScriptUI' (a nil value)" if called there;
-- every vanilla entity script that registers an interaction (civilship.lua,
-- crewtransport.lua, bulletinboard.lua, etc.) does so from initUI(), never initialize().
CW_CheckpointPicket = {}

local TOLL_COST = 75000

function CW_CheckpointPicket.initialize(factionIndex)
    if onServer() then
        CW_CheckpointPicket.factionIndex = factionIndex
    end
end

function CW_CheckpointPicket.initUI()
    ScriptUI():registerInteraction("Pay the Toll (75,000 Cr)"%_t, "payToll")
end

function CW_CheckpointPicket.payToll()
    if onClient() then invokeServerFunction("payToll") return end

    local player = Player(callingPlayer)
    if not player then return end

    local canPay, msg, args = player:canPay(TOLL_COST)
    if not canPay then
        player:sendChatMessage("Customs Picket"%_T, 1, msg, unpack(args or {}))
        return
    end

    player:pay("Border Toll"%_T, TOLL_COST)

    local faction = Faction(CW_CheckpointPicket.factionIndex)
    if faction then
        changeRelations(player, faction, 4000, RelationChangeType.General)
        player:sendChatMessage(faction.name, 0, "Toll received. Safe travels."%_T)
    end

    -- Dismisses cleanly -- paying resolves the encounter without a fight, and
    -- without crediting a War Score kill that didn't happen. deleteEntityJumped()
    -- removes the whole entity (scripts included), so there's no need to also
    -- remove this currently-executing script by hand first.
    Sector():deleteEntityJumped(Entity())
end
callable(CW_CheckpointPicket, "payToll")
