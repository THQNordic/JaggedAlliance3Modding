GameVar("gv_SquadBag", false)
-- save all ammo, meds, parts for squad's units
local not_accepted = T(319860782839, "Not accepted in Squad Supplies")

DefineClass.SquadBag = {
	__parents = { "Inventory" },
	inventory_slots = {
		{slot_name = "Inventory",  width = 4, large_with = 6, height = 1, base_class = "SquadBagItem", enabled = true },
	},
	squad_id = false,
	ui_mode = "small",-- small, large - to change inventory slot with
	DisplayName = T(989672962822, "Squad Ammo Bag"),
	DisplayNameShort = T(963854928388, "Squad Bag"),
	force_height = false, --when moving item during swap inv items are -2 and auto height is reduced depending on the number of total items, use this to trust the roll coming from MoveItem
}

function SquadBag:GetMaxTilesInSlot(slot_name)
	local width, height = self:GetSlotDataDim(slot_name)
	return width*height
end

function SquadBag:GetSlotDataDim(slot_name)
	local slot_data = self:GetSlotData(slot_name)	
	local width = self.ui_mode =="small" and slot_data.width or slot_data.large_with
	local count = self:CountItemsInSlot(slot_name)
	if InventoryDragItem and InventoryStartDragContext == self then
		count = count + 1 -- draging one
	end	

	count =  count + 2 -- add 2 free space
	local height = count/width + (count%width==0 and 0 or 1)
	height = Max(1, height, self.force_height or 0)
	return width, height, width
end

function SquadBag:GetSquadBag()
	return GetSquadBag(self.squad_id)
end

function SquadBag:Clear()
	local invSlot = self["Inventory"]
	if not IsKindOf(invSlot, "InventorySlot") then return end
	DoneObject(invSlot)
	invSlot = false
	self.squad_id=false
	self["Inventory"] = InventorySlot:new()
end

g_squad_bag_sort_thread = false
function SortItemsInBag(squad_id)
	DeleteThread(g_squad_bag_sort_thread)
	g_squad_bag_sort_thread = CreateGameTimeThread(_SortItemsInBag, squad_id)
end

