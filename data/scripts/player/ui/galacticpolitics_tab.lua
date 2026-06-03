package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("utility")

-- namespace GalacticPoliticsTab
GalacticPoliticsTab = {}
local self = GalacticPoliticsTab
local politicsList

if onClient() then
    function GalacticPoliticsTab.initialize()
        local playerWindow = PlayerWindow()

        -- Use a native diplomatic icon for the tab
        self.tab = playerWindow:createTab("Galactic Politics"%_t, "data/textures/icons/faction.png", "Galactic Politics"%_t)
        self.tab.onSelectedFunction = "clientFetchData"
        self.tab.onShowFunction = "clientFetchData"

        playerWindow:moveTabToTheRight(self.tab)
        GalacticPoliticsTab.buildWindow(self.tab)
        GalacticPoliticsTab.clientFetchData()
    end

    function GalacticPoliticsTab.buildWindow(container)
        local hsplit = UIHorizontalSplitter(Rect(container.size), 5, 5, 0.1)
        local margin = 10

        local refreshButton = container:createButton(
            Rect(hsplit.top.width - 150, 5, hsplit.top.width, hsplit.top.height - 25), "Refresh"%_t, "clientFetchData")
        refreshButton.icon = "data/textures/icons/refresh.png"
        refreshButton.tooltip = "Refresh Galactic Intelligence"%_t

        container:createLabel(Rect(margin, 5, margin + 300, hsplit.top.height - 5), "Active Galactic Conflicts"%_t, 20)

        politicsList = container:createListBoxEx(Rect(margin, hsplit.top.height, hsplit.bottom.width - 2 * margin, hsplit.bottom.height))
        politicsList.columns = 5
        politicsList.rowHeight = 35

        -- Calculate column widths cleanly to account for the scrollbar
        local width = container.size.x - 2 * margin - 20
        politicsList:setColumnWidth(0, width * 0.25)
        politicsList:setColumnWidth(1, width * 0.25)
        politicsList:setColumnWidth(2, width * 0.15)
        politicsList:setColumnWidth(3, width * 0.20)
        politicsList:setColumnWidth(4, width * 0.15)

        politicsList.headline = true
    end

    function GalacticPoliticsTab.clientFetchData()
        invokeServerFunction("serverFetchData")
    end

    function GalacticPoliticsTab.receiveData(data)
        if not politicsList then return end

        politicsList:clear()
        local white = ColorRGB(1, 1, 1)
        local gray = ColorRGB(0.8, 0.8, 0.8)

        politicsList:addRow() -- Headline
        politicsList:setEntryNoCallback(0, 0, "Faction A"%_t, true, false, white)
        politicsList:setEntryNoCallback(1, 0, "Faction B"%_t, true, false, white)
        politicsList:setEntryNoCallback(2, 0, "War Heat"%_t, true, false, white)
        politicsList:setEntryNoCallback(3, 0, "Status"%_t, true, false, white)
        politicsList:setEntryNoCallback(4, 0, "Relations"%_t, true, false, white)

        local function getRelationColor(rel)
            if rel >= 80000 then return ColorRGB(0.2, 1.0, 0.2)
            elseif rel >= 30000 then return ColorRGB(0.6, 1.0, 0.6)
            elseif rel <= -80000 then return ColorRGB(1.0, 0.2, 0.2)
            elseif rel <= -30000 then return ColorRGB(1.0, 0.6, 0.2)
            else return ColorRGB(0.8, 0.8, 0.8) end
        end

        local player = Player()
        for _, conflict in pairs(data) do
            politicsList:addRow()
            local row = politicsList.rows - 1

            local heatColor = gray
            if conflict.heat >= 80 then heatColor = ColorRGB(1.0, 0.2, 0.2)       -- Red
            elseif conflict.heat >= 40 then heatColor = ColorRGB(1.0, 0.6, 0.2)   -- Orange
            elseif conflict.heat > 0 then heatColor = ColorRGB(1.0, 1.0, 0.2)     -- Yellow
            else heatColor = ColorRGB(0.2, 1.0, 0.2) end                          -- Green

            local relA = player:getRelations(conflict.factionAIndex) or 0
            local relB = player:getRelations(conflict.factionBIndex) or 0

            local nameA = conflict.factionA
            if conflict.bountyA > 0 then nameA = nameA .. " [!]" end

            local nameB = conflict.factionB
            if conflict.bountyB > 0 then nameB = nameB .. " [!]" end

            politicsList:setEntryNoCallback(0, row, nameA, false, false, getRelationColor(relA))
            politicsList:setEntryNoCallback(1, row, nameB, false, false, getRelationColor(relB))
            politicsList:setEntryNoCallback(2, row, tostring(conflict.heat) .. "%", false, false, heatColor)
            politicsList:setEntryNoCallback(3, row, conflict.status%_t, false, false, heatColor)
            politicsList:setEntryNoCallback(4, row, tostring(conflict.relation), false, false, gray)

            local function concatLocalizedTraits(traits)
                local str = ""
                for i, t in ipairs(traits) do
                    str = str .. t%_t
                    if i < #traits then str = str .. ", " end
                end
                return str
            end

            local tooltip = "=== " .. conflict.factionA .. " ===\n"
            tooltip = tooltip .. "Traits: "%_t .. concatLocalizedTraits(conflict.traitsA) .. "\n"
            tooltip = tooltip .. "Your Relation: "%_t .. tostring(math.floor(relA)) .. "\n"
            if conflict.bountyA > 0 then tooltip = tooltip .. "Bounty on Enemy: ¢"%_t .. createMonetaryString(conflict.bountyA) .. "\n" end

            tooltip = tooltip .. "\n=== " .. conflict.factionB .. " ===\n"
            tooltip = tooltip .. "Traits: "%_t .. concatLocalizedTraits(conflict.traitsB) .. "\n"
            tooltip = tooltip .. "Your Relation: "%_t .. tostring(math.floor(relB)) .. "\n"
            if conflict.bountyB > 0 then tooltip = tooltip .. "Bounty on Enemy: ¢"%_t .. createMonetaryString(conflict.bountyB) .. "\n" end

            politicsList:setTooltip(row, tooltip)
        end
    end
