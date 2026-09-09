package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipGenerator = include("shipgenerator")
local SectorGenerator = include("SectorGenerator")
local CosmicWarBridge = include("cosmicwarbridge")
include("randomext")
include("relations")

-- namespace CW_PrisonerTransportEvent
-- v4.0.0 Final Pass: ties Extract POW's fiction into the ambient world -- a
-- lightly escorted POW convoy, out in the open rather than behind a heavily
-- guarded facility. Destroy the escorts and let the transport survive to credit
-- a War Score kill and pay out directly (rather than routing through Military
-- Outpost, keeping this event self-contained).
CW_PrisonerTransportEvent = {}

CW_PrisonerTransportEvent.transportId = nil
CW_PrisonerTransportEvent.escortIds = {}
CW_PrisonerTransportEvent.captorFactionIndex = 0
CW_PrisonerTransportEvent.resolved = false

function CW_PrisonerTransportEvent.getUpdateInterval()
    return 5.0
end

function CW_PrisonerTransportEvent.initialize()
    if onServer() then
        if not _restoring then
            CW_PrisonerTransportEvent.spawn()
        end
    end
end

function CW_PrisonerTransportEvent.spawn()
    local sector = Sector()
    if sector:getValue("neutral_zone") then terminate() return end

    local x, y = sector:getCoordinates()
    local captorFaction = Galaxy():getControllingFaction(x, y)
    if not captorFaction or not captorFaction.isAIFaction then terminate() return end

    local enemyIndex = captorFaction:getValue("enemy_faction") or 0
    if enemyIndex <= 0 or not Faction(enemyIndex) then terminate() return end

    CW_PrisonerTransportEvent.captorFactionIndex = captorFaction.index
    CW_PrisonerTransportEvent.enemyFactionIndex = enemyIndex

    local generator = SectorGenerator(x, y)
    local transport = ShipGenerator.createFreighterShip(captorFaction, generator:getPositionInSector())
    transport.title = "Prisoner Transport"%_T
    CW_PrisonerTransportEvent.transportId = transport.id

    for i = 1, random():getInt(2, 3) do
        local escort = ShipGenerator.createDefender(captorFaction, generator:getPositionInSector())
        escort.title = "Transport Escort"%_T
        ShipAI(escort.index):setAggressive()
        table.insert(CW_PrisonerTransportEvent.escortIds, escort.id)
    end

    sector:broadcastChatMessage(captorFaction.name, ChatMessageType.Warning,
        "Prisoner transport moving through this sector under light escort. Standard protocol."%_T)
end

function CW_PrisonerTransportEvent.updateServer(timeStep)
    if not onServer() or CW_PrisonerTransportEvent.resolved then return end

    local sector = Sector()
    local transport = CW_PrisonerTransportEvent.transportId and sector:getEntity(CW_PrisonerTransportEvent.transportId)
    if not transport or not valid(transport) then
        -- The transport itself was destroyed -- the prisoners are lost. No reward,
        -- no penalty; this simply resolves quietly.
        terminate()
        return
    end

    local anyEscortAlive = false
    for _, id in pairs(CW_PrisonerTransportEvent.escortIds) do
        local escort = sector:getEntity(id)
        if escort and valid(escort) then
            anyEscortAlive = true
            break
        end
    end

    if not anyEscortAlive then
        CW_PrisonerTransportEvent.resolved = true
        CosmicWarBridge.recordWarScoreKill(CW_PrisonerTransportEvent.captorFactionIndex)

        for _, player in pairs({sector:getPlayers()}) do
            player:receive("Prisoners Freed"%_T, 180000)
            local enemyFaction = Faction(CW_PrisonerTransportEvent.enemyFactionIndex)
            if enemyFaction then
                changeRelations(player, enemyFaction, 10000, RelationChangeType.General)
            end
        end

        sector:broadcastChatMessage("Prisoner Transport"%_T, ChatMessageType.Information,
            "The escort is down -- we're free! Thank you, whoever you are."%_T)

        sector:deleteEntityJumped(transport)
        terminate()
    end
end

function CW_PrisonerTransportEvent.secure()
    local savedEscorts = {}
    for _, id in pairs(CW_PrisonerTransportEvent.escortIds) do
        table.insert(savedEscorts, id.string)
    end
    return {
        transportId = CW_PrisonerTransportEvent.transportId and CW_PrisonerTransportEvent.transportId.string,
        escortIds = savedEscorts,
        captorFactionIndex = CW_PrisonerTransportEvent.captorFactionIndex,
        enemyFactionIndex = CW_PrisonerTransportEvent.enemyFactionIndex,
        resolved = CW_PrisonerTransportEvent.resolved,
    }
end

function CW_PrisonerTransportEvent.restore(data)
    CW_PrisonerTransportEvent.transportId = data.transportId and Uuid(data.transportId)
    CW_PrisonerTransportEvent.escortIds = {}
    if data.escortIds then
        for _, idStr in pairs(data.escortIds) do
            table.insert(CW_PrisonerTransportEvent.escortIds, Uuid(idStr))
        end
    end
    CW_PrisonerTransportEvent.captorFactionIndex = data.captorFactionIndex or 0
    CW_PrisonerTransportEvent.enemyFactionIndex = data.enemyFactionIndex or 0
    CW_PrisonerTransportEvent.resolved = data.resolved or false
end
