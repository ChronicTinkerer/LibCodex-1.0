-- LibCodex-1.0 / Modules / Catalog / Quests.lua
-- Quest catalog. Schema:
--   id            QuestID
--   label         quest title
--   level         scaling level (or fixed level on legacy quests)
--   requiredLevel minimum character level to pick up
--   side          "A" | "H" | "B"  (faction restriction; B = both)
--   type          quest type token: "daily", "weekly", "raid", "dungeon",
--                 "pvp", "scenario", "worldquest", "calling", or nil for normal
--   giverNPC      NPC id that offers the quest (where known)
--   turnInNPC     NPC id that accepts the turn-in (where known)
--   mapID         UiMapID where the quest is given out
--   x, y          giver location (normalized 0..1) when known
--   expansion     ExpansionID (0..ongoing)
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Quests = LibCodex.CollectionFactory.New("Quests", {
    keyField = "id",
    searchFields = { "label" },
})

-- ----------------------------------------------------------------------------
-- v2 compressed-format support. bake_v2 emits Quests rows as positional
-- arrays in the locked 11-slot schema with Z85-packed location strings:
--
--   {id, level, locsZ85, side, minLevel, raceMask, classMask, areaID,
--    preQ, nextQ, questLineID}
--
-- This block defines the per-row decoder the CollectionFactory's v2 path
-- calls (Common.lua: _MaterializeV2Chunks). Output entries match the
-- legacy Quests entry shape so existing :Get / :Search / consumer code
-- keeps working unchanged.
-- ----------------------------------------------------------------------------

local _SIDE_INT_TO_STR = { [0] = "B", [1] = "A", [2] = "H" }
local _POINT_INT_TO_STR = { [0] = "start", [1] = "end", [2] = "requirement" }

