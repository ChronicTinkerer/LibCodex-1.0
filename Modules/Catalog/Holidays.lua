-- LibCodex-1.0 / Modules / Catalog / Holidays.lua
-- Calendar event catalog. Brewfest, Hallow's End, Lunar Festival, the
-- Darkmoon Faire, etc. Each entry combines the Holidays DBC (timing /
-- region) with the HolidayNames DBC (the human-readable label).
--
-- Schema:
--   id              HolidayID
--   label           display name (joined from HolidayNames)
--   region          0=ALL, 1=US, 2=KR, 3=EU, 4=TW, 5=CN
--   looping         1 = recurs annually, 0 = one-shot
--   priority        UI display priority
--   filterType      CalendarFilterType (which calendar bucket this belongs to)
--   flags           raw Holidays.Flags
--   nameID          HolidayNames row id (for cross-reference)
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Holidays = LibCodex.CollectionFactory.New("Holidays", {
    keyField = "id",
    searchFields = { "label" },
})

function Holidays:Looping()
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.looping == 1 then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Holidays", Holidays)
