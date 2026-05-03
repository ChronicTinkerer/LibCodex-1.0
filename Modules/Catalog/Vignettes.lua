-- LibCodex-1.0 / Modules / Catalog / Vignettes.lua
-- Map vignette catalog. Vignettes are the special markers Blizzard's map
-- shows for rare spawns, treasure chests, world bosses, dungeon entrances,
-- and similar one-off points of interest. The runtime fires VIGNETTES_UPDATED
-- when nearby vignettes change; this module gives addons names + types for
-- the ids those events report.
--
-- Schema:
--   id              VignetteID
--   label           display name (Name_lang from DBC)
--   vignetteType    1=NormalNPC, 2=Treasure, 3=RareElite, 4=Event, 5=Dungeon, ...
--                   (numeric; consumers can map to friendly strings)
--   rewardQuestID   QuestID this vignette completes (for "tracked" rares)
--   playerCondition PlayerConditionID gate
--   flags           raw Vignette.Flags
--   objectiveType   ObjectiveType from DBC
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Vignettes = LibCodex.CollectionFactory.New("Vignettes", {
    keyField = "id",
    searchFields = { "label" },
})

function Vignettes:ByType(vignetteType)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.vignetteType == vignetteType then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Vignettes", Vignettes)
