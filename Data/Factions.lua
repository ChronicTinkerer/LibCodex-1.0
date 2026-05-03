-- LibCodex-1.0 / Data / Factions.lua
-- Hand-curated. Player factions (A/H/N) only. Reputation factions get
-- merged in from the wago Faction DBC by the bake tool.

local LibCodex = LibStub("LibCodex-1.0")

LibCodex:_FeedBundledRows("Factions",
    "id,label,kind,color,_handcrafted,sources",
    {
        {"A", "Alliance", "player", {r=0.00, g=0.44, b=0.87, hex="0070dd"}, true, {"handcrafted"}},
        {"H", "Horde",    "player", {r=0.77, g=0.12, b=0.23, hex="c41e3a"}, true, {"handcrafted"}},
        {"N", "Neutral",  "player", {r=1.00, g=0.81, b=0.00, hex="ffd000"}, true, {"handcrafted"}},
    }
)
