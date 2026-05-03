-- LibCodex-1.0 / Modules / Catalog / Scenarios.lua
-- Scenario catalog. Scenarios are short, mostly-soloable instances
-- (Proving Grounds, Brawler's Guild, TWW outdoor scenarios). Each entry
-- carries the scenario's stage definitions as a `steps` array.
--
-- Schema:
--   id              ScenarioID
--   label           Name_lang
--   areaTableID     AreaTable id where the scenario takes place
--   type            scenario type enum (1=Solo, 2=Group, etc.)
--   flags           raw Scenario.Flags
--   steps           array of { id, title, description, orderIndex,
--                              criteriaTreeID, rewardQuestID }
--                   sorted by orderIndex (post-processor attaches)
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Scenarios = LibCodex.CollectionFactory.New("Scenarios", {
    keyField = "id",
    searchFields = { "label" },
})

LibCodex:RegisterModule("Scenarios", Scenarios)