end

function GalacticPoliticsTab.serverFetchData()
    if not onServer() then return end
    local player = Player(callingPlayer)
    if not player then return end

    local server = Server()
    local factionsStr = server:getValue("factions")
    local factionIndices = {}

    if type(factionsStr) == "string" and factionsStr ~= "" then
        for id in string.gmatch(factionsStr, "([^,]+)") do table.insert(factionIndices, tonumber(id)) end
    end

    local conflicts, uniquePairs = {}, {}
    local cw_success = pcall(include, "cosmicwarbridge")
    local now = server.unpausedRuntime or 0

    local function getFactionTraits(faction)
        local traits = {}
        if faction:getTrait("aggressive") then table.insert(traits, "Aggressive"%_T) end
        if faction:getTrait("peaceful") then table.insert(traits, "Peaceful"%_T) end
        if faction:getTrait("wealthy") then table.insert(traits, "Wealthy"%_T) end
        if faction:getTrait("poor") then table.insert(traits, "Poor"%_T) end
        if #traits == 0 then return {"Unknown"%_T} end
        return traits
    end

    for _, idx in pairs(factionIndices) do
        local f = Faction(idx)
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local enemyIdx = f:getValue("enemy_faction") or 0
            if enemyIdx > 0 then
                local e = Faction(enemyIdx)
                if e then
                    local left, right = math.min(f.index, e.index), math.max(f.index, e.index)
                    local key = tostring(left) .. ":" .. tostring(right)

                    if not uniquePairs[key] then
                        uniquePairs[key] = true
                        local heat = 0
                        if cw_success and CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
                            heat = CosmicWarBridge.getFactionWarHeat(f.index) or 0
                        end

                        local rel = f:getRelations(e.index) or 0
                        local status = "Hostile"%_T
                        if rel <= -80000 then status = "Total War"%_T
                        elseif rel <= -45000 then status = "Active Conflict"%_T
                        elseif rel < 0 then status = "Cold War"%_T
                        else status = "Ceasefire"%_T end

                        local bountyA = 0
                        if f:getValue("cw_bounty_enemy") == e.index and (f:getValue("cw_bounty_expires") or 0) > now then
                            bountyA = f:getValue("cw_bounty_reward") or 0
                        end

                        local bountyB = 0
                        if e:getValue("cw_bounty_enemy") == f.index and (e:getValue("cw_bounty_expires") or 0) > now then
                            bountyB = e:getValue("cw_bounty_reward") or 0
                        end

                        table.insert(conflicts, {
                            factionA = f.name,
                            factionAIndex = f.index,
                            traitsA = getFactionTraits(f),
                            bountyA = bountyA,
                            factionB = e.name,
                            factionBIndex = e.index,
                            traitsB = getFactionTraits(e),
                            bountyB = bountyB,
                            heat = math.floor(heat * 100),
                            relation = rel,
                            status = status
                        })
                    end
                end
            end
        end
    end

    -- Sort with the hottest warzones right at the top!
    table.sort(conflicts, function(a, b) return a.heat > b.heat end)

    invokeClientFunction(player, "receiveData", conflicts)
end
callable(GalacticPoliticsTab, "serverFetchData")