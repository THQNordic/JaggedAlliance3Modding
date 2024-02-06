const.TagLookupTable["GridOpName"]   = "<color 75 105 198>"
const.TagLookupTable["/GridOpName"]  = "</color>"
const.TagLookupTable["GridOpStr"]   = "<color 180 86 36>"
const.TagLookupTable["/GridOpStr"]  = "</color>"
const.TagLookupTable["GridOpParam"]   = "<color 16 160 160>"
const.TagLookupTable["/GridOpParam"]  = "</color>"
const.TagLookupTable["GridOpValue"]   = "<color 160 160 16>"
const.TagLookupTable["/GridOpValue"]  = "</color>"
const.TagLookupTable["GridOpGlobal"]   = "<color 160 86 160>"
const.TagLookupTable["/GridOpGlobal"]  = "</color>"

local max_uint16 = 65535

local eval = prop_eval
local developer = Platform.developer
function DivToStr(v, s)
	local v100 = 1000 * v / (s or 1)
	v = v100 / 1000
	local r = v100 % 1000
	if r == 0 then
		return v
	elseif r < 10 then
		return v .. ".00" .. r
	elseif r < 100 then
		return v .. ".0" .. r
	end
	return v .. "." .. r
end

-- Return 'grid' in the same format and size as 'ref'
function GridMakeSame(grid, ref)
	grid = GridResample(grid, ref:size())
	grid = GridRepack(grid, IsComputeGrid(ref))
	return grid
end

-- Return true if 'grid' is the same format and size as 'ref'
function GridCheckSame(grid, ref)
	local fmt1, bits1 = IsComputeGrid(ref)
	local fmt2, bits2 = IsComputeGrid(grid)
	if fmt1 ~= fmt2 or bits1 ~= bits2 then
		return
	end
	local w1, h1 = ref:size()
	local w2, h2 = grid:size()
	if w1 ~= w2 or h1 ~= h2 then
		return
	end
	return true
end

function GridMapGet(grid, mx, my, coord_scale, value_scale)
	coord_scale = coord_scale or 1
	value_scale = value_scale or 1
	local mw, mh = terrain.GetMapSize()
	local gw, gh = grid:size()
	local gx, gy = MulDivTrunc(coord_scale * gw, mx, mw), MulDivTrunc(coord_scale * gh, my, mh)
	local gv = GridGet(grid, gx, gy, value_scale, coord_scale)
	return gv, gx, gy
end

----

if FirstLoad then
	LastGridProcName = ""
	LastGridProcDump = ""
end

function OnMsg.ChangeMap()
	LastGridProcName = ""
	LastGridProcDump = ""
end

local function OnChangeCombo()
	return {
		{value = "",            name = "Do nothing"},
		{value = "recalc_op",   name = "Run cursor only"},
		{value = "recalc_to",   name = "Run to cursor"},
		{value = "recalc_from", name = "Run from cursor"},
		{value = "recalc_all",  name = "Run All"},
	}
end

local run_mode_items = {"Debug", "Release", "GM", "Profile"}
local all_run_modes = set(table.unpack(run_mode_items))

DefineClass.GridProc = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Operations", id = "OnChange",    name = "On Change",       editor = "choice",    default = "recalc_op", items = OnChangeCombo },
		{ category = "Operations", id = "Lightmodel",  name = "Lightmodel",      editor = "preset_id", default = "", preset_class = "LightmodelPreset" },
		{ category = "Operations", id = "RunMode",     name = "Run Mode",        editor = "choice",    default = "Release", items = run_mode_items, max_items_in_set = 1 },
		{ category = "Operations", id = "RunOnce",     name = "Run Once",        editor = "bool",      default = false, },
		{ category = "Operations", id = "Randomize",   name = "Randomize",       editor = "bool",      default = false, no_edit = PropGetter("LoadSeed") },
		{ category = "Operations", id = "Seed",        name = "Fixed Seed",      editor = "number",    default = 0, no_edit = function(self) return self.Randomize or self.LoadSeed end, buttons = {{ name = "Rand", func = "ActionRand" }} },
		{ category = "Operations", id = "SaveSeed",    name = "Save Seed",       editor = "bool",      default = false, help = "Save the generation seed", no_edit = function(self) return self.LoadSeed or not self:GetSeedSaveDest() end },
		{ category = "Operations", id = "LoadSeed",    name = "Load Seed",       editor = "bool",      default = false, help = "Load the generation seed", no_edit = function(self) return not self:GetSeedSaveDest() end },
		{ category = "Operations", id = "Dump",        name = "Dump",            editor = "bool",      default = false, help = "Will create a generation dump log in Release and Debug runs. May affect performance." },
		{ category = "Stats",      id = "Count",       name = "Own Ops Count",   editor = "number",    default = 0,  read_only = true, dont_save = true },
		{ category = "Stats",      id = "ExecCount",   name = "Executed Ops",    editor = "number",    default = 0,  read_only = true, dont_save = true },
		{ category = "Stats",      id = "Time",        name = "Total Time (ms)", editor = "number",    default = -1, read_only = true, dont_save = true },
		{ category = "Stats",      id = "Log",         name = "Log",             editor = "text",      default = "", lines = 2, max_lines = 20, read_only = true, dont_save = true },
	},
	start_time = 0,
	log = false,
	err_msg = false,
	err_op = false,
}

function GridProc:GetSeedSaveDest()
end

function GridProc:ActionRand()
	self.Seed = AsyncRand()
	ObjModified(self)
end

function GridProc:GetLog()
	return self.log and table.concat(self.log, "\n") or ""
end

function GridProc:GetCount()
	return #self
end

function GridProc:Invalidate(state)
end

function GridProc:RunOps(state, from, to)
	local old_indent = state.indent
	local new_indent = (old_indent or "") .. "  .  "
	for i = 1, #self do
		local op = self[i]
		if not from or op == from then
			SuspendObjModified("RunOp")
			from = false
			state.indent = new_indent
			local err = op:RunOp(state)
			state.indent = old_indent
			if err and op.Optional then
				op.ignored_err = err
				err = nil
			else
				op.ignored_err = nil
			end
			op.run_err = err
			op.proc = state.proc
			ObjModified(op)
			ResumeObjModified("RunOp")
			if err then
				self.err_op = op
				self.err_msg = err
				return err
			end
		end
		if op == to then
			break
		end
	end
end

function GridProc:Run(state, from, to)
	state = state or {}
	PauseInfiniteLoopDetection("GridProc.Run")
	GridStatsReset()
	DbgStopInspect()
	local run_mode = state.run_mode or developer and self.RunMode or "GM"
	if run_mode == "Profile" then
		run_mode = "GM"
		FunctionProfilerStart()
	end
	if run_mode == "GM" then
		SuspendObjModified("GridProc.Run")
	end
	state.run_mode = run_mode
	local seed = state.rand
	if not seed then
		local seed_key, seed_tbl = self:GetSeedSaveDest()
		assert(not seed_key or seed_tbl)
		if self.LoadSeed then
			seed = seed_key and seed_tbl and seed_tbl[seed_key] or 0
		else
			seed = self.Randomize and AsyncRand() or self.Seed
			if self.SaveSeed and seed_key and seed_tbl then
				seed_tbl[seed_key] = seed
			end
		end
		state.rand = seed
	end
	local grids = state.grids or {}
	local params = state.params or {}
	state.env = state.env or setmetatable({}, {__index = function(tbl, key)
		local grid = rawget(grids, key)
		if grid ~= nil then
			return grid
		end
		local param = rawget(params, key)
		if param ~= nil then
			return param
		end
		assert(rawget(tbl, key) == nil)
		return rawget(_G, key)
	end})
	state.grids = grids
	state.params = params
	state.tags = state.tags or {}
	state.refs = state.refs or {}
	state.proc = state.proc or self
	
	local dump_str
	if self.Dump and state.run_mode ~= "GM" and state.proc == self then
		dump_str = pstr("", 1024*1024)
		local unpack = table.unpack
		local appendf = dump_str.appendf
		local append = dump_str.append
		state.dump = function(fmt, ...)
			appendf(dump_str, fmt, ...)
			append(dump_str, "\n")
		end
	end
	
	local start_exec_count = state.exec_count or 0
	state.exec_count = start_exec_count
	
	self.err_msg = nil
	self.err_op = nil
	self.start_time = GetPreciseTicks()
	self.Time = 0
	self.log = {}
	
	if self.Lightmodel ~= "" then
		SetLightmodelOverride(false, self.Lightmodel)
	end
	
	self:AddLog("Running")
	ObjModified(self)
	
	state.test = true
	local err = self:RunOps(state, from, to)
	if not err then
		state.test = nil
		self:RunInit(state)
		self:RunOps(state, from, to)
	end

	self.ExecCount = state.exec_count - start_exec_count
	
	local finalize_idx = self:AddLog("Finalize generation...")
	local start_finalize = GetPreciseTicks()
	self:RunDone(state)
	
	if dump_str then
		LastGridProcName = self:GetFullName()
		LastGridProcDump = dump_str
		CreateRealTimeThread(function()
			local filename = LastGridProcName .. ".txt"
			local err = AsyncStringToFile(filename, dump_str)
			if err then
				print("failed to write log:", err)
			elseif config.DebugMapGen then
				---[[
				local path = ConvertToOSPath(filename)
				print("log file saved to:", path)
				OpenTextFileWithEditorOfChoice(path)
				--]]
			end
		end)
	end
	
	local stat_alive = GridStatsAlive() or ""
	if #stat_alive > 0 then
		DebugPrint("Grids:\n")
		DebugPrint(print_format(stat_alive))
		DebugPrint("\n")
	end
	local stat_usage = GridStatsUsage() or ""
	if #stat_usage > 0 then
		DebugPrint("Grid ops:\n")
		DebugPrint(print_format(stat_usage))
		DebugPrint("\n")
	end
	ResumeObjModified("GridProc.Run")
	ResumeInfiniteLoopDetection("GridProc.Run")
	FunctionProfilerStop()
	
	local time_finalize = GetPreciseTicks() - start_finalize
	if finalize_idx and time_finalize > 0 then
		self.log[finalize_idx] = "Finalize generation: " .. time_finalize .. " ms"
	end
	self:AddLog(self:GetError() or "Finished with success")

	return self.err_msg
end

function GridProc:GetFullName()
	return self.class
end

function GridProc:AddLog(text, state)
	if not text then return end
	text = (state and state.indent or "") .. text
	local log = self.log
	local idx = #log + 1
	log[idx] = text
	self.Time = GetPreciseTicks() - self.start_time
	ObjModified(self)
	return idx
end

function GridProc:RunInit(state)
end

function GridProc:RunDone(state)
end

function GridProc:GetError()
	return self.err_msg and string.format("Error in '%s': '%s'", self.err_op.GridOpType, self.err_msg)
end

----

DefineClass.GridProcPreset = {
	__parents = { "Preset", "GridProc" },
	EditorCustomActions = {
		{ Menubar = "Action", Toolbar = "main", Name = "Run All",            FuncName = "ActionRunAll",        Icon = "CommonAssets/UI/Ged/play.tga", Shortcut = "R", },
		{ Menubar = "Action", Toolbar = "main", Name = "Run From Cursor",    FuncName = "ActionRunFromCursor", Icon = "CommonAssets/UI/Ged/right.tga", },
		{ Menubar = "Action", Toolbar = "main", Name = "Run To Cursor",      FuncName = "ActionRunToCursor",   Icon = "CommonAssets/UI/Ged/log-focused.tga", },
		{ Menubar = "Action", Toolbar = "main", Name = "Run Cursor Only",    FuncName = "ActionRunCursorOnly", Icon = "CommonAssets/UI/Ged/filter.tga", Split = true},
	},
	ContainerClass = "GridOp",
	StoreAsTable = false,

	EnableReloading = false,
	
	run_thread = false,
	run_start = 0,
	run_state = false,
	run_from = false,
	run_to = false,
	
	EditorMenubarName = false,
}

function GridProcPreset:ActionRunAll(ged)
	self:ScheduleRun()
end

local function RecalcProc(proc, op, recalc)
	recalc = recalc or proc.OnChange
	local from, to
	if recalc == "recalc_op" then
		from = op
		to = op
	elseif recalc == "recalc_to" then
		to = op
	elseif recalc == "recalc_from" then
		from = op
	elseif recalc ~= "recalc_all" then
		return
	end
	local prev_state = proc.run_state or empty_table
	local state = {
		grids = prev_state.grids,
		params = prev_state.params,
	}
	proc:ScheduleRun(state, from, to)
