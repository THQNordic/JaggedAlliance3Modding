local unit_weight = 4096
local type_tile = const.TypeTileSize
local height_max = const.MaxTerrainHeight
local height_scale = const.TerrainHeightScale
local empty_table = empty_table
local gofPermanent = const.gofPermanent
local gofGenerated = const.gofGenerated
local maxh = height_max - 10*guim
local minh = 10*guim
local gmodes = {"Height", "Type", "Grass", "Objects", "POI"}
local smodes = {"Prefab", "POI"}
local pmodes = {"Marks", "Overlap", "Cover"}
local omodes = {"Marks", "Overlap", "Cover", "Types"}
local imodes = {"Rollover", "Pos", "POI"}
local def_gm = set(table.unpack(gmodes))
local def_pn = set("Marks")
local b_dprint = CreatePrint{ "RM", format = print_format, output = DebugPrint }
local b_print = Platform.developer and CreatePrint{ "RM", format = print_format, color = yellow} or b_dprint
local pct_mul = 100
local pct_100 = 100*pct_mul
local function to_pct(mul, div)
	return div == 0 and 0 or MulDivRound(100 * pct_mul, mul, div)
end
local def_bd = "BiomeDistort"
DbgShowPrefab = empty_func

----

DefineClass.BiomeFiller = {
	__parents = { "GridOpInput", "DebugOverlayControl" },
	properties = {
		{ category = "General",    id = "SlopeGrid",     name = "Slope Grid",           editor = "choice",      default = "",     items = function(self) return GridOpOutputNames(self) end, grid_input = true, optional = true, help = "Required by POI logic." },
		{ category = "General",    id = "MinHeight",     name = "Min Height (m)",       editor = "number",      default = minh,   min = 0, max = height_max, scale = guim, help = "Prefabs below that limit will be smart clamped." },
		{ category = "General",    id = "MaxHeight",     name = "Max Height (m)",       editor = "number",      default = maxh,   min = 0, max = height_max, scale = guim, help = "Prefabs above that limit will be smart clamped." },
		{ category = "General",    id = "LoadPrefabLoc", name = "Load Prefab Loc",      editor = "bool",        default = false,  help = "Load any previously saved prefab locations found in the map." },
		{ category = "General",    id = "SavePrefabLoc", name = "Save Prefab Loc",      editor = "bool",        default = false,  help = "Save any prefab locations with persistable tags." },
		{ category = "General",    id = "UseMeshOverlap",name = "Use Mesh Overlap",     editor = "bool",        default = true,   log = true, help = "Detect prefab overlapping objects by analysing their collision mesh instead only their origin"},
		{ category = "General",    id = "OptionalChance",name = "Optional Chance (%)",  editor = "number",      default = 50,     slider = true, min = 0, max = 100, log = true, help = "Chance for optional objects to be placed" },
		{ category = "General",    id = "SteepSlope",    name = "Steep Slope",          editor = "number",      default = 30 * 60,slider = true, min = 0, max = 90*60, log = true, scale = "deg", help = "Slope threshold to start deleting objects marked to be removed on steep slopes" },
		
		{ category = "Debug",      id = "GenMode",       name = "Gen Mode",             editor = "set",         default = def_gm, items = gmodes, },
		{ category = "Debug",      id = "RemFadedObjs",  name = "Rem Faded Objs",       editor = "bool",        default = true,   log = true, help = "Remove border objects that wont be seen from the playable zone as they are always faded away"},
		{ category = "Debug",      id = "StepMode",      name = "Step Mode",            editor = "set",         default = set(),  items = smodes },
		{ category = "Debug",      id = "StepTime",      name = "Step Time (ms)",       editor = "number",      default = 300,    help = "Delay in each step during Step debug mode. Set to -1 to trigger a pause.", buttons = {{name = "Toggle Pause", func = "ActionTogglePause"}, {name = "Interrupt", func = "ActionInterrupt"}} },
		{ category = "Debug",      id = "Overlay",       name = "Overlay Mode",         editor = "set",         default = set(),  update_dbg = true, items = omodes, max_items_in_set = 1},
		{ category = "Debug",      id = "OverlayAlpha",  name = "Overlay Alpha (%)",    editor = "number",      default = 30,     slider = true, min = 0, max = 100, dont_save = true },
		{ category = "Debug",      id = "OverlayEdges",  name = "Overlay Edges",        editor = "bool",        default = true,   dont_save = true, update_dbg = true, },
		{ category = "Debug",      id = "InspectMode",   name = "Inspect Mode",         editor = "set",         default = set(),  dont_save = true, update_dbg = true, items = imodes, max_items_in_set = 1},
		{ category = "Debug",      id = "InspectFilter", name = "Inspect Filter",       editor = "set",         default = set(),  dont_save = true, update_dbg = true, items = function() return PrefabTagsCombo() end, help = "Show only prefabs with the selected tags" },
		{ category = "Debug",      id = "InspectPattern",name = "Inspect Prefab",       editor = "text",        default = "",     dont_save = true, update_dbg = true, buttons = {{name = "View", func = "ViewInspectedPrefab"}}, help = "Show only prefabs with names matching this pattern" },
		
		{ category = "Debug",      id = "SelectedPrefab",name = "Selected Prefab",      editor = "text",        default = "",     dont_save = true, buttons = {{name = "Goto", func = "GotoPrefabAction"}} },
		{ category = "Debug",      id = "SelectedPoi",   name = "Selected Info",        editor = "text",        default = "",     dont_save = true},
		{ category = "Debug",      id = "SelectedTags",  name = "Selected Tags",        editor = "text",        default = "",     dont_save = true},
		{ category = "Debug",      id = "SelectedMark",  name = "Selected Mark",        editor = "number",      default = 0,      dont_save = true},
		{ category = "Debug",      id = "SelectedBreak", name = "Selected Break",       editor = "bool",        default = false,  dont_save = true},
		
		{ category = "Results",    id = "PreviewSet",    name = "Preview Name",         editor = "set",         default = def_pn, items = pmodes, object_update = true, max_items_in_set = 1 },
		{ category = "Results",    id = "GridPreview",   name = "Preview Grid",         editor = "grid",        default = false,  min = 128, max = 512, frame = 1, color = true, invalid_value = 0 },
		{ category = "Results",    id = "MarkGrid",      name = "Prefab Marks",         editor = "grid",        default = false,  no_edit = true },
		{ category = "Results",    id = "OverlapGrid",   name = "Prefab Overlap",       editor = "grid",        default = false,  no_edit = true },
		{ category = "Results",    id = "CoverGrid",     name = "Area Cover",           editor = "grid",        default = false,  no_edit = true },
		{ category = "Results",    id = "PTypeGrid",     name = "PType Marks",          editor = "grid",        default = false,  no_edit = true },
		{ category = "Results",    id = "PrefabCount",   name = "Prefab Count",         editor = "number",      default = 0,      log = true},
		{ category = "Results",    id = "PrefabVisible", name = "Prefab Visible (%)",   editor = "number",      default = 0,      scale = pct_mul, log = true },
		{ category = "Results",    id = "OverlapMax",    name = "Max Overlap Prefabs",  editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "OverlapPct",    name = "Area Overlap (%)",     editor = "number",      default = 0,      scale = pct_mul, log = true },
		{ category = "Results",    id = "AreaUncovered", name = "Area Uncovered (%)",   editor = "number",      default = 0,      scale = pct_mul, log = true },
		{ category = "Results",    id = "AreaSpill",     name = "Area Spill (%)",       editor = "number",      default = 0,      scale = pct_mul, log = true },
		{ category = "Results",    id = "ObjectCount",   name = "Object Count",         editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "RemObjects",    name = "Removed Objects",      editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "RemColls",      name = "Removed Collections",  editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "PlacedColls",   name = "Placed Collections",   editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "RasterMem",     name = "Raster Mem (MB)",      editor = "number",      default = 0,      scale = 1024*1024 },
		{ category = "Results",    id = "MixHash",       name = "Prefab Types Hash",    editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "PrefabHash",    name = "Prefab Placed Hash",   editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "MarkHash",      name = "Marks Hash",           editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "FirstRand",     name = "First Rand",           editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "LastRand",      name = "Last Rand",            editor = "number",      default = 0,      log = true },
		{ category = "Results",    id = "LocateTime",    name = "Locate Time",          editor = "number",      default = 0,      scale = "sec" },
		{ category = "Results",    id = "PoiTime",       name = "Locate POI Time",      editor = "number",      default = 0,      scale = "sec" },
		{ category = "Results",    id = "RasterizeTime", name = "Rasterize Time",       editor = "number",      default = 0,      scale = "sec" },
		{ category = "Results",    id = "ObjectTime",    name = "Object Time",          editor = "number",      default = 0,      scale = "sec" },
		{ category = "Results",    id = "GenStep",       name = "Generate Step",        editor = "number",      default = 0,      scale = "m" },
		
		{ category = "Results",    id = "PlacedPrefabs", name = "Placed Prefabs",       editor = "text",        default = false,  lines = 10, text_style = "GedConsole",             buttons = {{name = "Sort", func = "ActionSortPrefabs"}} },
		{ category = "Results",    id = "PrefabTypes",   name = "Prefab Types",         editor = "text",        default = false,  lines = 10, text_style = "GedConsole", log = true, buttons = {{name = "Sort", func = "ActionSortPrefabTypes"}} },
		{ category = "Results",    id = "VisiblePrefabs",name = "Prefab Visibility",    editor = "text",        default = false,  lines = 10, text_style = "GedConsole", log = true, buttons = {{name = "Sort", func = "ActionSortVisible"}} },
		{ category = "Results",    id = "PlacedObjects", name = "Placed Objects",       editor = "text",        default = false,  lines = 10, text_style = "GedConsole", log = true, buttons = {{name = "Sort", func = "ActionSortObjects"}} },
		{ category = "Results",    id = "PlacedPOI",     name = "Placed POI",           editor = "text",        default = false,  lines = 10, text_style = "GedConsole", log = true, buttons = {{name = "Sort", func = "ActionSortPoi"}} },
		{ category = "Results",    id = "PrefabList",                                   editor = "prop_table",  default = false,  no_edit = true },
	},
	gen_thread = false,
	gen_handles = false,
	
	DbgInit = empty_func,
	DbgDone = empty_func,
	DbgUpdate = empty_func,
	DbgOnModified = empty_func,
	
	GridOpType = "Map Biome Fill",
	recalc_on_change = false,
}
	
