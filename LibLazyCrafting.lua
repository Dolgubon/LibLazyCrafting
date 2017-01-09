--[[
Author: Dolgubon
Filename: LibLazyCrafting.lua
Version: 0.1

This is a work in progress.
]]--

-- Initialize libraries
local libLoaded
local LIB_NAME, VERSION = "LibLazyCrafting", 0.1
local LibLazyCrafting, oldminor = LibStub:NewLibrary(LIB_NAME, VERSION)
if not LibLazyCrafting then return end

-- test test test test
-- First is the name of the set. Second is the name of the equipment. Third is the number of required traits.
-- This is pretty much arbitrary, sorted by when the set was introduced, and how many traits are needed.
local SetIndexes =
{
	[0]  = {"No Set"						,"No Set"					,0},
	[1]  = {"Death's Wind"					,"Death's Wind"				,2},
	[2]  = {"Night's Silence"				,"Night's Silence"			,2},
	[3]  = {"Ashen Grip"					,"Ashen Grip"				,2},
	[4]  = {"Torug's Pact"					,"Torug's Pact"				,3},
	[5]  = {"Twilight's Embrace"			,"Twilight's Embrace"		,3},
	[6]  = {"Armour of the Seducer"			,"Seducer"					,3},
	[7]  = {"Magnus' Gift"					,"Magnus'"					,4},
	[8]  = {"Hist Bark"						,"Hist Bark"				,4},
	[9]  = {"Whitestrake's Retribution"		,"Whitestrake's"			,4},
	[10] = {"Vampire's Kiss"				,"Vampire's Kiss"			,5},
	[11] = {"Song of the Lamae"				,"Song of the Lamae"		,5},
	[12] = {"Alessia's Bulwark"				,"Alessia's Bulwark"		,5},
	[13] = {"Night Mother's Gaze"			,"Night Mother"				,6},
	[14] = {"Willow's Path"					,"Willow's Path"			,6},
	[15] = {"Hunding's Rage"				,"Hunding's Rage"			,6},
	[16] = {"Kagrenac's Hope"				,"Kagrenac's Hope"			,8},
	[17] = {"Orgnum's Scales"				,"Orgnum's Scales"			,8},
	[18] = {"Eyes of Mara"					,"Eyes of Mara"				,8},
	[19] = {"Shalidor's Curse"				,"Shalidor's Curse"			,8},
	[20] = {"Oblivion's Foe"				,"Oblivion's Foe"			,8},
	[21] = {"Spectre's Eye"					,"Spectre's Eye"			,8},
	[22] = {"Way of the Arena"				,"Arena"					,8},
	[23] = {"Twice-Born Star"				,"Twice Born Star"			,9},
	[24] = {"Noble's Conquest"				,"Noble's Conquest"			,5},
	[25] = {"Redistributor"					,"Redistributor"			,7},
	[26] = {"Armour Master"					,"Armor Master"				,9},
	[27] = {"Trial by Fire"					,"Trials"					,3},
	[28] = {"Law of Julianos"				,"Julianos"					,6},
	[29] = {"Morkudlin"						,"Morkudlin"				,9},
	[30] = {"Tava's Favour"					,"Tava's Favor"				,5},
	[31] = {"Clever Alchemist"				,"Clever Alchemist"			,7},
	[32] = {"Eternal Hunt"					,"Eternal Hunt"				,9},
	[33] = {"Kvatch Gladiator"				,"Gladiator's"				,5},
	[34] = {"Varen's Legacy"				,"Varen's Legacy"			,7},
	[35] = {"Pelinal's Aptitude"			,"Pelinal's"				,9},

}

-- Index starts at 0 because that's how many upgrades are needed.
local qualityIndexes = 
{
	[0] = "White",
	[1] = "Green",
	[2] = "Blue",
	[3] = "Epic",
	[4] = "Gold",
}


