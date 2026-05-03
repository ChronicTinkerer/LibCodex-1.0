-- LibCodex-1.0 / LibCodex-1.0.lua
-- A reusable, addon-agnostic catalog of WoW game data: NPCs, Items, Spells,
-- Talents, Quests, Zones, FlightPoints, Currencies, Reputations, Crafts,
-- Achievements, Pets, Mounts, etc., plus the small enums (Realms, Factions,
-- Classes, Races, Specs, Stats, Professions).
--
-- Hybrid load model:
--   1. Bundled seed (Data\*.lua) loaded by each module file at construction.
--   2. SavedVariables (LibCodexDB) restored at PLAYER_LOGIN; carries everything
--      we've seen across previous sessions.
--   3. Adapters (Adapters\*.lua) fed at PLAYER_LOGIN and continuously by event
--      hooks. Adapters can register at any time before PLAYER_LOGIN.
--
-- Consumer usage:
--   local LC = LibStub("LibCodex-1.0")
--   local entry = LC:NPCs():Get(207516)
--   for _, hit in ipairs(LC:Items():Search("rune", { quality=4 })) do ... end

local LIB_MAJOR = "LibCodex-1.0"
local LIB_MINOR = 1

assert(LibStub, LIB_MAJOR .. " requires LibStub.")
local LibCodex, oldMinor = LibStub:NewLibrary(LIB_MAJOR, LIB_MINOR)
if not LibCodex then return end  -- already loaded same-or-newer version

-- ============================================================================
-- Internal state. Persisted across upgrades by transferring through `oldMinor`.
-- ============================================================================
LibCodex.modules        = LibCodex.modules        or {}   -- name -> collection object
LibCodex.adapters       = LibCodex.adapters       or {}   -- name -> { fn = function(LC) end, ran = bool }
LibCodex.bundledData    = LibCodex.bundledData    or {}   -- module-name -> array of entries (loaded by Data files)
LibCodex.pendingHydrate = LibCodex.pendingHydrate or {}   -- module-name -> array of entries waiting for module to register
LibCodex.events         = LibCodex.events         or {}   -- callback registry

-- ============================================================================
-- Module registration. Called by each Modules\*.lua file as it loads. The
-- module file builds its collection object (using Modules\Common.lua) and
-- hands it back to the library here.
-- ============================================================================

-- Register a module (collection) under a name. Returns the registered object
-- so the module file can chain into setting public methods on it.
function LibCodex:RegisterModule(name, collection)
    assert(type(name) == "string" and name ~= "", "RegisterModule needs a name")
    assert(type(collection) == "table", "RegisterModule needs a collection table")
    self.modules[name] = collection

    -- Drain any bundled or pending entries that landed before the module was up.
    if self.pendingHydrate[name] then
        for _, e in ipairs(self.pendingHydrate[name]) do
            if collection.Add then collection:Add(e) end
        end
        self.pendingHydrate[name] = nil
    end
    if self.pendingTSV and self.pendingTSV[name] and collection._IngestTSV then
        for _, p in ipairs(self.pendingTSV[name]) do
            collection:_IngestTSV(p.columns, p.blob)
        end
        self.pendingTSV[name] = nil
    end
    if self.pendingRows and self.pendingRows[name] and collection._IngestRows then
        for _, p in ipairs(self.pendingRows[name]) do
            collection:_IngestRows(p.columns, p.rows)
        end
        self.pendingRows[name] = nil
    end

    return collection
end

-- Look up a module by name. Returns nil if not registered. Used by adapters
-- and by consumer addons through the typed accessors below.
function LibCodex:GetModule(name)
    return self.modules[name]
end

-- ============================================================================
-- Bundled seed feed. Data\*.lua files call this at file-load time, BEFORE
-- their module file may have run (depends on TOC order). We stash entries
-- until the module registers, then drain.
-- ============================================================================
function LibCodex:_FeedBundled(moduleName, entries)
    if type(entries) ~= "table" then return end
    local mod = self.modules[moduleName]
    if mod and mod.Add then
        for _, e in ipairs(entries) do
            -- Tag bundled entries with their source for provenance tracking.
            e.sources = e.sources or {}
            local seen = false
            for _, s in ipairs(e.sources) do if s == "bundled" then seen = true; break end end
            if not seen then table.insert(e.sources, "bundled") end
            mod:Add(e)
        end
    else
        -- Module not registered yet. Stash for later drain.
        self.pendingHydrate[moduleName] = self.pendingHydrate[moduleName] or {}
        for _, e in ipairs(entries) do
            table.insert(self.pendingHydrate[moduleName], e)
        end
    end
