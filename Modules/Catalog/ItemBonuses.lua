-- LibCodex-1.0 / Modules / Catalog / ItemBonuses.lua
-- Item modifier system. Each entry is one ItemBonusList — a named bundle
-- of bonus rows that can be applied to an item to alter its stats, ilvl,
-- sockets, tertiaries, etc. Items reference bonus lists by id in the
-- `:bonus_id1:bonus_id2:...` segment of their hyperlink.
--
-- Schema:
--   id              ItemBonusListID
--   flags           raw ItemBonusList.Flags
--   bonuses         array of { type, value0, value1, value2, value3, orderIndex }
--                   from ItemBonus rows with this id as ParentItemBonusListID
--                   (post-processor attaches; sorted by orderIndex)
--   sources         provenance tags
--
-- ItemBonus.Type enum (commonly seen, not exhaustive):
--   1 = item-level adjustment (Value_0 = delta)
--   2 = stat add (Value_0 = stat token id, Value_1 = amount)
--   6 = quality override (Value_0 = quality enum)
--   7 = description text (Value_0 = description id)
--   9 = required-level adjustment
--  11 = socket added
--  16 = bound until equipped
--  18 = relic-trait variant
-- (More types exist; consumers should handle unknown values gracefully.)

local LibCodex = LibStub("LibCodex-1.0")
local ItemBonuses = LibCodex.CollectionFactory.New("ItemBonuses", {
    keyField = "id",
    searchFields = {},
})

LibCodex:RegisterModule("ItemBonuses", ItemBonuses)
