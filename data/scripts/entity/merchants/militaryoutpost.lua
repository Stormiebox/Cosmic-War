package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local cw_militaryoutpost_initUI = initUI
local cw_militaryoutpost_onInteract = onInteract

function initUI()
    if cw_militaryoutpost_initUI then cw_militaryoutpost_initUI() end
    ScriptUI():registerInteraction("Enlist as Mercenary"%_t, "onEnlistInteraction")
end

function onEnlistInteraction()
    local entity = Entity()
    local player = Player()
    
    if player:hasScript("cosmicwar_mercenary.lua") then
        local enlistedFaction = player:getValue("cw_mercenary_faction")
        if enlistedFaction == entity.factionIndex then
            ScriptUI():showDialog(makeAlreadyEnlistedDialog())
        else
            ScriptUI():showDialog(makeCannotEnlistDialog())
        end
        return
    end

    local cw_success = pcall(include, "cosmicwarbridge")
    if cw_success and CosmicWarBridge then
        local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
        if heat < 0.25 then
            ScriptUI():showDialog(makeNotAtWarDialog())
            return
        end
    end

    ScriptUI():showDialog(makeEnlistDialog())
end

function makeEnlistDialog()
    local dialog = {}
    dialog.text = "We are currently embroiled in a severe conflict. We are authorizing privateer licenses to independent captains. If you enlist, you will receive double bounty payouts for all enemy vessels you destroy in our name. However, our enemies will immediately classify you as a high-threat hostile."%_t
    dialog.answers = {
        {answer = "I'm in. Sign me up."%_t, onSelect = "enlistPlayer"},
        {answer = "Too risky for my blood. Nevermind."%_t}
    }
    return dialog
end

function makeNotAtWarDialog()
    local dialog = {}
    dialog.text = "We are not currently involved in any major conflicts that require independent mercenary support. Check back if the geopolitical situation deteriorates."%_t
    dialog.answers = {{answer = "Understood."%_t}}
    return dialog
end

function makeAlreadyEnlistedDialog()
    local dialog = {}
    dialog.text = "You are already an enlisted privateer for our forces. Keep up the good work out there, captain."%_t
    dialog.answers = {{answer = "Will do."%_t}}
    return dialog
end

function makeCannotEnlistDialog()
    local dialog = {}
    dialog.text = "Our records show you are already flying a mercenary banner for another faction. We cannot hire you."%_t
    dialog.answers = {{answer = "My mistake."%_t}}
    return dialog
end

function enlistPlayer()
    if onClient() then invokeServerFunction("enlistPlayer") return end
    
    local player = Player(callingPlayer)
    local entity = Entity()
    
    if player:hasScript("cosmicwar_mercenary.lua") then return end
    
    player:addScript("data/scripts/player/cosmicwar_mercenary.lua")
    player:setValue("cw_mercenary_faction", entity.factionIndex)
    
    player:sendChatMessage(entity.name, 0, "Welcome aboard. Your privateer license is active. Hunt down our enemies.")
end
callable(nil, "enlistPlayer")
