--localization file for english/United States
local L = LibStub("AceLocale-3.0"):NewLocale("zQuestMacroButtons", "enUS", true)

L["questCRAWFISHCREOLE"] = "Crawfish Creole"
L["npcCRAWFISHCREOLE"] = "Muddy Crawfish"
L["questOrgHungryThief"] = "Even Thieves Get Hungry"
L["npcOrgHungryThief"] = "Orgrimmar Thief"
L[""] = 
L[""] = 
L[""] = 
L[""] = 
L[""] = 


itemName, _, _, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemID)

itemName, _, _, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemID or "itemString" or "itemName" or "itemLink")

itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
 itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemID or "itemString" or "itemName" or "itemLink")

spellName, _, _, _, _, _, _, _, _ = GetSpellInfo(spellId)

spellName, _, _, _, _, _, _, _, _ = GetSpellInfo(spellId or spellName or spellLink)

spellName, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange 
 = GetSpellInfo(spellId or spellName or spellLink)