local craftResultFunctions = 
{

}
--GetItemLinkSetInfo(string itemLink, boolean equipped)
--GetItemLinkInfo(string itemLink)
--GetItemId(number bagId, number slotIndex)
--|H1:item:72129:369:50:26845:370:50:0:0:0:0:0:0:0:0:0:15:1:1:0:17:0|h|h

-- Crafting request Queue. Split by stations. Not sure how to handle multiple stations for furniture.
local craftingQueue = 
{
	[CRAFTING_TYPE_WOODWORKING] = {},
	[CRAFTING_TYPE_BLACKSMITHING] = {},
	[CRAFTING_TYPE_CLOTHIER] = {},
	[CRAFTING_TYPE_ENCHANTING] = {},
	[CRAFTING_TYPE_ALCHEMY] = {},
	[CRAFTING_TYPE_PROVISIONING] = {},
}

--NOTE: Templates are just for reference
--Template for a craft request. Changes into an improvement request after crafting if quality>0


--Template for an improvement request
local ImprovementRequestItem = 
{
	["Requester"] = "", -- ADDON NAME
	["ItemLink"] = "",
	["ItemBagID"] = 0,
	["ItemSlotID"] = 0,
	["ItemUniqueID"] = 0,
	["ItemCreater"] = "",
	["FinalQuality"] = 0,
}

local CraftGlyphRequest = 
{
	["essenceItemID"] = 0,
	["aspectItemID"] = 0,
	["potencyItemID"] = 0,
}

local CraftAlchemyRequest = 
{
	["SolvenItemID"] = 0,
	["Reagents"] = 
	{
		[1] = 0,
		[2] = 0,
		[3] = 0,
	}
}

local ProvisioningRequest = 
{
	["RecipeID"] = 0,
}

-- This is filled out after crafting. It's so we can make sure that:
-- A: The item was crafted and
-- B: The unique Item ID so we can know exactly what we made.
local waitingOnSmithingCraftComplete = 
{
	["craftFunction"] = function() end,
	["slotID"] = 0,
	["itemLink"] = "",
	["creater"] = "",
	["finalQuality"] = "",
}

-- Just a random help function; can probably be taken out but I'll leave it in for now
function GetID(itemLink) return string.match(itemLink,"|H%d:item:(%d+)") end

-- Returns SetIndex, Set Full Name, Set Item Name, Traits Required
function GetCurrentSetInteractionIndex()
	local baseSetPatternName
	local currentStation = GetCraftingInteractionType()
	if currentStation == CRAFTING_TYPE_BLACKSMITHING then
		baseSetPatternName = GetSmithingPatternInfo(15)
	elseif currentStation == CRAFTING_TYPE_CLOTHIER then
		baseSetPatternName = GetSmithingPatternInfo(16)
	elseif currentStation == CRAFTING_TYPE_WOODWORKING then
		baseSetPatternName = GetSmithingPatternInfo(7)
	else
		return nil , nil, nil, nil
	end
	for i =1, #SetIndexes do
		if string.find(baseSetPatternName, SetIndexes[i][2]) then
			return i, SetIndexes[i][1], SetIndexes[i][2] , SetIndexes[i][3]
		end
	end
	return 0, SetIndexes[0][1], SetIndexes[0][2] , SetIndexes[0][3]
end


-- Can an item be crafted here, based on set and station indexes
function canCraftItemHere(station, setIndex)
	if not setIndex then setIndex = 0 end
	if GetCraftingInteractionType()==station then
		if GetCurrentSetInteractionIndex(setIndex)==setIndex or setIndex==0 then
			return true
		end
	end
	return false

end

local CraftSmithingRequestItem = 
{
	["pattern"] =0,
	["style"] = 0,
	["trait"] = 0,
	["materialIndex"] = 0,
	["materialQuantity"] = 0,
	["setIndex"] = 0,
	["quality"] = 0,
	["useUniversalStyleItem"] = false,
}


