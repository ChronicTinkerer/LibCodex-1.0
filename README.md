<p align="center">
  <picture>
    <!--
      Drop in a light-mode variant (LibCodexLogoLight.png) or dark-mode
      variant (LibCodexLogoDark.png) and uncomment the matching <source>
      below to switch automatically based on the visitor's GitHub theme.
      <source media="(prefers-color-scheme: dark)" srcset="LibCodexLogoDark.png">
      <source media="(prefers-color-scheme: light)" srcset="LibCodexLogoLight.png">
    -->
    <img src="LibCodexLogo.png" alt="LibCodex" width="220">
  </picture>
</p>

# LibCodex-1.0

A reusable static-catalog library for World of Warcraft addons. **74 catalog and enum modules** covering every major DBC family the game ships:

- **World**: NPCs, items, game objects, vignettes (rare spawns / treasures), area triggers, zones, sub-zones (areas), flight points
- **Quests**: catalog with objectives, rewards (items / currency), quest lines, POI map markers, and quest-giver coordinates
- **Combat**: spells, talents, PvP talents, specs, classes, races, creature types, stats
- **Achievements**: catalog with per-step criteria attached
- **Collections**: pets (with abilities), pet-battle abilities, mounts, toys, heirlooms, transmog sets, transmog illusions
- **Group content**: encounters (instances + bosses), LFG dungeons, battlemasters (BG / arena), scenarios (with steps), Premade Group Finder activities, difficulty enum
- **Professions**: profession skill lines, recipes (crafts), trade-skill sub-categories, enchants, item sets (with tier bonuses)
- **Social / meta**: factions (player + reputation), currencies, realms, holidays, character-creation customization options + choices, player-condition predicates

