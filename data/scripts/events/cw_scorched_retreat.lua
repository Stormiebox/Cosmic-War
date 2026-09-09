package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")
local CosmicVaultEconomy = include("cosmicvaulteconomy")

-- namespace CW_ScorchedRetreatEvent
-- v4.0.0 Final Pass: fires only against a faction that's losing badly on War
-- Score (|score| >= 100, from the loser's perspective) -- narrated as already
-- having happened by the time the player arrives, rather than something the
-- player resolves. A losing faction demolished its own station here rather
-- than let it be captured intact, leaving a rich wreckage field and a real
-- Famine spike behind.
CW_ScorchedRetreatEvent = {}

function CW_ScorchedRetreatEvent.initialize()
    if onClient() then return end

    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction or not faction:getValue("cw_enabled") then
        terminate()
        return
    end

    local enemyIndex = faction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 then terminate() return end

    local score = CosmicWarBridge.getWarScore(faction.index, enemyIndex) or 0
    local lo = math.min(faction.index, enemyIndex)
    -- getWarScore() is signed from factionA's perspective (positive favors A) --
    -- normalize so "this specific faction is losing" reads correctly regardless
    -- of which side of the pair it happens to be.
    local scoreFromThisFactionPerspective = (faction.index == lo) and score or -score
    if scoreFromThisFactionPerspective > -100 then
        terminate()
        return
    end

    local random = Random(Seed(Server().unpausedRuntime + x * 31 + y * 17))
    local generator = SectorGenerator(x, y)
    for i = 1, random:getInt(3, 6) do
        local matrix = MatrixLookUpPosition(
            -vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)),
            vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), random:getFloat(-1, 1)),
            vec3(random:getFloat(-1500, 1500), random:getFloat(-1500, 1500), random:getFloat(-1500, 1500))
        )
        generator:createWreckage(faction, nil, 8, matrix)
    end

    CosmicVaultEconomy.addFamineScore(faction.index, 20)

    Sector():broadcastChatMessage("Unknown"%_T, ChatMessageType.Information,
        "Scans show a demolished station and heavy debris here -- looks like %1% chose to scorch this position rather than let it be taken intact."%_T, faction.name)

    local cvn = include("cosmicvaultnews")
    cvn.publishArticle({
        title = "Scorched Retreat: " .. tostring(faction.name) .. " Demolishes Its Own Position",
        content = "Rather than let sector (" .. x .. ":" .. y .. ") fall intact, " .. tostring(faction.name) .. " demolished the station there themselves. The wreckage is rich, but the loss has deepened their famine.",
        category = "War"
    })

    terminate()
end
