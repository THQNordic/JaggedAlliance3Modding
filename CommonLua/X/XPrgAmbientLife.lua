DefineClass.AmbientLife = {
	__parents = { "XPrg" },
	GlobalMap = "XPrgAmbientLife",
	GedEditor = "PrgEditor",
	EditorName = "Ambient Life",
	EditorMenubarName = "Ambient Life" ,
	EditorMenubar = "Editors.Art",
	EditorIcon = "CommonAssets/UI/Icons/conversation discussion language.png",
	PrgGlobalMap = "PrgAmbientLife",
}

if FirstLoad or ReloadForDlc then
	PrgAmbientLife = {}
end

------ XPrgAmbientLife specific commands  ---------

local PrgSlotFlagsUser = 24
local PrgSlotFlags = { "Occupied (bit 1)", "Present (bit 2)" }
local PrgSlotFlagOccupied = 2^0
local PrgSlotFlagPresent = 2^1
local PrgSlotFlagBlocked = 2^31

DefineClass.XPrgAmbientLifeCommand = {
	__parents =  { "XPrgCommand" },
}

-- Visit spot
DefineClass.XPrgPlaySpotPrg = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end  },
		{ id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "slot_data", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ id = "slotname", name = "Slot name", editor = "text", default = "", validate = validate_var},
		{ id = "slot", name = "Slot", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T(569417031596, "Play <spot> prg <color 0 128 0><comment>"), 
}

function XPrgPlaySpotPrg:GenCode(prgdata, level)
	local name = self.slotname
	local slot_data = self.slot_data ~= "" and self.slot_data or nil
	local slot = self.slot ~= "" and self.slot or nil
	local slotname = self.slotname ~= "" and self.slotname or nil
	if self.unit == prgdata.params[1].name then
		self:GenCodeCommandCallPrg(prgdata, level, name, self.unit, self.bld, self.obj, self.spot, slot_data, slot, slotname)
	else
		self:GenCodeCallPrg(prgdata, level, name, self.unit, self.bld, self.obj, self.spot)
	end
end
local spot_proximity_dist = 50*guic