end

-- Bulk feed via tab-separated string blob. Preferred for large catalogs
-- (Items/Spells/Quests with thousands of rows).
--
--   columns: comma-separated string of field names, e.g. "id,label,quality,level"
--   blob   : multi-line tab-separated values; each line is one entry
--
-- The collection keeps the raw blob in memory and builds a small id->offset
-- index. Entries are lazily expanded into dict form only when accessed via
-- :Get(id), which keeps memory usage proportional to what you query rather
-- than the total catalog size.
function LibCodex:_FeedBundledTSV(moduleName, columns, blob)
    if type(columns) ~= "string" or type(blob) ~= "string" then return end
    local mod = self.modules[moduleName]
    if mod and mod._IngestTSV then
        mod:_IngestTSV(columns, blob)
    else
        self.pendingTSV = self.pendingTSV or {}
        self.pendingTSV[moduleName] = self.pendingTSV[moduleName] or {}
        table.insert(self.pendingTSV[moduleName], { columns = columns, blob = blob })
    end
end

-- Bulk feed via positional row arrays. The unified bundled format used by
-- the bake tool. Each row is an array of values matching the columns CSV
-- (column order). Values may be primitives or tables. Rows are stored as-is
-- and lazily expanded into entry dicts on :Get(id), keeping memory low.
--
--   columns: comma-separated string of field names, e.g. "id,label,quality"
--   rows   : array of arrays, each one row in column order
--
-- Example:
--   LibCodex:_FeedBundledRows("Items", "id,label,quality", {
--       { 12345, "Linen Cloth", 1 },
--       { 67890, "Frostmourne", 5 },
--   })
function LibCodex:_FeedBundledRows(moduleName, columns, rows)
    if type(columns) ~= "string" or type(rows) ~= "table" then return end
    local mod = self.modules[moduleName]
    if mod and mod._IngestRows then
        mod:_IngestRows(columns, rows)
    else
        self.pendingRows = self.pendingRows or {}
        self.pendingRows[moduleName] = self.pendingRows[moduleName] or {}
        table.insert(self.pendingRows[moduleName], { columns = columns, rows = rows })
    end
end

-- ============================================================================
-- Adapter registration. Adapters are functions of the form fn(LC) that push
-- entries into modules. They run once at PLAYER_LOGIN; some adapters also
-- register their own event hooks for continuous capture.
-- ============================================================================
function LibCodex:RegisterAdapter(name, fn)
    assert(type(name) == "string" and name ~= "", "RegisterAdapter needs a name")
    assert(type(fn) == "function", "RegisterAdapter needs a function")
    self.adapters[name] = { fn = fn, ran = false }
end

-- Run all unrun adapters. Safe to call multiple times. Adapters that need to
-- defer (e.g., wait for another addon) should re-register themselves on a
-- later event rather than stay un-ran here.
function LibCodex:RunAdapters()
    for _, ad in pairs(self.adapters) do
        if not ad.ran then
            local ok, err = pcall(ad.fn, self)
            ad.ran = true
            if not ok then
                -- Best-effort warning; most users won't see chat from a library load.
                local msg = "|cffff5555LibCodex:|r adapter error: " .. tostring(err)
                if print then print(msg) end
            end
        end
    end
end

-- ============================================================================
-- SavedVariables hydrate / persist. Called at PLAYER_LOGIN.
--   LibCodexDB schema:
--     LibCodexDB = {
--       version = 1,
--       modules = {
--         NPCs = { [id] = entry, ... },
--         Items = { [id] = entry, ... },
--         ...
--       },
--     }
-- ============================================================================
local SV_VERSION = 1

function LibCodex:_RestoreSavedVariables()
    if type(LibCodexDB) ~= "table" then
        LibCodexDB = { version = SV_VERSION, modules = {} }
        return
    end
    LibCodexDB.version = LibCodexDB.version or SV_VERSION
    LibCodexDB.modules = LibCodexDB.modules or {}
    for modName, entries in pairs(LibCodexDB.modules) do
        local mod = self.modules[modName]
        if mod and mod.Add then
            for _, e in pairs(entries) do
                mod:Add(e)
            end
        end
    end
