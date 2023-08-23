DefineClass.TrapSpawnProperties = {
	__parents = { "TrapProperties" },
	properties = {
		{ category = "Visuals", id = "trapType", name = "Trap Type", editor = "combo", items = ClassDescendantsCombo("Trap"), default = "Landmine",
			help = "The class of trap to spawn." },
	},
}

function TrapSpawnProperties:GetPropertyList()
	local properties = TrapSpawnProperties:GetProperties()
	local values = {}
	for i = 1, #properties do
		local prop = properties[i]
		if not prop_eval(prop.dont_save, self, prop) then
			local prop_id = prop.id
			local value = self:GetProperty(prop_id)
			-- Unlike TrapProperties this copies the default properties as well,
			-- since it is used by the ModifyTrapSpawnersEffect
			values[prop_id] = value
		end
	end
	return values
end

-- Spawns a trap object.
DefineClass.TrapSpawnMarker = {
	__parents = { "ConditionalSpawnMarker", "TrapSpawnProperties" },
	properties = {
		{ category = "Visuals", id = "colors", name = "Colors", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false,  },
		{ category = "Visuals",
			id = "TriggerType",
			name = "TriggerType",
			editor = "choice",
			items = LandmineTriggerType,
			default = "Proximity",
			no_edit = function(o) return o.trapType ~= "Landmine" end
		},
	},
	disabled = false
}

function TrapSpawnMarker:GameInit()
	local root_collection = self:GetRootCollection()
	local collection_idx = root_collection and root_collection.Index or 0
	if collection_idx ~= 0 then
		local obj = MapGetFirst(self:GetPos(), guim * 10, "collection", collection_idx, true, "Landmine")
		if obj then
			StoreErrorSource(self, "Landmine grouped with a TrapSpawnMarker, this will cause two landmines on top of each other.")
			DoneObject(obj)
		end
	end
end

function TrapSpawnMarker:SetActive(active)
	self.disabled = not active
	if self.objects and self.disabled then
		self:DespawnObjects()
	end
	self:Update()
end

function TrapSpawnMarker:DespawnObjects()
	if not self.objects then return end
	self.objects:delete()
	self.objects = false
end

function TrapSpawnMarker:SpawnObjects()
	if self.disabled then return end
	if self.Trigger == "once" and self.last_spawned_objects then return end
	if not self.trapType then return end

	local values = TrapProperties.GetPropertyList(self)
	values.TriggerType = self.TriggerType
	local obj = PlaceObject(self.trapType, values)
	obj:SetPos(self:GetPos())
	obj:SetOrientation(self:GetOrientation())
	if self.colors then
		obj:SetColorization(self.colors)
	end
	obj:MakeSync()

	self.objects = obj
	self.last_spawned_objects = true
end

function TrapSpawnMarker:GetDynamicData(data)
	if self.objects then
		local obj_data = {}
		procall(self.objects.GetDynamicData, self.objects, obj_data)
		if next(obj_data) ~= nil then
			data.obj = obj_data
		end
	end
	if self.disabled then
		data.disabled = self.disabled
	end
end

function TrapSpawnMarker:SetDynamicData(data)
	self.disabled = data.disabled or false
	if data.last_spawned_objects then
		-- Parent will set this true when reading from the data (SetDynamicData is called with a RecursiveCall), preventing a spawn.
		self.last_spawned_objects = false
		self:SpawnObjects()
		if data.obj then
			procall(self.objects.SetDynamicData, self.objects, data.obj)
		end
	end
end

function TrapSpawnMarker:ApplyPropertyList(list)
	-- This property shouldn't be copied as it will restore mines.
	list.done = nil

	TrapProperties.ApplyPropertyList(self, list)
	-- If the trap is already spawned, apply the property change to it as well.
	if self.objects then
		TrapProperties.ApplyPropertyList(self.objects, list)
	end
end