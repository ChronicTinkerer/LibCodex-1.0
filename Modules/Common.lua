-- LibCodex-1.0 / Modules / Common.lua
-- Reusable id-keyed collection. Every catalog and enum module is built from
-- this factory. Provides a uniform :Get / :Search / :Add / :All / :Count API
-- so consumers learn one shape and reuse it across NPCs, Items, Spells, etc.
--
-- Usage from a module file:
--   local CC = LibCodex.CollectionFactory
--   local NPCs = CC.New("NPCs", { searchFields = { "label", "zone", "title", "notes" } })
--   LibCodex:RegisterModule("NPCs", NPCs)

local LibCodex = LibStub("LibCodex-1.0")
local CC = {}
LibCodex.CollectionFactory = CC

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

local function lower(s) return (s or ""):lower() end

-- Build a single haystack string from the configured search fields. Used
-- by :Search to do a single substring scan per entry.
local function buildHaystack(entry, fields)
    local parts = {}
    for _, f in ipairs(fields) do
        local v = entry[f]
        if v ~= nil then parts[#parts + 1] = tostring(v) end
    end
    return lower(table.concat(parts, " "))
end

-- Merge `incoming` into `existing` non-destructively:
--   * Existing fields with truthy values stick UNLESS incoming explicitly
--     overrides via _overwrite[fieldName] = true.
--   * Missing fields are filled from incoming.
--   * `sources` arrays are unioned.
--   * Locked fields (_handcrafted == true OR field listed in _locked) are
--     never overwritten regardless of _overwrite. Bake-tool friendly.
local function mergeEntry(existing, incoming)
    if not existing then return incoming end
    if not incoming then return existing end

    local locked = {}
    if existing._handcrafted then
        for k, _ in pairs(existing) do locked[k] = true end
    end
    if type(existing._locked) == "table" then
        for _, k in ipairs(existing._locked) do locked[k] = true end
    end

    for k, v in pairs(incoming) do
        if k == "sources" and type(v) == "table" then
            existing.sources = existing.sources or {}
            for _, s in ipairs(v) do
                local seen = false
                for _, s2 in ipairs(existing.sources) do
                    if s2 == s then seen = true; break end
                end
                if not seen then table.insert(existing.sources, s) end
            end
        elseif k == "_handcrafted" or k == "_locked" then
            -- Locks come from the existing entry; ignore incoming's lock fields.
        elseif locked[k] then
            -- Field locked by handcraft; do not touch.
        elseif existing[k] == nil then
            existing[k] = v
        elseif incoming._overwrite and incoming._overwrite[k] then
            existing[k] = v
        end
    end
    return existing
end

-- ----------------------------------------------------------------------------
-- Factory
-- ----------------------------------------------------------------------------

-- opts:
--   searchFields  array of field names that :Search scans (default {"label"})
--   keyField      field used as the unique key (default "id")
--   normalize     optional function(entry) called before Add to canonicalize fields
--   afterAdd      optional function(entry) called after Add (e.g., index updates)
function CC.New(name, opts)
    opts = opts or {}
    local searchFields = opts.searchFields or { "label" }
    local keyField     = opts.keyField     or "id"
    local normalize    = opts.normalize
    local afterAdd     = opts.afterAdd

    local self = {
        _name         = name,
        _entries      = {},   -- key -> entry
        _count        = 0,
        _searchFields = searchFields,
        _keyField     = keyField,
    }

    -- Add or merge an entry. Returns the resulting entry. Entries without a
    -- key field are still accepted but only addressable via :Search and :All.
    function self:Add(entry)
        if type(entry) ~= "table" then return nil end
        if normalize then entry = normalize(entry) or entry end

        local key = entry[keyField]
        if key ~= nil then
            local existing = self._entries[key]
            -- If the entry is still in a lazy bundled index (TSV blob or row
            -- table), materialize it first so the merge picks up bundled data
            -- and we don't double-count it as a new addition.
            if not existing then
                if self._tsvIndex and self._tsvIndex[key] then
                    existing = self:_ExpandTSVRow(key)
                elseif self._rowIndex and self._rowIndex[key] then
                    existing = self:_ExpandRow(key)
                end
            end
            if existing then
                mergeEntry(existing, entry)
                if afterAdd then afterAdd(self, existing) end
                return existing
            end
            self._entries[key] = entry
            self._count = self._count + 1
            if afterAdd then afterAdd(self, entry) end
            return entry
        else
            -- Keyless entry: store in the extras list so :Search/:All still see it.
            self._extras = self._extras or {}
            table.insert(self._extras, entry)
            self._count = self._count + 1
            if afterAdd then afterAdd(self, entry) end
            return entry
        end
    end

    -- Look up by exact key. If the entry isn't in the dict store, check the
    -- lazy bundled indexes (row table or TSV blob) and expand on demand.
    function self:Get(key)
        if key == nil then return nil end
        local hit = self._entries[key]
        if hit then return hit end
        if self._rowIndex and self._rowIndex[key] then
            return self:_ExpandRow(key)
        end
        if self._tsvIndex and self._tsvIndex[key] then
            return self:_ExpandTSVRow(key)
        end
        return nil
    end

    -- ------------------------------------------------------------------
    -- Unified row ingest. The bake tool's emit format. Each row is an
    -- array of values matching the columns CSV (column order). Stored
    -- as-is and expanded into entry dicts on :Get(id).
    -- ------------------------------------------------------------------
    function self:_IngestRows(columnsCSV, rows)
        if type(columnsCSV) ~= "string" or type(rows) ~= "table" then return end
        self._rowBlobs = self._rowBlobs or {}
        self._rowIndex = self._rowIndex or {}

        local cols = {}
        for c in columnsCSV:gmatch("[^,]+") do
            cols[#cols + 1] = c:match("^%s*(.-)%s*$")
        end
        local idColIdx = 1
        for i, c in ipairs(cols) do if c == keyField then idColIdx = i; break end end

        local blobIdx = #self._rowBlobs + 1
        self._rowBlobs[blobIdx] = { columns = cols, rows = rows }

        for i = 1, #rows do
            local row = rows[i]
            if type(row) == "table" then
                local id = row[idColIdx]
                if id ~= nil and not self._entries[id] and not self._rowIndex[id] then
                    self._rowIndex[id] = { blobIdx, i }
                    self._count = self._count + 1
                end
            end
        end
    end

    -- Internal: zip a single row's positional values into a {col=val} entry,
    -- cache it in _entries, and clear its lazy index slot.
    function self:_ExpandRow(key)
        local ref = self._rowIndex[key]
        if not ref then return nil end
        local blob = self._rowBlobs[ref[1]]
        local row = blob.rows[ref[2]]
        local cols = blob.columns
        local entry = {}
        if type(row) == "table" then
            for i = 1, #cols do
                local v = row[i]
                if v ~= nil then entry[cols[i]] = v end
            end
        end
        if not entry.sources then entry.sources = { "bundled" } end
        self._entries[key] = entry
        self._rowIndex[key] = nil
        return entry
    end

    -- ------------------------------------------------------------------
    -- TSV (tab-separated value) bulk ingest. Stores the raw blob and an
    -- id-only index so :Get(id) can lazily expand single rows.
    -- ------------------------------------------------------------------
    function self:_IngestTSV(columnsCSV, blob)
        self._tsvBlobs = self._tsvBlobs or {}
        self._tsvIndex = self._tsvIndex or {}
        local cols = {}
        for c in columnsCSV:gmatch("[^,]+") do
            cols[#cols + 1] = c:match("^%s*(.-)%s*$")
        end
        local blobIdx = #self._tsvBlobs + 1
        self._tsvBlobs[blobIdx] = { columns = cols, blob = blob }

        -- Build id -> {blobIdx, lineStart, lineEnd} index in one scan. Newlines
        -- separate rows. We capture the byte offsets so :_ExpandTSVRow doesn't
        -- have to re-scan the whole blob each time.
        local pos = 1
        local len = #blob
        local idColIdx = 1
        for i, c in ipairs(cols) do if c == "id" then idColIdx = i; break end end
        while pos <= len do
            local lineEnd = blob:find("\n", pos, true) or (len + 1)
            -- Extract the id field by walking idColIdx-1 tabs into this line.
            local fieldStart, idEnd = pos, nil
            for _ = 1, idColIdx - 1 do
                local t = blob:find("\t", fieldStart, true)
                if not t or t >= lineEnd then fieldStart = nil; break end
                fieldStart = t + 1
            end
            if fieldStart then
                local t = blob:find("\t", fieldStart, true)
                idEnd = (t and t < lineEnd) and t - 1 or lineEnd - 1
                local id = tonumber(blob:sub(fieldStart, idEnd))
                if id and not self._entries[id] then
                    self._tsvIndex[id] = { blobIdx, pos, lineEnd - 1 }
                    self._count = self._count + 1
                end
            end
            pos = lineEnd + 1
        end
    end

    -- Internal: pull a single row out of the TSV blob, parse it into an entry,
    -- and cache the result in _entries so subsequent lookups are O(1) hits.
    function self:_ExpandTSVRow(key)
        local entry_ref = self._tsvIndex[key]
        if not entry_ref then return nil end
        local blobIdx, lineStart, lineEnd = entry_ref[1], entry_ref[2], entry_ref[3]
        local blob = self._tsvBlobs[blobIdx]
        local line = blob.blob:sub(lineStart, lineEnd)

        local entry = {}
        local fieldStart = 1
        local colIdx = 1
        local cols = blob.columns
        local lineLen = #line
        while fieldStart <= lineLen + 1 and colIdx <= #cols do
            local t = line:find("\t", fieldStart, true)
            local field = (t and line:sub(fieldStart, t - 1)) or line:sub(fieldStart)
            local colName = cols[colIdx]
            -- Auto-coerce: id fields and any field named like *ID become numbers,
            -- "true"/"false" become booleans, empty strings become nil.
            if field == "" then
                -- skip
            elseif colName == "id" or colName:match("ID$") or colName == "level"
                or colName == "quality" or colName == "expansion" or colName == "count" then
                entry[colName] = tonumber(field) or field
            elseif field == "true" then
                entry[colName] = true
            elseif field == "false" then
                entry[colName] = false
            else
                entry[colName] = field
            end
            if not t then break end
            fieldStart = t + 1
            colIdx = colIdx + 1
        end
        entry.sources = entry.sources or { "bundled" }
        self._entries[key] = entry
        self._tsvIndex[key] = nil  -- index no longer needed once expanded
        return entry
    end

    -- Force-expand every lazy-backed entry into the dict store. Call this
    -- once when a consumer needs full iteration or a complete :Search().
    -- Drains both the row index and the legacy TSV index. Idempotent.
    function self:ExpandAll()
        local n = 0
        if self._rowIndex then
            for k, _ in pairs(self._rowIndex) do
                self:_ExpandRow(k); n = n + 1
            end
            self._rowIndex = nil
            self._rowBlobs = nil
        end
        if self._tsvIndex then
            for k, _ in pairs(self._tsvIndex) do
                self:_ExpandTSVRow(k); n = n + 1
            end
            self._tsvIndex = nil
            self._tsvBlobs = nil
        end
        return n
    end

    -- Substring search across configured search fields.
    -- opts.filter: optional function(entry) -> bool, called on every candidate
    -- opts can also contain field-equality filters: { side = "A", mapID = 2248 }
    -- Returns an array of matching entries.
    function self:Search(query, opts)
        opts = opts or {}
        local q = lower(query or "")
        local filterFn = opts.filter
        local fieldFilters = {}
        for k, v in pairs(opts) do
            if k ~= "filter" then fieldFilters[k] = v end
        end

        local function matches(e)
            if not e then return false end
            if q ~= "" then
                local hay = buildHaystack(e, self._searchFields)
                if not hay:find(q, 1, true) then return false end
            end
            for k, v in pairs(fieldFilters) do
                if e[k] ~= v then return false end
            end
            if filterFn and not filterFn(e) then return false end
            return true
        end

        local out = {}
        for _, e in pairs(self._entries) do
            if matches(e) then out[#out + 1] = e end
        end
        if self._extras then
            for _, e in ipairs(self._extras) do
                if matches(e) then out[#out + 1] = e end
            end
        end
        return out
    end

    -- Iterate every entry. Yields (key, entry) for keyed entries and
    -- (nil, entry) for keyless extras. Use ipairs(self:All()) if you'd
    -- prefer an array.
    function self:All()
        local function gen()
            for k, e in pairs(self._entries) do coroutine.yield(k, e) end
            if self._extras then
                for _, e in ipairs(self._extras) do coroutine.yield(nil, e) end
            end
        end
        return coroutine.wrap(gen)
    end

    -- Return entries as an array (useful for iteration in non-coroutine code).
    function self:AllArray()
        local out = {}
        for _, e in pairs(self._entries) do out[#out + 1] = e end
        if self._extras then
            for _, e in ipairs(self._extras) do out[#out + 1] = e end
        end
        return out
    end

    -- Return the raw key->entry map. Used by SavedVariables persistence.
    function self:AllRaw()
        return self._entries
    end

    function self:Count()
        return self._count
    end

    function self:Name()
        return self._name
    end

    function self:Remove(key)
        if key == nil then return false end
        if self._entries[key] then
            self._entries[key] = nil
            self._count = math.max(0, self._count - 1)
            return true
        end
        return false
    end

    function self:Clear()
        self._entries = {}
        self._extras = nil
        self._count = 0
    end

    return self
end

-- Expose merge utility for adapters that need it directly.
CC.Merge = mergeEntry