end

function GridProcPreset:ActionRunToCursor(ged)
	if IsKindOf(ged.selected_object, "GridOp") then 
		RecalcProc(self, ged.selected_object, "recalc_to")
	end
end

function GridProcPreset:ActionRunFromCursor(ged)
	if IsKindOf(ged.selected_object, "GridOp") then 
		RecalcProc(self, ged.selected_object, "recalc_from")
	end
end

function GridProcPreset:ActionRunCursorOnly(ged)
	if IsKindOf(ged.selected_object, "GridOp") then 
		RecalcProc(self, ged.selected_object, "recalc_op")
	end
end

function ActionOpenMapgenFolder(ged)
	local path = ConvertToOSPath("svnAssets/Source/MapGen/" .. GetMapName())
	CreateRealTimeThread(function()
		AsyncExec(string.format('cmd /c start /D "%s" .', path))
	end)
end

function GridProcPreset:ScheduleRun(state, from, to, delay)
	self.run_start = RealTime() + (delay or 0)
	self.run_state = state or {}
	self.run_from = from
	self.run_to = to
	if IsValidThread(self.run_thread) then
		return
	end
	self.run_thread = CreateRealTimeThread(function(self)
		while self.run_start > RealTime() do
			Sleep(self.run_start - RealTime())
		end
		self:Run(self.run_state, self.run_from, self.run_to)
	end, self)
end


function GridProcPreset:Run(state, ...)
	local err = GridProc.Run(self, state, ...)
	local proc = state and state.proc or self
	if proc == self then
		ObjModified(Presets[self.class])
	end
	return err
end

function GridProcPreset:GetFullName()
	return self.id
end

----

local preview_size = 512
local preview_recision = 1000
local float_recision = 1000000
local function ResampleGridForPreview(grid)
	grid = grid and not IsComputeGrid(grid) and GridRepack(grid, "F") or grid
	return GridResample(grid, preview_size, preview_size, false)
end
local function no_outputs(op)
	for id in pairs(op.output_props or empty_table) do
		if (op[id] or "") ~= "" then
			return
		end
	end
	return true
end
local function output_names(op)
	local items = {}
	local outputs = op.outputs or empty_table
	local default = op.output_default
	for id in pairs(op.output_props or empty_table) do
		items[#items + 1] = { value = id ~= default and id, name = op[id] }
	end
	table.sortby_field(items, "name")
	return items
end
local function allowed_run_mode_items(op)
	local def_modes = getmetatable(op).RunModes or all_run_modes
	if def_modes == all_run_modes then
		return run_mode_items
	end
	local items = {}
	for _, mode in ipairs(run_mode_items) do
		if def_modes[mode] then
			items[#items + 1] = mode
		end
	end
	return items
end

DefineClass.GridOp = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "General", id = "Enabled",       name = "Enabled",       editor = "bool",   default = true },
		{ category = "General", id = "Optional",      name = "Optional",      editor = "bool",   default = false },
		{ category = "General", id = "Breakpoint",    name = "Breakpoint",    editor = "bool",   default = false },
		{ category = "General", id = "GridOpType",    name = "Type",          editor = "text",   read_only = true, dont_save = true  },
		{ category = "General", id = "RunModes",      name = "Run Modes",     editor = "set",    default = all_run_modes, items = allowed_run_mode_items },
		{ category = "General", id = "UseParams",     name = "Use Params",    editor = "bool",   default = false, no_edit = function(self) return not self.param_props end },
		{ category = "General", id = "Operations",    name = "Operation",     editor = "set",    default = empty_table, items = function(self) return self.operations or empty_table end, max_items_in_set = 1, dont_save = true, no_edit = function(self) return #(self.operations or "") <= 1 end },
		{ category = "General", id = "Operation",                             editor = "text",   default = "", no_edit = true },
		{ category = "General", id = "Seed",          name = "Seed",          editor = "number", default = false, buttons = {{name = "Rand", func = "RandSeed"}}, help = "Custom rand seed. If not specified, it will be generated based on the operation name." },
		{ category = "General", id = "Comment",       name = "Comment",       editor = "text",   default = "" },
		
		{ category = "Stats",   id = "RunTime",       name = "Time (ms)",     editor = "number", default = -1, read_only = true, dont_save = true },
		{ category = "Stats",   id = "RunError",      name = "Error",         editor = "text",   default = false, read_only = true, dont_save = true },
		{ category = "Stats",   id = "ParamValues",   name = "Params",        editor = "text",   default = false, lines = 1, max_lines = 3, read_only = true, dont_save = true },
		
		{ category = "Preview", id = "OutputSelect",  name = "Output Select", editor = "choice", default = false, items = output_names, dont_save = true, max_items_in_set = 1, no_edit = no_outputs },
		{ category = "Preview", id = "OutputSize",    name = "Output Size",   editor = "point",  default = false, read_only = true, dont_save = true, no_edit = no_outputs },
		{ category = "Preview", id = "OutputLims",    name = "Output Lims",   editor = "point",  default = false, scale = preview_recision, read_only = true, dont_save = true, no_edit = no_outputs },
		{ category = "Preview", id = "OutputType",    name = "Output Type",   editor = "text",   default = false, read_only = true, dont_save = true, no_edit = no_outputs },
		{ category = "Preview", id = "OutputPreview", name = "Output Grid",   editor = "grid",   default = false, min = preview_size, max = preview_size, read_only = true, dont_save = true, no_edit = no_outputs },
	},
	
	GridOpType = "",
	EditorName = false,
	
	start_time = 0,
	recalc_on_change = true,
	proc = false,
	
	reset_props = false,
	
	inputs = false,
	input_props = false,
	input_fmt = false,
	input_bits = false,
	
	outputs = false,
	output_props = false,
	output_default = false,
	
	prop_to_param = false,
	params = false,
	param_props = false,
	
	operations = false,
	operation_text_only = false,
	props_processed = false,
	
	run_err = false,
	ignored_err = false,
}

local function is_optional(obj, prop)
	return eval(prop.optional, obj, prop)
end

local function is_ignored(obj, prop)
	return eval(prop.ignore_errors, obj, prop)
end

local function is_disabled(obj, prop)
	return eval(prop.no_edit, obj, prop)
end

function OnMsg.ClassesPostprocess()
	ClassDescendants("GridOp", function(class, def)
		if not def.props_processed then
			print("GridOp class", class, "requires GridOpType value")
		end
		local prop_to_param, param_props
		local input_props, output_props, reset_props
		for _, prop in ipairs(def.properties or empty_table) do
			if prop.grid_param then
				if not param_props then
					param_props = {}
					def.param_props = param_props
				end
				param_props[prop.id] = prop
			elseif prop.use_param then
				if not prop_to_param then
					prop_to_param = {}
					def.prop_to_param = prop_to_param
				end
				prop_to_param[prop.id] = prop.use_param
			end
			if prop.grid_input then
				if not input_props then
					input_props = {}
					def.input_props = input_props
				end
				input_props[prop.id] = prop
			end
			if prop.grid_output then
				if not output_props then
					output_props = {}
					def.output_props = output_props
					def.output_default = prop.id
				end
				output_props[prop.id] = prop
			end
			if prop.to_reset then
				if not reset_props then
					reset_props = {}
					def.reset_props = reset_props
				end
				reset_props[prop.id] = prop
			end
		end
	end)
end

function OnMsg.ClassesGenerate(classdefs)
	for class, def in pairs(classdefs) do
		local op_type = def.GridOpType
		if op_type then
			def.props_processed = true
			local operations = def.operations
			if op_type ~= "" then
				if operations then
					def.Operation = operations[1]
					if #operations > 1 then
						op_type = op_type .. ": " .. table.concat(operations, '-')
					end
				end
				def.EditorName = op_type
			end
			local prop_to_param, param_props
			local props = def.properties or empty_table
			local prop_idx = 1
			while prop_idx <= #props do
				local prop = props[prop_idx]
				local category = prop.category
				if prop.grid_param then
					local no_edit = prop.no_edit
					prop.no_edit = function(self, prop)
						return not self.UseParams or eval(no_edit, self, prop)
					end
				elseif prop.use_param then
					local no_edit = prop.no_edit
					local param_id = prop.id .. "Param"
					prop.use_param = param_id
					table.insert(props, prop_idx + 1, {
						id = param_id, name = prop.name .. " Param", editor = "choice",
						default = "", items = GridOpParams, grid_param = true, optional = true,
						category = category, operation = prop.operation,
						enabled_by = prop.enabled_by, no_edit = no_edit,
					})
					prop.no_edit = function(self, prop)
						return self.UseParams and self[param_id] ~= "" or eval(no_edit, self, prop)
					end
				end
				if prop.operation then
					local no_edit = prop.no_edit
					local list = prop.operation
					if type(list) ~= "table" then
						list = { list }
					end
					local disable_by, enable_by
					for _, name in ipairs(list) do
						if string.starts_with(name, "!") then
							name = string.sub(name, 2)
							disable_by = table.create_set(disable_by, name, true)
						else
							enable_by = table.create_set(enable_by, name, true)
						end
					end
					prop.no_edit = function(self, prop)
						if disable_by and disable_by[self.Operation] or enable_by and not enable_by[self.Operation] then
							return true
						end
						return eval(no_edit, self, prop)
					end
				end
				if prop.enabled_by then
					local no_edit = prop.no_edit
					local list = prop.enabled_by
					if type(list) ~= "table" then
						list = { list }
					end
					local disable_by, enable_by
					for _, name in ipairs(list) do
						if string.starts_with(name, "!") then
							name = string.sub(name, 2)
							disable_by = table.create_set(disable_by, name, true)
						else
							enable_by = table.create_set(enable_by, name, true)
						end
					end
					prop.no_edit = function(self, prop)
						for prop_id in pairs(disable_by) do
							if (self[prop_id] or "") ~= "" then
								return true
							end
						end
						if enable_by then
							local found
							for prop_id in pairs(enable_by) do
								if (self[prop_id] or "") ~= "" then
									found = true
									break
								end
							end
							if not found then
								return true
							end
						end
						return eval(no_edit, self, prop)
					end
				end
				if prop.optional and prop.help then
					prop.help = prop.help .. " (optional)"
				end
				if category == "Preview" or category == "Stats" then
					prop.dont_save = true
					prop.to_reset = prop.read_only
					prop.dont_recalc = true
				end
				prop_idx = prop_idx + 1
			end
		end
	end
end

function GridOp:RandSeed()
	self.Seed = AsyncRand()
	ObjModified(self)
end

function GridOp:SetOutputSelect(name)
	self.OutputSelect = name
	self.OutputSize = nil
	self.OutputLims = nil
	self.OutputType = nil
	self.OutputPreview = nil
end

function GridOp:SetGridOutput(name, grid)
	local outputs = (name or "") ~= "" and self.outputs
	if outputs then
		assert(grid)
		outputs[name] = grid
	end
end

function GridOp:GetGridInput(name)
	local inputs = (name or "") and self.inputs
	return inputs and inputs[name] or nil
end

function GridOp:GetOutputSelectGrid()
	local output = self.OutputSelect or self.output_default
	local name = output and self[output]
	return name and (self.outputs or empty_table)[name]
end

function GridOp:GetOutputSize()
	local size = self.OutputSize
	if not size then
		local grid = self:GetOutputSelectGrid()
		size = grid and point(grid:size()) or point20
		self.OutputSize = size
	end
	return size
end

function GridOp:GetOutputLims()
	local lims = self.OutputLims
	if not lims then
		local grid = self:GetOutputSelectGrid()
		lims = IsComputeGrid(grid) and point(GridMinMax(grid, preview_recision)) or point20
		self.OutputLims = lims
	end
	return lims
end

function GridOp:GetOutputType()
	local gtype = self.OutputType
	if not gtype then
		local grid = self:GetOutputSelectGrid()
		gtype = grid and GridGetPID(grid) or ""
		self.OutputType = gtype
	end
	return gtype
end

function GridOp:GetOutputPreview()
	local preview = self.OutputPreview
	if not preview then
		local grid = self:GetOutputSelectGrid()
		preview = grid and ResampleGridForPreview(grid)
		self.OutputPreview = preview
	end
	return preview
