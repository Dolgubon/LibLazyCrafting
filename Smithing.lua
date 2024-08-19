-----------------------------------------------------------------------------------
-- Library Name: LibLazyCrafting
-- Creator: Dolgubon (Joseph Heinzle)
-- Library Ideal: Allow addons to craft anything, anywhere
-- Library Creation Date: December, 2016
-- Publication Date: Febuary 5, 2017
--
-- File Name: Smithing.lua
-- File Description: Contains the functions for Smithing (Blacksmithing, Clothing, Woodworking)
-- Load Order Requirements: After LibLazyCrafting.lua
--
-----------------------------------------------------------------------------------


--GetLastCraftingResultItemLink(number resultIndex, number LinkStyle linkStyle)
--/script d(GetLastCraftingResultItemInfo(1))

local LibLazyCrafting = _G["LibLazyCrafting"]

local widgetType = 'smithing'
local widgetVersion = 3.0
if not LibLazyCrafting:RegisterWidget(widgetType, widgetVersion) then return  end

local LLC = LibLazyCrafting
local throw = LLC.LLCThrowError

local function dbug(...)
	if DolgubonGlobalDebugOutput then
		DolgubonGlobalDebugOutput(...)
	end
end

local INDEX_NO_SET = 0
LibLazyCrafting.INDEX_NO_SET = INDEX_NO_SET

local craftingQueue = LibLazyCrafting.craftingQueue

-- initialize data tables
local dataTables = -- Might move all data tables over to this in the future
{
	["SetIndexes"] = {},
	["materialItemIDs"] = {},
}
local SetIndexes = {}
local materialItemIDs = {}

local sortCraftQueue = LibLazyCrafting.sortCraftQueue

local abc = 1
local improvementChances = {}


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

------------------------------------------------------
-- HELPER FUNCTIONS

-- A simple shallow copy of a table.
local function copy(t)
	local a = {}
	for k, v in pairs(t) do
		a[k] = v
	end
	return a
end

-- Returns an item link from the given itemId.
local function getItemLinkFromItemId(itemId)
	return string.format("|H1:item:%d:%d:50:0:0:0:0:0:0:0:0:0:0:0:0:%d:%d:0:0:%d:0|h|h", itemId, 0, ITEMSTYLE_NONE, 0, 10000) 
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

-- Seperated by station. The additional amount of mats added to the base amount.
local additionalRequirements =
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

-- Jewelry material count and tiers do not follow the same
-- pattern as BS/CL/WW.
local JEWELY_MAT_REQUIREMENT = {
--mat                          char
--tier = { ring, necklace,  material tier} -- level
  [ 1] = {    2,        3,				1} --     1 pewter
, [ 2] = {    3,        5,				1} --     4
, [ 3] = {    4,        6,				1} --     6
, [ 4] = {    5,        8,				1} --     8
, [ 5] = {    6,        9,				1} --    10
, [ 6] = {    7,       11,				1} --    12
, [ 7] = {    8,       12,				1} --    14
, [ 8] = {    9,       14,				1} --    16
, [ 9] = {   10,       15,				1} --    18
, [10] = {   11,       17,				1} --    20
, [11] = {   12,       19,				1} --    22
, [12] = {   13,       20,				1} --    24
, [13] = {    3,        5,				2} --    26 copper
, [14] = {    4,        6,				2} --    28
, [15] = {    5,        8,				2} --    30
, [16] = {    6,        9,				2} --    32
, [17] = {    7,       11,				2} --    34
, [18] = {    8,       12,				2} --    36
, [19] = {    9,       14,				2} --    38
, [20] = {   10,       15,				2} --    40
, [21] = {   11,       17,				2} --    42
, [22] = {   12,       18,				2} --    44
, [23] = {   13,       20,				2} --    46
, [24] = {   14,       21,				2} --    48
, [25] = {   15,       23,				2} --    50
, [26] = {    4,        6,				3} --  CP10 silver
, [27] = {    6,        9,				3} --  CP20
, [28] = {    8,       12,				3} --  CP30
, [29] = {   10,       15,				3} --  CP40
, [30] = {   12,       18,				3} --  CP50
, [31] = {   14,       21,				3} --  CP60
, [32] = {   16,       24,				3} --  CP70
, [33] = {    6,        8,				4} --  CP80 electrum
, [34] = {    8,       12,				4} --  CP90
, [35] = {   10,       16,				4} -- CP100
, [36] = {   12,       20,				4} -- CP110
, [37] = {   14,       24,				4} -- CP120
, [38] = {   16,       28,				4} -- CP130
, [39] = {   18,       32,				4} -- CP140
, [40] = {   10,       15,				5} -- CP150 platinum
, [41] = {  100,      150,				5} -- CP160
}

local currentStep = 1
local baseRequirements = {}
for i = 1, 41 do
	if i == 41 then
		baseRequirements[i] = baseRequirements[40]
	elseif i == 40 then
		baseRequirements[i] = currentStep - 1
	elseif requirementJumps[currentStep] == i then
		currentStep = currentStep + 1
		baseRequirements[i] = currentStep -1
	else
		baseRequirements[i] = baseRequirements[i-1] +1
	end
end



local function maxStyle (craftRequestTable) -- Searches to find the style that the user has the most style stones for. Only searches basic styles. User must know style
 	local piece = craftRequestTable.pattern
 	local styleTable
 	if type(LibLazyCrafting.addonInteractionTables[craftRequestTable.Requester]["styleTable"])=="table" then
 		styleTable = LibLazyCrafting.addonInteractionTables[craftRequestTable.Requester]["styleTable"]
 	elseif type(LibLazyCrafting.addonInteractionTables[craftRequestTable.Requester]["styleTable"]) == "function" then
 		styleTable = LibLazyCrafting.addonInteractionTables[craftRequestTable.Requester]["styleTable"]()
 	end
    local bagId = BAG_BACKPACK
    SHARED_INVENTORY:RefreshInventory(bagId)
    local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(bagId)
 
    local max = -1
    local numKnown = 0
    local numAllowed = 0
    local maxStack = -1
    local useStolen = AreAnyItemsStolen(BAG_BACKPACK) and false
    local useSmartStyleSave = styleTable.smartStyleSlotSave
    for i, v in pairs(styleTable) do
        if v and type(i)=="number" then
            numAllowed = numAllowed + 1
	        
	        if IsSmithingStyleKnown(i, piece) then
	            numKnown = numKnown + 1
	 
	            for key, itemInfo in pairs(bagCache) do
	                local slotId = itemInfo.slotIndex
	                if itemInfo.stolen == true then
	                	-- if there's a stolen style mat, then use that style first
	                    local itemType, specialType = GetItemType(bagId, slotId)
	                    if itemType == ITEMTYPE_STYLE_MATERIAL then
	                        local _, stack, _, _, _, _, itemStyleId, _ = GetItemInfo(bagId, slotId)
	                        if itemStyleId == i then
	                            if stack > maxStack then
	                                maxStack = stack
	                                max = itemStyleId
	                                useStolen = true
	                            end
	                        end
	                    end
	                end
	            end
	 
	            if useStolen == false then -- if we're using a stolen style stone, then skip this
	            	if useSmartStyleSave then
	            		if GetCurrentSmithingStyleItemCount(max) == 0 or GetCurrentSmithingStyleItemCount(i)<GetCurrentSmithingStyleItemCount(max) then
		                    if GetCurrentSmithingStyleItemCount(i)>0 and v then
		                        max = i
		                    end
		                end
	            	else
		                if GetCurrentSmithingStyleItemCount(i)>GetCurrentSmithingStyleItemCount(max) then
		                    if GetCurrentSmithingStyleItemCount(i)>0 and v then
		                        max = i
		                    end
		                end
		            end
	            end
	        end
        end
    end
    if max == -1 then
        if numKnown <3 then
            return -2
        end
        if numAllowed < 3 then
            return -3
        end
    end
    return max
end



function enoughMaterials(craftRequestTable)

	local missing =
	{
		["materials"] = {},
	}
	local missingSomething = false
	local smithingQuantity = 1
	smithingQuantity = craftRequestTable.smithingQuantity or 1
	if craftRequestTable["style"] 
		and craftRequestTable['station']~= CRAFTING_TYPE_JEWELRYCRAFTING and not craftRequestTable["useUniversalStyleItem"] then
		if craftRequestTable["style"]==LLC_FREE_STYLE_CHOICE then
			if maxStyle(craftRequestTable) <0 then
				missing.materials["style"] = true
				missingSomething = true
			end
		elseif GetCurrentSmithingStyleItemCount(craftRequestTable["style"]) < 1*smithingQuantity then
			missing.materials["style"] = true
			missingSomething = true
		end
	end

	-- Check trait mats
	if not(GetCurrentSmithingTraitItemCount(craftRequestTable["trait"])>=1*smithingQuantity or craftRequestTable["trait"]==1) then
		if craftRequestTable["trait"]==0 then d("Invalid trait") end
		missing.materials["trait"] = true
		missingSomething = true
	end

	-- Check wood/ingot/cloth mats
	if not(GetCurrentSmithingMaterialItemCount(craftRequestTable["pattern"],craftRequestTable["materialIndex"])>=craftRequestTable["materialQuantity"]*smithingQuantity) then
		missing.materials["mats"]  = true
		missingSomething = true
	end

	if missingSomething then
		return false, missing
	else
		return true
	end
end

local function findMatTierByIndex(index)
	local a = {
		[1] = 7,
		[2] = 12,
		[3] = 17,
		[4] = 22,
		[5] = 25,
		[6] = 28,
		[7] = 31,
		[8] = 33,
		[9] = 39,
		[10] = 41,
	}
	for i = 1, #a do
		if index  > a[i] then
		else
			return i
		end
	end
	return 10
end

local SKILL_LINE =
{
	[CRAFTING_TYPE_BLACKSMITHING] = {
		skill_line_id = 79,
		base_ability_id = 70041,		-- "Metalworking"
		improve_ability_id = 48168,		-- "Temper Expertise"
		},
	[CRAFTING_TYPE_CLOTHIER] = {
		skill_line_id = 81,
		base_ability_id = 70044, 		-- "Tailoring"
		improve_ability_id = 48198,		-- "Tannin Expertise"
		},
	[CRAFTING_TYPE_WOODWORKING] = {
		skill_line_id = 80,
		base_ability_id = 70046, 		-- "Woodworking"
		improve_ability_id = 48177, 	-- "Resin Expertise"
		},
	[CRAFTING_TYPE_JEWELRYCRAFTING] = {
		skill_line_id = 141,
		base_ability_id = 103636, 		-- "Engraver"
		improve_ability_id = 103648,	-- "Platings Expertise"
		},
	[CRAFTING_TYPE_ALCHEMY] = {
		skill_line_id = 77,
		base_ability_id = 70043,		-- "Solvent Expertise"
		improve_ability_id = nil,		-- no blue/purple/gold in alchemy
		},
	[CRAFTING_TYPE_ENCHANTING] = {
		skill_line_id = 78,
		base_ability_id = 70045,		-- "Potency Improvement" -- glyph level
		improve_ability_id = 46763,		-- "Aspect Improvement", allows gold Kuta
		},
	[CRAFTING_TYPE_PROVISIONING] = {
		skill_line_id = 76,
		base_ability_id = 44650, 		-- "Recipe Improvement" = recipe level
		improve_ability_id = 69953, 	-- "Recipe Quality", allows use of gold recipes
		},
}

