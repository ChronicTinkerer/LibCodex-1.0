-- LibCodex-1.0 / Modules / Catalog / Pets.lua
-- Battle pet catalog. Schema:
--   id           BattlePetSpecies ID
--   label        species name ("Tiny Sporebat")
--   icon         icon path
--   family       petType: 1=Humanoid, 2=Dragonkin, 3=Flying, 4=Undead, 5=Critter,
--                6=Magic, 7=Elemental, 8=Beast, 9=Aquatic, 10=Mechanical
--   sourceType   how this pet is obtained (drop, vendor, quest, etc.)
--   creatureID   linked Creature ID (the in-world pet you can fight)
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Pets = LibCodex.CollectionFactory.New("Pets", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Pets", Pets)
