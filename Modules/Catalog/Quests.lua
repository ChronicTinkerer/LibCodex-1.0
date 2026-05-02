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

    return self:Add(entry)
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