end

function GridOp:SetOperations(opset)
	local op
	for key, value in pairs(opset) do
		if value then
			op = key
			break
		end
	end
	self.Operation = op
end

function GridOp:GetOperations()
	return self.Operation ~= "" and set(self.Operation) or set()
end

function GridOp:GetValue(prop_id)
	local prop_to_param = self.UseParams and self.prop_to_param
	local param_id = prop_to_param and prop_to_param[prop_id]
	local param = param_id and self[param_id] or ""
	if param ~= "" then
		return self.params and self.params[param]
	end
	return self[prop_id]
end

function GridOp:GetValueText(prop_id, default)
	local prop_to_param = self.UseParams and self.prop_to_param
	local param_id = prop_to_param and prop_to_param[prop_id]
	local param = param_id and self[param_id] or ""
	if param ~= "" then
		return "<GridOpParam><" .. param_id .. "></GridOpParam>", param
	end
	local value = self[prop_id]
	if value ~= default then
		return "<GridOpValue><" .. prop_id .. "></GridOpValue>", value
	end
	return ""
end

function GridOp:CollectTags(tags)
end

function GridOp:RunTest(state)
end

function GridOp:RunOp(state)
	local run_mode = state.run_mode
	if not self.Enabled or not self.RunModes[run_mode] then
		return
	end
	
	local test = state.test
	local grids = state.grids
	local refs = state.refs
	
	local params
	local param_props = self.param_props
	if param_props then
		params = self.params or {}
		self.params = params
		local state_params = state.params
		for id, prop in pairs(param_props) do
			if not is_disabled(self, prop) then
				local name = self[id] or ""
				if name ~= "" then
					if not test then
						-- TODO: remove non-existent params from the previous run
						local param = state_params[name]
						if not param then
							-- possible in partial runs
							param = params[name]
							state_params[name] = param
						end
						if param ~= nil then
							params[name] = param
						else
							return "Param Not Found: " .. name
						end
					end
				elseif not is_optional(self, prop) then
					return "Param Name Expected: " .. prop.name
				end
			end
		end
	end
	
	local outputs
	local output_props = self.output_props
	if output_props then
		outputs = {}
		self.outputs = outputs
		for id, prop in pairs(output_props) do
			if not is_disabled(self, prop) and not is_optional(self, prop) then
				local name = self[id] or ""
				if name == "" then
					return "Output Name Expected: " .. prop.name
				end
			end
		end
	end

	local inputs
	local input_props = self.input_props
	if input_props then
		local input_fmt, input_bits = self.input_fmt, self.input_bits
		inputs = self.inputs or {}
		self.inputs = inputs
		for id, prop in pairs(input_props) do
			if not is_disabled(self, prop) then
				local name = self[id] or ""
				if name ~= "" then
					if not test then
						local grid = grids[name]
						if not grid then
							-- possible in partial runs
							grid = inputs[name]
							grids[name] = grid
						end
						if grid then
							if input_fmt then
								grid = GridRepack(grid, input_fmt, input_bits or nil)
							end
							inputs[name] = grid
						elseif not (output_props or empty_table)[id] then
							if not is_ignored(self, prop) then
								return "Input Not Found: " .. name
							end
						end
					else
						refs[name] = (refs[name] or 0) + 1
					end
				elseif not is_optional(self, prop) then
					return "Input Name Expected: " .. prop.name
				end
			end
		end
	end
	
	local operations = self.operations
	if operations and not table.find(operations, self.Operation) then
		return "Grid Operation Expected"
	end
	
	if test then
		self.RunTime = nil
		self:CollectTags(state.tags)
		return self:RunTest(state)
	end
	
	for id, prop in pairs(self.reset_props or empty_table) do
		self[id] = nil
	end
	local exec_count = state.exec_count + 1
	state.exec_count = exec_count
	
	local name = self:GetFullName()
	local prev_rand = state.rand
	local rand = xxhash(state.rand, self.Seed or name)
	state.rand = rand
	
	bp(self.Breakpoint)
	
	local dump = state.dump
	if dump then
		dump("\nGridOp %03d 0x%016X: %s", exec_count, rand, name)
	end
	
	self.start_time = GetPreciseTicks()
	local err = self:Run(state)
	self.RunTime = GetPreciseTicks() - self.start_time
	
	state.rand = prev_rand -- restore the original seed, thus avoiding the order/count of operations affecting the randomness
	
	if err then
		return err
	end
	
	if output_props then
		for id, prop in pairs(output_props) do
			local name = self[id] or ""
			if name ~= "" then
				local grid = outputs[name]
				if not grid and not is_optional(self, prop) then
					return "Output Missing: " .. name
				end
				if dump and grid then
					local w, h = grid:size()
					local t, b = IsComputeGrid(grid)
					dump("* grid '%s' %d x %d '%s%s' 0x%016X", name, w, h, t and tostring(t) or "", b and tostring(b) or "", xxhash(grid))
				end
				if run_mode == "GM" then
					local prev_grid = grids[name]
					if prev_grid then
						prev_grid:free()
					end
				end
				grids[name] = grid
			end
		end
	end
	
	state.proc:AddLog(self:GetLogMessage(), state)
	
	if run_mode == "GM" then
		self.inputs = nil
		self.outputs = nil
		self.params = nil
		for name, grid in pairs(inputs or empty_table) do
			refs[name] = refs[name] - 1
			if grid ~= grids[name] then
				grid:free()
			end
		end
		for name, grid in pairs(grids) do
			if (refs[name] or 0) <= 0 then
				grid:free()
				grids[name] = nil
			end
		end
	end
end

function GridOp:GetFullName()
	return string.strip_tags(_InternalTranslate(T(self:GetLogText()), self, false))
end

function GridOp:GetLogMessage()
	if self.RunTime <= 1 then return end
	return string.format("%s: %d ms", self:GetFullName(), self.RunTime)
end

