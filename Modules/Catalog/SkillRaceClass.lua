-- LibCodex-1.0 / Modules / Catalog / SkillRaceClass.lua
-- SkillRaceClassInfo DBC: which races / classes can train each SkillLine,
-- with optional minimum level and tier gates. Used for "can my character
-- learn this skill" checks.
--
-- Schema:
--   id            SkillRaceClassInfoID
--   skillID       SkillLine id (-> Professions module)
--   raceMask      bitmask of allowed races (0 = any)
--   classMask     bitmask of allowed classes (0 = any)
--   raceMask1     RaceMasks_1 (extended bitmask for newer races)
--   minLevel      minimum character level
--   skillTierID   SkillTierID
--   availability  Availability enum
--   flags         raw SkillRaceClassInfo.Flags
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local SkillRaceClass = LibCodex.CollectionFactory.New("SkillRaceClass", {
    keyField = "id",
    searchFields = {},
})
function SkillRaceClass:ForSkill(skillID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.skillID == skillID then out[#out + 1] = e end
    end
    return out
end
LibCodex:RegisterModule("SkillRaceClass", SkillRaceClass)
