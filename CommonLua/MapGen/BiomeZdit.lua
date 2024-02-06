if not Platform.editor or not Platform.developer then
	return
end

local type_tile = const.TypeTileSize
local pct_mul = 100

----

function Biome:CalcTypeMixingPreview()
	local preview = NewComputeGrid(256, 256, "U", 16)
	self:GetTypeMixingGrid(preview)
	self.TypeMixingPreview = preview
	return preview
end

function Biome:GetFilteredPrefabsPreview()
	return #(self:GetFilteredPrefabs() or empty_table)
end

function Biome:GetTypeMixingPreview()
	return self.TypeMixingPreview or self:CalcTypeMixingPreview()
end

local function RecalcTypeMixingPreview(ged)
	local parent = ged:GetParentOfKind("SelectedObject", "Biome")
	if parent then
		parent:CalcTypeMixingPreview()
	end
end

function BiomePrefabTypeWeight:OnAfterEditorNew(parent, ged, is_paste)
	RecalcTypeMixingPreview(ged)
end

function BiomePrefabTypeWeight:OnAfterEditorDelete(parent, ged)
	RecalcTypeMixingPreview(ged)
end

function BiomePrefabTypeWeight:OnEditorSetProperty(prop_id, old_value, ged)
	RecalcTypeMixingPreview(ged)
end

----

if FirstLoad then
	g_BiomeFiller = false
end

BiomeFiller.dbg_paused = false
BiomeFiller.dbg_interrupt = false
BiomeFiller.dbg_placed_prefabs = false
BiomeFiller.dbg_prefab_types = false
BiomeFiller.dbg_visible_prefabs = false
BiomeFiller.dbg_placed_objects = false
BiomeFiller.dbg_placed_poi = false
BiomeFiller.dbg_obj_to_prefab_mark = false
BiomeFiller.dbg_grid_thread = false
BiomeFiller.dbg_inspect = false
BiomeFiller.dbg_filter_tags = false
BiomeFiller.dbg_filter_name = ""
BiomeFiller.dbg_view_mark = 0

function BiomeFiller:DbgInit()
	g_BiomeFiller = self
	for _, prop in ipairs(self:GetProperties()) do
		if prop.category == "Results" then
			self[prop.id] = nil
		end
	end
	self.dbg_paused = nil
	self.dbg_interrupt = nil
	self.dbg_placed_prefabs = nil
	self.dbg_prefab_types = nil
	self.dbg_visible_prefabs = nil
	self.dbg_placed_objects = nil
	self.dbg_placed_poi = nil
	self.dbg_obj_to_prefab_mark = nil
	self.dbg_inspect = nil
	self.dbg_filter_tags = nil
	self.dbg_filter_name = nil
	self.dbg_view_mark = nil
	self:DbgClear()
	ObjModified(self)
end

function BiomeFiller:ActionTogglePause()
	self.dbg_paused = not self.dbg_paused
	Msg(self)
end

function BiomeFiller:ActionInterrupt()
	self.dbg_interrupt = true
	self.dbg_paused = false
	Msg(self)
end

local function DbgGetPalette(grid, name, prefab_list)
	local palette, remap = {}, {}
	local level_map = GridLevels(grid)
	local count = 0
	if name == "Types" then
		local ptype_to_preset = PrefabTypeToPreset
		local idx_to_ptype = GetPrefabTypeList()
		local ptypes = {}
		for ptype_idx in pairs(level_map) do
			local ptype = idx_to_ptype[ptype_idx]
			if ptype then
				local val = ptypes[ptype]
				if not val then
					count = count + 1
					val = count
					ptypes[ptype] = val
					local preset = ptype_to_preset[ptype]
					local color = preset and preset.OverlayColor or RandColor(xxhash(ptype))
					palette[val] = color
				end
				remap[ptype_idx] = val
			end
		end
	else
		local i = 1
		local minv, maxv = max_int, 0
		for level in pairs(level_map) do
			if level ~= 0 then
				local val = count % 255 + 1
				remap[level] = val
				minv = Min(minv, val)
				maxv = Max(maxv, val)
				count = count + 1
			end
		end
		if count > 0 then
			palette[minv] = RGB(128, 128, 128)
			palette[maxv] = white
			if count > 2 then
				count = Min(255, count)
				local max_value = 1024
				local max_hue = 0
				local min_hue = max_value * 2 / 3
				for val = minv, maxv do
					local hue = min_hue + (max_hue - min_hue) * (val - minv) / (maxv - minv)
					palette[val] = HSB(hue, max_value, max_value, max_value)
				end
			end
		end
	end
	return palette, remap
