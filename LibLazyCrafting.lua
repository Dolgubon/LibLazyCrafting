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

LibLazyCrafting.test = "HEY!!"

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
craftingQueue = 
{
	--["GenericTesting"] = {}, -- This is for say, calling from chat.
	["ExampleAddon"] = -- This contains examples of all the crafting requests. It is removed upon initialization. Most values are random/default.
	{
		["autocraft"] = false, -- if true, then timestamps will be applied when the addon calls LLC_craft()
		["craftResultCallback"] = function() --[[ handler - specific to each single addon.]] end,
		[CRAFTING_TYPE_WOODWORKING] = 
		{
			{["type"] = "smithing",
			["pattern"] =0,
			["Requester"] = "",
			["autocraft"] = true,
			["style"] = 0,
			["trait"] = 0,
			["materialIndex"] = 0,
			["materialQuantity"] = 0,
			["setIndex"] = 0,
			["quality"] = 0,
			["useUniversalStyleItem"] = false,
			["timestamp"] = 1111111, },
		},
		[CRAFTING_TYPE_BLACKSMITHING] = 
		{
			{["type"] = "improvement",
			["Requester"] = "", -- ADDON NAME
			["autocraft"] = true,
			["ItemLink"] = "",
			["ItemBagID"] = 0,
			["ItemSlotID"] = 0,
			["ItemUniqueID"] = 0,
			["ItemCreater"] = "",
			["FinalQuality"] = 0,
			["timestamp"] = 1112222,}
		},
		[CRAFTING_TYPE_ENCHANTING] = 
		{
			{["essenceItemID"] = 0,
			["aspectItemID"] = 0,
			["potencyItemID"] = 0,
			["timestamp"] = 12345667,
			["autocraft"] = true,
			["Requester"] = "",
		}
		},
		[CRAFTING_TYPE_ALCHEMY] = 
		{	
			{["SolvenItemID"] = 0,
			["Reagents"] = 
			{
				[1] = 0,
				[2] = 0,
				[3] = 0,
			},
			["timestamp"] = 1234555,
			["Requester"] = "",
			["autocraft"] = true,
		}
		},
		[CRAFTING_TYPE_PROVISIONING] = 
		{
			{["RecipeID"] = 0,
			["timestamp"] = 111111,
			["Requester"] = "",
			["autocraft"] = true,}
		},
	},
}

LibLazyCrafting.functionTable = {}

function GetItemNameFromItemId(itemId)

	return GetItemLinkName(ZO_LinkHandler_CreateLink("Test Trash", nil, ITEM_LINK_TYPE,itemId, 1, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0))
end

-- Just a random help function; can probably be taken out but I'll leave it in for now
-- Pretty helpful function for exploration.
function GetItemIDFromLink(itemLink) return tonumber(string.match(itemLink,"|H%d:item:(%d+)")) end

local function sortCraftQueue()
	for name, requests in pairs(craftingQueue) do 
		for i = 1, 6 do 
			table.sort(requests[i], function(a, b) if a and b then return a["timestamp"]<b["timestamp"] else return a end end)
		end
	end
end

function enoughMaterials(craftRequestTable)
	local missing = 
	{
		["materials"] = {},
	}
	if GetCurrentSmithingStyleItemCount(craftRequestTable["style"]) >0 then
		-- Check trait mats
		if GetCurrentSmithingTraitItemCount(craftRequestTable["trait"])> 0 or craftRequestTable["trait"]==1 then
			-- Check wood/ingot/cloth mats
			if GetCurrentSmithingMaterialItemCount(craftRequestTable["pattern"],craftRequestTable["materialIndex"])>craftRequestTable["materialQuantity"] then
				-- Check if enough traits are known
				return true
			else
				missing.materials["mats"]  = true
			end
		else
			missing.materials["trait"] = true
		end
	else
		missing.materials["style"] = true
	end
	return false, missing
end



