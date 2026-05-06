-- LibCodex-1.0 / Data / Stats.lua
-- Hand-curated. Wago doesn't publish a Stat DBC; this list mirrors the
-- ITEM_MOD_* tokens GetItemStats() returns, plus their human-friendly names.
-- IDs are assigned by us for ordering — they are not Blizzard IDs.

local LibCodex = LibStub("LibCodex-1.0")

LibCodex:_FeedBundledRows("Stats",
    "id,label,token,kind,_handcrafted,sources",
    {
        -- Primary stats (one per spec; gear pieces normally show one).
        {1, "Strength",          "ITEM_MOD_STRENGTH_SHORT",         "primary",   true, {"handcrafted"}},
        {2, "Agility",           "ITEM_MOD_AGILITY_SHORT",          "primary",   true, {"handcrafted"}},
        {3, "Intellect",         "ITEM_MOD_INTELLECT_SHORT",        "primary",   true, {"handcrafted"}},
        {4, "Stamina",           "ITEM_MOD_STAMINA_SHORT",          "primary",   true, {"handcrafted"}},

        -- Secondary stats (every spec uses these; ratings on gear).
        {10, "Critical Strike",   "ITEM_MOD_CRIT_RATING_SHORT",      "secondary", true, {"handcrafted"}},
        {11, "Haste",             "ITEM_MOD_HASTE_RATING_SHORT",     "secondary", true, {"handcrafted"}},
        {12, "Mastery",           "ITEM_MOD_MASTERY_RATING_SHORT",   "secondary", true, {"handcrafted"}},
        {13, "Versatility",       "ITEM_MOD_VERSATILITY",            "secondary", true, {"handcrafted"}},

        -- Tertiary stats (rare procs on gear).
        {20, "Leech",             "ITEM_MOD_CR_LIFESTEAL_SHORT",     "tertiary",  true, {"handcrafted"}},
        {21, "Avoidance",         "ITEM_MOD_CR_AVOIDANCE_SHORT",     "tertiary",  true, {"handcrafted"}},
        {22, "Speed",             "ITEM_MOD_CR_SPEED_SHORT",         "tertiary",  true, {"handcrafted"}},
        {23, "Indestructible",    "ITEM_MOD_CR_STURDINESS_SHORT",    "tertiary",  true, {"handcrafted"}},

        -- Defensive (tank-relevant).
        {30, "Armor",             "ITEM_MOD_ARMOR",                  "defensive", true, {"handcrafted"}},
        {31, "Dodge",             "ITEM_MOD_DODGE_RATING",           "defensive", true, {"handcrafted"}},
        {32, "Parry",             "ITEM_MOD_PARRY_RATING",           "defensive", true, {"handcrafted"}},
    }
)
