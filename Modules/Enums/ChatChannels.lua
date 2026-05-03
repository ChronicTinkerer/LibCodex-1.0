-- LibCodex-1.0 / Modules / Enums / ChatChannels.lua
-- Chat channel definitions from wago `ChatChannels` DBC. Trade, General,
-- LFG, etc., plus the per-zone defaults.
--
-- Schema:
--   id            ChatChannelID
--   label         Name_lang
--   shortcut      Shortcut_lang ("/2", "/4", etc.)
--   flags         raw ChatChannels.Flags
--   factionGroup  faction restriction (-1 = both, 1 = Alliance, 2 = Horde)
--   ruleset       Ruleset enum (which channel-system rules apply)
--   sources       provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local ChatChannels = LibCodex.CollectionFactory.New("ChatChannels", {
    keyField = "id",
    searchFields = { "label", "shortcut" },
})
LibCodex:RegisterModule("ChatChannels", ChatChannels)
