-- LibCodex-1.0 / Modules / Catalog / Reputations.lua
-- All Faction.dbc entries: player-facing reputation factions plus internal
-- NPC combat factions. Distinct from Modules/Enums/Factions.lua which lists
-- only the three player factions (Alliance/Horde/Neutral).
local LibCodex = LibStub("LibCodex-1.0")
local Reputations = LibCodex.CollectionFactory.New("Reputations", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Reputations", Reputations)
