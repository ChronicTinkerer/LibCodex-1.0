-- LibCodex-1.0 / Modules / Catalog / EncounterSections.lua
-- JournalEncounterSection DBC: the strategy text sections inside the
-- dungeon journal for each boss fight. Sections form a tree (Parent /
-- FirstChild / NextSibling) so consumers can render the same outline the
-- in-game journal shows.
--
-- Schema:
--   id                   JournalEncounterSectionID
--   journalEncounterID   the encounter this section belongs to
--   title                Title_lang
--   bodyText             BodyText_lang
--   parentSectionID      ParentSectionID (0 = top-level)
--   firstChildSectionID  FirstChildSectionID
--   nextSiblingSectionID NextSiblingSectionID
--   orderIndex           OrderIndex
--   type                 section Type enum
--   spellID              SpellID this section describes (0 = none)
--   icon                 IconFileDataID
--   iconCreatureDisplayInfoID  IconCreatureDisplayInfoID
--   uiModelSceneID       UiModelSceneID
--   difficultyMask       which difficulties this section applies to
--   flags                raw JournalEncounterSection.Flags
--   iconFlags            IconFlags
--   sources              provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local EncounterSections = LibCodex.CollectionFactory.New("EncounterSections", {
    keyField = "id",
    searchFields = { "title", "bodyText" },
})
function EncounterSections:ForEncounter(journalEncounterID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.journalEncounterID == journalEncounterID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end
LibCodex:RegisterModule("EncounterSections", EncounterSections)
