-- base class handling the syncronization to sector inventory
DefineClass.SectorInventoryObj = {
	__parents = { "Object", "Inventory", "GameDynamicDataObject" },
}

function SectorInventoryObj:Init()
	self:AddInSectorInventory()
end

function SectorInventoryObj:Done()
	self:RemoveFromSectorInventory()
end

function SectorInventoryObj:AddInSectorInventory()
	if not gv_Sectors or not gv_CurrentSectorId then
		return
	end
	local cdata = self:GetSectorContainerData()
	if not cdata then
		-- ?container handle on different maps - can be the same?
		cdata = { self:GetHandle(), self.bOpened }
		local sector = gv_Sectors[gv_CurrentSectorId]
		if not sector then
			sector = {}
			gv_Sectors[gv_CurrentSectorId] = sector
		end
		sector.sector_inventory = sector.sector_inventory or {}
		table.insert(sector.sector_inventory, cdata)
	end
	return cdata
end

function SectorInventoryObj:RemoveFromSectorInventory()
	local cdata, sector_inventory, idx = self:GetSectorContainerData()
	if cdata then
		table.remove(sector_inventory, idx)
	end
end

function SectorInventoryObj:GetSectorContainerData()
	local sector = gv_Sectors and gv_Sectors[gv_CurrentSectorId]
	local sector_inventory = sector and sector.sector_inventory
	local idx = table.find(sector_inventory, 1, self:GetHandle())
	if idx then
		return sector_inventory[idx], sector_inventory, idx
	end
end

function SectorInventoryObj:AddItem(slot_name, item, left, top, local_execution)
	local pos, reason = Inventory.AddItem(self, slot_name, item, left, top)

	if pos then
		local cdata = self:GetSectorContainerData()
		if cdata then
			local val, idx = table.find_value(cdata[3], item)
			if not val then
				cdata[3] = cdata[3] or {}
				table.insert(cdata[3], item)
			end
		end
	end
	self:ContainerChanged()

	return pos, reason
end

function SectorInventoryObj:RemoveItem(slot_name, item, no_update)
	local item, pos = Inventory.RemoveItem(self, slot_name, item, no_update)	

	-- sync with sector data	
	local cdata = self:GetSectorContainerData()
	local items = cdata and cdata[3]
	table.remove_entry(items, item)
	
	self:ContainerChanged()

	return item, pos
end

function SectorInventoryObj:SyncWithSectorInventory()
	local cdata = self:GetSectorContainerData()
	local items = cdata and cdata[3] or empty_table
	self:ForEachItem(function(item, slot_name, left, top, items) 
		if not table.find(items, item) then
			Inventory.RemoveItem(self, slot_name, item)
		end
	end, items)
	local slot_name = self.inventory_slots[1].slot_name
	for k, item in sorted_pairs(items) do
		if not self:HasItemInSlot(slot_name, item) then
			Inventory.AddItem(self, slot_name, item)
		end
	end
	self:ContainerChanged()
end

function SectorInventoryObj:ContainerChanged()
	self:DespawnCheck()
end

function SectorInventoryObj:DespawnCheck()
end

function SectorInventoryObj:SetDynamicData(data)
	self:SyncWithSectorInventory()
end

DefineClass.ItemContainer = {
	__parents = { "SectorInventoryObj", "Lockpickable", "BoobyTrappable" },
	flags = { efSelectable = true },
	inventory_slots = {
		{ slot_name = "Inventory", width = 4, height = 2, base_class = "InventoryItem", enabled = true, dont_save = true },
	},
	bOpened = false,
	interacting_unit = false,
}

function ItemContainer:GameInit()
	PlayFX("Spawn", "start", self)
end

function ItemContainer:Done()
	PlayFX("Spawn", "end", self)
end

