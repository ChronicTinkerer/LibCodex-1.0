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
LibCodex:RegisterModule("Maps", Maps)
