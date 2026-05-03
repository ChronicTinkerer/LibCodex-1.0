-- LibCodex-1.0 / Modules / Catalog / Cinematics.lua
-- CinematicSequences DBC: in-engine camera scripts (cutscenes the engine
-- composes live, not pre-rendered movies). Each sequence references up to
-- 8 CinematicCamera ids.
--
-- Schema:
--   id        CinematicSequenceID
--   soundID   SoundID played alongside the scene
--   cameras   array of up to 8 CinematicCamera ids (Camera_0 .. Camera_7)
--   sources   provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Cinematics = LibCodex.CollectionFactory.New("Cinematics", {
    keyField = "id",
    searchFields = {},
})
LibCodex:RegisterModule("Cinematics", Cinematics)
