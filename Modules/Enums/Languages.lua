-- LibCodex-1.0 / Modules / Enums / Languages.lua
-- Chat-language enum from wago `Languages` DBC. Common, Orcish, Dwarvish,
-- Thalassian, Demonic, Draconic, etc.
--
-- Schema:
--   id            LanguageID
--   label         Name_lang
--   flags         raw Languages.Flags
--   uiTextureKitID  UiTextureKitID
--   uiTextureKitElementCount UiTextureKitElementCount
--   learningCurveID LearningCurveID
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Languages = LibCodex.CollectionFactory.New("Languages", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Languages", Languages)
