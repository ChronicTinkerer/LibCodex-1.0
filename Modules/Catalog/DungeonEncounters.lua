-- LibCodex-1.0 / Modules / Catalog / DungeonEncounters.lua
-- Combat-log encounter definitions. Each entry is one boss fight identified
-- by the encounter id that COMBAT_LOG_EVENT_UNFILTERED reports during boss
-- fights. Distinct from the Encounters module (which lists adventure-guide
-- entries: instances + JournalEncounter rows used for the dungeon journal).
--
-- DungeonEncounter ids are what BOSS_KILL events fire with and what
-- C_EncounterJournal correlates against. Combat addons (DBM, BigWigs, raid
-- frames, weakauras) need this id ↔ name mapping at runtime.
--
-- Schema:
--   id              DungeonEncounterID
--   label           Name_lang
--   mapID           encounter map id
--   difficultyID    Difficulty enum (-> Difficulty module)
--   orderIndex      UI / encounter order within the instance
--   bit             encounter completion bit index
--   completeWorldStateID  WorldState id flipped on kill
--   icon            SpellIconFileID
--   faction         faction restriction (-1 = any, 0 = horde-only, 1 = ally-only)
--   flags           raw DungeonEncounter.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local DungeonEncounters = LibCodex.CollectionFactory.New("DungeonEncounters", {
    keyField = "id",
    searchFields = { "label" },
})

function DungeonEncounters:ForMap(mapID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.mapID == mapID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    return out
end

LibCodex:RegisterModule("DungeonEncounters", DungeonEncounters)
