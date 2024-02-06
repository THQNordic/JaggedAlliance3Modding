local function GetPrefabItems(self)
	local items = {}
	local PrefabMarkers = PrefabMarkers
	for _, prefab in ipairs(self:FilterPrefabs()) do
		items[#items + 1] = PrefabMarkers[prefab]
	end
	table.sort(items)
	table.insert(items, 1, "")
	return items
end

DefineClass.PlacePrefabLogic = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Prefab", id = "FixedPrefab",     name = "Fixed Prefabs",          editor = "string_list", default = false, items = GetPrefabItems, no_validate = true, buttons = {{name = "Test", func = "TestPlacePrefab"}}},
		{ category = "Prefab", id = "PrefabPOIType",   name = "Prefab POI Type",        editor = "preset_id",   default = "", preset_class = "PrefabPOI" },
		{ category = "Prefab", id = "PrefabType",      name = "Prefab Type",            editor = "preset_id",   default = "", preset_class = "PrefabType" },
		{ category = "Prefab", id = "PrefabTagsAny",   name = "Prefab Tags Any",        editor = "set",         default = empty_table, items = function() return PrefabTagsCombo() end, three_state = true },
		{ category = "Prefab", id = "PrefabTagsAll",   name = "Prefab Tags All",        editor = "set",         default = empty_table, items = function() return PrefabTagsCombo() end, three_state = true },
		{ category = "Prefab", id = "MaxPrefabRadius", name = "Max Allowed Radius",     editor = "number",      default = 0, scale = "m" },
		{ category = "Prefab", id = "FixAtCenter",     name = "Fix At Center",          editor = "bool",        default = true, help = "Allow the prefab to be spawned anywhere inside the max radius" },
		{ category = "Prefab", id = "RandAngle",       name = "Rand Angle",             editor = "number",      default = 0, scale = "deg" },
		{ category = "Prefab", id = "PlacedName",      name = "Placed Name",            editor = "text",        default = "", read_only = true, dont_save = true,  buttons = {{name = "Goto", func = "GotoPrefabAction"}} },
		{ category = "Prefab", id = "PlaceError",      name = "Place Error",            editor = "text",        default = "", read_only = true, dont_save = true },
		{ category = "Prefab", id = "PrefabCount",     name = "Prefab Count",           editor = "number",      default = 0, read_only = true, dont_save = true },
	},
	reserved_locations = false,
}

function PlacePrefabLogic:SetFixedPrefab(prefab)
	if type(prefab) == "string" then
		prefab = { prefab }
	end
	self.FixedPrefab = prefab
end

