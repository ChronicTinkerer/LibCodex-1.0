-- LibCodex-1.0 / Modules / Enums / CreatureTypes.lua
-- Non-player "races" — the creature type categories used to classify NPCs:
-- Beast, Humanoid, Demon, Dragonkin, Elemental, Giant, Undead, Mechanical,
-- etc. Distinct from Modules/Enums/Races.lua, which lists playable races.
--
-- Schema:
--   id    numeric type ID (matches CreatureType.dbc and the value returned
--         by UnitCreatureType when adjusted)
--   label display name ("Beast", "Humanoid", etc.)

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local CreatureTypes = CC.New("CreatureTypes", {
    keyField = "id",
    searchFields = { "label" },
})

LibCodex:RegisterModule("CreatureTypes", CreatureTypes)
