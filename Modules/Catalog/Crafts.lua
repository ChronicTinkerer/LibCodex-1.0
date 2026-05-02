-- LibCodex-1.0 / Modules / Catalog / Crafts.lua
-- Recipe catalog. Each entry is one SkillLineAbility — a spell that can be
-- cast when a profession reaches a given rank. This includes both crafting
-- recipes (e.g. "Smelt Copper") and gathering procs (e.g. "Mining"
-- subskills granted by Apprentice -> Grandmaster).
--
-- Schema:
--   id              SkillLineAbilityID
--   spellID         the spell this ability casts
--   skillLineID     parent SkillLine (cross-ref to Professions module)
--   minRank         MinSkillLineRank (skill points needed to learn)
--   trivialHigh     TrivialSkillLineRankHigh (skill where the recipe
--                   becomes grey/no longer levels you)
--   trivialLow      TrivialSkillLineRankLow
--   classMask       ClassMask (bitmask; 0 = all classes can learn)
--   raceMask        RaceMask (bitmask; 0 = all races)
--   acquireMethod   AcquireMethod enum (trainer / drop / quest / ...)
--   supercedesSpell  SupercedesSpell — older recipe this replaces
--   sources         provenance tags
--
-- The `label` for a craft is the underlying spell's name, attached at runtime
-- by joining against LibCodex:Spells():Get(spellID). We don't duplicate
-- spell names into this module; the catalog is already enormous.

local LibCodex = LibStub("LibCodex-1.0")
local Crafts = LibCodex.CollectionFactory.New("Crafts", {
    keyField = "id",
    searchFields = { "label" },  -- label is filled at lookup time when needed
})

-- Convenience: find every craft for a given profession (skill line).
function Crafts:ForProfession(skillLineID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.skillLineID == skillLineID then out[#out + 1] = e end
    end
    return out
end

-- Resolve the human-readable label by looking up the underlying spell.
-- Caches the result back into the entry so repeat queries don't re-hit Spells.
function Crafts:GetLabel(craftID)
    local e = self:Get(craftID)
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

LibCodex:RegisterModule("Crafts", Crafts)
