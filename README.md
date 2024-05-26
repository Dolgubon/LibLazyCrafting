# What does LibLazyCrafting (LLC) do, and why should you use it?
Overall, the main goals are to simplify crafting for addons, while providing a common framework to avoid conflicts.

* Allows addons to **create and upgrade and even enchant** a piece of gear or create other crafting items with just one function
* Allows addons to request items to be crafted anywhere, not just at the relevant crafting station - **negating the need for code to handle crafting events**
* Various abstractions to the game crafting API to make it easier to ask for what you want, including **obviating the need to deal with the interaction between pattern index, material indexes, and material quantity**
* Allows you to obtain the item link result even when not at a crafting station
* Reduces **conflicts between crafting addons and inventory addons** by providing a common framework
* Functions to tell you the requirements to create items
* Extends game API functions with additional parameters, including quality, and enchantments
* Extends crafting functions to allow the use of itemIds in consumables, so you don't need to search for the item
* Allows addons to use some crafting related functions anywhere, not just at a crafting station
* Tells you when an item your addon requested is crafted, and **where in the bag it is located**
* Addons can listen to an event to know when all crafting stuff is complete
* If there's a crafting functionality you'd like that isn't in LLC, let me know and I'll see what I can do for it.

Github link: https://github.com/Dolgubon/LibLazyCrafting

