-- LibCodex-1.0 / Modules / Catalog / TransmogIllusions.lua
-- Weapon enchant illusions for transmog: Wreath of Saronite, Frostbrand,
-- the elemental weapon glows. Each entry references a SpellItemEnchantment
-- for the actual visual effect.
--
-- Schema:
--   id              TransmogIllusionID
--   enchantID       SpellItemEnchantmentID (-> Enchants module for label/icon)
--   unlockCondition ItemModifiedAppearance / playerCondition required to use
--   transmogCost    gold cost when applied
--   flags           raw TransmogIllusion.Flags
--   sources         provenance tags

local LibCodex = LibStub("LibCodex-1.0")
local TransmogIllusions = LibCodex.CollectionFactory.New("TransmogIllusions", {
    keyField = "id",
    searchFields = { "label" },
})

-- Resolve label from the underlying enchant entry. Cached on the entry.
function TransmogIllusions:GetLabel(illusionID)
    local e = self:Get(illusionID)
    if not e then return nil end
    if e.label then return e.label end
    if e.enchantID and LibCodex.modules.Enchants then
        local en = LibCodex.modules.Enchants:Get(e.enchantID)
        if en and en.label then
            e.label = en.label
            return e.label
        end
    end
    return nil
end

LibCodex:RegisterModule("TransmogIllusions", TransmogIllusions)
