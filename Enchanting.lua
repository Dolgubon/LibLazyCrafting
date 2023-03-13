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

local LibLazyCrafting = _G["LibLazyCrafting"]
local sortCraftQueue = LibLazyCrafting.sortCraftQueue

local widgetType = 'enchanting'
local widgetVersion = 1.9
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
local function LLC_CraftEnchantingGlyphItemID(self, potencyItemID, essenceItemID, aspectItemID, autocraft, reference, gearRequestTable, quantity)
	dbug('FUNCTION:LLCEnchantCraft')
	if reference == nil then reference = "" end
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	if not potencyItemID or not essenceItemID or not aspectItemID then d("Missing item Ids") return end
	if not areIdsValid(potencyItemID, essenceItemID, aspectItemID) then d("invalid essence Ids") return end
	local requestTable = gearRequestTable or {}
	if gearRequestTable then
		requestTable['dualEnchantingSmithing'] = true
	end
	requestTable['glyphInfo'] = requestTable.glyphInfo or {}
	requestTable['equipInfo'] = requestTable.equipInfo or {}
	requestTable["potencyItemID"] = potencyItemID
	requestTable["essenceItemID"] = essenceItemID
	requestTable["aspectItemID"] = aspectItemID
	requestTable["timestamp"] = requestTable["timestamp"] or LibLazyCrafting.GetNextQueueOrder()
	requestTable["autocraft"] = autocraft
	requestTable["Requester"] = self.addonName
	requestTable["reference"] = requestTable["reference"] or reference
	requestTable["quantity"] = quantity or 1
	requestTable["initialQuantity"] = quantity or 1
	if requestTable["station"] then
		requestTable["enchantingStation"] = requestTable["station"]
	else
		requestTable["station"] = CRAFTING_TYPE_ENCHANTING
	end

	LibLazyCrafting.AddHomeMarker(nil, CRAFTING_TYPE_ENCHANTING)
	table.insert(craftingQueue[self.addonName][CRAFTING_TYPE_ENCHANTING],requestTable)

	--sortCraftQueue()
	if GetCraftingInteractionType()==CRAFTING_TYPE_ENCHANTING then 
		LibLazyCrafting.craftInteract(event, CRAFTING_TYPE_ENCHANTING) 
	end
	return requestTable
end
--/script LLC_Global:CraftEnchantingItemId(45830, 45838, 45851, true, "Hum", nil, 2)
local function LLC_CraftEnchantingGlyph(self, potencyBagId, potencySlot, essenceBagId, essenceSlot, aspectBagId, aspectSlot, autocraft, reference, gearRequestTable, quantity)
	return LLC_CraftEnchantingGlyphItemID(self, GetItemId(potencyBagId, potencySlot),GetItemId(essenceBagId, essenceSlot),GetItemId(aspectBagId,aspectSlot),autocraft, reference, gearRequestTable, quantity)
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

LibLazyCrafting.functionTable.AddGlyphToExistingGear = LLC_AddGlyphToExistingGear

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

