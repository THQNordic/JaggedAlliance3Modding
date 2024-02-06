if Libs.Network ~= "async" then return end
local IsValid = IsValid

MapVar("NetObjects", {}, weak_keys_meta)

function NetTempObject(o)
	NetObjects[o or false] = false
end

function NetObject(o)
	NetObjects[o or false] = true
end

local function IsNetObj(o)
	local net_obj = NetObjects[o]
	return net_obj ~= false
			and IsValid(o) and (net_obj or not IsValid(o:GetParent()))
			and o.__ancestors.Object and o.handle and true
end

local mp_print = Platform.developer and print or function() end

local IsNetObj = IsNetObj

-- InteractionRand

MapVar("InteractionTypeSeeds", {}) -- keeps hash values for the interaction type names

MapGameTimeRepeat("InteractionRandScheduleReset", nil, function()
	WaitServerTick(10000)
	ResetInteractionRand(ServerTime() / 10000)
end)

function ValidateInteractionSeeds()
	for int_type, obj_to_target in pairs(InteractionSeeds) do
		for obj, target_to_seed in pairs(obj_to_target) do
			if obj and not IsValid(obj) then
				obj_to_target[obj] = nil
			else
				for target in pairs(target_to_seed) do
					if target and not IsValid(target) then
						target_to_seed[target] = nil
					end
				end
				if next(target_to_seed) == nil then
					obj_to_target[obj] = nil
				end
			end
		end
		if next(obj_to_target) == nil then
			InteractionSeeds[int_type] = nil
		end
	end
end

function ClearInteraction(int_type, obj)
	while obj and obj.NetOwner do
		obj = obj.NetOwner
	end
	if not IsValid(obj) or not IsNetObj(obj) then
		return false
	end
	local obj_to_target = InteractionSeeds[int_type or "none"]
	if obj_to_target then
		obj_to_target[obj] = nil
	end
	return true
end

function InteractionRand(max, int_type, obj, target)
	int_type = int_type or "none"
	assert(type(int_type) == "string")
	-- avoid having objects with random handle, they cannot be unserialized remotely
	while obj and obj.NetOwner do
		obj = obj.NetOwner
	end
	obj = IsNetObj(obj) and obj or false
	target = target or false
	local obj_to_target = InteractionSeeds[int_type]
	if not obj_to_target then
		obj_to_target = setmetatable({}, weak_keys_meta)
		InteractionSeeds[int_type] = obj_to_target
	end
	local target_to_seed = obj_to_target[obj]
	if not target_to_seed then
		target_to_seed = setmetatable({}, weak_keys_meta)
		obj_to_target[obj] = target_to_seed
	end
	while target and target.NetOwner do
		target = target.NetOwner
	end
	local interaction_seed = target_to_seed[target]
	if not interaction_seed then
		local type_seed = InteractionTypeSeeds[int_type]
		if not type_seed then
			type_seed = xxhash(int_type)
			InteractionTypeSeeds[int_type] = type_seed
		end
		interaction_seed = bxor(InteractionSeed, type_seed, obj and obj.handle or 0, target and target.handle or 0)
	end
	local rand
	rand, interaction_seed = BraidRandom(interaction_seed, max)
	target_to_seed[target] = interaction_seed
	
	NetUpdateHash("InteractionRand", rand, max, int_type, obj, target)
	return rand, interaction_seed
end


-------------------------------------------------[ WAIT HANDLE RESOLVE ]------------------------------------------------------------------- 

if FirstLoad then
	HandleResolveMsg = {}
end

function OnHandleAssigned(handle)
	if HandleResolveMsg[handle] then
		Msg(HandleResolveMsg[handle])
		HandleResolveMsg[handle] = nil
	end
end

function WaitResolveHandle(handle)
	local obj = HandleToObject[handle]
	if not obj then
		HandleResolveMsg[handle] = HandleResolveMsg[handle] or {}
		WaitMsg(HandleResolveMsg[handle], 1000)
		HandleResolveMsg[handle] = nil
		obj = HandleToObject[handle]
	end
	return obj
end

-------------------------------------------------[ Net map utilities ]------------------------------------------------------

local function QueryNetObjects(only_non_permanent)
	return MapGet(true, "Object", function(o)
											return IsNetObj(o) and (not only_non_permanent or o:GetGameFlags(const.gofPermanent) == 0)
										end)
end

local function SerializeInteractionSeeds()
	return next(InteractionSeeds) ~= nil and NetSerialize(InteractionSeeds) or nil
end