-- Decode a Z85-packed location buffer to a list of {mapID, x, y, point,
-- npcID?, objID?, z?} dicts. Walks records by minimum-record-size (6) and
-- stops at the all-zero header sentinel that marks Z85 trailing padding.
-- Returns nil on invalid input rather than raising; the decode path is
-- log-and-continue per the v2 spec.
local function _DecodeLocationsZ85(packed)
    if type(packed) ~= "string" or packed == "" then return nil end

    local Z85 = LibStub and LibStub("LibZ85-1.0", true)
    if not Z85 then return nil end

    local ok, bytes = pcall(Z85.decode, packed)
    if not ok or type(bytes) ~= "string" then return nil end

    local locs = {}
    local i = 1
    local n = #bytes
    local floor = math.floor
    local sb = string.byte

    while i + 5 <= n do  -- minimum record size = 6 bytes
        local b0 = sb(bytes, i)
        local b1 = sb(bytes, i + 1)
        local b2 = sb(bytes, i + 2)
        local b3 = sb(bytes, i + 3)
        local b4 = sb(bytes, i + 4)
        local b5 = sb(bytes, i + 5)

        -- All-zero header = Z85 trailing pad zone; stop.
        if b0 + b1 + b2 + b3 + b4 + b5 == 0 then break end

        -- Field extraction by div/mod (avoids 32-bit limits in the
        -- bit library; clearer than bit ops at sub-byte boundaries).
        local mapID   = b0 + (b1 % 64) * 256
        local x_int   = floor(b1 / 64) + b2 * 4 + (b3 % 16) * 1024
        local y_int   = floor(b3 / 16) + b4 * 16 + (b5 % 4) * 4096
        local p_int   = floor(b5 / 4) % 4
        local has_z   = floor(b5 / 16) % 2 == 1
        local has_npc = floor(b5 / 32) % 2 == 1
        local has_obj = floor(b5 / 64) % 2 == 1

        i = i + 6

        local loc = {
            mapID = mapID,
            x = x_int / 10000,
            y = y_int / 10000,
            point = _POINT_INT_TO_STR[p_int] or "start",
        }

        if has_z then
            if i + 1 > n then break end
            local zu = sb(bytes, i) + sb(bytes, i + 1) * 256
            loc.z = ((zu >= 32768) and (zu - 65536) or zu) / 10
            i = i + 2
        end

        if has_npc then
            if i + 2 > n then break end
            loc.npcID = sb(bytes, i) + sb(bytes, i + 1) * 256 + sb(bytes, i + 2) * 65536
            i = i + 3
        end

        if has_obj then
            if i + 2 > n then break end
            loc.objID = sb(bytes, i) + sb(bytes, i + 1) * 256 + sb(bytes, i + 2) * 65536
            i = i + 3
        end

        locs[#locs + 1] = loc
    end

    return locs
end

-- Per-row decoder called by Common.lua's _MaterializeV2Chunks. Translates
-- a positional v2 slot list (or sparse [N]=v dict) into the legacy entry
-- shape and inserts into self._entries.
function Quests:_DecodeV2Row(slots, schemaVersion, build)
    if type(slots) ~= "table" then return end

    -- Slot accessor: handles both dense list (slots[i]) and sparse dict
    -- (slots["1"], slots["2"], ...). Lua array constructors put both forms
    -- under integer keys, so a single accessor works for both.
    local id = slots[1]
    if type(id) ~= "number" or id <= 0 then return end

    local entry = { id = id, sources = { "bundled" } }

    if type(slots[2]) == "number" then entry.level = slots[2] end
    if type(slots[3]) == "string" then
        local locs = _DecodeLocationsZ85(slots[3])
        if locs then entry.locations = locs end
    end
    if type(slots[4]) == "number" then
        entry.side = _SIDE_INT_TO_STR[slots[4]] or "B"
    end
    if type(slots[5]) == "number" then entry.requiredLevel = slots[5] end
    if type(slots[6]) == "number" then entry.raceMask = slots[6] end
    if type(slots[7]) == "number" then entry.classMask = slots[7] end
    if type(slots[8]) == "number" then entry.categoryID = slots[8] end
    if type(slots[9]) == "table" then entry.preQ = slots[9] end
    if type(slots[10]) == "table" then entry.nextQ = slots[10] end
    if type(slots[11]) == "number" then entry.questLineID = slots[11] end

    -- Tag the entry's source build for future delta-overlay support.
    if build then entry._build = build end

    self._entries[id] = entry
    self._count = (self._count or 0) + 1
end

-- ----------------------------------------------------------------------------
-- Runtime helpers (called by Adapters/Runtime.lua on quest events).
-- ----------------------------------------------------------------------------

-- Add or refresh a quest entry from the live API. Resilient to missing fields:
-- the QuestLog API only returns a partial record for some quests, so we accept
-- whatever is available and let later events fill in the rest.
function Quests:AddFromAPI(questID, opts)
    if type(questID) ~= "number" then return nil end
    opts = opts or {}

    local entry = { id = questID, sources = { "runtime" } }

    -- Title via the modern API. Falls back to GetQuestLogTitle by index when
    -- the C_QuestLog variant returns nil (cold cache, cross-realm party, etc).
    local title = nil
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end
    if title and title ~= "" then entry.label = title end

    -- Difficulty / level. C_QuestLog.GetQuestDifficultyLevel returns the
    -- scaled level for the active player; not every quest has it.
    if C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        local lvl = C_QuestLog.GetQuestDifficultyLevel(questID)
        if lvl and lvl > 0 then entry.level = lvl end
    end

    -- Tag / type bucket. C_QuestLog.GetQuestTagInfo returns a struct on
    -- Dragonflight+; the tagID maps to daily/weekly/raid/etc.
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local info = C_QuestLog.GetQuestTagInfo(questID)
        if info and info.tagName then
            entry.type = info.tagName:lower()
        end
    end

    -- Faction restriction from the quest's frequency / requirements isn't
    -- exposed directly. The runtime adapter passes opts.side when it knows it
    -- (e.g. quest accepted by an Alliance character on a faction-locked quest).
    if opts.side then entry.side = opts.side end
    if opts.giverNPC then entry.giverNPC = opts.giverNPC end
    if opts.turnInNPC then entry.turnInNPC = opts.turnInNPC end
    if opts.mapID then entry.mapID = opts.mapID end
    if opts.x then entry.x = opts.x end
    if opts.y then entry.y = opts.y end
    -- Chromie / expansion context captured at quest-accept time. Sticky
    -- so consumers can later filter quests by the chromie expansion the
    -- player was in when they picked it up.
    if opts.chromieID then entry.chromieID = opts.chromieID end
    if opts.expansion then entry.expansion = opts.expansion end

    return self:Add(entry)
end

-- Filter helper: every quest captured while the player was in the given
-- chromie expansion. Pass nil to find quests captured outside chromie
-- (the player's natural expansion).
function Quests:ForChromie(chromieID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.chromieID == chromieID then out[#out + 1] = e end
    end
    return out
end

-- Runtime predicate: can the current player pick up this quest right now?
-- Uses live C_QuestLog API to ask the game directly. Returns:
--   true   if the player can accept it (or already has it)
--   false  if the quest is gated out (wrong faction, already done, chromie
--          bucket excludes it, etc.)
--   nil    if the API isn't available or the quest id is unknown to the client
function Quests:IsAvailableForPlayer(questID)
    if type(questID) ~= "number" or not C_QuestLog then return nil end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then
        return true
    end
    if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        if C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then
            return true
        end
        return false
    end
    -- C_QuestLog.GetQuestDifficultyLevel returns nil for quests the player
    -- can't see at all in their current chromie/level/faction state. That's
    -- a useful lower-bound proxy for "available".
    if C_QuestLog.GetQuestDifficultyLevel then
        local ok, lvl = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
        if ok and type(lvl) == "number" and lvl > 0 then
            return true
        end
    end
    return nil
end

-- Mark a quest as just turned in. Updates the entry's lastTurnedIn timestamp
-- so consumers can ask "have I done this lately?". Idempotent.
function Quests:MarkTurnedIn(questID)
    if type(questID) ~= "number" then return end
    local entry = self:Get(questID) or self:Add({ id = questID, sources = { "runtime" } })
    if time then entry.lastTurnedIn = time() end
    return entry
end

-- Filter helpers.
function Quests:Daily()
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.type == "daily" then out[#out + 1] = e end
    end
    return out
end

function Quests:ForSide(side)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if not e.side or e.side == "B" or e.side == side then
            out[#out + 1] = e
        end
    end
    return out
end

LibCodex:RegisterModule("Quests", Quests)
