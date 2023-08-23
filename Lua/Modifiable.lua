DefineClass.ZuluModifiable = {
	-- this class handles the case of Modifiable objects that need to save/load their applied modifiers in Zulu via ObjPropertyListToLuaCode
	__parents = { "Modifiable" },
	properties = {
		{ id = "applied_modifiers", editor = "prop_table", default = false, read_only = true, no_edit = true, base_class = "", },
	},
}

function ZuluModifiable:AddModifier(id, prop, ...)
	self.applied_modifiers = self.applied_modifiers or {}
	self:RemoveModifier(id, prop) -- one source can only modify the same property once in Zulu
	local mod_params = {...} 
	mod_params[1] = mod_params[1] or false
	table.insert(self.applied_modifiers, { id = id, prop = prop, params = mod_params })
	return Modifiable.AddModifier(self, id, prop, table.unpack(mod_params))
end

function ZuluModifiable:RemoveModifier(id, prop)
	for i = #(self.applied_modifiers or empty_table), 1, -1 do
		local data = self.applied_modifiers[i]
		if data.id == id and data.prop == prop then
			table.remove(self.applied_modifiers, i)
		end
	end
	return Modifiable.RemoveModifier(self, id, prop)
end

function ZuluModifiable:RemoveModifiers(id)
	for i = #(self.applied_modifiers or empty_table), 1, -1 do
		local data = self.applied_modifiers[i]
		if data.id == id then
			Modifiable.RemoveModifier(self, data.id, data.prop)
			table.remove(self.applied_modifiers, i)
		end
	end
end

function ZuluModifiable:ResetModifiers()
	for _, data in ipairs(self.applied_modifiers or empty_table) do
		Modifiable.RemoveModifier(self, data.id, data.prop)
	end
	
	for prop, list in pairs(self.modifications or empty_table) do
		for _, mod in ipairs(list) do
			Modifiable.RemoveModifier(self, mod.id, prop)
		end
	end
	self.applied_modifiers = nil	
end

function ZuluModifiable:ApplyModifiersList(list, add)
	if not add then
		self:ResetModifiers()
	end
	for _, data in ipairs(list) do
		if self:GetPropertyMetadata(data.prop) then
			-- table.unpack will fail if data.params[1] is nil, so make sure there's a value in it
			data.params[1] = data.params[1] or false
			self:AddModifier(data.id, data.prop, table.unpack(data.params))
		end
	end
end

function ZuluModifiable:SavePropsToLuaCode(indent, GetPropFunc, pstr, ...)
	-- remove the currently applied modifiers to save the base values of the modified properties
	local old_value = {}
	for _, data in ipairs(self.applied_modifiers) do
		local prop_meta = self:GetPropertyMetadata(data.prop)
		if prop_meta then
			local base_value = self["base_" .. data.prop]
			if base_value then
				if not old_value[data.prop] then
					old_value[data.prop] = self[data.prop]
					self[data.prop] = base_value
				end
			else
				Modifiable.RemoveModifier(self, data.id, data.prop)
			end
		else
			Modifiable.RemoveModifier(self, data.id, data.prop)
		end
	end
	
	-- dump props to lua code
	local result = ObjPropertyListToLuaCode(self, indent, GetPropFunc, pstr, ...)

	-- reapply the modifiers to restore the values of the modified properties
	for _, data in ipairs(self.applied_modifiers) do
		local prop_meta = self:GetPropertyMetadata(data.prop)
		if prop_meta then
			if old_value[data.prop] then
				self[data.prop] = old_value[data.prop]
			else
				-- table.unpack will fail if data.params[1] is nil, so make sure there's a value in it
				data.params[1] = data.params[1] or false
				Modifiable.AddModifier(self, data.id, data.prop, table.unpack(data.params))
			end
		end
	end
	
	return result
end

function ZuluModifiable:GetStatBoostItemMods(stat) -- From equipable items
	if not (self.modifications and self.modifications[stat]) then return end
	local mods = {}
	for _, mod in ipairs(self.modifications[stat] or empty_table) do
		if string.match(mod.id, "StatBoostItem-.*") then
			mods[#mods+1] = mod
		end
	end
	return mods
end

function ZuluModifiable:GetNonStatBoostItemMods(stat)
	if not (self.modifications and self.modifications[stat]) then return end
	local mods = {}
	for _, mod in ipairs(self.modifications[stat] or empty_table) do
		if not string.match(mod.id, "StatBoostItem-.*") then
			mods[#mods+1] = mod
		end
	end
	return mods
end

function ZuluModifiable:GetTotalModsByType(stat)
	if not (self.modifications and self.modifications[stat]) then return end
	local mods = {}
	for _, mod in ipairs(self.modifications[stat] or empty_table) do
		if string.starts_with(mod.id, "StatBoostBook") then
			mods.studying = (mods.studying or 0) + mod.add
		elseif string.starts_with(mod.id, "StatTraining") then
			mods.training = (mods.training or 0) + mod.add
		elseif string.starts_with(mod.id, "StatGain") then
			mods.statGain = (mods.statGain or 0) + mod.add
		elseif string.starts_with(mod.id, "StatBoostItem") then
			mods.item = (mods.item or 0) + mod.add
		end
	end
	return mods
end