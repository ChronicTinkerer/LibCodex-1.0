# LibCodex-1.0 — API reference

Hand-curated reference for the public surface of the library. For schemas (what fields each module's entries carry), see the **Module catalog** table in [`README.md`](../README.md). This file documents **methods**, not data shape.

## Contents

- [Getting the library handle](#getting-the-library-handle)
- [Standard collection API](#standard-collection-api)
- [Top-level accessors](#top-level-accessors)
- [Module-specific helpers](#module-specific-helpers)
- [Lazy materialization semantics](#lazy-materialization-semantics)
- [Adapter API](#adapter-api)
- [Module registration](#module-registration)
- [Internal data-feed APIs](#internal-data-feed-apis)
- [Lifecycle and SavedVariables](#lifecycle-and-savedvariables)
- [Diagnostics](#diagnostics)

---

## Getting the library handle

```lua
local LC = LibStub("LibCodex-1.0")
```

Standard LibStub. The library registers itself with a YYMMDDHHMM build-stamp `LIB_MINOR`; LibStub keeps the highest version when multiple addons embed copies. See [`README.md`](../README.md#distribution-patterns) for the standalone-vs-embedded patterns.

---

## Standard collection API

Every module accessed via `LC:NPCs()`, `LC:Items()`, etc. is built from the same factory in `Modules/Common.lua`. Every module supports this method surface.

| Method | Signature | Returns |
| --- | --- | --- |
| `:Get(key)` | `key` is the entry id (number or string for player factions) | entry table or `nil` |
| `:Search(query, opts)` | `query` is whitespace-separated tokens, **all** must match (AND). `opts` may contain field-equality filters (`{ side="A" }`) and `opts.filter = function(entry) -> bool` | array of matching entries |
| `:Add(entry)` | adds or merges an entry. `entry.id` keys it; entries without `id` go to keyless `_extras`. Merge respects `_handcrafted` and `_locked` fields | the resulting (possibly merged) entry |
| `:All()` | iterator. `for k, e in mod:All() do ... end` | coroutine yielding `(key, entry)` pairs |
| `:AllArray()` | non-iterator alternative | array of entries |
| `:AllRaw()` | raw `key -> entry` map (used by SavedVariables persistence) | map |
| `:Count()` | total entry count (materialized + lazy chunks) | number |
| `:Name()` | the module's name | string |
| `:Remove(key)` | drop an entry | `true` if removed, `false` otherwise |
| `:Clear()` | drop everything | nothing |
| `:ExpandAll()` | force-materialize every lazy entry into the dict store | number of entries materialized |

### Search syntax

`:Search` splits the query on whitespace into tokens. **All tokens must appear** in the entry's haystack (the concatenation of its `searchFields`).

```lua
LC:Items():Search("rune cloth")        -- matches entries containing both "rune" AND "cloth"
LC:NPCs():Search("storm", { side="A" }) -- substring + faction filter
LC:Quests():Search("", { filter = function(e) return e.level and e.level > 60 end })
```

Empty query `""` returns every entry that passes the field/filter tests.

---

## Top-level accessors

One per module. Returns the registered collection or `nil` if the module isn't loaded. See README's catalog table for what each returns.

```lua
LC:NPCs()       LC:Items()       LC:GameObjects()    LC:Spells()
LC:Quests()     LC:Talents()     LC:FlightPoints()   LC:Crafts()
LC:Professions()  LC:Pets()      LC:Mounts()         LC:Toys()
LC:Heirlooms()  LC:Achievements()  LC:Encounters()   LC:Zones()
LC:Areas()      LC:Currencies()  LC:Reputations()    -- alias to LC:Factions()
LC:Vignettes()  LC:Holidays()    LC:QuestPOI()       LC:PvpTalents()
LC:Enchants()   LC:ItemSets()    LC:TradeSkillCategories()  LC:TransmogSets()
LC:LFGDungeons()  LC:Battlemasters()  LC:Scenarios()  LC:GroupFinder()
LC:BattlePetAbilities()  LC:CustomizationOptions()  LC:CustomizationChoices()
LC:TransmogIllusions()  LC:AreaTriggers()  LC:PlayerConditions()
LC:AreaPOI()    LC:WMOAreaTables()  LC:TaxiPaths()  LC:DungeonEncounters()
LC:ItemAppearances()  LC:ItemModifiedAppearances()  LC:ItemBonuses()  LC:ItemEffects()
LC:SpellChargeCategories()  LC:SpellMechanics()  LC:SpellCooldowns()
LC:SpellCastTimes()  LC:SpellPower()  LC:SpellRanges()  LC:SpellDurations()
LC:Glyphs()     LC:AchievementCategories()  LC:FriendshipReputations()
LC:Maps()       LC:MapDifficulties()  LC:EncounterCreatures()
LC:EncounterSections()  LC:SkillRaceClass()  LC:GossipOptions()
LC:Movies()     LC:Cinematics()
LC:Classes()    LC:Races()       LC:Realms()         LC:Factions()
LC:CreatureTypes()  LC:Specs()   LC:Stats()          LC:Difficulty()
LC:Regions()    LC:Languages()   LC:ChatChannels()
```

Generic fallback: `LC:GetModule(name)` returns any registered module by name.

---

## Module-specific helpers

In addition to the standard API above, certain modules expose convenience methods for common queries.

### NPCs

```lua
NPCs:Near(mapID, x, y, tol)              -- entries within a tolerance
NPCs:WithFlag(flag)                       -- e.g. flag="vendor", "questGiver"
NPCs:AddLocation(id, mapID, x, y, zone, ctx)
NPCs:LocationsForChromie(npcID, chromieID)
NPCs:AddDrop(npcID, itemID, mapID, x, y)
```

### Items

```lua
Items:AddFromAPI(itemID, hyperlink)       -- captures from GetItemInfo, async-loads if cold
Items:ByQuality(min, max)                 -- 0..7 (Poor..Heirloom)
Items:Reagents()                          -- isCraftingReagent items
Items:AddDropSource(itemID, kind, sourceID, mapID, x, y)
Items:GetDropSources(itemID)              -- array of {kind, sourceID, sourceLabel, count, locations}
```

### GameObjects

```lua
GameObjects:AddLocation(id, mapID, x, y, zone, ctx)
GameObjects:LocationsForChromie(objectID, chromieID)
GameObjects:AddDrop(objectID, itemID, mapID, x, y)
GameObjects:OfType(t)
```

### Quests

```lua
Quests:AddFromAPI(questID, opts)          -- capture from C_QuestLog at quest-accept time
Quests:MarkTurnedIn(questID)
Quests:Daily()                             -- entries with type=="daily"
Quests:ForSide(side)                       -- "A" | "H" — also returns side="B"/nil entries
Quests:ForChromie(chromieID)               -- entries captured while in this chromie
Quests:IsAvailableForPlayer(questID)       -- runtime predicate via C_QuestLog
```

### FlightPoints

```lua
FlightPoints:AddFromTaxiAPI(index, currentMap, side)
FlightPoints:Known()                       -- nodes the player has discovered
FlightPoints:ForSide(side)                 -- "A" | "H" | "B"
```

### Crafts / Professions / TradeSkillCategories

```lua
Crafts:ForProfession(skillLineID)
Crafts:GetLabel(craftID)                   -- resolves spell name via Spells module
Professions:Craftable()                    -- only the real professions (filtered by professionEnum)
TradeSkillCategories:ForSkillLine(skillLineID)
```

### Talents / PvpTalents

```lua
Talents:ForTree(treeID)
Talents:ForSubTree(subTreeID)              -- TWW hero-talent subtrees
PvpTalents:ForSpec(specID)
PvpTalents:GetLabel(talentID)              -- resolves spell name via Spells module
```

### Achievements / AchievementCategories

```lua
AchievementCategories:Path(catID, maxDepth)  -- walks parent chain to root
-- Each Achievement entry has `criteria[]` and `categoryName` attached at bake time.
```

### Encounters / DungeonEncounters / EncounterCreatures / EncounterSections

```lua
Encounters:Bosses(instanceID)              -- JournalEncounter rows
Encounters:Instances()                     -- JournalInstance rows
DungeonEncounters:ForMap(mapID)            -- combat-log boss ids per map
EncounterCreatures:ForEncounter(journalEncounterID)
EncounterSections:ForEncounter(journalEncounterID)
```

### LFGDungeons / Battlemasters / Scenarios / GroupFinder

```lua
LFGDungeons:ForExpansion(expID)
LFGDungeons:ByType(typeID)                 -- 1=Dungeon, 2=Raid, 4=Random, 6=Holiday, 7=Scenario
Battlemasters:ByInstanceType(t)            -- 1=BG, 4=Arena
GroupFinder:ByCategory(catID)              -- sorted by orderIndex
```

### Items deeper

```lua
ItemSets:ForItem(itemID)                   -- which sets this item belongs to
ItemModifiedAppearances:ForItem(itemID)
ItemModifiedAppearances:ForAppearance(appearanceID)
ItemEffects:ForSpell(spellID)
TransmogSets:ForExpansion(expID)
TransmogIllusions:GetLabel(illusionID)     -- resolves enchant name via Enchants module
```

### Spells deeper

```lua
SpellMechanics:ForSpell(spellID)
SpellCooldowns:ForSpell(spellID)
SpellPower:ForSpell(spellID)
```

### Maps / Areas / Vignettes / AreaPOI / AreaTriggers / TaxiPaths / WMOAreaTables / QuestPOI

```lua
Maps:ByInstanceType(t)
Areas:Path(areaID, maxDepth)               -- walks parent chain
Vignettes:ByType(vignetteType)
AreaPOI:ForContinent(continentID)
AreaPOI:ForArea(areaID)
AreaTriggers:ForContinent(continentID)
TaxiPaths:FromNode(taxiNodeID)
TaxiPaths:ToNode(taxiNodeID)
WMOAreaTables:ForArea(areaTableID)
QuestPOI:ForQuest(questID)                 -- sorted by objectiveIndex
QuestPOI:ForMap(uiMapID)
```

### Pets / BattlePetAbilities

```lua
BattlePetAbilities:ByPetType(t)
-- Each Pet has `abilities[]` attached at bake time.
```

### Customization

```lua
CustomizationOptions:ForModel(chrModelID)
CustomizationChoices:ForOption(optionID)
```

### Holidays / FriendshipReputations / SkillRaceClass

```lua
Holidays:Looping()                         -- recurring annual events
FriendshipReputations:ForFaction(factionID)
SkillRaceClass:ForSkill(skillID)
```

### Enums

```lua
Classes:GetByToken(token)                  -- e.g. "WARRIOR" -> entry
Races:GetByToken(token)
Races:ForFaction(side)                     -- "A" | "H" | "B"
Factions:GetForPlayer()                    -- A/H/N entry for current character
Factions:ByKind(kind)                      -- "player" or "reputation"
Factions:Players()                         -- alias for ByKind("player")
Factions:Reputations()                     -- alias for ByKind("reputation")
Specs:ForClass(classID)
Realms:Cluster(realm)                      -- connected-realm cluster
Realms:AreConnected(a, b)
Realms:Current()
Stats:ByKind(kind)                         -- "primary" / "secondary" / "tertiary" / "defensive"
Stats:ByToken(token)                       -- "ITEM_MOD_STRENGTH_SHORT" -> entry
Difficulty:ForInstanceType(t)
```

---

## Lazy materialization semantics

LibCodex defers row-table allocation until first use. Two layers of laziness exist:

**Module-level lazy chunks.** The bake tool emits each chunk as a thunk: `LibCodex:_FeedBundledRowsLazy(name, cols, function() return {rows} end)`. The thunk's body isn't evaluated until the consumer queries the module. **All chunks for a module materialize together** the first time any of these is called:

- `:Get(key)` (only after the materialized + indexed paths miss)
- `:Search(query, opts)` (needs to scan every row)
- `:All()`, `:AllArray()`, `:AllRaw()` (full iteration)
- `:Add(entry)` (needs to merge against bundled data)
- `:Count()` (needs accurate count)
- `:ExpandAll()` (explicit drain)

**Row-level lazy expansion.** After a chunk materializes, individual rows live as positional arrays in `_rowIndex` keyed by id. They expand into entry dicts only when `:Get(id)` is called or when `:Search` finds a match (and even then, only matched rows expand).

A consumer addon that only touches a few modules (e.g. `LC:Quests()` and `LC:Items():Get(...)` for one specific item) pays:

- The string interning cost of the constants pool for every Data file (unavoidable; Lua interns strings at parse time)
- Zero per-row table cost for modules never queried
- Zero per-entry dict cost for individual rows never accessed

---

## Adapter API

Adapters are functions of the form `fn(LC)` that push entries into modules. They run once at PLAYER_LOGIN.

```lua
LibCodex:RegisterAdapter("MyAddon-Quests", function(LC)
    for id, e in pairs(MyAddonDB.knownNPCs or {}) do
        LC:NPCs():Add({
            id = id,
            label = e.name,
            sources = { "myaddon" },
        })
    end
end)
```

```lua
LibCodex:RunAdapters()                     -- run every unrun adapter (called from PLAYER_LOGIN)
```

Adapters that fail are caught via `pcall`; the rest still run.

---

## Module registration

```lua
LibCodex:RegisterModule(name, collection)  -- register a new module
LibCodex:GetModule(name)                   -- look up by name
```

Module registration happens at module-file load time. The factory in `Modules/Common.lua` exposes `LibCodex.CollectionFactory.New(name, opts)` to build the collection object. See [README's "Adding a new module"](../README.md#adding-a-new-module) walkthrough for the full pattern.

---

## Internal data-feed APIs

Used by the `Data/*.lua` files emitted by the bake tool. Consumer addons normally don't call these.

```lua
LibCodex:_FeedBundledRows(name, columnsCSV, rows)
   -- eager: register row table immediately
   -- rows = { {val1, val2, ...}, {val1, val2, ...}, ... }

LibCodex:_FeedBundledRowsLazy(name, columnsCSV, thunk)
   -- lazy: register a thunk; only invoked on first :Get/:Search/:All/:Add
   -- thunk = function() return { {val1, val2, ...}, ... } end
   -- THIS IS WHAT THE BAKE TOOL EMITS

LibCodex:_FeedBundled(name, entries)
   -- legacy: verbose Lua-table form
   -- entries = { { id=1, label="...", ... }, ... }

LibCodex:_FeedBundledTSV(name, columnsCSV, blob)
   -- legacy: tab-separated string blob
```

Trailing nils in row arrays are dropped; mid-row nils are written as the literal `nil`. The `sources` column omitted from the row defaults to `{"bundled"}` on expansion.

---

## Lifecycle and SavedVariables

```lua
LibCodex:_RestoreSavedVariables()         -- hydrate LibCodexDB into modules at PLAYER_LOGIN
LibCodex:_PersistSavedVariables()         -- snapshot current state into LibCodexDB at PLAYER_LOGOUT
```

Both are wired automatically when the library loads in a WoW client. Manual calls are useful for forcing a save mid-session (e.g. before a planned crash).

`LibCodexDB` schema:

```lua
LibCodexDB = {
    version = 1,
    modules = {
        NPCs  = { [12345] = { id=12345, label="Boss", ... }, ... },
        Items = { [67890] = { ... }, ... },
        -- one key per registered module
    },
    -- preference flags also live here:
    autoScan = true,
    autoScanInterval = 5,
    logEcho = false,
    dashboardOpen = true,
    dashboardTab = "Browse",
}
```

---

## Diagnostics

```lua
LibCodex:CountAll()                        -- table of name -> count for every module
LibCodex:VersionString()                   -- "LibCodex-1.0 v2605031226 (modules:74 adapters:1)"
```

Useful from the slash command suite or from a consumer addon's startup log.

---

## Slash commands and GUI

The standalone-addon distribution wires `/codex` and `/codex gui`. See [README's slash commands section](../README.md#slash-commands-and-gui) for the full subcommand list. When LibCodex is embedded inside a consumer addon (Pattern B), the slash command remains available but the consumer can choose to override it.
