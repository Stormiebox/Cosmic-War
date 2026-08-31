package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("utility")

-- namespace GalacticPoliticsTab
GalacticPoliticsTab = {}
local self = GalacticPoliticsTab
local politicsList

local BOUNTY_TRACKER_SCRIPT = "data/scripts/player/background/cw_bounty_tracker.lua"

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

    local function formatTimeRemaining(seconds)
        seconds = math.max(0, math.floor(seconds or 0))
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%dm %02ds", mins, secs)
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
        -- Reserve a taller top strip (2 rows: title/license status, then filter controls)
        -- so controls never have to fight the title for the same horizontal space.
        local hsplit = UIHorizontalSplitter(Rect(container.size), 5, 5, 0.14)
        local margin = 10
        local topWidth = hsplit.top.width
        local topHeight = hsplit.top.height

        local row1Bottom = topHeight * 0.5
        local row2Top = topHeight * 0.5 + 4
        local row2Bottom = topHeight - 4

        -- Row 1: title (left) + this player's own Bounty License status (right half)
        container:createLabel(Rect(margin, 2, margin + 320, row1Bottom), "Active Galactic Conflicts"%_t, 20)

        self.licenseLabel = container:createLabel(Rect(topWidth * 0.42, 2, topWidth - margin, row1Bottom), "", 15)
        self.licenseLabel:setTopLeftAligned()

        -- Row 2: filter, numeric toggle and refresh, laid out left-to-right with fixed
        -- spacing instead of width-relative right offsets, so nothing overlaps regardless
        -- of the player window's actual size.
        self.filterComboBox = container:createValueComboBox(Rect(margin, row2Top, margin + 230, row2Bottom), "onFilterChanged")
        self.filterComboBox:addEntry("All", "All"%_t)
        self.filterComboBox:addEntry("Active Conflicts", "Active Conflicts"%_t)
        self.filterComboBox:addEntry("Ceasefires Only", "Ceasefires Only"%_t)
        self.filterComboBox:addEntry("Active Bounties", "Active Bounties"%_t)
        self.filterComboBox.tooltip = "Filter Conflicts"%_t

        self.numericCheck = container:createCheckBox(Rect(margin + 245, row2Top, margin + 465, row2Bottom), "Numeric Relations"%_t, "onNumericCheckChanged")
        self.numericCheck.checked = false
        self.numericCheck.tooltip = "Toggle between numeric and descriptive relation values."%_t

        local refreshButton = container:createButton(Rect(margin + 480, row2Top, margin + 620, row2Bottom), "Refresh"%_t, "clientFetchData")
        refreshButton.icon = "data/textures/icons/cw_refresh.png"
        refreshButton.tooltip = "Refresh Galactic Intelligence"%_t

        -- Reserve 160px at the bottom of the UI for the Legend/Summary section
        local listRect = Rect(margin, hsplit.bottom.lower.y, container.size.x - margin, container.size.y - 160)
        politicsList = container:createListBoxEx(listRect)
        politicsList.columns = 7
        politicsList.rowHeight = 35

        -- Calculate column widths cleanly to account for the scrollbar
        local width = listRect.width - 20
        local colFractions = { 0.18, 0.18, 0.12, 0.12, 0.12, 0.14, 0.14 }
        for i = 0, 6 do
            politicsList:setColumnWidth(i, width * colFractions[i + 1])
        end

        self.selectedSorting = 4
        self.sortingType = -1
        self.sortingButtons = {}
        local sortingLabels = self.getSortingLabels()
        local currentX = margin
        for i = 1, 7 do
            local colWidth = width * colFractions[i]
            local btnRect = Rect(currentX, listRect.lower.y - 25, currentX + colWidth - 2, listRect.lower.y)
            local btn = container:createButton(btnRect, sortingLabels[i], "onSort" .. i)
            btn.hasFrame = false
            btn.textSize = 14
            btn.tooltip = "Sort by "%_t .. sortingLabels[i]
            table.insert(self.sortingButtons, btn)
            currentX = currentX + colWidth
        end
        self.updateSortingIcons()

        -- Bottom Information Section (Legend & Summary)
        local infoRect = Rect(margin, container.size.y - 150, container.size.x - margin, container.size.y - 10)
        local infoFrame = container:createFrame(infoRect)
        local infoSplit = UIVerticalSplitter(infoRect, 10, 10, 0.45)

        local legendStr = "Legend:"%_t .. "\n" ..
            " " .. "Bounty column:"%_t .. " " .. "Shows the higher of either side's active War Bounty reward. Hover a row for full details."%_t .. "\n" ..
            " " .. "War Heat:"%_t .. " (" .. "Red"%_t .. ") " .. "Critical"%_t .. " | (" .. "Orange"%_t .. ") " .. "High"%_t .. " | (" .. "Yellow"%_t .. ") " .. "Rising"%_t .. " | (" .. "Green"%_t .. ") " .. "Zero"%_t .. "\n" ..
            " " .. "Relations:"%_t .. " (" .. "Green"%_t .. ") " .. "Friendly"%_t .. " | (" .. "Gray"%_t .. ") " .. "Neutral"%_t .. " | (" .. "Red"%_t .. ") " .. "Hostile"%_t .. "\n" ..
            " " .. "Famine:"%_t .. " (" .. "Green"%_t .. ") " .. "Normal"%_t .. " | (" .. "Yellow"%_t .. ") " .. "Struggling"%_t .. " | (" .. "Red"%_t .. ") " .. "Critical"%_t
        local legendRectInset = Rect(infoSplit.left.lower + vec2(10, 10), infoSplit.left.upper - vec2(10, 10))
        local legendLabel = container:createLabel(legendRectInset, legendStr, 15)
        legendLabel.wordBreak = true
        legendLabel:setTopLeftAligned()

        local summaryStr = "Cosmic War Simulation:"%_t .. "\n" ..
            "Conflict escalates dynamically based on 'War Heat', triggering massive fleet clashes, bounties, and economic sanctions."%_t .. "\n\n" ..
            "Note: While politics and skirmishes are highly dynamic, faction station ownership and map borders remain static in Avorion."%_t .. "\n\n" ..
            "Tip: Use /cosmicwarbounties in chat for a quick text summary of your License and the bounty board."%_t
        local summaryRectInset = Rect(infoSplit.right.lower + vec2(10, 10), infoSplit.right.upper - vec2(10, 10))
        local summaryLabel = container:createLabel(summaryRectInset, summaryStr, 15)
        summaryLabel.wordBreak = true
        summaryLabel:setTopLeftAligned()
    end

    function GalacticPoliticsTab.getSortingLabels()
        return {"Faction A"%_t, "Faction B"%_t, "Bounty"%_t, "War Heat"%_t, "Famine"%_t, "Status"%_t, "Relations"%_t}
    end

    function GalacticPoliticsTab.clientFetchData()
        invokeServerFunction("serverFetchData")
    end

    function GalacticPoliticsTab.onNumericCheckChanged()
        if self.lastData then
            -- self.lastData is already the unwrapped conflicts array (see receiveData);
            -- just re-render from cache instead of re-fetching from the server.
            self.applyFiltersAndSort()
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
    function GalacticPoliticsTab.onSort6() self.updateSorting(6) end
    function GalacticPoliticsTab.onSort7() self.updateSorting(7) end

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
        local sortingLabels = self.getSortingLabels()
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

    function GalacticPoliticsTab.updateLicenseStatus()
        if not self.licenseLabel then return end

        local license = self.myLicense
        if license then
            self.licenseLabel.caption = "Your License: "%_t .. license.giverName .. " vs "%_t .. license.targetName ..
                " -- " .. tostring(license.kills) .. "/" .. tostring(license.maxKills) .. " "%_t .. "kills"%_t ..
                ", " .. formatTimeRemaining(license.timeRemaining) .. " "%_t .. "remaining"%_t
            self.licenseLabel.color = ColorRGB(1.0, 0.85, 0.3)
        else
            self.licenseLabel.caption = "Your License: "%_t .. "None active"%_t
            self.licenseLabel.color = ColorRGB(0.6, 0.6, 0.6)
        end
    end

    function GalacticPoliticsTab.applyFiltersAndSort()
        if not self.lastData then return end

        local filter = self.filterComboBox.selectedValue
        self.displayedConflicts = {}

        for _, conflict in ipairs(self.lastData) do
            local match = true
            -- selectedValue returns the raw addEntry() value, not the localized caption, so compare untranslated.
            if filter == "Active Conflicts" and conflict.heat == 0 then match = false end
            if filter == "Ceasefires Only" and conflict.heat > 0 then match = false end
            if filter == "Active Bounties" and conflict.bountyA == 0 and conflict.bountyB == 0 then match = false end

            if match then
                table.insert(self.displayedConflicts, conflict)
            end
        end

        table.sort(self.displayedConflicts, function(a, b)
            local valA, valB
            if self.selectedSorting == 1 then valA, valB = a.factionA, b.factionA
            elseif self.selectedSorting == 2 then valA, valB = a.factionB, b.factionB
            elseif self.selectedSorting == 3 then valA, valB = math.max(a.bountyA, a.bountyB), math.max(b.bountyA, b.bountyB)
            elseif self.selectedSorting == 4 then valA, valB = a.heat, b.heat
            elseif self.selectedSorting == 5 then valA, valB = math.max(a.famineA, a.famineB), math.max(b.famineA, b.famineB)
            elseif self.selectedSorting == 6 then valA, valB = a.status, b.status
            elseif self.selectedSorting == 7 then valA, valB = a.relation, b.relation
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
        self.lastData = data.conflicts or {}
        self.myLicense = data.myLicense
        self.updateLicenseStatus()
        self.applyFiltersAndSort()
    end

    function GalacticPoliticsTab.populateUI()
        politicsList:clear()
        local white = ColorRGB(1, 1, 1)
        local gray = ColorRGB(0.8, 0.8, 0.8)
        local gold = ColorRGB(1.0, 0.85, 0.3)

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
            local nameB = conflict.factionB or "Unknown Faction"%_t

            local relationText = tostring(conflict.relation)
            if self.numericCheck and not self.numericCheck.checked then
                relationText = getRelationDescription(conflict.relation)
            end

            local maxFamine = math.max(conflict.famineA or 0, conflict.famineB or 0)
            local famineText = "Normal"%_t
            local famineColor = ColorRGB(0.2, 1.0, 0.2)
            if maxFamine >= 100 then
                famineText = "Critical"%_t
                famineColor = ColorRGB(1.0, 0.2, 0.2)
            elseif maxFamine >= 50 then
                famineText = "Struggling"%_t
                famineColor = ColorRGB(1.0, 1.0, 0.2)
            end

            local bountyMax = math.max(conflict.bountyA or 0, conflict.bountyB or 0)
            local bountyText = "-"
            local bountyColor = gray
            if bountyMax > 0 then
                bountyText = createMonetaryString(bountyMax)
                bountyColor = gold
            end

            -- Cosmic War: Populates the row entries. Colors dynamically indicate player relations and overall war heat.
            politicsList:setEntryNoCallback(0, row, nameA, false, false, getRelationColor(relA))
            politicsList:setEntryNoCallback(1, row, nameB, false, false, getRelationColor(relB))
            politicsList:setEntryNoCallback(2, row, bountyText, false, false, bountyColor)
            politicsList:setEntryNoCallback(3, row, tostring(conflict.heat) .. "%", false, false, heatColor)
            politicsList:setEntryNoCallback(4, row, famineText, false, false, famineColor)
            politicsList:setEntryNoCallback(5, row, conflict.status%_t, false, false, heatColor)
            politicsList:setEntryNoCallback(6, row, relationText, false, false, gray)

            local tooltip = "=== " .. nameA .. " ===\n"
            tooltip = tooltip .. "Index: "%_t .. conflict.factionAIndex .. "\n"
            tooltip = tooltip .. "Traits: "%_t .. concatLocalizedTraits(conflict.traitsA) .. "\n"
            tooltip = tooltip .. "Your Relation: "%_t .. getRelationDescription(relA) .. " (" .. math.floor(relA) .. ")\n"
            if (conflict.famineA or 0) > 0 then tooltip = tooltip .. "Famine Score: "%_t .. math.floor(conflict.famineA) .. "\n" end
            if conflict.bountyA > 0 then tooltip = tooltip .. "Bounty License (Per Kill): ¢"%_t .. createMonetaryString(conflict.bountyA) .. " (Max 15 Kills)\n" end

            tooltip = tooltip .. "\n=== " .. nameB .. " ===\n"
            tooltip = tooltip .. "Index: "%_t .. conflict.factionBIndex .. "\n"
            tooltip = tooltip .. "Traits: "%_t .. concatLocalizedTraits(conflict.traitsB) .. "\n"
            tooltip = tooltip .. "Your Relation: "%_t .. getRelationDescription(relB) .. " (" .. math.floor(relB) .. ")\n"
            if (conflict.famineB or 0) > 0 then tooltip = tooltip .. "Famine Score: "%_t .. math.floor(conflict.famineB) .. "\n" end
            if conflict.bountyB > 0 then tooltip = tooltip .. "Bounty License (Per Kill): ¢"%_t .. createMonetaryString(conflict.bountyB) .. " (Max 15 Kills)\n" end

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
    if faction:getTrait("aggressive") > 0.5 then table.insert(traits, "Aggressive") end
    if faction:getTrait("peaceful") > 0.5 then table.insert(traits, "Peaceful") end
    if faction:getTrait("wealthy") > 0.5 then table.insert(traits, "Wealthy") end
    if faction:getTrait("poor") > 0.5 then table.insert(traits, "Poor") end
    if #traits == 0 then return {"Unknown"} end
    return traits
end

-- Checks both the calling player's own faction and (if applicable) their alliance for an
-- active License, since cw_bountypayouts.lua attaches the tracker to whichever of the two
-- actually owns the killing blow (see CW_BountyPayouts.onDestroyed).
local function getMyLicense(player)
    if not player then return nil end

    local holders = { player }
    if player.allianceIndex and player.allianceIndex > 0 then
        local alliance = Alliance(player.allianceIndex)
        if alliance then table.insert(holders, alliance) end
    end

    for _, holder in pairs(holders) do
        if holder:hasScript(BOUNTY_TRACKER_SCRIPT) then
            local invokeStatus, giverIdx, targetIdx, kills, maxKills, timeRemaining = holder:invokeFunction(BOUNTY_TRACKER_SCRIPT, "getStatus")
            if invokeStatus == 0 then
                local giver = Faction(giverIdx)
                local target = Faction(targetIdx)
                return {
                    giverName = giver and giver.name or ("Faction " .. tostring(giverIdx)),
                    targetName = target and target.name or ("Faction " .. tostring(targetIdx)),
                    kills = kills or 0,
                    maxKills = maxKills or 15,
                    timeRemaining = timeRemaining or 0,
                }
            end
        end
    end

    return nil
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
                -- Only tracking NPC Factions and Player Alliances to prevent multiplayer UI bloat!
                if e and (e.isAIFaction or e.isAlliance) then
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

                        local famineA = server:getValue("cv_famine_" .. tostring(f.index)) or 0
                        local famineB = server:getValue("cv_famine_" .. tostring(e.index)) or 0

                        table.insert(conflicts, {
                            factionA = string.gsub(fName, "%s*/%*.-%*/%s*", ""),
                            factionAIndex = f.index,
                            traitsA = getFactionTraitsSafe(f),
                            bountyA = bountyA,
                            famineA = famineA,
                            factionB = string.gsub(eName, "%s*/%*.-%*/%s*", ""),
                            factionBIndex = e.index,
                            traitsB = getFactionTraitsSafe(e),
                            bountyB = bountyB,
                            famineB = famineB,
                            heat = math.floor(heat * 100),
                            relation = rel,
                            status = status
                        })
                    end
                end
            end
        end
    end


    if server:getValue("eclipse_fully_awake") then
        table.insert(conflicts, 1, {
            factionA = "The Eclipse",
            factionAIndex = 0,
            traitsA = {"Genocidal", "Existential Threat"},
            bountyA = 0,
            famineA = 0,
            factionB = "Galactic Civilizations",
            factionBIndex = 0,
            traitsB = {},
            bountyB = 0,
            famineB = 0,
            heat = 100,
            relation = -100000,
            status = "Total Eradication"
        })
    end

    invokeClientFunction(player, "receiveData", {conflicts = conflicts, myLicense = getMyLicense(player)})
end
callable(GalacticPoliticsTab, "serverFetchData")
