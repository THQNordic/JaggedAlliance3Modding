local equip_slots = {
	["Handheld A"] = true,	
	["Handheld B"] = true,
	["Head"] = true,
	["Torso"] = true,
	["Legs"] = true,
}

function IsEquipSlot(slot_name)
	return equip_slots[slot_name]
end

function IsWeaponSlot(slot_name)
	return slot_name=="Handheld A" or slot_name=="Handheld B"
end

function GetSlotsToEquipItem(item)
	if not item then return end
	local canequipslots = {}
	local slots = UnitInventory.inventory_slots
	for _, slot_data in ipairs(slots) do
		local slot_name = slot_data.slot_name
		if IsEquipSlot(slot_name) then
			local base_class = slot_data.base_class
			if item:IsKindOfClasses(base_class) and (not slot_data.check_slot_name or item.Slot==slot_name) then
				canequipslots[#canequipslots +1] = slot_name
			end	
		end
	end
	return canequipslots
end

DefineClass.UnitInventory = {
	__parents = { "Inventory" },
	inventory_slots = {
		{ slot_name = "Inventory",     width = 6, height = 4, base_class = "InventoryItem", enabled = true },
		{ slot_name = "InventoryDead", width = 4, height = 6, base_class = "InventoryItem", enabled = true },
		{ slot_name = "Pick",          width = 2, height = 1, base_class = "InventoryItem", enabled = true },
		{ slot_name = "Handheld A",    width = 2, height = 1, base_class = {"Firearm","MeleeWeapon","HeavyWeapon","QuickSlotItem"}, enabled = true },
		{ slot_name = "Handheld B",    width = 2, height = 1, base_class = {"Firearm","MeleeWeapon","HeavyWeapon","QuickSlotItem"}, enabled = true },
		{ slot_name = "Head",          width = 1, height = 1, base_class = "Armor", check_slot_name = true, enabled = true },
		{ slot_name = "Torso",         width = 1, height = 1, base_class = "Armor", check_slot_name = true, enabled = true },
		{ slot_name = "Legs",          width = 1, height = 1, base_class = "Armor", check_slot_name = true, enabled = true },
		{ slot_name = "SetpieceWeapon",width = 2, height = 1, base_class = {"Firearm","MeleeWeapon","HeavyWeapon"}, enabled = true },
	},
	properties = {
		{ id = "current_weapon", editor = "text", default =  "Handheld A"},
	},
	pick_slot_item_src = false,
}

function UnitInventory:GetMaxTilesInSlot(slot_name)
	if slot_name=="Inventory" then
		return self:GetInventoryMaxSlots()
	elseif slot_name=="InventoryDead" then
		local max_slots = self.max_dead_slot_tiles or 24
		local rem = max_slots % 4
		if rem > 0 then
			max_slots = max_slots + 4 - rem
		end
		
		return max_slots
	else
		return Inventory.GetMaxTilesInSlot(self,slot_name)
	end
end

function UnitInventory:AddItem(slot_name, item, left, top, local_execution)
	local pos, reason = Inventory.AddItem(self, slot_name, item, left, top)
	if not pos then return pos, reason end
	
	item.owner = IsMerc(self) and self.session_id or false -- Dont bloat save with non-merc owners.
	if not local_execution then
		Msg("ItemAdded", self, item, slot_name, pos)
	end
	item:OnAdd(self, slot_name, pos, item)

	return pos, reason
end

-- add already generated items (from loot table) into inventory, stack them if can
function AddItemsToInventory(inventoryObj, items, bLog)
	local pos, reason
	for i = #items, 1, -1 do
		local item =  items[i]
		if IsKindOf(item, "InventoryStack") then
			inventoryObj:ForEachItemDef(item.class, 
				function(curitm, slot_name, item_left, item_top)
					if slot_name~="Inventory" then return end
					
				   if curitm.Amount < curitm.MaxStacks then
						local to_add = Min(curitm.MaxStacks - curitm.Amount, item.Amount)
						curitm.Amount =curitm.Amount + to_add
						if bLog then
							Msg("InventoryAddItem", inventoryObj, curitm, to_add)
						end
						item.Amount =  item.Amount - to_add			
						if item.Amount <= 0 then
							DoneObject(item)
							item = false
							table.remove(items, i)
							return "break"
						end
					end
				end)
		end
		if item then 
			pos, reason = inventoryObj:AddItem("Inventory", item)
			if pos then
				if bLog then
					Msg("InventoryAddItem", inventoryObj, item, IsKindOf(item, "InventoryStack") and item.Amount or 1)
				end
				table.remove(items, i)
			end
		else
			pos = true
		end				
	end
	ObjModified(inventoryObj)
	return pos, reason
end

function UnitInventory:AddItemsToInventory(items)
	return AddItemsToInventory(self, items, true)
end


function OnMsg.InventoryAddItem(unit, item, amount)
	LogGotItem(unit, item, amount)
end

GameVar("g_GossipItemsTakenByPlayer",{})
GameVar("g_GossipItemsSeenByPlayer",{})
GameVar("g_GossipItemsEquippedByPlayer",{})
GameVar("g_GossipItemsMoveFromPlayerToContainer",{})

function OnMsg.InventoryTakeAllAddItem(unit, item, amount, bAutoResolve)
	local item_id = item.id
	if not g_GossipItemsTakenByPlayer[item_id] and (bAutoResolve or g_GossipItemsSeenByPlayer[item_id]) then
		NetGossip("Loot","TakeByPlayer", item.class, amount, GetCurrentPlaytime(), Game and Game.CampaignTime)
		g_GossipItemsTakenByPlayer[item_id] = true
	end
	LogGotItem(unit, item, amount)
end

function OnMsg.SquadBagAddItem(item, amount)
	LogGotItem(false, item, amount)
end

function OnMsg.SquadBagTakeAllAddItem(item, amount, bAutoResolve)
	local item_id = item.id
	if not g_GossipItemsTakenByPlayer[item_id] and (bAutoResolve or g_GossipItemsSeenByPlayer[item_id])then
		NetGossip("Loot","TakeByPlayer", item.class, amount, GetCurrentPlaytime(), Game and Game.CampaignTime)
		g_GossipItemsTakenByPlayer[item_id] = true
	end	
	LogGotItem(false, item, amount)
end

if FirstLoad then
	DeferredItemLog = false
	CombatLogActorOverride = false
end

function OnMsg.NewGame()
	DeferredItemLog = false
	CombatLogActorOverride = false
end

TFormat.ItemLog = function(itemLog, unit, isSingleEntry)
	local amount = itemLog.amount or 1
	local itemNameT
	if amount > 1 then
		itemNameT = itemLog.item.DisplayNamePlural
	else
		itemNameT = itemLog.item.DisplayName
	end
	
	local res 
	if isSingleEntry then
		if unit then
			if IsKindOf(unit, "SectorStash") then
				res = T(585970067597, "Some of the items were placed in the sector stash")
			else	
				res = T{849649099073, " <amount> x <em><itemNameT></em> taken by <mercName>", amount = amount, itemNameT = itemNameT, mercName = unit:GetDisplayName()}
			end
		else
			res = T{359344947585, " <amount> x <em><itemNameT></em> added in the squad bag", amount = amount, itemNameT = itemNameT}
		end
	else
		if unit then
			if IsKindOf(unit, "SectorStash") then
				res = T(585970067597, "Some of the items were placed in the sector stash")
			else	
				res = T{581384045758, " <amount> x <em><itemNameT></em> (<mercName>)", amount = amount, itemNameT = itemNameT, mercName = unit:GetDisplayName()}
			end
		else
			res = T{437609056132, " <amount> x <em><itemNameT></em> (squad bag)", amount = amount, itemNameT = itemNameT}
		end
	end
	return res
end

function LogGotItem(unit, item, amount)
	if not item then return end
	--allow logs of ammo, parts and meds
	--if not IsKindOf(unit, "Unit") then return false end
	
	amount = amount or 1
	local actor = CombatLogActorOverride or "short"
	local logItem = { 
		unit = unit,
		item = item,
		amount = amount,
		actor = actor,
	}
	
	if DeferredItemLog then
		DeferredItemLog[#DeferredItemLog + 1] = logItem
		return
	end
	
	DeferredItemLog = { logItem }
	CreateRealTimeThread(function()
		Sleep(1)
		local text = false
		if #DeferredItemLog > 1 then
			local mercPickedUpItems = {}
			for i, log in ipairs(DeferredItemLog) do
				local amount = log.amount
				if amount == 0 then goto continue end

				if not mercPickedUpItems[log.unit] then
					mercPickedUpItems[log.unit] = {log}
				else
					for j, logItem in ipairs(mercPickedUpItems[log.unit]) do
						if log.item.class == logItem.item.class then
							logItem.amount = logItem.amount + log.amount
							goto continue
						end
					end
					table.insert(mercPickedUpItems[log.unit], log)
				end
				::continue::
			end
			
			local lineActor = DeferredItemLog[1].actor == "short" and "helper" or "importanthelper"
			
			CombatLog(DeferredItemLog[1].actor, T(435437836774, "Items acquired:"))
			local lines = {}
			
			for unit, itemsLog in pairs(mercPickedUpItems) do
				
				for _, itemLog in ipairs(itemsLog) do
					CombatLog(lineActor, TFormat.ItemLog(itemLog, unit))
				end
			end
			
			
			
			
		else
			text = TFormat.ItemLog({amount = amount, item = item}, unit, "singleEntry")
			CombatLog(DeferredItemLog[1].actor, text)
		end
		DeferredItemLog = false
	end)
end

function UnitInventory:RemoveItem(slot_name, item,...)
	local item, pos = Inventory.RemoveItem(self, slot_name, item,...)
	if not item then return end
	item:OnRemove(self, slot_name, pos, item)
	if IsKindOf(item, "BaseWeapon") and IsKindOf(self, "Unit") then
		-- Remove perk modifiers associated with this item.
		for _, id in ipairs(self.StatusEffects) do
			item:RemoveModifiers(id)
		end
	end	
	Msg("ItemRemoved", self, item, slot_name, pos)
	
	return item, pos
end

function UnitInventory:GetAvailableAmmos(weapon, ammo_type, unique)
	if not IsKindOfClasses(weapon, "Firearm", "HeavyWeapon") then
		return empty_table
	end
	local ammo_class = IsKindOfClasses(weapon, "HeavyWeapon", "FlareGun") and "Ordnance" or "Ammo"
	local types = {}
	local containers = {}
	local slots = {}
	local function add(ammo, container, slot)
		table.insert(types, ammo)
		table.insert(containers, container)
		table.insert(slots, slot)
	end
	local slot_name = GetContainerInventorySlotName(self)
	self:ForEachItemInSlot(slot_name, ammo_class, function(ammo, slot, left, top, weapon, types)
		if (not ammo_type or ammo.class == ammo_type) and ammo.Caliber == weapon.Caliber then
			if unique then
				local found = table.find(types, "class", ammo.class)
				if not found then
					add(ammo, self, slot_name)
				end
			else
				add(ammo, self, slot_name)
			end		
		end
	end, weapon, types)
	
	local squad_id = self.Squad
	local bag = GetSquadBag(squad_id)	
	for _, ammo in ipairs(bag or empty_table) do
		if IsKindOf(ammo, ammo_class)and (not ammo_type or ammo.class == ammo_type) and ammo.Caliber == weapon.Caliber then
			if unique then
				local found = table.find(types, "class", ammo.class)
				if not found then
					add(ammo, bag)
				end
			else
				add(ammo, bag)
			end		
		end
	end
	return types, containers, slots
end

-- count available ammo im mercs backpack and squads backpack
function UnitInventory:CountAvailableAmmo(ammo_type)
	local count = {count = 0}
	local slot_name = GetContainerInventorySlotName(self)
	self:ForEachItemInSlot(slot_name, ammo_type, function(ammo, slot, left, top, count)
		if (not ammo_type or ammo.class == ammo_type) then
			count.count = count.count + ammo.Amount
		end
	end, count)
	
	local squad_id = self.Squad
	local bag = GetSquadBag(squad_id)	
	for _, ammo in ipairs(bag or empty_table) do
		if (not ammo_type or ammo.class == ammo_type) then
			count.count = count.count + ammo.Amount
		end
	end
	return count.count
end

function UnitInventory:ReloadWeapon(gun, ammo_type, delayed_fx)
	local reloaded
	local ammo
	local ammo_items = {}
	local bag = self.Squad and GetSquadBagInventory(self.Squad)
	if not ammo_type or type(ammo_type) == "string" then
		if not ammo_type and gun.ammo then 
			ammo_type = gun.ammo.class
			ammo = self:GetAvailableAmmos(gun, ammo_type)
			if not ammo then 
				ammo = self:GetAvailableAmmos(gun)
			end
		else
			ammo = self:GetAvailableAmmos(gun, ammo_type)
		end
		ammo_items = ammo and table.ifilter(ammo, function(idx, stack) return stack.class == ammo[1].class and stack.Amount > 0 end)
		ammo = table.remove(ammo_items, 1)
	else
		ammo = ammo_type
		ammo_items = self:GetAvailableAmmos(gun, ammo_type.class)
		table.remove_value(ammo_items, ammo)
	end
	
	local prev, playedFX, change
	while ammo and (((gun.ammo and gun.ammo.Amount or 0) < gun.MagazineSize) or not gun.ammo or gun.ammo.class ~= ammo.class) do
		prev, playedFX, change = gun:Reload(ammo, nil, delayed_fx)
		
		local vo = gun:GetVisualObj()
		if change and vo and not playedFX then
			CreateGameTimeThread(function(weapon, obj, delayed_fx)
				--Added randomness for weapon reload to cover the case with all mercs reloading on combat end or ReloadMultiSelection shortcut(both are during unpaused game)
				if delayed_fx then
					Sleep(InteractionRand(500, "ReloadDelay"))
				end
				if GetMercInventoryDlg() then
					PlayFX("WeaponLoad", "start", obj.object_class or (obj.weapon and obj.weapon.object_class), obj)
				else
					local actor_class = obj.fx_actor_class
					obj.fx_actor_class = weapon.class
					PlayFX("WeaponReload", "start", obj)
					obj.fx_actor_class = actor_class
				end
			end, gun, vo, delayed_fx)
			playedFX = true
		end
		
		reloaded = true	
		local slot_name = GetContainerInventorySlotName(self)
		if ammo.Amount <= 0 then
			self:RemoveItem(slot_name, ammo)	
			if bag then
				bag:RemoveItem("Inventory", ammo)
			end
			ammo = table.remove(ammo_items, 1) -- keep loading from the next item stack if there's one and still not fully loaded
		else
			ObjModified(ammo)
		end
		if prev then
			if prev.Amount == 0 then
				DoneObject(prev)
			else
				bag:AddAndStackItem(prev)
			end
		end
	end
	
	if reloaded then
		local reloadOptions = GetReloadOptionsForWeapon(gun, self)
		if gun.ammo and gun.ammo.Amount and gun.ammo.Amount < gun.MagazineSize and not next(reloadOptions) then
			PlayVoiceResponse(self, "AmmoLow")
		end
	end
	
	Msg("WeaponReloaded", self)
	return reloaded
end

-- check for equipped weapons in specified Handheld slot
function UnitInventory:GetEquippedWeapons(slot_name, class)
	local weapons = {}
	self:ForEachItemInSlot(slot_name,function(item, s, l,t, weapons)
		if item:IsWeapon() and (not class or IsKindOf(item, class)) then
			weapons[#weapons +1] = item
		end	
	end, weapons)
	return weapons
end

function UnitInventory:InventoryBandage()
	local target = self
	local medicine = GetUnitEquippedMedicine(self)

	target:GetBandaged(medicine, self)
	Msg("InventoryChange", self)
end

function UnitInventory:GetBandaged(medkit, healer)
	if not self:HasStatusEffect("Bleeding") and self.HitPoints >= self.MaxHitPoints then
		return
	end
	
	-- Hemophobic quirk
	local chance = CharacterEffectDefs.Hemophobic:ResolveValue("procChance")
	if HasPerk(self, "Hemophobic") then
		local roll = InteractionRand(100, "Hemophobic")
		if roll < chance then
			PlayVoiceResponse(self, "Hemophobic")
			CombatLog("debug", T{Untranslated("<em>Hemophobic</em> proc on <unit>"), unit = self.Name})
			if g_Combat and IsValid(healer) and healer:GetBandageTarget() == self then
				healer:SetCommand("EndCombatBandage")
			end
			PanicOutOfSequence({self})
			return
		end
	end
	
	local heal_amount, condition_rate = healer:CalcHealAmount(medkit, self)	
	if (heal_amount or 0) <= 0 then
		return
	end
	self:RemoveStatusEffect("Bleeding")
	
	local voxels = self:GetVisualVoxels()
	local fire, dist = AreVoxelsInFireRange(voxels)
	if not fire or dist >= const.SlabSizeX then
		self:RemoveStatusEffect("Burning")
	end
	
	-- restore hp up to (current) max hp
	local old_hp = self.HitPoints
	self.HitPoints = Min(self.MaxHitPoints, self.HitPoints + heal_amount)
	local restored = self.HitPoints - old_hp
	self:OnHeal(restored, medkit, healer)
	
	if healer == self then
		CombatLog("short", T{934288978076, "<target> <em>bandaged</em> their wounds (<em><amount> HP</em> restored)",
			target = self.Nick or self.Name,
			amount = restored,
		})
	else
		CombatLog("short", T{559041931277, "<target> was <em>bandaged</em> by <healer> (<em><amount> HP</em> restored)",
			healer = healer.Nick or healer.Name,
			target = self.Nick or self.Name,
			amount = restored,
		})
		PlayVoiceResponse(self, "HealReceived")
	end
	
	local condition_loss = Max(1, MulDivRound(restored, 100, CombatActions.Bandage:ResolveValue("MaxConditionHPRestore")))
	condition_loss = Max(1, MulDivRound(condition_loss, condition_rate, 100))
	medkit.Condition = Clamp(medkit.Condition - condition_loss, 0, 100)
	local slot = healer:GetItemSlot(medkit)
	if slot and medkit.Condition <= 0 then
		CombatLog("short", T{831717454393, "<merc>'s <item> has been depleted", merc = healer.Nick, item = medkit.DisplayName})
		--healer:RemoveItem(slot, medkit)
		--DoneObject(medkit)
	end
		
	ObjModified(self)
	Msg("OnBandage", healer, self, restored)
	Msg("OnBandaged", healer, self, restored)
	if IsValid(healer) then
		Msg("InventoryChange", healer)
	end
end

function UnitInventory:OnHeal(hp, medkit, healer)
	Msg("OnHeal", self, hp, medkit, healer)
end

function UnitInventory:GetHandheldItems()
	local items = {}
	local slots = {}
	local item = false
	
	local y = 1
	for i = 1, 2 do
		local slot = (i == 1) and "Handheld A" or "Handheld B"
		for x = 1, 2 do
			item = self:GetItemAtPos(slot, x, y)
			if item then
				items[#items+1] = item
				slots[#slots+1] = slot
			end
		end
	end
	
	return items, slots
end

function UnitInventory:GetEquipedArmour()
	local slots = {"Head", "Torso", "Legs"}
	local items = {}
	
	for _, slot in ipairs(slots) do
		local item = self:GetItemAtPos(slot, 1, 1)
		if item then
			items[#items+1] = item
		end
	end
	
	return items
end

DefineClass.UnitData = {
	__parents = { "UnitProperties", "UnitInventory", "StatusEffectObject" },
	properties = {
		{ category = "", id = "MessengerOnline", editor = "bool", default = true },
		{ id = "status_effect_exp", editor = "nested_list", default = false, no_edit = true },
	},
}

function UnitData:GetBaseDamage(weapon)
	if IsKindOf(weapon, "Firearm") then
		return weapon.Damage
	elseif IsKindOfClasses(weapon, "Grenade", "MeleeWeapon", "Ordnance") then
		return weapon.BaseDamage
	elseif IsKindOf(weapon, "HeavyWeapon") then
		return weapon:GetBaseDamage()
	end

	return 0
end

function UnitData:CalcCritChance(weapon)
	return self:GetBaseCrit(weapon)
end

function UnitData:SetMessengerOnline(val)
	self.MessengerOnline = val
	if GetMercStateFlag(self.session_id, "OnlineNotificationSubscribe") then
		CombatLog("important", T{910877762088, "<Name> is now online.", self})
		SetMercStateFlag(self.session_id, "OnlineNotificationSubscribe", false)
	end
end

function CheatAddPerk(merc, perk_id)
	merc:AddStatusEffect(perk_id)
end

function UnitData:InitDerivedProperties()
	self.MaxHitPoints = self:GetInitialMaxHitPoints()
	self.HitPoints = self.MaxHitPoints
	self.GetMaxActionPoints = UnitProperties.GetMaxActionPoints
	self.ActionPoints = self:GetMaxActionPoints()
	
	self.Likes = table.copy(self.Likes)
	self.Dislikes = table.copy(self.Dislikes)
	
	if not self.Experience then
		local minXP = XPTable[self.StartingLevel]
		self.Experience = minXP
	end
end

function UnitData:CreateStartingPerks()
	local startingPerks = self:GetStartingPerks()
	for i, p in ipairs(startingPerks) do
		if CharacterEffectDefs[p] then
			self:AddStatusEffect(p)
		end
	end
end

function HasPerk(unit, id)
	if not IsKindOf(unit, "StatusEffectObject") or not unit.StatusEffects then return false end
	return unit.StatusEffects[id]
end

function UnitData:CreateStartingEquipment(seed, add_inventory)
	local items, looted = {}, {}
	for _, loot in ipairs(self.Equipment or empty_table) do
		local loot_tbl = LootDefs[loot]
		if loot_tbl then
			loot_tbl:GenerateLoot(self, looted, seed, items)
		end
	end
		
	self:EquipStartingGear(items)
	
end

function UnitData:IsNPC()
	local unit_data = UnitDataDefs[self.class]
	return not unit_data or not IsMerc(unit_data)
end

-- add unitdata function for checks in invenitry ui in satellite view
function UnitData:IsDowned()
	if not g_Combat then return false end
	-- valid for unit in combat mode only
	local unit = g_Units[self.session_id]
	return unit and unit:IsDowned()	
end

function UnitData:Random(max)
	return InteractionRand(max, "Loot")
end

function UnitData:IsLocalPlayerControlled()
	local squad = gv_Squads and gv_Squads[self.Squad]
	if not squad then return true end
	return IsControlledByLocalPlayer(squad and squad.Side, self.ControlledBy)
end

UnitData.CanBeControlled = UnitData.IsLocalPlayerControlled

function GetAvailableIntelSectors(sector_id)
	local available = {}
	local allSectors = {}
	local campaign = GetCurrentCampaignPreset()
	-- Check within radius of current sector
	local row, col = sector_unpack(sector_id)
	local radius = 2
	for r = row - 2, row + 2 do
		for c = col - 2, col + 2 do
			if r >= 1 and r <= campaign.sector_rows and c >= 1 and c <= campaign.sector_columns then
				local sector_id = sector_pack(r, c)
				if gv_Sectors[sector_id].Intel and not gv_Sectors[sector_id].intel_discovered then
					table.insert(available, sector_id)
				end
				table.insert(allSectors, sector_id)
			end
		end
	end
	
	return available, allSectors
end

function HandleGatherIntelCompleted(sector_id, mercs)
	local discovered_in = {}
	local intel_sectors = GetAvailableIntelSectors(sector_id)
	
	local s_id, idx 
	for i=1,2 do -- revil 2 intel sectors
		s_id, idx = table.interaction_rand(intel_sectors, "Satellite")
		if s_id then
			discovered_in[#discovered_in + 1] = s_id
			DiscoverIntelForSector(s_id, true)
			table.remove(intel_sectors, idx)
		end
	end
	
	s_id, idx = table.interaction_rand(intel_sectors, "Satellite")
	if s_id then
		local avg_wisdom = 0
		for _, m in ipairs(mercs) do
			avg_wisdom = avg_wisdom + m.Wisdom
		end
		avg_wisdom = avg_wisdom / #mercs
		local r = InteractionRand(100, "Satellite") + 1
		if r < (avg_wisdom - 25) then
			discovered_in[#discovered_in + 1] = s_id
			DiscoverIntelForSector(s_id, true)
			table.remove(intel_sectors, idx)
			s_id, idx = table.interaction_rand(intel_sectors, "Satellite")
		end
		r = InteractionRand(100, "Satellite") + 1
		if s_id and r < avg_wisdom - 55 then
			discovered_in[#discovered_in + 1] = s_id
			DiscoverIntelForSector(s_id, true)
		end
	end

	ForEachSectorAround(sector_id, 2, function(s) 
		gv_RevealedSectorsTemporarily[s] = Game.CampaignTime + 48*const.Scale.h
	end)
	RecalcRevealedSectors()
	
	local mercText = ConcatListWithAnd(table.map(mercs, function(o) return o.Nick; end))
	local sectorList = ConcatListWithAnd(table.map(discovered_in, function(o) return GetSectorName(gv_Sectors[o]); end))
	local text = false
	if #discovered_in == 0 then
		if #mercs == 1 then
			text = mercText .. T(814036636117, " has finished scouting the area and has found no <em>new intel</em>")
		else
			text = mercText .. T(266040497025, " have finished scouting the area and have found no <em>new intel</em>")
		end
	else
		if #discovered_in == 1 then
			if #mercs == 1 then
				text = mercText .. T(449289464268, " has finished scouting the area and has found intel for sector ")
			else
				text = mercText .. T(209577403591, " have finished scouting the area and have found intel for sector ")
			end
		else
			if #mercs == 1 then
				text = mercText .. T(215246075897, " has finished scouting the area and has found intel for sectors ")
			else
				text = mercText .. T(997308088801, " have finished scouting the area and have found intel for sectors ")
			end
		end
		text = text .. sectorList
	end
	
	-- text for not visited sector with property "interesting"
	local interesting_sectors = {}	
	ForEachSectorAround(sector_id, 2,
		function(s_id, interesting_sectors)
			local sector = gv_Sectors[s_id]
			if sector and sector.InterestingSector and not sector.last_enter_campaign_time then
				interesting_sectors[#interesting_sectors + 1] = GetSectorName(sector)
			end
		end, interesting_sectors)
	if next(interesting_sectors) then
		local interesting_sectors_text = T{769686665237, "Possible Operation in sectors - <sectors>", sectors = table.concat(interesting_sectors, ", ")}
		text = text.."\n"..interesting_sectors_text
	end
	
	local questHints = GetQuestsThatCanProvideHints(sector_id)
	if #questHints > 0 then
		local roll = InteractionRand(100, "Satellite")
		if roll > 50 then
			local idx = InteractionRand(#questHints, "Satellite") + 1
			local note = ShowQuestScoutingNote(questHints[idx])
			if note then
				text = text .. "\n\n".. T{717080721103, "Discovered info about nearby events:\n<note>", note = note.Text}.."\n\n"			
			end
		end
	end
	
	if DynamicSquadSpawnChanceOnScout > InteractionRand(100, "Satellite") then
		SpawnDynamicDBSquad(false, s_id)
	end
	
	return text 
end

function UnitData:RecalcOperationETA(operation, exclude_self) 
	local squad = self.Squad and gv_Squads[self.Squad]
	if not squad then return end
	local units = GetPlayerMercsInSector(squad.CurrentSector)
	for _,unit in ipairs(units) do
		local unit_data = gv_UnitData[unit]
		if unit_data.Operation==operation and (not exclude_self or unit~=self.session_id) then
			local new_eta = GetOperationTimerInitialETA(unit_data)
			if new_eta and new_eta>0 and new_eta~=unit_data.OperationInitialETA then
				unit_data.OperationInitialETA = new_eta
				Msg("OperationTimeUpdated", unit_data, operation)
			end
		end	
	end
end

function ReSortOperationSlots(sector_id,operation_id, profession, slot)
	local mercs = GetOperationProfessionals(sector_id,operation_id, profession)
	for _, merc in ipairs(mercs) do
		local mslot = merc.OperationProfessions[profession]
		if mslot then
			merc.OperationProfessions[profession] = mslot>slot and mslot-1 or mslot
		end
	end
end

function UnitData:RemoveOperationProfession(profession)
	if not profession then
		self:SetCurrentOperation("Idle")
		return
	end	
	if not self.OperationProfessions or not self.OperationProfessions[profession] then
		return
	end	
	
	local operation_id = self.Operation
	local operation = SectorOperations[operation_id]
	local prev_slot = self.OperationProfessions[profession]
	self.OperationProfessions[profession] = nil
	if not next(self.OperationProfessions) then
		self:SetCurrentOperation("Idle")
		return
	end
	ReSortOperationSlots(self:GetSector().Id,operation_id, profession, prev_slot)
	self.OperationInitialETA = GetOperationTimerInitialETA(self)
	self:RecalcOperationETA(operation_id, "exclude_self")
	Msg("OperationTimeUpdated", self, operation_id)
end

function UnitData:SetCurrentOperation(operation_id, slot, profession, partial_wounds, interrupted)
	--print("set operation: ", self.session_id, operation_id)
	local sector = self:GetSector()
	local is_operation_started = operation_id == "Idle" or operation_id == "Traveling" or operation_id == "Arriving" or
			sector and sector.started_operations and sector.started_operations[operation_id]

	if self.Operation == operation_id then
		local operation = SectorOperations[operation_id]
		if profession then
			self.OperationProfessions = self.OperationProfessions or {}
			self.OperationProfessions[profession] = self.Operation ~= "Idle" and slot or nil
		end
		operation:OnSetOperation(self, partial_wounds)
		self.OperationInitialETA = GetOperationTimerInitialETA(self)
		self:RecalcOperationETA(operation_id, "exclude_self")
		if is_operation_started then
			Msg("OperationTimeUpdated", self, operation_id)
		else	
			Msg("OperationChanged", self, operation, operation, self.OperationProfession, interrupted)
		end	
		return
	end
	local prev_operation = SectorOperations[self.Operation]
	local prev_profession = self.OperationProfession

	local prev_started = sector and sector.started_operations and sector.started_operations[self.Operation]
	local current = prev_started and prev_operation:ProgressCurrent(self, sector, self.OperationProfession or "prediction") or 0
	local target = prev_started and prev_operation:ProgressCompleteThreshold(self, sector, self.OperationProfession or "prediction") or 0
	
	prev_operation:OnRemoveOperation(self)
	local prev_professions = self.OperationProfessions
	local operation = SectorOperations[operation_id]
	self.Operation = operation_id
	self.OperationProfession = profession or operation.Professions and operation.Professions[1].id or "Idle"
	if profession or self.Operation ~= prev_operation.id then
		self.OperationProfessions = {}
		if profession then
			self.OperationProfessions[profession] = self.Operation ~= "Idle" and slot or nil
		end
	end
	
	for prof, slot in pairs(prev_professions) do
		ReSortOperationSlots(sector.Id,prev_operation.id,prof,slot)
	end

	operation:OnSetOperation(self, partial_wounds)
	self.OperationInitialETA = GetOperationTimerInitialETA(self)
	self:RecalcOperationETA(operation_id, "exclude_self") 
	if prev_operation.id ~= "Traveling" and prev_operation.id ~= "Idle" and prev_operation.id~= "Arriving" then
		self:RecalcOperationETA(prev_operation.id, "exclude_self") 	
	end
	
	local interrupted = interrupted
	local reason = interrupted
	if self.Operation == operation_id then -- we can cancel the operation in OnSetOperation
		CombatLog("debug", T{Untranslated("<em><activity></em> assigned to <DisplayName>"), self, activity = operation.display_name})
		if not sector then return end
		if operation_id == "Idle" and current < target and prev_operation.id ~= "Traveling" then
			interrupted = true
			local last_mercs =  #GetOperationProfessionals(sector.Id, prev_operation.id)
			if last_mercs == 0 and reason~="no log" then
				local perc = target==0 and 0 or MulDivRound(100, current, target)
				if perc > 0 then
					CombatLog("important", T{711857921546, "<em><display_name></em> was interrupted at <percent(percent)> in sector <SectorName(sector)>",
						prev_operation, sector = sector, percent = perc})
				end
			end
		end
	end
	ObjModified(self)
	Msg("OperationChanged", self, prev_operation, operation, prev_profession, interrupted)
end

function UnitData:SwapActiveWeapon(action_id, cost_ap)
	self.current_weapon = self.current_weapon == "Handheld A" and "Handheld B" or "Handheld A"
	ObjModified(self)
end

function UnitData:IsTravelling()
	return IsSquadTravelling(gv_Squads[self.Squad])
end

function UnitData:GetSector()
	local squad = gv_Squads[self.Squad]
	local sector_id = squad and squad.CurrentSector
	return gv_Sectors[sector_id]
end

function UnitData:RemoveItem(...)
	local res, pos = UnitInventory.RemoveItem(self, ...)
	self:CheckValidOperation()
	return res, pos
end

function UnitData:CheckValidOperation()
	if self.RequiredItem or self.Operation=="RepairItems" then
		local operation_descr = SectorOperations[self.Operation]
		local err, context = operation_descr:CanPerformOperation(self) 
		if err then
			SectorOperation_CancelByGame({self}, self.Operation, true)
		end
	end
end

-- Check for any expired mercs
function OnMsg.StartSatelliteGameplay()
	for i, ud in pairs(gv_UnitData) do
		if ud.HireStatus == "Hired" and ud.HiredUntil and Game.CampaignTime >= ud.HiredUntil then
			MercContractExpired(ud)
			return
		end
	end
end

function UnitData:Tick()
	if self.HiredUntil and Game.CampaignTime + const.Scale.h * 60 > self.HiredUntil then
		TutorialHintsState.ContractExpireHint = true
	end

	if self.HiredUntil and Game.CampaignTime >= self.HiredUntil then
		MercContractExpired(self)
	end
	
	-- heal player mercs 
	---heal militia and enemy units when no travel
	if IsMerc(self) or self.Operation~="Traveling" then
		local add = IsPatient(self) and const.Satellite.PatientHealPerTick or const.Satellite.NaturalHealPerTick
		if self.Operation=="RAndR" then
			add = const.Satellite.RandRActivityHealingMultiplier * add
		end	
		local old_hp = self.HitPoints
		self.HitPoints = Min(self.HitPoints + add, self.MaxHitPoints)
		local healed = self.HitPoints - old_hp
		if healed > 0 then
			self:OnHeal(healed)
		end
	end
	Msg("UnitDataTick", self)
end

function OnMsg.UnitDataTick(self)
	-- wound heal for enemy and militia when no travel
	if not IsMerc(self) and self.Operation~="Traveling" then
		UnitHealPerTick(self, const.Satellite.HealWoundsPerTick, const.Satellite.HealWoundThreshold, "dont log")
	end
end

local constRandomizationStats = 10
function UnitData:RandomizeStats(seed)
	local stats = GetUnitStatsCombo()
	local unit_def = UnitDataDefs[self.class]

	local rand
	for _, stat in ipairs(stats) do
		rand, seed = BraidRandom(seed, 2 * constRandomizationStats + 1)
		
		-- If the stat will be brought to or below 0 then
		-- clamp it to 0 if it was already 0 or 1 if it wasn't.
		local unitStat = self[stat]
		local modValue = rand - constRandomizationStats
		if unitStat - modValue <= 0 then
			modValue = unitStat == 0 and 0 or -(self[stat] - 1)
		end
		
		self:AddModifier("randstat", stat, false, modValue)
	end
end

function UnitData:__toluacode(indent, pstr, GetPropFunc)
	if not pstr then
		return string.format("PlaceUnitData('%s', %s)", self.class, self:SavePropsToLuaCode(indent, GetPropFunc, pstr) or "nil")
	end
	pstr:appendf("PlaceUnitData('%s', ", self.class)
	if not self:SavePropsToLuaCode(indent, GetPropFunc, pstr) then
		pstr:append("nil")
	end
	return pstr:append(")")
end

function UnitData:Die()
	if self.Squad then
		local sectorId = gv_Squads[self.Squad].CurrentSector
		local playerMercs = GetPlayerMercsInSector(sectorId)
		RewardTeamExperience(self, { units = playerMercs, sector = sectorId })
		Msg("UnitDiedOnSector", self, sectorId)
	end

	RemoveUnitFromSquad(self)
	Msg("MercHireStatusChanged", self, self.HireStatus, "Dead")
	self.HireStatus = "Dead"
	self.HiredUntil = Game.CampaignTime
end

function UnitData:AddStatusEffectWithDuration(id, duration)
	self.status_effect_exp = self.status_effect_exp or {}
	local exp_time = Game.CampaignTime + duration
	if not self.status_effect_exp[id] or self.status_effect_exp[id] < exp_time then
		self.status_effect_exp[id] = exp_time
	end
	self:AddStatusEffect(id)
end

function UnitData:GetSatelliteSquad()
	return self.Squad and gv_Squads[self.Squad]
end

function UnitData:UIHasAP(ap, action_id, args)
	if not g_Combat or not g_Units[self.session_id] then
		return true
	end
	return g_Units[self.session_id]:UIHasAP(ap, action_id, args)
end

function UnitData:GetUIScaledAP() 
	if not g_Combat or not g_Units[self.session_id] then
		return 0
	end
	return g_Units[self.session_id]:GetUIScaledAP() 
end

function UnitData:GetUIScaledAPMax() 
	if not g_Combat or not g_Units[self.session_id] then
		return 0
	end
	return g_Units[self.session_id]:GetUIScaledAPMax() 
end

function UnitData:GetUIActionPoints() 
	if not g_Combat or not g_Units[self.session_id] then
		return 0
	end
	return g_Units[self.session_id]:GetUIActionPoints() 
end

function UnitData:InventoryDisabled()

end

function OnMsg.SatelliteTick()
	for _, u in sorted_pairs(gv_UnitData or emtpy_table) do
		for effect_id, time in sorted_pairs(u.status_effect_exp or empty_table) do
			if Game.CampaignTime > time then
				u:RemoveStatusEffect(effect_id)
			end
		end
	end
end

function CreateUnitData(unitdata_id, id, seed)
	id = id or unitdata_id
	if gv_UnitData and gv_UnitData[id] then
		return gv_UnitData[id]
	end
	local unitdata_def = UnitDataDefs[unitdata_id]
	if not unitdata_def then
		local fallback = next(UnitDataDefs)
		StoreErrorSource(id, string.format("Invalid UnitDataCompositeDef '%s', falling back to '%s'!", unitdata_id, fallback))
		unitdata_def = UnitDataDefs[fallback]
		unitdata_id = fallback
	end
	local man = PlaceUnitData(unitdata_id)
	man.session_id = id
	if man then
		man.randomization_seed = seed
		if unitdata_def.Randomization then
			man:RandomizeStats(seed)
		end
		man:InitDerivedProperties()
		man:CreateStartingPerks()
		man:CreateStartingEquipment(seed, "add_inventory")
		GenerateEliteUnitName(man)
		if gv_UnitData then
			gv_UnitData[id] = man
		end
		Msg("UnitDataCreated", man)
		return man
	end
end

function AddScaledProgress(obj, progress_id, prop_id, add, max, scale)
	local scale = scale or 1000 -- one prop_id point is equal to <scale> progress_id points
	local abs_add = abs(add)
	local progress = obj[progress_id] + abs_add
	if progress >= scale then
		local sign = add ~= 0 and (add/abs_add) or 1
		obj[prop_id] = Clamp(obj[prop_id] + sign * (progress / scale), 0, max)
		progress = progress % scale
	end
	obj[progress_id] = progress
end

-- CompositeDef code
DefineClass.UnitDataCompositeDef = {
	__parents = { "CompositeDef" },
	
	-- Composite def
	ObjectBaseClass = "UnitData",
	ComponentClass = false,
	
	-- Preset
	EditorMenubarName = "Unit Editor",
	EditorMenubar = "Characters",
	EditorShortcut = "Ctrl-Alt-M",
	EditorIcon = "CommonAssets/UI/Icons/group outline.png",
	EditorCustomActions = {
		{
			Name = "Test",
		},
		{
			FuncName = "UIAddMercToSquad",
			Icon = "CommonAssets/UI/Ged/plus-one.tga",
			Menubar = "Test",
			Name = "Add Unit To Squad",
			Toolbar = "main",
		},
		{
			FuncName = "UIQuickTestUnit",
			Icon = "CommonAssets/UI/Ged/preview.tga",
			Menubar = "Test",
			Name = "Quick Test Unit in Combat of One",
			Toolbar = "main",
		},
	},
	GlobalMap = "UnitDataDefs",
	
	-- 'true' is much faster, but it doesn't call property setters & clears default properties upon saving
	StoreAsTable = false,
	-- Serialize props as an array => {key, value, key value}
	store_as_obj_prop_list = true
}

DefineModItemCompositeObject("UnitDataCompositeDef", {
	EditorName = "Unit",
	EditorSubmenu = "Unit",
})

if config.Mods then
	function ModItemUnitDataCompositeDef:TestModItem(ged)
		ModItemCompositeObject.TestModItem(self, ged)
		
		--despawn merc if on map
		local id = self.id
		if g_Units and g_Units[id] then
			LocalRemoveMercFromSquad(id)
			local mercs = GetPlayerMercsInSector()
			if mercs and #mercs == 1 and not g_Units[id] then
				local squads = GetPlayerMercSquads()
				if squads and squads[1] then
					RemoveSquadsFromLists(squads[1])
				end
			end
			gv_UnitData[id] = nil
		end
		
		CheatAddMerc(id)
	end
end

function UnitDataCompositeDef:GetWarning()
	local id = self.id
	if id and IsMerc(self) then
		local startingPerks = self:GetProperty("StartingPerks")
		local startingPerksCount = #startingPerks
		for indx, perk in ipairs(startingPerks) do
			local perkProps = CharacterEffectDefs[perk]
			if perkProps and not (perkProps.Tier == "Bronze" or perkProps.Tier == "Silver" or perkProps.Tier == "Gold") then
				startingPerksCount = startingPerksCount - 1
			end
		end
		local rspc = self:GetProperty("StartingLevel")
		if startingPerksCount + 1 < rspc  then
			return "Not enough starting perks! Should be " .. rspc - 1 .. ", has " .. startingPerksCount .. "."
		end
	end

	if not self.Name then
		return "Unit doesn't have name"
	end
end


UnitDataCompositeDef.GetMaxActionPoints = function(self) return UnitProperties.GetMaxActionPoints(self) end
UnitDataCompositeDef.GetLevel = function(self, baseLevel) return UnitProperties.GetLevel(self, baseLevel) end
UnitDataCompositeDef.GetInitialMaxHitPoints = function(self) return UnitProperties.GetInitialMaxHitPoints(self) end
UnitDataCompositeDef.GetLikedBy = function(self) return UnitProperties.GetLikedBy(self) end
UnitDataCompositeDef.GetDislikedBy = function(self) return UnitProperties.GetDislikedBy(self) end
UnitDataCompositeDef.GetUnitPower = function(self) return UnitProperties.GetUnitPower(self) end
UnitDataCompositeDef.GetStartingPerks = function(self) return UnitProperties.GetStartingPerks(self) end
UnitDataCompositeDef.GetSalaryPreview = function(self)
	return GetDailyMercSalary(self, 10)
end

UnitDataCompositeDef.PropertyTabs = {
	{ TabName = "General", Categories = {
		Preset = true,
		Stats = true,
		General = true,
		XP = true,
		AI = true,
		["Derived Stats"] = true,
		Misc = true,
		Perks = true,		
		Equipment = true,		
	} },
	{ TabName = "Leveling", Categories = {
		XP = true,
		Stats = true,
		Perks = true,		
	} },	
	{ TabName = "Hiring", Categories = {
		Hiring = true,
		["Hiring - Parameters"] = true,
		["Hiring - Lines"] = true,
		["Hiring - Conditions"] = true,
	} },	
	{ TabName = "Appearance", Categories = {
		Appearance = true,		
	} },	
	{ TabName = "Likes&Dislikes", Categories = {
		["Likes And Dislikes"] = true,
	} },
	{ TabName = "Voices", Categories = {
		["Voice"] = true,
	} },
}

function ForEachMerc(fn)
	ForEachPreset("UnitDataCompositeDef", function(preset)
		if preset.IsMercenary then fn(preset.id) end
	end)
end

function MercPresetCombo()
	local ret = {}
	ForEachMerc(function(preset) table.insert(ret, preset) end)
	table.sort(ret)
	return ret
end

function OnMsg.CombatEnd(combat, any_enemies)
	if IsCageFighting() then return end --special map and scenario - skip vr's for end combat
	local merc = GetRandomMapMerc(nil, AsyncRand()) -- no need for sync random for VR purposes
	if merc and combat.current_turn>1 then
		if combat.retreat_enemies then
			CreateMapRealTimeThread(function() 
				Sleep(2740)
				PlayVoiceResponse(merc, "CombatEndEnemiesRetreated")
			end)
			combat.retreat_enemies = false
		elseif any_enemies then
			CreateMapRealTimeThread(function() 
				Sleep(2740)
				PlayVoiceResponse(merc, "CombatEndEnemiesRemain")
			end)
		else
			CreateMapRealTimeThread(function() 
				Sleep(2740)
				PlayVoiceResponse(merc, "CombatEndNoEnemies")
			end)	
		end
	end	
	-- reset voiceresponses for combat end
	CreateMapRealTimeThread(function()
		--add delay to the reset by design: 0185549
		Sleep(2000)
		ResetVoiceResponses("OncePerCombat")
	end)
end

function UnitDataCompositeDef:SaveAll(force_save_all, by_user_request, ...)
	if Platform.developer and config.VoicesTTS then
		g_LocPollyActorsMatchTable = {}
		local updatePollyActors = function (obj)
			if IsKindOf(obj, "PropertyObject") and obj:GetProperty("pollysim") ~= "none" then
				local voice_name = obj:GetProperty("pollyvoice") or ""
				local name = obj:GetProperty("id")
				g_LocPollyActorsMatchTable[name] = voice_name
			end
		end
		ForEachPreset("UnitDataCompositeDef", updatePollyActors)
		local file_path = "svnProject/Lua/Dev/VoiceLines/__voiceActorPollyMatch.lua"
		SaveSVNFile(file_path, "return "..TableToLuaCode(g_LocPollyActorsMatchTable))
	end
	
	Preset.SaveAll(self, force_save_all, by_user_request, ...)
end

-- UnitDataCompositDefs reference LootDef presets, and their GetError needs the parent table cache populated
-- make sure it is loaded by hooking something that happens to be called at the right moment
function UnitDataCompositeDef:EditorContext(...)
	PopulateParentTableCache(LootDefs)
	return CompositeDef.EditorContext(self, ...)
end

-- Overwrite of the old PlaceUnitData 
function PlaceUnitData(item_id, instance, ...)
	local id = item_id

	local class = g_Classes[id]
	if not class then 
		printf("PlaceUnitData for invalid class %s", id)
		return PlaceUnitData("Dummy", instance, ...) 
	end

	local obj
	if UnitDataCompositeDef.store_as_obj_prop_list then
		obj = class:new({}, ...)
		SetObjPropertyList(obj, instance)
	else
		obj = class:new(instance, ...)
	end

	return obj
end
-- end of CompositeDef code

function NetSyncEvents.PlaceItemInInventoryCheat(item_name, amount, container_id, drop_chance)
	PlaceItemInInventoryCheat(item_name, amount, GetContainerFromContainerNetId(container_id), drop_chance, true)
end

function PlaceItemInInventoryCheat(item_name, amount, unit, drop_chance, sync_call)
	assert(amount ~= 0)
	if not sync_call then
		unit = unit or GetMercInventoryDlg() and GetInventoryUnit() or SelectedObj
		NetSyncEvent("PlaceItemInInventoryCheat", item_name, amount, GetContainerNetId(unit), drop_chance)
		return
	end
	local item = PlaceInventoryItem(item_name)
	item.drop_chance = drop_chance or nil
	if IsKindOf(item, "InventoryStack") then
		item.Amount = amount or item.MaxStacks
	end
	-- for debug add data as is it is a result of combining items
	if IsKindOf(item,"TransmutedItemProperties") then
		local recipe = Recipes[item.class]
		if not recipe then
			for rec, rec_data in pairs(Recipes) do
				if rec_data.ResultItems and rec_data.ResultItems[1].item == item.class then
					recipe = rec_data
					break
				end
			end
		end
		if recipe then
			item.RevertCondition = recipe.RevertCondition
			item.RevertConditionCounter = recipe.RevertConditionValue
			item.OriginalItemId = recipe.Ingredients[1].item
		end
	end
	local args = {item = item, dest_container = unit, dest_slot = "Inventory", sync_call = true}
	local r, r2 = MoveItem(args)
	return r, r2
end

function UIPlaceInInventory(root, obj, prop_id, self)
	if not IsKindOf(SelectedObj, "UnitInventory") or not obj then
		return
	end
	local r1, r2 = PlaceItemInInventoryCheat(obj.id)
	local unit = GetMercInventoryDlg() and GetInventoryUnit() or SelectedObj
	print("Trying to place item", obj.id, "in inventory of", unit.session_id)
end

function UIPlaceIngredientsInInventory(root, obj, prop_id, self)
	if not IsKindOf(SelectedObj, "UnitInventory") or not obj then
		return
	end
	local ingredients  = obj.Ingredients
	for _, ing in ipairs(ingredients) do
		PlaceItemInInventory(ing.item)
	end
end

function UIPlaceInInventoryAmmo(root, obj, prop_id, self)
	if not IsKindOf(SelectedObj, "UnitInventory") or not obj then
		return
	end
	local ammos = GetAmmosWithCaliber(obj.Caliber)
	local ammoKey = table.find(ammos, "colorStyle" , "AmmoBasicColor")
	if not ammoKey then
		ammoKey = 1
	end
	assert(ammos[ammoKey].id)
	PlaceItemInInventory(ammos[ammoKey].id)
end

local all_caps_stats = {
	Health = T(939485407221, "HEALTH"),
	Agility = T(896381935221, "AGILITY"),
	Dexterity = T(326250337641, "DEXTERITY"),
	Strength = T(250860654401, "STRENGTH"),
	Leadership = T(209792662352, "LEADERSHIP"),
	Wisdom = T(497213135536, "WISDOM"),
	Marksmanship = T(173881749528, "MARKSMANSHIP"),
	Mechanical = T(635077702917, "MECHANICAL"),
	Explosives = T(587803252973, "EXPLOSIVES"),
	Medical = T(295164282418, "MEDICAL"),
}

function GetStatAllCapsName(prop_id)
	return all_caps_stats[prop_id] or not Platform.developer and prop_id:upper() -- for props added my modders, all caps it assuming English language
end

-- Only for Elite Units
GameVar("gv_UsedEliteNames", {})
function GenerateEliteUnitName(unit)
	if unit and unit.elite then
		local namePool = {}
		if unit.eliteCategory then
			ForEachPresetInGroup("EliteEnemyName", unit.eliteCategory, function(preset)
				namePool[#namePool+1] = preset
			end)
		else
			namePool = PresetArray("EliteEnemyName")
		end
		
		while #namePool > 0 do
			local rand = InteractionRand(#namePool, "EliteName") + 1
			if not table.find(gv_UsedEliteNames, namePool[rand].id) then
				unit.Name = namePool[rand].name
				gv_UsedEliteNames[#gv_UsedEliteNames+1] = namePool[rand].id
				return
			else
				table.remove(namePool, rand)
			end
		end
	end
end

-- XP
function CalcRewardExperienceToUnit(unit, perUnitExp)
	return perUnitExp + MulDivRound(perUnitExp,(unit.Wisdom - 60),200)
end

function AccumulateTeamMemberXp(unitLogName, xpGained)
	if g_AccumulatedTeamXP[unitLogName] then
		g_AccumulatedTeamXP[unitLogName] = g_AccumulatedTeamXP[unitLogName] + xpGained
	else
		g_AccumulatedTeamXP[unitLogName] = xpGained
	end
end

function RewardTeamExperience(defeatedUnit, team, logImportant)
	if not team or not team.units or #team.units == 0 then return end

	local xpToReward = defeatedUnit.RewardExperience
	if not xpToReward then
		local level = defeatedUnit:GetLevel()
		xpToReward = XPRewardTable[level] or XPRewardTable[#XPRewardTable] or 0
	end
	
	local array = team.units
	if type(array[1]) == "string" then
		array = GetMercArrayUnitData(team.units)
	end
	
	local livingUnits = {} -- Unit data should all be alive, but units might not be, check just in case.
	for i, u in ipairs(array) do
		if not u:IsDead() then
			livingUnits[#livingUnits + 1] = u
		end
	end
	array = livingUnits;
	
	local xpBonusPercent = 0
	for i, u in ipairs(array) do -- add one time bonus xp from Teacher
		if HasPerk(u, "Teacher") then
			xpBonusPercent = xpBonusPercent + CharacterEffectDefs.Teacher:ResolveValue("squad_exp_bonus")
			break
		end
	end
	for i, u in ipairs(array) do -- add one time bonus xp from OldDog
		if HasPerk(u, "OldDog") then
			xpBonusPercent = xpBonusPercent + CharacterEffectDefs.OldDog:ResolveValue("old_dog_XP_bonus")
			break
		end
	end
	xpToReward = xpToReward + MulDivRound(xpToReward, xpBonusPercent, 100)
	
	local leveled_up = {}
	local log_msg
	local perUnit = MulDivRound(xpToReward, 1000, #team.units * 1000)

	for i, u in ipairs(array) do
		local previousLvl = u:GetLevel()
		local gain = CalcRewardExperienceToUnit(u, perUnit)
		local unitLogName = u:GetLogName()
		
		ReceiveStatGainingPoints(u, gain)
		u.Experience = (u.Experience or 0) + gain
		local newLvl = u:GetLevel()
		
		if g_AccumulatedTeamXP then
			AccumulateTeamMemberXp(unitLogName, gain)
		elseif gain > 0 then
			if i == 1 then
				log_msg = T{564767483783, "Gained XP: <unit> (<em><gain></em>)", unit = unitLogName, gain = gain}
			else
				log_msg = log_msg .. T{978587146153, ", <unit> (<em><gain></em>)", unit = unitLogName, gain = gain}
			end
		end
		
		local levelsGained = newLvl - previousLvl
		if levelsGained > 0 then
			leveled_up[#leveled_up + 1] = u
			u.perkPoints = u.perkPoints + 1
			TutorialHintsState.GainLevel = true
		end
	end
	
	if log_msg and not g_AccumulatedTeamXP then
		CombatLog(logImportant and "important" or "short", log_msg)
	end
		
	for _, u in ipairs(leveled_up) do
		CombatLog("important", T{134899495484, "<DisplayName> has reached <em>level <level></em>", SubContext(u, { level = u:GetLevel() })})
		ObjModified(u)
		Msg("UnitLeveledUp", u)
	end
end

-- Experience point thresholds per level.
XPTable =
{
	0, -- Level 1
	1000,
	2500,
	4500,
	7000, -- Level 5
	10000,
	13500,
	17500,
	22000,
	27000 -- Level 10
}

function CalcLevel(xp)
	for i = 1, #XPTable do
		if xp < XPTable[i] then return i - 1 end
	end
	return #XPTable
end

function CalcXpPercentAndLevel(xp) -- multiplied by 10 for precision to tenths
	local level = CalcLevel(xp)
	if level == #XPTable then
		return 100 * 10, #XPTable
	else
		return MulDivRound(xp - XPTable[level], 100 * 10, XPTable[level + 1] - XPTable[level]), level
	end
end

-- XP rewards for defeating an enemy, based on the enemy level
XPRewardTable =
{
	40, -- Level 1
	45,
	50,
	60,
	70, -- Level 5
	80,
	95,
	110,
	125,
	150 -- Level 10
}

-- Get the generic hire amount merc price.
function GetMercPrice(unit_data, days, include_medical, level)
	days = days or 7
	level = level or unit_data:GetLevel()

	local daily = GetDailyMercSalary(unit_data, level)
	local percentDiscount = 100 - GetMercDurationDiscountPercent(unit_data, days)
	local price = MulDivRound(daily * days, percentDiscount, 100 * 10) * 10 -- Round to tens
	
	local oneLessDay = (days - 1)
	local oneDayLessDiscount = 100 - GetMercDurationDiscountPercent(unit_data, oneLessDay)
	local oneDayLessPrice = MulDivRound(daily * oneLessDay, oneDayLessDiscount, 100 * 10) * 10
	local minRaise = oneDayLessPrice + 100
	if price < minRaise then -- Ensure that adding days is always at least $100 more expensive.
		price = minRaise
	end

	local medical = include_medical and CalculateMedical(unit_data) or 0
	price = price + medical
	
	return price, medical
end

TFormat.MercPrice = function(ctx, days, include_medical)
	return TFormat.money(ctx, GetMercPrice(ctx, days, include_medical))
end

TFormat.MercPriceBioPage = function(ctx, days, include_medical)
	local money = Game.Money
	local price, medical = GetMercPrice(ctx, days, include_medical)
	
	local medicalTextAdd = ""
	if medical > 0 then
		medicalTextAdd = T{203193755258, " (incl. <money(medicalAmount)> medical)", medicalAmount = medical}
	end
	
	if price > money then
		return T{733522960694, "<color MercStatValue_TooExpensive><money(price)></color>", price = price} .. medicalTextAdd
	end
	return T{409566110387, "<money(price)>", price = price} .. medicalTextAdd
end

TFormat.MercPriceBioPageRollover = function(ctx)
	if not IsKindOf(ctx, "UnitProperties") then
		ctx = ctx:ResolveValue()
		if not IsKindOf(ctx, "UnitProperties") then
			return false
		end
	end

	local defaultContractRollover = T(180617047212, "The contract cost of this merc for a week.")
	local medicalRollover = T(624700359694, "The Medical deposit will be refunded if the merc is healthy at the end of their contract. It will be partially refunded if the merc is wounded at the end of the contract and lost if the merc is heavily wounded or killed in action.")

	local rolloverText = defaultContractRollover
	local price, medical = GetMercPrice(ctx, 7, true)	
	local medicalTextAdd = ""
	if medical > 0 then
		rolloverText = rolloverText .. "<newline><newline>" .. medicalRollover
	end

	return rolloverText
end

function GetMercMinDaysCanAfford(mercUd, min, def)
	local level = mercUd:GetLevel()
	local daily = GetDailyMercSalary(mercUd, level)
	
	local medical = CalculateMedical(mercUd)
	local moneyAvail = Game.Money - medical
	moneyAvail = moneyAvail
	
	if mercUd.HireStatus == "Hired" then
		moneyAvail = moneyAvail + const.Satellite.PlayerMaxDebt
	end
	
	local daysCanAfford = moneyAvail / daily
	
	if daysCanAfford > def then return def end
	if daysCanAfford < min then return min end
	
	return daysCanAfford
end

function GetDailyMercSalary(merc, level)
	local startingLevel = merc:GetProperty("StartingLevel")
	local currentLevel = level or merc:GetLevel()
	
	local levelsOver = currentLevel - startingLevel

	local salaryAtStartingLevel = merc:GetProperty("StartingSalary")
	local salaryIncrease = merc:GetProperty("SalaryIncrease")
	local currentSalary = salaryAtStartingLevel
	for level = startingLevel, currentLevel - 1 do
		local increaseAmount = MulDivRound(currentSalary, salaryIncrease, 1000)
		currentSalary = currentSalary + increaseAmount 
	end

	return currentSalary
end

function GetMercDurationDiscountPercent(merc, duration)
	local discount = merc:GetProperty("DurationDiscount")
	if discount == "none" then return 0 end
	
	local minDay, minDiscount, maxDay, maxDiscount = 0,0,0,0
	if discount == "normal" then
		minDay = 3
		minDiscount = 0
		maxDay = 14
		maxDiscount = 25
	elseif discount == "long only" then
		minDay = 7
		minDiscount = 0
		maxDay = 14
		maxDiscount = 35
	end
	
	if duration >= minDay and duration <= maxDay then
		return minDiscount + MulDivRound(duration - minDay, (maxDiscount - minDiscount), maxDay - minDay)
	end
	return 0
end

function CalculateMedical(merc)
	local deposit = merc:GetProperty("MedicalDeposit")
	if deposit == "none" then return 0 end

	local level = merc:GetLevel()
	local salary = merc:GetProperty("StartingSalary")
	
	if deposit == "small" then
		-- 1 daily salary
		return salary
	elseif deposit == "large" then
		-- 2 daily salaries
		return MulDivRound(salary, 200, 100 * 10) * 10
	elseif deposit == "extreme" then
		-- 3 daily salaries
		return MulDivRound(salary, 300, 100 * 10) * 10
	end
end

function CalculateHaggleAmount(merc, offeredAmount)
	local haggle = merc:GetProperty("Haggling")
	local percent, min = 0, 0
	if haggle == "low" then
		percent = 10
		min = 100
	elseif haggle == "normal" then
		percent = 25
		min = 200
	elseif haggle == "high" then
		percent = 50
		min = 500
	end
	local haggleAmount = MulDivRound(offeredAmount, percent * 10, 1000)
	return Max(haggleAmount, min)
end

function TFormat.MedicalMoney(context, val)
	return TFormat.money(context, CalculateMedical(context) or 0)
end

function SetMercStateFlag(mercId, flag, value)
	local trackerQuest = QuestGetState("MercStateTracker")
	assert(trackerQuest)
	local mercTable = trackerQuest[mercId]
	if not mercTable then
		trackerQuest[mercId] = {}
		mercTable = trackerQuest[mercId]
	end
	mercTable[flag] = value
end

function GetMercStateFlag(mercId, flag)
	local trackerQuest = QuestGetState("MercStateTracker")
	assert(trackerQuest)
	local mercTable = trackerQuest[mercId]
	if not mercTable then
		trackerQuest[mercId] = {}
		mercTable = trackerQuest[mercId]
	end
	return mercTable[flag]
end

-- Medical deposit logic 165599 ad. 184562
function OnMsg.MercHireStatusChanged(unit_data, previousState, newState)
	local merc_id = unit_data.session_id
	if previousState == "Available" and newState == "Hired" then
		SetMercStateFlag(merc_id, "DownedDuringContract", false)
		SetMercStateFlag(merc_id, "MedicalPaidWhenHired", CalculateMedical(unit_data))
		SetMercStateFlag(merc_id, "RejectedRehire", false)
		SetMercStateFlag(merc_id, "HiredAt", Game.CampaignTime)
		SetMercStateFlag(merc_id, "HireCount", 1) -- How many times the contract has been extended
		MercHealOnHire(merc_id)
	elseif previousState == "Hired" and newState == "Available" then
		SetMercStateFlag(merc_id, "LastHiredAt", Game.CampaignTime)
	
		local medical = GetMercStateFlag(merc_id, "MedicalPaidWhenHired")
		if medical and medical > 0 then
			local mercHp = unit_data.HitPoints
			local mercMaxHp = unit_data:GetInitialMaxHitPoints() -- without wounds
			local percentHp = MulDivRound(mercHp, 100, mercMaxHp)
			
			local dontPayBelowPercent = 20
			percentHp = Max(0, percentHp - dontPayBelowPercent)
			if percentHp < dontPayBelowPercent then percentHp = 0 end
			
			medical = MulDivRound(medical, percentHp, 100 - dontPayBelowPercent)
			if medical > 0 then
				CombatLog("important", T{619266158254, "<Nick> has returned their medical deposit", unit_data})
				AddMoney(medical, "deposit")
			end
		end
	end
	
	-- Add random amount of xp on first hire 204339
	local isImp = not not string.find(merc_id, "IMP")
	if newState == "Hired" and not GetMercStateFlag(merc_id, "RandomEXPGiven") then -- and not isImp then
		local randomXpRangeMin = XPTable[1]
		local randomXpRangeMax = XPTable[2]
		local range = randomXpRangeMax - randomXpRangeMin
		range = MulDivRound(range, 600, 1000)
		range = randomXpRangeMin + InteractionRand(range, "RandomXPOnHire")
		unit_data.Experience = (unit_data.Experience or 0) + range
		local unit = g_Units[merc_id]
		if unit then
			unit.Experience = (unit.Experience or 0) + range
		end
		SetMercStateFlag(merc_id, "RandomEXPGiven", true)
	end
end

-- Mercs are healed when hired (but not contract extended) based on how
-- much time elapsed since they were last hired. This is an approximation of the RnR operation
function MercHealOnHire(merc_id)
	local ud = gv_UnitData[merc_id]
	local lastHireExpire = GetMercStateFlag(merc_id, "LastHiredAt")
	if not lastHireExpire then return end -- Wasn't hired before
	
	local timeElapsed = Game.CampaignTime - lastHireExpire
	local ticksPassed = timeElapsed / const.Satellite.Tick
	
	if ticksPassed > 0 then
		local woundStacks = PatientGetWoundedStacks(ud)
		ud.wounds_being_treated = PatientGetWoundedStacks(ud)
		
		local perTick = SectorOperations.RAndR:ResolveValue("HealPerTickBase")
		local threshold = SectorOperations.RAndR:ResolveValue("HealWoundThreshold") -- progress to heal one wound
		
		PatientAddHealWoundProgress(ud, perTick * ticksPassed, threshold, "no_log")
	end 
	
	-- Always heal to full and restore tiredness
	ud.HitPoints = ud.MaxHitPoints
	ud:SetTired(const.utNormal)
	
	ud.randr_activity_progress = 0
	ud.wounds_being_treated = 0
end

function OnMsg.MercContractExtended(merc)
	local merc_id = merc.session_id
	SetMercStateFlag(merc_id, "HiredAt", Game.CampaignTime)
	SetMercStateFlag(merc_id, "HireCount", (GetMercStateFlag(merc_id, "HireCount") or 1) + 1)
end

function OnMsg.UnitDowned(unit)
	local sessionId = IsMerc(unit) and unit.session_id
	if not sessionId then return end
	SetMercStateFlag(sessionId, "DownedDuringContract", true)
end

-- used by Combat participation condition
function OnMsg.ConflictStart(sector_id)
	if not next(gv_Quests) then return end -- Quick Start starts a conflict before quests are initialized.

	local squads = GetSquadsInSector(sector_id)
	for i, squad in ipairs(squads) do
		if squad.Side == "player1" then
			for i, uid in ipairs(squad.units) do
				local ud = gv_UnitData[uid]
				if IsMerc(ud) then
					local conflictList = GetMercStateFlag(uid, "ConflictsParticipated") or {}
					conflictList[#conflictList + 1] = { sector_id, Game.CampaignTime }
					SetMercStateFlag(uid, "ConflictsParticipated", conflictList)
				end
			end
		end
	end
end

function GetMercConflictsParticipatedWithinLastDays(merc_id, days, unique_sectors)
	local list = GetMercStateFlag(merc_id, "ConflictsParticipated")
	if not list then return 0 end
	local day = Game.CampaignTime / const.Scale.day

	local count = 0
	local sectorsDedupe = {}
	for i, conflict in ipairs(list) do
		local where = conflict[1]
		local when = conflict[2] / const.Scale.day
		if day - when > days then goto continue end
		if unique_sectors and sectorsDedupe[where] then goto continue end
		sectorsDedupe[where] = true;
		count = count + 1
		
		::continue::
	end
	return count
end

-- Stat Gaining

function ReceiveStatGainingPoints(unit, xpGain)
	if HasPerk(unit, "OldDog") then return end
	
	local xp = unit.Experience
	local xpPercent, level = CalcXpPercentAndLevel(xp)
	local pointsToGain = 0
	
	local xpTresholds = {}
	local interval = 1000 / const.StatGaining.PointsPerLevel
	for i=1, const.StatGaining.PointsPerLevel-1 do
		xpTresholds[#xpTresholds+1] = (xpTresholds[#xpTresholds] or 0) + interval
	end
	xpTresholds[#xpTresholds+1] = 1000
		
	while level < #XPTable and xpGain > 0 do -- loop per levelup, check all milestones
		local tempXp = Min(xpGain, XPTable[level + 1] - XPTable[level])
		xp = xp + tempXp
		xpGain = xpGain - tempXp
		
		local newXpPercent, newLevel = CalcXpPercentAndLevel(xp)
		if newLevel > level then newXpPercent = 100 * 10 end
		
		for i = 1, #xpTresholds do
			if xpPercent < xpTresholds[i] and newXpPercent >= xpTresholds[i] then
				pointsToGain = pointsToGain + 1
			end
		end
		
		level = newLevel
		xpPercent = 0
	end
	
	if level == #XPTable and xpGain > 0 then -- after max level
		local xpSinceLastMilestone = (xp - XPTable[#XPTable])
		-- Currently after lvl 10 you get a point every <MilestoneAfterMax> xp increasing by <MilestoneAfterMaxIncrement> xp every time
		local milestone = const.StatGaining.MilestoneAfterMax
		local increment = const.StatGaining.MilestoneAfterMaxIncrement
		while xpSinceLastMilestone >= milestone do
			xpSinceLastMilestone = xpSinceLastMilestone - milestone
			milestone = milestone + increment
		end
		
		while xpGain > 0 do -- loop per after max level milestone
			local xpToMilestone = milestone - xpSinceLastMilestone
			local tempXp = Min(xpGain, xpToMilestone)
			xp = xp + tempXp
			xpGain = xpGain - tempXp
			
			if tempXp >= xpToMilestone then
				pointsToGain = pointsToGain + 1
				xpSinceLastMilestone = 0
				milestone = milestone + increment
			end
		end
	end
	unit.statGainingPoints = unit.statGainingPoints + pointsToGain
end

StatGainReason = {
	FieldExperience = T(417395547281, "Field Experience"),
	Studying = T(713701397094, "Studying"),
	Training = T(168227169104, "Training"),
}

function GainStat(unit, stat, gainAmount, modId, reason)
	assert(stat)
	if unit:IsDead() then return end
	local unitData = gv_UnitData[unit.session_id]
	local unit = g_Units[unit.session_id]
	gainAmount = gainAmount or 1
	reason = reason or "FieldExperience"
	
	modId = modId or string.format("StatGain-%s-%s-%d", stat, unitData.session_id, GetPreciseTicks())
	local mod = unitData:AddModifier(modId, stat, false, gainAmount)
	if unit then
		unit:AddModifier(modId, stat, false, gainAmount)
	end
	Msg("ModifierAdded", unitData, stat, mod)
	
	local unitName = unitData:GetLogName()
	local statName = table.find_value(UnitPropertiesStats:GetProperties(), "id", stat).name
	if reason ~= "Training" then
		CombatLog("important", T{124938068325, "<em><unit></em> gained +<amount> <em><stat></em>",
			unit = unitName,
			stat = statName,
			amount = gainAmount
		})
	end
	if stat == "Health" then
		if unit then
			RecalcMaxHitPoints(unit)
		end
		RecalcMaxHitPoints(unitData)
	end

	ObjModified(unit)
	ObjModified(unitData)
	
	Msg("StatIncreased", unitData, stat, gainAmount, reason)
	PlayFX("StatIncreased", "start", stat)
	return stat
end

function GetPrerequisiteState(unit, id)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	if statGaining[id] then
		return statGaining[id].state
	else
		return false
	end
end

MapVar("g_StatGainingMapCDs", {}) 
--	state: Custom information that needs to be saved and tracked
--	gain: 	If the unit achieved the prerequisite
function SetPrerequisiteState(unit, id, state, gain)
	NetUpdateHash("SetPrerequisiteState", unit, id, state, gain)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	if not statGaining[id] then statGaining[id] = {} end
	
	if gain then -- reset the state
		statGaining[id].state = false
	else -- update the state
		statGaining[id].state = state 
	end
	SetMercStateFlag(unit.session_id, "StatGaining", statGaining)
	
	if gain then -- roll for statgain
		local prerequisite = StatGainingPrerequisites[id]
		local stat = prerequisite.relatedStat
		local failChance =  prerequisite.failChance
		
		if not prerequisite.oncePerMapVisit or not g_StatGainingMapCDs[id] then
			RollForStatGaining(unit, stat, failChance)
		end
		g_StatGainingMapCDs[id] = true
	end	
end

function RollForStatGaining(unit, stat, failChance)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	local cooldowns = statGaining.Cooldowns or {}
	local success_text = "(fail) "
	local reason_text = ""
	
	local roll = InteractionRand(100, "StatGaining")
	if not failChance or roll >= failChance then
		if unit.statGainingPoints > 0 then 
			if(not cooldowns[stat] or cooldowns[stat] <= Game.CampaignTime) then
				if unit[stat] > 0 and unit[stat] < 100 then
					local threshold = unit[stat] - const.StatGaining.BonusToRoll
					local roll = InteractionRand(100, "StatGaining") + 1
					if roll >= threshold then
						GainStat(unit, stat)
						unit.statGainingPoints = unit.statGainingPoints - 1
						
						-- set when the cooldown expires
						local cd = InteractionRandRange(const.StatGaining.PerStatCDMin, const.StatGaining.PerStatCDMax, "StatCooldown")
						cooldowns[stat] = Game.CampaignTime + cd
						statGaining.Cooldowns = cooldowns
						
						success_text = "(success) "
					else
						reason_text = "Need: " .. threshold .. ", Rolled: " .. roll .. "/100"
					end
				else
					reason_text = stat .. " is " .. unit[stat]
				end
			else
				reason_text = stat .. " is in cooldown"
			end
		else
			reason_text = "Not enough milestone points"
		end
	else
		reason_text = "Fail chance proced"
	end
	CombatLog("debug", success_text .. _InternalTranslate(unit.Nick) .. " stat gain " .. stat .. ". " .. reason_text)
	
	SetMercStateFlag(unit.session_id, "StatGaining", statGaining)
end

g_MercStatGainVisualize = false

function UpdateStatGainVisualization(window)
	local merc = window and window.context
	local visualizationForMerc = merc and g_MercStatGainVisualize and g_MercStatGainVisualize[merc]
	local timeStarted = visualizationForMerc and visualizationForMerc.timeStart
	
	local duration = 1000
	local timeLeft = 0
	if timeStarted then
		timeLeft = duration - (RealTime() - timeStarted)
	end
	
	if not visualizationForMerc or timeLeft <= 0 then
		if visualizationForMerc then g_MercStatGainVisualize[merc] = false end
		visualizationForMerc = false
		window:SetVisible(false)
		return
	end
	
	local stat = visualizationForMerc and visualizationForMerc.stat
	local amount = visualizationForMerc and visualizationForMerc.amount
	
	local meta = Presets.MercStat.Default
	local metaEntry = meta and meta[stat]
	if metaEntry then
		window.idStatIcon:SetImage(metaEntry.Icon)
	end
	window.idStatCount:SetText("+" .. amount)

	if timeLeft > 0 then
		window:DeleteThread("hide-stat-gain")
		window:CreateThread("hide-stat-gain", function()
			window:SetVisible(true)
			Sleep(timeLeft + 1)
			UpdateStatGainVisualization(window)
		end)
	end
end

function OnMsg.StatIncreased(unit, stat, amount)
	if not g_MercStatGainVisualize then g_MercStatGainVisualize = {} end
	local unitName = unit.session_id
	g_MercStatGainVisualize[unitName] = {
		timeStart = RealTime(),
		stat = stat,
		amount = amount,
	}
	ObjModified(unitName)
end

function StatGainingInspectorFormat(unit)
	local statGaining = GetMercStateFlag(unit.session_id, "StatGaining") or {}
	local res = {}
	res[#res+1] = unit.Name
	
	ForEachPreset("StatGainingPrerequisite", function(preset)
		local presetDetails = "<color 20 122 122>" .. preset.id .. "</color>" .. " (" .. preset.relatedStat .. ")" .. ": " .. preset.Comment
		res[#res+1] = presetDetails
		if statGaining[preset.id] and statGaining[preset.id].state then
			local presetState = preset.id .. " - "
			
			local state = statGaining[preset.id].state
			if state and type(state) == "table" then
				for k, v in pairs(state) do
					presetState = presetState .. k .. ": " .. v .. ". "
				end
			end
			res[#res+1] = presetState
		end
	end)
	
	local percent, level = CalcXpPercentAndLevel(unit.Experience)
	res[#res+1] = "<color 8 86 86>Current Xp</color>: " .. unit.Experience .. "xp, " .. percent/10 .. "," .. percent%10 .. "% of Level " .. level .. ". "
	res[#res+1] = "<color 8 86 86>Stat Gaining points</color>: " .. unit.statGainingPoints
	
	if statGaining.Cooldowns then
		for k, v in pairs(statGaining.Cooldowns) do
			res[#res+1] = "<color 8 86 86>" .. k .. " CD</color>: " .. _InternalTranslate(TFormat.time({}, v)) .. " " .. _InternalTranslate(TFormat.date({}, v))
		end
	end

	return res
end

-- Tracked Stats
function GetTrackedStat(unit, id)
	local statTracking = GetMercStateFlag(unit.session_id, "StatTracking") or {}
	return statTracking[id]
end

function SetTrackedStat(unit, id, value)
	local statTracking = GetMercStateFlag(unit.session_id, "StatTracking") or {}
	statTracking[id] = value
	SetMercStateFlag(unit.session_id, "StatTracking", statTracking)
end

-- Employment History
function AddEmploymentHistoryLog(unit, presetId, context)
	local employmentHistory = GetMercStateFlag(unit.session_id, "EmploymentHistory") or {}
	local log = { id = presetId, level = unit:GetLevel(), time = Game.CampaignTime, context = context }
	employmentHistory[#employmentHistory+1] = log
	SetMercStateFlag(unit.session_id, "EmploymentHistory", employmentHistory)
end

function GetEmploymentHistory(unit)
	return GetMercStateFlag(unit.session_id, "EmploymentHistory") or {}
end

-- Modifications
GameVar("NewModifications", {})
function OnMsg.ModifierAdded(unit, prop, mod)
	if not IsMerc(unit) then return end
	local modedProps = NewModifications[unit.session_id] or {}
	local mods = modedProps[prop] or {}
	
	mods[#mods+1] = mod
	modedProps[prop] = mods
	
	NewModifications[unit.session_id] = modedProps
end

-- from, to: session_id
function ReplaceMerc(from, to, keepInventory)
	local fromUnitData = gv_UnitData[from]
	local toUnitData = gv_UnitData[to]

	local hireStatus = fromUnitData.HireStatus
	if hireStatus ~= "Hired" then return end
	
	local hiredUntil = fromUnitData.HiredUntil
	local squad = gv_Squads[fromUnitData.Squad]
	
	fromUnitData.HireStatus = toUnitData.HireStatus
	fromUnitData.HiredUntil = false
	fromUnitData.Squad = false
	local squadIdx = table.remove_entry(squad.units, from)

	
	toUnitData.HireStatus = hireStatus
	toUnitData.HiredUntil = hiredUntil
	toUnitData.Squad = squad.UniqueId
	table.insert(squad.units, squadIdx, to)
	
	toUnitData.Experience = fromUnitData.Experience
	toUnitData.arrival_dir = fromUnitData.arrival_dir
	toUnitData.retreat_to_sector = fromUnitData.retreat_to_sector
	toUnitData.perkPoints = fromUnitData.perkPoints
	toUnitData.statGainingPoints = fromUnitData.statGainingPoints
	toUnitData.Tiredness = fromUnitData.Tiredness
	
	local trackerQuest = QuestGetState("MercStateTracker")
	trackerQuest[to] = trackerQuest[from]
	
	Msg("MercHireStatusChanged", fromUnitData, "Hired", false)
	Msg("MercHireStatusChanged", toUnitData, false, "Hired")
	
	if keepInventory then -- just swap their inventory slots
		for _, slotData in ipairs(fromUnitData.inventory_slots) do
			local slotName = slotData.slot_name
			local slot = fromUnitData[slotName]
			fromUnitData[slotName] = toUnitData[slotName]
			toUnitData[slotName] = slot
		end
	end
	
	-- status effects
	for _, effect in ipairs(fromUnitData.StatusEffects) do
		if not IsKindOf(effect, "Perk") or IsKindOf(effect, "Perk") and effect:IsLevelUp() then
			toUnitData:AddStatusEffect(effect.class)
		end
	end
	
	-- modifications
	if fromUnitData.modifications then
		local modList = fromUnitData.applied_modifiers
		fromUnitData:ApplyModifiersList(toUnitData.applied_modifiers)
		toUnitData:ApplyModifiersList(modList)
	end
	
	local unit = g_Units[from]
	if unit then
		local pos = unit:GetPos()
		local angle = unit:GetAngle()
		local side = unit.team and unit.team.side
		
		local newUnit = Unit:new{ 
			unitdatadef_id = to,
			session_id = to,
		}
		
		if SelectedObj == unit then
			SelectObj(newUnit)
		end
		
		DoneObject(unit)

		AddToGlobalUnits(newUnit)

		if angle then
			newUnit:SetAngle(angle)
		end
		if pos then
			newUnit:SetPos(pos)
		end
		if side then
			newUnit:SetSide(side)
		end
	end
	
	ObjModified(squad)
	ObjModified(fromUnitData)
	ObjModified(toUnitData)
end

function OnMsg.EnterSector(game_start, load_game)
	for session_id, unit_data in sorted_pairs(gv_UnitData) do
		if IsMerc(unit_data) and not g_Units[session_id] then
			unit_data:ForEachItem(false, function(item, slot)
				item:ApplyModifiersList(item.applied_modifiers)
			end)
		end
	end
end