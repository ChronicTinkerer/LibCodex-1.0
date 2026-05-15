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
-- LIB_MINOR is a sequential integer build number bumped by release.ps1 on
-- every release pass (+1 per run). LibStub compares minors numerically and
-- keeps the higher value, so a newer release loaded by any consumer takes
-- precedence over older copies still embedded in other addons.
local LIB_MINOR = 9

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
-- Per-module LoadOnDemand companions. Each LibCodex module has its own
-- LoadOnDemand sibling addon named `LibCodex-1.0-<ModuleName>` that carries
-- ONLY that module's bundled Data\<Module>.lua. Splitting per-module keeps
-- the core library's bytecode constant pool tiny AND lets consumers pay only
-- for the modules they actually query (Vellum hits Quests; Forge_Codex hits
-- whatever the user opens; AddonProfiler-only sessions pay for nothing).
--
-- Auto-load mechanic: the collection factory's :Get() calls
-- LoadModule(self._name) on its very first miss for THAT module. Modules
-- that already have data (because some other consumer already triggered the
-- load, or because a runtime adapter pushed entries in) hit before reaching
-- the auto-load branch, so this only fires when data is genuinely absent.
--
-- LoadModule() is idempotent: a successful first call adds the module to
-- _loadedModules; subsequent calls return true immediately. A failed call
-- adds the module to _loadAttempts so we don't pound the LoadAddOn API on
-- every miss for a permanently-missing module.
--
-- Naming convention: addon name = "LibCodex-1.0-" .. moduleName
--     "Items"   -> LibCodex-1.0-Items
--     "Quests"  -> LibCodex-1.0-Quests
--     "NPCs"    -> LibCodex-1.0-NPCs
-- (case is preserved exactly, matching the module name registered via
-- RegisterModule and the Data\<Module>.lua filename convention.)
-- ============================================================================

LibCodex._loadedModules = LibCodex._loadedModules or {}   -- moduleName -> true
LibCodex._loadAttempts  = LibCodex._loadAttempts  or {}   -- moduleName -> true (any attempt, success or not)

-- Try to load the LibCodex-1.0-<ModuleName> companion addon. Returns true if
-- the addon is now available (whether we just loaded it or it was already
-- present). Returns false if it's missing, disabled, or unavailable.
-- Callers should treat false as "this module's bundled data not present;
-- the catalog still works for whatever runtime / SVs / Adapters populated".
function LibCodex:LoadModule(moduleName)
    if not moduleName or moduleName == "" then return false end
    if self._loadedModules[moduleName] then return true end
    if self._loadAttempts[moduleName]  then return self._loadedModules[moduleName] == true end
    self._loadAttempts[moduleName] = true

    local loadFn = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
    if not loadFn then return false end

    local addonName = "LibCodex-1.0-" .. moduleName
    local ok = loadFn(addonName)
    -- LoadAddOn return shape varies across clients: 1/true on success,
    -- nil + reason on failure. Cover both.
    if ok == 1 or ok == true then
        self._loadedModules[moduleName] = true
        return true
    end
    -- Fallback: some clients return nothing useful but the addon did load.
    -- Probe via IsAddOnLoaded.
    local CA = C_AddOns
    if CA and CA.IsAddOnLoaded and CA.IsAddOnLoaded(addonName) then
        self._loadedModules[moduleName] = true
        return true
    end
    return false
end

function LibCodex:IsModuleLoaded(moduleName)
    return self._loadedModules[moduleName] == true
end

-- Internal helper called by the collection factory on a :Get miss. Triggers
-- LoadModule for that module at most once per session; subsequent misses
-- skip the load. Returns true only when this call ACTUALLY loaded the addon
-- (so callers know to retry their lookup); returns false on
-- already-attempted-or-loaded.
function LibCodex:_TryLoadModule(moduleName)
    if not moduleName then return false end
    if self._loadAttempts[moduleName] then return false end
    return self:LoadModule(moduleName)
