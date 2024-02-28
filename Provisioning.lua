-----------------------------------------------------------------------------------
-- Library Name: LibLazyCrafting
-- Creator: Dolgubon (Joseph Heinzle)
-- File Creator: ziggr
-- Library Ideal: Allow addons to craft anything, anywhere
-- Library Creation Date: December, 2016
-- Publication Date: Febuary 5, 2017
--
-- File Name: Provisioning.lua
-- File Description: Contains the functions for Provisioning AND furniture, as they use the same functions
-- Load Order Requirements: After LibLazyCrafting.lua
--
-----------------------------------------------------------------------------------


--Don't fail silently?

local LibLazyCrafting = _G["LibLazyCrafting"]
local sortCraftQueue = LibLazyCrafting.sortCraftQueue

local widgetType = 'provisioning'
local widgetVersion = 1.9
if not LibLazyCrafting:RegisterWidget(widgetType, widgetVersion) then return false end

local currentCraftAttempt

local function dbug(...)
	if not DolgubonGlobalDebugOutput then return end
	DolgubonGlobalDebugOutput(...)
end

local craftingQueue = LibLazyCrafting.craftingQueue

local function getItemLinkFromItemId(itemId) local name = GetItemLinkName(ZO_LinkHandler_CreateLink("Test Trash", nil, ITEM_LINK_TYPE,itemId, 1, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0))
	return ZO_LinkHandler_CreateLink(zo_strformat("<<t:1>>",name), nil, ITEM_LINK_TYPE,itemId, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
end

local function toRecipeLink(recipeId)
	return string.format("|H1:item:%s:3:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", tostring(recipeId))
end

local function LLC_CraftProvisioningItemByRecipeIndex(self, recipeListIndex, recipeIndex, timesToMake, autocraft, reference)
	dbug('FUNCTION:LLCCraftProvisioningByIndex')
	if reference == nil then reference = "" end
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	local _,_,_,_,_,_,station = GetRecipeInfo(recipeListIndex, recipeIndex)
	if not (recipeListIndex and recipeIndex and station) then 
		d("LibLazyCrafting: recipeListIndex:"..recipeListIndex.." and recipeIndex:"..recipeIndex.." does not seem to refer to a valid recipe")
		return 
	end
	local resultLink = GetRecipeResultItemLink(recipeListIndex, recipeIndex)
	local request = 
	{
		["recipeId"] = nil,
		["recipeListIndex"] = recipeListIndex,
		["recipeIndex"] = recipeIndex,
		["resultLink"] = GetRecipeResultItemLink(recipeListIndex, recipeIndex), 
		["timestamp"] = GetTimeStamp(),
		["autocraft"] = autocraft,
		["Requester"] = self.addonName,
		["reference"] = reference,
		["station"] = station,
		["timesToMake"] = timesToMake or 1
	}
	table.insert(craftingQueue[self.addonName][station], request)
	LibLazyCrafting.AddHomeMarker(nil, station)
	--sortCraftQueue()
	if GetCraftingInteractionType()==station then
		LibLazyCrafting.craftInteract(event, station)
	end
	return request
end

local function LLC_CraftProvisioningItemByRecipeId(self, recipeId, timesToMake, autocraft, reference)
	dbug('FUNCTION:LLCCraftProvisioningById')
	if reference == nil then reference = "" end
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	if not recipeId then return end

	-- ZOS API prefers recipeListIndex + recipeIndex, not recipeId or recipeLink.
	-- Translate now, fail silently if we cannot.
	local recipeLink = toRecipeLink(recipeId)
	local recipeListIndex, recipeIndex = GetItemLinkGrantedRecipeIndices(recipeLink)
	local request = LLC_CraftProvisioningItemByRecipeIndex(self, recipeListIndex, recipeIndex, timesToMake, autocraft, reference)
	request.recipeId = recipeId
	return request
end

local function CraftProvisioningItemByResultItemId(self, resultItemId, timesToMake, autocraft, reference)
	dbug('FUNCTION:LLCCraftProvisioningById')
	if reference == nil then reference = "" end
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	if not resultItemId then return end

	-- ZOS API prefers recipeListIndex + recipeIndex, not recipeId or recipeLink.
	-- Translate now, fail silently if we cannot.
	local station, recipeListIndex, recipeIndex = GetRecipeInfoFromItemId(resultItemId)
	local request = LLC_CraftProvisioningItemByRecipeIndex(self, recipeListIndex, recipeIndex, timesToMake, autocraft, reference)
	request.resultId = resultItemId
	return request
end

local function LLC_ProvisioningCraftInteraction(station, earliest, addon , position)
	dbug("FUNCTION:LLCProvisioningCraft")
	if not earliest then LibLazyCrafting.SendCraftEvent( LLC_NO_FURTHER_CRAFT_POSSIBLE,  station) return end
	if IsPerformingCraftProcess()  then return end

	dbug("CALL:ZOProvisioningCraft")
	local recipeArgs = { earliest.recipeListIndex, earliest.recipeIndex, 1}--earliest.timesToMake }
	LibLazyCrafting.isCurrentlyCrafting = {true, "provisioning", earliest["Requester"]}
	CraftProvisionerItem(unpack(recipeArgs))

	currentCraftAttempt = LibLazyCrafting.tableShallowCopy(earliest)
	currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
	currentCraftAttempt.slot = nil
	currentCraftAttempt.link = GetRecipeResultItemLink(unpack(recipeArgs))
	currentCraftAttempt.position = position
	currentCraftAttempt.timestamp = GetTimeStamp()
	currentCraftAttempt.addon = addon
	currentCraftAttempt.prevSlots = LibLazyCrafting.backpackInventory()
	currentCraftAttempt.recipeListIndex = earliest.recipeListIndex
	currentCraftAttempt.recipeIndex = earliest.recipeIndex
	LibLazyCrafting.recipeCurrentCraftAttempt = currentCraftAttempt
	-- If we're on the glyph creation stage and these aren't set, then you get a Lua error
	if station == CRAFTING_TYPE_ENCHANTING then
		ENCHANTING.potencySound = SOUNDS["NONE"]
		ENCHANTING.potencyLength = 0
		ENCHANTING.essenceSound = SOUNDS["NONE"]
		ENCHANTING.essenceLength = 0
		ENCHANTING.aspectSound = SOUNDS["NONE"]
		ENCHANTING.aspectLength = 0
	end
