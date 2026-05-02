-- LibCodex-1.0 / Modules / Catalog / Professions.lua
-- Skill-line catalog. Includes the "real" professions (Blacksmithing,
-- Alchemy, Cooking, Fishing, etc.) plus secondary skill lines (Riding,
-- weapon proficiencies, languages). Filter by `professionEnum ~= nil` to
-- get just craftable professions.
--
-- Schema:
--   id            SkillLineID
--   label         display name (DisplayName_lang from SkillLine)
--   description   flavor text from the DBC
--   icon          SpellIconFileID (FileDataID)
--   categoryID    SkillLineCategory grouping
--   parentID      ParentSkillLineID (subskill chain)
--   professionEnum  ProfessionEnumValue from the Profession DBC, when set
--   actionType    ActionTypeEnumValue from the Profession DBC (Crafting/Gathering)
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Professions = LibCodex.CollectionFactory.New("Professions", {
    keyField = "id",
    searchFields = { "label", "description" },
})

function Professions:Craftable()
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.professionEnum then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Professions", Professions)
