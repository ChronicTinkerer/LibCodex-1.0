-- LibCodex-1.0 / Modules / Catalog / Items.lua
-- Catalog of items keyed by itemID. The Runtime adapter calls AddFromAPI as
-- the player encounters items; that helper resolves item data via GetItemInfo
-- and re-tries asynchronously if the client cache is cold.
--
-- Schema (every field optional except id):
--   id                numeric itemID
--   label             item name
--   icon              texture path
--   quality           0..7 (Poor..Heirloom)
--   level             item level
--   requiredLevel     character level required to equip/use
--   type              item type ("Weapon", "Armor", "Consumable", ...)
--   subType           item subtype ("Sword", "Cloth", "Potion", ...)
--   equipLoc          INVTYPE_* slot string
--   bindType          0=none, 1=BoP, 2=BoE, 3=BoU, 4=Quest, 5=BoA
--   maxStack          stackable count
--   sellPrice         vendor sell price in copper
--   classID, subclassID  numeric class/subclass IDs
--   expansion         expansion ID (0..ongoing)
--   isCraftingReagent boolean
--   spell             { id, name } if the item triggers a spell on use
--   stats             table from GetItemStats (e.g. ITEM_MOD_STAMINA_SHORT=270)
--   tooltip           array of scanned tooltip lines (optional, expensive)
--   sources           array of source tags

local LibCodex = LibStub("LibCodex-1.0")
local CC = LibCodex.CollectionFactory

local Items = CC.New("Items", {
    keyField = "id",
    searchFields = { "label", "type", "subType" },
})

-- Pending async-load queue. itemID -> true while we wait for ITEM_DATA_LOAD_RESULT.
local pendingLoad = {}

-- Add (or refresh) an item by ID. Calls GetItemInfo synchronously; if the
-- client cache is cold (returns nil), requests an async load and merges in
-- when ITEM_DATA_LOAD_RESULT fires.
function Items:AddFromAPI(itemID, hyperlink)
    if type(itemID) ~= "number" then return nil end
    if not GetItemInfo then
        -- Outside-of-game (smoke testing). Just record the bare id.
        return self:Add({ id = itemID, sources = { "runtime" } })
    end

    local name, link, quality, level, reqLevel, type_, subType, maxStack,
          equipLoc, icon, sellPrice, classID, subclassID, bindType,
          expansion, _, isCraftingReagent = GetItemInfo(itemID)

    if not name then
        -- Cold cache. Ask the client to load it; we'll merge on the event.
        if not pendingLoad[itemID] then
            pendingLoad[itemID] = true
            if C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
        end
        return self:Add({ id = itemID, sources = { "runtime" } })
    end

    local entry = {
        id = itemID,
        label = name,
        icon = icon,
        quality = quality,
        level = level,
        requiredLevel = reqLevel,
        type = type_,
        subType = subType,
        equipLoc = equipLoc,
        bindType = bindType,
        maxStack = maxStack,
        sellPrice = sellPrice,
        classID = classID,
        subclassID = subclassID,
        expansion = expansion,
        isCraftingReagent = isCraftingReagent and true or false,
        sources = { "runtime" },
    }
    if hyperlink then entry.link = hyperlink end

    -- Optional: fetch stats. GetItemStats returns a table or nil.
    if GetItemStats and hyperlink then
        local stats = GetItemStats(hyperlink)
        if stats then entry.stats = stats end
    end

    return self:Add(entry)
end

-- Internal: handler for ITEM_DATA_LOAD_RESULT. Re-runs AddFromAPI for any
-- pending IDs that just landed.
function Items:_OnItemDataLoaded(itemID, success)
    if not pendingLoad[itemID] then return end
    pendingLoad[itemID] = nil
    if success then self:AddFromAPI(itemID) end
end

-- Filter helpers.
function Items:ByQuality(min, max)
    max = max or 7
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.quality and e.quality >= (min or 0) and e.quality <= max then
            out[#out + 1] = e
        end
    end
    return out
end

function Items:Reagents()
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.isCraftingReagent then out[#out + 1] = e end
    end
    return out
end

-- Reverse-pointer record: this item was just looted from this source. Builds
-- entry.dropsFrom keyed by source kind+id so /codex where <itemID> can list
-- every NPC and game object known to drop the item, with locations.
--   kind     "npc" | "gameobject"
--   sourceID numeric NPC or game object id
function Items:AddDropSource(itemID, kind, sourceID, mapID, x, y)
    if type(itemID) ~= "number" or type(sourceID) ~= "number" then return end
    local entry = self:Get(itemID) or self:Add({ id = itemID, sources = { "runtime" } })
    entry.dropsFrom = entry.dropsFrom or {}
    local key = (kind or "?") .. ":" .. sourceID
    local rec = entry.dropsFrom[key]
    if not rec then
        rec = { kind = kind, sourceID = sourceID, count = 0, lastSeen = 0, locations = {} }
        entry.dropsFrom[key] = rec
    end
    rec.count = (rec.count or 0) + 1
    if time then rec.lastSeen = time() end
    if mapID then
        local found
        for _, loc in ipairs(rec.locations) do
            if loc.mapID == mapID
                and math.abs((loc.x or 0) - (x or 0)) < 0.005
                and math.abs((loc.y or 0) - (y or 0)) < 0.005 then
                loc.count = (loc.count or 0) + 1
                found = true
                break
            end
        end
        if not found then
            table.insert(rec.locations, { mapID = mapID, x = x, y = y, count = 1 })
        end
    end
    return entry
end

-- Convenience query for "where can I get this item?". Returns an array of
-- { kind, sourceID, sourceLabel, count, locations[] } sorted by count.
function Items:GetDropSources(itemID)
    local entry = self:Get(itemID)
    if not entry or not entry.dropsFrom then return {} end
    local out = {}
    for _, rec in pairs(entry.dropsFrom) do
        local label
        if rec.kind == "npc" and LibCodex.modules.NPCs then
            local n = LibCodex.modules.NPCs:Get(rec.sourceID)
            if n then label = n.label end
        elseif rec.kind == "gameobject" and LibCodex.modules.GameObjects then
            local g = LibCodex.modules.GameObjects:Get(rec.sourceID)
            if g then label = g.label end
        end
        out[#out + 1] = {
            kind = rec.kind, sourceID = rec.sourceID,
            sourceLabel = label, count = rec.count, lastSeen = rec.lastSeen,
            locations = rec.locations,
        }
    end
    table.sort(out, function(a, b) return (a.count or 0) > (b.count or 0) end)
    return out
end

LibCodex:RegisterModule("Items", Items)
