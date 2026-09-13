-- namespace CosmicWarRiftHazard
CosmicWarRiftHazard = {}

local CosmicVaultRift = include("cosmicvaultrift")
local CosmicVaultWeather = include("cosmicvaultweather")

local lifetimeMode = "persistent"
local targetEntityId
local conditionId
local canonicalSeen = false
local legacyMigrationComplete = false

local function findLegacyTarget()
    local sector = Sector()
    for _, entityType in ipairs({EntityType.Station, EntityType.Ship}) do
        for _, entity in pairs({sector:getEntitiesByType(entityType)}) do
            if valid(entity) and entity:getValue("cw_mission_target") then
                return entity.id.string
            end
        end
    end
end

local function findCanonicalCondition()
    local sector = Sector()
    if not sector then return nil, "sector_unavailable" end
    local x, y = sector:getCoordinates()
    local conditions, errorCode = CosmicVaultWeather.ListWeatherAt(x, y)
    if not conditions then return nil, errorCode end
    for _, condition in ipairs(conditions) do
        if condition.conditionId == conditionId
                or (not conditionId and condition.weatherType == "RiftInstability"
                    and type(condition.sourceId) == "string"
                    and string.sub(condition.sourceId, 1, 3) == "cw-") then
            conditionId = condition.conditionId
            return condition
        end
    end
    return false
end

local function migrateLegacyAttachment()
    if legacyMigrationComplete then return false end
    local sector = Sector()
    if not sector then return nil end
    local x, y = sector:getCoordinates()
    targetEntityId = targetEntityId or findLegacyTarget()
    lifetimeMode = targetEntityId and "target_bound" or "persistent"
    local condition = CosmicVaultRift.StartRiftHazard({
        sourceId = "cw-legacy-rift:" .. tostring(x) .. ":" .. tostring(y),
        x = x,
        y = y,
        duration = -1,
        conflictPolicy = "replace"
    })
    if not condition then return nil end
    conditionId = condition.conditionId
    canonicalSeen = true
    legacyMigrationComplete = true
    return true
end

function CosmicWarRiftHazard.initialize(initialMode, initialTargetEntityId,
        initialConditionId)
    CosmicWarRiftHazard.reconcile(initialMode, initialTargetEntityId, initialConditionId)
end

function CosmicWarRiftHazard.reconcile(newMode, newTargetEntityId, newConditionId)
    if newMode == "persistent" or newMode == "target_bound" then
        lifetimeMode = newMode
    end
    targetEntityId = type(newTargetEntityId) == "string" and newTargetEntityId or nil
    if type(newConditionId) == "string" then
        conditionId = newConditionId
        canonicalSeen = true
        legacyMigrationComplete = true
    end
    return true
end

function CosmicWarRiftHazard.getUpdateInterval()
    return 2
end

function CosmicWarRiftHazard.updateServer()
    local condition = findCanonicalCondition()
    if condition == nil then
        return
    elseif condition == false then
        if canonicalSeen then
            terminate()
            return
        end
        if not migrateLegacyAttachment() then return end
    else
        canonicalSeen = true
    end

    local protectedTarget
    if lifetimeMode == "target_bound" then
        protectedTarget = targetEntityId and Entity(Uuid(targetEntityId)) or nil
        if not valid(protectedTarget) then
            local ended = conditionId and CosmicVaultRift.EndRiftHazard(conditionId,
                "target_removed")
            if ended then terminate() end
            return
        end
    end

    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if valid(entity) and (not protectedTarget or entity.id.string ~= targetEntityId) then
            local maxShield = entity.shieldMaxDurability or 0
            if maxShield > 0 then
                entity.shieldDurability = math.max(0,
                    (entity.shieldDurability or 0) - maxShield * 0.05)
            end
        end
    end
end

function CosmicWarRiftHazard.secure()
    return {
        lifetimeMode = lifetimeMode,
        targetEntityId = targetEntityId,
        conditionId = conditionId,
        canonicalSeen = canonicalSeen,
        legacyMigrationComplete = legacyMigrationComplete
    }
end

function CosmicWarRiftHazard.restore(data)
    if type(data) ~= "table" then return end
    if data.lifetimeMode == "persistent" or data.lifetimeMode == "target_bound" then
        lifetimeMode = data.lifetimeMode
    end
    targetEntityId = type(data.targetEntityId) == "string" and data.targetEntityId or nil
    conditionId = type(data.conditionId) == "string" and data.conditionId or nil
    canonicalSeen = data.canonicalSeen == true
    legacyMigrationComplete = data.legacyMigrationComplete == true
end
