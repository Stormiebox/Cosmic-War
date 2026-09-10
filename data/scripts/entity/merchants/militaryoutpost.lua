package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local cw_militaryoutpost_initUI = MilitaryOutpost.initUI

-- v4.0.0 Letters of Marque: a flat repair cost, scaled off the amount of hull
-- actually missing rather than the ship's full size, so a lightly-damaged ship pays a
-- lightly-damaged price -- "discounted" relative to the fact that this is the only paid
-- repair service anywhere in this mod's own scripting, no baseline to discount against.
local MARQUE_REPAIR_COST_PER_DURABILITY = 2.5

function MilitaryOutpost.initUI()
    if cw_militaryoutpost_initUI then cw_militaryoutpost_initUI() end
    ScriptUI():registerInteraction("Enlist as Mercenary"%_t, "onEnlistInteraction")
    ScriptUI():registerInteraction("Request Emergency Repairs (Letter of Marque)"%_t, "onMarqueRepairInteraction")
end

function MilitaryOutpost.onEnlistInteraction()
    local entity = Entity()
    local player = Player()
    
    if player:hasScript("cosmicwar_mercenary.lua") then
        local enlistedFaction = player:getValue("cw_mercenary_faction")
        if enlistedFaction == entity.factionIndex then
            ScriptUI():showDialog(MilitaryOutpost.makeAlreadyEnlistedDialog())
        else
            ScriptUI():showDialog(MilitaryOutpost.makeCannotEnlistDialog())
        end
        return
    end

    -- Heat must be evaluated server-side; Server() is not available in UI context.
    invokeServerFunction("requestEnlistDialog")
end

function MilitaryOutpost.requestEnlistDialog()
    if onClient() then invokeServerFunction("requestEnlistDialog") return end
    local entity = Entity()
    local CosmicWarBridge = include("cosmicwarbridge")
    local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
    invokeClientFunction(Player(callingPlayer), "showEnlistDialog", heat >= 0.25)
end

function MilitaryOutpost.showEnlistDialog(atWar)
    if atWar then
        ScriptUI():showDialog(MilitaryOutpost.makeEnlistDialog())
    else
        ScriptUI():showDialog(MilitaryOutpost.makeNotAtWarDialog())
    end
end

function MilitaryOutpost.makeEnlistDialog()
    local dialog = {}
    dialog.text = "We are currently embroiled in a severe conflict. We are authorizing a Letter of Marque to independent captains -- a standing commission, not a one-off job. Sign it and our enemies will immediately classify you as a high-threat hostile, and our stations will patch up your hull at a privateer's discount. Turn on us, and the commission is revoked on the spot."%_t
    dialog.answers = {
        {answer = "I'm in. Sign me up."%_t, onSelect = "enlistPlayer"},
        {answer = "Too risky for my blood. Nevermind."%_t}
    }
    return dialog
end

function MilitaryOutpost.makeNotAtWarDialog()
    local dialog = {}
    dialog.text = "We are not currently involved in any major conflicts that require independent mercenary support. Check back if the geopolitical situation deteriorates."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function MilitaryOutpost.makeAlreadyEnlistedDialog()
    local dialog = {}
    dialog.text = "You are already an enlisted privateer for our forces. Keep up the good work out there, captain."%_t
    dialog.answers = {{answer = "Will do."%_t}}
    return dialog
end

function MilitaryOutpost.makeCannotEnlistDialog()
    local dialog = {}
    dialog.text = "Our records show you are already flying a mercenary banner for another faction. We cannot hire you."%_t
    dialog.answers = {{answer = "My mistake."%_t}}
    return dialog
end

