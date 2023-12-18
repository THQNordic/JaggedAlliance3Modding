bobby_tier_print = CreatePrint{
	-- "BobbyRay Unlock & Tier",         -- comment out to disable these prints;
}
bobby_restock_print = CreatePrint{
	-- "BobbyRay Restock",         -- comment out to disable these prints;
}

bobby_mod_print = CreatePrint{
	-- "BobbyRay Modification",         -- comment out to disable these prints;
}

bobby_cost_print = CreatePrint{
	-- "BobbyRay Cost Mod",         -- comment out to disable these prints;
}

if FirstLoad then
	g_BobbyRayShopOpen = false -- to override g_RolloverShowMoreInfo (RolloverInventoryWeapon) when browsing shop with gamepad
end

function BobbyRayRolloverOverride()
	return g_BobbyRayShopOpen
end

--------------------------------------------- Tiers

function BobbyRayShopGetUnlockedTier()
	return GetQuestVar("BobbyRayQuest", "UnlockedTier")
end

function BobbyRayShopIsUnlocked()
	if not gv_Quests["BobbyRayQuest"] then return end
	return (GetQuestVar("BobbyRayQuest", "UnlockedTier") or 0) > 0
end

function BobbyRayShopIsOpening()
	return GetQuestVar("BobbyRayQuest", "TCE_PreparingToOpen") == "done" and not GetQuestVar("BobbyRayQuest", "TCE_StoreNowOpen") == "done"
end

function BobbyRayShopGetRestockTime()
	return GetQuestVar("BobbyRayQuest", "RestockTimer")
end

function NetSyncEvents.Cheat_BobbyRaySetTier(tier)
	if not gv_Quests["BobbyRayQuest"] then return end
	SetQuestVar(QuestGetState("BobbyRayQuest"), "UnlockedTier", tier)
	ObjModified("g_BobbyRayShop_UnlockedTier")
end

function NetSyncEvents.Cheat_BobbyRayToggleLock()
	if not gv_Quests["BobbyRayQuest"] then return end
	if BobbyRayShopGetUnlockedTier() > 0 then
		SetQuestVar(QuestGetState("BobbyRayQuest"), "UnlockedTier", 0)
		SetQuestVar(QuestGetState("BobbyRayQuest"), "RestockTimer", 0)
	else 
		SetQuestVar(QuestGetState("BobbyRayQuest"), "UnlockedTier", 1)
		SetQuestVar(QuestGetState("BobbyRayQuest"), "RestockTimer", Game.CampaignTime + 1 * const.Scale.h)
	end
	
	ObjModified("g_BobbyRayShop_UnlockedTier")
end

function TFormat.GetShopTime(context, time)
	local daysLeft = DivCeil(time, const.Scale.day)
	if daysLeft > 2 then return daysLeft .. " " .. T(569233738707, "days") end
	
	local hoursLeft = DivCeil(time, const.Scale.h)
	if hoursLeft > 1 then 
		return T{292118944563, "<hours> hours", hours = hoursLeft}
	else 
		return T(882114309389, "1 hour")
	end
end

---------------------------------------------

-- data structure is store { used = { item_id -> item }, standard = { item_class -> item }, standard_ids = { item_id -> item_class } }
-- 	the item_id -> is to allow saving
-- 	for standard items, we want class index so that we can efficiently check which items are already present during restocking
-- used items could collide, but this reasonably unlikely

GameVar("g_BobbyRayStore", {
	used = {},
	standard = {},
	standard_ids = {},
})

GameVar("g_BobbyRayCart", {
	units = {}
})

-- whenever items are added to the cart, they get assigned an ordinal, such that g_BobbyRayCartOrdinalUnits[item.id] = ordinal
-- the ordinal resets to 0 whenever the units are cleared
-- order form's item list is sorted by ordinal
if FirstLoad then
	lBobbyRayCartNextOrdinal = 1
	lBobbyRayCartOrdinalUnits = {}
end
local function lClearOrdinals()
	lBobbyRayCartNextOrdinal = 1
	lBobbyRayCartOrdinalUnits = lBobbyRayCartOrdinalUnits or {}
	table.clear(lBobbyRayCartOrdinalUnits)
end

local function lGetNextOrdinal()
	lBobbyRayCartNextOrdinal = lBobbyRayCartNextOrdinal + 1
	return lBobbyRayCartNextOrdinal - 1
end

local function lRebuildOrdinals(units)
	lClearOrdinals()
	for item_id, item in sorted_pairs(units) do
		lBobbyRayCartOrdinalUnits[item_id] = lGetNextOrdinal()
	end
end

local function lHasItemOrdinal(item_id)
	return lBobbyRayCartOrdinalUnits[item_id] and true or false
end
local function lGetItemOrdinal(item_id)
	assert(lBobbyRayCartOrdinalUnits[item_id])
	return lBobbyRayCartOrdinalUnits[item_id]
end

local function lCheckShopIdInconsistency()
	for class, item in pairs(g_BobbyRayStore.standard) do
		if g_BobbyRayStore.standard_ids[item.id] ~= item.class then
			return true
		end
	end
	return false
end

local function lFixShopIds()
	table.clear(g_BobbyRayStore.standard_ids)
	for class, item in pairs(g_BobbyRayStore.standard) do
		g_BobbyRayStore.standard_ids[item.id] = item.class
	end
end

function OnMsg.LoadSessionData()
	if lCheckShopIdInconsistency() then
		BobbyRayCartClearEverything()
		lFixShopIds() 
	end
	lRebuildOrdinals(BobbyRayCartGetUnits())
end

---------------------------------------------------------- New logic

GameVar("g_BobbyRayItemsDirty", false) -- so that we don't need to update an item's "New" status on every satellite tick; GameVar to sync in multiplayer
function NetSyncEvents.BobbyRayMarkItemsAsSeen(category, subcategory)
	category = BobbyRayShopGetCategory(category)
	if subcategory then subcategory = BobbyRayShopGetSubCategory(subcategory) end
	
	g_BobbyRayItemsDirty = true
	
	for item_id, item in pairs(g_BobbyRayStore.used) do
		if (subcategory and item:GetSubCategory() == subcategory) or (not subcategory and item:GetCategory() == category) then
			item.Seen = true
		end
	end
	for id, item in pairs(g_BobbyRayStore.standard) do
		if (subcategory and item:GetSubCategory() == subcategory) or (not subcategory and item:GetCategory() == category) then 
			item.Seen = true
		end
	end
end

