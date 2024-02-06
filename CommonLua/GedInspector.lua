if FirstLoad then
	GedInspectedObjects = setmetatable({}, weak_keys_meta)
	GedInspectedObjectsRefCount = setmetatable({}, weak_keys_meta)
	GedObjInspectors = {}
end

local function PrintTable(obj)
	if obj and obj.class then
		return "class " .. tostring(obj.class)
	elseif IsT(obj) then
		local tcontent = ""
		local id = TGetID(obj)
		if id then
			tcontent = tostring(id)
		end
		if obj[1] then
			tcontent = tcontent .. ", " .. tostring(obj[1])
		end
		if THasArgs(obj) then
			tcontent = tcontent .. ", ..."
		end
		return "T{".. tcontent .. "}"
	else
		return tostring(obj)
	end
end

local function PrintValue(obj)
	local t = type(obj)
	if t == "string" then
		return "\"" .. obj .. "\""
	elseif t == "table" then
		return PrintTable(obj)
	else
		return tostring(obj)
	end
end

local function UpdateObjRefCounts(old_obj, new_obj)
	if old_obj and GedInspectedObjectsRefCount[old_obj] == 1 then
		GedInspectedObjectsRefCount[old_obj] = nil
		GedInspectedObjects[old_obj] = nil
	elseif old_obj and GedInspectedObjectsRefCount[old_obj] then
		GedInspectedObjectsRefCount[old_obj] = GedInspectedObjectsRefCount[old_obj] - 1
	end
	
	if new_obj and GedInspectedObjectsRefCount[new_obj] then
		GedInspectedObjectsRefCount[new_obj] = GedInspectedObjectsRefCount[new_obj] + 1
	elseif new_obj then
		GedInspectedObjectsRefCount[new_obj] = 1
		local table_list = {}
		GedInspectedObjects[new_obj] = table_list
		if type(new_obj) ~= "thread" then
			-- gather table links
			for key, value in next, new_obj do
				if type(value) == "table" then
					table.insert(table_list, value)
				end
				
				if type(key) == "table" then
					table.insert(table_list, key)
				end
			end
		end
		local meta = getmetatable(new_obj)
		if meta then
			table.insert(table_list, meta)
		end
	end
end

local function get_thread_frame_ref(obj, level, info)
	local ref_list = GedInspectedObjects[obj]
	
	local data = {}
	local l = 1
	while true do
		local name, val = debug.getlocal (obj, level, l) 
		if not name then
			break
		end
		data[name] = val
		l = l + 1
	end
	
	ref_list[level] = data
	return level
end

function GedInspectorFormatObject(obj)
	local members = {}
	local ref_list = GedInspectedObjects[obj]
	
	-- The object should have already been created by a call to UpdateObjRefCounts so we can have proper ref count
	assert(ref_list)
	
	if type(obj) == "thread" then
		local info, level, s = true, 0
		while true do
			info = debug.getinfo(obj, level, "Slfun")
			if not info then break end
			local entry = {}
			entry.key = level
			entry.value = info.short_src.."(".. info.currentline..") " .. (info.name or info.name_what or "unknown name")
			entry.value_id = get_thread_frame_ref(obj, level, info)
			table.insert(members, entry)
			level = level + 1
		end
	else
		for key, value in next, obj do
			local entry = {}
			entry.key = key
			entry.value = value
			if IsT(value) then
				entry.value = _InternalTranslate(value)
			elseif type(value) == "table" and not value.class then
				local count = #value
				if (count or 0) > 0 then
					entry.count = count
				end
			end
			
			local make_ref = function(value)
				if type(value) == "table" or type(value) == "thread" then
					local ref_id = table.find(ref_list, value)
					if not ref_id then
						table.insert(ref_list, value)
						ref_id = #ref_list
					end
					return ref_id
				end
			end
			entry.value_id = make_ref(value)
			entry.key_id = make_ref(key)
			table.insert(members, entry)
		end
	end
	
	table.sort(members, function(a,b)
		local a, b = a.key, b.key
		if type(a) == "number" and type(b) == "number" then
			return a < b
		elseif type(a) == "number" then
			return false
		elseif type(b) == "number" then
			return true
		end
		return tostring(a) < tostring(b)
	end)
	
	-- Convert the values to strings after they are sorted.
	for k,v in ipairs(members) do
		v.key = PrintValue(v.key)
		v.value = PrintValue(v.value)
	end
	
	local context = { members = members, name = PrintValue(obj) }
	local metatable = getmetatable(obj)
	if metatable then
		context.metatable_name = PrintValue(metatable)
		context.metatable_id = table.find(ref_list, metatable)
	end
	return context
end

local function SetToggleActionStates(socket)
	local obj = socket:ResolveObj("root")
	socket:Send("rfnApp", "SetActionToggled", "SetO1", rawget(_G, "o1") ==  obj)
	socket:Send("rfnApp", "SetActionToggled", "SetO2", rawget(_G, "o2") ==  obj)
	socket:Send("rfnApp", "SetActionToggled", "SetO3", rawget(_G, "o3") ==  obj)
