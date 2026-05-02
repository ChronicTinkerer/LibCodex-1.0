-- LibCodex-1.0 / Modules / Catalog / Currencies.lua
local LibCodex = LibStub("LibCodex-1.0")
local Currencies = LibCodex.CollectionFactory.New("Currencies", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Currencies", Currencies)
