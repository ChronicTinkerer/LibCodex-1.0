-- LibCodex-1.0 / Modules / Catalog / Spells.lua
-- Spell catalog (every castable spell, passive, talent, item-effect, etc.)
local LibCodex = LibStub("LibCodex-1.0")
local Spells = LibCodex.CollectionFactory.New("Spells", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Spells", Spells)
