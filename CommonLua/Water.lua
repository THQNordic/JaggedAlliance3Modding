DefineClass.TerrainWaterObject = {
	__parents = { "Object", "EditorVisibleObject", "WaterObjProperties" },
	flags = { efMarker = true, cfEditorCallback = true },
	properties = {
		{ category = "Water", id = "wtype",            name = "Water Type",       editor = "number", default = 0 },
		{ category = "Water", id = "area",             name = "Saved Area",       editor = "number", default = -1, read_only = true },
		{ category = "Water", id = "applied_area",     name = "Current Area",     editor = "number", default = -1, read_only = true },
		{ category = "Water", id = "spill_tolerance",  name = "Spill Tolerance",  editor = "number", default = 5, scale = "%", help = "Defines the allowed error in % in the applied water area before adjusting the level." },
		{ category = "Water", id = "spill_avoid_step", name = "Spill Avoid Step", editor = "number", default = guim/2, scale = "m", min = 0, help = "When spilled, try to lower the water level by that much every time before trying to fill again." },
		{ category = "Water", id = "planes",           name = "Planes",           editor = "number", default = 0, read_only = true, dont_save = true },
		{ category = "Water", id = "hborder",          name = "Height Border",    editor = "number", default = guim, scale = "m", help = "Height border to adjusting the water level in the post generation step." },
		{ category = "Water", id = "zoffset",          name = "Level Offset",     editor = "number", default = 0, scale = "m", read_only = true },
	},
	radius = 0,

	invalidation_box = false,
	object_list = false,
}

function TerrainWaterObject:Getplanes()
	return self.object_list and #self.object_list or 0
end

function TerrainWaterObject:GetMaxColorizationMaterials()
	return 3
end

function TerrainWaterObject:GetPlaneInfo()
	if self:IsKindOf("WaterFillBig") then
		return _G["WaterPlaneBig"], 40000
	end
	return _G["WaterPlane"], 10000
end

function TerrainWaterObject:Done()
	if self.object_list then
		for _, o in ipairs(self.object_list) do
			DoneObject(o)
		end
	end
end

function TerrainWaterObject:RecreateWaterObjs()
	local object_list = self.object_list or {}
	local count = 0
	local prev_count = #object_list
	self.object_list = object_list

	local plane_class, step = self:GetPlaneInfo()
	local invalidation_box = self.invalidation_box
	if not invalidation_box then
		return
	end
	invalidation_box = box(invalidation_box:min() - point(step / 2, step / 2), invalidation_box:max() + point(step / 2, step / 2))
	local sizex, sizey = terrain.GetMapSize()
	invalidation_box = IntersectRects(box(0, 0, sizex, sizey), invalidation_box)

	local planes = MulDivTrunc(invalidation_box:sizex(), invalidation_box:sizey(), step * step)
	if planes > 30000 then
		return false
	end
	local x, y, z = self:GetPosXYZ()
	z = (z or terrain.GetHeight(x, y)) + self.zoffset
	local dir_offset = { -step, 0, step, 0, 0, -step, 0, step }
	
	local half_step_sqr = (step / 2) * (step / 2)
	local step_radius = sqrt(half_step_sqr * 2)
	local start = point(x, y)
	local function pt_hash(x, y)
		return (x << 31) + y
	end
	local queue = {start}
	local tested = {[pt_hash(start:xy())] = true,}
	while #queue > 0 do
		local current = queue[1]
		table.remove(queue, 1)

		if invalidation_box:Point2DInside(current) and terrain.IsWaterNearby(current, step_radius) then
			count = count + 1
			local plane = object_list[count]
			if not plane then
				plane = plane_class:new({})
				object_list[count] = plane
			end
			local xi, yi = current:xy()
			plane:SetPos(xi, yi, z)
			for k=1,#dir_offset,2 do
				local dx, dy = dir_offset[k], dir_offset[k + 1]
				local xk, yk = xi + dx, yi + dy
				local hash = pt_hash(xk, yk)
				if not tested[hash] then
					tested[hash] = true
					table.insert(queue, point(xk, yk))
				end
			end
		end
	end
	
	for i=prev_count, count + 1, - 1 do
		DoneObject(object_list[i])
		object_list[i] = nil
	end

	self:WaterPropChanged()
	-- we can't invoke a EditorCallback for placing here, as it triggers a new wate update and causes an infinite loop
	if IsEditorActive() then
		XEditorFilters:UpdateObjectList(object_list)
	end
end

