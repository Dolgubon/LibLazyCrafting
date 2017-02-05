local LibLazyCrafting = LibStub("LibLazyCrafting")
local sortCraftQueue = LibLazyCrafting.sortCraftQueue
local SetIndexes ={}


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


--- EXAMPLE ONLY - for knowing what is in a request
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


local function copy(t)
	local a = {}
	for k, v in pairs(t) do
		a[k] = v
	end
	return a
end


local requirementJumps = { -- At these material indexes, the material required changes, and the amount required jumps down
	[1] = 1,
	[2] = 8,
	[3] = 13,
	[4] = 18,
	[5] = 23,
	[6] = 26,
	[7] = 29,
	[8] = 32,
	[9] = 34,
	[10] = 40,
}

local additionalRequirements = -- Seperated by station. The additional amount of mats added to the base amount.
{
	[CRAFTING_TYPE_BLACKSMITHING] = 
	{ 2, 2, 2, 4, 4, 4, 1, 6, 4, 4, 4, 5, 4, 4,
	},
	[CRAFTING_TYPE_WOODWORKING] = 
	{ 2, 5, 2, 2, 2, 2,
	},
	[CRAFTING_TYPE_CLOTHIER] = 
	{ 6, 6, 4, 4, 4, 5, 4, 4, 6, 4, 4, 4, 5, 4, 4,

	},
}

local currentStep = 1
local baseRequirements = {}
for i = 1, 41 do
	if requirementJumps[currentStep] == i then
		currentStep = currentStep + 1
		baseRequirements[i] = currentStep -1 
	else
		baseRequirements[i] = baseRequirements[i-1] 
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
			if craftRequestTable["trait"]==0 then d("Invalid trait") end
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
LibLazyCrafting.canCraftItemHere = canCraftItemHere

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


---------------------------------
-- SMITHING HELPER FUNCTIONS

local function GetMaxImprovementMats(bag, slot ,station)
	local numBooster = 1
	local chance =0
	if not CanItemBeSmithingImproved(bag, slot, station) then return false end
	while chance<100 do
		numBooster = numBooster + 1
		chance = GetSmithingImprovementChance(bag, slot, numBooster,station)
		
	end
	return numBooster
end


function LLC_GetSmithingPatternInfo(patternIndex, station, set)
end

function LLC_GetSetIndexTable()
	return SetIndexes
end

-- Finds the material index based on the level
local function findMatIndex(level, champion)

	local index = 1

	if champion then
		index = 25
		index = index + math.floor(level/10)
	else
		index = 0
		if level<3 then
			index = 1
		else
			index = index + math.floor(level/2)
		end
	end
	return index

end



function GetMatRequirements(pattern, index, station)
	local mats
	
	mats = baseRequirements[index] + additionalRequirements[station][pattern]
	if station == CRAFTING_TYPE_WOODWORKING and pattern ~= 2 and index >=40 then
		mats = mats + 1
	end

	if station == CRAFTING_TYPE_BLACKSMITHING and pattern ==12 and index <13 and index >=8 then
		mats = mats - 1
	end

	if station == CRAFTING_TYPE_BLACKSMITHING and pattern >=4 and pattern <=6 and index >= 40 then
		mats = mats + 1
	end
	return mats
end


local function LLC_CraftSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, autocraft)
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	local station
	if type(self) == "number" then
		d("Please call using colon notation: e.g LLC:CraftSmithingItem(). If you are seeing this and you are not a developer please contact the author of the addon")
	end
	if not (stationOverride==CRAFTING_TYPE_BLACKSMITHING or stationOverride == CRAFTING_TYPE_WOODWORKING or stationOverride == CRAFTING_TYPE_CLOTHIER) then
		if GetCraftingInteractionType() == 0 then
			d("Invalid Station")
			return
		else
			station = GetCraftingInteractionType()
		end
	else
		station =stationOverride
	end
	--Handle the extra values. If they're nil, assign default values.
	if not quality then setIndex = 0 end
	if not quality then quality = 0 end


	-- create smithing request table and add to the queue
	if self.addonName=="LLC_Global" then d("Item added") end
	table.insert(craftingQueue[self.addonName][station],
	{
		["type"] = "smithing",
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
		["Requester"] = self.addonName,
	})
	sortCraftQueue()