function ItemContainer:Open(unit)
	NetUpdateHash("ItemContainer:Open", self, self.lockpickState)
	if self:CannotOpen() then
		NetUpdateHash("ItemContainer:Open:CannotOpen")
		return self:PlayCannotOpenFX(unit)
	end
	
	if self:TriggerTrap(unit) then
		NetUpdateHash("ItemContainer:Open:TriggerTrap")
		return false
	end
	
	self:PlayLockpickableFX("open")
	
	local visuals = ResolveInteractableVisualObjects(self)
	for i,obj in ipairs(visuals) do
		NetUpdateHash("ItemContainer:Open_loop", i, obj, obj:GetStateText(), obj:GetEntity(), IsValidEntity(obj:GetEntity()), obj:HasState("open"))
		if obj:GetStateText() == "idle" and IsValidEntity(obj:GetEntity()) and obj:HasState("open") then
			if obj:HasState("opening") then
				local anim_duration = GetAnimDuration(obj, "opening")
				NetUpdateHash("ItemContainer:Open_Sleep", anim_duration, obj, obj:GetStateText())
				obj:SetState("opening")
				Sleep(anim_duration)
			end
			obj:SetState("open")
			break
		end
	end
	
	self.bOpened = true

	local cdata = self:GetSectorContainerData()
	if cdata then
		cdata[2] = self.bOpened
		-- add items
		local items = {}
		self:ForEachItem(function(item, slot_name, left, top, items)
			items[#items + 1] = item
		end, items)
		cdata[3] = items
	end
	
	return true
end

function ItemContainer:IsOpened()
	return self.bOpened
end

function ItemContainer:GetTitle()
	return T(532393878412, "Item container")
end

function ItemContainer:GetInteractionCombatAction(unit)
	if self.interacting_unit then return end
	
	local trapAction, icon = BoobyTrappable.GetInteractionCombatAction(self, unit)
	if trapAction then return trapAction, icon end
	
	if self:CannotOpen() then
		local baseAction = Lockpickable.GetInteractionCombatAction(self, unit)
		if baseAction then return baseAction end 
	end
	
	return Presets.CombatAction.Interactions.Interact_LootContainer
end

function ItemContainer:RegisterInteractingUnit(unit)
	assert(not self.interacting_unit)
	self.interacting_unit = unit
	self:DespawnCheck()
end

function MultipleRegisterInteractingUnit(containers, unit)
	for i, container in ipairs(containers) do
		if not container.interacting_unit then
			container:RegisterInteractingUnit(unit)
		end
	end
end

function ItemContainer:UnregisterInteractingUnit(unit)
	assert(self.interacting_unit == unit)
	self.interacting_unit = nil
	self:DespawnCheck()
end

function MultipleUnregisterInteractingUnit(containers, unit)
	for i, container in ipairs(containers) do
		if container.interacting_unit == unit then
			container:UnregisterInteractingUnit(unit)
		end
	end
end

function ItemContainer:EndInteraction(unit)
	Interactable.EndInteraction(self, unit)
end

function ItemContainer:LockpickStateChanged(status)
	local state = false
	if self:CannotOpen() then
		state = "idle"
	elseif status == "open" then
		state = "open"
	end
	if not state then return end
	
	local visuals = ResolveInteractableVisualObjects(self)
	for i,obj in ipairs(visuals) do
		if obj:HasState(state) then obj:SetState(state) end
	end
end

function ItemContainer:SetDynamicData(data)
	self.bOpened = data.bOpened
	if self.bOpened then
		local visuals = ResolveInteractableVisualObjects(self)
		for i,obj in ipairs(visuals) do
			if obj:HasState("open") then
				obj:SetState("open")
			end
		end
	end
end

function ItemContainer:GetDynamicData(data)
	if self.bOpened then
		data.bOpened = self.bOpened
	end
end

function NetSyncEvents.OpenContainer(container, unit_id)
	if not container then return end

	local unit = g_Units[unit_id]
	if not container:IsOpened() then
		container:Open(unit)
	end
end

function OnMsg.LockpickableBrokeOpen(self)
	-- Breaking an inventory objects incurs a condition penalty
	-- and a chance to destroy non guaranteed drop items.
	local destroyedAny
	if IsKindOf(self, "Inventory") then
		self:ForEachItem(function(item, slot_name, left, top)
			if IsKindOf(item, "ItemWithCondition") then
				local conditionDamage = 20 + InteractionRand(30, "Lockpick")
				self:ItemModifyCondition(item, -conditionDamage)
			end
			if not item.guaranteed_drop or IsKindOf(item, "QuestItem") then
				-- destroy some of the stack items
				if IsKindOf(item, "InventoryStack") then
					local oldAmount = item.Amount
					local percentRemoved = 20 + InteractionRand(30, "Lockpick")
					item.Amount = MulDivRound(item.Amount, percentRemoved, 100)
					item.Amount = Max(item.Amount, 1)
					
					destroyedAny = true
					CombatLog("debug", (oldAmount - item.Amount) .. " " .. item.class .. " were destroyed when opening box")
				end
			end
		end)
		ObjModified(self)
	end
	
	if destroyedAny then
		CombatLog("important", T(146944507889, "Some items were destroyed while attempting to open the box"))
	end
end

-- Handle destroying of item container visual objects dropping the loot on the ground.
function OnMsg.DamageDone(attacker, target, damage, hit_descr)
	if not target:IsDead() then return end -- Check if object died
	if not target:HasMember("spawner") or not IsKindOf(target.spawner, "ItemContainer") then return end -- Object is part of item container
	local spawner = target.spawner
	if not spawner:GetItemInSlot("Inventory") then return end -- Container has items in it
	if not spawner.enabled then return end
	
	-- All of the container's objects are dead (destroyed)
	local spawnerObjs = spawner.objects
	local allDead = true
	for i, o in ipairs(spawnerObjs) do
		if IsKindOf(o, "CombatObject") and not o:IsDead() then
			allDead = false
			break
		end
	end
	
	-- Drop guaranteed drop item, dump everything else.
	if allDead then
		local items = {}
		spawner:ForEachItemInSlot("Inventory", function(item, slot, left, top, items)
			if item.guaranteed_drop or IsKindOf(item, "QuestItem") then
				items[#items + 1] = item
			else
				CombatLog("debug", "Item " .. item.class .. " was destroyed when destroying box")
			end
		end, items)
		spawner:ClearSlot("Inventory")
		
		if #items > 0 then
			local container = GetDropContainer(spawner)
			for i, item in ipairs(items) do
				container:AddItem("Inventory", item)
			end
			local x, y, z = FindFallDownPos(container)
			if not x then return end
			CreateGameTimeThread(GravityFall, container, point(x, y, z))
		end
	end
end

-- ItemDropContainer
DefineClass.ItemDropContainer = {
	DisplayName = T(131517457472, "Dropped Items"),
	__parents = { "ItemContainer", "SyncObject", "GameDynamicSpawnObject" },
	entity = "JungleCamp_Backpack_01",
	flags = { efCollision = false, efApplyToGrids = false },
	despawn_time = 0,
	despawn_thread = false,
	discovered = true,
	bOpened = true,
	__toluacode = empty_func, --fixes assert when trying to generate game record with invalid item drop containers
}

function ItemDropContainer:Done()
	DeleteThread(self.despawn_thread)
	self:UpdateInteractableBadge(false)
end

function ItemDropContainer:GetInteractionPos(unit)
	local positions = ItemContainer.GetInteractionPos(self, unit)
	if type(positions) == "table" then
		if unit and not table.find(positions, GetPassSlab(self)) then
			positions = ItemContainer.GetInteractionPos(self) -- return occupied positions too (backward compatibility)
		end
	end
	return positions
end

function ItemDropContainer:GetInteractionCombatAction(unit)
	-- Disable interaction when there is another unit on the container tile,
	-- because the unit on the tile could drop items without interacting with the container.
	-- Only one player could view/change the container at a time.
	-- We do it for both single and multiplayer for consistency, but it's required only to
	-- disable interaction when the other player controlled unit is on the tile.
	if not next(self.Inventory) then
		return false
	end
	if unit then
		local mypos = point_pack(SnapToVoxel(self:GetPosXYZ()))
		local upos = point_pack(SnapToVoxel(unit:GetPosXYZ()))
		if upos ~= mypos then
			local x, y = point_unpack(mypos)
			local tile_unit = MapGetFirst(x, y, const.SlabSizeX/2, "Unit", function(u, mypos)
				return not u:IsDead() and mypos == point_pack(SnapToVoxel(u:GetPosXYZ()))
			end, mypos)
			if tile_unit then
				return false
			end
		end
	end
	return ItemContainer.GetInteractionCombatAction(self, unit)
end

function ItemDropContainer:DespawnCheck()
	local despawn = not self.interacting_unit and not next(self.Inventory)
	if despawn == IsValidThread(self.despawn_thread) then
		return
	end
	if despawn then
		NetUpdateHash("DespawnCheck", self)
		self.despawn_thread = CreateGameTimeThread(function(self)
			Sleep(self.despawn_time)
			self.despawn_thread = nil
			DoneObject(self)
		end, self)
	else
		DeleteThread(self.despawn_thread)
		self.despawn_thread = false
	end
end

-- walks through all item containers in that sector
DefineClass.SectorStash = {
	__parents = { "Inventory" },
	inventory_slots = {
		{slot_name = "Inventory",  width = 4, height = 1, base_class = "InventoryItem", enabled = true },
	},
	sector_id = false,
	pickup_netsent = false,
	DisplayName = T(660371035462, "Sector stash"),
}

function SectorStash:ResetBinding()
	--the traditional inventory structure of this container is not sync ordered, therefore enum funcs with it will iterate in an async order;
	--however the "virtual" container data should be the same
	--so, rebuild async container before sync op
	local id = self.sector_id
	self:Clear()
	self:SetSectorId(id)
end

function SectorStash:GetSlotDataDim(slot_name)
	local slot_data = self:GetSlotData(slot_name)
	local width = slot_data.width
	local count = #self[slot_name] + 2 --self:CountItemsInSlot(slot_name)*2 -- pretend all are 2 tiles length
	local height = count/width + (count%width==0 and 0 or 1) + 1
	local height = Max(self:GetMaxTopPos(slot_name), height)
	height = Max(4, height)
	return width, height, width
end

function SectorStash:GetMaxTopPos(slot_name)
	local items = self[slot_name]
	if not next(items) then return 1 end
	local slot_data = self:GetSlotData(slot_name)
	local max = 0
	for i = #items, 1, -2 do
		local item, pos = items[i], items[i-1]
		local l,t = point_unpack(pos)
		max = Max(max, t)
	end
	return max
end

function SectorStash:Clear()
	local invSlot = self["Inventory"]
	if not IsKindOf(invSlot, "InventorySlot") then return end
	DoneObject(invSlot)
	invSlot = false
	self.sector_id = false
	self["Inventory"] = InventorySlot:new()
end

function SectorStash:GetVirtualContainerData()
	local sector = gv_Sectors and gv_Sectors[self.sector_id]
	local sector_inventory = sector and sector.sector_inventory
	local idx = table.find(sector_inventory, 1, "virtual")
	if idx then
		return sector_inventory[idx], sector_inventory, idx
	end
end

function SectorStash:AddDeadUnitsItems()
	if not gv_Sectors or not self.sector_id then
		return
	end
	local units_list = gv_Sectors[self.sector_id].dead_units
	for _, session_id in ipairs(units_list) do
		local ud = gv_UnitData[session_id]
		if ud and ud:IsDead() then
			ud:ForEachItemInSlot("InventoryDead", function(item, slot, left, top, self)
				Inventory.AddItem(self, "Inventory", item)
			end, self)
		end
	end
end

function SectorStash:RemoveDeadUnitsItem(item)
	if not gv_Sectors or not self.sector_id then
		return
	end
	local found = false
	local itm, pos
	local units_list = gv_Sectors[self.sector_id].dead_units
	for _, session_id in ipairs(units_list) do
		local ud = gv_UnitData[session_id]
		if ud and ud:IsDead() then
			itm, pos = ud:RemoveItem("InventoryDead", item)	
			if itm then
				found = true
				break
			end
		end
	end
	return itm, pos
end

function SectorStash:AddVirtualContainer()
	if not gv_Sectors or not self.sector_id then
		return
	end
	local cdata, sector_inventory, idx = self:GetVirtualContainerData()
	if not cdata then
		cdata = { "virtual", true }
		local sector = gv_Sectors[self.sector_id]
		if not sector then
			sector = {}
			gv_Sectors[self.sector_id] = sector
		end
		sector.sector_inventory = sector.sector_inventory or {}
		sector_inventory = sector.sector_inventory 
		table.insert(sector.sector_inventory, cdata)
	end
	return cdata, #sector_inventory
end

function SectorStash:SetSectorId(sector_id)
	local sector_id = sector_id or gv_CurrentSectorId	
	
	if self.sector_id == sector_id then
		return
	end
	
	self:Clear()
	
	self.sector_id = sector_id
	self:AddDeadUnitsItems()
	local containers = gv_Sectors[sector_id].sector_inventory or empty_table
	self:AddVirtualContainer()
	for cidx, container in ipairs(containers) do
		if container[2] then -- opened
			local items = container[3] or empty_table
			for idx, item in sorted_pairs(items) do
				Inventory.AddItem(self,"Inventory", item)
			end
		end
	end
end

function SectorStash:AddItem(slot_name, item, left, top, local_execution, use_pos)
	-- add to virtual container	
	local cdata = self:GetVirtualContainerData()
	if not cdata then
		AddToSectorInventory(self.sector_id, item)
	end	

	if cdata then
		cdata[3] = cdata[3] or {}
		local val, idx = table.find_value(cdata[3], item)
		if val then
			cdata[3][idx]=item -- if something is changed
		else
			table.insert(cdata[3], item)
		end	
	end
	local x, y
	if left then
		x, y = left, top
	end
	return Inventory.AddItem(self,"Inventory", item, x, y)
end

function SectorStash:RemoveItem(slot_name, item, no_update)
	local item, pos = Inventory.RemoveItem(self, slot_name, item, no_update)
	-- remove from dead units
	local itm, pos = self:RemoveDeadUnitsItem(item)
	if itm then 
		return itm , pos
	end	
	--remove from container	

	local containers = gv_Sectors[self.sector_id].sector_inventory or empty_table
	local found = false
	for cidx, container in ipairs(containers) do
		local items = container[3] or empty_table
		for i = #items, 1, -1 do
			if items[i]==item then
				table.remove(items, i)
				if container[1]~= "virtual" then
					local obj = HandleToObject[container[1]]
					if IsKindOf(obj, "SectorInventoryObj") then 
						obj:SyncWithSectorInventory()
--[[				else -- debug
						for i, obj in sorted_pairs(HandleToObject) do
							if IsKindOf(obj, "SectorInventoryObj") then
								if obj:GetItemPos(item) then
									print("change container handle")
									gv_Sectors[self.sector_id].sector_inventory[cidx][1] = obj:GetHandle()
									obj:SyncWithSectorInventory()
								end
							end
						end
--]]						
					end
				end
				found = true
				break
			end
		end
		if found then
			break
		end	
	end
	return item, pos
end

function SectorStash:GetMaxTilesInSlot(slot_name)
	local width, height = self:GetSlotDataDim(slot_name)
	return width*height
end

------------------------------------------------------------------------------------------------------------
function AddToSectorInventory(sector_id, items)
	if not gv_Sectors then
		return		
	end
	local sector = gv_Sectors and gv_Sectors[sector_id]
	local sector_inventory = sector and sector.sector_inventory
	local idx = sector_inventory and table.find(sector_inventory, 1, "virtual")
	local virtual = idx and sector_inventory[idx]
	
	if not virtual then
		virtual = { "virtual", true }
		if not sector then
			sector = {}
			gv_Sectors[sector_id] = sector
		end
		sector.sector_inventory  =  sector.sector_inventory  or {}
		sector_inventory = sector.sector_inventory 
		table.insert(sector.sector_inventory, virtual)
	end
	if virtual then
		virtual[3] = virtual[3] or {}
		for _, item in ipairs(items) do
			local val, idx = table.find_value(virtual[3], item)
			if val then
				virtual[3][idx] = item -- if something is changed
			else
				table.insert(virtual[3], item)
			end	
		end
	end
end


function SectorContainersHasItem(sector_id, item_id, amount)
	local sector_id = sector_id or gv_CurrentSectorId
	if not sector_id then
		return false
	end
	local cur_amount = 0
	if sector_id=="all_sectors" then
		for sector_id, data in gv_Sectors do
			local containers = data.sector_inventory or empty_table
			for cidx, container in ipairs(containers) do
				if container[2] then
					local items = container[3] or empty_table
					for idx, item in ipairs(items) do
						if item.class == item_id then
							cur_amount = cur_amount + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
							if cur_amount >= amount then
								return true
							end	
						end	
					end	
				end
			end	
		end
		return false	
	else
		local containers = gv_Sectors[sector_id] and gv_Sectors[sector_id].sector_inventory or empty_table
		local cur_amount = 0
		for cidx, container in ipairs(containers) do
			if container[2] then
				local items = container[3] or empty_table
				for idx, item in ipairs(items) do
					if item.class == item_id then
						cur_amount = cur_amount + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
						if cur_amount >= amount then
							return true
						end	
					end	
				end
			end
		end	
		return false
	end
end


function ExecSectorItemContainers(fn, ...)
	local containers = gv_Sectors[gv_CurrentSectorId].sector_inventory or empty_table
	for _,container in ipairs(containers) do
		local handle = container[1]
		local obj = HandleToObject[handle]
		local res
		res = fn(obj, ...)
		if res=="break" then
			return "break"
		end
	end	
end

function TakeItemFromMercs(mercs, item_id, count, callback_on_take, ...)
	local args = {...}
	local amount = {count = count}
	for idx, merc in ipairs(mercs) do
		local unit = gv_UnitData[merc]
		local unit_amount = 0
		unit:ForEachItemDef(item_id, function(item, slot, amount)
			local is_stack = IsKindOf(item, "InventoryStack")
			local val = is_stack and item.Amount or 1
			local remove = Min(amount.count, val)
			amount.count = amount.count - remove
			if val == remove then
				unit:RemoveItem(slot, item)
			elseif is_stack then -- item.Amount > remove
				item.Amount = item.Amount - remove
			end
			unit_amount = unit_amount + remove
			ObjModified(unit)
			if callback_on_take then
				callback_on_take(unit, item, unit_amount, table.unpack(args))
			end
			if amount.count <= 0 then
				return "break"
			end	
		end, amount)
		if amount.count <= 0 then
			break
		end
	end
	for idx, merc in ipairs(mercs) do
		local unit = gv_UnitData[mercs[idx]]
		if not unit then return end
		amount.count = TakeItemFromSquadBag(unit.Squad, item_id, amount.count, callback_on_take,...)	
	end	
	return amount.count
end

function TakeItemFromSectorInventory(sector, item_id, count)
	local containers = sector.sector_inventory or empty_table
	for cidx, container in ipairs(containers) do
		if container[2] then -- is opened
			local items = container[3] or empty_table
			for idx = #items, 1, -1 do
				local item = items[idx]
				if item and item.class == item_id then
					local is_stack = IsKindOf(item, "InventoryStack")
					local val = is_stack and item.Amount or 1
					local remove = Min(count, val)
					count = count - remove
					if val == remove then
						table.remove(items, idx)
						if gv_CurrentSectorId==sector.Id then
							local obj = HandleToObject[container[1]]
							if obj then 
								obj:SyncWithSectorInventory() 
							end
						end
					elseif is_stack then -- item.Amount > remove
						item.Amount = item.Amount - remove
					end
					if count <= 0 then
						return 0
					end
				end
			end
		end
	end
	return count
end

function HasItemInSquad(unit_id, ItemId, Amount, AnySquad)
	if not unit_id then 
		return false 
	end
	local all_mercs = false
	local squad = unit_id and gv_UnitData[unit_id] and gv_UnitData[unit_id].Squad
	local squads = {}
	if squad then
		if AnySquad then
			local side = gv_Squads[squad].Side
			all_mercs = {}
			for _, sqd in pairs(gv_Squads) do
				if sqd.Side == side then
					table.iappend(all_mercs, sqd.units)
					squads[#squads + 1] = sqd.UniqueId
				end
			end	
		else	
			all_mercs = table.copy(gv_Squads[squad].units)
			squads[#squads + 1] = squad
		end
		table.remove_entry(all_mercs, unit_id)
		table.insert(all_mercs, 1, unit_id) -- prioritize unit_id
	else
		all_mercs = GetAllPlayerUnitsOnMapSessionId()
		squads = table.imap(g_PlayerSquads,"UniqueId")
	end
	
	local calc_all = type(Amount)~= "number" 
	local amount = 0
	for idx, merc in ipairs(all_mercs) do
		local unit = gv_UnitData[merc]
		if unit then
			unit:ForEachItemDef(ItemId, function(item, slot, self_Amount)
				amount = amount + (item.Amount or 1)
				if not calc_all and amount >= self_Amount then
					return "break"
				end	
			end, Amount)
		end
		if not calc_all and amount >= Amount then
			return true
		end	
	end
	for _, squad in ipairs(squads) do
		local bag = GetSquadBag(squad) or empty_table
		for _, item in ipairs(bag) do
			if item.class == ItemId then
				amount = amount + (item.Amount or 1)
			end
		end
	end
	if not calc_all then
		return amount >= Amount, amount
	end	
	return true, amount
end

function NetSyncEvents.SyncItemContainers()
	if not gv_Sectors then return end
	MapForEach("map", "ItemContainer", function(o) 
		o:SyncWithSectorInventory()
	end)
end

function TestLootTablesUsage()
	local lootTablesPreset = {}
	local undefinedLootTables = {}
	local unusedLootTables = {}
	ForEachPreset("LootDef", function(lootTablePreset)
		table.insert(unusedLootTables, lootTablePreset)
		table.insert(lootTablesPreset, lootTablePreset)
	end)
	
	local function DoesLootTableIdExist(id, obj)
		if not table.find(lootTablesPreset, "id", id) then
			table.insert(undefinedLootTables, { id, obj })
		end
	end
	
	local function IsLootTableIdUsed(id)
		unusedLootTables = table.ifilter(unusedLootTables, function(idx, lootTable)
			local foundInSubItems
			for _, subItem in ipairs(lootTable) do
				if IsKindOf(subItem, "LootEntryLootDef") then
					if subItem.loot_def == id then
						foundInSubItems = true
						break
					end
				end
			end
			return id ~= lootTable.id and not foundInSubItems
		end)
	end
	
	--for each marker in markers.debug.lua on every map check used Loot Tables
	for _, markersOnMap in pairs(g_DebugMarkersInfo) do
		for	_, marker in ipairs(markersOnMap) do
			for _, lootTableId in ipairs(marker.LootTableIds) do
				DoesLootTableIdExist(lootTableId, marker)
				IsLootTableIdUsed(lootTableId)
			end
		end
	end
	
	--for each quest preset check used Loot Tables
	ForEachPreset("QuestsDef", function (questPreset)
		questPreset:ForEachSubObject("LootTableFunctionObjectBase", function(lootTable, parents)
			if lootTable.LootTableId then
				DoesLootTableIdExist(lootTable.LootTableId, questPreset)
				IsLootTableIdUsed(lootTable.LootTableId)
			end
		end)
	end)
	
	--for each conv preset check used Loot Tables
	ForEachPreset("Conversation", function (convPreset)
		convPreset:ForEachSubObject("LootTableFunctionObjectBase", function(lootTable, parents)
			if lootTable.LootTableId then
				DoesLootTableIdExist(lootTable.LootTableId, convPreset)
				IsLootTableIdUsed(lootTable.LootTableId)
			end
		end)
	end)
	
	--ignore these loot table groups
	local lootTableGroupsToIgnore = empty_table
	unusedLootTables = table.ifilter(unusedLootTables, function(idx, lootTable) return not table.find(lootTableGroupsToIgnore, lootTable.Group) end)
	
	return undefinedLootTables, unusedLootTables, lootTableGroupsToIgnore
end

-- all loot table id related Conditions & Effects inherit this class
DefineClass.LootTableFunctionObjectBase = { __parents = { "PropertyObject" } }