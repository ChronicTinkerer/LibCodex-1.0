-- LibCodex-1.0 / Modules / Catalog / ItemSets.lua
-- ItemSet catalog: tier sets, dungeon sets, and any grouping of equippable
-- items that grants set bonuses. Each entry lists the member items and any
-- set-bonus spells that fire when N pieces are equipped.
--
-- Schema:
--   id              ItemSetID
--   label           Name_lang
--   requiredSkill   SkillLineID required to equip the set (e.g. plate proficiency)
--   requiredSkillRank  minimum skill rank
--   flags           raw ItemSet.SetFlags
--   items           array of ItemIDs that make up the set (max 17 slots in DBC)
--   bonuses         array of { threshold, spellID, specID, traitSubTreeID }
--                   from ItemSetSpell — granted at `threshold` pieces equipped
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local ItemSets = LibCodex.CollectionFactory.New("ItemSets", {
    keyField = "id",
    searchFields = { "label" },
})

-- Convenience: every ItemSet that contains the given item.
function ItemSets:ForItem(itemID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.items then
            for _, iid in ipairs(e.items) do
                if iid == itemID then out[#out + 1] = e; break end
            end
        end
    end
    return out
end

LibCodex:RegisterModule("ItemSets", ItemSets)
