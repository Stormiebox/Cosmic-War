local cw_getPossibleMissions = MissionBulletins.getPossibleMissions

function MissionBulletins.getPossibleMissions()
    local scripts = {}
    if cw_getPossibleMissions then
        scripts = cw_getPossibleMissions()
    end

    local entity = Entity()
    if not entity or not entity.factionIndex then return scripts end

    include("cosmicwarbridge")
    if CosmicWarBridge then
        local heat = CosmicWarBridge.getFactionWarHeat(entity.factionIndex) or 0

        -- The probabilities are roughly matched to vanilla standard missions
        if heat >= 0.15 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_forcerecon.lua", prob = 2.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_sensor_deployment.lua", prob = 1.5})
        end
        if heat >= 0.25 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_borderskirmish.lua", prob = 2.0})
        end
        if heat >= 0.35 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_resource_heist.lua", prob = 1.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_resourcesabotage.lua", prob = 1.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_deploy_mines.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_scorched_earth.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_salvagerace.lua", prob = 1.0})
        end
        if heat >= 0.45 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_sector_raid.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_interception.lua", prob = 1.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_breakthrough.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_propaganda_broadcast.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_black_box_retrieval.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_deniableraid.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_counterintelligence_sweep.lua", prob = 1.0})
        end
        if heat >= 0.60 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_hunter_killer.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_frontlinesiege.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_distraction_carnage.lua", prob = 1.0})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_shieldbreaker.lua", prob = 0.75})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_decisivepush.lua", prob = 0.75})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_prizecrew.lua", prob = 0.75})
            -- v4.0.0: both these two carry their own additional real gate inside
            -- their own getBulletin() (War Score band, Intel balance) -- the heat
            -- tier here is just the probability-weight placement, same pattern
            -- already established by cw_decisivepush.lua two lines above.
            table.insert(scripts, {path = "data/scripts/player/missions/cw_armistice_escort.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_defector_debrief.lua", prob = 0.5})
        end
        if heat >= 0.80 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_highvaluedefection.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_assassinate_general.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_supply_line_raid.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_blockade_runner.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_subspace_containment.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_corridor_interdiction.lua", prob = 0.5})
        end
        if heat >= 1.00 then
            table.insert(scripts, {path = "data/scripts/player/missions/cw_decapitationstrike.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_extract_pow.lua", prob = 0.5})
            table.insert(scripts, {path = "data/scripts/player/missions/cw_champion_duel.lua", prob = 0.5})
        end
    end

    -- v4.0.0 Humanitarian Contracts: gated on Famine, not War Heat -- a starving faction
    -- wants relief regardless of whether it's currently at war with anyone, so this
    -- check doesn't depend on CosmicWarBridge being available above.
    local server = Server()
    local famineScore = server and (server:getValue("cv_famine_" .. tostring(entity.factionIndex)) or 0) or 0
    if famineScore >= 50 then
        table.insert(scripts, {path = "data/scripts/player/missions/cw_relief_convoy.lua", prob = 1.5})
    end
    -- v4.0.0: Medical Airlift is Severe-Famine-only (>=100), so it never
    -- competes with Relief Convoy's own >=50 slot for the same struggling-but-not-yet-
    -- critical faction.
    if famineScore >= 100 then
        table.insert(scripts, {path = "data/scripts/player/missions/cw_medical_airlift.lua", prob = 1.0})
    end
    if famineScore >= 50 then
        table.insert(scripts, {path = "data/scripts/player/missions/cw_refugeeresettlement.lua", prob = 1.0})
    end
    -- v4.0.0: the combat-side mirror of Relief Convoy/Medical Airlift -- same
    -- Famine >=100 severity gate as Medical Airlift, since it's also a
    -- meaningful single-shot reduction, just earned by fighting instead of flying
    -- cargo.
    if famineScore >= 100 then
        table.insert(scripts, {path = "data/scripts/player/missions/cw_famine_blockade_break.lua", prob = 1.0})
    end

    return scripts
end
