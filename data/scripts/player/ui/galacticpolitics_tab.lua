package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("utility")

-- namespace GalacticPoliticsTab
GalacticPoliticsTab = {}
local self = GalacticPoliticsTab
local politicsList

if onClient() then
    -- Pre-allocate helper functions to prevent memory churn during UI refreshes
    local function getRelationColor(rel)
        if rel >= 80000 then return ColorRGB(0.2, 1.0, 0.2)
        elseif rel >= 30000 then return ColorRGB(0.6, 1.0, 0.6)
        elseif rel <= -80000 then return ColorRGB(1.0, 0.2, 0.2)
        elseif rel <= -30000 then return ColorRGB(1.0, 0.6, 0.2)
        else return ColorRGB(0.8, 0.8, 0.8) end
    end

    local function getRelationDescription(rel)
        if rel >= 80000 then return "Allied"%_t
        elseif rel >= 30000 then return "Friendly"%_t
        elseif rel >= 10000 then return "Good"%_t
        elseif rel >= -10000 then return "Neutral"%_t
        elseif rel >= -45000 then return "Confrontational"%_t
        elseif rel >= -80000 then return "Aggressive"%_t
        else return "All-Out War"%_t end
    end

    local function concatLocalizedTraits(traits)
        local str = ""
        for i, t in ipairs(traits) do
            str = str .. t%_t
            if i < #traits then str = str .. ", " end
        end
        return str
    end

    function GalacticPoliticsTab.initialize()
        local playerWindow = PlayerWindow()

        -- Use a native diplomatic icon for the tab
        self.tab = playerWindow:createTab("Galactic Politics"%_t, "data/textures/icons/cw_galacticpolitics.png",
        "Galactic Politics"%_t)
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
        refreshButton.icon = "data/textures/icons/cw_refresh.png"
        refreshButton.tooltip = "Refresh Galactic Intelligence"%_t

        self.numericCheck = container:createCheckBox(Rect(hsplit.top.width - 320, 5, hsplit.top.width - 160, hsplit.top.height - 25), "Numeric Relations"%_t, "onNumericCheckChanged")
        self.numericCheck.checked = false
        self.numericCheck.tooltip = "Toggle between numeric and descriptive relation values."%_t

        self.filterComboBox = container:createValueComboBox(Rect(hsplit.top.width - 530, 6, hsplit.top.width - 330, hsplit.top.height - 28), "onFilterChanged")
        self.filterComboBox:addEntry("All", "All"%_t)
        self.filterComboBox:addEntry("Active Conflicts", "Active Conflicts"%_t)
        self.filterComboBox:addEntry("Ceasefires Only", "Ceasefires Only"%_t)
        self.filterComboBox:addEntry("Active Bounties", "Active Bounties"%_t)
        self.filterComboBox.tooltip = "Filter Conflicts"%_t

        container:createLabel(Rect(margin, 5, margin + 300, hsplit.top.height - 25), "Active Galactic Conflicts"%_t, 20)

        -- Reserve 160px at the bottom of the UI for the Legend/Summary section
        local listRect = Rect(margin, hsplit.bottom.lower.y, container.size.x - margin, container.size.y - 160)
        politicsList = container:createListBoxEx(listRect)
        politicsList.columns = 5
        politicsList.rowHeight = 35

        -- Calculate column widths cleanly to account for the scrollbar
        local width = listRect.width - 20
        politicsList:setColumnWidth(0, width * 0.25)
        politicsList:setColumnWidth(1, width * 0.25)
        politicsList:setColumnWidth(2, width * 0.15)
        politicsList:setColumnWidth(3, width * 0.20)
        politicsList:setColumnWidth(4, width * 0.15)

        self.selectedSorting = 3
        self.sortingType = -1
        self.sortingButtons = {}
        local colWidths = { width * 0.25, width * 0.25, width * 0.15, width * 0.20, width * 0.15 }
        local sortingLabels = {"Faction A"%_t, "Faction B"%_t, "War Heat"%_t, "Status"%_t, "Relations"%_t}
        local currentX = margin
        for i = 1, 5 do
            local btnRect = Rect(currentX, listRect.lower.y - 25, currentX + colWidths[i] - 2, listRect.lower.y)
            local btn = container:createButton(btnRect, sortingLabels[i], "onSort" .. i)
            btn.hasFrame = false
            btn.textSize = 14
            btn.tooltip = "Sort by "%_t .. sortingLabels[i]
            table.insert(self.sortingButtons, btn)
            currentX = currentX + colWidths[i]
        end
        self.updateSortingIcons()

        -- Bottom Information Section (Legend & Summary)
        local infoRect = Rect(margin, container.size.y - 150, container.size.x - margin, container.size.y - 10)
        local infoFrame = container:createFrame(infoRect)
        local infoSplit = UIVerticalSplitter(infoRect, 10, 10, 0.45)

        local legendStr = "Legend:"%_t .. "\n" ..
            " [!] " .. "Active War Bounty (Check Tooltip)"%_t .. "\n" ..
            " " .. "War Heat:"%_t .. " (" .. "Red"%_t .. ") " .. "Critical"%_t .. " | (" .. "Orange"%_t .. ") " .. "High"%_t .. " | (" .. "Yellow"%_t .. ") " .. "Rising"%_t .. " | (" .. "Green"%_t .. ") " .. "Zero"%_t .. "\n" ..
            " " .. "Relations:"%_t .. " (" .. "Green"%_t .. ") " .. "Friendly"%_t .. " | (" .. "Gray"%_t .. ") " .. "Neutral"%_t .. " | (" .. "Red"%_t .. ") " .. "Hostile"%_t
        local legendRectInset = Rect(infoSplit.left.lower + vec2(10, 10), infoSplit.left.upper - vec2(10, 10))
        local legendLabel = container:createLabel(legendRectInset, legendStr, 15)
        legendLabel.wordBreak = true
        legendLabel:setTopLeftAligned()

        local summaryStr = "Cosmic War Simulation:"%_t .. "\n" ..
            "Conflict escalates dynamically based on 'War Heat', triggering massive fleet clashes, bounties, and economic sanctions."%_t .. "\n\n" ..
            "Note: While politics and skirmishes are highly dynamic, faction station ownership and map borders remain static in Avorion."%_t
        local summaryRectInset = Rect(infoSplit.right.lower + vec2(10, 10), infoSplit.right.upper - vec2(10, 10))
        local summaryLabel = container:createLabel(summaryRectInset, summaryStr, 15)
        summaryLabel.wordBreak = true
        summaryLabel:setTopLeftAligned()
    end

    function GalacticPoliticsTab.clientFetchData()
        invokeServerFunction("serverFetchData")
    end

    function GalacticPoliticsTab.onNumericCheckChanged()
        if self.lastData then
            GalacticPoliticsTab.receiveData(self.lastData)
        else
            GalacticPoliticsTab.clientFetchData()
        end
    end

    function GalacticPoliticsTab.onFilterChanged()
        self.applyFiltersAndSort()
    end

    function GalacticPoliticsTab.onSort1() self.updateSorting(1) end
    function GalacticPoliticsTab.onSort2() self.updateSorting(2) end
    function GalacticPoliticsTab.onSort3() self.updateSorting(3) end
    function GalacticPoliticsTab.onSort4() self.updateSorting(4) end
    function GalacticPoliticsTab.onSort5() self.updateSorting(5) end

    function GalacticPoliticsTab.updateSorting(newSorting)
        if self.selectedSorting == newSorting then
            self.sortingType = self.sortingType * -1
        else
            self.selectedSorting = newSorting
            self.sortingType = 1
        end
        self.updateSortingIcons()
        self.applyFiltersAndSort()
    end

    function GalacticPoliticsTab.updateSortingIcons()
        local sortingLabels = {"Faction A"%_t, "Faction B"%_t, "War Heat"%_t, "Status"%_t, "Relations"%_t}
        for ndx, button in ipairs(self.sortingButtons) do
            local label = sortingLabels[ndx]
            if ndx == self.selectedSorting then
                if self.sortingType < 0 then
                    button.caption = label .. " ▼"
                else
                    button.caption = label .. " ▲"
                end
            else
                button.caption = label
            end
            button.icon = ""
        end
    end

    function GalacticPoliticsTab.applyFiltersAndSort()
        if not self.lastData then return end

        local filter = self.filterComboBox.selectedValue
        self.displayedConflicts = {}

        for _, conflict in ipairs(self.lastData) do
            local match = true
            if filter == "Active Conflicts"%_t and conflict.heat == 0 then match = false end
            if filter == "Ceasefires Only"%_t and conflict.heat > 0 then match = false end
            if filter == "Active Bounties"%_t and conflict.bountyA == 0 and conflict.bountyB == 0 then match = false end

            if match then
                table.insert(self.displayedConflicts, conflict)
            end
        end

        table.sort(self.displayedConflicts, function(a, b)
            local valA, valB
            if self.selectedSorting == 1 then valA, valB = a.factionA, b.factionA
            elseif self.selectedSorting == 2 then valA, valB = a.factionB, b.factionB
            elseif self.selectedSorting == 3 then valA, valB = a.heat, b.heat
            elseif self.selectedSorting == 4 then valA, valB = a.status, b.status
            elseif self.selectedSorting == 5 then valA, valB = a.relation, b.relation
            end

            if valA == valB then return false end
            if self.sortingType == 1 then
                return valA < valB
            else
                return valA > valB
            end
        end)

        self.populateUI()
    end

    function GalacticPoliticsTab.receiveData(data)
        if not politicsList then return end
        if type(data) ~= "table" then return end
        self.lastData = data
        self.applyFiltersAndSort()
    end

    function GalacticPoliticsTab.populateUI()
        politicsList:clear()
        local white = ColorRGB(1, 1, 1)
        local gray = ColorRGB(0.8, 0.8, 0.8)

        local player = Player()
        for index, conflict in ipairs(self.displayedConflicts) do
            politicsList:addRow(tostring(index))
            local row = politicsList.rows - 1

            local heatColor = gray
            if conflict.heat >= 80 then heatColor = ColorRGB(1.0, 0.2, 0.2)       -- Red
            elseif conflict.heat >= 40 then heatColor = ColorRGB(1.0, 0.6, 0.2)   -- Orange
            elseif conflict.heat > 0 then heatColor = ColorRGB(1.0, 1.0, 0.2)     -- Yellow
            else heatColor = ColorRGB(0.2, 1.0, 0.2) end                          -- Green

            local relA = player:getRelations(conflict.factionAIndex) or 0
            local relB = player:getRelations(conflict.factionBIndex) or 0

            local nameA = conflict.factionA or "Unknown Faction"%_t
            if conflict.bountyA > 0 then nameA = nameA .. " [!]" end

            local nameB = conflict.factionB or "Unknown Faction"%_t
            if conflict.bountyB > 0 then nameB = nameB .. " [!]" end

            local relationText = tostring(conflict.relation)
            if self.numericCheck and not self.numericCheck.checked then
                relationText = getRelationDescription(conflict.relation)
            end

            -- Cosmic War: Populates the row entries. Colors dynamically indicate player relations and overall war heat.
            politicsList:setEntryNoCallback(0, row, nameA, false, false, getRelationColor(relA))
            politicsList:setEntryNoCallback(1, row, nameB, false, false, getRelationColor(relB))
            politicsList:setEntryNoCallback(2, row, tostring(conflict.heat) .. "%", false, false, heatColor)
            politicsList:setEntryNoCallback(3, row, conflict.status%_t, false, false, heatColor)
            politicsList:setEntryNoCallback(4, row, relationText, false, false, gray)

            local tooltip = "=== " .. nameA .. " ===\n"
            tooltip = tooltip .. "Index: "%_t .. conflict.factionAIndex .. "\n"
            tooltip = tooltip .. "Traits: "%_t .. concatLocalizedTraits(conflict.traitsA) .. "\n"
            tooltip = tooltip .. "Your Relation: "%_t .. getRelationDescription(relA) .. " (" .. math.floor(relA) .. ")\n"
            if conflict.bountyA > 0 then tooltip = tooltip .. "Bounty on Enemy: ¢"%_t .. createMonetaryString(conflict.bountyA) .. "\n" end

            tooltip = tooltip .. "\n=== " .. nameB .. " ===\n"
            tooltip = tooltip .. "Index: "%_t .. conflict.factionBIndex .. "\n"
            tooltip = tooltip .. "Traits: "%_t .. concatLocalizedTraits(conflict.traitsB) .. "\n"
            tooltip = tooltip .. "Your Relation: "%_t .. getRelationDescription(relB) .. " (" .. math.floor(relB) .. ")\n"
            if conflict.bountyB > 0 then tooltip = tooltip .. "Bounty on Enemy: ¢"%_t .. createMonetaryString(conflict.bountyB) .. "\n" end

            politicsList:setTooltip(row, tooltip)
        end
    end
