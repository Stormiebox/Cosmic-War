package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
include("randomext")

-- namespace CW_OrbitalBombardmentEvent
CW_OrbitalBombardmentEvent = {}

CW_OrbitalBombardmentEvent.bomberIds = {}
CW_OrbitalBombardmentEvent.defenderFactionIndex = 0
CW_OrbitalBombardmentEvent.attackerFactionIndex = 0
CW_OrbitalBombardmentEvent.elapsed = 0
CW_OrbitalBombardmentEvent.duration = 8 * 60 -- bombers withdraw after 8 minutes if not stopped

function CW_OrbitalBombardmentEvent.getUpdateInterval()
    return 5.0
end

function CW_OrbitalBombardmentEvent.initialize()
    if onServer() then
        if not _restoring then
            CW_OrbitalBombardmentEvent.spawn()
        end
    end
end

function CW_OrbitalBombardmentEvent.spawn()
    local sector = Sector()

    -- Roaming war events don't fire in neutral zones -- matches every sibling event
    -- (cw_armsdeal.lua, cw_diplomaticsabotage.lua, etc.).
    if sector:getValue("neutral_zone") then
        terminate()
        return
    end

    local x, y = sector:getCoordinates()

    -- "Mayday, we're under bombardment" only makes sense over a sector someone actually
    -- controls, and the attacker must be that defender's real registered enemy -- not
    -- just whichever faction happens to be nearest an offset point (which could land on
    -- no man's land, the defender itself, or even a player faction/alliance).
    local defenderFaction = Galaxy():getControllingFaction(x, y)
    if not defenderFaction or not defenderFaction.isAIFaction then
        terminate()
        return
    end

    local enemyIndex = defenderFaction:getValue("enemy_faction") or 0
    local attackerFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not attackerFaction or not attackerFaction.isAIFaction then
        terminate()
        return
    end

    CW_OrbitalBombardmentEvent.defenderFactionIndex = defenderFaction.index
    CW_OrbitalBombardmentEvent.attackerFactionIndex = attackerFaction.index

    -- v4.0.0: previously 5 bombers spawned and just fought like any other ambush --
    -- the file's own comment admitted there was no actual bombardment. They now
    -- periodically inflict direct damage on the defender's stations in updateServer(),
    -- the same Durability:inflictDamage() API vanilla's own laserbossbehavior.lua uses
    -- for its boss barrage, so a bombardment sector is genuinely under attack even if
    -- no player is actively fighting the bombers off.
    local generator = SectorGenerator(x, y)
    for i = 1, 5 do
        local bomber = ShipGenerator.createMilitaryShip(attackerFaction, generator:getPositionInSector())
        bomber.title = "Orbital Bomber"
        ShipAI(bomber.index):setAggressive()
        table.insert(CW_OrbitalBombardmentEvent.bomberIds, bomber.id)
    end

    sector:broadcastChatMessage("Planetary Defense"%_T, ChatMessageType.Warning,
        "Mayday! We are under intense orbital bombardment! Any available ships, please assist!"%_T)
end

local function countLivingBombers()
    local living = {}
    local sector = Sector()
    for _, id in pairs(CW_OrbitalBombardmentEvent.bomberIds) do
        local ship = sector:getEntity(id)
        if ship and valid(ship) then
            table.insert(living, ship)
        end
    end
    return living
end

function CW_OrbitalBombardmentEvent.updateServer(timeStep)
    if not onServer() then return end
    if #CW_OrbitalBombardmentEvent.bomberIds == 0 then return end -- spawn() hasn't run yet, or already resolved

    local sector = Sector()
    local livingBombers = countLivingBombers()

    if #livingBombers == 0 then
        sector:broadcastChatMessage("Planetary Defense"%_T, ChatMessageType.Information,
            "The bombardment has ceased. All hostile bombers have been destroyed!"%_T)
        terminate()
        return
    end

    CW_OrbitalBombardmentEvent.elapsed = CW_OrbitalBombardmentEvent.elapsed + CW_OrbitalBombardmentEvent.getUpdateInterval()
    if CW_OrbitalBombardmentEvent.elapsed >= CW_OrbitalBombardmentEvent.duration then
        sector:broadcastChatMessage("Planetary Defense"%_T, ChatMessageType.Information,
            "The bombers are withdrawing -- reinforcements must be inbound elsewhere."%_T)
        terminate()
        return
    end

    -- Bombard one random defending station per tick: 1.5% of its max hull per hit,
    -- every 5s (~18%/min if left completely unchallenged) -- real, ongoing pressure
    -- that rewards intervention without being an instant-loss timer.
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    local targets = {}
    for _, station in pairs(stations) do
        if station.factionIndex == CW_OrbitalBombardmentEvent.defenderFactionIndex and station:hasComponent(ComponentType.Durability) then
            table.insert(targets, station)
        end
    end

    if #targets == 0 then
        -- No defending stations left standing at all -- the sector has already fallen
        -- to something else (siege, prior combat); nothing left to bombard.
        terminate()
        return
    end

    -- Deterministic random() (not math.random) -- multiplayer clients/server must agree
    -- on which station gets hit each tick.
    local target = targets[random():getInt(1, #targets)]
    local durability = Durability(target.index)
    local amount = target.maxDurability * 0.015
    durability:inflictDamage(amount, 1, DamageType.Energy, livingBombers[1].id)
end

function CW_OrbitalBombardmentEvent.secure()
    local savedIds = {}
    for _, id in pairs(CW_OrbitalBombardmentEvent.bomberIds) do
        table.insert(savedIds, id.string)
    end
    return {
        bomberIds = savedIds,
        defenderFactionIndex = CW_OrbitalBombardmentEvent.defenderFactionIndex,
        attackerFactionIndex = CW_OrbitalBombardmentEvent.attackerFactionIndex,
        elapsed = CW_OrbitalBombardmentEvent.elapsed
    }
end

function CW_OrbitalBombardmentEvent.restore(data)
    CW_OrbitalBombardmentEvent.bomberIds = {}
    if data.bomberIds then
        for _, idStr in pairs(data.bomberIds) do
            table.insert(CW_OrbitalBombardmentEvent.bomberIds, Uuid(idStr))
        end
    end
    CW_OrbitalBombardmentEvent.defenderFactionIndex = data.defenderFactionIndex or 0
    CW_OrbitalBombardmentEvent.attackerFactionIndex = data.attackerFactionIndex or 0
    CW_OrbitalBombardmentEvent.elapsed = data.elapsed or 0
end