function canCraftItem(craftRequestTable)
	--CanSmithingStyleBeUsedOnPattern()
	-- Check stylemats
	if GetCurrentSmithingStyleItemCount(craftRequestTable["style"]) >0 then
		-- Check trait mats
		if GetCurrentSmithingTraitItemCount(craftRequestTable["trait"])> 0 or craftRequestTable["trait"]==1 then
			-- Check wood/ingot/cloth mats
			if GetCurrentSmithingMaterialItemCount(craftRequestTable["pattern"],craftRequestTable["materialIndex"])>craftRequestTable["materialQuantity"] then
				-- Check if enough traits are known
				local _,_,_,_,traitsRequired, traitsKnown = GetSmithingPatternInfo(craftRequestTable["pattern"])
				if traitsRequired<= traitsKnown then
					-- Check if the specific trait is known
					if IsSmithingTraitKnownForResult(craftRequestTable["pattern"], craftRequestTable["materialIndex"], craftRequestTable["materialQuantity"],craftRequestTable["style"], craftRequestTable["trait"]) then
						-- Check if the style is known for that piece
						if IsSmithingStyleKnown(craftRequestTable["style"], craftRequestTable["pattern"]) then
							return true
						else
							d("Style Unknown")
						end
						d("Trait unknown")
					end
				else
					d("Not enough traits known")
				end
			else
				d("Not enough materials")
			end
		else
			d("Not enough trait mats")
		end
	else
		d("Not enough style mats")
	end
	return false
	
end