function PrgLeadToBldPos(unit, bld, path_obj, pos, custom_waypoints, slot_data)
	local outside
	if slot_data then
		outside = slot_data.outside or false
	end

	-- return back from the last visit spot
	if unit:IsValidPos() then
		if pos and unit:GetDist(pos) < spot_proximity_dist then
			if outside ~= nil then unit:SetOutsideVisuals(outside) end
			return
		end
		local unit_wp = custom_waypoints and path_obj:FindWaypointsInRange(custom_waypoints, spot_proximity_dist, unit)
		if unit_wp then
			FollowWaypointPath(unit, wp, 1, #wp)
			if unit.visit_restart then return end
			if pos and unit:GetDist(pos) < spot_proximity_dist then
				if outside ~= nil then unit:SetOutsideVisuals(outside) end
				return
			end
		end
		local unit_path = path_obj:FindWaypointsInRange("Path", spot_proximity_dist, unit)
		if unit_path then
			FollowWaypointPath(unit, unit_path, 1, #unit_path)
			if unit.visit_restart then return end
			if pos and unit:GetDist(pos) < spot_proximity_dist then
				if outside ~= nil then unit:SetOutsideVisuals(outside) end
				return
			end
		end
	end

	local path, floordoor
	if pos then
		if unit:IsValidPos() then
			path = path_obj:FindWaypointsInRange("Path", spot_proximity_dist, pos, "Nearest", unit)
		else
			path = path_obj:FindWaypointsInRange("Path", spot_proximity_dist, pos)
		end
		floordoor = path_obj:FindWaypointsInRange("Floordoor", nil, nil, spot_proximity_dist, path and path[#path] or pos)
	end

	-- continue returning back, following the nearest floordoor chain (to hide somewhere)
	if unit:IsValidPos() then
		if floordoor and unit:GetDist(floordoor[#floordoor]) <= spot_proximity_dist then
			floordoor = nil
		else
			local unit_floordoor = path_obj:FindWaypointsInRange("Floordoor", nil, nil, spot_proximity_dist, unit)
			if unit_floordoor then
				-- outside. enter inside
				FollowWaypointPath(unit, unit_floordoor, #unit_floordoor, 1)
				if unit.visit_restart then return end
				local anim_idx = unit:GetWaitAnim()
				if anim_idx >= 0 then
					unit:SetState(anim_idx)
				else
					unit:SetStateText("idle")
				end
				Sleep(500) -- wait the door to close
				if unit.visit_restart then return end
				if not pos and bld then
					unit:DetachFromMap()
					unit:SetOutside(false)
				end
			end
		end
	end

	-- appoach pos chains
	if slot_data and slot_data.move_start == "Pathfind" and unit:IsValidPos() then
		if floordoor then
			unit:Goto(floordoor[1])
		elseif path then
			unit:Goto(path[#path])
		end
		if unit.visit_restart then return end
	end

	-- follow pos chains
	if outside ~= nil then
		unit:SetOutsideVisuals(outside)
	end
	if floordoor then
		unit:SetPos(floordoor[1])
		unit:Face(floordoor[2], 0)
		FollowWaypointPath(unit, floordoor, 1, #floordoor)
		if unit.visit_restart then return end
	end
	if path then
		if not unit:IsValidPos() then
			unit:SetPos(path[#path])
			unit:Face(path[#path - 1], 0)
		end
		FollowWaypointPath(unit, path, #path, 1)
		if unit.visit_restart then return end
	end
end

function PrgFollowPathWaypoints(unit, bld, spot_obj, spot, orient_to_spot, slot_data)
	local spot_pos, spot_angle
	local spot_state = slot_data and slot_data.spot_state or ""
	if spot_state ~= "" then
		spot_pos = spot_obj:GetSpotLocPos(spot_state, 0, spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot_state, 0, spot)
	else
		spot_pos = spot_obj:GetSpotLocPos(spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot)
	end
	if unit:IsValidPos() and unit:GetDist(spot_pos) > spot_proximity_dist then
		local wp = bld:FindWaypointsInRange("Path", spot_proximity_dist, spot_pos, spot_proximity_dist, unit)
		if wp then
			FollowWaypointPath(unit, wp, #wp, 1)
		else
			wp = bld:FindWaypointsInRange("Path", spot_proximity_dist, unit, spot_proximity_dist, spot_pos)
			if wp then
				FollowWaypointPath(unit, wp, 1, #wp)
			end
		end
		if unit.visit_restart then return end
	end
	if slot_data then
		unit:SetOutsideVisuals(slot_data.outside)
		if slot_data.adjust_z then
			local passable_z = terrain.FindPassableZ(spot_pos, unit.pfclass, guim, guim)
			if passable_z then
				spot_pos = spot_pos:SetZ(passable_z)
			end
		end
	end
	if not unit:IsValidPos() or unit:GetDist(spot_pos) > spot_proximity_dist then
		unit:SetPos(spot_pos)
		unit:SetAngle(spot_angle)
	elseif orient_to_spot then
		local snap_angle_time = 200 * abs(AngleDiff(spot_angle, unit:GetAngle())) / (180 * 60)
		unit:SetAngle(spot_angle, snap_angle_time)
		local snap_pos_time = Min(200, unit:GetDist(spot_pos) * 1000 / Max(1, unit:GetSpeed()) or 0)
		unit:SetPos(spot_pos, snap_pos_time)
		Sleep(snap_pos_time)
	end
end

function PrgLeadToSpot(unit, bld, spot_obj, spot, orient_to_spot, custom_waypoints, slot_data)
	if not IsValid(spot_obj) then
		return
	end
	local spot_pos, spot_angle
	local spot_state = slot_data and slot_data.spot_state or ""
	if spot_state ~= "" then
		spot_pos = spot_obj:GetSpotLocPos(spot_state, 0, spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot_state, 0, spot)
	else
		spot_pos = spot_obj:GetSpotLocPos(spot)
		spot_angle = spot_obj:GetSpotAngle2D(spot)
	end
	if slot_data and slot_data.adjust_z then
		local passable_z = terrain.FindPassableZ(spot_pos, unit.pfclass, guim, guim)
		if passable_z then
			spot_pos = spot_pos:SetZ(passable_z)
		end
	end
	if unit:IsValidPos() and unit:GetDist(spot_pos) > spot_proximity_dist then
		local unit_wp = custom_waypoints and bld:FindWaypointsInRange(custom_waypoints, spot_proximity_dist, unit)
		if unit_wp then
			FollowWaypointPath(unit, unit_wp, 1, #unit_wp)
			if unit.visit_restart then return end
		end
	end
	if not unit:IsValidPos() or unit:GetDist(spot_pos) > spot_proximity_dist then
		local spot_wp = custom_waypoints and bld:FindWaypointsInRange(custom_waypoints, spot_proximity_dist, spot_pos)
		if spot_wp then
			PrgLeadToBldPos(unit, bld, bld, spot_wp[#spot_wp], nil, slot_data)
			if unit.visit_restart then return end
			FollowWaypointPath(unit, spot_wp, #spot_wp, 1)
			if unit.visit_restart then return end
		else
			PrgLeadToBldPos(unit, bld, bld, spot_pos, nil, slot_data)
			if unit.visit_restart then return end
		end
	end
	if not unit:IsValidPos() or unit:GetDist(spot_pos) > spot_proximity_dist then
		unit:SetPos(spot_pos)
		unit:SetAngle(spot_angle)
	elseif orient_to_spot then
		local snap_angle_time = 200 * abs(AngleDiff(spot_angle, unit:GetAngle())) / (180 * 60)
		unit:SetAngle(spot_angle, snap_angle_time)
		local snap_pos_time = Min(200, unit:GetDist(spot_pos) * 1000 / Max(1, unit:GetSpeed()) or 0)
		unit:SetPos(spot_pos, snap_pos_time)
		Sleep(snap_pos_time)
	end
end

function PrgLeadToExit(unit, bld, custom_waypoints, slot_data, prefer_passable)
	local spotname = "Exit"
	if bld:HasSpot(spotname) then
		local spot
		if prefer_passable then
			if unit:IsValidPos() then
				spot = bld:NearestPassableSpot(spotname, unit)
			else
				spot = bld:RandomPassableSpot(spotname, unit)
			end
			if not spot then
				printf("once", '%s (handle=%d) "Exit" spots are on impassable!', bld:GetEntity(), bld.handle)
			end
		end
		if not spot then
			spot = bld:GetRandomSpot(spotname)
		end
		PrgLeadToSpot(unit, bld, bld, spot, false, custom_waypoints, slot_data)
	else
		PrgLeadToBldPos(unit, bld, bld, nil, custom_waypoints, slot_data)
	end
	if unit.visit_restart then return end
end

--[===[
Not finished functions

function PrgChainStep(unit, path, path_idx, forward, status)
	while path_idx do
		local id = path[path_idx]
		local param = path[path_idx + 1]
		path_idx = path_idx + (forward and 2 or -2)
		if path_idx <= 0 or path_idx > #path then path_idx = nil end
		if id == "DetachFromMap" then
			unit:DetachFromMap()
			unit:SetOutsideVisuals(false)
			return path_idx
		elseif id == "Teleport" then
			if param then
				unit:SetPos(IsPoint(param) and param or param[path_forward and #param or 1])
				return path_idx, "teleported"
			end
			status = "teleport"
		elseif param then
			if IsPoint(param) then
				if status == "teleport" or not unit:IsValidPos() then
					unit:SetPos(param)
					return path_idx, "teleported"
				elseif id == "Pathfind" then
					unit:Goto(param)
					return path_idx
				end
			else
				local forward = path_forward
				if id == "Waypoints_Backward" then
					forward = not forward
				end
				local start_idx = forward and 1 or #param
				local last_idx = forward and #param or 1
				if status == "teleport" or not unit:IsValidPos() then
					unit:SetPos(param[start_idx])
					start_idx = start_idx == 1 and 2 or start_idx - 1
					unit:Face(param[start_idx], 0)
				elseif status == "teleported" then
					if unit:GetDist2D(param[start_idx]) == 0 then
						start_idx = start_idx == 1 and 2 or start_idx - 1
					end
					unit:Face(param[start_idx], 0)
				end
				if id == "Pathfind" then
					for i = start_idx, last_idx, forward and 1 or -1 do
						unit:Goto(param[i])
					end
				else
					FollowWaypointPath(unit, param, start_idx, last_idx)
				end
				return path_idx
			end
		end
	end
end

function PRGChainFollow(unit, bld, chain, idx1, idx2)
	local idx = idx1 or 1
	idx2 = idx2 or #path
	local status
	if idx <= idx2 then
		while idx and idx <= idx2 do
			idx, status = PrgChainStep(unit, path, idx, true, status)
		end
	else
		while idx and idx >= idx2 do
			idx, status = PrgChainStep(unit, path, idx, false, status)
		end
	end
end

function PrgResolveChain(bld, dest_pos, chain, resolved)
	resolved = resolved or {}
	local last_pos = dest_pos
	for i = 1, #chain, 2 do
		local id = chain[i]
		local param = chain[i+1]
		local value = param
		
		if id == "Pathfind" or id == "Teleport" then
			if param and type(param) == "string" and bld:HasSpot(param) then
				local spot = bld:GetNearestSpot(param, last_pos)
				last_pos = bld:GetSpotPos(spot)
				value = last_pos
			else
				value = false
			end
		elseif id == "Waypoints" or id == "Waypoints_Backward" then
			local wp = bld:NearestWaypoints(last_pos, nil, name, 1)
			value = wp
			if wp then
				last_pos = wp[#wp]
			end
		end
		if value ~= nil then
			resolved[#resolved + 1] = id
			resolved[#resolved + 1] = value
		end
	end
	return resolved
end

local function PRGChainFindUnitIdx(unit, chain, forward)
	local on_valid_pos = unit:IsValidPos()
	local count = #chain
	for i = 1, count, 2 do
		local id = chain[i]
		local wp = chain[i+1]
		if id == "SetHolder" then
			if not on_valid_pos then
				return i + (forward and 1 or - 1)
			end
		elseif on_valid_pos then
			if IsPoint(wp) then
				if unit:GetDist(wp) <= spot_proximity_dist then
					return i + (forward and 1 or - 1)
				end
			elseif type(wp) == "table" and (id == "Waypoints_Backward" or id == "Waypoints" or "Pathfind" or "Teleport") then
				if forward then
					if i == 1 and unit:GetDist(wp[1]) <= spot_proximity_dist then
						return i - 1
					end
					if unit:GetDist(wp[#wp]) <= spot_proximity_dist then
						return i + 1
					end
				else
					if i == count and unit:GetDist(wp[#wp]) <= spot_proximity_dist then
						return i + 1
					end
					if unit:GetDist(wp[1]) <= spot_proximity_dist then
						return i
					end
				end
			end
		end
	end
	return true
end

function PrgChainLead(unit, bld, pos, chain, prev_chain)
	--local resolved = PrgResolveChain(chain, bld, pos)
	local idx = PRGChainFindUnitIdx(unit, chain, false)
	local prev_idx = not idx and prev_chain and PRGChainFindUnitIdx(unit, prev_chain, true)
	local status
	while not idx and prev_idx do
		prev_idx = PrgChainStep(unit, prev_chain, prev_idx, false, status)
		idx = PRGChainFindUnitIdx(unit, chain, false)
	end
	PRGChainFollow(unit, bld, chain, idx, 1, status)
end

--]===]

function PrgLeadToHolder(unit, bld, path_obj, slot_data)
	path_obj = path_obj or bld
	if not unit:IsValidPos() then
		return
	end
	local goto_spot = slot_data and slot_data.goto_spot or ""
	if goto_spot ~= "Teleport" then
		PrgLeadToBldPos(unit, bld, path_obj, nil, nil, slot_data)
		if unit.visit_restart then return end
	end
	unit:DetachFromMap()
	unit:SetOutsideVisuals(slot_data and slot_data.outside or false)
end

DefineClass.XPrgLeadTo = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "loc", name = "Location", editor = "dropdownlist", default = "Spot", items = { "Spot", "Exit", "PassableExit" } },
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot_obj", name = "Spot object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot var", editor = "text", default = "", no_edit = function(self) return self.loc ~= "Spot" end },
		{ id = "orient_to_spot", name = "Orient to spot", editor = "bool", default = false },
		{ id = "waypoints", name = "Custom Waypoints", editor = "text", default = "" },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T{601947096634, "Lead <unit> to <spot_obj> <txt> <color 0 128 0><comment>",
		txt = function(obj)
			local loc = obj.loc == "Spot" and T(725779511260, "<spot>") or T(691129973441, "<loc>")
			if obj.waypoints ~= "" then
				return T{558667157664, "<loc><newline>   (custom waypoints <waypoints>)", loc = loc}
			end
			return loc
		end },
}

function XPrgLeadTo:GenCode(prgdata, level)
	local waypoints = self.waypoints ~= "" and self.waypoints or nil
	local orient_to_spot = self.orient_to_spot and "true" or "false"
	if self.loc == "Spot" and self.spot ~= "" then
		local params = {
			self.unit,
			string.format('PrgResolvePathObj(%s)', self.spot_obj),
			self.spot_obj,
			self.spot,
			orient_to_spot
		}
		if waypoints then
			table.insert(params, waypoints)
		end
		PrgAddExecLine(prgdata, level, string.format('PrgLeadToSpot(%s)', table.concat(params, ', ')))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	elseif self.loc == "Exit" or self.loc == "PassableExit" then
		local params = {
			self.unit,
			self.spot_obj
		}
		if waypoints or self.loc == "PassableExit" then
			table.insert(params, waypoints or "nil")
		end
		if self.loc == "PassableExit" then
			table.insert(params, "nil")
			table.insert(params, "true")
		end
		PrgAddExecLine(prgdata, level, string.format('PrgLeadToExit(%s)', table.concat(params, ', ')))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	end
end

-- move waypoints
DefineClass.XPrgFollowWaypoints = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "dir", name = "Direction", editor = "dropdownlist", default = "Forward", items = { "Forward", "Backward" } },
		{ id = "waypoints_var", name = "Waypoints Var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "anim", name = "Anim", editor = "text", default = "", },
	},
	Menubar = "Move",
	MenubarSection = "",
	TreeView = T(986340233264, "Follow waypoints <waypoints_var> <dir> <color 0 128 0>"),
}

function XPrgFollowWaypoints:GenCode(prgdata, level)
	local resolved_wp = self.waypoints_var
	if self.anim ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s:SetMoveAnim("%s")', self.unit, self.anim))
	end
	local first, last
	if self.dir == "Forward" then
		first = 1
		last = "nil"
	else
		first = "nil"
		last = 1
	end
	local comment = string.format('	-- move [%s .. %s]', first or "last-index", last or "last-index")
	PrgAddExecLine(prgdata, level, string.format('FollowWaypointPath(%s, %s, %s, %s)%s', self.unit, resolved_wp, first, last, comment))
end

-- select spot
MapVar("PRG_BldSlotData", {}, weak_keys_meta)

local function ChangeSlotFlags(bld, attach, spot_type, slot, flags_add, flags_clear)
	if not slot then
		return
	end
	local bld_slots = PRG_BldSlotData[bld]
	if not bld_slots then
		bld_slots = {}
		PRG_BldSlotData[bld] = bld_slots
	end
	local obj_slots
	if not attach or attach == bld then
		obj_slots = bld_slots
	else
		obj_slots = bld_slots[attach]
		if not obj_slots then
			obj_slots = {}
			bld_slots[attach] = obj_slots
		end
	end
	local slots = obj_slots[spot_type]
	if not slots then
		slots = {}
		obj_slots[spot_type] = slots
	end
	local prev_flags = slots[slot] or 0
	local flags = FlagClear(bor(prev_flags, flags_add or 0), flags_clear or 0)
	if flags ~= prev_flags then
		slots[slot] = flags
	end
	return flags
end

local function ClearAllSlotFlags(bld, attach, flags_clear)
	local bld_slots = PRG_BldSlotData[bld]
	if not bld_slots then
		return
	end
	local obj_slots
	if not attach or attach == bld then
		obj_slots = bld_slots
	else
		obj_slots = bld_slots[attach]
		if not obj_slots then
			return
		end
	end
	for spot_type, slots in pairs(obj_slots) do
		local cnt = table.maxn(slots)
		for slot = 1, cnt do
			local prev_flags = slots[slot] or 0
			if prev_flags ~= 0 then
				local flags = FlagClear(prev_flags, flags_clear)
				if flags ~= prev_flags then
					slots[slot] = flags
				end
			end
		end
	end
end

local function ForEachSlot(func, slot_data, bld, obj, spot_type, spot_first, max_slots, flags_required, flags_missing)
	local slots = PRG_BldSlotData[bld]
	if obj ~= bld then
		slots = slots and slots[obj]
	end
	slots = slots and slots[spot_type]
	local cnt = Min(max_slots, slots and table.maxn(slots) or 0)
	local flags_all = bor(bor(flags_required, flags_missing), PrgSlotFlagBlocked)
	for slot = 1, cnt do
		if band(slots[slot], flags_all) == flags_required then
			func(spot_first + slot - 1, obj, slot_data, slot, spot_type)
		end
	end
	if flags_required == 0 then
		for slot = cnt + 1, max_slots do
			func(spot_first + slot - 1, obj, slot_data, slot, spot_type)
		end
	end
end

local function ForEachObjSpot(func, bld, attach, slot_data)
	local obj = attach or bld
	local spots = slot_data.spots
	if spots then
		local flags_required = slot_data.flags_required or 0
		local flags_missing = slot_data.flags_missing or 0
		local spot_state = slot_data.spot_state or ""
		for i = 1, #spots do
			local spot_type = spots[i]
			local first, last
			if spot_state ~= "" then
				first, last = obj:GetSpotRange(spot_state, spot_type)
			else
				first, last = obj:GetSpotRange(spot_type)
			end
			local max_slots = 1 + last - first
			ForEachSlot(func, slot_data, bld, obj, spot_type, first, max_slots, flags_required, flags_missing)
		end
	else -- holder
		func("", obj, slot_data, 1, "")
	end
end

local function ForEachSpotInMultipleObjects(func, bld, slot_data, attach_attach, attach1, attach2, ...)
	if attach_attach then
		ForEachSpotInMultipleObjects(func, bld, slot_data, nil, attach1:GetAttach(attach_attach))
	elseif attach1 then
		ForEachObjSpot(func, bld, attach1, slot_data)
	end
	if attach2 then
		return ForEachSpotInMultipleObjects(func, bld, slot_data, attach_attach, attach2, ...)
	end
end

function PrgMatchSlotData(data, bld, unit)
	return true
end

function PrgForEachObjSlotFromGroup(func, bld, attach, group, slots_list, unit)
	if not bld or not slots_list then
		return
	end
	for j = 1, #slots_list do
		local data = slots_list[j]
		if data.groups[group] and PrgMatchSlotData(data, bld, unit) then
			if attach then
				ForEachSpotInMultipleObjects(func, bld, data, data.attach_attach, attach)
			elseif data.attach then
				ForEachSpotInMultipleObjects(func, bld, data, data.attach_attach, bld:GetAttach(data.attach))
			else
				ForEachObjSpot(func, bld, nil, data)
			end
		end
	end
end

local _GatherSlotsList
local function AddSlot(spot, spot_obj, slot_data, slot, slot_name)
	local t = _GatherSlotsList
	local i = #t
	t[i + 1] = spot
	t[i + 2] = spot_obj
	t[i + 3] = slot_data
	t[i + 4] = slot
	t[i + 5] = slot_name
end

-- for every slot: spot, spot_obj, slot_data, slot, slot_name
local function GatherAvailableSlots(bld, attach, group, slots_list, unit)
	_GatherSlotsList = _GatherSlotsList or {}
	PrgForEachObjSlotFromGroup(AddSlot, bld, attach, group, slots_list, unit)
	if #_GatherSlotsList == 0 then
		return
	end
	local list = _GatherSlotsList
	_GatherSlotsList = nil
	return list
end

function PrgGetObjRandomSpotFromGroup(bld, attach, group, slots_list, unit)
	local list = GatherAvailableSlots(bld, attach, group, slots_list, unit)
	local size = list and #list or 0
	if size == 0 then
		return
	end
	local idx = 1 + 5 * bld:Random(size/5)
	return table.unpack(list, idx, idx + 4)
end

function PrgGetObjNearestSpotFromGroup(bld, attach, group, slots_list, unit)
	local list = GatherAvailableSlots(bld, attach, group, slots_list, unit)
	local size = list and #list or 0
	if size == 0 then
		return
	elseif size < 5 then
		return table.unpack(list)
	end
	local pt = unit:GetPos()
	local best_idx, best_dist, dist
	for idx = 1, size, 5 do
		local spot, spot_obj = list[idx], list[idx + 1]
		if spot == "" then
			dist = pt:Dist(spot_obj:GetPosXYZ())
		else
			dist = pt:Dist(spot_obj:GetSpotPosXYZ(spot))
		end
		if idx == 1 or dist < best_dist then
			best_idx, best_dist = idx, dist
		end
	end
	return table.unpack(list, best_idx, best_idx + 4)
end

function PrgVisitHolder(unit, bld, path_obj, time, slot_data)
	if time then
		unit.visit_spot_end_time = GameTime() + time
		unit:PushDestructor(function(unit)
			unit.visit_spot_end_time = false
		end)
	end
	if unit:IsValidPos() then
		PrgLeadToHolder(unit, bld, path_obj, slot_data)
	end
	unit:WaitVisitEnd()
	if time then
		unit:PopAndCallDestructor()
	end
end

function PrgResolvePathObj(attach)
	if not IsValid(attach) then
		return
	end
	while attach and not attach:IsKindOf("WaypointsObj") do
		attach = attach:GetParent()
	end
	return attach
end

function PrgGotoSpot(unit, bld, spot_obj, spot, slot_data)
	spot = spot or ""
	if unit:IsValidPos() then
		if slot_data and slot_data.move_start == "GoToExitSpot" then
			unit:Goto(spot_obj:GetSpotLocPos(spot_obj:GetRandomSpot("Exit")))
			if unit.visit_restart then return end
		end
	end
	if spot == "" then
		if unit:IsValidPos() then
			local path_obj = PrgResolvePathObj(spot_obj) or bld
			PrgLeadToHolder(unit, bld, path_obj, slot_data)
		end
		return
	end
	local goto_spot = slot_data.goto_spot or ""
	if goto_spot == "LeadToSpot" then
		local path_obj = PrgResolvePathObj(spot_obj) or bld
		PrgLeadToSpot(unit, path_obj, spot_obj, spot, true, slot_data.custom_waypoints, slot_data)
	elseif goto_spot == "FollowPathWaypoints" then
		local path_obj = PrgResolvePathObj(spot_obj) or bld
		PrgFollowPathWaypoints(unit, path_obj, spot_obj, spot, true, slot_data)
	elseif goto_spot ~= "" then
		local spot_pos, spot_angle
		local spot_state = slot_data and slot_data.spot_state or ""
		if spot_state ~= "" then
			spot_pos = spot_obj:GetSpotLocPos(spot_state, 0, spot)
			spot_angle = spot_obj:GetSpotAngle2D(spot_state, 0, spot)
		else
			spot_pos = spot_obj:GetSpotLocPos(spot)
			spot_angle = spot_obj:GetSpotAngle2D(spot)
		end
		local adjusted_pos
		if slot_data then
			unit:SetOutsideVisuals(slot_data.outside)
			if slot_data.adjust_z then
				local passable_z = terrain.FindPassableZ(spot_pos, unit.pfclass, guim, guim)
				if passable_z then
					adjusted_pos = spot_pos:SetZ(passable_z)
				end
			end
		end
		if not unit:IsValidPos() then
			unit:SetPos(adjusted_pos)
			unit:SetAngle(spot_angle)
		else
			if goto_spot == "Pathfind" then
				unit:Goto(spot_pos)
				if unit.visit_restart then return end
			end
			if goto_spot == "Pathfind" or goto_spot == "StraightLine" then
				unit:Goto(spot_pos, "sl")
				if unit.visit_restart then return end
				local snap_angle_time = 200 * abs(AngleDiff(spot_angle, unit:GetAngle())) / (180 * 60)
				unit:SetAngle(spot_angle, snap_angle_time)
			else
				unit:SetPos(adjusted_pos)
				unit:SetAngle(spot_angle)
			end
		end
	end
end

function PrgReturnFromSpot(unit, bld, spot_obj, spot, slot_data)
	local move_end = slot_data and slot_data.move_end or ""
	if move_end == "" then
		return
	end
	if not unit:IsValidPos() and spot_obj and not IsValid(spot_obj) and bld then
		spot_obj = bld
		local attaches = slot_data and (slot_data.attach or "") ~= "" and spot_obj:GetAttaches(slot_data.attach)
		if attaches then
			spot_obj = unit:TableRand(attaches)
			attaches = (slot_data.attach_attach or "") ~= "" and spot_obj:GetAttaches(slot_data.attach_attach)
			if attaches then
				spot_obj = unit:TableRand(attaches)
			end
		end
	end
	local path_obj = PrgResolvePathObj(spot_obj) or bld
	if move_end == "LeadToExit" then
		PrgLeadToExit(unit, path_obj, slot_data.custom_waypoints, slot_data)
	elseif move_end == "TeleportToExit" then
		if path_obj:HasSpot("Exit") then
			local x, y, z, angle = path_obj:GetSpotLocXYZ(path_obj:GetRandomSpot("Exit"))
			unit:SetPos(x, y, z)
			unit:SetAngle(angle)
		else
			unit:DetachFromMap()
		end
	end
end

function PrgVisitSlot(unit, bld, spot_obj, spot, slot_data, slot, slot_name, time, visits_count, ...)
	spot = spot or ""
	if not slot_name and spot ~= "" then
		if slot then
			slot_name = IsValid(spot_obj) and spot_obj:GetSpotName(spot)
		else
			slot, slot_name = PrgGetSlotBySpot(spot_obj, spot, slot_data)
		end
	end
	local prg = slot_name and PrgAmbientLife[slot_name]
	local dtor
	if prg and IsFlagSet(slot_data.flags_missing or 0, PrgSlotFlagOccupied) then
		dtor = true
		unit:PushDestructor(function(unit)
			ChangeSlotFlags(bld, spot_obj, slot_name, slot, 0, PrgSlotFlagOccupied)
		end)
		ChangeSlotFlags(bld, spot_obj, slot_name, slot, PrgSlotFlagOccupied, 0)
	end
	PrgGotoSpot(unit, bld, spot_obj, spot, slot_data)
	if not unit.visit_restart then
		unit.visit_spot_end_time = time and GameTime() + time or false
		if prg then
			for i = 1, (visits_count or 1) do
				prg(unit, bld, spot_obj, spot, slot_data, slot, slot_name, ...)
				if unit.visit_restart then break end
			end
		elseif spot == "" then
			unit:WaitVisitEnd()
		end
		unit.visit_spot_end_time = false
	end
	PrgReturnFromSpot(unit, bld, spot_obj, spot, slot_data)
	if dtor then
		unit:PopAndCallDestructor()
	end
end

function PrgBlockSpot(bld, obj, spot)
	PrgChangeSpotFlags(bld, obj, spot, PrgSlotFlagBlocked)
end

function PrgUnblockAllSpots(bld, obj)
	ClearAllSlotFlags(bld, obj, PrgSlotFlagBlocked)
end

function PrgChangeSpotFlags(bld, obj, spot, flags_add, flags_clear, spot_type, slot)
	if not spot then
		return 0
	end
	if not spot_type then
		spot_type = spot and IsValid(obj) and obj:GetSpotName(spot) or ""
	end
	if spot_type ~= "" then
		if not slot and spot then
			slot = spot - obj:GetSpotBeginIndex(spot_type) + 1
		end
		return ChangeSlotFlags(bld, obj, spot_type, slot, flags_add, flags_clear)
	end
	return 0
end

function PrgGetSlotBySpot(obj, spot, slot_data)
	local spot_type = spot and spot ~= "" and IsValid(obj) and obj:GetSpotName(spot) or ""
	if spot_type == "" then
		return
	end
	local first, last
	local spot_state = slot_data and slot_data.spot_state or ""
	if spot_state == "" then
		first, last = obj:GetSpotRange(spot_type)
	else
		first, last = GetSpotRange(obj:GetEntity(), spot_state, spot_type)
	end
	assert(spot >= first and spot <= last)
	return spot - first + 1, spot_type
end

function GetObjRandomSpotByFlags(obj, attach_class, slot_data, spot_type1, ...)
end
function GetObjRandomSpotByFlagsFromList(obj, list, slot_data)
end

DefineClass.XPrgChangeSlotFlags = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Flags", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Flags", id = "obj", name = "Object", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Flags", id = "spot", name = "Spot", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Flags", id = "slotname", name = "Slot name", editor = "text", default = "", validate = validate_var},
		{ category = "Flags", id = "slot", name = "Slot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Flags", id = "flags_add", name = "Flags add", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ category = "Flags", id = "flags_clear", name = "Flags clear", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ category = "PRG End", id = "dtor_flags_add", name = "Dtor flags add", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ category = "PRG End", id = "dtor_flags_clear", name = "Dtor flags clear", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{221014920931, "<txt>",
		txt = function(obj)
			local list = {}
			if obj.comment ~= "" then
				table.insert(list, Untranslated("<color 0 128 0><comment></color>"))
			end
			if obj.flags_add ~= 0 then
				table.insert(list, Untranslated("Set <obj> <spot> flags <flags_add>"))
			end
			if obj.flags_clear ~= 0 then
				table.insert(list, Untranslated("Clear <obj> <spot> flags <flags_clear>"))
			end
			if obj.dtor_flags_add ~= 0 then
				table.insert(list, Untranslated("Dtor set <obj> <spot> flags <dtor_flags_add>"))
			end
			if obj.dtor_flags_clear ~= 0 then
				table.insert(list, Untranslated("Dtor clear <obj> <spot> flags <dtor_flags_clear>"))
			end
			if #list == 0 then
				return Untranslated("Set <obj> <spot> flags <flags_add>")
			end
			return table.concat(list, "\n")
	end,}
}

function XPrgChangeSlotFlags:GenCode(prgdata, level)
	if self.flags_add == 0 and self.flags_clear == 0 and self.dtor_flags_add == 0 and self.dtor_flags_clear == 0 then
		return
	end
	local g_spot_type
	local g_slot = self.slot
	if g_slot == "" then
		g_spot_type = PrgGetFreeVarName(prgdata, "_spot_type")
		PrgNewVar(g_spot_type, prgdata.exec_scope, prgdata)
		g_slot = PrgGetFreeVarName(prgdata, "_slot")
		PrgNewVar(g_slot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s, %s = PrgGetSlotBySpot(%s, %s)', g_slot, g_spot_type, self.obj, self.spot))
	else
		g_spot_type = self.slotname
		if g_spot_type == "" then
			PrgNewVar(g_spot_type, prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', g_spot_type, self.spot, self.obj, self.spot))
		end
	end
	if self.flags_add ~= 0 or self.flags_clear ~= 0 then
		PrgAddExecLine(prgdata, level, string.format('PrgChangeSpotFlags(%s, %s, %s, %s, %s, %s, %s)',
			self.bld, self.obj, self.spot, self.flags_add, self.flags_clear, g_spot_type, g_slot))
	end
	if self.dtor_flags_add ~= 0 or self.dtor_flags_clear ~= 0 then
		PrgAddDtorLine(prgdata, 2, string.format('PrgChangeSpotFlags(%s, %s, %s, %s, %s, %s, %s)', 
			self.bld, self.obj, self.spot, self.dtor_flags_add, self.dtor_flags_clear, g_spot_type, g_slot))
	end
end

DefineClass.XPrgHasVisitTime = {
	__parents = { "XPrgCondition" , "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "unit", name = "Unit", default = "unit", editor = "combo", items = function(self) return self:UpdateLocalVarCombo() end },
	},
	Menubar = "Condition",
	MenubarSection = "",
}

function XPrgHasVisitTime:GenConditionTreeView()
	if self.Not then
		return T(614538479407, "<unit> has no visit time")
	end
	return T(805860218823, "<unit> has visit time")
end

function XPrgHasVisitTime:GenConditionCode(prgdata)
	if self.Not then
		return string.format('%s:VisitTimeLeft() == 0', self.unit)
	end
	return string.format('%s:VisitTimeLeft() > 0', self.unit)
end

DefineClass.XPrgCheckSpotFlags = {
	__parents = { "XPrgCondition", "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "slotname", name = "Slot name", editor = "text", default = "", validate = validate_var},
		{ id = "slot", name = "Slot", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "flags_required", name = "Flags required", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
		{ id = "flags_missing", name = "Flags missing", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },
	},
	Menubar = "Condition",
	MenubarSection = "",
}

function XPrgCheckSpotFlags:GenConditionTreeView()
	local not_text = self.Not and T(555910511517, "not") or ""
	if self.flags_required ~= 0 or self.flags_missing ~= 0 then
		return T{203979122439, "<not_text> <obj> <spot> required <flags_required>, missing <flags_missing>", not_text = not_text}
	elseif self.flags_required ~= 0 then
		return T{401424619805, "<not_text> <obj> <spot> required <flags_required>", not_text = not_text}
	elseif self.flags_missing ~= 0 then
		return T{638353608159, "<not_text> <obj> <spot> missing <flags_missing>", not_text = not_text}
	elseif self.Not then
		return T(622500851793, "false")
	else
		return T(728621261810, "true")
	end
end

function XPrgCheckSpotFlags:GenConditionCode(prgdata, level)
	local g_spot_type = self.slotname
	if g_spot_type == "" then
		local g_spot_type = PrgGetFreeVarName(prgdata, "_spot_type")
		PrgNewVar(g_spot_type, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', g_spot_type, self.spot, self.obj, self.spot))
	end
	local slot = self.slot ~= "" and self.slot or "nil"
	local flags = string.format('PrgChangeSpotFlags(%s, %s, %s, %d, %d, %s, %s)', self.bld, self.obj, self.spot, 0, 0, g_spot_type, slot)
	local condition
	local cmp = self.Not and "~=" or "=="
	if self.flags_required ~= 0 and self.flags_missing ~= 0 then
		condition = string.format('band(%s, bor(%s, %s)) %s %s', flags, self.flags_required, self.flags_missing, cmp, self.flags_required)
	elseif self.flags_required ~= 0 then
		condition = string.format('band(%s, %s) %s %s', flags, self.flags_required, cmp, self.flags_required)
	elseif self.flags_missing ~= 0 then
		condition = string.format('band(%s, %s) %s 0', flags, self.flags_missing, cmp)
	elseif self.Not then
		condition = "false"
	else
		condition = "true"
	end
	return condition
end

-- GetSpotName
DefineClass.XPrgGetSpotName = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(256648612496, "<var_slotname> = Name of <obj> <spot>"),
}

function XPrgGetSpotName:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', self.var_slotname, self.spot, self.obj, self.spot))
end

-- XPrgGetSlotFromSpot
DefineClass.XPrgGetSlotFromSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot", name = "Spot var", editor = "combo", default = "" , items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Select", id = "slot_data", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot", name = "Slot", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(224239931056, "<var_slotname>, <var_slot> = Slot of <obj> <spot>"),
}

function XPrgGetSlotFromSpot:GenCode(prgdata, level)
	local slotname = self.var_slotname
	if slotname == "" then
		slotname = PrgGetFreeVarName(prgdata, "_slotname")
	end
	PrgNewVar(slotname, prgdata.exec_scope, prgdata)
	local slot = self.var_slot
	if slot == "" then
		PrgAddExecLine(prgdata, level, string.format('%s = %s and IsValid(%s) and obj:GetSpotName(%s) or ""', slotname, self.spot, self.obj, self.spot))
		return
	end
	PrgNewVar(slot, prgdata.exec_scope, prgdata)
	if self.slot_data ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s, %s = PrgGetSlotBySpot(%s, %s, %s)', slot, slotname, self.obj, self.spot, self.slot_data))
	else
		PrgAddExecLine(prgdata, level, string.format('%s, %s = PrgGetSlotBySpot(%s, %s)', slot, slotname, self.obj, self.spot))
	end
end

-- GetSpotPos
DefineClass.XPrgGetSpotPos = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot_var", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(474325559146, "<var_pos> = Position of <obj> <spot_var>"),
}

function XPrgGetSpotPos:GenCode(prgdata, level)
	local resolved_pos = string.format('%s:GetSpotLocPos(%s)', self.obj, self.spot_var)
	local var_pos = self.var_pos ~= "" and self.var_pos
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_pos, resolved_pos))
	end
end

-- GetWaypointsPos
DefineClass.XPrgGetWaypointsPos = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Obj", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "waypoints_var", name = "Waypoints var", editor = "text", default = "" },
		{ category = "Select", id = "waypoints_idx", name = "Waypoints index", editor = "text", default = "" },
		{ category = "Select", id = "fallback_pos", name = "Fallback pos", editor = "text", default = "" },
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T{406734142728, "<var_pos> = Position of <obj> <waypoints_var>[<idx>]",
		idx = function(obj)
			return obj.waypoints_idx ~= "" and T(198459076916, "<waypoints_idx>") or T(438475026383, "last")
		end,
	},
}

function XPrgGetWaypointsPos:GenCode(prgdata, level)
	local resolved_pos
	if self.waypoints_idx == "" then
		resolved_pos = string.format('%s[#%s]', self.waypoints_var, self.waypoints_var)
	elseif self.waypoints_idx == "1" then
		resolved_pos = string.format('%s[1]', self.waypoints_var)
	else
		resolved_pos = string.format('(%s[%s] or %s[#%s])', self.waypoints_var, self.waypoints_idx, self.waypoints_var, self.waypoints_var)
	end
	local var_pos = self.var_pos
	if var_pos ~= "" then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		local txt = string.format('%s = %s and %s', var_pos, self.waypoints_var, resolved_pos)
		if self.fallback_pos ~= "" then
			txt = string.format('%s or %s', txt, self.fallback_pos)
		end
		PrgAddExecLine(prgdata, level, txt)
	end
end

-- NearestSpot
DefineClass.XPrgNearestSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot_type", name = "Object spot", editor = "text", default = "" },
		{ category = "Select", id = "target", name = "Target", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(337758260894, "<var_spot> <var_pos> = Nearest spot <spot_type> to <target>"),
}

function XPrgNearestSpot:GenCode(prgdata, level)
	local resolved_spot = string.format('%s:GetNearestSpot("%s", %s)', self.obj, self.spot_type, self.target)
	local var_spot = self.var_spot ~= "" and self.var_spot
	local var_pos = self.var_pos ~= "" and self.var_pos
	if var_spot or var_pos then
		var_spot = var_spot or "_spot"
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_spot, resolved_spot))
	end
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s:GetSpotLocPos(%s)', var_pos, self.obj, var_spot))
	end
end

-- RandomSpot
DefineClass.XPrgRandomSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "spot_type", name = "Object spot", editor = "text", default = "" },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_pos", name = "Pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(505114548882, "<var_spot> <var_pos> = Random spot <spot_type>"),
}

function XPrgRandomSpot:GenCode(prgdata, level)
	local resolved_spot = string.format('%s:GetRandomSpot("%s")', self.obj, self.spot_type)
	local var_spot = self.var_spot ~= "" and self.var_spot
	local var_pos = self.var_pos ~= "" and self.var_pos
	if var_spot or var_pos then
		var_spot = var_spot or "_spot"
		PrgNewVar(var_spot, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', var_spot, resolved_spot))
	end
	if var_pos then
		PrgNewVar(var_pos, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s:GetSpotLocPos(%s)', var_pos, self.obj, var_spot))
	end
end

-- SelectWaypoints
DefineClass.XPrgSelectWaypoints = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "obj", name = "Obj", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "waypoints", name = "Waypoints name", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "first_target", name = "Waypoints start", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "first_target_range", name = "Waypoints start range", editor = "combo", default = tostring(spot_proximity_dist), items = {tostring(spot_proximity_dist), "Nearest"} },
		{ category = "Select", id = "last_target", name = "Waypoints end", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "last_target_range", name = "Waypoints end range", editor = "combo", default = tostring(spot_proximity_dist), items = {tostring(spot_proximity_dist), "Nearest"}},
		{ category = "Variables", id = "var_waypoints", name = "Waypoints", editor = "text", default = "", validate = validate_var },
	},
	Menubar = "Object",
	MenubarSection = "Select",
	TreeView = T(449306746296, "<var_waypoints> = Find <waypoints>(start:<first_target>, end:<last_target>)"),
}

function XPrgSelectWaypoints:GenCode(prgdata, level)
	local target1 = self.first_target == "" and "nil" or self.first_target
	local target2 = self.last_target == "" and "nil" or self.last_target
	local first_range = self.first_target_range == "Nearest" and '"Nearest"' or self.first_target_range
	local last_range = self.last_target_range == "Nearest" and '"Nearest"' or self.last_target_range
	local resolved_wp = string.format('%s:FindWaypointsInRange("%s", %s, %s, %s, %s)', self.obj, self.waypoints, first_range, target1, last_range, target2)
	local wp_var = self.var_waypoints == "" and "_path" or self.var_waypoints
	if wp_var then
		PrgNewVar(wp_var, prgdata.exec_scope, prgdata)
		PrgAddExecLine(prgdata, level, string.format('%s = %s', wp_var, resolved_wp))
	end
end

-- NearestAttach
DefineClass.XPrgNearestAttach = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "classname", name = "Classname", editor = "text", default = "" },
		{ category = "Select", id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ category = "Select", id = "target", name = "Target", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Select", id = "eval", name = "Eval", editor = "dropdownlist", default = "Nearest", items = { "Nearest", "Nearest2D" } },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
	},
	Menubar = "Object",
	MenubarSection = "",
	TreeView = T(753077944149, "<var_obj> = Nearest <classname> to <target>"),
}

function XPrgNearestAttach:GenCode(prgdata, level)
	local eval = self.eval == "Nearest2D" and "IsCloser2D" or "IsCloser"
	local resolved_obj = string.format('PrgGetNearestAttach(%s, "%s", %s, %s, "%s")', eval, self.spot_type, self.target, self.bld, self.classname)
	local var_obj = self.var_obj ~= "" and self.var_obj or "_obj"
	PrgNewVar(var_obj, prgdata.exec_scope, prgdata)
	PrgAddExecLine(prgdata, level, string.format('%s = %s', var_obj, resolved_obj))
end


function PrgGetNearestAttach(eval, spot_type, target, bld, attach_classname)
	if not IsValid(bld) then
		return
	end
	return PrgGetNearestObject(eval, spot_type, target, bld:GetAttach(attach_classname))
end

function PrgGetNearestObject(eval, spot_type, target, best_obj, attach2, attach3, ...)
	if attach2 then
		if spot_type and spot_type ~= "" and spot_type ~= "Origin" then
			if eval(target, attach2:GetSpotLocPos(attach2:GetSpotBeginIndex(spot_type)), best_obj:GetSpotLocPos(best_obj:GetSpotBeginIndex(spot_type))) then
				best_obj = attach2
			end
		elseif eval(target, attach2, best_obj) then
			best_obj = attach2
		end
		if attach3 then
			best_obj = PrgGetNearestObject(eval, spot_type, target, best_obj, attach3, ...)
		end
	end
	return best_obj
end

-- Use object
local UseObjectCombo = { "", "Use", "Open", "Open2", "Close" }

DefineClass.XPrgUseObject = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "action", name = "Action", editor = "combo", default = "Use", items = UseObjectCombo },
		{ id = "action_var", name = "Action Var", editor = "text", default = "" },
		{ id = "param1", name = "Param 1", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "param2", name = "Param 2", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "dtor_action", name = "Dtor action", editor = "combo", default = "", items = UseObjectCombo },
	},
	Menubar = "Game",
	MenubarSection = "",
	TreeView = T{221014920931, "<txt>",
		txt = function(obj)
			local params = obj:GetParams()
			if params ~= "" then
				params = T{229548576744, "<params>", params = Untranslated(params) }
			end
			local text1
			if obj.action ~= "" then
				text1 = T{709667218989, "<action> <obj> <params>", params = params }
			elseif obj.action_var ~= "" then
				text1 = T{988466378489, "<obj> action: <action_var> <params>", params = params }
			end
			local text2 = obj.dtor_action ~= "" and T{319120764798, "( Dtor <dtor_action> <obj> <params>)", params = params }
			return text1 and text2 and text1 .. "\n" .. text2 or text1 or text2 or ""
		end
	},
}

function XPrgUseObject:GetParams()
	local params = ""
	if self.param2 ~= "" then params = params ~= "" and self.param2 .. ", " .. params or self.param2 end
	if self.param1 ~= "" then params = params ~= "" and self.param1 .. ", " .. params or self.param1 end
	return params
end

function XPrgUseObject:GenCode(prgdata, level)
	local params = self:GetParams()
	if self.action ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s:%s(%s)', self.obj, self.action, params))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	elseif self.action_var ~= "" then
		PrgAddExecLine(prgdata, level, string.format('%s[%s](%s%s)', self.obj, self.action_var, self.obj, params ~= "" and ", " .. params or ""))
		PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
	end
	if self.dtor_action ~= "" then
		local g_obj = self.obj
		if self.action ~= "" then
			g_obj = PrgGetFreeVarName(prgdata, "_objaction")
			PrgNewVar(g_obj, prgdata.exec_scope, prgdata)
			PrgAddExecLine(prgdata, level, string.format('%s = %s', g_obj, self.obj))
		end
		PrgAddDtorLine(prgdata, 2, string.format('if IsValid(%s) then', g_obj))
		PrgAddDtorLine(prgdata, 3, string.format('%s:%s(%s)', g_obj, self.dtor_action, params))
		PrgAddDtorLine(prgdata, 2, string.format('end'))
	end
end

-- EnterInside
DefineClass.XPrgEnterInside = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
	},
	Menubar = "Game",
	MenubarSection = "",
	TreeView = T(643070862836, "Set <unit> inside"),
}

function XPrgEnterInside:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:SetOutsideVisuals(false)', self.unit))
end

-- ExitOutside
DefineClass.XPrgExitOutside = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Select", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
	},
	Menubar = "Game",
	MenubarSection = "",
	TreeView = T(558482318624, "Set <unit> outside"),
}

function XPrgExitOutside:GenCode(prgdata, level)
	PrgAddExecLine(prgdata, level, string.format('%s:SetOutsideVisuals(true)', self.unit))
end

-- SnapToSpot
DefineClass.XPrgSnapToSpot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "actor", name = "Actor", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "obj", name = "Object", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot", name = "Spot var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ id = "attach", name = "Attach", editor = "bool", default = false },
		{ id = "offset", name = "Offset", editor = "point", default = point30, scale = "m" },
		{ id = "time", name = "Time", editor = "number", default = "200" },
	},
	Menubar = "Object",
	MenubarSection = "Orient",
	TreeView = T(700136323216, "Snap <actor> to <obj> <spot><color 0 128 0><comment>"),
}

function XPrgSnapToSpot:GenCode(prgdata, level)
	if not self.attach then
		self:GenCodeSetPos(prgdata, level, self.actor, self.obj, self.spot, self.spot_type, self.offset, self.time)
	end
	self:GenCodeOrient(prgdata, level, self.actor, 1, self.obj, self.spot, self.spot_type, "SpotX 2D", self.attach, self.offset, self.time, true, false)
end


-- Define slot
DefineClass.XPrgDefineSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "groups", name = "Groups", editor = "text", default = "" },
		{ category = "Slot", id = "spot_type", name = "Spot name", editor = "text", default = "" },
		{ category = "Slot", id = "spot_state", name = "Spot state", editor = "combo", default = "", items = { "", "idle" } },
		{ category = "Slot", id = "attach", name = "Attach", editor = "text", default = "" },
		{ category = "Slot", id = "attach_attach", name = "Attach attach", editor = "text", default = "", no_edit = function(self) return self.attach == "" end },
		{ category = "Slot", id = "outside", name = "Slot Outside", editor = "bool", default = false },
		{ category = "Path", id = "move_start", name = "Move start", editor = "dropdownlist", default = "", items = { "", "Pathfind", "GoToExitSpot" }},
		{ category = "Path", id = "goto_spot", name = "Goto to slot", editor = "dropdownlist", default = "", items = { "", "LeadToSpot", "StraightLine", "Pathfind", "Teleport", "FollowPathWaypoints" }},
		{ category = "Path", id = "move_end", name = "Move end", editor = "dropdownlist", default = "", items = { "", "LeadToExit", "TeleportToExit" }},
		{ category = "Path", id = "custom_waypoints", name = "Custom waypoints", editor = "text", default = "" },
		{ category = "Path", id = "adjust_z", name = "Require passable Z", editor = "bool", default = false, help = "Prevent the actor from clipping into terrain by adjusting the z coordinate" },
		{ category = "Visit Flags", id = "flags_required", name = "Flags required", editor = "flags", size = PrgSlotFlagsUser, default = 0 , items = PrgSlotFlags },
		{ category = "Visit Flags", id = "flags_missing", name = "Flags missing", editor = "flags", size = PrgSlotFlagsUser, default = 0, items = PrgSlotFlags },

		{ id = "comment" },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{180913368574, "Define slot <groups> <spots><color 0 128 0><comment>",
		spots = function(obj)
			return obj.spot_type ~= "" and T(333975580910, "(<spot_type>) ") or ""
		end,
	},
}

function XPrgDefineSlot:GenCode(prgdata, level)
	local t = {}
	local var = PrgNewVar("_slots", prgdata.external_vars, prgdata)
	var.value = var.value or {}
	table.insert(var.value, t)

	t.groups = t.groups or {}
	local list = PrgSplitStr(self.groups, ",")
	for i = 1, #list do
		t.groups[ list[i] ] = true
	end
	if self.spot_type ~= "" then
		t.spots = PrgSplitStr(self.spot_type, ",")
	end
	if self.spot_state ~= "" then
		t.spot_state = self.spot_state
	end
	if self.attach ~= "" then
		t.attach = self.attach
	end
	if self.attach_attach ~= "" then
		t.attach_attach = self.attach_attach
	end
	if self.outside then
		t.outside = self.outside
	end
	t.goto_spot = self.goto_spot
	if self.move_start ~= "" then
		t.move_start = self.move_start
	end
	if self.move_end ~= "" then
		t.move_end = self.move_end
	end
	if self.custom_waypoints ~= "" then
		t.custom_waypoints = self.custom_waypoints
	end
	if self.adjust_z ~= "" then
		t.adjust_z = self.adjust_z
	end
	if self.flags_required ~= 0 then
		t.flags_required = self.flags_required
	end
	if self.flags_missing ~= 0 then
		t.flags_missing = self.flags_missing
	end
	self:GenCustomProperties(t)
end

function XPrgDefineSlot:GenCustomProperties(t)
end

-- Select slot
DefineClass.XPrgSelectSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Slot", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "group", name = "Group", editor = "text", default = "" },
		{ category = "Slot", id = "attach_var", name = "Attach Var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Eval", id = "eval", name = "Eval", editor = "dropdownlist", default = "Random", items = { "Random", "Nearest" } },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot_desc", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot", name = "Slot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_pos", name = "Spot pos", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{485397093579, "<vars> = Select slot <group>",
		vars = function(obj)
			local t
			if obj.var_obj ~= "" then t = (t and t .. ", " or "") .. obj.var_obj end
			if obj.var_spot ~= "" then t = (t and t .. ", " or "") .. obj.var_spot end
			if obj.var_slot_desc ~= "" then t = (t and t .. ", " or "") .. obj.var_slot_desc end
			if obj.var_pos ~= "" then t = (t and t .. ", " or "") .. obj.var_pos end
			return Untranslated(t or "_")
		end,
	},
}

function XPrgSelectSlot:GenCode(prgdata, level)
	self:GenCodeSelectSlot(prgdata, level, self.eval, self.group, self.attach_var, self.bld, self.unit, self.var_spot, self.var_obj, self.var_pos, self.var_slot_desc, self.var_slot, self.var_slotname)
end

-- Visit selected slot
DefineClass.XPrgVisitSelectedSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "obj", name = "Object", editor = "combo", default = "", validate = validate_var, items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "spot", name = "Spot", editor = "combo", default = "", validate = validate_var, items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Slot", id = "slot_desc", name = "Slot desc", editor = "text", default = "", validate = validate_var},
		{ category = "Slot", id = "slot", name = "Slot", editor = "combo", default = "", validate = validate_var, items = function(self) return self:UpdateLocalVarCombo() end  },
		{ category = "Slot", id = "slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
		{ category = "Slot", id = "time", name = "Time", editor = "text", default = "" },
		{ category = "Slot", id = "visits_count", name = "Visits Count", editor = "text", default = "" },
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T(656943101894, "Visit selected <obj> <spot>"),
}

function XPrgVisitSelectedSlot:GenCode(prgdata, level)
	local slot = self.slot ~= "" and self.slot or "nil"
	local slotname = self.slotname ~= "" and self.slotname or "nil"
	local visit_time = self.time == "" and "nil" or self.time
	local visits_count = (self.visits_count == "" or self.visits_count == "1") and "nil" or self.visits_count
	local visit_params = { self.unit, self.bld, self.obj, self.spot, self.slot_desc, slot, slotname, visit_time, visits_count }
	--[[while visit_params[#visit_params] == "nil" do
		visit_params[#visit_params] = nil
	end]]
	local params = prgdata.params
	local prg_params = ""
	-- skip params 1 and 2, because they are self.unit and self.bld
	if params[3] and (params[3].name or "") ~= "" then
		prg_params = {""}
		for i = 3, #params do
			local name = params[i].name
			if (name or "") ~= "" then
				prg_params[i-1] = name
			end
		end
		prg_params = table.concat(prg_params, ", ")
	end
	PrgAddExecLine(prgdata, level, string.format('PrgVisitSlot(%s%s)', table.concat(visit_params, ", "), prg_params))
	PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
end

-- Visit slot
DefineClass.XPrgVisitSlot = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ category = "Slot", id = "unit", name = "Unit", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "bld", name = "Building", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Slot", id = "group", name = "Group", editor = "text", default = "" },
		{ category = "Slot", id = "group_fallback", name = "Alt Group", editor = "text", default = "" },
		{ category = "Slot", id = "time", name = "Time", editor = "text", default = "" },
		{ category = "Slot", id = "visits_count", name = "Visits Count", editor = "text", default = "" },
		{ category = "Slot", id = "attach_var", name = "Attach Var", editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end   },
		{ category = "Eval", id = "eval", name = "Eval", editor = "dropdownlist", default = "Random", items = { "Random", "Nearest" } },
		{ category = "Variables", id = "var_obj", name = "Object", editor = "text", default = "", validate = validate_var },
		{ category = "Variables", id = "var_spot", name = "Spot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slot", name = "Slot", editor = "text", default = "", validate = validate_var},
		{ category = "Variables", id = "var_slotname", name = "Slot Name", editor = "text", default = "", validate = validate_var},
	},
	Menubar = "Slot",
	MenubarSection = "",
	TreeView = T{818935413042, "Visit slot <group><fallback>",
		fallback = function(obj)
			return obj.group_fallback ~= "" and T(142787057654, " (fallback: <group_fallback>)") or ""
		end},
}

function XPrgVisitSlot:GenCode(prgdata, level)
	local slots_var = PrgNewVar("_slots", prgdata.external_vars, prgdata)
	slots_var.value = slots_var.value or {}
	local slots = slots_var.value

	local attach_var = self.attach_var ~= "" and self.attach_var or nil
	local groups = { self.group, self.group_fallback }
	local cur_level = level
	for i = 1, #groups do
		local group = groups[i]
		local group_present
		for j = 1, #slots do
			if slots[j].groups[group] then
				group_present = true
				break
			end
		end
		if group_present then
			local var_obj = self.var_obj ~= "" and self.var_obj or "_obj"
			local var_spot = self.var_spot ~= "" and self.var_spot or "_spot"
			local var_slot = self.var_slot ~= "" and self.var_slot or "_slot"
			local var_slotname = self.var_slotname ~= "" and self.var_slotname or "_slotname"
			local var_slot_desc = "_slot_desc"
			local visit_time = self.time == "" and "nil" or self.time
			local visits_count = (self.visits_count == "" or self.visits_count == "1") and "nil" or self.visits_count
			if cur_level > level then
				PrgAddExecLine(prgdata, cur_level - 1, 'else')
			end
			self:GenCodeSelectSlot(prgdata, cur_level, self.eval, group, attach_var, self.bld, self.unit, var_spot, var_obj, nil, var_slot_desc, var_slot, var_slotname)
			PrgAddExecLine(prgdata, cur_level, string.format('if %s then', var_spot))
			local visit_params = { self.unit, self.bld, var_obj, var_spot, var_slot_desc, var_slot, var_slotname, visit_time, visits_count }
			--[[while visit_params[#visit_params] == "nil" do
				visit_params[#visit_params] = nil
			end]]
			local params = prgdata.params
			local prg_params = ""
			-- skip params 1 and 2, because they are self.unit and self.bld
			if params[3] and (params[3].name or "") ~= "" then
				prg_params = {""}
				for i = 3, #params do
					local name = params[i].name
					if (name or "") ~= "" then
						prg_params[i-1] = name
					end
				end
				prg_params = table.concat(prg_params, ", ")
			end
			PrgAddExecLine(prgdata, cur_level + 1, string.format('PrgVisitSlot(%s%s)', table.concat(visit_params, ", "), prg_params))
			PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
			cur_level = cur_level + 1
		elseif group == "Holder" then
			if cur_level > level then
				PrgAddExecLine(prgdata, cur_level - 1, 'else')
			end
			if self.time ~= "" then
				PrgAddExecLine(prgdata, cur_level, string.format('PrgVisitHolder(%s, %s, %s, %s)', self.unit, self.bld, self.bld, self.time))
			elseif attach_var then
				PrgAddExecLine(prgdata, cur_level, string.format('PrgVisitHolder(%s, %s, %s)', self.unit, self.bld, self.bld))
			else
				PrgAddExecLine(prgdata, cur_level, string.format('PrgVisitHolder(%s, %s)', self.unit, self.bld))
			end
			PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
			break
		elseif group == "Exit" then
			if cur_level > level then
				PrgAddExecLine(prgdata, cur_level - 1, 'else')
			end
			PrgAddExecLine(prgdata, cur_level, string.format('if %s:IsValidPos() then', self.unit))
			PrgAddExecLine(prgdata, cur_level + 1, string.format('PrgLeadToBldPos(%s, %s, %s)', self.unit, self.bld, self.bld))
			PrgAddExecLine(prgdata, 0, "VISIT_RESTART")
			PrgAddExecLine(prgdata, cur_level, 'end')
			break
		end
	end
	for l = cur_level-1, level, -1 do
		PrgAddExecLine(prgdata, l, 'end')
	end
end

-- Attach body part
DefineClass.XPrgAttachBodyPart = {
	__parents = { "XPrgAmbientLifeCommand" },
	properties = {
		{ id = "obj",       name = "Object",    editor = "combo", default = "", items = function(self) return self:UpdateLocalVarCombo() end, },
		{ id = "detach",    name = "Detach",    editor = "bool", default = false, },
		{ id = "reason",    name = "Reason",    editor = "text", default = "", },
		{ id = "classname", name = "Classname", editor = "text", default = "", no_edit = function(obj) return obj.detach end },
	},
	Menubar = "Object",
	MenubarSection = "",
	ActionName = "Attach Body Part",
	TreeView = T{718900601620, "<action> body part <classname> <color 0 128 0><comment>", action = function(obj) return obj.detach and T(229010438406, "Detach") or T(414612643342, "Attach") end, },
}

function XPrgAttachBodyPart:GenCode(prgdata, level)
	if self.classname == "" then return end
	if self.detach then
		PrgAddExecLine(prgdata, level, string.format('%s:RemoveAdditionalBodyPart("%s")', self.obj, self.reason))
	else
		PrgAddExecLine(prgdata, level, string.format('%s:AddAdditionalBodyPart("%s", "%s")', self.obj, self.reason, self.classname))
	end
end