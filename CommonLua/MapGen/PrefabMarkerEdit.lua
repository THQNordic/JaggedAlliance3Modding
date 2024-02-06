if not Platform.editor then
	return
end

if FirstLoad then
	l_LockedCol = false
	l_ResaveAllMapsThread = false
end

local height_tile = const.HeightTileSize
local type_tile = const.TypeTileSize
local height_scale = const.TerrainHeightScale
local gofPermanent = const.gofPermanent
local height_roughness_unity = 1000
local height_roughness_err = 1200
local height_outline_offset_err = guim
local invalid_type_value = 255
local GetHeight = terrain.GetHeight

local mask_max = 255
local invalid_type_value = 255
local invalid_grass_value = 255
local transition_max_pct = 30
local GetClassFlags = CObject.GetClassFlags
local cfCodeRenderable = const.cfCodeRenderable

local granularity = GetTerrainGridsMaxGranularity()
local clrNoModifier = SetA(const.clrNoModifier, 255)

local function get_surface(...)
	return Max(GetWalkableZ(...), GetHeight(...))
end
local function set_surface_z(pt, offset)
	return pt:SetZ(get_surface(pt) + (offset or 0))
end

function OnMsg.MarkersRebuildStart()
	if mapdata.IsPrefabMap then
		GridStatsReset()
	end
	l_LockedCol = Collection.GetLockedCollection()
	if l_LockedCol then
		l_LockedCol:SetLocked(false)
	end
end

function OnMsg.MarkersRebuildEnd()
	if mapdata.IsPrefabMap then
		local stat_usage = GridStatsUsage() or ""
		if #stat_usage > 0 then
			DebugPrint("Grid ops:\n")
			DebugPrint(print_format(stat_usage))
			DebugPrint("\n")
		end
	end
end

local function PrefabIsResaving()
	return IsValidThread(l_ResaveAllMapsThread)
end

function OnMsg.MarkersChanged()
	if PrefabIsResaving() then
		return
	end
	if l_LockedCol then
		l_LockedCol:SetLocked(true)
	end
	l_LockedCol = false
	PrefabUpdateMarkers()
end

