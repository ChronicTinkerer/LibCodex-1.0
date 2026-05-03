-- LibCodex-1.0 / Modules / Catalog / CustomizationOptions.lua
-- Character-creation customization options. Each entry is a category like
-- "Hair Color", "Face", "Skin Tone", "Tattoos". The actual selectable values
-- live in the CustomizationChoices module, keyed by `optionID`.
--
-- Schema:
--   id              ChrCustomizationOptionID
--   label           Name_lang
--   secondaryID     SecondaryID (used by some shape-shifting forms)
--   chrModelID      ChrModelID this option targets
--   categoryID      ChrCustomizationCategoryID grouping
--   optionType      ChrCustomizationOption.OptionType enum
--   barberCost      BarberShopCostModifier
--   chrCustomID     ChrCustomizationID
--   requirement     ChrCustomizationOption.Requirement
--   orderIndex      UI sort order
--   secondaryOrderIndex SecondaryOrderIndex
--   addedInPatch    encoded patch number this option appeared in
--   flags           raw ChrCustomizationOption.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local CustomizationOptions = LibCodex.CollectionFactory.New("CustomizationOptions", {
    keyField = "id",
    searchFields = { "label" },
})

function CustomizationOptions:ForModel(chrModelID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.chrModelID == chrModelID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end

LibCodex:RegisterModule("CustomizationOptions", CustomizationOptions)