function PlacePrefabLogic:FilterPrefabs(params, all_prefabs)
	all_prefabs = all_prefabs or PrefabMarkers
	local prefabs = {}
	local poi_type = params and params.poi_type or self.PrefabPOIType or ""
	local ptype = params and params.prefab_type or self.PrefabType or ""
	local max_radius = params and params.max_radius or self.MaxPrefabRadius or 0
	local tags_any = params and params.tags_any or self.PrefabTagsAny
	local tags_all = params and params.tags_all or self.PrefabTagsAll
	local type_tile = const.TypeTileSize
	for _, prefab in ipairs(all_prefabs) do
		if (poi_type == "" or prefab.poi_type == poi_type)
		and (ptype == "" or prefab.type == "" or prefab.type == ptype)
		and (max_radius == 0 or prefab.max_radius * type_tile <= max_radius)
		and MatchThreeStateSet(prefab.tags, tags_any, tags_all)
		then
			prefabs[#prefabs + 1] = prefab
		end
	end
	return prefabs
end

function PlacePrefabLogic:GetPrefabs(params)
	local fixed_prefabs = params and params.name or self.FixedPrefab
	if fixed_prefabs then
		local prefabs = {}
		if type(fixed_prefabs) == "string" then
			fixed_prefabs = { fixed_prefabs } 
		end
		for _, name in ipairs(fixed_prefabs) do
			local prefab = PrefabMarkers[name]
			if not prefab then
				StoreErrorSource(self, "No such prefab:", name)
			else
				prefabs[#prefabs + 1] = prefab
			end
		end
		if params and params.filter_fixed then
			local tags_any = params and params.tags_any or self.PrefabTagsAny
			local tags_all = params and params.tags_all or self.PrefabTagsAll
			for i = #prefabs,1,-1 do
				if not MatchThreeStateSet(prefabs[i].tags, tags_any, tags_all) then
					table.remove_rotate(prefabs, i)
				end
			end
		end
		if #prefabs > 0 then
			return prefabs
		end
	end
	return self:FilterPrefabs(params)
end

function PlacePrefabLogic:GetError()
	if mapdata.IsPrefabMap and self:GetPrefabCount() == 0 then
		return "No matching prefabs found!"
	end
end

function PlacePrefabLogic:GetPrefabCount(params)
	return #self:GetPrefabs(params)
end

function PlacePrefabLogic:ReserveLocation(pos, radius)
	self.reserved_locations = table.create_add(self.reserved_locations, {pos, radius})
end

function PlacePrefabLogic:GetReservedRatio()
	local max_radius = self.MaxPrefabRadius
	if max_radius <= 0 then
		return 100
	end
	local radius_sum2 = 0
	for _, info in ipairs(self.reserved_locations) do
		local radius = info[2]
		radius_sum2 = radius * radius
	end
	return 100 * sqrt(radius_sum2) / max_radius
end

function PlacePrefabLogic:CheckReservedLocations(pos, radius)
	--DbgClear(true) DbgAddCircle(self, self.MaxPrefabRadius, yellow) DbgAddCircle(pos, radius, blue)
	for _, info in ipairs(self.reserved_locations) do
		if IsCloser2D(pos, info[1], radius + info[2]) then
			--DbgAddCircle(info[1], info[2], red)
			return
		end
	end
	--DbgAddVector(pos)
	return true
end

function PlacePrefabLogic:GetPrefabLoc(seed, params)
	seed = seed or InteractionRand(nil, "PlacePrefab")
	local name, pos, angle, prefab, idx
	local prefabs = self:GetPrefabs(params)
	local retry
	while true do
		local idx
		if #prefabs > 1 then
			prefab, idx, seed = table.weighted_rand(prefabs, "weight", seed)
		else
			prefab = prefabs[1]
		end
		assert(prefab)
		if not prefab then
			return
		end
		pos = params and params.pos
		if not pos then
			pos = self:GetVisualPos()
			if not self.FixAtCenter then
				local reserved_radius
				if params and params.avoid_reserved_locations and self.reserved_locations then
					reserved_radius = (prefab.min_radius + prefab.max_radius) * const.TypeTileSize / 2
				end
				local radius = prefab.max_radius * const.TypeTileSize
				local free_dist = self.MaxPrefabRadius - radius
				if free_dist > 0 then
					local center = pos
					pos = false
					local retries = params and params.avoid_reserved_retries or 16
					for i=1,retries do
						local ra, rr
						ra, seed = BraidRandom(seed, 360*60)
						rr, seed = BraidRandom(seed, free_dist)
						local pos_i = RotateRadius(rr, ra, center)
						if not reserved_radius or self:CheckReservedLocations(pos_i, reserved_radius) then
							pos = pos_i
							break
						end
					end
				elseif reserved_radius and not self:CheckReservedLocations(pos, reserved_radius) then
					pos = false
				end
			end
		end
		if pos then
			name = PrefabMarkers[prefab]
			angle = params and params.angle
			if not angle then
				angle = self:GetAngle()
				local rand_angle = self.RandAngle
				if rand_angle > 0 then
					local desired_angle = params and params.desired_angle
					if desired_angle then
						local angle_diff = AngleDiff(desired_angle, angle)
						if abs(angle_diff) <= rand_angle then
							angle = desired_angle
						else
							local min_angle, max_angle = angle - rand_angle, angle + rand_angle
							if abs(AngleDiff(desired_angle, min_angle)) < abs(AngleDiff(desired_angle, max_angle)) then
								angle = min_angle
							else
								angle = max_angle
							end
						end
					else
						local da
						da, seed = BraidRandom(seed, -rand_angle, rand_angle)
						angle = angle + da
					end
				end
			end
			return name, pos, angle, prefab, seed
		end
		if #prefabs == 1 then
			return
		end
		table.remove_rotate(prefabs, idx)
	end
end

function PlacePrefabLogic:PlacePrefab(seed, params)
	local success, err, objs, inv_bbox
	local name, pos, angle, prefab, seed = self:GetPrefabLoc(seed, params)
	if not name then
		err = "No matching prefabs found!"
	else
		success, err, objs, inv_bbox = procall(PlacePrefab, name, pos, angle, seed, params)
	end
	self.PlaceError = err
	self.PlacedName = name
	ObjModified(self)
	return err, objs, pos, prefab, name, inv_bbox
end

function PlacePrefabLogic:EditorCallbackGenerate(generator, object_source, placed_objects, prefab_list)
	local mark = placed_objects[self]
	local info = mark and prefab_list[mark]
	local ptype = info and info[4]
	if ptype then
		self.PrefabType = ptype
	end
end

----

DefineClass.PlacePrefabMarker = {
	__parents = { "RadiusMarker", "PlacePrefabLogic", "PrefabSourceInfo" },
	editor_text_color = RGB(50, 50, 100),
	editor_color = RGB(150, 150, 0),
}

function PlacePrefabMarker:GetMeshRadius()
	local max_radius = self.MaxPrefabRadius
	for _, prefab in ipairs(self:GetPrefabs()) do
		max_radius = Max(max_radius, prefab.max_radius)
	end
	return max_radius
end

function PlacePrefabMarker:OnEditorSetProperty(prop_id, old_value, ged)
	local meta = self:GetPropertyMetadata(prop_id)
	if meta and meta.category == "Prefab" then
		self:UpdateMeshRadius()
	end
end

function PlacePrefabMarker:TestPlacePrefab()
	local err, objs = self:PlacePrefab(AsyncRand(), {
		create_undo = true,
	})
	if err then
		print(err)
	end
end
