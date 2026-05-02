-- LibCodex-1.0 / Adapters / Runtime.lua
-- Captures game data as the player encounters it during normal play. Hooks
-- a handful of cheap, high-yield events:
--   * NAME_PLATE_UNIT_ADDED, UPDATE_MOUSEOVER_UNIT, PLAYER_TARGET_CHANGED
--       -> NPC sightings (id, label, level, classification, side, location)
--   * GET_ITEM_INFO_RECEIVED
--       -> drains the Items module's pending-load queue when async loads finish
--   * BAG_UPDATE_DELAYED
--       -> walks the player's bags and registers every itemID seen
--   * AUTO_COMPLETE_ACCOUNT_LIST_UPDATED (and PLAYER_LOGIN once)
--       -> registers connected realms via GetAutoCompleteRealms()

local LibCodex = LibStub("LibCodex-1.0")
LibCodex.Runtime = LibCodex.Runtime or {}
local R = LibCodex.Runtime

-- Verbose mode: when on, each capture gets a line in LibCodex.Log.
-- Toggle with LibCodex.Runtime.SetVerbose(true/false) or "/codex verbose on".
R.verbose = false
local function vlog(msg)
    if R.verbose and LibCodex.Log and LibCodex.Log.Print then
        LibCodex.Log.Print("|cff66ddff[CodexRT]|r " .. tostring(msg))
    end
end
function R.SetVerbose(on)
    R.verbose = on and true or false
    return R.verbose
end

-- ----------------------------------------------------------------------------
-- Quest log scan. QUEST_LOG_UPDATE fires very often (every objective tick),
-- so we throttle and only walk the player's currently-active quests, refreshing
-- their entry via Quests:AddFromAPI. Title arrives this way for quests that
-- weren't in the player's log when they accepted (e.g. relogged with quests).
-- ----------------------------------------------------------------------------

local questLogScanTs = 0  -- updated by the QUEST_LOG_UPDATE handler

-- Walk the open taxi map and record one entry per visible flight node.
-- Position comes back already normalized 0..1 on the current map. We tag
-- each node with the player's faction so a later bake can split A/H trees.
local function scanTaxiMap(LC)
    local FP = LC:FlightPoints()
    if not (FP and FP.AddFromTaxiAPI and NumTaxiNodes) then return end
    local n = NumTaxiNodes() or 0
    if n <= 0 then return end
    local mapID
    if C_Map and C_Map.GetBestMapForUnit then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    local side
    if UnitFactionGroup then
        local fg = UnitFactionGroup("player")
        if fg == "Alliance" then side = "A"
        elseif fg == "Horde" then side = "H" end
    end
    local recorded = 0
    for i = 1, n do
        if FP:AddFromTaxiAPI(i, mapID, side) then
            recorded = recorded + 1
        end
    end
    if recorded > 0 then
        vlog(string.format("Taxi-map scan recorded %d nodes (mapID=%s side=%s)",
            recorded, tostring(mapID), tostring(side)))
    end
end