end

-- Cosmic War: Computes AI Faction Traits to display in the UI Tooltip. Consider surfacing cw_war_bias and cw_diplomatic_polarity here in the future.
local function getFactionTraitsSafe(faction)
    local traits = {}
    if faction.isPlayer then
        table.insert(traits, "Player Faction")
        return traits
    elseif faction.isAlliance then
        table.insert(traits, "Player Alliance")
        return traits
    end

    -- Send pure strings across the network boundary, the client will apply the local %_t translation!
    if faction:getTrait("aggressive") then table.insert(traits, "Aggressive") end
    if faction:getTrait("peaceful") then table.insert(traits, "Peaceful") end
    if faction:getTrait("wealthy") then table.insert(traits, "Wealthy") end
    if faction:getTrait("poor") then table.insert(traits, "Poor") end
    if #traits == 0 then return {"Unknown"} end
    return traits
end

function GalacticPoliticsTab.serverFetchData()
    if not onServer() then return end
    local player = Player(callingPlayer)
    if not player then return end

    local server = Server()
    -- Cosmic War: Fetches all tracked factions via the Cosmic Vault shared indexer cache.
    local factionsStr = server:getValue("factions")
    local factionIndices = {}

    if type(factionsStr) == "string" and factionsStr ~= "" then
        for id in string.gmatch(factionsStr, "([^,]+)") do table.insert(factionIndices, tonumber(id)) end
    end

    local conflicts, uniquePairs = {}, {}
    local cw_success = true; include("cosmicwarbridge")
    local now = server.unpausedRuntime or 0

    for _, idx in pairs(factionIndices) do
        local f = Faction(idx)
        if f and f.isAIFaction and f:getValue("cw_enabled") then
            local enemyIdx = f:getValue("enemy_faction") or 0
            if enemyIdx > 0 then
                local e = Faction(enemyIdx)
                -- Bulletproof: Ensure the enemy faction actually exists.
                -- Player and Alliance conflicts are safely swept up if the AI explicitly targeted them!
                if e and (e.isAIFaction or e.isAlliance or e.isPlayer) then
                    local left, right = math.min(f.index, e.index), math.max(f.index, e.index)
                    local key = tostring(left) .. ":" .. tostring(right)

                    if not uniquePairs[key] then
                        uniquePairs[key] = true
                        local heat = 0
                        if cw_success and CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
                            heat = CosmicWarBridge.getFactionWarHeat(f.index) or 0
                        end

                    -- Cosmic War: Translates raw relational values into descriptive diplomatic states.
                        local rel = f:getRelations(e.index) or 0
                        local status = "Hostile"
                        if rel <= -80000 then status = "Total War"
                        elseif rel <= -45000 then status = "Active Conflict"
                        elseif rel < 0 then status = "Cold War"
                        else status = "Ceasefire" end

                    -- Cosmic War: Calculates current bounty status based on the expiration timer and target.
                        local bountyA = 0
                        if f:getValue("cw_bounty_enemy") == e.index and (f:getValue("cw_bounty_expires") or 0) > now then
                            bountyA = f:getValue("cw_bounty_reward") or 0
                        end

                        local bountyB = 0
                        if e:getValue("cw_bounty_enemy") == f.index and (e:getValue("cw_bounty_expires") or 0) > now then
                            bountyB = e:getValue("cw_bounty_reward") or 0
                        end

                        local fName = f.name or ("Faction " .. tostring(f.index))
                        local eName = e.name or ("Faction " .. tostring(e.index))
                        
                        table.insert(conflicts, {
                            factionA = string.gsub(fName, "%s*/%*.-%*/%s*", ""),
                            factionAIndex = f.index,
                            traitsA = getFactionTraitsSafe(f),
                            bountyA = bountyA,
                            factionB = string.gsub(eName, "%s*/%*.-%*/%s*", ""),
                            factionBIndex = e.index,
                            traitsB = getFactionTraitsSafe(e),
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


    invokeClientFunction(player, "receiveData", conflicts)
end
callable(GalacticPoliticsTab, "serverFetchData")