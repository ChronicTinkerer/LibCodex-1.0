# LibCodex-1.0

A reusable static-catalog library for World of Warcraft addons. **45 catalog and enum modules** covering every major DBC family the game ships:

- **World**: NPCs, items, game objects, vignettes (rare spawns / treasures), area triggers, zones, sub-zones (areas), flight points
- **Quests**: catalog with objectives, rewards (items / currency), quest lines, POI map markers, and quest-giver coordinates
- **Combat**: spells, talents, PvP talents, specs, classes, races, creature types, stats
- **Achievements**: catalog with per-step criteria attached
- **Collections**: pets (with abilities), pet-battle abilities, mounts, toys, heirlooms, transmog sets, transmog illusions
- **Group content**: encounters (instances + bosses), LFG dungeons, battlemasters (BG / arena), scenarios (with steps), Premade Group Finder activities, difficulty enum
- **Professions**: profession skill lines, recipes (crafts), trade-skill sub-categories, enchants, item sets (with tier bonuses)
- **Social / meta**: factions (player + reputation), currencies, realms, holidays, character-creation customization options + choices, player-condition predicates

Hybrid load model: bundled seed (DBC-derived data shipped with the library) + runtime growth (events captured during play) + a pluggable adapter system for reading from other addons.

Consumer addons embed it the same way they embed any LibStub library.

```lua
local LC = LibStub("LibCodex-1.0")
local entry = LC:NPCs():Get(207516)
print(entry.label, entry.creatureType, entry.classification)
```

---

## Table of contents

