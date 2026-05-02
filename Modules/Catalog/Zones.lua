-- LibCodex-1.0 / Modules / Catalog / Zones.lua
-- UiMap entries: continents, zones, sub-zones, dungeons, raids, scenarios.
local LibCodex = LibStub("LibCodex-1.0")
local Zones = LibCodex.CollectionFactory.New("Zones", {
    keyField = "id",
    searchFields = { "label", "type" },
})
LibCodex:RegisterModule("Zones", Zones)
