local cw_getPossibleMissions = MissionBulletins.getPossibleMissions

function MissionBulletins.getPossibleMissions()
    local scripts = {}
    if cw_getPossibleMissions then
        scripts = cw_getPossibleMissions()
    end
    
    local entity = Entity()
    if not entity or not entity.factionIndex then return scripts end

    local cw_success = pcall(include, "cosmicwarbridge")
    if cw_success and CosmicWarBridge then
        local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0
        
        -- The probabilities are roughly matched to vanilla standard missions
        if heat >= 0.15 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_forcerecon.lua", prob = 2.0})
        end
        if heat >= 0.25 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_borderskirmish.lua", prob = 2.0})
        end
        if heat >= 0.35 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_resourcesabotage.lua", prob = 1.5})
        end
        if heat >= 0.45 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_interception.lua", prob = 1.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_breakthrough.lua", prob = 1.0})
        end
        if heat >= 0.60 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_frontlinesiege.lua", prob = 1.0})
        end
        if heat >= 0.80 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_highvaluedefection.lua", prob = 0.5})
        end
        if heat >= 1.00 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_decapitationstrike.lua", prob = 0.5})
        end
    end
    
    return scripts
end
