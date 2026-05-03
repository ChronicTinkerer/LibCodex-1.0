-- LibCodex-1.0 / Modules / Catalog / Battlemasters.lua
-- BattlemasterList catalog. Each entry is a battleground, arena bracket,
-- or rated PvP queue. Includes Brawls and seasonal PvP holidays.
--
-- Schema:
--   id              BattlemasterListID
--   label           Name_lang (e.g. "Warsong Gulch", "2v2 Arena Skirmish")
--   gameType        GameType_lang ("Battleground", "Arena", "Rated")
--   shortDesc       ShortDescription_lang
--   longDesc        LongDescription_lang
--   instanceType    1=Battleground, 4=Arena, others
--   pvpType         PvpType enum
--   minLevel        minimum character level
--   maxLevel        maximum character level
--   ratedPlayers    expected rating-bracket player count
--   minPlayers      minimum group size
--   maxPlayers      maximum group size
--   maxGroupSize    biggest group that can queue together
--   icon            IconFileDataID
--   flags           raw BattlemasterList.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Battlemasters = LibCodex.CollectionFactory.New("Battlemasters", {
    keyField = "id",
    searchFields = { "label", "gameType", "shortDesc" },
})

function Battlemasters:ByInstanceType(t)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.instanceType == t then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Battlemasters", Battlemasters)
