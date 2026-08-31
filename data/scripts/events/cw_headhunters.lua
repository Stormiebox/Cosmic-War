package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

local ShipGenerator = include("shipgenerator")

-- namespace CW_HeadhuntersEvent
CW_HeadhuntersEvent = {}

function CW_HeadhuntersEvent.initialize()
    if onClient() then return end

    local sector = Sector()
    local x, y = sector:getCoordinates()

    -- Only trigger if a player is present. Sector scripts have no implicit "self"
    -- player, so pull the present players explicitly rather than calling Player().
    local players = {sector:getPlayers()}
    if #players == 0 then
        Sector():removeScript("events/cw_headhunters.lua")
        terminate()
        return
    end
    local player = players[random():getInt(1, #players)]

    local server = Server()
    local factionStr = server:getValue("factions")
    if type(factionStr) ~= "string" or factionStr == "" then
        Sector():removeScript("events/cw_headhunters.lua")
        terminate()
        return
    end

    local bestEnemy = nil
    local lowestRel = 100000

    for id in string.gmatch(factionStr, "([^,]+)") do
        local index = tonumber(id)
        local f = Faction(index)
        if f and f.isAIFaction then
            local enemyIndex = f:getValue("enemy_faction") or 0
            if enemyIndex > 0 then
                local rel = player:getRelations(f.index) or 0
                if rel <= -80000 and rel < lowestRel then
                    lowestRel = rel
                    bestEnemy = f
                end
            end
        end
    end

    if not bestEnemy then
        Sector():removeScript("events/cw_headhunters.lua")
        terminate()
        return
    end

    -- Defer ambush until the player jumps to a new sector
    player:setValue("cw_pending_ambush", bestEnemy.index)

    -- Terminate this script, the scheduler will handle the ambush on sector entry
    Sector():removeScript("events/cw_headhunters.lua")
    terminate()
end
