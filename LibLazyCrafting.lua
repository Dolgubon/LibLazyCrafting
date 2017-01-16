--[[
Author: Dolgubon
Filename: LibLazyCrafting.lua
Version: 0.1

This is a work in progress.
]]--

------------------
--NOTES
-- Should Legendary upgrading be attempted? Is the risk worth it?
-- How to structure requests, and internal tables
-- What would addon developers want, to be able to interact with the library?

-- Initialize libraries
local libLoaded
local LIB_NAME, VERSION = "LibLazyCrafting", 0.1
local LibLazyCrafting, oldminor = LibStub:NewLibrary(LIB_NAME, VERSION)
if not LibLazyCrafting then return end


-- First is the name of the set. Second is the name of the equipment. Third is the number of required traits.
-- This is pretty much arbitrary, sorted by when the set was introduced, and how many traits are needed.
local SetIndexes ={}

-- Index starts at 0 because that's how many upgrades are needed.
local qualityIndexes = 
{
	[0] = "White",
	[1] = "Green",
	[2] = "Blue",
	[3] = "Epic",
	[4] = "Gold",
}



--GetItemLinkSetInfo(string itemLink, boolean equipped)
--GetItemLinkInfo(string itemLink)
--GetItemId(number bagId, number slotIndex)
--|H1:item:72129:369:50:26845:370:50:0:0:0:0:0:0:0:0:0:15:1:1:0:17:0|h|h

-- Crafting request Queue. Split by addon. Further split by station. Each request has a timestamp for when it was requested.
-- Due to how requests are added, each addon's requests withing station should be sorted by oldest to newest. We'll assume that. (maybe check once in a while)
-- Thus, all that's needed to find the oldest request is cycle through each addon, and check only their first request.
-- Unless a user has hundreds of addons using this library (unlikely) it shouldn't be a big strain. (shouldn't anyway)
-- Not sure how to handle multiple stations for furniture. needs more research for that.
local craftingQueue = 
{
	["GenericTesting"] = {}, -- This is for say, calling from chat.
	["ExampleAddon"] = -- This contains examples of all the crafting requests. It is removed upon initialization. Most values are random/default.
	{
		["craftResultCallback"] = function() --[[ handler - specific to each single addon.]] end,
		[CRAFTING_TYPE_WOODWORKING] = 
		{
			["type"] = "smithing",
			["pattern"] =0,
			["style"] = 0,
			["trait"] = 0,
			["materialIndex"] = 0,
			["materialQuantity"] = 0,
			["setIndex"] = 0,
			["quality"] = 0,
			["useUniversalStyleItem"] = false,
			["timestamp"] = 1111111, 
		},
		[CRAFTING_TYPE_BLACKSMITHING] = 
		{
			["type"] = "improvement",
			["Requester"] = "", -- ADDON NAME
			["ItemLink"] = "",
			["ItemBagID"] = 0,
			["ItemSlotID"] = 0,
			["ItemUniqueID"] = 0,
			["ItemCreater"] = "",
			["FinalQuality"] = 0,
			["timestamp"] = 1112222,
		},
		[CRAFTING_TYPE_ENCHANTING] = 
		{
			["essenceItemID"] = 0,
			["aspectItemID"] = 0,
			["potencyItemID"] = 0,
			["timestamp"] = 12345667,
		},
		[CRAFTING_TYPE_ALCHEMY] = 
		{	
			["SolvenItemID"] = 0,
			["Reagents"] = 
			{
				[1] = 0,
				[2] = 0,
				[3] = 0,
			},
			["timestamp"] = 1234555,
		},
		[CRAFTING_TYPE_PROVISIONING] = 
		{
			["RecipeID"] = 0,
			["timestamp"] = 111111,
		},
	},
}

-- This is filled out after crafting. It's so we can make sure that:
-- A: The item was crafted and
-- B: Find it. Includes itemLink and other stuff just in case it doesn't go to the expected slot (It should)
local waitingOnSmithingCraftComplete = 
{
	["craftFunction"] = function() end,
	["slotID"] = 0,
	["itemLink"] = "",
	["creater"] = "",
	["finalQuality"] = "",
}

