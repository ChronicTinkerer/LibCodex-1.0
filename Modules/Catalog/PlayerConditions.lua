-- LibCodex-1.0 / Modules / Catalog / PlayerConditions.lua
-- PlayerCondition catalog. The DBC's universal gating predicate: any other
-- table that has a `PlayerConditionID` field uses one of these rows to
-- decide whether the linked content shows / fires for the current player.
-- Common gates: minimum level, race or class restriction, faction reputation
-- threshold, completed-quest requirement, equipped-item requirement.
--
-- The full DBC has 80+ columns covering every kind of check Blizzard's
-- system can express. We surface the subset most frequently used by
-- consumer addons; the raw row is also accessible via :Get if you need
-- something we didn't pull through.
--
-- Schema:
--   id              PlayerConditionID
--   failureMessage  Failure_description_lang ("Requires level 60.")
--   minLevel        minimum character level
--   maxLevel        maximum character level (0 = no cap)
--   raceMask        bitmask of allowed races (0 = any race)
--   classMask       bitmask of allowed classes (0 = any class)
--   languageID      LanguageID required
--   minLanguage     MinLanguage skill rank
--   currentPvpFaction  CurrentPvpFaction (0=none, 1=Alliance, 2=Horde)
--   pvpMedal        required PvpMedal tier
--   maxFactionID    Reputation faction id this condition checks
--   maxReputation   reputation threshold against maxFactionID
--   reputationLogic logic operator for the reputation check
--   itemFlags       ItemFlags used by the item-check sub-predicate
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local PlayerConditions = LibCodex.CollectionFactory.New("PlayerConditions", {
    keyField = "id",
    searchFields = { "failureMessage" },
})

LibCodex:RegisterModule("PlayerConditions", PlayerConditions)
