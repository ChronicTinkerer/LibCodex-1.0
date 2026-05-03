-- LibCodex-1.0 / Modules / Enums / Regions.lua
-- Region enum from wago `Cfg_Regions` DBC. The handful of WoW publishing
-- regions: US, EU, KR, TW, CN.
--
-- Schema:
--   id            Cfg_Regions row id
--   tag           short tag ("us", "eu", "kr", ...)
--   regionID      Region_ID enum
--   raidOrigin    Raidorigin
--   regionGroup   Region_group_mask
--   challengeOrigin Challenge_origin
--   timeEventGroupID Cfg_TimeEventRegionGroupID
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Regions = LibCodex.CollectionFactory.New("Regions", {
    keyField = "id",
    searchFields = { "tag" },
})
LibCodex:RegisterModule("Regions", Regions)
