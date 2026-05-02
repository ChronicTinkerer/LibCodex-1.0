-- LibCodex-1.0 / Modules / Catalog / FlightPoints.lua
-- Flight master / taxi node catalog. Schema:
--   id              TaxiNodeID
--   label           taxi node name (e.g. "Stormwind, Elwynn")
--   continentID     instance/continent map id (older WoW concept; still in DBC)
--   worldX/Y/Z      world-space coords from TaxiNodes DBC
--   mapID           UI map id (filled at runtime when the player visits)
--   x, y            normalized 0..1 coords on mapID (filled at runtime)
--   side            "A" | "H" | "B"  (filled at runtime; mount ids in DBC are
--                   ambiguous, so we let the API decide by faction)
--   bitNumber       CharacterBitNumber from DBC (used by Blizzard's known-node
--                   bitmask; useful if a consumer wants to read it directly)
--   mountCreatureA  Alliance flightmaster mount NPC id (best-effort from DBC)
--   mountCreatureH  Horde flightmaster mount NPC id (best-effort from DBC)
--   flags           TaxiNodes.Flags (raw)
--   known           per-character: true once the player has discovered it
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local FlightPoints = LibCodex.CollectionFactory.New("FlightPoints", {
    keyField = "id",
    searchFields = { "label" },
})

-- ----------------------------------------------------------------------------
-- Runtime helpers (called by Adapters/Runtime.lua on TAXIMAP_OPENED).
-- ----------------------------------------------------------------------------

-- Add or refresh a flight point from the live taxi-map API. The taxi map
-- exposes one entry per node visible to the player, with normalized 0..1
-- position on the current map and a discovery state.
--
--   index      taxi map slot index
--   currentMap UiMapID the taxi map is showing (caller passes this)
--   side       "A" | "H" — pass the player's faction
function FlightPoints:AddFromTaxiAPI(index, currentMap, side)
    if type(index) ~= "number" then return nil end
    if not (NumTaxiNodes and TaxiNodeName) then return nil end

    local name = TaxiNodeName(index)
    if not name or name == "" then return nil end

    local entry = { label = name, sources = { "runtime" } }

    -- Position on the taxi map (already 0..1).
    if TaxiNodePosition then
        local x, y = TaxiNodePosition(index)
        if x and y and (x ~= 0 or y ~= 0) then
            entry.x, entry.y = x, y
            if currentMap then entry.mapID = currentMap end
        end
    end

    -- Discovery state. CURRENT = player is here right now; REACHABLE = known +
    -- can fly to it; UNREACHABLE = known but unflyable from here; DISTANT =
    -- known but not on this continent; NONE = the slot is empty.
    if TaxiNodeGetType then
        local t = TaxiNodeGetType(index)
        if t == "CURRENT" or t == "REACHABLE" or t == "UNREACHABLE" or t == "DISTANT" then
            entry.known = true
        end
    end

    if side then entry.side = side end

    -- The TaxiNode API doesn't expose ids directly. We dedupe by name within
    -- a session so we don't add multiple keyless entries for the same node;
    -- the bake tool will reconcile against the wago-imported entries by
    -- matching label when ids aren't yet known.
    local existing
    for _, e in pairs(self:AllRaw()) do
        if e.label == name then existing = e; break end
    end
    if existing then
        for k, v in pairs(entry) do
            if k == "sources" then
                existing.sources = existing.sources or {}
                local seen = false
                for _, s in ipairs(existing.sources) do
                    if s == "runtime" then seen = true; break end
                end
                if not seen then table.insert(existing.sources, "runtime") end
            elseif existing[k] == nil or k == "known" or k == "x" or k == "y" or k == "mapID" then
                existing[k] = v
            end
        end
        return existing
    end

    -- New entry without an id; stored in extras for visibility via :Search.
    return self:Add(entry)
end

-- Filter: every node the player has discovered.
function FlightPoints:Known()
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.known then out[#out + 1] = e end
    end
    return out
end

-- Filter: nodes for a given faction (or both/neutral).
function FlightPoints:ForSide(side)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if not e.side or e.side == "B" or e.side == side then
            out[#out + 1] = e
        end
    end
    return out
end

LibCodex:RegisterModule("FlightPoints", FlightPoints)
