package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("utility")

-- namespace GalacticPoliticsTab
GalacticPoliticsTab = {}
local self = GalacticPoliticsTab

local BOUNTY_TRACKER_SCRIPT = "data/scripts/player/background/cw_bounty_tracker.lua"

-- v4.0.0: this mod's own nine custom traits, in the same order cosmicwarnews.lua's
-- getFactionStanceLabel() already checks them in -- kept in sync deliberately, since
-- both are "what is this faction's real assigned identity" lookups against the same
-- registry, and this file's own previous vanilla-only check (aggressive/peaceful) was
-- exactly the "one consumer got the fix, the sibling didn't" defect class this whole
-- pass keeps finding.
local CW_TRAIT_IDS = {
    "cw_warmonger", "cw_pacifist", "cw_isolationist", "cw_opportunist",
    "cw_imperialist", "cw_entrenched", "cw_vengeful", "cw_mercantile", "cw_xenophobic"
}

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
        for i, t in ipairs(traits or {}) do
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

    -- v4.0.0: Status is a legibility-ordered escalation, not alphabetical --
    -- clicking the Status header used to sort Active Conflict / Ceasefire / Cold War /
    -- Total War (English alphabetical order, and it silently changed per language
    -- since it sorted the untranslated string). This is what a player clicking that
    -- header is actually asking for.
    local STATUS_SEVERITY = { ["Ceasefire"] = 1, ["Cold War"] = 2, ["Active Conflict"] = 3, ["Total War"] = 4, ["Total Eradication"] = 5 }
    local function statusSeverityRank(status)
        return STATUS_SEVERITY[status] or 0
    end

    function GalacticPoliticsTab.initialize()
        -- v4.0.0: onPostRenderHud is an event callback, not an auto-invoked lifecycle
        -- method -- it never fires without this registration. Confirmed against vanilla's
        -- own structuredmission.lua (Player():registerCallback("onPostRenderHud", ...) in
        -- its own initialize()) and matches Cosmic Vault's Cosmic Codex / Cosmic Overhaul's
        -- Bulletin Board and Resource Display tabs, all of which register the same way.
        Player():registerCallback("onPostRenderHud", "onPostRenderHud")

        local playerWindow = PlayerWindow()

        self.tab = playerWindow:createTab("Galactic Politics"%_t, "data/textures/icons/cw_galacticpolitics.png",
        "Galactic Politics"%_t)
        self.tab.onSelectedFunction = "clientFetchData"
        self.tab.onShowFunction = "clientFetchData"

        playerWindow:moveTabToTheRight(self.tab)
        GalacticPoliticsTab.buildWindow(self.tab)
        GalacticPoliticsTab.clientFetchData()
    end

    -- v4.0.0: the tab is now a TabbedWindow hosting four sub-tabs (Conflicts, Dossier,
    -- War Room, Legend) instead of one single table with a 195px legend block nailed
    -- to the bottom of the same view. Each sub-tab builds its own header/content; all
    -- four are built once, up front (matching vanilla's own TabbedWindow convention --
    -- see factory.lua's Buy/Sell/Configure tabs), and updated in place via the same
    -- refresh calls a data-arrival callback already needs to make regardless.
    function GalacticPoliticsTab.buildWindow(container)
        local tabbedWindow = container:createTabbedWindow(Rect(container.size))

        self.conflictsSubTab = tabbedWindow:createTab("Conflicts"%_t, "data/textures/icons/cw_galacticpolitics.png", "Active galactic conflicts"%_t)
        self.dossierSubTab = tabbedWindow:createTab("Dossier"%_t, "data/textures/icons/magnifying_glass.png", "Select a conflict to see full faction detail"%_t)
        self.warRoomSubTab = tabbedWindow:createTab("War Room"%_t, "data/textures/icons/money.png", "Your own stakes in the galaxy's wars"%_t)
        -- War Room's own data (License/Warbonds/Intel) is fetched on demand, the
        -- moment the player actually opens this sub-tab -- same dual-binding pattern
        -- as the outer Galactic Politics tab itself, not fetched on every Conflicts
        -- refresh for a sub-tab most sessions may never open.
        self.warRoomSubTab.onSelectedFunction = "clientFetchWarRoom"
        self.warRoomSubTab.onShowFunction = "clientFetchWarRoom"
        self.legendSubTab = tabbedWindow:createTab("Legend"%_t, "data/textures/icons/help.png", "Legend & quick reference"%_t)

        GalacticPoliticsTab.buildConflictsTab(self.conflictsSubTab)
        GalacticPoliticsTab.buildDossierTab(self.dossierSubTab)
        GalacticPoliticsTab.buildWarRoomTab(self.warRoomSubTab)
        GalacticPoliticsTab.buildLegendTab(self.legendSubTab)
    end

    -- ========================================================================
    -- Conflicts sub-tab
    -- ========================================================================

    function GalacticPoliticsTab.buildConflictsTab(container)
        local UIKit = include("cosmicvaultuikit")

        -- Two-row header (title/license, then filter controls), with clearance for
        -- the sort-button strip handled once by the shared kit instead of by hand --
        -- this exact arithmetic is what independently drifted into an overlap bug in
        -- three different Cosmic Overhaul tabs before createHeaderLayout existed.
        local layout = UIKit.createHeaderLayout(container, { rows = { { fraction = 0.4 }, { fraction = 0.6 } } })
        local margin = layout.margin
        local topWidth = layout.width

        container:createLabel(Rect(layout.rows[1].lower + vec2(margin, 2), layout.rows[1].lower + vec2(margin + 320, layout.rows[1].height)), "Active Galactic Conflicts"%_t, 20)

        self.licenseLabel = container:createLabel(Rect(layout.rows[1].lower + vec2(topWidth * 0.42, 2), layout.rows[1].lower + vec2(topWidth - margin - 40, layout.rows[1].height)), "", 15)
        self.licenseLabel:setTopLeftAligned()

        local refreshButton = container:createButton(Rect(layout.rows[1].lower + vec2(topWidth - margin - 32, 2), layout.rows[1].lower + vec2(topWidth - margin, layout.rows[1].height)), "", "clientFetchData")
        refreshButton.icon = "data/textures/icons/cw_refresh.png"
        refreshButton.tooltip = "Refresh Galactic Intelligence"%_t

        self.filterComboBox = container:createValueComboBox(Rect(layout.rows[2].lower + vec2(margin, 0), layout.rows[2].lower + vec2(margin + 230, layout.rows[2].height)), "onFilterChanged")
        self.filterComboBox:addEntry("All", "All"%_t)
        self.filterComboBox:addEntry("Active Conflicts", "Active Conflicts"%_t)
        self.filterComboBox:addEntry("Ceasefires Only", "Ceasefires Only"%_t)
        self.filterComboBox:addEntry("Active Bounties", "Active Bounties"%_t)
        self.filterComboBox.tooltip = "Filter Conflicts"%_t

        self.numericCheck = container:createCheckBox(Rect(layout.rows[2].lower + vec2(margin + 245, 0), layout.rows[2].lower + vec2(margin + 465, layout.rows[2].height)), "Numeric Relations"%_t, "onNumericCheckChanged")
        self.numericCheck.checked = false
        self.numericCheck.tooltip = "Toggle between numeric and descriptive relation values."%_t

        self.conflictsTable = UIKit.createSortableTable(GalacticPoliticsTab, container, layout.contentRect, {
            { label = "Faction A"%_t, width = 2.0, sortValue = function(r) return r.factionA end,
              cellText = function(r) return r.factionA end,
              cellColor = function(r) return getRelationColor(Player():getRelations(r.factionAIndex) or 0) end },
            { label = "Faction B"%_t, width = 2.0, sortValue = function(r) return r.factionB end,
              cellText = function(r) return r.factionB end,
              cellColor = function(r) return getRelationColor(Player():getRelations(r.factionBIndex) or 0) end },
            { label = "War Score"%_t, width = 1.3, sortValue = function(r) return r.warScore or 0 end,
              cellText = function(r)
                  local ws = r.warScore or 0
                  if ws == 0 then return "Even"%_t end
                  local leader = ws > 0 and r.factionA or r.factionB
                  return string.format("%s +%d"%_t, leader, math.abs(math.floor(ws)))
              end,
              cellColor = function(r) return ColorRGB(0.8, 0.8, 0.8) end },
            { label = "Bounty"%_t, width = 1.2, sortValue = function(r) return math.max(r.bountyA or 0, r.bountyB or 0) end,
              cellText = function(r)
                  local m = math.max(r.bountyA or 0, r.bountyB or 0)
                  return m > 0 and createMonetaryString(m) or "-"
              end,
              cellColor = function(r) return math.max(r.bountyA or 0, r.bountyB or 0) > 0 and ColorRGB(1.0, 0.85, 0.3) or ColorRGB(0.7, 0.7, 0.7) end },
            { label = "War Heat"%_t, width = 1.2, sortValue = function(r) return r.heat end,
              cellText = function(r) return tostring(r.heat) .. "%" end,
              cellColor = function(r)
                  if r.heat >= 80 then return ColorRGB(1.0, 0.2, 0.2)
                  elseif r.heat >= 40 then return ColorRGB(1.0, 0.6, 0.2)
                  elseif r.heat > 0 then return ColorRGB(1.0, 1.0, 0.2)
                  else return ColorRGB(0.2, 1.0, 0.2) end
              end },
            { label = "Famine"%_t, width = 1.2, sortValue = function(r) return math.max(r.famineA or 0, r.famineB or 0) end,
              cellText = function(r)
                  local m = math.max(r.famineA or 0, r.famineB or 0)
                  if m >= 100 then return "Critical"%_t elseif m >= 50 then return "Struggling"%_t else return "Normal"%_t end
              end,
              cellColor = function(r)
                  local m = math.max(r.famineA or 0, r.famineB or 0)
                  if m >= 100 then return ColorRGB(1.0, 0.2, 0.2) elseif m >= 50 then return ColorRGB(1.0, 1.0, 0.2) else return ColorRGB(0.2, 1.0, 0.2) end
              end },
            { label = "Status"%_t, width = 1.5, sortValue = function(r) return statusSeverityRank(r.status) end,
              cellText = function(r) return r.status%_t end,
              cellColor = function(r)
                  if r.heat >= 80 then return ColorRGB(1.0, 0.2, 0.2)
                  elseif r.heat >= 40 then return ColorRGB(1.0, 0.6, 0.2)
                  elseif r.heat > 0 then return ColorRGB(1.0, 1.0, 0.2)
                  else return ColorRGB(0.2, 1.0, 0.2) end
              end },
            { label = "Relations"%_t, width = 1.5, sortValue = function(r) return r.relation end,
              cellText = function(r)
                  if self.numericCheck and self.numericCheck.checked then return tostring(r.relation) end
                  return getRelationDescription(r.relation)
              end,
              cellColor = function(r) return ColorRGB(0.8, 0.8, 0.8) end },
        }, { sortStripRect = layout.sortStripRect, rowHeight = 30, defaultSortColumn = 5, defaultSortDirection = -1 })

        self.conflictsTable:setSelectionChangedHandler(function(row)
            if not row then return end
            GalacticPoliticsTab.onConflictSelected(row)
        end)
    end

    function GalacticPoliticsTab.clientFetchData()
        invokeServerFunction("serverFetchData")
    end

    function GalacticPoliticsTab.clientFetchWarRoom()
        invokeServerFunction("serverFetchWarRoom")
    end

    function GalacticPoliticsTab.onNumericCheckChanged()
        if self.conflictsTable then self.conflictsTable:setRows(self.conflictsTable.rowData) end
    end

    function GalacticPoliticsTab.onFilterChanged()
        GalacticPoliticsTab.applyFilter()
    end

    -- v4.0.0 fix: the filter used to test `conflict.heat` while the Status column
    -- right next to it is derived from `relation` -- a row could visibly say
    -- "Ceasefire" in its own Status cell and still get excluded by "Ceasefires Only",
    -- because its heat happened to be above zero. Filtering on the same `status`
    -- field the column actually shows removes the contradiction.
    function GalacticPoliticsTab.applyFilter()
        if not self.lastData then return end
        local filter = self.filterComboBox.selectedValue
        local filtered = {}
        for _, conflict in ipairs(self.lastData) do
            local match = true
            if filter == "Active Conflicts" and conflict.status == "Ceasefire" then match = false end
            if filter == "Ceasefires Only" and conflict.status ~= "Ceasefire" then match = false end
            if filter == "Active Bounties" and (conflict.bountyA or 0) == 0 and (conflict.bountyB or 0) == 0 then match = false end
            if match then table.insert(filtered, conflict) end
        end
        self.conflictsTable:setRows(filtered)
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

    function GalacticPoliticsTab.receiveData(data)
        if type(data) ~= "table" then return end
        self.lastData = data.conflicts or {}
        self.myLicense = data.myLicense
        self.updateLicenseStatus()
        GalacticPoliticsTab.applyFilter()
    end

    -- ========================================================================
    -- Dossier sub-tab
    -- ========================================================================

    function GalacticPoliticsTab.buildDossierTab(container)
        local UIKit = include("cosmicvaultuikit")
        local margin = 10

        self.dossierHint = container:createLabel(Rect(margin, margin, container.size.x - margin, margin + 24), "Select a conflict on the Conflicts tab to see full detail here."%_t, 15)
        self.dossierHint:setTopLeftAligned()

        local hsplit = UIVerticalSplitter(Rect(margin, margin + 30, container.size.x - margin, container.size.y - margin), 10, 10, 0.5)
        self.dossierPanelA = UIKit.createDossierPanel(container, hsplit.left, { maxRows = 10 })
        self.dossierPanelB = UIKit.createDossierPanel(container, hsplit.right, { maxRows = 10 })
    end

    -- v4.0.0: fetches the pair's expensive detail fields (home sector, defense
    -- generator status, expansion momentum, corridor endpoint, real trait
    -- description) only when a conflict row is actually selected -- the Conflicts
    -- table's own refresh stays a lean per-conflict list, not a query that computes
    -- every faction's full dossier on every tick.
    function GalacticPoliticsTab.onConflictSelected(row)
        self.selectedConflict = row
        invokeServerFunction("serverFetchDossier", row.factionAIndex, row.factionBIndex)
    end

    local function populateDossierPanel(panel, data)
        if not data then
            panel:setData({ title = "Unknown"%_t, rows = {} })
            return
        end

        local rows = {}
        -- Falls back to the same vanilla/Player-Faction/Player-Alliance labels
        -- getFactionTraitsSafe() already computes when this faction has none of this
        -- mod's own nine custom traits assigned (getPrimaryTraitInfo() only ever
        -- covers those nine, by design).
        local traitValue = (data.traitName and data.traitName%_t) or concatLocalizedTraits(data.traits) or "Unknown"%_t
        local traitTooltip = data.traitDesc and data.traitDesc%_t or nil
        table.insert(rows, { label = "Trait"%_t, value = traitValue, tooltip = traitTooltip })
        if data.homeX and data.homeY then
            table.insert(rows, { label = "Home Sector"%_t, value = string.format("(%d:%d)", data.homeX, data.homeY) })
        end
        table.insert(rows, { label = "War Heat"%_t, bar = (data.heat or 0), color = (data.heat or 0) >= 0.8 and ColorRGB(1.0, 0.2, 0.2) or ((data.heat or 0) >= 0.4 and ColorRGB(1.0, 0.6, 0.2) or ColorRGB(0.2, 1.0, 0.2)) })
        local famineText, famineColor = "Normal"%_t, ColorRGB(0.2, 1.0, 0.2)
        if (data.famine or 0) >= 100 then famineText, famineColor = "Critical"%_t, ColorRGB(1.0, 0.2, 0.2)
        elseif (data.famine or 0) >= 50 then famineText, famineColor = "Struggling"%_t, ColorRGB(1.0, 1.0, 0.2) end
        table.insert(rows, { label = "Famine"%_t, value = famineText, color = famineColor })
        table.insert(rows, { label = "Your Relation"%_t, value = tostring(math.floor(data.relation or 0)) })
        if (data.intel or 0) > 0 then
            table.insert(rows, { label = "Your Intel"%_t, value = tostring(math.floor(data.intel)), tooltip = "Spend 50 via /cosmicwarintel"%_t })
        end
        if data.enemyName then
            table.insert(rows, { label = "Registered Enemy"%_t, value = data.enemyName })
        end
        if data.bountyActive then
            table.insert(rows, { label = "Bounty (Per Kill)"%_t, value = "¢" .. createMonetaryString(data.bountyReward or 0), color = ColorRGB(1.0, 0.85, 0.3) })
        end
        table.insert(rows, { label = "Defense Generator"%_t, value = data.hasGenerator and "Commissioned"%_t or "None"%_t, color = data.hasGenerator and ColorRGB(1.0, 0.6, 0.2) or ColorRGB(0.6, 0.6, 0.6) })
        if data.underMomentum then
            table.insert(rows, { label = "Expansion"%_t, value = "Momentum Active"%_t, color = ColorRGB(0.6, 1.0, 0.6), tooltip = "Recently won a siege -- expansion rolls are temporarily boosted."%_t })
        end
        if data.corridorEndpoint then
            table.insert(rows, { label = "Subspace Corridor"%_t, value = "Endpoint Here"%_t, color = ColorRGB(0.6, 0.4, 1.0) })
        end

        panel:setData({ title = data.name or "Unknown"%_t, rows = rows })
    end

    function GalacticPoliticsTab.receiveDossier(dataA, dataB)
        if self.dossierHint then
            self.dossierHint.caption = self.selectedConflict and (self.selectedConflict.factionA .. " vs "%_t .. self.selectedConflict.factionB) or "Select a conflict on the Conflicts tab to see full detail here."%_t
        end
        populateDossierPanel(self.dossierPanelA, dataA)
        populateDossierPanel(self.dossierPanelB, dataB)
    end

    -- ========================================================================
    -- War Room sub-tab
    -- ========================================================================

    function GalacticPoliticsTab.buildWarRoomTab(container)
        local UIKit = include("cosmicvaultuikit")
        local margin = 10
        local width = container.size.x
        local height = container.size.y

        container:createLabel(Rect(margin, margin, width - margin, margin + 26), "Your Stakes In The War"%_t, 20)

        local hsplit = UIVerticalSplitter(Rect(margin, margin + 34, width - margin, height - margin), 10, 10, 0.5)
        self.warRoomLicensePanel = UIKit.createDossierPanel(container, hsplit.left, { maxRows = 4, titleFontSize = 15 })
        self.warRoomBondsPanel = UIKit.createDossierPanel(container, hsplit.right, { maxRows = 10, titleFontSize = 15 })
    end

    function GalacticPoliticsTab.receiveWarRoom(data)
        data = data or {}

        local licenseRows = {}
        if data.license then
            table.insert(licenseRows, { label = "Target"%_t, value = data.license.targetName })
            table.insert(licenseRows, { label = "Given By"%_t, value = data.license.giverName })
            table.insert(licenseRows, { label = "Progress"%_t, value = tostring(data.license.kills) .. "/" .. tostring(data.license.maxKills) .. " "%_t .. "kills"%_t })
            table.insert(licenseRows, { label = "Time Left"%_t, value = formatTimeRemaining(data.license.timeRemaining) })
        end
        self.warRoomLicensePanel:setData({ title = "Bounty License"%_t, rows = licenseRows })

        local bondRows = {}
        for _, bond in ipairs(data.bonds or {}) do
            table.insert(bondRows, {
                label = bond.factionName,
                value = createMonetaryString(bond.amount) .. " -> " .. createMonetaryString(bond.projectedPayout) .. " (" .. tostring(math.floor((bond.projectedMultiplier or 0) * 100)) .. "%)",
                tooltip = "Projected payout if this war ended right now."%_t
            })
        end
        for _, intel in ipairs(data.intel or {}) do
            table.insert(bondRows, { label = "Intel vs "%_t .. intel.factionName, value = tostring(math.floor(intel.amount)) })
        end
        if data.isAlliance then
            table.insert(bondRows, { label = "Alliance Pool"%_t, value = "Active"%_t, tooltip = "Intel is shared with your Alliance."%_t, color = ColorRGB(0.6, 1.0, 0.6) })
        end
        self.warRoomBondsPanel:setData({ title = "Warbonds & Intel"%_t, rows = bondRows })
    end

    -- ========================================================================
    -- Legend sub-tab
    -- ========================================================================

    function GalacticPoliticsTab.buildLegendTab(container)
        local margin = 16
        local width = container.size.x

        container:createLabel(Rect(margin, margin, width - margin, margin + 26), "Legend & Quick Reference"%_t, 20)

        local y = margin + 40
        local function swatchLine(color, text)
            container:createRect(Rect(margin, y + 3, margin + 14, y + 14), color)
            local lbl = container:createLabel(Rect(margin + 22, y, width - margin, y + 20), text, 14)
            lbl:setTopLeftAligned()
            y = y + 24
        end

        container:createLabel(Rect(margin, y, width - margin, y + 20), "War Heat"%_t, 16)
        y = y + 26
        swatchLine(ColorRGB(1.0, 0.2, 0.2), "Critical (80%+)"%_t)
        swatchLine(ColorRGB(1.0, 0.6, 0.2), "High (40-79%)"%_t)
        swatchLine(ColorRGB(1.0, 1.0, 0.2), "Rising (1-39%)"%_t)
        swatchLine(ColorRGB(0.2, 1.0, 0.2), "Zero"%_t)

        y = y + 14
        container:createLabel(Rect(margin, y, width - margin, y + 20), "Your Relations"%_t, 16)
        y = y + 26
        swatchLine(ColorRGB(0.2, 1.0, 0.2), "Friendly"%_t)
        swatchLine(ColorRGB(0.8, 0.8, 0.8), "Neutral"%_t)
        swatchLine(ColorRGB(1.0, 0.2, 0.2), "Hostile"%_t)

        y = y + 14
        container:createLabel(Rect(margin, y, width - margin, y + 20), "Famine"%_t, 16)
        y = y + 26
        swatchLine(ColorRGB(0.2, 1.0, 0.2), "Normal"%_t)
        swatchLine(ColorRGB(1.0, 1.0, 0.2), "Struggling (50+)"%_t)
        swatchLine(ColorRGB(1.0, 0.2, 0.2), "Critical (100+)"%_t)

        y = y + 14
        local summaryStr = "Cosmic War Simulation:"%_t .. "\n" ..
            "Conflict escalates dynamically based on 'War Heat', triggering massive fleet clashes, bounties, and economic sanctions."%_t .. "\n\n" ..
            "Note: While politics and skirmishes are highly dynamic, faction station ownership and map borders can change dynamically through sieges and expansion -- but do not move on the static galaxy map projection itself instantly, it takes time."%_t .. "\n\n" ..
            "Tip: Use /cosmicwar main command in chat to bring up a help menu with available Cosmic War commands and information regarding said commands."%_t
        local summaryLabel = container:createLabel(Rect(margin, y, width - margin, container.size.y - margin), summaryStr, 15)
        summaryLabel.wordBreak = true
        summaryLabel:setTopLeftAligned()
    end

    -- v4.0.0: Galactic Politics hotkey -- same CCM keybind + onPostRenderHud pattern
    -- Cosmic Vault's Cosmic Codex and Cosmic Overhaul's Bulletin Board/Resource Display
    -- tabs already use (cosmicvaultconfig.lua/cosmicoverhaulconfig.lua's own "UI &
    -- Keybinds" pages). Unbound by default -- see cosmicwarconfig.lua's own "UI &
    -- Keybinds" page, which declares no default for this key, exactly like every other
    -- keybind option in the suite.
    function GalacticPoliticsTab.onPostRenderHud(state)
        local ccm = include("ccm")
        if ccm then
            local cwcfg = ccm.bind("Cosmic_War")
            if cwcfg.isKeyComboDown("hotkeyGalacticPolitics") then
                local pw = PlayerWindow()
                if pw and self.tab then
                    pw:show()
                    if pw.selectTab then
                        pw:selectTab(self.tab)
                    elseif pw.activateTab then
                        pw:activateTab(self.tab)
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Server
-- ============================================================================

-- v4.0.0 fix: previously checked only the two vanilla traits (aggressive/peaceful),
-- so most AI factions -- which carry one of this mod's own nine custom traits instead
-- -- showed as "Unknown" in the one screen built to explain who they are. The correct
-- derivation already existed in cosmicwarnews.lua's getFactionStanceLabel(); this
-- mirrors it rather than duplicating a second, divergence-prone copy of the same
-- registry walk.
local function getFactionTraitsSafe(faction)
    local traits = {}
    if faction.isPlayer then
        table.insert(traits, "Player Faction")
        return traits
    elseif faction.isAlliance then
        table.insert(traits, "Player Alliance")
        return traits
    end

    local cvf = include("cosmicvaultfaction")
    local registry = cvf.getCustomTraits() or {}
    for _, traitId in pairs(CW_TRAIT_IDS) do
        if (cvf.getTrait(faction.index, traitId) or 0) > 0 then
            local info = registry[traitId]
            if info and info.name then table.insert(traits, info.name) end
        end
    end

    -- Fall back to the vanilla traits only if this faction was never assigned one of
    -- this mod's own custom traits (e.g. seeded before cosmicwartraits.lua ran).
    if #traits == 0 then
        if faction:getTrait("aggressive") > 0.5 then table.insert(traits, "Aggressive") end
        if faction:getTrait("peaceful") > 0.5 then table.insert(traits, "Peaceful") end
    end
    if #traits == 0 then return {"Unknown"} end
    return traits
end

--- Returns {name, descriptions} for whichever of this mod's nine custom traits is
-- currently assigned to the faction, or nil if none is. Descriptions are joined into
-- one tooltip string; the display name is left untranslated (bare string) so the
-- client applies %_t itself, matching every other faction-name/trait string this file
-- already sends across the network boundary this way.
local function getPrimaryTraitInfo(faction)
    if not faction or faction.isPlayer or faction.isAlliance then return nil end
    local cvf = include("cosmicvaultfaction")
    local registry = cvf.getCustomTraits() or {}
    for _, traitId in pairs(CW_TRAIT_IDS) do
        if (cvf.getTrait(faction.index, traitId) or 0) > 0 then
            local info = registry[traitId]
            if info then
                return info.name, table.concat(info.descriptions or {}, " ")
            end
        end
    end
    return nil, nil
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
    include("cosmicwarbridge")
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
                        if CosmicWarBridge and CosmicWarBridge.getFactionWarHeat then
                            heat = CosmicWarBridge.getFactionWarHeat(f.index) or 0
                        end

                    -- Cosmic War: Translates raw relational values into descriptive diplomatic states.
                        local rel = f:getRelations(e.index) or 0
                        local status
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

                        -- v4.0.0 War Score & Attrition: positive favors faction A.
                        local warScore = CosmicWarBridge.getWarScore and CosmicWarBridge.getWarScore(f.index, e.index) or 0

                        -- Note: this row deliberately does NOT carry traits/Intel fields.
                        -- The Conflicts table's own eight columns never read them (verified
                        -- against every cellText/sortValue/cellColor below), and the Dossier
                        -- and War Room sub-tabs already fetch that same data themselves, on
                        -- demand, only for the pair a player actually selects/opens -- see
                        -- serverFetchDossier() and serverFetchWarRoom() below. Computing
                        -- getFactionTraitsSafe() and CosmicWarBridge.getIntel() twice per
                        -- pair here as well would just be paid-for-and-thrown-away work on
                        -- every refresh.
                        table.insert(conflicts, {
                            warScore = warScore,
                            factionA = string.gsub(fName, "%s*/%*.-%*/%s*", ""),
                            factionAIndex = f.index,
                            bountyA = bountyA,
                            famineA = famineA,
                            factionB = string.gsub(eName, "%s*/%*.-%*/%s*", ""),
                            factionBIndex = e.index,
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
        -- v4.0.0 fix: this synthetic row now carries the exact same field set as every
        -- real conflict row above (warScore included) -- it previously omitted warScore
        -- entirely, a shape mismatch that was harmless only because every reader happened
        -- to nil-guard the field. traitsA/traitsB/intelA/intelB are gone from real rows
        -- too now (see the comment above the real row's own table.insert), so this row
        -- matches by simply not having them either.
        table.insert(conflicts, 1, {
            warScore = 0,
            factionA = "The Eclipse",
            factionAIndex = 0,
            bountyA = 0,
            famineA = 0,
            factionB = "Galactic Civilizations",
            factionBIndex = 0,
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

-- v4.0.0: the Dossier sub-tab's own fetch, split out from serverFetchData() so
-- browsing the Conflicts list doesn't pay for these fields on every refresh -- only
-- computed for the exact pair a player actually selects.
function GalacticPoliticsTab.serverFetchDossier(factionAIndex, factionBIndex)
    if not onServer() then return end
    local player = Player(callingPlayer)
    if not player then return end

    include("cosmicwarbridge")
    local server = Server()

    local function buildDossier(idx)
        if not idx or idx <= 0 then return nil end
        local f = Faction(idx)
        if not f then return nil end

        local traitName, traitDesc = getPrimaryTraitInfo(f)
        -- Fallback for Player Faction/Alliance rows and any AI faction with none of
        -- this mod's own custom traits assigned -- see populateDossierPanel().
        local traits = traitName and nil or getFactionTraitsSafe(f)
        local hx, hy = f:getHomeSectorCoordinates()
        local heat = CosmicWarBridge and CosmicWarBridge.getFactionWarHeat and (CosmicWarBridge.getFactionWarHeat(idx) or 0) or 0
        local famine = server:getValue("cv_famine_" .. tostring(idx)) or 0
        local intel = CosmicWarBridge and CosmicWarBridge.getIntel and (CosmicWarBridge.getIntel(player, idx) or 0) or 0
        local enemyIdx = f:getValue("enemy_faction") or 0
        local enemyFaction = enemyIdx > 0 and Faction(enemyIdx) or nil
        local hasGenerator = f:getValue("cw_defense_generator_sector") and true or false
        local momentumUntil = server:getValue("cw_expansion_momentum_" .. tostring(idx)) or 0
        local underMomentum = momentumUntil > (server.unpausedRuntime or 0)
        local corridorEndpoint = (hx and hy) and server:getValue("cw_corridor_at_" .. hx .. ":" .. hy) or nil
        local now = server.unpausedRuntime or 0
        local bountyActive = (f:getValue("cw_bounty_enemy") or 0) > 0 and (f:getValue("cw_bounty_expires") or 0) > now
        local bountyReward = bountyActive and (f:getValue("cw_bounty_reward") or 0) or 0

        return {
            name = f.name,
            index = idx,
            traitName = traitName,
            traitDesc = traitDesc,
            traits = traits,
            homeX = hx,
            homeY = hy,
            heat = heat,
            famine = famine,
            intel = intel,
            relation = player:getRelations(idx) or 0,
            enemyName = enemyFaction and enemyFaction.name or nil,
            hasGenerator = hasGenerator,
            underMomentum = underMomentum,
            corridorEndpoint = corridorEndpoint and true or false,
            bountyActive = bountyActive,
            bountyReward = bountyReward,
        }
    end

    invokeClientFunction(player, "receiveDossier", buildDossier(factionAIndex), buildDossier(factionBIndex))
end
callable(GalacticPoliticsTab, "serverFetchDossier")

-- v4.0.0: the War Room sub-tab's fetch -- everything the player personally has
-- riding on the war (License, Warbonds, Intel), previously only reachable through
-- two chat commands and a station dialog.
function GalacticPoliticsTab.serverFetchWarRoom()
    if not onServer() then return end
    local player = Player(callingPlayer)
    if not player then return end

    include("cosmicwarbridge")
    local server = Server()

    local license = getMyLicense(player)

    local bonds = {}
    if player:hasScript("cosmicwar_warbonds.lua") then
        local status, rawBonds = player:invokeFunction("cosmicwar_warbonds.lua", "getActiveBonds")
        if status == 0 and type(rawBonds) == "table" then
            for _, b in pairs(rawBonds) do
                local f = Faction(b.factionIndex)
                table.insert(bonds, {
                    factionName = f and f.name or ("Faction " .. tostring(b.factionIndex)),
                    amount = b.amount or 0,
                    projectedPayout = b.projectedPayout or 0,
                    projectedMultiplier = b.projectedMultiplier or 0,
                })
            end
        end
    end

    -- Intel: scoped to the same "factions this player is actively tracking" set
    -- serverFetchData() already establishes (tracked, cw_enabled AI factions with a
    -- registered enemy) rather than a full second enumeration of every AI faction
    -- that ever existed -- a faction the player banked Intel against but who has
    -- since resolved their war won't appear here, a deliberate, documented scope
    -- boundary rather than a silent gap.
    local intel = {}
    local factionsStr = server:getValue("factions")
    if type(factionsStr) == "string" and factionsStr ~= "" then
        for id in string.gmatch(factionsStr, "([^,]+)") do
            local idx = tonumber(id)
            local f = idx and Faction(idx)
            if f and f.isAIFaction and f:getValue("cw_enabled") then
                local amt = CosmicWarBridge and CosmicWarBridge.getIntel and (CosmicWarBridge.getIntel(player, idx) or 0) or 0
                if amt > 0 then
                    table.insert(intel, { factionName = f.name, amount = amt })
                end
            end
        end
    end

    local isAlliance = player.allianceIndex and player.allianceIndex > 0 or false

    invokeClientFunction(player, "receiveWarRoom", { license = license, bonds = bonds, intel = intel, isAlliance = isAlliance })
end
callable(GalacticPoliticsTab, "serverFetchWarRoom")
