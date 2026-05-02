-- LibCodex-1.0 / Modules / Enums / Classes.lua
-- The 13 player classes in retail WoW. Stable across patches; bundled fully.
-- Schema per entry:
--   id           numeric class ID (matches Blizzard's GetClassInfo / classID)
--   label        display name ("Mage", "Death Knight", ...)
--   token        engine token ("MAGE", "DEATHKNIGHT") — used by RAID_CLASS_COLORS etc.
--   icon         classic icon path
--   primaryStat  "Strength" / "Agility" / "Intellect"
--   resource     base resource ("MANA", "RAGE", "ENERGY", "FOCUS", "RUNIC_POWER")
--   roles        array of roles available across all specs ("TANK","HEALER","DAMAGER")
--   color        { r=, g=, b=, hex= } from class colors
--   armor        primary armor type ("Cloth","Leather","Mail","Plate")

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local Classes = CC.New("Classes", {
    keyField = "id",
    searchFields = { "label", "token" },
})

LibCodex:RegisterModule("Classes", Classes)

-- Convenience accessor: GetByToken("MAGE") -> class entry.
function Classes:GetByToken(token)
    if not token then return nil end
    for _, e in pairs(self:AllRaw()) do
        if e.token == token then return e end
    end
    return nil
end
