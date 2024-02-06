config.DebugAdapterPort = config.DebugAdapterPort or 8165

-- NOTE: for setExpression request to work:
--		1) provide evaluateName for the editable property
--		2) supportsSetExpression = true
--		3) supportsSetVariable = false/nil
-- The following config variable forces the above three
config.DebugAdapterUseSetExpression = false

config.MaxWatchLenValue = config.MaxWatchLenValue or 512
config.MaxWatchLenKey = config.MaxWatchLenKey or 128

if FirstLoad then
	__tuple_meta = { __name = "tuple" }
end

local function IsTuple(value)
	return type(value) == "table" and getmetatable(value) == __tuple_meta
end

----- DASocket

DASocket = rawget(_G, "DASocket") or { -- simple lua table, since it needs to work before the class resolution
	request = false, -- the current request being processed
	state = false, -- false, "running", "stopped"
	manual_pause = false,
	in_break = false,
	debug_blacklisted = false,
	callstack = false,
	scope_frame = false,
	stack_vars = false,
	breakpoints = false,
	condition_env = false,
	var_ref_idx = false,
	ref_to_var = false,

	Capabilities = {
		supportsConfigurationDoneRequest = true,
		supportsTerminateRequest = true,
		supportTerminateDebuggee = true,
		supportsConditionalBreakpoints = true,
		supportsHitConditionalBreakpoints = true,
		supportsLogPoints = true,
		supportsSetVariable = not config.DebugAdapterUseSetExpression,
		supportsSetExpression = config.DebugAdapterUseSetExpression,
		supportsVariableType = true,
		supportsCompletionsRequest = true,
		completionTriggerCharacters = {".", ":", "}"},
		supportsBreakpointLocationsRequest = true,	-- comes after setBreakpoints request!

		-- NOTE: no idea how to trigger these requests: 
		--supportsEvaluateForHovers = true,		-- only evaluate request with 'watch' context comming(no 'hover')
		--supportsGotoTargetsRequest = true,	-- no official Lua API and hacking the Lua stack seems to crash the engine
		--supportsModulesRequest = true,		-- not received - seems it is implemented for VS but not for VSCode
		--additionalModuleColumns = {{attributeName = "name", label = "label"}},
		--supportsDelayedStackTraceLoading = true,	-- we show the whole stack anyway
		-- NOTE: we may have 5k threads
		--supportsTerminateThreadsRequest = true,
		--supportsSingleThreadExecutionRequests = true,
		--supportsValueFormattingOptions = true,	-- no special formatting options
		--supportsLoadedSourcesRequest = true,
	},
}
setmetatable(DASocket, JSONSocket)
DASocket.__index = DASocket

function DASocket:OnDisconnect(reason)
	---[[]] self:Logf("OnDisconnect %s", tostring(reason) or "")
	table.remove_value(DAServer.debuggers, self)
	printf("DebugAdapter connection %d %s:%d lost%s", self.connection, self.host, self.port, reason and ("(" .. reason .. ")") or "")
end

function DASocket:OnMsgReceived(message, headers)
	local msg_type = message.type
	if msg_type == "event" then
		local func = self["Event_" .. message.event]
		if func then
			return func(self, message.body)
		end
	elseif msg_type == "request" then
		local func = self["Request_" .. message.command]
		if func then
			---[[]]self:Logf("Message: %s", ValueToLuaCode(message))
			self.request = message
			local ok, err, response = pcall(func, self, message.arguments)
			if not ok then
				print("DebugAdapter error:", err)
				return
			end
			assert(self.request or (not err and response == nil)) -- if a response was sent there should be no return values
			if self.request then -- if response not send, send it now
				return self:SendResponse(err, response)
			end
			return
		end
	elseif msg_type == "response" then
		local func = self.result_callbacks and self.result_callbacks[message.request_seq]
		if func then
			return func(self, message)
		end
	end
	return "Unhandled message"
end

function DASocket:SendEvent(event, body)
	self.seq_id = (self.seq_id or 0) + 1
	return self:Send{
		type = "event",
		event = event,
		body = body,
		seq = self.seq_id,
	}
end

function DASocket:SendResponse(err, response)
	local request = self.request
	self.request = nil
	assert(request)
	if not request then return end
	self.seq_id = (self.seq_id or 0) + 1
	return self:Send{
		type = "response",
		request_seq = request.seq,
		success = not err,
		message = err or nil,
		command = request.command,
		body = response or nil,
		seq = self.seq_id,
	}
end

function DASocket:SendRequest(command, arguments, callback)
	self.seq_id = (self.seq_id or 0) + 1
	local err = self:Send{
		type = "request",
		command = command,
		arguments = arguments or nil,
		seq = self.seq_id,
	}
	if err then return err end
	CreateRealTimeThread(function(self, seq) -- clear the callback in 60sec
		Sleep(60000)
		self.result_callbacks[seq] = nil
	end, self, self.seq_id)
	self.result_callbacks = self.result_callbacks or {}
	self.result_callbacks[self.seq_id] = callback or nil