Hybrid load model: per-module LoadOnDemand seed data (each module's bundled rows ship in its own LoD companion addon, loaded only when queried) + runtime growth (events captured during play) + a pluggable adapter system for reading from other addons. Idle memory cost is tiny because consumers only pay for the modules they actually touch.

Consumer addons embed it the same way they embed any LibStub library.

```lua
local LC = LibStub("LibCodex-1.0")
local entry = LC:NPCs():Get(207516)
print(entry.label, entry.creatureType, entry.classification)
```

---

**Method-level reference:** [`docs/API.md`](docs/API.md) — every public method, signature, and module-specific helper. Use this as the lookup; this README covers schema and architecture.

## Table of contents

- [Quick start for consumers](#quick-start-for-consumers)
- [Architecture](#architecture)
- [Module catalog](#module-catalog)
- [Data file format](#data-file-format)
- [Adapters](#adapters)
- [SavedVariables](#savedvariables)
- [Slash commands and GUI](#slash-commands-and-gui)
- [Multi-flavor support](#multi-flavor-support)
- [Build tools](#build-tools)
- [Adding a new module](#adding-a-new-module)
- [Distribution patterns](#distribution-patterns)
- [Repo layout](#repo-layout)
- [Versioning](#versioning)
- [Releasing](#releasing)

---

## Quick start for consumers

LibCodex ships as a standalone addon. Two ways to use it from your addon:

**Option A — depend on it as a sibling addon (recommended).** Add this line to your addon's `.toc`:

```
## Dependencies: LibCodex-1.0
```

WoW will load LibCodex first, and `LibStub("LibCodex-1.0")` works from anywhere in your code. No vendoring, no embed manifest. Users install LibCodex as a separate addon (CurseForge / WoWInterface / manual).

**Option B — vendor a copy under `Libs/` and embed it** (self-contained distribution; no separate user install). Drop the `LibCodex-1.0` folder under your addon's `Libs/` directory and reference its embed manifest from your `embeds.xml`:

```xml
<Include file="Libs\LibCodex-1.0\LibCodex-1.0.xml"/>
```

Both patterns work; LibStub guarantees only one copy is active at a time.

Once loaded, the API is identical:

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

Four layers, loaded in this order. Bundled seed data lives in 73 per-module LoadOnDemand companion addons, NOT inside the core library, so the always-on cost is small and consumers only pay for the modules they query.

```
1. Module factory            (Modules/Common.lua)
   |
   v
2. Module registrations      (Modules/Catalog/*.lua, Modules/Enums/*.lua)
   |
   v
3. PLAYER_LOGIN
   - SavedVariables hydrate  (LibCodexDB.modules -> :Add)
   - Adapters run            (Adapters/*.lua)
   |
   v
4. Lazy per-module LoD       (first :Get() miss for any module triggers
                              C_AddOns.LoadAddOn("LibCodex-1.0-<Module>");
                              that addon's Data\<Module>.lua then runs and
                              calls _FeedBundled* on the registered module)
```

**Layer 1: factory.** `Modules/Common.lua` exports `LibCodex.CollectionFactory.New(name, opts)` which builds an id-keyed collection with the standard `:Get / :Search / :Add / :All / :Count` shape.

**Layer 2: modules.** Each `Modules/Catalog/*.lua` and `Modules/Enums/*.lua` calls the factory, attaches module-specific helpers, and registers itself with `LibCodex:RegisterModule(name, collection)`.

**Layer 3: runtime.** At PLAYER_LOGIN, the library hydrates `LibCodexDB` (everything captured in previous sessions) and runs every registered adapter. The runtime adapter (`Adapters/Runtime.lua`) hooks events like `NAME_PLATE_UNIT_ADDED`, `LOOT_OPENED`, `QUEST_ACCEPTED`, `TAXIMAP_OPENED` to keep the catalog growing as the player moves through the world.

**Layer 4: per-module bundled seed (LoadOnDemand).** This is the big one for memory. The core library ships zero `Data/` files itself. Instead, each module has a sibling LoadOnDemand companion addon named `LibCodex-1.0-<ModuleName>` (e.g. `LibCodex-1.0-Items`, `LibCodex-1.0-Quests`, `LibCodex-1.0-NPCs`) that ships exactly one `Data\<Module>.lua` with that module's bundled rows.

When something calls `LC:Items():Get(25)` for the first time, `Modules/Common.lua` checks `_entries / _rowIndex / _tsvIndex / _lazyChunks` and on a complete miss invokes `LibCodex:_TryLoadModule("Items")`. That LoadAddOns the `LibCodex-1.0-Items` companion, which runs `Data\Items.lua`, which feeds rows into the registered `Items` collection. The retry then expands the row and returns the entry.

Result: a session that only touches `Quests` and `NPCs` pays the bytecode cost for those two modules and nothing else. The 400K-row Spells catalog stays unloaded unless somebody queries Spells. Real-world test: querying every module loads ~1.18 GB of Lua memory; querying Items + NPCs alone loads ~140 MB. Compare to ~1.84 GB if every module's data was always in the core lib's bytecode pool.

The `LoadModule` mechanism is idempotent — a successful load is recorded in `_loadedModules`, and a failed load is recorded in `_loadAttempts` so the retry path doesn't pound `LoadAddOn` on every miss for a permanently-missing companion.

Catalog modules grow from any of three sources tagged in `entry.sources`:
- `bundled` — shipped in `LibCodex-1.0-<Module>/Data*/<Module>.lua`
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
| `AreaPOI`      | wago `AreaPOI` + `AreaPOIState` | `description`, `x`/`y`/`z`, `continentID`, `areaID`, `portLocID`, `playerCondition`, `uiAtlasMember`, `worldStateID`, `states[]` (state overlays). Named map markers — capital portals, world bosses, flight points, etc. |
| `WMOAreaTables`| wago `WMOAreaTable`             | `wmoID`, `wmoGroupID`, `nameSetID`, `areaTableID`, `ambienceID`, `zoneMusicID`. Interior areas inside dungeons / detailed-geometry locations. |
| `TaxiPaths`    | wago `TaxiPath` + `TaxiPathNode` | `fromNode`, `toNode` (-> FlightPoints), `cost`, `nodes[]` (each: `x`, `y`, `z`, `continentID`, `nodeIndex`, `flags`, `delay`). Actual flight routes between flight masters. |
| `DungeonEncounters` | wago `DungeonEncounter`    | `mapID`, `difficultyID`, `orderIndex`, `bit`, `completeWorldStateID`, `icon`, `faction`. Combat-log encounter ids — distinct from `Encounters` which lists adventure-guide entries. |
| `ItemAppearances` | wago `ItemAppearance`        | `displayType`, `displayInfoID`, `icon`, `uiOrder`, `transmogPlayerCondition`. Distinct visual appearances for transmog. |
| `ItemModifiedAppearances` | wago `ItemModifiedAppearance` | `itemID`, `appearanceID`, `modifierID`, `orderIndex`, `sourceType`. Bridge from item-with-modifier to appearance — `TransmogSets.appearances[]` ids resolve here. |
| `ItemBonuses`  | wago `ItemBonusList` + `ItemBonus` | `flags`, `bonuses[]` (each: `type`, `value0..3`, `orderIndex`). Item modifier system — the `:bonus_id1:bonus_id2:` segment in item hyperlinks. |
| `ItemEffects`  | wago `ItemEffect` + `ItemXItemEffect` | `spellID`, `triggerType`, `charges`, `cooldownMS`, `categoryCooldownMS`, `spellCategoryID`, `specID`, `playerCondition`, `items[]` (which items grant this effect). |
| `SpellChargeCategories` | wago `SpellCategory`   | `maxCharges`, `chargeRecoveryTime`, `usesPerWeek`, `typeMask`. Charge-group definitions (Avenging Wrath, Reverse Time, etc). |
| `SpellMechanics` | wago `SpellCategories`        | `spellID`, `category`, `chargeCategory`, `defenseType`, `diminishType`, `dispelType`, `mechanic`, `preventionType`, `startRecoveryCategory`. Per-spell mechanic / DR / dispel bindings. |
| `SpellCooldowns` | wago `SpellCooldowns`         | `spellID`, `recoveryTime`, `categoryRecoveryTime`, `startRecoveryTime`, `auraSpellID`. Per-spell cooldown data. |
| `SpellCastTimes` | wago `SpellCastTimes`         | `base`, `minimum`. Cast-time lookup table (small enum referenced from Spell.CastingTimeIndex). |
| `SpellPower`     | wago `SpellPower`             | `spellID`, `powerType`, `manaCost`, `manaPerSecond`, `powerCostPct`, `optionalCost`, plus per-percent / per-second variants. Resource cost data. |
| `SpellRanges`    | wago `SpellRange`             | `label`, `shortLabel`, `rangeMinFriend`/`Hostile`, `rangeMaxFriend`/`Hostile`. Range lookup table. |
| `SpellDurations` | wago `SpellDuration`          | `duration`, `maxDuration`, `durationPerResource`. Aura duration lookup table. |
| `Glyphs`       | wago `GlyphProperties`          | `spellID`, `glyphType`, `glyphExclusiveCategoryID`, `icon`. Legacy glyph catalog (system retired in Legion but DBC remains). |
| `AchievementCategories` | wago `Achievement_Category` | `parentID`, `uiOrder`. Bucket names for the Achievements panel. `:Path(catID)` walks parents. Also enriches `Achievements.categoryName`. |
| `FriendshipReputations` | wago `FriendshipReputation` + `FriendshipRepReaction` | `factionID` (-> Factions), `description`, `standingModified`, `standingChangedText`, `icon`, `tiers[]` (each: `reaction`, `threshold`, `color`). Custom-rank reputations like Nomi / Steamwheedle. |
| `Maps`         | wago `Map`                      | `directory`, `mapType`, `instanceType`, `expansion`, `areaTableID`, `parentMapID`, `loadingScreenID`. Internal MapID catalog (continent/zone/instance/scenario). Distinct from `Zones` which exposes UiMap. |
| `MapDifficulties` | wago `MapDifficulty`         | `mapID`, `difficultyID`, `message`, `maxPlayers`, `resetInterval`, `lockID`, `contentTuningID`. Per-map difficulty tier definitions. |
| `EncounterCreatures` | wago `JournalEncounterCreature` | `journalEncounterID`, `creatureDisplayInfoID`, `fileDataID`, `orderIndex`. Boss + add creatures per dungeon-journal encounter. |
| `EncounterSections` | wago `JournalEncounterSection` | `journalEncounterID`, `title`, `bodyText`, `parentSectionID`, `firstChildSectionID`, `nextSiblingSectionID`, `type`, `spellID`, `difficultyMask`. Strategy text sections of the dungeon journal (tree-structured). |
| `SkillRaceClass` | wago `SkillRaceClassInfo`     | `skillID`, `raceMask`, `classMask`, `minLevel`, `availability`. Which races/classes can train each skill line. |
| `GossipOptions` | wago `GossipNPCOption`         | `gossipNpcOption`, `lfgDungeonsID`, `trainerID`, `uiMapID`, `traitTreeID`, `professionID`, etc. Per-NPC gossip option metadata — what each gossip click triggers. |
| `Movies`       | wago `Movie`                    | `volume`, `keyID`, `audioFileDataID`, `subtitleFileDataID`. Pre-rendered cinematic movie definitions. |
| `Cinematics`   | wago `CinematicSequences`       | `soundID`, `cameras[]` (up to 8 CinematicCamera ids). In-engine cutscene scripts. |

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
| `Regions`        | wago `Cfg_Regions`    | `tag`, `regionID`, `raidOrigin`, `regionGroup`. WoW publishing regions. |
| `Languages`      | wago `Languages`      | `flags`, `uiTextureKitID`, `learningCurveID`. Chat language enum. |
| `ChatChannels`   | wago `ChatChannels`   | `shortcut`, `flags`, `factionGroup`, `ruleset`. Default channel definitions. |

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
/codex perf [Module]      lazy-load memory footprint (no arg = summary)
/codex gui                redirect to /forge codex (see note below)
```

`/codex perf` with no argument prints a per-module summary of how many
lazy chunks are still pending vs. materialized — a quick sanity check that
modules nobody queried haven't been needlessly expanded. With a module
name (`/codex perf Spells`) it forces a full expand of that one module
and reports the Lua memory delta in KB, so you can see exactly what each
catalog costs at runtime.

**Note:** the built-in dashboard was retired during v1.0 development and
moved to the standalone **Forge_Codex** sub-addon (part of the Forge
developer toolset). `/codex gui` now redirects to `/forge codex` if Forge
is loaded; otherwise the slash logs a hint pointing the user to install
Forge.

The Forge_Codex tab provides the same Stats / Search / Browse / Where /
Settings / Actions / Log views, plus per-module entry inspection,
deeper field rendering, and integration with Forge_Logs for filtered
log views. Source for that lives in the `Forge_Codex/` addon folder.

LibCodex-1.0 itself ships only the data layer and the slash-command
layer; the GUI lives in Forge to keep this library lean for embedding.

---

## Multi-flavor support

LibCodex ships catalogs for three game flavors, with one TOC and one Data folder per flavor:

| Flavor | TOC | Data folder | Bundled data sources |
| --- | --- | --- | --- |
| **Mainline** (Retail) | `LibCodex-1.0.toc` | `Data/` | wago.tools (DBC) + Wowhead enrichment |
| **Mists** (MoP Classic) | `LibCodex-1.0_Mists.toc` | `Data_Mists/` | wago.tools (DBC) |
| **TBC** (TBC Anniversary) | `LibCodex-1.0_TBC.toc` | `Data_TBC/` | cmangos `tbc-db` SQL + wago.tools |
| **Vanilla** (Classic Era / Hardcore) | `LibCodex-1.0_Vanilla.toc` | `Data_Vanilla/` | cmangos `classic-db` SQL + wago.tools |
| **XPTR** (Retail experimental PTR) | `LibCodex-1.0_XPTR.toc` | `Data_XPTR/` | wago.tools (DBC) |

The BigWigs packager builds three separate zips at release time, one per flavor TOC. CurseForge / Wago / WoWInterface auto-tag each upload to the right game-version slot based on the TOC's `## Interface:` line.

**Why three different data sources?** Blizzard ships stripped-down DBCs for non-Retail flavors and fills in the rest server-side at runtime. wago.tools' DBC mirror sees only what's in the static DBC, so Classic-flavor Creature catalogs from wago alone can be near-empty. For TBC, we instead ingest the cmangos server emulator's open-source world DB SQL dump, which contains the full creature/quest/object catalog assembled from years of community reverse-engineering. Mists (MoP Classic) currently uses wago alone because no maintained MoP server emulator with public SQL dumps is wired up yet; Wowhead-crawl enrichment fills the gap pending that work.

**Adding a new flavor:**

1. Append a row to `FLAVOR_DATA_DIR` and `FLAVOR_DEFAULT_SOURCE` maps in each tool (`bake.py`, `import-wago.py`, `import-emulator-sql.py`, `import-blizzard.py`, `crawl-wowhead.py`).
2. Create `Data_<NewFlavor>/` with a stub for every module (run `bake.py --flavor <name>` once and it will auto-create empty stubs).
3. Create `LibCodex-1.0_<NewFlavor>.toc` cloned from an existing flavor TOC; update `## Interface:` and the `Data_<NewFlavor>\*.lua` include list.
4. Append the new TOC path to `release.ps1`'s `$FilesToBump` array so future bumps include it.
5. Run an import (wago / emulator SQL / Wowhead) for the new flavor and bake.

---

## Build tools

All Python tools live in `.dev/tools/` (see [Repo layout](#repo-layout) — everything dev-local lives under `.dev/`). They use only the standard library (no pip installs needed). Tested on Python 3.10+. Tools accept `--flavor mainline|mists|tbc` to target a specific Classic flavor; defaults to mainline.

### `.dev/tools/refresh.ps1` (recommended entry point)

End-to-end pipeline wrapper. One command runs the full import + bake cycle for one flavor.

```powershell
.\.dev\tools\refresh.ps1 -Flavor mists
.\.dev\tools\refresh.ps1 -Flavor mists -SkipWowhead   # wago only, fast
.\.dev\tools\refresh.ps1 -Flavor tbc -MaxIds 500
.\.dev\tools\refresh.ps1 -Flavor mainline -DryRun     # preview
```

Sequence: `import-wago` → `bake` → `crawl-wowhead` → `bake`. Each step is idempotent and resumable.

### `.dev/tools/import-wago.py`

Pulls DBC table CSV exports from [wago.tools](https://wago.tools), maps each row into Codex schema, writes a SavedVariables-shaped Lua file the bake tool can merge.

```
py .dev\tools\import-wago.py --flavor mists
```

Defaults: fetches every table in `TABLE_CONFIG` (~22 tables across 19 modules), caches CSVs under `.dev/wago-cache/`, writes `.dev/wago-import-<flavor>.lua`.

Useful flags:

```
--flavor mainline|mists|tbc     game flavor (sets default branch and output)
--tables Creature,ItemSparse    only fetch named tables
--branch wow                    explicit wago branch (overrides flavor default)
--cache-dir .dev/wago-cache     where to cache downloaded CSVs
--output <path>                 explicit output file
```

### `.dev/tools/import-emulator-sql.py`

Ingests a server-emulator world DB SQL dump (cmangos schema) and produces a SavedVariables-shaped Lua file with rich NPC/Quest/GameObject data including spawn coordinates and quest relations. **The load-bearing tool for non-Retail flavors**, where wago.tools' Creature DBC is sparse but server emulators have complete content from years of community work.

```
py .dev\tools\import-emulator-sql.py --flavor tbc
```

Defaults: downloads the cmangos TBC dump (~15 MB gzipped) from `cmangos/tbc-db` on first run, caches under `.dev/emulator-sql-cache/`, writes `.dev/emulator-import-tbc.lua`.

Tables ingested: `creature_template` (NPCs), `creature` (spawn instances), `quest_template`, `creature_questrelation`, `creature_involvedrelation`, `gameobject_template`, `item_template`. Output schema includes per-NPC spawn coordinates, faction, level range, and quest-start/end relations.

### `.dev/tools/crawl-wowhead.py`

Targeted Wowhead crawler. For each NPC/Item/Quest id you supply, fetches the Wowhead page and extracts what wago can't give us:

- NPCs: spawn locations (mapID + normalized x/y per spawn)
- Items: drop sources (which NPC dropped it, with drop chance), vendor sources
- Quests: title, level, side, item rewards, currency rewards, quest-giver and turn-in NPCs, quest-giver map coordinates

Polite citizen by default: 1.5s between requests with jitter, recovery pause on 403, per-id disk cache, hard cap on total requests per run.

```
py .dev\tools\crawl-wowhead.py --flavor mists --modules Quests --from-data Data_Mists --max-ids 1000
```

Flag summary:

```
--flavor mainline|mists|tbc     URL prefix + cache + default output
--from <savedvars.lua>          read ids from a SavedVariables file
--from-data <Data dir>          read ids from Data/*.lua (uses what's already baked)
--ids "12345,67890,100-200"     explicit id list / ranges
--modules NPCs,Items,Quests     which modules to crawl
--max-ids 1000                  hard cap per run
--rate 1.5                      seconds between requests
--quality-min 4                 Items only: skip below this quality
--dry-run                       plan without fetching
--quiet                         only print errors and the final summary
```

The crawler is fully resumable. Cached pages are detected and skipped without a network round-trip, so re-running the same command after a cancelled run picks up where it left off.

### `.dev/tools/bake.py`

Reads SavedVariables (or the output of an importer or crawler) and merges learned entries into `Data/*.lua` (Mainline) or `Data_<Flavor>/*.lua` (per Classic flavor). Hand-curated entries marked `_handcrafted=true` survive every bake.

```
py .dev\tools\bake.py --flavor mists --source .dev\wago-import-mists.lua
```

Useful flags:

```
--flavor mainline|mists|tbc     selects the Data folder + default source
--source <path>                 SavedVariables-shaped Lua to merge from
--data-dir <path>               override output Data folder (rarely needed)
--dry-run                       show what would change without writing
--only Items,NPCs               only process named modules
--skip Realms                   skip named modules
```

Backups land in `Data_<Flavor>/.bake-backup/<timestamp>/` before any file is overwritten. The bake's location-dedup logic collapses near-duplicate `locations` entries within a small radius (`NPCs` ~50 yards, `GameObjects` ~15 yards) so repeated visits don't bloat coordinates.

### `.dev/tools/import-blizzard.py`

Fetches Item/Quest data from Blizzard's official Game Data API. Useful supplement for Mainline catalogs. Note: Blizzard's API does NOT expose individual creature lookup, so it cannot fill the NPC gap on Classic flavors — for that, use `import-emulator-sql.py` instead. Requires `BNET_CLIENT_ID` and `BNET_CLIENT_SECRET` environment variables; register a client at https://develop.battle.net.

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

## Distribution patterns

LibCodex follows the standard LibStub convention and ships as a standalone addon plus its 73 per-module LoD companions. Two distribution patterns work:

### Pattern A: Standalone dependency (recommended)

LibCodex's published zip unpacks to **74 sibling folders** inside `Interface/AddOns/`:

```
Interface/AddOns/
  LibCodex-1.0/             core library (always-on)
  LibCodex-1.0-Items/       LoadOnDemand companion (loads on first Items query)
  LibCodex-1.0-NPCs/
  LibCodex-1.0-Quests/
  ... 70 more LibCodex-1.0-<Module>/ folders ...
```

WoW only loads top-level AddOns folders, so the 73 LoD companions need to live as siblings of the core, not nested inside it. The CurseForge / WoWInterface / Wago packages handle this layout automatically — users just install "LibCodex-1.0" through their addon manager and end up with all 74 folders.

Your consumer addon declares the core as a dependency in its `.toc`:

```
## Title: MyAddon
## Dependencies: LibCodex-1.0
```

You do NOT need to declare each `LibCodex-1.0-<Module>` as a dependency — the core lib auto-loads them on demand. WoW will load LibCodex-1.0 before MyAddon, then `LibStub("LibCodex-1.0")` works from anywhere in your code, and any `:Get(id)` call against a module triggers the matching LoD companion if it isn't already loaded.

LibCodex declares its own `## SavedVariables: LibCodexDB` in its `.toc`, so all the runtime growth (NPC sightings, captured loot, chromie tags) persists at the library level — every addon that uses LibCodex shares the same catalog.

### Pattern B: Vendored / embedded core (no bundled data)

You can vendor the core library under your addon's `Libs/` and embed it the standard way:

```
MyAddon/
  Libs/
    LibStub/
      LibStub.lua
    LibCodex-1.0/
      ... (core lib only — Modules/, Adapters/, Log.lua, SlashCommand.lua) ...
```

```xml
<!-- MyAddon/embeds.xml -->
<Ui>
    <Script file="Libs\LibStub\LibStub.lua"/>
    <Include file="Libs\LibCodex-1.0\LibCodex-1.0.xml"/>
</Ui>
```

**Caveat — vendoring drops the bundled seed data.** The 73 `LibCodex-1.0-<Module>` companion addons can't be vendored because WoW's loader doesn't see nested folders. Vendoring gives you the registration surface, the runtime adapter, the SavedVariables persistence, and the slash commands, but every `:Get(id)` will return `nil` until something populates the module via runtime capture, an adapter, or `:Add(entry)`.

This pattern is useful for addons that:
- Capture data at runtime and don't need a pre-baked seed catalog
- Already get their data from another source and only want LibCodex's storage / search / merge behavior
- Want to ship as a single-folder addon with no external dependency declaration

If you DO want bundled seed data in a vendored install, you'd have to also distribute the per-module addon folders as siblings of your addon — at which point Pattern A is simpler.

### Choosing between them

- **Pattern A** for production / public release. Standard layout, full catalog, shared SavedVariables, modules load on demand so memory cost matches what you actually query.
- **Pattern B** for self-contained internal addons that drive their own data and just want LibCodex's data-shape conventions.

---

## Repo layout

```
LibCodex-1.0/
  LibCodex-1.0.lua            core: LibStub registration, accessors, LoadModule
  LibCodex-1.0.toc            Mainline (Retail) manifest, no Data/ entries
  LibCodex-1.0_Mists.toc      MoP Classic manifest
  LibCodex-1.0_TBC.toc        TBC Anniversary manifest
  LibCodex-1.0_Vanilla.toc    Classic Era / Hardcore manifest
  LibCodex-1.0_XPTR.toc       Experimental PTR manifest
  LibCodex-1.0.xml            embed manifest (consumer addons reference this)
  README.md  CHANGELOG.md  LICENSE
  .gitignore  .pkgmeta        .pkgmeta has 73 move-folders entries (see below)

  Modules/
    Common.lua                collection factory
    Catalog/                  catalog module declarations (registration only)
    Enums/                    enum module declarations (small + hand-curated)

  LibCodex-1.0-Items/         per-module LoD companion (1 of 73)
    LibCodex-1.0-Items.toc        Mainline TOC, ## LoadOnDemand: 1
    LibCodex-1.0-Items_Mists.toc  MoP Classic TOC
    LibCodex-1.0-Items_TBC.toc    TBC Anniversary TOC
    LibCodex-1.0-Items_Vanilla.toc
    LibCodex-1.0-Items_XPTR.toc
    Data/Items.lua            Mainline bundled rows (~11 MB on disk)
    Data_Mists/Items.lua
    Data_TBC/Items.lua
    Data_Vanilla/Items.lua
    Data_XPTR/Items.lua
  LibCodex-1.0-NPCs/          ... 72 more sibling per-module addons
  LibCodex-1.0-Quests/        each follows the exact same structure as
  LibCodex-1.0-Spells/        LibCodex-1.0-Items above
  ...
```

The 73 per-module addon folders are nested inside `LibCodex-1.0/` in the source repo for git / packaging convenience. The BigWigs packager's `move-folders` directive in `.pkgmeta` lifts each one to a sibling at the published-zip root, so end users end up with `Interface/AddOns/LibCodex-1.0/` and `Interface/AddOns/LibCodex-1.0-Items/` at the top level. WoW only loads top-level AddOns folders, never nested ones — that's why the flatten-at-package step is required.

Adapters and slash commands live alongside Modules/ inside the core repo:

```
LibCodex-1.0/
  Adapters/
    Runtime.lua               WoW event hooks for live capture

  embeds/
    LibStub/                  vendored LibStub for standalone use
  libs/
    LibEditMode/              vendored LibEditMode

  Log.lua                     dedicated debug-window helper
                              (also bridges to Cairn-Log-1.0 if present)
  SlashCommand.lua            /codex slash command suite

  .dev/                       all dev-local artifacts (gitignored, pkgignored)
    tools/                    Python build tools + refresh.ps1
      bake.py                 merge import dumps into per-module Data folders
      import-wago.py          fetch DBC CSVs from wago.tools
      import-emulator-sql.py  ingest cmangos-style server emulator SQL dumps
      import-blizzard.py      fetch from Blizzard Game Data API (OAuth)
      crawl-wowhead.py        targeted Wowhead enrichment
      refresh.ps1             end-to-end pipeline wrapper
    release.ps1               one-command tag + push; bumps the Core TOCs
                              AND every nested per-module TOC in lockstep
    configs/                  bake-config*.lua (per-source paths)
    wago-cache/               downloaded CSVs
    wowhead-cache-<flavor>/   per-flavor HTML cache
    blizzard-cache-<flavor>/  per-flavor API JSON cache
    emulator-sql-cache/       gzipped server emulator dumps
    *-import-<flavor>.lua     intermediate import dumps from each tool
```
```

The `.dev/` folder convention keeps the repo root tidy: a single `.gitignore` line (`.dev/`) and a single `.pkgmeta ignore:` entry (`- .dev`) cover every dev artifact. Adding a new tool or cache type does not require touching either file.

---

## Versioning

LIB_MAJOR is `LibCodex-1.0`. The `1.0` in the major name is part of the LibStub contract: when consumers ask for `LibStub("LibCodex-1.0")` they're asking for the 1.x line. Breaking changes would mint a `LibCodex-2.0` major.

LIB_MINOR is a **sequential integer build number**. Each release.ps1 invocation reads the current version from the primary TOC and writes `N+1` to all configured TOCs and the lib MINOR in lockstep. First release of a new project starts at 1.

This replaced the previous YYMMDDHHMM time-stamp scheme on 2026-05-05 because time-stamped versions go non-monotonic when builds happen from machines on different timezones (a UTC-stamped sandbox build vs an Eastern-time local build can produce timestamps that disagree with the wall clock). Sequential is always strictly increasing and free of timezone failure modes.

All three flavor TOCs (`LibCodex-1.0.toc`, `LibCodex-1.0_Mists.toc`, `LibCodex-1.0_TBC.toc`) plus `LibCodex-1.0.lua`'s LIB_MINOR are bumped together by `release.ps1` so users on any client see the same release at the same time.

---

## Releasing

Auto-packaging is wired up via [BigWigsMods/packager](https://github.com/BigWigsMods/packager) in `.github/workflows/release.yml`. A pushed git tag triggers a build that produces three zips (Mainline, Mists, TBC), tags each with its game-version range based on the TOC's `## Interface:` line, and uploads to CurseForge / WoWInterface / Wago plus creates a GitHub Release.

**One-time setup (per site):**

1. Create the project page on each site you want to publish to:
   - CurseForge: https://www.curseforge.com -> Author Tools -> Submit Project
   - WoWInterface: https://www.wowinterface.com/downloads/author.php
   - Wago: https://addons.wago.io
2. Copy the numeric project ID from each site into each flavor's `.toc`:
   ```
   ## X-Curse-Project-ID: 12345
   ## X-Wago-ID: AbC123
   ## X-WoWI-ID: 67890
   ```
   Per-flavor staging tip: omit `X-Wago-ID` / `X-WoWI-ID` from a flavor's TOC to publish that flavor to CurseForge only on its first release. Add the lines back once the flavor is validated.
3. Generate an API token on each site and add as a GitHub repo secret (Settings -> Secrets and variables -> Actions):
   - `CF_API_KEY` -> https://www.curseforge.com/account/api-tokens
   - `WAGO_API_TOKEN` -> https://addons.wago.io/account/apikeys
   - `WOWI_API_TOKEN` -> WoWInterface profile -> API Tokens

A missing secret causes the packager to silently skip that site, so you can publish to CurseForge today and add WoWI/Wago whenever those project pages exist.

**Releasing a new build:**

```powershell
# One command: bumps all four version markers (3 TOCs + LIB_MINOR) by +1,
# commits, tags with the new build number, pushes HEAD + tag.
.\.dev\release.ps1 "v3: short description of changes"
```

What the script does:

1. Reads `## Version: N` from `LibCodex-1.0.toc` (the primary).
2. Writes `N+1` to all three TOCs and `LibCodex-1.0.lua`'s `LIB_MINOR`.
3. `git add -A && git commit -m "<msg>"`.
4. `git tag -a <N+1> -m <N+1>` (annotated, never lightweight — VSCode silently skips lightweight tags).
5. `git push origin HEAD && git push origin <tag>`.

The push of the tag fires the workflow. Watch progress under the **Actions** tab on GitHub.

Use `-DryRun` to preview the changes without writing files or running git. Use `-NoPush` to bump + commit + tag locally without pushing.

---

## License

MIT. See [LICENSE](LICENSE).
