package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicVaultUI = include("cosmicvaultui")

-- namespace CW_EclipseVanguardEvent
CW_EclipseVanguardEvent = {}

function CW_EclipseVanguardEvent.initialize()
    if onClient() then return end
    if not _restoring then deferredCallback(2.0, "spawn") end
    deferredCallback(15 * 60, "finalize")
end

function CW_EclipseVanguardEvent.finalize() terminate() end

function CW_EclipseVanguardEvent.spawn()
    -- Safety Guard: Ensure Eclipse is fully awoken. "eclipse_fully_awake" is a plain Server
    -- custom value, so no include() is needed to read it.
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
    -- v4.0.0: the original 50x/50x offense multipliers below predate this
    -- pass's hull fix (4x maxDurabilityFactor, added below) and were left untouched by it --
    -- leaving a solo, escort-less ship hitting far harder than Decapitation Strike, this
    -- mod's own calibrated "true superboss" (8 escorts, up to ~12x fire rate at max heat).
    -- Recalibrated using that same hpMult-scaling formula at this ship's own 4.0 hull
    -- multiplier, so it stays a step below the superboss on every axis instead of above it.
    dreadnought:addBaseMultiplier(StatsBonuses.FireRate, 5.0) -- 6x total

    if dreadnought:hasComponent(ComponentType.Shield) then
        dreadnought:addBaseMultiplier(StatsBonuses.ShieldDurability, 3.0) -- 4x total
        dreadnought.shieldDurability = dreadnought.shieldMaxDurability
    end

    -- v4.0.0: this boss-tier anomaly had 50x shields and 50x fire rate but zero hull
    -- scaling -- once the shield broke, it died like a stock military ship. 4x hull
    -- toughness (via the same officially-supported maxDurabilityFactor API used
    -- throughout this mod) gives it a real second phase after the shield goes down,
    -- without approaching Decapitation Strike's true-superboss toughness.
    if dreadnought:hasComponent(ComponentType.Durability) then
        Durability(dreadnought.index).maxDurabilityFactor = Durability(dreadnought.index).maxDurabilityFactor * 4.0
        dreadnought.durability = dreadnought.maxDurability
    end

    Sector():broadcastChatMessage("Unknown", 2, "WARNING: MASSIVE ANOMALY DETECTED. THE ECLIPSE VANGUARD HAS ARRIVED."%_T)

    -- ShowCinematicBanner is a server-only "push" helper (it guards `if not onServer()`
    -- and does its own player:invokeFunction() push internally) -- call it directly from
    -- here for each player rather than broadcasting to clients and having them call it
    -- on themselves, which silently no-ops. See Avorion_Modding_Codex.md's
    -- "A Player()-targeted push API must be called from the server" section.
    for _, player in pairs({Sector():getPlayers()}) do
        CosmicVaultUI.ShowCinematicBanner(player, "ECLIPSE VANGUARD INBOUND", ColorRGB(1, 0, 0), "data/sounds/siren.ogg", 5)
    end

    terminate()
end