function NetSyncEvents.BobbyRayUpdateNew()
	if not g_BobbyRayItemsDirty then return end
	g_BobbyRayItemsDirty = false
	for item_id, item in pairs(g_BobbyRayStore.used) do
		if item.Seen then item.New = false end
	end
	
	for item_class, item in pairs(g_BobbyRayStore.standard) do
		if item.Seen then item.New = false end
	end
end

---------------------------------------------------------- Shop Contents

function lGetShopItemFromId(id)
	if g_BobbyRayStore.used[id] then return g_BobbyRayStore.used[id] end
	return g_BobbyRayStore.standard[g_BobbyRayStore.standard_ids[id]]
end

function BobbyRayStoreGetEntry(entry)
	if entry.Used then return entry
	else return g_BobbyRayStore.standard[entry.class] end
end

function BobbyRayStoreClear()
	table.clear(g_BobbyRayStore)
	g_BobbyRayStore.used = {}
	g_BobbyRayStore.standard = {}
	g_BobbyRayStore.standard_ids = {}
	
	BobbyRayCartClearEverything() -- clear cart too because any reference will become invalid
end

function BobbyRayStoreToArray(categoryId, subcategoryId, context)
	local category = BobbyRayShopGetCategory(categoryId)
	local subcategory = BobbyRayShopGetSubCategory(subcategoryId)
	local array = {}
	local min_entries = 7
	for item_id, item in pairs(g_BobbyRayStore.used) do
		if (subcategory and subcategory:BelongsInSubCategory(item)) or (not subcategory and category:BelongsInCategory(item)) then
			table.insert(array, item)
		end
	end
	for id, item in pairs(g_BobbyRayStore.standard) do
		if (subcategory and item:GetSubCategory() == subcategory) or (not subcategory and item:GetCategory() == category) then 
			table.insert(array, item)
		end
	end
	
	table.sort(array, function(a,b)
		local aEntry = BobbyRayStoreGetEntry(a)
		local bEntry = BobbyRayStoreGetEntry(b)
		
		-- 0-th first, sort by presence in cart
		local aInCart = g_BobbyRayCart.units[a.id] and g_BobbyRayCart.units[a.id] ~= 0
		local bInCart = g_BobbyRayCart.units[b.id] and g_BobbyRayCart.units[b.id] ~= 0
		if aInCart and not bInCart then return true
		elseif bInCart and not aInCart then return false end
		
		-- first, sort by subcategory
		local aEntrySubCat = aEntry:GetSubCategory()
		local bEntrySubCat = bEntry:GetSubCategory()
		if aEntrySubCat.SortKey < bEntrySubCat.SortKey then return true end
		if aEntrySubCat.SortKey > bEntrySubCat.SortKey then return false end
		
		-- second sort by item class?
		if aEntry.class < bEntry.class then return true end
		if aEntry.class > bEntry.class then return false end
		
		-- third sort by Condition
		if aEntry.Condition < bEntry.Condition then return false end
		if aEntry.Condition > bEntry.Condition then return true end
		
		-- finally sort by id which should be unique
		return aEntry.id < bEntry.id
	end)
	
	for i = table.count(array), min_entries - 1 do
		table.insert(array, empty_table)
	end
	
	NetSyncEvent("BobbyRayMarkItemsAsSeen", category.id, subcategory and subcategory.id)
	
	return array
end

function BobbyRayCartUnitsToOrders()
	local orders = {}
	local min_entries = 12
	for item_id, count in pairs(BobbyRayCartGetUnits()) do
		local entry = lGetShopItemFromId(item_id)
		table.insert(orders, entry)
	end
	table.sort(orders, function(a,b) return lGetItemOrdinal(a.id) < lGetItemOrdinal(b.id) end)
	for i=table.count(orders), min_entries - 1 do
		table.insert(orders, empty_table)
	end
	return orders
end

function BobbyRayCartGetAggregate()
	local acc = MulDivRound(BobbyRayCartGetDeliveryOption().Price, gv_Sectors[BobbyRayCartGetDeliverySector()].BobbyRayDeliveryCostMultiplier, 100)
	local count = 0
	for item_id, number in pairs(BobbyRayCartGetUnits()) do
		local entry = lGetShopItemFromId(item_id)
		acc = acc + BobbyRayStoreGetEntry(entry).Cost * number
		count = count + number
	end
	return count, acc
end

function BobbyRayCartHasEnoughMoney(entry)
	local cart_count, cart_cost = BobbyRayCartGetAggregate()
	local entry_cost = BobbyRayStoreGetEntry(entry) and BobbyRayStoreGetEntry(entry).Cost or 0
	return Game.Money - cart_cost - entry_cost >= 0
end

function BobbyRayCartHasEnoughStock(entry)
	local max_stock = BobbyRayStoreGetEntry(entry).Stock
	local cur_stock = BobbyRayCartGetUnits()[entry.id] or 0
	return cur_stock < max_stock 
end

function CanAddToCart(item_id)
	local item = lGetShopItemFromId(item_id)
	return BobbyRayCartHasEnoughMoney(item) and BobbyRayCartHasEnoughStock(item)
end

function CanRemoveFromCart(item_id)
	return g_BobbyRayCart.units[item_id] and g_BobbyRayCart.units[item_id] > 0
end

function BobbyRayCartClearEverything()
	g_BobbyRayCart.delivery_option = nil
	BobbyRayCartClearSectorDelivery()
	BobbyRayCartClearUnits()
end

---------------------------------------------------------- Cart Operations

local function lForgetBobbyRayOrderTabState()
	if PDABrowserTabState["bobby_ray_shop"] and PDABrowserTabState["bobby_ray_shop"].mode_param == "cart" and table.count(g_BobbyRayCart.units) == 0 then
		PDABrowserTabState["bobby_ray_shop"].mode_param = "front"
	end
end

local function lBobbyRayCartAdd(item_id)
	g_BobbyRayCart.units[item_id] = g_BobbyRayCart.units[item_id] and g_BobbyRayCart.units[item_id] + 1 or 1
	if not lHasItemOrdinal(item_id) then lBobbyRayCartOrdinalUnits[item_id] = lGetNextOrdinal() end
end

local function lBobbyRayCartRemove(item_id)
	g_BobbyRayCart.units[item_id] = g_BobbyRayCart.units[item_id] and Max(0, g_BobbyRayCart.units[item_id] - 1) or 0
end

function BobbyRayCartGetUnits()
	g_BobbyRayCart.units = g_BobbyRayCart.units or {}
	return g_BobbyRayCart.units
end

function BobbyRayCartClearUnits()
	table.clear(g_BobbyRayCart.units)
	lClearOrdinals()
end