function TerrainWaterObject:UpdateGridAndVisuals(avoid_spill)
	local zoffset = self.zoffset
	local max_area
	local zstep = 0
	if avoid_spill then
		zstep = self.spill_avoid_step
		max_area = self.area
		if max_area > 0 then
			max_area = MulDivRound(max_area, 100 + self.spill_tolerance, 100)
		end
	end
	local new_inv_box, applied_area, spilled
	local adjusted
	while true do
		new_inv_box, applied_area, spilled = terrain.UpdateWaterGridFromObject(self, self.wtype, zoffset, max_area)
		if not spilled or zstep <= 0 then
			break
		end
		zoffset = zoffset - zstep
		adjusted = true
	end
	if adjusted then
		StoreErrorSource(self, "Water object spill")
		self.zoffset = zoffset
	end
	if not new_inv_box then
		StoreErrorSource(self, "Water object without water")
	end
	local prev_invalid_box = self.invalidation_box
	local invalid_box = false
	if prev_invalid_box and new_inv_box then
		invalid_box = Extend(new_inv_box, prev_invalid_box)
	elseif new_inv_box then
		invalid_box = new_inv_box
	elseif prev_invalid_box then
		invalid_box = prev_invalid_box
	end
	self.invalidation_box = new_inv_box
	self.applied_area = applied_area
	if invalid_box then
		self:RecreateWaterObjs()
	end
end

local WaterPassTypes = {
	{ text = "Impassable" , value = 0 }, -- impassable below certain level from water plane
	{ text = "Passable" , value = 1 },   -- do not affect passability
	{ text = "Water Pass" , value = 2 }, -- special pass type
}

-- A base class for the objects that modify the water grid, and need to be reapplied to it when rebuilding the water grid
-- Also, ApplyAllWaterObjects call RebuildGrids for such objects when a certain hash changes (see below), in order to rebuild passability
DefineClass.TerrainWaterMod = {
	__parents = { "Object" },
	flags = { cfEditorCallback = true },
	properties = {
		{ id = "Passability", editor = "dropdownlist", default = 1, items = WaterPassTypes },
	},
}
function ApplyAllWaterObjects(height_change_bbox, avoid_spill)
	SuspendPassEdits("ApplyAllWaterObjects")
	if not height_change_bbox then
		local st = GetPreciseTicks()
		terrain.ClearWater()
		MapForEach("map", "TerrainWaterObject", TerrainWaterObject.UpdateGridAndVisuals, avoid_spill)
	else
		-- Collect all water objects, whose boxes intersect with the changed terrain height box
		-- AND, recursively, water objects whose boxes intersect with those.
		local union_box = height_change_bbox
		local water_objs = MapGet("map", "TerrainWaterObject")
		local added_objs = {}
		local dirty = true
		while dirty do
			dirty = false
			for _, water_obj in ipairs(water_objs) do
				local inv_box = water_obj.invalidation_box
				if inv_box and not added_objs[water_obj] and union_box:Intersect2D(inv_box) ~= const.irOutside then
					union_box = AddRects(inv_box, union_box)
					added_objs[water_obj] = true
					dirty = true
				end
			end
		end
		
		-- Then, clear the water grid in the resulting union box, and rebuild all water object within it.
		terrain.ClearWater(union_box)
		MapForEach(union_box, "TerrainWaterObject", TerrainWaterObject.UpdateGridAndVisuals, avoid_spill)
	end
	
	if const.pfWater then
		-- Remember old TerrainWaterMod hashes and boxes
		local old_hashes = table.copy(TerrainWaterModHashes)
		local old_boxes = table.copy(TerrainWaterModOldBoxes)
		-- Apply all TerrainWaterMod objects to the water grid, calculate new hashes
		MapForEach("map", "TerrainWaterMod", nil, nil, const.gofPermanent, function(water_mod)
			terrain.MarkWaterArea(water_mod, water_mod.Passability)
			water_mod:UpdatePassabilityHash()
		end)
		-- Rebuild passability for all objects for which the PassabilityHash changed (including newly appeared and deleted objects)
		for obj, hash in pairs(TerrainWaterModHashes) do
			local old_hash = old_hashes[obj]
			if old_hash ~= hash then
				RebuildGrids(obj:GetObjectBBox())
				if old_hash then
					RebuildGrids(old_boxes[obj])
				end
			end
			old_hashes[obj] = nil
		end
		for obj, hash in pairs(old_hashes) do
			RebuildGrids(old_boxes[obj])
		end
	end
	
	ResumePassEdits("ApplyAllWaterObjects")
end

function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackMove" or id == "EditorCallbackPlace" or id == "EditorCallbackClone" or id == "EditorCallbackDelete" then
		for i, obj in ipairs(objects) do
			if obj:IsKindOfClasses("TerrainWaterObject", "TerrainWaterMod") then
				DelayedCall(0, ApplyAllWaterObjects)
				break
			end
		end
	end
end

