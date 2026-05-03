-- LibCodex-1.0 / Modules / Catalog / ItemModifiedAppearances.lua
-- The bridge between an Item (with its modifier id) and an ItemAppearance.
-- Each row says "Item X with modifier M shows appearance A". TransmogSets
-- references these IDs (`appearances[]` is an array of ItemModifiedAppearance
-- IDs); this module lets you resolve them back to the source item.
--
-- Schema:
--   id              ItemModifiedAppearanceID
--   itemID          source item (-> Items module)
--   appearanceID    ItemAppearanceID (-> ItemAppearances module)
--   modifierID      ItemAppearanceModifierID (variant within the item)
--   orderIndex      UI sort order
--   sourceType      TransmogSourceTypeEnum (drop / vendor / quest / etc.)
--   flags           raw ItemModifiedAppearance.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local ItemModifiedAppearances = LibCodex.CollectionFactory.New("ItemModifiedAppearances", {
    keyField = "id",
    searchFields = {},
})

-- Convenience: every modified-appearance row that belongs to an item.
function ItemModifiedAppearances:ForItem(itemID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.itemID == itemID then out[#out + 1] = e end
    end
    return out
end

-- Convenience: every modified-appearance row that points at one appearance.
function ItemModifiedAppearances:ForAppearance(appearanceID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.appearanceID == appearanceID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("ItemModifiedAppearances", ItemModifiedAppearances)
