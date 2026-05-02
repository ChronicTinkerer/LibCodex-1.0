-- LibCodex-1.0 / Dashboard.lua
-- Single-window GUI control panel for everything /codex can do. Designed so
-- you never need to type slash commands once it's open. Also serves as a
-- live introspection view while you play.
--
-- Layout:
--   Title bar (drag to move, X to close)
--   Tab bar:  Stats | Search | Where | Settings | Actions
--   Content panel below (changes per tab)
--   Footer:   "Open Log" + "Reload UI" buttons + status text
--
-- Slash command: /codex gui  (or click the 'GUI' button on the log window)

local LibCodex = LibStub("LibCodex-1.0")
LibCodex.Dashboard = LibCodex.Dashboard or {}
local D = LibCodex.Dashboard

local frame, tabs, panels, currentTab

-- ----------------------------------------------------------------------------
-- Helpers.
-- ----------------------------------------------------------------------------

local function out(msg)
    if LibCodex.Log and LibCodex.Log.Print then
        LibCodex.Log.Print(msg)
    elseif print then
        print(msg)
    end
end

local function makeButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function makeCheckbox(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return cb
end

local function makeLabel(parent, text, fontObj)
    local f = parent:CreateFontString(nil, "OVERLAY", fontObj or "GameFontNormal")
    f:SetText(text)
    return f
end

-- ----------------------------------------------------------------------------
-- Stats panel: per-module entry counts with source breakdown.
-- ----------------------------------------------------------------------------

local function buildStatsPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    p.title = makeLabel(p, "Module entry counts (refresh to recompute)", "GameFontHighlight")
    p.title:SetPoint("TOPLEFT", 8, -4)

    p.refresh = makeButton(p, "Refresh", 80, 22, function() D.RefreshStats() end)
    p.refresh:SetPoint("TOPRIGHT", -8, -2)

    p.scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT", 8, -28)
    p.scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    p.text = CreateFrame("EditBox", nil, p.scroll)
    p.text:SetMultiLine(true)
    p.text:SetAutoFocus(false)
    p.text:SetFontObject(ChatFontNormal)
    p.text:SetWidth(420)
    p.text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.scroll:SetScrollChild(p.text)

    return p
end

function D.RefreshStats()
    if not panels or not panels.Stats or not panels.Stats.text then return end
    local lines = {}
    local rows = {}
    for name, mod in pairs(LibCodex.modules) do
        local total = mod.Count and mod:Count() or 0
        local bySource = {}
        if mod.AllRaw then
            for _, e in pairs(mod:AllRaw()) do
                if type(e.sources) == "table" then
                    for _, s in ipairs(e.sources) do
                        bySource[s] = (bySource[s] or 0) + 1
                    end
                end
            end
        end
        rows[#rows + 1] = { name = name, total = total, bySource = bySource }
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    for _, r in ipairs(rows) do
        local parts = {}
        local names = {}
        for s, _ in pairs(r.bySource) do names[#names + 1] = s end
        table.sort(names)
        for _, s in ipairs(names) do parts[#parts + 1] = s .. ":" .. r.bySource[s] end
        lines[#lines + 1] = string.format("%-14s total:%-7d  %s", r.name, r.total, table.concat(parts, "  "))
    end
    panels.Stats.text:SetText(table.concat(lines, "\n"))
end

-- ----------------------------------------------------------------------------
-- Search panel.
-- ----------------------------------------------------------------------------

local function buildSearchPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    makeLabel(p, "Search across all modules:", "GameFontHighlight"):SetPoint("TOPLEFT", 8, -4)

    p.input = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    p.input:SetSize(280, 22)
    p.input:SetPoint("TOPLEFT", 12, -28)
    p.input:SetAutoFocus(false)
    p.input:SetScript("OnEnterPressed", function(self) D.RunSearch(self:GetText()); self:ClearFocus() end)

    p.go = makeButton(p, "Search", 80, 22, function() D.RunSearch(p.input:GetText()) end)
    p.go:SetPoint("LEFT", p.input, "RIGHT", 8, 0)

    p.scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT", 8, -56)
    p.scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    p.text = CreateFrame("EditBox", nil, p.scroll)
    p.text:SetMultiLine(true)
    p.text:SetAutoFocus(false)
    p.text:SetFontObject(ChatFontNormal)
    p.text:SetWidth(420)
    p.text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.scroll:SetScrollChild(p.text)

    return p
end

function D.RunSearch(query)
    if not panels or not panels.Search or not panels.Search.text then return end
    if not query or query == "" then
        panels.Search.text:SetText("(enter a search query)")
        return
    end
    local lines = {}
    local total = 0
    for name, mod in pairs(LibCodex.modules) do
        if mod.Search then
            local hits = mod:Search(query)
            if #hits > 0 then
                lines[#lines + 1] = name .. " (" .. #hits .. " matches):"
                local shown = 0
                for _, e in ipairs(hits) do
                    if shown >= 15 then
                        lines[#lines + 1] = "  ... " .. (#hits - 15) .. " more"
                        break
                    end
                    local srcs = e.sources and table.concat(e.sources, ",") or "?"
                    lines[#lines + 1] = string.format("  [%s] %s  (src:%s)",
                        tostring(e.id or "?"), tostring(e.label or "?"), srcs)
                    shown = shown + 1
                    total = total + 1
                end
                lines[#lines + 1] = ""
            end
        end
    end
    if total == 0 then
        lines[#lines + 1] = "No matches for '" .. query .. "'"
    end
    panels.Search.text:SetText(table.concat(lines, "\n"))
end

-- ----------------------------------------------------------------------------
-- Where panel: itemID -> drop sources.
-- ----------------------------------------------------------------------------

local function buildWherePanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    makeLabel(p, "Where can I get an item? (enter itemID)", "GameFontHighlight"):SetPoint("TOPLEFT", 8, -4)

    p.input = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    p.input:SetSize(150, 22)
    p.input:SetPoint("TOPLEFT", 12, -28)
    p.input:SetNumeric(true)
    p.input:SetAutoFocus(false)
    p.input:SetScript("OnEnterPressed", function(self) D.RunWhere(tonumber(self:GetText())); self:ClearFocus() end)

    p.go = makeButton(p, "Lookup", 80, 22, function() D.RunWhere(tonumber(p.input:GetText())) end)
    p.go:SetPoint("LEFT", p.input, "RIGHT", 8, 0)

    p.scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT", 8, -56)
    p.scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    p.text = CreateFrame("EditBox", nil, p.scroll)
    p.text:SetMultiLine(true)
    p.text:SetAutoFocus(false)
    p.text:SetFontObject(ChatFontNormal)
    p.text:SetWidth(420)
    p.text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.scroll:SetScrollChild(p.text)

    return p
end

function D.RunWhere(itemID)
    if not panels or not panels.Where or not panels.Where.text then return end
    if not itemID then
        panels.Where.text:SetText("(enter a numeric itemID)")
        return
    end
    local Items = LibCodex:Items()
    if not Items then panels.Where.text:SetText("Items module not loaded.") return end
    local entry = Items:Get(itemID)
    if not entry then
        panels.Where.text:SetText("Item " .. itemID .. " not in catalog.")
        return
    end
    local lines = { string.format("[%d] %s", itemID, tostring(entry.label or "?")) }
    if entry.dropsFrom then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Drop sources:"
        local dropSources = (Items.GetDropSources and Items:GetDropSources(itemID)) or {}
        for _, s in pairs(dropSources) do
            local pct = (s.outof and s.outof > 0) and string.format(" %.1f%%", (s.count or 0) / s.outof * 100) or ""
            lines[#lines + 1] = string.format("  %s [%s] %s  x%d%s",
                s.kind or "?", tostring(s.sourceID or "?"),
                tostring(s.sourceLabel or s.sourceName or "?"),
                s.count or 0, pct)
            if s.locations then
                for _, loc in ipairs(s.locations) do
                    lines[#lines + 1] = string.format("      map %d at (%.2f, %.2f) x%d",
                        loc.mapID or 0, loc.x or 0, loc.y or 0, loc.count or 1)
                end
            end
        end
    else
        lines[#lines + 1] = "(no drop history yet)"
    end
    panels.Where.text:SetText(table.concat(lines, "\n"))
end

-- ----------------------------------------------------------------------------
-- Browse panel: pick a module, optionally filter, click to inspect a row.
-- Designed to handle modules ranging from dozens (Classes) to hundreds of
-- thousands (Spells). The list view caps at BROWSE_LIMIT rows; use the
-- filter to narrow down. Click a row to load its full entry into the detail
-- pane on the right.
-- ----------------------------------------------------------------------------

local BROWSE_LIMIT = 300       -- max rows to render in the list
local BROWSE_ROW_HEIGHT = 16

-- Enumerate every keyed entry in a module, including ones still in the lazy
-- bundled indexes (row format, TSV format). We only return the keys; the
-- caller materializes a full entry via :Get(key) on demand.
local function enumerateKeys(mod)
    local keys = {}
    if mod._entries then
        for k, _ in pairs(mod._entries) do keys[#keys + 1] = k end
    end
    if mod._rowIndex then
        for k, _ in pairs(mod._rowIndex) do keys[#keys + 1] = k end
    end
    if mod._tsvIndex then
        for k, _ in pairs(mod._tsvIndex) do keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

-- Format an arbitrary entry-field value for the detail pane. Tables get a
-- compact one-line repr; long tables truncate with "..." so the view stays
-- readable.
local function formatValue(v, depth)
    depth = depth or 0
    if depth > 4 then return "..." end
    local t = type(v)
    if t == "string" then return '"' .. v .. '"' end
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "nil" then return "nil" end
    if t == "table" then
        local parts = {}
        local n = 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 8 then parts[#parts + 1] = "..."; break end
            local ks = (type(k) == "string") and k or ("[" .. tostring(k) .. "]")
            parts[#parts + 1] = ks .. "=" .. formatValue(vv, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function buildBrowsePanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()
    p._modName = nil       -- currently-selected module
    p._filter = ""

    -- Module picker. Single button that opens a small popup listing every
    -- registered module. UIDropDownMenu would also work but the popup is
    -- simpler and renders predictably across UI scales.
    p.modBtn = makeButton(p, "Module: (pick one)", 180, 22, function() D.OpenBrowseModulePicker() end)
    p.modBtn:SetPoint("TOPLEFT", 8, -4)

    -- Filter input (substring match against the module's search fields).
    p.filter = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    p.filter:SetSize(180, 22)
    p.filter:SetPoint("LEFT", p.modBtn, "RIGHT", 14, 0)
    p.filter:SetAutoFocus(false)
    p.filter:SetScript("OnTextChanged", function(self) p._filter = self:GetText() or ""; D.RefreshBrowse() end)
    p.filter:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    p.filterLabel = makeLabel(p, "filter", "GameFontDisableSmall")
    p.filterLabel:SetPoint("BOTTOMLEFT", p.filter, "TOPLEFT", -2, 0)

    -- Count / status line under the controls.
    p.count = makeLabel(p, "", "GameFontHighlightSmall")
    p.count:SetPoint("TOPLEFT", 12, -32)

    -- Left column: scrollable result list (clickable rows).
    p.listScroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.listScroll:SetPoint("TOPLEFT", 8, -52)
    p.listScroll:SetPoint("BOTTOMLEFT", 8, 8)
    p.listScroll:SetWidth(240)

    p.list = CreateFrame("Frame", nil, p.listScroll)
    p.list:SetSize(220, 1)  -- height grows as rows are added
    p.listScroll:SetScrollChild(p.list)
    p._rowButtons = {}      -- pool of reusable row buttons

    -- Right column: detail pane for the selected entry.
    p.detailScroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.detailScroll:SetPoint("TOPLEFT", p.listScroll, "TOPRIGHT", 18, 0)
    p.detailScroll:SetPoint("BOTTOMRIGHT", -28, 8)

    p.detail = CreateFrame("EditBox", nil, p.detailScroll)
    p.detail:SetMultiLine(true)
    p.detail:SetAutoFocus(false)
    p.detail:SetFontObject(ChatFontNormal)
    p.detail:SetWidth(320)
    p.detail:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    p.detailScroll:SetScrollChild(p.detail)
    p.detail:SetText("(select a module, then click a row)")

    return p
end

-- Open a popup showing every registered module name. Selecting one sets the
-- Browse panel's current module and refreshes the list.
function D.OpenBrowseModulePicker()
    if not panels or not panels.Browse then return end
    local p = panels.Browse

    -- Lazy-create the popup the first time.
    if not p.modPopup then
        local popup = CreateFrame("Frame", nil, p, "TooltipBorderedFrameTemplate")
        popup:SetFrameStrata("DIALOG")
        popup:SetSize(180, 200)
        popup:SetPoint("TOPLEFT", p.modBtn, "BOTTOMLEFT", 0, -2)
        popup:Hide()
        popup.scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
        popup.scroll:SetPoint("TOPLEFT", 6, -6)
        popup.scroll:SetPoint("BOTTOMRIGHT", -26, 6)
        popup.list = CreateFrame("Frame", nil, popup.scroll)
        popup.list:SetSize(150, 1)
        popup.scroll:SetScrollChild(popup.list)
        popup._buttons = {}
        p.modPopup = popup
    end

    local popup = p.modPopup
    if popup:IsShown() then popup:Hide(); return end

    -- Rebuild the popup contents fresh each open so newly-registered modules
    -- show up without a /reload.
    local names = {}
    for n in pairs(LibCodex.modules) do names[#names + 1] = n end
    table.sort(names)

    -- Recycle row buttons from the pool.
    for i = #names + 1, #popup._buttons do popup._buttons[i]:Hide() end
    for i, name in ipairs(names) do
        local btn = popup._buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, popup.list)
            btn:SetSize(150, 18)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            btn.text:SetPoint("LEFT", 4, 0)
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            popup._buttons[i] = btn
        end
        btn:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
        local mod = LibCodex.modules[name]
        local count = (mod and mod.Count and mod:Count()) or 0
        btn.text:SetText(string.format("%s  |cff888888(%d)|r", name, count))
        btn:SetScript("OnClick", function()
            p._modName = name
            p.modBtn:SetText("Module: " .. name)
            popup:Hide()
            D.RefreshBrowse()
        end)
        btn:Show()
    end
    popup.list:SetHeight(math.max(1, #names * 18))
    popup:Show()
end

-- Repopulate the result list for the current module + filter combination.
function D.RefreshBrowse()
    if not panels or not panels.Browse then return end
    local p = panels.Browse
    if not p._modName then
        p.count:SetText("Pick a module to start browsing.")
        return
    end
    local mod = LibCodex.modules[p._modName]
    if not mod then
        p.count:SetText("Module '" .. p._modName .. "' is not registered.")
        return
    end

    -- Compute the row set. With a filter we use :Search (which materializes
    -- matching lazy rows automatically). Without a filter we enumerate all
    -- keys and cap at BROWSE_LIMIT — full enumeration would blow up for
    -- modules with hundreds of thousands of rows.
    local rows
    local total
    if p._filter and p._filter ~= "" and mod.Search then
        local hits = mod:Search(p._filter)
        total = #hits
        rows = {}
        for i = 1, math.min(BROWSE_LIMIT, #hits) do
            local e = hits[i]
            rows[i] = { key = e.id or e[mod._keyField or "id"], entry = e }
        end
    else
        local keys = enumerateKeys(mod)
        total = #keys
        rows = {}
        for i = 1, math.min(BROWSE_LIMIT, #keys) do
            rows[i] = { key = keys[i], entry = nil }  -- entry loaded on click
        end
    end

    p.count:SetText(string.format("Showing %d of %d entries%s",
        #rows, total,
        total > BROWSE_LIMIT and "  |cffff8866(narrow with filter)|r" or ""))

    -- Recycle row buttons. Keep extras hidden rather than destroyed so we
    -- don't churn frames as the user filters in real time.
    for i = #rows + 1, #p._rowButtons do p._rowButtons[i]:Hide() end
    for i, row in ipairs(rows) do
        local btn = p._rowButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, p.list)
            btn:SetSize(220, BROWSE_ROW_HEIGHT)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.text:SetPoint("LEFT", 4, 0)
            btn.text:SetJustifyH("LEFT")
            btn.text:SetWidth(212)
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            p._rowButtons[i] = btn
        end
        btn:SetPoint("TOPLEFT", 0, -(i - 1) * BROWSE_ROW_HEIGHT)
        local entry = row.entry or mod:Get(row.key)
        local label = (entry and (entry.label or entry.name)) or "(no label)"
        btn.text:SetText(string.format("|cffaaaaaa[%s]|r %s",
            tostring(row.key), tostring(label)))
        btn:SetScript("OnClick", function() D.ShowBrowseDetail(row.key) end)
        btn:Show()
    end
    p.list:SetHeight(math.max(1, #rows * BROWSE_ROW_HEIGHT))
end

-- Render every field of the entry into the right-hand detail pane.
function D.ShowBrowseDetail(key)
    if not panels or not panels.Browse then return end
    local p = panels.Browse
    local mod = LibCodex.modules[p._modName]
    if not mod then return end
    local entry = mod:Get(key)
    if not entry then
        p.detail:SetText("(entry " .. tostring(key) .. " not found)")
        return
    end

    -- Sort field names: id first, then alphabetical, with internal _foo at end.
    local names = {}
    for k in pairs(entry) do names[#names + 1] = k end
    table.sort(names, function(a, b)
        if a == "id" then return true end
        if b == "id" then return false end
        local au = type(a) == "string" and a:sub(1, 1) == "_"
        local bu = type(b) == "string" and b:sub(1, 1) == "_"
        if au ~= bu then return not au end
        return tostring(a) < tostring(b)
    end)

    local lines = { string.format("%s [%s]", p._modName, tostring(key)), "" }
    for _, k in ipairs(names) do
        lines[#lines + 1] = string.format("%s = %s", tostring(k), formatValue(entry[k]))
    end
    p.detail:SetText(table.concat(lines, "\n"))
end

-- ----------------------------------------------------------------------------
-- Settings panel.
-- ----------------------------------------------------------------------------

local function buildSettingsPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    makeLabel(p, "Toggles (changes persist in LibCodexDB):", "GameFontHighlight"):SetPoint("TOPLEFT", 8, -4)

    p.echo = makeCheckbox(p, "Echo log to chat", function(on)
        if LibCodex.Log and LibCodex.Log.SetEcho then LibCodex.Log.SetEcho(on) end
    end)
    p.echo:SetPoint("TOPLEFT", 12, -32)

    p.verbose = makeCheckbox(p, "Runtime verbose mode (logs every capture)", function(on)
        if LibCodex.Runtime and LibCodex.Runtime.SetVerbose then
            LibCodex.Runtime.SetVerbose(on)
        end
    end)
    p.verbose:SetPoint("TOPLEFT", 12, -60)

    p.autoscan = makeCheckbox(p, "Auto-scan nameplates (every 5s)", function(on)
        if LibCodex.Runtime and LibCodex.Runtime.SetAutoScan then
            LibCodex.Runtime.SetAutoScan(on)
        end
    end)
    p.autoscan:SetPoint("TOPLEFT", 12, -88)

    p.friendly = makeButton(p, "Enable friendly NPC nameplates", 240, 22, function()
        if LibCodex.Runtime and LibCodex.Runtime.EnableFriendlyNameplates then
            local changed = LibCodex.Runtime.EnableFriendlyNameplates()
            out(changed and "|cffffd55a[Codex]|r Friendly nameplate CVars set." or "|cffffd55a[Codex]|r Already enabled.")
        end
    end)
    p.friendly:SetPoint("TOPLEFT", 12, -120)

    -- Reflect current state when shown.
    p:SetScript("OnShow", function()
        if LibCodex.Log and LibCodex.Log.IsEchoing then p.echo:SetChecked(LibCodex.Log.IsEchoing()) end
        if LibCodex.Runtime then
            p.verbose:SetChecked(LibCodex.Runtime.verbose and true or false)
            if LibCodex.Runtime.IsAutoScanning then
                p.autoscan:SetChecked(LibCodex.Runtime.IsAutoScanning())
            end
        end
    end)

    return p
end

-- ----------------------------------------------------------------------------
-- Actions panel: one-click triggers for the operational commands.
-- ----------------------------------------------------------------------------

local function buildActionsPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    makeLabel(p, "One-click actions:", "GameFontHighlight"):SetPoint("TOPLEFT", 8, -4)

    local y = -32
    local function addBtn(label, desc, fn)
        local b = makeButton(p, label, 200, 22, fn)
        b:SetPoint("TOPLEFT", 12, y)
        local d = makeLabel(p, desc, "GameFontNormalSmall")
        d:SetPoint("LEFT", b, "RIGHT", 12, 0)
        y = y - 26
    end

    addBtn("Run Manual Scan", "Sweep nameplates + bags + target/focus right now",
        function()
            if LibCodex.Runtime and LibCodex.Runtime.ScanNow then
                local r = LibCodex.Runtime.ScanNow()
                out(string.format("|cffffd55a[Codex]|r Scan: %d bag items, %d units, realms %d->%d",
                    r.bagItemsCaptured, #r.unitsRead, r.realmsBefore, r.realmsAfter))
            end
        end)

    addBtn("Force Save", "Flush current catalog into LibCodexDB now",
        function()
            LibCodex:_PersistSavedVariables()
            out("|cffffd55a[Codex]|r Forced save. /reload to flush to disk.")
        end)

    addBtn("Reload UI", "Standard /reload (writes SavedVariables to disk)",
        function() ReloadUI() end)

    addBtn("Open Log", "Show the dedicated log window",
        function() if LibCodex.Log then LibCodex.Log.Show() end end)

    addBtn("Clear Log", "Wipe the log window",
        function() if LibCodex.Log then LibCodex.Log.Clear() end end)

    addBtn("Refresh Stats", "Update the Stats tab",
        function() D.RefreshStats() end)

    return p
end

-- ----------------------------------------------------------------------------
-- Log panel: embedded scrolling message frame mirroring LibCodex.Log output.
-- Same buffer the standalone log window uses, so a copy/clear/echo here
-- affects both views.
-- ----------------------------------------------------------------------------

local function buildLogPanel(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetAllPoints()

    p.smf = CreateFrame("ScrollingMessageFrame", nil, p)
    p.smf:SetPoint("TOPLEFT", 8, -4)
    p.smf:SetPoint("BOTTOMRIGHT", -8, 32)
    p.smf:SetFontObject(GameFontHighlightSmall)
    p.smf:SetJustifyH("LEFT")
    p.smf:SetMaxLines(500)
    p.smf:SetFading(false)
    p.smf:SetHyperlinksEnabled(true)
    p.smf:EnableMouseWheel(true)
    p.smf:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
        else
            if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
        end
    end)

    p.clearBtn = makeButton(p, "Clear", 70, 22, function()
        if LibCodex.Log and LibCodex.Log.Clear then LibCodex.Log.Clear() end
        p.smf:Clear()
    end)
    p.clearBtn:SetPoint("BOTTOMLEFT", 8, 4)

    p.copyBtn = makeButton(p, "Copy", 70, 22, function()
        if LibCodex.Log and LibCodex.Log.OpenCopy then LibCodex.Log.OpenCopy() end
    end)
    p.copyBtn:SetPoint("LEFT", p.clearBtn, "RIGHT", 6, 0)

    p.bottomBtn = makeButton(p, "Newest", 80, 22, function() p.smf:ScrollToBottom() end)
    p.bottomBtn:SetPoint("BOTTOMRIGHT", -8, 4)

    p.popoutBtn = makeButton(p, "Pop out", 80, 22, function()
        if LibCodex.Log and LibCodex.Log.Show then LibCodex.Log.Show() end
    end)
    p.popoutBtn:SetPoint("RIGHT", p.bottomBtn, "LEFT", -6, 0)

    -- Hook LibCodex.Log.Print to also feed our embedded SMF whenever a
    -- new line lands. We chain the original via closure so the standalone
    -- log window keeps working too.
    if LibCodex.Log and LibCodex.Log.Print and not LibCodex.Log._dashboardHooked then
        local orig = LibCodex.Log.Print
        LibCodex.Log.Print = function(msg)
            orig(msg)
            if p and p.smf then
                local ts = (date and pcall(date, "%H:%M:%S")) and date("%H:%M:%S") or ""
                local line = (ts ~= "" and ("|cff888888[" .. ts .. "]|r ") or "") .. tostring(msg)
                p.smf:AddMessage(line)
            end
        end
        LibCodex.Log._dashboardHooked = true
    end

    return p
end

-- ----------------------------------------------------------------------------
-- Tabs.
-- ----------------------------------------------------------------------------

local TAB_NAMES = { "Stats", "Search", "Browse", "Where", "Settings", "Actions", "Log" }

local function selectTab(name)
    currentTab = name
    for n, panel in pairs(panels) do
        if panel then panel:SetShown(n == name) end
    end
    for n, tab in pairs(tabs) do
        if tab then
            -- Active tab: brighter background. Inactive: dimmer.
            tab:SetNormalFontObject(n == name and "GameFontHighlight" or "GameFontNormal")
        end
    end
    if name == "Stats" then D.RefreshStats() end
end

-- ----------------------------------------------------------------------------
-- Build the main frame.
-- ----------------------------------------------------------------------------

local function buildFrame()
    if frame or not CreateFrame then return frame end

    frame = CreateFrame("Frame", "LibCodexDashboard", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(640, 460)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
    frame.title:SetText("LibCodex Dashboard")

    -- Tab bar.
    tabs = {}
    panels = {}
    local tabBuilders = {
        Stats    = buildStatsPanel,
        Search   = buildSearchPanel,
        Browse   = buildBrowsePanel,
        Where    = buildWherePanel,
        Settings = buildSettingsPanel,
        Actions  = buildActionsPanel,
        Log      = buildLogPanel,
    }
    local panelHost = CreateFrame("Frame", nil, frame)
    panelHost:SetPoint("TOPLEFT", 8, -56)
    panelHost:SetPoint("BOTTOMRIGHT", -8, 32)

    -- Tabs: tighter stride so seven fit comfortably in the wider frame.
    local x = 8
    for _, name in ipairs(TAB_NAMES) do
        local tab = makeButton(frame, name, 84, 22, function() selectTab(name) end)
        tab:SetPoint("TOPLEFT", x, -28)
        tabs[name] = tab
        local panel = tabBuilders[name](panelHost)
        panel:Hide()
        panels[name] = panel
        x = x + 86
    end

    -- Footer: status text on the left, persistent action buttons on the right.
    -- The reload + save pair is always visible so the user can flush state and
    -- restart the UI without hunting through the Actions tab.
    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.status:SetPoint("BOTTOMLEFT", 12, 14)
    frame.status:SetText((LibCodex.VersionString and LibCodex:VersionString()) or "LibCodex")

    frame.reloadBtn = makeButton(frame, "Reload UI", 90, 22, function() ReloadUI() end)
    frame.reloadBtn:SetPoint("BOTTOMRIGHT", -10, 8)

    frame.saveBtn = makeButton(frame, "Save Now", 90, 22, function()
        LibCodex:_PersistSavedVariables()
        out("|cffffd55a[Codex]|r Forced save. Reload to flush to disk.")
    end)
    frame.saveBtn:SetPoint("RIGHT", frame.reloadBtn, "LEFT", -6, 0)

    selectTab("Stats")
    frame:Hide()
    return frame
end

-- Persist dashboard visibility across reloads. The flag lives in LibCodexDB
-- so it survives both /reload and full logout. Re-shown automatically at
-- PLAYER_LOGIN if the user had it open last session.
local function persistOpen(on)
    LibCodexDB = LibCodexDB or {}
    LibCodexDB.dashboardOpen = on and true or false
end

function D.Show()
    buildFrame()
    if frame then frame:Show(); persistOpen(true) end
end

function D.Hide()
    if frame then frame:Hide() end
    persistOpen(false)
end

function D.Toggle()
    buildFrame()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide(); persistOpen(false)
    else
        frame:Show(); persistOpen(true)
    end
end

-- Auto-restore at PLAYER_LOGIN. Defer briefly so other libs/addons finish
-- their own setup before we paint the window.
if CreateFrame then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if LibCodexDB and LibCodexDB.dashboardOpen then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, function() D.Show() end)
            else
                D.Show()
            end
        end
    end)
end