local glyphInfo = {-- negative first, then positive
	-- (-) enchantId, (+) enchantId, (-) glyph itemId, (+) glyph itemId, (-) glyph name, (+) glyph name, rune ItemID
	{29, 17, 43573,26580,"Absorb Health","Health", ITEMTYPE_GLYPH_WEAPON,ITEMTYPE_GLYPH_ARMOR, 45831 },
	{83, 19, 45868,26582,"Absorb Magicka","Magicka", ITEMTYPE_GLYPH_WEAPON, ITEMTYPE_GLYPH_ARMOR, 45832},
	{82, 25, 45867,26588,"Absorb Stamina","Stamina", ITEMTYPE_GLYPH_WEAPON, ITEMTYPE_GLYPH_ARMOR, 45833},
	{84, 18, 45869,26581,"Decrease Health","Health Recovery", ITEMTYPE_GLYPH_WEAPON, ITEMTYPE_GLYPH_JEWELRY, 45834},
	{86, 20, 45870,26583,"Reduce Spell Cost","Magicka Recovery",ITEMTYPE_GLYPH_JEWELRY , ITEMTYPE_GLYPH_JEWELRY, 45835},
	{87, 26, 45871,26589,"Reduce Feat Cost","Stamina Recovery", ITEMTYPE_GLYPH_JEWELRY,ITEMTYPE_GLYPH_JEWELRY , 45836},
	{23, 24, 26586,26587,"Poison Resist","Poison",ITEMTYPE_GLYPH_JEWELRY , ITEMTYPE_GLYPH_WEAPON, 45837},
	{11, 10, 26849,26848,"Flame Resist","Flame",ITEMTYPE_GLYPH_JEWELRY ,ITEMTYPE_GLYPH_WEAPON , 45838},
	{14, 15, 5364,5365,"Frost Resist","Frost",ITEMTYPE_GLYPH_JEWELRY , ITEMTYPE_GLYPH_WEAPON, 45839},
	{31, 6, 43570,26844,"Shock Resist","Shock", ITEMTYPE_GLYPH_JEWELRY, ITEMTYPE_GLYPH_WEAPON, 45840},
	{9, 3, 26847,26841,"Disease Resist","Foulness",ITEMTYPE_GLYPH_JEWELRY , ITEMTYPE_GLYPH_WEAPON, 45841},
	{7, 16, 26845,5366,"Crushing","Hardening",ITEMTYPE_GLYPH_WEAPON ,ITEMTYPE_GLYPH_WEAPON , 45842},
	{28, 4, 26591,54484,"Weakening","Weapon Damage",ITEMTYPE_GLYPH_WEAPON , ITEMTYPE_GLYPH_WEAPON, 45843},
	{91, 90, 45875,45874,"Potion Speed","Potion Boost",ITEMTYPE_GLYPH_JEWELRY ,ITEMTYPE_GLYPH_JEWELRY , 45846},
	{94, 92, 45885,45883,"Decrease Physical Harm","Increase Physical Harm", ITEMTYPE_GLYPH_JEWELRY,ITEMTYPE_GLYPH_JEWELRY , 45847},
	{95, 93, 45886,45884,"Decrease Spell Harm","Increase Magical Harm",ITEMTYPE_GLYPH_JEWELRY ,ITEMTYPE_GLYPH_JEWELRY , 45848},
	{89, 88, 45873,45872,"Shielding","Bashing",ITEMTYPE_GLYPH_JEWELRY ,ITEMTYPE_GLYPH_JEWELRY , 45849},
	{147, 146, 68344,68343,"Prismatic Onslaught","Prismatic Defense", ITEMTYPE_GLYPH_WEAPON, ITEMTYPE_GLYPH_ARMOR, 68342},
	{178, 179, 166046,166047,"Reduce Skill Cost","Prismatic Recovery", ITEMTYPE_GLYPH_JEWELRY, ITEMTYPE_GLYPH_JEWELRY, 166045},
}
LibLazyCrafting.glyphEssenceIdInfo = glyphInfo