end


----- References

local reference_pool_size = 100000000
local modules_start = 1 * reference_pool_size
local threads_start = 2 * reference_pool_size
local variables_start = 3 * reference_pool_size
local reference_types = { "module", "thread", "variables"}
function DASocket:GetReferenceType(id)
	return reference_types[id / reference_pool_size]
end


----- Events

function DASocket:Event_StopDAServer()
	-- this comes form another debugee requesting us to stop the DAServer so it can be debugged
	self:Logf("DebugAdapter stopped listening")
	if DAServer.listen_socket then
		sockDisconnect(DAServer.listen_socket)
		DAServer.listen_socket:delete()
		DAServer.listen_socket = nil
	end
end


----- Requests

function DASocket:Request_initialize(arguments)
	if arguments.clientName then
		self.event_source = arguments.clientName .. " "
	end
	self.linesStartAt1 = arguments.linesStartAt1
	self.columnsStartAt1 = arguments.columnsStartAt1
	self.client = arguments
	self:SendResponse(nil, self.Capabilities)
	DebuggerInit()
	DebuggerClearBreakpoints()
	self.condition_env = {}
	setmetatable(self.condition_env, {
		__index = DebuggerIndex
	})
	self:SendEvent("initialized")
end

function DASocket:Request_configurationDone(arguments)
	-- marks the end of initialization
	self:Continue()
end

function DASocket:Request_attach(arguments)
	self:SendResponse()
end

function DASocket:Request_disconnect(arguments)
	self.state = false
	self:SendResponse()
	if arguments.restart then
		CreateRealTimeThread(restart, GetAppCmdLine())
	elseif arguments.terminateDebuggee then
		CreateRealTimeThread(quit)
	end
end

function DASocket:Request_threads(arguments)
	local threads = {
		{ id = threads_start + 1, name = "Global" }
	}
	return nil, { threads = threads }
end


-- returns table of lines with all the comments removed
local function GetCleanSourceCode(filename)
	-- capitalize the drive letter to avoid casing mismatches
	filename = string.upper(filename:sub(1, 1)) .. filename:sub(2)
	local err, source = AsyncFileToString(filename, nil, nil, "lines")
	if err then return err end

	local clean_source = {}
	local in_multi_line_comment = false
	for line_number, line in ipairs(source) do
		if in_multi_line_comment then
			local multi_line_end = line:find("%]%]")
			if multi_line_end then
				in_multi_line_comment = false
				line = line:sub(multi_line_end + 2, -1)
			end
		end
		if in_multi_line_comment then
			clean_source[line_number] = ""
		else
			-- remove multiline comments on a single line(which can be several)
			local clean_line
			local string_pos = 1
			repeat
				local multi_line_start = line:find("%-%-%[%[", string_pos)
				local multi_line_end = multi_line_start and line:find("%]%]", multi_line_start + 4)
				if multi_line_end then
					clean_line = clean_line or {}
					table.insert(clean_line, line:sub(string_pos, multi_line_start - 1))
					string_pos = multi_line_end + 2
				end
			until not multi_line_end
			if clean_line then
				line = table.concat(clean_line, "")
			end
			
			local multi_line_start = line:find("%-%-%[%[")
			if multi_line_start then
				in_multi_line_comment = true
				clean_source[line_number] = line:sub(1, multi_line_start - 1)
			else
				line = line:gsub("%-%-.*", "")				-- remove comments till the end of the line
				clean_source[line_number] = line
			end
		end
	end

	return clean_source
end

function DASocket:Request_breakpointLocations(arguments)
	local breakpoints_locations = {}
	local source = GetCleanSourceCode(arguments.source.path or arguments.source.sourceReference)
	if source[arguments.line]:match("%S") then
		return nil, {breakpoints = {line = arguments.line, column = 1}}
	else
		return nil, {breakpoints = {}}
	end
end

local function get_cond_expr(cond)
	local cond_expr = (cond == "") and "return true" or cond
	if not string.match(cond_expr, "^%s*return%s") then
		cond_expr = "return " .. cond_expr
	end
	
	return cond_expr
end

local is_running_packed = not IsFSUnpacked()
DASocket.UnpackedLuaSources = {
	"ModTools/Src/",
}
DASocket.PackedLuaMapping = {
	["CommonLua/"] = "ModTools/Src/CommonLua/",
	["Lua/"] = "ModTools/Src/Lua/",
	["Data/"] = "ModTools/Src/Data/",
}
for i, dlc in pairs(rawget(_G, "DlcDefinitions")) do
	local dlc_path = SlashTerminate(dlc.folder)
	DASocket.PackedLuaMapping[dlc_path] = string.format("ModTools/Src/DLC/%s/", dlc.name)
end