function MilitaryOutpost.enlistPlayer()
    if onClient() then invokeServerFunction("enlistPlayer") return end

    local player = Player(callingPlayer)
    local entity = Entity()

    if player:hasScript("cosmicwar_mercenary.lua") then return end

    player:addScriptOnce("data/scripts/player/cosmicwar_mercenary.lua")
    player:setValue("cw_mercenary_faction", entity.factionIndex)

    -- v4.0.0 Letters of Marque: belligerent status is immediate, not something
    -- that only eventually follows from kills -- the same -200000 "declare war"
    -- magnitude every War Contract already uses on acceptance.
    local enlistingFaction = entity.factionIndex and Faction(entity.factionIndex)
    local enemyIndex = enlistingFaction and enlistingFaction:getValue("enemy_faction") or 0
    if enemyIndex and enemyIndex > 0 then
        local cvf = include("cosmicvaultfaction")
        cvf.changeRelations(player.index, enemyIndex, -200000)
    end

    player:sendChatMessage(entity.name, 0, "Welcome aboard. Your Letter of Marque is active. Hunt down our enemies -- and don't turn that commission on us."%_T)
end
callable(MilitaryOutpost, "enlistPlayer")
callable(MilitaryOutpost, "requestEnlistDialog")
callable(MilitaryOutpost, "showEnlistDialog")

-- v4.0.0 Letters of Marque: the "discounted repair" perk. A flat privateer's
-- rate, only available to a player currently commissioned by THIS station's faction --
-- there is no baseline paid-repair service anywhere else in this mod's own scripts to
-- discount against, so this is the perk in absolute terms rather than a percentage off an
-- existing price.
function MilitaryOutpost.onMarqueRepairInteraction()
    invokeServerFunction("requestMarqueRepair")
end

function MilitaryOutpost.requestMarqueRepair()
    if onClient() then invokeServerFunction("requestMarqueRepair") return end

    local player = Player(callingPlayer)
    local entity = Entity()
    if not player or not entity then return end

    local enlistedFaction = player:getValue("cw_mercenary_faction")
    local eligible = player:hasScript("cosmicwar_mercenary.lua") and enlistedFaction == entity.factionIndex
    invokeClientFunction(player, "showMarqueRepairDialog", eligible)
end

function MilitaryOutpost.showMarqueRepairDialog(eligible)
    if eligible then
        ScriptUI():showDialog(MilitaryOutpost.makeMarqueRepairDialog())
    else
        ScriptUI():showDialog(MilitaryOutpost.makeNoMarqueDialog())
    end
end

function MilitaryOutpost.makeMarqueRepairDialog()
    local dialog = {}
    dialog.text = "Hand her over, captain. We'll patch up every hull breach at the commissioned rate -- cheaper than any drydock, and we won't ask questions."%_t
    dialog.answers = {
        {answer = "Repair my ship"%_t, onSelect = "buyMarqueRepair"},
        {answer = "Not right now."%_t}
    }
    return dialog
end

function MilitaryOutpost.makeNoMarqueDialog()
    local dialog = {}
    dialog.text = "This service is reserved for captains actively holding one of our Letters of Marque."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function MilitaryOutpost.buyMarqueRepair()
    if onClient() then invokeServerFunction("buyMarqueRepair") return end

    local player = Player(callingPlayer)
    local entity = Entity()
    if not player or not entity then return end

    local enlistedFaction = player:getValue("cw_mercenary_faction")
    if not (player:hasScript("cosmicwar_mercenary.lua") and enlistedFaction == entity.factionIndex) then return end

    local craft = player.craft
    if not craft or not valid(craft) then return end

    local missing = (craft.maxDurability or 0) - (craft.durability or 0)
    if missing <= 0 then
        player:sendChatMessage(entity.name, 0, "Your hull is already in perfect condition, captain."%_T)
        return
    end

    local cost = math.floor(missing * MARQUE_REPAIR_COST_PER_DURABILITY)
    local canPay, msg, args = player:canPay(cost)
    if not canPay then
        player:sendChatMessage(entity.name, 1, msg, unpack(args or {}))
        return
    end

    player:pay("Letter of Marque Repairs"%_T, cost)
    craft.durability = craft.maxDurability

    player:sendChatMessage(entity.name, 0, "All patched up. Fly true, captain."%_T)
end
callable(MilitaryOutpost, "requestMarqueRepair")
callable(MilitaryOutpost, "showMarqueRepairDialog")
callable(MilitaryOutpost, "buyMarqueRepair")
