-- LibCodex-1.0 / Modules / Catalog / GossipOptions.lua
-- GossipNPCOption DBC: per-NPC gossip option metadata. Each row maps a
-- specific gossip choice to the system it triggers (LFG dungeon picker,
-- trainer panel, garrison follower, profession recipe view, etc.). Lets
-- you ask "what does this gossip click actually do?" without trial-and-
-- error.
--
-- Schema:
--   id                 GossipNPCOptionID
--   gossipNpcOption    GossipNpcOption type enum
--   lfgDungeonsID      LFGDungeons (-> LFGDungeons) for LFG-picker gossips
--   trainerID          Trainer id
--   garrFollowerTypeID  garrison follower type id (legacy)
--   charShipmentID     work order id (legacy)
--   garrTalentTreeID   Garrison talent tree id (legacy)
--   uiMapID            UiMap (-> Zones) for map-opener gossips
--   uiItemInteractionID  UI item interaction id
--   covenantID         Covenant id (SL legacy)
--   gossipIndex        per-NPC gossip option index
--   traitTreeID        TraitTree (-> Talents) for talent-resetter gossips
--   professionID       Profession id (-> Professions)
--   sources            provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local GossipOptions = LibCodex.CollectionFactory.New("GossipOptions", {
    keyField = "id",
    searchFields = {},
})
LibCodex:RegisterModule("GossipOptions", GossipOptions)
