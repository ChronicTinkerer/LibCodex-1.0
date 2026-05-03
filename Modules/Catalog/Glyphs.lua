-- LibCodex-1.0 / Modules / Catalog / Glyphs.lua
-- Legacy glyph catalog from wago `GlyphProperties` DBC. The classic glyph
-- system was retired in Legion but the DBC entries remain — useful for
-- historical content and any addon that still references glyph IDs.
--
-- Schema:
--   id                       GlyphPropertiesID
--   spellID                  the spell this glyph grants
--   glyphType                Major / Minor / Prime enum
--   glyphExclusiveCategoryID  exclusion grouping (only one glyph from a
--                            category can be slotted)
--   icon                     SpellIconFileDataID
--   sources                  provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Glyphs = LibCodex.CollectionFactory.New("Glyphs", {
    keyField = "id",
    searchFields = {},
})
LibCodex:RegisterModule("Glyphs", Glyphs)
