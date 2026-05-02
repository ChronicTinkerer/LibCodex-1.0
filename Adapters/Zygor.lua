-- LibCodex-1.0 / Adapters / Zygor.lua
-- Imports NPC data from ZygorGuidesViewer (ZGV._NPCData) at PLAYER_LOGIN if
-- ZGV is loaded. Runs once per session; results merge into LibCodex:NPCs()
-- with source = "zygor". Existing entries are augmented, never overwritten.
--
-- Zygor's NPC data is internal to ZGV and may shift with their releases.
-- This parser tolerates absent fields and skips records it can't read.

local LibCodex = LibStub("LibCodex-1.0")

local function isZygorLoaded()
    return type(_G.ZGV) == "table" and type(_G.ZGV._NPCData) == "table"
end

-- ZGV stores entries either as nested tables (newer format) or as
-- pipe-delimited strings (older format). Best-effort to handle both.
local function parseStringRow(row)
    if type(row) ~= "string" then return nil end
    -- Format roughly:  "Name|mapID|x|y|side|...
    -- Numbers may be 0..1 normalized or 0..100; we normalize to 0..1.
    local fields = {}
    for chunk in row:gmatch("[^|]+") do fields[#fields + 1] = chunk end
    if #fields < 4 then return nil end
    local label = fields[1]
    local mapID = tonumber(fields[2])
    local x     = tonumber(fields[3])
    local y     = tonumber(fields[4])
    local side  = fields[5]
    if not (label and mapID and x and y) then return nil end
    if x > 1 then x = x / 100 end
    if y > 1 then y = y / 100 end
    return { label = label, mapID = mapID, x = x, y = y, side = side }
end

local function parseTableRow(row)
    if type(row) ~= "table" then return nil end
    -- Common ZGV table fields: name, m (mapID), x, y, faction
    local label = row.name or row.label
    local mapID = row.m or row.mapID
    local x = row.x
    local y = row.y
    if not (label and mapID and x and y) then return nil end
    if x > 1 then x = x / 100 end
    if y > 1 then y = y / 100 end
    return { label = label, mapID = mapID, x = x, y = y, side = row.faction or row.side }
end

local function importOnce(LC)
    if not isZygorLoaded() then return 0, 0 end
    local NPCs = LC:NPCs()
    if not NPCs then return 0, 0 end

    local imported, skipped = 0, 0
    for key, row in pairs(_G.ZGV._NPCData) do
        local parsed = parseTableRow(row) or parseStringRow(row)
        if parsed then
            -- Convert single-location to the locations array shape.
            NPCs:Add({
                id = (type(key) == "number") and key or nil,
                label = parsed.label,
                locations = {
                    { mapID = parsed.mapID, x = parsed.x, y = parsed.y },
                },
                side = parsed.side,
                sources = { "zygor" },
            })
            imported = imported + 1
        else
            skipped = skipped + 1
        end
    end
    return imported, skipped
end

LibCodex:RegisterAdapter("Zygor", function(LC)
    -- ZGV may load AFTER us. Try at PLAYER_LOGIN; if not present, retry once
    -- a few seconds later, then give up. The adapter is idempotent because
    -- the collection's merge logic coalesces duplicate ids.
    local function attempt()
        if isZygorLoaded() then importOnce(LC) end
    end
    attempt()
    if C_Timer and C_Timer.After then
        C_Timer.After(2.0, attempt)
        C_Timer.After(8.0, attempt)
    end
end)
