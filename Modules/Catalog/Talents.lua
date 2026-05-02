-- LibCodex-1.0 / Modules / Catalog / Talents.lua
-- Talent / trait catalog. Modern WoW (Dragonflight+) talent system based on
-- TraitDefinition: each entry is one selectable talent on a class or spec
-- talent tree.
--
-- Schema:
--   id            TraitDefinitionID
--   label         OverrideName_lang (falls back to spell name at runtime)
--   description   OverrideDescription_lang
--   icon          OverrideIcon (FileDataID; nil means "use spell icon")
--   spellID       backing spell id (the thing the talent grants)
--   treeID        TraitTreeID this talent belongs to
--   treeName      human-readable tree label (e.g. "Druid", "Restoration")
--   subTreeID     TraitSubTreeID for hero-talent (TWW) entries
--   subTreeName   hero-talent label (e.g. "Druid of the Claw")
--   maxRanks      max points investable in this talent
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Talents = LibCodex.CollectionFactory.New("Talents", {
    keyField = "id",
    searchFields = { "label", "description", "treeName", "subTreeName" },
})

-- ----------------------------------------------------------------------------
-- Convenience filters.
-- ----------------------------------------------------------------------------

function Talents:ForTree(treeID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.treeID == treeID then out[#out + 1] = e end
    end
    return out
end

function Talents:ForSubTree(subTreeID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.subTreeID == subTreeID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Talents", Talents)