function canCraftItem(craftRequestTable)
	local missing = 
	{
		["knowledge"] = {},
		["materials"] = {},
	}
	--CanSmithingStyleBeUsedOnPattern()
	-- Check stylemats
	local _,_,_,_,traitsRequired, traitsKnown = GetSmithingPatternInfo(craftRequestTable["pattern"])
	if traitsRequired<= traitsKnown then
		-- Check if the specific trait is known
		if IsSmithingTraitKnownForResult(craftRequestTable["pattern"], craftRequestTable["materialIndex"], craftRequestTable["materialQuantity"],craftRequestTable["style"], craftRequestTable["trait"]) then
			-- Check if the style is known for that piece
			if IsSmithingStyleKnown(craftRequestTable["style"], craftRequestTable["pattern"]) then
				return true
			else
				missing.knowledge["style"] = true
			end
			missing.knowledge["trait"] = true
		end
	else
		missing.knowledge["traitNumber"] = true
	end
	return false, missing
	
end


-- Returns SetIndex, Set Full Name, Traits Required
local function GetCurrentSetInteractionIndex()
	local baseSetPatternName
	local sampleId
	local currentStation = GetCraftingInteractionType()
	-- Get info based on what station it is.
	if currentStation == CRAFTING_TYPE_BLACKSMITHING then
		baseSetPatternName = GetSmithingPatternInfo(15)
		sampleId = GetItemIDFromLink(GetSmithingPatternResultLink(15,1,3,1,1,0))
	elseif currentStation == CRAFTING_TYPE_CLOTHIER then
		baseSetPatternName = GetSmithingPatternInfo(16)
		sampleId = GetItemIDFromLink(GetSmithingPatternResultLink(16,1,7,1,1,0))
	elseif currentStation == CRAFTING_TYPE_WOODWORKING then
		baseSetPatternName = GetSmithingPatternInfo(7)
		sampleId = GetItemIDFromLink(GetSmithingPatternResultLink(7,1,3,1,1,0))
	else
		return nil , nil, nil, nil
	end
	-- If no set
	if baseSetPatternName=="" then return 0, SetIndexes[0][1],  SetIndexes[0][3] end
	-- find set index
	for i =1, #SetIndexes do
		if i == 22 then d(SetIndexes[i][2][currentStation],sampleId,SetIndexes[i][2][currentStation]==sampleId) end
		if sampleId == SetIndexes[i][2][currentStation] then
			return i, SetIndexes[i][1] , SetIndexes[i][3]
		end
	end
	
end
LibLazyCrafting.functionTable.GetCurrentSetInteractionIndex  = GetCurrentSetInteractionIndex

-- Can an item be crafted here, based on set and station indexes
local function canCraftItemHere(station, setIndex)
	if not setIndex then setIndex = 0 end
	if GetCraftingInteractionType()==station then
		if GetCurrentSetInteractionIndex(setIndex)==setIndex or setIndex==0 then
			return true
		end
	end
	return false

end

LibLazyCrafting.functionTable.canCraftItemHere = canCraftItemHere

local function isItemCraftable(request, station)
	if station ==CRAFTING_TYPE_ENCHANTING or station == CRAFTING_TYPE_PROVISIONING or station == CRAFTING_TYPE_ALCHEMY then
		return true
	end
	if request["type"] == "improvement" then return true end
	if canCraftItemHere(station, request["setIndex"]) and canCraftItem(request) and enoughMaterials(request) then
		return true
	else
		return false
	end
end



-- Finds the highest priority request.
local function findEarliestRequest(station)
	local earliest = {[station]= {["timestamp"] = GetTimeStamp() + 100000}} -- should be later than anything else, as it's 'in the future'
	local addonName = nil
	for addon, requestTable in craftingQueue do

		for i = 1, #requestTable do
			if isItemCraftable(requestTable[i],station)  and requestTable[i]["autocraft"] then
				if requestTable[station][i]["timestamp"] < earliest[station][i]["timestamp"] then
					earliest = requestTable[i]
					addonName = addon
					break
				else
					break
				end
			end

		end

	end
	if addonName then
		return earliest, addonName
	else
		return nil, nil
	end
