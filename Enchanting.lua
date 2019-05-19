-----------------------------------------------------------------------------------
-- Library Name: LibLazyCrafting
-- Creator: Dolgubon (Joseph Heinzle)
-- Library Ideal: Allow addons to craft anything, anywhere
-- Library Creation Date: December, 2016
-- Publication Date: Febuary 5, 2017
--
-- File Name: Enchanting.lua
-- File Description: Contains the functions for Enchanting
-- Load Order Requirements: After LibLazyCrafting.lua
-- 
-----------------------------------------------------------------------------------

local LibLazyCrafting = LibStub("LibLazyCrafting")
local sortCraftQueue = LibLazyCrafting.sortCraftQueue

local widgetType = 'enchanting'
local widgetVersion = 1.4
if not LibLazyCrafting:RegisterWidget(widgetType, widgetVersion) then return false end

local function dbug(...)
	if not DolgubonGlobalDebugOutput then return end
	DolgubonGlobalDebugOutput(...)
end

local craftingQueue = LibLazyCrafting.craftingQueue

--------------------------------------
-- ENCHANTING HELPER FUNCTIONS

local function getItemLinkFromItemId(itemId) local name = GetItemLinkName(ZO_LinkHandler_CreateLink("Test Trash", nil, ITEM_LINK_TYPE,itemId, 1, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0)) 
	return ZO_LinkHandler_CreateLink(zo_strformat("<<t:1>>",name), nil, ITEM_LINK_TYPE,itemId, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) end

local function areIdsValid(potency, essence, aspect)
	if GetItemLinkEnchantingRuneClassification( getItemLinkFromItemId(potency)) ~= ENCHANTING_RUNE_POTENCY
		or GetItemLinkEnchantingRuneClassification( getItemLinkFromItemId(aspect)) ~= ENCHANTING_RUNE_ASPECT
		or GetItemLinkEnchantingRuneClassification( getItemLinkFromItemId(essence)) ~= ENCHANTING_RUNE_ESSENCE then

		return false
	else
		return true
	end
end

local function copy(t)
	local a = {}
	for k, v in pairs(t) do
		a[k] = v
	end
	return a
end

-----------------------------------------------------
-- ENCHANTING USER INTERACTION FUNCTIONS

-- Since bag indexes can change, this ignores those. Instead, it takes in the name, or the index (table of indexes is found in table above, and is specific to this library)
-- Bag indexes will be determined at time of crafting	
local function LLC_CraftEnchantingGlyphItemID(self, potencyItemID, essenceItemID, aspectItemID, autocraft, reference)
	dbug('FUNCTION:LLCEnchantCraft')
	if reference == nil then reference = "" end
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	if not potencyItemID or not essenceItemID or not aspectItemID then  return end
	if not areIdsValid(potencyItemID, essenceItemID, aspectItemID) then d("invalid essence Ids") return end
	local requestTable = {
		["potencyItemID"] = potencyItemID,
		["essenceItemID"] = essenceItemID,
		["aspectItemID"] = aspectItemID,
		["timestamp"] = GetTimeStamp(),
		["autocraft"] = autocraft,
		["Requester"] = self.addonName,
		["reference"] = reference,
		["station"] = CRAFTING_TYPE_ENCHANTING,
	}
	table.insert(craftingQueue[self.addonName][CRAFTING_TYPE_ENCHANTING],requestTable)

	--sortCraftQueue()
	if GetCraftingInteractionType()==CRAFTING_TYPE_ENCHANTING then 
		LibLazyCrafting.craftInteract(event, CRAFTING_TYPE_ENCHANTING) 
	end
	return requestTable
end

local function LLC_CraftEnchantingGlyph(self, potencyBagId, potencySlot, essenceBagId, essenceSlot, aspectBagId, aspectSlot, autocraft, reference)
	return LLC_CraftEnchantingGlyphItemID(self, GetItemId(potencyBagId, potencySlot),GetItemId(essenceBagId, essenceSlot),GetItemId(aspectBagId,aspectSlot),autocraft, reference)
end

local function LLC_AddGlyphToExistingGear(self, existingRequestTable, gearBag, gearSlot)
	local requestTable  = existingRequestTable
	if potencyId and essenceId and aspectId then
		existingRequestTable['dualEnchantingSmithing'] = true
		existingRequestTable['equipUniqueId'] = GetItemUniqueId(gearBag, gearSlot)
		existingRequestTable['equipStringUniqueId'] = Id64ToString(existingRequestTable['equipUniqueId'])
		existingRequestTable.equipCreated = true
	elseif potencyId or essenceId or aspectId then
		d("Only partial enchanting traits specified. Aborting craft")
	end

end