end

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
    if self.pendingLazyRows and self.pendingLazyRows[name] and collection._IngestLazyChunk then
        for _, p in ipairs(self.pendingLazyRows[name]) do
            collection:_IngestLazyChunk(p.columns, p.thunk)
        end
        self.pendingLazyRows[name] = nil
    end
    if self.pendingV2Rows and self.pendingV2Rows[name] and collection._IngestV2Chunk then
        for _, p in ipairs(self.pendingV2Rows[name]) do
            collection:_IngestV2Chunk(p.schemaVersion, p.build, p.thunk)
        end
        self.pendingV2Rows[name] = nil
    end
    if self.pendingV2Deltas and self.pendingV2Deltas[name] and collection._IngestV2Delta then
        for _, p in ipairs(self.pendingV2Deltas[name]) do
            collection:_IngestV2Delta(p.schemaVersion, p.deltaToc, p.thunk)
        end
        self.pendingV2Deltas[name] = nil
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

-- Lazy variant: instead of taking the rows table directly, take a thunk
-- (zero-arg function) that returns the rows table on demand. The library
-- stores the thunk and only invokes it when the consumer actually queries
-- the module via :Get / :Search / :All / :Add. Modules a consumer never
-- touches pay zero row-table memory cost.
--
-- Usage from bake-emitted Data files:
--   LibCodex:_FeedBundledRowsLazy("Spells", "id,label,icon", function() return {
--       {1, "Spell 1", "icon1"},
--       -- ...8000 rows in this chunk...
--   } end)
--
-- Why this works: in Lua, a function definition compiles to a Proto object
-- whose constants pool holds the literal strings/numbers. The TABLE itself
-- (and the per-row sub-tables) is only constructed when the function body
-- runs. So wrapping the constructor in a function defers the dominant
-- memory cost (per-table headers, hash structures, array storage) until
-- materialization. String constants stay around regardless because Lua
-- interns them at parse time.
function LibCodex:_FeedBundledRowsLazy(moduleName, columns, thunk)
    if type(columns) ~= "string" or type(thunk) ~= "function" then return end
    local mod = self.modules[moduleName]
    if mod and mod._IngestLazyChunk then
        mod:_IngestLazyChunk(columns, thunk)
    else
        self.pendingLazyRows = self.pendingLazyRows or {}
        self.pendingLazyRows[moduleName] = self.pendingLazyRows[moduleName] or {}
        table.insert(self.pendingLazyRows[moduleName], { columns = columns, thunk = thunk })
    end
end

-- v2-format ingest. Modules emitted by bake_v2 carry positional rows with
-- Z85-encoded location strings instead of the legacy column-named form.
-- Format spec: see .dev/tools/bake_v2/ and the LibCodex format-v2 design memo.
--
-- Signature:
--   LibCodex:_FeedBundledRowsV2(moduleName, schemaVersion, build, thunk)
--
-- thunk is a zero-arg function returning the chunk's row table (same lazy
-- pattern as _FeedBundledRowsLazy: deferred materialization). Each call
-- represents one chunk; multi-chunk modules call this multiple times with
-- the same schemaVersion + build.
--
-- Schema-version handshake:
--   * if schemaVersion > _READER_MAX_KNOWN_V: reader is too old, log + drop.
--   * if schemaVersion < _READER_MIN_SUPPORTED_V: bundle is too old, log + drop.
--   * else dispatch to the module's :_IngestV2Chunk if registered, else
--     queue under pendingV2Rows for ingestion when the module registers.
LibCodex._READER_MAX_KNOWN_V    = LibCodex._READER_MAX_KNOWN_V    or 1
LibCodex._READER_MIN_SUPPORTED_V = LibCodex._READER_MIN_SUPPORTED_V or 1
LibCodex._errorRing  = LibCodex._errorRing  or {}
LibCodex._errorRingI = LibCodex._errorRingI or 0
local _ERROR_RING_CAP = 100

