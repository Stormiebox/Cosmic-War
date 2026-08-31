package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")

-- namespace CW_EclipseVanguardEvent
CW_EclipseVanguardEvent = {}

function CW_EclipseVanguardEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_EclipseVanguardEvent.finalize() terminate() end

function CW_EclipseVanguardEvent.spawn()
    -- Safety Guard: Ensure Eclipse is fully awoken
    include("cosmicascendancybridge")
    if not Server():getValue("eclipse_fully_awake") then
        include("cosmicvaultdebug").info("Cosmic War", "[Cosmic War] Eclipse not awoken. Skipping Eclipse Vanguard event.")
        terminate()
        return
    end


    local x, y = Sector():getCoordinates()
    -- Emulate a boss-level faction
    local eclipseFaction = Galaxy():getPirateFaction(0)

    local dreadnought = ShipGenerator.createMilitaryShip(eclipseFaction, SectorGenerator(x,y):getPositionInSector())
    dreadnought.title = "The Eclipse Vanguard"
    dreadnought:addScriptOnce("data/scripts/entity/ai/patrol.lua")
    dreadnought:addBaseMultiplier(StatsBonuses.FireRate, 49.0) -- 50x total

    if dreadnought:hasComponent(ComponentType.Shield) then
        dreadnought:addBaseMultiplier(StatsBonuses.ShieldDurability, 49.0)
        dreadnought.shieldDurability = dreadnought.shieldMaxDurability
    end

    Sector():broadcastChatMessage("Unknown", 2, "WARNING: MASSIVE ANOMALY DETECTED. THE ECLIPSE VANGUARD HAS ARRIVED.")
    broadcastInvokeClientFunction("showVanguardBanner")
    terminate()
end

function CW_EclipseVanguardEvent.showVanguardBanner()
    if onClient() then
        local CosmicVaultUI = include("cosmicvaultui")
        if CosmicVaultUI and CosmicVaultUI.ShowCinematicBanner then
            CosmicVaultUI.ShowCinematicBanner(Player(), "ECLIPSE VANGUARD INBOUND", ColorRGB(1, 0, 0), "data/sounds/siren.ogg", 5)
        end
    end
end
callable(CW_EclipseVanguardEvent, "showVanguardBanner")
