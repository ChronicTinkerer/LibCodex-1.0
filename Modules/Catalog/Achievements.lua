-- LibCodex-1.0 / Modules / Catalog / Achievements.lua
-- Achievement catalog. Schema:
--   id           AchievementID
--   label        achievement title
--   description  flavor text
--   points       reward points
--   icon         icon path
--   categoryID   AchievementCategory id
--   side         "A" | "H" | "B" (faction restriction if any)
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Achievements = LibCodex.CollectionFactory.New("Achievements", {
    keyField = "id",
    searchFields = { "label", "description" },
})
LibCodex:RegisterModule("Achievements", Achievements)