function LibCodex:_LogError(scope, moduleName, message)
    self._errorRingI = (self._errorRingI % _ERROR_RING_CAP) + 1
    self._errorRing[self._errorRingI] = {
        time = (time and time()) or 0,
        scope = scope,
        module = moduleName,
        message = message,
    }
end

function LibCodex:GetErrors()
    local out = {}
    for i = 1, _ERROR_RING_CAP do
        local e = self._errorRing[i]
        if e then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.time or 0) < (b.time or 0) end)
    return out
end

function LibCodex:ClearErrors()
    for k in pairs(self._errorRing) do self._errorRing[k] = nil end
    self._errorRingI = 0
end

function LibCodex:_FeedBundledRowsV2(moduleName, schemaVersion, build, thunk)
    if type(moduleName) ~= "string"
        or type(schemaVersion) ~= "number"
        or type(build) ~= "number"
        or type(thunk) ~= "function"
    then
        return
    end

    -- Schema-version handshake. If the bundle's _V is outside our supported
    -- range, log a clear actionable error and drop the chunk; the module's
    -- queries will return nil for missing IDs rather than producing wrong
    -- values from a mis-decoded format.
    if schemaVersion > self._READER_MAX_KNOWN_V then
        self:_LogError(
            "module", moduleName,
            string.format(
                "module schema _V=%d is newer than reader supports (max %d). Update LibCodex.",
                schemaVersion, self._READER_MAX_KNOWN_V
            )
        )
        return
    end
    if schemaVersion < self._READER_MIN_SUPPORTED_V then
        self:_LogError(
            "module", moduleName,
            string.format(
                "module schema _V=%d is older than reader supports (min %d). Re-bake required.",
                schemaVersion, self._READER_MIN_SUPPORTED_V
            )
        )
        return
    end

    local mod = self.modules[moduleName]
    if mod and mod._IngestV2Chunk then
        mod:_IngestV2Chunk(schemaVersion, build, thunk)
    else
        self.pendingV2Rows = self.pendingV2Rows or {}
        self.pendingV2Rows[moduleName] = self.pendingV2Rows[moduleName] or {}
        table.insert(self.pendingV2Rows[moduleName], {
            schemaVersion = schemaVersion,
            build = build,
            thunk = thunk,
        })
    end
end