function NetSyncEvents.BobbyRayCartAdd(item_id)
	if not CanAddToCart(item_id) then return end
	lBobbyRayCartAdd(item_id)
	ObjModified(g_BobbyRayCart)
end

function NetSyncEvents.BobbyRayCartRemove(item_id)
	lBobbyRayCartRemove(item_id)
	ObjModified(g_BobbyRayCart)
end

--------------------------------------------- Order Form clear empty
-- whenever neither player has the Order page open, the game will clear the cart entries with amount 0
-- if this results in the cart ending up empty, it resets the tab state so that the shop opens at the frontpage instead of the order form (same on satellite ticks, which clear the cart)

if FirstLoad then
	BobbyRayOrderFormOpenedBySelf = false
	BobbyRayOrderFormOpenedByOther = false
end

function BobbyRayCheckClearEmptyCartEntries()
	if not g_BobbyRayCart then return end
	if not BobbyRayOrderFormOpenedByOther and not BobbyRayOrderFormOpenedBySelf then
		for item, amount in pairs(g_BobbyRayCart.units) do
			if amount == 0 then
				g_BobbyRayCart.units[item] = nil
				lBobbyRayCartOrdinalUnits[item] = nil
			end
		end
		lForgetBobbyRayOrderTabState()
	end
end

function GetBobbyRayOrderFormOpenId()
	return netInGame and netUniqueId or "self"
end

function NetSyncEvents.SetBobbyRayOrderFormOpened(player_id, open)
	if player_id == GetBobbyRayOrderFormOpenId() then
		BobbyRayOrderFormOpenedBySelf = open
	else
		BobbyRayOrderFormOpenedByOther = open
	end
	BobbyRayCheckClearEmptyCartEntries()
end

function OnMsg.NetGameLeft()
	BobbyRayOrderFormOpenedByOther = false
	BobbyRayCheckClearEmptyCartEntries()
end

function OnMsg.NetPlayerLeft(player_id)
	BobbyRayOrderFormOpenedByOther = false
	BobbyRayCheckClearEmptyCartEntries()
end

function OnMsg.ChangeMap()
	BobbyRayOrderFormOpenedBySelf = false
	BobbyRayOrderFormOpenedByOther = false
end

---------------------------------------------------------- Delivery Option

function BobbyRayCartGetDefaultDeliveryOption()
	return Presets.BobbyRayShopDeliveryDef.Default.Standard
end

function BobbyRayCartGetDeliveryOption()
	g_BobbyRayCart.delivery_option = g_BobbyRayCart.delivery_option or "Standard"
	return FindPreset("BobbyRayShopDeliveryDef", g_BobbyRayCart.delivery_option)
end

local function lBobbyRaySetDeliveryOption(option_id)
	g_BobbyRayCart.delivery_option = option_id
end

function NetSyncEvents.BobbyRaySetDeliveryOption(option_id)
	lBobbyRaySetDeliveryOption(option_id)
	ObjModified(g_BobbyRayCart)
end

---------------------------------------------------------- Sector Delivery

g_UnlockedSectors = false -- !TODO: debug only, remove before release
function BobbyRayGetAvailableDeliverySectors()
	local initial_sector = GetCurrentCampaignPreset().InitialSector
	local sectors = { initial_sector }
	for id, sector in pairs(gv_Sectors) do
		if (g_UnlockedSectors and sector.CanBeUsedForArrival and id ~= initial_sector) or (sector.Side == "player1" and sector.CanBeUsedForArrival and not sector.PortLocked and sector.last_own_campaign_time ~= 0 and id ~= initial_sector) then
			table.insert(sectors, id)
		end
	end
	if #sectors == 0 then
		table.insert(sectors, initial_sector)
	end
	return sectors
end

function BobbyRayCartSetSectorDelivery(sectorId)
	g_BobbyRayCart.delivery_destination = sectorId
end

function NetSyncEvents.BobbyRayCartSetSectorDelivery(sectorId)
	BobbyRayCartSetSectorDelivery(sectorId)
	ObjModified(g_BobbyRayCart)
	ObjModified("DeliverySectorChanged")
end

function BobbyRayGetDefaultDeliverySector()
	return BobbyRayGetAvailableDeliverySectors()[1]
end

function BobbyRayCartGetDeliverySector()
	return g_BobbyRayCart.delivery_destination or BobbyRayGetDefaultDeliverySector()
end

function BobbyRayCartClearSectorDelivery()
	g_BobbyRayCart.delivery_destination = nil
end

-------------------------------------------------------

function BobbyRayStoreGetStats_Firearm(item)
	return {
		{ T(467324314141, "DMG"), Untranslated(item.Damage) },
		{ T(788999452116, "RANGE"), Untranslated(item.WeaponRange) },
		{ T(921500948697, "CRIT"), T{580888120593, "<percent(number)>", number = Presets.WeaponPropertyDef.Default.MaxCritChance:GetProp(item)} },
		{ T(842354777573, "PEN"), GetPenetrationClassUIText(item.PenetrationClass) },
	}
end

function BobbyRayStoreGetStats_MeleeWeapon(item)
	return {
		{ T(467324314141, "DMG"), Untranslated(item.Damage and item.Damage or item.BaseDamage) },
		{ T(788999452116, "RANGE"), Untranslated(item.WeaponRange) },
		{ T(921500948697, "CRIT"), T{580888120593, "<percent(number)>", number = Presets.WeaponPropertyDef.Default.MaxCritChance:GetProp(item)} },
		{ T(842354777573, "PEN"), GetPenetrationClassUIText(item.PenetrationClass) },
	}
end

function BobbyRayStoreGetStats_Armor(item)
	return {
		{ T(113963825061, "DR"), T{580888120593, "<percent(number)>", number = item.DamageReduction + item.AdditionalReduction } },
		{ T(260685017729, "SLOT"), Presets.TargetBodyPart.Default[item.Slot].display_name },
		{ T(842354777573, "PEN"), GetPenetrationClassUIText(item.PenetrationClass) },
	}
end

function BobbyRayStoreGetStats_Ammo(item)
	return {
		{ T(196962828215, "Cal"), FindPreset("Caliber", item.Caliber).Name },
		item.PenetrationClass and { T(314470590373, "Pen"), GetPenetrationClassUIText(item.PenetrationClass) } or nil
	}
end

function BobbyRayStoreGetStats_Other(item)
	return nil
end