- [Quick start for consumers](#quick-start-for-consumers)
- [Architecture](#architecture)
- [Module catalog](#module-catalog)
- [Data file format](#data-file-format)
- [Adapters](#adapters)
- [SavedVariables](#savedvariables)
- [Slash commands and GUI](#slash-commands-and-gui)
- [Build tools](#build-tools)
- [Adding a new module](#adding-a-new-module)
- [Embedding in a consumer addon](#embedding-in-a-consumer-addon)
- [Repo layout](#repo-layout)

---

## Quick start for consumers

Embed LibCodex into your addon's `embeds.xml`:

```xml
<Include file="Libs\LibCodex-1.0\LibCodex-1.0.xml"/>
```

Then in any of your Lua files:

```lua
local LC = LibStub("LibCodex-1.0")

-- Direct lookup by id.
local sword = LC:Items():Get(12345)
print(sword.label, sword.quality, sword.level)

-- Substring search across the module's configured search fields.
for _, hit in ipairs(LC:Items():Search("rune", { quality = 4 })) do
    print(hit.id, hit.label)
end

-- Iterate every entry in a module.
for id, entry in LC:NPCs():All() do
    if entry.classification == "Boss" then
        print(id, entry.label)
    end
end
```

Every module exposes the same five-method surface: `:Get(id)`, `:Search(query, opts)`, `:Add(entry)`, `:All()`, `:Count()`. Module-specific helpers (e.g., `LC:Items():ByQuality(4)`) sit on top.

---

## Architecture

Three layers, loaded in this order at addon startup:

```
1. Module factory            (Modules/Common.lua)
   |
   v
2. Module registrations      (Modules/Catalog/*.lua, Modules/Enums/*.lua)
   |
   v
3. Bundled seed data         (Data/*.lua  -> _FeedBundledRows)
   |
   v
4. PLAYER_LOGIN
   - SavedVariables hydrate  (LibCodexDB.modules -> :Add)
   - Adapters run            (Adapters/*.lua)
```

**Layer 1: factory.** `Modules/Common.lua` exports `LibCodex.CollectionFactory.New(name, opts)` which builds an id-keyed collection with the standard `:Get / :Search / :Add / :All / :Count` shape.

**Layer 2: modules.** Each `Modules/Catalog/*.lua` and `Modules/Enums/*.lua` calls the factory, attaches module-specific helpers, and registers itself with `LibCodex:RegisterModule(name, collection)`.

**Layer 3: bundled seed.** Each `Data/*.lua` file calls `LibCodex:_FeedBundledRows(name, columnsCSV, rowsTable)`. Rows are stored lazily; entries are materialized into dicts only when something calls `:Get(id)`. This keeps memory low even for the 400K-row Spells catalog.

**Layer 4: runtime.** At PLAYER_LOGIN, the library hydrates `LibCodexDB` (everything captured in previous sessions) and runs every registered adapter. The runtime adapter (`Adapters/Runtime.lua`) hooks events like `NAME_PLATE_UNIT_ADDED`, `LOOT_OPENED`, `QUEST_ACCEPTED`, `TAXIMAP_OPENED` to keep the catalog growing as the player moves through the world.

Catalog modules grow from any of three sources tagged in `entry.sources`:
- `bundled` — shipped in `Data/*.lua`
- `runtime` — captured via API events
- `wago` / `wowhead` — written into SavedVariables by an importer or external addon, then merged on next load

---

## Module catalog

Every module is keyed by `id`. Common fields across modules: `label` (display name), `sources` (array of provenance tags). Module-specific fields are listed below.

### Catalog tier (large, grow over time)

| Module        | Source                          | Key fields beyond label                                       |
| ------------- | ------------------------------- | ------------------------------------------------------------- |
| `NPCs`         | wago `Creature` + runtime       | `creatureType`, `classification`, `side`, `level`, `locations[]`, `drops[]` |
| `Items`        | wago `ItemSparse` + runtime     | `quality`, `level`, `classID`, `subclassID`, `expansion`, `dropsFrom[]`, `soldBy[]` |
| `GameObjects`  | runtime tooltip + Wowhead       | `locations[]`, `drops[]`                                      |
| `Spells`       | wago `SpellName`                | `icon`                                                        |
| `Quests`       | wago `QuestV2` + Wowhead + runtime | `objectives[]`, `giverNPC`, `turnInNPC`, `itemRewards[]`, `currencyRewards[]`, `locations[]`, `questLine`, `level`, `side` |
| `Talents`      | wago `TraitDefinition`          | `description`, `icon`, `spellID`, `treeID`, `treeName`, `subTreeID`, `subTreeName`, `maxRanks` |
| `FlightPoints` | wago `TaxiNodes` + runtime      | `continentID`, `worldX/Y/Z`, `mapID`, `x/y`, `side`, `bitNumber`, `mountCreatureA/H`, `known` |
| `Crafts`       | wago `SkillLineAbility`         | `spellID`, `skillLineID`, `minRank`, `trivialHigh`, `trivialLow`, `classMask`, `raceMask` |
| `Professions`  | wago `SkillLine` + `Profession` | `categoryID`, `icon`, `parentID`, `professionEnum`, `actionType` |
| `Pets`         | wago `BattlePetSpecies`         | `creatureID`, `family`, `sourceType`, `description`, `icon`   |
| `Mounts`       | wago `Mount`                    | `spellID`, `sourceType`, `factionID`                          |
| `Toys`         | wago `Toy`                      | `itemID`, `sourceType`                                        |
| `Heirlooms`    | wago `Heirloom`                 | `itemID`, `classMask`                                         |
| `Achievements` | wago `Achievement` + `Criteria` + `CriteriaTree` | `description`, `points`, `categoryID`, `side`, `criteria[]` (each: `description`, `type`, `asset`, `amount`, `order`) |
| `Encounters`   | wago `JournalInstance` + `JournalEncounter` | `kind` ("instance" or "encounter"), `instanceID`, `expansion`, `mapID`, `loot[]` |
| `Zones`        | wago `UiMap`                    | `type`, `parentID`                                            |
| `Areas`        | wago `AreaTable`                | `zoneName`, `continentID`, `parentAreaID`, `factionGroupMask` (sub-zones inside UiMaps; `:Path(areaID)` walks parent chain) |
| `Currencies`   | wago `CurrencyTypes`            | `expansion`                                                   |
| `Vignettes`    | wago `Vignette`                 | `vignetteType`, `rewardQuestID`, `playerCondition`, `objectiveType`, `flags` (rare spawns, treasures, world bosses) |
| `Holidays`     | wago `Holidays` + `HolidayNames` | `region`, `looping`, `priority`, `filterType`, `nameID`     |
| `QuestPOI`     | wago `QuestPOIBlob` + `QuestPOIPoint` | `questID`, `uiMapID`, `mapID`, `objectiveIndex`, `objectiveID`, `numPoints`, `points[]` (each: `x`, `y`, `z` normalized) |
| `PvpTalents`   | wago `PvpTalent`                | `spellID`, `description`, `specID`, `categoryID`, `levelRequired`, `actionBarSpellID`, `overridesSpellID` |
| `Enchants`     | wago `SpellItemEnchantment`     | `icon`, `duration`, `itemLevelMin`, `itemLevelMax`, `hordeLabel`, `flags` |
| `ItemSets`     | wago `ItemSet` + `ItemSetSpell` | `requiredSkill`, `items[]` (ItemIDs), `bonuses[]` (each: `threshold`, `spellID`, `specID`, `traitSubTreeID`) |
| `TradeSkillCategories` | wago `TradeSkillCategory` | `parentID`, `skillLineID`, `orderIndex`, `hordeLabel` (profession sub-buckets) |
| `TransmogSets` | wago `TransmogSet` + `TransmogSetItem` | `classMask`, `expansion`, `parentID`, `groupID`, `appearances[]` (ItemModifiedAppearanceIDs) |
| `LFGDungeons`  | wago `LFGDungeons`              | `description`, `typeID`, `subtype`, `side`, `expansion`, `mapID`, `difficultyID`, `minGear`, `groupID`, `randomID`, `scenarioID`, `finalEncounterID` |
| `Battlemasters`| wago `BattlemasterList`         | `gameType`, `shortDesc`, `longDesc`, `instanceType`, `pvpType`, `minLevel`, `maxLevel`, `minPlayers`, `maxPlayers`, `maxGroupSize` |
| `Scenarios`    | wago `Scenario` + `ScenarioStep` | `areaTableID`, `type`, `steps[]` (each: `id`, `title`, `description`, `orderIndex`, `criteriaTreeID`, `rewardQuestID`) |
| `GroupFinder`  | wago `GroupFinderActivity` + `GroupFinderCategory` + `GroupFinderActivityGrp` | `shortName`, `categoryID`, `categoryName`, `groupID`, `groupName`, `mapID`, `difficultyID`, `expansion`, `maxPlayers`, `minGearLevel` |
| `BattlePetAbilities` | wago `BattlePetAbility` + `BattlePetSpeciesXAbility` | `description`, `icon`, `petType`, `cooldown`, `species[]` (each: `speciesID`, `requiredLevel`, `slot`). Also enriches `Pets[species].abilities[]`. |
| `CustomizationOptions` | wago `ChrCustomizationOption`  | `chrModelID`, `categoryID`, `optionType`, `barberCost`, `requirement`, `orderIndex`, `addedInPatch` |
| `CustomizationChoices` | wago `ChrCustomizationChoice`  | `optionID`, `swatchColor0`, `swatchColor1`, `orderIndex`, `addedInPatch`, `soundKitID` |
| `TransmogIllusions` | wago `TransmogIllusion`        | `enchantID` (-> Enchants for label/icon), `unlockCondition`, `transmogCost` |
| `AreaTriggers` | wago `AreaTrigger`              | `continentID`, `x`, `y`, `z`, `shapeType`, `radius` (or `boxLength`/`boxWidth`/`boxHeight`/`boxYaw`), `actionSetID`, `phaseID` (no name; identify by id + position) |
| `PlayerConditions` | wago `PlayerCondition`      | `failureMessage`, `minLevel`, `maxLevel`, `raceMask`, `classMask`, `currentPvpFaction`, plus 14 logic / threshold fields. Universal gating predicate referenced by `PlayerConditionID` everywhere. |

### Enum tier (small, stable, hand-curated or DBC-sourced)

| Module          | Source                | Key fields beyond label              |
| --------------- | --------------------- | ------------------------------------ |
| `Classes`        | wago `ChrClasses`     | `token` (e.g. "WARRIOR")             |
| `Races`          | wago `ChrRaces`       | `token`, `side`, `playable`, `allied` |
| `Realms`         | wago `Realm` (404 today; runtime via `GetAutoCompleteRealms`) | `region`, `locale`, `type`, `online`, `connectedTo[]` |
| `Factions`       | hand-curated (player) + wago `Faction` (reputation) | `kind` ("player" or "reputation"), `color` (player only), `expansion` + `parentFactionID` (reputation only). Mixed string + numeric ids; `:Players()` / `:Reputations()` filter by kind. |
| `CreatureTypes`  | wago `CreatureType`   |                                      |
| `Specs`          | wago `ChrSpecialization` | `classID`, `role`                |
| `Stats`          | hand-curated          | `token` (ITEM_MOD_*), `kind`         |
| `Difficulty`     | wago `Difficulty`     | `instanceType`, `orderIndex`, `minPlayers`, `maxPlayers`, `fallbackDifficultyID` |

The accessor methods on the library mirror the module names: `LC:NPCs()`, `LC:Items()`, `LC:Quests()`, etc.

---

## Data file format

Each `Data/<Module>.lua` calls `LibCodex:_FeedBundledRows(moduleName, columnsCSV, rowsTable)`.

Tiny example:

```lua
local LibCodex = LibStub("LibCodex-1.0")

LibCodex:_FeedBundledRows("Stats",
    "id,label,token,kind,sources",
    {
        {1, "Strength",  "ITEM_MOD_STRENGTH_SHORT", "primary", {"handcrafted"}},
        {2, "Agility",   "ITEM_MOD_AGILITY_SHORT",  "primary", {"handcrafted"}},
        {3, "Intellect", "ITEM_MOD_INTELLECT_SHORT","primary", {"handcrafted"}},
    }
)
```

Format rules:
- Columns CSV starts with `id`. Other field names follow in any order.
- Each row is a Lua array of positional values matching the columns CSV.
- Trailing nils may be omitted (`{1, "Strength"}` is equivalent to `{1, "Strength", nil, nil, nil}`).
- Mid-row nils must be written explicitly as the literal `nil`.
- Nested tables are allowed: `locations`, `objectives`, `dropsFrom`, etc.
- A `sources` value of exactly `{"bundled"}` may be omitted; the loader supplies that default.
- Entries marked `_handcrafted=true` are preserved verbatim by the bake tool across re-runs.

### Lazy expansion

The factory in `Modules/Common.lua` does not materialize rows into entry dicts at load time. Instead it indexes each row by id (`_rowIndex[id] = {blobIdx, rowNum}`) and expands on first `:Get(id)` call. `:ExpandAll()` materializes everything if you need full iteration.

This is what lets the library ship ~400K spells and ~170K items without melting the WoW client at login.

### Chunking for large modules

Lua 5.1 caps each function's constant pool at 262143 entries (MAXARG_Bx). Modules over 8000 rows would blow that limit if emitted as one big call. The bake tool wraps each chunk in an IIFE so each batch gets its own constant pool:

```lua
local LibCodex = LibStub("LibCodex-1.0")
local _N, _C = "Spells", "id,label,icon"

-- Chunk 1/51: rows 1..8000
LibCodex:_FeedBundledRows(_N, _C, (function() return {
    {1, "Spell 1", "icon1"},
    -- ... up to 8000 rows ...
} end)())

-- Chunk 2/51: rows 8001..16000
LibCodex:_FeedBundledRows(_N, _C, (function() return {
    -- ...
} end)())
```

Chunking is automatic in `bake.py` whenever a module exceeds 8000 rows.

---

## Adapters

Adapters run at PLAYER_LOGIN (`LibCodex:RunAdapters()`) and may also register their own event hooks for continuous capture.

### Runtime adapter (`Adapters/Runtime.lua`)

Hooks the following events:

| Event                             | What gets captured                                            |
| --------------------------------- | ------------------------------------------------------------- |
| `NAME_PLATE_UNIT_ADDED`            | NPC id from GUID, label, level, classification, side, location |
| `UPDATE_MOUSEOVER_UNIT`            | same as nameplate                                             |
| `PLAYER_TARGET_CHANGED`            | same as nameplate                                             |
| `BAG_UPDATE_DELAYED`               | every itemID currently in the player's bags                   |
| `GET_ITEM_INFO_RECEIVED`           | drains the Items async-load queue                             |
| `LOOT_OPENED` / `LOOT_READY`       | drop attribution: which items came from the most recent kill or container |
| `CHAT_MSG_LOOT`                    | secondary drop attribution from chat text                     |
| `COMBAT_LOG_EVENT_UNFILTERED`      | tracks `PARTY_KILL` / `UNIT_DIED` so the next loot event knows the source |
| `AUTO_COMPLETE_ACCOUNT_LIST_UPDATED` | connected-realm list                                        |
| `QUEST_ACCEPTED`                   | quest title, level, accept location, faction context          |
| `QUEST_TURNED_IN`                  | turn-in timestamp                                             |
| `QUEST_LOG_UPDATE`                 | throttled re-scan of the active quest log                     |
| `TAXIMAP_OPENED`                   | every visible flight node + player's known/unknown state      |

Plus a tooltip hook for `GameObjects` (mailboxes, herbs, ore, chests).

Auto-scan tick (default ON, configurable) periodically re-walks visible nameplates so wandering NPCs get captured even when the player isn't actively targeting them.

### Writing your own adapter

Inside any consumer addon:

```lua
local LC = LibStub("LibCodex-1.0")
LC:RegisterAdapter("MyAddon-Quests", function(LC)
    -- Called once at PLAYER_LOGIN. Read whatever data your adapter knows
    -- about and feed it in via the module APIs:
    for id, e in pairs(MyAddonDB.knownNPCs or {}) do
        LC:NPCs():Add({
            id = id,
            label = e.name,
            sources = { "myaddon" },
        })
    end
end)
```

Adapters run in registration order. `:Add` is idempotent and merges into existing entries non-destructively (handcrafted fields survive; `sources` is unioned).

---

## SavedVariables

The library persists state to `LibCodexDB`, declared in the .toc as `## SavedVariables: LibCodexDB`.

Shape:

```lua
LibCodexDB = {
    version = 1,
    modules = {
        NPCs  = { [12345] = { id=12345, label="Boss", ... }, ... },
        Items = { [67890] = { id=67890, label="Sword", ... }, ... },
        -- one key per registered module
    },
    -- A handful of preference flags also live here:
    autoScan = true,
    autoScanInterval = 5,
    logEcho = false,
    dashboardOpen = true,
}
```

`_RestoreSavedVariables()` runs at PLAYER_LOGIN and feeds every saved entry back through `:Add()`, where the merge logic reconciles it with bundled data. `_PersistSavedVariables()` runs at PLAYER_LOGOUT and writes every module's current `_entries` table back to disk.

---

## Slash commands and GUI

`/codex` opens the slash command suite. Subcommands:

```
/codex stats              per-module entry counts with source breakdown
/codex info <id>          show every field of an entry (asks NPCs, Items first)
/codex search <query>     substring search across every module
/codex sources <id>       list provenance tags for an entry
/codex where <itemID>     show recorded drop sources for an item
/codex scan               force a nameplate / bag re-scan
/codex auto on|off [s]    toggle continuous auto-scan, optional interval seconds
/codex verbose on|off     toggle per-capture log lines
/codex log                open the dedicated log window
/codex save               force-write to SavedVariables (no reload required)
/codex debug              dump internal state for diagnosis
/codex gui                open the dashboard window
```

`/codex gui` opens a tabbed dashboard:

- **Stats** — per-module counts and source breakdown
- **Search** — same `:Search()` as the slash command, results in a scrollable pane
- **Browse** — pick a module, optionally filter, click a row to inspect every field
- **Where** — itemID -> drop sources with map locations
- **Settings** — auto-scan toggle, friendly nameplates toggle, log echo
- **Actions** — reload UI, force save, run adapters, etc.
- **Log** — embedded view of the dedicated log window

Dashboard open state is persisted across reloads (`LibCodexDB.dashboardOpen`).

---

## Build tools

All Python tools are in `tools/`. They use only the standard library (no pip installs needed). Tested on Python 3.10+.

### `tools/import-wago.py`

Pulls DBC table CSV exports from [wago.tools](https://wago.tools), maps each row into Codex schema, writes a SavedVariables-shaped Lua file ready for the bake tool to merge.

```
py tools\import-wago.py
```

Defaults to fetching every table listed in `TABLE_CONFIG` (currently 22 tables across 19 modules) and writing `wago-import.lua` in the current directory. Cache is persisted to `.wago-cache/` so re-runs only re-fetch new tables.

Useful flags:

```
--tables Creature,ItemSparse    only fetch named tables
--branch wow                     wago branch (wow=retail, wowt=PTR, wow_classic, ...)
--cache-dir .wago-cache          where to cache downloaded CSVs
--output wago-import.lua         output file path
```

After import, run the bake tool against `bake-config-wago.lua` (which points `wtf_path` at `wago-import.lua`).

### `tools/crawl-wowhead.py`

Targeted Wowhead crawler. For each NPC/Item/Quest id you supply, fetches the Wowhead page and extracts what wago can't give us:

- NPCs: spawn locations (mapID + normalized x/y per spawn)
- Items: drop sources (which NPC dropped it, with drop chance), vendor sources
- Quests: title, level, side, item rewards, currency rewards, quest-giver and turn-in NPCs, quest-giver map coordinates

Polite citizen by default: 1.5s between requests with jitter, recovery pause on 403, per-id disk cache, hard cap on total requests per run.

```
py tools\crawl-wowhead.py --modules Quests --from-data Data --max-ids 65000
```

Flag summary:

```
--from <savedvars.lua>           read ids from a SavedVariables file
--from-data <Data dir>           read ids from Data/*.lua (uses what's already baked)
--ids "12345,67890,100-200"      explicit id list / ranges
--modules NPCs,Items,Quests      which modules to crawl
--max-ids 1000                   hard cap per run
--rate 1.5                       seconds between requests (default 1.5)
--quality-min 4                  Items only: skip below this quality
--cache-dir .wowhead-cache       on-disk cache
--dry-run                        plan without fetching
--quiet                          only print errors and the final summary
```

The crawler is fully resumable. Cached pages are detected and skipped without a network round-trip, so re-running the same command after a cancelled run picks up where it left off.

### `tools/bake.py`

Reads SavedVariables (or the output of an importer or crawler) and merges learned entries into `Data/*.lua`. Hand-curated entries marked `_handcrafted=true` survive every bake.

```
py tools\bake.py --config tools\bake-config-wago.lua
```

The config file is tiny:

```lua
return {
    wtf_path = "C:/path/to/SavedVariables/LibCodex-1.0.lua",
    data_dir = "../Data",
    backup = true,
}
```

Backups land in `Data/.bake-backup/<timestamp>/` before any file is overwritten. Useful flags:

```
--dry-run             show what would change without writing
--only Items,NPCs     only process named modules
--skip Realms         skip named modules
```

The bake's location-dedup logic collapses near-duplicate `locations` entries within a small radius (`NPCs` ~50 yards, `GameObjects` ~15 yards) so repeated visits don't bloat coordinates.

---

## Adding a new module

Walkthrough using a hypothetical `Pots` module (potions catalog):

**1. Create the module file** at `Modules/Catalog/Pots.lua`:

```lua
local LibCodex = LibStub("LibCodex-1.0")
local Pots = LibCodex.CollectionFactory.New("Pots", {
    keyField = "id",
    searchFields = { "label", "tier" },
})

function Pots:ByTier(tier)
    local out = {}
    for _, e in pairs(self:AllRaw()) do
        if e.tier == tier then out[#out + 1] = e end
    end
    return out
end

LibCodex:RegisterModule("Pots", Pots)
```

**2. Add an accessor** in `LibCodex-1.0.lua` (the file scrolls through these near the bottom):

```lua
function LibCodex:Pots() return self.modules.Pots end
```

**3. Wire the load order** in both `LibCodex-1.0.toc` (for standalone testing) and `LibCodex-1.0.xml` (for embed):

```
Modules\Catalog\Pots.lua
Data\Pots.lua
```

**4. Add the module to `EXPECTED_MODULES`** in `tools/bake.py` so the bake tool auto-creates an empty stub if the Data file is missing:

```python
EXPECTED_MODULES = [
    ..., "Pots",
]
```

**5. (Optional) Add a wago row mapper** in `tools/import-wago.py` if there's a DBC table that fits:

```python
def _row_pots(row):
    rid = _to_int(row.get("ID"))
    label = (row.get("Name_lang") or "").strip()
    if not rid or not label: return None
    return { "id": rid, "label": label, "sources": ["wago"] }

TABLE_CONFIG["SomeDBCTable"] = ("Pots", _row_pots)
```

**6. (Optional) Add a Wowhead parser** in `tools/crawl-wowhead.py` if there's per-id enrichment worth scraping. Mirror the structure of `parse_npc` / `parse_item` / `parse_quest`.

**7. (Optional) Add runtime capture** in `Adapters/Runtime.lua` if there's a relevant WoW event.

After step 4, run the bake tool once and an empty `Data/Pots.lua` will appear, ready to be filled by an import or runtime capture.

---

## Embedding in a consumer addon

LibCodex follows the standard LibStub convention. Two things to set up in your addon:

**1. Vendor LibStub and LibCodex** in your addon's libs folder:

```
MyAddon/
  Libs/
    LibStub/
      LibStub.lua
    LibCodex-1.0/
      ... (the contents of this repo) ...
```

**2. Reference LibCodex's embed manifest** from your addon's `embeds.xml`:

```xml
<Ui>
    <Script file="Libs\LibStub\LibStub.lua"/>
    <Include file="Libs\LibCodex-1.0\LibCodex-1.0.xml"/>
</Ui>
```

Then call `LibStub("LibCodex-1.0")` from anywhere in your addon and use the API. Multiple addons can embed the same version with no conflict; LibStub only loads the highest-versioned copy.

LibCodex declares its own `## SavedVariables: LibCodexDB` when loaded as a standalone addon. When embedded inside a consumer addon, the consumer is responsible for declaring SavedVariables too, OR LibCodex can be loaded as a sibling addon (set `## LoadOnDemand: 0` in the embedded copy's TOC and let WoW load it normally).

---

## Repo layout

```
LibCodex-1.0/
  LibCodex-1.0.lua            core: LibStub registration, top-level accessors
  LibCodex-1.0.toc            standalone-addon manifest
  LibCodex-1.0.xml            embed manifest (consumer addons reference this)
  README.md                   this file

  Modules/
    Common.lua                collection factory
    Catalog/
      NPCs.lua, Items.lua, GameObjects.lua, Spells.lua, Quests.lua,
      Talents.lua, FlightPoints.lua, Crafts.lua, Professions.lua,
      Pets.lua, Mounts.lua, Toys.lua, Heirlooms.lua, Achievements.lua,
      Encounters.lua, Zones.lua, Currencies.lua,
      Areas.lua, Vignettes.lua, Holidays.lua, QuestPOI.lua, PvpTalents.lua,
      Enchants.lua, ItemSets.lua, TradeSkillCategories.lua, TransmogSets.lua,
      LFGDungeons.lua, Battlemasters.lua, Scenarios.lua, GroupFinder.lua,
      BattlePetAbilities.lua, CustomizationOptions.lua,
      CustomizationChoices.lua, TransmogIllusions.lua,
      AreaTriggers.lua, PlayerConditions.lua
    Enums/
      Classes.lua, Factions.lua, Races.lua, Realms.lua,
      CreatureTypes.lua, Specs.lua, Stats.lua, Difficulty.lua

  Data/                       bundled seed (one file per module; generated by bake.py)
    NPCs.lua, Items.lua, ...

  Adapters/
    Runtime.lua               WoW event hooks for live capture

  embeds/
    LibStub/                  vendored LibStub for standalone use

  Log.lua                     dedicated debug-window helper
  Dashboard.lua               GUI control panel (/codex gui)
  SlashCommand.lua            /codex slash command suite

  tools/                      Python build tools (not loaded by WoW)
    bake.py                   merge SavedVariables into Data/
    import-wago.py            fetch DBC CSVs from wago.tools
    crawl-wowhead.py          fetch quest/NPC/item pages from Wowhead
    bake-config-wago.lua      bake config pointing at wago-import.lua
    bake-config-wowhead.lua   bake config pointing at wowhead-import.lua

  .wago-cache/                downloaded CSVs (gitignored)
  .wowhead-cache/             downloaded HTML pages (gitignored)
```

---

## Versioning

LIB_MAJOR is `LibCodex-1.0`. The 1.0 in the major name is part of the LibStub contract: when consumers ask for `LibStub("LibCodex-1.0")` they're asking for the 1.x line. Breaking changes would mint a `LibCodex-2.0` major.

LIB_MINOR is the integer revision. Bump it when shipping a backwards-compatible change so older copies of the library yield to newer ones at LibStub registration time.

---

## License

MIT. See LICENSE if/when one is added.