function _SortItemsInBag(squad_id)
	local bag_items = GetSquadBag(squad_id)
	local stacks = {}
	for idx, item in ipairs(bag_items) do
		for i = 1, #stacks do
			local bag_item = stacks[i]
			if bag_item.class == item.class then
				local to_add = Min(bag_item.MaxStacks - bag_item.Amount, item.Amount)
				if to_add>0 then
					bag_item.Amount = bag_item.Amount + to_add
					item.Amount = item.Amount - to_add
					if item.Amount==0 then
						DoneObject(item)
						item = false
						break
					end
				end
			end	
		end
		if item and item.Amount and item.Amount>0 then
			stacks[#stacks + 1] = item
		end
	end
	table.sort(stacks, function(a,b) 
		local tname_a = a.class
		local tname_b = b.class
		if not tname_a then return false end
		if not tname_b then return true end
		if tname_a=="Meds" then
			if tname_b=="Meds" then-- meds
				return a.Amount>b.Amount
			end
			return true
		end	
		if tname_a=="Parts" then
			if tname_b=="Meds" then
				return false
			elseif tname_b=="Parts" then-- part
				return a.Amount>b.Amount
			else
				return true
			end
		end	
		if IsKindOf(a, "Ammo") then-- a is ammo	
			if tname_b=="Meds" or tname_b == "Parts" then
				return false
			end		
			if IsKindOf(b, "Ammo") then
				local caliber_a = a.Caliber 
				local caliber_b = b.Caliber 
				if caliber_a == caliber_b then
					if a.Amount == b.Amount then
						return a.class < b.class
					else
						return a.Amount > b.Amount
					end
				else 
					return caliber_a < caliber_b 
				end
			end
			return true
		else
			if tname_b=="Meds" or tname_b == "Parts" or IsKindOf(b, "Ammo") then
				return false
			end		
			return tname_a<tname_b
		end	
		return false
	end)
	gv_Squads[squad_id].squad_bag = stacks
end

function SquadBag:SetUMode(ui_mode)	
	if self.ui_mode==ui_mode then
		return
	end
	self.ui_mode = ui_mode
	local squad_id = self.squad_id
	self:Clear()
	self:SetSquadId(squad_id)
end

function SquadBag:SetSquadId(squad_id)	
	if self.squad_id==squad_id then
		return
	end	
	
	self:Clear()
	
	self.squad_id = squad_id
	local items = self:GetSquadBag() or empty_table	
	for idx, item in ipairs(items) do
		Inventory.AddItem(self,"Inventory", item)
	end
end

function SquadBag:AddItem(slot_name, item, left, top, local_execution)
	local pos, reason = Inventory.AddItem(self, slot_name, item, left, top, local_execution)
	if not pos and left and top then
		--failed to add item @ specific slot, but this container self expands, try without specific pos
		pos, reason = Inventory.AddItem(self, slot_name, item)
	end

	if pos then
		local cdata = self:GetSquadBag() or {}		
		if cdata then			
			local left, top = point_unpack(pos)
			local currentitem = self:GetItemInSlot(slot_name, false, left, top)
			local val, idx = table.find_value(cdata,currentitem)
			if val then
				cdata[idx]=currentitem -- if something is changed
			else
				table.insert_unique(cdata,currentitem)
			end	
		end
		gv_Squads[self.squad_id].squad_bag = cdata
	end
	
	SortItemsInBag(self.squad_id)
	return pos, reason
end

function SquadBag:AddAndStackItem(item)
	MergeStackIntoContainer(self, "Inventory", item)
	
	if item.Amount > 0 then
		self:AddItem("Inventory", item)
		ObjModified(item)
	else
		DoneObject(item)
	end
end

function SquadBag:RemoveItem(slot_name, item, no_update)
	local item, pos = Inventory.RemoveItem(self, slot_name, item, no_update)	

	-- sync with sector data	
	local cdata = self:GetSquadBag()
	table.remove_entry(cdata, item)
	gv_Squads[self.squad_id].squad_bag = cdata
	
	SortItemsInBag(self.squad_id)
	return item, pos
end

function SquadBag:InventoryDisabled()

end

function GetSquadBagInventory(squad_id, ui_mode)
	if not gv_SquadBag then
		gv_SquadBag = PlaceObject("SquadBag")
	end
	--if ui_mode and gv_SquadBag.ui_mode~=ui_mode then
		gv_SquadBag:Clear()
		gv_SquadBag.ui_mode = ui_mode
	--end	
	gv_SquadBag:SetSquadId(squad_id)
	return gv_SquadBag
end

function GetSquadBag(squad_id)
	if not squad_id then return end
	local squad = gv_Squads and gv_Squads[squad_id]
	local bag = squad and squad.squad_bag
	return bag
end

function OnMsg.MercHireStatusChanged(unit_data, previousState, newState)
	if previousState == "Available" and newState == "Hired" then
		local merc_id = unit_data.session_id
		if merc_id and unit_data.Squad then
			MoveItemsToSquadBag(merc_id, unit_data.Squad)
		end
	end
end

function MoveItemsToSquadBag(unit_id,squad_id)	
	local bag = gv_Squads[squad_id].squad_bag or {}
	local unit = unit_id
	if type(unit_id)=="string" then
		unit = gv_UnitData[unit_id] or g_Units[unit_id]
	end
	unit:ForEachItemInSlot("Inventory",function(item, slot, l, t, unit, bag)
		if item:IsKindOf("SquadBagItem") then
			unit:RemoveItem("Inventory",item)
			table.insert_unique(bag, item)
		end
	end, unit, bag)	
	SortItemsInBag(squad_id)
	gv_Squads[squad_id].squad_bag = bag
	
	InventoryUIResetSquadBag()
	InventoryUIRespawn()
end

function TakeItemFromSquadBag(squad_id, item_id, count, callback_on_take,...)	
	local bag = GetSquadBag(squad_id)or {}
	
	local args = {...}
	local count = count
	local amount = 0
	for i = #bag, 1, -1 do
		local item =  bag[i]
		if item.class == item_id then
			local is_stack = IsKindOf(item, "InventoryStack")
			local val = is_stack and item.Amount or 1
			local remove = Min(count, val)
			count = count - remove
			if val == remove then
				table.remove_entry(bag, item)
			elseif is_stack then -- item.Amount > remove
				item.Amount = item.Amount - remove
			end
			amount = amount + remove
			if callback_on_take then
				callback_on_take(squad_id, item, amount, table.unpack(args))
			end
			if count <= 0 then
				break
			end	
		end
	end	
	
	InventoryUIResetSquadBag()
	InventoryUIRespawn()
	
	return count
end

-- add items generated from loot table to squad bag
function AddItemsToSquadBag(squad_id, items)	
	local bag = GetSquadBag(squad_id)
	if not bag then
		bag = {}
		gv_Squads[squad_id].squad_bag = bag
	end
	
	for i=#items,1, -1 do
		local item =  items[i]
		if item:IsKindOf("SquadBagItem") then
			local count = item.Amount
			for _, curitm in ipairs(bag) do
				if curitm and curitm.class==item and IsKindOf(curitm,"InventoryStack") and curitm.Amount < curitm.MaxStacks then
					local to_add = Min(curitm.MaxStacks - curitm.Amount, count)
					curitm.Amount = curitm.Amount + to_add
					count = count - to_add			
					if to_add > 0 then
						Msg("SquadBagAddItem", curitm, to_add)
					end
					if count<=0 then
						DoneObject(item)
						item =  false
						break
					end	
				end
			end	
			if count > 0 then
				table.insert(bag, item)		
				Msg("SquadBagAddItem", item, count)
			end
			table.remove(items, i)
		end	
	end
	
	SortItemsInBag(squad_id)
	
	if gv_SquadBag and gv_SquadBag.squad_id == squad_id then
		InventoryUIResetSquadBag()
		gv_SquadBag:SetSquadId(squad_id)
		InventoryUIRespawn()
	end	
end

function AddItemToSquadBag(squad_id, item_id, count, callback,...)	
	local bag = GetSquadBag(squad_id)
	if not bag then
		bag = {}
		gv_Squads[squad_id].squad_bag = bag
	end
	
	local args = {...}
	local count = count
	for _, curitm in ipairs(bag) do
		if curitm and curitm.class==item_id and IsKindOf(curitm,"InventoryStack") and curitm.Amount < curitm.MaxStacks then
			local to_add = Min(curitm.MaxStacks - curitm.Amount, count)
			curitm.Amount = curitm.Amount + to_add
			count = count - to_add			
			if to_add > 0 then
				Msg("SquadBagAddItem", curitm, to_add)
				if callback then callback(squad_id, curitm, to_add,...) end
			end
			if count<=0 then
				break
			end	
		end
	end	
	while count > 0 do
		local item = PlaceInventoryItem(item_id)
		if not item:IsKindOf("SquadBagItem") then
			DoneObject(item)
			break
		end

		local to_add = 1
		if IsKindOf(item,"InventoryStack") then
			to_add = Min(item.MaxStacks, count)
			item.Amount = to_add
		end
		table.insert(bag, item)
		
		if to_add > 0 then
			Msg("SquadBagAddItem", item, to_add)
			if callback then callback(squad_id, item, to_add,...) end
		end
		count = count - to_add
	end
	
	if gv_SquadBag and gv_SquadBag.squad_id == squad_id then
		InventoryUIResetSquadBag()
		gv_SquadBag:SetSquadId(squad_id)
		InventoryUIRespawn()
	end
	
	return count
end

function OnMsg.PreSquadDespawned(squad_id, sector_id, reason)
	local bag = GetSquadBag(squad_id)
	if not bag or reason~="despawn" then return end
	-- move to sector stash
	AddToSectorInventory(sector_id, bag)	
	if gv_SectorInventory and gv_SectorInventory.sector_id == sector_id then
		InventoryUIResetSectorStash(sector_id)
	end	
	InventoryUIResetSquadBag()
	InventoryUIRespawn()
end

function OnChangeUnitSquad(unit, prevSquad, newSquad)
	-- move to the same squad
	if not prevSquad or prevSquad==newSquad then 
		return 
	end
	local prevSquadData = gv_Squads[prevSquad]
	if not prevSquadData then -- Remnant from previous game?
		return
	end
	
	local prev_bag = prevSquadData.squad_bag
	-- empty squad bag
	if not prev_bag then
		return 
	end
	
	local all_units = prevSquadData.units
	local count_units = #all_units
	
	-- one unit move to other squad
	if count_units==1 then
		local new_bag = gv_Squads[newSquad].squad_bag or {}
		for _, item in ipairs(prev_bag) do
			new_bag[#new_bag+1] =  item
		end
		gv_Squads[newSquad].squad_bag = new_bag
		gv_Squads[prevSquad].squad_bag = {}
		SortItemsInBag(newSquad)
		InventoryUIResetSquadBag()
		InventoryUIRespawn()
		return
	end
	
	-- devide between units
	
	-- count in bag
	local count_parts, count_meds, count_ammo = 0,0, {}
	for _, item in ipairs(prev_bag) do
		local item_id = item.class
		if item_id=="Parts" then
			count_parts = count_parts + item.Amount
		end
		if item_id=="Meds" then
			count_meds = count_meds + item.Amount
		end
		if IsKindOf(item, "Ammo") then
			count_ammo[item_id] = count_ammo[item_id] or {count = 0, units = {}, caliber = item.Caliber}
			count_ammo[item_id].count = count_ammo[item_id].count + item.Amount
		end
	end	

	-- skills and ammo need
	local mechanics, med_kit = 0,0
	for _, unit_id in ipairs(all_units) do
		local unit = gv_UnitData[unit_id]
		if unit.Specialization=="Mechanic" then
			mechanics = mechanics + 1
		end
		if unit:GetItem("Medkit") or unit:GetItem("FirstAidKit")then
			med_kit = med_kit + 1
		end
		unit:ForEachItem("FirearmBase", function(item, slot, l,t, count_ammo)
			local caliber = item.Caliber
			for ammo_type, data in pairs(count_ammo) do
				if data.Caliber==Caliber then
					table.insert_unique(count_ammo[ammo_type].units,unit.session_id)
				end
			end			
		end, count_ammo)
	end	

	local parts = count_parts/count_units
	local meds = count_meds/count_units
	if mechanics>0  then
		parts = unit.Specialization== "Mechanic" and count_parts/mechanics or 0
	end
	if med_kit>0  then
		meds = (unit:GetItem("Medkit") or unit:GetItem("FirstAidKit")) and meds/med_kit or 0
	end
	
	local ammo_parts = {}
	for ammo_type, data in pairs(count_ammo) do
		if not data.units or #data.units==0 then
			ammo_parts[ammo_type] = data.count/count_units
		elseif table.find(data.units, unit.session_id) then	
			ammo_parts[ammo_type] = data.count/#data.units
		end
	end
	
	-- add to new_bag meds , parts, ammo
	local new_bag = gv_Squads[newSquad].squad_bag or {}
	for i=#prev_bag, 1, -1 do
		local item = prev_bag[i]
		local item_id = item.class
		local class
		local is_ammo = IsKindOf(item, "Ammo")
		local is_part = item_id=="Parts"
		local is_med = item_id=="Meds"
		local amount = 0
		class = item_id
		if is_ammo and ammo_parts[item_id] then
			amount = ammo_parts[item_id]
		elseif is_part then
			amount = parts
		elseif is_med then
			amount = meds
		end
		if class then			
			local to_move = Min(rawget(item, "Amount") or 0, amount)
			if to_move>0 then
				if to_move==item.Amount then
					table.remove(prev_bag, i)
					table.insert(new_bag, item)				
				else
					local new_item = PlaceInventoryItem(class)
					item.Amount = item.Amount-to_move
					new_item.Amount = to_move
					table.insert(new_bag, new_item)
				end
				if is_part then
					parts = parts - to_move
				elseif is_med then
					meds = meds - to_move
				elseif is_ammo then	
					ammo_parts[class] =  ammo_parts[class] - to_move
				end
			end
		end
	end
	
	gv_Squads[newSquad].squad_bag = new_bag
	SortItemsInBag(newSquad)
	InventoryUIResetSquadBag()
	InventoryUIRespawn()
end