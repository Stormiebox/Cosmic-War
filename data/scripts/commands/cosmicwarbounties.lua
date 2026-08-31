package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

-- NOTE:
-- Chat command scripts in Avorion are expected to expose global entry points:
--   execute(sender, commandName, ...), getDescription(), getHelp()
-- To reduce global collision risk while preserving compatibility, helpers are scoped locally.

local scriptPath = "data/scripts/player/background/cw_bounty_tracker.lua"

local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%dm%02ds", mins, secs)
end

-- Checks both the player's own faction and (if applicable) their alliance for an active
-- License, since cw_bountypayouts.lua attaches the tracker to whichever of the two actually
-- owns the killing blow (see CW_BountyPayouts.onDestroyed).
local function collectMyLicense(player)
    if not player then return nil end

    local holders = { player }
    if player.allianceIndex and player.allianceIndex > 0 then
        local alliance = Alliance(player.allianceIndex)
        if alliance then table.insert(holders, alliance) end
    end

    for _, holder in pairs(holders) do
        if holder:hasScript(scriptPath) then
            local invokeStatus, giverIdx, targetIdx, kills, maxKills, timeRemaining = holder:invokeFunction(scriptPath, "getStatus")
            if invokeStatus == 0 then
                local giver = Faction(giverIdx)
                local target = Faction(targetIdx)
                return {
                    giverName = giver and giver.name or ("Faction " .. tostring(giverIdx)),
                    targetName = target and target.name or ("Faction " .. tostring(targetIdx)),
                    kills = kills or 0,
                    maxKills = maxKills or 15,
                    timeRemaining = timeRemaining or 0,
                }
            end
        end
    end

    return nil
end

local function collectActiveBounties()
    local server = Server()
    if not server or type(server.getValue) ~= "function" then
        return nil, "Server API not ready"
    end

    if not server:getValue("factions_ready") then
        return nil, "Faction index initializing."
    end

    local now = server.unpausedRuntime or 0
    local factionStr = server:getValue("factions")
    local factionIndices = {}

    if type(factionStr) == "string" and factionStr ~= "" then
        for id in string.gmatch(factionStr, "([^,]+)") do
            table.insert(factionIndices, tonumber(id))
        end
    end

    local bounties = {}
    for _, idx in pairs(factionIndices) do
        local f = Faction(idx)
        if f and f.isAIFaction then
            local bountyEnemy = f:getValue("cw_bounty_enemy") or 0
            local bountyReward = f:getValue("cw_bounty_reward") or 0
            local bountyExpires = f:getValue("cw_bounty_expires") or 0

            if bountyEnemy > 0 and bountyReward > 0 and bountyExpires > now then
                local e = Faction(bountyEnemy)
                if e then
                    table.insert(bounties, {
                        giverName = f.name or ("Faction " .. tostring(f.index)),
                        targetName = e.name or ("Faction " .. tostring(e.index)),
                        reward = bountyReward,
                        expiresIn = bountyExpires - now,
                    })
                end
            end
        end
    end

    table.sort(bounties, function(a, b) return a.reward > b.reward end)
    return bounties, nil
end

function execute(sender, commandName, ...)
    local player = Player(sender)
    if not player then
        return 1, "", "Player not found"
    end

    local lines = {}

    local myLicense = collectMyLicense(player)
    if myLicense then
        table.insert(lines, string.format("[Your License] %s vs %s -- %d/%d kills, %s remaining",
            myLicense.giverName, myLicense.targetName, myLicense.kills, myLicense.maxKills, formatTime(myLicense.timeRemaining)))
    else
        table.insert(lines, "[Your License] None active. Destroy a bounty target's military assets to accept one.")
    end

    local bounties, err = collectActiveBounties()
    if err then
        table.insert(lines, "[Board] " .. err)
    elseif #bounties == 0 then
        table.insert(lines, "[Board] No active War Bounties right now.")
    else
        table.insert(lines, string.format("[Board] %d active War Bounties:", #bounties))
        local topN = math.min(10, #bounties)
        for i = 1, topN do
            local b = bounties[i]
            table.insert(lines, string.format("  %d. %s offers c%s/kill vs %s (expires in %s)",
                i, b.giverName, createMonetaryString(b.reward), b.targetName, formatTime(b.expiresIn)))
        end
    end

    return 0, table.concat(lines, "\n"), ""
end

function getDescription()
    return "Shows your active War Bounty License and all currently active War Bounties."
end

function getHelp()
    return "/cosmicwarbounties"
end