end

-- Iterate every module and write its current contents into LibCodexDB.
-- Hooked to PLAYER_LOGOUT so we save once per session boundary.
function LibCodex:_PersistSavedVariables()
    LibCodexDB = LibCodexDB or { version = SV_VERSION, modules = {} }
    LibCodexDB.version = SV_VERSION
    LibCodexDB.modules = {}
    for name, mod in pairs(self.modules) do
        if mod.AllRaw then
            LibCodexDB.modules[name] = mod:AllRaw()
        end
    end
end

-- ============================================================================
-- Top-level typed accessors. Each is a one-line wrapper around GetModule for
-- callsite ergonomics: LC:NPCs() reads better than LC:GetModule("NPCs").
-- New modules should add their accessor here when registered.
-- ============================================================================
function LibCodex:NPCs()      return self.modules.NPCs end
function LibCodex:Items()     return self.modules.Items end
function LibCodex:GameObjects() return self.modules.GameObjects end
function LibCodex:Spells()    return self.modules.Spells end
function LibCodex:Talents()   return self.modules.Talents end
function LibCodex:Quests()    return self.modules.Quests end
function LibCodex:Zones()     return self.modules.Zones end
function LibCodex:FlightPoints() return self.modules.FlightPoints end
function LibCodex:Currencies() return self.modules.Currencies end
function LibCodex:Reputations() return self.modules.Reputations end
function LibCodex:Crafts()    return self.modules.Crafts end
function LibCodex:Achievements() return self.modules.Achievements end
function LibCodex:Pets()      return self.modules.Pets end
function LibCodex:Mounts()    return self.modules.Mounts end
function LibCodex:Toys()      return self.modules.Toys end
function LibCodex:Realms()    return self.modules.Realms end
function LibCodex:Classes()   return self.modules.Classes end
function LibCodex:Races()     return self.modules.Races end
function LibCodex:CreatureTypes() return self.modules.CreatureTypes end
function LibCodex:Factions()  return self.modules.Factions end
function LibCodex:Specs()     return self.modules.Specs end
function LibCodex:Stats()     return self.modules.Stats end
function LibCodex:Professions() return self.modules.Professions end
function LibCodex:Heirlooms() return self.modules.Heirlooms end
function LibCodex:Encounters() return self.modules.Encounters end
function LibCodex:Vignettes() return self.modules.Vignettes end
function LibCodex:Areas()     return self.modules.Areas end

-- ============================================================================
-- Diagnostic helpers exposed to consumers.
-- ============================================================================
function LibCodex:CountAll()
    local out = {}
    for name, mod in pairs(self.modules) do
        out[name] = (mod.Count and mod:Count()) or 0
    end
    return out
end

function LibCodex:VersionString()
    return string.format("%s v%d (modules:%d adapters:%d)",
        LIB_MAJOR, LIB_MINOR,
        (function() local n=0; for _ in pairs(self.modules)  do n=n+1 end; return n end)(),
        (function() local n=0; for _ in pairs(self.adapters) do n=n+1 end; return n end)())
end

-- ============================================================================
-- PLAYER_LOGIN bootstrap. Only register the event frame the FIRST time this
-- file loads (oldMinor == nil). Upgrades reuse the existing frame.
-- ============================================================================
if not oldMinor then
    if CreateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("PLAYER_LOGOUT")
        f:SetScript("OnEvent", function(_, evt)
            if evt == "PLAYER_LOGIN" then
                LibCodex:_RestoreSavedVariables()
                if LibCodex.Log and LibCodex.Log.LoadPrefs then
                    LibCodex.Log.LoadPrefs()
                end
                LibCodex:RunAdapters()
            elseif evt == "PLAYER_LOGOUT" then
                LibCodex:_PersistSavedVariables()
            end
        end)
        LibCodex._eventFrame = f
    end
end

-- Expose a global handle for very-old style consumers, but discourage use.
-- LibStub("LibCodex-1.0") is the supported entry point.
_G.LibCodex = LibCodex
