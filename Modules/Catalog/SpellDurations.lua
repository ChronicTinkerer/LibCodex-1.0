-- LibCodex-1.0 / Modules / Catalog / SpellDurations.lua
-- Duration lookup table from wago `SpellDuration` DBC. A small enum
-- referenced from Spell.DurationIndex; gives base + max + per-resource
-- duration scaling for spell auras.
--
-- Schema:
--   id                  SpellDuration row id
--   duration            base duration in ms
--   maxDuration         max duration in ms (after extension talents/procs)
--   durationPerResource added duration per spent resource (combo points etc.)
--   sources             provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellDurations = LibCodex.CollectionFactory.New("SpellDurations", {
    keyField = "id",
    searchFields = {},
})
LibCodex:RegisterModule("SpellDurations", SpellDurations)
