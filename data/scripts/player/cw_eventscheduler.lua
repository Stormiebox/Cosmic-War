package.path = package.path .. ";data/scripts/lib/?.lua"
include("randomext")

-- namespace CW_EventScheduler
CW_EventScheduler = {}

local events = {
    { min = 120, max = 180, script = "events/cw_fleetclash.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "events/cw_refugeeconvoy.lua", timer = 0, schedule = 0 },
    { min = 180, max = 240, script = "events/cw_strandedflagship.lua", timer = 0, schedule = 0 },
    { min = 90,  max = 150, script = "events/cw_armsdeal.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "events/cw_wreckagefield.lua", timer = 0, schedule = 0 },
    { min = 60,  max = 120, script = "events/cw_headhunters.lua", timer = 0, schedule = 0 },
    { min = 100, max = 160, script = "events/cw_blockade.lua", timer = 0, schedule = 0 },
    { min = 120, max = 180, script = "events/cw_diplomaticsabotage.lua", timer = 0, schedule = 0 }
}

function CW_EventScheduler.getUpdateInterval()
    return 60 -- Check every minute
end

function CW_EventScheduler.initialize()
    if onClient() then return end

    Player():registerCallback("onSectorEntered", "onSectorEntered")

    -- Initialize timers with a random offset so they don't all trigger at once
    local now = Player().playtime
    for _, event in pairs(events) do
        if event.schedule == 0 then
            event.schedule = random():getInt(event.min, event.max) * 60
            event.timer = now + random():getInt(0, event.schedule)
        end
    end
end

function CW_EventScheduler.onSectorEntered(playerIndex, x, y)
    local player = Player(playerIndex)
    if not player then return end

    -- Distress Call FOB Spawns
    local fobStr = player:getValue("cw_distress_fob_list")
    if fobStr and fobStr ~= "" then
        local entries = {}
        for coord in string.gmatch(fobStr, "([^;]+)") do
            table.insert(entries, coord)
        end

        local isFob = false
        local newEntries = {}
        for _, coord in pairs(entries) do
            if coord == x .. "," .. y then
                isFob = true
            else
                table.insert(newEntries, coord)
            end
        end

        if isFob then
            player:setValue("cw_distress_fob_list", table.concat(newEntries, ";") .. (#newEntries > 0 and ";" or ""))
            
            -- Spawn FOB
            include("galaxy")
            local SectorGenerator = include("SectorGenerator")
            local generator = SectorGenerator(x, y)
            local ShipGenerator = include("shipgenerator")
            local faction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))
            
            for i = 1, 3 do
                local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
                ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
            end
            
            local station = ShipGenerator.createShipyard(faction, generator:getPositionInSector())
            if station then
                station.title = "Forward Operating Base"%_T
                station:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
            end
            
            -- Add hazard (Thunderstorm)
            Sector():addScriptOnce("dlc/rift/sector/riftbackgroundthunder.lua")
            
            player:sendChatMessage("System", ChatMessageType.Warning, "Warning! Hostiles have established a Forward Operating Base in this sector!"%_T)
        end
    end

    -- Bounty Hunter Ambush
    local pendingAmbushIndex = player:getValue("cw_pending_ambush")
    if pendingAmbushIndex and type(pendingAmbushIndex) == "number" then
        player:setValue("cw_pending_ambush", nil)
        
        local bestEnemy = Faction(pendingAmbushIndex)
        if bestEnemy then
            local random = Random(Seed(Server().unpausedRuntime))
            local dir = vec3(random:getFloat(-1, 1), 0, random:getFloat(-1, 1))
            if length(dir) == 0 then dir = vec3(1, 0, 0) end
            dir = normalize(dir)

            local distance = 3000
            local center = dir * distance

            local ShipGenerator = include("shipgenerator")
            for i = 1, random:getInt(2, 4) do
                local pos = center + vec3(random:getFloat(-200, 200), random:getFloat(-200, 200), random:getFloat(-200, 200))
                local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)
                local ship = ShipGenerator.createMilitaryShip(bestEnemy, matrix) -- Elite headhunter, scaled below

                -- Custom Cosmic War Scaling for Elite Bounty Hunters
                ship.damageMultiplier = (ship.damageMultiplier or 1) * 2.5
                if ship:hasComponent(ComponentType.Durability) then
                    Durability(ship.index).maxDurabilityFactor = Durability(ship.index).maxDurabilityFactor * 2.5
                    ship.durability = ship.maxDurability
                end

                -- Soft Bridge to Cosmic Starfall (Equip heavy subsystems if available)
                local success, sfAPI = pcall(include, "starfall_subsystems")
                if success and sfAPI and sfAPI.equipEliteSubsystems then
                    sfAPI.equipEliteSubsystems(ship)
                end

                ship.title = "Elite Headhunter"
                ship:addScriptOnce("ai/patrol.lua")
                ship:addScriptOnce("data/scripts/entity/enemy.lua")
            end

            player:sendChatMessage("Alert", ChatMessageType.Warning, "Warning: Incoming elite headhunter fleet from " .. bestEnemy.name .. "!"%_T)
        end
    end
end

function CW_EventScheduler.secure()
    return {events = events}
end

function CW_EventScheduler.restore(data)
    if data.events then
        for i, savedEvent in pairs(data.events) do
            if events[i] and events[i].script == savedEvent.script then
                events[i].timer = savedEvent.timer
                events[i].schedule = savedEvent.schedule
            else
                for _, e in pairs(events) do
                    if e.script == savedEvent.script then
                        e.timer = savedEvent.timer
                        e.schedule = savedEvent.schedule
                        break
                    end
                end
            end
        end
    end
end

function CW_EventScheduler.updateServer(timeStep)
    local now = Player().playtime
    for _, event in pairs(events) do
        if now >= event.timer then
            -- Reset timer and roll a new schedule
            event.schedule = random():getInt(event.min, event.max) * 60
            event.timer = now + event.schedule

            -- Spawn event
            local sector = Sector()
            if sector then
                sector:addScriptOnce(event.script)
            end
        end
    end
end