end

local function LLC_CraftSmithingItemByLevel(self, patternIndex, isCP , level, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, autocraft)
	local materialIndex = findMatIndex(level, isCP)
	local materialQuantity = GetMatRequirements(patternIndex, materialIndex, stationOverride)
	LLC_CraftSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, autocraft)
end

LibLazyCrafting.functionTable.CraftSmithingItem = LLC_CraftSmithingItem
LibLazyCrafting.functionTable.CraftSmithingItemByLevel = LLC_CraftSmithingItemByLevel
-- /script LLC_Global:CraftSmithingItemByLevel(3, true, 140,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 1,true)
-- /script LLC_Global:CraftSmithingItemByLevel(3, true, 140,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 5,true)


-- We do take the bag and slot index here, because we need to know what to upgrade
function LLC_ImproveSmithingItem(self, BagIndex, SlotIndex, newQuality, autocraft)
	local station = -1
	for i = 1, 6 do
		if CanItemBeSmithingImproved(BagIndex, SlotIndex,i) then
			station = i
		end
	end
	if station == -1 then d("Cannot be improved") return end
	if autocraft==nil then autocraft = self.autocraft end
	local a = {
	["type"] = "improvement",
	["Requester"] = self.addonName, -- ADDON NAME
	["autocraft"] = autocraft,
	["ItemLink"] = GetItemLink(BagIndex, SlotIndex),
	["ItemBagID"] = BagIndex,
	["ItemSlotID"] = SlotIndex,
	["ItemUniqueID"] = GetItemUniqueId(BagIndex, SlotIndex),
	["ItemCreater"] = GetItemCreatorName(BagIndex, SlotIndex),
	["quality"] = newQuality,
	["timestamp"] = GetTimeStamp(),}
	table.insert(craftingQueue[self.addonName][station], a)
	sortCraftQueue()
end

local currentCraftAttempt = 
{
	["type"] = "smithing",
	["pattern"] = 3,
	["style"] = 2,
	["trait"] = 3,
	["materialIndex"] = 3,
	["materialQuantity"] = 5,
	["setIndex"] = 3,
	["quality"] = 2,
	["useUniversalStyleItem"] = true,
	["autocraft"] = true,
	["Requester"] = "",	
	["timestamp"] = 1234566789012345,
	["slot"]  = 0,
	["link"] = "",
	["callback"] = function() end,
	["position"] = 0,
}




-------------------------------------------------------
-- SMITHING INTERACTION FUNCTIONS

