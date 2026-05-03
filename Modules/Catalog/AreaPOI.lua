-- LibCodex-1.0 / Modules / Catalog / AreaPOI.lua
-- Named map points-of-interest. Distinct from AreaTrigger (invisible volumes
-- that fire scripts) — these are the labeled markers Blizzard's world map
-- draws: capital portals, world bosses, gathering nodes (named ones),
-- flight points, mailboxes, vendors highlighted by Blizzard's UI, etc.
--
-- Schema:
--   id              AreaPoiID
--   label           Name_lang
--   description     Description_lang
--   x, y, z         world-space position (Pos_0/1/2)
--   continentID    ContinentID (instance / world map)
--   areaID          AreaTable id this POI sits in
--   portLocID       portal destination ref (when this POI teleports)
--   playerCondition  PlayerConditionID gate
--   uiAtlasMember   UiTextureAtlasMemberID (icon)
--   poiDataType     enum describing PoiData payload
--   poiData         payload (varies by poiDataType)
--   worldStateID    WorldStateID this POI is keyed to (for state-driven icons)
--   widgetSetID     UiWidgetSetID
--   flags           raw AreaPOI.Flags
--   states          array of state overlays from AreaPOIState (post-processor)
--                   each: { worldStateValue, iconEnumValue, description, atlasMember }
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local AreaPOI = LibCodex.CollectionFactory.New("AreaPOI", {
    keyField = "id",
    searchFields = { "label", "description" },
})

function AreaPOI:ForContinent(continentID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.continentID == continentID then out[#out + 1] = e end
    end
    return out
end

function AreaPOI:ForArea(areaID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.areaID == areaID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("AreaPOI", AreaPOI)
