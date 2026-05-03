-- LibCodex-1.0 / Modules / Catalog / PvpTalents.lua
-- PvP-only talent catalog. Sibling to the Talents module (which covers the
-- regular trait/talent tree). PvP talents are slot-based: each spec gets
-- access to a pool, and the player picks N of them when in War Mode or
-- inside a battleground/arena.
--
-- Schema:
--   id              PvpTalentID
--   spellID         the spell this talent grants
--   description     OverrideDescription_lang
--   specID          ChrSpecializationID this talent belongs to
--   categoryID      PvpTalentCategoryID
--   levelRequired   minimum character level
--   actionBarSpellID  spell id to put on the action bar (overrides spellID)
--   overridesSpellID  spell this PvP talent replaces (when slotted)
--   playerCondition  gating PlayerConditionID
--   flags           raw PvpTalent.Flags
--   sources         provenance tags
--
-- The `label` field is filled at runtime by joining the underlying SpellID
-- against LibCodex:Spells():Get(spellID), same pattern as Crafts:GetLabel.

local LibCodex = LibStub("LibCodex-1.0")
local PvpTalents = LibCodex.CollectionFactory.New("PvpTalents", {
    keyField = "id",
    searchFields = { "label", "description" },
})

-- Resolve human-readable label from the backing spell. Caches in the entry.
function PvpTalents:GetLabel(talentID)
    local e = self:Get(talentID)
    if not e then return nil end
    if e.label then return e.label end
    if e.spellID and LibCodex.modules.Spells then
        local sp = LibCodex.modules.Spells:Get(e.spellID)
        if sp and sp.label then
            e.label = sp.label
            return e.label
        end
    end
    return nil
end

function PvpTalents:ForSpec(specID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.specID == specID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("PvpTalents", PvpTalents)
