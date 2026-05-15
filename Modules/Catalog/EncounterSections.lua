-- LibCodex-1.0 / Modules / Catalog / EncounterSections.lua
local LibCodex = LibStub("LibCodex-1.0")
local EncounterSections = LibCodex.CollectionFactory.New("EncounterSections", { keyField = "id", searchFields = { "title","bodyText" } })
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
function EncounterSections:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end
    local id = slots[1]; if type(id) ~= "number" or id <= 0 then return end
    local entry = { id = id, sources = { "bundled" } }
    if type(slots[2]) == "string" then entry.title = decodeZ85String(slots[2]) end
    if type(slots[3]) == "number" then entry.icon = slots[3] end
    if type(slots[4]) == "number" then entry.type = slots[4] end
    if type(slots[5]) == "number" then entry.spellID = slots[5] end
    if type(slots[6]) == "number" then entry.flags = slots[6] end
    if type(slots[7]) == "string" then entry.bodyText = decodeZ85String(slots[7]) end
    if type(slots[8]) == "number" then entry.difficultyMask = slots[8] end
    if type(slots[9]) == "number" then entry.firstChildSectionID = slots[9] end
    if type(slots[10]) == "number" then entry.iconCreatureDisplayInfoID = slots[10] end
    if type(slots[11]) == "number" then entry.iconFlags = slots[11] end
    if type(slots[12]) == "number" then entry.journalEncounterID = slots[12] end
    if type(slots[13]) == "number" then entry.nextSiblingSectionID = slots[13] end
    if type(slots[14]) == "number" then entry.orderIndex = slots[14] end
    if type(slots[15]) == "number" then entry.parentSectionID = slots[15] end
    if type(slots[16]) == "number" then entry.uiModelSceneID = slots[16] end
    if build then entry._build = build end
    self._entries[id] = entry; self._count = (self._count or 0) + 1
end
LibCodex:RegisterModule("EncounterSections", EncounterSections)