local function getCraftLevel(station)
	local skillLine = SKILL_LINE[station]
	local skillType, skillIndex, abilityIndex, morphChoice, rankindex = GetSpecificSkillAbilityKeysByAbilityId(skillLine.base_ability_id)
	if abilityIndex then
		local currentSkill, maxSkill = GetSkillAbilityUpgradeInfo(skillType,skillIndex,abilityIndex)
		return currentSkill , maxSkill
	else
		return 0,1
	end
end


local function canCraftItem(craftRequestTable)
	local missing =
	{
		["knowledge"] = {},
		["materials"] = {},
	}
	--CanSmithingStyleBeUsedOnPattern()
	-- Check stylemats
	local setPatternOffset = {}

	if craftRequestTable["setIndex"] == INDEX_NO_SET or ZO_Smithing_IsConsolidatedStationCraftingMode() then
		setPatternOffset = {0,0,[6]=0,[7]=0}
	else
		setPatternOffset = {14, 15,[6]=6,[7]=2}
	end

	-- This offset index was used in the call GetSmithingPatternInfo, but not in IsSmithingTraitKnownForResult
	-- which caused the check to fail if you didn't have the same traits known for both rings and necklaces in sets.
	local patternIndex = craftRequestTable["pattern"] + setPatternOffset[craftRequestTable["station"]]
	local _,_,_,_,_, traitsKnown = GetSmithingPatternInfo(patternIndex)
	local traitsRequired = GetSetIndexes()[craftRequestTable["setIndex"]][3]

	local level, max =  getCraftLevel(craftRequestTable['station'])
	-- check if level is high enough
	local matIndex
	if craftRequestTable['station'] == CRAFTING_TYPE_JEWELRYCRAFTING then
		matIndex = JEWELY_MAT_REQUIREMENT[craftRequestTable['materialIndex']][3]
	else
		matIndex = findMatTierByIndex(craftRequestTable['materialIndex'])
	end
	local missingInd = false
	--CheckInventorySpaceSilently
	if level < matIndex then
		missing['craftSkill'] = true
		missingInd = true
	end
	if traitsRequired> traitsKnown then
		missing.knowledge["traitNumber"] = true
		missingInd = true
	end
	-- Check if the specific trait is known
	if not IsSmithingTraitKnownForResult(patternIndex, craftRequestTable["materialIndex"], craftRequestTable["materialQuantity"],craftRequestTable["style"], craftRequestTable["trait"]) then
		missingInd = true
		missing.knowledge["trait"] = true
	end
	-- Check if the style is known for that piece
	if craftRequestTable["station"] == CRAFTING_TYPE_JEWELRYCRAFTING or craftRequestTable["style"]==LLC_FREE_STYLE_CHOICE or IsSmithingStyleKnown(craftRequestTable["style"], craftRequestTable["pattern"]) then
	else
		missingInd = true
		missing.knowledge["style"] = true
	end
	if not CheckInventorySpaceSilently(1) then
		missingInd = true
		missing.inventorySpace = true
	end
	if missingInd then
		return false, missing
	else
		return true
	end
end

-- Returns SetIndex, Set Full Name, Traits Required
local function GetCurrentSetInteractionIndex()
	local baseSetPatternName
	local itemLink
	local currentStation = GetCraftingInteractionType()
	-- Get info based on what station it is.
	if currentStation == CRAFTING_TYPE_BLACKSMITHING then
		itemLink = GetSmithingPatternResultLink(15,1,3,1,1,0)
	elseif currentStation == CRAFTING_TYPE_CLOTHIER then
		itemLink = GetSmithingPatternResultLink(16,1,7,1,1,0)
	elseif currentStation == CRAFTING_TYPE_WOODWORKING then
		itemLink = GetSmithingPatternResultLink(7,1,3,1,1,0)
	elseif currentStation == CRAFTING_TYPE_JEWELRYCRAFTING then
		itemLink = GetSmithingPatternResultLink(4,1,3,nil,1,0)
	else
		return nil , nil, nil, nil
	end
	local hasSet, setName, _,_,_, id = GetItemLinkSetInfo(itemLink)
	local traitsNeeded = SetIndexes[id][3]
	if hasSet then
		return id, setName, traitsNeeded
	else
		return INDEX_NO_SET, "No Set",  0
	end
	
end
LibLazyCrafting.functionTable.GetCurrentSetInteractionIndex  = GetCurrentSetInteractionIndex

-- Can an item be crafted here, based on set and station indexes
local function canCraftItemHere(station, setIndex)

	if not setIndex then setIndex = INDEX_NO_SET end

	if GetCraftingInteractionType()==station then
		if IsConsolidatedSmithingItemSetIdUnlocked(setIndex) then
			return true
		end

		if GetCurrentSetInteractionIndex()==setIndex or setIndex==INDEX_NO_SET then
			return true
		end
	end
	return false

end
LibLazyCrafting.canCraftSmithingItemHere = canCraftItemHere

---------------------------------
-- SMITHING HELPER FUNCTIONS

local function GetMaxImprovementMats(bag, slot ,station)
	local numBooster = 0
	local chance =0
	if not CanItemBeSmithingImproved(bag, slot, station) then return false end
	while chance<100 do
		numBooster = numBooster + 1
		chance = GetSmithingImprovementChance(bag, slot, numBooster,station)

	end
	return numBooster
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




local function GetMatRequirements(pattern, index, station)
	if station == nil then station = GetCraftingInteractionType() end
	local mats
	if station == CRAFTING_TYPE_JEWELRYCRAFTING then
		mats = JEWELY_MAT_REQUIREMENT[index][pattern]
		return mats
	end
	mats = baseRequirements[index] + additionalRequirements[station][pattern]
	-- Deal with the exceptions in the material amount patterns
	if station == CRAFTING_TYPE_WOODWORKING and pattern ~= 2 and index >=40 then
		mats = mats + 1
	end
	if station == CRAFTING_TYPE_BLACKSMITHING and pattern ==12 and index <13 and index >=8 then
		mats = mats - 1
	end

	if station == CRAFTING_TYPE_BLACKSMITHING and pattern >=4 and pattern <=6 and index >= 40 then
		mats = mats + 1
	end

	if index==41 then
		mats = mats*10
	end
	return mats
end

LibLazyCrafting.functionTable.GetMatRequirements = GetMatRequirements

local function getImprovementLevel(station)
	local SkillTextures =
	{
		[CRAFTING_TYPE_BLACKSMITHING] = "/esoui/art/icons/ability_smith_004.dds", -- bs, temper expertise esoui/art/icons/ability_smith_004.dds
		[CRAFTING_TYPE_CLOTHIER] = "/esoui/art/icons/ability_tradecraft_004.dds", -- cl, tannin expertise esoui/art/icons/ability_tradecraft_004.dds
		[CRAFTING_TYPE_WOODWORKING] = "/esoui/art/icons/ability_tradecraft_001.dds", -- ww, rosin experise esoui/art/icons/ability_tradecraft_001.dds
		[CRAFTING_TYPE_JEWELRYCRAFTING] = "/esoui/art/icons/passive_platingexpertise.dds" -- jw, platings expertise /esoui/art/icons/passive_platingexpertise.dds
	}
	local skillType, skillIndex = GetCraftingSkillLineIndices(station)
	local abilityIndex = nil
	for i = 1, GetNumSkillAbilities(skillType, skillIndex) do
		local _, texture = GetSkillAbilityInfo(skillType, skillIndex, i)
		if texture == SkillTextures[station] then
			abilityIndex = i
		end
	end
	if abilityIndex then

		local currentSkill, maxSkill = GetSkillAbilityUpgradeInfo(skillType,skillIndex,abilityIndex)

		return currentSkill , maxSkill
	else
		return 0,1
	end
end

---------------------------------
-- SMITHING CRAFTING FUNCTIONS
---------------------------------
---------------------------------



-- When crafting jewelry:
-- pass anything for styleIndex
-- pass 1 + ITEM_TRAIT_TYPE_JEWELRY_XXX for whatever trait you want (or just 1 for no trait)
-- ITEM_TRAIT_TYPE_JEWELRY_ARCANE       = 22
-- ITEM_TRAIT_TYPE_JEWELRY_HEALTHY      = 21
-- ITEM_TRAIT_TYPE_JEWELRY_ROBUST       = 23
-- ITEM_TRAIT_TYPE_JEWELRY_TRIUNE       = 30
-- ITEM_TRAIT_TYPE_JEWELRY_INFUSED      = 33
-- ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE   = 32
-- ITEM_TRAIT_TYPE_JEWELRY_SWIFT        = 28
-- ITEM_TRAIT_TYPE_JEWELRY_HARMONY      = 29
-- ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY = 31

-- Currently enchantment is non functional, but present as a palceholder
-- Not sure what the enchantId you want is?
--	Take the glyph for that enchantment, or an item with that enchantment, and run it through GetItemLinkFinalEnchantId( itemLink ))
-- The number it returns is the enchant Id!

-- /script local c = 0 for i = 1, 1000 do local a = GetEnchantSearchCategoryType( i ) if a~=0 then d("i: "..i.." search: ".. a) c = c+1 end end d(c)
LLC_FREE_STYLE_CHOICE = "free style choice"
local function LLC_CraftSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, autocraft, reference, potencyId, essenceId, aspectId, smithingQuantity)
	dbug("FUNCTION:LLCSmithing")