local enchantLevelInfo = {
	-- Parity, potencyItemId, quality, pre50 lvl indicator, level, cp
	{-1, 45817,20,5,  lvl=1,cp=nil},
	{1,  45855,20,5,  lvl=1,cp=nil},
	{-1, 45818,20,10, lvl=5,cp=nil},
	{1,  45856,20,10, lvl=5,cp=nil},
	{1,  45857,20,15, lvl=10,cp=nil},
	{-1, 45819,20,15, lvl=10,cp=nil},
	{-1, 45820,20,20, lvl=15,cp=nil},
	{1,  45806,20,20, lvl=15,cp=nil},
	{-1, 45821,20,25, lvl=20,cp=nil},
	{1,  45807,20,25, lvl=20,cp=nil},
	{-1, 45822,20,30, lvl=25,cp=nil},
	{1,  45808,20,30, lvl=25,cp=nil},
	{-1, 45823,20,35, lvl=30,cp=nil},
	{1,  45809,20,35, lvl=30,cp=nil},
	{-1, 45824,20,40, lvl=35,cp=nil,},
	{1,  45810,20,40, lvl=35,cp=nil},
	{-1, 45825,20,45, lvl=40,cp=nil},
	{1,  45811,20,45, lvl=40,cp=nil},
	{1,  45812,125,50,lvl=nil,cp=10},
	{-1, 45826,125,50,lvl=nil,cp=10},
	{-1, 45827,127,50,lvl=nil,cp=30},
	{1,  45813,127,50,lvl=nil,cp=30},
	{1,  45814,129,50,lvl=nil,cp=50},
	{-1, 45828,129,50,lvl=nil,cp=50},
	{-1, 45829,131,50,lvl=nil,cp=70},
	{1,  45815,131,50,lvl=nil,cp=70},
	{1,  45816,272,50,lvl=nil,cp=100},
	{-1, 45830,272,50,lvl=nil,cp=100},
	{-1, 64508,308,50,lvl=nil,cp=150},
	{1,  64509,308,50,lvl=nil,cp=150},
	{1,  68341,366,50,lvl=nil,cp=160},
	{-1, 68340,366,50,lvl=nil,cp=160},
}

LibLazyCrafting.enchantPotencyLevelInfo = enchantLevelInfo

local levelLeaps = { -- internal, so we can take shortcut. Key is level + 50 if it's CP
	{Key=1,lvl=1,cp=nil},
	{Key=5,lvl=5,cp=nil},
	{Key=10,lvl=10,cp=nil},
	{Key=15,lvl=15,cp=nil},
	{Key=20,lvl=20,cp=nil},
	{Key=25,lvl=25,cp=nil},
	{Key=30,lvl=30,cp=nil},
	{Key=35,lvl=35,cp=nil,},
	{Key=40,lvl=40,cp=nil},
	{Key=60,lvl=nil,cp=10},
	{Key=80,lvl=nil,cp=30},
	{Key=100,lvl=nil,cp=50},
	{Key=120,lvl=nil,cp=70},
	{Key=150,lvl=nil,cp=100},
	{Key=200,lvl=nil,cp=150},
	{Key=210,lvl=nil,cp=160},
}

local qualityItemIdInfo = 
{
	45850,
	45851,
	45852,
	45853,
	45854,
}

local cpQualityInfo = {
	[10] = {125, 135, 145, 155, 165},
	[30] = {127, 137, 147, 157, 167},
	[50] = {129, 139, 149, 169, 169},
	[70] = {131, 141, 151, 161, 171},
	[100] = {272, 273, 274, 275, 276 },
	[150] = {308, 309, 310, 311, 312},
	[160] = {366, 367, 368, 369, 370},
}

LibLazyCrafting.enchantCPQualityInfo = cpQualityInfo

local function getQualityInfo(isCP, level, quality)
	if not isCP then
		return 20,  math.floor(level/5) * 5 + 5 + quality
	end

	return cpQualityInfo[level][quality], 50
end

local function closestGlyphLevel(isCP, level)
	if not isCP then
		if level < 5 then return 1 end
		if level > 40 then return 40 end
		return level - level % 5
	else
		local enchantLevels = {160, 150, 100, 70, 50, 30, 10}
		for i = 1, #enchantLevels do
			if level >=enchantLevels[i] then 
				return enchantLevels[i] 
			end
		end
	end
end
LibLazyCrafting.closestGlyphLevel = closestGlyphLevel
LibLazyCrafting.getGlyphInfo = function () return glyphInfo, enchantLevelInfo,qualityItemIdInfo  end


--[[
/script g = SHARED_INVENTORY.bagCache[BAG_VIRTUAL] p =GetEnchantingResultingItemLink
/script for k,v in pairs(g)do s=v.slotIndex a=GetItemLink(5,s)if GetItemLinkEnchantingRuneClassification(a)==2 and GetItemCraftingInfo(5,s)==3 
	then b=p(5,45830,5,s,5,45850)c=p(5,45830,5,s,5,45850)d(GetItemLinkItemId(a).." "..b) end end
	]]