local function PackedToUnpackedLuaPath(virtual_path)
	for packed, unpacked in pairs(DASocket.PackedLuaMapping) do
		if string.starts_with(virtual_path, packed) then
			local result, err = ConvertToOSPath(unpacked .. string.sub(virtual_path, #packed + 1))
			if not err and io.exists(result) then
				return result
			end
		end
	end
	return virtual_path
end

local function UnpackedToPackedLuaPath(virtual_path)
	for packed, unpacked in pairs(DASocket.PackedLuaMapping) do
		if string.starts_with(virtual_path, unpacked) then
			return packed .. string.sub(virtual_path, #unpacked + 1)
		end
	end
	return virtual_path
end

local function FindMountedLuaPath(os_path)
	local lua_mount_points = {
		"CommonLua/",
		"Lua/",
		"Data/",
	}
	if config.Mods then
		if is_running_packed then
			table.iappend(lua_mount_points, DASocket.UnpackedLuaSources)
		end
		for i, mod in ipairs(ModsLoaded) do
			table.insert(lua_mount_points, mod.content_path)
		end
		for i, dlc in pairs(rawget(_G, "DlcDefinitions")) do
			table.insert(lua_mount_points, dlc.folder)
		end
	end
	local os_path_lower = os_path:lower()
	for i, src_virtual in ipairs(lua_mount_points) do
		local src_os_path, err = ConvertToOSPath(src_virtual)
		if not err and io.exists(src_os_path) then
			local src_os_path = string.lower(src_os_path)
			if string.starts_with(os_path_lower, src_os_path) then
				return src_virtual .. string.gsub(string.sub(os_path, #src_os_path + 1), "\\", "/")
			end
		end
	end
end

function DASocket:Request_setBreakpoints(arguments)
	if not arguments.breakpoints then return end
	
	local bp_path = arguments.source.path or arguments.source.sourceReference
	local source = GetCleanSourceCode(bp_path)
	local filename = FindMountedLuaPath(bp_path)
	if not filename then
		return "This file is not a part of the game and cannot be debugged."
	end
	if is_running_packed then
		filename = UnpackedToPackedLuaPath(filename)
	end
	bp_path = bp_path:lower()
	self.breakpoints = self.breakpoints or {}
	for line, bp in pairs(self.breakpoints[bp_path]) do
		DebuggerRemoveBreakpoint(filename, line)
	end
	self.breakpoints[bp_path] = {}
	local response = {}
	for bp_idx, bp in ipairs(arguments.breakpoints) do
		local bp_set = table.copy(arguments.source)
		bp_set.id = bp_idx
		bp_set.line = bp.line
		local condition, hitCondition
		if bp.condition ~= nil then
			bp_set.condition = bp.condition
			local cond_expr = get_cond_expr(bp.condition)
			local eval, err = load(cond_expr, nil, nil, self.condition_env)
			if eval then
				condition = eval
			else
				bp_set.message = err
			end
			if bp.hitCondition ~= nil then
				bp_set.hitCondition = bp.hitCondition
				local hit_cond_expr = get_cond_expr(bp.hitCondition)
				local eval, err = load(hit_cond_expr, nil, nil, self.condition_env)
				if eval then
					hitCondition = eval
				else
					bp_set.message = table.concat({bp_set.message or "", err}, "\r\n")
				end
			end
		end
		bp_set.verified = source[bp.line]:match("%S")
		if bp_set.verified then
			if bp.logMessage then
				DebuggerAddBreakpoint(filename, bp.line, bp.logMessage, condition, hitCondition)
			else
				DebuggerAddBreakpoint(filename, bp.line, condition, hitCondition)
			end
		end
		self.breakpoints[bp_path][bp.line] = bp_set
		table.insert(response, bp_set)
	end
	
	return nil, {breakpoints = response}
end

function DASocket:Request_pause(arguments)
	self:SendResponse() -- first send the response
	self.manual_pause = true
	self.debug_blacklisted = config.DebugBlacklistedSource or false
	config.DebugBlacklistedSource = true
	DebuggerBreakExecution()
end

-- NOTE: When "Smooth Scroll" enabled - if BP/exception occurs and VSCode is already in the file it does not jump to the line
function DASocket:Request_stackTrace(arguments)
	self.var_ref_idx = variables_start
	self.ref_to_var = {}
	
	return nil, self.callstack
end

function DASocket:Request_continue(arguments)
	self:SendResponse()
	self:Continue()
	self.manual_pause = false
	config.DebugBlacklistedSource = self.debug_blacklisted
	self.debug_blacklisted = false
end

function DASocket:Request_step(arguments)
end

function DASocket:Request_stepIn(arguments)
	self:SendResponse()
	DebuggerStep("step into", self.coroutine)
	self:Continue()
end

function DASocket:Request_stepOut(arguments)
	self:SendResponse()
	DebuggerStep("step out", self.coroutine)
	self:Continue()
end

function DASocket:Request_next(arguments)
	self:SendResponse()
	DebuggerStep("step over", self.coroutine)	-- this will send "stopped" event with reason "step" via hookBreakLuaDebugger
	self:Continue()
end

local function IsSimpleValue(value)
	local vtype = type(value)

	return vtype == "number" or vtype == "string" or vtype == "boolean" or vtype == "nil"
end

local function ValueType(value)
	local vtype = type(value)
	if vtype == "boolean" or vtype == "string" or vtype == "number" then
		return vtype
	elseif vtype == "nil" then
		return "boolean"
	else
		return "value"
	end
end

local function HandleExpressionResults(ok, result, ...)
	if not ok then
		return result
	end
	if select("#", ...) ~= 0 then
		result = setmetatable({result, ...}, __tuple_meta)
	end
	return false, result
end

local function GetRawG()
	local env = { }
	local env_meta = {}
	env_meta.__index = function(env, key)
		return rawget(_G, key)
	end
	env_meta.__newindex = function(env, key, value)
		rawset(_G, key, value)
	end
	env._G = env
	setmetatable(env, env_meta)
	return env
end

function DASocket:EvaluateExpression(expression, frameId)
	local expr, err = load("return " .. expression, nil, nil, frameId and self.stack_vars[frameId] or GetRawG())
	if err then
		return err
	end
	return HandleExpressionResults(pcall(expr))
end

local func_info = {}
local class_to_name
local has_CObject = false

function Debug_ResolveMeta(value)
	local meta = getmetatable(value)
	if meta and LightUserDataValue(value) and not IsT(value) then
		return -- because LightUserDataSetMetatable(TMeta)
	end
	return meta
end

function Debug_ResolveObjId(obj)
	local id = rawget(obj, "id") or rawget(obj, "Id") or PropObjHasMember(obj, "GetId") and obj:GetId() or ""
	if id ~= "" and type(id) == "string" then
		return id
	end
end

function Debugger_ToString(value, max_len)
	local vtype = type(value)
	local meta = Debug_ResolveMeta(value)
	local str
	if vtype == "string" then
		str = value
	elseif vtype == "thread" then
		local str_value = tostring(value)
		if IsRealTimeThread(value) then
			str_value = "real " .. str_value
		elseif IsGameTimeThread(value) then
			str_value = "game " .. str_value
		end
		if not IsValidThread(value) then
			str_value = "dead " .. str_value
		elseif CurrentThread() == value then
			str_value = "current " .. str_value
		end
		return str_value
	elseif vtype == "function" then
		if IsCFunction(value) then
			return "C " .. tostring(value)
		end
		return "Lua " .. tostring(value)
	elseif IsT(value) then
		str = TDevModeGetEnglishText(value, "deep", "no_assert")
		if str == "Missing text" then
			str = TTranslate(value, nil, false)
		end
	elseif vtype == "table" then
		if rawequal(value, _G) then
			return "_G"
		end
		local class = meta and value.class or ""
		str = tostring(value)
		if class ~= "" and type(class) == "string" then
			local id = Debug_ResolveObjId(value) or ""
			if id ~= "" then
				id = ' "' .. id .. '"'
			end
			local suffix, num = string.gsub(str, "^table", "")
			if num == 0 then
				suffix = ""
			end
			str = class .. id .. suffix
			if not class_to_name then
				class_to_name = table.invert(g_Classes)
				has_CObject = not not g_Classes.CObject
			end
			if class_to_name[value] then
				return "class " .. str
			elseif not IsValid(value) and has_CObject and IsKindOf(value, "CObject") then
				return "invalid object " .. str
			else
				return "object " .. str
			end
		else
			local name = rawget(value, "__name")
			if type(name) == "string" then
				return name
			end
			local count = table.count(value)
			if count > 0 then
				local len = #value
				if len > 0 then
					str = str .. " #" .. len
				end
				if len ~= count then
					str = str .. " [" .. count .. "]"
				end
			end
		end
	elseif vtype == "userdata" then
		if __cobjectToCObject and __cobjectToCObject[value] then
			return "GameObject " .. tostring(value)
		end
	end
	if meta then
		if rawget(meta, "__tostring") ~= nil then
			local ok, result = pcall(meta.__tostring, value)
			if ok then
				str = result
			end
		elseif IsGrid(value) then
			local pid = GridGetPID(value)
			local w, h = value:size()
			return "grid " .. pid .. ' ' .. w .. 'x' .. h
		elseif meta == __tuple_meta then
			return "tuple #" .. table.count(value) .. ""
		end
	end
	str = str or tostring(value)
	max_len = max_len or config.MaxWatchLenValue
	if #str > max_len then
		str = string.sub(str, 1, max_len) .. "..."
	end
	return str
end

function DASocket:Request_evaluate(arguments)
	local context = arguments.context
	if context == "watch" then
	if not self.ref_to_var then return end

		local err, result = self:EvaluateExpression(arguments.expression, arguments.frameId)
		if err then return err end
		local simple_value = IsSimpleValue(result)
		if not simple_value then
			self.var_ref_idx = self.var_ref_idx + 1
			self.ref_to_var[self.var_ref_idx] = result
		end
		local var_ref = simple_value and 0 or self.var_ref_idx

		return nil, {result = Debugger_ToString(result), variablesReference = var_ref, type = ValueType(result)}
	elseif context == "repl" then
		local err, result = self:EvaluateExpression(arguments.expression, arguments.frameId)
		if err then return err end
		local vtype = ValueType(result)
		if IsTuple(result) then
			local str = {}
			for i, val in ipairs(result) do
				str[i] = Debugger_ToString(val)
			end
			result = table.concat(str, ", ")
		else
			local str = Debugger_ToString(result)
			local entries = Debugger_GetWatchEntries(result)
			if #entries > 0 then
				local concat = {str, " {"}
				for i, entry in ipairs(entries) do
					concat[#concat + 1] = "\n\t"
					concat[#concat + 1] = Debugger_ToString(entry[1])
					concat[#concat + 1] = " = "
					concat[#concat + 1] = Debugger_ToString(entry[2])
				end
				concat[#concat + 1] = "\n}"
				str = table.concat(concat)
			end
			result = str
		end
		return nil, {result = result, type = vtype}
	end
end

function DASocket:Request_scopes(arguments)
	if not self.ref_to_var then return end

	local frame = arguments.frameId
	self.scope_frame = frame
	self.eval_env = self.stack_vars[frame]
	self.ref_to_var[variables_start] = self.eval_env

	return nil, {scopes = {
		{
			name = "Autos",
			variablesReference = variables_start,
		},
	}}
end

function Debugger_GetWatchEntries(var)
	local meta = Debug_ResolveMeta(var)
	local vtype = type(var)
	local values
	if vtype == "thread" then
		local current = CurrentThread() == var
		local callstack = GetStack(var) or ""
		callstack = string.tokenize(callstack, "\n")
		local last_dbg_idx
		for i, line in ipairs(callstack) do
			if line:find_lower("CommonLua/Libs/DebugAdapter") then
				last_dbg_idx = i
			end
		end
		if last_dbg_idx then
			local clean_stack = {}
			for i=last_dbg_idx + 1,#callstack do
				clean_stack[#clean_stack + 1] = callstack[i]
			end
			callstack = clean_stack
		end
		values = {
			type = IsRealTimeThread(var) and "real" or IsGameTimeThread(var) and "game" or "",
			current = current,
			status = GetThreadStatus(var) or "dead",
			callstack = callstack,
		}
	elseif vtype == "function" then
		if not IsCFunction(var) then
			local info = func_info[var]
			if not info then
				info = debug.getinfo(var) or empty_table
				func_info[var] = info
			end
			if info.short_src and info.linedefined and info.linedefined ~= -1 then
				values = {
					source = string.format("%s(%d)", info.short_src, info.linedefined),
				}
			end
		end
	elseif vtype == "userdata" then
		if __cobjectToCObject and __cobjectToCObject[var] then
			return
		end
		if meta and meta.__debugview then
			local ok, result = pcall(meta.__debugview, var)
			if ok then
				values = result
			end
		end
	elseif vtype == "table" then
		values = var
	end
	
	local entries = {}
	if meta then
		table.insert(entries, {"metatable", meta})
	end
	local biggest_number, number_keys_entries, other_keys_entries = 0
	for key, value in pairs(values) do
		if type(key) == "number" then
			number_keys_entries = table.create_add(number_keys_entries, { key, value })
			biggest_number = Max(biggest_number, key)
		else
			local key_str = Debugger_ToString(key, const.MaxWatchLenKey)
			other_keys_entries = table.create_add(other_keys_entries, { key_str, value })
		end
	end
	if number_keys_entries then
		table.sortby_field(number_keys_entries, 1)
		local max_len = #tostring(biggest_number)
		for _, entry in ipairs(number_keys_entries) do
			local key, value = entry[1], entry[2]
			local key_str = tostring(key)
			key_str = string.rep(" ", max_len - #key_str) .. key_str
			table.insert(entries, { key_str, value })
		end
	end
	if other_keys_entries then
		table.sort(other_keys_entries, function(e1, e2) return CmpLower(e1[1], e2[1]) end)
		table.iappend(entries, other_keys_entries)
	end
	
	return entries
end

function DASocket:Request_variables(arguments)
	if not self.var_ref_idx then return end
	if not arguments then return end
	
	local var_ref = arguments.variablesReference
	if not var_ref then return end
	
	
	local entries = Debugger_GetWatchEntries(self.ref_to_var[var_ref])
	if #entries == 0 then return end
	
	local variables = {}
	for i, entry in ipairs(entries) do
		variables[i] = self:CreateVar(entry[1], entry[2])
	end
	return nil, { variables = variables }
end

function DASocket:SetVariableValue(var_name, new_value)
	local vars = self.stack_vars[self.scope_frame]
	local var_index, up_value_func = vars:__get_value_index(var_name)
	rawset(vars, var_name, new_value)
	local result
	-- local variales are shadowing the upvalues with the same name
	if up_value_func then
		result = debug.setupvalue(up_value_func, var_index, new_value)
	else
		result = debug.setlocal(self.scope_frame + 8, var_index, new_value)
	end
	
	return vars[result]
end

function DASocket:Request_setVariable(arguments)
	if not self.ref_to_var then return end

	local new_value = self:SetVariableValue(arguments.name, arguments.value)

	return nil, {value = new_value, type = ValueType(new_value)}
end

function DASocket:Request_setExpression(arguments)
	if not self.ref_to_var then return end

	local var_name = arguments.expression
	local err, eval = self:EvaluateExpression(var_name, arguments.frameId)
	if err then return err end

	local result = self:SetVariableValue(var_name, arguments.value)

	return nil, {value = result, type = ValueType(result)}
end

function DASocket:Request_loadedSources(arguments)
end

function DASocket:Request_source(arguments)
end

function DASocket:Request_terminate(arguments)
	CreateRealTimeThread(quit, 1)
end

function DASocket:Request_modules(arguments)
	-- list Libs, DLCs and Mods as modules
	local startModule = arguments.startModule or 0
	local moduleCount = arguments.moduleCount or 0
	local modules = {}
	for _, mod in ipairs(ModsLoaded) do
		table.insert(modules, {id = mod.id, name = mod.name})
	end

	return nil, {modules = modules, totalModules = #modules}
end

local function GetTextLine(text, line)
	local line_number = 1
	for text_line in string.gmatch(text, "[\r\n]+") do
		if line_number == line then
			return text_line
		end
	end

	return text
end

local completion_type_remap = {
	["value"] = "value",
	["f"] = "function",
}

local function GetCompletionsList(line, column, frameId)
	local completions = GetAutoCompletionList(line, column)

	for _, completion in ipairs(completions) do
		completion.type = completion_type_remap[completion.kind]
		completion.kind = nil
		completion.label = completion.value
		completion.value = nil
	end

	return completions
end

function DASocket:Request_completions(arguments)
	local line = GetTextLine(arguments.text, arguments.line)
	if line then
		return nil, {targets = GetCompletionsList(line, arguments.column)}
	end
end

local stop_reasons_map = {
	step = "step",
	breakpoint = "breakpoint",
	pause = "pause",
	exception = "exception",
}
local stop_descriptions_map = { -- shown in UI
	step = "Step",
	breakpoint = "Breakpoint",
	pause = "Pause",
	exception = "Exception",
}

function DASocket:OnStopped(reason, bp_id)
	if self.state then
		self.state = "stopped"
		self:SendEvent("stopped", {
			reason = stop_reasons_map[reason] or "pause",
			description = stop_descriptions_map[reason],
			allThreadsStopped = true,
			threadId = threads_start + 1,
			hitBreakpointIds = bp_id and {bp_id} or nil,
		})
	end
end

function DASocket:OnOutput(text, output_type)
	if self.state == "running" then
		self:SendEvent("output", {
			output = text,
			category = output_type or "console",
		})
	end
end

function ForEachDebugger(method, ...)
	for _, debugger in ipairs(DAServer.debuggers) do
		debugger[method](debugger, ...)
	end
end

function OnMsg.ConsoleLine(text, bNewLine)
	ForEachDebugger("OnOutput", bNewLine and ("\r\n" .. text) or text)
end

function DASocket:OnExit()
	if self.state then
		self:SendEvent("exited", {
			exitCode = GetExitCode(),
		})
	end
end

function DASocket:Update()
	while self.manual_pause do
		sockProcess(1)
	end
end

local function CaptureVars(co, level)
	local vars = {}
	
	local info
	if co then
		info = debug.getinfo(co, level, "fu")
	else
		info = debug.getinfo(level + 1, "fu")
	end
	local func = info and info.func or nil
	if not func then return vars end
	
	local i = 1
	local local_nils = {}
	local upvalue_nils = {}
	local local_var_index = {}
	local upvalue_var_index = {}
	
	local function capture(var_index, index, nils, name, value)
		if name then
			if rawequal(value, nil) then
				nils[name] = true
			else
				vars[name] = value
			end
			var_index[name] = index
			
			return name
		end
	end
	
	-- upvalues first
	for i = 1, info.nups do
		capture(upvalue_var_index, i, upvalue_nils, debug.getupvalue(func, i))
	end

	-- local vars can shadow upvalues and if available and edited - they should change(not shadowed upvalue)
	if co then
		while capture(local_var_index, i, local_nils, debug.getlocal(co, level, i)) do
			i = i + 1
		end
	else
		while capture(local_var_index, i, local_nils, debug.getlocal(level + 1, i)) do
			i = i + 1
		end
	end
	
	vars.__get_value_index = function(t, key)
		if local_var_index[key] then
			return local_var_index[key]
		else
			return upvalue_var_index[key], func
		end
	end

	return setmetatable(vars, {
		__index = function (t, key)
			if local_var_index[key] then
				if local_nils[key] then
					return nil
				end
			else
				if upvalue_nils[key] then
					return nil
				end
			end

			return rawget(_G, key)
		end,
	})
end

local function GetStackFrames(startColumn, arguments)
	arguments = arguments or empty_table
	
	local co = arguments.co
	local level = arguments.level or 0
	local max_levels = arguments.max_levels
	
	local stack_frames = {}
	local stack_vars = {}

	repeat
		local info
		if arguments.co then
			info = debug.getinfo(co, level, "nSl")
		else
			info = debug.getinfo(level, "nSl")
		end
		if not info then break end
		
		local vars = CaptureVars(co, level)
		local path = string.sub(info.source, string.match(info.source, "^@") and 2 or 1, -1)
		local visible = config.DebugBlacklistedSource or not string.match(path, "/DebugAdapter.lua$")
		local skip_frame = visible and #stack_frames == 0 and (info.name == "assert" or info.name == "error" or info.short_src == "[C]")
		if visible and not skip_frame then
			local os_path = is_running_packed and ConvertToOSPath(PackedToUnpackedLuaPath(path)) or ConvertToOSPath(path)
			local known_source = info.short_src ~= "[C]" and not string.starts_with(info.short_src, "[string")
			local default_name = known_source and "?" or info.short_src
			local stackFrame = {}
			stackFrame.id = #stack_frames + 1
			stackFrame.name = string.format("%s (%s%s)", info.name or default_name, info.what, (info.namewhat or "") ~= "" and ("-" .. info.namewhat) or "")
			if known_source then
				stackFrame.source = {
					name = info.short_src,
					path = os_path,
				}
				stackFrame.line = info.currentline
			else
				stackFrame.line = 0
			end
			stackFrame.column = 0
			table.insert(stack_frames, stackFrame)
			table.insert(stack_vars, vars)
		end
		level = level + 1
	until (level > 100) or (max_levels and #stack_frames >= max_levels)
	
	return {stackFrames = stack_frames, totalFrames = #stack_frames}, stack_vars
end

function DASocket:UpdateStackFrames(arguments)
	self.callstack, self.stack_vars = GetStackFrames(self.columnsStartAt1 and 1 or 0, arguments)
end

function DASocket:CreateVar(var_name, var_value)
	local simple_value = IsSimpleValue(var_value)
	if not simple_value then
		self.var_ref_idx = self.var_ref_idx + 1
		self.ref_to_var[self.var_ref_idx] = var_value
	end
	local var = {
		name = var_name,
		value = Debugger_ToString(var_value),
		type = ValueType(var_value),
		variablesReference = simple_value and 0 or self.var_ref_idx,
		evaluateName = config.DebugAdapterUseSetExpression and var_name or nil,
	}
	return var
end

function DASocket:Continue()
	self.callstack = false
	self.scope_frame = false
	self.stack_vars = false
	self.var_ref_idx = false
	self.ref_to_var = false
	self.coroutine = false
	self.state = "running"
end

function DASocket:Break(reason, co, break_offset, level)
	self.coroutine = co
	self:UpdateStackFrames({level = level, co = co, break_offset = break_offset})
	local bp_id
	if reason == "breakpoint" then
		for _, stack_frame in ipairs(self.callstack.stackFrames) do
			if stack_frame.source then
				local stack_path = stack_frame.source.path:lower()
				local stack_breakpoints = self.breakpoints and self.breakpoints[stack_path]
				local bp = stack_breakpoints and stack_breakpoints[stack_frame.line]
				if bp and bp.verified then
					bp_id = bp.id
					break
				end
			end
		end
	end
	if self.state ~= "stopped" then
		self:OnStopped(reason, bp_id)
	end
	if not self.in_break then
		self.in_break = true
		while not self.manual_pause and self.state == "stopped" do
			sockProcess(1)
		end
		self.in_break = false
	end
end

----- DAServer

DAServer = rawget(_G, "DAServer") or { -- simple lua table, since it needs to work before the class resolution
	host = "127.0.0.1",
	port = 8165,
	debuggers = {},
}

function DAServer:Start(replace_previous, wait_debugger_time, host, port)
	if not self.listen_socket then
		self.host = host or self.host
		self.port = port or self.port
		self.listen_socket = DASocket:new{
			OnAccept = function (self, ...) return DAServer:OnAccept(...) end,
		}
		local err = sockListen(self.listen_socket, self.host, self.port)
		if replace_previous and err == "address in use" then
			print("Replacing existing DebugAdapter")
			local timeout = GetPreciseTicks() + 2000
			-- there is another debugee running, connect to it and shut it down
			local conn = DASocket:new()
			local conn_err = sockConnect(conn, timeout, self.host, self.port)
			if not conn_err then
				while GetPreciseTicks() - timeout < 0 and sockIsConnecting(conn) do
					sockProcess(1)
				end	
			end
			if conn:IsConnected() then
				conn:SendEvent("StopDAServer")
				sockProcess(200)
				conn:delete()
				-- try again
				err = sockListen(self.listen_socket, self.host, self.port)
			end
		end
		if err then
			print("DebugAdapter listen error: ", err)
			self.listen_socket:delete()
			self.listen_socket = nil
		else
			--[[]]printf("DebugAdapter started at %s:%d", self.host, self.port)
		end
	end
	if self.listen_socket and wait_debugger_time then -- wait for connection
		local timeout = GetPreciseTicks() + wait_debugger_time
		while GetPreciseTicks() - timeout < 0 and #self.debuggers == 0 do
			sockProcess(1)
		end
	end
	return #self.debuggers > 0
end

function DAServer:Stop()
	for _, da in ipairs(self.debuggers) do
		da:OnExit()
	end
	if self.listen_socket then
		self.listen_socket:delete()
		self.listen_socket = nil
	end
end

function DAServer:OnAccept(socket, host, port)
	self.connections = (self.connections or 0) + 1
	local sock_obj = DASocket:new{
		[true] = socket,
		host = host,
		port = port,
		event_source = string.format("DASocket#%d ", self.connections),
		connection = self.connections,
	}
	self.debuggers[#self.debuggers + 1] = sock_obj
	DAServer.thread = IsValidThread(DAServer.thread) or CreateRealTimeThread(function()
		while #DAServer.debuggers > 0 do
			sockProcess(0)
			ForEachDebugger("Update")
			WaitWakeup(50)
		end
		DAServer.thread = nil
	end)
	printf("DebugAdapter connection %d %s:%d", sock_obj.connection, host, port)
	return sock_obj
end

function Debug(replace_previous, wait_debugger_time, host, port)
	if DAServer.listen_socket then return end -- debugger already active
	DAServer:Start(
		replace_previous, 
		wait_debugger_time,
		host,
		port or config.DebugAdapterPort) -- start without waiting for connection
	UpdateThreadDebugHook()				-- change to the actual hook
	DebuggerEnableHook(true)
end

----- globals

function OnMsg.Autodone()
	DAServer:Stop()
end

function IsDAServerListening()
	return not not (rawget(_G, "DAServer") and DAServer.listen_socket)
end

if not Platform.ged then
	Debug(true)
end

function hookBreakLuaDebugger(reason) -- called from C so we can pass the self param
	ForEachDebugger("Break", reason, nil, nil, 5)
	if config.EnableHaerald and rawget(_G, "g_LuaDebugger") then
		g_LuaDebugger:Break()
	end
end

function hookLogPointLuaDebugger(log_msg)
	log_msg = string.gsub(log_msg, "{.-}", function(expression) 
		expression = string.sub(expression, 2, -2)
		local vars = CaptureVars(nil, 7)
		local expr, err = load("return " .. expression, nil, nil, vars)
		if err then
			return err
		else
			local ok, result = pcall(expr)
			return result
		end
	end)
	printf("LogPoint: %s", log_msg)
	ForEachDebugger("OnOutput", log_msg)
end

local oldStartDebugger = rawget(_G, "StartDebugger") or empty_func

function StartDebugger()
	Debug(true)
	
	if config.EnableHaerald then
		return oldStartDebugger()
	end
end

function _G.startdebugger(co, break_offset)
	Debug(true)
	UpdateThreadDebugHook()	-- change to the actual hook
	StartDebugger()
	if IsDAServerListening() then
		DebuggerEnableHook(true)
		ForEachDebugger("Break", "exception", co, break_offset, co and 0 or 1)
	end
	if rawget(_G, "g_LuaDebugger") and config.EnableHaerald then
		DebuggerEnableHook(true)
		g_LuaDebugger:Break(co, break_offset)
	end
end

function _G.bp(...)
	if not (select("#", ...) == 0 or select(1, ...)) then return end
	
	Debug(true)
	UpdateThreadDebugHook()	-- change to the actual hook
	StartDebugger()
	DebuggerEnableHook(true)
	local break_offset = select(2, ...)
	if IsDAServerListening() then
		ForEachDebugger("Break", "breakpoint", nil, break_offset, 5)
	end
	if rawget(_G, "g_LuaDebugger") and config.EnableHaerald then
		g_LuaDebugger:Break(nil, break_offset)
	end
end