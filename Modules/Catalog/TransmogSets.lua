-- LibCodex-1.0 / Modules / Catalog / TransmogSets.lua
-- Transmog set catalog. Each entry is a named appearance set the player
-- can collect (raid tier visuals, mage-tower sets, dungeon sets, etc.).
-- Backed by TransmogSet DBC, with member appearances attached from
-- TransmogSetItem.
--
-- Schema:
--   id              TransmogSetID
--   label           Name_lang
--   classMask       bitmask of class restrictions (0 = no restriction)
--   trackingQuestID  quest used to track collection state
--   parentID        ParentTransmogSetID (variants share a parent)
--   groupID         TransmogSetGroupID (UI group bucketing)
--   expansion       ExpansionID
--   patchIntroduced  PatchIntroduced (encoded patch number)
--   uiOrder         UiOrder
--   flags           raw TransmogSet.Flags
--   appearances     array of ItemModifiedAppearanceIDs that make up the set
--                   (attached by post-processor walking TransmogSetItem)
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local TransmogSets = LibCodex.CollectionFactory.New("TransmogSets", {
    keyField = "id",
    searchFields = { "label" },
})

function TransmogSets:ForExpansion(expID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.expansion == expID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("TransmogSets", TransmogSets)
