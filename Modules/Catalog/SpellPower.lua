-- LibCodex-1.0 / Modules / Catalog / SpellPower.lua
-- Per-spell power-cost data from wago `SpellPower` DBC. Tells you how
-- much mana / energy / rage / etc. a spell consumes, with separate flat,
-- per-second, and percentage-based components.
--
-- Schema:
--   id              SpellPower row id
--   spellID         the spell this cost applies to
--   orderIndex      multi-cost ordering (some spells have multiple costs)
--   powerType       UnitPowerType enum (0=Mana, 1=Rage, 2=Focus, 3=Energy, 6=RunicPower, ...)
--   manaCost        flat cost
--   manaCostPerLevel  scaling cost per character level
--   manaPerSecond   per-second drain (channels)
--   powerCostPct    percentage of base resource
--   powerCostMaxPct percentage of max resource
--   optionalCost    optional flat cost (overpowered casts)
--   optionalCostPct percentage variant
--   powerPctPerSecond  per-second percentage drain
--   powerDisplayID  PowerDisplay row id
--   altPowerBarID   alternate power bar id
--   requiredAuraSpellID  aura that gates this cost record
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SpellPower = LibCodex.CollectionFactory.New("SpellPower", {
    keyField = "id",
    searchFields = {},
})

function SpellPower:ForSpell(spellID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.spellID == spellID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("SpellPower", SpellPower)