local function UnserializeInteractionSeeds(interact)
	local seeds = interact and NetUnserialize(interact) or {}
	for int_type, obj_to_target in pairs(seeds) do
		setmetatable(obj_to_target, weak_keys_meta)
		for obj, target_to_seed in pairs(obj_to_target) do
			setmetatable(target_to_seed, weak_keys_meta)
		end
	end
	return seeds
end

if Platform.developer then
	SerializeInteractionSeeds = function()
		local map1 = {}
		for int_type, obj_to_target in pairs(InteractionSeeds) do
			local map2 = setmetatable({}, weak_keys_meta)
			for obj, target_to_seed in pairs(obj_to_target) do
				local map3 = setmetatable({}, weak_keys_meta)
				for target, seed in pairs(target_to_seed) do
					if not target then
						map3[false] = seed
					elseif target.handle then
						map3[target.handle] = seed
					else
						assert(false, "Interaction target without handle: " .. tostring(target.class))
					end
				end
				if not obj then
					map2[false] = map3
				elseif obj.handle then
					map2[obj.handle] = map3
				else
					assert(false, "Interaction object without handle: " .. tostring(obj.class))
				end
			end
			map1[int_type] = map2
		end
		return next(map1) ~= nil and NetSerialize(map1) or nil
	end
	UnserializeInteractionSeeds = function(interact)
		local seeds = interact and NetUnserialize(interact) or {}
		local map1 = {}
		local count = 0
		for int_type, obj_handle_to_target in pairs(seeds) do
			local map2 = {}
			for obj_handle, target_handle_to_seed in pairs(obj_handle_to_target) do
				local map3 = {}
				for target_handle, seed in pairs(target_handle_to_seed) do
					if type(target_handle) == "number" then
						local target = HandleToObject[target_handle]
						if target then
							map3[target] = seed
						else
							assert(false, string.format("Missing interaction target %d from '%s'", target_handle, int_type))
						end
					else
						map3[target_handle] = seed
					end
					count = count + 1
				end
				if type(obj_handle) == "number" then
					local obj = HandleToObject[obj_handle]
					if obj then
						map2[obj] = map3
					else
						printf("Missing interaction object %d from '%s'", obj_handle, int_type)
						assert(false, "Missing interaction object!")
					end
				else
					map2[obj_handle] = map3
				end
			end
			map1[int_type] = map2
		end
		return map1
	end
end

function NetGetRandData()
	ValidateInteractionSeeds()
	local rand_data = {
		map = MapLoadRandom,
		interact = SerializeInteractionSeeds(),
		seed = InteractionSeed,
	}
	return rand_data
end

function NetSetRandData(rand_data)
	MapLoadRandom = rand_data.map
	InteractionSeeds = UnserializeInteractionSeeds(rand_data.interact)
	InteractionSeed = rand_data.seed
end

function NetGetGameState()
	local success, err, state, state_local = procall(function()
		local non_permanent_objs = QueryNetObjects(true)
		local net_objs = QueryNetObjects()
		local scenario_data, scenario_data_local = NetGetScenarioData()

		local game_data = {}
		game_data.map_name = GetMapName()
		game_data.map_hash = mapdata.NetHash
		game_data.paused = not not PauseReasons.UserPaused
		game_data.rand = NetGetRandData()
		game_data.objects = NetGetNetObjs(non_permanent_objs)
		game_data.props = NetGetNetObjProps(non_permanent_objs)
		game_data.dynamic = NetGetDynamicData(net_objs)
		game_data.scenario = scenario_data
		game_data.globals = {}
		Msg("NetStateGet", game_data.globals)
		local state, err = NetSerialize(game_data)
		if not state then
			assert(false, "Network serialization error: " .. tostring(err))
			return err
		end
		FindSerializeError(state, game_data)

		local game_data_local = {}
		game_data_local.scenario = scenario_data_local
		game_data_local.objects = NetGetLocalObjData()
		game_data_local.MapLoadRandom = MapLoadRandom
		local state_local, err = NetSerialize(game_data_local)
		if not state_local then
			assert(false, "Network serialization error: " .. tostring(err))
			return err
		end
		FindSerializeError(state_local, game_data_local)

		local compressed_state = Compress(state)
		local compressed_state_local = Compress(state_local)
		return false, compressed_state, compressed_state_local
	end)
	if not success then
		return err
	end
	return err, state, state_local
end

