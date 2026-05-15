-- LibCodex-1.0 / Modules / Catalog / AreaTriggers.lua
local LibCodex = LibStub("LibCodex-1.0")
local AreaTriggers = LibCodex.CollectionFactory.New("AreaTriggers", { keyField = "id", searchFields = {} })
local NAMES = {nil,"x","y","flags","actionSetID","boxHeight","boxLength","boxWidth","boxYaw",
               "continentID","phaseGroupID","phaseID","phaseUseFlags","radius","shapeID","shapeType","z"}
function AreaTriggers:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end
    local id = slots[1]; if type(id) ~= "number" or id <= 0 then return end
    local entry = { id = id, sources = { "bundled" } }
    for i = 2, #NAMES do
        if type(slots[i]) == "number" then entry[NAMES[i]] = slots[i] end
    end
    if build then entry._build = build end
    self._entries[id] = entry; self._count = (self._count or 0) + 1
end
LibCodex:RegisterModule("AreaTriggers", AreaTriggers)
