-- make objects that obstruct the view transparent (camera3p)
if FirstLoad then
	g_CameraMakeTransparentEnabled = false
	g_updateStepOpacityThread = false
	g_CameraMakeTransparentThread = false
	g_CMT_fade_out = false
	g_CMT_fade_in = false
	g_CMT_hidden = false
	g_CMT_replaced = false
	g_CMT_replaced_destroy = false
end

local CMT_fade_out = g_CMT_fade_out
local CMT_fade_in = g_CMT_fade_in
local CMT_hidden = g_CMT_hidden
local CMT_replaced = g_CMT_replaced
local CMT_replaced_destroy = g_CMT_replaced_destroy

local transparency_enum_flags = const.efCameraMakeTransparent
local transparency_surf_flags = EntitySurfaces.Walk + EntitySurfaces.Collision
local obstruct_view_refresh_time = const.ObstructViewRefreshTime
local fade_in_time = const.ObstructOpacityFadeInTime
local fade_out_time = const.ObstructOpacityFadeOutTime
local obstruct_opacity = const.ObstructOpacity
local obstruct_opacity_refresh_time = const.ObstructOpacityRefreshTime
local refresh_time = Max(obstruct_opacity_refresh_time, Max(fade_out_time, fade_in_time) / (100 - Clamp(obstruct_opacity, 0, 99)))
local opacity_change_fadein  = fade_in_time <= 0 and 100 or (100 - obstruct_opacity) * refresh_time / fade_in_time
local opacity_change_fadeout = fade_out_time <= 0 and 100 or (100 - obstruct_opacity) * refresh_time / fade_out_time

local function ResetLists()
	g_CMT_fade_out = {}
	g_CMT_fade_in = {}
	g_CMT_hidden = {}
	g_CMT_replaced = {}
	g_CMT_replaced_destroy = {}
	CMT_fade_out = g_CMT_fade_out
	CMT_fade_in = g_CMT_fade_in
	CMT_hidden = g_CMT_hidden
	CMT_replaced = g_CMT_replaced
	CMT_replaced_destroy = g_CMT_replaced_destroy
end

if FirstLoad then
	ResetLists()
end

function OnMsg.DoneMap()
	g_updateStepOpacityThread = false
	g_CameraMakeTransparentThread = false
	ResetLists()
end