function GridOp:GetParamValues()
	local prop_to_param = self.UseParams and self.prop_to_param
	local params = self.params
	if not next(params) or not next(prop_to_param) then
		return ""
	end
	local list, passed = {}, {}
	for prop_id, param_id in pairs(prop_to_param) do
		local param = param_id and self[param_id] or ""
		if not passed[param] then
			passed[param] = true
			local value = param ~= "" and params[param]
			if value then
				list[#list + 1] = string.format("%s = %s", param, tostring(value))
			end
		end
	end
	table.sort(list)
	return table.concat(list, ", ")
end

function GridOp:Run()
end

function GridOp:GetError()
	return self.run_err
end

function GridOp:GetRunError()
	return self.run_err or self.ignored_err
end

function GridOp:GetEditorText()
	if self.Operation == "" then
		return "<GridOpType>"
	elseif self.operation_text_only then
		return "<Operation>"
	else
		return "<GridOpType> <Operation>"
	end
end

function GridOp:GetLogText()
	return self:GetEditorText()
end

function GridOp:GetEditorView()
	local text = self:GetEditorText() or ""
	if text == "" then
		text = "<GridOpType>"
	end
	local my_run_modes = self.RunModes
	local run_mode = (self:GetPreset() or empty_table).RunMode
	if run_mode and not my_run_modes[run_mode] then
		text = "<style GedComment>--</style>"
	elseif not self.Enabled then
		text = "[<style GedHighlight>Disabled</style>] " .. text
	elseif self.run_err then
		text = "<style GedError>[Error] " .. text .. "</style>"
	elseif self.ignored_err then
		text = "[<style GedHighlight>Ignored</style>] " .. text
	--[[
	elseif my_run_modes ~= all_run_modes then
		text = " <style GedConsole>[" .. table.concat(SetToList(my_run_modes), ",") .. "]</style> " .. text
	--]]
	elseif self.RunTime > 0 then
		text = text .. " <color 128 128 0><RunTime></color>"
	end
	if (self.Comment or "") ~= "" then
		text = "<style GedComment><Comment></style>\n" .. text
	end
	return Untranslated(text)
end

function GridOp:GetPreset()
	return GetParentTable(self)
end

function GridOp:Recalc()
	local proc = self.proc
	if proc then
		RecalcProc(proc, self)
	end
end

function GridOp:OnEditorSetProperty(prop_id, old_value, ged)
	local proc = self.recalc_on_change and self.proc
	if not proc then return end
	local meta = self:GetPropertyMetadata(prop_id) or empty_table
	if meta.dont_recalc then return end
	RecalcProc(proc, self)
end

----

DefineClass.GridOpComment = {
	__parents = { "GridOp" },
	GridOpType = "Comment",
	recalc_on_change = false,
}

function GridOpComment:GetEditorView()
	if (self.Comment or "") ~= "" then
		return Untranslated("<style GedComment><Comment></style>")
	end
	return ""
end

----

local function GridOpItems(grid_op, def, callback)
	local local_items, global_items = {}, {}
	local parent = grid_op and grid_op:GetPreset()
	if not parent then
		return {}
	end
	ForEachPreset(parent.class, function(preset)
		local is_local = preset == parent
		local items = is_local and local_items or global_items
		for _, op in ipairs(preset) do
			callback(op, items, is_local)
		end
	end)
	for key in pairs(local_items) do
		global_items[key] = nil
	end
	local names = table.keys(local_items, true)
	table.iappend(names, table.keys(global_items, true))
	if def then
		table.insert(names, 1, def)
	end
	return names
end

function GridOpOutputNames(grid_op)
	return GridOpItems(grid_op, nil, function(op, items)
		for _, prop in ipairs(op:GetProperties() or empty_table) do
			if prop.grid_output then
				items[op[prop.id]] = true
			end
		end
	end)
end

function GridOpParams(grid_op)
	return GridOpItems(grid_op, "", function(op, items, is_local)
		if IsKindOf(op, "GridOpParam") then
			if not op.ParamLocal or is_local then 
				items[op.ParamName] = true
			end
		end
	end)
end

DefineClass.GridOpParam = {
	__parents = { "GridOp" },
	properties = {
		{ category = "General", id = "ParamName",  name = "Name",  editor = "combo", default = "", items = GridOpParams },
		{ category = "General", id = "ParamValue", name = "Value", editor = "text",  default = "" },
		{ category = "General", id = "ParamLocal", name = "Local", editor = "bool",  default = false },
	},
	GridOpType = "",
}

function GridOpParam:GetParamStr()
	return tostring(self.ParamValue)
end

function GridOpParam:GetParam(state)
	return self.ParamValue
end

function GridOpParam:Run(state)
	if self.ParamName == "" then
		return "Missing Param Name"
	end
	local value, err = self:GetParam(state)
	if err then
		return err
	end
	state.params[self.ParamName] = value
	local dump = state.dump
	if dump then
		dump("* %s '%s' = %s", type(value), self.ParamName, ValueToLuaCode(value))
	end
end

function GridOpParam:GetEditorText()
	return "<GridOpParam><ParamName></GridOpParam> = <GridOpValue><ParamStr></GridOpValue>"
end

----

DefineClass.GridOpParamEval = {
	__parents = { "GridOpParam" },
	properties = {
		{ category = "Preview", id = "ParamPreview", name = "Evaluated", editor = "text", default = "", read_only = true, dont_save = true },
	},
	GridOpType = "Param",
	value = false,
}

function GridOpParamEval:GetParam(state)
	local func, err = load("return " .. self.ParamValue, nil, nil, state.env)
	if not func then
		return nil, err
	end
	local success, value = pcall(func)
	if not success then
		return nil, value
	end
	self.value = value
	return value
end

function GridOpParamEval:GetParamPreview()
	if not self.proc then
		return ""
	end
	return ValueToLuaCode(self.value)
end

----

DefineClass.GridOpRun = {
	__parents = { "GridOp" },
	properties = {
		{ category = "General", id = "Sequence",   name = "Sequence",    editor = "preset_id", default = "", preset_class = function(self) return (self:GetPreset() or empty_table).class end, operation = "Proc" },
		{ category = "General", id = "Iterations", name = "Iterations",  editor = "number",    default = 1, min = 1, operation = "Proc" },
		{ category = "General", id = "InputName",  name = "Input Name",  editor = "combo",     default = "",  items = GridOpOutputNames, grid_input = true, optional = true, operation = {"Code", "Func"} },
		{ category = "General", id = "OutputName", name = "Output Name", editor = "combo",     default = "",  items = GridOpOutputNames, grid_output = true, optional = true, operation = {"Code", "Func"} },
		{ category = "General", id = "Tags",       name = "Tags",        editor = "set",       items = {"Terrain", "Objects"}, default = false },
		{ category = "General", id = "Code",       name = "Code",        editor = "func",      default = false, lines = 1, max_lines = 100, params = "state, grid", operation = "Code" },
		{ category = "General", id = "Func",       name = "Func",        editor = "text",      default = "", operation = "Func" },
		{ category = "General", id = "Param1",     name = "Param 1",     editor = "choice",    default = "", operation = "Func", items = GridOpParams, optional = true, grid_param = true },
		{ category = "General", id = "Param2",     name = "Param 2",     editor = "choice",    default = "", operation = "Func", items = GridOpParams, optional = true, grid_param = true },
		{ category = "General", id = "Param3",     name = "Param 3",     editor = "choice",    default = "", operation = "Func", items = GridOpParams, optional = true, grid_param = true },
	},
	GridOpType = "Run",
	operations = {"Proc", "Code", "Func"},
}

	
function GridOpRun:CollectTags(tags)
	table.append(tags, self.tags)
end

function GridOpRun:GetEditorText()
	local op = self.Operation
	if op == "Proc" then
		local iters = self.Iterations > 1 and " x <GridOpValue><Iterations></GridOpValue>" or ""
		return "<GridOpType> <GridOpStr><Sequence></GridOpStr>" .. iters
	elseif op == "Func" then
		if self.Func == "" then
			return "<GridOpType>"
		end
		local params = {}
		if self.InputName ~= "" then
			params[1] = "<GridOpName><InputName></GridOpName>"
		end
		if self.Param1 ~= "" then
			params[#params + 1] = "<GridOpParam><Param1></GridOpParam>"
		elseif self.Param2 ~= "" or self.Param3 ~= "" then
			params[#params + 1] = "nil"
		end
		if self.Param2 ~= "" then
			params[#params + 1] = "<GridOpParam><Param2></GridOpParam>"
		elseif self.Param3 ~= "" then
			params[#params + 1] = "nil"
		end
		if self.Param3 ~= "" then
			params[#params + 1] = "<GridOpParam><Param3></GridOpParam>"
		end
		
		local params_str = #params > 0 and table.concat(params, ", ") or ""
		local func_str = "<GridOpGlobal><Func></GridOpGlobal>(" .. params_str .. ")"
		if self.OutputName ~= "" then
			return "<GridOpName><OutputName></GridOpName> = " .. func_str
		end
		return "<GridOpType> " .. func_str
	elseif op == "Code" then
		local source = FuncSource[self.Code]
		local source_str = ""
		if source and source[3] then
			source_str = "\n<style GedConsole>" .. table.concat(source[3], "\n") .. "</style>"
		end
		if self.OutputName ~= "" then
			if self.InputName ~= "" then
				return "<GridOpName><OutputName></GridOpName> = <GridOpType>(<GridOpName><InputName></GridOpName>)" .. source_str
			end
			return "<GridOpName><OutputName></GridOpName> = <GridOpType>()" .. source_str
		end
		if self.InputName ~= "" then
			return "<GridOpType> <Operation>(<GridOpName><InputName></GridOpName>)" .. source_str
		end
		return "<GridOpType>" .. source_str
	end
	return GridOp.GetEditorText(self)
end

function GridOpRun:GetLogText()
	return "<GridOpType> <Operation>"
end

function GridOpRun:GetTarget(state)
	local sequences = {}
	local parent = state.proc
	ForEachPreset(parent.class, function(preset, group, sequence, sequences)
		if preset.id == sequence then
			sequences[#sequences + 1] = preset
		end
	end, self.Sequence, sequences)
	if #sequences == 0 then
		return nil, "Cannot Find Sequence: " .. self.Sequence
	elseif #sequences > 1 then
		return nil, "Multiple Sequences Named: " .. self.Sequence
	elseif sequences[1] == parent then
		return nil, "Cannot Run Itself: " .. self.Sequence
	end
	return sequences[1]
end

function GridOpRun:RunTest(state)
	local op = self.Operation
	if op == "Proc" then
		local target, err = self:GetTarget(state)
		if err then
			return err
		end
		self.target = target
		for it = 1,self.Iterations do
			local err = target:RunOps(state)
			if err then
				return err
			end
		end
	elseif op == "Code" then
		local source = FuncSource[self.Code]
		if source and source[4] then
			return source[4]
		end
	elseif op == "Func" then
		local name = self.Func or ""
		if name == "" then
			return "Function name expected"
		end
		if not _G[name] then
			return "No such global function"
		end
	end
end

function GridOpRun:Run(state)
	local op = self.Operation
	if op == "Proc" then
		local target = self.target
		if not target then
			return "Gather Run Error"
		end
		state.running = state.running or {}
		if state.running[target] then
			return "Infinite Recursion"
		end
		state.completed = state.completed or {}
		if state.completed[target] and target.RunOnce then
			return
		end
		state.running[target] = true
		local iters_str = self.Iterations > 1 and " x " .. self.Iterations or ""
		state.proc:AddLog("Running " .. self.Sequence .. iters_str, state)
		for it = 1,self.Iterations do
			local err = target:RunOps(state)
			if err then
				return err
			end
		end
		state.running[target] = nil
		state.completed[target] = true
	elseif op == "Code" then
		local input_grid = self:GetGridInput(self.InputName)
		if self.InputName ~= "" and not input_grid then
			return "Input grid " .. self.InputName .. "not found"
		end
		local success, err, output_grid = pcall(self.Code, state, input_grid) -- todo: debug missing error propagation
		if err then
			return err
		end
		if self.OutputName ~= "" then
			if not output_grid then
				return "Grid result expected"
			end
			self:SetGridOutput(self.OutputName, output_grid)
		end
	elseif op == "Func" then
		local input_grid = self:GetGridInput(self.InputName)
		if self.InputName ~= "" and not input_grid then
			return "Input grid " .. self.InputName .. "not found"
		end
		local func = _G[self.Func]
		local params = self.params
		local param1 = params and params[self.Param1]
		local param2 = params and params[self.Param2]
		local param3 = params and params[self.Param3]
		local success, output_grid = pcall(func, input_grid, param1, param2, param3)
		if not success then
			return output_grid
		end
		if self.OutputName ~= "" then
			if not output_grid then
				return "Grid result expected"
			end
			self:SetGridOutput(self.OutputName, output_grid)
		end
	end
end

----

DefineClass.GridOpDir = {
	__parents = { "GridOp" },
	properties = {
		{ category = "General", id = "BaseDir", name = "Base Dir", editor = "browse", default = "", folder = "svnAssets" },
	},
	GridOpType = "Directory Change",
}

function GridOpDir:GetEditorText()
	return "Set Directory <GridOpStr><BaseDir></GridOpStr>"
end

function GridOpDir:SetBaseDir(path)
	local path, fname, ext = SplitPath(path)
	self.BaseDir = SlashTerminate(path)
end

function GridOpDir:Run(state)
	if self.BaseDir == "" then
		return "Base Dir Expected"
	end
	if not io.exists(self.BaseDir) then
		return "Base Dir Do Not Exists"
	end
	state.base_dir = self.BaseDir
end

local function GridOpBaseDirs(grid_op)
	local base_dirs = GridOpItems(grid_op, "svnAssets/Source/MapGen", function(op, items)
		if IsKindOf(op, "GridOpDir") then
			items[op.BaseDir] = true
		end
	end)
	return base_dirs
end

----

DefineClass.GridOpOutput = {
	__parents = { "GridOp" },
	properties = {
		{ category = "General", id = "OutputName",    name = "Output Name", editor = "combo",  default = "", items = GridOpOutputNames, grid_output = true },
	},
	output_preview = false,
	GridOpType = "",
}

function GridOpOutput:GetEditorText()
	local op_str = GridOp.GetEditorText(self)
	return op_str .. " to <GridOpName><OutputName></GridOpName>"
end

function GridOpOutput:Run(state)
	local err, grid = self:GetGridOutput(state)
	if err then
		return err
	end
	self:SetGridOutput(self.OutputName, grid)
end

function GridOpOutput:GetGridOutput(state)
end

----

DefineClass.GridOpInput = {
	__parents = { "GridOp" },
	properties = {
		{ category = "General", id = "InputName", name = "Input Name", editor = "combo", default = "", items = GridOpOutputNames, grid_input = true },
	},
	GridOpType = "",
}

function GridOpInput:GetEditorText()
	local op_str = GridOp.GetEditorText(self)
	return op_str .. " <GridOpName><InputName></GridOpName>"
end

function GridOpInput:Run(state)
	return self:SetGridInput(state, self:GetGridInput(self.InputName))
end

function GridOpInput:SetGridInput(state, grid)
end

----

DefineClass.GridOpInputOutput = {
	__parents = { "GridOpInput", "GridOpOutput" },
	properties = {
		{ category = "Preview", id = "OutputCurtain", name = "Output Curtain (%)", editor = "number", default = 100, min = 0, max = 100, slider = true, dont_save = true },
	},
	input_preview = false,
	output_preview = false,
	GridOpType = "",
}

function GridOpInputOutput:GetGridOutputFromInput(state, grid)
end

function GridOpInputOutput:SetGridInput(state, input)
	return self:GetGridOutputFromInput(state, input)
end

function GridOpInputOutput:GetGridOutput(state)
	return GridOpInput.Run(self, state)
end

function GridOpInputOutput:Run(state)
	self.input_preview = nil
	self.output_preview = nil
	return GridOpOutput.Run(self, state)
end

function GridOpInputOutput:GetEditorText()
	local ops_str = GridOp.GetEditorText(self)
	if self.InputName == self.OutputName then
		return ops_str .. " <GridOpName><OutputName></GridOpName>"
	end
	return ops_str .. " <GridOpName><InputName></GridOpName> to <GridOpName><OutputName></GridOpName>"
end

function GridOpInputOutput:SetOutputCurtain(curtain)
	self.OutputCurtain = curtain
	self.OutputPreview = nil
end

function GridOpInputOutput:SetOutputSelect(name)
	self.input_preview = nil
	self.output_preview = nil
	GridOp.SetOutputSelect(self, name)
end

function GridOpInputOutput:GetOutputPreview()
	local preview = self.OutputPreview
	if not preview then
		local output = self.output_preview or self:GetOutputSelectGrid()
		local input = self.input_preview or (self.inputs or empty_table)[self.InputName]
		if output and input then
			local curtain = self.OutputCurtain
			output = ResampleGridForPreview(output)
			self.output_preview = output
			preview = output
			if curtain < 100 then
				input = ResampleGridForPreview(input)
				input = GridRepack(input, IsComputeGrid(output))
				self.input_preview = input
				preview = input
				if curtain > 0 then
					local l = MulDivRound(preview_size, curtain, 100)
					local mask = NewComputeGrid(preview_size, preview_size, "U", 8)
					for x = 0, l do
						GridDrawColumn(mask, x, preview_size - 1, 1, 1, 1)
					end
					preview = GridDest(output)
					GridRepack(mask, preview)
					GridLerp(input, preview, output, preview) 
				end
			end
			self.OutputPreview = preview
		end
	end
	return preview
end

----

local ref_available = function(self) return self.RefName ~= "" end
local grid_fmts = {"", "float", "uint16", "uint8"}
local function GridTypeToFmt(gt)
	if gt == "float" then
		return "f", 32
	elseif gt == "uint16" then
		return "u", 16
	elseif gt == "uint8" then
		return "u", 8
	end
end

DefineClass.GridOpDest = {
	__parents = { "GridOpOutput" },
	properties = {
		{ category = "General", id = "RefName",     name = "Grid Reference", editor = "combo", default = "", items = GridOpOutputNames, grid_input = true, optional = true, help = "Needed to match the same grid size and type" },
		{ category = "General", id = "Width",       name = "Grid Width",     editor = "number", default = 0, min = 0, use_param = true, no_edit = ref_available },
		{ category = "General", id = "Height",      name = "Grid Height",    editor = "number", default = 0, min = 0, use_param = true, no_edit = ref_available },
		{ category = "General", id = "GridType",    name = "Grid Type",      editor = "choice", default = "", items = grid_fmts, no_edit = ref_available },
		{ category = "General", id = "GridDefault", name = "Grid Default",   editor = "number", default = 0 },
	},
	GridOpType = "",
}

function GridOpDest:GetGridOutput(state)
	local ref = self:GetGridInput(self.RefName)
	local value = self.GridDefault
	if ref then
		if value == 0 then
			return nil, GridDest(ref, true)
		else
			local grid = GridDest(ref)
			GridFill(grid, value)
			return nil, grid
		end
	end
	local w = self:GetValue("Width")
	local h = self:GetValue("Height")
	local t, b = GridTypeToFmt(self.GridType)
	if not t then
		return "Grid Type Not Specified"
	end
	local grid = NewComputeGrid(w, h, t, b)
	if value ~= 0 then
		GridFill(grid, value)
	end
	return nil, grid
end

----

DefineClass.GridOpFile = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "General", id = "FileRelative",   name = "File Relative", editor = "bool",   default = true },
		{ category = "General", id = "FileName",       name = "File Name",     editor = "browse", default = "", folder = GridOpBaseDirs, dont_validate = true, allow_missing = function(self) return self.AllowMissing end },
		{ category = "General", id = "FileFormat",     name = "File Format",   editor = "choice", default = "", items = {"", "image", "grid", "raw8", "raw16"} },
		{ category = "Preview", id = "FilePath",       name = "File Path Game",editor = "text",   default = "", read_only = true, dont_save = true },
		{ category = "Preview", id = "FilePathOs",     name = "File Path OS",  editor = "text",   default = "", read_only = true, dont_save = true },
	},
	AllowMissing = false,
	DefaultFormat = "image",
}

function GridOpFile:SetFileName(path)
	if self.FileRelative then
		local dir, fname, ext = SplitPath(path)
		path = fname .. ext
	end
	self.FileName = path
end

function GridOpFile:ResolveFilePath(state)
	if self.FileRelative and not state.base_dir then
		return "Base Dir Not Set"
	end
	if self.FileName == "" then
		return "File Name Expected"
	end
	local path = self.FileName
	if self.FileRelative then
		path = state.base_dir .. path
	end
	if not self.AllowMissing and not io.exists(path) then
		return "File Does Not Exist"
	end
	self.FilePath = path
	return nil, path
end

function GridOpFile:GetFilePathOs()
	return ConvertToOSPath(self.FilePath)
end

function GridOpFile:ResolveFileFormat()
	local fmt = self.FileFormat
	if fmt == "" then
		local ext = string.lower(GetPathExt(self.FileName))
		if ext == "grid" then
			fmt = "grid"
		elseif ext == "r16" then
			fmt = "raw16"
		elseif ext == "raw" or ext == "r8" then
			fmt = "raw8"
		elseif ext == "tga" or ext == "png" or ext == "jpg" then
			fmt = "image"
		else
			fmt = self.DefaultFormat
		end
	end
	return fmt
end

----

local function not_img(op)
	return op:ResolveFileFormat() ~= "image"
end
	
DefineClass.GridOpRead = {
	__parents = { "GridOpOutput", "GridOpFile" },
	properties = {
		{ category = "General", id = "OutputName2",    name = "Output Name 2", editor = "combo",  default = "",    items = GridOpOutputNames, grid_output = true, optional = true, no_edit = not_img},
		{ category = "General", id = "OutputName3",    name = "Output Name 3", editor = "combo",  default = "",    items = GridOpOutputNames, grid_output = true, optional = true, no_edit = not_img },
		{ category = "General", id = "OutputName4",    name = "Output Name 4", editor = "combo",  default = "",    items = GridOpOutputNames, grid_output = true, optional = true, no_edit = not_img },
	},
	GridOpType = "Read",
}

function GridOpRead:GetEditorText()
	local outputs = { "<GridOpName><OutputName></GridOpName>" }
	if self.OutputName2 ~= "" then
		outputs[#outputs + 1] = "<GridOpName><OutputName2></GridOpName>"
	end
	if self.OutputName3 ~= "" then
		outputs[#outputs + 1] = "<GridOpName><OutputName3></GridOpName>"
	end
	if self.OutputName4 ~= "" then
		outputs[#outputs + 1] = "<GridOpName><OutputName4></GridOpName>"
	end
	local str = table.concat(outputs, ", ")
	str = "<GridOpType> " .. str .. " from <GridOpStr><FileName></GridOpStr>"
	if self.FileFormat ~= "" then
		str = str .. " as <GridOpValue><FileFormat></GridOpValue>"
	end
	return str
end

function GridOpRead:GetGridOutput(state)
	local err, path = self:ResolveFilePath(state)
	if err then
		return err
	end
	local grid
	local fmt = self:ResolveFileFormat()
	if fmt == "grid" then
		grid, err = GridReadFile(path)
	elseif fmt == "image" then
		local r, g, b, a = ImageToGrids(path)
		if not r then
			err = g
		else
			grid = r
			if self.OutputName2 ~= "" then
				self:SetGridOutput(self.OutputName2, g)
			end
			if self.OutputName3 ~= "" then
				self:SetGridOutput(self.OutputName3, b)
			end
			if self.OutputName4 ~= "" then
				self:SetGridOutput(self.OutputName4, a)
			end
		end
	elseif fmt == "raw16" then
		grid = NewComputeGrid(0, 0, "U", 16)
		err = GridLoadRaw(path, grid)
	elseif fmt == "raw8" then
		grid = NewComputeGrid(0, 0, "U", 8)
		err = GridLoadRaw(path, grid)
	else
		err = "Unknown File Format"
	end
	return err, grid
end

----

DefineClass.GridOpWrite = {
	__parents = { "GridOpInput", "GridOpFile" },
	properties = {
		{ category = "General", id = "Normalize", name = "Normalize", editor = "bool", default = true, no_edit = not_img },
	},
	GridOpType = "Write",
	FileRelative = false,
	AllowMissing = true,
	DefaultFormat = "",
}

function GridOpWrite:GetEditorText()
	local str = "<GridOpType> <GridOpName><InputName></GridOpName> to <GridOpStr><FileName></GridOpStr>"
	if self.FileFormat ~= "" then
		str = str .. " as <GridOpValue><FileFormat></GridOpValue>"
	end
	return str
end

function GridOpWrite:SetGridInput(state, grid)
	local err, path = self:ResolveFilePath(state)
	if err then
		return err
	end
	local fmt = self:ResolveFileFormat()
	if fmt == "grid" then
		local success
		success, err = GridWriteFile(grid, path)
	elseif fmt == "image" then
		if self.Normalize then
			grid = GridNormalize(grid, GridDest(grid), 0, 255)
		end
		err = GridToImage(path, grid)
	elseif fmt == "raw8" then
		local grid_fmt, grid_bits = IsComputeGrid(grid)
		if grid_fmt ~= "U" or grid_bits ~= 8 then
			return "Incompatible grid format"
		end
		err = GridSaveRaw(path, grid)
	elseif fmt == "raw16" then
		local grid_fmt, grid_bits = IsComputeGrid(grid)
		if grid_fmt ~= "U" or grid_bits ~= 16 then
			return "Incompatible grid format"
		end
		err = GridSaveRaw(path, grid)
	else
		return "Unsupported File Format"
	end
	return err
end

----

local empty_kernel = {
	0, 0, 0,
	0, 1, 0,
	0, 0, 0
}

local function GridFilters()
	return {
		{
			value = "",
			name = "Custom",
		},
		{
			value = "none",
			name = "None",
			kernel = empty_kernel,
		},
		{
			value = "gaussian",
			name = "Blur (Gaussian)",
			kernel = {
				1, 2, 1,
				2, 4, 2,
				1, 2, 1
			},
			scale = 16,
		},
		{
			value = "box",
			name = "Blur (Box)",
			kernel = {
				1, 1, 1,
				1, 1, 1,
				1, 1, 1
			},
			scale = 9,
		},
		{
			value = "laplacian",
			name = "Edges (Laplacian)",
			kernel = {
				-1, -1, -1,
				-1,  8, -1,
				-1, -1, -1,
			},
			scale = 8,
		},
		{
			value = "sobel",
			name = "Slope (Sobel)",
			kernel = {
				-2, -2,  0,
				-2,  0,  2,
				 0,  2,  2,
			},
			scale = 6,
		},
		{
			value = "sharpen",
			name = "Sharpen",
			kernel = {
				 0, -1,  0,
				-1,  5, -1,
				 0, -1,  0
			},
			scale = 1,
		},
	}
end

DefineClass.GridOpFilter = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Intensity",   name = "Filter Degree",  editor = "number",     default = 1, min = 1, max = 10, step = 1, buttons_step = 1, slider = true, help = "Defines the filter strength" },
		{ category = "General", id = "Strength",    name = "Filter Strength",editor = "number",     default = 100, min = 0, max = 100, scale = "%", slider = true },
		{ category = "General", id = "Filter",      name = "Filter Preset",  editor = "choice",     default = "none", items = GridFilters, dont_save = true, operation = "Convolution" },
		{ category = "General", id = "Kernel",      name = "Filter Kernel",  editor = "prop_table", default = empty_kernel, operation = "Convolution" },
		{ category = "General", id = "Scale",       name = "Filter Scale",   editor = "number",     default = 0, operation = "Convolution" },
		{ category = "General", id = "Fast",        name = "Fast Mode",      editor = "bool",       default = true, operation = "Smooth" },
		{ category = "General", id = "RestoreLims", name = "Restore Limits", editor = "bool",       default = false },
	},
	input_fmt = "F",
	GridOpType = "Filter",
	operations = {"Smooth", "Convolution"},
}

function GridOpFilter:SetFilter(value)
	local filter = table.find_value(GridFilters(), "value", value) or empty_table
	if not filter.kernel then
		return
	end
	self.Kernel = table.icopy(filter.kernel)
	self.Scale = filter.scale
end

function GridOpFilter:GetFilter()
	local kernel = self.Kernel
	local scale = self.Scale
	for _, filter in ipairs(GridFilters()) do
		if scale == (filter.scale or 0) and table.iequal(kernel, filter.kernel) then
			return filter.value
		end
	end
	return ""
end

function GridOpFilter:GetGridOutputFromInput(state, grid)
	local strength = self.Strength
	if strength == 0 then
		return nil, grid:clone()
	end
	local filtered
	local count = self.Intensity
	local op = self.Operation
	local restore = self.RestoreLims
	if op == "Convolution" then
		local kernel = self.Kernel
		if not kernel then
			return "Missing kernel"
		end
		local scale = self.Scale
		local tmp = GridDest(grid)
		filtered = grid
		for i=1,count do
			GridFilter(filtered, tmp, kernel, scale, restore)
			filtered, tmp = tmp, filtered
		end
	elseif op == "Smooth" then
		filtered = GridDest(grid)
		local w, h = grid:size()
		local fast = self.Fast
		if fast and (not IsPowerOf2(w) or not IsPowerOf2(h)) then
			fast = false
			state.proc:AddLog("Ignoring Fast smooth - the grid size is not a power of 2")
		end
		GridSmooth(grid, filtered, count, fast, restore)
	end
	if strength < 100 then
		GridLerp(grid, filtered, filtered, strength, 0, 100)
	end
	return nil, filtered
end

function GridOpFilter:GetEditorText()
	local op = self.Operation
	local str_intensity = self.Intensity > 1 and " (<GridOpValue>x" .. self.Intensity .. "</GridOpValue>)" or ""
	if op == "Smooth" then
		local str = "Smooth <GridOpName><InputName></GridOpName>" .. str_intensity
		if self.InputName ~= self.OutputName then
			str = str .. " to <GridOpName><OutputName></GridOpName>"
		end
		return str
	elseif op == "Convolution" then
		local str = "Apply <GridOpValue><Filter></GridOpValue> filter" .. str_intensity .. " in <GridOpName><InputName></GridOpName>"
		if self.InputName ~= self.OutputName then
			str = str .. " to <GridOpName><OutputName></GridOpName>"
		end
		return str
	end
	return GridOpInputOutput.GetEditorText(self)
end

----

DefineClass.GridOpLerp = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "TargetName", name = "Target Grid Name",  editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true },
		{ category = "General", id = "MaskName",   name = "Mask Grid Name",    editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true },
		{ category = "General", id = "Normalize",  name = "Mask Normalize",    editor = "bool",   default = true },
		{ category = "General", id = "MaskMin",    name = "Mask Min",          editor = "number", default = 0, enabled_by = "!Normalize" },
		{ category = "General", id = "MaskMax",    name = "Mask Max",          editor = "number", default = 100, enabled_by = "!Normalize" },
		{ category = "General", id = "Convert",    name = "Convert Grids",     editor = "bool",   default = true, help = "Allow converting the grid params to match" },
	},
	GridOpType = "Lerp",
}

function GridOpLerp:GetGridOutputFromInput(state, grid)
	local target = self:GetGridInput(self.TargetName)
	local mask = self:GetGridInput(self.MaskName)
	if self.Convert then
		target = GridMakeSame(target, grid)
		mask = GridMakeSame(mask, grid)
	end
	local res = GridDest(grid)
	if self.Normalize then
		GridLerp(grid, res, target, mask)
	else
		GridLerp(grid, res, target, mask, self.MaskMin, self.MaskMax)
	end
	return nil, res
end

function GridOpLerp:GetEditorText()
	return "Lerp <GridOpName><InputName></GridOpName> - <GridOpName><TargetName></GridOpName> in <GridOpName><OutputName></GridOpName>"
end

----

----

DefineClass.GridOpMorph = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Depth", name = "Depth",  editor = "number", default = 1, min = 1 },
	},
	GridOpType = "Binary Morphology",
	operations = {"Erode", "Dilate", "Open", "Close"},
}