-- /script local o = ZO_Menu_SetLastCommandWasFromMenu ZO_Menu_SetLastCommandWasFromMenu = function(...)ZO_ChatWindowTextEntryEditBox:SetText("Hi")ZO_ChatWindowTextEntryEditBox.addonChangedText = false o(...) end
-- /script local a = true local o = ZO_ChatWindowTextEntryEditBox.GetText ZO_ChatWindowTextEntryEditBox.GetText = function(...)ZO_ChatWindowTextEntryEditBox.addonChangedText = false if a then a = false return "blabla" else return o(...) end end
	if reference == nil then reference = "" end
	if not self then d("Please call with colon notation") end
	if autocraft==nil then autocraft = self.autocraft end
	local station
	if type(self) == "number" then
		d("LLC: Please call using colon notation: e.g LLC:CraftSmithingItem(). If you are seeing this and you are not a developer please contact the author of the addon")
	end
	if styleIndex == LLC_FREE_STYLE_CHOICE and not self.styleTable then
		error("You must specify a style table to use this option when you add your addon to the library")

	end

	local validStations =
	{
		[CRAFTING_TYPE_BLACKSMITHING]  = true,
		[CRAFTING_TYPE_WOODWORKING]  = true,
		[CRAFTING_TYPE_CLOTHIER]  = true,
		[CRAFTING_TYPE_JEWELRYCRAFTING]  = true,
	}
	if not validStations[stationOverride] then
		station = GetCraftingInteractionType()
		if not validStations[station] then
			d("LLC: No station specified, and you are not at a crafting station")
			throw(self, "No station specified, and you are not at a crafting station")
			return
		end
	else
		station =stationOverride
	end
	--Handle the extra values. If they're nil, assign default values.
	if not setIndex then setIndex = INDEX_NO_SET end
	if not quality then quality = 0 end

	-- create smithing request table and add to the queue
	if self.addonName=="LLC_Global" then d("Item added") end
	local requestTable 
	if potencyId and essenceId and aspectId then
		requestTable = LibLazyCrafting.functionTable.CraftEnchantingItemId(self,potencyId, essenceId, aspectId, autocraft, reference )
		requestTable['dualEnchantingSmithing'] = true
		requestTable['equipInfo'] = requestTable['equipInfo'] or {}
		requestTable['glyphInfo'] = requestTable['glyphInfo'] or {}
	elseif potencyId or essenceId or aspectId then
		d("Only partial enchanting traits specified. Aborting craft")
		return
	else
		requestTable = {}
	end
	
	requestTable["type"] = "smithing"
	requestTable["pattern"] =patternIndex
	requestTable["style"] = styleIndex
	requestTable["trait"] = traitIndex
	requestTable["materialIndex"] = materialIndex
	requestTable["materialQuantity"] = materialQuantity
	requestTable["station"] = station
	requestTable["setIndex"] = setIndex
	requestTable["quality"] = quality
	requestTable["useUniversalStyleItem"] = useUniversalStyleItem
	requestTable["timestamp"] = LibLazyCrafting.GetNextQueueOrder()
	requestTable["autocraft"] = autocraft
	requestTable["Requester"] = self.addonName
	requestTable["reference"] = reference
	requestTable["smithingQuantity"] = smithingQuantity or 1
	requestTable["initialQuantity"] = quantity
	if GetSetIndexes()[setIndex] and GetSetIndexes()[setIndex].isSwapped and station == CRAFTING_TYPE_JEWELRYCRAFTING then -- New Moon Acolyte pattern indexes are swapped for jewelry!
		if requestTable.pattern == 1 then
			requestTable.pattern = 2
		else
			requestTable.pattern = 1
		end
	end
	LibLazyCrafting.AddHomeMarker(setIndex, station)
	table.insert(craftingQueue[self.addonName][station],requestTable)

	--sortCraftQueue()
	if not IsPerformingCraftProcess() and GetCraftingInteractionType()~=0 then
		LibLazyCrafting.craftInteract(nil, GetCraftingInteractionType())
	end

	return requestTable
end

local function isValidLevel(isCP, lvl)
	if lvl == 2 then return false end
	if isCP then
		if lvl %10 ~= 0 then  return  false end
		if lvl > 160 or lvl <10 then  return false  end
	else
		if lvl % 2 ~=0 and lvl ~= 1 then return false end
		if lvl <1 or lvl > 50 then return false end
	end
	return true
end

LibLazyCrafting.functionTable.isSmithingLevelValid = isValidLevel

local function LLC_CraftSmithingItemByLevel(self, patternIndex, isCP , level, styleIndex, traitIndex, 
	useUniversalStyleItem, stationOverride, setIndex, quality, autocraft, reference, potencyId, essenceId, aspectId, smithingQuantity)

	if isValidLevel( isCP ,level) then
		local materialIndex = findMatIndex(level, isCP)

		local materialQuantity = GetMatRequirements(patternIndex, materialIndex, stationOverride)

		return LLC_CraftSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, stationOverride, setIndex, quality, autocraft, reference, potencyId, essenceId, aspectId, smithingQuantity)
	else
	end
end



LibLazyCrafting.functionTable.CraftSmithingItem = LLC_CraftSmithingItem
LibLazyCrafting.functionTable.CraftSmithingItemByLevel = LLC_CraftSmithingItemByLevel
-- /script local a = {1, 16, 36} for i = 1, 3 do LLC_Global:CraftSmithingItemByLevel(5, false, a[i],3 ,ITEM_TRAIT_TYPE_ARMOR_TRAINING ,false, CRAFTING_TYPE_CLOTHIER, 0, ITEM_QUALITY_ARCANE,true) end
-- /script LLC_Global:CraftSmithingItemByLevel(3, false, 4,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 2,true, nil, nil, nil,nil, 2)
-- /script for i= 2, 25 do LLC_Global:CraftSmithingItemByLevel(3, false, i*2,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 3,true) end
-- /script LLC_Global:CraftSmithingItemByLevel(3, true, 140,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 5,true)


-- We do take the bag and slot index here, because we need to know what to upgrade
local function InternalImproveSmithingItem(self, BagIndex, SlotIndex, newQuality, autocraft, reference, existingRequestTable)
	dbug("FUNCTION:LLCImprove")
	if reference == nil then reference = "" end
	--abc = abc + 1 if abc>50 then d("improve")return end
	local station = -1
	for i = 1, 7 do
		if CanItemBeSmithingImproved(BagIndex, SlotIndex,i) then
			station = i
		end
	end
	if station == -1 then d("Cannot be improved") return end
	if autocraft==nil then autocraft = self.autocraft end
	local station = GetRearchLineInfoFromRetraitItem(BagIndex, SlotIndex)
	local craftingRequestTable
	-- if existingRequestTable then
	-- 	craftingRequestTable = existingRequestTable
	-- else
		craftingRequestTable = {}
	-- end

	craftingRequestTable["type"] = "improvement"
	craftingRequestTable["Requester"] = self.addonName -- ADDON NAME
	craftingRequestTable["autocraft"] = autocraft
	craftingRequestTable["ItemLink"] = GetItemLink(BagIndex, SlotIndex)
	craftingRequestTable["ItemBagID"] = BagIndex
	craftingRequestTable["ItemSlotID"] = SlotIndex
	craftingRequestTable["itemUniqueId"] = GetItemUniqueId(BagIndex, SlotIndex)
	craftingRequestTable['itemStringUniqueId'] = Id64ToString(craftingRequestTable['itemUniqueId'])
	craftingRequestTable["ItemCreater"] = GetItemCreatorName(BagIndex, SlotIndex)
	craftingRequestTable["quality"] = newQuality
	craftingRequestTable["reference"] = reference
	craftingRequestTable["station"] = station
	craftingRequestTable["timestamp"] = LibLazyCrafting.GetNextQueueOrder()
	craftingRequestTable["smithingQuantity"] = 1
	if existingRequestTable then
		craftingRequestTable.dualEnchantingSmithing = existingRequestTable.dualEnchantingSmithing
		craftingRequestTable["equipInfo"] = existingRequestTable["equipInfo"] or {}
		craftingRequestTable["glyphInfo"] = existingRequestTable["glyphInfo"] or {}
		craftingRequestTable.potencyItemID = existingRequestTable.potencyItemID
		craftingRequestTable.essenceItemID = existingRequestTable.essenceItemID
		craftingRequestTable.aspectItemID = existingRequestTable.aspectItemID
		craftingRequestTable.quantity = existingRequestTable.quantity
		craftingRequestTable['craftNow'] = existingRequestTable['craftNow']
	end

	table.insert(craftingQueue[self.addonName][station], craftingRequestTable)
	--sortCraftQueue()
	if not IsPerformingCraftProcess() and GetCraftingInteractionType()~=0 and not LibLazyCrafting.isCurrentlyCrafting[1] then
		LibLazyCrafting.craftInteract(nil, GetCraftingInteractionType())
	end
	return craftingRequestTable
end

local function LLC_ImproveSmithingItem(self, BagIndex, SlotIndex, newQuality, autocraft, reference)
	InternalImproveSmithingItem(self, BagIndex, SlotIndex, newQuality, autocraft, reference)
end

local function LLC_AddExistingGlyphToGear(self, existingRequestTable, glyphBag, glyphSlot)
	existingRequestTable['dualEnchantingSmithing'] = true
	existingRequestTable['glyphUniqueId'] = GetItemUniqueId(glyphBag, glyphSlot)
	existingRequestTable['glyphStringUniqueId'] = Id64ToString(existingRequestTable['glyphUniqueId'])
	existingRequestTable.glyphCreated = true
	return
end


local function LLC_DeconstructItem(self, bagIndex, slotIndex, autocraft, reference)
	local station = nil
	for i = 1, 7 do
		if CanItemBeDeconstructed(bagIndex, slotIndex, i) then
			station = i
		end
	end
	if not station then
		d(GetItemLink(bagIndex, slotIndex)+" cannot be deconstructed at any crafting station. It may not be possible to deconstruct this item")
	end
	
	local craftingRequestTable = 
	{
		["reference"] = reference or "",
		["autocraft"] = autocraft or true,
		["ItemLink"] = GetItemLink(bagIndex, slotIndex),
		["itemUniqueId"] = GetItemUniqueId(bagIndex, slotIndex),
		['itemStringUniqueId'] = Id64ToString(GetItemUniqueId(bagIndex, slotIndex)),
		["station"] = station,
		["timestamp"] = LibLazyCrafting.GetNextQueueOrder(),
		["slotIndex"] = slotIndex,
		["bagIndex"] = bagIndex,
		["Requester"] = self.addonName,
		["type"] = "deconstruct"
	}
	table.insert(craftingQueue[self.addonName][station], craftingRequestTable)
	if not IsPerformingCraftProcess() and GetCraftingInteractionType()~=0 and not LibLazyCrafting.isCurrentlyCrafting[1] then
		LibLazyCrafting.craftInteract(nil, GetCraftingInteractionType())
	end
	return craftingRequestTable
end

LibLazyCrafting.functionTable.DeconstructSmithingItem = LLC_DeconstructItem

LibLazyCrafting.functionTable.AddExistingGlyphToGear = LLC_AddExistingGlyph

LibLazyCrafting.functionTable.ImproveSmithingItem = LLC_ImproveSmithingItem
-- Examples
-- /script for i = 1, 200 do if GetItemTrait(1,i)==20 or GetItemTrait(1,i)==9 then LLC_Global:ImproveSmithingItem(1,i,3,true) d("Improve") end end
-- /script for i = 1, 200 do if GetItemTrait(1,i)==20 or GetItemTrait(1,i)==9 then LLC_ImproveSmithingItem(LLC_Global, 1,i,3,true) d("Improve") end end


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

