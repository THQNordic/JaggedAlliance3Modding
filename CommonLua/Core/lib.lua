--- Basic lua library functions.
if FirstLoad then
	weak_keys_meta = { __mode = "k", __name = "weak_keys_meta" }
	weak_values_meta = { __mode = "v", __name = "weak_values_meta" }
	weak_keyvalues_meta = { __mode = "kv", __name = "weak_keyvalues_meta" }
	immutable_meta = {
		__newindex = function() assert(false, "Trying to modify an immutable table", 1) end,
		__name = "immutable_meta",
	}
	__empty_meta = {
		__newindex = function() assert(false, "Trying to modify the empty table", 1) end,
		__eq = function(t1, t2) return next(t1) == nil and next(t2) == nil end,
		__name = "__empty_meta"
	}
	__empty_meta.__metatable = __empty_meta -- raise an error if the metatable is changed
	empty_table = setmetatable({}, __empty_meta)
	empty_func = function() end
	return_true = function() return true end
	return_0 = function() return 0 end
	return_100 = function() return 100 end
	return_first = function(a) return a end
	return_second = function(a, b) return b end
	empty_box = box()
	point20 = point(0, 0)
	point30 = point(0, 0, 0)
	axis_x = point(4096, 0, 0)
	axis_y = point(0, 4096, 0)
	axis_z = point(0, 0, 4096)
	axis_minus_z = point(0, 0, -4096)
end

dbg = empty_func -- WILL BE REMOVED IN GOLD MASTER

function readonlytable(table)
	return setmetatable({}, {
		__index = table,
		__newindex = function(table, key, value)
			assert(false, "Trying to modify a read-only table!")
		end,
	})
end

max_int = 2^31 - 1
min_int = -(2^31)
max_int64 = 2^63 - 1
min_int64 = -(2^63)

local function tostring(val)
	if type(val) == "function" then
		local debug_info = debug.getinfo(val, "Sn")
		return debug_info.short_src .. "(" .. debug_info.linedefined .. ")"
	end
	return _G.tostring(val)
end

function concat_params(sep, ...)
	local p = pack_params(...)
	if p then
		for i = 1, #p do
			p[i] = tostring(p[i])
		end
		return table.concat(p, sep)
	end
	return ""
end

--- Converts the arguments to a string to be printed in the game console in a convenient way.
-- @cstyle string print_format(...).
function print_format(...)
	local arg = {...}
	local count = count_params(...)
	if count == 0 then
		return
	end
	for i = count, 1, -1 do
		if arg[i] ~= nil then
			break
		end
		count = count - 1
	end
	if count == 1 and type(arg[1])=="table" then
		return table.format(arg[1], 3, 175)
	end
	for i = 1, count do
		arg[i] = type(arg[i])=="table" and table.format(arg[i], 1, -1) or tostring(arg[i])
	end
	return table.concat(arg, " ")
end

--- Creates a print function to be used locally within a subsystem
--[[
	my_print = CreatePrint{
		"tag",         -- comment out to disable these prints; all prints will be prefixed with [tag]; "" to print, but without tag
		trace = "line", -- "line" for call line or "stack" for entire call stack
		timestamp = "realtime", -- "realtime", "gametime" or "both"
		output = ConsolePrint, -- OutputDebugString, etc.
		format = "printf", -- use printf format for this print
	}
	usage: my_print("message", table, integer, string, ...)
	usage: my_print("once", "message", table, integer, string, ...)
]]--
if FirstLoad then
	org_print = print
	once_log = {}
end

function OutputDebugStringNL(s) OutputDebugString(s) OutputDebugString("\r\n") end
function DebugPrintNL(s) DebugPrint(s) DebugPrint("\r\n") end

function CreatePrint(options)
	if not options or not options[1] then
		return empty_func
	end
	local tag
	if type(options[1]) == "string" and options[1] ~= "" then
		tag = "[" .. options[1] .. "] "
	else
		tag = ""
	end
	local trace = options.trace
	local timestamp = options.timestamp
	local format = options.format == "printf" and string.format or options.format or print_format
	local output
	if Platform.cmdline then
		output = org_print
	else
		output = options.output or ConsolePrint
		if output == OutputDebugString then
			output = OutputDebugStringNL
		end
		if output == DebugPrint then
			output = DebugPrintNL
		end
	end
	local append_new_line = options.append_new_line
	local color_tag
	if options.color then
		local r, g, b = GetRGB(options.color)
		color_tag = string.format("<color %d %d %d>", r, g, b)
	end
		
	return function(once, ...)
		local s
		if once == "once" then
			s = format(...) or ""
			if once_log[s] then
				return
			else
				once_log[s] = true
			end
		else
			s = format(once, ...) or ""
		end
		if timestamp == "realtime" then
			s = string.format("%srt %8d\t%s", tag, RealTime(), s)
		elseif timestamp == "gametime" then
			s = string.format("%sgt %8d\t%s", tag, GameTime(), s)
		elseif timestamp == "precise" then
			s = string.format("%spt %8d\t%s", tag, GetPreciseTicks(), s)
		elseif timestamp then
			s = string.format("%srt %8d gt %7d\t%s", tag, RealTime(), GameTime(), s)
		else
			s = tag .. s
		end
		if trace == "line" then
			s = s .. "\n\t" .. GetCallLine()
		elseif trace == "stack" then
			s = s .. "\n" .. GetStack(2, false, "\t")
		end
		if color_tag then
			s = color_tag .. s .. "</color>"
		end
		if append_new_line then
			s = s .. "\n"
		end
		return output(s)
	end
end

print = CreatePrint{
	"",
	--trace = "stack",
}

printf = CreatePrint{
	"",
	--trace = "stack",
	format = string.format,
}

function DebugPrintf(fmt, ...)
	return DebugPrint(string.format(fmt, ...))
end

local function parse_error(err)
	local file, line, err = string.match(tostring(err), "(.-%.lua):(%d+): (.*)")
	if file and line and io.exists(file) then
		return file, line, err
	end
end

function OnMsg.Autorun()
	LoadingBlacklist = {}
end

--- Protected "silent" versions of 'dofile'. Instead of printing an error, returns ok code followed by error text or execution results.
-- @cstyle void pdofile(filename, fenv, mode).
-- @param filename string; the file name.
-- @param fenv table; execution environment, if not present taken from caller function.
-- @param mode string; controls weather the chuck can be text or binary. Possible values are "b", "t" and "bt".
-- @return ok bool, err text or execution results.
function pdofile(name, fenv, mode)
	if LoadingBlacklist[name] then return false, "Blacklisted" end

	local func, err = loadfile(name, mode, fenv or _ENV)
	if not func then
		return false, err
	end

	return pcall(func)
end

local function procall_helper(ok, ...)
	if not ok then return end
	return ...
end

--- Executes a file and returs the results of the execution. Prints in case of any errors.
-- @cstyle void dofile(filename, fenv).
-- @param filename string; the file name.
-- @param fenv table; execution environment, if not present taken from caller function.
-- @return execution results.
function dofile(name, fenv, ...)
	if LoadingBlacklist[name] then return end
	
	local func, err = loadfile(name, nil, fenv or _ENV)
	if not func then
		syntax_error(err, parse_error(err))
		if parse_error(err) and GetIgnoreDebugErrors() then
			syntax_error(string.format("[Compile Error]: Lua compilation error in '%s'!", name))
			FlushLogFile()
			quit(1)
		end
		return
	end

	return procall_helper(procall(func, ...))
end

--- dofolder loads a folder tree of lua files. If there is a "__load.lua" file in a folder then only it is loaded instead of loading all lua files.
-- @cstyle void dofolder(folder, fenv).
-- @param folder string; the folder name.
-- @param fenv string; optional, the envoronment for the code execution.
function dofolder(folder, fenv, ...)
	if LoadingBlacklist[folder] then return end
	-- see if the folder has special init
	local load = folder .. "/__load.lua"
	if io.exists(load) then
		dofile(load, fenv, folder, ...)
		return
	end
	dofolder_files(folder, fenv, ...)
	dofolder_folders(folder, fenv, ...)
end

function dofolder_files(folder, fenv, ...)
	if LoadingBlacklist[folder] then return end
	local files = io.listfiles(folder, "*.lua", "non recursive")
	table.sort(files, CmpLower)
	for i = 1, #files do
		local file = files[i]
		if not string.match(file, ".*[/\\]__[^/\\]*$") then
			dofile(file, fenv, ...)
		end
	end
end

function dofolder_folders(folder, fenv, ...)
	if LoadingBlacklist[folder] then return end
	local folders = io.listfiles(folder, "*", "folders")
	table.sort(folders, CmpLower)
	for i = 1, #folders do
		local folder = folders[i]
		if not string.match(folder, ".*[/\\]__[^/\\]*$") then
			dofolder(folder, fenv, ...)
		end
	end
end