function SaveTerrainWaterObjArea(hm)
	local markers = MapGet("map", "TerrainWaterObject")
	if #(markers or "") == 0 then
		return
	end
	hm = hm or terrain.GetHeightGrid()
	local ww, wh = terrain.WaterMapSize()
	local wm = NewComputeGrid(ww, wh, "u", 16)
	for _, m in ipairs(markers) do
		m.area = GridWaterArea(hm, wm, m)
	end
end


function OnMsg.NewMapLoaded()
	ApplyAllWaterObjects()
end

function OnMsg.LoadGameObjectsUnpersisted()
	ApplyAllWaterObjects()
end

DefineClass.WaterObjProperties = {
	__parents = {"PropertyObject",  "ColorizableObject" },

	properties = {
		{ id = "waterpreset", category = "Water", editor = "preset_id", preset_class = "WaterObjPreset",	autoattach_prop = true, }
	},
	waterpreset = false,
}

function WaterObjProperties:GetMaxColorizationMaterials()
	return 3
end

local water_obj_prop_ids
function WaterObjProperties:Setwaterpreset(value)
	if self.waterpreset == value then
		return
	end
	self.waterpreset = value
	local props_values = WaterObjPresets[value]
	if not props_values then return end
	for _, id in ipairs(water_obj_prop_ids) do
		self:SetProperty(id, props_values:GetProperty(id))
	end
	if props_values:AreColorsModified() then
		self:SetColorization(props_values)
	end
	self:WaterPropChanged()
end

function WaterObjProperties:WaterPropChanged()
end

function WaterObjProperties:ColorizationReadOnlyReason()
	return self.waterpreset and self.waterpreset ~= "" and "Object is WaterObj and waterpreset is set to a valid value." or false
end

function WaterObjProperties:ColorizationPropsDontSave(i)
	return self.waterpreset and self.waterpreset ~= ""
end


--------- WaterObj to inherit from for the planes ----------------
DefineClass.WaterObj = {
	__parents = { "CObject", "ComponentCustomData", "TerrainWaterMod", "WaterObjProperties" },

	flags = {
		cfWaterObj = true, efSelectable = false,
	},
	properties = {
		{ id = "ColorModifier", editor = "rgbrm", default = RGB(100, 100, 100),
			read_only = function(obj) return (obj.waterpreset or "") ~= "" end,
			dont_save = function(obj) return (obj.waterpreset or "") ~= "" end,
		},
	},
}