end

local function GedBindObjDirect(socket, new_obj)
	UpdateObjRefCounts(socket:ResolveObj("root"), new_obj)
	socket:BindObj("root", new_obj)
	SetToggleActionStates(socket)
end

-- also writes to navigation history
function GedOpBindObjByRefId(socket, obj, ref_id, new_inspector)
	local obj_ref_list = GedInspectedObjects[obj]
	local new_obj = obj_ref_list[ref_id]
	if new_obj then
		if new_inspector then
			Inspect(new_obj)
		else
			socket.nav_pos = socket.nav_pos + 1
			while #socket.nav_list > socket.nav_pos do
				table.remove(socket.nav_list, #socket.nav_list)
			end
			socket.nav_list[socket.nav_pos] = {obj = new_obj, parent_pos = socket.nav_pos - 1}
			socket:SetSearchString(false)
			GedBindObjDirect(socket, new_obj)
		end
	end
end

local function GedParentOf(socket, child_obj)
	local nav_list = socket.nav_list
	local pos = socket.nav_pos
	
	local current = nav_list[pos]
	local parent = nav_list[current.parent_pos]
	return parent, current.parent_pos
end

local function GedParentOfIndexedObj(socket, child_obj)
	local parent, pos = GedParentOf(socket, child_obj)
	local idx = table.find(parent.obj, child_obj)
	if idx then
		return parent, pos, idx
	end
end

function GedOpInspectorNavGo(socket, obj, subcmd)
	local nav_list = socket.nav_list
	local nav_pos = socket.nav_pos
	if subcmd == "back" and socket.nav_pos > 1 then
		socket.nav_pos = socket.nav_pos - 1
		if nav_list[socket.nav_pos].parent_pos ~= nav_list[socket.nav_pos + 1].parent_pos then
			socket:SetSearchString(false)
		end
		GedBindObjDirect(socket, nav_list[socket.nav_pos].obj)
	elseif subcmd == "forward" and socket.nav_pos < #socket.nav_list then
		socket.nav_pos = socket.nav_pos + 1
		if nav_list[socket.nav_pos].parent_pos ~= nav_list[socket.nav_pos - 1].parent_pos then
			socket:SetSearchString(false)
		end
		GedBindObjDirect(socket, nav_list[socket.nav_pos].obj)
	elseif subcmd == "parent" then
		local parent, nav_pos = GedParentOf(socket, obj)
		if parent then
			socket.nav_pos = nav_pos
			socket:SetSearchString(false)
			GedBindObjDirect(socket, parent.obj)
		end
	elseif subcmd == "nextchild" then
		local parent, _, child_idx = GedParentOfIndexedObj(socket, obj)
		if parent then
			local candidate = parent.obj[child_idx + 1]
			if candidate then
				socket.nav_pos = socket.nav_pos + 1
				socket.nav_list[socket.nav_pos] = { obj = candidate, parent_pos = nav_list[nav_pos].parent_pos }
				GedBindObjDirect(socket, candidate)
			end
		end
	elseif subcmd == "prevchild" then
		local parent, _, child_idx = GedParentOfIndexedObj(socket, obj)
		if parent then
			local candidate = parent.obj[child_idx - 1]
			if candidate then
				socket.nav_pos = socket.nav_pos + 1
				socket.nav_list[socket.nav_pos] = { obj = candidate, parent_pos = nav_list[nav_pos].parent_pos }
				GedBindObjDirect(socket, candidate)
			end
		end
	end
end

function GedOpInspectorSetGlobal(socket, obj, global_name, toggle)
	assert(table.find({"o1", "o2", "o3"}, global_name))
	if toggle then
		rawset(_G, global_name, obj)
	else
		rawset(_G, global_name, nil)
	end
	for _, inspector in ipairs(GedObjInspectors) do
		SetToggleActionStates(inspector)
	end
end

function GedOpInspectorViewObject(socket, obj)
	ViewAndSelectObject(obj)
end

function OnMsg.GedOpened(ged_id)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == "GedInspector" then
		table.insert(GedObjInspectors, gedApp)
		SetToggleActionStates(gedApp)
	end
end

function OnMsg.GedClosing(ged_id)
	local socket = table.find_value(GedObjInspectors, "ged_id", ged_id)
	table.remove_value(GedObjInspectors, socket)
	
	if socket then
		local root = socket:ResolveObj("root")
		UpdateObjRefCounts(root, nil)
	end
end

function Inspect(object)
	if type(object) ~= "table" then
		print("Only tables can be inspected")
		return
	end
	if not CanYield() then
		CreateRealTimeThread(Inspect, object)
		return
	end
	UpdateObjRefCounts(nil, object)
	local app = OpenGedApp("GedInspector", object)
	if app then
		app.nav_list = {{obj = object, parent_pos = 1}}
		app.nav_pos = 1
	end
	return app
end