local validLevels = 
{
	1,
	5,
	10,
	15,
	20,
	25,
	30,
	35,
	40,
	60,
	80,
	100,
	120,
	150,
	200,
	210,
}

-- Currently not properly implemented
local function LLC_CraftEnchantingGlyphAttributes(self, isCP, level, enchantId, quality, autocraft, reference)
	-- LLC_CraftEnchantingGlyphItemID(self, GetItemId(potencyBagId, potencySlot),GetItemId(essenceBagId, essenceSlot),GetItemId(aspectBagId,aspectSlot),autocraft, reference)
end
------------------------------------------------------------------------
-- ENCHANTING STATION INTERACTION FUNCTIONS

local currentCraftAttempt = 
{
	["essenceItemID"] = 0,
	["aspectItemID"] = 0,
	["potencyItemID"] = 0,
	["timestamp"] = 1234566789012345,
	["autocraft"] = true,
	["Requester"] = "",
	["slot"]  = 0,
	["link"] = "",
	["callback"] = function() end,
	["position"] = 0,

}


local function LLC_EnchantingCraftinteraction(station, earliest, addon , position)
	dbug("FUNCTION:LLCEnchantCraft")
	if not earliest then  LibLazyCrafting.SendCraftEvent( LLC_NO_FURTHER_CRAFT_POSSIBLE,  station) end
	if earliest and not IsPerformingCraftProcess() then
		local locations = 
		{
		select(1,findItemLocationById(earliest["potencyItemID"])),
		select(2,findItemLocationById(earliest["potencyItemID"])),
		select(1,findItemLocationById(earliest["essenceItemID"])),
		select(2,findItemLocationById(earliest["essenceItemID"])),
		findItemLocationById(earliest["aspectItemID"]),
		}
		if locations[1] and locations[5] and locations[3] then
			dbug("CALL:ZOEnchantCraft")
			LibLazyCrafting.isCurrentlyCrafting = {true, "enchanting", earliest["Requester"]}
			CraftEnchantingItem(unpack(locations))
			
			currentCraftAttempt= copy(earliest)
			currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
			currentCraftAttempt.slot = FindFirstEmptySlotInBag(BAG_BACKPACK)
			currentCraftAttempt.link = GetEnchantingResultingItemLink(unpack(locations))
			currentCraftAttempt.position = position
			currentCraftAttempt.timestamp = GetTimeStamp()
			currentCraftAttempt.addon = addon
			if currentCraftAttempt.link=="" then
				-- User doesn't know all the runes. Boooo more work
				currentCraftAttempt.allRunesKnown= false
				currentCraftAttempt.locations = locations
			end

			ENCHANTING.potencySound = SOUNDS["NONE"]
			ENCHANTING.potencyLength = 0
			ENCHANTING.essenceSound = SOUNDS["NONE"]
			ENCHANTING.essenceLength = 0
			ENCHANTING.aspectSound = SOUNDS["NONE"]
			ENCHANTING.aspectLength = 0
			
		end
	end
end

local function searchUniqueId(uniqueItemId)
	for i=0, GetBagSize(BAG_BANK) do
		if GetItemUniqueId(BAG_BANK,i)==itemID  then
			return BAG_BANK, i
		end
	end
	for i=0, GetBagSize(BAG_BACKPACK) do
		if GetItemUniqueId(BAG_BACKPACK,i)==itemID then
			return BAG_BACKPACK,i
		end
	end
	for i=0, GetBagSize(BAG_SUBSCRIBER_BANK) do
		if GetItemUniqueId(BAG_SUBSCRIBER_BANK,i)==itemID  then
			return BAG_SUBSCRIBER_BANK, i
		end
	end
	return nil, itemID
end



local function applyGlyphToItem(requestTable)
	-- local glyphUniqueId = GetItemUniqueId(requestTable.glyphBag, requestTable.glyphSlot)
	-- local equipUniqueId = GetItemUniqueId(requestTable.equipBag, requestTable.equipSlot)
	-- if not glyphUniqueId == requestTable.glyphUniqueId and not equipUniqueId == requestTable.equipUniqueId then
	-- 	d("Enchanting failed. Gear and glyph were moved")
	-- end
	local equipBag , equipSlot = searchUniqueId(requestTable.equipUniqueId)
	local glyphBag, glyphSlot = searchUniqueId(requestTable.glyphUniqueId)
	if not equipBag or not glyphBag then
		if not equipBag then
			d("LibLazyCrafting: Could not find crafted gear")
		end
		if not glyphBag then
			d("LibLazyCrafting: Could not find crafted glyph")
		end
		d("LibLazyCrafting: Aborting enchanting")
		LibLazyCrafting.SendCraftEvent(LLC_ENCHANTMENT_FAILED, 0, requestTable.Requester, requestTable )
		
		return
	end
	EnchantItem(equipBag, equipSlot, glyphBag , glyphSlot)
	-- Set the new gear as new
	LibLazyCrafting:SetItemStatusNew(requestTable.equipSlot)
	LibLazyCrafting.SendCraftEvent(LLC_CRAFT_SUCCESS, 0, requestTable.Requester, requestTable )
