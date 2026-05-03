-- LibCodex-1.0 / Modules / Catalog / TradeSkillCategories.lua
-- Trade-skill category catalog. These are the sub-buckets the profession
-- window draws ("Bracers", "Helms", "Belts" inside Blacksmithing; "Potions"
-- and "Elixirs" inside Alchemy). Each row is one bucket within a SkillLine.
--
-- Schema:
--   id              TradeSkillCategoryID
--   label           Name_lang
--   hordeLabel      HordeName_lang (when names diverge)
--   parentID        ParentTradeSkillCategoryID (sub-buckets within categories)
--   skillLineID     SkillLine this category belongs to (-> Professions module)
--   orderIndex      UI sort order
--   flags           raw TradeSkillCategory.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local TradeSkillCategories = LibCodex.CollectionFactory.New("TradeSkillCategories", {
    keyField = "id",
    searchFields = { "label", "hordeLabel" },
})

function TradeSkillCategories:ForSkillLine(skillLineID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.skillLineID == skillLineID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end

LibCodex:RegisterModule("TradeSkillCategories", TradeSkillCategories)
