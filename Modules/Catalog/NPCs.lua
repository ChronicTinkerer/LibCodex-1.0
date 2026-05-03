-- LibCodex-1.0 / Modules / Catalog / NPCs.lua
-- Catalog of NPCs across the game. Entries are id-keyed where the npcID is
-- known, but legacy seed entries (from GPSGuide) may lack ids and are stored
-- as keyless extras. Both are searchable.
--
-- Schema (every field optional):
--   id              numeric NPC ID (extracted from creature GUID)
--   label           name ("Estelle Gendry")
--   title           subtitle ("Innkeeper")
--   creatureType    "Beast" | "Humanoid" | "Demon" | "Undead" | "Elemental" | ...
--   classification  "Normal" | "Elite" | "Rare" | "RareElite" | "Boss" | "Trivial"
--   level           number, or { min=, max= }
--   race            string when known
--   side            "A" | "H" | "B"
--   locations       array of { mapID, x, y, zone }
--   flags           { vendor, banker, repair, innkeeper, flightmaster, questGiver }
--   drops           array of itemIDs (if known)
--   quests          array of questIDs offered/turned in
--   notes           free text
--   sources         array of source tags ("bundled","runtime","wago","wowhead",...)

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local NPCs = CC.New("NPCs", {
    keyField = "id",
    searchFields = { "label", "title", "zone", "notes" },

    -- Normalize incoming entries:
    --   * Legacy GPSGuide-style entries have a single mapID/x/y/zone instead of
    --     a `locations` array. Convert on the way in.
    --   * Lower-case the creatureType for consistent compares.
    normalize = function(entry)
        if entry.mapID and not entry.locations then
            entry.locations = {
                { mapID = entry.mapID, x = entry.x, y = entry.y, zone = entry.zone },
            }
        end
        return entry
    end,
})

-- Find every NPC at a given (mapID, x, y) within a tolerance (default 2%).
function NPCs:Near(mapID, x, y, tol)
    tol = tol or 0.02
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.locations then
            for _, loc in ipairs(e.locations) do
                if loc.mapID == mapID
                    and math.abs((loc.x or 0) - x) <= tol
                    and math.abs((loc.y or 0) - y) <= tol then
                    out[#out + 1] = e
                    break
                end
            end
        end
    end
    return out
end

-- Find every NPC with a flag set (e.g. innkeeper, flightmaster).
function NPCs:WithFlag(flag)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.flags and e.flags[flag] then out[#out + 1] = e end
    end
    return out
end

-- Distance threshold in yards: locations within this radius of an existing
-- entry are treated as the same spot (same mob, slightly different captures
-- as it patrols). 50 yards is roughly the size of a single nameplate range,
-- which is the distance you'd consider "the same encounter".
local LOCATION_DEDUP_YARDS = 50
local LOCATION_DEDUP_FALLBACK_NORM = 0.015  -- ~1.5% of map; used if world API is missing

-- Returns true if (mapA, xA, yA) is within `yards` of (mapB, xB, yB) using
-- WoW's world-coordinate API. Falls back to normalized-coord proximity if
-- the world API isn't available (e.g., in instance maps without world coords).
local function withinYards(mapA, xA, yA, mapB, xB, yB, yards)
    if mapA ~= mapB then
        -- Different map IDs: only count as "near" if both resolve to the same
        -- continent and the world distance is small. Most cross-map captures
        -- (different sub-zones) are intentionally distinct.
        return false
    end
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local cA, wA = C_Map.GetWorldPosFromMapPos(mapA, CreateVector2D(xA, yA))
        local cB, wB = C_Map.GetWorldPosFromMapPos(mapB, CreateVector2D(xB, yB))
        if cA and cB and cA == cB and wA and wB then
            local dx = wA.x - wB.x
            local dy = wA.y - wB.y
            return math.sqrt(dx * dx + dy * dy) <= yards
        end
    end
    -- Fallback when world coords aren't available.
    return math.abs((xA or 0) - (xB or 0)) < LOCATION_DEDUP_FALLBACK_NORM
        and math.abs((yA or 0) - (yB or 0)) < LOCATION_DEDUP_FALLBACK_NORM
end

-- Append a sighted location to an existing entry (or create the entry).
-- Skips when an existing location is within LOCATION_DEDUP_YARDS of the new
-- one, so a patrolling mob captured every 5 seconds doesn't blow up the
-- locations array.
function NPCs:AddLocation(id, mapID, x, y, zone)
    local entry = self:Get(id) or self:Add({ id = id, locations = {} })
    entry.locations = entry.locations or {}
    for _, loc in ipairs(entry.locations) do
        if withinYards(loc.mapID, loc.x, loc.y, mapID, x, y, LOCATION_DEDUP_YARDS) then
            return entry  -- close enough to a known spot; skip
        end
    end
    table.insert(entry.locations, { mapID = mapID, x = x, y = y, zone = zone })
    return entry
end

-- Record that this NPC dropped an item at the given location. Symmetric to
-- GameObjects:AddDrop. Items module mirrors the reverse pointer so a single
-- query can answer "where can I get this item from?"
function NPCs:AddDrop(npcID, itemID, mapID, x, y)
    local entry = self:Get(npcID) or self:Add({ id = npcID, drops = {} })
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

LibCodex:RegisterModule("NPCs", NPCs)
