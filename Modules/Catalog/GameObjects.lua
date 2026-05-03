-- LibCodex-1.0 / Modules / Catalog / GameObjects.lua
-- Catalog of in-world interactable objects: containers (chests, lockboxes),
-- gather nodes (herbs, ore, fish), mailboxes, quest objects, doors, etc.
-- Same shape as NPCs but for things with GameObject- GUIDs.
--
-- Schema (every field optional except id):
--   id          numeric object ID (extracted from GameObject GUID)
--   label       display name as scanned from tooltip / mouseover
--   type        coarse category: "Container", "Herb", "Ore", "Fish",
--               "Mailbox", "QuestObject", "Door", "Other"
--   locations   array of { mapID, x, y, zone }
--   drops       map of itemID -> { count, lastSeen, locations[] }
--               (populated by Adapters/Runtime.lua loot capture)
--   notes       free-text
--   sources     array of source tags

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local GameObjects = CC.New("GameObjects", {
    keyField = "id",
    searchFields = { "label", "type", "notes" },
})

-- Append a sighted location to an existing entry (or create one). Avoids
-- duplicating identical locations within a small tolerance.
function GameObjects:AddLocation(id, mapID, x, y, zone, ctx)
    -- ctx (optional) tags the location with chromie / expansion captured at
    -- the moment of sighting so consumers can later filter by chromie state.
    local entry = self:Get(id) or self:Add({ id = id, locations = {} })
    entry.locations = entry.locations or {}
    for _, loc in ipairs(entry.locations) do
        if loc.mapID == mapID
            and math.abs((loc.x or 0) - (x or 0)) < 0.001
            and math.abs((loc.y or 0) - (y or 0)) < 0.001 then
            if ctx then
                if ctx.chromieID and not loc.chromieID then loc.chromieID = ctx.chromieID end
                if ctx.expansion and not loc.expansion then loc.expansion = ctx.expansion end
            end
            return entry
        end
    end
    local loc = { mapID = mapID, x = x, y = y, zone = zone }
    if ctx then
        if ctx.chromieID then loc.chromieID = ctx.chromieID end
        if ctx.expansion then loc.expansion = ctx.expansion end
    end
    table.insert(entry.locations, loc)
    return entry
end

-- Filter helper: every location for a game object that matches the given
-- chromie expansion id. Pass nil to get only locations with no chromie tag.
function GameObjects:LocationsForChromie(objectID, chromieID)
    local entry = self:Get(objectID)
    if not entry or not entry.locations then return {} end
    local out = {}
    for _, loc in ipairs(entry.locations) do
        if loc.chromieID == chromieID then out[#out + 1] = loc end
    end
    return out
end

-- Record that this object dropped an item at the given location. Builds the
-- per-source drops map and a per-location count. Items module also records
-- the reverse pointer so `/codex where <itemID>` can list every source.
function GameObjects:AddDrop(objectID, itemID, mapID, x, y)
    local entry = self:Get(objectID) or self:Add({ id = objectID, drops = {} })
    entry.drops = entry.drops or {}
    local d = entry.drops[itemID]
    if not d then
        d = { count = 0, lastSeen = 0, locations = {} }
        entry.drops[itemID] = d
    end
    d.count = (d.count or 0) + 1
    if time then d.lastSeen = time() end
    if mapID then
        local found
        for _, loc in ipairs(d.locations) do
            if loc.mapID == mapID
                and math.abs((loc.x or 0) - (x or 0)) < 0.005
                and math.abs((loc.y or 0) - (y or 0)) < 0.005 then
                loc.count = (loc.count or 0) + 1
                found = true
                break
            end
        end
        if not found then
            table.insert(d.locations, { mapID = mapID, x = x, y = y, count = 1 })
        end
    end
    return entry
end

-- Filter helpers: list all gather nodes / containers / mailboxes / etc.
function GameObjects:OfType(t)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.type == t then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("GameObjects", GameObjects)
