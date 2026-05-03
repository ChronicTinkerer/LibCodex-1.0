-- LibCodex-1.0 / Modules / Enums / Difficulty.lua
-- Instance / scenario difficulty enum.
--
-- Schema:
--   id            DifficultyID
--   label         display name ("Mythic", "Heroic", "10 Player Heroic", ...)
--   instanceType  1=Party, 2=Raid, 3=PvP, 4=Scenario, 5=WorldPvPScenario
--   orderIndex    UI sort order
--   minPlayers    minimum group size
--   maxPlayers    maximum group size
--   fallbackDifficultyID  difficulty to fall back to if this one is empty
--   flags         raw Difficulty.Flags
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Difficulty = LibCodex.CollectionFactory.New("Difficulty", {
    keyField = "id",
    searchFields = { "label" },
})

function Difficulty:ForInstanceType(t)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.instanceType == t then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Difficulty", Difficulty)
