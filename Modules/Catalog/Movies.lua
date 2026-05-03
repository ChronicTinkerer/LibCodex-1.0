-- LibCodex-1.0 / Modules / Catalog / Movies.lua
-- Movie DBC: pre-rendered cinematic movies (the .ogv-style assets for
-- expansion intros, key cutscenes, etc.). Distinct from CinematicSequences
-- which are in-engine camera scripts.
--
-- Schema:
--   id                 MovieID
--   volume             Volume (0-100)
--   keyID              KeyID
--   audioFileDataID    AudioFileDataID
--   subtitleFileDataID SubtitleFileDataID
--   subtitleFileFormat SubtitleFileFormat enum
--   sources            provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Movies = LibCodex.CollectionFactory.New("Movies", {
    keyField = "id",
    searchFields = {},
})
LibCodex:RegisterModule("Movies", Movies)
