-- LibCodex-1.0 / Modules / Catalog / AreaTriggers.lua
-- AreaTrigger catalog. Server-defined invisible volumes that fire scripted
-- actions when a player walks through them. Used for: dungeon/raid entrance
-- portals, instance portals, zone-line transitions, "you have discovered X"
-- toasts, holiday event triggers, and many quest scripts.
--
-- Schema:
--   id              AreaTriggerID
--   continentID     ContinentID (the world map / instance map this lives in)
--   x, y, z         world-space position (Pos_0, Pos_1, Pos_2)
--   shapeType       0=Sphere, 1=Box, 2=Polygon, 3=Cylinder
--   shapeID         per-shape definition row id
--   radius          for sphere / cylinder shapes
--   boxLength       Box_length (for box shape)
--   boxWidth        Box_width
--   boxHeight       Box_height
--   boxYaw          Box_yaw (rotation)
--   actionSetID     AreaTriggerActionSetID (script bundle to run on entry)
--   phaseID         PhaseID (visibility gating)
--   phaseGroupID    PhaseGroupID
--   phaseUseFlags   PhaseUseFlags
--   flags           raw AreaTrigger.Flags
--   sources         provenance tags
--
-- Note: AreaTriggers have no Name_lang. Consumers identify them by id +
-- continent + position. Wowhead and similar tools annotate them externally.

local LibCodex = LibStub("LibCodex-1.0")
local AreaTriggers = LibCodex.CollectionFactory.New("AreaTriggers", {
    keyField = "id",
    searchFields = {},  -- no text fields; lookup by id or continent
})

function AreaTriggers:ForContinent(continentID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.continentID == continentID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("AreaTriggers", AreaTriggers)