function NetSetGameState(compressed_data, compressed_data_local)
	if not compressed_data then return end
	local game_data = Decompress(compressed_data)
	if not game_data then return "decompress" end
	game_data = NetUnserialize(game_data)
	if not game_data then return "unserialize" end
	local game_data_local, err_local
	if compressed_data_local then
		local data = Decompress(compressed_data_local)
		if not data then
			err_local = "decompress"
		else
			data = NetUnserialize(data)
			if not data then
				err_local = "unserialize"
			elseif data.MapLoadRandom == game_data.rand.map then
				game_data_local = data
			else
				err_local = "version"
			end
		end
	end

	assert(game_data.map_name == GetMapName())
	
	if game_data.map_hash ~= mapdata.NetHash then
		print("[NET ERROR] The local map is different version")
		--return "map"
	end

	local success, error = procall(function()
		-- remove all non-permanent objects - they will be copied from the host
		local non_permanent_objs = QueryNetObjects(true)
		DoneObjects(non_permanent_objs)

		NetCreateNetObjs(game_data.objects)
		NetSetNetObjProps(game_data.props)
		NetSetDynamicData(game_data.dynamic)
		NetSetRandData(game_data.rand)
		NetSetScenarioData(game_data.scenario, game_data_local and game_data_local.scenario)
		if game_data_local then
			SetLocalObjData(game_data_local.objects)
		end
		SetTimeFactor(const.DefaultTimeFactor)
		SetPause(game_data.paused or false)
		Msg("NetStateSet", game_data.globals) --> allow the dynamic objects to init some parts based on their surrounding environment or whatever)
	end)
	
	if not success then
		assert(false, tostring(error))
		return "failed", err_local
	end
	return nil, err_local
end

function NetGetNetObjs(objects)
	local object_data = {}
	local count = 0
	for _, obj in ipairs(objects) do
		object_data[count + 1] = obj.class
		object_data[count + 2] = obj.handle
		object_data[count + 3] = obj:GetPos()
		count = count + 3
	end
	return object_data
end

function NetCreateNetObjs(object_data)
	for i=1,#object_data, 3 do
		local class, handle, pos = unpack_params(object_data, i, i + 2)
		local obj = PlaceObject(class, { handle = handle })
		if obj then
			Object.SetPos(obj, pos) --> don't use the object's original method to avoid custom logic
		else
			mp_print("Cannot create an object", class, "with handle", handle)
		end
	end
end

local network_ignore_props = {
	Pos = true
}

