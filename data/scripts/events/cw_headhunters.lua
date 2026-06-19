package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("galaxy")
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

    -- Spawn the Headhunter Hit-Squad
    local random = Random(Seed(os.time()))
    local dir = vec3(random:getFloat(-1, 1), 0, random:getFloat(-1, 1))
    if length(dir) == 0 then dir = vec3(1, 0, 0) end
    dir = normalize(dir)

    local distance = 3000
    local center = dir * distance

    for i = 1, random:getInt(2, 4) do
        local pos = center + vec3(random:getFloat(-200, 200), random:getFloat(-200, 200), random:getFloat(-200, 200))
        local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)
        local ship = ShipGenerator.createMilitaryShip(bestEnemy, matrix, 3) -- Heavy military

        -- Soft Bridge to Cosmic Starfall (Equip heavy subsystems if available)
        pcall(function()
            local success, sfAPI = pcall(include, "starfall_subsystems")
            if success and sfAPI and sfAPI.equipEliteSubsystems then
                sfAPI.equipEliteSubsystems(ship)
            end
        end)

        ship.title = "Elite Headhunter"
        ship:addScriptOnce("ai/patrol.lua")
        ship:addScriptOnce("data/scripts/entity/enemy.lua")
    end

    player:sendChatMessage("Alert", 2, "Warning: Incoming elite headhunter fleet from " .. bestEnemy.name .. "!")

    terminate()
end

function initialize(...)
    if cw_headhunters.initialize then return cw_headhunters.initialize(...) end
end