local function LLC_SmithingCraftInteraction( station)
	local earliest, addon , position = LibLazyCrafting.findEarliestRequest(station)
	if earliest then

		if earliest.type =="smithing" then

			local parameters = {
			earliest.pattern, 
			earliest.materialIndex,
			earliest.materialQuantity, 
			earliest.style, 
			earliest.trait, 
			earliest.useUniversalStyleItem,
			LINK_STYLE_DEFAULT,
		}

			CraftSmithingItem(unpack(parameters))
			currentCraftAttempt = copy(earliest)
			currentCraftAttempt.position = position
			currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
			currentCraftAttempt.slot = FindFirstEmptySlotInBag(BAG_BACKPACK)
			currentCraftAttempt.timestamp = GetTimeStamp()
			table.remove(parameters,6 )
			currentCraftAttempt.link = GetSmithingPatternResultLink(unpack(parameters))
		elseif earliest.type =="improvement" then
			local parameters = {}
			local skillIndex = station + 1 - math.floor(station/6)
			local currentSkill, maxSkill = GetSkillAbilityUpgradeInfo(SKILL_TYPE_TRADESKILL,skillIndex,6)

			if currentSkill~=maxSkill then
				-- cancel if quality is already blue and skill is not max
				-- This is to save on improvement mats. 

				if earliest.quality>2 and GetItemLinkQuality(GetItemLink(earliest.ItemBagID, earliest.ItemSlotID)) >ITEM_QUALITY_MAGIC then
					d("Improvement skill is not at maximum. Improvement prevented to save mats.")
					return
				end
			end
			local numBooster = GetMaxImprovementMats( earliest.ItemBagID,earliest.ItemSlotID,station)
			if not numBooster then return end

			ImproveSmithingItem(earliest.ItemBagID,earliest.ItemSlotID, numBooster)
			currentCraftAttempt = copy(earliest)
			currentCraftAttempt.position = position
			currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
			currentCraftAttempt.timestamp = GetTimeStamp()
			currentCraftAttempt.link = GetSmithingImprovedItemLink(earliest.ItemBagID, earliest.ItemSlotID, station)
		end
		
			--ImproveSmithingItem(number itemToImproveBagId, number itemToImproveSlotIndex, number numBoostersToUse)
			--GetSmithingImprovedItemLink(number itemToImproveBagId, number itemToImproveSlotIndex, number TradeskillType craftingSkillType, number LinkStyle linkStyle)
	end
end
-- check ItemID and style

local function WasItemCrafted()
	local checkPosition = {BAG_BACKPACK, currentCraftAttempt.slot}
	if GetItemName(unpack(checkPosition))==GetItemLinkName(currentCraftAttempt.link) then
		if GetItemLinkQuality(GetItemLink(unpack(checkPosition))) ==ITEM_QUALITY_NORMAL then
			if GetItemRequiredLevel(unpack(checkPosition))== GetItemLinkRequiredLevel(currentCraftAttempt.link) then
				if GetItemRequiredChampionPoints(unpack(checkPosition)) == GetItemLinkRequiredChampionPoints(currentCraftAttempt.link) then
					if GetItemId(unpack(checkPosition)) == GetItemIDFromLink(currentCraftAttempt.link) then
						if GetItemLinkItemStyle(GetItemLink(unpack(checkPosition))) ==GetItemLinkItemStyle(currentCraftAttempt.link) then
							return true
						else
							return false
						end
					else
						return false
					end
				else
					return false
				end
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end

end

local function SmithingCraftCompleteFunction(station)
	if currentCraftAttempt.type == "smithing" then
		if WasItemCrafted() then
			d("Crafted success")

			if currentCraftAttempt.quality>0 then
				LLC_ImproveSmithingItem({["addonName"]=currentCraftAttempt.Requester}, BAG_BACKPACK, currentCraftAttempt.slot, currentCraftAttempt.quality, currentCraftAttempt.autocraft)
			end

			craftingQueue[currentCraftAttempt.Requester][station][currentCraftAttempt.position] = nil
			currentCraftAttempt = {}
			sortCraftQueue()

		end
	elseif currentCraftAttempt.type == "improvement" then
	else
		return
	end

end


LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING] =
{
	["check"] = function(station) return station == CRAFTING_TYPE_BLACKSMITHING end,
	['function'] = LLC_SmithingCraftInteraction,
	["complete"] = SmithingCraftCompleteFunction,
	["endInteraction"] = function(station) --[[endInteraction()]] end,
	["isItemCraftable"] = function(station, request) 

		if request["type"] == "improvement" then return true end


		if canCraftItemHere(station, request["setIndex"]) and canCraftItem(request) and enoughMaterials(request) then

			return true
		else
			return false
		end 
	end,
}
-- Should be the same for other stations though. Except for the check
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_WOODWORKING] = copy(LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING]) 
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_WOODWORKING]["check"] = function(station) return station == CRAFTING_TYPE_WOODWORKING end 
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_CLOTHIER] = copy(LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING])
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_CLOTHIER]["check"] = function(station) return station == CRAFTING_TYPE_CLOTHIER end 


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