function GridOpMorph:GetGridOutputFromInput(state, grid)
	local dst, src = grid, GridDest(grid)
	local function do_morph(erode)
		local depth = self.Depth
		while depth > 0 do
			src, dst = dst, src
			if dst == grid then
				dst = GridDest(grid)
			end
			if erode then
				GridErode(src, dst)
			else
				GridDilate(src, dst)
			end
			depth = depth - 1
		end
	end
	local op = self.Operation
	if op == "Erode" then
		do_morph(true)
	elseif op == "Dilate" then
		do_morph(false)
	elseif op == "Open" then
		do_morph(true)
		do_morph(false)
	elseif op == "Close" then
		do_morph(false)
		do_morph(true)
	end
	return nil, dst
end

function GridOpMorph:GetEditorText()
	local str = "Morphologically <Operation> <GridOpName><InputName></GridOpName>"
	if self.Depth > 1 then
		str = str .. " x <GridOpValue><Depth></GridOpValue>"
	end
	if self.InputName ~= self.OutputName then
		str = str .. " to <GridOpName><OutputName></GridOpName>"
	end
	return str
end

----

DefineClass.GridOpConvert = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "GridType",    name = "Grid Type",      editor = "choice", default = "", items = {"", "float", "uint16", "uint8"}, operation = "Repack", no_edit = ref_available },
		{ category = "General", id = "RefName",     name = "Grid Reference", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true, operation = "Repack", help = "Needed to match the same grid type" },
		{ category = "General", id = "GridRound",   name = "Grid Round",     editor = "bool",   default = false, operation = "Repack" },
		{ category = "General", id = "Granularity", name = "Granularity",    editor = "number", default = 1, operation = "Round" },
	},
	GridOpType = "Convert",
	operations = {"Invert", "Abs", "Not", "Round", "Copy", "Repack"},
}