-- Do not reorder; Just rename
local property_names = {
	"Flow Time Speed",
	"Flow Directional Speed",
	"Flow Direction",
	"Flow Magnitude",
	"Wave Texture Scale",
	"Wave Normal Strenght",
	"Specular Contribution",
	"Env Refl Contribution",
	"Color Depth Gradient",
	"Opacity Depth Gradient",
	"Refraction Strength",
	"Edge Noise Scale",
	"HighResolution1",
	"HighResolution2"
}
assert(#property_names == 4 * 3 + 2)
water_obj_prop_ids = {
	"ColorModifier"
}
for i = 1, 14 do
	local int_offset = (i - 1) / 4
	local ccd = 3 + int_offset
	local bit_offset = ((i - 1) % 4) * 8
	local mask = 0xFF
	if i == 13 or i == 14 then
		int_offset = 3
		ccd = 6
		bit_offset = (i - 13) * 16
		mask = 0xFFFF
	end
	local id = "WaterParam" .. i
	table.insert(WaterObjProperties.properties, {
		id = id, editor = "number",
		slider = true, min = 0, max = mask, scale = mask,
		default = 0, name = property_names[i], category = "Water",
		read_only = function(obj) return (obj.waterpreset or "") ~= "" end,
		dont_save = function(obj) return (obj.waterpreset or "") ~= "" end,
	})
	WaterObj["Get" .. id] = function(self)
		return (self:GetCustomData(ccd) >> bit_offset) & mask
	end
	WaterObj["Set" .. id] = function(self, value)
		value = value & mask
		local old = self:GetCustomData(ccd) & ~(mask << bit_offset)
		self:SetGameFlags(const.gofDirtyVisuals)
		local result = self:SetCustomData(ccd, old | (value << bit_offset))
		self:WaterPropChanged()
		return result
	end

	table.insert(water_obj_prop_ids, id)

	if not WaterObjProperties[id] then
		WaterObjProperties[id] = 0
	end
	WaterObjProperties["Get" .. id] = function(self)
		return self[id]
	end
	WaterObjProperties["Set" .. id] = function(self, value)
		self[id] = value
	end
end

function WaterObjProperties:OnEditorSetProperty(prop_id, old_value, ged)
	if table.find(water_obj_prop_ids, prop_id) then
		self:WaterPropChanged()
	end
	if string.starts_with(prop_id, "EditableColor") or string.starts_with(prop_id, "EditableRoughness") or string.starts_with(prop_id, "EditableMetallic") then
		self:WaterPropChanged()
	end
end

function TerrainWaterObject:WaterPropChanged()
	if not self.object_list then return end
	for _, plane in ipairs(self.object_list) do
		for _, id in ipairs(water_obj_prop_ids) do
			plane:SetProperty(id, self:GetProperty(id))
		end
		plane:SetColorization(self)
	end
end

DefineClass.WaterObjPreset = {
	__parents = {"Preset", "WaterObjProperties"},
	properties = {
		{id = "ColorModifier", editor = "rgbrm", default = RGB(100, 100, 100) },
		{id = "waterpreset", editor = false,},
	},
	GlobalMap = "WaterObjPresets",
	EditorMenubarName = "Water presets",
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/blood drink drop water.png",
}

function WaterObjPreset:WaterPropChanged()
	local patchWaterProps = function(obj) 
		if obj:GetGameFlags(const.gofPermanent) ~= 0 and obj.waterpreset == self.id then
			obj:Setwaterpreset(false)
			obj:Setwaterpreset(self.id)
			ObjModified(obj)
		end
	end
	MapForEach("map", "TerrainWaterObject", patchWaterProps)
	MapForEach("map", "WaterObj", patchWaterProps)

	for obj in pairs(GedObjects) do
		if IsKindOf(obj, "GedMultiSelectAdapter") then
			ObjModified(obj)
		end
	end
end

function AdjustTerrainWaterObjLevels(hm, markers)
	markers = markers or MapGet("map", "TerrainWaterObject")
	if #(markers or "") == 0 then
		return
	end
	local hscale = const.TerrainHeightScale
	terrain.ClearWater()
	hm = hm or terrain.GetHeightGrid()
	local ww, wh = terrain.WaterMapSize()
	local wm = NewComputeGrid(ww, wh, "u", 16)
	for _, m in ipairs(markers) do
		local x, y, z = m:GetPosXYZ()
		m.zoffset = nil
		if m.area > 0 then
			local z0 = GridWaterLevel(hm, wm, m, m.area, m.hborder)
			if z / hscale ~= z0 / hscale then
				m.zoffset = z0 - z
				z = z0
			end
		end
		if z > 0 then
			local spilled
			m.invalidation_box, m.applied_area, spilled = terrain.UpdateWaterGridFromObject(m, m.wtype, m.zoffset, m.area)
			assert(not spilled)
			m:RecreateWaterObjs()
		end
	end
end

function PlaceWaterMarkers(mask)
	local mw, mh = terrain.GetMapSize()
	local gw, gh = mask:size()
	local tile = mw / gw
	local preset = mapdata.SeaPreset
	local level = mapdata.SeaLevel
	if level == 0 then
		return false, "Map Sea Level should be set"
	end
	local min_dist = mapdata.SeaMinDist
	local min_grid_dist = min_dist / tile
	local min_area = min_grid_dist * min_grid_dist * 22 / 7
	local zone_map = GridRepack(mask, "u", 16, true)
	local zones = GridEnumZones(zone_map, min_area)
	local level_mask = GridDest(zone_map)
	local level_dist = GridRepack(level_mask, "f", 32, true)
	local flags = const.gofGenerated | const.gofPermanent
	local visible = IsEditorActive()
	for i=1,#zones do
		local zone = zones[i]
		assert(zone.size >= min_area)
		GridMask(zone_map, level_mask, zone.level)
		GridFrame(level_mask, 1, 0)
		GridRepack(level_mask, level_dist)
		GridDistance(level_dist, tile)
		local minv, maxv, minp, maxp = GridMinMax(level_dist, true)
		if maxv > min_dist then
			local wobj = WaterFillBig:new()
			wobj:SetGameFlags(flags)
			wobj:SetVisible(visible)
			maxp = maxp * tile
			maxp = maxp:SetZ(level)
			wobj:SetPos(maxp)
			wobj:Setwaterpreset(preset)
			--DbgAddCircle(maxp, maxv) DbgAddVector(maxp, 100*guim)
		end
	end
end

----

if const.pfWater then

if FirstLoad then
	TerrainWaterModHashes = setmetatable({}, weak_keys_meta)
	TerrainWaterModOldBoxes = setmetatable({}, weak_keys_meta)
end

-- ApplyAllWaterObjects call RebuildGrids for such objects when a certain hash changes (see below), in order to rebuild passability

function TerrainWaterMod:SetPassability(value)
	self.Passability = value
	if not IsChangingMap() then
		DelayedCall(0, ApplyAllWaterObjects)
	end
end

function TerrainWaterMod:UpdatePassabilityHash()
	TerrainWaterModHashes[self] = xxhash(self:GetPos(), self.Passability)
	TerrainWaterModOldBoxes[self] = self:GetObjectBBox()
end

function TerrainWaterMod:Done()
	TerrainWaterModHashes[self] = nil
end

end -- const.pfWater

---- 