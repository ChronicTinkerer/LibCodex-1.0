-- LibCodex-1.0 / Modules / Catalog / SpellCooldowns.lua
-- Per-spell cooldown data from wago `SpellCooldowns` DBC.
--
-- Schema:
--   id                   SpellCooldowns row id
--   spellID              spell this cooldown applies to
--   difficultyID         difficulty filter (0 = any)
--   recoveryTime         spell-specific cooldown in ms
--   categoryRecoveryTime category-shared cooldown in ms
--   startRecoveryTime    GCD trigger in ms
--   auraSpellID          aura that gates this cooldown record
--   sources              provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellCooldowns = LibCodex.CollectionFactory.New("SpellCooldowns", {
    keyField = "id",
    searchFields = {},
})

function SpellCooldowns:ForSpell(spellID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.spellID == spellID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("SpellCooldowns", SpellCooldowns)