end

function BiomeFiller:DbgDone()
	self.Overlay = nil
	self.InspectMode = nil
	self.InspectFilter = nil
	self:DbgUpdateShow()
	self:DbgClear()
	GedObjectDeleted(self)
end

BiomeFiller.dbg_overlay_grid = false
function BiomeFiller:DbgClear()
	DbgHideTerrainGrid(self.dbg_overlay_grid)
	self.dbg_overlay_grid = nil
	DbgClear()
	editor.ClearSel()
end

function BiomeFiller:OnEditorSetProperty(prop_id, ...)
	local prop = self:GetPropertyMetadata(prop_id)
	if prop and prop.update_dbg then
		self:DbgUpdateShow()
	end
	return GridOp.OnEditorSetProperty(self, prop_id, ...)
end

function BiomeFiller:GetGridPreview()
	local modes = self:GetGridModes()
	for key, value in pairs(self.PreviewSet) do
		if value then
			return modes[key]
		end
	end
end
				
BiomeFiller.dbg_palettes = false
function BiomeFiller:DbgUpdate()
	self.dbg_palettes = false
	self:DbgUpdateShow()
	editor.ClearSel()
end

function BiomeFiller:DbgUpdatePalette(name)
	name = name or self:DbgGetOverlay()
	self.dbg_palettes = self.dbg_palettes or {}
	local grid = self:GetGridModes()[name]
	local info = self.dbg_palettes[name] or empty_table
	local edges = self.OverlayEdges
	local prev_grid, prev_edges = info[3], info[5] or false
	if grid and (prev_grid ~= grid or prev_edges ~= edges) then
		local palette, remap = DbgGetPalette(grid, name, self.PrefabList or empty_table)
		local edge
		if edges then
			edge = GridDest(grid)
			GridEdge(grid, edge)
			GridNot(edge)
		end
		local g = GridDest(grid)
		GridReplace(grid, g, remap)
		if edges then
			GridMulDiv(g, edge, 1)
		end
		info = { palette, remap, grid, g, edges }
		self.dbg_palettes[name] = info
	end
	return table.unpack(info)
end

function BiomeFiller:DbgGetColor(mark)
	local overlay = self:DbgGetOverlay() or "Marks"
	local palette, remap = self:DbgUpdatePalette(overlay)
	local pidx = remap[mark]
	return pidx and palette[pidx]
end

function BiomeFiller:DbgGetOverlay()
	for ov, value in pairs(self.Overlay) do
		if value then
			return ov
		end
	end
end