end

LibLazyCrafting.functionTable.findEarliestRequest = findEarliestRequest

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

LibLazyCrafting.functionTable.findItem = findItem

local function LLC_CraftSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, autocraft)
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
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
		["autocraft"] = autocraft,
	}
	sortCraftQueue()
end
LibLazyCrafting.functionTable.craftSmithingItem = LLC_CraftSmithingItem




function LibLazyCrafting:Init()

	-- Call this to register the addon with the library.
	-- Really this is mostly arbitrary, I just want to force an addon to give me their name ;p. But it's an easy way, and only needs to be done once.
	-- Returns a table with all the functions, as well as the addon's personal queue.
	-- nilable:boolean autocraft will cause the library to automatically craft anything in the queue when at a crafting station. 
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

		-- Add all the functions to the interaction table!!
		-- On the other hand, then addon devs can mess up the functions?
		LLCAddonInteractionTable.CraftSmithingItem = LLC_CraftSmithingItem
		LLCAddonInteractionTable["CraftEnchantingItemId"] = LibLazyCrafting.functionTable.CraftEnchantingItemId
		LLCAddonInteractionTable["CraftEnchantingGlyph"] = LibLazyCrafting.functionTable.CraftEnchantingGlyph


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
	LLC_Global = LibLazyCrafting:AddRequestingAddon("LLC_Global")

	--craftingQueue["ExampleAddon"] = nil
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



-- First is the name of the set. Second is a table of sample itemIds. Third is the number of required traits.
-- First itemId is for blacksmithing (axe, no trait), second is for clothing, (robe no trait) third is woodworking (Bow, no trait)
-- This is pretty much arbitrary, sorted by when the set was introduced, and how many traits are needed.
-- Declared at the end of the file for cleanliness

SetIndexes =
{
	[0]  = {"No Set"						,"No Set"					,0},
	[1]  = {"Death's Wind",{46499,46518,[6]=43805},2},
	[2]  = {"Night's Silence",{47265,47287,[6]=47279},2},
	[3]  = {"Ashen Grip",{49563,49583,[6]=49575},2},
	[4]  = {"Torug's Pact",{50708,50727,[6]=43979},3},
	[5]  = {"Twilight's Embrace",{46882,46901,[6]=43808},3},
	[6]  = {"Armour of the Seducer",{48031,48050,[6]=48042},3},
	[7]  = {"Magnus' Gift",{48797,48816,[6]=43849},4},
	[8]  = {"Hist Bark",{51090,51113,[6]=51105},4},
	[9]  = {"Whitestrake's Retribution",{47648,47671,[6]=47663},4},
	[10] = {"Vampire's Kiss",{48414,48433,[6]=48425},5},
	[11] = {"Song of the Lamae",{52233,52251,[6]=52243},5},
	[12] = {"Alessia's Bulwark",{52614,52632,[6]=52624},5},
	[13] = {"Night Mother's Gaze",{49180,49203,[6]=49195},6},
	[14] = {"Willow's Path",{51471,51494,[6]=51486},6},
	[15] = {"Hunding's Rage",{51852,51872,[6]=51864},6},
	[16] = {"Kagrenac's Hope",{53757,53780,[6]=53772},8},
	[17] = {"Orgnum's Scales",{52995,53014,[6]=53006},8},
	[18] = {"Eyes of Mara",{53376,53393,[6]=44053},8},
	[19] = {"Shalidor's Curse",{54138,54157,[6]=54149},8},
	[20] = {"Oblivion's Foe",{49946,49964,[6]=43968},8},
	[21] = {"Spectre's Eye",{50327,50345,[6]=43972},8},
	[22] = {"Way of the Arena",{54965,54971,[6]=54963},8},
	[23] = {"Twice-Born Star",{58175,58182,[6]=58174},9},
	[24] = {"Noble's Conquest",{60261,60268,[6]=60280},5},
	[25] = {"Redistributor",{60611,60618,[6]=60630},7},
	[26] = {"Armour Master",{60961,60968,[6]=60980},9},
	[27] = {"Trial by Fire",{69599,69606,[6]=69592},3},
	[28] = {"Law of Julianos",{69949,69956,[6]=69942},6},
	[29] = {"Morkudlin",{70649,70656,[6]=70642},9},
	[30] = {"Tava's Favour",{71813,71820,[6]=71806},5},
	[31] = {"Clever Alchemist",{72163,72170,[6]=72156},7},
	[32] = {"Eternal Hunt",{72513,72520,[6]=72506},9},
	[33] = {"Kvatch Gladiator",{75386,75393,[6]=75406},5},
	[34] = {"Varen's Legacy",{75736,75743,[6]=75756},7},
	[35] = {"Pelinal's Aptitude",{76086,76093,[6]=76106},9},

}

