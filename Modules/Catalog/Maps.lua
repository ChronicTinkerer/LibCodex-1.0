-- LibCodex-1.0 / Modules / Catalog / Maps.lua
-- The internal `Map` DBC. Each entry is a continent, zone, dungeon, raid,
-- battleground, scenario, or test map identified by the legacy MapID
-- (referenced from old APIs and many DBC tables). Distinct from `Zones`
-- which exposes the modern UiMap.
--
-- Schema:
--   id              MapID
--   directory       Directory (internal asset folder name)
--   label           MapName_lang
--   description     MapDescription0_lang
--   pvpDescription  PvpLongDescription_lang
--   mapType         MapType enum (continent/dungeon/raid/etc.)
--   instanceType    1=Party, 2=Raid, 3=PvP, 4=Scenario
--   expansion       ExpansionID
--   areaTableID     parent AreaTable id
--   parentMapID     ParentMapID
--   loadingScreenID LoadingScreenID
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Maps = LibCodex.CollectionFactory.New("Maps", {
    keyField = "id",
    searchFields = { "label", "description", "directory" },
})
function Maps:ByInstanceType(t)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.instanceType == t then out[#out + 1] = e end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Map projection helpers.
--
-- WoW exposes two coordinate systems:
--   * "World coords" -- continent-relative, in yards, used by COMBAT_LOG and
--     a lot of internal positional data.
--   * "UI map coords" -- normalized 0..1 within a UiMap (zone), used by the
--     world map and most addon UI (pin frames, minimap, etc.).
--
-- Catalog data we ship (NPC spawn coords from Wowhead, quest POI, vignettes)
-- is a mix: some sources give world coords, some give UI-map normalized.
-- These helpers wrap C_Map's projection calls so consumers don't have to
-- juggle Vector2D / boilerplate, and so the module degrades gracefully if
-- the API surface ever changes again.
--
-- Both return nil on failure (bad coords, no UiMap covering that point, or
-- the API not present in this client build).
-- ---------------------------------------------------------------------------

-- Convert continent world coordinates to a UI map id and normalized (x, y).
--   continentID  -- the continent UiMapID (Eastern Kingdoms = 13, Kalimdor =
--                   12, Outland = 101, Northrend = 113, etc.). NOT the legacy
--                   MapID stored in this module's `id` field.
--   worldX, worldY -- yards from the continent origin (combat log style).
-- Returns: uiMapID, x, y  (x,y in 0..1)  or nil if the point isn't on a
-- known UiMap.
function Maps:WorldToUiMap(continentID, worldX, worldY)
    if not (C_Map and C_Map.GetMapPosFromWorldPos) then return nil end
    if type(continentID) ~= "number" or
       type(worldX) ~= "number" or type(worldY) ~= "number" then
        return nil
    end
    local ok, uiMapID, pos = pcall(C_Map.GetMapPosFromWorldPos,
        continentID, worldX, worldY)
    if not ok or not uiMapID or not pos then return nil end
    local x, y = pos:GetXY()
    if not x or not y then return nil end
    return uiMapID, x, y
end

-- Convert a UI map normalized point back to continent world coordinates.
--   uiMapID -- the zone UiMapID the (x,y) is expressed in.
--   x, y    -- 0..1 normalized within that UiMap.
-- Returns: continentID, worldX, worldY (yards) or nil.
function Maps:UiMapToWorld(uiMapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
    if type(uiMapID) ~= "number" or
       type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    -- C_Map.GetWorldPosFromMapPos takes a Vector2D-ish table. We pass the
    -- minimal shape it accepts (an {x,y} table with GetXY metamethod is
    -- not required; the API will read positional fields).
    local point = { x = x, y = y }
    if CreateVector2D then
        point = CreateVector2D(x, y)
    end
    local ok, continentID, worldPos = pcall(C_Map.GetWorldPosFromMapPos,
        uiMapID, point)
    if not ok or not continentID or not worldPos then return nil end
    local wx, wy = worldPos:GetXY()
    if not wx or not wy then return nil end
    return continentID, wx, wy
end

-- Distance helper between two UI map points on the SAME uiMap. Returns
-- yards by round-tripping both points through the world coord system. Nil
-- if either point fails to project.
function Maps:UiDistance(uiMapID, ax, ay, bx, by)
    local _, awx, awy = self:UiMapToWorld(uiMapID, ax, ay)
    local _, bwx, bwy = self:UiMapToWorld(uiMapID, bx, by)
    if not awx or not bwx then return nil end
    local dx, dy = awx - bwx, awy - bwy
    return math.sqrt(dx * dx + dy * dy)
end

LibCodex:RegisterModule("Maps", Maps)