function BiomeFiller:DbgUpdateShow()
	local new_overlay = self:DbgGetOverlay()
	DeleteThread(self.dbg_grid_thread)
	if not new_overlay then
		DbgShowTerrainGrid(false)
	else
		self.dbg_grid_thread = CreateRealTimeThread(function()
			WaitNextFrame(1)
			local palette, remap, dgrid, g = self:DbgUpdatePalette(new_overlay)
			self.dbg_overlay_grid = g
			DbgShowTerrainGrid(g, palette)
		end)
	end

	local new_inspect = false
	for ins, value in pairs(self.InspectMode) do
		if value then
			new_inspect = ins
			break
		end
	end
	
	local filter_tags = false
	for tag, value in pairs(self.InspectFilter) do
		if value then
			filter_tags = table.create_set(filter_tags, tag, true)
		end
	end
	local filter_name = self.InspectPattern
	
	local prefab_to_tags = {}
	local function GetPrefabTags(prefab)
		local tags = prefab_to_tags[prefab]
		if tags == nil then
			local poi_tags = prefab.poi_type and table.get(PrefabPoiToPreset, prefab.poi_type, "Tags")
			local ptype_tags = prefab.type and table.get(PrefabTypeToPreset, prefab.type, "Tags")
			local marker_tags = prefab.tags
			tags = {}
			table.append(tags, ptype_tags)
			table.append(tags, marker_tags)
			table.append(tags, poi_tags)
			tags = table.keys(tags, true)
			prefab_to_tags[prefab] = #tags > 0 and tags or false
		end
		return tags
	end
	local function PrefabTagsToStr(tags, sep)
		return table.concat(tags, sep or ", ")
	end
	function DbgShowPrefab(pos, name, color, mark, rmin, rmax)
		local prefab = name and PrefabMarkers[name]
		local tags = prefab and GetPrefabTags(prefab) or empty_table
		if filter_tags then
			local found
			for _, tag in ipairs(tags) do
				if filter_tags[tag] then
					found = true
					break
				end
			end
			if not found then
				return
			end
		end
		if name and filter_name ~= "" and not string.find(name, filter_name) then
			return
		end
		if rmin then
			DbgAddCircle(pos, rmin * type_tile, color, -1, guim)
			if rmax then
				DbgAddCircle(pos, rmax * type_tile, color, -1, guim)
			end
		end
		DbgAddVector(pos, 50*guim, color)
		if name then
			if mark then
				name = name .. " (" .. mark .. ")"
			end
			local poi_type = prefab and prefab.poi_type or ""
			if poi_type ~= "" then
				name = name .. " " .. poi_type
			end
			if #tags > 0 then
				name = name .. " [" .. PrefabTagsToStr(tags) .. "]"
			end
			DbgAddText(name, ValidateZ(pos):AddZ(50*guim), color)
		end
		return true
	end
	
	if self.dbg_inspect ~= new_inspect
	or self.dbg_filter_name ~= filter_name
	or not table.equal_values(self.dbg_filter_tags, filter_tags) then
		self.dbg_inspect = new_inspect
		self.dbg_filter_tags = filter_tags
		self.dbg_filter_name = filter_name
		DbgClear()
		DbgStopInspect()
		if new_inspect == "Pos" then
			DbgInspectThread = CreateMapRealTimeThread(function()
				WaitNextFrame(1)
				local shown = 0
				for mark, info in ipairs(self.PrefabList or empty_table) do
					local name, pos = table.unpack(info)
					local color = self:DbgGetColor(mark)
					if color and DbgShowPrefab(pos, name, color, mark) then
						shown = shown + 1
					end
				end
				print("Shown", shown, "prefabs")
			end)
		elseif new_inspect == "POI" then
			DbgInspectThread = CreateMapRealTimeThread(function()
				WaitNextFrame(1)
				local poi_to_preset = PrefabPoiToPreset
				local shown = 0
				for mark, info in ipairs(self.PrefabList or empty_table) do
					local name, pos = table.unpack(info)
					local prefab = PrefabMarkers[name]
					local poi_type = prefab and prefab.poi_type or ""
					local preset = poi_type ~= "" and poi_to_preset[poi_type]
					if preset and DbgShowPrefab(pos, name, preset.OverlayColor, mark, prefab.max_radius) then
						shown = shown + 1
					end
				end
				print("Shown", shown, "prefabs")
			end)
		elseif new_inspect == "Rollover" then
			DbgInspectThread = CreateMapRealTimeThread(function()
				local last_mark, last_prefab, last_mark, last_click = 0
				while DbgInspectThread == CurrentThread() do
					DbgClearColors()
					local mark = 0
					if self.dbg_obj_to_prefab_mark then
						local solid, transparent = GetPreciseCursorObj()
						local obj = GetTopmostParent(transparent or solid)
						mark = obj and self.dbg_obj_to_prefab_mark[obj] or 0
						if obj then
							DbgSetColor(obj, white)
						end
					end
					if mark == 0 and self.MarkGrid and self.PrefabList then
						local pos = DbgGetInspectPos()
						mark = GridGetMark(self.MarkGrid, pos) or 0
					end
					if mark ~= last_mark then
						last_mark = mark
						DbgClear()
						local name, pos, color
						if mark ~= 0 then
							local info = self.PrefabList[mark] or empty_table
							name, pos = table.unpack(info)
							pos = pos:SetInvalidZ()
							color = self:DbgGetColor(mark) or white
						end
						if name then
							local prefab = PrefabMarkers[name]
							DbgShowPrefab(pos, name, color, mark, prefab.min_radius, prefab.max_radius)
						end
						last_prefab = name
						WaitNextFrame(1)
					else
						WaitNextFrame(10)
					end
					local tool = GetDialog("XSelectObjectsTool")
					local terrain_pos = tool and tool.last_mouse_click 
					if not terrain_pos then
						last_click = nil
					elseif terrain_pos ~= last_click then
						last_click = terrain_pos
						local prefab = PrefabMarkers[last_prefab] or empty_table
						self.SelectedPrefab = last_prefab
						self.SelectedMark = last_mark
						self.SelectedTags = PrefabTagsToStr(GetPrefabTags(prefab))
						self.SelectedPoi = prefab.poi_type
						self:DbgOnModified()
					end
				end
			end)
		end
	end
