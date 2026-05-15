-- LibCodex-1.0 / Modules / Enums / Difficulty.lua
-- Instance / scenario difficulty enum. v2 slot schema (append-only):
--   1: id                    DifficultyID
--   2: label                 display name, Z85-encoded (string codec)
--   3: flags                 raw Difficulty.Flags bitfield
--   4: fallbackDifficultyID  difficulty to fall back to if empty
--   5: instanceType          1=Party 2=Raid 3=PvP 4=Scenario 5=WorldPvPScenario
--   6: maxPlayers
--   7: minPlayers
--   8: orderIndex            UI sort order
--   sources                  provenance, runtime-only

local LibCodex = LibStub("LibCodex-1.0")
local Difficulty = LibCodex.CollectionFactory.New("Difficulty", {
    keyField = "id",
    searchFields = { "label" },
})

-- ----------------------------------------------------------------------------
-- v2 compressed-format support. Slot 2 (label) is Z85-encoded with the
-- "string" codec: pad-byte prefix + UTF-8 text + trailing zero pad. Same
-- shape as Currencies.label / Currencies.categoryName.
-- ----------------------------------------------------------------------------

local function decodeZ85String(z85str)
    if type(z85str) ~= "string" or z85str == "" then return nil end
    local Z85 = LibStub and LibStub("LibZ85-1.0", true)
    if not Z85 then return nil end
    local ok, bytes = pcall(Z85.decode, z85str)
    if not ok or type(bytes) ~= "string" or #bytes < 1 then return nil end
    local pad = string.byte(bytes, 1)
    if pad < 0 or pad > 3 then return nil end
    local tail_end = #bytes - pad
    if tail_end < 1 then return "" end
    return string.sub(bytes, 2, tail_end)
end

function Difficulty:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end

    local id = slots[1]
    if type(id) ~= "number" or id <= 0 then return end

    local entry = { id = id, sources = { "bundled" } }

    if type(slots[2]) == "string" then entry.label                = decodeZ85String(slots[2]) end
    if type(slots[3]) == "number" then entry.flags                = slots[3] end
    if type(slots[4]) == "number" then entry.fallbackDifficultyID = slots[4] end
    if type(slots[5]) == "number" then entry.instanceType         = slots[5] end
    if type(slots[6]) == "number" then entry.maxPlayers           = slots[6] end
    if type(slots[7]) == "number" then entry.minPlayers           = slots[7] end
    if type(slots[8]) == "number" then entry.orderIndex           = slots[8] end

    if build then entry._build = build end

    self._entries[id] = entry
    self._count = (self._count or 0) + 1
end

function Difficulty:ForInstanceType(t)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.instanceType == t then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Difficulty", Difficulty)