end

local function LLC_ProvisioningCraftingComplete(station, lastCheck)
	LibLazyCrafting.stackableCraftingComplete(station, lastCheck, CRAFTING_TYPE_PROVISIONING, currentCraftAttempt)
	LibLazyCrafting.recipeCurrentCraftAttempt = nil
end

local function LLC_ProvisioningIsItemCraftable(self, station, request)
	if station ~= request.station then return false end

	local materialList  = {}
	if not request.recipeListIndex or not request.recipeIndex then return nil end
	local rli = request.recipeListIndex  -- for less typing
	local ri = request.recipeIndex
	local recipeInfo = { GetRecipeInfo(rli, ri) }
	local ingrCt = recipeInfo[3]
	for ingrIndex = 1,ingrCt do
		local _, _, ingrReqCt = GetRecipeIngredientItemInfo(request.recipeListIndex, request.recipeIndex, ingrIndex)
		local ingrLink = GetRecipeIngredientItemLink(rli, ri, ingrIndex, LINK_STYLE_DEFAULT)
		if ingrReqCt
			and (0 < ingrReqCt)
			and  ingrLink
			and (ingrLink ~= "") then
			local mat = { itemLink   = ingrLink
						, requiredCt = ingrReqCt * request.timesToMake
						}
			table.insert(materialList, mat)
		end
	end
	return LibLazyCrafting.HaveMaterials(materialList)
end

local function CompileProvisioningRequirements(request)
	local requirements = {}
	local _,_,numIngredients = GetRecipeInfo(request.recipeListIndex, request.recipeIndex)
	for i = 1, numIngredients do
		local id = GetItemLinkItemId(GetRecipeIngredientItemLink(request.recipeListIndex, request.recipeIndex, i))
		if id and id~=0 then
			requirements[id] = GetRecipeIngredientRequiredQuantity(request.recipeListIndex, request.recipeIndex, i) * request.timesToMake
		end
	end
	return requirements
end



LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_PROVISIONING] =
{
	["station"] = CRAFTING_TYPE_PROVISIONING,
	["check"] = function(self, station) return station == self.station end,
	['function'] = LLC_ProvisioningCraftInteraction,
	["complete"] = LLC_ProvisioningCraftingComplete,
	["endInteraction"] = function(station) --[[endInteraction()]] end,
	["isItemCraftable"] = LLC_ProvisioningIsItemCraftable,
	["materialRequirements"] = function(self, request) return CompileProvisioningRequirements(request) end,
}

LibLazyCrafting.functionTable.CraftProvisioningItemByRecipeId 		= LLC_CraftProvisioningItemByRecipeId
LibLazyCrafting.functionTable.CraftFurnishingItemByRecipeItemId		= LLC_CraftProvisioningItemByRecipeId

LibLazyCrafting.functionTable.CraftProvisioningItemByResultItemId	= CraftProvisioningItemByResultItemId
LibLazyCrafting.functionTable.CraftFurnishingItemByResultItemId		= CraftProvisioningItemByResultItemId

LibLazyCrafting.functionTable.CraftProvisioningItemByRecipeIndex	= LLC_CraftProvisioningItemByRecipeIndex
LibLazyCrafting.functionTable.CraftProvisioningItem					= LLC_CraftProvisioningItemByRecipeIndex
LibLazyCrafting.functionTable.CraftFurnishingItemByRecipeIndex		= LLC_CraftProvisioningItemByRecipeIndex


-- CraftProvisionerItem = function(...)d(...)d("----")end
-- /script CraftProvisionerItem(22, 30, 1)
-- /script LLC_Global:CraftProvisioningItemByRecipeIndex(22, 30, 1)
-- /script local o = CraftProvisionerItem CraftProvisionerItem = function(...)d(...)d("----") o(...)end