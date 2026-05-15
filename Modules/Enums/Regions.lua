-- LibCodex-1.0 / Modules / Enums / Regions.lua
-- v2 slots: 1:id, 2:challengeOrigin, 3:raidOrigin, 4:regionGroup,
--           5:regionID, 6:tag (Z85 string), 7:timeEventGroupID

local LibCodex = LibStub("LibCodex-1.0")
local Regions = LibCodex.CollectionFactory.New("Regions", {
    keyField = "id",
    searchFields = { "tag" },
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

function Regions:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end
    local id = slots[1]
    if type(id) ~= "number" or id <= 0 then return end
    local entry = { id = id, sources = { "bundled" } }
    if type(slots[2]) == "number" then entry.challengeOrigin   = slots[2] end
    if type(slots[3]) == "number" then entry.raidOrigin        = slots[3] end
    if type(slots[4]) == "number" then entry.regionGroup       = slots[4] end
    if type(slots[5]) == "number" then entry.regionID          = slots[5] end
    if type(slots[6]) == "string" then
        entry.tag = decodeZ85String(slots[6])
        entry.label = entry.tag  -- mirror for Codex viewer and generic consumers
    end
    if type(slots[7]) == "number" then entry.timeEventGroupID  = slots[7] end
    if build then entry._build = build end
    self._entries[id] = entry
    self._count = (self._count or 0) + 1
end

LibCodex:RegisterModule("Regions", Regions)