-- Ideas to increase Queue Accuracy:
--		previousCraftAttempt/check for currentCraftAttempt = {}

local setLookupTable = {}
local function generateSetLookupTable()
	for tableSetIndexes = 1, GetNumConsolidatedSmithingSets() do
		setLookupTable[GetConsolidatedSmithingItemSetIdByIndex(tableSetIndexes)] = tableSetIndexes
	end
end


local function setCorrectSetIndex_ConsolidatedStation(setIndex)
	if not ZO_Smithing_IsConsolidatedStationCraftingMode() then
		return
	end
	if GetActiveConsolidatedSmithingItemSetId() == setIndex or setIndex==INDEX_NO_SET then
		return
	end
	--
	if setLookupTable[setIndex] == nil then
		generateSetLookupTable()
	end
	if IsInGamepadPreferredMode() then
		SetActiveConsolidatedSmithingSetByIndex(setLookupTable[setIndex])
		pcall(function() SMITHING_GAMEPAD:RefreshSetSelector() end)
		pcall(function() SMITHING_GAMEPAD.header.tabBar:SetSelectedIndex(1) end )
	else
		SMITHING.setSearchBox:SetText("")
		ZO_ClearTable(SMITHING.setFilters)
		SMITHING:RefreshSetCategories()
		SMITHING.categoryTree:SelectNode( SMITHING.setNodeLookupData[setIndex])
		
		
	end
end


-------------------------------------------------------
-- SMITHING INTERACTION FUNCTIONS

local craftingSounds = 
{
	[CRAFTING_TYPE_BLACKSMITHING] = "Blacksmith_Create_Tooltip_Glow",
	[CRAFTING_TYPE_CLOTHIER] = "Clothier_Create_Tooltip_Glow",
	[CRAFTING_TYPE_WOODWORKING] = "Woodworker_Create_Tooltip_Glow",
	[CRAFTING_TYPE_JEWELRYCRAFTING] = "JewelryCrafter_Create_Tooltip_Glow",
	["improve"] = "Crafting_Create_Slot_Animated",

}

local function LLC_Smithing_MinorModuleInteraction(station, earliest, addon, position)
	local parameters = {
		earliest.pattern,
		earliest.materialIndex,
		earliest.materialQuantity,
		earliest.style,
		earliest.trait,
		earliest.useUniversalStyleItem,
		1,
	}
	setCorrectSetIndex_ConsolidatedStation(earliest.setIndex)
	if earliest.style == LLC_FREE_STYLE_CHOICE then
		parameters[4] = maxStyle(earliest)
	end
	local setPatternOffset = {14, 15,[6]=6,[7]=2}
	if earliest.setIndex~=INDEX_NO_SET then
		parameters[1] = parameters[1] + setPatternOffset[station]
	end
	parameters[7] = math.min(GetMaxIterationsPossibleForSmithingItem(unpack(parameters)), earliest.smithingQuantity or 1)
	if (earliest.smithingQuantity or 1) > GetMaxIterationsPossibleForSmithingItem(unpack(parameters)) then
		d("Mismatch asked quantity: "..earliest.smithingQuantity.." actual max "..GetMaxIterationsPossibleForSmithingItem(unpack(parameters)))
	end
	if parameters[7] == 0 then
		return
	end
	dbug("CALL:ZOCraftSmithing")

	LibLazyCrafting.isCurrentlyCrafting = {true, "smithing", earliest["Requester"]}
	LibLazyCrafting:setWatchingForNewItems (true)

	hasNewItemBeenMade = false

	if IsInGamepadPreferredMode() then -- Gamepad seems to not play craft sounds
		PlaySound(craftingSounds[station])
	end
	CraftSmithingItem(unpack(parameters))
	-- d(unpack(parameters))

	currentCraftAttempt = copy(earliest)
	currentCraftAttempt.position = position
	currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
	currentCraftAttempt.slot = FindFirstEmptySlotInBag(BAG_BACKPACK)

	parameters[6] = LINK_STYLE_DEFAULT

	currentCraftAttempt.link = GetSmithingPatternResultLink(unpack(parameters))
	--d("Making reference #"..tostring(currentCraftAttempt.reference).." link: "..currentCraftAttempt.link)
end

local function LLC_improvement_MinorModuleInteraction(station, earliest, addon, position)
	local parameters = {}
	local currentSkill, maxSkill = getImprovementLevel(station)
	local currentItemQuality = GetItemLinkQuality(GetItemLink(earliest.ItemBagID, earliest.ItemSlotID))
	if earliest.quality == currentItemQuality then
		dbug("ACTION:RemoveImprovementRequest")
		d("Item is already at final quality, but LLC did not improve the item. It may have been improved by the user or another addon")
		local returnTable = table.remove(craftingQueue[addon][station],position )
		returnTable.bag = BAG_BACKPACK
		LibLazyCrafting.SendCraftEvent( LLC_CRAFT_SUCCESS ,  station,addon , returnTable )


		currentCraftAttempt = {}
		--sortCraftQueue()
		LibLazyCrafting.craftInteract(nil, station)
		LibLazyCrafting.DeleteHomeMarker(returnTable.setIndex, station)
		return
	end
	if currentSkill~=maxSkill then
		-- cancel if quality is already blue and skill is not max
		-- This is to save on improvement mats.

		if earliest.quality>2 and currentItemQuality >ITEM_QUALITY_MAGIC then
			d("Improvement skill is not at maximum. Improvement prevented to save mats.")
			return
		end
		if station == CRAFTING_TYPE_JEWELRYCRAFTING and earliest.quality>1 and currentItemQuality >ITEM_QUALITY_NORMAL then
			d("Improvement skill is not at maximum. Improvement prevented to save mats.")
			return
		end
	end
	local numBooster = GetMaxImprovementMats( earliest.ItemBagID,earliest.ItemSlotID,station)
	if not numBooster then return end
	local _,_, stackSize = GetSmithingImprovementItemInfo(station, currentItemQuality)
	if stackSize< numBooster then
		d("Not enough improvement mats")
		return end
	dbug("CALL:ZOImprovement")
	LibLazyCrafting.isCurrentlyCrafting = {true, "improve", earliest["Requester"]}
	if IsInGamepadPreferredMode() then
		PlaySound(craftingSounds.improve)
	end
	ImproveSmithingItem(earliest.ItemBagID,earliest.ItemSlotID, numBooster)
	currentCraftAttempt = copy(earliest)
	currentCraftAttempt.position = position
	currentCraftAttempt.callback = LibLazyCrafting.craftResultFunctions[addon]
	currentCraftAttempt.previousQuality = currentItemQuality

	currentCraftAttempt.link = GetSmithingImprovedItemLink(earliest.ItemBagID, earliest.ItemSlotID, station)
end

local function findAllDeconstructable()
end

	-- ["reference"] = reference or "",
	-- ["autocraft"] = autocraft or true,
	-- ["ItemLink"] = GetItemLink(bagIndex, slotIndex),
	-- ["itemUniqueId"] = GetItemUniqueId(bagIndex, slotIndex),
	-- ['itemStringUniqueId'] = Id64ToString(GetItemUniqueId(bagIndex, slotIndex)),
	-- ["station"] = station,
	-- ["timestamp"] = LibLazyCrafting.GetNextQueueOrder(),
	-- ["type"] = "deconstruct"
local function LLC_Deconstruction_MinorModuleInteraction(station, earliest, addon, position)
	if GetItemUniqueId(earliest.bagIndex, earliest.slotIndex) == earliest.itemUniqueId then
		currentCraftAttempt = {}
		currentCraftAttempt = copy(earliest)
		PrepareDeconstructMessage() 
		AddItemToDeconstructMessage(earliest.bagIndex, earliest.slotIndex, 1)  
		SendDeconstructMessage()
	end
	dbug("Not implemented yet")

end

local function LLC_Research_MinorModuleInteraction(station, earliest, addon, position)
	dbug("Not implemented yet")
end

local smithingMinorModuleFunctions = 
{
	["smithing"] = LLC_Smithing_MinorModuleInteraction,
	["improvement"] = LLC_improvement_MinorModuleInteraction,
	["deconstruct"] = LLC_Deconstruction_MinorModuleInteraction,
	["research"] = LLC_Research_MinorModuleInteraction,

}

local hasNewItemBeenMade = false

local function LLC_SmithingCraftInteraction( station, earliest, addon , position)
	dbug("EVENT:CraftIntBegin")
	--abc = abc + 1 if abc>50 then d("raft")return end

	local earliest, addon , position = LibLazyCrafting.findEarliestRequest(station)
	if earliest and not IsPerformingCraftProcess() then
		smithingMinorModuleFunctions[earliest.type](station, earliest, addon, position)
			--ImproveSmithingItem(number itemToImproveBagId, number itemToImproveSlotIndex, number numBoostersToUse)
			--GetSmithingImprovedItemLink(number itemToImproveBagId, number itemToImproveSlotIndex, number TradeskillType craftingSkillType, number LinkStyle linkStyle)
	else
		LibLazyCrafting.SendCraftEvent( LLC_NO_FURTHER_CRAFT_POSSIBLE,  station)
	end

end
-- check ItemID and style

local function WasItemCrafted(bag, slot)
	dbug("CHECK:WasItemCrafted")
	--abc = abc + 1 if abc>50 then d("wascrafted")return end
	local checkPosition = {BAG_BACKPACK, slot}
	if GetItemName(unpack(checkPosition))==GetItemLinkName(currentCraftAttempt.link) then
		if GetItemLinkQuality(GetItemLink(unpack(checkPosition))) ==ITEM_QUALITY_NORMAL then
			if GetItemRequiredLevel(unpack(checkPosition))== GetItemLinkRequiredLevel(currentCraftAttempt.link) then
				if GetItemRequiredChampionPoints(unpack(checkPosition)) == GetItemLinkRequiredChampionPoints(currentCraftAttempt.link) then
					if GetItemId(unpack(checkPosition)) == GetItemLinkItemId(currentCraftAttempt.link) then
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
local function WasItemImproved(currentCraftAttempt)
		--GetItemLinkQuality(GetItemLink(earliest.ItemBagID, earliest.ItemSlotID))
	return GetItemLinkQuality(GetItemLink(currentCraftAttempt.ItemBagID,currentCraftAttempt.ItemSlotID))==currentCraftAttempt.quality

end
local backupPosition

local function removedRequest(station, timestamp)
	for addon, requestTable in pairs(craftingQueue) do
		for i = 1, #requestTable[station] do
			if requestTable[station][i]["timestamp"] == timestamp then
				return addon, i
			end
		end
	end
	d("Request to remove not found")
	return nil, 0
end

