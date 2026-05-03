-- LibCodex-1.0 / Modules / Catalog / Areas.lua
-- AreaTable catalog. Areas are sub-zones within UiMaps. The Zones module
-- gives you the map-level entries (Elwynn Forest, Stormwind City, etc.)
-- whereas Areas gives you the finer-grained sub-zone names (Goldshire,
-- Northshire Abbey, the Trade District). Both fire to the player as the
-- "you have entered ..." text and minimap subzone label.
--
-- Schema:
--   id              AreaID
--   label           AreaName_lang (player-facing sub-zone name)
--   zoneName        ZoneName (internal/short name; sometimes empty)
--   continentID     ContinentID (matches the legacy continent enum)
--   parentAreaID    AreaTable.ParentAreaID — usually the enclosing zone
--   factionGroupMask  bitmask of factions this sub-zone applies to
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Areas = LibCodex.CollectionFactory.New("Areas", {
    keyField = "id",
    searchFields = { "label", "zoneName" },
})

-- Walk up the parent chain. Returns a list of areas from this one to the
-- root, e.g. for Goldshire -> { Goldshire, Elwynn Forest, Eastern Kingdoms }.
function Areas:Path(areaID, maxDepth)
    maxDepth = maxDepth or 16
    local out = {}
    local cur = areaID
    for _ = 1, maxDepth do
        if cur == nil then break end
        local entry = self:Get(cur)
        if not entry then break end
        out[#out + 1] = entry
        cur = entry.parentAreaID
    end
    return out
end

LibCodex:RegisterModule("Areas", Areas)
