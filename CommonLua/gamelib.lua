exported_files_header_warning = "-- ========== THIS IS AN AUTOMATICALLY GENERATED FILE! ==========\n\n"

function GetClassesWithEntities(...)
	return ClassDescendantsList("CObject", function(name, class, parent1, ...)
		return IsValidEntity(class:GetEntity()) and
			(not parent1 or class:IsKindOfClasses(parent1, ...))
	end, ...)
end

function GetDeprecatedParticleNames()
	return not config.UseDeprecatedParticles and config.DeprecatedParticleNames or empty_table
end 

function GetParticleSystemNames(filter, ui)
	local to_ignore = GetDeprecatedParticleNames()
	local list = {}
	local parsys = GetParticleSystemNameList(ui)
	for i = 1, #parsys do
		local name = parsys[i]
		if not filter or filter(name) then
			for j = 1, #to_ignore do
				if string.find_lower(name, to_ignore[j]) then
					name = false
					break 
				end
			end
			if name then
				list[#list + 1] = name
			end
		end
	end
	table.sort(list)
	return list
end

function ParticlesComboItems()
	local t = GetParticleSystemNames(nil, false) 
	table.insert(t, 1, "") 
	return t
end

function UIParticlesComboItems()
	local t = GetParticleSystemNames(nil, true) 
	table.insert(t, 1, "") 
	return t
end

function GetAllEntitiesCombo()
	return table.keys(GetAllEntities(), true)
end

function GatherMsgItems(msg, obj, def)
	local items = {}
	Msg(msg, items, obj)
	items = table.keys(items, true)
	if def ~= nil then
		table.insert(items, 1, def)
	end
	return items
end

function GatherComboItems(msg, def)
	return function(self)
		return GatherMsgItems(msg, self, def)
	end
end

GetWeightPos = function(objects)
	if not objects or #objects == 0 then
		return point20
	elseif #objects == 1 then
		return objects[1]:GetPos()
	end
	local pos = objects[1]:GetVisualPos()
	for i = 2, #objects do
		pos = pos + objects[i]:GetVisualPos()
	end
	if pos:IsValidZ() then
		return point(pos:x() / #objects, pos:y() / #objects, pos:z() / #objects)
	end
	return point(pos:x() / #objects, pos:y() / #objects)
end

NearestObject = function(pos, objects, max_distance)
	local best, best_distance
	for i = 1, #objects do
		local obj = objects[i]
		local d = obj:GetDist(pos)
		if (not max_distance or d < max_distance) and (not best or d < best_distance) then
			best_distance = d
			best = obj
		end
	end
	return best, best_distance
end

NearestObjectDistFunc = function(pos, objects, fDist, max_distance)
	local best, best_distance
	for i = 1, #objects do
		local obj = objects[i]
		local d = fDist(pos, obj)
		if (not max_distance or d < max_distance) and (not best or d < best_distance) then
			best_distance = d
			best = obj
		end
	end
	return best, best_distance
end

NearestObjectCond = function(pos, objects, f, max_distance)
	local best, best_distance
	for i = 1, #objects do
		local obj = objects[i]
		if f(obj) then
			local d = obj:GetDist(pos)
			if (not max_distance or d < max_distance) and (not best or d < best_distance) then
				best_distance = d
				best = obj
			end
		end
	end
	return best, best_distance
end

local AttachToSpot = function(to, obj, spot_type)
	local idx = -1
	if spot_type then
		idx = to:GetSpotBeginIndex(spot_type)
		if idx == -1 then
			local name = to:GetEntity() ~= "" and to:GetEntity() or to.class
			printf("Missing spot '%s' in '%s' state '%s'",
				type(spot_type) == "number" and string.sub(GetSpotNameByType(spot_type),3) or tostring(spot_type),
				to.class, GetStateName(to:GetState()))
			idx = to:GetSpotBeginIndex("Origin")
		end
	end
	to:Attach(obj, idx)
	return obj
end

AttachToObject = function(to, childclass, spot_type)
	return AttachToSpot(to, PlaceObject(childclass, nil, const.cofComponentAttach), spot_type)
end

AttachPartToObject = function(to, part, spot_type)
	return AttachToSpot(to, PlaceParticles(part, nil, const.cofComponentAttach), spot_type)
end

local AttachToSpotIdx = function(to, obj, spot_idx)
	if spot_idx == -1 then
		local name = to:GetEntity() ~= "" and to:GetEntity() or to.class
		local spot_type = to:GetSpotsType(spot_idx)
		printf("Missing spot '%s' in '%s' state '%s'",
			type(spot_type) == "number" and string.sub(GetSpotNameByType(spot_type),3) or tostring(spot_type),
			to.class, GetStateName(to:GetState()))
		spot_idx = to:GetSpotBeginIndex("Origin")
	end
	to:Attach(obj, spot_idx)
	return obj
end

AttachToObjectSpotIdx = function(to, childclass, spot_idx)
	return AttachToSpotIdx(to, PlaceObject(childclass, nil, const.cofComponentAttach), spot_idx)
end

GetFacingSpots = function(obj, spot_name, zdir, tolerance)
	local t = GetFreeSpotArray(obj, spot_name)
	for i = #t, 1, -1 do
		local spot = t[i]
		local angle, axis = obj:GetSpotVisualRotation(spot)
		local spot_zdir = RotateAxis(axis_x, axis, angle)
		if GetAngle(zdir, spot_zdir) > tolerance then
			table.remove(t, i)
		end
	end
	return t
end

GetFreeSpotArray = function(obj, spot_name)
	local spot_w_attaches = {}
	for i = 1, obj:GetNumAttaches() do
		local a = obj:GetAttach(i)
		spot_w_attaches[a:GetAttachSpot()] = true
	end
	local first, last = obj:GetSpotRange(spot_name)
	local t = {}
	for i = first, last do
		local spot = obj:GetSpotPos(i)
		if spot_w_attaches[spot] then
			t[#t+1] = obj:GetSpotPos(spot)
		end
	end
	if #t <= 1 then
		local i = 1
		while true do
			local spot_name = spot_name .. i
			if not obj:HasSpot(spot_name) then
				break
			end
			local spot = obj:GetSpotBeginIndex(spot_name)
			if spot == -1 then
				break
			end
			if not spot_w_attaches[spot] then
				t[#t+1] = spot
			end
			i = i + 1
		end
	end
	
	return t
end

function CalcColorGradient(value, min, max, colormin, colormax, mid, colormid)
	if value<=min then
		return colormin
	elseif value>=max then
		return colormax
	elseif not mid then
		return InterpolateRGB(colormin,colormax,value-min,max-min)
	elseif value < mid then
		return InterpolateRGB(colormin,colormid,value-min,mid-min)
	else
		return InterpolateRGB(colormid,colormax,value-mid,max-mid)
	end
end

-- animation
if Platform.developer then
	-- debug
	ShowAnimDebug = function(obj, color1, color2)
		if not obj then return end
		
		local text = PlaceObject("Text")
		text:SetDepthTest(true)
		text:SetColor1(color1 or text.color1)
		text:SetColor2(color2 or text.color2)
				
		obj:Attach(text)
		
		CreateRealTimeThread(function()
			while IsValid(text) do
				local infos = {}
				local channel = 1
				while true do
					local info = obj:GetAnimDebug(channel)
					if not info then break end
					infos[ channel ] = string.format("%d. %s\n", channel, info)
					channel = channel + 1
				end
				text:SetText(table.concat(infos))
				WaitNextFrame()
			end
		end)
	end
	
	CycleAnim = function(obj, anim_name)
		if type(anim_name) ~= "string" or string.len(anim_name) < 2 then
			return
		end
		local state = EntityStates[anim_name]
		if not state then
			print("Unknown animation: "..anim_name)
		else
			obj:SetCommand(false)
			obj:SetState(state)
		end
	end

	CycleCurAnim = function(obj)
		local state = obj:GetState()
		obj:SetCommand(false)
		obj:SetState(state)
	end
end

ScreenshotMapName = GetMapName

function ScreenshotFilenameMeta() -- override in project
	return ""
end

function GenerateScreenshotFilename(prefix, folder)
	folder = folder or ""
	if not string.match(folder, "/$") and #folder > 0 then
		folder = folder .. "/"
	end
	local existing_files = io.listfiles(folder, prefix .. "*.png")
	local index = 0
	for i=1,#existing_files do
		index = Max(index, tonumber(string.match(existing_files[i], prefix .. "(%d+)") or 0))
	end
	local filename_meta = ScreenshotFilenameMeta() or ""
	return string.format("%s%s%04d%s.png", folder, prefix, index+1, filename_meta)
end

function GetVisiblePos()
	local pt = GetTerrainGamepadCursor()
	if pt ~= InvalidPos() and terrain.IsPointInBounds(pt) then return pt end
	local pos, look_at
	if cameraRTS.IsActive() then
		pos, look_at = cameraRTS.GetPos(), cameraRTS.GetLookAt()
	elseif camera3p.IsActive() then
		pos, look_at = camera3p.GetEye(), camera3p.GetLookAt()
	elseif cameraMax.IsActive() then
		pos, look_at = cameraMax.GetPosLookAt()
	elseif camera.GetLookAt then
		pos, look_at = camera.GetEye(), camera.GetLookAt()
	else
		return pt
	end
	local v = look_at - pos
	return (pos + SetLen(v, 10 * guim)):SetInvalidZ()
end

function GetClassAndDescendantsEntities(class)
	local processed = {}
	local entities = {}
	ClassDescendantsListInclusive(class, function(name, classdef, processed, entities)
		local entity = classdef:GetEntity()
		if entity and not processed[entity] then
			processed[entity] = true
			if IsValidEntity(entity) then
				entities[#entities + 1] = entity
			end
		end
	end, processed, entities)
	return entities
end

function GetClassDescendantsStates(class, category)
	local entities = GetClassAndDescendantsEntities(class)
	local animations = {}
	local processed = {}
	for i = 1, #entities do
		local entity = entities[i]
		local ent_anims = GetStatesFromCategory(entity, category)
		for j = 1, #ent_anims do
			local anim = ent_anims[j]
			if not processed[anim] then
				processed[anim] = true
				animations[#animations + 1] = anim
			end
		end
	end
	table.sort(animations, CmpLower)
	return animations
end

function StoreErrorSource()
	return ""
end

function StoreWarningSource()
	return ""
end

local esCollision = EntitySurfaces.Collision
local cmPassability = const.cmPassability

function HasCollisions(obj_or_ent)
	return HasAnySurfaces(obj_or_ent, esCollision) or HasMeshWithCollisionMask(obj_or_ent, cmPassability)
end

-- Helper functions for heuristic calculation
function HeuristicEval(v, maxv, deltaPlus, deltaMinus)
	deltaMinus = deltaMinus or deltaPlus
	if maxv > v then
		return (maxv - v) * deltaMinus
	else
		return (v - maxv) * deltaPlus
	end
end

if Platform.developer then
	g_ProfileStats = rawget(_G, "g_ProfileStats") or {}
	g_Sections =  rawget(_G, "g_Sections") or 1
	local statsInterval = 3000
	function __SectionStart(s)
		PerformanceMarker(g_Sections)
		g_Sections = g_Sections + 1
	end

	function __SectionEnd(s)
		g_Sections = g_Sections - 1
		local time = GetPerformanceMarkerElapsedTime(g_Sections)
		local t = g_ProfileStats[s] or {}
		local now = GameTime()
		for gt in pairs(t) do
			if now - gt > statsInterval then
				t[gt] = nil
			end
		end
		t[now] = (t[now] or 0) + time
		g_ProfileStats[s] = t
	end
	
	function __SectionStats(s)	
		local total = 0
		local t = g_ProfileStats[s] or {}
		local now = GameTime()
		local samples = 0
		for gt, time in pairs(t) do
			if now - gt > statsInterval then
				t[gt] = nil
			end
			total = total + time
			samples = samples + 1
		end
		return total, samples
	end
	local thread
	function __PrintStats(s)
		if thread then
			DeleteThread(thread)
		end
		thread = CreateRealTimeThread(function()
			while true do
				local total, samples = __SectionStats(s)
				printf("time: %d / %d", total, samples)
				Sleep(500)
			end
		end)
	end
	
else
	function __SectionStart(s)
	end

	function __SectionEnd(s)
	end
end

function SaveGameState()
end

function LoadGameState()
end

function GetScalingPerc()
	local screen_sz = UIL.GetScreenSize()
	local res16to9 = screen_sz:x() * 10 / screen_sz:y() > 15
	local org_size = res16to9 and point(1280, 720) or point(1024, 768)
	local percX = screen_sz:x() * 100 / org_size:x()
	local percY = screen_sz:y() * 100 / org_size:y()
	return Min(percX, percY)
end

function WaitCaptureScreenshot(filename, options)
	local options = options or {}
	local interface = options.interface or (options.interface == nil and true)
	local width = options.width or UIL.GetScreenSize():x()
	local height = options.height or UIL.GetScreenSize():y()
	local src = options.src or box(point20, UIL.GetScreenSize())
	local quality = options.quality or 100
	local alpha = options.alpha or (options.alpha == nil and false)
	
	local oldInterfaceInScreenshot = hr.InterfaceInScreenshot
	hr.InterfaceInScreenshot = interface and 1 or 0
	
	local done, err = false, false
	if not WriteScreenshot(filename, width, height, src, quality, alpha) then
		err = "could not start writing screenshot"
	end
	local timeout = options.timeout or 3000
	local st = now()
	while not(done or err) do
		done, err = ScreenshotWritten()
		Sleep(5)
		if now() - st > timeout then
			assert(false, "WriteScreenshot timeout!")
			err = "timeout"
			break
		end
	end
	hr.InterfaceInScreenshot = oldInterfaceInScreenshot
	if not err and not io.exists(filename) then
		err = "no file written"
	end
	return err
end

function ChangeGamepadUIStyle(new_style_table)
	local change
	for k, v in pairs(new_style_table) do
		local prev_v = GamepadUIStyle[k]
		if prev_v ~= v then
			GamepadUIStyle[k] = v
			change = true
		end
	end
	if change then
		Msg("GamepadUIStyleChanged")
	end
end

function OnMsg.GamepadUIStyleChanged()
	-- force scale recalc of the desktop so that the additional controller UI scale is taken into account
	if terminal.desktop then
		terminal.desktop:OnSystemSize(UIL.GetScreenSize())
	end
end

function GetUIStyleGamepad(player)
	return GamepadUIStyle[player or 1]
end

function GetSafeAreaBox()
	if Platform.playstation then
		return UIL.GetSafeArea()
	else
		local margin = Max(0, EngineOptions and EngineOptions.DisplayAreaMargin)
		local percent = 100 - margin*2 or 0
		
		local screen_size = UIL.GetScreenSize()
		local screen_w, screen_h = screen_size:xy()
		
		local safe_size = MulDivRound(screen_size, percent, 100)
		local safe_w, safe_h = safe_size:xy()
		local x_margin, y_margin = (screen_w - safe_w)/2, (screen_h - safe_h)/2
		
		return x_margin, y_margin, x_margin + safe_w, y_margin + safe_h
	end
end

--- Converts one single value to an easy to read string.
-- @cstyle string format_value(value).
function format_value(v, levmax, lev)
	lev = lev and (lev + 1) or 1
	if type(v) == "table" then
		if v.class then
			if not IsValid(v) then
				return v.class .. " invalid"
			elseif v:HasMember("handle") then
				return v.class .. " [" .. v.handle .. "]"
			else
				return v.class .. " " .. tostring(v:GetVisualPos())
			end
		end
		if lev and levmax and levmax <= lev then
			return "{...}"
		end
		local tab = "    "
		local indent = string.rep(tab, lev - 1)
		local r = {}
		for a,b in sorted_pairs(v) do
			r[#r + 1] = format_value(a, lev, lev) .. " = " .. format_value(b, levmax, lev)
		end
		return string.format("{\n%s%s%s\n%s}", tab, indent, table.concat(r, ",\n" .. tab .. indent), indent)
	elseif type(v) == "thread" then
		return tostring(v)
	elseif type(v) == "function" then
		local info = debug.getinfo(v)
		if info and info.short_src and info.linedefined then
			return string.format("%s(%d)", info.short_src, info.linedefined)
		end
	end
	return tostring(v)
end

function CutPath(path, dist)
	local total_dist = 0
	local pt = path[1]
	
	for i = 2, #path do
		local seg_len = pt:Dist2D(path[i])
		if total_dist + seg_len > dist then
			local d = dist - total_dist
			local v = SetLen(path[i] - pt, d)
			path[i] = pt + v
			for j = i+1, #path do
				path[j] = nil
			end
			return dist
		end
		total_dist = total_dist + seg_len
		pt = path[i]
	end
	return total_dist
end

function IsValidAnim(obj, anim)
	return obj:HasState(anim) and not obj:IsErrorState(anim)
end

function IsVisible(obj)
	return IsValid(obj) and obj:GetEnumFlags( const.efVisible ) ~= 0
end

function WaitRenderMode(new_mode, call_while_waiting, ...)
	while IsRenderModeChanging() do
		Sleep(1) -- yield
	end
	SetRenderMode(new_mode)
	if call_while_waiting then call_while_waiting(...) end
	while IsRenderModeChanging() and GetRenderMode() ~= new_mode do
		Sleep(1) -- yield
	end
	return GetRenderMode() == new_mode
end

local IsValid = IsValid
function GetTopmostSelectionNode(obj)
	if not IsValid(obj) then return obj end
	while true do
		local parent = obj:GetParent()
		if not parent or not IsValid(parent) then return obj end
		if obj:GetGameFlags(const.gofSelectionHierarchyNode) ~= 0 then return obj end
		obj = parent
	end
end

function ValidateMember(obj, member)
	local value = obj and obj[member]
	if not value then return end
	if not IsValid(value) then
		obj[member] = nil
	end
end

function AreCheatsAvailable()
	return true
end

function GetComboItems(t, text, value)
	local r = {}
	if text then
		for i = 1, #t do
			r[#r+1] = { text = t[i][text], value = t[i][value], }
		end
	else
		for k, v in pairs(t) do
			r[#r+1] = { text = v, value = k }
		end
	end
	
	return r
end

function ValidateZ( pt, terrain_offset )
	if IsValid(pt) then
		pt = pt:GetPos()
	end
	return pt:z() and pt or pt:SetZ( terrain.GetHeight( pt ) + (terrain_offset or 0) )
end

function ResolveZ(x, y, z)
	x, y, z = ResolveVisualPosXYZ(x, y, z)
	return z
end

-- prints the delay of a specific player input which originated at action_time (in PreciseTicks)
-- and whose consequences have happened in game_time (optional)
-- the delay is calculated in PreciseTicks between the time the action originated and its effect is shown on-screen
-- the time reported could be more than the actual delay if the lua code could not wakeup within a frame
function PrintDelayToScreen(action_time, message, game_time)
	game_time = game_time or GameTime()
	local rt = GetPreciseTicks(1000)
	CreateRealTimeThread(function()
		while hr.GameTimePresented - game_time < 0 do
			WaitMsg("OnRender")
		end
		printf("Action %s (display %dms) (delay %dms)", message, hr.PreciseTicksPresented - rt, hr.PreciseTicksPresented - action_time)
	end)
end

local use_console_out = Platform.developer or Platform.cmdline
printl = CreatePrint{"", output = use_console_out and ConsolePrint or DebugPrint, append_new_line = not use_console_out }
printfl = CreatePrint{"", output = use_console_out and ConsolePrint or DebugPrint, append_new_line = not use_console_out, format = string.format }

--[[ PrintDelayToScreen sample code
CreateRealTimeThread(function()
	local mouse_down_time
	local mouse_input_delay
	local draw_box_until
	
	local oldMouseEvent = Desktop.MouseEvent
	function Desktop:MouseEvent(event, pt, button, time)
		if event == "OnMouseButtonDown" and button = "L" then
			mouse_down_time = time
			mouse_input_delay = GetPreciseTicks(1000) - time
			self:Invalidate()
		end
		return oldMouseEvent(self, event, pt, button, time)
	end

	function Desktop:DrawAfterChildren()
		if mouse_down_time then
			PrintDelayToScreen(mouse_down_time, string.format("Mouse click white box (input delay %d)", mouse_input_delay))
			mouse_down_time = nil
			draw_box_until = RealTime() + 200
			--self:Invalidate()
		end
		if draw_box_until then
			if draw_box_until - RealTime() > 0 then
				UIL.DrawSolidRect(box(0, 0, 120, 120), RGB(255,255,255))
			else
				draw_box_until = nil
			end
		end
	end
end)
--]]

function CanApplicationQuit()
	local result = {can_quit = true}
	Msg("CanApplicationQuit", result)
	return GetIgnoreDebugErrors() or result.can_quit
end

function ToCombo(tbl, first)
	return function(...)
		tbl = type(tbl) ~= "string" and tbl or _G[tbl]
		tbl = type(tbl) == "function" and tbl(...) or tbl
		local items = #tbl == 0 and table.keys(tbl) or table.icopy(tbl)
		table.sort(items)
		if first == nil then first = "" end
		table.insert(items, 1, first)
		return items
	end
end

---

function PlaceAtCursor(class)
	local obj = PlaceObject(class)
	obj:SetPos(GetTerrainCursor())
	return obj
end

if Platform.developer then

function PrintWrongSpotAttaches(obj)
	local entity = obj:GetEntity()
	local count = obj:GetNumAttaches()
	for i = 1, count do
		local attach = obj:GetAttach(i)
		local spot = attach:GetAttachSpot()
		local spot_name = obj:GetSpotName(spot)
		local spot_begin, spot_end = obj:GetSpotRange(obj:GetState(), spot_name)
		if spot < spot_begin or spot > spot_end then
			print(string.format("Entity: %s:%s, Class:[%s:%s] attach out of range for spot %s: %d[%d, %d]", entity, attach:GetEntity(), obj.class, attach.class, spot_name, spot, spot_begin, spot_end))
		end
	end
end

end

function SetClipPlaneByProgress(object, progress)
	if progress == 100 then
		object:SetClipPlane(0)
		return
	end
	
	local total_box = object:GetObjectBBox()
	local function recursive_extend_box(obj)
		if obj:GetEntity() and obj:GetEntity() ~= "" then
			total_box = obj:GetObjectBBox(total_box)
		end
		for key, value in ipairs(obj:GetAttaches() or empty_table) do
			recursive_extend_box(value)
		end
	end
	recursive_extend_box(object)
	
	total_box = box(total_box:min():SetZ(object:GetVisualPos():z()), total_box:max())
	
	local z = total_box:minz() + MulDivRound(total_box:sizez(), progress, 100)
	local p1 = point(total_box:minx(), total_box:miny(), z)
	local p2 = point(total_box:minx(), total_box:maxy(), z)
	local p3 = point(total_box:maxx(), total_box:miny(), z)
	object:SetClipPlane(PlaneFromPoints(p1, p2, p3))
end

----

-- Similar to ValueToLuaCode, but representing the objects by class and handle only. Useful for prints.

function ObjToStr(value)
	local class = type(value) == "table" and value.class
	if not class then return "" end
	local handle = rawget(value, "handle")
	local handle_str = handle and string.format(" [%d]", handle) or ""
	local id = rawget(value, "id")
	local id_str = id and string.format(" \"%s\"", id) or ""
	local pos = IsValid(value) and value:GetPos()
	local pos_str = pos and string.format(" at %s", tostring(pos)) or ""
	return string.format("%s%s%s%s", class, id_str, handle_str, pos_str)
end

function ValueToStr(value, indent, visited)
	local vtype = type(value)
	if vtype == "function" then
		return GetGlobalName(value) or tostring(value)
	end
	if IsT(value) then
		return TTranslate(value)
	end
	if vtype ~= "table" then
		return ValueToLuaCode(value)
	end
	if value == _G then
		return "_G"
	end
	local class = value.class
	if class then
		return ObjToStr(value)
	end
	if next(value) == nil then
		return "{}"
	end
	local name = GetGlobalName(value)
	if name then
		return name
	end
	visited = visited or {}
	if visited == true or visited[value] then
		return "{...}"
	end
	visited[value] = true
	local n
	for k, v in pairs(value) do
		if type(k) ~= "number" or k < 1 then
			n = false
			break
		end
		n = Max(n or 0, k)
	end
	if n then
		for i=1,n do
			if value[i] == nil then
				n = false
				break
			end
		end
	end
	if n then
		assert(n > 0)
		local values = {"{ "}
		for i=1,n-1 do
			values[#values + 1] = ValueToStr(value[i], indent, visited)
			values[#values + 1] = ", "
		end
		values[#values + 1] = ValueToStr(value[n], indent, visited)
		values[#values + 1] = " }"
		return table.concat(values)
	end
	indent = indent or ""
	local indent2 = indent .. "\t"
	local lines = {}
	for k, v in pairs(value) do
		if type(k) == "string" and IsIdentifierName(k) then
			lines[#lines + 1] = string.format("%s%s = %s,", indent2, k, ValueToStr(v, indent2, visited))
		else
			lines[#lines + 1] = string.format("%s[%s] = %s,", indent2, ValueToStr(k, indent2, visited), ValueToStr(v, indent2, visited))
		end
	end
	table.sort(lines)
	table.insert(lines, 1, "{")
	lines[#lines + 1] = indent .. "}"
	return table.concat(lines, "\n")
end

function GetObjRefCode(obj)
	if obj and obj.handle then
		return string.format("HandleToObject[%d]", obj.handle)
	elseif obj and IsValidPos(obj) then
		local pos, class = obj:GetPos(), obj.class
		local objs = MapGet(pos, 0, class)
		local idx = table.find(objs, obj)
		if idx then
			return string.format("MapGet(point%s, 0, '%s')[%d]", tostring(pos), class, idx)
		end
	end
end

----

function GetRandomItemByWeight(classes, slot, prop_id)
	local lo, hi = 1, #classes
	while lo <= hi do
		local mid = (lo + hi) / 2
		local check = prop_id and classes[mid][prop_id] or classes[mid]
		if slot < check then
			hi = mid - 1
		elseif slot > check then
			lo = mid + 1
		else
			return mid
		end
	end
	
	return lo
end

----

local default_repetitions = { 1, -1, -2, -3, -4, -6, -8, -10 }
function ListChances(items, weights, total_weight, additional_text, repetitions)
	if type(weights) == "string" or type(weights) == "function" then
		weights = table.map(items, weights)
	end
	if not total_weight then
		total_weight = 0
		for i in ipairs(items) do
			local weight = weights and weights[i] or 100
			total_weight = total_weight + weight
		end
	end
	if total_weight == 0 then return end
	repetitions = repetitions or default_repetitions
	local tab_width = 40
	local text = pstr(additional_text or "", 4096)
	text:append(additional_text and "\n" or "", "Chances for repetitions in %\n")
	for n, rep in ipairs(repetitions) do
		if rep < 0 then
			text:append("'-X' is the chance of something not happening X times\n")
			break
		end
	end
	for n, rep in ipairs(repetitions) do
		text:appendf("<tab %d right>%d", n * tab_width, rep)
	end
	text:appendf("<tab %d>  Event\n", #repetitions * tab_width)
	for i, item in ipairs(items) do
		local chance = (weights and weights[i] or 100) * 1.0 / total_weight
		for n, rep in ipairs(repetitions) do
			local percent = rep > 0 and (chance ^ rep) or (1 - chance) ^ -rep
			text:appendf("<tab %d right>%d%%", n * tab_width, 100.0 * percent + 0.5)
		end
		if type(item) == "table" then
			if item.EditorView then
				item = _InternalTranslate(item.EditorView, item, false)
			else
				item = item.id or item.item or item.value
			end
		end
		if IsT(item) then item = _InternalTranslate(item, nil, false) end
		text:appendf("<tab %d>  %s\n", #repetitions * tab_width, tostring(item))
	end
	return tostring(text)
end

-----

if FirstLoad then
	GameSpeedLock_OrigSpeed = false
	GameSpeedLock_ForcedSpeed = false
end

function ToggleLockGameSpeedNoUserInteraction(speed)
	assert(not netInGame)
	table.restore(_G, "LockGameSpeedNoUserInteraction", true)
	table.restore(config, "LockGameSpeedNoUserInteraction", true)
	if GameSpeedLock_ForcedSpeed then
		SetTimeFactor(GameSpeedLock_OrigSpeed)
		GameSpeedLock_ForcedSpeed = false
		GameSpeedLock_OrigSpeed = false
		print("Game Speed Unlocked")
	else
		speed = speed or GetTimeFactor()
		GameSpeedLock_ForcedSpeed = speed
		GameSpeedLock_OrigSpeed = GameSpeedLock_OrigSpeed or GetTimeFactor()
		for reason in pairs(PauseReasons) do
			Resume(reason)
		end
		ResumeGame(GetGamePause())
		__SetTimeFactor(speed)
		table.change(_G, "LockGameSpeedNoUserInteraction", {
			Pause = empty_func,
			PauseGame = empty_func,
			__SetTimeFactor = empty_func,
			GetTimeFactor = function() return GameSpeedLock_ForcedSpeed end,
		})
		table.change(config, "LockGameSpeedNoUserInteraction", {
			NoUserInteraction = true,
			LuaErrorMessage = false,
			AssertMessage = false,
		})
		print("Game Speed Locked to Factor", speed)
	end
	UpdateGameSpeed()
end

function UpdateGameSpeed()
end

----

function AreCheatsEnabled()
	return Platform.cheats or AreModdingToolsActive()
end

----

if FirstLoad then
	DbgLastIdx = 0
end

function DbgNextColor(idx)
	idx = idx or (DbgLastIdx + 1)
	DbgLastIdx = idx
	local colors = const.ColorList
	return colors and #colors > 0 and colors[1 + (idx - 1) % #colors] or RandColor(idx)
end

function OnMsg.DbgClear()
	DbgLastIdx = 0
end

----

if FirstLoad then
	SpecialLuaErrorHandlingReasons = {}
end

function SetSpecialLuaErrorHandling(reason, enable)
	SpecialLuaErrorHandlingReasons[reason or false] = enable and true or nil
	config.SpecialLuaErrorHandling = not not next(SpecialLuaErrorHandlingReasons)
end

SetSpecialLuaErrorHandling("Pause", config.PauseGameOnLuaError)

if FirstLoad then
	LastErrorGameTime = false -- not a map var in order to persist it when loading an earlier save
end

function DbgOnLuaError(err)
	LastErrorGameTime = GameTime()
	if config.PauseGameOnLuaError and SetGameSpeed and Pause then
		if config.PauseGameOnLuaError == "stop" then
			SetGameSpeed("pause")
		else
			Pause("UI")
		end
		print("[PauseGameOnLuaError] GameTime:", GameTime(), "RealPause:", GetGamePause(), "TimeFactor:", GetTimeFactor())
	end
end

OnMsg.OnLuaError = DbgOnLuaError

----

ReportZeroAnimDuration = empty_func

if Platform.asserts then

function ReportZeroAnimDuration(obj, anim, dt)
	dt = dt or obj:GetAnimDuration(anim)
	if dt ~= 0 then return end
	if type(anim) == "number" then anim = GetStateName(anim) end
	if not obj:HasState(anim) then
		GameTestsErrorf("once", "Missing anim %s.%s", obj:GetEntity(), anim)
	else
		GameTestsErrorf("once", "Zero length anim %s.%s", obj:GetEntity(), anim)
	end
end

end

----

-- merges axis-aligned bounding boxes from the list to create a shorter, less accurate list
-- 'accuracy' is the largest allowed distance from a input bounding box that can be present in the output list
-- 'optimize_boxes' makes a second pass to shrink the resulting boxes as much as possible
function CompactAABBList(box_list, accuracy, optimize_boxes)
	local slot_size = accuracy / 2
	local map_box = box(0, 0, terrain.GetMapSize())
	local grid_size = point(terrain.GetMapSize()) / slot_size + point(1, 1)
	PauseInfiniteLoopDetection("CompactAABBList")
	
	-- rasterize all boxes into a grid
	local grid = NewComputeGrid(grid_size:x(), grid_size:y(), "u", 8)
	for _, bx in ipairs(box_list) do
		bx = IntersectRects(bx, map_box)
		GridDrawBox(grid, bx:Align(slot_size) / slot_size, 1)
	end
	
	-- build an "extended" grid, 1 tile in each direction
	local ext_grid = NewComputeGrid(grid_size:x(), grid_size:y(), "u", 8)
	for y = 0, grid_size:y() do
		for x = 0, grid_size:x() do
			if grid:get(x, y) + grid:get(x - 1, y) + grid:get(x + 1, y) + grid:get(x, y - 1) + grid:get(x, y + 1) > 0 then
				ext_grid:set(x, y, 1)
			end
		end
	end
	
	-- build rectangles in 'ext_grid' in a greedy manner:
	--  * after finding the top of the rectangle, shrink it from left & right, omitting tiles not in 'grid'
	--  * as a last step, try expanding the entire rectangle left & right, if this would cover more tiles from 'grid'
	-- mark the rectangle with 0 in 'grid' to mark them are "covered"
	local ret = {}
	for y = 0, grid_size:y() do
		for x = 0, grid_size:x() do
			-- start building a new rectangle if we encounter a full tile
			if ext_grid:get(x, y) == 1 then
				-- extend to the right
				local x1, x2 = x, x + 1
				while x2 < grid_size:x() and ext_grid:get(x2, y) == 1 do
					x2 = x2 + 1
				end
				
				-- delete tiles not present in 'grid' from the right
				while x2 > x1 and grid:get(x2 - 1, y) == 0 do
					x2 = x2 - 1
				end
				
				-- delete tiles not present in 'grid' from the left
				while x1 < x2 and grid:get(x1, y) == 0 do
					x1 = x1 + 1
				end
				
				if x2 > x1 then
					-- extend downwards
					local bx = box(x1, y + 1, x2, y + 2)
					while bx:maxy() <= grid_size:y() and GridBoxEquals(ext_grid, bx, 1) do
						bx = Offset(bx, 0, 1)
					end
					bx = Offset(bx, 0, -1)
					bx:InplaceExtend(x1, y)
					
					-- try extending once left
					if GridBoxEquals(ext_grid, Extend(bx, x1 - 1, y), 1) then
						bx:InplaceExtend(x1 - 1, y)
					end
					
					-- try extending once right
					if GridBoxEquals(ext_grid, Extend(bx, x2 + 1, y), 1) then
						bx:InplaceExtend(x2 + 1, y)
					end
					
					-- mark as "covered" and add it to the output
					-- NOTE: marking in 'grid' produces 10% less boxes (by allowing box overlap), but has 2x worse performance
					GridDrawBox(ext_grid, bx, 0)
					table.insert(ret, bx * slot_size)
				end
			end
		end
	end
	
	if optimize_boxes then
		-- shrink the output rectangles to the original bounding boxes edges where possible
		-- (using a locality-access structure for good performance)
		local slot_size = slot_size * 2
		local slot_to_boxes = {}
		for _, orig_bx in ipairs(box_list) do
			local bx = IntersectRects(orig_bx, map_box):Align(slot_size) / slot_size
			for x = bx:minx(), bx:maxx() - 1 do
				for y = bx:miny(), bx:maxy() - 1 do
					local key = point_pack(x, y)
					local slot = slot_to_boxes[key] or {}
					table.insert(slot, orig_bx)
					slot_to_boxes[key] = slot
				end
			end
		end
		for idx, orig_bx in ipairs(ret) do
			local final_bx = box()
			local bx = IntersectRects(orig_bx, map_box):Align(slot_size) / slot_size
			for x = bx:minx(), bx:maxx() - 1 do
				for y = bx:miny(), bx:maxy() - 1 do
					for _, input_bx in ipairs(slot_to_boxes[point_pack(x, y)]) do
						final_bx:InplaceExtend(IntersectRects(orig_bx, input_bx))
					end
				end
			end
			ret[idx] = final_bx
		end
	end
	
	ResumeInfiniteLoopDetection("CompactAABBList")
	grid:free()
	ext_grid:free()
	return ret
end