local function get_marker_terrains(obj)
	local items = {}	
	local bbox = obj:GetBBox()
	local invalid_terrain_idx = GetTerrainTextureIndex(obj.InvalidTerrain) or -1
	local mask = GridGetTerrainMask(bbox, invalid_terrain_idx)
	local skipped_terrain_idxs = obj:GetSkippedTextureList()
	local _, types = GridGetTerrainType(bbox, mask, invalid_type_value, invalid_terrain_idx, skipped_terrain_idxs)
	for _, idx in ipairs(types) do
		local texture = TerrainTextures[idx]
		if texture then
			items[#items + 1] = texture.id
		end
	end
	table.sort(items)
	table.insert(items, 1, "")
	return items
end
local debug_show_types = {
	"capture_box", "radius", "flat_zone", "crit_slope", "roughness",
	"height_offset", "height_lims", "missing_types", "transition",
	"large_objs", "optional_objs", "collections",
}
local def_show_types = set("capture_box")

DefineClass.PrefabMarkerEdit = {
	__parents = { "InitDone" },
	properties = {
		{ category = "Checks", id = "CheckObjCount",     name = "Objects Count",         editor = "bool",         default = true,      help = "Perform check of the object's density on export" },
		{ category = "Checks", id = "CheckObjRadius",    name = "Objects Radius",        editor = "bool",         default = true,      help = "Perform check of the object's max radius on export" },
		{ category = "Checks", id = "CheckRougness",     name = "Height Rougness",       editor = "bool",         default = true,      help = "Perform check of the height map rougness" },
		{ category = "Checks", id = "CheckRadiusRatio",  name = "Radius Ratio",          editor = "bool",         default = true,      help = "Perform check of the max to min radius ratio" },
		{ category = "Checks", id = "CheckVisibility",   name = "Objects Visibility",    editor = "bool",         default = true,      help = "Search for invisible or completely transparent objects" },
		
		{ category = "Stats", id = "ClassToCountStat", name = "Objs by Class",      editor = "text",       default = "", lines = 1, max_lines = 10, read_only = true, developer = true, dont_save = true  },
		{ category = "Stats", id = "ClassToCount",                                  editor = "prop_table", default = false, no_edit = true },
		{ category = "Stats", id = "ExportTime",       name = "Prefab Export (ms)", editor = "number",     default = 0, read_only = true, dont_save = true },

		{ category = "Debug", id = "source",           name = "Source",             editor = "prop_table", default = false,     export = "marker", read_only = true, indent = ' ', buttons = {{name = "View", func = "ActionViewSource"}}},
		{ category = "Debug", id = "place_mark",       name = "Place Mark",         editor = "number",     default = -1,        read_only = true, dont_save = true },
		{ category = "Debug", id = "apply_pos",        name = "Apply Pos",          editor = "point",      default = false,     read_only = true, dont_save = true },
		{ category = "Debug", id = "DebugShow",        name = "Debug Show",         editor = "set",        default = def_show_types, items = debug_show_types, developer = true, dont_save = true, help = "collections and optional_objs cannot be used at the same time"},
		{ category = "Debug", id = "ShowType",         name = "Show Terrain Type",  editor = "set",        default = set(), items = get_marker_terrains, developer = true, dont_save = true, buttons = {{name = "Update", func = "ActionShowTypeUpdate"}}, },
		{ category = "Debug", id = "OverlayAlpha",     name = "Overlay Alpha (%)",  editor = "number",     default = 30,     slider = true, min = 0, max = 100, dont_save = true },
	},
	editor_objects_visible = false,
	editor_objects = false,
	object_colors = false,
	editor_update_thread = false,
	editor_update_time = false,
	DebugErrorShow = false,
}

function PrefabMarkerEdit:ActionShowTypeUpdate()
	self:DbgShowTypes()
end

function DebugOverlayControl:SetOverlayAlpha(alpha)
	hr.TerrainDebugAlphaPerc = alpha
end

function DebugOverlayControl:GetOverlayAlpha()
	return hr.TerrainDebugAlphaPerc
end

if FirstLoad then
	dbg_common_grid = false
end

function OnMsg.ChangeMap()
	DbgHideTerrainGrid(dbg_common_grid)
	dbg_common_grid = false
end

function DbgUpdateTypesGrid()
	local tgrid, dest_grid, type_to_palette, palette, mask, tmp
	local last_palette_idx = 1
	local markers = MapGet("map", "PrefabMarker")
	for _, marker in ipairs(markers) do
		local remap, grid
		for tname, show in pairs(IsValid(marker) and marker.ShowType or empty_table) do
			local type_idx = show and GetTerrainTextureIndex(tname)
			if type_idx then
				type_to_palette = type_to_palette or {}
				local palette_idx = type_to_palette[type_idx]
				if not palette_idx then
					palette_idx = last_palette_idx + 1
					last_palette_idx = palette_idx
					type_to_palette[type_idx] = palette_idx
					palette = palette or {0}
					palette[palette_idx] = RandColor(xxhash(tname))
				end
				remap = remap or {}
				remap[type_idx] = palette_idx
			end
		end
		if remap then
			tgrid = tgrid or terrain.GetTypeGrid()
			dest_grid = dest_grid or GridDest(tgrid, true)
			mask = mask or GridDest(tgrid)
			tmp = tmp or GridDest(tgrid)
			mask:clear()
			GridDrawBox(mask, marker:GetBBox():grow(type_tile / 2) / type_tile, 1)
			GridMulDiv(tgrid, tmp, mask, 1)
			GridReplace(tmp, remap, 0)
			GridAdd(dest_grid, tmp)
		end
	end
	if not dest_grid then
		DbgHideTerrainGrid(dbg_common_grid)
		dbg_common_grid = false
	else
		DbgShowTerrainGrid(dest_grid, palette)
		dbg_common_grid = dest_grid
	end
end

function PrefabMarkerEdit:DbgShowTypes()
	CreateRealTimeThread(DbgUpdateTypesGrid)
end

local function ApplyObjectColors(obj_colors, apply)
	for obj, obj_color in pairs(obj_colors or empty_table) do
		local new_clr, orig_clr = table.unpack(obj_color)
		if IsValid(obj) then
			local prev_clr = obj:GetColorModifier()
			if apply and new_clr ~= prev_clr then
				obj_color[2] = prev_clr
				obj:SetColorModifier(new_clr)
			elseif not apply and orig_clr and prev_clr == new_clr then
				obj:SetColorModifier(orig_clr)
			end
		end
	end
end

function PrefabMarkerEdit:EditorObjectsDestroy()
	DoneObjects(self.editor_objects )
	ApplyObjectColors(self.object_colors, false)
	self.editor_objects = nil
	self.object_colors = nil
end

function PrefabMarkerEdit:PostLoad(reason)
	self:EditorObjectsCreate()
end

function PrefabMarkerEdit:Done()
	self:EditorObjectsDestroy()
end

local function GridExtrem(grid)
	local laplacian = {
		-8, -11, -8,
		-11, 76, -11,
		-8, -11, -8,
	}
	local extrem = GridFilter(grid, laplacian, 76)
	GridMulDiv(extrem, height_scale * height_roughness_unity, height_tile)
	GridAbs(extrem)
	return extrem
end

local function PrefabEvalPlayableArea(height_map, mask, tile_size, play_zone, border)
	local mw, mh = height_map:size()
	local flat_zone = GridSlope(height_map, tile_size, height_scale)
	local max_play_sin = sin(const.RandomMap.PrefabMaxPlayAngle)
	GridMulDiv(flat_zone, 4096, 1)
	GridMask(flat_zone, 0, max_play_sin)
	if mask then
		GridAnd(flat_zone, mask)
	end
	border = border and (border + tile_size - 1) / tile_size or 0
	if border > 0 then
		assert(border >= 0 and 2 * border < Min(mw, mh), "Invalid border size")
		GridFrame(flat_zone, border, 0)
	end
	if play_zone then
		play_zone:clear()
	end
	local play_area = 0
	local min_play_radius = const.RandomMap.PrefabMinPlayRadius
	local radius = min_play_radius / tile_size
	local min_area = radius * radius * 22 / 7
	local zones = GridEnumZones(flat_zone, min_area)
	local level_dist = GridDest(flat_zone)
	for i=1,#zones do
		local zone = zones[i]
		assert(zone.size >= min_area)
		GridMask(flat_zone, level_dist, zone.level)
		GridDistance(level_dist, tile_size, min_play_radius)
		local minv, maxv = GridMinMax(level_dist)
		if maxv >= min_play_radius then
			play_area = play_area + zone.size
			if play_zone then
				GridOr(play_zone, level_dist)
			end
		end
	end
	return play_area
end

function PrefabMarkerEdit:EditorObjectsCreate()
	if not self:IsValidPos() then
		StoreErrorSource("silent", self, "Object on invalid pos!")
		return
	end
	self:EditorObjectsDestroy()
	local show = self.DebugShow
	if self.DebugErrorShow then
		show = table.copy(show)
		show[self.DebugErrorShow] = true
	end
	local objects, obj_colors = {}, {}
	local points, colors = {}, {}
	local function add_line()
		if #(points or "") == 0 then
			return
		end
		local v_pstr = pstr("")
		local line = PlaceObject("Polyline")
		for i, point in ipairs(points) do 
			v_pstr:AppendVertex(point, colors[i])
		end 
		--line:SetDepthTest(true)
		line:SetMesh(v_pstr)
		line:SetPos(AveragePoint(points))
		objects[#objects + 1] = line
		points, colors = {}, {}
	end
	local function add_vector(pt, vec, color)
		vec = vec or 10*guim
		if type(vec) == "number" then
			vec = point(0, 0, vec)
		end
		local v_pstr  = pstr("")
		v_pstr:AppendVertex(pt, color)
		v_pstr:AppendVertex(pt + vec)
		local line = PlaceObject("Polyline")
		line:SetMesh(v_pstr)
		line:SetPos(pt)
		objects[#objects + 1] = line
	end
	local function add_circle(center, radius, color)
		local circle = PlaceTerrainCircle(center, radius, color)
		--circle:SetDepthTest(false)
		objects[#objects + 1] = circle
	end
	local pt1 = self:GetVisualPos()
	local x0, y0, z0 = pt1:xyz()
	local clr_mod = SetA(self:GetColorModifier(), 255)
	local color = clr_mod ~= clrNoModifier and clr_mod or self.ExportError ~= "" and red or editor.IsSelected(self) and cyan or white
	local terrain_lines = {}
	local angle = self:GetAngle()
	local w0, h0 = self.CaptureSize:xy()
	local selected = editor.IsSelected(self)
	
	if show.capture_box and w0 > type_tile and h0 > type_tile then
		if angle == 0 then
			local box = PlaceBox(box(x0, y0, guim, x0 + w0 - type_tile, y0 + h0 - type_tile, guim), color, nil, "depth test")
			box:AddMeshFlags(const.mfTerrainDistorted)
			objects[#objects + 1] = box
		else
			local w = w0 - type_tile
			local h = h0 - type_tile
			local edges = {
				point(-w,-h),
				point( w,-h),
				point( w, h),
				point(-w, h),
			}
			if not self.Centered then
				for i=1,#edges do
					edges[i] = edges[i] + point(w0, h0)
				end
			end
			if angle then
				for i=1,#edges do
					edges[i] = Rotate(edges[i], angle)
				end
			end
			for i=1,#edges do
				edges[i] = pt1 + edges[i] / 2
			end
			edges[#edges + 1] = edges[1]
			for i=1,#edges-1 do
				local line = PlaceTerrainLine(edges[i], edges[i + 1], color)
				objects[#objects + 1] = line
			end
		end
	end
	local minr, maxr = self.RadiusMin, self.RadiusMax * type_tile
	if show.radius and maxr > 0 then
		local prefab = {
			min_radius = self.RadiusMin * type_tile,
			max_radius = self.RadiusMax * type_tile,
			total_area = self.TotalArea * type_tile * type_tile,
		}
		local pos = pt1 + Rotate(self.CaptureSize / 2, angle)
		local estimators = PrefabRadiusEstimators()
		local items = PrefabRadiusEstimItems()
		for _, item in ipairs(items) do
			local estimator = estimators[item.value]
			add_circle(pos, estimator(prefab), item.color)
			local r, g, b = GetRGB(item.color)
			printf("once", "<color %d %d %d>%s</color>", r, g, b, item.text)
		end
	end
	local function add_box(center, size, color)
		local edges = {
			point(-1,-1) * size / 2,
			point( 1,-1) * size / 2,
			point( 1, 1) * size / 2,
			point(-1, 1) * size / 2,
		}
		for i=1,#edges do
			local pt = edges[i] + center
			edges[i] = set_surface_z(pt, guim/2)
		end
		local dz = point(0, 0, 2*size)
		edges[#edges + 1] = edges[1]
		local N = 1
		for i=1,#edges do
			points[N] = edges[i]
			colors[N] = color
			N = N + 1
		end
		add_line()
	end
	local height_map = self.HeightMap
	local type_map = self.TypeMap
	local mask = self.MaskMap
	local msize = mask and mask:size() or 0
	local require_ex = show.flat_zone or show.crit_slope or show.roughness or show.transition or show.height_offset
	local height_map_ex = require_ex and height_map and GridRepack(height_map, "F")
	local height_offset = self.HeightOffset
	if height_map_ex then
		GridAdd(height_map_ex, height_offset)
	end
	local mask_ex = require_ex and mask and GridRepack(mask, "F")
	local xc2, yc2 = 2 * x0 + w0 + 1, 2 * y0 + h0 + 1
	local function show_grid(grid, minv, maxv, color0, color1)
		local w, h = grid:size()
		local min_step = type_tile
		local max_step = type_tile * Min(w, h) / 64
		local step = Max(min_step, Min(max_step, type_tile))
		color0 = color0 or red
		minv = minv or min_int
		maxv = maxv or max_int
		local count, max_count = 0, 8*1024
		local data = {}
		GridForeach(grid, function(v, x, y)
			count = count + 1
			if count >= max_count then
				return
			end
			local px = (xc2 + (2 * x - w + 1) * type_tile) / 2
			local py = (yc2 + (2 * y - h + 1) * type_tile) / 2
			local clr = color1 and InterpolateRGB(color0, color1, v - minv, maxv - minv) or color0
			data[#data + 1] = {point(px, py), clr}
		end, minv, maxv, step, type_tile)
		if count >= max_count then
			print("Debug show cancelled, too much to draw!")
		end
		for i=1,#data do
			local pos, clr = table.unpack(data[i])
			add_box(pos, step - min_step/2, clr)
			if count < 100 then
				add_vector(set_surface_z(pos), 10*guim, clr)
			end
		end
	end
	if show.flat_zone and height_map_ex and mask_ex then
		local flat_zone = GridDest(height_map_ex)
		PrefabEvalPlayableArea(height_map_ex, mask_ex, type_tile, flat_zone)
		show_grid(flat_zone, 0, max_int, green)
	end
	local hsize = height_map_ex and height_map_ex:size() or 0
	local function grid_to_world(gx, gy)
		if not gy then
			return point(grid_to_world(gx:xy()))
		end
		local x = (xc2 + (2 * gx - hsize + 1) * height_tile) / 2
		local y = (yc2 + (2 * gy - hsize + 1) * height_tile) / 2
		return x, y
	end
	if show.crit_slope and hsize > 0 then
		local crit_angle = const.MaxPassableTerrainSlope
		local tol_angle = 3*60 + 30
		local mesh = {}
		local slope = GridSlope(height_map_ex, height_tile, height_scale)
		GridASin(slope, true, 180*60)
		GridAdd(slope, -crit_angle)
		GridAbs(slope)
		show_grid(slope, 0, tol_angle, red, yellow)
	end
	if show.height_lims and hsize > 0 then
		local minv, maxv, minp, maxp = GridMinMax(height_map, true)
		minp = grid_to_world(minp):SetZ(minv)
		maxp = grid_to_world(maxp):SetZ(maxv)
		add_vector(minp, 100*guim, red)
		add_vector(maxp, 100*guim, green)
		add_circle(minp, 2*guim, red)
		add_circle(maxp, 2*guim, green)
	end
	if show.roughness and hsize > 0 then
		local extrem = GridExtrem(height_map_ex, height_tile, height_scale)
		show_grid(extrem, height_roughness_err)
	end
	if show.height_offset and height_map and msize then
		local mesh = {}
		local outline = GridDest(mask_ex)
		GridOutline(mask_ex, outline, true)
		GridMulDiv(outline, height_map_ex, 1)
		GridAbs(outline)
		show_grid(outline, height_outline_offset_err)
	end
	if show.transition and msize > 0 then
		show_grid(mask_ex, 1, 255 - 1, yellow, red)
	end
	local objs
	if show.large_objs then
		local obj_max_radius = const.RandomMap.PrefabMaxObjRadius or GetEntityMaxSurfacesRadius()
		objs = objs or self:CollectObjs()
		for _, obj in ipairs(objs) do
			if obj:GetRadius() > obj_max_radius then
				local bbox = PlaceBox(ObjectHierarchyBBox(obj), red, nil, "depth test")
				objects[#objects + 1] = bbox
				StoreErrorSource(obj, "Too large object")
			end
		end
	end
	if show.optional_objs then
		objs = objs or self:CollectObjs()
		for _, obj in ipairs(objs) do
			if obj:GetOptionalPlacement() then
				obj_colors[obj] = {cyan, 0}
			end
		end
	elseif show.collections then
		objs = objs or self:CollectObjs()
		local hsb_max = 1020
		local Collections = Collections
		local GetCollectionIndex = CObject.GetCollectionIndex
		local clrNoModifier = const.clrNoModifier
		local topmost_coll, nested_count, parents_count = {}, {}, {}
		for _, obj in ipairs(objs) do
			local col_idx = GetCollectionIndex(obj) or 0
			if col_idx ~= 0 and not parents_count[col_idx] then
				local topmost_idx = col_idx
				local parents = 0
				while true do
					local topmost = Collections[topmost_idx]
					local parent_idx = GetCollectionIndex(topmost) or 0
					if parent_idx == 0 then
						break
					end
					parents = parents + 1
					topmost_idx = parent_idx
				end
				nested_count[topmost_idx] = Max(nested_count[topmost_idx] or 0, parents)
				parents_count[col_idx] = parents
				topmost_coll[col_idx] = topmost_idx
			end
		end
		local col_to_color, topmost_colors = {}, {}
		for _, obj in ipairs(objs) do
			local col_idx = obj:GetCollectionIndex() or 0
			if col_idx ~= 0 then
				local color = col_to_color[col_idx]
				if not color then
					local topmost_idx = topmost_coll[col_idx]
					local topmost_color = topmost_colors[topmost_idx]
					local nested_max = nested_count[topmost_idx]
					if not topmost_color then
						local max_dist, h, s
						local b = (hsb_max * 2 - hsb_max * Min(4, nested_max) / 4) / 3
						local i = 0 
						local rand = BraidRandomCreate(col_idx)
						while true do
							h, s = rand(hsb_max + 1), rand(hsb_max + 1)
							local rand_clr = HSB(h, s, b, hsb_max)
							if ColorDist(rand_clr, clrNoModifier) > 100 then
								i = i + 1
								if i == 10 then
									break
								end
								local min_dist = max_int
								for _, clr in pairs(topmost_colors) do
									min_dist = Min(min_dist, ColorDist(clr, rand_clr))
								end
								if not max_dist or max_dist < min_dist then
									max_dist = min_dist
									topmost_color = rand_clr
									if max_dist > 100 then
										break
									end
								end
							end
						end
						topmost_colors[topmost_idx] = topmost_color
					end
					local parents = parents_count[col_idx]
					if parents == 0 then
						color = topmost_color
					else
						local h, s, b = RGBtoHSB(topmost_color, hsb_max)
						local s1 = (s > hsb_max * 2 / 3) and (hsb_max / 3) or hsb_max
						local ds = (s1 - s) * Min(4, nested_max) / 4
						local db = hsb_max - b
						s = s + ds * parents / nested_max
						b = b + db * parents / nested_max
						color = HSB(h, s, b, hsb_max)
					end
					col_to_color[col_idx] = color
				end
				obj_colors[obj] = {color, 0}
			end
		end
	end
	ApplyObjectColors(obj_colors, true)
	self.object_colors = obj_colors
	self.editor_objects = objects
end

function PrefabMarkerEdit:EditorObjectsUpdate()
	self:EditorObjectsDestroy()
	self.editor_update_time = RealTime() + 30
	if IsValidThread(self.editor_update_thread) then
		return
	end
	self.editor_update_thread = CreateRealTimeThread(function()
		while RealTime() < self.editor_update_time do
			Sleep(self.editor_update_time - RealTime())
		end
		if IsValid(self) then
			self:EditorObjectsShow()
		end
	end)
end

function PrefabMarkerEdit:EditorObjectsShow(show)
	if show == nil then show = IsEditorActive() end
	local prev_show = self.editor_objects and self.editor_objects_visible
	if prev_show == show then
		return
	end
	self.editor_objects_visible = show
	if not self.editor_objects and show then
		self:EditorObjectsCreate()
	end
	for _, object in ipairs(self.editor_objects or empty_table) do
		if IsValid(object) then
			object:SetVisible(show)
		end
	end
	ApplyObjectColors(self.object_colors, show)
	self:SetVisible(show)
	if IsValid(self.editor_text_obj) then
		self.editor_text_obj:SetVisible(show)
	end
	ObjModified(self)
	PropertyHelpers_Refresh(self)
end

function PrefabMarkerEdit:EditorEnter()
	self:EditorObjectsShow(true)
end

function PrefabMarkerEdit:EditorExit()
	self:EditorObjectsShow(false)
end

function PrefabMarkerEdit:OnEditorSetProperty(prop_id, old_value)
	if prop_id == "DebugShow" then
		local show = self.DebugShow
		if show.collections and show.optional_objs then
			show = table.copy(show)
			if old_value.collections then -- collections and optional objects are mutually exclusive
				show.collections = nil
			else
				show.optional_objs = nil
			end
			self.DebugShow = show
		end
		self:EditorObjectsUpdate()
	end
	if prop_id == "Centered" or prop_id == "ColorModifier" then
		self:EditorObjectsUpdate()
	end
	if prop_id == "ShowType" then
		self:DbgShowTypes()
	elseif prop_id == "CaptureSize" then
		local w, h = self.CaptureSize:xy()
		if w < 0 then w = max_int end
		if h < 0 then h = max_int end
		local x, y = self:GetVisualPosXYZ()
		w = Min(w, terrain.GetMapWidth() - x)
		h = Min(h, terrain.GetMapHeight() - y)
		w = (w / granularity) * granularity
		h = (h / granularity) * granularity
		self.CaptureSize = point(w, h)
		self:EditorObjectsUpdate()
	elseif prop_id == "CircleMaskRadius" then
		self:CaptureTerrain()
	end
end

PrefabMarkerEdit.EditorCallbackPlace = PrefabMarkerEdit.EditorObjectsUpdate
PrefabMarkerEdit.EditorCallbackRotate = PrefabMarkerEdit.EditorObjectsUpdate
PrefabMarkerEdit.EditorCallbackMove = PrefabMarkerEdit.EditorObjectsUpdate

local function GetMaxNegShape(mask)
	GridNot(mask)
	local zones = GridEnumZones(mask, 32, max_int, 256)
	if #zones == 256 then
		return "Too many shapes found"
	end
	local zone = table.max(zones, "size")
	if not zone then
		return "No shapes found"
	end
	GridMask(mask, zone.level)
end

function PrefabMarkerEdit:GetSkippedTextureList()
	local indexes
	for _, terrain in ipairs(self.SkippedTerrains or empty_table) do
		local idx = GetTerrainTextureIndex(terrain)
		if not idx then
			StoreErrorSource(self, "Terrain name not found:", terrain)
		else
			indexes = indexes or {}
			indexes[#indexes + 1] = idx
		end
	end
	return indexes or empty_table
end

function PrefabMarkerEdit:GetBBox()
	local bbox
	local x, y = self:GetVisualPosXYZ()
	local w, h = self.CaptureSize:xy()
	if w <= 0 or h <= 0 then
		return
	end
	if self.Centered then
		local dx, dy = w / 2, h / 2
		return box(x - dx, y - dy, x + dx, y + dy)
	else
		return box(x, y, x + w, y + h)
	end
end

function PrefabMarkerEdit:SetBBox(bbox)
	local x, y, z = self:GetPosXYZ()
	local bw, bh = bbox:size():xy()
	local x1, y1
	if self.Centered then
		x1, y1 = bbox:Center():xy()
	else
		x1, y1 = bbox:minxyz()
	end
	self:SetPos(x1, y1, z)
	self.CaptureSize = point(bw, bh)
end
				
function PrefabMarkerEdit:CaptureTerrain(shrinked, extended)
	local st = GetPreciseTicks()
	self:ClearTerrain()
	local bbox = self:GetBBox()
	if not bbox then
		return
	end
	local abox = bbox:Align(granularity)
	if abox ~= bbox then
		bbox = abox
		self:SetBBox(abox)
	end
	
	local memory = 0
	local x, y, z = self:GetVisualPosXYZ()
	local w, h = self.CaptureSize:xy()
	local mask
	
	local invalid_terrain_idx = -1
	if self.InvalidTerrain ~= "" then
		invalid_terrain_idx = GetTerrainTextureIndex(self.InvalidTerrain) or -1
		if invalid_terrain_idx == -1 then
			StoreErrorSource(self, "Invalid terrain type specified")
		end
	end
	local transition_dist = self:GetTransitionDist()
	if self.CircleMask then
		mask = GridGetEmptyMask(bbox)
		local radius = self.CircleMaskRadius or Min(w, h) / 2
		GridCircleSet(mask, mask_max, w / 2, h / 2, radius, transition_dist, type_tile)
	elseif invalid_terrain_idx ~= -1 then
		local extend_retries = 0
		local post_process = self.PostProcess or 0
		while true do
			mask = GridGetTerrainMask(bbox, invalid_terrain_idx)
			if not mask then
				return
			elseif GridEquals(mask, 0) then
				StoreErrorSource(self, "Only invalid terrain found!")
				return
			elseif not GridFind(mask, 0) then
				StoreErrorSource(self, "Invalid terrain not found!")
				return
			end
			if post_process > 0 then
				local err = GetMaxNegShape(mask) or GetMaxNegShape(mask)
				if err then
					StoreErrorSource(self, err)
					return
				end
			end
			if extended or post_process < 2 then
				break
			end
			local mw, mh = mask:size()
			local minx, miny, maxx, maxy = GridBBox(mask)
			if minx > 0 and maxx < mw and miny > 0 and maxy < mh then
				if extend_retries == 0 then
					break
				end
				self:SetBBox(bbox)
				return self:CaptureTerrain(false, true)
			elseif extend_retries > 100 then
				StoreErrorSource(self, "Capture size extend error. Adjustment disabled!")
				return self:CaptureTerrain(true, true)
			end
			local bminx, bminy, bmaxx, bmaxy = bbox:xyxy()
			if minx <= 0 then bminx = bminx - granularity end
			if miny <= 0 then bminy = bminy - granularity end
			if maxx >= mw then bmaxx = bmaxx + granularity end
			if maxy >= mh then bmaxy = bmaxy + granularity end
			bbox = box(bminx, bminy, bmaxx, bmaxy)
			assert(bbox == bbox:Align(granularity))
			extend_retries = extend_retries + 1
		end
		if not shrinked and post_process > 1 then
			local minx, miny, maxx, maxy = GridBBox(mask)
			local new_bbox = box(
				x + (minx - 1) * type_tile, y + (miny - 1) * type_tile,
				x + (maxx + 1) * type_tile, y + (maxy + 1) * type_tile)
			new_bbox = new_bbox:Align(granularity)
			if new_bbox ~= bbox then
				self:SetBBox(new_bbox)
				return self:CaptureTerrain(true, true)
			end
		end
		if transition_dist > 0 then
			GridNot(mask)
			local fmask = GridRepack(mask, "F")
			GridDistance(fmask, type_tile, transition_dist, false) -- no approximation, will take longer to compute
			GridMulDiv(fmask, mask_max, transition_dist)
			GridRound(fmask)
			GridRepack(fmask, mask)
			fmask:free()
		else
			GridNormalize(mask, 0, mask_max)
		end
	end
	assert(bbox == bbox:Align(granularity))
	if mask then
		self.MaskHash = mask and xxhash(mask)
		self.MaskMap = mask
		memory = memory + GridGetSizeInBytes(mask) 
	end
	local capture_type = self.CaptureSet
	if capture_type.Terrain then
		local skipped_terrain_idxs = self:GetSkippedTextureList()
		local type_map, types = GridGetTerrainType(bbox, mask, invalid_type_value, invalid_terrain_idx, skipped_terrain_idxs)
		if not type_map then
			return
		end
		local type_names
		for _, idx in ipairs(types or empty_table) do
			local texture = TerrainTextures[idx]
			local name = texture and texture.id
			if name then
				type_names = type_names or {}
				type_names[name] = idx
			end
		end
		self.TypeHash = xxhash(type_map)
		self.TypeMap = type_map
		self.TypeNames = type_names
		memory = memory + GridGetSizeInBytes(type_map) 
	end
	--DbgClearVectors() DbgAddTerrainRect(bbox)
	if capture_type.Height then
		local terrain_z = z / height_scale
		local height_map, hmin, hmax = GridGetTerrainHeight(bbox, mask, terrain_z)
		if not height_map then
			return
		end
		self.HeightHash = xxhash(height_map)
		self.HeightMap = height_map
		self.HeightOffset = -terrain_z
		self.HeightMin = hmin - point(0, 0, terrain_z)
		self.HeightMax = hmax - point(0, 0, terrain_z)
		memory = memory + GridGetSizeInBytes(height_map) 
	end
	
	if capture_type.Grass then
		local grass_map = GridGetTerrainGrass(bbox, mask, invalid_grass_value, self.InvalidGrass)
		if not grass_map then
			return
		end
		if not GridEquals(grass_map, 0) then
			self.GrassHash = xxhash(grass_map)
			self.GrassMap = grass_map
		end
		memory = memory + GridGetSizeInBytes(grass_map) 
	end
	self.TerrainCaptureTime = GetPreciseTicks() - st
	self.RequiredMemory = memory
	self:EditorObjectsUpdate()
	return bbox
end

function PrefabMarkerEdit:ActionCaptureTerrain()
	self:CaptureTerrain()
	ObjModified(self)
	PropertyHelpers_Refresh(self)
end

function PrefabMarkerEdit:ActionClearTerrain()
	self:ClearTerrain()
	ObjModified(self)
	PropertyHelpers_Refresh(self)
end

function PrefabMarkerEdit:TerrainRectIsCentered()
	return self.Centered
end

function PrefabMarkerEdit:TerrainRectIsEnabled(prop_id)
	return prop_id == "CaptureSize" and next(self.CaptureSet) and not self.HeightHash and not self.TypeHash and not self.GrassHash
end

function PrefabMarkerEdit:OnEditorSelect(selected)
	self:EditorObjectsUpdate()
end

function PrefabMarkerEdit:ClearTerrain()
	self.HeightMap = nil
	self.HeightHash = nil
	self.HeightOffset = nil
	self.HeightMin = nil
	self.HeightMax = nil
		
	self.TypeMap = nil
	self.TypeHash = nil
	self.TypeNames = nil
	
	self.MaskMap = nil
	self.MaskHash = nil
	
	self.GrassMap = nil
	self.GrassHash = nil
end

function PrefabMarkerEdit:EditorCallbackDelete()
	self:EditorObjectsDestroy()
	self:DeleteExports()
end

function PrefabMarkerEdit:CollectObjs(bbox)
	bbox = bbox or self:GetBBox()
	return bbox and (MapGet(bbox, "attached", false, nil, nil, gofPermanent) or empty_table) or {self}
end

function PrefabMarkerEdit:ForceEditorMode(set)
	if not IsEditorActive() then
		return
	end
	MapForEach(self:GetBBox(), "attached", false, "EditorObject", nil, nil, gofPermanent, function(obj, set, self)
		if set then
			obj:EditorEnter()
		else
			obj:EditorExit()
		end
	end, set, self)
end

function PrefabMarkerEdit:ActionPrefabExport(root)
	local err, objs, defs = self:ExportPrefab()
	if err then
		print("Prefab", self:GetPrefabName(), "export failed:", err)
	else
		DebugPrint(TableToLuaCode(defs))
	end
end

function PrefabMarkerEdit:ActionPrefabRevision()
	local info = self:GetRevisionInfo()
	if info then
		self:ShowMessage(info, "Revision")
	end
end

function PrefabMarkerEdit:ActionExploreTo()
	local exported = self.ExportedName or ""
	if exported ~= "" and IsFSUnpacked() and ExportedPrefabs[exported] then
		local filename = GetPrefabFileObjs(exported)
		local dir, file, ext = SplitPath(filename)
		AsyncExec("explorer " .. ConvertToOSPath(dir))
	end
end

local function svn_process(file, prev_hash, new_hash)
	if new_hash then
		if SvnToAdd then
			SvnToAdd[#SvnToAdd + 1] = file
			return
		end
		return SVNAddFile(file)
	elseif not new_hash and prev_hash then
		if SvnToDel then
			SvnToDel[#SvnToDel + 1] = file
			return
		end
		return SVNDeleteFile(file)
	end
end

if FirstLoad then
	SvnToAdd = false
	SvnToDel = false
end
	
function OnMsg.MarkersRebuildStart()
	SvnToAdd, SvnToDel = {}, {}
end

function OnMsg.MarkersRebuildEnd()
	SVNAddFile(SvnToAdd)
	SVNDeleteFile(SvnToDel)
	SvnToAdd, SvnToDel = false, false
end

local function PrefabToMarkerName(name)
	return name and ("Prefab." .. name) or ""
end

function ShowPrefabMarker(prefab_name, ged)
	local marker_name = PrefabToMarkerName(prefab_name)
	local marker = Markers[marker_name]
	if not marker then
		print("No such prefab marker:", prefab_name)
		return
	end
	EditorWaitViewMapObjectByHandle(marker.handle, marker.map, ged)
end

function GotoPrefabAction(root, obj, prop_id, ged)
	local name = obj[prop_id] or ""
	if name == "" then
		print("No prefab provided")
		return
	end
	ShowPrefabMarker(name, ged)
end

local function GetMarkerSource(prefab_name)
	local marker_props = PrefabMarkers[prefab_name]
	local source = marker_props and marker_props.marker
	if not source then
		local marker_name = PrefabToMarkerName(prefab_name)
		source = Markers[marker_name]
	end
	return source or empty_table
end

function PrefabMarkerEdit:DeleteExports()
	local name = self.ExportedName or ""
	if name == "" or not ExportedPrefabs[name] then
		return
	end
	local marker = GetMarkerSource(name)
	if marker.handle ~= self.handle or marker.map ~= GetMapName() then
		return
	end
	ExportedPrefabs[name] = nil
	SVNDeleteFile{
		GetPrefabFileObjs(name),
		GetPrefabFileType(name),
		GetPrefabFileGrass(name),
		GetPrefabFileHeight(name),
		GetPrefabFileMask(name),
	}
end

function PrefabMarkerEdit:DbgShow(what)
	self.DebugErrorShow = what
end

function PrefabMarkerEdit:GetClassToCountStat()
	local list = {}
	for class,count in pairs(self.ClassToCount or empty_table) do
		list[#list+1] = {class = class, count = count}
	end
	table.sortby_field_descending(list, "count")
	for i, entry in ipairs(list) do
		list[i] = string.format("%s = %d\n", entry.class, entry.count)
	end
	return table.concat(list)
end

function PrefabMarkerEdit:GetCaptureCenter()
	return self:GetVisualPos() + Rotate(self.CaptureSize:SetZ(0), self:GetAngle()) / 2
end

function PrefabMarkerEdit:ExportPrefab()
	self:ForceEditorMode(false)
	local err, param1, param2 = self:DoExport()
	self:ForceEditorMode(true)
	self.ExportError = err
	self:EditorObjectsUpdate()
	self:EditorTextUpdate()
	return err, param1, param2
end

local function save_grid(grid, filename, old_hash, new_hash)
	if old_hash == new_hash and io.exists(filename) then
		return
	end
	if grid then
		local success, err = GridWriteFile(grid, filename, true)
		if err then
			return err
		end
	end
	svn_process(filename, old_hash, new_hash)
end

local function DumpObjDiffs(filename, defs, name, bin, hash, prev_hash)
	print("DumpObjDiffs", name)
	local err, prev_bin = AsyncFileToString(filename, nil, nil, "pstr")
	if err then
		print("-", err)
		return
	end
	if prev_bin == bin then
		print("- same binary!!!")
		return
	end
	local prev_defs = Unserialize(prev_bin)
	assert(prev_defs)
	if not prev_defs then
		return
	end
	print("prev_defs", #prev_defs, "prev_bin", #prev_bin, "prev_hash", prev_hash)
	print(" new_defs", #defs,      " new_bin", #bin,      " new_hash", hash)
	if #prev_defs ~= #defs then
		print("- defs count changed")
		return
	end
	local total = 0
	for i, def in ipairs(defs) do
		local prev_def = prev_defs[i]
		local found
		for j, v in ipairs(def) do
			local prev_v = prev_def[j]
			if prev_v ~= v then
				if found then
					print("- def", i)
				end
				print("- -", j, prev_v, "-->", v)
				total = total + 1
			end
		end
	end
	if total == 0 then
		print("- no diff found!!!")
	end
end

function PrefabMarkerEdit:DoExport(name)
	self.ExportTime = nil
	local start_time = GetPreciseTicks()
	self:DbgShow()
	if not IsFSUnpacked() then
		return "unpacked sources required"
	end
	if self.PrefabType ~= "" and not PrefabTypeToPreset[self.PrefabType] then
		return "no such prefab type"
	end
	if self.PoiType ~= "" then
		local poi_preset = PrefabPoiToPreset[self.PoiType]
		if not poi_preset then
			return "no such POI type"
		end
		local poi_areas = poi_preset.PrefabTypeGroups or empty_table
		if #poi_areas > 0 then
			if self.PoiArea == "" or not table.find(poi_areas, "id", self.PoiArea) then
				return "missing POI area"
			end
		end
	end
	
	name = name or self:GetPrefabName()
	if #name == 0 then
		return "no name"
	end
	local marker_name = PrefabToMarkerName(name)
	local marker = Markers[marker_name]
	if marker and (marker.handle ~= self.handle or marker.map ~= GetMapName()) then
		return "duplicated prefab", marker.map, marker.pos
	end
	
	if self:GetGameFlags(gofPermanent) == 0 then
		return "invalid prefab"
	end
	local old_height_hash = self.HeightHash
	local old_type_hash = self.TypeHash
	local old_grass_hash = self.GrassHash
	local old_mask_hash = self.MaskHash
	
	self:SetAngle(0)
	self:SetInvalidZ()
	local bbox, adjusted = self:CaptureTerrain()
	if not bbox then
		return "capture failed"
	end
	local grass_map = self.GrassMap
	local height_map = self.HeightMap
	local type_map = self.TypeMap
	if type_map then
		local valid_types = GridDest(type_map)
		GridReplace(type_map, valid_types, invalid_type_value, 0)
		GridMask(valid_types, 0, MaxTerrainTextureIdx())
		if not GridEquals(valid_types, 1) then
			self:DbgShow("missing_types")
			return "unknown terrain types detected"
		end
	end
	
	local mask = self.MaskMap
	if (height_map or type_map) and not mask then
		return "Prefab mask unavailable"
	end
	
	self.PlayArea = nil
	self.HeightRougness = nil
	if height_map then
		local height_offset = self.HeightOffset
		local height_map_ex = GridRepack(height_map, "F")
		local mask_ex = mask and GridRepack(mask, "F")
		GridAdd(height_map_ex, height_offset)
		local extrem = GridExtrem(height_map_ex, height_tile, height_scale)
		local mine, maxe = GridMinMax(extrem)
		self.HeightRougness = maxe
		if maxe > height_roughness_err and self.CheckRougness then
			self:DbgShow("roughness")
			return "height map too rough!", maxe, height_roughness_err
		end
		self.PlayArea = PrefabEvalPlayableArea(height_map_ex, mask_ex, type_tile)
		local outline
		if not mask_ex then
			outline = GridDest(height_map_ex, true)
			GridFrame(outline, 1, 1)
		elseif self:GetTransitionDist() == 0 then
			outline = GridDest(mask_ex)
			GridOutline(mask_ex, outline, true)
		end
		if outline then
			GridMulDiv(outline, height_map_ex, 1)
			local minh, maxh = GridMinMax(outline)
			if maxh > height_outline_offset_err then
				self:DbgShow("height_offset")
				return "height offset found at the prefab border", maxh, height_outline_offset_err
			end
		end
	end
	
	self.TotalArea = nil
	self.RadiusMin = nil
	self.RadiusMax = nil
	local total_area
	if mask then
		local bmask = GridDest(mask)
		local mw, mh = mask:size()
		local gcenter = point(mw / 2, mh / 2)
		GridNot(mask, bmask)
		local minx, miny, maxx, maxy = GridMinMaxDist(bmask, gcenter)
		local radius_min = gcenter:Dist2D(minx, miny)
		GridNot(bmask)
		local minx, miny, maxx, maxy = GridMinMaxDist(bmask, gcenter)
		local radius_max = gcenter:Dist2D(maxx, maxy)
		assert(radius_min <= radius_max)
		total_area = GridCount(mask, 0, max_int)
		self.TotalArea = total_area
		self.RadiusMin = radius_min
		self.RadiusMax = radius_max
		if self.CheckRadiusRatio and (2 * radius_min < radius_max) then
			self:DbgShow("radius")
			return "max to min radius ratio is too big", radius_max, radius_min
		end
	end
	
	local new_height_hash = self.HeightHash
	local new_type_hash = self.TypeHash
	local new_grass_hash = self.GrassHash
	local new_mask_hash = self.MaskHash
	
	local IsOptional = CObject.GetOptionalPlacement
	local objs = self:CollectObjs(bbox)
	
	local rmin, rmax, rsum, rcount = max_int, 0, 0, 0
	local efCollision = const.efCollision
	local efVisible = const.efVisible
	local HasAnySurfaces = HasAnySurfaces
	local HasMeshWithCollisionMask = HasMeshWithCollisionMask
	local GetEnumFlags = CObject.GetEnumFlags
	local GetClassEnumFlags = GetClassEnumFlags
	local class_to_count = {}		
	for i=#objs,1,-1 do
		local obj = objs[i]
		assert(GetClassFlags(obj, cfCodeRenderable) == 0)
		local class = obj.class
		local obj_err = obj:GetError()
		if obj_err then
			StoreErrorSource(obj, obj_err)
			return "object with errors"
		end
		if obj.__ancestors.PrefabObj then
			table.remove(objs, i)
		else
			class_to_count[class] = (class_to_count[class] or 0) + 1
			if GetEnumFlags(obj, efCollision) ~= 0 and not HasCollisions(obj) then
				obj:ClearEnumFlags(efCollision)
				print("Removed collision flags for", obj.class, "at", obj:GetPos(), "in", name)
			end
			if self.CheckVisibility then
				if obj:GetEnumFlags(efVisible) == 0 and GetClassEnumFlags(obj, efVisible) ~= 0 then
					StoreErrorSource(obj, "Invisible object")
					return "invisible objects detected"
				elseif obj:GetOpacity() == 0 then
					StoreErrorSource(obj, "Transparent object")
					return "transparent objects detected"
				end
			end
			local r = obj:GetRadius()
			if r > 0 then
				rmin = Min(rmin, r)
				rmax = Max(rmax, r)
				rsum = rsum + r
				rcount = rcount + 1
			end
		end
	end
	self.ObjRadiusMin = rmin
	self.ObjRadiusMax = rmax
	self.ObjRadiusAvg = rcount > 0 and (rsum / rcount) or 0
	self.ClassToCount = next(class_to_count) and class_to_count
	self.HeightMap = height_map
	self.TypeMap = type_map
	self.GrassMap = grass_map
	self.MaskMap = mask
	
	local obj_max_radius = const.RandomMap.PrefabMaxObjRadius or GetEntityMaxSurfacesRadius()
	if self.CheckObjRadius and rmax > obj_max_radius then
		self:DbgShow("large_objs")
		return "too large objects detected", rmax, obj_max_radius
	end
	
	local nObjs2x = 0
	for _,obj in ipairs(objs) do
		if not IsOptional(obj) then
			nObjs2x = nObjs2x + 2
		else
			nObjs2x = nObjs2x + 1
		end
	end
	self.ObjCount = nObjs2x/2
	self.ObjMaxCount = nil
	if total_area then
		local obj_avg_radius = const.RandomMap.PrefabAvgObjRadius
		local max_objs = MulDivRound(total_area, type_tile * type_tile * 7, obj_avg_radius * obj_avg_radius * 22)
		self.ObjMaxCount = max_objs
		if self.CheckObjCount and self.ObjCount > max_objs then
			return "too many objects", self.ObjCount, max_objs
		end
	end
	
	local center = self:GetCaptureCenter()
	local prev_hash = self.ExportedHash
	local prev_name = self.ExportedName or ""
	local prev_rev = self.AssetsRevision
	self.ExportedHash = nil
	self.ExportedName = nil
	self.RequiredMemory = nil
	self.AssetsRevision = nil
	
	local table_find = table.find
	local Collections = Collections
	local GetCollectionIndex = CObject.GetCollectionIndex
	
	local coll_idx_found, optional_objs = {}, {}
	for _, obj in ipairs(objs) do
		local col_idx = GetCollectionIndex(obj)
		if col_idx ~= 0 then
			if not table_find(coll_idx_found, col_idx) then
				coll_idx_found[#coll_idx_found + 1] = col_idx
			end
			if IsOptional(obj) then
				optional_objs[col_idx] = (optional_objs[col_idx] or 0) + 1
			end
		end
	end

	local nested_colls
	local function ProcessCollection(col_idx)
		local col = Collections[col_idx]
		if not col then
			return
		end
		local parent_idx = GetCollectionIndex(col)
		if parent_idx == 0 then
			return
		end
		nested_colls = nested_colls or {}
		local subcolls = nested_colls[parent_idx]
		if not subcolls then
			nested_colls[parent_idx] = { col_idx }
		elseif not table_find(subcolls, col_idx) then
			subcolls[#subcolls + 1] = col_idx
		else
			return
		end
		return ProcessCollection(parent_idx)
	end
	for _, col_idx in ipairs(coll_idx_found) do
		ProcessCollection(col_idx)
	end
	local function GetNestedOptionalObjs(col_idx)
		local count = optional_objs[col_idx] or 0
		for _, sub_col_idx in ipairs(nested_colls and nested_colls[col_idx]) do
			count = count + GetNestedOptionalObjs(sub_col_idx)
		end
		return count
	end
	local nested_opt_objs
	for _, col_idx in ipairs(coll_idx_found) do
		local count = GetNestedOptionalObjs(col_idx)
		if count > 0 then
			nested_opt_objs = nested_opt_objs or {}
			nested_opt_objs[col_idx] = count
		end
	end
	
	self.NestedColls = nested_colls
	self.NestedOptObjs = nested_opt_objs
	
	local class_to_defaults = {}
	local prop_eval = prop_eval
	local GetClassValue = GetClassValue
	local GetDefRandomMapFlags = GetDefRandomMapFlags
	local ListPrefabObjProps = ListPrefabObjProps
	
	local ignore_props = {
		CollectionIndex = true,
		Pos = true, Axis = true, Angle = true,
		ColorModifier = true, Scale = true,
		Entity = true, Mirrored = true,
	}
	for _, info in ipairs(RandomMapFlags) do
		ignore_props[info.id] = true
	end
	
	local defs = {}
	local base_prop_count = const.RandomMap.PrefabBasePropCount
	for i, obj in ipairs(objs) do
		local class = obj.class
		local props = obj:GetProperties()
		local default_props = class_to_defaults[class]
		if not default_props then
			default_props = {}
			class_to_defaults[class] = default_props
			local get_default = obj.GetDefaultPropertyValue
			for _, prop in ipairs(props) do
				local id = prop.id
				if not ignore_props[id] and not prop_eval(prop.dont_save, obj, prop) and prop_eval(prop.editor, obj, prop) then
					default_props[id] = get_default(obj, id, prop)
				end
			end
		end

		local def_rmf = GetDefRandomMapFlags(obj)
		local def_entity = GetClassValue(obj, "entity") or class
		
		local dpos, angle, daxis, coll_idx,
			scale, color, entity, mirror, fade_dist,
			rmf_flags, ground_offset, normal_offset = ListPrefabObjProps(obj, center, def_rmf, def_entity, obj.prefab_no_fade_clamp)
		
		local def = {
			class, dpos, angle, daxis, scale, rmf_flags, fade_dist,
			ground_offset, normal_offset, coll_idx, color, mirror
		}
		local count = #def
		assert(count == base_prop_count)
		local prop_get = obj.GetProperty
		for _, prop in ipairs(props) do
			local id = prop.id
			local default_value = default_props[id]
			if default_value ~= nil then
				local value = prop_get(obj, id)
				if value ~= nil and value ~= default_value then
					assert(value == "" or not IsT(value) and not ObjectClass(value))
					count = count + 2
					def[count - 1] = id
					def[count] = value
				end
			end
		end
		while not def[count] do
			def[count] = nil
			count = count - 1
		end
		defs[i] = def
	end
	local bin, err = SerializePstr(defs)
	if not bin then
		return err
	end
	if FindSerializeError(bin, defs) then
		return "Objects serialization mismatch"
	end

	local new_hash = xxhash(bin)
	local filename = GetPrefabFileObjs(name)
	if prev_hash ~= new_hash or not io.exists(filename) then
		--DumpObjDiffs(filename, defs, name, bin, new_hash, prev_hash)
		local err = AsyncStringToFile(filename, bin)
		if err then
			return "Failed to save prefab", filename, err
		end
		svn_process(filename, prev_hash, new_hash)
	end
	
	local filename_height = GetPrefabFileHeight(name)
	local err = save_grid(height_map, filename_height, old_height_hash, new_height_hash)
	if err then
		return "Failed to save grid", filename_height, err
	end
	
	local filename_type = GetPrefabFileType(name)
	local err = save_grid(type_map, filename_type, old_type_hash, new_type_hash)
	if err then
		return "Failed to save grid", filename_type, err
	end
	
	local filename_grass = GetPrefabFileGrass(name)
	local err = save_grid(grass_map, filename_grass, old_grass_hash, new_grass_hash)
	if err then
		return "Failed to save grid", filename_grass, err
	end
	
	local filename_mask = GetPrefabFileMask(name)
	local err = save_grid(mask, filename_mask, old_mask_hash, new_mask_hash)
	if err then
		return "Failed to save grid", filename_mask, err
	end
	
	ExportedPrefabs[name] = true
	if prev_name ~= name then
		self:DeleteExports()
	end
	self.ExportedName = name
	self.ExportedHash = new_hash
	self.AssetsRevision = prev_name == name and prev_rev or AssetsRevision
	self.ExportTime = GetPreciseTicks() - start_time
	return nil, objs, defs
end

function PrefabMarkerEdit:ActionViewSource(root)
	if self.source then
		ViewMarker(root, self.source)
	end
end

function PrefabMarkerEdit:GetRevisionInfo()
	if ExportedPrefabs[self.ExportedName] then return end
	return SVNLocalRevInfo(GetPrefabFileObjs(self.ExportedName))
end

local function GetPrefabVersion(map_name)
	map_name = map_name or GetMapName()
	if string.find_lower(map_name, "gameplay") then
		return 0
	end
	local version_str = map_name and string.match(map_name, "_[Vv](%d+)$")
	return version_str and tonumber(version_str) or 1
end

function PrefabMarker:CreateMarker()
	assert(self:GetGameFlags(gofPermanent) ~= 0)
	local err, param1, param2 = self:ExportPrefab()
	if err then
		StoreErrorSource("silent", self, "Failed to export", self:GetPrefabName(), ":", err, param1, param2)
		return false, err
	end
	local map_name = GetMapName()
	local version = GetPrefabVersion(map_name)
	local props = { "name", name = self.MarkerName, }
	local get_prop = self.GetProperty
	local get_default = self.GetDefaultPropertyValue
	for _, prop in ipairs(self:GetProperties()) do
		local export_id = prop.export
		if export_id then
			local prop_id = prop.id
			local value = get_prop(self, prop_id)
			if value ~= get_default(self, prop_id, prop) then
				props[export_id] = value
				props[#props + 1] = export_id
			end
		end
	end
	if mapdata.LockMarkerChanges then
		local err = self:CheckCompatibility(props)
		if err then
			StoreErrorSource("silent", self, "Prefab", self:GetPrefabName(), "compatibility error:", err)
			return false, err
		end
		return
	end
	local data_concat = {"return {"}
	local tmp_concat = {"", "=", "", ","}
	for _, id in ipairs(props) do
		tmp_concat[1] = id
		tmp_concat[3] = ValueToLuaCode(props[id], ' ')
		data_concat[#data_concat + 1] = table.concat(tmp_concat)
	end
	data_concat[#data_concat + 1] = "}"
	local data_str = table.concat(data_concat)
	local marker = PlaceObject('Marker', {
		name = PrefabToMarkerName(self.ExportedName),
		type = "Prefab",
		handle = self.handle,
		pos = self:GetPos(),
		map = map_name,
		data = data_str,
		data_version = PrefabMarkerVersion,
	})
	self.source = {
		handle = self.handle,
		map = map_name,
	}
	return marker
end

function PrefabMarkerEdit:CheckCompatibility(new_props)
	local marker_name = PrefabToMarkerName(self.ExportedName)
	local marker = Markers[marker_name]
	if not marker then
		return "Missing marker"
	end
	local data = marker.type == "Prefab" and marker.data 
	local props = data and dostring(data)
	if not props then
		return "Unserialize props error"
	end
	local max_pct_err = 5
	local to_check = {}
	for _, prop in ipairs(self:GetProperties()) do
		local export_id = prop.export
		if export_id and prop.compatibility then
			to_check[#to_check + 1] = export_id
		end
	end
	for _, prop in ipairs(to_check) do
		local value = props[prop]
		local new_value = new_props[prop]
		if new_value ~= value then
			local ptype = type(new_value)
			if ptype ~= type(value) then
				return "Changed type of prop " .. prop
			end
			if ptype == "number" then
				if abs(new_value - value) > MulDivRound(value, max_pct_err, 100) then
					return "Too big difference in value of prop " .. prop
				end
			elseif IsPoint(value) then
				if new_value:Dist(value) > MulDivRound(value:Len(), max_pct_err, 100) then
					return "Too big difference in value of prop " .. prop
				end
			elseif not compare(value, new_value) then
				return "Changed value of prop " .. prop
			end
		end
	end
end

----

function OnMsg.PreSaveMap()
	local prefabs = MapCount("map", "PrefabMarker", nil, nil, gofPermanent)
	if mapdata.IsPrefabMap then
		if prefabs == 0 then
			mapdata.IsPrefabMap = false
			print("This map is no more a prefab map.")
		else
			MapClearGameFlags(gofPermanent, "map", "PropertyHelper", "CameraObj")
		end
	else
		if prefabs ~= 0 then
			mapdata.IsPrefabMap = true
			print("This map is now declared as a prefab map.")
		end
	end
	if mapdata.IsPrefabMap then
		SaveTerrainWaterObjArea()
		MapForEach("map", "PrefabMarker", function(prefab)
			prefab:EditorObjectsShow(false)
		end)
	end
end

function OnMsg.PostSaveMap()
	if mapdata.IsPrefabMap then
		MapForEach("map", "PrefabMarker", function(prefab)
			prefab:EditorObjectsShow()
		end)
	end
end

----

AppendClass.PrefabMarker = {
	__parents = { "PrefabMarkerEdit" },
	editor_text_depth_test = false,
}

function PrefabMarker:EditorGetText(line_separator)
	local name = self:GetPrefabName()
	line_separator = line_separator or "\n"
	if self.ExportError ~= "" then
		name = name .. line_separator .. "Error: " .. self.ExportError
	elseif self.PoiType ~= "" then
		name = name .. line_separator .. self.PoiType
		if self.PoiArea ~= "" then
			name = name .. "." .. self.PoiArea
		end
	end
	return name
end

function PrefabMarker:EditorGetTextColor()
	if self.ExportError ~= "" then
		return red
	end
	local poi_preset = self.PoiType ~= "" and PrefabPoiToPreset[self.PoiType]
	if poi_preset then
		return poi_preset.OverlayColor or RandColor(xxhash(self.PoiType))
	end
	return EditorTextObject.EditorGetTextColor(self)
end

----

function ResaveAllPrefabs(version)
	if IsValidThread(l_ResaveAllMapsThread) then
		return
	end
	l_ResaveAllMapsThread = CreateRealTimeThread(function()
		local start_time = GetPreciseTicks()
		if not version then
			local err, files = AsyncListFiles("Prefabs", "*")
			if #files > 0 then
				print("Deleting all prefabs...")
				for i=1,#files do
					local success, err = os.remove(files[i])
					if err then
						print("Error", err, "deleting prefab file", files[i])
					end
				end
			end
			ExportedPrefabs = {}
		end
		print("Resaving maps...")
		local prefab_maps = {}
		for map, data in pairs(MapData) do
			if data.IsPrefabMap then
				prefab_maps[map] = true
			end
		end
		for i = 1,#Markers do
			local marker = Markers[i]
			if marker.type == "Prefab" and MapData[marker.map] then
				prefab_maps[marker.map] = true
			end
		end

		if version then
			for map in pairs(prefab_maps) do
				if version ~= GetPrefabVersion(map) then
					prefab_maps[map] = nil
				end
			end
		end
		prefab_maps = table.keys(prefab_maps, true)

		LoadingScreenOpen("idLoadingScreen", "ResaveAllPrefabs")
		EditorActivate()
		ForEachMap(prefab_maps, function() 
			print("Resaving map ", GetMap())
			SaveMap("no backup")
		end)
		LoadingScreenClose("idLoadingScreen", "ResaveAllPrefabs")
		
		l_ResaveAllMapsThread = false
		PrefabUpdateMarkers()
		
		print("Resaving all prefabs complete in", DivRound(GetPreciseTicks() - start_time, 1000), "sec")
	end)
end

function ResaveAllGameMaps(filter)
	if IsValidThread(l_ResaveAllMapsThread) then
		return
	end
	l_ResaveAllMapsThread = CreateRealTimeThread(function()
		local start_time = GetPreciseTicks()
		print("Resaving maps...")
		local maps = GetAllGameMaps()
		EditorActivate()
		for _, map in ipairs(maps) do
			local data = MapData[map]
			if not filter or filter(map, data) then
				local logic
				if not config.ResaveAllGameMapsKeepsGameLogic then
					logic = data.GameLogic
					data.GameLogic = false -- avoid starting game stuff that could spawn objects / modify the map
				end
				print("Resaving map ", map)
				ChangeMap(map)
				if not config.ResaveAllGameMapsKeepsGameLogic then
					data.GameLogic = logic
				else
					Msg("GameEnterEditor")
				end
				if not filter or filter(map, data, "loaded check") then
					SaveMap("no backup")
				end
			end
		end
		
		l_ResaveAllMapsThread = false
		print("Resaving", #maps, "maps complete in", DivRound(GetPreciseTicks() - start_time, 1000), "sec")
	end)
end

function RegenerateMap(map, reload_on_finish)
	map = map or GetMapName() or ""
	map = GetOrigMapName(map)
	if map == "" then
		return
	end
	if not IsValidThread(l_ResaveAllMapsThread) then
		l_ResaveAllMapsThread = CreateRealTimeThread(RegenerateMap, map, reload_on_finish)
		return
	elseif l_ResaveAllMapsThread ~= CurrentThread() then
		return
	end
	local data = MapData[map]
	if not data or not data.IsRandomMap then
		print("Not a random map")
		return
	end
	local active = IsEditorActive()
	if not active then
		EditorActivate()
	end
	print("Regenerating map", map, "...")
	local logic = data.GameLogic
	if logic then
		data.GameLogic = false -- avoid starting game stuff that could spawn objects / modify the map
		local st = GetPreciseTicks()
		ChangeMap(map)
		printf("Map reloaded without game logic in %.3f s", (GetPreciseTicks() - st) * 0.001)
		Sleep(1)
	end
	SetGameSpeed("pause")
	assert(mapdata == data)
	assert(not data.GameLogic)
	local st = GetPreciseTicks()
	Presets.MapGen.Default.BiomeCreator:Run()
	printf("Map gen finished in %.3f s", (GetPreciseTicks() - st) * 0.001)
	Sleep(1)
	data.GameLogic = logic
	SaveMap("no backup")
	Sleep(1)
	if not active then
		EditorDeactivate()
	end
	if logic and reload_on_finish then
		local st = GetPreciseTicks()
		ChangeMap(map)
		printf("Map reloaded with game logic in %.3f s", (GetPreciseTicks() - st) * 0.001)
		Sleep(1)
	end
end

function GetRandomMaps(filter, ...)
	local maps = {}
	for id, map_data in pairs(MapData) do 
		if map_data.IsRandomMap and GameMapFilter(id, map_data) and (not filter or filter(id, map_data, ...)) then
			maps[#maps + 1] = id
		end
	end
	table.sort(maps)
	return maps
end

function TimeToHHMMSS(ms)
	local sec = DivRound(ms, 1000)
	local hours = sec / (60 * 60)
	sec = sec - hours * (60 * 60)
	local mins = sec / 60
	sec = sec - mins * 60
	return string.format("%02d:%02d:%02d", hours, mins, sec)
end

function RegenerateRandomMaps(maps)
	if IsValidThread(l_ResaveAllMapsThread) then
		return
	end
	l_ResaveAllMapsThread = CreateRealTimeThread(function()
		local start_time = GetPreciseTicks()
		local old_ignoreerrors = IgnoreDebugErrors(true)
		print("Regenerating maps...")
		maps = maps or GetRandomMaps()
		local active = IsEditorActive()
		if not active then
			EditorActivate()
		end
		for i, map in ipairs(maps) do
			printf("Regenerating map %d / %d...", i, #maps)
			local success, err = sprocall(RegenerateMap, map)
			if not success then
				print("<color 255 0 0>Critical error for</color>", map, err)
			end
		end
		print("Regenerating", #maps, "maps complete in", TimeToHHMMSS(GetPreciseTicks() - start_time))
		
		if not active then
			EditorDeactivate()
		end
		ChangeMap("")
		IgnoreDebugErrors(old_ignoreerrors)
		l_ResaveAllMapsThread = false
	end)
end

function GetRegenerateMapLists()
	return GatherMsgItems("GatherRegenerateMapLists")
end

function RegenerateMapList(list_name)
	local maps = GetRegenerateMapLists()[list_name]
	if maps then
		RegenerateRandomMaps(maps)
	end
end

local function GetFilesHashes(path)
	local hashes = { }
	for _, file in ipairs(io.listfiles(path)) do
		local err, hash = AsyncFileToString(file, nil, nil, "hash")
		if err then
			GameTestsError("Failed to open " .. file .. " for " .. map .. " due to err: " .. err)
			return
		end
		hashes[file] = hash
	end
	return hashes
end

TestNightlyPrefabMethods = {}
function TestNightlyPrefabMethods.TestDoesPrefabMapSavingGenerateFakeDeltas(map, result)
	SaveMap("no backup")
	local path = "svnAssets/Source/Maps/" .. map .. "/"
	local hashes_before = GetFilesHashes(path)
	SaveMap("no backup")
	local hashes_after = GetFilesHashes(path)
	for file, hash in pairs(hashes_before or empty_table) do
		if hash ~= hashes_after[file] then
			result["fake deltas"] = result["fake deltas"] or {
				err = "Resaving prefab maps produced differences!",
				texts = {}
			}
			table.insert(result["fake deltas"].texts, map .. ": difference in " .. file)
		end
	end
end

function GameTestsNightly.TestPrefabMaps()
	WaitSaveGameDone()
	StopAutosaveThread()
	table.change(config, "TestPrefabMaps", {
		AutosaveSuspended = true,
	})
	local thread = CreateRealTimeThread(function()
		WaitDataLoaded()
		if not IsEditorActive() then
			EditorActivate()
		end
		local test_times = { }
		local result = { }
		for map, data in sorted_pairs(MapData) do
			if data.IsPrefabMap then
				assert(not data.GameLogic)
				GameTestsPrint("Testing map", map)
				ChangeMap(map)
				if GetMapName() ~= map then
					GameTestsError("Failed to change map to " .. map .. "! ")
					return
				end
				for method_name, method in sorted_pairs(TestNightlyPrefabMethods) do
					local start = GetPreciseTicks()
					method(map, result)
					test_times[method_name] = (test_times[method_name] or 0) + (GetPreciseTicks() - start)
				end
			end
		end
		if IsEditorActive() then
			EditorDeactivate()
		end
		for _, res in sorted_pairs(result) do
			GameTestsError(res.err)
			for _, text in ipairs(res.texts) do
				GameTestsPrint(text)
			end
		end
		for method_name, time in sorted_pairs(test_times) do
			GameTestsPrint(method_name, "took", time, "ms")
		end
		Msg(CurrentThread())
	end)
	while IsValidThread(thread) do
		WaitMsg(thread, 1000)
	end
	table.restore(config, "TestPrefabMaps")
end

