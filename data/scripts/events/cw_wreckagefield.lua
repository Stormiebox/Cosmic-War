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

    local wrecksCreated = 0
    for i = 1, numWrecks do
        local matrix = MatrixLookUpPosition(-vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)), vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)), vec3(random:getFloat(-2000, 2000), random:getFloat(-2000, 2000), random:getFloat(-2000, 2000)))

        -- Spawn broken ships
        if generator:createWreckage(faction, nil, 10, matrix) then wrecksCreated = wrecksCreated + 1 end
    end

    -- If Cosmic Vault News is installed, broadcast news
    local article = {
            title = "Massive Graveyard Discovered",
            category = "War Casualties",
            content = "Scouts returning from sector (" .. x .. ":" .. y .. ") report finding a dense cluster of capital ship wreckages. Scavengers are already flocking to the area to pick the bones clean."
        }
    if wrecksCreated > 0 then
        include("cw_news").Publish({
            article = article,
            eventId = "wreckage-field:" .. tostring(faction.index) .. ":" .. tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(math.floor(Server().unpausedRuntime)),
            threadId = "sector:" .. tostring(x) .. ":" .. tostring(y),
            eventType = "war.aftermath.wreckage_field",
            topic = "discovery",
            severity = "info",
            location = {x = x, y = y, radius = 0},
            provenance = {recordType = "cw_event", sourceRevision = math.floor(Server().unpausedRuntime), sourceState = "materialized", wrecksCreated = wrecksCreated, factionIndex = faction.index}
        })
    end

    terminate()
end

