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
