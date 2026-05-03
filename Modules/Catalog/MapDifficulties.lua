-- LibCodex-1.0 / Modules / Catalog / MapDifficulties.lua
-- MapDifficulty DBC: which difficulty tiers each instance offers, with
-- per-tier reset interval and player caps. One row per (map, difficulty).
--
-- Schema:
--   id              MapDifficultyID
--   mapID           Map (-> Maps module)
--   difficultyID    Difficulty (-> Difficulty module)
--   message         Message_lang (e.g. "This dungeon is in Mythic mode.")
--   maxPlayers      MaxPlayers cap
--   resetInterval   ResetInterval (seconds)
--   lockID          LockID (instance lock grouping)
--   contentTuningID ContentTuningID for level scaling
--   itemContext     ItemContext id (loot context)
--   itemContextPickerID  ItemContextPickerID
--   worldStateExpressionID  WorldStateExpressionID
--   flags           raw MapDifficulty.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local MapDifficulties = LibCodex.CollectionFactory.New("MapDifficulties", {
    keyField = "id",
    searchFields = { "message" },
})
function MapDifficulties:ForMap(mapID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.mapID == mapID then out[#out + 1] = e end
    end
    return out
end
LibCodex:RegisterModule("MapDifficulties", MapDifficulties)
