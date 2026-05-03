-- LibCodex-1.0 / Modules / Catalog / EncounterCreatures.lua
-- JournalEncounterCreature DBC: the creatures (boss + adds) that make up
-- each Journal encounter. Lets a raid-frame addon ask "show me every
-- creature display id this fight uses" without scraping Wowhead.
--
-- Schema:
--   id                   JournalEncounterCreatureID
--   journalEncounterID   the Journal encounter this creature belongs to
--   label                Name_lang
--   description          Description_lang
--   creatureDisplayInfoID  CreatureDisplayInfoID (model id)
--   fileDataID           FileDataID
--   orderIndex           UI sort order within the encounter
--   uiModelSceneID       UiModelSceneID for the dungeon journal preview
--   sources              provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local EncounterCreatures = LibCodex.CollectionFactory.New("EncounterCreatures", {
    keyField = "id",
    searchFields = { "label", "description" },
})
function EncounterCreatures:ForEncounter(journalEncounterID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.journalEncounterID == journalEncounterID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end
LibCodex:RegisterModule("EncounterCreatures", EncounterCreatures)
