-- Cosmic War: Custom Faction Traits Registration
-- This library registers the 9 specialized diplomatic traits for Cosmic War.
local cvf = include("cosmicvaultfaction")

local CosmicWarTraits = {}

function CosmicWarTraits.initialize()
    if not cvf or not cvf.registerCustomTrait then return end

    cvf.registerCustomTrait("cw_warmonger", "Warmonger", {
        "Highly aggressive and eager to declare war.",
        "Passively decays relations with neutral factions."
    })
    
    cvf.registerCustomTrait("cw_pacifist", "Pacifist", {
        "Despises conflict and strictly avoids unprovoked wars.",
        "Passively improves relations with neighbors."
    })
    
    cvf.registerCustomTrait("cw_isolationist", "Isolationist", {
        "Wants to be left alone.",
        "Refuses to form alliances or expand borders.",
        "Diplomatic shifts are heavily dampened."
    })
    
    cvf.registerCustomTrait("cw_opportunist", "Opportunist", {
        "Profit and power above all else.",
        "Highly likely to betray weak allies or surrender to strong enemies."
    })
    
    cvf.registerCustomTrait("cw_imperialist", "Imperialist", {
        "Driven by a relentless desire to expand.",
        "Rapidly claims empty sectors and builds outposts.",
        "Causes border friction with neighbors."
    })
    
    cvf.registerCustomTrait("cw_entrenched", "Entrenched", {
        "Prioritizes absolute defense of their core territory.",
        "Rarely attacks, but builds massive defensive networks.",
        "Extremely difficult to conquer."
    })
    
    cvf.registerCustomTrait("cw_vengeful", "Vengeful", {
        "Does not easily forgive transgressions.",
        "Ceasefire negotiations are almost impossible once a war begins."
    })
    
    cvf.registerCustomTrait("cw_mercantile", "Mercantile", {
        "Prioritizes profit over military supremacy.",
        "Pays triple (3x) standard rates for mercenary contracts."
    })
    
    cvf.registerCustomTrait("cw_xenophobic", "Xenophobic", {
        "Views all outsiders with extreme prejudice.",
        "Actively hostile to ships entering their space.",
        "Relations continuously decay. Cannot form alliances."
    })
end

-- Helper to safely set vanilla trait pairs symmetrically
local function setVanillaTraitPair(faction, trait, contrary, value)
    faction:setTrait(trait, value)
    faction:setTrait(contrary, -value)
end

