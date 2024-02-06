if Platform.ged then return end

---- A diagnostic message cache to improve Ged performance
--
-- 1. The cache is only maintained for objects in the active Ged window.
-- 2. It is kept up-to-date by periodic updates.
--
-- Motivation: Diagnostic messages of objects often depend on external data. The usual way to update
-- the messages is with ObjModified calls whenever that external data changes. However, we can't
-- expect people to put this effort merely for a warning message. Thus we need an automated system.

function ClearDiagnosticMessageCache()
	DiagnosticMessageCache = {}
	DiagnosticMessageObjs = {} -- topologically sorted (child objects first)
end

if FirstLoad then
	ClearDiagnosticMessageCache()
end

local GetDiagnosticMessageNoCache = GetDiagnosticMessage

function GetDiagnosticMessage(obj, verbose, indent)
	local cached = DiagnosticMessageCache[obj]
	if cached ~= nil then return cached end
	
	local message = GetDiagnosticMessageNoCache(obj, verbose, indent) or false
	DiagnosticMessageObjs[#DiagnosticMessageObjs + 1] = obj
	DiagnosticMessageCache[obj] = message
	return message
end

function UpdateDiagnosticMessage(obj)
	local no_cache = not DiagnosticMessageCache[obj]
	local old_msg = DiagnosticMessageCache[obj] or false
	local new_msg = GetDiagnosticMessageNoCache(obj) or false
	DiagnosticMessageCache[obj] = new_msg
	return no_cache or new_msg ~= old_msg and ValueToLuaCode(new_msg) ~= ValueToLuaCode(old_msg)
end

----- Keeping the cache up-to-date

if FirstLoad then
	DiagnosticMessageActiveGed = false
	DiagnosticMessageActivateGedThread = false
	DiagnosticMessageSuspended = false
end

local function for_each_subobject(t, class, fn)
	if IsKindOf(t, class) then
		fn(t)
	end
	for _, obj in ipairs(t and t.GedTreeChildren and t:GedTreeChildren() or t) do
		if type(obj) == "table" then
			for_each_subobject(obj, class, fn)
		end
	end
end

local function init_cache_for_object(ged, root, initial)
	local old_cache = DiagnosticMessageCache
	ClearDiagnosticMessageCache()
	
	local total, count = 0, 0
	for_each_subobject(root, "GedEditedObject", function() total = total + 1 end)
	
	local time = GetPreciseTicks()
	for_each_subobject(root, "GedEditedObject", function(obj)
		local old_msg = old_cache[obj] or false
		local new_msg = GetDiagnosticMessage(obj) or false
		if new_msg ~= old_msg and ValueToLuaCode(new_msg) ~= ValueToLuaCode(old_msg) then
			GedObjectModified(obj, "warning")
		end
		
		count = count + 1
		if GetPreciseTicks() > time + 150 then
			time = GetPreciseTicks()
			if initial then
				ged:SetProgressStatus("Updating warnings/errors...", count, total)
			end
			Sleep(50)
		end
	end)
	
	ged:SetProgressStatus(false)
end

local function ged_update_warnings(ged)
	-- update Ged with the warnings cache via GedGetCachedDiagnosticMessages (to show ! marks)
	GedUpdateObjectValue(ged, nil, "root|warnings_cache")
	-- update the status bar that contains warning/error information
	for name, obj in pairs(ged.bound_objects) do
		if name:find("|GedPresetStatusText", 1, true) or name:find("|GedModStatusText", 1, true) or name:find("|warning_error_count", 1, true) then
			GedUpdateObjectValue(ged, nil, name)
		end
	end
end

function InitializeWarningsForGedEditor(ged, initial)
	if IsValidThread(DiagnosticMessageActivateGedThread) and DiagnosticMessageActivateGedThread ~= CurrentThread then
		DeleteThread(DiagnosticMessageActivateGedThread)
	end
	
	DiagnosticMessageActiveGed = ged
	Msg("WakeupQuickDiagnosticThread")
	DiagnosticMessageActivateGedThread = CreateRealTimeThread(function()
		ged:SetProgressStatus(false)
		init_cache_for_object(ged, ged:ResolveObj(ged.context.WarningsUpdateRoot), initial)
		ged_update_warnings(ged)
		Msg("WakeupFullDiagnosticThread")
	end)
end

function OnMsg.GedActivated(ged, initial)
	if ged.context.WarningsUpdateRoot and ged:ResolveObj(ged.context.WarningsUpdateRoot) then
		InitializeWarningsForGedEditor(ged, initial)
	else
		ClearDiagnosticMessageCache()
		DiagnosticMessageActiveGed = false
	end
end

function OnMsg.SystemActivate()
	ClearDiagnosticMessageCache()
	DiagnosticMessageActiveGed = false
end

function GedGetCachedDiagnosticMessages()
	local ret = {}
	for obj, msg in pairs(DiagnosticMessageCache) do
		if msg then
			ret[tostring(obj)] = msg
		end
	end
	return ret
end

function UpdateDiagnosticMessages(objs)
	-- Update children objects first, which are last on the list, so when an object is updated,
	-- we "know" its warning is correct (unless a child's warning status changed in the meantime)
	local time, updated = GetPreciseTicks(), false
	for i = 1, #objs do
		local obj = objs[i]
		if GedIsValidObject(obj) and UpdateDiagnosticMessage(obj) then
			GedObjectModified(obj, "warning")
			updated = true
		end
		if GetPreciseTicks() - time > 50 then
			Sleep(50)
			if not DiagnosticMessageActiveGed then return end
			time = GetPreciseTicks()
		end
	end
	if updated then
		ged_update_warnings(DiagnosticMessageActiveGed)
	end
end

if FirstLoad then
	CreateRealTimeThread(function()
		while true do
			Sleep(77)
			while DiagnosticMessageActiveGed do
				if not DiagnosticMessageSuspended then
					sprocall(UpdateDiagnosticMessages, DiagnosticMessageObjs)
				end
				Sleep(50)
			end
			WaitMsg("WakeupFullDiagnosticThread")
		end
	end)
	-- Update Ged's bound objects (the ones currently in panels) with a greater frequency for better responsiveness
	CreateRealTimeThread(function()
		while true do
			Sleep(33)
			while DiagnosticMessageActiveGed do
				if not DiagnosticMessageSuspended then
					local objs = {}
					for name, obj in pairs(DiagnosticMessageActiveGed.bound_objects) do
						if name:ends_with("|warning") then
							if IsKindOf(obj, "PropertyObject") then
								obj:ForEachSubObject(function(subobj) objs[subobj] = true end)
							end
							objs[obj] = true
						end
					end
					sprocall(UpdateDiagnosticMessages, table.keys(objs))
				end
				Sleep(50)
			end
			WaitMsg("WakeupQuickDiagnosticThread")
		end
	end)
end
