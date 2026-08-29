package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local cw_militaryoutpost_initUI = MilitaryOutpost.initUI

function MilitaryOutpost.initUI()
    if cw_militaryoutpost_initUI then cw_militaryoutpost_initUI() end
    ScriptUI():registerInteraction("Enlist as Mercenary"%_t, "onEnlistInteraction")
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

    local CosmicWarBridge = include("cosmicwarbridge")
    local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
    if heat < 0.25 then
        ScriptUI():showDialog(MilitaryOutpost.makeNotAtWarDialog())
        return
    end

    ScriptUI():showDialog(MilitaryOutpost.makeEnlistDialog())
end

function MilitaryOutpost.makeEnlistDialog()
    local dialog = {}
    dialog.text = "We are currently embroiled in a severe conflict. We are authorizing privateer licenses to independent captains. If you enlist, you will receive double bounty payouts for all enemy vessels you destroy in our name. However, our enemies will immediately classify you as a high-threat hostile."%_t
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
    
    player:sendChatMessage(entity.name, 0, "Welcome aboard. Your privateer license is active. Hunt down our enemies.")
end
callable(MilitaryOutpost, "enlistPlayer")