--SHARED_INVENTORY.bagCache[BAG_VIRTUAL]

local function getEnchantingResultItemId(enchantId)
	for i = 1, #glyphInfo do
		if glyphInfo[i][1] == enchantId then
			return glyphInfo[i][3], -1, glyphInfo[i][9]
		elseif glyphInfo[i][2] == enchantId then
			return glyphInfo[i][4], 1, glyphInfo[i][9]
		end
	end
end


local function findNextPotencyByLevel(isCP, level, parity)
	-- first find the level wanted
	local calculatedKey = level
	if isCP then
		calculatedKey = calculatedKey + 50
	end
	local levelToFind
	for i = 1, #levelLeaps do
		if calculatedKey <=levelLeaps[i].Key then
			levelToFind = levelLeaps[i]
			break
		end
	end
	for i = 1, #enchantLevelInfo do
		if enchantLevelInfo[i].lvl == levelToFind.lvl and enchantLevelInfo[i].cp == levelToFind.cp and enchantLevelInfo[i][1] == parity then
			return enchantLevelInfo[i][2]
		end
		-- if not enchantLevelInfo[i+1] then
		-- 	return enchantLevelInfo[i][2]
		-- end
		-- if isCP and enchantLevelInfo[i].cp then
		-- 	if enchantLevelInfo[i+1].cp > level then
		-- 		return enchantLevelInfo[i][2]
		-- 	end
		-- elseif not isCP and enchantLevelInfo[i].lvl then
		-- 	if not enchantLevelInfo[i+1].lvl then
		-- 		return enchantLevelInfo[i][2]
		-- 	end
		-- 	if enchantLevelInfo[i+1].lvl > level then
		-- 		return enchantLevelInfo[i][2]
		-- 	end
		-- end
	end
end

local function getComponentRunesForGlyphItemLink(itemLink)
	local itemId = GetItemLinkItemId(itemLink)
	local level, isCP = GetItemLinkGlyphMinLevels(itemLink)
	local quality =  GetItemLinkFunctionalQuality(itemLink)
	local parity
	local essenceId
	local potencyId
	local aspectId = qualityItemIdInfo[quality]
	--	{83, 19, 45868,26582,"Absorb Magicka","Magicka", ITEMTYPE_GLYPH_WEAPON, ITEMTYPE_GLYPH_ARMOR, 45832},
	for i = 1, #glyphInfo do
		if glyphInfo[i][3] == itemId then
			parity = -1
			essenceId = glyphInfo[i][9]
		elseif glyphInfo[i][4] == itemId then
			parity = 1
			essenceId = glyphInfo[i][9]
		end
	end
		--{1,  45813,127,50,lvl=nil,cp=30},
	for i = 1, #enchantLevelInfo do
		if enchantLevelInfo[i]["lvl"] == level and enchantLevelInfo[i]["cp"] == isCP and parity == enchantLevelInfo[i][1] then
			potencyId = enchantLevelInfo[i][2]
		end
	end
	local response = {
		["essenceItemID"] = essenceId, 
		["aspectItemID"] = aspectId, 
		["potencyItemID"] = potencyId,
	}
	return response
end
LibLazyCrafting.getComponentRunesForGlyphItemLink = getComponentRunesForGlyphItemLink

-- Currently not properly implemented
local function LLC_CraftEnchantingGlyphAttributes(self, isCP, level, enchantId, quality, autocraft, reference, gearRequestTable)
	local _, parity, essenceId = getEnchantingResultItemId(enchantId)
	local potencyId = findNextPotencyByLevel(isCP, level, parity)
	local aspectId = qualityItemIdInfo[quality]
	local a = LLC_CraftEnchantingGlyphItemID(self, potencyId, essenceId, aspectId, autocraft, reference, gearRequestTable, gearRequestTable.smithingQuantity)
	return a
	-- LLC_Global:CraftEnchantingGlyphItemID(self, GetItemId(potencyBagId, potencySlot),GetItemId(essenceBagId, essenceSlot),GetItemId(aspectBagId,aspectSlot),autocraft, reference)
