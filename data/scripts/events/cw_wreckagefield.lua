package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("galaxy")
local SectorGenerator = include("sectorgenerator")

local cw_wreckagefield = {}

function cw_wreckagefield.initialize()
    if onClient() then return end
    
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local random = Random(Seed(os.time()))
    
    -- Only trigger in populated sectors
    if sector.numFactions == 0 then
        terminate()
        return
    end
    
    local faction = Galaxy():getNearestFaction(x, y)
    if not faction or not faction.isAIFaction then
        terminate()
        return
    end

    -- Spawn a massive wreckage field representing a recent major clash
    local generator = SectorGenerator(x, y)
    local numWrecks = random:getInt(4, 9)
    
    for i = 1, numWrecks do
        local matrix = MatrixLookUpPosition(-vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)), vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)), vec3(random:getFloat(-2000, 2000), random:getFloat(-2000, 2000), random:getFloat(-2000, 2000)))
        
        -- Spawn broken ships
        generator:createWreckage(faction, matrix)
    end
    
    -- If Cosmic Vault News is installed, broadcast news
    pcall(function()
        local server = Server()
        local article = {
            title = "Massive Graveyard Discovered",
            category = "War Casualties",
            content = "Scouts returning from sector (" .. x .. ":" .. y .. ") report finding a dense cluster of capital ship wreckages. Scavengers are already flocking to the area to pick the bones clean."
        }
        local cvn_success, cvn = pcall(include, "cosmicvaultnews")
        if cvn_success and cvn and cvn.publishArticle then
            cvn.publishArticle(article)
        else
            server:sendCallback("onCCNewsPublishArticle", article)
        end
    end)
    
    terminate()
end

return cw_wreckagefield