--[[
Pelinal's Aptitude
76086 axe 
76093 bow 
76106 robe

Varen's Legacy
75736 axe 
75743 bow 
75756 robe

Kvatch Gladiator
75386 axe 
75393 bow 
75406 robe

Eternal Hunt
72506 robe 
72513 axe 
72520 bow

Clever Alchemist
72156 robe 
72163 axe 
72170 bow

Tava's Favour
71806 robe 
71813 axe 
71820 bow

Morkudlin
70642 robe 
70649 axe 
70656 bow

Law of Julianos
69592 robe 
69599 axe 
69606 bow

Trial By Fire
69942 robe 
69949 axe 
69956 bow

Armour Master
60961 axe 
60968 bow 
60980 robe

Redistributor
60611 axe 
60618 bow 
60630 robe

Noble's Conquest
60261 axe 
60268 bow 
60280 robe

Twice Born Star
58174 robe 
58175 axe 
58182 bow

Way of the arena
54963 robe 
54965 axe 
54971 bow

Spectre's Eye
43972 robe 
50327 axe 
50345 bow

Oblivion's Foe
43968 robe 
49946 axe 
49964 bow

Shalidor's Curse
54138 axe 
54149 robe 
54157 bow

Eyes of Mara
44053 robe 
53376 axe 
53393 bow

Orgnum's Scales
52995 axe 
53006 robe 
53014 bow

Kagrenac's Hope
53757 axe 
53772 robe 
53780 bow

Hunding's Rage
51852 axe 
51864 robe 
51872 bow

Willow's Path
51471 axe 
51486 robe 
51494 bow

Night Mother's Gaze
49180 axe 
49195 robe 
49203 bow

Allessia's Bulwark
52614 axe 
52624 robe 
52632 bow

Song of the Lamae
52233 axe 
52243 robe 
52251 bow

Vampire's Kiss
48414 axe 
48425 robe 
48433 bow

Whitestrake's Retribution
47648 axe 
47663 robe 
47671 bow

Hist bark
51090 axe 
51105 robe 
51113 bow

Magnus' Gift
43849 robe 
48797 axe 
48816 bow

Armour of the Seducer
48031 axe 
48042 robe 
48050 bow

Twilight's Embrace
43808 robe 
46882 axe 
46901 bow

Torug's Pact
43979 robe 
50708 axe 
50727 bow

Ashen Grip
49563 axe 
49575 robe 
49583 bow

Night's Silence
47265 axe 
47279 robe 
47287 bow

Death's Wind
43805 robe
46499 axe 
46518 bow

Whitestrake
47671 - bow
47663 - robe 8
47648 - axe 15

Hist Bark
51113 - bow
51105 - robe 8
51090 - axe 15

Magnus
48816 - bow
43849 - robe
48797 - axe 

Night mother
49180 axe 
49195 robe 
49203 bow




]]




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