do
	for i, prop in ipairs(BiomeFiller.properties) do
		if prop.category == "Results" and not prop.items then
			prop.dont_save = true
			prop.read_only = true
		end
	end
end

function BiomeFiller:GetGridModes()
	return {
		Marks = self.MarkGrid,
		Overlap = self.OverlapGrid,
		Cover = self.CoverGrid,
		Types = self.PTypeGrid,
	}
end

function BiomeFiller:CollectTags(tags)
	tags.Terrain = true
	tags.Objects = true
	tags.Pause = true
	return GridOp.CollectTags(self, tags)
end

function BiomeFiller:SetGridInput(state, grid)
	if not next(GetPrefabTypeList()) then
		state.proc:AddLog(self:GetFullName() .. ": No prefab types found!", state)
		return
	end
	
	PauseInfiniteLoopDetection("BiomeFiller.Generate")
	SuspendPassEdits("BiomeFiller.Generate")
	SuspendObjModified("BiomeFiller.Generate")

	-- allow gen proc restarting (via Ged)
	local map_thread = CurrentThread()
	local gen_thread = CreateRealTimeThread(function()
		self:Generate(state, grid)
		Wakeup(map_thread)
	end)
	self.gen_thread = gen_thread
	while self.gen_thread == gen_thread and IsValidThread(gen_thread) and not WaitWakeup(100) do
		-- wait for the gen thread to finish
	end
	if self.gen_thread ~= gen_thread then
		return
	end
	
	ResumeObjModified("BiomeFiller.Generate")
	ResumePassEdits("BiomeFiller.Generate")
	ResumeInfiniteLoopDetection("BiomeFiller.Generate")
end