function PickRandomWeightItems(num, items_array, max_weight)
	local picked_items = {}
	local picked_items_set = {}
	for i=1, num do
		local rand_weight = InteractionRand(max_weight, "BobbyRayShop")
		local cur_weight = 0
		local cur_index = 1
		while true do
			local item = items_array[cur_index]
			while picked_items_set[item] do
				cur_index = cur_index + 1
				item = items_array[cur_index]
			end
			cur_weight = cur_weight + item.RestockWeight
			cur_index = cur_index + 1
			if cur_weight > rand_weight then
				table.insert(picked_items, item.class)
				picked_items_set[item] = true
				max_weight = max_weight - item.RestockWeight
				break
			end
		end
	end
	return picked_items
end

function PrepareShopItemsForRestock(unlocked_tier, used)
	local category_weights = {}
	local category_count = {}
	local category_items = {} -- array
	local category_items_set = {}
	NetUpdateHash("PrepareShopItemsForRestock1", unlocked_tier, used)
	-- aggregate category weights and count
	-- !TODO: do we want to skip items that are already at max stock?
	ForEachPreset("InventoryItemCompositeDef", function(preset)
		local item = g_Classes[preset.id]
		local usedOrStandard = false
		if used then 
			usedOrStandard = item.CanAppearUsed
		else 
			usedOrStandard = item.CanAppearStandard
		end
		if item.CanAppearInShop and usedOrStandard and item.Tier <= unlocked_tier and item.RestockWeight > 0 then
			local cat = item:GetCategory().id
			if not category_weights[cat] then
				category_weights[cat] = 0
				category_count[cat] = 0
				category_items[cat] = {}
				category_items_set[cat] = {}
			end
			table.insert(category_items[cat], item)
			category_items_set[cat][item] = true
			category_weights[cat] = category_weights[cat] + item.RestockWeight
			category_count[cat] = category_count[cat] + 1
			NetUpdateHash("PrepareShopItemsForRestock2", cat, item.class, item.RestockWeight, category_count[cat], category_weights[cat])
		end
	end)
	return category_items, category_count, category_weights, category_items_set
end

function RandomlyModifyWeapon(weapon)
	local weapon_component_chance = const.BobbyRay.Restock_UsedWeaponComponentPercentage
	local weapon_component_price_modifier = const.BobbyRay.Restock_UsedWeaponComponentPriceMod
	-- we shuffle first because blocked components could get a lower chance of being picked
	local shuffledComponents = {}
	for i, slotDef in ipairs(weapon.ComponentSlots) do
		table.insert(shuffledComponents, slotDef)
	end
	table.shuffle(shuffledComponents, InteractionRand(nil, "BobbyRayShop"))
	
	local blocked_slots = {}
	local applied_mods = {}
	for i, slotDef in ipairs(shuffledComponents) do
		if InteractionRand(100, "BobbyRayShop") <= weapon_component_chance and not blocked_slots[slotDef.SlotType] then
			local comp_num = #slotDef.AvailableComponents
			if slotDef.DefaultComponent and slotDef.DefaultComponent ~= "" then comp_num = comp_num - 1 end -- hack to skip the default component; on clash, we pick the last component, not included in the random gen
			assert(comp_num >= 0)
			if comp_num == 0 then goto continue end
			local index = InteractionRand(comp_num) + 1
			local comp_id = slotDef.AvailableComponents[index]
			local component = WeaponComponents[comp_id]
			if comp_id == slotDef.DefaultComponent then component = slotDef.AvailableComponents[comp_num] end
			applied_mods[slotDef.SlotType] = comp_id
			if component.BlockSlots and next(component.BlockSlots) ~= nil then
				for _, blockSlotType in ipairs(component.BlockSlots) do
					blocked_slots[blockSlotType] = true
				end
			end
			bobby_mod_print("Applied", comp_id,"to", slotDef.SlotType)
		elseif blocked_slots[slotDef.SlotType] then
			bobby_mod_print("Skipped due to blocked slot:", slotDef.SlotType)
		else
			bobby_mod_print("Skipped due to low chance:", slotDef.SlotType)
		end
		::continue::
	end
	
	local cost_modifier = 0
	for slot, component in pairs(applied_mods) do
		cost_modifier = cost_modifier + weapon_component_price_modifier
		weapon:SetWeaponComponent(slot, component)
	end
	
	return cost_modifier
end

function RestockStandardItem(item_class)
	local item = g_BobbyRayStore.standard[item_class]
	if not item then
		item = PlaceInventoryItem(item_class)
		item.Stock = 0
		g_BobbyRayStore.standard[item_class] = item
		g_BobbyRayStore.standard_ids[item.id] = item_class
	end
	
	item.LastRestock = Game.CampaignTime
	local rand_stock = InteractionRand(item.MaxStock + 1, "BobbyRayShop")
	item.Stock = Max(1, item.Stock, rand_stock)
	item.New = true
end

function RestockUsedArmor(armor_id)
	local used_price_min = const.BobbyRay.Restock_UsedPriceModMin
	local used_price_max = const.BobbyRay.Restock_UsedPriceModMax
	local used_condition_min = const.BobbyRay.Restock_UsedConditionMin
	local used_condition_max = const.BobbyRay.Restock_UsedConditionMax
	
	local item = PlaceInventoryItem(armor_id)
	item.Used = true
	item.Condition = used_condition_min + InteractionRand(used_condition_max - used_condition_min, "BobbyRayShop")
	local usedCostMod = used_price_min + InteractionRand(used_price_max - used_price_min, "BobbyRayShop")
	item.Stock = 1
	item.LastRestock = Game.CampaignTime
	g_BobbyRayStore.used[item.id] = item
	local baseCost = item.Cost
	item.Cost = MulDivRound(item.Cost, usedCostMod, 100)
	bobby_cost_print(item.class, "\n\tbase price:", baseCost, "$", "\n\tcondition price mod:", usedCostMod, "%", "\n\tfinal price:", item.Cost, "$")
	item.New = true
end

function RestockUsedWeapon(weapon_id)
	local used_price_min = const.BobbyRay.Restock_UsedPriceModMin
	local used_price_max = const.BobbyRay.Restock_UsedPriceModMax
	local used_condition_min = const.BobbyRay.Restock_UsedConditionMin
	local used_condition_max = const.BobbyRay.Restock_UsedConditionMax
	
	local item = PlaceInventoryItem(weapon_id)
	item.Used = true
	item.Condition = used_condition_min + InteractionRand(used_condition_max - used_condition_min, "BobbyRayShop")
	local usedCostMod = used_price_min + InteractionRand(used_price_max - used_price_min, "BobbyRayShop")
	item.Stock = 1
	item.LastRestock = Game.CampaignTime
	local compCostMod = RandomlyModifyWeapon(item)
	g_BobbyRayStore.used[item.id] = item
	local baseCost = item.Cost
	item.Cost = MulDivRound(item.Cost, usedCostMod + compCostMod, 100)
	bobby_cost_print(item.class, "\n\tbase price:", baseCost, "%", "\n\tcondition price mod:", usedCostMod, "%", "\n\tmodification price mod:", compCostMod, "%", "\n\tfinal price:", item.Cost, "$")
	item.New = true