--- Executes a string and returs the results of the execution. Prints in case of any errors.
-- @cstyle void dostring(code, fenv).
-- @param code string; the code to execute.
-- @param fenv table; execution environment, if not present taken from caller function.
-- @return execution results.
function dostring(text, fenv)
	local func, err = load(text, nil, nil, fenv or _ENV)
	if not func then
		syntax_error(err, parse_error(err))
		return
	end
	return procall_helper(procall(func))
end

function LoadConfig(cfg, secret)
	local err, file = AsyncFileToString(cfg)
	if not err then
		local err, text = OSDecryptData(file, secret or "")
		file = text or file
	end
	pcall(load(file or ""))
end

--- Returns a string description of the function, file name and file line it was called from.
-- @cstyle string getfileline(depth).
-- @param depth type int; the level of the call stack to get information from.
-- @return string.
function getfileline(depth)
	local info = type(depth) == "function" and debug.getinfo(depth) or debug.getinfo(2 + (depth or 0))
	local file = io.getmetadata(info.short_src, "os_path") or info.short_src
	return info and string.format("%s(%d): %s %s", file, info.currentline or 0, info.namewhat or "", info.name or "<>")
end

function ReloadLua(dlc)
	SuspendThreadDebugHook("ReloadLua") -- disable any Lua debug hooks (infinite loop detection, backtracing, Lua debugger)
	local start_time = GetPreciseTicks()
	local ct = CurrentThread()
	ReloadForDlc = dlc or false
	print("Reloading lua files")
	if MountsByLabel("Lua") == 0 and LuaPackfile then
		MountPack("", LuaPackfile, "in_mem,seethrough,label:Lua")
	end
	if MountsByLabel("Data") == 0 and DataPackfile then
		MountPack("Data", DataPackfile, "in_mem,label:Data")
	end
	const.LuaReloads = (const.LuaReloads or 0) + 1
	Msg("ReloadLua")
	collectgarbage("collect")
	dofile("CommonLua/Core/autorun.lua")
	Msg("Autorun")
	Msg("AutorunEnd")
	MsgClear("AutorunEnd")
	printf("Reloading done in %dms", GetPreciseTicks() - start_time)
	ReloadForDlc = false
	if ct then
		InterruptAdvance()
	end
	ResumeThreadDebugHook("ReloadLua")
end

function ResolveHandle(handle)
	if not handle then return end
	local obj = HandleToObject[handle]
	if not obj then
		obj = { handle = handle, [true] = false }
		HandleToObject[handle] = obj
	end
	return obj
end

o = ResolveHandle

function GetModifiedProperties(obj, GetPropFunc, ignore_props)
	local result
	GetPropFunc = GetPropFunc or obj.GetProperty
	for i, prop in ipairs(obj:GetProperties()) do
		if not prop_eval(prop.dont_save, obj, prop) and prop.editor then
			local id = prop.id
			if not ignore_props or not ignore_props[id] then
				local value = GetPropFunc(obj, id, prop)
				if not obj:IsDefaultPropertyValue(id, prop, value) then
					result = result or {}
					result[id] = value
				end
			end
		end
	end
	return result
end

SetObjPropertyList = rawget(_G, "SetObjPropertyList") or function(obj, list)
	if obj and list then
		local SetPropFunc = obj.SetProperty
		for i = 1, #list, 2 do
			SetPropFunc(obj, list[i], list[i + 1])
		end
	end
end

SetArray = rawget(_G, "SetArray") or function(obj, array)
	if obj and array then
		for i = 1, #array do
			rawset(obj, i, array[i])
		end
	end
end

----

local env_defaults = {"PlaceObj", "o", "point", "box", "RGBA", "RGB", "RGBRM", "PackCurveParams", "T", "TConcat", "range", "set"}
function LuaValueEnv(env)
	env = env or {}
	for _, k in ipairs(env_defaults) do
		if env[k] == nil then
			env[k] = rawget(_G, k)
		end
	end
	return setmetatable(env, {
		__index = function (t, key)
			if key ~= "class" then
				assert(false, string.format("missing '%s' used in lua code", key), 1) 
			end
		end})
end

