-- LibCodex-1.0 / Modules / Catalog / AreaPOI.lua
local LibCodex = LibStub("LibCodex-1.0")
local AreaPOI = LibCodex.CollectionFactory.New("AreaPOI", { keyField = "id", searchFields = { "label", "description" } })
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
function AreaPOI:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end
    local id = slots[1]; if type(id) ~= "number" or id <= 0 then return end
    local entry = { id = id, sources = { "bundled" } }
    if type(slots[2])  == "string" then entry.label           = decodeZ85String(slots[2])  end
    if type(slots[3])  == "number" then entry.x               = slots[3]  end
    if type(slots[4])  == "number" then entry.y               = slots[4]  end
    if type(slots[5])  == "string" then entry.description     = decodeZ85String(slots[5])  end
    if type(slots[6])  == "number" then entry.flags           = slots[6]  end
    if type(slots[7])  == "number" then entry.areaID          = slots[7]  end
    if type(slots[8])  == "number" then entry.continentID     = slots[8]  end
    if type(slots[9])  == "number" then entry.playerCondition = slots[9]  end
    if type(slots[10]) == "number" then entry.poiData         = slots[10] end
    if type(slots[11]) == "number" then entry.poiDataType     = slots[11] end
    if type(slots[12]) == "number" then entry.portLocID       = slots[12] end
    if type(slots[13]) == "number" then entry.states          = slots[13] end
    if type(slots[14]) == "number" then entry.uiAtlasMember   = slots[14] end
    if type(slots[15]) == "number" then entry.widgetSetID     = slots[15] end
    if type(slots[16]) == "number" then entry.worldStateID    = slots[16] end
    if type(slots[17]) == "number" then entry.z               = slots[17] end
    if build then entry._build = build end
    self._entries[id] = entry; self._count = (self._count or 0) + 1
end
LibCodex:RegisterModule("AreaPOI", AreaPOI)