end

LibLazyCrafting.functionTable.CraftEnchantingGlyphByAttributes = LLC_CraftEnchantingGlyphAttributes

local function LLC_EnchantAttributesToGlyphIds(isCP, level, enchantId, quality)
	local _, parity, essenceId = getEnchantingResultItemId(enchantId)
	local potencyId = findNextPotencyByLevel(isCP, level, parity)
	local aspectId = qualityItemIdInfo[quality]
	return potencyId, essenceId, aspectId
end

LibLazyCrafting.functionTable.EnchantAttributesToGlyphIds = LLC_EnchantAttributesToGlyphIds
LibLazyCrafting.EnchantAttributesToGlyphIds = LLC_EnchantAttributesToGlyphIds

function LLC_GetEnchantingResultItemLinkByAttributes(isCP, level, enchantId, quality, autocraft, reference)
	local itemId = getEnchantingResultItemId(enchantId)
	local quality1, quality2 = getQualityInfo(isCP, level, quality)
	return string.format("|H1:item:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId, quality1, quality2) 
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
local lastSlotUsed = nil

local function LLC_EnchantingCraftinteraction(station, earliest, addon, position)
	dbug("FUNCTION:LLCEnchantCraft")
	if not earliest then  LibLazyCrafting.SendCraftEvent( LLC_NO_FURTHER_CRAFT_POSSIBLE,  station) end
	if earliest and not IsPerformingCraftProcess() then
		local locations = 
		{
			select(1,findItemLocationById(earliest["potencyItemID"])),
			select(2,findItemLocationById(earliest["potencyItemID"])),
			select(1,findItemLocationById(earliest["essenceItemID"])),
			select(2,findItemLocationById(earliest["essenceItemID"])),
			select(1,findItemLocationById(earliest["aspectItemID"])),
			select(2,findItemLocationById(earliest["aspectItemID"])),
			earliest["quantity"]
		}
		local max = GetMaxIterationsPossibleForEnchantingItem(unpack(locations))
		local maxCraftable = math.min(earliest["quantity"] or 1, max )
		locations[7] = maxCraftable
		if locations[1]  and locations[3] and locations[5] and maxCraftable>0 then
			dbug("CALL:ZOEnchantCraft")
			LibLazyCrafting.isCurrentlyCrafting = {true, "enchanting", earliest["Requester"]}
			LibLazyCrafting:setWatchingForNewItems(true)
			CraftEnchantingItem(unpack(locations))
			currentCraftAttempt= copy(earliest)
			currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
			currentCraftAttempt.slot = FindFirstEmptySlotInBag(BAG_BACKPACK)
			currentCraftAttempt.link = GetEnchantingResultingItemLink(unpack(locations))
			currentCraftAttempt.position = position
			currentCraftAttempt.timestamp = earliest.timestamp
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

function searchUniqueId(uniqueItemId)
	for i=0, GetBagSize(BAG_BANK) do
		if GetItemUniqueId(BAG_BANK,i)==uniqueItemId  then
			return BAG_BANK, i
		end
	end
	for i=0, GetBagSize(BAG_BACKPACK) do
		if GetItemUniqueId(BAG_BACKPACK,i)==uniqueItemId then
			return BAG_BACKPACK,i
		end
	end
	for i=0, GetBagSize(BAG_SUBSCRIBER_BANK) do
		if GetItemUniqueId(BAG_SUBSCRIBER_BANK,i)==uniqueItemId  then
			return BAG_SUBSCRIBER_BANK, i
		end
	end
	return nil, uniqueItemId
end


local function applyGlyphToItem(requestTable)
	-- local glyphUniqueId = GetItemUniqueId(requestTable.glyphBag, requestTable.glyphSlot)
	-- local equipUniqueId = GetItemUniqueId(requestTable.equipBag, requestTable.equipSlot)
	-- if not glyphUniqueId == requestTable.glyphUniqueId and not equipUniqueId == requestTable.equipUniqueId then
	-- 	d("Enchanting failed. Gear and glyph were moved")
	-- end
	local glyphInfo = requestTable.glyphInfo
	local equipInfo = requestTable.equipInfo
	local numLoops = math.min(#glyphInfo, #equipInfo)
	for i = numLoops,1, -1 do

		local equipBag, equipSlot = searchUniqueId(equipInfo[i].uniqueId)
		local glyphBag, glyphSlot = searchUniqueId(glyphInfo[i].uniqueId)
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
		table.remove(glyphInfo)
		local equipUniqueId = table.remove(equipInfo).uniqueId
		-- Enchanting too many too fast will get you kicked!
		zo_callLater(function()
			EnchantItem(equipBag, equipSlot, glyphBag , glyphSlot)

			
			zo_callLater( function() 
				local _,equipSlot = searchUniqueId(equipUniqueId)
				LibLazyCrafting:SetItemStatusNew(equipSlot) 
			end, 550 )

			LibLazyCrafting.SendCraftEvent(LLC_CRAFT_SUCCESS, 0, requestTable.Requester, requestTable )
		end, (numLoops-i+1)*260
		
		)
		currentCraftAttempt = {}
	end
end

local function wasItemMade(bag, slot)
	return  GetItemLinkName(GetItemLink(BAG_BACKPACK, slot,0)) == GetItemLinkName(currentCraftAttempt.link)
		and GetItemLinkQuality(GetItemLink(BAG_BACKPACK, slot,0)) == GetItemLinkQuality(currentCraftAttempt.link)
end
local function handleEnchantComplete(station, slot)
			-- We found it!
		dbug("ACTION:RemoveQueueItem")
		local removedTable = craftingQueue[currentCraftAttempt.Requester][CRAFTING_TYPE_ENCHANTING][currentCraftAttempt.position]
		if (currentCraftAttempt.quantity or 1) <= 1 then
			removedTable = table.remove(craftingQueue[currentCraftAttempt.Requester][CRAFTING_TYPE_ENCHANTING] , currentCraftAttempt.position )
			removedTable.quantity = removedTable.quantity - 1
			currentCraftAttempt.quantity = currentCraftAttempt.quantity - 1

			LibLazyCrafting.DeleteHomeMarker(nil, CRAFTING_TYPE_ENCHANTING)
		else
			removedTable =  craftingQueue[currentCraftAttempt.Requester][CRAFTING_TYPE_ENCHANTING][currentCraftAttempt.position]
			removedTable.quantity = removedTable.quantity - 1
			currentCraftAttempt.quantity = currentCraftAttempt.quantity - 1
		end
		if removedTable.dualEnchantingSmithing then
			removedTable.glyphInfo= removedTable.glyphInfo or {}
			table.insert(removedTable.glyphInfo,
			{
				bag=BAG_BACKPACK,
				slot=slot,
				uniqueId=GetItemUniqueId(BAG_BACKPACK, slot),
				uniqueIdString = Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot)),
			})
			removedTable.glyphBag = BAG_BACKPACK
			removedTable.glyphSlot = slot
			removedTable['glyphUniqueId'] = GetItemUniqueId(removedTable.glyphBag, removedTable.glyphSlot)
			removedTable['glyphStringUniqueId'] = Id64ToString(removedTable['glyphUniqueId'])
			return removedTable
		end
		--sortCraftQueue()
		local resultTable = 
		{
			["bag"] = BAG_BACKPACK,
			["slot"] = slot,
			['link'] = currentCraftAttempt.link,
			['uniqueId'] = GetItemUniqueId(BAG_BACKPACK, currentCraftAttempt.slot),
			["quantity"] = removedTable.quantity,
			["reference"] = removedTable.reference,
		}
		LibLazyCrafting.SendCraftEvent( LLC_CRAFT_SUCCESS ,  station, removedTable.Requester , resultTable )
		return removedTable