function LibLazyCrafting:Init()

	-- Same as the normal crafting function, with a few extra parameters.
	-- However, doesn't craft it, just adds it to the queue. (TODO: Maybe change this? But do we want auto craft?)
	-- StationOverride 
	-- test: /script LLC_CraftSmithingItem(1, 1, 7, 2, 1, false, 1, 0, 0 )
	-- test: /script LLC_CraftSmithingItem(1, 1, 7, 2, 1, false, 5, 0, 0)

	function LLC_CraftSmithingItem(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, addonName)
		local station
		if not (stationOverride==CRAFTING_TYPE_BLACKSMITHING or stationOverride == CRAFTING_TYPE_WOODWORKING or stationOverride == CRAFTING_TYPE_CLOTHIER) then
			d("Invalid Station")
			return
		end
		--Handle the extra values. If they're nil, assign default values.
		if not quality then setIndex = 0 end
		if not quality then quality = 0 end
		if not stationOverride then 
			if overallStationOverride then
				station = overallStationOverride
			else
				station = GetCraftingInteractionType()
				if station == 0 then
					d("Error: You must be at a crafting station, or specify a station Override")
				end
			end
		else
			station = stationOverride
		end

		-- create smithing request table and add to the queue
		d("Item added")
		craftingQueue[station][#craftingQueue[station] + 1] =
		{
			["Requester"] = addonName,
			["pattern"] =patternIndex,
			["style"] = styleIndex,
			["trait"] = traitIndex,
			["materialIndex"] = materialIndex,
			["materialQuantity"] = materialQuantity,
			["setIndex"] = setIndex,
			["quality"] = quality,
			["useUniversalStyleItem"] = useUniversalStyleItem,
		}

	end

	function LLC_CraftQueue()

		local station = GetCraftingInteractionType()
		if station == 0 then d("You must be at a crafting station") return end
		d(craftingQueue[station][1])
		if canCraftItemHere(station, craftingQueue[station][1]["setIndex"]) and not IsPerformingCraftProcess() then
			local craftThis = craftingQueue[station][1]
			if not craftThis then d("Nothing queued") return end
			if canCraftItem(craftThis) then
				local patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, quality = craftThis["pattern"], craftThis["materialIndex"], craftThis["materialQuantity"], craftThis["style"], craftThis["trait"], craftThis["quality"]
				waitingOnSmithingCraftComplete = {}
				waitingOnSmithingCraftComplete["slotID"] = FindFirstEmptySlotInBag(BAG_BACKPACK)
				waitingOnSmithingCraftComplete["itemLink"] = GetSmithingPatternResultLink(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, 0)
				waitingOnSmithingCraftComplete["craftFunction"] = 
				function()
					CraftSmithingItem(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem)
				end
				waitingOnSmithingCraftComplete["craftFunction"]()
				waitingOnSmithingCraftComplete["creater"] = GetDisplayName()
				waitingOnSmithingCraftComplete["finalQuality"] = quality

				return
			else
				d("User does not have the skill to craft this")
			end

		else
			if IsPerformingCraftProcess() then d("Already Crafting") else d("Item cannot be crafted here") end
		end
	end

	-- We do take the bag and slot index here, because we need to know what to upgrade
	function LLC_ImproveSmithingItem(BagIndex, SlotIndex, newQuality)
	end

	-- Since bag indexes can change, this ignores those. Instead, it takes in the name, or the index (table of indexes is found in table above, and is specific to this library)
	-- Bag indexes will be determined at time of crafting	
	function LLC_CraftEnchantingGlyphByTypes(PotencyNameOrIndex, EssenceNameOrIndex, AspectNameOrIndex)
	end

	function LLC_CraftAlchemyItem(SolventNameOrIndex, IngredientNameOrIndexOne, IngredientNameOrIndexTwo, IngredientNameOrIndexThree)
	end

	function LLC_GetQueue(Station)
	end

	function LLC_RemoveQueueItem(index)
	end

	function LLC_ClearQueue()
	end

	function LLC_GetSmithingResultLink(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, linkstyle, stationOverride, setIndex, quality)
	end

	function LLC_GetSmithingPatternInfo(patternIndex, station, set)
	end

	function LLC_GetSetIndexTable()
		return SetIndexes
	end


	-- Why use this instead of the EVENT_CRAFT_COMPLETE?
	-- Using this will allow the library to tell you how the craft failed, at least for some problems.
	-- Or that the craft was completed.
	-- AddonName is your addon. It will be used as a reference to the function
	-- funct is the function that will be called where:
	-- funct(event, station, LLCResult, extraLLCResultInfo)

	function LLC_DesignateCraftCompleteFunction(AddonName, funct)
		craftResultFunctions[AddonName] = funct
	end
	-- Response codes
	LLC_CRAFT_SUCCESS = 1 -- extra result: Position of item, item link, maybe other stuff?
	LLC_ITEM_TO_IMPROVE_NOT_FOUND = 2 -- extra result: Improvement request table
	LLC_INSUFFICIENT_MATERIALS = 3 -- extra result: what is missing, item identifier
	LLC_INSUFFICIENT_SKILL  = 4 -- extra result: what skills are missing; both if not enough traits, not enough styles, or trait unknown
	

end


-- Called when a crafting station is opened. Should then craft anything needed in the queue
local function CraftInteract(event, station)


end

-- Called when a crafting request is done. If this function is called, it probably means that 
-- the  craft was successful, but let's check anyway.
local function CraftComplete(event, station)
	local LLCResult = nil
	for k, v in pairs(craftResultFunctions) do
		v(event, station, LLCResult)
	end
end


local function OnAddonLoaded()
	if not libLoaded then
		libLoaded = true
		local LibLazyCrafting = LibStub('LibLazyCrafting')
		LibLazyCrafting:Init()
		EVENT_MANAGER:UnregisterForEvent(LIB_NAME, EVENT_ADD_ON_LOADED)
		EVENT_MANAGER:RegisterForEvent(LIB_NAME, EVENT_CRAFTING_STATION_INTERACT,CraftInteract)
		EVENT_MANAGER:RegisterForEvent(LIB_NAME, EVENT_CRAFT_COMPLETED, CraftComplete)
	end
end

EVENT_MANAGER:RegisterForEvent(LIB_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
