package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

local ShipGenerator = include("shipgenerator")

local cw_headhunters = {}

function cw_headhunters.initialize()
    if onClient() then return end

    local sector = Sector()
    local x, y = sector:getCoordinates()
    local player = Player()

    -- Only trigger if the player is present
    if not player then
        terminate()
        return
    end

    local server = Server()
    local factionStr = server:getValue("factions")
    if type(factionStr) ~= "string" or factionStr == "" then
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
        terminate()
        return
    end

    -- Defer ambush until the player jumps to a new sector
    player:setValue("cw_pending_ambush", bestEnemy.index)
    
    -- Terminate this script, the scheduler will handle the ambush on sector entry
    terminate()
end

function initialize(...)
    if cw_headhunters.initialize then return cw_headhunters.initialize(...) end
end
