package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

local SectorGenerator = include("SectorGenerator")

-- namespace CW_WreckagefieldEvent
CW_WreckagefieldEvent = {}

function CW_WreckagefieldEvent.initialize()
    if onClient() then return end

    local sector = Sector()
    local x, y = sector:getCoordinates()
    local random = Random(Seed(Server().unpausedRuntime))

    -- Only trigger in populated sectors
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    if #stations == 0 then
        Sector():removeScript("events/cw_wreckagefield.lua")
        terminate()
        return
    end

    local faction = Galaxy():getNearestFaction(x, y)
    if not faction or not faction.isAIFaction then
        Sector():removeScript("events/cw_wreckagefield.lua")
        terminate()
        return
    end

    -- Spawn a massive wreckage field representing a recent major clash
    local generator = SectorGenerator(x, y)
    local numWrecks = random:getInt(4, 9)

    for i = 1, numWrecks do
        local matrix = MatrixLookUpPosition(-vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)), vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)), vec3(random:getFloat(-2000, 2000), random:getFloat(-2000, 2000), random:getFloat(-2000, 2000)))

        -- Spawn broken ships
        generator:createWreckage(faction, nil, 10, matrix)
    end

    -- If Cosmic Vault News is installed, broadcast news
    local article = {
            title = "Massive Graveyard Discovered",
            category = "War Casualties",
            content = "Scouts returning from sector (" .. x .. ":" .. y .. ") report finding a dense cluster of capital ship wreckages. Scavengers are already flocking to the area to pick the bones clean."
        }
    local cvn = include("cosmicvaultnews")
    cvn.publishArticle(article)

    Sector():removeScript("events/cw_wreckagefield.lua")
    terminate()
end

