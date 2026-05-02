-- LibCodex-1.0 / Modules / Enums / Stats.lua
-- Player stat enum. Wago doesn't publish a Stat DBC (the values are largely
-- baked into client code), so this module is hand-curated. The seed data
-- lives in Data/Stats.lua.
--
-- Schema:
--   id        small numeric ID we assign for ordering (NOT a Blizzard ID)
--   label     localized display name placeholder ("Strength", "Critical Strike")
--   token     ITEM_MOD_* token used by GetItemStats() responses (e.g.
--             "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_CRIT_RATING_SHORT")
--   kind      "primary" | "secondary" | "tertiary"
--   sources   provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Stats = LibCodex.CollectionFactory.New("Stats", {
    keyField = "id",
    searchFields = { "label", "token", "kind" },
})

function Stats:ByKind(kind)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.kind == kind then out[#out + 1] = e end
    end
    return out
end

-- Convenience: look up a stat by its ITEM_MOD_* token.
function Stats:ByToken(token)
    if not token then return nil end
    for _, e in pairs(self:AllRaw()) do
        if e.token == token then return e end
    end
    return nil
end

LibCodex:RegisterModule("Stats", Stats)
