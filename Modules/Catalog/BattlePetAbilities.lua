-- LibCodex-1.0 / Modules / Catalog / BattlePetAbilities.lua
-- Pet-battle ability catalog. Each entry is one move a battle pet can use.
-- The Pets module's `abilities` field cross-references these by id.
--
-- Schema:
--   id              BattlePetAbilityID
--   label           Name_lang
--   description     Description_lang
--   icon            IconFileDataID
--   petType         PetTypeEnum (1=Humanoid, 2=Dragonkin, ..., 10=Elemental)
--   cooldown        Cooldown turns
--   visualID        BattlePetVisualID (for visualizing the ability)
--   flags           raw BattlePetAbility.Flags
--   sources         provenance tags
--
-- Pets that can learn this ability are recorded inline as `species[]` (an
-- array of { speciesID, requiredLevel, slotEnum }), populated by the
-- BattlePetSpeciesXAbility post-processor.

local LibCodex = LibStub("LibCodex-1.0")
local BattlePetAbilities = LibCodex.CollectionFactory.New("BattlePetAbilities", {
    keyField = "id",
    searchFields = { "label", "description" },
})

function BattlePetAbilities:ByPetType(t)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.petType == t then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("BattlePetAbilities", BattlePetAbilities)
