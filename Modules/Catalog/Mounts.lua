-- LibCodex-1.0 / Modules / Catalog / Mounts.lua
-- Mount catalog. Schema:
--   id           MountID
--   label        mount name ("Argent Charger")
--   icon         icon path
--   sourceType   numeric source category (drop, achievement, quest, vendor, ...)
--   spellID      spell that summons the mount
--   factionID    optional faction restriction
--   side         "A" | "H" | "B" (derived from faction-restriction)
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Mounts = LibCodex.CollectionFactory.New("Mounts", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Mounts", Mounts)
