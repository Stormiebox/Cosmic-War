package.path = package.path .. ";data/scripts/lib/?.lua"

local uiContainer = nil
local blueRect = nil
local redRect = nil
local timeLabel = nil
local factionLabel = nil

local endTime = 0
local totalTime = 60 * 60 -- Default to 1 hour if unknown
local defenderName = "Defenders"
local invaderName = "Invaders"
local isContested = false
local flashTimer = 0

function initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
        checkZone()
    else
        buildUI()
        invokeServerFunction("requestZoneData")
    end
end

function onSectorEntered()
    checkZone()
end

function checkZone()
    local sector = Sector()
    if not sector then return end
    local x, y = sector:getCoordinates()
    
    local CosmicVaultTerritory = include("cosmicvaultterritory")
    local zones = CosmicVaultTerritory.getContestedZones()
    local zone = zones[x .. "_" .. y]
    
    if zone then
        local def = Faction(zone.defender)
        local inv = Faction(zone.invader)
        local dName = def and def.name or "Defenders"
        local iName = inv and inv.name or "Invaders"
        
        invokeClientFunction(Player(), "receiveZoneData", true, zone.endTime, Server().unpausedRuntime, dName, iName, zone.startTime)
        return
    end
    invokeClientFunction(Player(), "receiveZoneData", false)
end
callable(nil, "checkZone")

function requestZoneData()
    checkZone()
end
callable(nil, "requestZoneData")

function receiveZoneData(contested, et, now, dName, iName, st)
    isContested = contested
    if contested then
        local remaining = et - now
        endTime = Client().unpausedRuntime + remaining
        defenderName = dName
        invaderName = iName
        
        -- Exact calculation based on recorded start time
        if st and et > st then
            totalTime = et - st
        else
            totalTime = 60 * 60 -- Fallback if st is missing
        end
        
        if uiContainer then uiContainer:show() end
    else
        if flashTimer <= 0 then
            if uiContainer then uiContainer:hide() end
        end
    end
end

function triggerSiegeSuccess()
    if onServer() then
        invokeClientFunction(Player(), "triggerSiegeSuccess")
        return
    end
    
    isContested = true
    flashTimer = 5.0
    
    if uiContainer then uiContainer:show() end
    local width = 600
    if blueRect then blueRect.rect = Rect(0, 0, 0, 40) end
    if redRect then redRect.rect = Rect(0, 0, width, 40) end
    if factionLabel then factionLabel.caption = "INVASION SUCCESSFUL - BORDER FLIPPED" end
    if timeLabel then timeLabel.caption = "Sector Lost" end
end
callable(nil, "triggerSiegeSuccess")

function triggerDefenseSuccess()
    if onServer() then
        invokeClientFunction(Player(), "triggerDefenseSuccess")
        return
    end
    
    isContested = true
    flashTimer = 5.0
    
    if uiContainer then uiContainer:show() end
    local width = 600
    if blueRect then blueRect.rect = Rect(0, 0, width, 40) end
    if redRect then redRect.rect = Rect(width, 0, width, 40) end
    if factionLabel then factionLabel.caption = "DEFENSE SUCCESSFUL - INVADERS REPELLED" end
    if timeLabel then timeLabel.caption = "Sector Secured" end
end
callable(nil, "triggerDefenseSuccess")

function buildUI()
    local res = getResolution()
    local width = 600
    local height = 40
    local x = (res.x / 2) - (width / 2)
    local y = 95
    
    uiContainer = Hud():createContainer(Rect(x, y, x + width, y + height))
    
    uiContainer:createRect(Rect(0, 0, width, height), ColorRGB(0.1, 0.1, 0.1))
    
    blueRect = uiContainer:createRect(Rect(0, 0, width / 2, height), ColorRGB(0.1, 0.4, 0.9))
    redRect = uiContainer:createRect(Rect(width / 2, 0, width, height), ColorRGB(0.9, 0.1, 0.1))
    
    factionLabel = uiContainer:createLabel(vec2(width / 2, 5), "Defenders vs Invaders", 14)
    factionLabel.centered = true
    factionLabel.color = ColorRGB(1, 1, 1)
    
    timeLabel = uiContainer:createLabel(vec2(width / 2, 20), "Time Remaining: --:--", 12)
    timeLabel.centered = true
    timeLabel.color = ColorRGB(1, 1, 1)
    
    uiContainer:hide()
end

function onResolutionChanged(res)
    if not uiContainer then return end
    local width = 600
    local height = 40
    local x = (res.x / 2) - (width / 2)
    local y = 95
    uiContainer.rect = Rect(x, y, x + width, y + height)
end

function getUpdateInterval()
    return 1.0
end

function updateClient(timeStep)
    if flashTimer > 0 then
        flashTimer = flashTimer - timeStep
        if flashTimer <= 0 then
            isContested = false
            if uiContainer then uiContainer:hide() end
        end
        return
    end

    if not isContested or not uiContainer then return end
    
    local remaining = endTime - Client().unpausedRuntime
    if remaining < 0 then remaining = 0 end
    
    local invaderPercent = (totalTime - remaining) / totalTime
    if invaderPercent > 1 then invaderPercent = 1 end
    if invaderPercent < 0 then invaderPercent = 0 end
    
    local width = 600
    local splitX = width * (1.0 - invaderPercent)
    
    blueRect.rect = Rect(0, 0, splitX, 40)
    redRect.rect = Rect(splitX, 0, width, 40)
    
    factionLabel.caption = string.format("%s vs %s", defenderName, invaderName)
    
    local m = math.floor(remaining / 60)
    local s = math.floor(remaining % 60)
    timeLabel.caption = string.format("Conflict resolves in: %02d:%02d", m, s)
end
