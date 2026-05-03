-- LibCodex-1.0 / Modules / Catalog / TaxiPaths.lua
-- The actual flight routes between FlightPoints. TaxiPath.dbc is one row
-- per directional edge from FromTaxiNode -> ToTaxiNode. TaxiPathNode adds
-- the intermediate waypoints the plane / wyvern / dragon flies through, so
-- a routing addon can draw the real path on the map instead of a straight
-- line between endpoints.
--
-- Schema:
--   id              TaxiPathID
--   fromNode        FromTaxiNode (cross-ref to FlightPoints)
--   toNode          ToTaxiNode (cross-ref to FlightPoints)
--   cost            taxi cost in copper
--   nodes           array of { x, y, z, continentID, nodeIndex, flags,
--                              delay, arrivalEvent, departureEvent }
--                   sorted by NodeIndex (post-processor attaches)
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local TaxiPaths = LibCodex.CollectionFactory.New("TaxiPaths", {
    keyField = "id",
    searchFields = {},  -- not text-searchable; lookup by id or endpoints
})

-- Convenience: every path with this taxi node as origin.
function TaxiPaths:FromNode(taxiNodeID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.fromNode == taxiNodeID then out[#out + 1] = e end
    end
    return out
end

-- Convenience: every path with this taxi node as destination.
function TaxiPaths:ToNode(taxiNodeID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.toNode == taxiNodeID then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("TaxiPaths", TaxiPaths)
