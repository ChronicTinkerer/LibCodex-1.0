# Changelog

All notable changes to LibCodex-1.0 are recorded here. Version stamps were YYMMDDHHMM build numbers through 2605031257; the convention switched to sequential integer build numbers (one increment per `release.ps1` run) on 2026-05-05. Higher integers are newer than any YYMMDDHHMM stamp.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 8 — SubAddons source layout (2026-05-06)

Internal cleanup. No user-visible changes; the published zip is byte-identical to build 7 because the packager flattens the new nested layout the same way.

### Changed

- **Source layout:** All 73 per-module LoD companion folders (`LibCodex-1.0-<Module>/`) moved from the repo root into `LibCodex-1.0/SubAddons/`. Repo root drops from 74 addon folders to 1. The packager's `move-folders` directive still flattens to siblings at install time, so users see no difference.
- `.pkgmeta` `move-folders` source paths updated to `LibCodex-1.0/SubAddons/LibCodex-1.0-<Module>`.
- `release.ps1` nested-TOC glob now `SubAddons\LibCodex-1.0-*\*.toc`; `$isNested` predicate updated to match.
- `bake.py`, `import-blizzard.py`, `rechunk-taxipaths.py` path constants now resolve sub-addons under `SubAddons/`.
- Establishes `SubAddons/` as the universal sub-addon container name for all author repos (Forge / Cairn migrations to follow).

## 7 — Per-module LoadOnDemand split (2026-05-06)

Major architectural release. Bundled seed data moves out of the core library and into 73 per-module LoadOnDemand companion addons. Idle memory cost drops from ~1.84 GB (everything always-on) to ~140 MB for a Vellum-style consumer that only queries a handful of modules. No public API changes for consumers.

### Added

- **Per-module LoadOnDemand companions.** 73 sibling addons named `LibCodex-1.0-<ModuleName>` (e.g. `LibCodex-1.0-Items`, `LibCodex-1.0-Quests`, `LibCodex-1.0-NPCs`), each shipping exactly one module's bundled rows for all 5 flavors. The first `:Get()` miss against any module triggers `C_AddOns.LoadAddOn("LibCodex-1.0-<Module>")` which then runs that module's `Data\<Module>.lua` and feeds rows into the registered collection.
- **Core library API:** `LibCodex:LoadModule(name)`, `:IsModuleLoaded(name)`, internal `:_TryLoadModule(name)`. Idempotent, soft-optional, single-attempt-per-module-per-session.
- **Multi-flavor support** for MoP Classic (Interface 50503), TBC Anniversary (20505), Classic Era / Hardcore (11508), and Experimental PTR (120007). Adds `LibCodex-1.0_Mists.toc`, `_TBC.toc`, `_Vanilla.toc`, `_XPTR.toc` to the core lib and matching per-flavor TOCs to every per-module companion.
- **Cairn-Log-1.0 bridge** in `Log.lua` (lazy resolution via `LibStub("Cairn-Log-1.0", true)`). When Cairn is installed, every `LibCodex.Log.Print` also emits to a `LibCodex` source on Cairn.Log, which Forge_Logs then displays. Soft-optional — runs unchanged when Cairn is absent.
- **`/codex info <ModuleName> <id>` two-arg form** for targeted single-module probing. Loads only that one module's LoD companion. Pairs with `/codex perf` to measure per-module memory deltas. The legacy single-arg form (`/codex info <id>`) still works and iterates every module.
- **`.pkgmeta` `move-folders` block** — 73 entries that lift each nested per-module addon to a zip-root sibling at package time. Source repo nests them under `LibCodex-1.0/` for git convenience; the published zip flattens them to the layout WoW's loader expects.
- **`import-emulator-sql.py`** — ingests cmangos-style server emulator SQL dumps for non-Retail flavors where Blizzard ships sparse DBCs (TBC Anniversary, Vanilla). Pulls 11K+ NPCs with spawn coords for TBC.
- **`import-blizzard.py`** — fetches NPC / Quest / Item data from Blizzard's official Game Data API (OAuth client_credentials flow). Per-flavor namespaces, on-disk JSON cache, polite rate limiting.
- **Auto-packaging workflow** (`.github/workflows/release.yml`) using BigWigsMods/packager v2. Tag push triggers a build that uploads to CurseForge, WoWInterface, and Wago, and creates a matching GitHub Release.
- `Maps:WorldToUiMap(continentID, worldX, worldY)` and `Maps:UiMapToWorld(uiMapID, x, y)` wrap `C_Map.GetMapPosFromWorldPos` / `GetWorldPosFromMapPos` with type-checked, nil-safe surface. Plus `Maps:UiDistance(uiMapID, ax, ay, bx, by)` for yard distance between two normalized UI points on the same map.
- `/codex perf` slash command — with no arg, prints a per-module summary of pending lazy chunks vs. materialized entries vs. row-indexed entries. With a module name (e.g. `/codex perf Spells`), forces a full expand and reports the Lua memory delta in KB.

