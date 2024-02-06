----------------------------
---- CODE SERIALIZATION ----
----------------------------

LuaKeywords = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["goto"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}
local LuaKeywords = LuaKeywords

function IsIdentifierName(key)
	return string.match(key, "^[_%a][_%w]+$") and not LuaKeywords[key]
end
local IsIdentifierName = IsIdentifierName

function FormatKey(k, pstr)
	local type = type(k)
	assert(type == "number" or type == "boolean" or type == "string", "Trying to use an object for a key?")
	if type == "number" then
		if not pstr then
			return string.format("[%d] = ", k)
		else
			return pstr:appendf("[%d] = ", k)
		end
	elseif type == "boolean" then
		local fkey = k and "[true] = " or "[false] = "
		if not pstr then
			return fkey
		else
			return pstr:append(fkey)
		end
	elseif IsIdentifierName(k) then
		if not pstr then
			return k .. " = "
		else
			return pstr:append(k, " = ")
		end
	else
		if not pstr then
			return string.format("[%s] = ", StringToLuaCode(k))
		else
			pstr:append("[")
			pstr:appends(k)
			return pstr:append("] = ")
		end
	end
end

function prop_eval(value, obj, prop_meta, def)
	while type(value) == "function" do
		local ok
		ok, value = procall(value, obj, prop_meta)
		if not ok then
			return def
		end
	end
	return value
end
local eval = prop_eval

--[[@@@
Converts a value to an executable Lua expresion.
Use _'LuaCodeToTuple()'_ for evaluating the Lua expression.
@function string code ValueToLuaCode(value, int indent)
@param value - value to be converted.
@param int indent - initial number of indentations.
@param pstr pstr - pstr string to serialize into.
@param table injected_props - table with metadata of properties injected from parent objects.
@result string code - the supplied value, converted to Lua code.
]]
function ValueToLuaCode(value, indent, pstr, injected_props)
	assert(not pstr or type(pstr) == "userdata")
	if pstr then
		return pstr:appendv(value, indent, injected_props)
	end
	local vtype = type(value)
	if vtype == "nil" then
		return "nil"
	end
	if vtype == "boolean" then
		return value and "true" or "false"
	end
	if vtype == "number" then
		return tostring(value)
	end
	if vtype == "string" then
		return StringToLuaCode(value)
	end
	if vtype == "function" then
		return GetFuncSourceString(value, "")
	end
	if vtype == "userdata" or vtype == "table" then
		local meta = getmetatable(value)
		local __toluacode = meta and meta.__toluacode
		if __toluacode then
			return __toluacode(value, indent, nil, nil, injected_props)
		end
		if vtype == "table" then
			return TableToLuaCode(value, indent, nil, injected_props)
		end
		if IsPStr(value) then
			return StringToLuaCode(value)
		end
		if Request_IsTask(value) then
			return value:GetResource()
		end
		assert(false, "User data with missing __toluacode method!")
		return "nil"
	end
end