local function UpdateObstructors_StepOpacity(obstructors)
	local view = 1
	CMT_fade_in[view] = CMT_fade_in[view] or {}
	CMT_fade_out[view] = CMT_fade_out[view] or {}
	local vfade_in = CMT_fade_in[view]
	local vfade_out = CMT_fade_out[view]
	-- move fade_out objects to fade_in
	for i = #vfade_out, 1, -1 do
		local o = vfade_out[i]
		if not (obstructors and obstructors[o]) then
			assert(not vfade_in[o])
			table.remove(vfade_out, i)
			vfade_out[o] = nil
			if o:GetOpacity() < 100 then
				vfade_in[#vfade_in + 1] = o
				vfade_in[o] = true
			end
		end
	end
	-- set the new fade_out
	if obstructors then
		for i = 1, #obstructors do
			local o = obstructors[i]
			if not vfade_out[o] then
				vfade_out[#vfade_out + 1] = o
				vfade_out[o] = true
			end
			if vfade_in[o] then
				table.remove_entry(vfade_in, o)
				vfade_in[o] = nil
			end
		end
	end
end

local function UpdateObstructors_Hidden(view, obstructors)
	-- logic for objects for which hide/show is immediate
	local hidden_for_view = CMT_hidden[view]
	CMT_hidden[view] = obstructors
	if obstructors then
		for i = 1, #obstructors do
			local o = obstructors[i]
			o:SetOpacity(0)
			obstructors[o] = true
		end
	end
	if hidden_for_view then
		for i = 1, #hidden_for_view do
			local o = hidden_for_view[i]
			if IsValid(o) and not (obstructors and obstructors[o]) then
				o:SetOpacity(100) -- show what was hidden in the previous tick 
			end
		end
	end
end

local function ClearObstructors()
	for o in pairs(CMT_replaced) do
		o:DestroyReplacement()
	end
	for view = 1, camera.GetViewCount() do
		local vfade_out = CMT_fade_out[view]
		if vfade_out then
			for i = 1, #vfade_out do
				local o = vfade_out[i]
				if IsValid(o) then
					o:SetOpacity(100)
				end
			end
		end
		local vfade_in = CMT_fade_in[view]
		if vfade_in then
			for i = 1, #vfade_in do
				local o = vfade_in[i]
				if IsValid(o) then
					o:SetOpacity(100)
				end
			end
		end
		local hv = CMT_hidden[view]
		if hv then
			for i = 1, #hv do
				local o = hv[i]
				if IsValid(o) then
					o:SetOpacity(100)
				end
			end
		end
	end
	ResetLists()
end

local function UpdateObstructors(view, get_obstructors)
	local success, obstructors, obstructors_immediate = procall(get_obstructors, view)
	UpdateObstructors_StepOpacity(obstructors)
	UpdateObstructors_Hidden(view, obstructors_immediate)
end

local function UpdateObstructorsRefresh(cam, get_obstructors)
	local refresh_time = obstruct_view_refresh_time
	while true do
		while IsEditorActive() do
			Sleep(2 * refresh_time)
		end
		-- restore opacity of fade_in/fade_out objects
		if not g_CameraMakeTransparentEnabled or not cam.IsActive() then
			ClearObstructors()
			while not g_CameraMakeTransparentEnabled or not cam.IsActive() do
				Sleep(refresh_time)
			end
		end
		for view = 1, camera.GetViewCount() do
			UpdateObstructors(view, get_obstructors)
		end
		Sleep(refresh_time)
	end
end

local function UpdateStepOpacity(view)
	local vfade_out = CMT_fade_out[view]
	if vfade_out then
		for i = #vfade_out, 1, -1 do
			local o = vfade_out[i]
			if not IsValid(o) then
				vfade_out[o] = nil
				table.remove(vfade_out, i)
			else
				local new_opacity = o:GetOpacity() - opacity_change_fadeout
				if new_opacity < obstruct_opacity then
					new_opacity = obstruct_opacity
				end
				o:SetOpacity(new_opacity)
			end
		end
	end
	local vfade_in = CMT_fade_in[view]
	if vfade_in then
		for i = #vfade_in, 1, -1 do
			local o = vfade_in[i]
			local keep
			if IsValid(o) then
				local new_opacity = Min(100, o:GetOpacity() + opacity_change_fadein)
				o:SetOpacity(new_opacity)
				keep = new_opacity < 100
			end
			if not keep then
				vfade_in[o] = nil
				table.remove(vfade_in, i)
			end
		end
	end
end

local function UpdateStepOpacityRefresh()
	local refresh_time = refresh_time
	while true do
		for view = 1, camera.GetViewCount() do
			UpdateStepOpacity(view)
		end
		Sleep(refresh_time)
	end
end

local DistSegmentToPt = DistSegmentToPt
local camera_clip_extend_radius = const.CameraClipExtendRadius
local offset_z_150cm = 150*guic
local cone_radius_max = config.CameraTransparencyConeRadiusMax
local cone_radius_min = config.CameraTransparencyConeRadiusMin
if FirstLoad then
	draw_transparency_cone = false
end

function ToggleTransparencyCone()
	DbgClearVectors()
	draw_transparency_cone = not draw_transparency_cone
end

local hide_filter = function(u, eye)
	local posx, posy, posz = u:GetVisualPosXYZ()
	local scale = u:GetScale()
	local dist_to_eye = DistSegmentToPt(posx, posy, posz, 0, 0, u.height * scale / 100, eye, true)
	return dist_to_eye < u.camera_radius * scale / 100 + camera_clip_extend_radius
end
local col_exec = function(o, list)
	if not list[o] then
		list[#list + 1] = o
		list[o] = true
	end
end
local function GetViewObstructorsCamera3p(view)
	local eye = camera.GetEye(view)
	local lookat = camera3p.GetLookAt(view)
	if not eye or not eye:IsValid() then
		return
	end
	local to_fade, to_fade_count
	local to_hide = MapGet(eye, 4*guim, "Unit", hide_filter, eye) or {}
	for i = 1, #to_hide do
		to_hide[ to_hide[i] ] = true
	end

	for loc_player = 1, LocalPlayersCount do
		local obj = GetPlayerControlCameraAttachedObj(loc_player)
		if obj and obj:IsValidPos() then
			local posx, posy, posz = obj:GetVisualPosXYZ()
			local err1, to_fade1 = AsyncIntersectConeWithObstacles(
				eye, point(posx, posy, posz + offset_z_150cm),
				cone_radius_max, cone_radius_min,
				transparency_enum_flags,
				transparency_surf_flags,
				draw_transparency_cone)
			assert(not err1, err1)
			if to_fade1 then
				if to_fade then
					for i = 1, #to_fade1 do
						local o = to_fade1[i]
						if not to_fade[o] then
							to_fade_count = to_fade_count + 1
							to_fade[to_fade_count] = o
							to_fade[o] = true
						end
					end
				else
					to_fade = to_fade1
					to_fade_count = #to_fade
					for i = 1, to_fade_count do
						to_fade[ to_fade[i] ] = true
					end
				end
			end
		end
	end
	if to_fade then
		for i = 1, to_fade_count do
			local col = to_fade[i]:GetRootCollection()
			if col and not to_fade[col] then
				to_fade[col] = true
				local col_areapoint1 = eye
				local col_areapoint2 = lookat
				MapForEach(
					col_areapoint1, col_areapoint2, 50*guim,
					"attached", false, "collection", col.Index, true, 
					const.efVisible, col_exec , to_fade)
			end
		end
	end
	return to_fade, to_hide
end

function RestartCameraMakeTransparent()
	StopCameraMakeTransparent()
	if g_CameraMakeTransparentEnabled then
		g_CameraMakeTransparentThread = CreateMapRealTimeThread(UpdateObstructorsRefresh, camera3p, GetViewObstructorsCamera3p)
		g_updateStepOpacityThread = CreateMapRealTimeThread(UpdateStepOpacityRefresh)
	end
end

function StopCameraMakeTransparent()
	ClearObstructors()
	if g_updateStepOpacityThread then
		DeleteThread(g_updateStepOpacityThread)
		g_updateStepOpacityThread = false
	end
	if g_CameraMakeTransparentThread then
		DeleteThread(g_CameraMakeTransparentThread)
		g_CameraMakeTransparentThread = false
	end
end

OnMsg.NewMapLoaded = RestartCameraMakeTransparent
OnMsg.LoadGame = RestartCameraMakeTransparent
OnMsg.GameEnterEditor = StopCameraMakeTransparent

DefineClass.CameraTransparentWallReplacement = {
	__parents = { "CObject", "ComponentAttach" },
	flags = { efCameraMakeTransparent = false, efCameraRepulse = true, efSelectable = false, efWalkable = false, efCollision = false, efApplyToGrids = false, efShadow = false },
	properties =
	{
		{ id = "CastShadow", name = "Shadow from All", editor = "bool", default = false },
	},
}

local function CameraSpecialWallReplaceObjects(o)
	return { "(default)", "place_default", "" }
end

DefineClass.CameraSpecialWall = {
	__parents = { "Object" },
	flags = { efCameraMakeTransparent = true, efCameraRepulse = false },
	properties = {
		{ id = "TransparentReplace", editor = "combo", items = CameraSpecialWallReplaceObjects },
	},
	TransparentReplace = "(default)",
	replace_default = "",
	replace_height_min = -guim,
	replace_height_max = guim,
}

function OnMsg.ClassesPostprocess()
	-- create unique GetAction and GetActionEnd functions per class
	local replace_default = {}
	ClassDescendants("CameraSpecialWall", function(class_name, class, replace_default)
		if class.replace_default == "" then
			local classname = class:GetEntity() .. "_Base"
			if g_Classes[classname] then
				replace_default[class] = classname
			end
		end
		local properties = class.properties
		local idx = table.find(properties, "id", "OnCollisionWithCamera")
		if idx then
			local idx_old = table.find(properties, "id", "TransparentReplace")
			local prop = properties[idx_old]
			table.remove(properties, idx_old)
			table.insert(properties, idx + (idx < idx_old and 1 or 0), prop)
		end
	end, replace_default)
	for class, value in pairs(replace_default) do
		class.replace_default = value
	end
end

local default_color = RGBA(128, 128, 128, 0)
local default_roughness = 0
local default_metallic = 0

function CameraSpecialWall:PlaceReplacement()
	local replacement = CMT_replaced[self]
	if replacement then
		CMT_replaced_destroy[self] = nil
		return
	end
	local classname = self.TransparentReplace
	if classname == "place_default" then
		classname = self.replace_default
	elseif classname == "(default)" then
		classname = self.replace_default
		local pos = self:GetPos()
		local height = pos:z() and pos:z() - GetWalkableZ(pos) or 0
		if height < self.replace_height_min or height > self.replace_height_max then
			classname = ""
		elseif self:RotateAxis(0,0,4096):z() < 2048 then
			-- inclined more then 45 degrees
			classname = ""
		end
	end
	local replaced_base
	if classname ~= "" then
		local color1, roughness1, metallic1 = self:GetColorizationMaterial(1)
		local color2, roughness2, metallic2 = self:GetColorizationMaterial(2)
		local color3, roughness3, metallic3 = self:GetColorizationMaterial(3)
		local components = 0
		if (color1 ~= default_color or roughness1 ~= default_roughness or metallic1 ~= default_metallic) or 
			(color2 ~= default_color or roughness2 ~= default_roughness or metallic2 ~= default_metallic) or 
			(color3 ~= default_color or roughness3 ~= default_roughness or metallic3 ~= default_metallic) then
			components = const.cofComponentColorizationMaterial
		end
		replaced_base = PlaceObject(classname, nil, components)
		replaced_base:SetMirrored(self:GetMirrored())
		replaced_base:SetAxis(self:GetAxis())
		replaced_base:SetAngle(self:GetAngle())
		replaced_base:SetScale(self:GetScale())
		replaced_base:SetColorModifier(self:GetColorModifier())
		if components == const.cofComponentColorizationMaterial then
			replaced_base:SetColorizationMaterial(1, color1, roughness1, metallic1)
			replaced_base:SetColorizationMaterial(2, color2, roughness2, metallic2)
			replaced_base:SetColorizationMaterial(3, color3, roughness3, metallic3)
		end
		local anim = self:GetStateText()
		if anim ~= "idle" and replaced_base:HasState(anim) and not replaced_base:IsErrorState(anim) then
			replaced_base:SetState(anim)
		end
		replaced_base:SetPos(self:GetVisualPosXYZ())
	end
	CMT_replaced[self] = replaced_base or true
end

function CameraSpecialWall:DestroyReplacement(delay)
	local obj = CMT_replaced[self]
	if obj then
		if obj == true then
			CMT_replaced[self] = nil
			return
		end
		if (delay or 0) == 0 then
			CMT_replaced[self] = nil
			CMT_replaced_destroy[self] = nil
			DoneObject(obj)
		elseif not CMT_replaced_destroy[self] then
			CMT_replaced_destroy[self] = RealTime() + delay
		end
	end
end

function CameraSpecialWall:SetOpacity(opacity)
	if opacity < 100 then
		self:PlaceReplacement()
	else
		self:DestroyReplacement()
	end
	Object.SetOpacity(self, opacity)
end