end

function BobbyRayStoreRestock(restock_modifier_standard, restock_modifier_used)
	if not BobbyRayShopIsUnlocked() then return end
	
	local restock_min_percent_used = MulDivRound(const.BobbyRay.Restock_UsedPercentageMin, restock_modifier_used or 100, 100)
	local restock_max_percent_used = MulDivRound(const.BobbyRay.Restock_UsedPercentageMax, restock_modifier_used or 100, 100)
	local restock_min_percent_standard = MulDivRound(const.BobbyRay.Restock_StandardPercentageMin, restock_modifier_standard or 100, 100)
	local restock_max_percent_standard = MulDivRound(const.BobbyRay.Restock_StandardPercentageMax, restock_modifier_standard or 100, 100)

	local category_items, category_count, category_weights, category_items_set = PrepareShopItemsForRestock(BobbyRayShopGetUnlockedTier(), "used")
	-- restock random armor
	--[[]]
	local total_items = category_count["Armor"]
	local restock_items = Max(1, MulDivRound(total_items, restock_min_percent_used + InteractionRand(restock_max_percent_used - restock_min_percent_used + 1, "BobbyRayShop"), 100))
	restock_items = Min(restock_items, #category_items["Armor"])
	local picked_items = PickRandomWeightItems(restock_items, category_items["Armor"], category_weights["Armor"])
	if total_items > 0 then  bobby_restock_print("Restocking", restock_items, "out of", total_items, "used", "Armors", "or ", MulDivRound(restock_items, 100, total_items)) end
	for _, item in ipairs(picked_items) do
		RestockUsedArmor(item)
	end
	--]]
	
	--[[]]
	local total_items = category_count["Weapons"]
	local restock_items = Max(1, MulDivRound(total_items, restock_min_percent_used + InteractionRand(restock_max_percent_used - restock_min_percent_used + 1, "BobbyRayShop"), 100))
	restock_items = Min(restock_items, #category_items["Weapons"])
	local picked_items = PickRandomWeightItems(restock_items, category_items["Weapons"], category_weights["Weapons"])
	if total_items > 0 then  bobby_restock_print("Restocking", restock_items, "out of", total_items, "used", "Weapons", "or ", MulDivRound(restock_items, 100, total_items)) end
	for _, item in ipairs(picked_items) do
		RestockUsedWeapon(item)
	end
	--]]
	
	-- restock standard items
	local category_items, category_count, category_weights, category_items_set = PrepareShopItemsForRestock(BobbyRayShopGetUnlockedTier())
	for cat, _ in sorted_pairs(category_weights) do
		local total_items = category_count[cat]
		local restock_items = Max(1, MulDivRound(total_items, restock_min_percent_standard + InteractionRand(restock_max_percent_standard - restock_min_percent_standard + 1, "BobbyRayShop"), 100))
		restock_items = Min(restock_items, #category_items[cat])
		if total_items > 0 then bobby_restock_print("Restocking", restock_items, "out of", total_items, cat, "or ", MulDivRound(restock_items, 100, total_items)) end
		local picked_items = PickRandomWeightItems(restock_items, category_items[cat], category_weights[cat])
		for _, item in ipairs(picked_items) do
			RestockStandardItem(item)
		end
	end
	CombatLog("important", T(938586124784, "Inventory restock at Bobby Ray's Guns 'n Things."))
end

function BobbyRayStoreConsumeRandomStock(pick_probability, stock_min_percent, stock_max_percent)
	pick_probability = pick_probability or const.BobbyRay.FakePurchase_PickProbability
	stock_min_percent = stock_min_percent or const.BobbyRay.FakePurchase_StockConsumedMin
	stock_max_percent = stock_max_percent or const.BobbyRay.FakePurchase_StockConsumedMax
	-- standard items
	local consumed_items = 0
	local total_items = 0
	for _, item in sorted_pairs(g_BobbyRayStore.standard) do
		total_items = total_items + 1
		if item.CanBeConsumed and InteractionRand(100, "BobbyRayShop") < pick_probability then
			consumed_items = consumed_items + 1
			local current_stock = item.Stock
			local stock_purchased = Max(1, MulDivRound(current_stock, stock_min_percent, 100) + MulDivRound(current_stock, InteractionRand(stock_max_percent - stock_min_percent + 1, "BobbyRayShop"), 100))
			assert(current_stock >= stock_purchased)
			local new_stock = current_stock - stock_purchased
			item.Stock = new_stock
			bobby_restock_print("Consumed", stock_purchased, "out of", current_stock, "of", item.class, "(Standard)", "or", MulDivRound(stock_purchased, 100, current_stock))
			-- remove if stock is depleted
			if new_stock <= 0 then 
				g_BobbyRayStore.standard[item.class] = nil
				g_BobbyRayStore.standard_ids[item.id] = nil
			end
		end
	end
	if total_items > 0 then bobby_restock_print(" --------------------------- Consumed", consumed_items, "out of", total_items, "standard items", "or", MulDivRound(consumed_items, 100, total_items)) end
	
	-- used items
	consumed_items = 0
	total_items = 0
	for item_id, item in sorted_pairs(g_BobbyRayStore.used) do
		total_items = total_items + 1
		if item.CanBeConsumed and InteractionRand(100, "BobbyRayShop") < pick_probability then
			consumed_items = consumed_items + 1
			bobby_restock_print("Consumed", item.class, "(Used)")
			g_BobbyRayStore.used[item.id] = nil
		end
	end
	if total_items > 0 then bobby_restock_print(" --------------------------- Consumed", consumed_items, "out of", total_items, "used items", "or", MulDivRound(consumed_items, 100, total_items)) end
end

function BobbyRayShopSetCategory(category, subcategory)
	PDABrowserTabState["bobby_ray_shop"].category = category or "Weapons"
	PDABrowserTabState["bobby_ray_shop"].subcategory = subcategory
end

function BobbyRayShopGetActiveCategoryPair(category)
	PDABrowserTabState["bobby_ray_shop"].category = PDABrowserTabState["bobby_ray_shop"].category or "Weapons"
	return PDABrowserTabState["bobby_ray_shop"].category, PDABrowserTabState["bobby_ray_shop"].subcategory
end

function BobbyRayShopGetCategory(category)
	return FindPreset("BobbyRayShopCategory", category)
end

function BobbyRayShopGetSubCategory(subcategory)
	return FindPreset("BobbyRayShopSubCategory", subcategory)
end
---------------------------------------------------------- Weapon Components

function TFormat.GetWeaponModificationRolloverTitle(ctx)
	local component = WeaponComponents[WeaponGetComponentAt(ctx.weapon, ctx.index)]
	return component.DisplayName
end

function TFormat.GetWeaponModificationRolloverText(ctx)
	local component = WeaponComponents[WeaponGetComponentAt(ctx.weapon, ctx.index)]
	return GetWeaponComponentDescription(component)
end

function WeaponCountComponents(weapon)
	if not weapon.components then return 0 end
	
	local count = 0
	for slot, component in pairs(weapon.components) do
		local componentSlot = table.find_value(weapon.ComponentSlots, "SlotType", slot)
		-- local defaultComponent = componentSlot and componentSlot.DefaultComponent
		if component and component ~= "" then count = count + 1 end
	end
	return count
end

function WeaponGetComponentAt(weapon, index)
	if not weapon.ComponentSlots or not weapon.ComponentSlots[index] then return nil end
	
	local count = 0
	for _, slot in ipairs(weapon.ComponentSlots) do
		local comp = weapon.components[slot.SlotType]
		
		if comp and comp ~= "" then
			count = count + 1
		end
		if count == index then
			return comp
		end
	end
	return nil
end

---------------------------------------------------------- Finish purchase

GameVar("g_BobbyRay_CurrentShipments", {})

local function lBobbyRayAddShipment(departure_time, due_time, order_id, items, sector_id, total_cost, delivery_option)
	assert(not g_BobbyRay_CurrentShipments[order_id])
	g_BobbyRay_CurrentShipments[order_id] = { order_id = order_id, departure_time = departure_time, due_time = due_time, items = items, sector_id = sector_id, total_cost = total_cost, delivery_option = delivery_option.id }
	return g_BobbyRay_CurrentShipments[order_id]
end

local function lBobbyRayRemoveShipment(order_id)
	assert(g_BobbyRay_CurrentShipments[order_id])
	g_BobbyRay_CurrentShipments[order_id] = nil
end

local function lBobbyRayClearShipments()
	table.clear(g_BobbyRay_CurrentShipments)
end

local function lCheckShipments()
	local due_shipments = {}
	for order_id, shipment in pairs(g_BobbyRay_CurrentShipments) do
		if Game.CampaignTime >= shipment.due_time then
			table.insert(due_shipments, shipment)
		end
	end
	
	table.sort(due_shipments, function(a,b)
		if a.due_time > b.due_time then return false;
		elseif b.due_time > a.due_time then return true;
		end
		
		assert(a == b or a.order_id ~= b.order_id)
		if a.order_id >= b.order_id then return false;
		elseif b.order_id > a.order_id then return true;
		end
	end)
	
	for _, shipment in ipairs(due_shipments) do
		Msg("BobbyRayShopShipmentArrived", shipment)
		lBobbyRayRemoveShipment(shipment.order_id)
	end
end

function GetClosestShipment()
	if table.count(g_BobbyRay_CurrentShipments) == 0 then return nil end
	
	local closest_shipment = nil
	for id, shipment in pairs(g_BobbyRay_CurrentShipments) do
		if closest_shipment == nil or shipment.due_time < closest_shipment.due_time or shipment.order_id < closest_shipment.order_id then
			closest_shipment = shipment
		end
	end
	return closest_shipment
end

local function lGenerateShipmentId(num_attempts)
	local order_id = InteractionRand(2147483647, "BobbyRayShop")
	local count = 0
	num_attempts = num_attempts or 20
	while g_BobbyRay_CurrentShipments[order_id] do
		order_id = InteractionRand(2147483647, "BobbyRayShop")
		count = count + 1
		if count > num_attempts then return -1 end
	end
	return order_id
end

function BobbyRayShopFinishPurchase()
	-- !TODO: recheck money because of multiplayer lag? a merc could have been hired, etc.
	local order_id = lGenerateShipmentId()
	assert(order_id ~= -1, "Failed to generate shipment id (too many collisions)")
	
	local due_time = Game.CampaignTime + BobbyRayCartGetDeliveryOption().MinTime * const.Scale.day + InteractionRand((BobbyRayCartGetDeliveryOption().MaxTime - BobbyRayCartGetDeliveryOption().MinTime) * const.Scale.day)
	local sector_id = BobbyRayCartGetDeliverySector()
	local delivery_option = BobbyRayCartGetDeliveryOption()
	
	local items_number, total_cost = BobbyRayCartGetAggregate()
	
	-- create inventory entries
	local shipment_items = {}
	local units = BobbyRayCartGetUnits()
	--this generates item ids so it should be in sync order
	for unit, amount in sorted_pairs(units) do
		if amount ~= 0 then
			local actual_unit = lGetShopItemFromId(unit)
			for _, item in sorted_pairs(actual_unit:GenerateInventoryEntries(amount)) do
				table.insert(shipment_items, item)
			end
		end
	end
	
	local gossip_table = {}
	for unit, amount in pairs(units) do
		if amount ~= 0 then
			local actual_unit = lGetShopItemFromId(unit)
			table.insert(gossip_table,{
				item = actual_unit.class,
				cost = actual_unit.Cost,
				used = actual_unit.Used and true or false,
				amount = amount,
				shop_stack = actual_unit.ShopStackSize and actual_unit.ShopStackSize or 1,
			})
		end
	end
	NetGossip("BobbyRayPurchase", order_id, gossip_table, GetCurrentPlaytime(), Game and Game.CampaignTime)
	
	-- add event to satellite timeline
	local shipment_context = { sectorId = sector_id, items = shipment_items, order_id = order_id }
	AddTimelineEvent(
		"bobby_ray_shipment_" .. tostring(order_id), 
		due_time, 
		"store_shipment", 
		shipment_context
	)
	
	-- !TODO send e-mail
	
	-- update store
	for item_id, amount in pairs(units) do
		if amount > 0 then
			local item = lGetShopItemFromId(item_id)
			if item.Used then
				assert(g_BobbyRayStore.used[item.id])
				g_BobbyRayStore.used[item.id] = nil
			else
				assert(g_BobbyRayStore.standard[item.class] and g_BobbyRayStore.standard[item.class].Stock >= amount)
				g_BobbyRayStore.standard[item.class].Stock = g_BobbyRayStore.standard[item.class].Stock - amount
				if g_BobbyRayStore.standard[item.class].Stock == 0 then
					g_BobbyRayStore.standard[item.class] = nil
					g_BobbyRayStore.standard_ids[item.id] = nil
				end
			end
		end
	end
	
	-- clear cart
	BobbyRayCartClearEverything()
	
	-- update player money
	AddMoney(-total_cost, "expense")
	
	local shipment_details = lBobbyRayAddShipment(Game.CampaignTime, due_time, order_id, shipment_items, sector_id, total_cost, delivery_option)
	CombatLog("important",T{624146592949, "<em>Bobby Ray's</em> shipment sent. It will arrive in <em><timeDuration(due_time)></em> in <em><SectorName(sector_id)></em>",order_id = order_id, due_time = due_time - Game.CampaignTime, sector_id = sector_id})
	Msg("BobbyRayShopShipmentSent", shipment_details)
end

function OnMsg.BobbyRayShopShipmentArrived(shipment_details)
	local sectorStash = GetSectorInventory(shipment_details.sector_id)
	local itemsCopy = table.copy(shipment_details.items)
	if sectorStash then 
		AddItemsToInventory(sectorStash, itemsCopy)
	end
end

---------------------------------------------------------- Email

function TFormat.BobbyRayEmailItemList(context, items)
	return table.concat(table.map(items, function(item) return T{757479034237, "\t<bullet_point> <DisplayName> x <Amount>\n", DisplayName = item.DisplayName, Amount = (item.Amount or 1)} end ))
end

---------------------------------------------------------- Time advancement

function OnMsg.StartSatelliteGameplay()
	lCheckShipments()
	BobbyRayCartClearEverything()
end

function OnMsg.SatelliteTick()
	lCheckShipments()
	BobbyRayCartClearEverything()
	lForgetBobbyRayOrderTabState()
	NetSyncEvent("BobbyRayUpdateNew")
end

function OnMsg.MoneyChanged(amount, logReason, previousBalance)
	ObjModified(g_BobbyRayCart)
	ObjModified(g_BobbyRayStore)
end
---------------------------------------------------------- Multiplayer utility

local function lCloseBobbyCountdowns()
	for d, _ in pairs(g_OpenMessageBoxes) do
		if d and d.window_state == "open" and d.context.obj == "bobby-countdown" then
			d:Close()
		end
	end
end

function NetSyncEvents.CreateTimerBeforeAction(mode)
	if not CanYield() then
		CreateRealTimeThread(NetSyncEvents.CreateTimerBeforeAction, mode)
		return
	end
	
	lCloseBobbyCountdowns()
	
	local dialog = CreateMessageBox(terminal.desktop, "", "", T(739643427177, "Cancel"),  "bobby-countdown")
	local reason = "bobby-countdown"
	Pause(reason)
	PauseCampaignTime(reason)
	dialog.OnDelete = function()
		Resume(reason)
		ResumeCampaignTime(reason)
	end
	
	local countdown_seconds = 3 -- !TODO: save this as a const?
	dialog:CreateThread("bobby-countdown", function()
		if netInGame and table.count(netGamePlayers) > 1 then
			local idText = dialog.idMain.idText
			local currentCountdown = countdown_seconds
			for i = 1, countdown_seconds do
				if idText.window_state == "open" then
					if mode == "clear-order" then
						idText:SetText(T{575279476730, "<center>Clearing order in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "clear-store" then
						idText:SetText(T{332391120755, "<center>(DEV-DEBUG)Clearing store in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "finish-order" then
						idText:SetText(T{533359561728, "<center>Finishing order in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "restock" then
						idText:SetText(T{852189704117, "<center>(DEV-DEBUG)Restocking shop in <u(currentCountdown)>", currentCountdown = currentCountdown})
					elseif mode == "consume-stock" then
						idText:SetText(T{202941315408, "<center>(DEV-DEBUG)Consuming random shop stock in <u(currentCountdown)>", currentCountdown = currentCountdown})
					else
						idText:SetText(T{233587337306, "<center>Unknown action in <u(currentCountdown)>", currentCountdown = currentCountdown})
					end
				else
					break
				end
					
				Sleep(1000)
				currentCountdown = currentCountdown - 1
			end
		end
		dialog:Close()

		if mode == "clear-store" then
			if IsBobbyRayOpen("cart") then OpenBobbyRayPage() end
			BobbyRayStoreClear()
			ObjModified(g_BobbyRayStore)
		elseif mode == "clear-order" then
			if IsBobbyRayOpen("cart") then OpenBobbyRayPage() end
			BobbyRayCartClearEverything()
			ObjModified(g_BobbyRayCart)
		elseif mode == "finish-order" then
			OpenBobbyRayPage()
			ObjModified("BobbyRayShopFinishPurchaseUI")
			BobbyRayShopFinishPurchase()
		elseif mode == "consume-stock" then
			BobbyRayStoreConsumeRandomStock()
			ObjModified(g_BobbyRayStore)
			ObjModified(g_BobbyRayCart)
		elseif mode == "restock" then
			BobbyRayStoreRestock()
			ObjModified(g_BobbyRayStore)
			ObjModified(g_BobbyRayCart)
		else
			assert("unknown mode:", mode)
		end
	end)
	
	local res = dialog:Wait()
	if res == "ok" then
		NetSyncEvent("CancelBobbyCountdown", mode, netUniqueId)
	end
end

function NetSyncEvents.CancelBobbyCountdown(mode, player_id)
	lCloseBobbyCountdowns()
end

function SavegameSessionDataFixups.BobbyRayTabState(data, meta)
	assert(data.gvars.PDABrowserTabState)
	if not data.gvars.PDABrowserTabState.bobby_ray_shop then
		data.gvars.PDABrowserTabState.bobby_ray_shop = { locked = true }
	end
end

---------------------------------------------------------- Satellite Squad

DefineClass.ShipmentWindowClass = {
	__parents = { "XMapObject", "XContextWindow" },
	ZOrder = 3,
	IdNode = true,
	ContextUpdateOnOpen = true,
	ScaleWithMap = false,
	FXMouseIn = "SatelliteBadgeRollover",
	FXPress = "SatelliteBadgePress",
	FXPressDisabled = "SatelliteBadgeDisabled",
	RolloverOffset = box(30, 24, 0, 0),
	RolloverBackground = RGBA(255, 255, 255, 0),
	PressedBackground = RGBA(255, 255, 255, 0),

	routes_displayed = false,
	
	route_visible = true
}

function ShipmentWindowClass:UpdateZoom(prevZoom, newZoom, time)
	local map = self.map
	local maxZoom = map:GetScaledMaxZoom()
	local minZoom = Max(1000 * map.box:sizex() / map.map_size:x(), 1000 * map.box:sizey() / map.map_size:y())
	newZoom = Clamp(newZoom, minZoom + 120, maxZoom)

	XMapWindow.UpdateZoom(self, prevZoom, newZoom, time)
end

function ShipmentWindowClass:GetTravelPos()
	return self:GetVisualPos()
end

function ShipmentWindowClass:SetVisible(visible)
	XMapObject.SetVisible(self, visible)
	XContextWindow.SetVisible(self, visible)
	
	if not self.routes_displayed then return end
	self.routes_displayed["main"][1]:SetVisible(visible)
	for _1, decoration in pairs(self.routes_displayed["main"].decorations) do
		decoration:SetVisible(visible)
	end
end

function ShipmentWindowClass:Close()
	XMapObject.Close(self)
	if self.window_state == "open" or self.window_state == "closing" then XContextWindow.Close(self) end
	
	if not self.routes_displayed then return end
	self.routes_displayed["main"][1]:Close()
	for _1, decoration in pairs(self.routes_displayed["main"].decorations) do
		decoration:Close()
	end
end

function CreateBobbyRayShipmentSquad(shipment_details)	
	local predef_props = {
		Side = "player1",
		arrival_squad = true, arrival_shipment = true, 
		shipment = shipment_details, 
		Name = "Bobby Ray's shipment " .. tostring(shipment_details.order_id), -- !TODO: this would need to be a translated string, but I'm not showing a rollover, for now.
		CurrentSector = shipment_details.sector_id -- !TODO: should this be something else? Perhaps inferred from the travel time? I believe it may affect its label
	}
	return XTemplateSpawn("BobbyRaySquadWindow", g_SatelliteUI, predef_props)
end

function ShipmentUIUpdateMovement(shipment_window)
	local lateLayoutThread = shipment_window:GetThread("late-layout")
	if lateLayoutThread and CurrentThread() ~= lateLayoutThread then
		shipment_window:DeleteThread(lateLayoutThread)
	end

	shipment_window:DeleteThread("sat-movement")
	shipment_window:CreateThread("sat-movement", ArrivingShipmentTravelThread, shipment_window)
end

function ArrivingShipmentTravelThread(shipment_window)
	local shipment = shipment_window.context.shipment
	local sectorId = shipment.sector_id
	local sY, sX = sector_unpack(sectorId)
	local sectorPos = gv_Sectors[sectorId].XMapPosition
	local leftMostSectorId = sector_pack(sY, 1)
	
	local positions, routeSegments = ComputeArrivingPath(leftMostSectorId, sectorId)

	if not shipment.departure_time then -- save fixup, essentially
		local preset = FindPreset("BobbyRayShopDeliveryDef", shipment.delivery_option)
		assert(preset)
		shipment.departure_time = shipment.due_time - preset.MaxTime * const.Scale.day
	end
	
	local routeEndDecoration = XTemplateSpawn("SquadRouteDecoration", g_SatelliteUI)
	if g_SatelliteUI.window_state == "open" then
		routeEndDecoration:Open()
	end
	routeEndDecoration:SetRouteEnd(point(0, sY), sectorId)
	routeEndDecoration:SetColor(GameColors.Player)
	
	if not shipment_window.routes_displayed then shipment_window.routes_displayed = {} end
	shipment_window.routes_displayed["main"] = routeSegments
	routeSegments.decorations = { routeEndDecoration }
	
	local totalTime = shipment.due_time - shipment.departure_time
	local timeLeft = shipment.due_time - Game.CampaignTime
	DisplayArrivingPathRemainder(totalTime, timeLeft, routeSegments, positions, shipment_window)
end

---------------------------------------------------------- Rollover Button

DefineClass.PDABobbyRayPopupButtonClass = {
	__parents = { "PDACommonButtonClass" },
	has_lost_rollover = false
}

function PDABobbyRayPopupButtonClass:OnLayoutComplete()
	if not self.has_lost_rollover then
		if not self:MouseInWindow(terminal.GetMousePos()) then
			self.has_lost_rollover = true
		end
	end
	PDACommonButtonClass.OnLayoutComplete(self)
end

function PDABobbyRayPopupButtonClass:SetupCategoryButton()
	local dlg = GetDialog(self)
	local alignMenuTo = self
	local category = BobbyRayShopGetCategory(self:GetContext())
	local categoryId, subcategoryId = BobbyRayShopGetActiveCategoryPair()
	local active_category = BobbyRayShopGetCategory(categoryId)
	local active_subcategory = BobbyRayShopGetSubCategory(subcategoryId)
	local ctxMenu = XTemplateSpawn("PDABrowserBobbyRay_Store_SubCategoryMenu", dlg, { category = category, active_category = active_category, active_subcategory = active_subcategory })
	ctxMenu:SetAnchor(alignMenuTo.box)
	ctxMenu:SetMinWidth(self.measure_width)
	ctxMenu.button = self
	ctxMenu:Open()
	self:OnOpenPopupMenu()
	self.desktop:SetModalWindow(ctxMenu)
	self.has_lost_rollover = false
end

function PDABobbyRayPopupButtonClass:RolloverCategoryButton(rollover)
	if GetUIStyleGamepad() then return end
	if rollover then
		CreateRealTimeThread(function()
			Sleep(1) -- to avoid recursive update
			self:SetupCategoryButton()
		end)
	end
end

function PDABobbyRayPopupButtonClass:OnSetRollover(rollover)
	if rollover and self.has_lost_rollover then
		self:RolloverCategoryButton(rollover)
	elseif not rollover then
		self.has_lost_rollover = true
	end
	PDACommonButtonClass.OnSetRollover(self, rollover)
end

function PDABobbyRayPopupButtonClass:OnPress(gamepad)
	self:SetupCategoryButton()
end

function PDABobbyRayPopupButtonClass:OnClosePopupMenu()
	self:SetColumnsUse("abccd")
	if not self:MouseInWindow(terminal.GetMousePos()) then 
		self.has_lost_rollover = true 
	end
end

function PDABobbyRayPopupButtonClass:OnOpenPopupMenu()
	self:SetColumnsUse("ccccd")
end

---------------------------------------------------------- Resolution change

if FirstLoad then
	g_PrevRes = point(GetResolution())
end
function OnMsg.SystemSize(pt)
	if g_PrevRes ~= pt then
		g_PrevRes = pt
		if IsBobbyRayOpen() then
			OpenBobbyRayPage() -- front page to prevent the grid ui breaking
		end
	end
end
