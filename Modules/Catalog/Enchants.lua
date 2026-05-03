-- LibCodex-1.0 / Modules / Catalog / Enchants.lua
-- SpellItemEnchantment catalog. Covers permanent enchants on weapons, armor,
-- rings, etc., plus temporary ones like sharpening stones and oils. The
-- backing record drives the "Enchanted: <name>" line in item tooltips.
--
-- Schema:
--   id              SpellItemEnchantmentID (matches ItemEnchant ids in tooltips)
--   label           Name_lang (player-facing enchant name)
--   hordeLabel      HordeName_lang (Horde-side variant when names diverge)
--   icon            IconFileDataID
--   duration        seconds; 0 = permanent
--   itemLevelMin    minimum item level the enchant can apply to
--   itemLevelMax    maximum item level the enchant can apply to
--   flags           raw SpellItemEnchantment.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local Enchants = LibCodex.CollectionFactory.New("Enchants", {
    keyField = "id",
    searchFields = { "label", "hordeLabel" },
})

LibCodex:RegisterModule("Enchants", Enchants)