-- Evaluates vanilla traits and assigns Cosmic War custom traits.
-- Only meant to be called on Server by factions.lua
function CosmicWarTraits.applyTraits(faction)
    if not faction then return end
    local random = Random(Server().seed + faction.index * 101)
    
    -- Strip out old string stances if they exist
    faction:setValue("cw_diplomatic_stance", nil)
    
    local aggressive = faction:getTrait("aggressive") or 0
    local peaceful = faction:getTrait("peaceful") or 0
    local careful = faction:getTrait("careful") or 0
    local brave = faction:getTrait("brave") or 0
    local opportunistic = faction:getTrait("opportunistic") or 0
    local honorable = faction:getTrait("honorable") or 0
    local trusting = faction:getTrait("trusting") or 0
    local mistrustful = faction:getTrait("mistrustful") or 0
    local greedy = faction:getTrait("greedy") or 0

    local assignedTrait = nil

    -- Primary extreme evaluation
    if aggressive > 0.6 and opportunistic > 0.4 then
        assignedTrait = "cw_warmonger"
    elseif peaceful > 0.6 and trusting > 0.4 then
        assignedTrait = "cw_pacifist"
    elseif careful > 0.6 and mistrustful > 0.6 then
        assignedTrait = "cw_isolationist"
    elseif opportunistic > 0.7 and greedy > 0.5 then
        assignedTrait = "cw_opportunist"
    elseif aggressive > 0.4 and greedy > 0.6 then
        assignedTrait = "cw_imperialist"
    elseif careful > 0.7 and peaceful > 0.2 then
        assignedTrait = "cw_entrenched"
    elseif mistrustful > 0.7 and aggressive > 0.4 then
        assignedTrait = "cw_vengeful"
    elseif greedy > 0.7 and peaceful > 0.2 then
        assignedTrait = "cw_mercantile"
    elseif mistrustful > 0.8 and careful > 0.2 then
        assignedTrait = "cw_xenophobic"
    end

    -- 30% chance to forcefully inject a specialized trait if generic
    if not assignedTrait and random:test(0.30) then
        local roll = random:getInt(1, 9)
        local traitsList = {
            "cw_warmonger", "cw_pacifist", "cw_isolationist", "cw_opportunist", 
            "cw_imperialist", "cw_entrenched", "cw_vengeful", "cw_mercantile", "cw_xenophobic"
        }
        assignedTrait = traitsList[roll]
        
        -- Override vanilla traits to loosely match the injected trait
        if assignedTrait == "cw_warmonger" then
            setVanillaTraitPair(faction, "aggressive", "peaceful", random:getFloat(0.6, 1.0))
            setVanillaTraitPair(faction, "sadistic", "sympathetic", 0.8)
            setVanillaTraitPair(faction, "active", "passive", 0.8)
            setVanillaTraitPair(faction, "dumb", "smart", 0.5)
        elseif assignedTrait == "cw_pacifist" then
            setVanillaTraitPair(faction, "peaceful", "aggressive", random:getFloat(0.6, 1.0))
            setVanillaTraitPair(faction, "sympathetic", "sadistic", 1.0)
            setVanillaTraitPair(faction, "forgiving", "strict", 1.0)
        elseif assignedTrait == "cw_mercantile" then
            setVanillaTraitPair(faction, "greedy", "generous", random:getFloat(0.7, 1.0))
            setVanillaTraitPair(faction, "peaceful", "aggressive", random:getFloat(0.3, 0.8))
            setVanillaTraitPair(faction, "smart", "dumb", 1.0)
            setVanillaTraitPair(faction, "active", "passive", 0.5)
            setVanillaTraitPair(faction, "forgiving", "strict", 0.5)
        elseif assignedTrait == "cw_xenophobic" then
            setVanillaTraitPair(faction, "mistrustful", "trusting", random:getFloat(0.8, 1.0))
            setVanillaTraitPair(faction, "strict", "forgiving", 1.0)
            setVanillaTraitPair(faction, "sadistic", "sympathetic", 1.0)
        elseif assignedTrait == "cw_vengeful" then
            setVanillaTraitPair(faction, "strict", "forgiving", 1.0)
            setVanillaTraitPair(faction, "sadistic", "sympathetic", 1.0)
        elseif assignedTrait == "cw_entrenched" then
            setVanillaTraitPair(faction, "passive", "active", 1.0)
            setVanillaTraitPair(faction, "smart", "dumb", 1.0)
        elseif assignedTrait == "cw_imperialist" then
            setVanillaTraitPair(faction, "active", "passive", 1.0)
            setVanillaTraitPair(faction, "strict", "forgiving", 0.8)
        elseif assignedTrait == "cw_opportunist" then
            setVanillaTraitPair(faction, "smart", "dumb", 0.8)
            setVanillaTraitPair(faction, "active", "passive", 0.5)
        elseif assignedTrait == "cw_isolationist" then
            setVanillaTraitPair(faction, "passive", "active", 1.0)
            setVanillaTraitPair(faction, "strict", "forgiving", 1.0)
        end
    end

    if not assignedTrait then
        assignedTrait = "cw_balanced"
    end

    -- Save it natively
    if cvf and cvf.setTrait then
        if assignedTrait ~= "cw_balanced" then
            cvf.setTrait(faction.index, assignedTrait, 1.0)
        end
    else
        -- Fallback if Cosmic Vault is missing
        faction:setValue("cosmic_trait_" .. assignedTrait, 1.0)
    end
end

-- Initialize the registry globally immediately upon inclusion
CosmicWarTraits.initialize()

return CosmicWarTraits
