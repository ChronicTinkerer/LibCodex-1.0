-- LibCodex-1.0 / Modules / Enums / Specs.lua
-- Player specializations (the 38 talent specs across the 13 classes).
-- Schema:
--   id           SpecializationID
--   label        spec name ("Frost", "Holy", "Survival")
--   classID      ChrClasses ID this spec belongs to
--   role         "TANK" | "HEALER" | "DAMAGER"
--   primaryStat  "Strength" | "Agility" | "Intellect"
--   icon         icon path
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Specs = LibCodex.CollectionFactory.New("Specs", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Specs", Specs)

-- Convenience: every spec for a given class.
function Specs:ForClass(classID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.classID == classID then out[#out + 1] = e end
    end
    return out
end