function GridOpConvert:GetGridOutputFromInput(state, grid)
	local op = self.Operation
	if op == "Repack" then
		local t, b = GridTypeToFmt(self.GridType)
		if not t then
			local ref = self:GetGridInput(self.RefName)
			t, b = IsComputeGrid(ref)
			if not t then
				return "Grid Type Not Specified"
			end
		end
		local src = grid
		if self.GridRound then
			src = GridDest(src)
			GridRound(grid, src)
		end
		return nil, GridRepack(src, t, b, true)
	end
	local res = GridDest(grid)
	if op == "Abs" then
		GridAbs(grid, res)
	elseif op == "Not" then
		GridNot(grid, res)
	elseif op == "Invert" then
		GridInvert(grid, res)
	elseif op == "Round" then
		GridRound(grid, res, self.Granularity)
	elseif op == "Copy" then
		res:copy(grid)
	end
	return nil, res
end

function GridOpConvert:GetEditorText()
	local text = "<Operation>"
	if self.InputName ~= "" then
		text = text .. " <GridOpName><InputName></GridOpName>"
		if self.OutputName ~= "" and self.InputName ~= self.OutputName then
			text = text .. " to <GridOpName><OutputName></GridOpName>"
		end
	end
	if self.Operation == "Repack" then
		text = text .. " as <GridOpStr><GridType></GridOpStr>"
	end
	return text
end

----

local function ExtendModeItems()
	return {
		{ value = 0, text = "" },
		{ value = 1, text = "Filled" },
		{ value = 2, text = "Centered" },
	}
end

DefineClass.GridOpResample = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "RefName",       name = "Ref Name",       editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true, help = "Needed to match the same grid size and type" },
		{ category = "General", id = "Width",         name = "Width",          editor = "number", default = 256, min = 0, use_param = true, enabled_by = "!RefName" },
		{ category = "General", id = "Height",        name = "Height",         editor = "number", default = 256, min = 0, use_param = true, enabled_by = "!RefName" },
		{ category = "General", id = "InPercents",    name = "In Percents",    editor = "bool",   default = false, enabled_by = "!RefName" },
		{ category = "General", id = "Interpolate",   name = "Interpolate",    editor = "bool",   default = true, operation = "Resample" },
		{ category = "General", id = "RestoreLims",   name = "Restore Limits", editor = "bool",   default = false, operation = "Resample" },
		{ category = "General", id = "ExtendMode",    name = "Mode",           editor = "choice", default = 0, items = ExtendModeItems, operation = "Extend" },
	},
	GridOpType = "Change Dimensions",
	operations = {"Resample", "Extend"},
	operation_text_only = true,
}

local function CanFastResample(dim2, dim1)
	if dim2 == dim1 then
		return
	end
	local dir = 1
	if dim1 > dim2 then
		dim2, dim1 = dim1, dim2
		dir = -1
	end
	if dim2 % dim1 ~= 0 then
		return
	end
	local k = dim2 / dim1
	if not IsPowerOf2(k) then
		return
	end
	return k * dir
end

function GridOpResample:GetGridOutputFromInput(state, grid)
	local w, h
	local gw, gh = grid:size()
	local ref = self:GetGridInput(self.RefName)
	if ref then
		w, h = ref:size()
	else
		w = self:GetValue("Width")
		h = self:GetValue("Height")
		if self.InPercents then
			w = MulDivRound(gw, w, 100)
			h = MulDivRound(gh, h, 100)
		end
	end
	if w == 0 or h == 0 then
		return "Invalid Size"
	end
	if w == gw and h == gh then
		return nil, grid:clone()
	end
	local op = self.Operation
	if op == "Resample" then
		local interpolate, restore = self.Interpolate, self.RestoreLims
		if interpolate then
			local kw, kh = CanFastResample(gw, w), CanFastResample(gh, h)
			if kw and kw == kh then
				while gw < w do
					gw, gh = 2 * gw, 2 * gh
					grid = GridResample(grid, gw, gh, true, restore)
				end
				while gw > w do
					gw, gh = gw / 2, gh / 2
					grid = GridResample(grid, gw, gh, true, restore)
				end
				return nil, grid
			end
		end
		return nil, GridResample(grid, w, h, interpolate, restore, true)
	elseif op == "Extend" then
		return nil, GridExtend(grid, w, h, self.ExtendMode)
	end
end

function GridOpResample:GetEditorText()
	if self.InputName == "" or self.OutputName == "" then
		return "<GridOpType>"
	end
	local str = "<Operation> <GridOpName><InputName></GridOpName>"
	if self.InputName ~= self.OutputName then
		str = str .. " in <GridOpName><OutputName></GridOpName>"
	end
	if self.RefName ~= "" then
		str = str .. " as <GridOpName><RefName></GridOpName>"
	else
		local wstr, w = self:GetValueText("Width")
		local hstr, h = self:GetValueText("Height")
		if not self.InPercents then
			str = str .. " to (" .. wstr .. ", " .. hstr .. ")"
		elseif w ~= h then
			str = str .. " to (" .. wstr .. "%, " .. hstr .. "%)"
		else
			str = str .. " to " .. wstr .. "%"
		end
	end
	return str
end

----

DefineClass.GridOpChangeLim = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Min",       name = "Min",       editor = "number", default = 0, use_param = true },
		{ category = "General", id = "Max",       name = "Max",       editor = "number", default = 1, use_param = true },
		{ category = "General", id = "Scale",     name = "Scale",     editor = "number", default = 1, use_param = true },
		{ category = "General", id = "Smooth",    name = "Smooth",    editor = "bool",   default = false },
		{ category = "General", id = "Remap",     name = "Remap",     editor = "bool",   default = false },
		{ category = "General", id = "RemapMin",  name = "Remap Min", editor = "number", default = 0, use_param = true, enabled_by = "Remap" },
		{ category = "General", id = "RemapMax",  name = "Remap Max", editor = "number", default = 1, use_param = true, enabled_by = "Remap" },
	},
	operations = {"Normalize", "Mask", "Clamp", "Band", "Remap"},
	GridOpType = "Change Limits",
}

function GridOpChangeLim:GetGridOutputFromInput(state, grid)
	local min = self:GetValue("Min")
	local max = self:GetValue("Max")
	local scale = self:GetValue("Scale")
	local new_min, new_max
	local op = self.Operation
	local res = GridDest(grid)
	if op == "Normalize" then
		if min >= max then
			return "Invalid Range"
		end
		res = GridNormalize(grid, res, min, max, scale)
	elseif op == "Mask" then
		GridMask(grid, res, min, max, scale)
		min, max = 0, 1
	elseif op == "Clamp" then
		if min >= max then
			return "Invalid Range"
		end
		GridClamp(grid, res, min, max, scale)
	elseif op == "Band" then
		if min >= max then
			return "Invalid Range"
		end
		GridBand(grid, res, min, max, scale)
	elseif op == "Remap" then
		res:copy(grid)
	elseif op == "Max" then
		GridMax(grid, res, min, scale)
	elseif op == "Min" then
		GridMin(grid, res, max, scale)
	end
	if self.Smooth and not GridIsFlat(res) then
		GridSin(res, min, max)
		new_min, new_max = min, max
		min, max = -1, 1
	end
	if self.Remap then
		new_min = self:GetValue("RemapMin")
		new_max = self:GetValue("RemapMax")
	end
	if min ~= (new_min or min) or max ~= (new_max or max) then
		GridRemap(res, min, max, new_min, new_max)
	end
	return nil, res
end

function GridOpChangeLim:GetEditorText()
	local min_str = self:GetValueText("Min")
	local max_str = self:GetValueText("Max")
	local range_str, grids_str, remap_str = " between ", "", ""
	if self.InputName ~= "" then
		grids_str = " <GridOpName><InputName></GridOpName>"
		if self.OutputName ~= "" and self.InputName ~= self.OutputName then
			grids_str = grids_str .. " to <GridOpName><OutputName></GridOpName>"
		end
	end
	if self.Remap then
		local from_str = self:GetValueText("RemapMin")
		local to_str = self:GetValueText("RemapMax")
		remap_str = " to " .. from_str .. " - " .. to_str
		range_str = " from "
	end
	return "<Operation>" .. grids_str .. range_str .. min_str .. " - " .. max_str .. remap_str
end

----

----

DefineClass.GridOpMinMax = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "RefName",  name = "Grid Name", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true },
		{ category = "General", id = "RefValue", name = "Value",     editor = "number", default = 0, use_param = true, enabled_by = "!GridName" },
		{ category = "General", id = "Scale",    name = "Scale",     editor = "number", default = 1, use_param = true },
	},
	operations = {"Min", "Max"},
	GridOpType = "MinMax",
}

function GridOpMinMax:GetGridOutputFromInput(state, grid)
	local ref_value, scale = self:GetValue("RefValue"), self:GetValue("Scale")
	local ref_grid = self:GetGridInput(self.RefName)
	local op = self.Operation
	local res = GridDest(grid)
	if op == "Max" then
		if ref_grid then
			GridMax(grid, res, ref_grid)
		else
			GridMax(grid, res, ref_value, scale)
		end
	elseif op == "Min" then
		if ref_grid then
			GridMin(grid, res, ref_grid)
		else
			GridMin(grid, res, ref_value, scale)
		end
	end
	return nil, res
