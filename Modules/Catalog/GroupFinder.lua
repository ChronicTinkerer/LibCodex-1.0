-- LibCodex-1.0 / Modules / Catalog / GroupFinder.lua
-- GroupFinderActivity catalog: the "I'm looking for / I'm forming" listings
-- in the modern Premade Group Finder (LFGListFrame). Covers Mythic+ keystone
-- tiers, raid difficulties, Delve tiers, custom group types, etc.
--
-- Schema:
--   id              GroupFinderActivityID
--   label           FullName_lang
--   shortName       ShortName_lang
--   categoryID      GroupFinderCategoryID
--   categoryName    name resolved via post-processor (e.g. "Dungeons", "Raids")
--   groupID         GroupFinderActivityGrpID (sub-grouping)
--   groupName       group name resolved via post-processor
--   orderIndex      UI sort order
--   mapID           UI map id
--   difficultyID    Difficulty enum (-> Difficulty module)
--   areaID          AreaTable id
--   expansion       ExpansionID
--   maxPlayers      MaxPlayers
--   minGearLevel    MinGearLevelSuggestion
--   playerCondition PlayerConditionID gate
--   displayType     DisplayType enum
--   flags           raw GroupFinderActivity.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local GroupFinder = LibCodex.CollectionFactory.New("GroupFinder", {
    keyField = "id",
    searchFields = { "label", "shortName", "categoryName", "groupName" },
})

function GroupFinder:ByCategory(catID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.categoryID == catID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end

LibCodex:RegisterModule("GroupFinder", GroupFinder)
