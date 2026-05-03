-- LibCodex-1.0 / Modules / Catalog / SpellChargeCategories.lua
-- Charge-category definitions from wago `SpellCategory` DBC. These are the
-- shared cooldown groups used by spells that have multiple charges or
-- weekly use limits (Avenging Wrath, Reverse Time, etc).
--
-- Schema:
--   id              SpellCategoryID
--   label           Name_lang
--   maxCharges      max simultaneous charges
--   chargeRecoveryTime  ms between charges regenerating
--   usesPerWeek     weekly cap (0 = no cap)
--   typeMask        type flags
--   flags           raw SpellCategory.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellChargeCategories = LibCodex.CollectionFactory.New("SpellChargeCategories", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("SpellChargeCategories", SpellChargeCategories)