local function ObjectHandlesHelperNoPstr(value, ret)
	for i=1, #value do
		if type(value[i]) == "boolean" or (not IsValid(value[i]) or value[i]:GetGameFlags(const.gofPermanent) == 0) then
			ret[#ret + 1] = "false,"
		elseif not value[i].handle then
			assert(false, "serializing object without handle")
		else
			ret[#ret + 1] = string.format("o(%d),", value[i].handle)
		end
	end
end

local function ObjectHandlesHelperPstr(value, pstr)
	for i=1, #value do
		if type(value[i]) == "boolean" or (not IsValid(value[i]) or value[i]:GetGameFlags(const.gofPermanent) == 0) then
			pstr:append("false,")
		elseif not value[i].handle then
			assert(false, "serializing object without handle")
		else
			pstr:appendf("o(%d),", value[i].handle)
		end
	end
end

local function ProcessIndentPlusOneHelper(indent)
	local ret = ""
	if type(indent) == "string" then
		ret = string.format("%s%s", indent, "    ")
	else
		for i = 1, indent + 1 do
			ret = string.format("%s%s", ret, "    ")
		end
	end
	
	return ret
end

function PropToLuaCode(value, vtype, indent, pstr, prop_meta, obj, injected_props)
	assert(not vtype or type(vtype) == "string")
	assert(not pstr or type(pstr) == "userdata")
	
	if vtype == "bool" or vtype == "boolean" then
		return ValueToLuaCode(not not value, indent, pstr)
	end
	if vtype == "string" or vtype == "text" then
		if type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then
			return TToLuaCode(value, ContextCache[value], pstr)
		end
	end
	if vtype == "rgbrm" then
		local r, g, b, ro, m = GetRGBRM(value)
		local a = GetAlpha(value)
		assert(a == 255)
		if ro == 0 and m == 0 then
			local fmt = "RGBA(%d, %d, %d, %d)"
			if not pstr then
				return string.format(fmt, r, g, b, a)
			else
				return pstr:appendf(fmt, r, g, b, a)
			end
		end
		local fmt = "RGBRM(%d, %d, %d, %d, %d)"
		if not pstr then
			return string.format(fmt, r, g, b, ro, m)
		else
			return pstr:appendf(fmt, r, g, b, ro, m)
		end
	end
	if vtype == "packedcurve" then
		local pt1, pt2, pt3, pt4, max_y = UnpackCurveParams(value)
		local fmt = "PackCurveParams(%d, %d, %d, %d, %d, %d, %d, %d, %d)"
		if not pstr then
			return string.format(fmt, pt1:x(), pt1:y(), pt2:x(), pt2:y(), pt3:x(), pt3:y(), pt4:x(), pt4:y(), max_y)
		else
			return pstr:appendf(fmt, pt1:x(), pt1:y(), pt2:x(), pt2:y(), pt3:x(), pt3:y(), pt4:x(), pt4:y(), max_y)
		end
	end
	if vtype == "color" then
		local r, g, b, a = GetRGBA(value)
		local fmt = "RGBA(%d, %d, %d, %d)"
		if not pstr then
			return string.format(fmt, r, g, b, a)
		else
			return pstr:appendf(fmt, r, g, b, a)
		end
	end
	if vtype == "set" then
		value = IsSet(value) and value or setmetatable(value, __set_meta)
		return ValueToLuaCode(value, indent, pstr)
	end
	if vtype == "object" then
		if not value.handle then
			assert(false, "serializing object without handle")
			return
		end
		if not pstr then
			return string.format("o(%d)", value.handle)
		else
			return pstr:appendf("o(%d)", value.handle)
		end
	end
	if vtype == "objects" then
		if not pstr then
			local ret = { "{" }
			if #value == 0 and next(value) then
				local indentStr = ProcessIndentPlusOneHelper(indent)
				
				for k, v in sorted_pairs(value) do
					if not v then --uninitialized
						ret[#ret + 1] = string.format("\n%s%s = false,", indentStr, k)
					elseif IsKindOf(v, "Object") then --single nested object
						ret[#ret + 1] = string.format("\n%s%s = o(%d),", indentStr, k, v.handle)
					else --table
						ret[#ret + 1] = string.format("\n%s%s = {", indentStr, k)
						ObjectHandlesHelperNoPstr(v, ret)
						ret[#ret + 1] = "},"
					end
				end
			else
				ObjectHandlesHelperNoPstr(value, ret)
			end
			
			ret[#ret + 1] = "}"
			return table.concat(ret)
		else
			pstr:append("{")
			if #value == 0 and next(value) then
				local indentStr = ProcessIndentPlusOneHelper(indent)
				
				for k, v in sorted_pairs(value) do
					if not v then --uninitialized
						pstr:append(string.format("\n%s%s = false,", indentStr, k))
					elseif IsKindOf(v, "Object") then --single nested object
						pstr:append(string.format("\n%s%s = o(%d),", indentStr, k, v.handle))
					else --table
						pstr:append(string.format("\n%s%s = {", indentStr, k))
						ObjectHandlesHelperPstr(v, pstr)
						pstr:append("},")
					end
				end
			else
				ObjectHandlesHelperPstr(value, pstr)
			end
			return pstr:append("}")
		end
	end
	if vtype == "range" then
		value = IsRange(value) and value or setmetatable(value, __range_meta)
		return ValueToLuaCode(value, indent, pstr)
	end
	if vtype == "browse" then
		if not pstr then
			return string.format("%q", value)
		else
			return pstr:appendf("%q", value)
		end
	end
	if vtype == "func" or vtype == "expression" then
		local src = GetFuncSourceStringIndent(indent, value, "", eval(prop_meta.params, obj, prop_meta) or "self")
		if not pstr then
			return src
		else
			Msg("OnFunctionSerialized", pstr, value)
			return pstr:append(src)
		end
	end
	return ValueToLuaCode(value, indent, pstr, injected_props)
end

--[[@@@
Converts a tuple of values to an executable Lua expression.
Use [LuaCodeToTuple](#LuaCodeToTuple) for evaluating the Lua expression.
@function string code TupleToLuaCode(values...)
@param values... - tuple of values to be converted to executable code string.
@result string code - the supplied tuple, converted to Lua code.
]]
function TupleToLuaCode(...)
	local values = pack_params(...)
	if not values then return "" end
	for i = 1, values.n or #values do
		values[i] = ValueToLuaCode(values[i], " ") or "nil"
	end
	return table.concat(values, ",")
end

local function _load(ok, ...)
	if ok then
		return nil, ...
	else
		return ...
	end
end

local function procall_helper2(ok, ...)
	if not ok then return ... or "error" end
	return nil, ...
end

local default_env
function FileToLuaValue(filename, env)
	default_env = default_env or LuaValueEnv{}
	local err, data
	err, data = AsyncFileToString(filename)
	if err then return err end
	local func, err	
	if not string.starts_with(data, "return") then
		data = "return " .. data
	end
	func, err = load(data, nil, nil, env or default_env)
	if not func then return err end
	return procall_helper2(procall(func))
end

--[[@@@
Evaluates a string generated using [TupleToLuaCode](#TupleToLuaCode) and returns the original values.
@function error, values LuaCodeToTuple(string code, table env)
@param string code - code to be evaluated.
@param table env - evaluation environment.
@result error, values - error string (or nil, if none) and the evaluated tuple.
]]
function LuaCodeToTuple(code, env)
	local err, code = ChecksumRemove(code)
	if err then return err end
	local func, err = load("return " .. (code or ""), nil, nil, env or _ENV)
	if func then
		return _load(pcall(func))
	end
	return err
end

function TableToLuaCode(tbl, indent, pstr, injected_props)
	assert(not pstr or type(pstr) == "userdata")
	if pstr then
		return pstr:appendt(tbl, indent, false, injected_props)
	end
	
	if type(indent) == "number" then
		indent = string.rep("\t", indent)
	end
	
	if next(tbl) == nil or indent and #indent > 100 then
		assert(not indent or #indent <= 100, "too many nested values")
		return "{}"
	end
	
	indent = indent or ""
	local new_indent = indent == " " and indent or indent .. "\t"
	local lines = {}

	local keys = {}
	for key in pairs(tbl) do
		if type(key) ~= "number" or key < 1 or key > #tbl then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, lessthan)
	for i, key in ipairs(keys) do
		if key ~= "__index" then
			local value = ValueToLuaCode(tbl[key], new_indent, nil, injected_props)
			if value then
				lines[#lines + 1] = FormatKey(key) .. value
			end
		end
	end
	local only_numbers = #lines == 0
	for i = 1, #tbl do
		local value = tbl[i]
		only_numbers = only_numbers and type(value) == "number"
		lines[#lines + 1] = ValueToLuaCode(value, new_indent, nil, injected_props) or "nil"
	end
	if indent == " " or #lines == 0 or only_numbers then
		return string.format("{%s}", table.concat(lines, ","))
	end
	local code = table.concat(lines, ",\n\t" .. indent)
	return string.format("{\n\t%s%s,\n%s}", indent, code, indent)
end

function ObjPropertyListToLuaCode(obj, indent, GetPropFunc, pstr, additional, injected_props)
	indent = indent or ""
	local new_indent
	if not pstr then
		new_indent = indent == " " and indent or indent ~= "" and indent .. "\t" or "\t"
	else
		indent = type(indent) == "number" and indent or 0
		new_indent = indent >= 0 and indent + 1 or indent
	end
	
	local code
	local props = obj:GetProperties()
	local prop_count = #props
	for i = 1, prop_count + #injected_props do
		local prop = i > prop_count and injected_props[ i - prop_count ] or props[ i ]
		local id = prop.id
		if injected_props and i <= prop_count and eval(prop.inject_in_subobjects, obj, prop) then
			injected_props[#injected_props + 1] = prop
		end
		
		local editor = eval(prop.editor, obj, prop)
		if not eval(prop.dont_save, obj, prop) and editor then
			local value
			if GetPropFunc then
				value = GetPropFunc(obj, id, prop)
			else
				value = obj:GetProperty(id)
			end
			if not obj:IsDefaultPropertyValue(id, prop, value) then
				if not pstr then
					value = PropToLuaCode(value, editor, new_indent, nil, prop, obj, injected_props)
					if value then
						code = code or { "{" }
						code[#code + 1] = string.format("\t'%s', %s,", id, value)
					else
						assert(false, print_format("ToLuaCode:", id, "cannot be saved as", editor))
					end
				else
					if not code then
						code = true
						if indent < 0 then
							pstr:append("{ ")
						else
							pstr:append("{\n")
							pstr:appendr("\t", indent)
						end
					end
					local len = #pstr
					pstr:appendf("\t'%s', ", id)
					if PropToLuaCode(value, editor, new_indent, pstr, prop, obj, injected_props) then
						if indent < 0 then
							pstr:append(", ")
						else
							pstr:append(",\n")
							pstr:appendr("\t", indent)
						end
					else
						pstr:resize(len)
						assert(false, string.format("ToLuaCode: %s.%s cannot be saved as %s", obj.class, id, editor))
					end
				end
			end
		end
	end
	if code then
		if not pstr then
			if additional then
				code[#code + 1] = additional
			end
			code[#code + 1] = "}"
			return table.concat(code, indent == " " and " " or "\n" .. indent)
		else
			if additional then
				pstr:append(additional)
			end
			return pstr:append("}")
		end
	end
end

function ArrayToLuaCode(array, indent, pstr, injected_props)
	if not array or #array == 0 then return end
	indent = indent or ""
	local new_indent
	if not pstr then
		new_indent = indent ~= "" and (indent .. "\t") or "\t"
		local code = { }
		for i = 1, #array do
			local value = rawget(array, i)
			assert(value ~= nil, "ArrayToLuaCode: nil value")
			value = ValueToLuaCode(value, new_indent, nil, injected_props)
			assert(value, "ArrayToLuaCode: Value cannot be saved")
			code[#code + 1] = value
		end
		code[#code + 1] = "}"
		code[1] = "{\n" .. new_indent .. code[1]
		return table.concat(code, ",\n\t" .. indent)
	else
		indent = type(indent) == "number" and indent or 0
		new_indent = indent >= 0 and indent + 1 or indent
		pstr:append("{\n")
		pstr:appendr("\t", new_indent)
		for i = 1, #array do
			local value = rawget(array, i)
			assert(value ~= nil, "ArrayToLuaCode: nil value")
			pstr:appendv(value, new_indent, injected_props)
			pstr:append(",\n\t")
			pstr:appendr("\t", indent)
		end
		return pstr:append("}")
	end
end

function CopyValue(value)
	local vtype = type(value)
	if vtype == "number" or vtype == "string" or vtype == "boolean" or vtype == "nil" then
		return nil, value
	end
	local success, code = procall(ValueToLuaCode, value)
	if not success then return code end
	local success, err, copy = procall(LuaCodeToTuple, code)
	assert(success, err)
	if not success then return err end
	assert(not err, err)
	if err then return err end
	return nil, copy
end

-------------------------
---- FUNCTION SOURCE ----
-------------------------

if FirstLoad then
	FuncSource = setmetatable({}, weak_keys_meta) -- cache for the source code of functions
	LuaSource = {} -- cache for Lua source files; will NOT be updated for externally changed files
end

function FetchLuaSource(file_name, no_cache)
	if not no_cache then
		local source = LuaSource[file_name]
		if source then return source end
	end
	
	local err, content = AsyncFileToString(file_name, nil, nil, "lines")
	if err then return end
	LuaSource[file_name] = content
	return content
end

function CacheLuaSourceFile(file_name, source)
	LuaSource[file_name] = type(source) == "table" and source or string.split(tostring(source), "\n")
end

function InvalidateGetFuncSourceCache()
	LuaSource = {}
end

--- Parses the source file of a function and returns its name, params and body
-- @cstyle name, params, body GetFuncSource(func f).
-- @param f function;
-- @return name string, params string with comma-separated params, body is either a string or a table with strings for multiline functions.
function GetFuncSource(f, no_cache)
	assert(not f or type(f) == "function")
	if not f or type(f) ~= "function" then return end
	
	if not no_cache then
		local name, params, body = unpack_params(FuncSource[f or false])
		if body then
			return name, params, body
		end
	end
	
	local info = debug.getinfo(f, "S")
	local first, last = info.linedefined, info.lastlinedefined
	local source = info.source
	if not info or not source or not first or not last then return end
	
	local file_contents
	if source:sub(1, 1) == "@" then
		file_contents = FetchLuaSource(source:sub(2), no_cache)
		if not file_contents then return end
	else -- compiled from a string, e.g. from LuaCodeToTuple
		file_contents = string.split(info.source, "\n")
	end
	
	local first_line = (file_contents[first] or "")
	local name, params, body_start = first_line:match("%f[%w]function%f[%W]%s*([%w:._]*)%s*%(([%w%s,._]-)%)%s*()")
	if not body_start then return end
	if first == last then
		local body = first_line:match("^(.*)%f[%w]end%f[^%w_]", body_start)
		body = body and body:match("(.-)%s*$")
		FuncSource[f] = { name, params, body }
		return name, params, body, first, last, file_contents
	else
		--print("first", file_contents[first])
		local b = first_line:sub(body_start, -1)
		if b == "" then b = nil end
		--print(name, params, b, "n")
		local body = { b }
		local tabs
		for i = first + 1, last do
			local current_line = file_contents[i]
			if i == last then
				current_line = (current_line or ""):match("(.-)%s*%f[%w]end%f[^%w_]")
				if not current_line then return end
				if current_line == "" then break end
			end
			if not tabs then
				tabs = string.match(current_line, "^[\n\r ]*(\t*)")
			end
			if tabs then
				local current_tabs = string.match(current_line, "^(\t*)") or ""
				current_line = current_line:sub(Min(#tabs, #current_tabs) + 1)
			end
			body[#body + 1] = current_line
		end
		FuncSource[f] = { name, params, body }
		return name, params, body, first, last, file_contents
	end
end

if FirstLoad then
	missing_source_func = function()
		assert(false, "Missing func!")
	end
end

function GetMissingSourceFallback()
	assert(false, "Func source missing!")
	return missing_source_func
end

--- Parses the source file of a function and returns its ready for compilation source.
-- @cstyle string GetFuncSourceString(func f, string new_name, string new_params).
-- @param f function;
-- @param new_name string; optional name to be used instead of the original one.
-- @param new_params string; optional parameters to be used instead of the original ones.
-- @return function source.
function GetFuncSourceString(f, new_name, new_params)
	if f ~= missing_source_func then
		local name, params, body = GetFuncSource(f)
		if not body then
			print("WARNING: Unable to retrieve a function's source code while saving!\n", rawget(_G, "FindFunctionByAddress") and TableToLuaCode(FindFunctionByAddress(f)) or "(unknown)")
		else
			name = new_name or name
			params = new_params or params
			if type(body) == "string" then
				return string.format("function %s(%s) %s end", name, params, body)
			else
				return string.format("function %s(%s)\n%s\nend", name, params, table.concat(body, "\n"))
			end
		end
	end
	return "GetMissingSourceFallback()"
end

--- Compiles a function and stores its source code in FuncSource so that it can be looked up with GetFuncSource/GetFuncSourceString later.
-- @cstyle function CompileFunc(string name, string params, string body, string chunkname).
-- @param name string; function name.
-- @param params string; function parameters.
-- @param body string; function body without the final end statement.
-- @return function, error.
function CompileFunc(name, params, body, chunkname)
	local src = string.format("return function (%s) %s\nend", params or "", body)
	local f, err = load(src, chunkname or string.format("%s(%s)", name or "func", params or ""))
	f = f and f() or function() printf("bad function %s(%s): %s", name, params, err) end
	body = string.split(body, "\n")
	if not err then
		FuncSource[f] = { name, params or "", body, err }
	end
	return f, err
end

--- Compiles an expression returning a value. If needed adds "return " before the expression.
-- @cstyle function CompileExpression(string name, string params, string body, string chunkname).
-- @param name string; function name.
-- @param params string; function parameters.
-- @param body string; function body without the final end statement.
-- @return function, error.
function CompileExpression(name, params, body, chunkname)
	body = body:match("^%s*(.-)%s*$")
	if not body:find("return ", 1, true) then
		body = "return " .. body
	end
	local src = string.format("local function %s(%s) %s end\nreturn %s", name, params or "", body, name)
	local f, err = load(src, chunkname or ("expression " .. (params or "")))
	f = f and f() or function() printf("bad expression %s(%s): %s", name, params, err) end
	if not err then
		FuncSource[f] = { name, params or "", body }
	end
	return f, err
end

function GetFuncSourceStringIndent(indent, ...)
	local src = GetFuncSourceString(...)
	
	-- Make sure that we don't persist a function with "end end" as the last line,
	-- because GetFuncSource can't correctly find the function code end in this case.
	--
	-- Fix up code formatting as well (each function compiled with CompileExpression
	-- that has a composite statement will be formatted on multiple lines)
	if src:find("%send%W") and src:ends_with(" end") then
		local first, last = src:find("function%s*%b() ")
		if first == 1 then
			src = src:sub(1, last - 1) .. "\n" .. src:sub(last + 1)
		end
		src = src:sub(1, -5) .. "\nend"
	end
	
	local internal_indent
	if type(indent) == "number" then
		if indent <= 0 then
			return src
		end
		internal_indent = string.rep("\t", indent + 1)
		indent = string.rep("\t", indent)
	elseif indent == " " then
		return src
	else -- tabs
		internal_indent = indent .. "\t"
	end

	local lines = string.split(src, "\n")
	for i = 2, #lines - 1 do 
		lines[i] = internal_indent .. lines[i]
	end
	if #lines > 2 then
		lines[#lines] = indent .. lines[#lines]
	end
	
	return table.concat(lines, "\n")
end

-- returns the function body (with no enclosing function(...) end)
function GetFuncBody(func, indent, default)
	local name, params, body = GetFuncSource(func)
	if type(body) == "table" then
		indent = indent or ""
		return indent .. table.concat(body, "\n" .. indent)
	elseif type(body) == "string" then
		return (indent or "") .. body
	end
	return default or ""
end

-- returns the expression "value" (with no return keyword)
function GetExpressionBody(func)
	local body = GetFuncBody(func)
	assert(body == "" or body:starts_with("return"))
	return #body >= 8 and body:sub(8) or "nil"
end
