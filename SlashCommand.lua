-- LibCodex-1.0 / SlashCommand.lua
-- /codex slash command suite for in-game introspection. Useful for confirming
-- that runtime capture is actually firing, debugging missing entries, and
-- inspecting individual records without opening SavedVariables.

local LibCodex = LibStub("LibCodex-1.0")

-- ----------------------------------------------------------------------------
-- Output helpers. Route through LibCodex.Log when present so commands feed
-- the dedicated window AND (optionally) chat. Falls back to bare print() if
-- the log module isn't loaded for any reason.
-- ----------------------------------------------------------------------------
local PREFIX = "|cffffd55a[Codex]|r "
local function logLine(s)
    if LibCodex.Log and LibCodex.Log.Print then
        LibCodex.Log.Print(s)
    else
        print(s)
    end
end
local function out(msg)  logLine(PREFIX .. tostring(msg)) end
local function line(msg) logLine(tostring(msg)) end

-- Iterate every entry (keyed + extras) across one module; calls fn(entry).
local function forEachEntry(mod, fn)
    if not mod then return end
    if mod.AllRaw then
        for _, e in pairs(mod:AllRaw()) do fn(e) end
    end
    if mod._extras then
        for _, e in ipairs(mod._extras) do fn(e) end
    end
end

-- ----------------------------------------------------------------------------
-- /codex stats — per-module counts broken down by source.
-- ----------------------------------------------------------------------------
local function cmdStats()
    out("Stats by module (source breakdown):")
    -- Collect into a sortable list so output is stable.
    local rows = {}
    for name, mod in pairs(LibCodex.modules) do
        local bySource = {}
        local total = 0
        forEachEntry(mod, function(e)
            total = total + 1
            if type(e.sources) == "table" and #e.sources > 0 then
                for _, s in ipairs(e.sources) do
                    bySource[s] = (bySource[s] or 0) + 1
                end
            else
                bySource["(no source)"] = (bySource["(no source)"] or 0) + 1
            end
        end)
        rows[#rows + 1] = { name = name, total = total, bySource = bySource }
    end
    table.sort(rows, function(a, b) return a.name < b.name end)

    for _, r in ipairs(rows) do
        local parts = {}
        local sourceNames = {}
        for s, _ in pairs(r.bySource) do sourceNames[#sourceNames + 1] = s end
        table.sort(sourceNames)
        for _, s in ipairs(sourceNames) do
            parts[#parts + 1] = string.format("%s:%d", s, r.bySource[s])
        end
        line(string.format("  %-14s total:%-5d  %s", r.name, r.total, table.concat(parts, "  ")))
    end
end

-- ----------------------------------------------------------------------------
-- /codex info <id> — dump every field of an entry across modules.
-- ----------------------------------------------------------------------------
local function dumpValue(v, indent)
    indent = indent or "    "
    if type(v) ~= "table" then return tostring(v) end
    if next(v) == nil then return "{}" end
    local parts = {}
    for k, val in pairs(v) do
        local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
        parts[#parts + 1] = string.format("%s%s = %s", indent, key, dumpValue(val, indent .. "  "))
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent:sub(3) .. "}"
end

local function cmdInfo(rest)
    local id = tonumber(rest)
    if not id then
        out("Usage: /codex info <numeric id>")
        return
    end
    local hits = 0
    for name, mod in pairs(LibCodex.modules) do
        local e = mod.Get and mod:Get(id)
        if e then
            hits = hits + 1
            out(string.format("%s[%s]:", name, tostring(id)))
            line(dumpValue(e, "  "))
        end
    end
    if hits == 0 then out("No entry with id " .. id .. " in any module.") end
end

-- ----------------------------------------------------------------------------
-- /codex search <text> — list matching entries with source tags.
-- ----------------------------------------------------------------------------
local function cmdSearch(rest)
    if not rest or rest == "" then out("Usage: /codex search <text>") return end
    local total = 0
    for name, mod in pairs(LibCodex.modules) do
        if mod.Search then
            local hits = mod:Search(rest)
            if #hits > 0 then
                out(string.format("%s (%d matches):", name, #hits))
                local shown = 0
                for _, e in ipairs(hits) do
                    if shown >= 10 then
                        line("  ... " .. (#hits - 10) .. " more (refine query to see all)")
                        break
                    end
                    local srcs = e.sources and table.concat(e.sources, ",") or "?"
                    line(string.format("  [%s] %s  |cff888888(src:%s)|r",
                        tostring(e.id or "?"), tostring(e.label or "?"), srcs))
                    shown = shown + 1
                    total = total + 1
                end
            end
        end
    end
    if total == 0 then out("No matches for \"" .. rest .. "\".") end
end

-- ----------------------------------------------------------------------------
-- /codex sources <name> — list entries that include a given source tag.
-- ----------------------------------------------------------------------------
local function cmdSources(rest)
    if not rest or rest == "" then
        -- No arg: list every source tag we've seen, with counts across all modules.
        out("Known source tags across all modules:")
        local all = {}
        for _, mod in pairs(LibCodex.modules) do
            forEachEntry(mod, function(e)
                if type(e.sources) == "table" then
                    for _, s in ipairs(e.sources) do
                        all[s] = (all[s] or 0) + 1
                    end
                end
            end)
        end
        local names = {}
        for s, _ in pairs(all) do names[#names + 1] = s end
        table.sort(names)
        if #names == 0 then line("  (none captured yet)") end
        for _, s in ipairs(names) do
            line(string.format("  %-12s %d entries", s, all[s]))
        end
        return
    end

    local target = rest:match("^%s*(%S+)")
    out(string.format("Entries tagged with source \"%s\":", target))
    local total = 0
    for modName, mod in pairs(LibCodex.modules) do
        local hits = {}
        forEachEntry(mod, function(e)
            if type(e.sources) == "table" then
                for _, s in ipairs(e.sources) do
                    if s == target then hits[#hits + 1] = e; return end
                end
            end
        end)
        if #hits > 0 then
            line(string.format("  %s: %d", modName, #hits))
            local shown = 0
            for _, e in ipairs(hits) do
                if shown >= 5 then
                    line("    ... " .. (#hits - 5) .. " more")
                    break
                end
                line(string.format("    [%s] %s", tostring(e.id or "?"), tostring(e.label or "?")))
                shown = shown + 1
            end
            total = total + #hits
        end
    end
    if total == 0 then line("  (no entries carry this source)") end
end

-- ----------------------------------------------------------------------------
-- /codex debug — adapter and event diagnostics.
-- ----------------------------------------------------------------------------
local function cmdDebug()
    out(LibCodex:VersionString())
    out("Adapters:")
    local names = {}
    for n, _ in pairs(LibCodex.adapters) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
        local a = LibCodex.adapters[n]
        line(string.format("  %-12s ran=%s", n, tostring(a.ran)))
    end
    out("SavedVariables:")
    if type(LibCodexDB) == "table" then
        local mods = LibCodexDB.modules or {}
        local n = 0
        for _, _ in pairs(mods) do n = n + 1 end
        line(string.format("  LibCodexDB.modules has %d module entries (last save).", n))
    else
        line("  LibCodexDB not yet populated. (Saves on /reload or logout.)")
    end
    -- Show what events Runtime adapter relies on, so user can sanity-check.
    out("Runtime adapter listens for:")
    line("  NAME_PLATE_UNIT_ADDED, UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED,")
    line("  PLAYER_FOCUS_CHANGED, GET_ITEM_INFO_RECEIVED, BAG_UPDATE_DELAYED,")
    line("  AUTO_COMPLETE_ACCOUNT_LIST_UPDATED.")
    line("  Mouseover/target/focus an NPC, or open your bags, to trigger captures.")
end

-- ----------------------------------------------------------------------------
-- /codex save — force-write SavedVariables NOW (without waiting for logout).
-- Useful for confirming runtime capture is working.
-- ----------------------------------------------------------------------------
local function cmdSave()
    LibCodex:_PersistSavedVariables()
    out("Forced save. /reload to flush LibCodexDB to disk.")
end

local function cmdScan()
    if not (LibCodex.Runtime and LibCodex.Runtime.ScanNow) then
        out("Runtime adapter not loaded.")
        return
    end
    out("Manual scan triggered:")
    local r = LibCodex.Runtime.ScanNow()
    line(string.format("  C_Container API present: %s   C_Map API present: %s",
        tostring(r.cContainerOK), tostring(r.cMapOK)))
    line(string.format("  Bag slots scanned: %d   items captured: %d",
        r.bagSlotsSeen, r.bagItemsCaptured))
    if #r.unitsRead == 0 then
        line("  Units read: none (target/mouseover/focus all empty or were players)")
    else
        for _, u in ipairs(r.unitsRead) do
            line(string.format("  Unit '%s' captured npcID %d", u.unit, u.id))
        end
    end
    line(string.format("  Realms: %d -> %d", r.realmsBefore, r.realmsAfter))
end

local function cmdVerbose(rest)
    if not (LibCodex.Runtime and LibCodex.Runtime.SetVerbose) then
        out("Runtime adapter not loaded.")
        return
    end
    local sub = (rest or ""):lower():match("^%s*(%S*)") or ""
    if sub == "on"  then LibCodex.Runtime.SetVerbose(true);  out("Runtime verbose: ON  (every capture is logged).")
    elseif sub == "off" then LibCodex.Runtime.SetVerbose(false); out("Runtime verbose: OFF.")
    elseif sub == "" then
        local cur = LibCodex.Runtime.verbose
        out(string.format("Runtime verbose is currently %s. Use 'on' or 'off'.",
            cur and "ON" or "OFF"))
    else out("Usage: /codex verbose [on|off]") end
end

local function cmdAuto(rest)
    if not (LibCodex.Runtime and LibCodex.Runtime.SetAutoScan) then
        out("Runtime adapter not loaded.")
        return
    end
    local sub, num = (rest or ""):lower():match("^%s*(%S*)%s*(%S*)")
    sub = sub or ""
    if sub == "" then
        out(string.format("Auto-scan is %s. Interval: %ds.",
            LibCodex.Runtime.IsAutoScanning() and "ON" or "OFF",
            LibCodexDB and LibCodexDB.autoScanInterval or 5))
        line("  Subcommands: on [N], off, enable-friendly")
    elseif sub == "on" then
        local n = tonumber(num)
        LibCodex.Runtime.SetAutoScan(true, n)
        out(string.format("Auto-scan ON every %ds. Walks every visible nameplate + boss frames + party pets.",
            LibCodexDB.autoScanInterval))
    elseif sub == "off" then
        LibCodex.Runtime.SetAutoScan(false)
        out("Auto-scan OFF.")
    elseif sub == "enable-friendly" or sub == "friendly" then
        if LibCodex.Runtime.EnableFriendlyNameplates() then
            out("Friendly-NPC nameplates ENABLED. Vendors/bankers/quest-givers will now show nameplates and get auto-captured.")
        else
            out("Friendly-NPC nameplate CVars were already enabled (or SetCVar unavailable).")
        end
    else
        out("Usage: /codex auto [on|off N|enable-friendly]")
    end
end

local function cmdWhere(rest)
    local id = tonumber(rest)
    if not id then
        out("Usage: /codex where <itemID> - lists every NPC and game object you've looted this item from.")
        return
    end
    local Items = LibCodex:Items()
    if not Items then out("Items module not loaded.") return end
    local entry = Items:Get(id)
    if not entry then out("Item " .. id .. " is not in the catalog yet.") return end
    out(string.format("Sources for [%d] %s:", id, tostring(entry.label or "?")))
    local sources = Items:GetDropSources(id)
    if #sources == 0 then
        line("  No drop history yet. Loot the item once and run /codex where again.")
        return
    end
    for _, s in ipairs(sources) do
        line(string.format("  %s [%d] %s  - looted %dx",
            s.kind or "?", s.sourceID or 0, tostring(s.sourceLabel or "?"), s.count or 0))
        if s.locations then
            for _, loc in ipairs(s.locations) do
                line(string.format("      map %d at (%.2f, %.2f)  x%d",
                    loc.mapID or 0, loc.x or 0, loc.y or 0, loc.count or 1))
            end
        end
    end
end

local function cmdLog(rest)
    if not LibCodex.Log then out("Log module not loaded.") return end
    local sub = (rest or ""):lower():match("^%s*(%S*)") or ""
    if     sub == ""      then LibCodex.Log.Toggle()
    elseif sub == "show"  then LibCodex.Log.Show()
    elseif sub == "hide"  then LibCodex.Log.Hide()
    elseif sub == "clear" then LibCodex.Log.Clear();        out("Log cleared.")
    elseif sub == "copy"  then LibCodex.Log.OpenCopy()
    elseif sub == "on"    then LibCodex.Log.SetEcho(true);  out("Log: chat echo ON.")
    elseif sub == "off"   then LibCodex.Log.SetEcho(false); out("Log: chat echo OFF (window only).")
    else out("Usage: /codex log [show|hide|clear|copy|on|off]")
    end
end

local function cmdHelp()
    out("Commands:")
    line("  /codex                 - this help")
    line("  /codex stats           - per-module counts broken down by source")
    line("  /codex info <id>       - dump full entry across all modules")
    line("  /codex search <text>   - list matching entries with source tags")
    line("  /codex sources         - list every source tag seen, with counts")
    line("  /codex sources <name>  - list entries tagged with that source")
    line("  /codex debug           - adapter + SavedVariables diagnostics")
    line("  /codex save            - force-persist to LibCodexDB now")
    line("  /codex scan            - manually trigger a runtime scan and report counts")
    line("  /codex auto [on|off N|enable-friendly] - auto-scan controls / enable friendly nameplates")
    line("  /codex where <itemID>  - list every NPC/object you've looted this item from")
    line("  /codex verbose [on|off]- log every capture to the log window")
    line("  /codex log [...]       - show|hide|clear|copy|on|off the log window")
    line("  /codex perf [Module]   - measure lazy-load memory footprint (no arg = summary)")
    line("  /codex gui             - open the GUI dashboard (no slash commands needed)")
end

-- ----------------------------------------------------------------------------
-- /codex perf <ModuleName>
-- Measures the Lua memory delta when a module's lazy chunks materialize.
-- Real-world validation that lazy loading actually saves what we claim.
--
--   /codex perf Spells       -- shows: lazy chunks pending, memory before,
--                               forces ExpandAll, memory after, delta
--   /codex perf              -- summary across every module: lazy-pending count
--                               and entries materialized so far
-- ----------------------------------------------------------------------------
local function cmdPerf(arg)
    local target = (arg or ""):match("^%s*(.-)%s*$")

    if target == "" then
        -- Summary mode: per-module materialization status.
        out("Per-module memory state (no materialization triggered):")
        local rows = {}
        for name, mod in pairs(LibCodex.modules) do
            local pending = (mod._lazyChunks and #mod._lazyChunks) or 0
            local materialized = 0
            if mod._entries then
                for _ in pairs(mod._entries) do materialized = materialized + 1 end
            end
            local indexed = 0
            if mod._rowIndex then
                for _ in pairs(mod._rowIndex) do indexed = indexed + 1 end
            end
            rows[#rows + 1] = {
                name = name, pending = pending,
                materialized = materialized, indexed = indexed,
            }
        end
        table.sort(rows, function(a, b) return a.name < b.name end)
        for _, r in ipairs(rows) do
            local tag = (r.pending > 0) and " |cffaaaaaa[lazy]|r" or ""
            line(string.format("  %-26s pending:%-3d  materialized:%-6d  indexed:%-6d%s",
                r.name, r.pending, r.materialized, r.indexed, tag))
        end
        local total_lua_kb = collectgarbage and collectgarbage("count") or -1
        if total_lua_kb >= 0 then
            line(string.format("  Total Lua memory in this addon's environment: %.1f KB",
                total_lua_kb))
        end
        line("Run `/codex perf <ModuleName>` to materialize one and measure the delta.")
        return
    end

    -- Targeted mode: force-materialize one module and report memory delta.
    local mod = LibCodex.modules[target]
    if not mod then
        out("Module '" .. target .. "' not found. Try /codex stats to see registered modules.")
        return
    end

    if not collectgarbage then
        out("collectgarbage() unavailable in this environment; can't measure memory.")
        return
    end

    -- Snapshot before. Force a full GC so we measure live data, not garbage.
    collectgarbage("collect")
    local memBefore = collectgarbage("count")
    local pendingBefore = (mod._lazyChunks and #mod._lazyChunks) or 0
    local entriesBefore = 0
    if mod._entries then
        for _ in pairs(mod._entries) do entriesBefore = entriesBefore + 1 end
    end
    local indexedBefore = 0
    if mod._rowIndex then
        for _ in pairs(mod._rowIndex) do indexedBefore = indexedBefore + 1 end
    end

    -- Materialize everything: drains lazy chunks, expands every row into a
    -- dict entry. Worst-case memory cost; real-world consumers usually pay
    -- much less because they only :Get the entries they need.
    if mod.ExpandAll then
        mod:ExpandAll()
    end

    -- Snapshot after.
    collectgarbage("collect")
    local memAfter = collectgarbage("count")
    local entriesAfter = 0
    if mod._entries then
        for _ in pairs(mod._entries) do entriesAfter = entriesAfter + 1 end
    end

    local delta = memAfter - memBefore
    out(string.format("|cffd0a0ff%s perf:|r", target))
    line(string.format("  lazy chunks pending: %d -> 0", pendingBefore))
    line(string.format("  indexed (lazy rows): %d -> 0", indexedBefore))
    line(string.format("  materialized dict entries: %d -> %d (+%d)",
        entriesBefore, entriesAfter, entriesAfter - entriesBefore))
    line(string.format("  Lua memory: %.1f KB -> %.1f KB  (%s%.1f KB)",
        memBefore, memAfter, delta >= 0 and "+" or "", delta))
    if entriesAfter > entriesBefore then
        local newEntries = entriesAfter - entriesBefore
        line(string.format("  cost per new entry (avg): %.2f KB",
            delta / newEntries))
    end
end

-- ----------------------------------------------------------------------------
-- Dispatch.
-- ----------------------------------------------------------------------------
local function dispatch(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""
    if     cmd == ""        then cmdHelp()
    elseif cmd == "stats"   then cmdStats()
    elseif cmd == "info"    then cmdInfo(rest)
    elseif cmd == "search"  then cmdSearch(rest)
    elseif cmd == "sources" then cmdSources(rest)
    elseif cmd == "debug"   then cmdDebug()
    elseif cmd == "save"    then cmdSave()
    elseif cmd == "scan"    then cmdScan()
    elseif cmd == "auto"    then cmdAuto(rest)
    elseif cmd == "where"   then cmdWhere(rest)
    elseif cmd == "verbose" then cmdVerbose(rest)
    elseif cmd == "log"     then cmdLog(rest)
    elseif cmd == "perf"    then cmdPerf(rest)
    elseif cmd == "gui" or cmd == "dashboard" or cmd == "panel" then
        if LibCodex.Dashboard and LibCodex.Dashboard.Toggle then
            LibCodex.Dashboard.Toggle()
        else
            out("Dashboard not loaded.")
        end
    elseif cmd == "help" or cmd == "?" then cmdHelp()
    else
        out("Unknown subcommand: " .. cmd)
        cmdHelp()
    end
end

-- Register slash commands. Only when running inside WoW.
if SLASH_LIBCODEX1 == nil and _G.SlashCmdList then
    SLASH_LIBCODEX1 = "/codex"
    SLASH_LIBCODEX2 = "/lc"
    _G.SlashCmdList["LIBCODEX"] = dispatch
end

-- Also expose programmatically so other addons (or tests) can trigger commands.
LibCodex.SlashCommand = { Dispatch = dispatch }
