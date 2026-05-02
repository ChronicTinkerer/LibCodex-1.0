-- LibCodex-1.0 / Modules / Enums / Factions.lua
-- Player factions: Alliance, Horde, Neutral. Distinct from rep factions
-- (which live in Modules/Catalog/Reputations.lua under their own module).
-- Schema:
--   id    "A" | "H" | "N"
--   label "Alliance" | "Horde" | "Neutral"
--   color { r=, g=, b=, hex= }

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local Factions = CC.New("Factions", {
    keyField = "id",
    searchFields = { "label" },
})

LibCodex:RegisterModule("Factions", Factions)

-- Convenience: GetForPlayer() returns the entry matching the current player's
-- faction group. Returns Neutral entry as a fallback (e.g., Pandaren pre-choice).
function Factions:GetForPlayer()
    if UnitFactionGroup then
        local f = UnitFactionGroup("player")
        if f == "Alliance" then return self:Get("A") end
        if f == "Horde"    then return self:Get("H") end
    end
    return self:Get("N")
end