function NetGetNetObjProps(objects)
	local prop_objdata = {}
	for i=1,#objects do
		local obj = objects[i]
		local modified_props = GetModifiedProperties( obj, nil, network_ignore_props )
		if modified_props then
			modified_props.__obj = obj
			AddNetObjDebugInfo(obj, modified_props)
			
			local serialized_props, err = NetSerialize(modified_props)
			if serialized_props and not FindSerializeError(serialized_props, modified_props) then
				prop_objdata[#prop_objdata + 1] = serialized_props
			else
				mp_print("Serialize properties failed for", format_value(obj), err)
				if Platform.developer then
					DebugPrint(format_value(modified_props))
				end
				assert(false, "Serialize properties failed")
			end
		end
	end
	return prop_objdata
end

function NetSetNetObjProps(prop_objdata)
	local warned = false
	for i = 1,#prop_objdata do
		local modified_props = NetUnserialize(prop_objdata[i])
		local obj = modified_props.__obj
		if obj then
			local props = obj:GetProperties()
			for j = 1, #props do
				local id = props[j].id
				local value = modified_props[id]
				if value ~= nil then
					local success, error = procall(obj.SetProperty, obj, id, value)
					if not success then
						mp_print("Failed to set", obj.class, "property", id, ":", error)
					end
				end
			end
		else
			ShowNetObjDebugInfo(modified_props)
		end
	end
end

function NetGetDynamicData(objects)
	local dynamic_objdata = {}
	for _, obj in ipairs(objects) do
		local data = {}

		procall(obj.GetDynamicData, obj, data)
		
		if next(data) then
			data.__obj = obj
			AddNetObjDebugInfo(obj, data)
			
			local serialized_data, err = NetSerialize(data)
			if serialized_data and not FindSerializeError(serialized_data, data) then
				dynamic_objdata[#dynamic_objdata + 1] = serialized_data
			else
				mp_print("Serialize dynamic data failed for", format_value(obj), err)
				assert(false, "Serialize dynamic data failed")
			end
		end
	end
	return dynamic_objdata
end

function NetSetDynamicData(dynamic_objdata)
	for i = 1,#dynamic_objdata do
		local data = NetUnserialize(dynamic_objdata[i])
		local obj = data.__obj
		if obj then
			local success, error = procall(obj.SetDynamicData, obj, data)
			if not success then
				mp_print("Failed to set", obj.class, "dynamic data:", error)
			end
		else
			ShowNetObjDebugInfo(data)
		end
	end
end

function NetAdjustTime(time)
	return time and (GameTime() - time) or nil
end

function NetGetLocalObjData()
	local objects = MapGet(true, "LootObj", function(o) return not IsNetObj(o) and o:GetGameFlags(const.gofPermanent) == 0 end)
	local objdata = {}
	for _, obj in ipairs(objects) do
		local data = {}
		data.__class = obj.class
		data.__pos = obj:GetPos()
		data.__props = GetModifiedProperties( obj, nil, network_ignore_props )
		procall(obj.GetDynamicData, obj, data)
		if next(data) then
			local serialized_data, err = NetSerialize(data)
			if serialized_data and not FindSerializeError(serialized_data, data) then
				objdata[#objdata + 1] = serialized_data
			else
				mp_print("Serialize dynamic data failed for", format_value(obj), err)
				assert(false, "Serialize dynamic data failed")
			end
		end
	end
	return objdata
end

function SetLocalObjData(objdata)
	for i = 1, #objdata do
		local data = NetUnserialize(objdata[i])
		local obj = PlaceObject(data.__class)
		if obj then
			NetTempObject(obj)
			Object.SetPos(obj, data.__pos) --> don't use the object's original method to avoid custom logic		
			local modified_props = data.__props
			local props = obj:GetProperties()
			for j = 1, #props do
				local id = props[j].id
				local value = modified_props[id]
				if value ~= nil then
					local success, error = procall(obj.SetProperty, obj, id, value)
					if not success then
						mp_print("Failed to set", obj.class, "property", id, ":", error)
					end
				end
			end
			local success, error = procall(obj.SetDynamicData, obj, data)
			if not success then
				mp_print("Failed to set", obj.class, "dynamic data:", error)
			end
		end
	end
end

-- Pause/Resume

function SetPause(pause)
	local paused = not not PauseReasons.UserPaused
	if paused == pause then return end
	if pause then
		Pause("UserPaused")
	else
		Resume("UserPaused")
	end
end

function TogglePause()
	local paused = not not PauseReasons.UserPaused
	if netSwarmSocket then
		NetEchoEvent("SetPause", not paused)
	else
		local pause = not paused
		SetPause(pause)
		return pause
	end
end

function NetEvents.SetPause(pause)
	SetPause(pause)
end

-------------------------------------------------[ Server time ]------------------------------------------------------

function ServerTime()
	return IsRealTimeThread() and (RealTime() + netServerRealTimeDelta) or (GameTime() + netServerGameTimeDelta)
end

function NetSetServerTime(server_time)
	if server_time then
		local estimated_rt = RealTime() + netServerRealTimeDelta
		local estimated_gt = GameTime() + netServerGameTimeDelta
		log("servertime", server_time, ", gt error", estimated_gt - server_time, ", rt error", estimated_rt - server_time)
		
		local new_rt_delta = server_time - RealTime()
		local new_gt_delta = server_time - GameTime()
		if netServerRealTimeDelta ~= new_rt_delta or netServerGameTimeDelta ~= new_gt_delta then
			netServerRealTimeDelta = new_rt_delta
			netServerGameTimeDelta = new_gt_delta
			Msg("ServerTimeUpdate")
		end
	else
		netServerRealTimeDelta = 0
		netServerGameTimeDelta = 0
	end
end

function WaitServerTime(time)
	while WaitMsg("ServerTimeUpdate", time - ServerTime()) do end
end

function WaitServerTick(tick_interval, tick_phase)
	WaitServerTime(ServerTime() / tick_interval * tick_interval + tick_interval + (tick_phase or 0))
end

function OnMsg.NetPing(server_time)
	NetSetServerTime(server_time)
end

-- SetTimeFactor
if FirstLoad then
	__SetTimeFactor = SetTimeFactor
end
NetEvents.SetTimeFactor = __SetTimeFactor
function SetTimeFactor(time_factor, sync)
	if sync then
		NetEchoEvent("SetTimeFactor", time_factor)
	else
		__SetTimeFactor(time_factor)
	end
end

-- Debug

function AddNetObjDebugInfo() end
function ReportMissingObj() end
function ShowNetObjDebugInfo() end

if Platform.developer then

MapVar("__missing_net_objs", {})
function ReportMissingObj(handle, class, pos)
	if handle and not __missing_net_objs[handle] then
		__missing_net_objs[handle] = true
		mp_print("Missing", class or "object", "with handle", handle, "at", pos)
	end
end

function AddNetObjDebugInfo(obj, data)
	data.__class = obj.class
	data.__handle = obj.handle
	data.__pos = obj:GetVisualPos()
end

function ShowNetObjDebugInfo(data)
	ReportMissingObj(data.__handle, data.__class, data.__pos)
end

end

