package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
include("randomext")

-- namespace CW_ArtilleryBarrageEvent
-- v4.0.0: a stationary long-range platform, distinct from Orbital
-- Bombardment's mobile bombers. While it lives, it periodically re-applies the
-- Shield Jammer debuff (cw_shieldjammer.lua, the same one Fleet Clash/Siege
-- Event already use) to every present player ship -- shield regeneration stays
-- suppressed for as long as the platform survives, not just a single 10-second
-- hit.
CW_ArtilleryBarrageEvent = {}

CW_ArtilleryBarrageEvent.platformId = nil
CW_ArtilleryBarrageEvent.defenderFactionIndex = 0
CW_ArtilleryBarrageEvent.attackerFactionIndex = 0
CW_ArtilleryBarrageEvent.elapsed = 0
CW_ArtilleryBarrageEvent.duration = 6 * 60

function CW_ArtilleryBarrageEvent.getUpdateInterval()
    return 8.0
end

function CW_ArtilleryBarrageEvent.initialize()
    if onServer() then
        if not _restoring then
            CW_ArtilleryBarrageEvent.spawn()
        end
    end
end

function CW_ArtilleryBarrageEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local defenderFaction = Galaxy():getControllingFaction(x, y)
    if not defenderFaction or not defenderFaction.isAIFaction then terminate() return end

    local enemyIndex = defenderFaction:getValue("enemy_faction") or 0
    local attackerFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not attackerFaction or not attackerFaction.isAIFaction then terminate() return end

    CW_ArtilleryBarrageEvent.defenderFactionIndex = defenderFaction.index
    CW_ArtilleryBarrageEvent.attackerFactionIndex = attackerFaction.index

    local generator = SectorGenerator(x, y)
    local platform = ShipGenerator.createDefender(attackerFaction, generator:getPositionInSector())
    platform.title = "Artillery Platform"%_T
    -- Without this, a player who spots the platform and jumps away without destroying it
    -- leaves it (and this event's own updateServer polling) running forever -- the same
    -- cleanup every other sector event in this mod attaches to its spawned ships.
    platform:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    if platform:hasComponent(ComponentType.Durability) then
        Durability(platform.index).maxDurabilityFactor = Durability(platform.index).maxDurabilityFactor * 3.0
        platform.durability = platform.maxDurability
    end
    CW_ArtilleryBarrageEvent.platformId = platform.id

    sector:broadcastChatMessage(attackerFaction.name, ChatMessageType.Warning,
        "Artillery platform in range. Suppressing their shields -- move in while they're exposed."%_T)
end

function CW_ArtilleryBarrageEvent.updateServer(timeStep)
    if not onServer() then return end
    if not CW_ArtilleryBarrageEvent.platformId then return end

    local sector = Sector()
    local platform = sector:getEntity(CW_ArtilleryBarrageEvent.platformId)
    if not platform or not valid(platform) then
        sector:broadcastChatMessage("Planetary Defense"%_T, ChatMessageType.Information,
            "The artillery platform is down! Shields are free to recharge again."%_T)
        terminate()
        return
    end

    CW_ArtilleryBarrageEvent.elapsed = CW_ArtilleryBarrageEvent.elapsed + CW_ArtilleryBarrageEvent.getUpdateInterval()
    if CW_ArtilleryBarrageEvent.elapsed >= CW_ArtilleryBarrageEvent.duration then
        sector:broadcastChatMessage("Planetary Defense"%_T, ChatMessageType.Information,
            "The barrage has lifted -- the platform is withdrawing out of range."%_T)
        terminate()
        return
    end

    -- Re-apply the jammer to every present player ship every 8s -- the jammer's
    -- own 10s duration means this keeps regeneration suppressed continuously for
    -- as long as the platform survives, without needing to touch the jammer
    -- script itself. The platform belongs to attackerFaction, so it's their weapon --
    -- only players actually at war with them should eat the debuff. Without this check,
    -- a player allied with the attacker (or simply at peace with them) got their own
    -- side's shields suppressed by a platform that isn't targeting them at all.
    for _, player in pairs({sector:getPlayers()}) do
        if player:getRelationStatus(CW_ArtilleryBarrageEvent.attackerFactionIndex) == RelationStatus.War then
            local ship = player.craftIndex and sector:getEntity(player.craftIndex)
            if ship and ship:hasComponent(ComponentType.Shield) then
                ship:addScriptOnce("data/scripts/entity/debuffs/cw_shieldjammer.lua")
            end
        end
    end
end

function CW_ArtilleryBarrageEvent.secure()
    return {
        platformId = CW_ArtilleryBarrageEvent.platformId and CW_ArtilleryBarrageEvent.platformId.string,
        defenderFactionIndex = CW_ArtilleryBarrageEvent.defenderFactionIndex,
        attackerFactionIndex = CW_ArtilleryBarrageEvent.attackerFactionIndex,
        elapsed = CW_ArtilleryBarrageEvent.elapsed,
    }
end

function CW_ArtilleryBarrageEvent.restore(data)
    CW_ArtilleryBarrageEvent.platformId = data.platformId and Uuid(data.platformId)
    CW_ArtilleryBarrageEvent.defenderFactionIndex = data.defenderFactionIndex or 0
    CW_ArtilleryBarrageEvent.attackerFactionIndex = data.attackerFactionIndex or 0
    CW_ArtilleryBarrageEvent.elapsed = data.elapsed or 0
end
