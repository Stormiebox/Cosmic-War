package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")

-- namespace CW_DefectionOfferEvent
-- v4.0.0: fires against a faction currently losing badly on War
-- Score (|score| >= 100 from its own perspective) -- one of its warships wants
-- out and is offering to stand down for a price. Makes War Score personally
-- consequential rather than only a background number. The interaction itself
-- lives on the ship's own attached script (cw_defector_ship.lua) -- see
-- observation 0110.
CW_DefectionOfferEvent = {}

function CW_DefectionOfferEvent.initialize()
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
    local scoreFromThisFactionPerspective = (faction.index == lo) and score or -score
    if scoreFromThisFactionPerspective > -100 then
        terminate()
        return
    end

    local generator = SectorGenerator(x, y)
    local ship = ShipGenerator.createMilitaryShip(faction, generator:getPositionInSector())
    ship.title = "Wavering Officer"%_T
    -- Deliberately not set aggressive -- this ship isn't looking for a fight, it's
    -- looking for a way out.
    ship:addScriptOnce("data/scripts/entity/cw_defector_ship.lua", { faction.index, 200000 })
    ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    sector:broadcastChatMessage("Unknown"%_T, ChatMessageType.Information,
        "A lone %1% warship is hailing anyone nearby -- broken transmission, but it sounds like they want out."%_T, faction.name)

    terminate()
end