end

function GridOpMinMax:GetEditorText()
	if self.InputName == "" or self.OutputName == "" then
		return "<GridOpType>"
	end
	local str = "<GridOpName><OutputName></GridOpName> = <Operation>(<GridOpName><InputName></GridOpName>, "
	if self.RefName ~= "" then
		str = str .. "<GridOpName><RefName></GridOpName>"
	else
		str = str .. self:GetValueText("RefValue")
	end
	return str .. ")"
end

----

DefineClass.GridOpMulDivAdd = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "MulName",   name = "Mul Grid Name", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true },
		{ category = "General", id = "AddName",   name = "Add Grid Name", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true },
		{ category = "General", id = "SubName",   name = "Sub Grid Name", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true },
		{ category = "General", id = "Mul",       name = "Mul",           editor = "number", default = 1, use_param = true },
		{ category = "General", id = "Div",       name = "Div",           editor = "number", default = 1, use_param = true },
		{ category = "General", id = "Add",       name = "Add",           editor = "number", default = 0, use_param = true },
		{ category = "General", id = "Sub",       name = "Sub",           editor = "number", default = 0, use_param = true },
		{ category = "General", id = "Convert",   name = "Convert Grids", editor = "bool",   default = true, help = "Allow converting the grid params to match" },
	},
	GridOpType = "Mul Div Add",
}

function GridOpMulDivAdd:GetGridOutputFromInput(state, grid)
	local grid_mul = self:GetGridInput(self.MulName)
	local grid_add = self:GetGridInput(self.AddName)
	local grid_sub = self:GetGridInput(self.SubName)
	local mul = self:GetValue("Mul")
	local div = self:GetValue("Div")
	local add = self:GetValue("Add")
	local sub = self:GetValue("Sub")
	if div == 0 then
		return "Division By Zero"
	end
	local res = grid:clone()
	if grid_mul then
		if self.Convert then
			grid_mul = GridMakeSame(grid_mul, res)
		end
		GridMulDiv(res, grid_mul, 1)
	end
	GridMulDiv(res, mul, div)
	GridAdd(res, add - sub)
	if grid_add then
		if self.Convert then
			grid_add = GridMakeSame(grid_add, res)
		end
		GridAdd(res, grid_add)
	end
	if grid_sub then
		if self.Convert then
			grid_sub = GridMakeSame(grid_sub, res)
		end
		GridAddMulDiv(res, grid_sub, -1)
	end
	return nil, res
end

function GridOpMulDivAdd:GetEditorText()
	local txt = "<GridOpType>"
	local negate = self:GetValue("Mul") == -1
	if self.OutputName ~= "" and self.InputName ~= "" then
		txt = "<GridOpName><OutputName></GridOpName> = "
		if negate then
			txt = txt .. "-"
		end
		txt = txt .. "<GridOpName><InputName></GridOpName>"
	end
	if self.MulName ~= "" then
		txt = txt .. " x <GridOpName><MulName></GridOpName>"
	end
	local mul_str = not negate and self:GetValueText("Mul", 1) or ""
	local div_str = self:GetValueText("Div", 1)
	local add_str = self:GetValueText("Add", 0)
	local sub_str = self:GetValueText("Sub", 0)
	if mul_str ~= "" then
		txt = txt .. " x " .. mul_str
	end
	if div_str ~= "" then
		txt = txt .. " / " .. div_str
	end
	if add_str ~= "" then
		txt = txt .. " + " .. add_str
	end
	if sub_str ~= "" then
		txt = txt .. " - " .. sub_str
	end
	if self.AddName ~= "" then
		txt = txt .. " + <GridOpName><AddName></GridOpName>"
	end
	if self.SubName ~= "" then
		txt = txt .. " - <GridOpName><SubName></GridOpName>"
	end
	
	return txt
end

----

DefineClass.GridOpReplace = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Old", name = "Old", editor = "number", default = 0, use_param = true },
		{ category = "General", id = "New", name = "New", editor = "number", default = 1, use_param = true },
	},
	GridOpType = "Replace",
}

function GridOpReplace:GetGridOutputFromInput(state, grid)
	local old = self:GetValue("Old")
	local new = self:GetValue("New")
	local res = GridDest(grid)
	res = GridReplace(grid, res, old, new)
	return nil, res
end

function GridOpReplace:GetEditorText()
	local old_str = self:GetValueText("Old")
	local new_str = self:GetValueText("New")
	return "<GridOpType> " .. old_str .. " by " .. new_str .. " in <GridOpName><InputName></GridOpName> to <GridOpName><OutputName></GridOpName>"
end

----

DefineClass.GridOpRandPos = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Tile",       name = "Tile",       editor = "number", default = 1, use_param = true },
		{ category = "General", id = "Count",      name = "Count",      editor = "number", default = -1, use_param = true },
		{ category = "General", id = "ForEachPos", name = "ForEachPos", editor = "func",   default = false, lines = 1, max_lines = 100, params = "x, y, v, area, tile, state", },
	},
	GridOpType = "Rand Pos",
}

function GridOpRandPos:GetGridOutputFromInput(state, grid)
	local tile = self:GetValue("Tile")
	local min, max = GridMinMax(grid)
	local output, remap
	local limit = 0xffff
	if min < 0 or max > limit then
		remap = true
		output = GridDest(grid)
		GridMax(grid, output, 0)
		GridMulDiv(output, limit, max)
		output = GridRepack(output, "u", 16)
	else
		output = GridRepack(grid, "u", 16, true)
	end
	local count = 0
	local max_count = self:GetValue("Count")
	GridRandomEnumMarkDist(output, state.rand, tile, function(x, y, v, area)
		if count == max_count then
			return
		end
		count = count + 1
		if remap then
			v = v * limit / max
		end
		local success, radius = pcall(self.ForEachPos, x, y, v, area, tile, state) -- todo: debug missing error propagation
		if not success or not radius then
			return
		end
		if remap then
			radius = radius * max / limit
		end
		return radius
	end)
	return nil, output
end

----

DefineClass.GridOpDistance = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Min",  name = "Min",  editor = "number", default = 0, use_param = true },
		{ category = "General", id = "Max",  name = "Max",  editor = "number", default = -1, use_param = true },
		{ category = "General", id = "Tile", name = "Tile", editor = "number", default = 1, use_param = true },
	},
	GridOpType = "Distance",
	operations = {"Transform", "Wave"},
}

function GridOpDistance:GetGridOutputFromInput(state, grid)
	local op = self.Operation
	local res = GridDest(grid)
	local tile, max_dist, min_dist = self:GetValue("Tile"), self:GetValue("Max"), self:GetValue("Min")
	if max_dist < 0 then
		max_dist = max_int
	end
	if op == "Transform" then
		GridDistance(grid, res, tile, max_dist)
	elseif op == "Wave" then
		GridWave(grid, res, tile, max_dist)
	end
	if min_dist > 0 then
		GridBand(res, min_dist, max_dist)
	end
	return nil, res
end

----

DefineClass.GridOpEnumAreas = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "MinArea",    name = "Min Tiles Count", editor = "number", default = 0, use_param = true, min = 0, help = "Will be computed based on the min border distance if not specified" },
		{ category = "General", id = "MinBorder",  name = "Min Border Dist", editor = "number", default = 0, min = 0, use_param = true },
		{ category = "General", id = "Tile",       name = "Tile Size",       editor = "number", default = 1, min = 1, use_param = true },
		{ category = "Stats",   id = "AreasCount", name = "Areas Found",     editor = "number", default = 0, read_only = true, dont_save = true },
	},
	GridOpType = "Enum Areas",
}

function GridOpEnumAreas:GetGridOutputFromInput(state, grid)
	local tile, min_border, min_area = self:GetValue("Tile"), self:GetValue("MinBorder"), self:GetValue("MinArea")
	min_area = Max(min_area, (min_border * min_border * 22) / (tile * tile * 7))
	if min_area == 0 then
		return "Zero area size"
	end
	local work_grid = min_border > max_uint16 and GridRepack(grid, "f") or grid
	local zones = GridEnumZones(work_grid, min_area)
	local level_dist
	local gw, gh = work_grid:size()
	local found = 0
	local res = GridDest(work_grid)
	res:clear()
	for i=1,#zones do
		local zone = zones[i]
		level_dist = level_dist or GridDest(work_grid)
		GridMask(work_grid, level_dist, zone.level)
		local accepted = true
		if min_border > 0 then
			GridDistance(level_dist, tile, min_border)
			local minv, maxv = GridMinMax(level_dist)
			accepted = maxv >= min_border
		end
		if accepted then
			found = found + 1
			GridPaint(res, level_dist, found)
		end
	end
	self.AreasCount = found
	if found == 0 then
		return "No areas found"
	end
	res = GridRepack(res, IsComputeGrid(grid))
	return nil, res
end

----

DefineClass.GridOpMean = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "OperandName", name = "Second Operand", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true },
	},
	GridOpType = "Mean",
	input_fmt = "F",
	operations = {"Arithmetic", "Geometric", "Root Square"},
}

function GridOpMean:GetGridOutputFromInput(state, grid)
	local operand = self:GetGridInput(self.OperandName)
	local op = self.Operation
	local res = GridDest(grid)
	if op == "Arithmetic" then
		GridAdd(grid, res, operand)
		GridMulDiv(res, 1, 2)
	elseif op == "Geometric" then
		GridMulDiv(grid, res, operand)
		GridPow(res, 1, 2)
	else
		local res2 = GridDest(grid)
		GridPow(grid, res, 2)
		GridPow(operand, res2, 2)
		GridAdd(res, res2)
		GridPow(res, 1, 2)
		res2:free()
	end
	return nil, res
end

function GridOpMean:GetEditorText()
	return "<Operation> <GridOpType> <GridOpName><InputName></GridOpName> and <GridOpName><OperandName></GridOpName> into <GridOpName><OutputName></GridOpName>"
end

----

DefineClass.GridOpPow = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "PowMul", name = "Pow Mul", editor = "number", default = 1, min = 1, },
		{ category = "General", id = "PowDiv", name = "Pow Div", editor = "number", default = 1, min = 1, },
	},
	GridOpType = "Pow",
	input_fmt = "F",
}

function GridOpPow:GetGridOutputFromInput(state, grid)
	local res = GridDest(grid)
	GridPow(grid, res, self.PowMul, self.PowDiv)
	return nil, res
end

function GridOpPow:GetEditorText()
	return "<GridOpName><OutputName></GridOpName> = <GridOpName><InputName></GridOpName> ^ (<GridOpValue><PowMul></GridOpValue>/<GridOpValue><PowDiv></GridOpValue>)"
end

----

DefineClass.GridOpNoise = {
	__parents = { "GridOpDest", "PerlinNoiseBase" },
	properties = {
		{ category = "General", id = "NoisePreset", name = "Noise Preset", editor = "preset_id", default = "", preset_class = "NoisePreset" },
	},
	GridOpType = "Noise",
}

function GridOpNoise:GetGridOutput(state)
	local ref = self:GetGridInput(self.RefName)
	local err, noise
	if ref then
		noise = GridDest(ref)
	else
		err, noise = GridOpDest.GetGridOutput(self, state)
		if err then
			return err
		end
	end
	if self.NoisePreset ~= "" then
		local preset = NoisePresets[self.NoisePreset]
		if not preset then
			return "No such noise preset " .. self.NoisePreset
		end
		preset:GetNoise(state.rand, noise)
	elseif not GridPerlin(state.rand, self:ExportOctaves(), noise) then
		return "Perlin Noise Failed"
	end
	return nil, noise
end

function GridOpNoise:GetEditorText()
	return "Generate Noise in <GridOpName><OutputName></GridOpName>"
end

----

DefineClass.GridOpDistort = {
	__parents = { "GridOpInputOutput", "PerlinNoiseBase" },
	properties = {
		{ category = "General", id = "Strength",   name = "Strength",   editor = "number", default = 50,  min = 0, max = 100, scale = 100, slider = true, help = "Distortion Strength" },
		{ category = "General", id = "Scale",      name = "Scale",      editor = "number", default = 100, min = 1, max = 1000, scale = 100, slider = true, help = "Distortion Strength" },
		{ category = "General", id = "Iterations", name = "Iterations", editor = "number", default = 1,  min = 1, max = 10, slider = true, help = "Distortion Iterations" },
		{ category = "General", id = "NoiseX",     name = "Noise X",    editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, grid_output = true, optional = true },
		{ category = "General", id = "NoiseY",     name = "Noise Y",    editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, grid_output = true, optional = true },
		{ category = "General", id = "NoiseAmp",   name = "Noise Amp",  editor = "number", default = 4096, min = 1 },
	},
	GridOpType = "Distort",
}

