package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")

-- namespace CW_RunnerInterceptEvent
-- v4.0.0: an AI blockade runner tries to slip supplies through
-- contested space while an enemy interceptor squadron hunts it down. The
-- player can escort it (fight off the interceptors) or intercept it themselves
-- (finish the job) -- either choice credits a different side's War Score, made
-- entirely through which ship the player chooses to shoot at, no dialog needed.
CW_RunnerInterceptEvent = {}

CW_RunnerInterceptEvent.runnerId = nil
CW_RunnerInterceptEvent.interceptorIds = {}
CW_RunnerInterceptEvent.runnerFactionIndex = 0
CW_RunnerInterceptEvent.interceptorFactionIndex = 0
CW_RunnerInterceptEvent.resolved = false
CW_RunnerInterceptEvent.elapsed = 0

function CW_RunnerInterceptEvent.getUpdateInterval()
    return 5.0
end

function CW_RunnerInterceptEvent.initialize()
    if onServer() then
        if not _restoring then
            CW_RunnerInterceptEvent.spawn()
        end
    end
end

function CW_RunnerInterceptEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local runnerFaction = Galaxy():getControllingFaction(x, y)
    if not runnerFaction or not runnerFaction.isAIFaction then terminate() return end

    local enemyIndex = runnerFaction:getValue("enemy_faction") or 0
    local interceptorFaction = enemyIndex > 0 and Faction(enemyIndex) or nil
    if not interceptorFaction or not interceptorFaction.isAIFaction then terminate() return end

    CW_RunnerInterceptEvent.runnerFactionIndex = runnerFaction.index
    CW_RunnerInterceptEvent.interceptorFactionIndex = interceptorFaction.index

    local generator = SectorGenerator(x, y)
    local runner = ShipGenerator.createFreighterShip(runnerFaction, generator:getPositionInSector())
    runner.title = "Blockade Runner"%_T
    if runner:hasComponent(ComponentType.Shield) then
        runner:addBaseMultiplier(StatsBonuses.ShieldDurability, 4.0)
        runner.shieldDurability = runner.shieldMaxDurability
    end
    -- Without this, a player who leaves before the chase resolves leaves the runner --
    -- and this event's own updateServer polling -- running forever.
    runner:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    CW_RunnerInterceptEvent.runnerId = runner.id

    for i = 1, random():getInt(2, 3) do
        local ship = ShipGenerator.createMilitaryShip(interceptorFaction, generator:getPositionInSector())
        ship.title = "Interceptor"%_T
        ShipAI(ship.index):setAggressive()
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        table.insert(CW_RunnerInterceptEvent.interceptorIds, ship.id)
    end

    sector:broadcastChatMessage(runnerFaction.name, ChatMessageType.Warning,
        "Running the blockade -- anyone out there willing to cover us gets our gratitude."%_T)
end

function CW_RunnerInterceptEvent.updateServer(timeStep)
    if not onServer() or CW_RunnerInterceptEvent.resolved then return end

    local sector = Sector()
    local runner = CW_RunnerInterceptEvent.runnerId and sector:getEntity(CW_RunnerInterceptEvent.runnerId)

    if not runner or not valid(runner) then
        -- Runner destroyed -- the blockade held.
        CW_RunnerInterceptEvent.resolved = true
        CosmicWarBridge.recordWarScoreKill(CW_RunnerInterceptEvent.runnerFactionIndex)
        sector:broadcastChatMessage(Faction(CW_RunnerInterceptEvent.interceptorFactionIndex) and Faction(CW_RunnerInterceptEvent.interceptorFactionIndex).name or "Unknown"%_T, ChatMessageType.Information,
            "Runner down. The blockade holds."%_T)
        terminate()
        return
    end

    CW_RunnerInterceptEvent.elapsed = CW_RunnerInterceptEvent.elapsed + CW_RunnerInterceptEvent.getUpdateInterval()
    if CW_RunnerInterceptEvent.elapsed >= 90 then
        -- The runner made it -- credit its own faction's War Score.
        CW_RunnerInterceptEvent.resolved = true
        CosmicWarBridge.recordWarScoreKill(CW_RunnerInterceptEvent.interceptorFactionIndex)
        sector:broadcastChatMessage(Faction(CW_RunnerInterceptEvent.runnerFactionIndex) and Faction(CW_RunnerInterceptEvent.runnerFactionIndex).name or "Unknown"%_T, ChatMessageType.Information,
            "We're through! Thank you for the cover."%_T)
        sector:deleteEntityJumped(runner)
        terminate()
    end
end

function CW_RunnerInterceptEvent.secure()
    local savedInterceptors = {}
    for _, id in pairs(CW_RunnerInterceptEvent.interceptorIds) do
        table.insert(savedInterceptors, id.string)
    end
    return {
        runnerId = CW_RunnerInterceptEvent.runnerId and CW_RunnerInterceptEvent.runnerId.string,
        interceptorIds = savedInterceptors,
        runnerFactionIndex = CW_RunnerInterceptEvent.runnerFactionIndex,
        interceptorFactionIndex = CW_RunnerInterceptEvent.interceptorFactionIndex,
        resolved = CW_RunnerInterceptEvent.resolved,
        elapsed = CW_RunnerInterceptEvent.elapsed,
    }
end

function CW_RunnerInterceptEvent.restore(data)
    CW_RunnerInterceptEvent.runnerId = data.runnerId and Uuid(data.runnerId)
    CW_RunnerInterceptEvent.interceptorIds = {}
    if data.interceptorIds then
        for _, idStr in pairs(data.interceptorIds) do
            table.insert(CW_RunnerInterceptEvent.interceptorIds, Uuid(idStr))
        end
    end
    CW_RunnerInterceptEvent.runnerFactionIndex = data.runnerFactionIndex or 0
    CW_RunnerInterceptEvent.interceptorFactionIndex = data.interceptorFactionIndex or 0
    CW_RunnerInterceptEvent.resolved = data.resolved or false
    CW_RunnerInterceptEvent.elapsed = data.elapsed or 0
end
