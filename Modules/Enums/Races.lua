-- LibCodex-1.0 / Modules / Enums / Races.lua
-- Player races including base + allied races as of TWW.
-- Schema:
--   id              numeric race ID matching Blizzard's GetPlayerInfoByGUID race ID
--   label           display name ("Human", "Lightforged Draenei", ...)
--   token           engine token ("Human", "LightforgedDraenei", ...)
--   side            "A" | "H" | "B" (Pandaren = "B" until they choose at level 10)
--   allied          true if this is an allied race
--   homeMapID       starting zone map ID (best-effort)

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local Races = CC.New("Races", {
    keyField = "id",
    searchFields = { "label", "token" },
})

LibCodex:RegisterModule("Races", Races)

function Races:GetByToken(token)
    if not token then return nil end
    for _, e in pairs(self:AllRaw()) do
        if e.token == token then return e end
    end
    return nil
end

function Races:ForFaction(side)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.side == side or e.side == "B" then out[#out + 1] = e end
    end
    return out
end