### Changed

- **BREAKING (distribution layout, NOT API):** Bundled seed `Data/*.lua` files moved out of the core `LibCodex-1.0/` and into 73 per-module sibling addons. The published zip now installs as 74 sibling folders under `Interface/AddOns/` instead of 1. Pattern A consumers see no change — `## Dependencies: LibCodex-1.0` plus standard `LibStub("LibCodex-1.0"):Module():Get(id)` works as before, with the per-module addons loaded on demand. Pattern B (vendoring) now ships only the core registration / adapter / runtime layer; vendored installs lose bundled seed data and rely entirely on runtime capture or external `:Add` calls.
- **Versioning convention:** switched from YYMMDDHHMM build stamps to sequential integer build numbers, one increment per `release.ps1` run. This is build 7. Previous YYMMDDHHMM stamps are older than any sequential number.
- **`bake.py`** resolves output paths per-module via a new `module_data_dir(name, flavor)` helper, instead of against a single global Data folder. Backups are per-module under each addon's Data folder. The `--data-dir` override still pins all modules to one folder for one-off exports.
- **`import-blizzard.py`** uses a `path_for_module` callable in `collect_ids_from_data` for per-module Data path resolution.
- **`release.ps1`** dynamically discovers every nested per-module TOC via `Get-ChildItem 'LibCodex-1.0-*\*.toc'` and bumps all 365 of them in lockstep with the core. The validation print is condensed to a single summary line for the nested batch (would otherwise be ~1095 lines).
- **All dev-local artifacts** consolidated under `.dev/` at the repo root: `tools/`, `release.ps1`, `configs/`, every `*-cache-<flavor>/`, every `*-import-<flavor>.lua`. One folder, one `.gitignore` line, one `.pkgmeta` exclusion.

### Removed

- **`LibCodex-1.0-Detail` single-blob LoadOnDemand companion** — intermediate architecture from earlier in 2026-05-06. Loading it pulled in the entire 1.8 GB bytecode pool on the first `:Get()` miss, which defeated the purpose. Replaced by the 73 per-module split.
- **`:LoadDetail()`, `:HasDetail()`, `:_TryLoadDetail()`** on the core library — replaced by `:LoadModule(name)`, `:IsModuleLoaded(name)`, `:_TryLoadModule(name)`. State moved from boolean `_detailLoaded` / `_detailLoadAttempted` to per-module hashes `_loadedModules` / `_loadAttempts`.
- HEAVY_MODULES allow-list gate on the auto-load path — the auto-load now applies universally to every module, not a curated subset.

### Fixed

- `bake.py` chunked-readback regex didn't match the `_FeedBundledRowsLazy(_N, _C, fn)` emit form, so re-baking a chunked module (>8000 rows, like `TaxiPaths`) silently dropped rows. Now correctly round-trips both the dense and chunked emit forms.
- `TaxiPaths` chunk-size override — default 8000 rows-per-chunk overflowed Lua's 262K constant limit because TaxiPath rows carry nested `nodes[]` tables. Added `_CHUNK_SIZE_OVERRIDES` for modules with structurally heavy rows.

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