end

local function LLC_EnchantingCraftingComplete(station, lastCheck)
	if currentCraftAttempt.allRunesKnown==false then -- User didn't know all the glyphs, so we get the item link *now* since now they know them
	-- Hopefully they have more than one
		currentCraftAttempt.link = GetEnchantingResultingItemLink(unpack(currentCraftAttempt.locations))
	end
	dbug("EVENT:CraftComplete")
	if not currentCraftAttempt.addon then return end
	local bag, slot = LibLazyCrafting.findNextSlotIndex(wasItemMade)
	local found = false
	local removedTable
	while slot ~= nil do
		removedTable = handleEnchantComplete(station, slot)
		bag, slot = LibLazyCrafting.findNextSlotIndex(wasItemMade, slot+1)
		found = true
	end
	if found then
		if removedTable.equipInfo and #removedTable.equipInfo>0 then
			applyGlyphToItem(removedTable)
			return
		else
			local copiedTable = LibLazyCrafting.tableShallowCopy(removedTable)
			copiedTable.slot = slot
			copiedTable.quantity = 1
			LibLazyCrafting.SendCraftEvent(LLC_INITIAL_CRAFT_SUCCESS, station, removedTable.Requester, copiedTable)
			return
		end
		currentCraftAttempt = {}
		return
	end

	if lastCheck then
		-- give up on finding it.
		currentCraftAttempt = {}
	elseif lastSlotUsed then
		if GetItemLinkName(GetItemLink(BAG_BACKPACK, lastSlotUsed,0)) == GetItemLinkName(currentCraftAttempt.link)
			and GetItemLinkQuality(GetItemLink(BAG_BACKPACK, lastSlotUsed,0)) == GetItemLinkQuality(currentCraftAttempt.link) then
				currentCraftAttempt.slot = lastSlotUsed
				lastSlotUsed = nil
				return LLC_EnchantingCraftingComplete(event, station, lastCheck)
		end
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

