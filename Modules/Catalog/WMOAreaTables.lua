-- LibCodex-1.0 / Modules / Catalog / WMOAreaTables.lua
-- World Map Object area entries: interior areas inside dungeons, raids, and
-- detailed-geometry locations like Stormwind's individual buildings. Each
-- entry pinpoints which "room" of a complex location the player is standing
-- in, beyond what AreaTable can express.
--
-- Schema:
--   id              WMOAreaTableID
--   label           AreaName_lang (e.g. "Cathedral of Light")
--   wmoID           WMOID — the World Map Object container
--   wmoGroupID      WMOGroupID — sub-group within the WMO
--   nameSetID       NameSetID for variant-name selection
--   areaTableID     parent AreaTable id (cross-ref to Areas module)
--   ambienceID      ambient sound id
--   zoneMusicID     zone music id
--   flags           raw WMOAreaTable.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local WMOAreaTables = LibCodex.CollectionFactory.New("WMOAreaTables", {
    keyField = "id",
    searchFields = { "label" },
})

function WMOAreaTables:ForArea(areaTableID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.areaTableID == areaTableID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("WMOAreaTables", WMOAreaTables)