end

local function BiomeFiller_ObjModified(obj)
	ObjModified(obj)
end

function BiomeFiller:DbgOnModified()
	DelayedCall(20, BiomeFiller_ObjModified, self)
end

local function ChangeSortKey(key, ...)
	local keys = {...}
	local idx = table.find(keys, key)
	return idx and keys[idx + 1] or keys[1]
end
local function GetSortedList(list, key, ...)
	local keys = {...}
	local sort = {}
	for i=1,#keys do
		sort[i] = keys[i] == key and "*" or ""
	end
	list = list or {}
	local function CmpItemValues(a, b, k, ...)
		if not k then
			return
		end
		local va, vb = a[k], b[k]
		if va ~= vb then
			return va > vb
		end
		return CmpItemValues(a, b, ...)
	end
	table.sort(list, function(a, b)
		return CmpItemValues(a, b, key, table.unpack(keys))
	end)
	return list, keys, sort
end

BiomeFiller.dbg_placed_objects_sort = "count"

function BiomeFiller:ActionSortObjects()
	self.dbg_placed_objects_sort = ChangeSortKey(self.dbg_placed_objects_sort, "class", "count")
	self:DbgOnModified()
end

function BiomeFiller:GetPlacedObjects()
	local list, keys, sort = GetSortedList(self.dbg_placed_objects, self.dbg_placed_objects_sort, "class", "pct", "count")
	local tmp = {
		string.format("%35s | %6s | %s", table.unpack(sort)),
		string.format("%35s | %6s | %s", table.unpack(keys)),
		"-------------------------------------------------------------------------------------------",
	}
	for _, t in ipairs(list) do
		local pct = t.pct
		tmp[#tmp + 1] = string.format("%35s | %3d.%02d | %d", t.class, pct / pct_mul, pct % pct_mul, t.count)
	end
	return table.concat(tmp, "\n")
end

BiomeFiller.dbg_placed_prefabs_sort = "impact"
function BiomeFiller:ActionSortPrefabs()
	self.dbg_placed_prefabs_sort = ChangeSortKey(self.dbg_placed_prefabs_sort, "name", "count", "objs", "grid", "impact")
	self:DbgOnModified()
end
function BiomeFiller:GetPlacedPrefabs()
	local list, keys, sort = GetSortedList(self.dbg_placed_prefabs, self.dbg_placed_prefabs_sort, "name", "count", "objs", "load", "place", "grid", "load", "place", "impact")
	local tmp = {
		string.format("%35s %5s   %5s %5s %5s   %5s %5s %5s   %s", table.unpack(sort)),
		string.format("%35s %5s | %5s %5s %5s | %5s %5s %5s | %s", table.unpack(keys)),
		"-------------------------------------------------------------------------------------------",
	}
	for _, t in ipairs(list) do
		local prefab = t.prefab
		tmp[#tmp + 1] = string.format("%35s %5d | %5d %5d %5d | %5d %5d %5d | %d",
			t.name, t.count,
			t.objs, t.obj_load_time or 0, t.obj_place_time or 0,
			t.grid, t.grid_load_time or 0, t.grid_place_time or 0,
			t.impact)
	end
	return table.concat(tmp, "\n")
end

BiomeFiller.dbg_prefab_types_sort = "area"
function BiomeFiller:ActionSortPrefabTypes()
	self.dbg_prefab_types_sort = ChangeSortKey(self.dbg_prefab_types_sort, "name", "area", "prefabs")
	self:DbgOnModified()
end
function BiomeFiller:GetPrefabTypes()
	local list, keys, sort = GetSortedList(self.dbg_prefab_types, self.dbg_prefab_types_sort, "name", "area", "prefabs")
	local tmp = {
		string.format("%35s   %6s   %s", table.unpack(sort)),
		string.format("%35s | %6s | %s", table.unpack(keys)),
		"-------------------------------------------------------------------------------------------",
	}
	for _, t in ipairs(list) do
		local prefab = t.prefab
		local area = t.area or 0
		local fully_hidden = t.fully_hidden or 0
		tmp[#tmp + 1] = string.format("%35s | %3d.%02d | %d",
			t.name, area / pct_mul, area % pct_mul, t.prefabs)
	end
	return table.concat(tmp, "\n")
end

BiomeFiller.dbg_visible_prefabs_sort = "visible_area"
function BiomeFiller:ActionSortVisible()
	self.dbg_visible_prefabs_sort = ChangeSortKey(self.dbg_visible_prefabs_sort, "visible_area", "fully_hidden")
	self:DbgOnModified()
end
function BiomeFiller:GetVisiblePrefabs()
	local list, keys, sort = GetSortedList(self.dbg_visible_prefabs, self.dbg_visible_prefabs_sort, "name", "visible_area", "fully_hidden")
	local tmp = {
		string.format("%35s   %12s   %12s", table.unpack(sort)),
		string.format("%35s | %12s | %12s", table.unpack(keys)),
		"-------------------------------------------------------------------------------------------",
	}
	for _, t in ipairs(list) do
		local prefab = t.prefab
		local visible_area = t.visible_area or 0
		local fully_hidden = t.fully_hidden or 0
		tmp[#tmp + 1] = string.format("%35s | %9d.%02d | %9d.%02d",
			t.name, visible_area / pct_mul, visible_area % pct_mul, fully_hidden / pct_mul, fully_hidden % pct_mul)
	end
	return table.concat(tmp, "\n")
end

BiomeFiller.dbg_placed_poi_sort = "count"
function BiomeFiller:ActionSortPoi()
	self.dbg_placed_poi_sort = ChangeSortKey(self.dbg_placed_poi_sort, "name", "count")
	self:DbgOnModified()
end
function BiomeFiller:GetPlacedPOI()
	local list, keys, sort = GetSortedList(self.dbg_placed_poi, self.dbg_placed_poi_sort, "name", "count")
	local tmp = {
		string.format("%35s   %s", table.unpack(sort)),
		string.format("%35s | %s", table.unpack(keys)),
		"-------------------------------------------------------------------------------------------",
	}
	for _, t in ipairs(list) do
		local prefab = t.prefab
		tmp[#tmp + 1] = string.format("%35s | %d", t.name, t.count)
	end
	return table.concat(tmp, "\n")
end

--[[
function BiomeActionImport(ged)
	if not g_BiomeFiller then
		print("No biome filler found!")
		return
	end
	local props = GetModifiedProperties(g_BiomeFiller) or {}
	local preset = BiomeFillerPreset:new()
	props.Id = preset:GenerateUniquePresetId("Imported")
	preset:SetProperties(props)
	preset:PostLoad()
	ObjModified(Presets.BiomeFillerPreset)
end
--]]

function BiomeFiller:ViewInspectedPrefab()
	local pattern = self.InspectPattern
	if pattern == "" then
		print("No prefab name selected")
		return
	end
	local unpack = table.unpack
	local list = self.PrefabList or empty_table
	local last_mark = self.dbg_view_mark
	local mark, mark_pos, mark_radius, mark_name
	local count = #list
	local i = last_mark + 1
	for n = 1, count do
		if i > count then i = 1 end
		local name, pos = unpack(list[i])
		if string.find(name, pattern) then
			mark, mark_pos, mark_name = i, pos, name
			
			break
		end
		i = i + 1
	end
	if not mark then
		print("No placed prefabs matching the pattern:", name)
		return
	end
	self.dbg_view_mark = mark
	local prefab = PrefabMarkers[mark_name]
	local prefab_radius = prefab and prefab.max_radius * type_tile
	ViewPos(mark_pos, 2 * prefab_radius)
	printf("Shown: %s [%d]", mark_name, mark)
end

function OnMsg.GedPropertyEdited(_, obj)
	if IsKindOf(obj, "NoisePreset") then
		ForEachPreset("Biome", function(biome)
			if biome.TypeMixingPreset == obj.id then
				ObjModified(biome)
			end
		end)
	end
end

function Biome:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "TypeMixingPreset" then
		self:CalcTypeMixingPreview()
	else
		local prop = self:GetPropertyMetadata(prop_id)
		if prop.recalc_curve then
			self["CalcCurve" .. prop.recalc_curve](self)
		end
	end
end

function OnMsg.ChangeMap()
	g_BiomeFiller = false
end
