-- LibCodex-1.0 / Modules / Catalog / QuestPOI.lua
-- Quest Points-Of-Interest: the markers Blizzard's quest tracker draws on
-- the world map. Each "blob" is a region or single point on a UiMap that
-- corresponds to a quest objective.
--
-- Schema:
--   id              QuestPOIBlobID
--   questID         the quest this POI belongs to
--   uiMapID         UiMap the POI is drawn on
--   mapID           internal map id (legacy)
--   objectiveIndex  which objective (0-based; matches QuestObjective.OrderIndex)
--   objectiveID     QuestObjective row id this POI maps to
--   numPoints       number of vertex points (1 = point waypoint, >1 = polygon)
--   points          array of { x, y, z } normalized 0..1 coords on uiMapID
--                   (attached by post-processor walking QuestPOIPoint)
--   flags           raw QuestPOIBlob.Flags
--   playerCondition gating PlayerConditionID
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local QuestPOI = LibCodex.CollectionFactory.New("QuestPOI", {
    keyField = "id",
    searchFields = {},  -- POIs aren't searched by text; lookup is by quest id
})

-- Convenience: every POI for a given quest, sorted by objective index.
function QuestPOI:ForQuest(questID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.questID == questID then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (a.objectiveIndex or 0) < (b.objectiveIndex or 0) end)
    return out
end

-- Convenience: every POI on a given UiMap.
function QuestPOI:ForMap(uiMapID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.uiMapID == uiMapID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("QuestPOI", QuestPOI)
