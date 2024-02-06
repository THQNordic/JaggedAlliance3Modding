local SuspendProcessReasons
local SuspendedProcessing
local CheckExecutionTimestamp = empty_func
local CheckRemainingReason = empty_func
local table_unpack = table.unpack
local table_iequal = table.iequal

if FirstLoad then
	__process_params_meta = {
		__eq = function(t1, t2)
			if type(t1) ~= type(t2) or not rawequal(getmetatable(t1), getmetatable(t2)) then
				return false
			end
			local count = t1[1]
			if count ~= t2[1] then
				return false
			end
			for i=2,count do
				if t1[i] ~= t2[i] then
					return false
				end
			end
			return true
		end
	}
end

local function PackProcessParams(obj, ...)
	local count = select("#", ...)
	if count == 0 then
		return obj or false
	end
	return setmetatable({count + 2, obj, ...}, __process_params_meta)
end

local function UnpackProcessParams(params)
	if type(params) ~= "table" or getmetatable(params) ~= __process_params_meta then
		return params
	end
	return table_unpack(params, 2, params[1])
end

function OnMsg.DoneMap()
	CheckRemainingReason()
	SuspendProcessReasons = false
	SuspendedProcessing = false
end

local function ExecuteSuspended(process)
	local delayed = SuspendedProcessing
	local funcs_to_params = delayed and delayed[process]
	if not funcs_to_params then
		return
	end
	delayed[process] = nil
	local procall = procall
	for _, funcname in ipairs(funcs_to_params) do
		local func = _G[funcname]
		for _, params in ipairs(funcs_to_params[funcname]) do
			dbg(CheckExecutionTimestamp(process, funcname, params, true))
			procall(func, UnpackProcessParams(params))
		end
	end
end

function CancelProcessing(process)
	if not SuspendProcessReasons or not SuspendProcessReasons[process] then
		return
	end
	if SuspendedProcessing then
		SuspendedProcessing[process] = nil
	end
	SuspendProcessReasons[process] = nil
	Msg("ProcessingResumed", process, "cancel")
end

--[[@@@
Checks if the processing of routines from a named process is currently suspended
@function bool IsProcessingSuspended(string process)
--]]
function IsProcessingSuspended(process)
	local process_to_reasons = SuspendProcessReasons
	return process_to_reasons and next(process_to_reasons[process])
end

--[[@@@
Suspends the processing of routines from a named process. Multiple suspending with the same reason would lead to an error.
@function void SuspendProcessing(string process, type reason, bool ignore_errors)
@param string process - the name of the process, which routines should be suspended.
@param type reason - the reason to be used in order to resume the processing later. Could be any type.
@param bool ignore_errors - ignore suspending errors (e.g. process already suspended).
--]]
function SuspendProcessing(process, reason, ignore_errors)
	reason = reason or ""
	local reasons = SuspendProcessReasons and SuspendProcessReasons[process]
	if reasons and reasons[reason] then
		assert(ignore_errors)
		return
	end
	local now = GameTime()
	if reasons then
		reasons[reason] = now
		return
	end
	SuspendProcessReasons = table.set(SuspendProcessReasons, process, reason, now)
	Msg("ProcessingSuspended", process)
end

--[[@@@
Resumes the processing of routines from a named process. Resuming an already resumed process, or resuming it with time delay, would lead to an error.
@function void ResumeProcessing(string process, type reason, bool ignore_errors)
@param string process - the name of the process, which routines should be suspended.
@param type reason - the reason to be used in order to resume the processing later. Could be any type.
@param bool ignore_errors - ignore resume errors (e.g. process already resumed).
--]]
function ResumeProcessing(process, reason, ignore_errors)
	reason = reason or ""
	local reasons = SuspendProcessReasons and SuspendProcessReasons[process]
	local suspended = reasons and reasons[reason]
	if not suspended then
		return
	end
	assert(ignore_errors or suspended == GameTime())
	local now = GameTime()
	reasons[reason] = nil
	if next(reasons) ~= nil then
		return
	end
	assert(not IsProcessingSuspended(process))
	ExecuteSuspended(process)
	Msg("ProcessingResumed", process)
end

--[[@@@
Execute a routine from a named process. If the process is currently suspended, the call will be registered in ordered to be executed once the process is resumed. Multiple calls with the same context will be registered as one.
@function void ExecuteProcess(string process, function func, table obj)
@param string process - the name of the process, which routines should be suspended.
@param function func - the function to be executed.
@param table obj - optional function context.
--]]
function ExecuteProcess(process, funcname, obj, ...)
	if not IsProcessingSuspended(process) then
		dbg(CheckExecutionTimestamp(process, funcname, obj))
		return procall(_G[funcname], obj, ...)
	end
	local params = PackProcessParams(obj, ...)
	local suspended = SuspendedProcessing
	if not suspended then
		suspended = {}
		SuspendedProcessing = suspended
	end
	local funcs_to_params = suspended[process]
	if not funcs_to_params then
		suspended[process] = { funcname, [funcname] = {params} }
		return
	end
	local objs = funcs_to_params[funcname]
	if not objs then
		funcs_to_params[#funcs_to_params + 1] = funcname
		funcs_to_params[funcname] = {params}
		return
	end
	table.insert_unique(objs, params)
end

----

if Platform.asserts then

local ExecutionTimestamps

function OnMsg.DoneMap()
	ExecutionTimestamps = false
end

-- Rise an error if a routine from a process is executed twice in the same time
CheckExecutionTimestamp = function(process, funcname, obj, delayed)
	if not config.DebugSuspendProcess then
		return
	end
	if not ExecutionTimestamps then
		ExecutionTimestamps = {}
		CreateRealTimeThread(function()
			Sleep(1)
			ExecutionTimestamps = false
		end)
	end
	local func_to_objs = ExecutionTimestamps[process]
	if not func_to_objs then
		func_to_objs = {}
		ExecutionTimestamps[process] = func_to_objs
	end
	local objs_to_timestamp = func_to_objs[funcname]
	if not objs_to_timestamp then
		objs_to_timestamp = {}
		func_to_objs[funcname] = objs_to_timestamp
	end
	obj = obj or false
	local rtime, gtime = RealTime(), GameTime()
	local timestamp = xxhash(rtime, gtime)
	if timestamp == objs_to_timestamp[obj] then
		print("Duplicated processing:", process, funcname, "time:", gtime, "obj:", obj and obj.class, obj and obj.handle)
		assert(false, string.format("Duplicated process routine: %s.%s", process, funcname))
	else
		objs_to_timestamp[obj] = timestamp
		--[[
		if IsValid(obj) then
			local pos = obj:GetVisualPos()
			local seed = xxhash(obj and obj.handle)
			local len = 5*guim + BraidRandom(seed, 10*guim)
			DbgAddVector(pos, len, RandColor(seed))
			DbgAddText(funcname, pos + point(0, 0, len), RandColor(obj and obj.handle))
		end
		--]]
	end
end

CheckRemainingReason = function()
	local process = next(SuspendProcessReasons)
	local reason = process and next(SuspendProcessReasons[process])
	if reason then
		assert(false, string.format("Process '%s' not resumed: %s", process, ValueToStr(reason)))
	end
end

end -- Platform.asserts