-- LibCodex-1.0 / Modules / Catalog / Heirlooms.lua
-- Heirloom catalog. Schema:
--   id           HeirloomID (the static ItemID; level-scales at runtime)
--   label        heirloom name
--   itemID       backing item id
--   classMask    bitmask of which classes can use this heirloom
--   armor        primary armor type
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Heirlooms = LibCodex.CollectionFactory.New("Heirlooms", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Heirlooms", Heirlooms)