function BiomeFiller:Generate(state, ptype_grid)
	local gen_thread = CurrentThread()
	if gen_thread ~= self.gen_thread then
		return
	end
	
	self:DbgInit()
	
	state = state or empty_table
	local debug = state.run_mode ~= "GM" and (Platform.editor or Platform.developer)
	local dump = state.dump
	local gen_mode = self.GenMode
	local step
	local step_prefab, step_poi
	local prefab_stats, prefab_stat_count
	local AddPrefabStat = empty_func
	local Min, Max = Min, Max
	local irOutside = const.irOutside
	local group_dist_pct = const.RandomMap.PrefabGroupSimilarDistPct
	local map_divs = const.RandomMap.PrefabRasterParallelDiv
	local group_attract = const.RandomMap.PrefabGroupSimilarWeight
	local max_map_size = const.RandomMap.PrefabMaxMapSize
	local raster_cache_memory = const.RandomMap.PrefabRasterCacheMemory
	local table_append = table.append
	local table_get = table.get
	local ipairs, pairs = ipairs, pairs
	local BraidRandom = BraidRandom
	local LerpRandRange = LerpRandRange
	local unpack = table.unpack
	local table_keys = table.keys
	local MulDivRound = MulDivRound
	local GetHeight = terrain.GetHeight
	local GetSlopeOrientation = terrain.GetSlopeOrientation
	local IsPointInBounds = terrain.IsPointInBounds

	local start_seed = state.rand or AsyncRand()
	local rand_seed = BraidRandom(start_seed)
	
	local g_print = b_print
	if dump then
		g_print = function(...)
			dump(print_format("\n--", ...))
			return b_print(...)
		end
	end
	
	if debug then
		if next(self.StepMode or empty_table) then
			if self.StepMode.Prefab then
				step_prefab = true
				map_divs = 1
			end
			if self.StepMode.POI then
				step_poi = true
			end
			step = function(fmt, ...)
				if self.dbg_interrupt then
					return
				end
				if fmt then
					printf(fmt, ...)
				end
				self:DbgOnModified()
				if self.StepTime < 0 then
					self.dbg_paused = true
				else
					Sleep(self.StepTime)
				end
				if self.dbg_paused then
					print("Pause")
					while self.dbg_paused do
						WaitMsg(self)
					end
					print("Resume")
				end
				if gen_thread ~= self.gen_thread then
					Halt()
				end
			end
		end
		prefab_stats, prefab_stat_count = {}, {}
		AddPrefabStat = function(prefab, name, value)
			local stat = prefab_stats[prefab] or {}
			local count = prefab_stat_count[prefab] or {}
			stat[name] = (stat[name] or 0) + (value or 1)
			count[name] = (count[name] or 0) + 1
			prefab_stats[prefab] = stat
			prefab_stat_count[prefab] = count
		end
	end
	
	local mw, mh = terrain.GetMapSize()
	assert(mw == mh)
	if mw > max_map_size then
		g_print("map larger than", max_map_size)
		return
	end
	local gw, gh = ptype_grid:size()
	if gw ~= gh or mw / gw == 0 or mw % gw ~= 0 or (mw / gw) % type_tile ~= 0 then
		return "Invalid mix grid size!"
	end
	local work_step = mw / gw
	local work_ratio = work_step / type_tile
	self.GenStep = work_step
	
	local function new_grid(packing)
		return NewComputeGrid(gw, gh, "u", packing or 16)
	end
	local function free_grid(grid)
		if grid then grid:free() end
	end
	
	local function rand_init(name, ...)
		rand_seed = xxhash(start_seed, name, ...)
		if dump then
			dump("\n*** INITRAND %d %s", rand_seed, name)
		end
		return rand_seed
	end
	local function trand(tbl, calc_weight)
		rand_seed = BraidRandom(rand_seed)
		return table.weighted_rand(tbl, calc_weight, rand_seed)
	end
	local function crand(chance, max_chance)
		rand_seed = BraidRandom(rand_seed)
		return LerpRandRange(rand_seed, max_chance or 100) < chance
	end
	local function rand(min, max)
		rand_seed = BraidRandom(rand_seed)
		return min and LerpRandRange(rand_seed, min, max) or rand_seed
	end
	
	local prefab_markers = PrefabMarkers
	local exported_prefabs = ExportedPrefabs
	local ptype_to_preset = PrefabTypeToPreset
	local prefab_list = {}
	
	local add_idx = 0
	local prefabs_count = {}
	local bx_changes, levels_count, placed_marks
	local height_out_of_lims
	local mark_grid, ptype_grid_res, overlap_grid
	local locate_time, poi_time, raster_time = 0, 0, 0
	local prefab_tag_loc, prefabs_to_persist = {}, {}
	local point_pack, point_unpack = point_pack, point_unpack
	
	local function FindAndRasterPrefabs()
		rand_init("FindAndRasterPrefabs")
		local ptype_to_prefabs = PrefabTypeToPrefabs
		local poi_type_to_preset = PrefabPoiToPreset
		local idx_to_ptype = GetPrefabTypeList()
		local ptypes_found, ptype_to_tags, ptype_to_area, ptype_to_idx = {}, {}, {}, {}
		for idx, area in pairs(GridLevels(ptype_grid)) do
			local ptype = idx_to_ptype[idx]
			assert(ptype)
			if ptype then
				ptypes_found[#ptypes_found + 1] = ptype
				ptype_to_area[ptype] = area
				ptype_to_idx[ptype] = idx
				local tags = ptype_to_preset[ptype].Tags
				if next(tags) then
					ptype_to_tags[ptype] = tags
				end
			end
		end
		local ptype_cmp = PrefabType.Compare
		table.sort(ptypes_found, function(a, b)
			local pa, pb = ptype_to_preset[a], ptype_to_preset[b]
			return ptype_cmp(pa, pb)
		end)
		
		mark_grid = new_grid()
		ptype_grid_res = new_grid()
		local cover_grid
		if debug then
			overlap_grid = new_grid()
			cover_grid = new_grid()
			self.MarkGrid = mark_grid
			self.OverlapGrid = overlap_grid
			self.CoverGrid = cover_grid
			self.PTypeGrid = ptype_grid_res
		end
		
		local prefab_tags, prefab_to_persist_tags = {}, {}
		local persistable_tags = GetPrefabTagsPersistable()
		for _, prefab in ipairs(prefab_markers) do
			local poi_tags = table_get(poi_type_to_preset, prefab.poi_type, "Tags")
			local ptype_tags = ptype_to_tags[prefab.type]
			local marker_tags = prefab.tags
			if next(ptype_tags) or next(marker_tags) or next(poi_tags) then
				local tags = {}
				table_append(tags, ptype_tags)
				table_append(tags, marker_tags)
				table_append(tags, poi_tags)
				tags = table_keys(tags, true)
				local persist_tags
				for _, tag in ipairs(tags) do
					if persistable_tags[tag] then
						persist_tags = table.create_add(persist_tags, tag)
					end
				end
				prefab_to_persist_tags[prefab] = persist_tags
				prefab_tags[prefab] = tags
			end
		end
		local persisted_prefabs, persisted_tag_count
		if self.LoadPrefabLoc then
			for _, entry in ipairs(mapdata.PersistedPrefabs) do
				local name = entry[1]
				local prefab = prefab_markers[name]
				local persist_tags = prefab and prefab_to_persist_tags[prefab]
				if not persist_tags then
					g_print("Non persistable prefab loaded:", name)
				else
					persisted_prefabs = table.create_add(persisted_prefabs, entry)
					persisted_tag_count = persisted_tag_count or {}
					for _, tag in pairs(persist_tags) do
						persisted_tag_count[tag] = (persisted_tag_count[tag] or 0) + 1
					end
				end
			end
		end
		local function IsPrefabAllowed(prefab)
			if (prefab.max_count or -1) == (prefabs_count[prefab] or 0) then
				return
			end
			if persisted_tag_count then
				local tags = prefab_tags[prefab]
				for _, tag in ipairs(tags) do
					local tag_count = persisted_tag_count[tag]
					if tag_count and tag_count <= 0 then
						return
					end
				end
			end
			return true
		end
		
		local map_angle = rand(360*60)
		local similar_grids = {}
		
		local function MulDivWeight(weight, mul, div, pow)
			for i=1,(pow or 0) do
				weight = weight * mul / div
			end
			return weight
		end
		
		local _overlap_reduct, _fit_effort -- prefab type props
		local _place_x, _place_y, _radius_target, _radius_range -- prefab location props
		
		local radius_getters = PrefabRadiusEstimators()
		local get_radius

		local repeat_weights = {}
		local function prefab_weight(prefab)
			local weight = MulDivRound(unit_weight, prefab.weight, 100)
			--[[
			local sweight = 0
			for tag in pairs(prefab.tags) do
				local sgrid = similar_grids[tag]
				if sgrid then
					sweight = sweight + sgrid:get(_place_x, _place_y) - 1
				end
			end
			if sweight > 0 then
				weight = weight + MulDivRound(weight, sweight, group_attract)
			end
			--]]
			weight = MulDivWeight(weight, prefab.min_radius, prefab.max_radius, _overlap_reduct) -- prioritize prefabs with better incircle to excircle radius ratio to reduce overlapping
			local radius = get_radius(prefab)
			local radius_err = abs(_radius_target - radius)
			weight = MulDivWeight(weight, _radius_range - radius_err, _radius_range, _fit_effort) -- prioritize prefabs with radius closer to the desired one
			local repeat_weight = repeat_weights[prefab]
			if repeat_weight then
				weight = MulDivRound(weight, repeat_weight, unit_weight)
			end
			return 1 + weight
		end
		
		local function prefab_add(prefab_list, prefab, x, y, radius, mix_grid_idx, ptype, try_persist, skip_raster, angle)
			--assert(ptype_grid:get(x, y) == mix_grid_idx)
			assert((prefab.max_count or -1) ~= (prefabs_count[prefab] or 0))
			local count = (prefabs_count[prefab] or 0) + 1
			prefabs_count[prefab] = count
			local reduct = prefab.repeat_reduct or 0
			if reduct > 0 then
				local rstep = reduct / 10
				local weight = unit_weight
				for i=1,count do
					local new_weight = weight * (100 - reduct) / 100
					if new_weight == weight then
						break
					end
					weight = new_weight
					reduct = reduct - rstep
					if reduct <= 0 then
						break
					end
				end
				repeat_weights[prefab] = weight
			end
			local mx, my = x * work_step, y * work_step
			local mz = GetHeight(mx, my)
			local prefab_pos = point(mx, my, mz)
			assert(IsPointInBounds(prefab_pos))
			local bbox
			if not skip_raster then
				local excircle_m = prefab.max_radius * type_tile
				bbox = box(mx - excircle_m, my - excircle_m, mx + excircle_m, my + excircle_m)
			end
			
			if not angle then
				local angle_variation = prefab.angle_variation or 180*60
				angle = rand(-angle_variation, angle_variation) - (prefab.angle or 0)
				local rotation_mode = prefab.rotation_mode
				if rotation_mode == "slope" then
					angle = angle + GetSlopeOrientation(prefab_pos, work_step * prefab.min_radius / 2)
				elseif rotation_mode == "map" then
					angle = angle + map_angle
				end
			end
			
			local raster = {
				pos = prefab_pos,
				angle = angle,
				place_idx = 0,
				place_mask_idx = mix_grid_idx,
			}
			add_idx = add_idx + 1
			prefab_list[#prefab_list + 1] = {prefab, raster, add_idx, ptype, bbox}
			
			local remaining = max_int
			local tags = prefab_tags[prefab]
			if tags then
				local loc = point_pack(x, y, radius)
				for _, tag in ipairs(tags) do
					local loc_list = prefab_tag_loc[tag]
					if not loc_list then
						prefab_tag_loc[tag] = { loc }
					else
						loc_list[#loc_list + 1] = loc
					end
					local tag_count = persisted_tag_count and persisted_tag_count[tag]
					if tag_count then
						assert(tag_count > 0)
						tag_count = tag_count - 1
						persisted_tag_count[tag] = tag_count
						remaining = Min(remaining, tag_count)
					end
				end
				if try_persist and prefab_to_persist_tags[prefab] then
					local name = prefab_markers[prefab]
					prefabs_to_persist[#prefabs_to_persist + 1] = { name, ptype, x, y, angle }
				end
			end
			return count, remaining
		end
		
		local skip = debug and {
			Height = not gen_mode.Height,
			Type = not gen_mode.Type,
			Grass = not gen_mode.Grass,
		}
		local raster_params = {
			place_grid = mark_grid,
			place_mask = ptype_grid,
			place_mask_res = ptype_grid_res,
			overlap_grid = overlap_grid,
			dither_seed = rand(),
			height_min = self.MinHeight,
			height_max = self.MaxHeight,
		}
		local raster_meta = {__index = raster_params}
		local prefab_cache = {}
		local cache_info = {}
		local current_memory = 0
		local peak_memory = 0
		local tasks_count = map_divs * map_divs
		local PREFAB_META, PREFAB_RASTER, PREFAB_IDX, PREFAB_TYPE, PREFAB_BOX = 1, 2, 3, 4, 5
		local function FreeCache(prefab)
			local cache = prefab_cache[prefab]
			if not cache then
				assert(false, "Missing cache")
				return
			end
			local data = cache.__index
			free_grid(data.height_grid)
			free_grid(data.type_grid)
			free_grid(data.grass_grid)
			free_grid(data.mask_grid)
			prefab_cache[prefab] = nil
			current_memory = current_memory - (prefab.required_memory or 0)
			assert(current_memory >= 0, "Wrong memory estimation")
		end
		local function LoadCache(prefab)
			local cache, ignore_memory_limits
			while true do
				cache = prefab_cache[prefab]
				if cache then
					break
				elseif cache == false then -- load error
					return
				end
				local required_memory = prefab.required_memory or 0
				if ignore_memory_limits or current_memory + required_memory <= raster_cache_memory then
					local preload_start_time = GetPreciseTicks()
					local data = PrefabPreload(prefab, raster_meta, skip)
					if debug then
						AddPrefabStat(prefab, "grid_load_time", GetPreciseTicks() - preload_start_time)
					end
					cache = data and {__index = data} or false
					if cache then
						current_memory = current_memory + required_memory
						peak_memory = Max(peak_memory, current_memory)
					end
					prefab_cache[prefab] = cache
					break
				end
				local min_prefab
				local min_required_memory = max_int
				local locked = 0
				for i=1,#cache_info do
					local prefab_i = cache_info[i]
					if prefab_cache[prefab_i] then
						local required_memory_i = prefab_i.required_memory or 0
						if min_required_memory > required_memory_i then
							if cache_info[prefab_i].locks == 0 then
								min_prefab = prefab_i
								min_required_memory = required_memory_i
							else
								locked = locked + 1
							end
						end
					end
				end
				if min_prefab then
					FreeCache(min_prefab)
				elseif locked > 0 then
					WaitMsg("PrefabCacheUnloaded")
				else
					g_print("Unable to free enough memory for rasterization!")
					ignore_memory_limits = true
				end
			end
			if not cache then
				return
			end
			local info = cache_info[prefab]
			assert(info, "Load cache error")
			if info then
				info.locks = info.locks + 1
			end
			return cache
		end
		local function UnloadCache(prefab)
			local info = cache_info[prefab]
			if not info or info.locks <= 0 or info.count <= 0 then
				assert(false, "Unload cache error")
				return
			end
			info.locks = info.locks - 1
			info.count = info.count - 1
			Msg("PrefabCacheUnloaded")
			if info.count ~= 0 then
				return
			end
			assert(info.locks == 0, "Invalid lock count")
			FreeCache(prefab)
		end
		local function WaitRaster(prefabs_to_raster)
			if #prefabs_to_raster == 0 then
				return
			end
			local start_time_raster = GetPreciseTicks()
			-- try to reduce object removal from overlapping:
			local function prefab_list_sort(a, b)
				local p1, p2 = a[PREFAB_META], b[PREFAB_META]
				if p1 ~= p2 then
					local ptype1, ptype2 = a[PREFAB_TYPE], b[PREFAB_TYPE]
					if ptype1 ~= ptype2 then
						local preset1, preset2 = ptype_to_preset[ptype1], ptype_to_preset[ptype2]
						if preset1 and preset2 then
							return ptype_cmp(preset1, preset2)
						end
					end
					local mul1 = (p1.obj_count or 1) * (p2.total_area or 1)
					local mul2 = (p2.obj_count or 1) * (p1.total_area or 1)
					if mul1 ~= mul2 then
						return mul1 < mul2
					end
					local mul1 = p1.max_radius * p2.min_radius
					local mul2 = p2.max_radius * p1.min_radius
					if mul1 ~= mul2 then
						return mul1 < mul2
					end
				end
				return a[PREFAB_IDX] < b[PREFAB_IDX]
			end
			table.sort(prefabs_to_raster, prefab_list_sort)
			-- add the new prefabs in to the final list
			local place_idx = #prefab_list
			for _, info in ipairs(prefabs_to_raster) do
				place_idx = place_idx + 1
				local raster = info[PREFAB_RASTER]
				raster.place_idx = place_idx
				prefab_list[place_idx] = info
			end

			local waiting = {}
			local thread_idx = 0
			local y0 = 0
			for y=1,map_divs do
				local y1 = MulDivRound(mh, y, map_divs)
				assert(y1 % type_tile == 0)
				local x0 = 0
				for x=1,map_divs do
					local x1 = MulDivRound(mw, x, map_divs)
					assert(x1 % type_tile == 0)
					local mbox = box(x0, y0, x1, y1)
					for i=1,#prefabs_to_raster do
						local prefab, raster, add_idx, ptype, bbox = unpack(prefabs_to_raster[i])
						if bbox and bbox:Intersect2D(mbox) ~= irOutside then
							local info = cache_info[prefab]
							if not info then
								info = {
									count = 1,
									locks = 0,
								}
								cache_info[prefab] = info
								cache_info[#cache_info + 1] = prefab
							else
								info.count = info.count + 1
							end
						end
					end
					local thread = CreateRealTimeThread(function()
						for i=1,#prefabs_to_raster do
							local prefab, raster, add_idx, ptype, bbox = unpack(prefabs_to_raster[i])
							local cache = bbox and bbox:Intersect2D(mbox) ~= irOutside and LoadCache(prefab)
							if cache then
								setmetatable(raster, cache)
								local raster_start_time = GetPreciseTicks()
								local err, ibox, out_of_lims = AsyncGridSetTerrain(raster, mbox)
								if debug then
									AddPrefabStat(prefab, "grid_place_time", GetPreciseTicks() - raster_start_time)
								end
								if err then
									g_print("Failed to rasterize prefab", prefab_markers[prefab], err)
								elseif ibox then
									bx_changes = bx_changes or box()
									bx_changes = Extend(bx_changes, ibox)
								end
								if out_of_lims then
									height_out_of_lims = true
								end
								setmetatable(raster, nil)
								UnloadCache(prefab)
								if step_prefab then
									terrain.InvalidateHeight(ibox)
									terrain.InvalidateType(ibox)
									DbgClear()
									local name = prefab_markers[prefab]
									DbgShowPrefab(raster.pos, name, white, raster.place_idx, prefab.min_radius, prefab.max_radius)
									step("Terrain %d %s", add_idx, name)
								end
							end
						end
						waiting[CurrentThread()] = nil
						Wakeup(gen_thread)
					end)
					thread_idx = thread_idx + 1
					waiting[thread] = thread_idx
					x0 = x1
				end
				y0 = y1
			end
			while next(waiting) do
				WaitWakeup(1000)
				for thread in pairs(waiting) do
					if not IsValidThread(thread) then
						waiting[thread] = nil
					end
				end
			end
			local inv_bbox = bx_changes:grow(type_tile)
			terrain.FixHeightBorder(inv_bbox)
			if not step_prefab then
				terrain.InvalidateHeight(inv_bbox)
				terrain.InvalidateType(inv_bbox)
			end
			raster_time = raster_time + (GetPreciseTicks() - start_time_raster)
		end
		
		local dist_mask
		local dist_grid = new_grid()
		local dist_prec = 8
		local dist_tile = work_ratio * dist_prec
	
		local function WaitFitAndRaster(ptype)
			local ptype_preset = ptype_to_preset[ptype]
			if dump then
				dump("\n----\nPTYPE '%s' %s", ptype, TableToLuaCode(ptype_preset))
			end
			
			get_radius = radius_getters[ptype_preset.RadiusEstim]
			_overlap_reduct = ptype_preset.OverlapReduct > 0 and 2 ^ (ptype_preset.OverlapReduct - 1) or 0 -- prefab_weight
			_fit_effort = ptype_preset.FitEffort > 0 and 2 ^ (ptype_preset.FitEffort - 1) or 0 -- prefab_weight
			
			local prefabs = {}
			local respect_bounds = ptype_preset.RespectBounds
			local place_radius = ptype_preset.PlaceRadius / type_tile
			local radius_min, radius_max = max_int, 0
			for _, prefab in ipairs(ptype_to_prefabs[ptype] or empty_table) do
				local poi_type = prefab.poi_type or ""
				if poi_type == "" and IsPrefabAllowed(prefab) then
					local radius = get_radius(prefab)
					if radius >= place_radius then
						radius_max = Max(radius_max, radius)
						radius_min = Min(radius_min, radius)
						prefabs[#prefabs + 1] = prefab
					end
				end
			end
			if #prefabs == 0 then
				return
			end
			_radius_range = radius_max - radius_min + 1 -- prefab_weight
			
			local ptype_idx = ptype_to_idx[ptype]
			local mix_grid_idx = respect_bounds and ptype_idx
			local min_fill_ratio = ptype_preset.MinFillRatio -- pct
			local max_fill_error = ptype_preset.MaxFillError -- promil
			local max_pass = ptype_preset.FitPasses
			local placed_count = 0
			for pass = 1, max_pass do
				local start_time_fit = GetPreciseTicks()
				local prefab_list_pass = {}
				local area_remaining, all_area = GridMaskMark(ptype_grid, dist_grid, ptype_idx, ptype_grid_res)
				if not area_remaining then
					return
				end
				local min_area_remaining = all_area - all_area * min_fill_ratio / 100
				if area_remaining <= min_area_remaining + all_area * max_fill_error / 1000 then
					return
				end
				GridDistance(dist_grid, dist_tile, radius_max * dist_prec)
				if dump then
					local pct_x100 = all_area and MulDivRound(10000, all_area - area_remaining, all_area) or 0
					dump("\nPASS %d/%d START %s - %2d prefab(s) | form '%s' | min fill %2d%% | filled area %2d.%02d%%\n", pass, max_pass, ptype, #prefabs, ptype_preset.RadiusEstim, min_fill_ratio, pct_x100/100, pct_x100%100)
				end
				rand_init("FindAndRasterPrefabs", pass, ptype)
				local pass_placed_count = 0
				GridRandomEnumMarkDist(dist_grid, rand(), dist_tile, function(x, y, dist, area)
					if area <= min_area_remaining then
						return
					end
					_radius_target = Max(dist / dist_prec, radius_min) -- prefab_weight
					_place_x, _place_y = x, y -- prefab_weight
					local prefab, idx = trand(prefabs, prefab_weight)
					if not prefab then
						g_print("Failed to find prefab for type", ptype)
						return
					end
					local radius = get_radius(prefab)
					local count, remaining = prefab_add(prefab_list_pass, prefab, x, y, radius, mix_grid_idx, ptype)
					if (prefab.max_count or -1) == count or remaining <= 0 then
						table.remove(prefabs, idx)
					end
					if dump then
						pass_placed_count = pass_placed_count + 1
						local weight = prefab_weight(prefab)
						local total_weight, min_weight, max_weight = 0
						for i=1,#prefabs do
							local weight_i = prefab_weight(prefabs[i])
							total_weight = total_weight + weight_i
							min_weight, max_weight = MinMax(weight_i, min_weight, max_weight)
						end
						local avg_weight = total_weight / #prefabs
						dump("PREFAB %4d | rand 0x%016X | weight %5d (%5d -%5d -%5d) | dist %3d (rad %3d - %3d) | pos (%4d, %4d) | '%s'",
							pass_placed_count, rand_seed, weight, min_weight, avg_weight, max_weight,
							_radius_target, prefab.min_radius, prefab.max_radius, x, y, prefab_markers[prefab])
					end
					return radius * dist_prec
				end)
				if dump then
					placed_count = placed_count + pass_placed_count
					dump("\nPASS %d/%d END %s PLACED %d TOTAL %d\n", pass, max_pass, ptype, pass_placed_count, placed_count)
				end
				locate_time = locate_time + (GetPreciseTicks() - start_time_fit)
				if #prefab_list_pass == 0 then
					return
				end
				WaitRaster(prefab_list_pass)
			end
		end
		for _, ptype in ipairs(ptypes_found) do
			WaitFitAndRaster(ptype)
		end
		
		local function WaitPlaceAndRasterPois()
			if not gen_mode.POI then
				return
			end
			
			local start_time_poi = GetPreciseTicks()
			
			local ptype_to_poi_prefabs = {}
			local poi_type_to_ptypes = {}
			local prefab_to_ptype_map = {}
			local prefab_list_poi = {}
			
			local dbg_poi_count
			local poi_count, poi_marks, poi_types = {}, {}, {}
			local function poi_weight(prefab)
				local weight = MulDivRound(unit_weight, prefab.weight, 100)
				local count = prefabs_count[prefab] or 0
				if count > 0 then
					local max_count = prefab.max_count or -1
					weight = max_count > 0 and MulDivRound(weight, max_count - count, max_count) or weight
				end
				return weight
			end
			local tag_to_tag_limits = GetPrefabTagsLimits()
			local slope_grid = self:GetGridInput(self.SlopeGrid)
			local slope_mask
			local function PlacePois(poi_type, poi_area, ptypes, partial_count, max_count)
				local total_count = poi_count[poi_type] or 0
				if partial_count == 0 or total_count == max_count then
					return
				end
				local prefabs
				local min_radius, max_radius = max_int, 0
				for _, ptype in ipairs(ptypes) do
					for _, prefab in ipairs(ptype_to_poi_prefabs[ptype]) do
						if poi_type == prefab.poi_type
						and (not poi_area or poi_area == prefab.poi_area)
						and prefab_to_ptype_map[prefab][ptype]
						and IsPrefabAllowed(prefab) then
							prefabs = prefabs or {}
							if not prefabs[prefab] then
								prefabs[prefab] = ptype
								prefabs[#prefabs + 1] = prefab
								local radius = get_radius(prefab)
								max_radius = Max(max_radius, radius)
								min_radius = Min(min_radius, radius)
							end
						end
					end
				end
				if not prefabs then
					return
				end
				if dump then
					dump("\nPOI '%s' START {%s} - %2d prefab(s), count %d/%d\n", poi_type, table.concat(ptypes, ","), #prefabs, partial_count, max_count)
				end
				rand_init("PlacePois", poi_type, unpack(ptypes))
				local ptype_single
				if #ptypes == 1 then
					ptype_single = ptypes[1]
					local ptype_idx = ptype_to_idx[ptype_single]
					if ptype_idx then
						GridMask(ptype_grid, dist_grid, ptype_idx)
					end
				else
					local grid_idx_remap = {}
					for _, ptype in ipairs(ptypes) do
						local ptype_idx = ptype_to_idx[ptype]
						if ptype_idx then
							grid_idx_remap[ptype_idx] = 1
						end
					end
					GridReplace(ptype_grid, dist_grid, grid_idx_remap, 0)
				end
				local ptypes_map = table.invert(ptypes)
				local poi_preset = poi_types[poi_type]
				local fill_radius = poi_preset.FillRadius * dist_prec / type_tile
				if fill_radius > 0 then
					GridNot(dist_grid)
					GridDistance(dist_grid, dist_tile, fill_radius)
					GridMask(dist_grid, 0, fill_radius - 1)
					GridDistance(dist_grid, dist_tile, fill_radius)
					GridMask(dist_grid, fill_radius)
				end
				
				local to_mark = {}
				local function MarkDist(x, y, radius, min_dist, max_dist)
					local pos = point_pack(x, y)
					local limits = to_mark[pos]
					if not limits then
						limits = {}
						to_mark[pos] = limits
					end
					if min_dist and min_dist >= 0 then
						limits[1] = Max(limits[1] or min_int, radius + min_dist / type_tile)
					end
					if max_dist and max_dist < max_int then
						limits[2] = Min(limits[2] or max_int, radius + max_dist / type_tile)
					end
				end
				
				local dist_to_same_m = poi_preset.DistToSame
				for _, poi_info in pairs(poi_marks) do
					local poi_type_i, x, y, radius = unpack(poi_info)
					MarkDist(x, y, radius, poi_type_i == poi_type and dist_to_same_m or 0)
				end
				
				for poi_tag in pairs(poi_preset.Tags) do
					for tag, limits in pairs(tag_to_tag_limits[poi_tag]) do
						local min_dist, max_dist = limits[1], limits[2]
						for _, loc in ipairs(prefab_tag_loc[tag]) do
							local x, y, radius = point_unpack(loc)
							MarkDist(x, y, radius, min_dist, max_dist)
						end
					end
				end
				
				local GridCircleSet = GridCircleSet
				local limit_dist
				for pos, limits in pairs(to_mark) do
					local x, y = point_unpack(pos)
					local min_dist, max_dist = limits[1], limits[2]
					if min_dist and min_dist >= 0 then
						GridCircleSet(dist_grid, 0, x, y, min_dist, 0, work_ratio)
					end
					if max_dist and max_dist < max_int then
						if not limit_dist then
							dist_mask = dist_mask or GridDest(dist_grid)
							dist_mask:clear()
							limit_dist = true
						end
						GridCircleSet(dist_mask, 1, x, y, max_dist, 0, work_ratio)
					end
				end
				if limit_dist then
					GridAnd(dist_grid, dist_mask)
				end
				
				local frame = (mapdata.PassBorder - poi_preset.DistToPlayable) / type_tile
				if frame > 0 then
					if frame >= gw / 2 or frame >= gh / 2 then
						g_print("Dist To Playable Area for", poi_type, "leaves no available space for placement!")
					end
					GridFrame(dist_grid, frame, 0)
				end
				local slope_min, slope_max = poi_preset.TerrainSlopeMin, poi_preset.TerrainSlopeMax
				if slope_grid and (slope_min > 0 or slope_max < 90*60) then
					if not slope_mask then
						slope_mask = GridDest(dist_grid)
						slope_grid = GridMakeSame(slope_grid, slope_mask)
					end
					GridMask(slope_grid, slope_mask, slope_min, slope_max)
					GridAnd(dist_grid, slope_mask)
				end
				GridDistance(dist_grid, dist_tile, max_radius * dist_prec)
				
				if step_poi then
					DbgClear()
					local show_grid, poi_grid = GridDest(dist_grid), GridDest(dist_grid)
					GridMask(dist_grid, show_grid, 1, max_int)
					local colors = { yellow, green, cyan, purple, orange, white, black }
					local palette = { [0] = 0, red }
					for i, prefab in ipairs(prefabs) do
						local radius = get_radius(prefab)
						GridMask(dist_grid, poi_grid, radius * dist_prec, max_int)
						GridAdd(show_grid, poi_grid)
						palette[i + 1] = palette[i + 1] or colors[1 + (i - 1) % #colors]
					end
					DbgShowTerrainGrid(show_grid, palette)
					step("POI %s START {%s}: %2d prefab(s) available", poi_type, table.concat(ptypes, ","), #prefabs)
				end
				
				-- todo: make forced mode to ensure the placement of at least one?
				local placed_count = 0
				local place_model = poi_preset.PlaceModel
				local skip_raster = place_model ~= "terrain"
				local place_mark = place_model ~= "point"
				local dist_to_same = dist_to_same_m / type_tile
				local prefab, idx, radius, max_radius, poi_radius
				GridRandomFetchMarkDist(dist_grid, rand(), dist_tile, function(x, y, dist)
					if idx then
						if x < 0 then
							table.remove(prefabs, idx)
						else
							local ptype = ptype_single
							if not ptype then
								local ptype_idx = ptype_grid:get(x, y)
								ptype = idx_to_ptype[ptype_idx]
								if not ptype or not ptypes_map[ptype] then
									ptype = prefabs[prefab]
								end
							end
							
							assert(prefab_to_ptype_map[prefab][ptype])
							local count, remaining = prefab_add(prefab_list_poi, prefab, x, y, radius, false, ptype, true, skip_raster)
							if (prefab.max_count or -1) == count or remaining <= 0 then
								table.remove(prefabs, idx)
							end
							if place_mark then
								poi_marks[#poi_marks + 1] = { poi_type, x, y, radius }
							end
							placed_count = placed_count + 1
							total_count = total_count + 1
							if debug then
								if dump then
									dump("POI %4d | rand 0x%016X | pos (%4d, %4d) | '%s'", placed_count, rand_seed, x, y, prefab_markers[prefab])
								end
								if step_poi then
									local mx, my = x * work_step, y * work_step
									DbgShowPrefab(point(mx, my), prefab_markers[prefab], cyan, total_count, radius, poi_radius)
								end
							end
							if placed_count == partial_count or total_count == max_count then
								return
							end
						end
					end
					prefab, idx = trand(prefabs, poi_weight)
					if not prefab then
						return
					end
					radius = get_radius(prefab)
					poi_radius = radius + dist_to_same
					return radius * dist_prec, poi_radius * dist_prec
				end)
				poi_count[poi_type] = total_count
				if debug then
					local poi_name = poi_area and (poi_type .. "." .. poi_area) or poi_type
					dbg_poi_count = dbg_poi_count or {}
					dbg_poi_count[poi_name] = (dbg_poi_count[poi_name] or 0) + placed_count
					local types_str = table.concat(ptypes, ",")
					if step_poi then
						step("POI %s END {%s}: %2d prefab(s) placed", poi_type, types_str, total_count)
					end
					if dump then
						dump("\nPOI '%s' END {%s} PLACED %d TOTAL\n", poi_type, types_str, placed_count, total_count)
					end
				end
				return placed_count
			end

			for _, prefab in ipairs(prefab_markers) do
				local poi_type = prefab.poi_type or ""
				if poi_type ~= "" then
					local poi_preset = poi_type_to_preset[poi_type]
					if not poi_preset then
						g_print("No such POI type", poi_type, "selected in", prefab_markers[prefab])
					else
						local ptype_map
						if #poi_preset.CustomTypes > 0 then
							ptype_map = table.invert(poi_preset.CustomTypes)
						elseif #poi_preset.PrefabTypeGroups > 0 then
							local group = table.find_value(poi_preset.PrefabTypeGroups, "id", prefab.poi_area) or empty_table
							ptype_map = table.invert(group.types)
						else
							ptype_map = {[prefab.type] = true}
						end
						assert(next(ptype_map))
						prefab_to_ptype_map[prefab] = ptype_map
						local all_ptypes = poi_type_to_ptypes[poi_type]
						if not all_ptypes then
							poi_type_to_ptypes[poi_type] = ptype_map
						else
							table.append(all_ptypes, ptype_map)
						end
							
						for ptype in pairs(ptype_map) do
							if ptype_to_idx[ptype] then
								ptype_to_poi_prefabs[ptype] = table.create_add_unique(ptype_to_poi_prefabs[ptype], prefab)
								if not poi_types[poi_type] then
									poi_types[poi_type] = poi_preset
									poi_types[#poi_types + 1] = poi_type
								end
							end
						end
					end
				end
			end
			
			local PoiCmp = PrefabPOI.Compare
			table.sort(poi_types, function (poi1, poi2)
				local preset1, preset2 = poi_types[poi1], poi_types[poi2]
				return PoiCmp(preset1, preset2)
			end)
			
			if dump then
				dump("\n----\nPersisted prefabs loaded: %d", #(persisted_prefabs or ""))
				dump("Persistable tag counters: %s\n", TableToLuaCode(persisted_tag_count))
			end
			
			DbgClear()
			local persisted_placed = 0
			for i, entry in ipairs(persisted_prefabs) do
				local name, ptype, x, y, angle = unpack(entry)
				local prefab = prefab_markers[name]
				local poi_type = prefab.poi_type or ""
				local poi_preset = poi_types[poi_type]
				if not poi_preset then
					g_print("Persisted prefab", name, "has invalid POI type", poi_type)
				else
					if not prefab_to_ptype_map[prefab][ptype] then
						g_print("Persisted prefab", name, "has invalid prefab type", ptype)
					end
					get_radius = radius_getters[poi_preset.RadiusEstim]
					local radius = get_radius(prefab)
					local place_model = poi_preset.PlaceModel
					local skip_raster = place_model ~= "terrain"
					local place_mark = place_model ~= "point"
					if place_mark then
						poi_marks[#poi_marks + 1] = { poi_type, x, y, radius }
					end
					local show
					for tag in pairs(poi_preset.Tags) do
						for other_tag, limits in pairs(tag_to_tag_limits[tag]) do
							local min_dist, max_dist = limits[1], limits[2]
							for _, loc in ipairs(prefab_tag_loc[other_tag]) do
								local xi, yi, radiusi = point_unpack(loc)
								local dx, dy = x - xi, y - yi
								local d = (sqrt(dx*dx + dy*dy) - radius - radiusi) * type_tile
								local is_err
								if min_dist and min_dist >= 0 and d < min_dist then
									g_print("Persisted prefab", i, name, "is too close to tag", other_tag, "(", d, "/", min_dist, ")")
									is_err = true
								end
								if max_dist and max_dist >= 0 and d > max_dist then
									g_print("Persisted prefab", i, name, "is too far from tag", other_tag, "(", d, "/", max_dist, ")")
									is_err = true
								end
								if is_err then
									show = true
									local pos = point(x, y) * type_tile
									local posi = point(xi, yi) * type_tile
									local r = radius * type_tile
									local ri = radiusi * type_tile
									DbgAddCircle(posi, ri, red)
									DbgAddSegment(pos, posi, yellow)
									if dump then
										dump("DbgClear(); DbgAddCircle(%s, %d); DbgAddCircle(%s, %d, red); DbgAddSegment(%s, %s, yellow); ViewPos(%s, %d)\n",
											ValueToLuaCode(pos), r,
											ValueToLuaCode(posi), ri,
											ValueToLuaCode(pos), ValueToLuaCode(posi),
											ValueToLuaCode((pos + posi) / 2), pos:Dist2D(posi) + ri + r)
									end
								end
							end
						end
					end
					if show then
						local pos = point(x, y) * type_tile
						DbgAddText(string.format("[%d] %s", i, name), ValidateZ(pos):AddZ(101*guim))
						DbgAddVector(pos, 100*guim)
						DbgAddCircle(pos, radius * type_tile)
					end
					local total_count = poi_count[poi_type] or 0
					total_count = total_count + 1
					poi_count[poi_type] = total_count
					prefab_add(prefab_list_poi, prefab, x, y, radius, false, ptype, true, skip_raster, angle)
					persisted_placed = persisted_placed + 1
					if debug then
						if dump then
							dump("PERSIST %3d | pos (%4d, %4d) | angle %6d | '%s'", persisted_placed, x, y, angle, name)
						end
						if step_poi then
							local mx, my = x * work_step, y * work_step
							DbgShowPrefab(point(mx, my), name, red, total_count, radius, poi_radius)
						end
					end
				end
			end
			
			for _, poi_type in ipairs(poi_types) do
				local poi_preset = poi_types[poi_type]
				local poi_max_count = -1
				if poi_preset.MaxCount ~= -1 then
					poi_max_count = rand(Max(poi_preset.MinCount, 0), poi_preset.MaxCount)
				end
				local orig_max_count = poi_max_count
				get_radius = radius_getters[poi_preset.RadiusEstim]
				local custom_types = poi_preset.CustomTypes
				local type_groups = poi_preset.PrefabTypeGroups
				
				if dump then
					dump("\n----\nPOITYPE '%s' %s", poi_type, TableToLuaCode(poi_preset))
				end
				
				if #custom_types > 0 then
					PlacePois(poi_type, false, custom_types, poi_max_count, orig_max_count)
				elseif #type_groups > 0 then
					local total_area = 0
					if poi_max_count ~= -1 then
						for _, group in ipairs(type_groups) do
							for _, ptype in ipairs(group.types) do
								total_area = total_area + (ptype_to_area[ptype] or 0)
							end
						end
					end
					for i, group in ipairs(type_groups) do
						local count = poi_max_count
						if total_area > 0 and count ~= -1 and i ~= #type_groups then
							local group_area = 0
							for _, ptype in ipairs(group.types) do
								group_area = group_area + (ptype_to_area[ptype] or 0)
							end
							count = MulDivRound(poi_max_count, group_area, total_area)
							total_area = total_area - group_area
						end
						count = PlacePois(poi_type, group.id, group.types, count, orig_max_count)
						if count and poi_max_count ~= -1 then
							poi_max_count = poi_max_count - count
						end
					end
				else
					local ptype_map = poi_type_to_ptypes[poi_type]
					local ptypes = table_keys(ptype_map, true)
					local total_area = 0
					if poi_max_count ~= -1 then
						for _, ptype in ipairs(ptypes) do
							total_area = total_area + (ptype_to_area[ptype] or 0)
						end
					end
					for i, ptype in ipairs(ptypes) do
						local count = poi_max_count
						if total_area > 0 and count ~= -1 and i ~= #ptypes then
							local ptype_area = (ptype_to_area[ptype] or 0)
							count = MulDivRound(poi_max_count, ptype_area, total_area)
							poi_max_count = poi_max_count - count
							total_area = total_area - ptype_area
						end
						count = PlacePois(poi_type, false, { ptype }, count, orig_max_count)
						if count and poi_max_count ~= -1 then
							poi_max_count = poi_max_count - count
						end
					end
				end
				
				local placed_count = poi_count[poi_type] or 0
				if placed_count < poi_preset.MinCount then
					g_print("Not all", poi_type, "prefabs are placed:", placed_count, "/", poi_preset.MinCount)
				end
			end
			poi_time = GetPreciseTicks() - start_time_poi
			WaitRaster(prefab_list_poi)
			if debug then
				if step_poi then
					DbgShowTerrainGrid(false)
				end
				local tmp = {}
				for name, count in pairs(dbg_poi_count) do
					tmp[#tmp + 1] = {name = name, count = count}
				end
				self.dbg_placed_poi = tmp
			end
		end
		WaitPlaceAndRasterPois()

		free_grid(dist_grid)
		free_grid(dist_mask)
		placed_marks = GridLevels(mark_grid)
		if debug then
			self.LocateTime = locate_time
			self.RasterizeTime = raster_time
			self.PoiTime = poi_time
			self.PrefabCount = #prefab_list
			assert(add_idx == #prefab_list)
			local list = {}
			local prefab_hash
			for i, info in ipairs(prefab_list) do
				local prefab, raster = unpack(info)
				list[i] = { prefab_markers[prefab], raster.pos }
				if debug then
					prefab_hash = xxhash(prefab.hash, prefab_hash)
				end
			end
			self.PrefabHash = prefab_hash
			self.MixHash = xxhash(ptype_grid)
			self.MarkHash = xxhash(mark_grid)
			self.PrefabList = list
			self.RasterMem = peak_memory
			local min, max = GridMinMax(overlap_grid)
			local all = GridCount(overlap_grid, 0, max_int)
			local overlap = GridCount(overlap_grid, 1, max_int)
			self.OverlapMax = max
			self.OverlapPct = to_pct(overlap, all)
			
			local prefabs_to_raster = 0
			local visible_prefabs = {}
			local tmp = {}
			for idx, info in ipairs(prefab_list) do
				local prefab, raster = unpack(info)
				if raster.place_mask_idx then
					prefabs_to_raster = prefabs_to_raster + 1
					local visible_area = Min(placed_marks[idx] or 0, prefab.total_area) -- not accurate due to prefab rotation
					assert(visible_area <= prefab.total_area)
					local completely_hidden = visible_area == 0 and 1 or 0
					local stat = tmp[prefab] or {}
					stat.area = (stat.area or 0) + visible_area
					stat.hidden = (stat.hidden or 0) + completely_hidden
					stat.count = (stat.count or 0) + 1
					tmp[prefab] = stat
				end
			end
			for prefab, stat in pairs(tmp) do
				local max_area = prefab.total_area * stat.count
				assert(max_area > 0 and stat.area * work_ratio <= max_area)
				visible_prefabs[#visible_prefabs + 1] = {
					name = prefab_markers[prefab],
					visible_area = max_area > 0 and MulDivRound(pct_100, stat.area * work_ratio, max_area) or 0,
					fully_hidden = MulDivRound(pct_100, stat.hidden, stat.count),
				}
			end
			self.dbg_visible_prefabs = visible_prefabs
		
			self.PrefabVisible = prefabs_to_raster > 0 and to_pct(table.count(placed_marks), prefabs_to_raster) or 0
			local mix_area = gw * gh
			local area_spill, area_uncovered = GridGetCover(mark_grid, ptype_grid, cover_grid)
			self.AreaUncovered = to_pct(area_uncovered, mix_area)
			self.AreaSpill = to_pct(area_spill, mix_area)
			
			local tmp = {}
			local w, h = ptype_grid:size()
			for ptype, area in pairs(ptype_to_area) do
				local stats = {
					name = ptype,
					area = pct_mul * 100 * area / (w * h),
					prefabs = table.count(prefab_list, PREFAB_TYPE, ptype)
				}
				tmp[#tmp + 1] = stats
			end
			self.dbg_prefab_types = tmp
		end
	end
	
	local function PlacePrefabObjects()
		if not gen_mode.Objects then
			return
		end
		local start_time_po = GetPreciseTicks()
		rand_init("PlacePrefabObjects")
		
		local IsValidPos = CObject.IsValidPos
		local GetClassFlags = CObject.GetClassFlags
		local SetGameFlags = CObject.SetGameFlags
		local GetGameFlags = CObject.GetGameFlags
		local SetCollectionIndex = CObject.SetCollectionIndex
		local ClearCachedZ = CObject.ClearCachedZ
		local GridGetMark = GridGetMark
		local unpack = table.unpack
		local g_Classes = g_Classes
		local IsValid = IsValid
		local handle_provider = empty_func
		
		if self.gen_handles then
			local first_handle, handle_size = GetHandlesAutoLimits()
			local first_handle_pool, handle_pool_size, handle_pool = GetHandlesAutoPoolLimits()
			local last_handle = first_handle + handle_size - 1
			local last_handle_pool = first_handle_pool + handle_pool_size - handle_pool
			local system_handles = 1000
			local start_marker_handle = first_handle
			local next_handle = first_handle + system_handles + 1
			local next_handle_pool = first_handle_pool
			local handle_collisions = 0
			local handle_to_prefab = {}
			local handle_to_object = HandleToObject
			local IsKindOf = IsKindOf
			handle_provider = function(current_prefab, classname, reserved_handles, backwards)
				if not reserved_handles then
					local classdef = classname and g_Classes[classname]
					if not classdef or not IsKindOf(classdef, "Object") then
						return
					end
					reserved_handles = classdef.reserved_handles
				end
				local handle
				if not reserved_handles or reserved_handles == 0 then
					if last_handle <= next_handle then
						assert(false, "No more handles!")
						return false, "handles"
					elseif backwards then
						handle = last_handle
						last_handle = handle - 1
					else
						handle = next_handle
						next_handle = handle + 1
					end
				else
					if last_handle_pool <= next_handle_pool then
						assert(false, "No more handle pools!")
						return false, "handles"
					elseif backwards then
						handle = last_handle_pool
						last_handle_pool = handle - handle_pool
					else
						handle = next_handle_pool
						next_handle_pool = handle + handle_pool
					end
				end
				assert(handle > 0)
				local existing_obj = handle_to_object[handle]
				if IsValid(existing_obj) then
					handle_collisions = handle_collisions + 1
					if handle_collisions == 100 then
						assert(false, "Blank map used for generation isn't empty!")
						return false, "map"
					end
					if backwards then
						return false, "collision"
					end
					if handle_collisions < 100 and classname then
						local prev_prefab = handle_to_prefab[handle]
						g_print("Duplicated handle", handle, "\nNew object is", classname, "from", prefab_markers[current_prefab], "\nExisting object is", existing_obj.class, "from", prefab_markers[prev_prefab] or "map", "\n")
					end
					local new_handle, handle_err
					if handle - start_marker_handle > system_handles then
						while true do
							new_handle, handle_err = handle_provider(current_prefab, existing_obj.class, existing_obj.reserved_handles, true)
							if handle_err ~= "collision" then
								break
							end
						end
					end
					if new_handle then
						existing_obj.handle = new_handle
						handle_to_object[handle] = nil
						handle_to_object[new_handle] = existing_obj
					else
						g_print("Replacing existing object", existing_obj.class, existing_obj.handle, "by", classname)
						DoneObject(existing_obj)
					end
				end
				handle_to_prefab[handle] = current_prefab
				return handle
			end
		end
		
		local placed_objects, object_source = {}, {}
		local obj_count = 0
		local game_flags = gofPermanent | gofGenerated
		local function PlacedObject(obj, mark, prefab)
			mark = mark or 0
			local prev_mark = placed_objects[obj]
			assert(not prev_mark or prev_mark == mark)
			if prev_mark == mark then return end
			placed_objects[obj] = mark or 0
			object_source[obj] = prefab
			obj_count = obj_count + 1
			SetGameFlags(obj, game_flags)
			--bp(obj:IsEqualPos2D(1185431, 1650466))
		end
		--[[
		if dump then
			local orig_PlacedObject = PlacedObject
			PlacedObject = function(obj, ...)
				orig_PlacedObject(obj, ...)
				local x, y, z = obj:GetVisualPosXYZ()
				dump("OBJECT %4d: pos (%7d, %7d, %7d) | angle %7d | '%s'", obj_count, x, y, z, obj:GetAngle(), obj.class)
			end
		end
		--]]
		
		local max_chance = 100 * 1000
		local optional_chance = self.OptionalChance * 1000
		local steep_slope_cos = cos(self.SteepSlope)
		local rem_faded_objs = self.RemFadedObjs
		local use_mesh_overlap = self.UseMeshOverlap
		local removed_count = 0
		local RemoveObject = DoneObject
		local SkippedObject = empty_func
		
		if debug then
			RemoveObject = function(obj)
				DoneObject(obj)
				removed_count = removed_count + 1
			end
			SkippedObject = function()
				removed_count = removed_count + 1
			end
		end
		
		local OVRLP_DEL_NONE, OVRLP_DEL_ALL, OVRLP_DEL_IGNORE, OVRLP_DEL_PARTIAL, OVRLP_DEL_SINGLE = false, 0, 1, 2, 3
		
		local rem_coll_count = 0
		local obj_to_coll, coll_to_objs, coll_indice, coll_is_partial, removed_coll = {}, {}, {}, {}, {}
		local function RemoveColl(idx, nested_colls)
			if removed_coll[idx] then
				return
			end
			removed_coll[idx] = true
			if not nested_colls then
				return
			end
			for _, sub_idx in ipairs(nested_colls[idx]) do
				RemoveColl(sub_idx, nested_colls)
			end
		end
		
		local prefab_defs = {}
		local class_to_defaults = {}
		local last_col_idx, placed_collections = 0, 0
		local collections = Collections
		
		local rmfOptionalPlacement = const.rmfOptionalPlacement
		local rmfMeshOverlapCheck = const.rmfMeshOverlapCheck
		local rmfDeleteOnSteepSlope = const.rmfDeleteOnSteepSlope
		local cofComponentRandomMap = const.cofComponentRandomMap
		local max_collection_idx = const.GameObjectMaxCollectionIndex
		local base_prop_count = const.RandomMap.PrefabBasePropCount
		
		local GetPrefabFileObjs = GetPrefabFileObjs
		local AsyncFileToString = async.AsyncFileToString -- avoid yielding
		local Unserialize = Unserialize
		local GetDefRandomMapFlags = GetDefRandomMapFlags
		local GetPrefabObjPos = GetPrefabObjPos
		local SetPrefabObjPos = SetPrefabObjPos
		local PropObjSetProperty = PropObjSetProperty
		local SetRandomMapFlags = CObject.SetRandomMapFlags
		local selected_break = self.SelectedBreak and self.SelectedMark or 0
		local abort_prefab_placement
	
		local function PlacePrefab(prefab, prefab_pos, prefab_angle, mark, ptype, bbox)
			if abort_prefab_placement then
				return
			end
			
			--assert((prefab.revision or 0) <= revision)
			--assert((prefab.version or 1) <= version)
			assert(prefab_pos:IsValidZ())
			
			if dump then
				local x, y = prefab_pos:xy()
				dump("PlacePrefab %4d | pos (%7d, %7d) | angle %7d | '%s' ----------------------", mark, x, y, prefab_angle, prefab_markers[prefab])
			end
			
			mark = mark_grid and mark or 0
			
			if selected_break > 0 then
				bp(selected_break == mark)
			end
			
			local ptype_preset = ptype_to_preset[ptype] or empty_table
			local on_obj_overlap = ptype_preset.OnObjOverlap
			local ignore_colls = on_obj_overlap == OVRLP_DEL_IGNORE
			local ignore_partial_colls = on_obj_overlap == OVRLP_DEL_PARTIAL
			local delete_no_colls = on_obj_overlap == OVRLP_DEL_SINGLE

			local objs
			local nested_colls = prefab.nested_colls
			local nested_opt_objs = prefab.nested_opt_objs
			local save_collections = prefab.save_collections
			local defs = prefab_defs[prefab]
			if defs == nil then
				local load_time_start = GetPreciseTicks()
				local name = prefab_markers[prefab]
				if not exported_prefabs[name] then
					g_print("no such exported prefab", name)
					return
				end
				local filename = GetPrefabFileObjs(name)
				local err, bin = AsyncFileToString(nil, filename, nil, nil, "pstr")
				if err then
					g_print("failed to load prefab", name, ":", err)
					return
				end
				defs = Unserialize(bin)
				if not defs then
					g_print("failed to unserialize objects from prefab", name)
					return
				end
				prefab_defs[prefab] = (prefabs_count[prefab] or max_int) > 1 and defs or false
				if debug then
					AddPrefabStat(prefab, "obj_load_time", GetPreciseTicks() - load_time_start)
				end
			end
			if not defs then
				g_print("Uncached prefab", prefab_markers[prefab])
				return
			end
			
			local place_time_start = GetPreciseTicks()
			objs = {}
			for _, def in ipairs(defs) do
				do
					local class, dpos, angle, daxis,
						scale, rmf_flags, fade_dist,
						ground_offset, normal_offset,
						coll_idx, color, mirror = unpack(def, 1, base_prop_count)

					assert(class ~= "Collection")
					assert(not coll_idx or coll_idx ~= 0)
					
					local classdef, entity, default_rmf_flags
					local defaults = class_to_defaults[class]
					if defaults then
						classdef, entity, default_rmf_flags = unpack(defaults)
					else
						classdef = g_Classes[class]
						assert(classdef)
						if classdef then
							default_rmf_flags = GetDefRandomMapFlags(classdef)
							entity = classdef.entity or class
						end
						class_to_defaults[class] = {classdef, entity, default_rmf_flags}
					end
					if not classdef then
						goto continue
					end
					rmf_flags = rmf_flags or default_rmf_flags
					
					if optional_chance > 0 and (rmf_flags & rmfOptionalPlacement) ~= 0 then
						local reduction = coll_idx ~= 0 and nested_opt_objs and nested_opt_objs[coll_idx] or 1
						local chance = reduction > 1 and Max(1, optional_chance / reduction) or optional_chance 
						if crand(chance, max_chance) then
							if coll_idx then
								RemoveColl(coll_idx, nested_colls)
							end
							SkippedObject()
							goto continue
						end
					end
					local check_mark
					if on_obj_overlap then
						check_mark = bbox and mark
						if coll_idx then
							if removed_coll[coll_idx] then
								SkippedObject()
								goto continue
							end
							if ignore_partial_colls or delete_no_colls then
								check_mark = nil
							end
						end
					end
					
					local mesh_overlap = use_mesh_overlap and (rmf_flags & rmfMeshOverlapCheck) ~= 0
					local max_slope = (rmf_flags & rmfDeleteOnSteepSlope) ~= 0 and steep_slope_cos
					
					local new_pos, new_angle, new_axis, mark_found = GetPrefabObjPos(
						dpos, angle, daxis,
						rem_faded_objs and fade_dist,
						prefab_pos, prefab_angle,
						ground_offset, normal_offset,
						mark_grid, check_mark,
						mesh_overlap, entity, scale, mirror,
						max_slope)
						
					if not new_pos then
						if not ignore_colls and coll_idx then
							RemoveColl(coll_idx, nested_colls)
						end
						SkippedObject()
						goto continue
					end
					
					local handle, err = handle_provider(prefab, class, false, true)
					local components = 0
					if rmf_flags ~= default_rmf_flags then
						components = components | cofComponentRandomMap
					end
					local obj = classdef:new{handle = handle}
					if not IsValid(obj) then
						g_print("Aborting object placement after a failure to create an object of type", class)
						abort_prefab_placement = true
						break
					end
					SetPrefabObjPos(obj, new_pos, new_angle, new_axis, scale, color, mirror)
					for i=base_prop_count+1,#def,2 do
						PropObjSetProperty(obj, def[i], def[i + 1])
					end
					if rmf_flags ~= default_rmf_flags then
						SetRandomMapFlags(obj, rmf_flags)
					end
					objs[#objs + 1] = obj
					
					if coll_idx then
						obj_to_coll[obj] = coll_idx
						local coll_objs = coll_to_objs[coll_idx]
						if coll_objs then
							coll_objs[#coll_objs + 1] = obj
						else
							coll_indice[#coll_indice + 1] = coll_idx
							coll_to_objs[coll_idx] = { obj }
						end
						if ignore_partial_colls and not coll_is_partial[coll_idx] then
							if bbox and mark_found ~= mark then
								-- all seen objects from that collection are outside the prefab
								goto continue
							end
							-- mark the collection as partial as at least one object is inside
							coll_is_partial[coll_idx] = true
						end
					end
					PlacedObject(obj, mark, prefab)
				end
				::continue::
			end
			if debug then
				AddPrefabStat(prefab, "obj_place_time", GetPreciseTicks() - place_time_start)
			end
			if ignore_partial_colls then
				if #coll_indice > 0 then
					for _, coll_idx in ipairs(coll_indice) do
						local coll_objs = coll_to_objs[coll_idx]
						if coll_is_partial[coll_idx] then
							-- at least on object from the collection is inside the prefab
							for _, obj in ipairs(coll_objs) do
								PlacedObject(obj, mark, prefab)
							end
						else
							-- all objects from these collections are outside their prefabs
							RemoveColl(coll_idx, nested_colls)
							for _, obj in ipairs(coll_objs) do
								RemoveObject(obj)
							end
						end
					end
				end
			end
			if save_collections then
				for _, coll_idx in ipairs(coll_indice) do
					local coll_objs = not removed_coll[coll_idx] and coll_to_objs[coll_idx] or ""
					local count = #coll_objs
					for i = count, 1, -1 do
						if not IsValid(coll_objs[i]) then
							coll_objs[i] = coll_objs[count]
							coll_objs[count] = nil
							count = count - 1
						end
					end
					if count > 0 then
						local col_idx = last_col_idx + 1
						while collections[col_idx] do
							col_idx = col_idx + 1
						end
						last_col_idx = col_idx
						assert(col_idx <= max_collection_idx)
						if col_idx > max_collection_idx then
							g_print("max collections reached!", max_map_size)
						else
							local col = Collection:new{ Index = col_idx }
							col:SetName(string.format("MapGen_%d", col_idx))
							collections[col_idx] = col
							PlacedObject(col)
							for i=1,count do
								SetCollectionIndex(coll_objs[i], col_idx)
							end
							placed_collections = placed_collections + 1
						end
					end
				end
			end
			local has_removed_colls = next(removed_coll)
			for _, obj in ipairs(objs) do
				if IsValid(obj) then
					local coll_idx = has_removed_colls and obj_to_coll[obj]
					if coll_idx and removed_coll[coll_idx] then
						-- delete placed objects from removed collections
						RemoveObject(obj)
					elseif obj.__ancestors.Object then
						obj:PostLoad()
					end
				end
			end
			if has_removed_colls then
				rem_coll_count = rem_coll_count + table.count(removed_coll)
				removed_coll = {}
			end
			if #coll_indice > 0 then
				coll_indice, coll_to_objs = {}, {}
			end
			if next(obj_to_coll) then obj_to_coll = {} end
			if next(coll_is_partial) then coll_is_partial = {} end
			return objs
		end
		
		-- place all prefab objects:
		for mark, info in ipairs(prefab_list) do
			local prefab, raster, add_idx, ptype, bbox = unpack(info)
			assert(raster.place_idx == mark)
			if not bbox or not placed_marks or placed_marks[mark] then
				PlacePrefab(prefab, raster.pos, raster.angle, mark, ptype, bbox)
				if step_prefab then
					DbgClear()
					local name = prefab_markers[prefab]
					DbgShowPrefab(raster.pos, name, white, mark, prefab.min_radius, prefab.max_radius)
					step("Objects %d %s", add_idx, name)
				end
			end
		end
		
		if mark_grid then
			MapForEach(bx_changes or "map", "attached", false, nil, nil, gofPermanent, function(obj)
				--bp(obj:IsEqualPos2D(1185431, 1650466))
				local current_mark = GridGetMark(mark_grid, obj)
				if current_mark == 0 then
					-- existing map object outside the prefab zone
					ClearCachedZ(obj)
				elseif not placed_objects[obj] then
					-- existing map object inside the prefab zone
					DoneObject(obj)
				end
			end)
		end
		
		MapForEach(bx_changes or "map", "attached", false, "EditorCallbackObject", nil, nil, gofPermanent | gofGenerated, function(obj, ...)
			obj:EditorCallbackGenerate(...)
		end, self, object_source, placed_objects, prefab_list)
		
		if debug then
			self.ObjectTime = GetPreciseTicks() - start_time_po
			self.ObjectCount = obj_count
			self.RemObjects = removed_count
			self.RemColls = rem_coll_count
			self.PlacedColls = placed_collections
			local class_to_count = {}
			for obj in pairs(placed_objects) do
				if IsValid(obj) then
					class_to_count[obj.class] = (class_to_count[obj.class] or 0) + 1
				end
			end
			local tmp = {}
			local total_count = 0
			for class, count in pairs(class_to_count) do
				total_count = total_count + count
			end
			for class, count in pairs(class_to_count) do
				local pct = total_count > 0 and MulDivRound(pct_100, count, total_count) or 0
				tmp[#tmp + 1] = {count = count, class = class, pct = pct}
			end
			self.dbg_placed_objects = tmp
			self.dbg_obj_to_prefab_mark = placed_objects
		end
		--DbgAddTerrainRect(bx_changes, red)
	end
	
	FindAndRasterPrefabs()
	
	local orig_rand = HandleRand
	local handle_seed = rand_init("HandleRand")
	HandleRand = function(range)
		range, handle_seed = BraidRandom(handle_seed, range)
		return range
	end
	PlacePrefabObjects()
	HandleRand = orig_rand
	
	if self.SavePrefabLoc then
		mapdata.PersistedPrefabs = prefabs_to_persist
		if dump then
			dump("\n----\nPersisted prefabs saved: %d", #(prefabs_to_persist or ""))
			for i, entry in ipairs(prefabs_to_persist) do
				local name, ptype, x, y, angle = unpack(entry)
				dump("%3d | pos (%4d, %4d) | angle %6d | '%s'", i, x, y, angle, name)
			end
		end
	end
	
	if height_out_of_lims then
		g_print("The resulting map height is outside the allowed range!")
	end
	
	if debug then
		self.FirstRand = start_seed
		self.LastRand = rand_seed
			
		local unpack = table.unpack
		local tmp = {}
		for prefab, stat in pairs(prefab_stats) do
			local counters = prefab_stat_count[prefab]
			local avg_stats = {
				name = prefab_markers[prefab],
				count = prefabs_count[prefab],
				objs = prefab.obj_count,
				grid = sqrt(prefab.total_area),
			}
			local sum = 0
			for name, value in pairs(stat) do
				sum = sum + value
				avg_stats[name] = value / counters[name]
			end
			avg_stats.impact = sum
			tmp[#tmp + 1] = avg_stats
		end
		self.dbg_placed_prefabs = tmp
		
		if dump then
			dump("\n\n\nUsed Prefabs Meta:\n")
			local names = {}
			for prefab, count in pairs(prefabs_count) do
				local name = prefab_markers[prefab]
				names[#names + 1] = name
				names[name] = prefab
			end
			table.sort(names)
			for _, name in ipairs(names) do
				local prefab = table.copy(names[name])
				prefab.marker = nil -- too mush spam here
				dump("%20s: %s\n", name, TableToLuaCode(prefab))
			end
			dump("\n\n\nResults:\n")
			for i, prop in ipairs(self:GetProperties()) do
				if prop.log then
					local name = prop.name or prop.id
					local value = tostring(self:GetProperty(prop.id))
					if prop.editor == "text" then
						dump("\n%s:", name)
						dump(value)
					else
						dump("%20s: %s", name, value)
					end
				end
			end
		end
	end
	self:DbgUpdate()
	self:DbgOnModified()
end