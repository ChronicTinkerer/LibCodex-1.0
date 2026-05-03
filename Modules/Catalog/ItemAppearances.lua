-- LibCodex-1.0 / Modules / Catalog / ItemAppearances.lua
-- Visual-appearance catalog for transmog. Each entry is one distinct
-- visual a piece of armor / weapon can take. Multiple items can share an
-- appearance (e.g., the same model in different recolors). The bridge from
-- a specific item to its appearances lives in ItemModifiedAppearances.
--
-- Schema:
--   id              ItemAppearanceID
--   displayType     visual category enum (helm / cloak / shoulder / etc.)
--   displayInfoID   ItemDisplayInfoID — the actual model
--   icon            DefaultIconFileDataID
--   uiOrder         UI sort order
--   transmogPlayerCondition  PlayerConditionID gate for transmog use
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local ItemAppearances = LibCodex.CollectionFactory.New("ItemAppearances", {
    keyField = "id",
    searchFields = {},  -- no text label; lookup by id
})

LibCodex:RegisterModule("ItemAppearances", ItemAppearances)
