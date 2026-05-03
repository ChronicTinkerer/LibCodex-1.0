-- LibCodex-1.0 / Modules / Catalog / AchievementCategories.lua
-- Achievement category catalog from wago `Achievement_Category` DBC. Each
-- entry is one bucket the achievements UI groups achievements under
-- ("Quests", "Exploration", "Player vs. Player", etc.). Categories can
-- nest via Parent.
--
-- Schema:
--   id        Achievement_CategoryID
--   label     Name_lang
--   parentID  Parent — 0/-1 = root
--   uiOrder   UI sort order
--   sources   provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local AchievementCategories = LibCodex.CollectionFactory.New("AchievementCategories", {
    keyField = "id",
    searchFields = { "label" },
})

-- Walk up the parent chain. Returns a list from this category to the root.
function AchievementCategories:Path(catID, maxDepth)
    maxDepth = maxDepth or 16
    local out, cur = {}, catID
    for _ = 1, maxDepth do
        if cur == nil or cur == 0 then break end
        local entry = self:Get(cur)
        if not entry then break end
        out[#out + 1] = entry
        cur = entry.parentID
    end
    return out
end

LibCodex:RegisterModule("AchievementCategories", AchievementCategories)
