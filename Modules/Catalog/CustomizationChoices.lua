-- LibCodex-1.0 / Modules / Catalog / CustomizationChoices.lua
-- The selectable values within a CustomizationOption. "Brown" / "Blonde" /
-- "Black" within the "Hair Color" option, or specific tattoo designs within
-- a "Tattoos" option.
--
-- Schema:
--   id              ChrCustomizationChoiceID
--   label           Name_lang (often empty for swatch-only choices)
--   optionID        ChrCustomizationOptionID this choice belongs to
--   reqID           ChrCustomizationReqID
--   visReqID        ChrCustomizationVisReqID
--   orderIndex      OrderIndex
--   uiOrderIndex    UiOrderIndex
--   soundKitID      SoundKitID (for /barbershop chair noises)
--   swatchColor0    SwatchColor_0 (premultiplied ARGB int)
--   swatchColor1    SwatchColor_1
--   addedInPatch    encoded patch number
--   flags           raw ChrCustomizationChoice.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local CustomizationChoices = LibCodex.CollectionFactory.New("CustomizationChoices", {
    keyField = "id",
    searchFields = { "label" },
})

function CustomizationChoices:ForOption(optionID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.optionID == optionID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end

LibCodex:RegisterModule("CustomizationChoices", CustomizationChoices)
