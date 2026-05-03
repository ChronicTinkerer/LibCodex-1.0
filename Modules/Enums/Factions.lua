-- LibCodex-1.0 / Modules / Enums / Factions.lua
-- Unified faction catalog. Covers TWO kinds of "faction":
--   * Player factions: Alliance ("A"), Horde ("H"), Neutral ("N").
--     Hand-curated, string ids.
--   * Reputation factions: every Faction DBC row (Argent Dawn, Cenarion
--     Circle, Brawler's Guild, etc.). Imported from wago, numeric ids.
--
-- Schema:
--   id              "A" | "H" | "N" (player) OR numeric FactionID (reputation)
--   label           display name
--   kind            "player" | "reputation"
--   color           { r, g, b, hex } — for player factions only
--   expansion       Expansion enum — for reputation factions only
--   parentFactionID  ParentFactionID — for reputation factions only
--   sources         provenance tags
--
-- Mixed-type ids (string + number) coexist in the same module without
-- collision because Lua tables key by both type and value. Consumers that
-- only want one kind should use :ByKind.

local LibCodex = LibStub("LibCodex-1.0")
local Factions = LibCodex.CollectionFactory.New("Factions", {
    keyField = "id",
    searchFields = { "label" },
})

LibCodex:RegisterModule("Factions", Factions)

-- Convenience: GetForPlayer() returns the Alliance/Horde/Neutral entry
-- matching the current player's faction group. Returns the Neutral entry
-- as a fallback (e.g., a Pandaren who hasn't picked a side yet).
function Factions:GetForPlayer()
    if UnitFactionGroup then
        local f = UnitFactionGroup("player")
        if f == "Alliance" then return self:Get("A") end
        if f == "Horde"    then return self:Get("H") end
    end
    return self:Get("N")
end

-- Filter by kind: "player" returns A/H/N, "reputation" returns the rep
-- factions imported from wago.
function Factions:ByKind(kind)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.kind == kind then out[#out + 1] = e end
    end
    return out
end

-- Convenience aliases for the common queries.
function Factions:Players()      return self:ByKind("player") end
function Factions:Reputations()  return self:ByKind("reputation") end
