-- Cosmic War: Custom Faction Traits Registration
-- This library registers the 9 specialized diplomatic traits for Cosmic War.
local cvf = include("cosmicvaultfaction")

local CosmicWarTraits = {}

function CosmicWarTraits.initialize()
    if not cvf then return end

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

    -- Cosmic Ascendancy/War: Ascendancy + War Traits (Inherent Imperialism)
    if faction.name == "The Eclipse" or faction:getValue("is_eclipse") then
        assignedTrait = "cw_imperialist"
        setVanillaTraitPair(faction, "active", "passive", 1.0)
        setVanillaTraitPair(faction, "strict", "forgiving", 1.0)
        setVanillaTraitPair(faction, "sadistic", "sympathetic", 1.0)
        setVanillaTraitPair(faction, "aggressive", "peaceful", 1.0)
    end

    -- Primary Fitness Evaluation
    if not assignedTrait then
        local candidates = {}
        
        -- Clamp to 0 so negative (contrary) traits don't penalize scores
        local agg = math.max(0, aggressive)
        local pac = math.max(0, peaceful)
        local car = math.max(0, careful)
        local opp = math.max(0, opportunistic)
        local gre = math.max(0, greedy)
        local tru = math.max(0, trusting)
        local mis = math.max(0, mistrustful)
        
        candidates["cw_warmonger"] = (agg * 1.5) + (opp * 1.0)
        candidates["cw_pacifist"] = (pac * 1.5) + (tru * 1.0)
        candidates["cw_isolationist"] = (car * 1.2) + (mis * 1.2)
        candidates["cw_opportunist"] = (opp * 1.5) + (gre * 1.0)
        candidates["cw_imperialist"] = (agg * 1.2) + (gre * 1.2)
        candidates["cw_entrenched"] = (car * 1.5) + (pac * 1.0)
        candidates["cw_vengeful"] = (mis * 1.5) + (agg * 1.0)
        candidates["cw_mercantile"] = (gre * 1.5) + (pac * 1.0)
        candidates["cw_xenophobic"] = (mis * 1.6) + (car * 0.8)

        local bestTrait = nil
        local bestScore = 1.0 -- Must score at least > 1.0 to natively qualify

        for trait, score in pairs(candidates) do
            if score > bestScore then
                bestScore = score
                bestTrait = trait
            end
        end

        assignedTrait = bestTrait
    end

    -- 40% chance to forcefully inject a specialized trait if generic
    if not assignedTrait and random:test(0.40) then
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

    if assignedTrait ~= "cw_balanced" then
        cvf.setTrait(faction.index, assignedTrait, 1.0)
    end
    if faction.name == "The Eclipse" or faction:getValue("is_eclipse") then
        cvf.setTrait(faction.index, "cw_vengeful", 1.0)
    end
end

-- Initialize the registry globally immediately upon inclusion
CosmicWarTraits.initialize()


return CosmicWarTraits
