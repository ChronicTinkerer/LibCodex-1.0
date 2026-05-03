-- LibCodex-1.0 / Modules / Catalog / LFGDungeons.lua
-- LFGDungeons catalog. Each entry is one dungeon, raid, or random group
-- queueable via the Group Finder (the original LFD/LFR/RDF system, not the
-- modern Premade Group Finder which lives in GroupFinder).
--
-- Schema:
--   id              LFGDungeonsID
--   label           Name_lang
--   description     Description_lang
--   typeID          1=Dungeon, 2=Raid, 4=Random, 6=Holiday, 7=Scenario
--   subtype         finer category enum
--   faction         0=Horde-only, 1=Alliance-only, -1=Both
--   icon            IconTextureFileID
--   expansion       ExpansionLevel
--   mapID           UI map id for the dungeon
--   difficultyID    Difficulty enum (-> Difficulty module)
--   minGear         minimum item level required
--   groupID         grouping bucket (e.g. all Mythic+ keystones share a group)
--   orderIndex      UI sort order
--   randomID        for "Random Heroic" type listings: the random pool id
--   scenarioID      ScenarioID for scenario dungeons
--   finalEncounterID  the boss whose kill marks completion
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local LFGDungeons = LibCodex.CollectionFactory.New("LFGDungeons", {
    keyField = "id",
    searchFields = { "label", "description" },
})

function LFGDungeons:ForExpansion(expID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.expansion == expID then out[#out + 1] = e end
    end
    return out
end

function LFGDungeons:ByType(typeID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.typeID == typeID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("LFGDungeons", LFGDungeons)