end


local function LLC_EnchantingCraftingComplete(event, station, lastCheck)
	if not currentCraftAttempt.allRunesKnown==false then -- User didn't know all the glyphs, so we get the item link *now* since they know all of them
		currentCraftAttempt.link = GetEnchantingResultingItemLink(unpack(currentCraftAttempt.locations))
	end
	dbug("EVENT:CraftComplete")
	if not currentCraftAttempt.addon then return end

	if GetItemLinkName(GetItemLink(BAG_BACKPACK, currentCraftAttempt.slot,0)) == GetItemLinkName(currentCraftAttempt.link)
		and GetItemLinkQuality(GetItemLink(BAG_BACKPACK, currentCraftAttempt.slot,0)) == GetItemLinkQuality(currentCraftAttempt.link)
	then
		-- We found it!
		dbug("ACTION:RemoveQueueItem")
		local removedTable = table.remove(craftingQueue[currentCraftAttempt.addon][CRAFTING_TYPE_ENCHANTING] , currentCraftAttempt.position )
		if removedTable.dualEnchantingSmithing then
			removedTable.glyphBag = BAG_BACKPACK
			removedTable.glyphSlot = currentCraftAttempt.slot
			requestTable['glyphUniqueId'] = GetItemUniqueId(removedTable.glyphBag, removedTable.glyphSlot)
			requestTable['glyphStringUniqueId'] = Id64ToString(requestTable['glyphUniqueId'])
			removedTable.glyphCreated = true
			currentCraftAttempt = {}
			if removedTable.equipCreated then
				applyGlyphToItem(removedTable)
			else
				return
			end
		end
		--sortCraftQueue()
		local resultTable = 
		{
			["bag"] = BAG_BACKPACK,
			["slot"] = currentCraftAttempt.slot,
			['link'] = currentCraftAttempt.link,
			['uniqueId'] = GetItemUniqueId(BAG_BACKPACK, currentCraftAttempt.slot),
			["quantity"] = 1,
			["reference"] = currentCraftAttempt.reference,
		}
		
		LibLazyCrafting.SendCraftEvent( LLC_CRAFT_SUCCESS ,  station, currentCraftAttempt.addon , resultTable )
		currentCraftAttempt = {}

	elseif lastCheck then
		-- give up on finding it.
		currentCraftAttempt = {}
	else
		-- further search
		-- search again later
		if GetCraftingInteractionType()==0 then zo_callLater(function() LLC_EnchantingCraftingComplete(event, station, true) end,100) end
	end


end

LibLazyCrafting.applyGlyphToItem = applyGlyphToItem

local function LLC_EnchantingEndInteraction(event ,station)

	local slot = FindFirstEmptySlotInBag(BAG_BACKPACK)
	zo_callLater(function() d(GetItemLink(1,slot)) end, 3000)
	--currentCraftAttempt = nil

end

local function haveEnoughMats(...)
	local IDs = {...}
	for k, itemId in pairs (IDs) do
		local bag, bank, craft = GetItemLinkStacks(getItemLinkFromItemId(itemId))
		if bag + bank + craft == 0 then -- i.e.if the stack count of all is 0
			return false
		end
	end
	return true
end


LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_ENCHANTING] =
{
	["station"] = CRAFTING_TYPE_ENCHANTING,
	["check"] = function(self, station) return station == self.station end,
	['function'] = LLC_EnchantingCraftinteraction,
	["complete"] = LLC_EnchantingCraftingComplete,
	["endInteraction"] = function(self, station) --[[endInteraction()]] end,
	["isItemCraftable"] = function(self, station, request) 
		if station == CRAFTING_TYPE_ENCHANTING and haveEnoughMats(request.potencyItemID, request.essenceItemID, request.aspectItemID) then 
			return true else return false 
		end 
	end,
}

LibLazyCrafting.functionTable.CraftEnchantingItemId = LLC_CraftEnchantingGlyphItemID
LibLazyCrafting.functionTable.CraftEnchantingGlyph = LLC_CraftEnchantingGlyph
LibLazyCrafting.functionTable.CraftEnchantingItem = LLC_CraftEnchantingGlyph

--- testers:
-- /script LLC_Global:CraftEnchantingItemId(45830, 45838, 45851)

