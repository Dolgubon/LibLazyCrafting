local LibLazyCrafting = LibStub("LibLazyCrafting")
d("hh")
abcdefg = "123"

-- Since bag indexes can change, this ignores those. Instead, it takes in the name, or the index (table of indexes is found in table above, and is specific to this library)
-- Bag indexes will be determined at time of crafting	
local function LLC_CraftEnchantingGlyphItemID(self, potencyItemID, essenceItemID, aspectItemID, autocraft)
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	if not potencyItemID or not essenceItemID or not aspectItemID then  return end
	table.insert(craftingQueue[self.addonName][CRAFTING_TYPE_ENCHANTING],
	{
		["potencyItemID"] = potencyItemID,
		["essenceItemID"] = essenceItemID,
		["aspectItemID"] = aspectItemID,
		["timestamp"] = GetTimeStamp(),
		["autocraft"] = autocraft,
		["Requester"] = self.addonName,
	}
	)
	sortCraftQueue()
end

local function LLC_CraftEnchantingGlyph(self, potencyBagId, potencySlot, essenceBagId, essenceSlot, aspectBagId, aspectSlot)
	LLC_CraftEnchantingGlyphItemID(self, GetItemId(potencyBagId, potencySlot),GetItemId(essenceBagId, essenceSlot),GetItemId(aspectBagId,aspectSlot))
end


LibLazyCrafting.functionTable.CraftEnchantingItemId = LLC_CraftEnchantingGlyphItemID
LibLazyCrafting.functionTable.CraftEnchantingGlyph = LLC_CraftEnchantingGlyph