-- LibCodex-1.0 / Modules / Catalog / ItemEffects.lua
-- The "use" / proc effects items grant. Potions, scrolls, trinkets,
-- on-equip auras, on-use abilities — anything that fires a spell from an
-- item routes through one of these rows. The bridge from a specific item
-- to its effects is ItemXItemEffect, captured into `items[]` below.
--
-- Schema:
--   id              ItemEffectID
--   spellID         the spell this effect casts
--   triggerType     0=OnUse, 1=OnEquip, 2=OnProc, 3=OnLearn, 6=OnLooted, ...
--   charges         max charges (0 = unlimited)
--   cooldownMS      cooldown in milliseconds
--   categoryCooldownMS  cooldown shared across the spell category
--   spellCategoryID category id (shared cooldown grouping)
--   specID          ChrSpecializationID restriction (0 = any spec)
--   playerCondition PlayerConditionID gate
--   slotIndex       LegacySlotIndex (legacy; usually 0 in modern data)
--   items           array of ItemIDs that grant this effect (post-processor
--                   walks ItemXItemEffect and attaches them here)
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local ItemEffects = LibCodex.CollectionFactory.New("ItemEffects", {
    keyField = "id",
    searchFields = {},
})

function ItemEffects:ForSpell(spellID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.spellID == spellID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("ItemEffects", ItemEffects)