function LuaCodeToObjs(script, params)
	params = params or empty_table
	
	local mapx, mapy = terrain.GetMapSize()
	local pos = params.pos
	local invalid_center = not pos or pos == InvalidPos() or pos:x() < 0 or pos:y() < 0 or pos:x() > mapx or pos:y() > mapy
	local xc, yc, zc = 0, 0, 0
	if not invalid_center then
		xc, yc, zc = pos:xyz()
	end
	
	local HandleToObject = HandleToObject
	local gofPermanent = const.gofPermanent
	local PlaceObj = PlaceObj
	local g_Classes = g_Classes
	local CObject = CObject
	local InvalidZ = const.InvalidZ
	local SetGameFlags = CObject.SetGameFlags
	local GetCollectionIndex = CObject.GetCollectionIndex
	local SetCollectionIndex = CObject.SetCollectionIndex
	local SetPos = CObject.SetPos
	local SetScale = CObject.SetScale
	local SetAngle = CObject.SetAngle
	local SetAxis = CObject.SetAxis
	local CObject_new = CObject.new
	
	local AdjustPos, AdjustPosXY, AdjustPosXYZ
	if params.no_pos_clamp then
		AdjustPosXY = function(x, y)
			return x + xc, y + yc
		end
		AdjustPosXYZ = function(x, y, z)
			return x + xc, y + yc, z and zc and (z + zc) or InvalidZ
		end
	else
		AdjustPosXY = function(x, y)
			return Clamp(x + xc, 0, mapx), Clamp(y + yc, 0, mapy)
		end
		AdjustPosXYZ = function(x, y, z)
			return Clamp(x + xc, 0, mapx), Clamp(y + yc, 0, mapy), z and zc and (z + zc) or InvalidZ
		end
	end
	if params.no_z then
		AdjustPos = function(pt)
			if pt then
				return point(AdjustPosXY(pt:xy()))
			end
		end
	else
		AdjustPos = function(pt)
			if pt then
				return point(AdjustPosXYZ(pt:xyz()))
			end
		end
	end
	
	local exec = params.exec
	local handle_provider = params.handle_provider
	local no_collections = params.no_collections
	local collection_index_provider = params.collection_index_provider
	local ground_offsets = params.ground_offsets
	local normal_offsets = params.normal_offsets
	
	local func, err
	local objs = {}
	local collection_remap = {}
	if type(script) == "string" then
		local comment_tag = params.comment_tag or "--[[HGE place script]]--"
		if not params.is_file and comment_tag ~= "" and not string.starts_with(script, comment_tag) then
			return false, "invalid script"
		end

		local env = {
			SetObjectsCenter = function(center)
				if invalid_center then
					xc, yc, zc = center:xyz()
				end
			end,
			PlaceObj = function (class, values, arr, handle)
				local is_collection = class == "Collection"
				if no_collections and is_collection then
					return
				end
				
				-- handle nested objects properties
				if not g_Classes[class]:IsKindOf("CObject") then
					return PlaceObj(class, values)
				end

				if handle_provider then
					handle = handle_provider(class, values)
				else
					handle = handle and not HandleToObject[handle] and handle
				end
				local col_idx
				if is_collection then
					for i = 1, #values, 2 do
						if values[i] == "Index" then
							col_idx = values[i + 1]
							if collection_index_provider then
								values[i + 1] = collection_index_provider(col_idx)
							end
							break
						end
					end
				else
					for i = 1, #values, 2 do
						if values[i] == "Pos" then
							values[i + 1] = AdjustPos(values[i + 1])
							break
						end
					end
				end
				
				local obj = PlaceObj(class, values, arr, handle)
				if is_collection and col_idx and col_idx ~= 0 then
					collection_remap[col_idx] = obj.Index
				end
				if exec then exec(obj) end
				objs[#objs + 1] = obj
			end,
			PlaceGrass = function(class, x, y, s, a, ox, oy, oz)
				local classdef = g_Classes[class]
				if not classdef then
					assert(false, "No such class: " .. class)
					return
				end
				local obj = CObject_new(classdef)
				x, y = AdjustPosXY(x, y)
				SetPos(obj, x, y, InvalidZ)
				if s then SetScale(obj, s) end
				if a then SetAngle(obj, a) end
				if ox then SetAxis(obj, ox, oy, oz) end
				if exec then exec(obj) end
				objs[#objs + 1] = obj
			end,
			PlaceCObjects = function(data)
				local new_objs = exec and {} or objs
				local err = PlaceAndInitBin(data, point(xc, yc, zc), new_objs, ground_offsets, normal_offsets, params.no_pos_clamp)
				if err then
					assert(false, "Failed to decode object stream " .. comment_tag .. ": " .. err)
					return
				end
				if exec then
					for i=1,#new_objs do
						local obj = new_objs[i]
						exec(obj)
						objs[#objs + 1] = obj
					end
				end
			end,
			o = ResolveHandle,
			point = point,
			box = box,
			LoadGrid = function (data, ...)
				data = data or ""
				local grid, err = LoadGrid(data, ...)
				if not grid and data ~= "" then
					assert(false, err)
				end
				return grid
			end,
			GridReadStr = function (data, ...)
				data = data or ""
				local grid, err = GridReadStr(data, ...)
				if not grid and data ~= "" then
					assert(false, err)
				end
				return grid
			end,
			InvalidPos = InvalidPos,
			RGBA = RGBA,
			RGB = RGB,
			RGBRM = RGBRM,
			T = T,
			range = range,
			set = set,
			PlaceAndInit4 = PlaceAndInit4,
			PlaceAndInit_v2 = PlaceAndInit_v2,
		}
		if params.is_file then
			func, err = loadfile(script, nil, env)
		else
			func, err = load(script, nil, nil, env)
		end
		assert(func, err)
		if not func then
			return false, err
		end
	elseif type(script) == "function" then
		func = script
	else
		return false, "invalid script"
	end

	SuspendPassEdits("LuaCodeToObjs")
	func()
	
	table.validate(objs)
	
	local locked_idx = editor.GetLockedCollectionIdx()
	for i = 1,#objs do
		local obj = objs[i]
		if not handle_provider then
			SetGameFlags(obj, gofPermanent)
		end
		if not no_collections then
			local idx = GetCollectionIndex(obj)
			idx = idx ~= 0 and collection_remap[idx] or locked_idx
			SetCollectionIndex(obj, idx)
		end
		if obj.__ancestors.Object then
			obj:PostLoad("paste")
		end
	end

	UpdateCollectionsEditor()
	ResumePassEdits("LuaCodeToObjs")
	
	return objs
end

local empty_func = empty_func
function sorted_pairs(t)
	if not t then return empty_func end
	local first_key = next(t)
	if first_key == nil then 
		return empty_func -- the table has no elements
	elseif next(t, first_key) == nil then 
		return pairs(t) -- the table has only one element
	end
	local keys = table.keys(t, true)
	local n = 1
	return function(t, key)
		key = keys[n]
		assert(type(key) ~= "table") --cant sort table keys, it will cause desyncs
		n = n + 1
		if key == nil then return end
		return key, t[key]
	end, t, nil
end

function sorted_handled_obj_key_pairs(t) --note that it traverses only obj keys and skips the rest
	if not t then return empty_func end
	local first_key = next(t)
	if first_key == nil then 
		return empty_func
	elseif next(t, first_key) == nil then 
		return pairs(t) 
	end
	local handleToVal = {}
	local handleToKey = {}
	local orderT = {}
	local n = 1
	for k, v in pairs(t) do
		if IsKindOf(k, "Object") then
			local h = k.handle
			handleToVal[h] = v
			handleToKey[h] = k
			orderT[n] = h
			n = n + 1
		end
	end
	
	table.sort(orderT, lessthan)
	n = 1
	
	return function(t, key)
		local h = orderT[n]
		n = n + 1
		if h == nil then return end
		return handleToKey[h], handleToVal[h]
	end, t, nil
end

if FirstLoad then
	g_old_pairs = pairs
end
function totally_async_pairs(t)
	if not t then return empty_func end
	local first_key = next(t)
	if first_key == nil then 
		return empty_func -- the table has no elements
	elseif next(t, first_key) == nil then 
		return g_old_pairs(t) -- the table has only one element
	end
	local keys = table.keys(t)
	local rand_idx = AsyncRand(#keys - 1) + 1
	keys[1], keys[rand_idx] = keys[rand_idx], keys[1]
	local n = 1
	return function(t, key)
		key = keys[n]
		n = n + 1
		if key == nil then return end
		return key, t[key]
	end, t, nil
end

if Platform.developer then
function simple_key_pairs(t)
		for key in g_old_pairs(t) do
			local tkey = type(key)
			assert(tkey == "number" or tkey == "boolean")
		end
	return g_old_pairs(t)
end
else
	simple_key_pairs = pairs
end


----- random array iterator

local large_primes = { -- using different primes improves somewhat the possible permutations received
	2000000011, 2000025539, 2000049899, 2000074933, 2000092243, 2000130467, 2000193983, 2000233049, 2000258899, 2000323693, 
	2000398357, 2000424479, 2000449897, 2000493491, 2000541203, 2000553461, 2000574853, 2000610511, 2000685233, 2000699957,
	2000776051, 2000802673, 2000854319, 2000892217, 
}
-- if seed is string it is used as an InteractionRand() parameter
-- if seed is nil or false then AsyncRand() is used
function random_ipairs(list, seed) -- iterates over list items in random(ish) order
	if not list or #list < 2 then
		return ipairs(list)
	end
	if type(seed) == "string" then seed = InteractionRand(#list * #large_primes, seed) end
	seed = abs(seed or AsyncRand(#list * #large_primes))
	local last
	local large_prime = large_primes[1 + (seed / #list) % #large_primes]
	return function(list, index)
		index = 1 + (index - 1 + large_prime) % #list
		if index == last then return end
		last = last or index
		return index, list[index]
	end, list, seed % #list + 1
end

-- if seed is string it is used as an InteractionRand() parameter
-- if seed is nil or false then AsyncRand() is used
function random_index(max, seed) -- returns values from [0 .. max - 1] in random(ish) order
	if (max or 0) < 1 then 
		return empty_func
	end
	if type(seed) == "string" then seed = InteractionRand(max * #large_primes, seed) end
	seed = abs(seed or AsyncRand(max * #large_primes))
	local last
	local large_prime = large_primes[1 + (seed / max) % #large_primes]
	return function(max, index)
		index = (index + large_prime) % max
		if index == last then return end
		last = last or index
		return index
	end, max, seed % max
end


--- Makes certain fields in a table refer to engine exported variables (LuaVars)
-- The values of all matching fields are set to the corresponding engine exported variable (LuaVar)
-- Any further read/writes to matching fields are redirected to LuaVar get/set calls
-- @cstyle void SetupVarTable(table table, string prefix).
-- @param table - the table to be modified; modifies metatable.
-- @param prefix - a prefix used to match engine exported vars (LuaVars) to table fields - a field matches when <engine var> == <prefix><field>

function SetupVarTable(table, prefix)
	if FirstLoad and getmetatable(table) then
		error("SetupVarTable requires a table without a metatable", 1)
		return
	end
	
	setmetatable(table, nil)

	local vars = {}
	for key, value in pairs(EnumEngineVars(prefix)) do
		vars[key] = true
		local new_value = table[key]
		if new_value == nil then
			local subtable_key = string.match(key, "(%w*)%.")
			local subtable = subtable_key and table[subtable_key]
			if subtable_key and not (subtable and getmetatable(subtable)) then
				subtable = subtable or {}
				SetupVarTable(subtable, prefix .. subtable_key .. ".")
				table[subtable_key] = subtable
			end
		elseif new_value ~= nil and new_value ~= value then
			SetEngineVar(prefix, key, new_value)
		end
		table[key] = nil
	end

	local meta = {
		__index = function (table, key)
			if vars[key] then
				return GetEngineVar(prefix, key)
			end
		end,

		__newindex_locked = function (table, key, value)
			if vars[key] then
				SetEngineVar(prefix, key, value)
			else
				error("Trying to create new value " .. prefix .. key, 1)
			end
		end,

		__newindex_unlocked = function (table, key, value)
			if vars[key] then
				SetEngineVar(prefix, key, value)
			else
				rawset(table, key, value)
			end
		end,

		__enum = function(table)
			local bVars = true
			return function(table, key)
				if bVars then
					key = next(vars, key)
					if key ~= nil then
						return key, GetEngineVar(prefix, key)
					end
					bVars = false
				end
				return next(table, key)
			end,
			table,
			nil
		end,
	}
	meta.__newindex = meta.__newindex_unlocked
	setmetatable(table, meta)
	
	return vars
end

function SetVarTableLock(table, bLock)
	local meta = getmetatable(table)
	meta.__newindex = bLock and meta.__newindex_locked or meta.__newindex_unlocked
end

function parallel_foreach(array, func, timeout, threads)
	local thread = CurrentThread()
	assert(thread)
	if not array or not thread or not func then return "bad params" end
	if #array == 0 then return end
	threads = threads or tonumber(os.getenv("NUMBER_OF_PROCESSORS"))
	threads = Min(threads or #array, #array)
	local err
	local counter = 1
	local items = #array

	local function worker()
		while not err and counter <= items do
			local idx = counter
			counter = counter + 1
			err = err or func(array[idx], idx)
		end
		threads = threads - 1
		if threads == 0 then
			Wakeup(thread)
		end
	end

	for i = 1, threads do
		CreateRealTimeThread(worker)
	end

	if WaitWakeup(timeout) then
		return err
	end
	-- in case of a timeout stop threads from making additional calls
	counter = items + 1
	threads = -1
	return "timeout"
end

function ConvertFromOSPath(path, base_folder)
	-- find a suffix of path which starts with base_folder; preserves case; flips slashes to forward
	-- e.g. ConvertFromOSPath("C:\\Src\\GangsAssets\\source\\Textures\\Particles\\pesho.tga", "Textures") -> "Textures/Particles/pesho.tga"
	if not base_folder then return path end
	if not string.ends_with(base_folder, "/") and not string.ends_with(base_folder, "\\")  then
		base_folder = base_folder .. "/"
	end
	base_folder = string.gsub(base_folder, "/", "\\")
	
	local re = string.format(".*\\%s(.*)$", string.lower(base_folder))
	local filename = string.match(string.lower(path):gsub("/", "\\"), re)
	if filename then
		return string.gsub(base_folder .. string.sub(path, -#filename), "\\", "/")
	end
	return path
end

-- MapVars (persistable, reset at map change)

MapVars = {}
MapVarValues = {}

function MapVar(name, value, meta)
	if type(value) == "table" then
		local org_value = value
		value = function()
			local v = table.copy(org_value, false)
			setmetatable(v, getmetatable(org_value) or meta)
			return v
		end
	end
	if FirstLoad or rawget(_G, name) == nil then
		rawset(_G, name, false)
	end
	assert(not table.find(MapVars, name))
	MapVars[#MapVars + 1] = name
	MapVarValues[name] = value or false
	PersistableGlobals[name] = true
end

function OnMsg.NewMap()
	for _, name in ipairs(MapVars) do
		local value = MapVarValues[name]
		if type(value) == "function" then
			value = value()
		end
		_G[name] = value or false
	end
end

function OnMsg.PersistPostLoad(data)
	for _, name in ipairs(MapVars) do
		if data[name] == nil then
			local value = MapVarValues[name]
			if type(value) == "function" then
				value = value()
			end
			_G[name] = value or false
		end
	end
end

function OnMsg.Autorun() -- hook the handler below after everything else
function OnMsg.PostDoneMap()
	for _, name in ipairs(MapVars) do
		_G[name] = false
	end
end
end

function LoadLogfile(max_lines, as_table)
	FlushLogFile()
	local f, err = io.open(GetLogFile(), "r")
	if not f then
		return err
	end

	local lines = {}
	local first_err = false
	for line in f:lines() do
		lines[#lines + 1] = line
		if max_lines and #lines > max_lines then
			table.remove(lines, 1)
		end
		if not first_err and (string.find(line, "Error%]") or string.find(line, "%[Console%]")) then
			first_err = line
		end
	end
	f:close()
	return as_table and lines or table.concat(lines, "\n"), first_err
end

function BraidRandomCreate(...)
	local seed, _ = xxhash(...)
	_, seed = BraidRandom(seed)
	_, seed = BraidRandom(seed)
	return function (...)
		local rand
		rand, seed = BraidRandom(seed, ...)
		return rand
	end
end

function RandPoint(ampx, ampy, ampz, seed)
	ampy = ampy or ampx
	ampz = ampz or ampx
	seed = seed or AsyncRand()
	local x, y, z
	x, seed = BraidRandom(seed, -ampx, ampx)
	y, seed = BraidRandom(seed, -ampy, ampy)
	z, seed = BraidRandom(seed, -ampz, ampz)
	return point(x, y, z) 
end

local keep_ref_thread
local keep_ref_objects

function KeepRefForRendering(obj, free_handler)
	if not keep_ref_thread then
		keep_ref_thread = CreateRealTimeThread(function()
			local f1, f2, f3
			repeat
				WaitMsg("OnRender")
				for i=1,#(f1 or "") do
					local handler = type(f1[i]) == "table" and rawget(f1[i], "__free_handler")
					if handler then
						handler(f1[i].__obj)
					end
				end
				f1, f2, f3 = f2, f3, keep_ref_objects
				keep_ref_objects = nil
			until not (f1 or f2 or f3)
			keep_ref_thread = false
		end)
	end
	if free_handler then
		obj = { __obj = obj, __free_handler = free_handler }
	end
	if keep_ref_objects then
		keep_ref_objects[#keep_ref_objects + 1] = obj
	else
		keep_ref_objects  = {obj}
	end
end

----

if FirstLoad then
	g_ReleaseNextFrame = { [1] = {} , [2] = {} }
end
local g_ReleaseNextFrame = g_ReleaseNextFrame

function OnMsg.OnRender()
	if #g_ReleaseNextFrame[1] == 0 and #g_ReleaseNextFrame[2] == 0 then return end
	
	g_ReleaseNextFrame[1] = g_ReleaseNextFrame[2]
	g_ReleaseNextFrame[2] = {}
end

function KeepRefOneFrame(obj)
	if obj then
		table.insert(g_ReleaseNextFrame[#g_ReleaseNextFrame], obj)
	end
end

----

function SetupFuncCallTable(func)
	local table = {}
	setmetatable(table, {
		__newindex = function (table, key, value)
			return func(key, value)
		end,
		__call = function (table, ...)
			return func(...)
		end,
	})
	return table
end

function AsyncEmptyPath(path)
	if (path or "") == "" or path == "./" or path == "../" then return "Cannot delete path " .. tostring(path) end
	local err, files = AsyncListFiles(path, "*", "recursive")
	if err then return err end
	if #files > 0 then
		err = AsyncFileDelete(files)
		if err then return err end
	end
	local err, folders = AsyncListFiles(path, "*", "recursive,folders")
	if err then return err end
	if #folders > 0 then
		table.sort(folders) -- so we can be sure to delete subfolders before root folders
		table.reverse(folders)
		err = AsyncFileDelete(folders)
		if err then return err end
	end
	return nil, #files, #folders
end

function AsyncDeletePath(path)
	local err = AsyncEmptyPath(path)
	if err then return err end
	return AsyncFileDelete(path)
end


-- SVN stub
function SVNDeleteFile() end
function SVNAddFile() end
function SVNMoveFile() end
function SVNExistFile() end

function SVNShowLog(path)
	CreateRealTimeThread(function()
		AsyncExec(string.format('TortoiseProc /command:log /notempfile /closeonend /path:"%s"', ConvertToOSPath(path)))
	end)
end

function SVNShowBlame(path)
	local path = ConvertToOSPath(path)
	local rev = LuaRevision
	local cmd = string.format('TortoiseProc /command:blame /notempfile /closeonend /ignoreeol /ignoreallspaces /startrev:1 /endrev:%d /path:"%s"', rev, path)
	AsyncExec(cmd)
end

function SVNShowDiff(path)
	local path = ConvertToOSPath(path)
	local cmd = string.format('TortoiseProc /command:diff /notempfile /closeonend /path:"%s"', path)
	AsyncExec(cmd)
end

local ExtractedSvnInfoValues = {
	{ key = "localPath", re = "Working Copy Root Path: (.-)\n"},
	{ key = "branch", re = "URL: (.-)\n"},
	{ key = "relative_url", re = "Relative URL: (.-)\n"},
	{ key = "root", re = "Repository Root: (.-)\n"},
	{ key = "revision", re = "Revision: (%d+)", number = true},
	{ key = "kind", re = "Node Kind: (%w+)"},
	{ key = "depth", re = "Depth: (%w+)", default = "infinity" },
	{ key = "author", re = "Last Changed Author: (%w+)"},
	{ key = "last_revision", re = "Last Changed Rev: (%d+)", number = true},
	{ key = "date", re = "Last Changed Date: (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)"},
	{ key = "text_date", re = "Text Last Updated: (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)"},
	{ key = "checksum", re = "Checksum: (%w+)"}
}

local SvnInfoCache = {} -- GetSvnInfo is dev only so it's ok having such cache

function GetSvnInfo(target, env)
	local svn_info_values = SvnInfoCache[target]
	if not svn_info_values then
		local folder, filename, ext = SplitPath(target)
		local file = filename .. ext
		if file == "" then
			file = "."
		end
		local err, exit_code, output, err_messsage = AsyncExec("svn info " .. file, ConvertToOSPath(folder), true, true, "belownormal")
		if err then 
			return err, nil, exit_code, output, err_messsage
		end

		svn_info_values = {}
		for _, value in ipairs(output and ExtractedSvnInfoValues) do
			local m = string.match(output, value.re) or value.default
			if m then
				svn_info_values[value.key] = value.number and tonumber(m) or m
			end
		end
		SvnInfoCache[target] = svn_info_values
	end
	return nil, svn_info_values
end

function StringToFileIfDifferent(filename, data)
	local err, old_data = AsyncFileToString(filename, nil, nil, "pstr")
	if not err then
		local same = old_data:equals(data)
		old_data:free()
		if same then return end
	end
	local dir = SplitPath(filename)
	AsyncCreatePath(dir)
	return AsyncStringToFile(filename, data)
end

function SaveSVNFile(file_path, data, is_local)
	local exists = io.exists(file_path)
	if not exists then
		local path = SplitPath(file_path)
		AsyncCreatePath(path)
		if path:starts_with("CommonLua/Libs/") and (path:ends_with("/Data/") or path:ends_with("/XTemplates/")) then
			AsyncStringToFile(path .. "/__load.lua", "")
		end
		if not is_local then
			SVNAddFile(path)
		end
	end
	local err = StringToFileIfDifferent(file_path, data)
	if err then return err end
	if not exists and not is_local then
		SVNAddFile(file_path)
	end
	if file_path:ends_with(".lua") then
		CacheLuaSourceFile(file_path, data)
	end
end

function GetUnpackedLuaRevision(env, path, fallback_revision)
	if not Platform.cmdline and not config.RunUnpacked then
		return false
	end
	if env then
		path = expand_vars(path or "$(project)/..", env)
	else
		path = path or "svnSrc/."
	end
	local dir = ConvertToOSPath(path)
	local err, exit_code, output, err_messsage = AsyncExec("svn info .", dir, true, true)
	if not err and exit_code ~= 0 then
		err = "Exit code (" .. tostring(exit_code) .. ")"
		if (err_messsage or "") ~= "" then
			err = err .. ": " .. tostring(err_messsage)
		end
	end
	if not err then
		local rev = string.match(output or "", "Last Changed Rev: (%d+)")
		rev = tonumber(rev) or -1
		assert(rev ~= -1)
		if rev == -1 then
			return false, "Failed to parse revision info"
		end
		return rev
	elseif type(fallback_revision) == "number" then
		return fallback_revision
	else
		if env then
			env:error("svn info '%s' err '%s'", dir, err)
		else
			assert(false, string.format("svn info '%s' err '%s'", dir, err))
		end
		return false, err
	end
end

function ShowLog()
	CreateRealTimeThread(function()
		FlushLogFile()
		OpenTextFileWithEditorOfChoice(GetLogFile())
	end)
end

function OpenTextFileWithEditorOfChoice(file, line)
	file = file or ""
	if file == "" then return end
	file = ConvertToOSPath(file)
	line = line or 0
	if config.EditorVSCode then
		AsyncExec("cmd /c code -r -g \"" .. file .. ":" .. line .. "\"", true, true)
	elseif config.EditorGed or not Platform.desktop then
		OpenGedApp("GedFileEditor", false, { file_name = file })
	else
		local err = AsyncExec("explorer " .. file)
		if err then
			print(err)
			OS_LocateFile(file)
		end
	end
end

function GenerateColor(color, variation)
	local r, g, b = GetRGB(color)
	local vr, vg, vb = GetRGB(variation)
	local red = r + AsyncRand(2*vr+1) - vr
	local green = g + AsyncRand(2*vg+1) - vg
	local blue = b + AsyncRand(2*vb+1)- vb
	return RGB(red, green, blue)
end

local invalid_pos = InvalidPos()
function InvalidPos()
	return invalid_pos
end


-- PeriodicRepeat

PeriodicRepeatNames = {}
PeriodicRepeatInfo = {}
if FirstLoad then
	PeriodicRepeatThreads = {}
end
PersistableGlobals.PeriodicRepeatThreads = true

 -- !!! backwards compatibility
MapRepeatInfo = PeriodicRepeatInfo
MapRepeatThreads = PeriodicRepeatThreads
function OnMsg.PersistLoad(data)
	PeriodicRepeatThreads = data["PeriodicRepeatThreads"] or data["MapRepeatThreads"]
	MapRepeatThreads = PeriodicRepeatThreads
end
--- !!!

function PeriodicRepeat(create_thread, name, interval, func, condition)
	assert(not PeriodicRepeatInfo[name], "Duplicated map repeat")
	PeriodicRepeatInfo[name] = {
		create_thread,
		interval,
		func,
		condition,
	}
	PeriodicRepeatNames[#PeriodicRepeatNames + 1] = name
end

local function has_map()
	return rawget(_G, "CurrentMap") ~= ""
end

function MapGameTimeRepeat(name, interval, func, condition)
	return PeriodicRepeat(CreateGameTimeThread, name, interval, func, condition or has_map)
end

function MapRealTimeRepeat(name, interval, func, condition)
	return PeriodicRepeat(CreateMapRealTimeThread, name, interval, func, condition or has_map)
end

local function PeriodicRepeatCreateThread(name)
	local info = PeriodicRepeatInfo[name]
	if info[4] and not info[4](info) then return end -- condition failed
	local thread = PeriodicRepeatInfo[name][1](function(name)
		local sleep
		while true do
			do
				local info = PeriodicRepeatInfo[name]
				sleep = info[3](sleep) or info[2] or -1
			end
			Sleep(sleep)
		end
	end, name)
	MakeThreadPersistable(thread)
	if not Platform.goldmaster then
		ThreadsSetThreadSource(thread, name, PeriodicRepeatInfo[name][3])
	end
	return thread
end

function PeriodicRepeatCreateThreads()
	for _, name in ipairs(PeriodicRepeatNames) do
		if not IsValidThread(PeriodicRepeatThreads[name]) then
			PeriodicRepeatThreads[name] = PeriodicRepeatCreateThread(name)
		end
	end
end

function OnMsg.NewMap()
	PeriodicRepeatCreateThreads()
end

OnMsg.ReloadLua = PeriodicRepeatCreateThreads
OnMsg.PersistPostLoad = PeriodicRepeatCreateThreads

function PeriodicRepeatValidateThreads()
	for name, thread in pairs(PeriodicRepeatThreads) do
		if not PeriodicRepeatInfo[name] then
			PeriodicRepeatThreads[name] = nil
			DeleteThread(thread)
		end
	end
end
OnMsg.LoadGame = PeriodicRepeatValidateThreads

function RestartPeriodicRepeatThread(name)
	DeleteThread(PeriodicRepeatThreads[name])
	if PeriodicRepeatInfo[name] then
		PeriodicRepeatThreads[name] = PeriodicRepeatCreateThread(name)
	end
end

function WakeupPeriodicRepeatThread(name, ...)
	return Wakeup(PeriodicRepeatThreads[name], ...)
end

---- PostMsg

--- Calls all static messages (and wakes up threads) from a GameTime thread before the end of the current millisecond.
-- @cstyle void PostMsg(message, ...).
-- @param message any value used as message name.
function PostMsg(message, ...)
	local list = PostMsgList
	if list then
		assert(IsValidThread(PeriodicRepeatThreads["PostMsgThread"]))
		list[#list + 1] = pack_params(message, ...)
		Wakeup(PeriodicRepeatThreads["PostMsgThread"])
	else
		Msg(message, ...)
	end
end

MapVar("PostMsgList", {})
local remove = table.remove
local clear = table.clear
MapGameTimeRepeat("PostMsgThread", 0, function()
	while true do
		local i, list = 1, PostMsgList
		while i <= #list do
			local msg = list[i]
			list[i] = false
			if msg then
				Msg(unpack_params(msg))
			end
			i = i + 1
		end
		clear(list)
		WaitWakeup()
	end
end)


---- DelayedCall

if FirstLoad then
	DelayedCallTime = {}
	DelayedCallParams = {}
	DelayedCallThread = {}
end

local function call_method(self, method, ...)
	self[method](self, ...)
end

function DelayedCall(delay, func, ...)
	assert(delay >= 0)
	DelayedCallThread[func] = DelayedCallThread[func] or CreateMapRealTimeThread(function()
		while WaitWakeup(DelayedCallTime[func] - now()) do
		end
		local params = DelayedCallParams[func]
		DelayedCallTime[func] = nil
		DelayedCallParams[func] = nil
		DelayedCallThread[func] = nil
		local typ = type(func)
		if typ == "function" then
			func(unpack_params(params))
		elseif typ == "table" then
			assert(params and params[1], "Method name required for tables")
			call_method(func, unpack_params(params))
		elseif typ == "string" then
			_G[func](unpack_params(params))
		else
			assert(false, "DelayedCall invalid function type")
		end
	end)
	DelayedCallParams[func] = pack_params(...)
	DelayedCallTime[func] = RealTime() + (delay or 0)
	Wakeup(DelayedCallThread[func])
end

function DelayedCallCancel(func)
	DeleteThread(DelayedCallThread[func])
	DelayedCallParams[func] = nil
	DelayedCallTime[func] = nil
	DelayedCallThread[func] = nil
end

function OnMsg.PostDoneMap()
	DelayedCallTime = {}
	DelayedCallParams = {}
	DelayedCallThread = {}
end

function CallMember(obj_list, member, ...)
	for _, obj in ipairs(obj_list) do
		if PropObjHasMember(obj, member) then call_method(obj, member, ...) end
	end
end

function log() end

function TrimUserInput(input, min_len, max_len)
	if type(input) ~= "string" then return end
	input = input:trim_spaces()
	if #input < (min_len or 1) or #input > (max_len or 80) then return end
	return input
end

function IsValidEmail(email)
	if type(email) ~= "string" or email:match("%@example%.com$") then
		return
	end
	--return email:match(config.EmailPattern or "^[%w\128-\255%!%#%$%%%&%'%*%+%-%/%=%?%^%_%`%{%|%}%~]+%@[%w\128-\255%-%.]+%.[%w\128-\255]+$") or nil
	return email:match(config.EmailPattern or "[^@]+%@[^@]+%.[^@]+$") or nil -- at most one @ and at least one dot after it
end

function IsValidPassword(pass, username)
	if not utf8.IsStrMoniker(pass, config.PasswordMinLen or 8, config.PasswordMaxLen or 128) then
		return false, "bad-password-length"
	end
	if config.PasswordHasMixedDigits ~= false and (not pass:find("%d") or not pass:find("%D")) then
		return false, "no-mixed-digits"
	end
	if not config.PasswordAllowCommon and CommonPasswords and CommonPasswords[pass] then
		return false, "common-pass"
	end
	if not config.PasswordAllowUsername and username and pass:find(username, 1, true) then
		return false, "username-in-pass"
	end
	
	return true
end

function IsValidUserName(name)
	if not utf8.IsStrMoniker(name, config.UsernameMin or 4, config.UsernameMax or 30) then
		return
	end

	return name:match(config.UsernamePattern or "^[%w\128-\255_%-%/%+][%w\128-\255%s_%-%/%+]+[%w\128-\255_%-%/%+]$") and true or false
end

-- the checksum check in this function should be the same in the functions ParseSerial and GenerateSerial
function IsSerialNumberValid(serial, charset)
	serial = tostring(serial):upper()
	local charset = config.SerialCharset or 'ABCDEFGHJKLMNPRTUVWXY346789'
	local set, checksum, g1, g2, g3, g4 = string.match(serial, "^(%w%w%w)(%w)-(%w%w%w%w)-(%w%w%w%w)-(%w%w%w%w)-(%w%w%w%w)$")
	if set then
		local n = abs(xxhash(set, g1, g2, g3, g4)) % #charset + 1
		return charset:sub(n, n) == checksum
	end
end

-- HMAC SHA1 HASH ---------------------------
local last_key, last_ipad, last_opad, last_hash
function Hmac(str, key, fHash)
	fHash = fHash or SHA256
	local ipad, opad = last_ipad, last_opad
	if key ~= last_key or last_hash ~= fHash then
		local key = #key > 64 and fHash(key) or key
		local aipad, aopad = {}, {}
		for i = 1, #key do
			local k = string.byte(key, i)
			aipad[i] = bxor(k, 0x36)
			aopad[i] = bxor(k, 0x5c)
		end
		for i = #key+1, 64 do
			aipad[i] = 0x36
			aopad[i] = 0x5c
		end
		ipad = string.char(unpack_params(aipad))
		opad = string.char(unpack_params(aopad))
		last_key, last_ipad, last_opad = key, ipad, opad
		last_hash = fHash
	end
	str = fHash(opad .. fHash(ipad .. str))
	return str
end

function Hmac64(str, key, fHash)
	return Encode64(Hmac(str, key, fHash))
end

function HashXUID(XUID)
	if type(XUID) ~= "string" then return end
	return Encode64(SHA256("XUID" .. XUID))
end

function MatchIPMask(ip, mask_list)
	if type(ip) ~= "string" then return end
	if not mask_list then return true end
	for i = 1, #mask_list do
		if ip:match(mask_list[i]) then
			return true
		end
	end
end

function IsFSUnpacked()
	return (Platform.pc or Platform.osx or Platform.linux or Platform.ps4) and config.RunUnpacked
end

-- allow the engine to provide its own func
if not rawget(_G, "LocalIPs") then
function LocalIPs()
	return sockResolveName(sockGetHostName())
end
end

local function IPListInsideHG(item, ...)
	if type(item) ~= "string" then return end
	if item:match("^213%.240%.234%.%d+$") or item:match("^10%.34%.%d+%.%d+$") then return true end
	return IPListInsideHG(...)
end
function insideHG()	
	if Platform.console then return Platform.developer end
	return IPListInsideHG(LocalIPs())
end

function PlatformName()
	return 	Platform.pc and "pc" or 
				Platform.linux and "linux" or 
				Platform.osx and "osx" or 
				Platform.ios and "ios" or 
				Platform.ps4 and "ps4" or 
				Platform.ps5 and "ps5" or 
				Platform.xbox_one and "xbox_one" or
				Platform.xbox_series and "xbox_series" or
				Platform.switch and "switch" or  
				''
end

function ProviderName()
	return ''
end

function VariantName()
	return Platform.publisher and "publisher" or Platform.demo and "demo" or Platform.beta and "beta" or Platform.developer and "developer" or ''
end

function EncodeHGRunUrl(text)
	local url = Encode64(text)
	url = string.gsub(url, "[\n\r]", "")
	url = string.gsub(url, "=", "%%3D")
	return "hgrun://" .. url
end

function DecodeHGRunUrl(url)
	url = string.match(url, "hgrun://(.*)/")
	url = string.gsub(url, "%%3D", "=")
	url = Decode64(url)
	return url
end

function OpenUrl(url, force_external_browser)
	if Platform.steam and SteamIsOverlayEnabled() and IsSteamLoggedIn() and not force_external_browser then
		SteamActivateGameOverlayToWebPage(url)
	elseif Platform.pc then
		local os_command = string.format("explorer \"%s\"", url)
		os.execute(os_command)
	elseif Platform.osx then
		url = string.gsub(url, "%^", "") -- strip win shell escapes
		OpenNSURL(url)	
	elseif Platform.linux then
		AsyncExec("xdg-open " .. url)
	elseif Platform.xbox then
		XboxLaunchUri(url)
	elseif Platform.playstation then
		AsyncPlayStationShowBrowserDialog(url)
	end
end

-- Helper functions for getting coords on the night sky
function CSphereRA(h, m, s)
	local correction = -2*60 - 27 -- offset from input stars data
	return h*60*60 + m*60 + s + correction
end

function CSphereDec(d, m, s)
	local value = abs(d) * 60*60 + abs(m)*60 + abs(s)
	return d > 0 and value or -value
end

---- Infinite Loop Detection

if FirstLoad then
	IFD_PauseReasons = false
end

if not rawget(_G, "SetInfiniteLoopDetectionHook") then

ResumeInfiniteLoopDetection = empty_func
PauseInfiniteLoopDetection = empty_func

else

function ResumeInfiniteLoopDetection(reason)
	reason = reason or true
	local reasons = IFD_PauseReasons
	if not reasons then
		return
	end
	reasons[reason] = nil
	if next(reasons) then
		return
	end
	IFD_PauseReasons = false
	config.InfiniteLoopDetection = true
end

function PauseInfiniteLoopDetection(reason)
	reason = reason or true
	local reasons = IFD_PauseReasons
	if not reasons then
		if not config.InfiniteLoopDetection then
			-- disabled by default
			return
		end
		IFD_PauseReasons = { [reason] = true }
		config.InfiniteLoopDetection = false
	else
		if reasons[reason] then
			return
		end
		reasons[reason] = true
	end
	return true
end

end -- SetInfiniteLoopDetectionHook

----

function AESEncryptThenHmac(key, data)
	local err, encrypted = AESEncrypt(key, data)
	if err then return err end
	local hmac = Hmac(tostring(encrypted), SHA256(key), SHA256) -- just in case do not reuse the key directly
	if not hmac then return "hmac err" end
	return nil, encrypted .. hmac
end

function AESHmacThenDecrypt(key, data)
	assert(type(data) == "string")
	local hmac_key = SHA256(key)
	local hmac_len = hmac_key:len() -- also a SHA256
	-- sanity-check data size to be at least an AES block + hmac and to be a whole number of AES blocks
	if #data < 16 + hmac_len or #data % 16 ~= 0 then
		return "data err"
	end
	local encrypted = data:sub(1, -(hmac_key:len() + 1))
	local hmac = data:sub(-hmac_key:len())
	local calculated_hmac = Hmac(encrypted, hmac_key, SHA256)
	if not calculated_hmac or calculated_hmac ~= hmac then 
		return "hmac err"
	end
	local err, data = AESDecrypt(key, encrypted)
	return err, data
end

EncryptAuthenticated = AESEncryptThenHmac
DecryptAuthenticated = AESHmacThenDecrypt

if not Platform.cmdline then
	g_encryption_key = SHA256(GetAppId() .. (config.ProjectKey or "1ac7d4eb8be00f1bf6ae7af04142b8fc"))
end

--filename expects full relative path
function SaveLuaTableToDisk(t, filename, key)
	local shouldCompress =         not Platform.console and not Platform.developer
	local shouldEncrypt  = key and not Platform.console and not Platform.developer
	
	local data, success
	data = pstr("return ", 1024)
	local len0 = #data
	ValueToLuaCode(t, nil, data)
	success = #data > len0
	
	if not success then
		IgnoreError("empty data", "SaveLuaTableToDisk")
		return false, "empty data"
	end

	if shouldCompress then
		data = CompressPstr(data)
	end
	
	if shouldEncrypt then
		local err, result = EncryptAuthenticated(key, data)
		if err then
			IgnoreError(err, "SaveLuaTableToDisk")
			-- ATTN: we keep the original data on error
		else
			data = result
		end
	end	
	
	local err = AsyncStringToFile(filename, data, -2, 0, nil) -- -2 = overwrite entire file
	
	if err then
		IgnoreError(err, "SaveLuaTableToDisk")
		return false, err
	end
	
	return true
end

function LoadLuaTableFromDisk(filename, env, key)
	local shouldDecrypt    = key and not Platform.console
	local shouldDecompress =         not Platform.console
	
	local err, data, result
	err, data = AsyncFileToString(filename)
	
	if err then
		IgnoreError(err, "LoadLuaTableFromDisk")
		return false, err
	end
	
	if shouldDecrypt then
		err, result = DecryptAuthenticated(key, data)
		if not err then
			data = result
		else
			-- ATTN: leave original data
		end
	end
	
	local decompressedData = shouldDecompress and not data:starts_with("return ") and Decompress(data)
	if decompressedData then data = decompressedData end
	-- inlined dofile
	local func, err = load(data, nil, nil, env or _ENV)
	if not func then
		return false, "invalid data"
	end
	return procall_helper(procall(func))
end

function RSACreateKeyNoErr(data)
	local err, key = RSACreate(data)
	if err then
		assert(false, "RSA create key err: " .. err)
		return
	end
	return key
end

function RSAGenerate()
	local err, key = RSACreate()
	if err then
		assert(false, "RSA create key err: " .. err)
		return err
	end
	local err, private_str = RSASerialize(key)
	if err then
		assert(false, "RSA serialize private key err: " .. err)
		return err
	end
	local err, public_str = RSASerialize(key, true)
	if err then
		assert(false, "RSA serialize public key err: " .. err)
		return err
	end
	return nil, key, private_str, public_str
end

function CreateFileSignature(file, key)
	local err, data = AsyncFileToString(file)
	if err then
		return string.format("reading %s failed: %s", file, err)
	end
	
	local hash = SHA256(data)
	assert(#hash == 32)
	local err, sign = RSACreateSignature(key, hash)
	if err then
		return string.format("encryption failed: %s", err)
	end
	assert(#sign == 256)
	local signature = file .. ".sign"
	local err = AsyncStringToFile(signature, sign)
	if err then
		return string.format("signature %s creation failed: %s", signature, err)
	end
end

function CheckSignature(data, sign, key)
	if not key then
		return "key"
	end
	if not data then
		return "data"
	end
	if #(sign or "") ~= 256 then
		return "signature"
	end
	return RSACheckSignature(key, sign, SHA256(data))
end

---- ObjModified

if FirstLoad then
	DelayedObjModifiedList = {}
	DelayedObjModifiedThread = false
	SuspendObjModifiedReasons = {}
	SuspendObjModifiedList = false
end

function ObjListModified(list)
	local IsKindOf, IsValid = IsKindOf, IsValid
	local i = 1
	while true do
		local obj = list[i]
		if obj == nil then
			break
		end
		if type(obj) ~= "table" or not IsKindOf(obj, "CObject") or IsValid(obj) then
			ObjModified(obj, true)
		end
		i = i + 1
	end
end

function ObjModifiedDelayed(obj)
	if SuspendObjModifiedList then
		return ObjModified(obj)
	end
	local list = DelayedObjModifiedList
	assert(list)
	if not obj or not list or list[obj] then
		return
	end
	list[obj] = true
	list[#list + 1] = obj
	if IsValidThread(DelayedObjModifiedThread) then
		Wakeup(DelayedObjModifiedThread)
		return
	end
	DelayedObjModifiedThread = CreateRealTimeThread(function(list)
		while true do
			procall(ObjListModified, list)
			table.clear(list)
			WaitWakeup()
		end
	end, list)
end

function ObjModifiedIsScheduled(obj)
	return SuspendObjModifiedList and SuspendObjModifiedList[obj] or DelayedObjModifiedList and DelayedObjModifiedList[obj]
end

function ObjModified(obj, instant)
	if not obj then return end
	local objs = SuspendObjModifiedList
	if not objs or instant then
		Msg("ObjModified", obj)
		return
	end
	if objs[obj] then
		table.remove_value(objs, obj)
	else
		objs[obj] = true
	end
	objs[#objs + 1] = obj
end

function SuspendObjModified(reason)
	if next(SuspendObjModifiedReasons) == nil then
		SuspendObjModifiedList = {}
	end
	SuspendObjModifiedReasons[reason] = true
end

function ResumeObjModified(reason)
	if not SuspendObjModifiedReasons[reason] then
		return
	end
	SuspendObjModifiedReasons[reason] = nil
	if next(SuspendObjModifiedReasons) == nil then
		local objs = SuspendObjModifiedList
		SuspendObjModifiedList = false
		procall(ObjListModified, objs)
	end
end

----

function ScaleToFit(child_size, parent_size, clip)
	local x_greater = parent_size:x() * child_size:y() > parent_size:y() * child_size:x()
	if x_greater == not not clip then
		return point(parent_size:x(), child_size:y() * parent_size:x() / child_size:x())
	else
		return point(child_size:x() * parent_size:y() / child_size:y(), parent_size:y())
	end
end

function FitBoxInBox(inner, outer)
	local result = inner
	if result:maxx() > outer:maxx() then
		result = Offset(result, point(outer:maxx() - result:maxx(), 0))
	end
	if result:minx() < outer:minx() then
		result = Offset(result, point(outer:minx() - result:minx(), 0))
	end
	if result:maxy() > outer:maxy() then
		result = Offset(result, point(0, outer:maxy() - result:maxy()))
	end
	if result:miny() < outer:miny() then
		result = Offset(result, point(0, outer:miny() - result:miny()))
	end
	return result
end

function MulDivRoundPoint(point_in, multiplier, divisor)
	if type(multiplier) == "number" then
		multiplier = point(multiplier, multiplier)
	end
	if type(divisor) == "number" then
		divisor = point(divisor, divisor)
	end
	return point(MulDivRound(point_in:x(), multiplier:x(), divisor:x()), MulDivRound(point_in:y(), multiplier:y(), divisor:y()))
end

function ClassMethodsCombo(class, method_prefix, additional)
	local list = {}
	for name, value in pairs(g_Classes[class or false] or empty_table) do
		if type(value) == "function" and type(name) == "string" and name:starts_with(method_prefix) then
			list[#list + 1] = name
		end
	end
	table.sort(list)
	if additional then
		table.insert(list, 1, additional)
	end
	return list
end

function FormatNumberProp(number, scale, precision)
	local suffix = ""
	if type(scale) ~= "number" then
		suffix = " " .. scale
		scale = GetPropScale(scale)
	end
	
	local full_units = number / scale
	if number < 0 and number % scale ~= 0 then
		full_units = full_units + 1
	end
	local fractional_part = abs(number - full_units * scale)
	local number_str = full_units == 0 and number < 0 and "-0" or tostring(full_units)
	
	-- guess precision
	if not precision then
		precision = 1
		local s = scale
		while s > 10 do
			s = s / 10
			precision = precision + 1
		end
	end
	
	if precision > 0 and scale > 1 then
		local frac = ""
		local power = 1
		for i = 1, precision do
			power = power * 10
			frac = frac .. MulDivTrunc(fractional_part, power, scale) % 10
		end
		frac = frac:gsub("0*$", "") -- remove trailing zeroes
		if #frac > 0 then
			number_str = number_str .. "." .. frac
		end
	end
	return number_str .. suffix
end

function MatchThreeStateSet(set_to_match, set_any, set_all)
	if not next(set_to_match) then
		for _, is_set in pairs(set_any) do
			if is_set then
				return
			end
		end
		for _, is_set in pairs(set_all) do
			if is_set then
				return
			end
		end
		return true
	end
	if next(set_any) then
		local require_any, found_any
		for tag, is_set in pairs(set_any) do
			local found = set_to_match[tag]
			if found then
				if not is_set then
					return
				end
				found_any = true -- at least one of the required flags is present
			else
				if is_set then
					require_any = true -- there are required flags to match
				end
			end
		end
		if require_any and not found_any then
			return
		end
	end
	if next(set_all) then
		local has_disable, disable_missing
		for tag, is_set in pairs(set_all) do
			local found = set_to_match[tag]
			if is_set then
				if not found then
					return
				end
			else
				has_disable = true -- there are rejected flags to match
				if not found then
					disable_missing = true -- at least one of the rejected flags isn't present
				end
			end
		end
		if has_disable and not disable_missing then
			return
		end
	end
	return true
end

function ExecuteWithStatusUI(status, fn, wait)
	CreateRealTimeThread(function()
		local ui = StdStatusDialog:new({}, terminal.desktop, { status = status })
		ui:Open()
		WaitNextFrame(3)
		fn(ui)
		ui:Close()
		if wait then Msg("ExecuteWithStatusUI") end
	end)
	if wait then WaitMsg("ExecuteWithStatusUI") end
end

--[[
	ic - fancy print-debugging loosely inspired by https://github.com/gruns/icecream
		ic()     -- prints the current file/line
		ic(a, b) -- prints a = <value of a>, b = <value of b>; not a real parser so don't get fancy
		ic "foo" -- prints foo
	each ic() also prints time elapsed since the previous ic() in the same function, if >= 2 ms 
]]

ic = {
	print_func = print,
	prefix = "[ic] ",
	file_cache = {}, -- clear on reload
	read_file = function(self, file)
		if not self.file_cache[file] then
			local err, lines = async.AsyncFileToString(nil, file, nil, nil, "lines")
			self.file_cache[file] = { err, lines }
		end
		return table.unpack(self.file_cache[file])
	end,
	file_line = function(self, file, line)
		local err, lines = self:read_file(file)
		if err then 
			return err 
		end
		return false, tostring(lines[line])
	end,
	file_line_parsed_cache = {}, -- clear on reload
	parse_file_line = function(self, call_line)
		local file, line = call_line:match("^(.-)%((%d+)%)$")
		line = tonumber(line)
		if not file and not line then
			return "can't parse file/line from " .. call_line
		end
		local err, source_line = self:file_line(file, line)
		if err then 
			return err 
		end
		local source_args = source_line:match("ic%s*(%b())") or source_line:match([[ic%s*(%b"")]])
		if not source_args then 
			return "can't parse arguments from " .. call_line
		end
		if source_args:starts_with("(") then
			source_args = source_args:sub(2, -2)
		end
		return false, source_args:split("%s*,%s*")
	end,
	file_line_args = function(self, call_line)
		if not self.file_line_parsed_cache[call_line] then
			self.file_line_parsed_cache[call_line] = { self:parse_file_line(call_line) }
		end
		return table.unpack(self.file_line_parsed_cache[call_line])
	end,
	__call = function(self, ...)
		local args = {...}
		local call_line = GetCallLine(2)
		local ret
		if not next(args) then
			ret = call_line
		else
			local err, source_args = self:file_line_args(call_line)
			if err then 
				ret = err
			else
				local rets = {}
				for i, source_arg in ipairs(source_args) do
					if source_arg:starts_with([["]]) and source_arg:ends_with([["]]) then
						rets[i] = source_arg:match([["(.-)"]])
					elseif source_arg:match("^%d+$") then
						rets[i] = source_arg
					else
						rets[i] = source_arg .. " = " .. ValueToLuaCode(args[i], ' ')
					end
				end
				ret = table.concat(rets, ", ")
			end
		end

		local func = debug.getinfo(2).func
		if self.profile_func ~= func then
			self.profile_time = GetPreciseTicks()
			self.profile_func = func
		else
			local t = GetPreciseTicks()
			local elapsed = t - self.profile_time
			if elapsed > 1 then
				ret = ret .. " (+" .. tostring(elapsed) .. " ms)"
			end
			self.profile_time = t
		end

		self.print_func(self.prefix .. ret)
	end,
}

setmetatable(ic, ic)


----- Pausing threads (used by XWindowInspector)

if FirstLoad then
	PauseLuaThreadsOldGT = false
	PauseLuaThreadsOldRT = false
	PauseLuaThreadsReasons = {}
end

function PauseLuaThreads(reason)
	if next(PauseLuaThreadsReasons) then return end
	PauseLuaThreadsReasons[reason or false] = true
	
	PauseLuaThreadsOldGT = AdvanceGameTime
	PauseLuaThreadsOldRT = AdvanceRealTime
	AdvanceGameTime = function(time) -- time is ignored
		PauseLuaThreadsOldGT(GameTime())
	end
	AdvanceRealTime = function(time) -- time is ignored
		PauseLuaThreadsOldRT(now())
		local desktop = terminal.desktop
		if desktop.measure_update or desktop.layout_update then
			desktop:MeasureAndLayout()
		end
		if rawget(_G, "g_LuaDebugger") and g_LuaDebugger.update_thread then
			g_LuaDebugger:DebuggerTick()
		end
		if rawget(_G, "LuaReloadRequest") then
			LuaReloadRequest = false
			ReloadLua()
		end
	end
	Msg("LuaThreadsPaused", true)
end

function ResumeLuaThreads(reason)
	if not next(PauseLuaThreadsReasons) then return end
	
	PauseLuaThreadsReasons[reason or false] = nil
	if next(PauseLuaThreadsReasons) then return end
	
	AdvanceGameTime = PauseLuaThreadsOldGT
	AdvanceRealTime = PauseLuaThreadsOldRT
	Msg("LuaThreadsPaused", false)
end

function AreLuaThreadsPaused()
	return not not next(PauseLuaThreadsReasons)
end

function RoundUp(x, period)
	if x % period == 0 then
		return x
	end
	return ((x / period) + 1) * period
end

function ConvertToBenderProjectPath(path)
	path = string.gsub(path or "", "/", "\\")
	if string.starts_with(path, "\\") then
		path = string.sub(path, 2)
	end
	return string.format("\\\\bender.haemimontgames.com\\%s\\%s", const.ProjectName or ProjectEnv.project, path)
end

if FirstLoad then
	SearchStringsInFilesCache = false
end

function SearchStringsInFiles(strings, files, string_to_files, threads, silent)
	threads = Max(1, threads or tonumber(os.getenv("NUMBER_OF_PROCESSORS")))
	
	local st = GetPreciseTicks()
	local count = 0
	string_to_files = string_to_files or {}
	local function SearchForStringsInFile(file)
		local data
		local err, src_modified, src_size = AsyncGetFileAttribute(file)
		SearchStringsInFilesCache = SearchStringsInFilesCache or {}
		local cache = SearchStringsInFilesCache[file]
		if not err and cache and cache.src_modified == src_modified and cache.src_size == src_size then
			data = cache.data
		end
		if not data then
			local err
			err, data = AsyncFileToString(file, nil, nil, "pstr")
			if err then
				return
			end
			cache = {
				data = data,
				src_modified = src_modified,
				src_size = src_size,
			}
			SearchStringsInFilesCache[file] = cache
		end
		for _, str in ipairs(strings) do
			local files = string_to_files[str] or {}
			if not files[file] then
				local searches = cache.searches or {}
				local search = searches[str]
				if not search then
					search = ""
					local err, idx = AsyncStringSearch(data, str, false, true)
					if idx then
						local code = string.byte('\n')
						local len = #data
						local from = idx - 1
						while from > 0 and data:byte(from) ~= code do
							from = from - 1
						end
						from = from + 1
						local to = idx + #str
						while to <= len and data:byte(to) ~= code do
							to = to + 1
						end
						to = to - 1
						search = data:sub(from, to)
					end
					searches[str] = search
					cache.searches = searches
				end
				if search ~= "" then
					files[file] = search
					string_to_files[str] = files
				end
			end
		end
		count = count + 1
		if not silent then
			print("Files processed:", count, "/", #files)
		end
	end
	parallel_foreach(files, SearchForStringsInFile, nil, threads)
	if not silent then
		printf("All files processed in %.1f s", (GetPreciseTicks() - st) / 1000.0)
	end
	return string_to_files
end

function WaitCopyDir(src, dest)
	src = ConvertToOSPath(SlashTerminate(src))
	dest = ConvertToOSPath(SlashTerminate(dest))
	local err, files = AsyncListFiles(src, nil, "recursive,relative")
	for _, file in ipairs(files) do
		local path, filename, ext = SplitPath(file)
		err = err or AsyncCreatePath(dest .. path)
		err = err or AsyncCopyFile(src .. file, dest .. file, "raw")
	end
	return err
end

function MakeLine(start_y, end_y, max_x)
	start_y = start_y or 1000
	end_y = end_y or 1000
	max_x = max_x or 1000

	local points = {}
	local slope = end_y - start_y
	for i = 0, 3 do
		local y = start_y + MulDivRound(i, slope, 3)
		table.insert(points, point(MulDivRound(i, max_x, 3), y, y))
	end
	return points
end

----

function GetPlatformName()
	if Platform.pc then
		return "win32"
	elseif Platform.osx then
		return "osx"
	elseif Platform.linux then
		return "linux"
	elseif Platform.ios then
		return "ios"
	elseif Platform.ps4 then
		return "ps4"
	elseif Platform.ps5 then
		return "ps5"
	elseif Platform.xbox_one then
		return "xbox_one"
	elseif Platform.xbox_series then
		return "xbox_series"
	elseif Platform.switch then
		return "switch"
	else
		return "unknown"
	end
end

----

SuspendErrorOnMultiCall = empty_func
ResumeErrorOnMultiCall = empty_func
ErrorOnMultiCall = empty_func

if Platform.developer then
	MultiCallRegistered = {}
	ErrorOnMultiCall = function(func_name, count, class_name)
		local idx = table.find(MultiCallRegistered, 1, func_name) or (#MultiCallRegistered + 1)
		MultiCallRegistered[idx] = {func_name, count, class_name}
	end
end
