-- LibCodex-1.0 / Modules / Catalog / Toys.lua
-- Toy collection catalog. Schema:
--   id           ToyID (matches the underlying ItemID)
--   label        toy name (resolved via Items at runtime)
--   sourceType   numeric source category
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Toys = LibCodex.CollectionFactory.New("Toys", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Toys", Toys)
