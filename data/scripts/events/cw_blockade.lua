package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local ShipGenerator = include("shipgenerator")

local cw_blockade = {}

function cw_blockade.initialize()
    if onClient() then return end

    local sector = Sector()
    local x, y = sector:getCoordinates()

    -- Only trigger in populated sectors
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    if #stations == 0 then
        terminate()
        return
    end

    local defender = Galaxy():getNearestFaction(x, y)
    if not defender or not defender.isAIFaction then
        terminate()
        return
    end

    local enemyIndex = defender:getValue("enemy_faction") or 0
    if enemyIndex == 0 then
        terminate()
        return
    end

    local attacker = Faction(enemyIndex)
    if not attacker then
        terminate()
        return
    end

    -- Create Blockade Fleet at the sector's edge
    local random = Random(Seed(os.time()))
    local dir = vec3(random:getFloat(-1, 1), 0, random:getFloat(-1, 1))
    if length(dir) == 0 then dir = vec3(1, 0, 0) end
    dir = normalize(dir)

    local distance = 15000 -- spawn near the edge where jump gates usually are
    local center = dir * distance

    for i = 1, random:getInt(3, 5) do
        local pos = center + vec3(random:getFloat(-500, 500), random:getFloat(-500, 500), random:getFloat(-500, 500))
        local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)
        local ship = ShipGenerator.createMilitaryShip(attacker, matrix, random:getInt(1, 3)) -- 1: defender, 2: attacker, 3: heavy
        ship:addScriptOnce("ai/patrol.lua")
    end

    -- If Cosmic Vault News is installed, broadcast news
    local article = {
            title = "Trade Route Blockaded!",
            category = "War Update",
            content = attacker.name .. " forces have established a blockade on the outskirts of sector (" .. x .. ":" .. y .. "). All neutral merchants and civilian vessels are advised to steer clear or risk being fired upon."
        }
    local cvn = include("cosmicvaultnews")
    cvn.publishArticle(article)

    terminate()
end

function initialize(...)
    if cw_blockade.initialize then return cw_blockade.initialize(...) end
end
