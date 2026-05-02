-- LibCodex-1.0 / Modules / Catalog / Encounters.lua
-- Dungeon and raid encounters: each entry is either an instance (whole
-- dungeon/raid) or a single boss encounter inside one. Schema:
--   id           JournalInstance or JournalEncounter id
--   label        instance/encounter name
--   kind         "instance" | "encounter"
--   instanceID   parent instance id (only for kind=encounter)
--   expansion    expansion ID
--   difficulty   numeric difficulty mask (only for instances)
--   loot         array of itemIDs known to drop here (from JournalEncounterItem)
--   mapID        UiMapID where the encounter takes place
--   sources      provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Encounters = LibCodex.CollectionFactory.New("Encounters", {
    keyField = "id",
    searchFields = { "label" },
})
LibCodex:RegisterModule("Encounters", Encounters)

-- Convenience: every encounter inside a given instance.
function Encounters:Bosses(instanceID)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.kind == "encounter" and e.instanceID == instanceID then out[#out + 1] = e end
    end
    return out
end

-- Convenience: every instance entry (dungeons + raids), filtered by kind.
function Encounters:Instances()
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.kind == "instance" then out[#out + 1] = e end
    end
    return out
end