# Documentation
Note: If you wish to use this library and run into issues or have questions, send me a mail on esoui. While the documentation should be accurate, it might still contain errors or old information. :(

## General Usage Notes

Add the following to your manifest.txt file:
\#\# DependsOn: LibLazyCrafting

Next, register your addon with LibLazyCrafting (LLC) in the addon initialized function. This will let you associate craft requests with your addon, as well as set various parameters when your addon calls LLC functions

### local interactionTable = LibLazyCrafting:AddRequestingAddon(*String addonName, boolean autoCraft, function callbackFunction, string optionalDebugAuthor, table optionalStyleTable*)
* *String addonName*: The name of the requesting addon.  
* *boolean autoCraft*: Whether requests from this addon should by default be crafted as soon as possible, or if your addon will initiate the crafts (usually upon request by the user)  
* *function callbackFunction* (* String event, integer CraftingType, table requestTable*) : The function that should be called when a requested craft is either complete, or failed for some reason. Different parameters may be returned depending on the event  
* *string optionalDebugAuthor*: This is optional, and if you give it your name, then it'll do debug messages when the character name matches. AKA when you run the addon yourself. Not sure how good the debug message coverage is.  
* *table optionalStyleTable*: This is used if you do no choice/max style for crafting equippable gear. Basically, these are what styles LLC can use. You can still manually choose to use other styles if you want, but if you don't specify, the addon will use styles from this table.
* **returns**: An interaction table with which your addon can use when calling the various functions provided by LLC. This interaction table contains most of the functions LLC provides.  

### See reference section at the end for info on LLC Event names, what the reference parameter is, what the request table is, and what an Item ID is
The reference section also contains some useful information about the game's API.


## Smithing
Functions available:

### CraftSmithingItemByLevel( *integer patternIndex,boolean isCP ,integer level, integer styleIndex,integer traitIndex,boolean useUniversalStyleItem,integer stationOverride, integer setIndex,integer quality,boolean autocraft,string reference,integer potencyId, integer essenceId, integer aspectId,integer smithingQuantity*)
This is the main function in this module. 
* patternIndex*: Pattern Index is whether you want to make a sword, dagger, staff, etc. It is dependent on the provided station parameter. That is, if you give 1 for pattern and CRAFTING_TYPE_BLACKSMITHING for station, LLC will create an Axe.
If you give 1 for pattern and CRAFTING_TYPE_CLOTHIER, then LLC will create a robe.
* isCP, level* -> Self explanatory, unless you don't play ESO
* styleIndex, traitIndex*: Matches the game's values
* useUniversalStyleItem*: AKA mimic stone
* stationOverride*: Allows you to set a specific crafting station. Default is the station you are at. If you are not at a station and do not pass a value, the function will fail.
* setIndex*: An integer determining the crafted set you wish to create. The default is 1, which signifies no set. A list of set indexes can be found in the Smithing.lua file, or with GetSetIndexes()
* quality*: One of the ITEM_QUALITY global constants. The default is white quality.
* autocraft*: Determines if the library will craft the item. If it is false, the library will keep it in queue until the requesting addon tells it to craft the item.
* reference*: This can be any type of data. It lets your addon to identify the request, to delete it, craft it, and know when it is complete. The default is the empty string.potencyId, essenceId, aspectId: If you want to create equipment with glyphs, use these parameters
* smithingQuantity*: How many to make
* potencyId, essenceID, and aspectID* - these can be used if you want the gear to be created with an enchantment. 

returns: The request table, which contains all the information about the craft request.

### CraftSmithingItem( *integer patternIndex, integer materialIndex, integer materialQuantity, integer styleIndex, integer traitIndex, boolean useUniversalStyleItem, integer:nilable stationOverride, integer:nilable setIndex, integer:nilable quality, boolean:nilable autocraft, anything:nilable reference, integer potencyId, integer essenceId, integer aspectId, integer smithingQuantity*)
This function is the same as CraftSmithingItemByLevel, except it replaces isCP and level with what the game uses to decide those. Not reccommended to use, unless converting an existing non LLC addon to one that uses LLC.

### InteractionTable:isSmithingLevelValid(*boolean isCP, integer lvl)*
returns boolean isValidSmithingLevel -- This returns true if equipment can be created at that level. For example, if you ask for isCP = true, and lvl = 155, you will get false, because the game does not allow you to create items at CP155

### ImproveSmithingItem( *Integer BagIndex, Integer SlotIndex, Integer newQuality, boolean autocraft, string reference*)
Improve the item at the specified bag index and slot index to the specified quality
### GetCurrentSetInteractionIndex
**returns**: the current set interaction index. tbh not sure how it reacts to the grand master stations
### CompileRequirements(*table requestTable*)
**returns**: A table containing the items required to craft the request, in the form of [itemID] = quantity
### GetSetIndexes()
**returns**: a table containing information about all the craftable sets, including their names, traits required, set index, and example item IDs (no trait axe, robe, bow and necklace)
### getItemLinkFromRequest(requestTable)
**returns** The item link that will be created by the request table.

### AddExistingGlyphToGear(existingRequestTable, glyphBag, glyphSlot)
- Takes in the bag and glyph slots of an existing piece of gear, and an existing craft request table, and then will apply that glyph to the gear once the gear is created
### AddGlyphToExistingGear(existingRequestTable, gearBag, gearSlot)
- Same as the above, but the gear already exists, and you're waiting on the glyph to be made

### DeconstructSmithingItem(bagIndex, slotIndex, autocraft, reference)
- Takes in the bag and slot indexes of an item, and will deconstruct that item. Checks for the unique id before deconstructing, but if item has moved in the meantime, then it will not deconstruct

## Provisioning and Furniture
The exact same functions are used by both provisioning and furniture, so they are combined here. You can use the AKA functions as your preference/use requires.

### CraftProvisioningItemByResultItemId(*integer resultItemId, integer timesToMake, boolean autocraft, string reference*)
AKA CraftFurnishingItemByResultItemId  
* What item do you want to make? Get the item ID and pass it to this function
### CraftProvisioningItemByRecipeId( *integer recipeId, integer timesToMake, boolean autocraft, string reference*)
AKA CraftFurnishingItemByRecipeId  
* Recipe ID is the item link of the recipe that creates the food or furniture you want to make  
### CraftProvisioningItemByRecipeIndex(*integer recipeListIndex, integer recipeIndex, timesToMake, autocraft, reference*)
AKA CraftFurnishingItemByRecipeIndex  
AKA CraftProvisioningItem  
This is the game equivalent craft provisioning function, so recipeListIndex and recipeIndex have the same function as in the game's API. Not particularly suggested for use.  
But, you can use GetRecipeInfoFromItemId(recipeId) to get the relevant recipeListIndex and recipeIndex, which may be useful as there are many game API functions which use those as parameters.  


## Alchemy

CraftAlchemyPotion
### CraftAlchemyItemByItemId(*integer solventId, integer reagentId1, integer reagentId2, integer reagentId3, integer timesToMake, integer autocraft, integer reference*)
* *integer solventId* ,  *integer reagentId1* ,  *integer reagentId2* ,  *integer reagentId3* - These are item IDs.
* *integer timesToMake* - Does not take into account the passives
### CraftAlchemyPotionselvent(*selventBagId, solventSlotId, reagent1BagId, reagent1SlotId, reagent2BagId, reagent2SlotId, reagent3BagId, reagent3SlotId, timesToMake, autocraft, reference*)
This is the 'base game API' equivalent function. LLC will convert the bag and slot IDs to the item IDs, so once the user arrives at an alchemy station, 
even if the locations of the reagents have changed, it will use whatever it was when your addon called the function


## Enchanting

### CraftEnchantingGlyphItemID(*potencyItemID, essenceItemID, aspectItemID, autocraft, reference, gearRequestTable, quantity*)
*integer gearRequestTable* -> You can also pass this function a request table from the smithing functions, and once the glyph and gear are created, LLC will auto enchant the gear
### CraftEnchantingGlyph(*integer potencyBagId, integer potencySlot, integer essenceBagId, integer essenceSlot, integer aspectBagId, integer aspectSlot, boolean autocraft, string reference, table:nilable gearRequestTable, integer quantity*)
Similar to alchemy, this will convert the bag and slot IDs into item IDs and use those to identify what will be crafted once at the table
*integer gearRequestTable* -> You can also pass this function a request table from the smithing functions, and once the glyph and gear are created, LLC will auto enchant the gear
### AddExistingGlyphToGear(existingRequestTable, glyphBag, glyphSlot)
- Takes in the bag and glyph slots of an existing piece of gear, and an existing craft request table, and then will apply that glyph to the gear once the gear is created
### AddGlyphToExistingGear(existingRequestTable, gearBag, gearSlot)
- Same as the above, but the gear already exists, and you're waiting on the glyph to be madeEnchantAttributesToGlyphIds(isCP, level, enchantId, quality) returns potencyId, essenseId, aspectId

## Example usage


Note: LLC_Global is a global queue meant only for testing and exploration. It is not recommended to actually use this within your addon; see General Usage for more info
You can paste these functions into chat to craft stuff

/script LLC_Global:CraftSmithingItemByLevel(3, true, 150,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 3,true) -- crafts a blue CP150 shoes  
/script for i= 2, 25 do LLC_Global:CraftSmithingItemByLevel(3, false, i * 2,3 ,1 ,false, CRAFTING_TYPE_CLOTHIER, 0, 3,true) end -- Crafts lvl 4,6, 8, 10, etc. up to lvl 50. The items will be blue shoes.  
/script LLC_Global:CraftEnchantingItemId(45830, 45838, 45851) -- Crafts a Monumental Glyph of Flame Resist  
/script LLC_Global:CraftProvisioningItem(1, 1) -- Makes Fishy Sticks


# Reference section

### LLC events
Each LLC event has a string to identify them, not a number. (like how the game does it) This is for more clarity.  
**LLC_CRAFT_SUCCESS** = "success" -- extra result: Position of item, item link, possibly other stuff depending on crafting type  
**LLC_ITEM_TO_IMPROVE_NOT_FOUND** = "item not found" -- extra result: Improvement request table  
**LLC_INSUFFICIENT_MATERIALS** = "not enough mats" -- extra result: what is missing, item identifier  
**LLC_INSUFFICIENT_SKILL**  = "not enough skill" -- extra result: what skills are missing; both if not enough traits, not enough styles, or trait unknown  
**LLC_NO_FURTHER_CRAFT_POSSIBLE** = "no further craft items possible" -- Thrown when there is no more items that can be made at the station  
**LLC_INITIAL_CRAFT_SUCCESS** = "initial stage of crafting complete" -- Thrown when the white item of a higher quality item is created  
**LLC_ENCHANTMENT_FAILED** = "enchantment failed"  
**LLC_CRAFT_PARTIAL_IMPROVEMENT** = "item has been improved one stage, but is not yet at final quality"  
**LLC_CRAFT_BEGIN** = "starting crafting"  

### What is Reference parameter?
The reference parameter is usually optional, but if provided, it allows you to keep track of requests. You can use the reference to cancel a request, get a request's info, or know when a specific request was completed.
I suggest using a string, but I think you can actually use any type of value.

### What is the Request Table?
A request table is a table containing all the information required to craft an item.
Exact parameters vary by station, but all request tables should contain some common values.
Common values include the station, the addon that requested the item, autocraft, and a reference, if provided

### What is an item ID?
ESO uses item links. The item ID is the long number at the start of an item link. For example, given this item link:
|H0:item:**71062**:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h
The item ID is 71062. For crafting materials, the item ID is all that is required to identify a given item. Also, item links may be different but still refer to the same item.
Thus, many of the functions in LLC use the item ID in the place of an item link.
You can get an item ID from an item link with GetItemLinkItemId(itemLink)
You can get the item ID from an item in a bag with GetItemId(bagID, slotID)
You can get the item link from an item ID (for crafting materials) using LibLazyCrafting.getItemLinkFromItemId(itemId)


