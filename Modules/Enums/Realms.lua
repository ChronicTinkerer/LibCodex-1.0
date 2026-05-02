-- LibCodex-1.0 / Modules / Enums / Realms.lua
-- Static catalog of WoW realms with connected-realm clusters. The bundled
-- Data\Realms.lua file contains a small seed; the runtime adapter populates
-- additional realms from GetAutoCompleteRealms() as the player connects.
-- Schema:
--   id              numeric realm ID (Blizzard internal)
--   label           short name as it appears in-game ("Stormrage")
--   fullName        full name with spaces if any ("Argent Dawn")
--   region          "US" | "EU" | "KR" | "TW" | "CN"
--   locale          locale string ("enUS","enGB","deDE","frFR","ruRU",...)
--   type            "PvE" | "PvP" | "RP" | "RPPvP"
--   timezone        IANA TZ ("America/New_York")
--   connectedTo     array of realm IDs that share AH/mail/guilds with this one
--   connectedGroup  optional shared cluster identifier
--   online          true unless flagged offline

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local Realms = CC.New("Realms", {
    keyField = "id",
    searchFields = { "label", "fullName" },
    -- Realms are also addressable by name; we maintain a name->id index lazily.
})

-- Lazy name index. Rebuilt when stale (after Add).
local _nameIndex
local function rebuildNameIndex()
    _nameIndex = {}
    for _, e in pairs(Realms:AllRaw()) do
        if e.label    then _nameIndex[e.label:lower()]    = e end
        if e.fullName then _nameIndex[e.fullName:lower()] = e end
    end
end

-- :Get accepts either a numeric ID or a name string.
local realRawGet = Realms.Get
function Realms:Get(key)
    if type(key) == "string" then
        if not _nameIndex then rebuildNameIndex() end
        return _nameIndex[key:lower()]
    end
    return realRawGet(self, key)
end

-- After every Add, mark the name index stale.
local realAdd = Realms.Add
function Realms:Add(entry)
    local res = realAdd(self, entry)
    _nameIndex = nil
    return res
end

-- Return every realm in the same connected-realm cluster as `realm`.
-- `realm` can be an id or a name. Includes the input realm itself.
function Realms:Cluster(realm)
    local seed = self:Get(realm)
    if not seed then return {} end
    local seen = { [seed.id] = true }
    local out  = { seed }

    local function add(r)
        if r and not seen[r.id] then
            seen[r.id] = true
            out[#out + 1] = r
        end
    end

    if type(seed.connectedTo) == "table" then
        for _, otherID in ipairs(seed.connectedTo) do
            add(self:Get(otherID))
        end
    end
    if seed.connectedGroup then
        for _, e in pairs(self:AllRaw()) do
            if e.connectedGroup == seed.connectedGroup then add(e) end
        end
    end

    return out
end

function Realms:AreConnected(a, b)
    local ra, rb = self:Get(a), self:Get(b)
    if not ra or not rb then return false end
    if ra.id == rb.id then return true end
    if ra.connectedGroup and ra.connectedGroup == rb.connectedGroup then return true end
    if type(ra.connectedTo) == "table" then
        for _, id in ipairs(ra.connectedTo) do
            if id == rb.id then return true end
        end
    end
    return false
end

-- Returns the realm record matching the player's current realm. Uses
-- GetRealmName when in WoW; falls back to scanning the catalog otherwise.
function Realms:Current()
    if GetRealmName then
        local name = GetRealmName()
        if name then return self:Get(name) end
    end
    return nil
end

LibCodex:RegisterModule("Realms", Realms)