local function scanActiveQuestLog(LC)
    local Quests = LC:Quests()
    if not (Quests and C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
    local n = C_QuestLog.GetNumQuestLogEntries()
    if not n or n <= 0 then return end
    local refreshed = 0
    for i = 1, n do
        local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
        if info and info.questID and not info.isHeader then
            Quests:AddFromAPI(info.questID, {
                -- info.difficultyLevel mirrors GetQuestDifficultyLevel.
                -- info.frequency: 1=normal, 2=daily, 3=weekly. We translate
                -- frequency into our `type` token.
                side = nil,  -- not exposed via the log API
            })
            refreshed = refreshed + 1
        end
    end
    if refreshed > 0 then
        vlog(string.format("Quest-log scan refreshed %d entries", refreshed))
    end
end

-- ----------------------------------------------------------------------------
-- NPC capture from a unit token (player target / mouseover / nameplate).
-- Returns the captured npcID (nil if nothing captured).
-- ----------------------------------------------------------------------------

-- Generalized GUID decoder. Returns (kind, id) where kind is:
--   "npc"        for Creature- and Vehicle- GUIDs
--   "gameobject" for GameObject- GUIDs (chests, herbs, ore, mailboxes, etc.)
--   "item"       for Item- GUIDs (rare; mostly tooltip use)
-- Returns (nil, nil) for player GUIDs and anything we don't catalog.
local function entityFromGUID(guid)
    if type(guid) ~= "string" then return nil, nil end
    local kind = guid:match("^([^-]+)")
    if not kind then return nil, nil end
    if kind == "Creature" or kind == "Vehicle" or kind == "Pet" then
        local id = guid:match("^[^-]+-[^-]+-[^-]+-[^-]+-[^-]+-(%d+)-")
        return "npc", tonumber(id)
    elseif kind == "GameObject" then
        local id = guid:match("^[^-]+-[^-]+-[^-]+-[^-]+-[^-]+-(%d+)-")
        return "gameobject", tonumber(id)
    end
    return nil, nil
end

-- Backward-compat alias used by older code paths.
local function npcIDFromGUID(guid)
    local kind, id = entityFromGUID(guid)
    if kind == "npc" then return id end
    return nil
end

local function readUnit(unit)
    if not (UnitExists and UnitExists(unit)) then return nil end
    if UnitIsPlayer and UnitIsPlayer(unit) then return nil end
    local guid = UnitGUID and UnitGUID(unit)
    local kind, id = entityFromGUID(guid or "")
    if not id then return nil end

    -- Dispatch GameObjects (chests, herbs, ore, mailboxes) to their own module.
    if kind == "gameobject" then
        local GO = LibCodex:GameObjects()
        if not GO then return nil end
        local name = UnitName and UnitName(unit) or nil
        local mapID, x, y, zone
        if C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") then
            local pmap = C_Map.GetBestMapForUnit("player")
            mapID = pmap
            local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(pmap, "player")
            if pos then x, y = pos.x, pos.y end
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(pmap)
            if info then zone = info.name end
        end
        GO:Add({ id = id, label = name, sources = { "runtime" } })
        if mapID and x and y then GO:AddLocation(id, mapID, x, y, zone) end
        vlog(string.format("Object %d (%s) from unit '%s'", id, tostring(name), tostring(unit)))
        return id
    end
    -- Otherwise it's an NPC; fall through to existing logic.

    local NPCs = LibCodex:NPCs()
    if not NPCs then return end

    local name        = UnitName and UnitName(unit) or nil
    local level       = UnitLevel and UnitLevel(unit) or nil
    local classif     = UnitClassification and UnitClassification(unit) or nil
    local creatureType = UnitCreatureType and UnitCreatureType(unit) or nil
    local reaction    = UnitReaction and UnitReaction(unit, "player") or nil

    -- Guess side from reaction relative to player faction.
    local side
    if reaction then
        if reaction >= 5 then
            -- Friendly: assume same faction as the player.
            local f = UnitFactionGroup and UnitFactionGroup("player")
            if     f == "Alliance" then side = "A"
            elseif f == "Horde"    then side = "H"
            else side = "B" end
        elseif reaction <= 2 then
            -- Hostile: assume opposite faction.
            local f = UnitFactionGroup and UnitFactionGroup("player")
            if     f == "Alliance" then side = "H"
            elseif f == "Horde"    then side = "A"
            else side = "B" end
        else
            side = "B"
        end
    end

    local mapID, x, y, zone
    if C_Map then
        local pmap = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if pmap then
            mapID = pmap
            local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(pmap, "player")
            if pos then x, y = pos.x, pos.y end
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(pmap)
            if info then zone = info.name end
        end
    end

    NPCs:Add({
        id = id,
        label = name,
        level = level,
        classification = (classif and classif:gsub("^%l", string.upper)) or nil,
        creatureType = creatureType,
        side = side,
        sources = { "runtime" },
    })
    -- Don't record locations for the player's own pet/companion. Pets follow
    -- the player so each scan would otherwise add a fresh location, bloating
    -- the entry and burying real spawn locations.
    local isFollower = (unit == "pet" or unit == "pettarget")
        or (UnitIsUnit and UnitIsUnit(unit, "pet"))
        or (UnitPlayerControlled and UnitPlayerControlled(unit) and not (UnitIsPlayer and UnitIsPlayer(unit)))
    if mapID and x and y and not isFollower then
        NPCs:AddLocation(id, mapID, x, y, zone)
    end
    vlog(string.format("NPC %d (%s) from unit '%s'%s",
        id, tostring(name), tostring(unit), isFollower and " [no-loc: follower]" or ""))
    return id
end

-- ----------------------------------------------------------------------------
-- Bag scan: every itemID currently in the player's bags.
-- ----------------------------------------------------------------------------

-- Scan one bag. Returns (slotsScanned, itemsCaptured).
local function scanBag(bagID)
    if not (C_Container and C_Container.GetContainerNumSlots) then return 0, 0 end
    local slots = C_Container.GetContainerNumSlots(bagID) or 0
    if slots == 0 then return 0, 0 end
    local Items = LibCodex:Items()
    if not Items then return slots, 0 end
    local captured = 0
    for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID then
            Items:AddFromAPI(info.itemID, info.hyperlink)
            captured = captured + 1
            vlog(string.format("Item %d from bag %d slot %d", info.itemID, bagID, slot))
        end
    end
    return slots, captured
end

-- Scan every bag the player has access to. Returns (totalSlots, totalCaptured).
local function scanAllBags()
    local s, c = 0, 0
    for bag = 0, 4 do
        local bs, bc = scanBag(bag)
        s, c = s + bs, c + bc
    end
    return s, c
end

-- ----------------------------------------------------------------------------
-- Connected realms.
-- ----------------------------------------------------------------------------

local function syncConnectedRealms()
    if not GetAutoCompleteRealms then return end
    local Realms = LibCodex:Realms()
    if not Realms then return end
    local list = GetAutoCompleteRealms() or {}
    if #list == 0 then return end

    -- Find the seed realm record (player's current realm).
    local mine = Realms:Current()
    if not mine then return end

    -- Ensure every connected realm has a record; cross-link.
    local idsInCluster = {}
    for _, name in ipairs(list) do
        local existing = Realms:Get(name)
        if existing then
            idsInCluster[#idsInCluster + 1] = existing.id
        else
            -- Create a stub record. Numeric ID unknown; use negative hash so
            -- it doesn't collide with real IDs. The bake tool can rectify later.
            local stubID = -(name:byte(1) * 1000 + name:byte(2) or 0)
            local stub = {
                id = stubID, label = name, fullName = name,
                region = mine.region, locale = mine.locale, type = mine.type,
                connectedTo = {}, online = true,
                sources = { "runtime" },
            }
            Realms:Add(stub)
            idsInCluster[#idsInCluster + 1] = stubID
        end
    end

    -- Cross-link mine and the cluster.
    mine.connectedTo = mine.connectedTo or {}
    local seen = {}
    for _, id in ipairs(mine.connectedTo) do seen[id] = true end
    for _, id in ipairs(idsInCluster) do
        if id ~= mine.id and not seen[id] then
            table.insert(mine.connectedTo, id)
            seen[id] = true
        end
    end
end

-- ----------------------------------------------------------------------------
-- Periodic nameplate sweep. WoW shows a nameplate for every visible NPC
-- (out to ~40 yards, configurable). Iterating C_NamePlate.GetNamePlates()
-- gives us every nearby NPC at once, so we don't have to wait for the
-- player to manually target each one.
-- ----------------------------------------------------------------------------

-- Scan every visible nameplate + boss frames + party NPC pets. Returns count
-- of NPCs successfully captured this pass.
local function scanNameplates()
    local n = 0
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates() or {}
        for _, plate in ipairs(plates) do
            local unit = plate and plate.namePlateUnitToken or plate.UnitFrame and plate.UnitFrame.unit
            if unit and readUnit(unit) then n = n + 1 end
        end
    end
    -- Also boss frames (raid bosses) and known unit tokens that often hold NPCs.
    for _, u in ipairs({ "boss1", "boss2", "boss3", "boss4", "boss5",
                        "target", "mouseover", "focus", "pet", "pettarget" }) do
        if readUnit(u) then n = n + 1 end
    end
    return n
end

-- Periodic ticker, started on demand or by SetAutoScan(true).
local autoTicker
local AUTOSCAN_DEFAULT_INTERVAL = 5

-- ----------------------------------------------------------------------------
-- GameObject capture via tooltip. Game objects (chests, herb nodes, mailboxes,
-- ore veins, lockboxes, doors) are NOT units, so UnitGUID and the nameplate
-- system never see them. The reliable signal is the tooltip: when the player
-- mouses over a game object, the tooltip is shown with the object's name and
-- (in retail 10.0+) its database id via the TooltipDataProcessor.
-- ----------------------------------------------------------------------------

local function captureGameObjectFromTooltip(objectID, name)
    if type(objectID) ~= "number" or objectID == 0 then return end
    local GO = LibCodex:GameObjects()
    if not GO then return end
    local mapID, x, y = currentMapPos()
    local zone
    if mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info then zone = info.name end
    end
    GO:Add({ id = objectID, label = name, sources = { "runtime" } })
    if mapID and x and y then GO:AddLocation(objectID, mapID, x, y, zone) end
    vlog(string.format("Object %d (%s) from tooltip", objectID, tostring(name)))
end

local function installGameObjectTooltipHook()
    -- Modern path: TooltipDataProcessor + Enum.TooltipDataType.GameObject (10.0.2+).
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
       and Enum and Enum.TooltipDataType and Enum.TooltipDataType.GameObject then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.GameObject, function(_, data)
            if not data then return end
            local id = data.id
            local name
            if data.lines and data.lines[1] then name = data.lines[1].leftText end
            captureGameObjectFromTooltip(id, name)
        end)
        return true
    end

    -- Older fallback: hook GameTooltip:OnShow and check for non-unit non-spell tips.
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", function(self)
            if self:GetUnit() then return end           -- units are handled elsewhere
            if self:GetSpell() then return end          -- spells are not game objects
            if self:GetItem() then return end           -- items handled by Items module
            local name = (self.GetText and self:GetText()) or nil
            -- Without TooltipDataProcessor we can't get the object ID; skip silently.
            -- Recording a label-only object isn't useful since we can't dedupe.
            if not name then return end
        end)
        return false
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Loot capture. When LOOT_OPENED fires, walk every loot slot and bidirectionally
-- record (item, source, location) so /codex where <itemID> can answer
-- "where can I get this item?".
-- ----------------------------------------------------------------------------

local function currentMapPos()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local pmap = C_Map.GetBestMapForUnit("player")
    if not pmap then return nil end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(pmap, "player")
    local x, y
    if pos then x, y = pos.x, pos.y end
    return pmap, x, y
end

-- Identify the loot source. WoW exposes UnitGUID("npc") for the NPC body
-- you opened the loot from. For game-object loot (chests etc.), the source
-- is "mouseover" at the time of interaction.
local function identifyLootSource()
    for _, u in ipairs({ "npc", "target", "mouseover" }) do
        if UnitExists and UnitExists(u) then
            local kind, id = entityFromGUID(UnitGUID and UnitGUID(u) or "")
            if kind and id then return kind, id, UnitName and UnitName(u) end
        end
    end
    return nil, nil, nil
end

-- Most recently killed NPC. Used as the loot-source fallback when neither
-- "npc" nor "target" still resolves at LOOT_OPENED time (common with auto-loot
-- + AoE pulls). Captured from PARTY_KILL combat log events.
local lastKilled = { kind = nil, id = nil, label = nil, mapID = nil, x = nil, y = nil, ts = 0 }

local function recordKill(destGUID, destName)
    local kind, id = entityFromGUID(destGUID or "")
    if not (kind and id) then return end
    local m, x, y = currentMapPos()
    lastKilled.kind, lastKilled.id, lastKilled.label = kind, id, destName
    lastKilled.mapID, lastKilled.x, lastKilled.y = m, x, y
    lastKilled.ts = (time and time()) or 0
end

local function captureLoot()
    vlog("LOOT_OPENED fired; reading loot window")
    if not (GetNumLootItems and GetLootSlotLink) then
        vlog("  loot APIs unavailable")
        return 0
    end
    local Items = LibCodex:Items()
    if not Items then return 0 end

    local kind, sourceID, sourceLabel = identifyLootSource()
    -- Fallback: use most recently killed NPC (within last 30 seconds) if the
    -- live unit tokens have already cleared (auto-loot / AoE).
    if not sourceID and lastKilled.id and (((time and time()) or 0) - (lastKilled.ts or 0)) < 30 then
        kind, sourceID, sourceLabel = lastKilled.kind, lastKilled.id, lastKilled.label
        vlog(string.format("  source via lastKilled: %s %d (%s)",
            tostring(kind), sourceID, tostring(sourceLabel)))
    end
    local mapID, x, y = currentMapPos()
    local n = GetNumLootItems() or 0
    vlog(string.format("  loot slots: %d   source: %s/%s (%s)",
        n, tostring(kind), tostring(sourceID), tostring(sourceLabel)))
    local recorded = 0

    -- Make sure the source entry exists (so AddDrop can hang off it).
    if kind == "npc" and LibCodex.modules.NPCs and sourceID then
        LibCodex.modules.NPCs:Add({ id = sourceID, label = sourceLabel, sources = { "runtime" } })
    elseif kind == "gameobject" and LibCodex.modules.GameObjects and sourceID then
        LibCodex.modules.GameObjects:Add({ id = sourceID, label = sourceLabel, sources = { "runtime" } })
        if mapID and x and y then
            LibCodex.modules.GameObjects:AddLocation(sourceID, mapID, x, y, nil)
        end
    end

    for slot = 1, n do
        local link = GetLootSlotLink(slot)
        local itemID
        if link then itemID = tonumber(link:match("item:(%d+)")) end
        if itemID then
            -- Make sure the Items entry exists / is enriched via API.
            Items:AddFromAPI(itemID, link)
            -- Record the reverse pointer.
            Items:AddDropSource(itemID, kind, sourceID, mapID, x, y)
            -- Forward pointer on the NPC/GameObject.
            if kind == "npc" and LibCodex.modules.NPCs then
                LibCodex.modules.NPCs:AddDrop(sourceID, itemID, mapID, x, y)
            elseif kind == "gameobject" and LibCodex.modules.GameObjects then
                LibCodex.modules.GameObjects:AddDrop(sourceID, itemID, mapID, x, y)
            end
            recorded = recorded + 1
            vlog(string.format("Loot: item %d from %s %s (%s)",
                itemID, tostring(kind), tostring(sourceID), tostring(sourceLabel)))
        end
    end
    return recorded
end

-- ----------------------------------------------------------------------------
-- Public API. Callable from anywhere (slash commands, other addons).
-- ----------------------------------------------------------------------------

-- Manually trigger a scan of bags + current target/mouseover/focus + realms.
-- Returns a summary table with counts so callers can report results.
function R.ScanNow()
    local report = {
        bagSlotsSeen      = 0,
        bagItemsCaptured  = 0,
        unitsRead         = {},   -- list of npcIDs captured
        realmsBefore      = 0,
        realmsAfter       = 0,
        cContainerOK      = (C_Container and C_Container.GetContainerNumSlots) and true or false,
        cMapOK            = (C_Map and C_Map.GetBestMapForUnit) and true or false,
    }
    -- Bag scan.
    local s, c = scanAllBags()
    report.bagSlotsSeen     = s
    report.bagItemsCaptured = c
    -- Unit reads (target/mouseover/focus + every visible nameplate + boss frames).
    for _, u in ipairs({ "target", "mouseover", "focus", "pet", "pettarget",
                         "boss1", "boss2", "boss3", "boss4", "boss5" }) do
        local id = readUnit(u)
        if id then table.insert(report.unitsRead, { unit = u, id = id }) end
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = plate and plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit then
                local id = readUnit(unit)
                if id then table.insert(report.unitsRead, { unit = unit, id = id }) end
            end
        end
    end
    -- Realms.
    local Realms = LibCodex:Realms()
    if Realms then report.realmsBefore = Realms:Count() end
    syncConnectedRealms()
    if Realms then report.realmsAfter = Realms:Count() end
    return report
end

-- Expose the inner functions too for advanced callers.
R.ReadUnit        = readUnit
R.ScanBag         = scanBag
R.ScanAllBags     = scanAllBags
R.ScanNameplates  = scanNameplates
R.SyncRealms      = syncConnectedRealms

-- Toggle the periodic nameplate auto-scan. Persists in LibCodexDB.autoScan.
-- interval is in seconds; default 5; minimum 2 (anything tighter pegs the CPU
-- in heavily-populated zones for no real benefit).
function R.SetAutoScan(on, interval)
    interval = math.max(2, tonumber(interval) or AUTOSCAN_DEFAULT_INTERVAL)
    LibCodexDB = LibCodexDB or {}
    LibCodexDB.autoScan = on and true or false
    LibCodexDB.autoScanInterval = interval

    if autoTicker and autoTicker.Cancel then autoTicker:Cancel() end
    autoTicker = nil
    if on and C_Timer and C_Timer.NewTicker then
        autoTicker = C_Timer.NewTicker(interval, function()
            local n = scanNameplates()
            if n > 0 then vlog(string.format("auto-scan: %d nameplate units processed", n)) end
        end)
    end
    return on and true or false
end

function R.IsAutoScanning() return autoTicker ~= nil end

-- Enable WoW's friendly-NPC nameplate CVars so the auto-scan can see vendors,
-- bankers, quest-givers, and other peaceful units that are normally hidden.
-- The CVars are: nameplateShowFriends, nameplateShowFriendlyNPCs,
-- nameplateShowEnemies (already on by default), nameplateShowAll.
-- Returns true if something was actually changed.
function R.EnableFriendlyNameplates()
    if not SetCVar then return false end
    local changed = false
    local function set(name, val)
        if GetCVar and GetCVar(name) ~= tostring(val) then
            SetCVar(name, val)
            changed = true
        end
    end
    set("nameplateShowFriends", 1)
    set("nameplateShowFriendlyNPCs", 1)
    set("nameplateShowFriendlyMinions", 1)
    set("nameplateShowEnemies", 1)
    set("nameplateShowAll", 1)
    return changed
end

-- ----------------------------------------------------------------------------
-- Adapter registration + event frame.
-- ----------------------------------------------------------------------------

LibCodex:RegisterAdapter("Runtime", function(LC)
    if not CreateFrame then return end  -- not in WoW (smoke test)

    local f = CreateFrame("Frame", "LibCodexRuntimeAdapter")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("AUTO_COMPLETE_ACCOUNT_LIST_UPDATED")
    f:RegisterEvent("LOOT_OPENED")
    f:RegisterEvent("LOOT_READY")
    f:RegisterEvent("CHAT_MSG_LOOT")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f:RegisterEvent("QUEST_ACCEPTED")
    f:RegisterEvent("QUEST_TURNED_IN")
    f:RegisterEvent("QUEST_REMOVED")
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("TAXIMAP_OPENED")
    f:SetScript("OnEvent", function(_, evt, arg1, arg2)
        if     evt == "NAME_PLATE_UNIT_ADDED"   then readUnit(arg1)
        elseif evt == "UPDATE_MOUSEOVER_UNIT"   then readUnit("mouseover")
        elseif evt == "PLAYER_TARGET_CHANGED"   then readUnit("target")
        elseif evt == "PLAYER_FOCUS_CHANGED"    then readUnit("focus")
        elseif evt == "GET_ITEM_INFO_RECEIVED"  then
            local Items = LC:Items()
            if Items then Items:_OnItemDataLoaded(arg1, arg2) end
        elseif evt == "BAG_UPDATE_DELAYED"      then scanAllBags()
        elseif evt == "LOOT_OPENED" or evt == "LOOT_READY" then captureLoot()
        elseif evt == "CHAT_MSG_LOOT"           then
            -- arg1 is the message text e.g. "You receive loot: [Linen Cloth]x3."
            -- We grab the itemID from the link and bind it to the most recent
            -- known loot source (last killed mob if recent enough).
            local msg = arg1 or ""
            local itemID = tonumber(msg:match("|Hitem:(%d+):"))
            local Items = LC:Items()
            if itemID and Items then
                Items:AddFromAPI(itemID, msg:match("|Hitem:[^|]+|h%[[^%]]+%]|h"))
                if lastKilled.id and (((time and time()) or 0) - (lastKilled.ts or 0)) < 30 then
                    Items:AddDropSource(itemID, lastKilled.kind, lastKilled.id,
                        lastKilled.mapID, lastKilled.x, lastKilled.y)
                    if lastKilled.kind == "npc" and LibCodex.modules.NPCs then
                        LibCodex.modules.NPCs:AddDrop(lastKilled.id, itemID,
                            lastKilled.mapID, lastKilled.x, lastKilled.y)
                    elseif lastKilled.kind == "gameobject" and LibCodex.modules.GameObjects then
                        LibCodex.modules.GameObjects:AddDrop(lastKilled.id, itemID,
                            lastKilled.mapID, lastKilled.x, lastKilled.y)
                    end
                    vlog(string.format("Chat-loot: item %d -> %s %d", itemID,
                        tostring(lastKilled.kind), lastKilled.id))
                else
                    vlog(string.format("Chat-loot: item %d (no recent kill source)", itemID))
                end
            end
        elseif evt == "COMBAT_LOG_EVENT_UNFILTERED" then
            if CombatLogGetCurrentEventInfo then
                local _, subevent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
                if subevent == "PARTY_KILL" or subevent == "UNIT_DIED" then
                    recordKill(destGUID, destName)
                end
            end
        elseif evt == "AUTO_COMPLETE_ACCOUNT_LIST_UPDATED" then syncConnectedRealms()
        elseif evt == "QUEST_ACCEPTED" then
            -- arg1 is the quest log index in older clients, the questID in
            -- modern ones. Try the modern signature first.
            local Quests = LC:Quests()
            if Quests then
                local questID = arg2 or arg1
                if type(questID) == "number" then
                    -- Pull current map context so the entry records WHERE the
                    -- player picked the quest up.
                    local mapID, x, y
                    if C_Map and C_Map.GetBestMapForUnit then
                        mapID = C_Map.GetBestMapForUnit("player")
                        if mapID and C_Map.GetPlayerMapPosition then
                            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                            if pos then x, y = pos:GetXY() end
                        end
                    end
                    -- Faction context: the active player's side. The quest may
                    -- be flagged Both server-side, but if a Horde player can
                    -- pick it up we can at least confirm it's not Alliance-only.
                    local side
                    if UnitFactionGroup then
                        local fg = UnitFactionGroup("player")
                        if fg == "Alliance" then side = "A"
                        elseif fg == "Horde" then side = "H" end
                    end
                    Quests:AddFromAPI(questID, {
                        mapID = mapID, x = x, y = y, side = side,
                    })
                    vlog(string.format("Quest accepted: %d", questID))
                end
            end
        elseif evt == "QUEST_TURNED_IN" then
            local Quests = LC:Quests()
            if Quests and type(arg1) == "number" then
                Quests:MarkTurnedIn(arg1)
                vlog(string.format("Quest turned in: %d", arg1))
            end
        elseif evt == "QUEST_REMOVED" then
            -- Quiet event; no DB change needed. Logged for diagnostics only.
            if type(arg1) == "number" then
                vlog(string.format("Quest removed: %d", arg1))
            end
        elseif evt == "QUEST_LOG_UPDATE" then
            -- Throttled refresh: walk the active quest log and refresh entries
            -- the API now has fuller info for. Throttle to once per 10s so we
            -- don't thrash on every objective tick.
            local now = (time and time()) or 0
            if (questLogScanTs or 0) + 10 <= now then
                questLogScanTs = now
                scanActiveQuestLog(LC)
            end
        elseif evt == "TAXIMAP_OPENED" then
            -- arg1 is the taxi map UI system: 1 = old flight master,
            -- 2 = modern flight map. The API surface is the same either way.
            scanTaxiMap(LC)
        end
    end)

    -- Initial passes after a short delay so APIs have data ready.
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, function()
            scanAllBags()
            syncConnectedRealms()
            scanNameplates()
        end)
    end

    -- Install tooltip hook for game-object capture (mailboxes, herbs, ore, chests).
    installGameObjectTooltipHook()

    -- Restore persisted auto-scan setting (default: ON if user never set it).
    LibCodexDB = LibCodexDB or {}
    if LibCodexDB.autoScan == nil then LibCodexDB.autoScan = true end
    if LibCodexDB.autoScan then
        R.SetAutoScan(true, LibCodexDB.autoScanInterval)
    end
end)
