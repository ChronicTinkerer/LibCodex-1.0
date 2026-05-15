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

    -- ------------------------------------------------------------------
    -- Lazy chunks. The bake tool emits each Data/<Module>.lua chunk as a
    -- thunk via _FeedBundledRowsLazy; we queue them here and only invoke
    -- on first :Get / :Search / :All / :Add. Modules a consumer addon
    -- never touches pay zero per-row memory.
    -- ------------------------------------------------------------------
    function self:_IngestLazyChunk(columnsCSV, thunk)
        self._lazyChunks = self._lazyChunks or {}
        self._lazyChunks[#self._lazyChunks + 1] = { columns = columnsCSV, thunk = thunk }
    end

    -- Materialize every queued lazy chunk by invoking its thunk and routing
    -- the resulting rows through the standard _IngestRows path. Idempotent:
    -- empties the queue once drained. Safe to call from anywhere — it's a
    -- no-op when there are no pending chunks.
    function self:_MaterializeLazyChunks()
        if not self._lazyChunks or #self._lazyChunks == 0 then return end
        local chunks = self._lazyChunks
        self._lazyChunks = nil  -- prevent re-entry from inside _IngestRows
        for i = 1, #chunks do
            local p = chunks[i]
            local ok, rows = pcall(p.thunk)
            if ok and type(rows) == "table" then
                self:_IngestRows(p.columns, rows)
            end
        end
    end

    -- ------------------------------------------------------------------
    -- v2 chunks. The bake_v2 tool emits each chunk as a thunk via
    -- _FeedBundledRowsV2(name, schemaVersion, build, thunk). The chunk's
    -- rows are positional arrays in the v2 11-slot schema, with location
    -- data Z85-packed into slot 3. Per-module decode logic lives on the
    -- collection itself as :_DecodeV2Row(slots); collections that don't
    -- define one silently skip v2 chunks.
    -- ------------------------------------------------------------------
    function self:_IngestV2Chunk(schemaVersion, build, thunk)
        self._v2Chunks = self._v2Chunks or {}
        self._v2Chunks[#self._v2Chunks + 1] = {
            schemaVersion = schemaVersion,
            build = build,
            thunk = thunk,
        }
    end

    -- Drain the v2 chunk queue. For each chunk, invoke its thunk to get the
    -- row table, then call self:_DecodeV2Row(slots) for each row. If the
    -- collection doesn't define _DecodeV2Row, this is a silent no-op.
    -- After base materialization, applies any pending v2 deltas in TOC order.
    function self:_MaterializeV2Chunks()
        if not self._v2Chunks or #self._v2Chunks == 0 then
            -- No base chunks pending, but deltas might still need applying
            -- (e.g., re-running materialize after a partial load)
            self:_MaterializeV2Deltas()
            return
        end
        local chunks = self._v2Chunks
        self._v2Chunks = nil
        if not self._DecodeV2Row then return end  -- module hasn't opted in to v2
        for i = 1, #chunks do
            local p = chunks[i]
            local ok, rows = pcall(p.thunk)
            if ok and type(rows) == "table" then
                for _, row in ipairs(rows) do
                    self:_DecodeV2Row(row, p.schemaVersion, p.build)
                end
            end
        end
        -- Phase 1.5: after base rows, apply any deltas in TOC order
        self:_MaterializeV2Deltas()
    end

    -- ------------------------------------------------------------------
    -- v2 build deltas. bake_v2 emits one delta per future TOC version it
    -- has data for. The reader applies any delta whose deltaToc <= the
    -- player's current TOC (from GetBuildInfo()), in ascending order, after
    -- base chunks materialize. Cumulative model: a player on TOC 120007
    -- gets every 120006 + 120007 delta applied on top of base; a player
    -- on TOC 120005 (the base) gets none.
    --
    -- Delta thunk return format:
    --   { [questID] = positional v2 row, ..., _removed = {ids...} }
    -- ------------------------------------------------------------------
    function self:_IngestV2Delta(schemaVersion, deltaToc, thunk)
        self._v2Deltas = self._v2Deltas or {}
        self._v2Deltas[#self._v2Deltas + 1] = {
            schemaVersion = schemaVersion,
            deltaToc = deltaToc,
            thunk = thunk,
        }
    end

    function self:_MaterializeV2Deltas()
        if not self._v2Deltas or #self._v2Deltas == 0 then return end
        if not self._DecodeV2Row then return end

        local deltas = self._v2Deltas
        self._v2Deltas = nil

        -- Determine current player TOC. GetBuildInfo() returns
        -- (version, build, date, tocVersion). Skip apply for any delta
        -- whose deltaToc > currentToc (those are future-build data the
        -- player doesn't see yet).
        local currentToc = 0
        if GetBuildInfo then
            local _, _, _, toc = GetBuildInfo()
            if type(toc) == "number" then currentToc = toc end
        end

        -- Sort by deltaToc ascending so applies are deterministic
        table.sort(deltas, function(a, b) return a.deltaToc < b.deltaToc end)

        for i = 1, #deltas do
            local p = deltas[i]
            if p.deltaToc <= currentToc then
                local ok, body = pcall(p.thunk)
                if ok and type(body) == "table" then
                    -- Drop removed IDs first so a remove-then-readd within a
                    -- single delta lands as the readd (matches Python helper).
                    if type(body._removed) == "table" then
                        for _, removedId in ipairs(body._removed) do
                            self._entries[removedId] = nil
                        end
                    end
                    -- Apply integer-keyed overrides/adds
                    for key, row in pairs(body) do
                        if type(key) == "number" and type(row) == "table" then
                            self:_DecodeV2Row(row, p.schemaVersion, p.deltaToc)
                        end
                    end
                end
            end
        end
    end


    -- Trigger LoD load of the module's companion subaddon (if not yet
    -- attempted), then drain any chunks the load queued. Idempotent; safe
    -- to call from any read-side method that finds entries empty.
    function self:_EnsureBundledLoaded()
        if (self._count or 0) > 0 then return end
        local LC = LibStub and LibStub("LibCodex-1.0", true)
        if not (LC and LC._TryLoadModule) then return end
        if LC._loadAttempts and LC._loadAttempts[self._name] then return end
        if LC:_TryLoadModule(self._name) then
            if self._lazyChunks then self:_MaterializeLazyChunks() end
            if self._v2Chunks   then self:_MaterializeV2Chunks()   end
        end
    end

    -- Add or merge an entry. Returns the resulting entry. Entries without a
    -- key field are still accepted but only addressable via :Search and :All.
    function self:Add(entry)
        if type(entry) ~= "table" then return nil end
        if normalize then entry = normalize(entry) or entry end

        -- Runtime adds need to merge against bundled data; materialize any
        -- pending lazy chunks first so existing entries get found.
        if self._lazyChunks then self:_MaterializeLazyChunks() end

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
    -- Falls through to materializing any pending lazy chunks if the key
    -- isn't found in already-known indexes.
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
        -- Fall through: maybe the key lives in a chunk we haven't loaded yet.
        if self._v2Chunks then
            self:_MaterializeV2Chunks()
            local re = self._entries[key]
            if re then return re end
        end
        if self._lazyChunks then
            self:_MaterializeLazyChunks()
            if self._rowIndex and self._rowIndex[key] then
                return self:_ExpandRow(key)
            end
            local re = self._entries[key]
            if re then return re end
        end
        -- Last resort: the bundled data for this specific module may live in
        -- LibCodex-1.0-<ModuleName> (LoadOnDemand companion addon, one per
        -- module). Trigger the load once per session per module. When the
        -- companion addon's Data\<Module>.lua runs, it calls _FeedBundled* on
        -- this collection, which fills self._lazyChunks / self._rowIndex here.
        -- We retry the lookup once to materialize any rows that just landed.
        local LC = LibStub and LibStub("LibCodex-1.0", true)
        if LC and LC._TryLoadModule and not LC._loadAttempts[self._name] then
            if LC:_TryLoadModule(self._name) then
                -- Module loaded: re-check our indexes and lazy chunks.
                if self._entries[key] then return self._entries[key] end
                if self._rowIndex and self._rowIndex[key] then
                    return self:_ExpandRow(key)
                end
                if self._lazyChunks then
                    self:_MaterializeLazyChunks()
                    if self._rowIndex and self._rowIndex[key] then
                        return self:_ExpandRow(key)
                    end
                    if self._entries[key] then return self._entries[key] end
                end
            end
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
    -- Drains pending lazy chunks AND the row / TSV indexes. Idempotent.
    function self:ExpandAll()
        if self._lazyChunks then self:_MaterializeLazyChunks() end
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

    -- Substring search across configured search fields. Walks every
    -- materialized entry AND every lazy bundled row (both row format and
    -- legacy TSV format), expanding lazy rows into entry dicts only when
    -- they actually match. This keeps memory low even when searching across
    -- huge modules like Spells (400K rows).
    --
    -- opts.filter: optional function(entry) -> bool, called on every candidate
    -- opts can also contain field-equality filters: { side = "A", mapID = 2248 }
    -- Returns an array of matching entries.
    function self:Search(query, opts)
        -- Search needs to walk every row, so materialize any deferred chunks
        -- first. After this the existing _entries / _rowIndex / _tsvIndex
        -- scan logic covers everything.
        if self._lazyChunks then self:_MaterializeLazyChunks() end
        if self._v2Chunks   then self:_MaterializeV2Chunks()   end
        self:_EnsureBundledLoaded()

        opts = opts or {}
        local q = lower(query or "")
        local filterFn = opts.filter
        local fieldFilters = {}
        local hasFieldFilters = false
        for k, v in pairs(opts) do
            if k ~= "filter" then
                fieldFilters[k] = v
                hasFieldFilters = true
            end
        end

        -- Multi-token search: split the query on whitespace into N tokens.
        -- A row matches only when EVERY token is found in its haystack
        -- (substring AND, not OR). Empty query means "match everything".
        --   "rune cloth"   -> matches haystacks containing both 'rune' and 'cloth'
        --   "ironforge"    -> single token, same as before
        local tokens
        if q ~= "" then
            tokens = {}
            for tk in q:gmatch("%S+") do
                tokens[#tokens + 1] = tk
            end
            if #tokens == 0 then q = "" end  -- whitespace-only collapses to "match everything"
        end
        local function haystackMatchesTokens(hay)
            if not tokens then return true end
            for i = 1, #tokens do
                if not hay:find(tokens[i], 1, true) then return false end
            end
            return true
        end

        -- Match against an already-materialized dict entry.
        local function matchesDict(e)
            if not e then return false end
            if tokens then
                local hay = buildHaystack(e, self._searchFields)
                if not haystackMatchesTokens(hay) then return false end
            end
            for k, v in pairs(fieldFilters) do
                if e[k] ~= v then return false end
            end
            if filterFn and not filterFn(e) then return false end
            return true
        end

        local out = {}

        -- Pass 1: walk materialized entries (the fast path, O(materialized)).
        for _, e in pairs(self._entries) do
            if matchesDict(e) then out[#out + 1] = e end
        end

        -- Pass 2: walk lazy row-format entries. Build the haystack from
        -- positional row values so we don't materialize non-matches into
        -- entry dicts. Snapshot the keys first because :_ExpandRow mutates
        -- _rowIndex (matched rows move into _entries).
        if self._rowIndex and next(self._rowIndex) then
            local candidates = {}
            for key, _ in pairs(self._rowIndex) do
                candidates[#candidates + 1] = key
            end
            -- Pre-resolve searchField -> column-index lookups per blob to
            -- avoid an inner-loop scan. Same for fieldFilters.
            local searchIdxByBlob = {}
            local filterIdxByBlob = {}
            for blobIdx, blob in ipairs(self._rowBlobs) do
                local sIdx = {}
                for _, fname in ipairs(self._searchFields) do
                    for i, c in ipairs(blob.columns) do
                        if c == fname then sIdx[#sIdx + 1] = i; break end
                    end
                end
                searchIdxByBlob[blobIdx] = sIdx
                if hasFieldFilters then
                    local fIdx = {}
                    for k, _ in pairs(fieldFilters) do
                        for i, c in ipairs(blob.columns) do
                            if c == k then fIdx[k] = i; break end
                        end
                    end
                    filterIdxByBlob[blobIdx] = fIdx
                end
            end

            for _, key in ipairs(candidates) do
                local ref = self._rowIndex[key]
                if ref then
                    local blobIdx = ref[1]
                    local blob = self._rowBlobs[blobIdx]
                    local row = blob.rows[ref[2]]
                    if type(row) == "table" then
                        -- Substring test against searchable column values.
                        -- For multi-token queries, every token must match.
                        local substrOk = (not tokens)
                        if not substrOk then
                            local idxs = searchIdxByBlob[blobIdx]
                            local parts = {}
                            for i = 1, #idxs do
                                local v = row[idxs[i]]
                                if v ~= nil then parts[#parts + 1] = tostring(v) end
                            end
                            substrOk = haystackMatchesTokens(lower(table.concat(parts, " ")))
                        end
                        -- Field-equality test on positional values. Only run
                        -- if substring already passed.
                        local fieldOk = true
                        if substrOk and hasFieldFilters then
                            local fIdx = filterIdxByBlob[blobIdx]
                            for fk, fv in pairs(fieldFilters) do
                                local idx = fIdx and fIdx[fk]
                                if not idx or row[idx] ~= fv then
                                    fieldOk = false; break
                                end
                            end
                        end
                        if substrOk and fieldOk then
                            local entry = self:_ExpandRow(key)
                            if entry and (not filterFn or filterFn(entry)) then
                                out[#out + 1] = entry
                            end
                        end
                    end
                end
            end
        end

        -- Pass 3: walk lazy TSV-format entries (legacy). The TSV blob is a
        -- flat string per line, so a substring test on the raw line text
        -- is correct for the searchable-column case (a stricter test than
        -- ideal, but TSV is a back-compat path that won't see new data).
        -- Field filters are applied post-expansion since they need parsing.
        if self._tsvIndex and next(self._tsvIndex) then
            local candidates = {}
            for key, _ in pairs(self._tsvIndex) do
                candidates[#candidates + 1] = key
            end
            for _, key in ipairs(candidates) do
                local ref = self._tsvIndex[key]
                if ref then
                    local blob = self._tsvBlobs[ref[1]]
                    local line = blob.blob:sub(ref[2], ref[3])
                    local substrOk = (not tokens) or haystackMatchesTokens(lower(line))
                    if substrOk then
                        local entry = self:_ExpandTSVRow(key)
                        if entry and matchesDict(entry) then
                            out[#out + 1] = entry
                        end
                    end
                end
            end
        end

        -- Pass 4: keyless extras.
        if self._extras then
            for _, e in ipairs(self._extras) do
                if matchesDict(e) then out[#out + 1] = e end
            end
        end

        return out
    end

    -- Iterate every entry. Yields (key, entry) for keyed entries and
    -- (nil, entry) for keyless extras. Use ipairs(self:All()) if you'd
    -- prefer an array. Materializes lazy chunks first so consumers see
    -- the full bundled catalog.
    function self:All()
        if self._lazyChunks then self:_MaterializeLazyChunks() end
        if self._v2Chunks   then self:_MaterializeV2Chunks()   end
        self:_EnsureBundledLoaded()
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
        if self._lazyChunks then self:_MaterializeLazyChunks() end
        if self._v2Chunks   then self:_MaterializeV2Chunks()   end
        self:_EnsureBundledLoaded()
        local out = {}
        for _, e in pairs(self._entries) do out[#out + 1] = e end
        if self._extras then
            for _, e in ipairs(self._extras) do out[#out + 1] = e end
        end
        return out
    end

    -- Return the raw key->entry map. Used by SavedVariables persistence.
    -- Materializes lazy chunks because callers expect the full catalog.
    function self:AllRaw()
        if self._lazyChunks then self:_MaterializeLazyChunks() end
        if self._v2Chunks   then self:_MaterializeV2Chunks()   end
        self:_EnsureBundledLoaded()
        return self._entries
    end

    -- Total entry count INCLUDING unmaterialized lazy chunks. We count
    -- materialized entries directly and then materialize+count any pending
    -- lazy chunks. Note this does pay the materialization cost; callers
    -- that need a cheap "approximate count" should check :Count() before
    -- the first :Get/:Search/:All to get just the eager count.
    function self:Count()
        if self._lazyChunks then self:_MaterializeLazyChunks() end
        if self._v2Chunks   then self:_MaterializeV2Chunks()   end
        self:_EnsureBundledLoaded()
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