-- Just a random help function; can probably be taken out but I'll leave it in for now
-- Pretty helpful function for exploration.
function GetItemIDFromLink(itemLink) return string.match(itemLink,"|H%d:item:(%d+)") end

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


function findItem(itemID)
	for i=0, GetBagSize(BAG_BANK) do
		if GetItemId(BAG_BANK,i)==itemID  then
			return BAG_BANK, i
		end
	end
	for i=0, GetBagSize(BAG_BACKPACK) do
		if GetItemId(BAG_BACKPACK,i)==itemID then
			return BAG_BACKPACK,i
		end
	end
	if GetItemId(BAG_VIRTUAL, itemID) then
		
		return BAG_VIRTUAL, itemID

	end
	return nil, item
end

local function LLC_CraftSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, addonName)
	local station
	if type(self) == "number" then
		d("Please call using colon notation: e.g LLC:CraftSmithingItem()")
	end
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
	self.personalQueue[station][#self.personalQueue[station] + 1] =
	{
		["pattern"] =patternIndex,
		["style"] = styleIndex,
		["trait"] = traitIndex,
		["materialIndex"] = materialIndex,
		["materialQuantity"] = materialQuantity,
		["setIndex"] = setIndex,
		["quality"] = quality,
		["useUniversalStyleItem"] = useUniversalStyleItem,
		["timestamp"] = GetTimeStamp(),
	}

end

function LibLazyCrafting:Init()

	-- Call this to register the addon with the library.
	-- Really this is mostly arbitrary, I just want to force an addon to give me their name ;p. But it's an easy way, and only needs to be done once.
	-- Returns a table with all the functions, as well as the addon's personal queue.
	-- nilable:boolean Autocraft will cause the library to automatically craft anything in the queue when at a crafting station. 
	function LibLazyCrafting:AddRequestingAddon(addonName, autocraft)
		-- Add the 'open functions' here.
		local LLCAddonInteractionTable = {}
		if LLCAddonInteractionTable[addonName] then
			d("LibLazyCrafting:AddRequestingAddon has been called twice, or the chosen addon name has already been used")
		end
		craftingQueue[addonName] = { {}, {}, {}, {}, {}, {},} -- Initialize the addon's personal queue. The tables are empty, station specific queues.

		-- Ensures that any request will have an addon name attached to it, if needed.
		LLCAddonInteractionTable["addonName"] = addonName 
		-- The crafting queue is added. Consider hiding this.
		-- Pro: It hides it, prevents addon people from messing with the queue. More OOP. Don't have to deal with devs messing other addons up
		-- Cons: Prevents them from messing with it. Maybe no scroll menus! It's up to them if they want to manually add something, too.
		-- But can easily add 'if type(timestamp) ~= number then ignore end.' On the other hand, addons can mess with the timestamps, and change priority
		LLCAddonInteractionTable["personalQueue"]  = craftingQueue[addonName]

		LLCAddonInteractionTable["autocraft"] = autocraft
		-- Add all the functions to the interaction table!!
		-- On the other hand, then addon devs can mess up the functions?
		LLCAddonInteractionTable.CraftSmithingItem = LLC_CraftSmithingItem
		


		return LLCAddonInteractionTable
	end

	-- Same as the normal crafting function, with a few extra parameters.
	-- However, doesn't craft it, just adds it to the queue. (TODO: Maybe change this? But do we want auto craft?)
	-- StationOverride 
	-- test: /script LLC_CraftSmithingItem(1, 1, 7, 2, 1, false, 1, 0, 0 )
	-- test: /script LLC_CraftSmithingItem(1, 1, 7, 2, 1, false, 5, 0, 0)



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
	--for k, v in pairs(craftResultFunctions) do
	--	v(event, station, LLCResult)
	--end
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


SetIndexes =
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
--[[
function ActivityManager:QueueActivity(activity)
    local queue, lookup = self.queue, self.lookup
    local key = activity:GetKey()
    if(lookup[key]) then return false end
    queue[#queue + 1] = activity
    lookup[key] = activity
    table.sort(queue, ByPriority)
    return true
end

function ActivityManager:RemoveActivity(activity)
    self.lookup[activity:GetKey()] = nil
    for i = 1, #self.queue do
        if(self.queue[i]:GetKey() == activity:GetKey()) then
            table.remove(self.queue, i)
            break
        end
    end
end





]]