-- v2 build delta. Phase 1.5 build-compatibility table: bake_v2 emits one
-- delta per future TOC version it has data for. The reader applies any
-- delta whose deltaToc <= GetBuildInfo() tocVersion in ascending order,
-- after base chunks have been materialized. Delta thunks return a table:
--   { [questID] = positional v2 row, ..., _removed = {ids...} }
function LibCodex:_FeedBundledV2Delta(moduleName, schemaVersion, deltaToc, thunk)
    if type(moduleName) ~= "string"
        or type(schemaVersion) ~= "number"
        or type(deltaToc) ~= "number"
        or type(thunk) ~= "function"
    then
        return
    end

    -- Same schema-version handshake as _FeedBundledRowsV2: bail loudly if
    -- the bundle is outside the reader's supported range.
    if schemaVersion > self._READER_MAX_KNOWN_V then
        self:_LogError(
            "module", moduleName,
            string.format(
                "delta schema _V=%d is newer than reader supports (max %d). Update LibCodex.",
                schemaVersion, self._READER_MAX_KNOWN_V
            )
        )
        return
    end
    if schemaVersion < self._READER_MIN_SUPPORTED_V then
        self:_LogError(
            "module", moduleName,
            string.format(
                "delta schema _V=%d is older than reader supports (min %d). Re-bake required.",
                schemaVersion, self._READER_MIN_SUPPORTED_V
            )
        )
        return
    end

    local mod = self.modules[moduleName]
    if mod and mod._IngestV2Delta then
        mod:_IngestV2Delta(schemaVersion, deltaToc, thunk)
    else
        self.pendingV2Deltas = self.pendingV2Deltas or {}
        self.pendingV2Deltas[moduleName] = self.pendingV2Deltas[moduleName] or {}
        table.insert(self.pendingV2Deltas[moduleName], {
            schemaVersion = schemaVersion,
            deltaToc = deltaToc,
            thunk = thunk,
        })
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
-- DEPRECATED: reputations were merged into the unified Factions module.
-- LC:Reputations() now returns the Factions module for back-compat. Filter
-- with :ByKind("reputation") if you only want the rep-faction subset.
function LibCodex:Reputations() return self.modules.Factions end
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
function LibCodex:Difficulty() return self.modules.Difficulty end
function LibCodex:Holidays()  return self.modules.Holidays end
function LibCodex:QuestPOI()  return self.modules.QuestPOI end
function LibCodex:PvpTalents() return self.modules.PvpTalents end
function LibCodex:Enchants() return self.modules.Enchants end
function LibCodex:ItemSets() return self.modules.ItemSets end
function LibCodex:TradeSkillCategories() return self.modules.TradeSkillCategories end
function LibCodex:TransmogSets() return self.modules.TransmogSets end
function LibCodex:LFGDungeons()  return self.modules.LFGDungeons end
function LibCodex:Battlemasters() return self.modules.Battlemasters end
function LibCodex:Scenarios()    return self.modules.Scenarios end
function LibCodex:GroupFinder()  return self.modules.GroupFinder end
function LibCodex:BattlePetAbilities() return self.modules.BattlePetAbilities end
function LibCodex:CustomizationOptions() return self.modules.CustomizationOptions end
function LibCodex:CustomizationChoices() return self.modules.CustomizationChoices end
function LibCodex:TransmogIllusions() return self.modules.TransmogIllusions end
function LibCodex:AreaTriggers() return self.modules.AreaTriggers end
function LibCodex:PlayerConditions() return self.modules.PlayerConditions end
function LibCodex:AreaPOI()         return self.modules.AreaPOI end
function LibCodex:WMOAreaTables()   return self.modules.WMOAreaTables end
function LibCodex:TaxiPaths()       return self.modules.TaxiPaths end
function LibCodex:DungeonEncounters() return self.modules.DungeonEncounters end
function LibCodex:ItemAppearances() return self.modules.ItemAppearances end
function LibCodex:ItemModifiedAppearances() return self.modules.ItemModifiedAppearances end
function LibCodex:ItemBonuses()    return self.modules.ItemBonuses end
function LibCodex:ItemEffects()    return self.modules.ItemEffects end
function LibCodex:SpellChargeCategories() return self.modules.SpellChargeCategories end
function LibCodex:SpellMechanics()  return self.modules.SpellMechanics end
function LibCodex:SpellCooldowns()  return self.modules.SpellCooldowns end
function LibCodex:SpellCastTimes()  return self.modules.SpellCastTimes end
function LibCodex:SpellPower()      return self.modules.SpellPower end
function LibCodex:SpellRanges()     return self.modules.SpellRanges end
function LibCodex:SpellDurations()  return self.modules.SpellDurations end
function LibCodex:Glyphs()          return self.modules.Glyphs end
function LibCodex:AchievementCategories() return self.modules.AchievementCategories end
function LibCodex:FriendshipReputations() return self.modules.FriendshipReputations end
function LibCodex:Regions()         return self.modules.Regions end
function LibCodex:Languages()       return self.modules.Languages end
function LibCodex:ChatChannels()    return self.modules.ChatChannels end
function LibCodex:Maps()            return self.modules.Maps end
function LibCodex:MapDifficulties() return self.modules.MapDifficulties end
function LibCodex:EncounterCreatures() return self.modules.EncounterCreatures end
function LibCodex:EncounterSections()  return self.modules.EncounterSections end
function LibCodex:SkillRaceClass()  return self.modules.SkillRaceClass end
function LibCodex:GossipOptions()   return self.modules.GossipOptions end
function LibCodex:Movies()          return self.modules.Movies end
function LibCodex:Cinematics()      return self.modules.Cinematics end

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
    return string.format("%s v%s (modules:%d adapters:%d)",
        LIB_MAJOR, tostring(LIB_MINOR),
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
