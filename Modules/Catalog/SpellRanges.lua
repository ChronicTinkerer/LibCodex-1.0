-- LibCodex-1.0 / Modules / Catalog / SpellRanges.lua
-- Range lookup table from wago `SpellRange` DBC. A small enum referenced
-- from Spell.RangeIndex; each entry defines minimum and maximum cast
-- distance (separate values for friendly vs. hostile targets).
--
-- Schema:
--   id              SpellRange row id
--   label           DisplayName_lang ("Long Range", "Melee Range", ...)
--   shortLabel      DisplayNameShort_lang
--   rangeMinFriend  RangeMin_0 — minimum range for friendly casts
--   rangeMinHostile RangeMin_1 — minimum range for hostile casts
--   rangeMaxFriend  RangeMax_0
--   rangeMaxHostile RangeMax_1
--   flags           raw SpellRange.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellRanges = LibCodex.CollectionFactory.New("SpellRanges", {
    keyField = "id",
    searchFields = { "label", "shortLabel" },
})
LibCodex:RegisterModule("SpellRanges", SpellRanges)
