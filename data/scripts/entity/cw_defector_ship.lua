package.path = package.path .. ";data/scripts/lib/?.lua"
include("relations")

-- namespace CW_DefectorShip
-- v4.0.0: the interaction-owning half of Defection Offer
-- (cw_defection_offer.lua). Same lesson as cw_checkpoint_picket.lua --
-- ScriptUI():registerInteraction() only works from a script attached to the
-- ship itself, in that script's own initialize().
CW_DefectorShip = {}

function CW_DefectorShip.initialize(factionIndex, cost)
    if onServer() then
        CW_DefectorShip.factionIndex = factionIndex
        CW_DefectorShip.cost = cost or 200000
        ScriptUI():registerInteraction("Accept Defection"%_t, "acceptDefection")
    end
end

function CW_DefectorShip.acceptDefection()
    if onClient() then invokeServerFunction("acceptDefection") return end

    local player = Player(callingPlayer)
    if not player then return end

    local canPay, msg, args = player:canPay(CW_DefectorShip.cost)
    if not canPay then
        player:sendChatMessage("Defector"%_T, 1, msg, unpack(args or {}))
        return
    end

    local entity = Entity()
    local oldFactionIndex = CW_DefectorShip.factionIndex
    local oldFaction = Faction(oldFactionIndex)

    player:pay("Defection Payment"%_t, CW_DefectorShip.cost)

    -- v4.0.0: this pays to make the ship stand down and leave, not to add it to
    -- the player's own fleet -- there's no confirmed, verified way in this
    -- workspace to reassign a live ship's factionIndex directly to a player's own
    -- personal faction (every proven capture precedent in this mod, Prize Crew
    -- included, retargets an AI FACTION index, never a raw player index), and
    -- this isn't the place to guess at unverified engine behavior. Framed as the
    -- defector jumping to safety rather than joining your fleet.
    Sector():deleteEntityJumped(entity)

    if oldFaction then
        local enemyIndex = oldFaction:getValue("enemy_faction") or 0
        if enemyIndex > 0 then
            local CosmicWarBridge = include("cosmicwarbridge")
            -- Reuses the territory-swing weight, not the kill weight -- a
            -- defection is a real strategic loss for the former faction, closer
            -- in significance to losing a station than to losing one ship.
            CosmicWarBridge.recordWarScoreTerritory(oldFactionIndex, enemyIndex)
        end
        changeRelations(player, oldFaction, -15000, RelationChangeType.General)
    end

    player:sendChatMessage("Defector"%_T, 0, "Deal's done. I'm out -- and my former commanders are going to have questions."%_T)
end
callable(CW_DefectorShip, "acceptDefection")