local function smithingCompleteNewItemHandler(station, bag, slot)

	dbug("ACTION:RemoveRequest")
	local addonName, position = removedRequest(station, currentCraftAttempt.timestamp)
	local removedRequest
	if addonName then
		if (currentCraftAttempt.smithingQuantity or 1) <= 1 then
			removedRequest =  table.remove(craftingQueue[addonName][station],position)
			removedRequest.smithingQuantity = removedRequest.smithingQuantity - 1
			currentCraftAttempt.smithingQuantity = currentCraftAttempt.smithingQuantity - 1
		else
			removedRequest =  craftingQueue[addonName][station][position]
			removedRequest.smithingQuantity = removedRequest.smithingQuantity - 1
			currentCraftAttempt.smithingQuantity = currentCraftAttempt.smithingQuantity - 1
		end
		if currentCraftAttempt.quality>1 then
			-- d("Improving #".. tostring(currentCraftAttempt.reference))

			if removedRequest.dualEnchantingSmithing then
				table.insert(removedRequest.equipInfo,
				{
					bag=BAG_BACKPACK,
					slot=slot,
					uniqueId=GetItemUniqueId(BAG_BACKPACK, slot),
					uniqueIdString = Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot)),
				})
				removedRequest["craftNow"] = true
				InternalImproveSmithingItem({["addonName"]=currentCraftAttempt.Requester}, BAG_BACKPACK, slot, currentCraftAttempt.quality, 
					currentCraftAttempt.autocraft, currentCraftAttempt.reference, removedRequest)
				LibLazyCrafting.SendCraftEvent(LLC_INITIAL_CRAFT_SUCCESS, station, currentCraftAttempt.Requester, removedRequest)
				
				LibLazyCrafting.DeleteHomeMarker(removedRequest.setIndex, station)
				return
			end

			local requestTable = LLC_ImproveSmithingItem({["addonName"]=currentCraftAttempt.Requester}, BAG_BACKPACK, slot, currentCraftAttempt.quality, currentCraftAttempt.autocraft, currentCraftAttempt.reference)
			removedRequest["craftNow"] = true
			local copiedTable = LibLazyCrafting.tableShallowCopy(removedRequest)
			copiedTable.slot = slot
			copiedTable.smithingQuantity = 1
			LibLazyCrafting.DeleteHomeMarker(removedRequest.setIndex, station)
			LibLazyCrafting.AddHomeMarker(INDEX_NO_SET, station)
			LibLazyCrafting.SendCraftEvent(LLC_INITIAL_CRAFT_SUCCESS, station, currentCraftAttempt.Requester, copiedTable)
		else
			removedRequest.bag = BAG_BACKPACK
			removedRequest.slot = slot
			if removedRequest.dualEnchantingSmithing then
				table.insert(removedRequest.equipInfo,
				{
					bag=BAG_BACKPACK,
					slot=slot,
					uniqueId=GetItemUniqueId(BAG_BACKPACK, slot),
					uniqueIdString = Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot)),
				})
				removedRequest.equipCreated = true
				if removedRequest.glyphInfo and #removedRequest.glyphInfo>0 then
					LibLazyCrafting.applyGlyphToItem(removedRequest)
					return
				else
					local copiedTable = LibLazyCrafting.tableShallowCopy(removedRequest)
					copiedTable.slot = slot
					copiedTable.smithingQuantity = 1
					LibLazyCrafting.SendCraftEvent( LLC_INITIAL_CRAFT_SUCCESS,  station,removedRequest.Requester, copiedTable )
					return
				end
			end
			local copiedTable = LibLazyCrafting.tableShallowCopy(removedRequest)
			copiedTable.slot = slot
			copiedTable.smithingQuantity = 1

			LibLazyCrafting.DeleteHomeMarker(removedRequest.setIndex, station)
			LibLazyCrafting.SendCraftEvent(LLC_CRAFT_SUCCESS, station, removedRequest.Requester, copiedTable )
		end
	else
		d("Bad craft remove")
	end
end



local function SmithingCraftCompleteFunction(station)
	dbug("EVENT:CraftComplete")

	if currentCraftAttempt.type == "smithing" and hasNewItemBeenMade then
		hasNewItemBeenMade = false
		local bag, slot = LibLazyCrafting.findNextSlotIndex(WasItemCrafted)
		while slot ~= nil do
			smithingCompleteNewItemHandler(station, bag, slot)
			bag, slot = LibLazyCrafting.findNextSlotIndex(WasItemCrafted, slot+1)
		end
		currentCraftAttempt = {}
		--sortCraftQueue()
		backupPosition = nil

	elseif currentCraftAttempt.type == "improvement" then

		if WasItemImproved(currentCraftAttempt) then
			local returnTable
			local addonName, position = removedRequest(station, currentCraftAttempt.timestamp)
			if addonName then
				returnTable =  table.remove(craftingQueue[addonName][station],position)
				returnTable.bag=returnTable.ItemBagID
				returnTable.slot=returnTable.ItemSlotID
				returnTable.bag = BAG_BACKPACK
				if returnTable.dualEnchantingSmithing then
					-- don't need to re-add to equipInfo table bc it should already be there
					currentCraftAttempt = {}

					if returnTable.glyphInfo and #returnTable.glyphInfo>0 then
						LibLazyCrafting.applyGlyphToItem(returnTable)
					else
						LibLazyCrafting:SetItemStatusNew(returnTable.ItemSlotID)
						local copiedTable = LibLazyCrafting.tableShallowCopy(returnTable)
						copiedTable.slot = slot
						copiedTable.smithingQuantity = 1
						LibLazyCrafting.SendCraftEvent( LLC_INITIAL_CRAFT_SUCCESS,  station,copiedTable.Requester, copiedTable )
					end

					LibLazyCrafting.DeleteHomeMarker(returnTable.setIndex, station)
					return
				end
				LibLazyCrafting.SendCraftEvent( LLC_CRAFT_SUCCESS,  station,returnTable.Requester, returnTable )

				LibLazyCrafting.DeleteHomeMarker(returnTable.setIndex, station)
			else
				d("Bad request. No addon attached to crafting request")
			end
		elseif GetItemLinkQuality(GetItemLink(currentCraftAttempt.ItemBagID,currentCraftAttempt.ItemSlotID)) > currentCraftAttempt.previousQuality then
			LibLazyCrafting.SendCraftEvent( LLC_CRAFT_PARTIAL_IMPROVEMENT,  station,currentCraftAttempt.Requester, currentCraftAttempt )
		end
		currentCraftAttempt = {}
		--sortCraftQueue()
		backupPosition = nil
		-- ["reference"] = reference or "",
		-- ["autocraft"] = autocraft or true,
		-- ["ItemLink"] = GetItemLink(bagIndex, slotIndex),
		-- ["itemUniqueId"] = GetItemUniqueId(bagIndex, slotIndex),
		-- ['itemStringUniqueId'] = Id64ToString(GetItemUniqueId(bagIndex, slotIndex)),
		-- ["station"] = station,
		-- ["timestamp"] = LibLazyCrafting.GetNextQueueOrder(),
		-- ["type"] = "deconstruct"
		-- LLC_Global:DeconstructSmithingItem
	elseif currentCraftAttempt.type == "deconstruct" then
		local id64 = GetItemUniqueId(currentCraftAttempt.bagIndex, currentCraftAttempt.slotIndex)
		if id64 ~= currentCraftAttempt.itemUniqueId then
			local addonName, position = removedRequest(station, currentCraftAttempt.timestamp)
			if addonName then
				returnTable = table.remove(craftingQueue[addonName][station],position)
				local copiedTable = LibLazyCrafting.tableShallowCopy(returnTable)
				LibLazyCrafting.SendCraftEvent(LLC_CRAFT_SUCCESS, station, returnTable.Requester, copiedTable )
			end
		end
		currentCraftAttempt = {}
		backupPosition = nil

	else
		return
	end
end



local function slotUpdateHandler(event, bag, slot, isNew, itemSoundCategory, inventoryUpdateReason, stackCountChange)

	if not isNew then return end

	if stackCountChange ~= 1 then return end
	local itemType = GetItemType(bag, slot)
	if itemType ==ITEMTYPE_ARMOR or itemType ==ITEMTYPE_WEAPON then else return end
	hasNewItemBeenMade = true
	if LibLazyCrafting.IsPerformingCraftProcess() and ( currentCraftAttempt.slot ~= slot or not currentCraftAttempt.slot ) then
		backupPosition = slot

	end
	if currentCraftAttempt.slot ~= slot or not currentCraftAttempt.slot  then
		backupPosition = slot

	end
