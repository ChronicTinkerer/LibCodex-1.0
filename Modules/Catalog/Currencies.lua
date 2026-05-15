-- LibCodex-1.0 / Modules / Catalog / Currencies.lua
-- Currency catalog. v2 slot schema (append-only):
--   1: id           CurrencyID
--   2: expansion    ExpansionID
--   3: categoryID   currency category ID
--   4: label        display name, Z85-encoded (string codec; pad-prefix byte)
--   5: categoryName category display name, Z85-encoded (same codec)
--   sources         provenance tags, runtime-only

local LibCodex = LibStub("LibCodex-1.0")
local Currencies = LibCodex.CollectionFactory.New("Currencies", {
    keyField = "id",
    searchFields = { "label", "categoryName" },
})

-- ----------------------------------------------------------------------------
-- v2 compressed-format support.
--
-- Slot 4 (label) and slot 5 (categoryName) are Z85-encoded strings using the
-- "string" codec: byte 0 holds the trailing zero-pad length (0..3); bytes
-- 1..N hold the UTF-8 text. We strip the pad on decode so the text round
-- trips exactly even when its length isn't a multiple of 4.
-- ----------------------------------------------------------------------------

local function decodeZ85String(z85str)
    if type(z85str) ~= "string" or z85str == "" then return nil end
    local Z85 = LibStub and LibStub("LibZ85-1.0", true)
    if not Z85 then return nil end
    local ok, bytes = pcall(Z85.decode, z85str)
    if not ok or type(bytes) ~= "string" or #bytes < 1 then return nil end
    local pad = string.byte(bytes, 1)
    if pad < 0 or pad > 3 then return nil end
    local tail_end = #bytes - pad
    if tail_end < 1 then return "" end
    return string.sub(bytes, 2, tail_end)
end

function Currencies:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end

    local id = slots[1]
    if type(id) ~= "number" or id <= 0 then return end

    local entry = { id = id, sources = { "bundled" } }

    if type(slots[2]) == "number" then entry.expansion    = slots[2] end
    if type(slots[3]) == "number" then entry.categoryID   = slots[3] end
    if type(slots[4]) == "string" then entry.label        = decodeZ85String(slots[4]) end
    if type(slots[5]) == "string" then entry.categoryName = decodeZ85String(slots[5]) end

    if build then entry._build = build end

    self._entries[id] = entry
    self._count = (self._count or 0) + 1
end

LibCodex:RegisterModule("Currencies", Currencies)
