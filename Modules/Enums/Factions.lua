-- LibCodex-1.0 / Modules / Enums / Factions.lua
-- v2 slots: 1:id, 2:label (Z85), 3:expansion, 4:color (Z85),
--           5:parentFactionID, 6:kind (Z85)

local LibCodex = LibStub("LibCodex-1.0")
local Factions = LibCodex.CollectionFactory.New("Factions", {
    keyField = "id",
    searchFields = { "label" },
})

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

function Factions:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end
    local id = slots[1]
    if type(id) ~= "number" or id <= 0 then return end
    local entry = { id = id, sources = { "bundled" } }
    if type(slots[2]) == "string" then entry.label            = decodeZ85String(slots[2]) end
    if type(slots[3]) == "number" then entry.expansion        = slots[3] end
    if type(slots[4]) == "string" then entry.color            = decodeZ85String(slots[4]) end
    if type(slots[5]) == "number" then entry.parentFactionID  = slots[5] end
    if type(slots[6]) == "string" then entry.kind             = decodeZ85String(slots[6]) end
    if build then entry._build = build end
    self._entries[id] = entry
    self._count = (self._count or 0) + 1
end

LibCodex:RegisterModule("Factions", Factions)
