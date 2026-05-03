-- LibCodex-1.0 / Modules / Catalog / SpellMechanics.lua
-- Per-spell category / mechanic / dispel-type bindings from wago
-- `SpellCategories` DBC (note the plural — distinct from `SpellCategory`
-- which defines the categories themselves; this table maps spells to them).
--
-- Schema:
--   id              SpellCategories row id
--   spellID         the spell this binding applies to
--   difficultyID    difficulty filter (0 = any)
--   category        SpellCategoryID (-> SpellChargeCategories module)
--   chargeCategory  separate charge-category cross-ref
--   defenseType     DefenseType enum (melee / ranged / etc.)
--   diminishType    DR category (root / stun / silence / ...)
--   dispelType      DispelType enum (magic / curse / disease / poison)
--   mechanic        Mechanic enum (slow / fear / charm / ...)
--   preventionType  prevention category
--   startRecoveryCategory  GCD category
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellMechanics = LibCodex.CollectionFactory.New("SpellMechanics", {
    keyField = "id",
    searchFields = {},
})

function SpellMechanics:ForSpell(spellID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.spellID == spellID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("SpellMechanics", SpellMechanics)