local function hasSkillToCraft(...)
	return true
end

local function compileGlyphRequirements(self, requestTable, requirements)
	if not requirements then
		if requestTable.dualEnchantingSmithing then
			requirements = LibLazyCrafting.craftInteractionTables[requestTable.smithingStation]:materialRequirements( requestTable, {})
		else
			requirements = {}
		end
	end
	requirements[requestTable["potencyItemID"]] =1 *requestTable.quantity
	requirements[requestTable["essenceItemID"]] =1 *requestTable.quantity
	requirements[requestTable["aspectItemID"]] =1 *requestTable.quantity
	return requirements
end



LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_ENCHANTING] =
{
	["station"] = CRAFTING_TYPE_ENCHANTING,
	["check"] = function(self, station) return station == self.station end,
	['function'] = LLC_EnchantingCraftinteraction,
	["complete"] = LLC_EnchantingCraftingComplete,
	["endInteraction"] = function(self, station) --[[endInteraction()]] end,
	["isItemCraftable"] = function(self, station, request) 
		if station == CRAFTING_TYPE_ENCHANTING and haveEnoughMats(request.potencyItemID, request.essenceItemID, request.aspectItemID) 
			and hasSkillToCraft(request.potencyItemID, request.essenceItemID, request.aspectItemID) then 
			return true else return false 
		end 
	end,
	["materialRequirements"] = compileGlyphRequirements,
}

LibLazyCrafting.functionTable.CraftEnchantingItemId = LLC_CraftEnchantingGlyphItemID
LibLazyCrafting.functionTable.CraftEnchantingGlyph = LLC_CraftEnchantingGlyph
LibLazyCrafting.functionTable.CraftEnchantingItem = LLC_CraftEnchantingGlyph

--- testers:
-- /script LLC_Global:CraftEnchantingItemId(45830, 45838, 45851)




