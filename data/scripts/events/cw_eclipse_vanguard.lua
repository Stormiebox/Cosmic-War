package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- namespace CosmicWarEvent
local CosmicWarEvent = {}

function CosmicWarEvent.initialize()
    if onServer() then
        CosmicWarEvent.spawn()
    end
end

function CosmicWarEvent.spawn()
    -- Safety Guard: Ensure Eclipse is fully awoken
    include("cosmicascendancybridge")
    if not Server():getValue("eclipse_fully_awake") then
        include("cosmicvaultdebug").info("Cosmic War", "[Cosmic War] Eclipse not awoken. Skipping Eclipse Vanguard event.")
        return
    end


    local x, y = Sector():getCoordinates()
    -- Emulate a boss-level faction
    local eclipseFaction = Galaxy():getPirateFaction(0)

    local dreadnought = ShipGenerator.createBossShip(eclipseFaction, SectorGenerator(x,y):getPositionInSector())
    dreadnought.title = "The Eclipse Vanguard"
    dreadnought:addScriptOnce("data/scripts/entity/ai/patrol.lua")
    dreadnought:addMultiplyableBias(StatsBonuses.FireRate, 49.0) -- 50x total

    if dreadnought:hasComponent(ComponentType.Shield) then
        dreadnought.shieldMaxDurability = dreadnought.shieldMaxDurability * 50.0
        dreadnought.shieldDurability = dreadnought.shieldMaxDurability
    end

    Sector():broadcastChatMessage("Unknown", 2, "WARNING: MASSIVE ANOMALY DETECTED. THE ECLIPSE VANGUARD HAS ARRIVED.")
    broadcastInvokeClientFunction("showVanguardBanner")
    terminate()
end

function CosmicWarEvent.showVanguardBanner()
    if onClient() then
        local CosmicVaultUI = include("cosmicvaultui")
        if CosmicVaultUI and CosmicVaultUI.ShowCinematicBanner then
            CosmicVaultUI.ShowCinematicBanner(Player(), "ECLIPSE VANGUARD INBOUND", ColorRGB(1, 0, 0), "data/sounds/siren.ogg", 5)
        end
    end
end
callable(CosmicWarEvent, "showVanguardBanner")
