package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

local giverIndex = 0
local targetIndex = 0
local kills = 0
local maxKills = 15
local timeLimit = 45 * 60 -- 45 minutes
local timeRemaining = timeLimit
local lastNotificationTime = timeLimit

function sendBountyMessage(msgType, text, ...)
    local f = Faction()
    if not f then return end
    
    if f.isPlayer then
        Player(f.index):sendChatMessage("Bounty Network"%_T, msgType, text, ...)
    elseif f.isAlliance then
        local alliance = Alliance(f.index)
        if alliance then
            for _, playerIndex in pairs({alliance:getOnlineMembers()}) do
                Player(playerIndex):sendChatMessage("Bounty Network"%_T, msgType, text, ...)
            end
        end
    end
end

function initialize(giver, target, firstReward)
    giverIndex = giver or 0
    targetIndex = target or 0

    if onServer() then
        sendBountyMessage(0, "War Bounty License Activated! You have 45 minutes to destroy up to 15 military targets of the enemy faction."%_T)

        -- addScriptOnce is deferred, so the caller can't invokeFunction("registerKill")
        -- back into us within the same tick it attaches this script. The first kill's
        -- reward is passed straight through here instead.
        if firstReward and firstReward > 0 then
            registerKill(firstReward)
        end
    end
end

function getUpdateInterval()
    return 60 -- Update every minute
end

function update(timeStep)
    if not onServer() then return end
    
    timeRemaining = timeRemaining - timeStep
    
    if timeRemaining <= 0 then
        sendBountyMessage(3, "War Bounty License has expired."%_T)
        terminate()
        return
    end
    
    -- Notify roughly every 5 minutes
    if lastNotificationTime - timeRemaining >= 300 then
        lastNotificationTime = lastNotificationTime - 300
        local mins = math.ceil(timeRemaining / 60)
        sendBountyMessage(0, "Bounty License: %1% minutes remaining."%_T, mins)
    end
end

function getTargetFaction()
    return targetIndex
end

-- Returns plain scalars only (matching every other invokeFunction() call site in this
-- mod) rather than a table, since invokeFunction's documented argument marshaling only
-- guarantees numbers/strings/nil and there is no confirmed table-safe path.
function getStatus()
    return giverIndex, targetIndex, kills, maxKills, math.max(0, math.ceil(timeRemaining))
end

function registerKill(reward)
    if not onServer() then return end
    
    kills = kills + 1
    local f = Faction()
    if f then
        f:receive("Confirmed War Bounty"%_T, reward)
        sendBountyMessage(0, "Bounty target destroyed! [%1%/%2%] (+%3% Cr)"%_T, kills, maxKills, reward)
        
        if kills >= maxKills then
            sendBountyMessage(0, "Bounty License Complete! Contract fulfilled."%_T)
            terminate()
        end
    end
end

function secure()
    return {
        giverIndex = giverIndex,
        targetIndex = targetIndex,
        kills = kills,
        maxKills = maxKills,
        timeRemaining = timeRemaining,
        lastNotificationTime = lastNotificationTime
    }
end

function restore(data)
    giverIndex = data.giverIndex or 0
    targetIndex = data.targetIndex or 0
    kills = data.kills or 0
    maxKills = data.maxKills or 15
    timeRemaining = data.timeRemaining or (45 * 60)
    lastNotificationTime = data.lastNotificationTime or timeRemaining
end