function GridOpDistort:GetGridOutputFromInput(state, grid)
	local unity = self.NoiseAmp
	local noise_x = self:GetGridInput(self.NoiseX)
	local noise_y = self:GetGridInput(self.NoiseY)
	if not noise_x then
		noise_x, noise_y = GridDest(grid), GridDest(grid)
		if not GridPerlin(state.rand, self:ExportOctaves(), noise_x, noise_y) then
			return "Perlin Noise Failed"
		end
		GridNormalize(noise_x, 0, unity)
		GridNormalize(noise_y, 0, unity)
	end
	local stength = MulDivRound(self.Scale * unity, self.Strength, 1000 * 100)
	local src, res = grid, grid
	for i=1,self.Iterations do
		src, res = res, src
		res = res == grid and GridDest(grid) or res
		if not GridPerturb(src, res, noise_x, noise_y, stength, unity) then
			return "Grid Perturb Failed"
		end
	end
	self:SetGridOutput(self.NoiseX, noise_x)
	self:SetGridOutput(self.NoiseY, noise_y)
	return nil, res
end

----

DefineClass.GridOpDraw = {
	__parents = { "GridOpDest" },
	properties = {
		{ category = "General", id = "DrawValue",   name = "Value",   editor = "number", default = 1 },
		{ category = "General", id = "DrawBorder",  name = "Border",  editor = "number", default = 1, min = 1, use_param = true, operation = "Frame" },
		{ category = "General", id = "DrawBox",     name = "Box",     editor = "box",    default = false, operation = "Box" },
		{ category = "General", id = "DrawCenter",  name = "Center",  editor = "point",  default = false, operation = "Circle" },
		{ category = "General", id = "DrawRadius",  name = "Radius",  editor = "number", default = false, min = 1, operation = "Circle" },
		{ category = "General", id = "DrawFallout", name = "Fallout", editor = "number", default = 0, min = 0, operation = "Circle" },
	},
	GridOpType = "Draw",
	operations = {"Frame", "Box", "Circle", "Blank"},
}

function GridOpDraw:GetGridOutput(state)
	local err, res = GridOpDest.GetGridOutput(self, state)
	if err then
		return err
	end
	local op = self.Operation
	if op == "Frame" then
		GridFrame(res, self:GetValue("DrawBorder"), self.DrawValue)
	elseif op == "Box" then
		GridDrawBox(res, self.DrawBox, self.DrawValue)
	elseif op == "Circle" then
		local center = self.DrawCenter or point(res:size()) / 2
		local radius = self.DrawRadius or Min(res:size()) / 2
		GridCircleSet(res, self.DrawValue, center, radius + self.DrawFallout, self.DrawFallout)
	end
	return nil, res
end

----

local function show_not_grid(op)
	return op.Show ~= "grid"
end

local function no_edit_colors(op)
	return op.Show ~= "grid" or op.ColorRand
end

local function no_rand_colors(op)
	return op.Show ~= "grid" or not op.ColorRand
end

DefineClass.GridOpDbg = {
	__parents = { "GridOp", "DebugOverlayControl" },
	properties = {
		{ category = "General", id = "Show",         name = "Show",          editor = "choice", default = "grid",items = {"clear", "grid", "biome", "passability", "grass" } },
		{ category = "General", id = "Grid",         name = "Grid",          editor = "choice", default = "",    items = GridOpOutputNames, grid_input = true, optional = true, no_edit = function(self) return self.Show ~= "grid" end },
		{ category = "General", id = "AllowInspect", name = "Allow Inspect", editor = "bool",   default = false, no_edit = show_not_grid },
		{ category = "General", id = "ColorRand",    name = "Color Rand",    editor = "bool",   default = false, no_edit = show_not_grid },
		{ category = "General", id = "InvalidValue", name = "Invalid Value", editor = "number", default = -1,    no_edit = no_rand_colors },
		{ category = "General", id = "Granularity",  name = "Granularity",   editor = "number", default = 1,     no_edit = show_not_grid },
		{ category = "General", id = "ColorFrom",    name = "Color From",    editor = "color",  default = red,   no_edit = no_edit_colors },
		{ category = "General", id = "ColorTo",      name = "Color To",      editor = "color",  default = green, no_edit = no_edit_colors },
		{ category = "General", id = "ColorLimits",  name = "Color Limits",  editor = "bool",   default = false, no_edit = no_edit_colors },
		{ category = "General", id = "ColorMin",     name = "Color Min",     editor = "color",  default = 0,     no_edit = no_edit_colors, enabled_by = "ColorLimits" },
		{ category = "General", id = "ColorMax",     name = "Color Max",     editor = "color",  default = blue,  no_edit = no_edit_colors, enabled_by = "ColorLimits" },
		{ category = "General", id = "Normalize",    name = "Normalize",     editor = "bool",   default = true,  no_edit = no_edit_colors },
		{ category = "General", id = "ValueMin",     name = "Value Min",     editor = "number", default = 0,     no_edit = no_edit_colors, enabled_by = "!Normalize" },
		{ category = "General", id = "ValueMax",     name = "Value Max",     editor = "number", default = 1,     no_edit = no_edit_colors, enabled_by = "!Normalize" },
		{ category = "General", id = "OverlayAlpha", name = "Overlay Alpha (%)", editor = "number", default = 60, slider = true, buttons_step = 1, min = 0, max = 100, dont_save = true, dont_recalc = true },
		{ category = "General", id = "WaitFrames",   name = "Wait Frames",   editor = "number", default = 0 },
		{ category = "General", id = "Invalidate",   name = "Invalidate",    editor = "bool",   default = false },
	},
	GridOpType = "Debug",
	RunModes = set("Debug", "Release"),
	palette = false,
}

function GridOpDbg:Run(state)
	if GetMap() == "" then
		return "No Map Loaded"
	end
	local show = self.Show
	if show == "clear" then
		hr.TerrainDebugDraw = 0
	elseif show == "grid" then
		local grid = self:GetGridInput(self.Grid)
		if not grid then
			return
		end
		local dbg_grid = grid
		local palette = self.palette or {}
		if self.ColorRand then
			local invalid = self.InvalidValue
			for i=0,255 do
				palette[i] = i == invalid and 0 or RandColor(i)
			end
			if self.Granularity ~= 1 then
				dbg_grid = GridDest(grid)
				GridRound(grid, dbg_grid, self.Granularity)
			end
		else
			dbg_grid = GridDest(grid)
			if self.Normalize then
				GridNormalize(grid, dbg_grid, 0, 255)
			else
				GridRemap(grid, dbg_grid, self.ValueMin, self.ValueMax, 0, 255)
			end
			local cfrom, cto = self.ColorFrom, self.ColorTo
			local InterpolateRGB = InterpolateRGB
			for i=1,254 do
				palette[i] = InterpolateRGB(cfrom, cto, i, 255)
			end
			if self.ColorLimits then
				palette[0], palette[255] = self.ColorMin, self.ColorMax
			else
				palette[0], palette[255] = cfrom, cto
			end
		end
		self.palette = palette
		DbgShowTerrainGrid(dbg_grid, palette)
		if self.AllowInspect then
			DbgStartInspectPos(function(pos)
				if not self.AllowInspect then
					return
				end
				local mx, my = pos:xy()
				local gv, gx, gy = GridMapGet(grid, mx, my, 1, 100)
				return string.format("%s(%d : %d) = %s\n", self.Grid, gx, gy, DivToStr(gv, 100))
			end)
		end
		
	else
		hr.TerrainDebugDraw = 1
		local palette
		if show == "biome" then
			palette = DbgGetBiomePalette()
		end
		DbgSetTerrainOverlay(show, palette)
	end
	if self.Invalidate then
		state.proc:InvalidateProc(state)
	end
	if self.WaitFrames ~= 0 then
		WaitNextFrame(self.WaitFrames)
	end
end

--[[ Example
function DebugGrid3D()
	local grid_width = 64
	local grid_height = 64
	local grid_depth = 64
	local grid = NewComputeGrid(grid_width, grid_height * grid_depth, "U", 8)
	GridAdd(grid, 255)
	DbgSetTerrainOverlay3D("grid", 0, grid, 179178, 170817, 6949, grid_width, grid_height, grid_depth, 1200, 1200, 700)
	
	hr.TerrainDebug3DDraw = 1
end]]

if FirstLoad then
	g_ShowPassability3DThread = false
end

function EnablePassability3DVisualization(enable)
	DeleteThread(g_ShowPassability3DThread)
	if enable then
		hr.TerrainDebug3DDraw = 1
		g_ShowPassability3DThread = CreateRealTimeThread(function()
			local grid_width = 256
			local grid_height = 256
			local grid_depth = 128
			while true do
				local cursor = GetTerrainGamepadCursor()
				if cursor then
					local x, y, z = cursor:xyz()
					DbgSetTerrainOverlay3D("passability", 0, x, y, z, grid_width, grid_height, grid_depth, 1200, 1200, 700)
				end
				Sleep(200)
			end
		end)
	else
		hr.TerrainDebug3DDraw = 0
	end
end

function GridOpDbg:GetEditorText()
	local txt = {}
	if self.WaitFrames ~= 0 then
		txt[#txt + 1] = "Wait <WaitFrames> frames"
	end
	if self.Invalidate then
		txt[#txt + 1] = "Invalidate terrain"
	end
	if self.Show == "grid" then
		if self.Grid ~= "" then
			txt[#txt + 1] = "Show <GridOpName><Grid></GridOpName>"
		end
	elseif self.Show ~= "" then
		if self.Show == "clear" then
			txt[#txt + 1] = "Clear overlay"
		else
			txt[#txt + 1] = "Show <GridOpValue><Show></GridOpValue>"
		end
	end
	return table.concat(txt, ", ")
end


DefineClass.GridOpHistogram = {
	__parents = { "GridOpInput" },
	properties = {
		{ category = "General", id = "Levels",        name = "Histo Levels", editor = "number", default = 100, min = 10, max = 1000 },
		{ category = "General", id = "Normalize",     name = "Normalize",    editor = "bool",   default = true },
		{ category = "General", id = "MinValue",      name = "From",         editor = "number", default = 0, enabled_by = "!Normalize" },
		{ category = "General", id = "MaxValue",      name = "To",           editor = "number", default = 100, enabled_by = "!Normalize" }, 
		{ category = "Preview", id = "Histogram",     name = "Histogram",    editor = "grid",   default = false, dont_save = true, min = 128, read_only = true, dont_normalize = true, frame = 1 }, 
		{ category = "Preview", id = "Average",       name = "Average",      editor = "number", default = 0, scale = preview_recision, read_only = true }, 
		{ category = "Preview", id = "Deviation",     name = "Deviation",    editor = "number", default = 0, scale = preview_recision, read_only = true }, 
		{ category = "Preview", id = "Volume",        name = "Volume",       editor = "number", default = 0, scale = preview_recision, read_only = true },
	},
	GridOpType = "Histogram",
	RunModes = set("Debug", "Release"),
}

function GridOpHistogram:SetGridInput(state, grid)
	local hsize = self.Levels
	local from, to
	if not self.Normalize then
		from, to = self.MinValue, self.MaxValue
	end
	local histogram, maxh = GridHistogram(grid, hsize, from, to)
	if not histogram then
		return "Histogram Failed"
	end
	local hgrid = self.Histogram
	local w, h = hsize, 64
	if not hgrid or hgrid:size() ~= hsize then
		hgrid = NewComputeGrid(w, h, "U", 8)
		self.Histogram = hgrid
	else
		hgrid:clear()
	end
	if maxh == 0 then
		return
	end
	for gx = 0, w-1 do
		local gy = MulDivRound(h - 1, maxh - histogram[gx + 1], maxh)
		GridDrawColumn(hgrid, gx, gy, 0, 255)
	end
	local avg, dev, vol = GridStats(grid, preview_recision)
	if not avg then
		return "Statistics Failed"
	end
	self.Average = avg
	self.Deviation = dev
	self.Volume = vol
end