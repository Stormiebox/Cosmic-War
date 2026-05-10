package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, ...)
    local player = Player(sender)
    if not player then
        return 1, "", "Player not found"
    end

    local galaxy = Galaxy()
    if not galaxy then
        return 1, "", "Galaxy unavailable"
    end

    if type(galaxy.getFactions) ~= "function" then
        return 1, "", "Galaxy API not ready"
    end

    local factions = {galaxy:getFactions()}
    local enabled = 0
    local rivalryMarkers = 0
    local bountyActive = 0
    local mirroredPairs = 0
    local uniquePairs = {}
    local mirroredKeys = {}

    local hot = {}

    for _, f in pairs(factions) do
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            enabled = enabled + 1

            local enemy = f:getValue("enemy_faction")
            if enemy and enemy > 0 then
                rivalryMarkers = rivalryMarkers + 1

                local enemyFaction = Faction(enemy)
                if enemyFaction then
                    local left = math.min(f.index, enemyFaction.index)
                    local right = math.max(f.index, enemyFaction.index)
                    local key = tostring(left) .. ":" .. tostring(right)
                    uniquePairs[key] = true

                    local reverseEnemy = enemyFaction:getValue("enemy_faction") or 0
                    if reverseEnemy == f.index and not mirroredKeys[key] then
                        mirroredKeys[key] = true
                        mirroredPairs = mirroredPairs + 1
                    end

                    local rel = f:getRelations(enemyFaction.index) or 0
                    table.insert(hot, {
                        a = f.name or ("Faction " .. tostring(f.index)),
                        b = enemyFaction.name or ("Faction " .. tostring(enemyFaction.index)),
                        rel = rel
                    })
                end
            end

            local bountyEnemy = f:getValue("cw_bounty_enemy") or 0
            local bountyReward = f:getValue("cw_bounty_reward") or 0
            local bountyExpires = f:getValue("cw_bounty_expires") or 0
            if bountyEnemy > 0 and bountyReward > 0 and bountyExpires > Server().unpausedRuntime then
                bountyActive = bountyActive + 1
            end
        end
    end

    table.sort(hot, function(lhs, rhs)
        return (lhs.rel or 0) < (rhs.rel or 0)
    end)

    local uniquePairCount = 0
    for _ in pairs(uniquePairs) do
        uniquePairCount = uniquePairCount + 1
    end

    local parts = {}
    table.insert(parts, string.format("[Cosmic War] Active AI factions: %d", enabled))
    table.insert(parts, string.format("Rivalry markers: %d", rivalryMarkers))
    table.insert(parts, string.format("Mirrored rivalries: %d/%d", mirroredPairs, uniquePairCount))
    table.insert(parts, string.format("Active bounties: %d", bountyActive))

    local topN = math.min(3, #hot)
    for i = 1, topN do
        local item = hot[i]
        table.insert(parts, string.format("Hot %d: %s vs %s (%d)", i, item.a, item.b, item.rel))
    end

    local msg = table.concat(parts, " | ")
    return 0, msg, ""
end

function getDescription()
    return "Shows current Cosmic War status."
end

function getHelp()
    return "/cosmicwarstatus"
end