end
EVENT_MANAGER:UnregisterForEvent(LibLazyCrafting.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
EVENT_MANAGER:RegisterForEvent(LibLazyCrafting.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, slotUpdateHandler)
EVENT_MANAGER:AddFilterForEvent(LibLazyCrafting.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
EVENT_MANAGER:AddFilterForEvent(LibLazyCrafting.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)

local compileRequirements

-- First is the name of the set. Second is a table of sample itemIds. Third is the number of required traits.
-- First itemId is for blacksmithing (axe, no trait), second is for clothing, (robe no trait) third is woodworking (Bow, no trait)
-- This is pretty much arbitrary, sorted by when the set was introduced, and how many traits are needed.
-- Declared at the end of the file for cleanliness

-- Language free!!!!

-- For brevity sake, sets are simply listed as 3 item IDs with the number of traits needed.
-- The name of the set is then added in on initialization using the API.
local setInfo =
{ --{{Axe    , Robe  ,  6  = Bow   ,  7  = Necklace},trait_ct},
	{{43529  , 43549 , [6] = 43543 , [7] =  43561},0},  --  1 no set
	{{46499  , 43805 , [6] = 46518 , [7] = 137683},2},  --  2 death's wind
	{{47265  , 47279 , [6] = 47287 , [7] = 137685},2},  --  3 night's silence
	{{49563  , 49575 , [6] = 49583 , [7] = 137691},2},  --  4 ashen grip
	{{50708  , 43979 , [6] = 50727 , [7] = 137694},3},  --  5 torug's pact
	{{46882  , 43808 , [6] = 46901 , [7] = 137684},3},  --  6 twilight's embrace
	{{48031  , 48042 , [6] = 48050 , [7] = 137687},3},  --  7 seducer
	{{48797  , 43849 , [6] = 48816 , [7] = 137689},4},  --  8 magnus' gift
	{{51090  , 51105 , [6] = 51113 , [7] = 137695},4},  --  9 hist bark
	{{47648  , 47663 , [6] = 47671 , [7] = 137686},4},  -- 10 whitestrake's
	{{48414  , 48425 , [6] = 48433 , [7] = 137688},5},  -- 11 vampire's kiss
	{{52233  , 52243 , [6] = 52251 , [7] = 137698},5},  -- 12 song of lamae
	{{52614  , 52624 , [6] = 52632 , [7] = 137699},5},  -- 13 alessia's bulwark
	{{49180  , 49195 , [6] = 49203 , [7] = 137690},6},  -- 14 night mother's gaze
	{{51471  , 51486 , [6] = 51494 , [7] = 137696},6},  -- 15 willow's path
	{{51852  , 51864 , [6] = 51872 , [7] = 137697},6},  -- 16 hunding's rage
	{{53757  , 53772 , [6] = 53780 , [7] = 137702},8},  -- 17 kagrenac's hope
	{{52995  , 53006 , [6] = 53014 , [7] = 137700},8},  -- 18 orgnum's scales
	{{53376  , 44053 , [6] = 53393 , [7] = 137701},8},  -- 19 eyes of mara
	{{54138  , 54149 , [6] = 54157 , [7] = 137703},8},  -- 20 shalidor's curse
	{{49946  , 43968 , [6] = 49964 , [7] = 137692},8},  -- 21 oblivion's foe
	{{50327  , 43972 , [6] = 50345 , [7] = 137693},8},  -- 22 spectre's eye
	{{54965  , 54963 , [6] = 54971 , [7] = 137704},8},  -- 23 way of the arena
	{{58175  , 58174 , [6] = 58182 , [7] = 137705},9},  -- 24 twice-born star
	{{60261  , 60280 , [6] = 60268 , [7] = 137706},5},  -- 25 noble's conquest
	{{60611  , 60630 , [6] = 60618 , [7] = 137707},7},  -- 26 redistributor
	{{60961  , 60980 , [6] = 60968 , [7] = 137708},9},  -- 27 armor master
	{{69949  , 69942 , [6] = 69956 , [7] = 137710},3},  -- 28 trial by fire
	{{69599  , 69592 , [6] = 69606 , [7] = 137709},6},  -- 29 law of julianos
	{{70649  , 70642 , [6] = 70656 , [7] = 137712},9},  -- 30 morkuldin
	{{71813  , 71806 , [6] = 71820 , [7] = 137713},5},  -- 31 tava's favor
	{{72163  , 72156 , [6] = 72170 , [7] = 137714},7},  -- 32 clever alchemist
	{{72513  , 72506 , [6] = 72520 , [7] = 137715},9},  -- 33 eternal hunt
	{{75386  , 75406 , [6] = 75393 , [7] = 137716},5},  -- 34 kvatch gladiator
	{{75736  , 75756 , [6] = 75743 , [7] = 137717},7},  -- 35 varen's legacy
	{{76086  , 76106 , [6] = 76093 , [7] = 137718},9},  -- 36 pelinal's aptitude
	{{121551 , 121571, [6] = 121558, [7] = 137719},3},  -- 37 assassin's guile
	{{122251 , 122271, [6] = 122258, [7] = 137721},6},  -- 38 shacklebreaker
	{{121901 , 121921, [6] = 121908, [7] = 137720},8},  -- 39 daedric trickery
	{{131070 , 131090, [6] = 131077, [7] = 137724},6},  -- 40 mechanical acuity
	{{130370 , 130390, [6] = 130377, [7] = 137722},2},  -- 41 innate axiom
	{{130720 , 130740, [6] = 130727, [7] = 137723},4},  -- 42 fortified brass
	{{135717 , 135737, [6] = 135724, [7] = 138714},3},  -- 43 adept rider
	{{136417 , 136437, [6] = 136424, [7] = 138730},9},  -- 44 nocturnal's favor
	{{136067 , 136087, [6] = 136074, [7] = 138722},6},  -- 45 sload's semblance
	{{143161 , 143181, [6] = 143168, [7] = 143197},2},	-- 46 Naga Shaman
	{{143531 , 143551, [6] = 143538, [7] = 143567},4},	-- 47 Might of the Lost Legion
	{{142791 , 142811, [6] = 142798, [7] = 142827},7,},	-- 48 Grave-Stake Collector
	{{147948 , 147968, [6] = 147955, [7] =147984 },8,},	-- 49 Coldharbour's Favourite
	{{148318 , 148338, [6] = 148325, [7] =148354 },5,},	-- 50 Senche Raht's Grit
	{{148688 , 148708, [6] = 148695, [7] =148724 },3,},	-- 51 Vasterie's Tutelage
	{{155778 , 155798, [6] = 155785, [7] =155813 },6,},	-- 52 Ancient Dragonguard
	{{155404 , 155424, [6] = 155411, [7] =155439 },3,},	-- 53 Daring Corsair
	{{156152 , 156172, [6] = 156159, [7] =156187 },3,isSwapped=true},	-- 54 New Moon Acolyte -- Note, set ring and neck are swapped. neck ID is 156188
	{{158546 , 158496, [6] = 158553, [7] =158358 },3,isSwapped=true}, -- 55 Critical Riposte
	{{158920 , 158870, [6] = 158927, [7] =158732 },3,isSwapped=true}, -- 56 Unchained Aggressor
	{{159294 , 159244, [6] = 159301, [7] =159106 },3,isSwapped=true}, -- 57 Dauntless Combatant
	{{161451 , 161401, [6] = 161458, [7] =161263 },3,isSwapped=true}, -- 58 Stuhn's Favor
	{{161825 , 161775, [6] = 161832, [7] =161637 },3,isSwapped=true}, -- 491 Dragon's Appetite
	{{163287 , 163237, [6] = 163294, [7] =163099 },3,isSwapped=true}, -- 506 Spell Parasite
	{{168747 , 168767, [6] = 168754, [7] =168782 },9,isSwapped=true}, -- 541 Aetherial Ascension
	{{168373 , 168393, [6] = 168380, [7] =168408 },6,isSwapped=true}, -- 540 Legacy of Karth
	{{167999 , 168019, [6] = 168006, [7] =168034 },3,isSwapped=true}, -- 539 Red Eagle's Fury
	{{172455 , 172475, [6] = 172462, [7] =172490 },3,isSwapped=true}, -- 582 Hist Whisperer's Song
	{{172829 , 172849, [6] = 172836, [7] =172864 },7,isSwapped=true}, -- 583 Heartland Conquerer
	{{173203 , 173223, [6] = 173210, [7] =173238 },5,isSwapped=true}, -- 584 Diamond's Victory
	{{178806 , 178826, [6] = 178813, [7] =178841 },3,isSwapped=true}, -- 610 Wretched Vitality
	{{179180 , 179200, [6] = 179187, [7] =179215 },7,isSwapped=true}, -- 611 Deadlands Demolisher
	{{179554 , 179574, [6] = 179561, [7] =179589 },5,isSwapped=true}, -- 612 Iron Flask
	{{184771 , 184791, [6] = 184778, [7] =184807 },3,isSwapped=true}, -- 640 Order's Wrath
	{{185151 , 185171, [6] = 185158, [7] =185187 },5,isSwapped=true}, -- 641 Serpent's Disdain
	{{185531 , 185551, [6] = 185538, [7] =185567 },7,isSwapped=true}, -- 642 Druid'd Braid
	{{191232 , 191252, [6] = 191239, [7] =191268 },7,isSwapped=true}, -- 677 Chimera's Rebuke
	{{191612 , 191632, [6] = 191619, [7] =191648 },7,isSwapped=true}, -- 678 Old Growth Brewer
	{{191992 , 192012, [6] = 191999, [7] =192028 },7,isSwapped=true}, -- 679 Claw of the Forest Wraith
	{{194562 , 194582, [6] = 194569, [7] =194598 },7,isSwapped=true}, -- 695 Shattered Fate
	{{194942 , 194962, [6] = 194949, [7] =194978 },7,isSwapped=true}, -- 696 Telvanni Efficiency
	{{195322 , 195342, [6] = 195329, [7] =195358 },7,isSwapped=true}, -- 697 Seeker Synthesis
	{{205393 , 205413, [6] = 205400, [7] =205429 },3,isSwapped=true}, -- 763 Tharriker's Strike
	{{205773 , 205793, [6] = 205780, [7] =205809 },5,isSwapped=true}, -- 764 Highland Sentinel
	{{206153 , 206173, [6] = 206160, [7] =206189 },7,isSwapped=true}, -- 765 Threads of War
}

SetIndexes = {}

for i = 1, #setInfo do
	local _, name,_,_,_, index = GetItemLinkSetInfo(getItemLinkFromItemId(setInfo[i][1][1]),false)

	SetIndexes[index] = setInfo[i]
	SetIndexes[index][3] = index
	if index==INDEX_NO_SET then
		table.insert(SetIndexes[index],1,"No Set")
	else
		table.insert(SetIndexes[index],1,name)
	end


end


--GetItemLinkSetInfo(string itemLink, boolean equipped)
-- Returns: boolean hasSet, string setName, number numBonuses, number numEquipped, number maxEquipped, number setId

-- for i = 1,#SetIndexes do
-- 	local _, a = GetItemLinkSetInfo(getItemLinkFromItemId(SetIndexes[i][1][1]),false)

-- 	table.insert(SetIndexes[i],1,a)
-- end


function GetSetIndexes()

	return SetIndexes
end
LibLazyCrafting.functionTable.GetSetIndexes = GetSetIndexes
LibLazyCrafting.GetSetIndexes = GetSetIndexes

-- IDs for stuff like Sanded Ruby Ash, Iron Ingots, etc.
local materialItemIDs =
{
	[CRAFTING_TYPE_BLACKSMITHING] =
	{
		5413,
		4487,
		23107,
		6000,
		6001,
		46127,
		46128,
		46129,
		46130,
		64489,
	},
	[CRAFTING_TYPE_CLOTHIER] =
	{
		811,
		4463,
		23125,
		23126,
		23127,
		46131,
		46132,
		46133,
		46134,
		64504,
	},
	[3] = -- Leather mats
	{
		794,
		4447,
		23099,
		23100,
		23101,
		46135,
		46136,
		46137,
		46138,
		64506,
	},
	[CRAFTING_TYPE_WOODWORKING] =
	{
		803,
		533,
		23121,
		23122,
		23123,
		46139,
		46140,
		46141,
		46142,
		64502,
	},
	[CRAFTING_TYPE_JEWELRYCRAFTING] =
	{
		135138,
		135140,
		135142,
		135144,
		135146,
	}
}

-- Improvement mats
-- Use GetSmithingImprovementItemLink(number TradeskillType craftingSkillType, number improvementItemIndex, number LinkStyle linkStyle)

local improvementChances =
{
	[0] = {5, 7,10,20},
	[1] = {4,5,7,14},
	[2] = {3,4,5,10},
	[3] = {2,3,4,8},
}


local function compileImprovementRequirements(request, requirements)
	local station = request.station
	requirements = requirements or {}
	if request.equipCreated then
		return requirements
	end
	local currentQuality = GetItemQuality(request.ItemBagID, request.ItemSlotID)
	local improvementLevel = getImprovementLevel(station)

	for i  = currentQuality, request.quality - 1 do
		requirements[GetItemLinkItemId( GetSmithingImprovementItemLink(station, i, 0) )] = improvementChances[improvementLevel][i]
	end
	return requirements
end

function compileRequirements(request, requirements)-- Ingot/style mat/trait mat/improvement mat
	local station = request.station
	if not requirements then
		if request.dualEnchantingSmithing then
			requirements = LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_ENCHANTING]:materialRequirements( request,{})
			if request.smithingQuantity == 0 then
				return requirements
			end
		else
			requirements = {}
		end
	end
	if request["type"] == "smithing" then

		local matId = materialItemIDs[station][findMatTierByIndex(request.materialIndex)]
		if station == CRAFTING_TYPE_CLOTHIER and request.pattern > 8 then
			matId = materialItemIDs[3][findMatTierByIndex(request.materialIndex)]
		end
		if station == CRAFTING_TYPE_JEWELRYCRAFTING then
			local matindex = JEWELY_MAT_REQUIREMENT[request.materialIndex][3]
			matId = materialItemIDs[station][matindex]
		end
		requirements[matId] = request.materialQuantity
		if station ~= 7 then
			if request.useUniversalStyleItem then
				requirements[ 71668] = 1 -- mimic stone Item ID
			else
				requirements[ GetItemLinkItemId( GetItemStyleMaterialLink(request.style , 0))] = 1
			end
		end

		local traitLink = GetSmithingTraitItemLink(request.trait, 0)
		if traitLink~="" then
			requirements[GetItemLinkItemId( traitLink)] = 1
		end
		if request.quality==1 then return requirements end


		local improvementLevel = getImprovementLevel(station)

		for i  = 1, request.quality - 1 do
			requirements[GetItemLinkItemId( GetSmithingImprovementItemLink(station, i, 0) )] = improvementChances[improvementLevel][i]
		end

		return requirements
	elseif request["type"] == "improvement" then
		return compileImprovementRequirements(request, requirements)
	else
		return requirements
	end
end

LibLazyCrafting.functionTable.CompileRequirements = compileRequirements
local itemSetIds ={ 
    [0] = 
    {
        [1] = "43529,35",
        [2] = 44241,
        [3] = "45018,260",
        [4] = "45280,17",
        [5] = 45858,
        [6] = "54508,2",
        [7] = "54512,2",
        [8] = "56026,34",
        [9] = "139396,11",
    },
}
local lastComputedSetTable = {}
local function createSetItemIdTable(setId)
	if lastComputedSetTable.id == setId then
		return lastComputedSetTable
	end

	local IdSource = LibLazyCraftingSavedVars.SetIds[setId]
	if not IdSource then
		return
	end
	local start = IdSource[1]
	local start = 0
	local workingTable = {}
	local numRanges = 0
	for i= 1, #workingTable do
		if workingTable[i]>400 then
			numRanges = numRanges+1
		end
	end
	for j = 1, #IdSource do
		if type(IdSource[j])=="number" then
			workingTable[#workingTable + 1] = IdSource[j]
		else

			local commaSpot = string.find(IdSource[j],",")
			local firstPart = tonumber(string.sub( IdSource[j], 1,commaSpot-1))
			local lastPart = tonumber(string.sub(IdSource[j], commaSpot+1))

			for i = 0, lastPart do
				workingTable[#workingTable + 1] = firstPart + i
			end
		end
	end
	workingTable.id = setId
	lastComputedSetTable = workingTable
	return workingTable
end
LLCTestingexpandSetItemTable = createSetItemIdTable
-------
-- SCANNING FUNCTIONALITY
-------

local lookedForSetIds = {}

local function populateLookedForIds()
	for i = 1, #SetIndexes do
		lookedForSetIds[ GetItemLinkSetInfo(getItemLinkFromItemId(SetIndexes[i]))] = true
	end
end
local varsDefault = {}

local function miniaturizeSetInfo(toMinify)
	local minifiedTable={} 
	local numConsecutive,lastPosition = 0,1 
	for i = 2, #toMinify do 
		if toMinify[lastPosition]+numConsecutive+1==toMinify[i] then 
			numConsecutive=numConsecutive+1 
		else 
			if numConsecutive>0 then 
				table.insert(minifiedTable,tostring(toMinify[lastPosition])..","..numConsecutive)
			else 
				table.insert(minifiedTable,toMinify[lastPosition]) 
			end 
			numConsecutive=0 
			lastPosition=i 
		end
	end 
	if numConsecutive>0 then 
		table.insert(minifiedTable,tostring(toMinify[lastPosition])..","..numConsecutive)
	else
		table.insert(minifiedTable,toMinify[lastPosition])
	end
	return minifiedTable
end

--- This was created mostly in slash commands. So variable names suck, locals are used rarely due to chat space limitations
local function internalScrapeSetItemItemIds()
	local apiVersionDifference = GetAPIVersion() - 101029
	local estimatedTime = math.floor((20000*apiVersionDifference+200000)/300*25/1000)+3
	zo_callLater(function()
	CHAT_SYSTEM:AddMessage("LibLazyCrafting: Beginning scrape of set items. Estimated time: "..estimatedTime.."s")
	CHAT_SYSTEM:AddMessage("This is a (usually) once per major game update scan. Please wait until it it is complete.")end
	, 25)
	
	local craftedItemIds = LibLazyCraftingSavedVars.SetIds or {}
	for k, setTable in pairs(LibLazyCrafting.GetSetIndexes()) do 
		if craftedItemIds[setTable[4] ] ~= nil then
			craftedItemIds[setTable[4] ].ignore = true
		else
			craftedItemIds[setTable[4] ] = {} 
		end
	end 
	craftedItemIds[0]= craftedItemIds[0] or nil
	local excludedTraits={[9]=true,[19]=true,[20]=true,[10]=true,[24]=true,[27]=true,} 
	local function isExcludedTrait(a) 
		local trait=GetItemLinkTraitInfo(a)  
		return excludedTraits[trait] 
	end
	local maxloop=1
	local function loopSpacer(start, last, functionToRun, interval)
		if start<last then
			for i = start, start+interval do
				functionToRun(i)
			end
			if maxloop>1000000 then
				return
			end
			maxloop = maxloop+1
			zo_callLater(
				function()
				loopSpacer(start+interval+1, last, functionToRun, interval)
			end
			,25)
		else 
			
			LibLazyCraftingSavedVars.SetIds = craftedItemIds
			for k, v in pairs(LibLazyCraftingSavedVars.SetIds) do
				if v.ignore then
					v.ignore = nil
				else
					table.sort(v)
					LibLazyCraftingSavedVars.SetIds[k] = miniaturizeSetInfo(v)
				end
			end
			LibLazyCraftingSavedVars.SetIds[0] = itemSetIds[0]
			LibLazyCraftingSavedVars.lastScrapedAPIVersion = GetAPIVersion()
			d("LibLazyCrafting: Item Scrape complete")
		end
	end
	local lowerEnd = 1
	if LibLazyCraftingSavedVars.SetIds and LibLazyCraftingSavedVars.SetIds[506]~= nil then
		lowerEnd = 163057
	end

	loopSpacer(lowerEnd,170000+12000*apiVersionDifference,
		function(id)
			local link="|H1:item:"..id..":0:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" 
			local itemType,specializedType=GetItemLinkItemType(link)
			if itemType<3 and itemType>0 then
				if (specializedType==300 or specializedType==0 or specializedType==250)and not isExcludedTrait(link) and GetItemLinkFlavorText(link)==""  then 
					local isSet,_,_,_,_,setId=GetItemLinkSetInfo(link)
					if craftedItemIds[setId] and not craftedItemIds[setId].ignore and isSet then
						table.insert(craftedItemIds[setId],id)
					end 
				end 
			end
		end,300)
	
end--[[

GetItemLinkEquipType()
GetItemLinkArmorType()
GetItemLinkWeaponType()
]]
local jewelryPatterns=
{
	EQUIP_TYPE_RING,
	EQUIP_TYPE_NECK,
}
local woodPatterns = 
{
	WEAPONTYPE_BOW,
	WEAPONTYPE_SHIELD,
	WEAPONTYPE_FIRE_STAFF,
	WEAPONTYPE_FROST_STAFF,
	WEAPONTYPE_LIGHTNING_STAFF,
	WEAPONTYPE_HEALING_STAFF,
}
local armourPatterns = 
{
	EQUIP_TYPE_CHEST,
	EQUIP_TYPE_FEET,
	EQUIP_TYPE_HAND,
	EQUIP_TYPE_HEAD,
	EQUIP_TYPE_LEGS,
	EQUIP_TYPE_SHOULDERS,
	EQUIP_TYPE_WAIST,
}
local blackWeaponPatterns = 
{
	WEAPONTYPE_AXE,
	WEAPONTYPE_HAMMER,
	WEAPONTYPE_SWORD,
	WEAPONTYPE_TWO_HANDED_AXE,
	WEAPONTYPE_TWO_HANDED_HAMMER,
	WEAPONTYPE_TWO_HANDED_SWORD,
	WEAPONTYPE_DAGGER,
}

local function itemLinkArmourCheck(armourWeight, armourType)
	return function(link) return GetItemLinkEquipType(link)==armourType and GetItemLinkArmorType(link)==armourWeight end
end

function IsItemLinkRobe(link)
	local itemId = GetItemLinkItemId(link)
	local baseLink = getItemLinkFromItemId(itemId)
	local textureFileName = GetItemLinkIcon(baseLink)
	return textureFileName == "/esoui/art/icons/gear_breton_light_robe_d.dds"
end

local function mapItemType(station, pattern)
	local isWeapon
	local equipType
	local weaponType
	local armourType
	local armourWeight
	if station == CRAFTING_TYPE_WOODWORKING then
		isWeapon = true
		weaponType = woodPatterns[pattern]
		return function(link) return GetItemLinkWeaponType(link)==weaponType end
	elseif station == CRAFTING_TYPE_CLOTHIER then
		isWeapon = false
		if pattern > 8 then
			armourWeight = ARMORTYPE_MEDIUM
			armourType = armourPatterns[pattern - 8]
			return itemLinkArmourCheck(armourWeight, armourType)
		else
			armourWeight = ARMORTYPE_LIGHT
			armourType = armourPatterns[math.max(pattern - 1, 1)]
			local check = itemLinkArmourCheck(armourWeight, armourType)
			if pattern <3 then
				return function(link) 
					if check(link) then 
						local textureFileName = GetItemLinkIcon(link)
						if pattern == 1 then
							return textureFileName == "/esoui/art/icons/gear_breton_light_robe_d.dds"
						else
							return textureFileName ~= "/esoui/art/icons/gear_breton_light_robe_d.dds"
						end
					end
				end
			end
			return check
		end
	elseif station == CRAFTING_TYPE_JEWELRYCRAFTING then
		isWeapon = false
		equipType = jewelryPatterns[pattern]
		return function(link) return GetItemLinkEquipType(link)==equipType end
	elseif station == CRAFTING_TYPE_BLACKSMITHING then
		if pattern > 7 then
			isWeapon = false
			armourWeight = ARMORTYPE_HEAVY
			armourType = armourPatterns[pattern - 7]
			return itemLinkArmourCheck(armourWeight, armourType)
		else
			isWeapon = true
			weaponType = blackWeaponPatterns[pattern]
			return function(link) return GetItemLinkWeaponType(link)==weaponType end
		end
	end
end
local function levelStuff(level, isCP, quality)
	if not isCP then
		if level < 5 then
			if level == 1 then
				return 29+quality, level
			elseif level == 4 then
				return 24 + quality , level
			end
		else
			return 19+quality, level
		end
	else
		if level <101 then
			return 115 + quality*10 + level/10-1 , 50
		end
		if level <151 then
			return 217 + 18*(level-100)/10 + quality, 50
		elseif level == 160 then 
			return 365 + quality, 50 
		end
	end

end
local function computeLinkParticulars(requestTable, link)
	local particulars = {}
	local itemId = GetItemLinkItemId( link)
	local enchantId = 0
	local enchantCPQuality = 0
	local enchantLvl = 0
	if requestTable.dualEnchantingSmithing then
		if requestTable.link then
			-- extract link portions needed
		else
			local essence, potency = LibLazyCrafting.getGlyphInfo()
			-- first, find potency parity
			local potencyId = requestTable.potencyItemID
			local essenceId = requestTable.essenceItemID
			local parity
			for i = 1, #potency do 
				if potency[i][2]==potencyId then
					parity = potency[i][1]
				end
			end
			for i = 1, #essence do
				if essence[i][9]==essenceId then
					if parity > 0 then
						enchantId = essence[i][4]
					else
						enchantId = essence[i][3]
					end
				end
			end

			-- compute link portions needed
			-- 1. get table from enchanting
			-- 2. loop through to find what's needed
		end
	end
	local matIndex = requestTable["materialIndex"]
	local materialQuantity =  requestTable["materialQuantity"] 
	local cpQuality, level = levelStuff(level, isCP, quality)
	-- cpQuality = 364
	-- lvl = 50
	link = string.format("|H1:item:%d:%d:%d:%d:%d:%d:0:0:0:0:0:0:0:0:0:%d:0:0:0:10000:0|h|h", itemId, cpQuality, lvl, enchantId, enchantCPQuality, enchantLvl,requestTable.style) 
	return link
end
local linkTable = {}
local function getItemLinkFromRequest(requestTable)
	local setId= requestTable.setIndex

	local trait = requestTable.trait
	local pattern= requestTable.pattern
	local station= requestTable.station
	local isLinkMatchFunction = mapItemType(station, pattern)
	if not linkTable.id or linkTable.id ~= setId then
		linkTable = {}
		linkTable.id = setId
		local IdTable = createSetItemIdTable(setId)
		for i, v in pairs(IdTable) do
			linkTable[i] = getItemLinkFromItemId(IdTable[i])
		end
	end
	local finalLink
	for i , v in pairs(linkTable) do
		if isLinkMatchFunction(linkTable[i]) and  GetItemLinkTraitInfo(linkTable[i])+1==trait then
			finalLink = computeLinkParticulars(requestTable, linkTable[i])
		end
	end
	return finalLink
end

local function fillOutFromParticulars(level, isCP, quality,style, potencyId, essenceId,aspectId,  link)
	local itemId = GetItemLinkItemId( link)
	local enchantId = 0
	local enchantCPQuality = 0
	local enchantLvl = 0
	if potencyId and essenceId then
		local essence, potency, aspect = LibLazyCrafting.getGlyphInfo()
		local parity
		for i = 1, #potency do 
			if potency[i][2]==potencyId then
				parity = potency[i][1]
				enchantCPQuality = potency[i][3]
				enchantLvl = potency[i][4]
			end
		end
		for i = 1, #essence do
			if essence[i][9]==essenceId then
				if parity > 0 then
					enchantId = essence[i][4]
				else
					enchantId = essence[i][3]
				end
			end
		end
		for i = 1, #aspect do
			if aspectId==aspect[i] then
				enchantCPQuality = enchantCPQuality + i -1
			end
		end
	end
	local cpQuality, lvl = levelStuff(level, isCP, quality)
	link = string.format("|H1:item:%d:%d:%d:%d:%d:%d:0:0:0:0:0:0:0:0:0:%d:0:0:0:10000:0|h|h", itemId, cpQuality, lvl, enchantId, enchantCPQuality, enchantLvl,style) 
	return link
end

local function internalGetItemLinkFromParticulars(setId, trait, pattern, station,level, isCP, quality,style,  potencyId, essenceId , aspectId)
	local isLinkMatchFunction = mapItemType(station, pattern)
	if not linkTable.id or linkTable.id ~= setId then
		linkTable = {}
		linkTable.id = setId
		local IdTable = createSetItemIdTable(setId)
		for i, v in pairs(IdTable) do
			linkTable[i] = getItemLinkFromItemId(IdTable[i])
		end
	end
	local finalLink
	for i , v in pairs(linkTable) do
		if isLinkMatchFunction(linkTable[i]) and  GetItemLinkTraitInfo(linkTable[i])+1==trait then
			finalLink = fillOutFromParticulars(level, isCP, quality,style, potencyId, essenceId,aspectId,  linkTable[i])
		end
	end
	return finalLink
end

local function getItemLinkFromParticulars(setId, trait, pattern, station,level, isCP, quality,style,  potencyId, essenceId , aspectId)
	local wasError, result = pcall(function() return internalGetItemLinkFromParticulars(setId, trait, pattern, station,level, isCP, quality,style,  potencyId, essenceId , aspectId) end )
	if wasError then
		return result
	else
		return nil
	end
end


-- local function getLinkFromRequest(request)
-- 	return getItemLinkFromParticulars(request.setIndex,request.trait ,request.pattern ,request.station ,request.,request.,request.quality,request.style, request.potencyItemId , request.essenceItemId, request.aspectItemId)
-- end

local function getNonCraftableReasons(request)
	local results = {}
	results.canCraftHere =  canCraftItemHere(station, request["setIndex"])
	local canCraft, canCraftMissings = canCraftItem(request)
	local enoughMats, missingMats = enoughMaterials(request)
	results.missingKnowledge = canCraftMissings
	results.missingMats = missingMats
	results.finalVerdict = results.canCraftHere and canCraft and enoughMats
	return results
end

LibLazyCrafting.functionTable.getItemLinkFromParticulars = getItemLinkFromParticulars
LibLazyCrafting.getItemLinkFromParticulars = getItemLinkFromParticulars
LibLazyCrafting.functionTable.getItemLinkFromRequest = getItemLinkFromRequest
LibLazyCrafting.getItemLinkFromRequest = getItemLinkFromRequest

-- LibLazyCrafting.functionTable.getItemLinkFromRequest = getItemLinkFromRequest

LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING] =
{
	["station"] = CRAFTING_TYPE_BLACKSMITHING,
	["check"] = function(self, station) return station == self.station end,
	["function"] = LLC_SmithingCraftInteraction,
	["complete"] = SmithingCraftCompleteFunction,
	["endInteraction"] = function(self, station) --[[endInteraction()]] end,
	["isItemCraftable"] = function(self, station, request)

		if request["type"] == "improvement" then
			local numBooster = GetMaxImprovementMats( request.ItemBagID,request.ItemSlotID,station)
			if not numBooster then return false end
			local _,_,stackSize = GetSmithingImprovementItemInfo(station, GetItemLinkQuality(GetItemLink(request.ItemBagID, request.ItemSlotID)))
			if stackSize< numBooster then
				return false
			end
			return true
		end
		if request["type"] == "deconstruct" then
			return true
		end
		if canCraftItemHere(station, request["setIndex"]) and canCraftItem(request) and enoughMaterials(request) then
			return true
		else
			return false
		end
	end,
	["materialRequirements"] = function(self, request) return compileRequirements(request) end,
	["getItemLinkFromRequest"] = getItemLinkFromRequest,
	["getNonCraftableReasons"] = getNonCraftableReasons,
}
-- Should be the same for other stations though. Except for the check
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_WOODWORKING] = copy(LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING])
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_WOODWORKING]["station"] = CRAFTING_TYPE_WOODWORKING

LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_CLOTHIER] = copy(LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING])
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_CLOTHIER]["station"] = CRAFTING_TYPE_CLOTHIER

LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_JEWELRYCRAFTING] = copy(LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_BLACKSMITHING])
LibLazyCrafting.craftInteractionTables[CRAFTING_TYPE_JEWELRYCRAFTING]["station"] = CRAFTING_TYPE_JEWELRYCRAFTING

local function initializeSetInfo()
	if not LibLazyCraftingSavedVars then 
		LibLazyCraftingSavedVars = {}
	end
	local vars = LibLazyCraftingSavedVars
	-- Last condition is bc I forgot to actually add them before the patch increase :(
	if not vars.SetIds or not vars.lastScrapedAPIVersion or vars.lastScrapedAPIVersion<GetAPIVersion() or LibLazyCraftingSavedVars.SetIds[695] == nil then
		-- if LibLazyCraftingSavedVars.SetIds and LibLazyCraftingSavedVars.SetIds[695] == nil then
		-- 	d("LibLazyCrafting: Usually this scraping only runs once per major game patch, but this re-run is required to add the new sets from Blackwood.")
		-- end
		internalScrapeSetItemItemIds()
	end
end
EVENT_MANAGER:RegisterForEvent(LLC.name.."SmithingScan",EVENT_PLAYER_ACTIVATED, initializeSetInfo)
--[[

/script local a = 0 for k, v in pairs(craftedSetIds) do for i = 1, #v do a = a + #tostring(v[i]) end end d(a)
--filter the no set id items

/script julianosTiny = {} for i = 1, #craftedSetIds[207] do

/script for i = 1, GetNumSmithingPatterns() do local _,_, numMats = GetSmithingPatternMaterialItemInfo(i, 1) for j=0, 40 do local a= GetSmithingPatternResultLink(i, 2, numMats, 1, j, 0) if a~="" then d(a) end end end
/script local b = 0 for i = 1, GetNumSmithingPatterns() do local _,_, numMats = GetSmithingPatternMaterialItemInfo(i, 1) for j=0, 40 do local a= GetSmithingPatternResultLink(i, 2, numMats, 1, j, 0) if a~="" and j~=10 and j~=11 and j~=20 and j~=21 then table.insert(DolgubonSetCrafter.savedvars.craftedSetIds[0], GetItemLinkItemId(a)) end end end d(b)
local function getItemLinkFromItemId(itemId)
	return string.format("|H1:item:%d:0:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i,)
end
|H1:item:117210:363:50:26845:370:50:0:0:0:0:0:0:0:0:1:24:0:1:0:341:0|h|h
|H1:item:150812:0:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h
]]
