-- LibCodex-1.0 / Modules / Catalog / SpellCastTimes.lua
-- Cast-time lookup table from wago `SpellCastTimes` DBC. A small enum;
-- many spells share the same cast-time entry.
--
-- Schema:
--   id        SpellCastTimes row id (referenced from Spell.CastingTimeIndex)
--   base      base cast time in ms
--   minimum   minimum cast time after haste in ms
--   sources   provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellCastTimes = LibCodex.CollectionFactory.New("SpellCastTimes", {
    keyField = "id",
    searchFields = {},
})
LibCodex:RegisterModule("SpellCastTimes", SpellCastTimes)
