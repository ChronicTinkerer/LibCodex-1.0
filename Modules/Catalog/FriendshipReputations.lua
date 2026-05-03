-- LibCodex-1.0 / Modules / Catalog / FriendshipReputations.lua
-- Friendship reputation overlays from wago `FriendshipReputation` DBC.
-- These are reputation factions that present custom rank names + thresholds
-- instead of the standard Hated..Exalted scale (Nomi, Steamwheedle, etc.).
-- Each entry binds to a regular FactionID with its own description and
-- per-tier reaction labels (attached as tiers[] by post-processor).
--
-- Schema:
--   id              FriendshipReputationID
--   factionID       which Faction (-> Factions module) this overlay decorates
--   description     Description_lang
--   standingModified  StandingModified_lang
--   standingChangedText  StandingChangedText_lang
--   icon            TextureFileID
--   flags           raw FriendshipReputation.Flags
--   tiers           array of { reaction, threshold, color } from
--                   FriendshipRepReaction (post-processor attaches; sorted by threshold)
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local FriendshipReputations = LibCodex.CollectionFactory.New("FriendshipReputations", {
    keyField = "id",
    searchFields = { "description" },
})

function FriendshipReputations:ForFaction(factionID)
    for _, e in pairs(self:AllRaw()) do
        if e.factionID == factionID then return e end
    end
    return nil
end

LibCodex:RegisterModule("FriendshipReputations", FriendshipReputations)
