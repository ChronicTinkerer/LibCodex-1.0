# Changelog

All notable changes to LibCodex-1.0 are recorded here. The version stamp follows the YYMMDDHHMM build-number convention; later timestamps are newer.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

_Nothing pending._

## 2605031257 — Polish pass (2026-05-03)

### Added

- `/codex perf` slash command. With no arg, prints a per-module summary of
  pending lazy chunks vs. materialized entries — quick sanity check that
  nothing has been needlessly expanded. With a module name (e.g.
  `/codex perf Spells`), forces a full expand and reports the Lua memory
  delta in KB so the cost of each catalog is measurable in-game.
- `Maps:WorldToUiMap(continentID, worldX, worldY)` and
  `Maps:UiMapToWorld(uiMapID, x, y)` — wrap `C_Map.GetMapPosFromWorldPos` /
  `GetWorldPosFromMapPos` with type-checked, nil-safe surface. Also
  `Maps:UiDistance(uiMapID, ax, ay, bx, by)` for yard distance between two
  normalized UI points on the same map.

## 2605031240 — Initial public release (2026-05-03)

First release. The library went through dozens of internal iterations across the day; this entry summarizes the surface area as shipped.

### Added — Core

- LibStub-registered library at `LibCodex-1.0`. YYMMDDHHMM build-stamp versioning.
- Hybrid load model: bundled DBC seed + runtime growth via event capture + pluggable adapter system for reading from other addons.
- Reusable collection factory (`Modules/Common.lua`) with the standard `:Get / :Search / :Add / :All / :AllArray / :AllRaw / :Count / :ExpandAll` surface.
- Two-layer lazy materialization: chunk-level deferred via thunks (modules never queried pay zero per-row table memory), row-level deferred via positional indexes (rows expanded into entry dicts on first `:Get`).
- Multi-token `:Search` (whitespace-separated tokens, ALL must match).
- SavedVariables persistence: `LibCodexDB.modules[name][id] = entry` shape, hydrated at PLAYER_LOGIN, snapshotted at PLAYER_LOGOUT.

### Added — Catalog modules (74 total)

- **World**: NPCs, Items, GameObjects, Spells, Vignettes, AreaTriggers, AreaPOI, Zones, Areas, FlightPoints, Maps, MapDifficulties, WMOAreaTables, TaxiPaths
- **Quests**: Quests (with objectives, rewards, quest-line membership, POI map markers, chromie tags), QuestPOI
- **Combat**: Spells, Talents, PvpTalents, SpellChargeCategories, SpellMechanics, SpellCooldowns, SpellCastTimes, SpellPower, SpellRanges, SpellDurations, Glyphs, Specs, Classes, Races, CreatureTypes, Stats
- **Achievements**: Achievements (with criteria), AchievementCategories, Encounters, DungeonEncounters, EncounterCreatures, EncounterSections
- **Collections**: Pets (with abilities), BattlePetAbilities, Mounts, Toys, Heirlooms, TransmogSets, ItemAppearances, ItemModifiedAppearances, TransmogIllusions, ItemBonuses, ItemEffects, ItemSets
- **Group content**: LFGDungeons, Battlemasters, Scenarios, GroupFinder, Difficulty
- **Professions**: Professions, Crafts, TradeSkillCategories, Enchants, SkillRaceClass
- **Social/meta**: Factions (player + reputation), FriendshipReputations, Currencies, Realms, Holidays, CustomizationOptions, CustomizationChoices, PlayerConditions, GossipOptions, Movies, Cinematics, Regions, Languages, ChatChannels

### Added — Runtime adapter

- Hooks `NAME_PLATE_UNIT_ADDED`, `UPDATE_MOUSEOVER_UNIT`, `PLAYER_TARGET_CHANGED` for NPC capture
- `BAG_UPDATE_DELAYED` + `GET_ITEM_INFO_RECEIVED` for item capture
- `LOOT_OPENED` / `LOOT_READY` / `CHAT_MSG_LOOT` + `COMBAT_LOG_EVENT_UNFILTERED` for drop attribution (NPC kill ↔ items)
- `QUEST_ACCEPTED` / `QUEST_TURNED_IN` / `QUEST_REMOVED` / `QUEST_LOG_UPDATE` for quest data
- `TAXIMAP_OPENED` for flight-point discovery
- `ENCOUNTER_START` / `ENCOUNTER_END` for dungeon-encounter tracking
- `AUTO_COMPLETE_ACCOUNT_LIST_UPDATED` for connected-realm capture
- Tooltip hook for game-object capture (mailboxes, herbs, ore, chests)
- Chromie-time tagging on every NPC / GameObject / Quest capture

### Added — Build tools

- `tools/import-wago.py`: pulls 100+ DBC tables from wago.tools, maps them into Codex schema, outputs SavedVariables-shaped Lua. Caches CSVs per branch for resumability.
- `tools/crawl-wowhead.py`: targeted Wowhead crawler for NPCs, Items, Quests, GameObjects. Captures spawn coords, drop tables, quest rewards, quest-giver locations. Polite-citizen defaults (1.5s rate, browser UA, 403 recovery, per-id disk cache, hard cap).
- `tools/bake.py`: merges SavedVariables + import outputs into bundled `Data/*.lua` files. Preserves `_handcrafted` entries. Per-bake backups. Auto-chunks emit so Lua 5.1's 262K-constant limit doesn't blow up on Spells (~400K rows). Lazy-thunk emit (modules never queried pay zero per-row table memory).
- `tools/diff-bake.py`: compare two `Data/` directories module-by-module. Reports entry-count delta, added / removed ids, new / dropped columns.
- `tools/list-tables.py`: enumerate which wago tables are imported vs. what's left to add.

### Added — GUI + slash commands

- `/codex` slash command suite: stats, info, search, sources, where, scan, auto, verbose, log, gui, save, debug
- `/codex gui` Dashboard: Stats / Search / Browse / Where / Settings / Actions / Log tabs
- Browse tab supports module picker, multi-token filter, `id:N` direct lookup, scrollable list with click-to-detail, keyboard navigation (up/down/enter), row highlighting, Copy ID popup
- Last-active tab persists across reloads; dashboard open state persists too
- Search → Browse handoff button
- LibEditMode integration: dashboard registers as a movable Edit Mode system when the library is present (soft-optional)

### Added — Documentation

- `README.md`: module catalog table, architecture, data file format, distribution patterns (standalone vs embedded), build tool docs, "Adding a new module" walkthrough
- `docs/API.md`: method-level reference for every public surface
- `LICENSE`: MIT
