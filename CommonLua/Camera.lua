function CameraShake_GetEffectPower(pos, radius_insight, radius_outofsight)
	local cam_pos, cam_look = GetCamera()
	local camera_orientation = CalcOrientation(cam_pos, cam_look)
	local shake_orientation = CalcOrientation(cam_pos, pos)
	local dist = DistSegmentToPt(cam_pos, cam_look, pos)
	if dist < 0 then
		assert(false)
		return 0
	end
	
	local radius
	if abs(AngleDiff(shake_orientation, camera_orientation)) < const.CameraShakeFOV/2 then
		radius = radius_insight or const.ShakeRadiusInSight
	else
		radius = radius_outofsight or const.ShakeRadiusOutOfSight
	end
	return dist < radius and 100 * (radius - dist) / radius or 0
end

--- Starts a camera shake effect with the specified position and power.
-- @cstyle void CameraShake(point pos, int power).
-- @param pos point.
-- @param power int.
-- @return void.
function CameraShake(pos, power)
	power = power * CameraShake_GetEffectPower(pos) / 100
	if power == 0 then return end
	local total_duration = const.MinShakeDuration + power*(const.MaxShakeDuration-const.MinShakeDuration)/const.MaxShakePower
	local shake_offset = power*const.MaxShakeOffset/const.MaxShakePower
	local shake_roll = power*const.MaxShakeRoll/const.MaxShakePower
	camera.Shake(total_duration, const.ShakeTick, shake_offset, shake_roll)
end

MapVar("camera_shake_thread", false)
MapVar("camera_shake_max_offset", 0)

local function DoShakeCamera(total_duration, shake_tick, max_offset, max_roll_offset)
	local time_left = total_duration
	while true do
		local LookAtOffset = RandPoint(1500, 500, 500)
		local EyePtOffset = RandPoint(1500, 500, 500)
		local len = Max(1, 2 * time_left * max_offset / total_duration)
		local angle = 60 * time_left * max_roll_offset / total_duration
		if LookAtOffset:Len2() > 0 then
			LookAtOffset = SetLen(LookAtOffset, len)
		end
		if EyePtOffset:Len2() > 0 then
			EyePtOffset = SetLen(EyePtOffset, len)
		end
		camera.SetLookAtOffset(LookAtOffset, shake_tick)
		camera.SetEyeOffset(EyePtOffset, shake_tick)
		camera.SetRollOffset(AsyncRand(2*angle+1)-angle, shake_tick)
		if total_duration > 0 then
			time_left = time_left - shake_tick
			if time_left <= shake_tick then
				Sleep(time_left)
				break
			end
		end
		Sleep(shake_tick)
	end
	camera.ShakeStop(shake_tick)
end

function camera.Shake(total_duration, shake_tick, shake_max_offset, shake_max_roll)
	local max_offset = Clamp(shake_max_offset, 0, 10*guim)
	assert(max_offset == shake_max_offset, "camera.Shake() max_offset should be [0-10m]!")
	local max_roll = Clamp(shake_max_roll, 0, 180)
	assert(max_roll == shake_max_roll, "camera.Shake() max_roll should be [0-180]!")

	if total_duration == 0 or shake_tick <= 0 then
		return
	end
	if IsValidThread(camera_shake_thread) then
		if camera_shake_max_offset > shake_max_offset then
			return
		end
		DeleteThread(camera_shake_thread)
	end
	camera_shake_max_offset = max_offset
	camera_shake_thread = CreateRealTimeThread(DoShakeCamera, total_duration, shake_tick, max_offset, max_roll)
	MakeThreadPersistable(camera_shake_thread)
end

function camera.ShakeStop(shake_tick)
	camera.SetRollOffset(0, 0)
	camera.SetLookAtOffset(point30, shake_tick or 0)
	camera.SetEyeOffset(point30, shake_tick or 0)
	camera_shake_max_offset = 0
	if IsValidThread(camera_shake_thread) and CurrentThread() ~= camera_shake_thread then
		DeleteThread(camera_shake_thread)
	end
	camera_shake_thread = false
end

function OnMsg.ChangeMap()
	camera.ShakeStop()
end

function SetCamera(ptCamera, ptCameraLookAt, camType, zoom, properties, fovX, time)
	if type(ptCamera) == "table" then
		return SetCamera(unpack_params(ptCamera))
	end
	time = time or 0
	if camType then
		if camType == "Max" or camType == "3p" or camType == "RTS" or camType == "Tac" then
			camType = "camera" .. camType
		end
		_G[camType].Activate(1)
	end
	if not ptCamera then
		return
	end
	if camera3p.IsActive() then
		camera3p.SetEye(ptCamera, time)
		camera3p.SetLookAt(ptCameraLookAt, time)
	elseif cameraRTS.IsActive() then
		if properties then
			cameraRTS.SetProperties(1, properties)
		end
		cameraRTS.SetCamera(ptCamera, ptCameraLookAt, time)
		if zoom then
			cameraRTS.SetZoom(zoom)
		end
	elseif cameraMax.IsActive() then
		-- cameraMax can't look straight down
		local diff = ptCameraLookAt - ptCamera
		if diff:x() == 0 and diff:y() == 0 then
			ptCamera = ptCamera:SetX(ptCamera:x()-5)
		end
		cameraMax.SetCamera(ptCamera, ptCameraLookAt, time)
	elseif cameraTac.IsActive() then
		cameraTac.SetCamera(ptCamera, ptCameraLookAt, time)
		if properties then
			local floor = properties.floor
			local overview = properties.overview
			if floor then
				cameraTac.SetFloor(floor)
			end
			if overview ~= nil then
				cameraTac.SetOverview(overview, true)
			end
		end
		if zoom then
			cameraTac.SetZoom(zoom)
		end
	end
	SetCameraFov(fovX)
end

function SetCameraFov(fovX)
	camera.SetFovX(fovX or 70*60)
end

function SetRTSCameraFov(properties, duration, easing)
	local FovX = properties.FovX
	local minFovX = properties.FovXNarrow -- FovX for 3:4 screens
	local minX, minY = 4, 3
	local maxFovX = properties.FovXWide -- FovX for 21:9 screens
	local maxX, maxY = 21, 9
	if FovX and minFovX and maxFovX then
		-- when both FovXNarrow and FovXWide are supplied,
		-- FovX at 16:9 is computed and equals FovXNarrow * 5 / 9 + FovXWide * 4 / 9
		assert(abs(minFovX * 5 / 9 + maxFovX * 4 / 9 - FovX) < 60)
	end
	FovX = FovX or 90*60
	if not minFovX then
		minFovX = FovX
		minX, minY = 16, 9
	end
	if not maxFovX then
		maxFovX = FovX
		maxX, maxY = 16, 9
	end
	hr.CameraFovEasing = easing or "Linear"
	camera.SetAutoFovX(1, duration or 0, minFovX, minX, minY, maxFovX, maxX, maxY)
end

-- init from last camera with reasonable settings ( at editor exit, ... )
-- or set to map center if first run
function SetDefaultCameraRTS()
	cameraRTS.Activate(1)
	cameraRTS.SetProperties(1, const.DefaultCameraRTS)
	if Libs.Sim then
		cameraRTS.SetProperties(1, GetRTSCamPropsFromAccountStorage())
	end
	SetRTSCameraFov(const.DefaultCameraRTS)
	local lookat = cameraRTS.GetLookAt()
	if lookat:x() == 0 and lookat:y() == 0 then
		lookat = point(terrain.GetMapSize()) / 2
	end
	ViewObjectRTS(lookat, 0)
end

function GetCameraTypesItems()
	return {"3p", "RTS", "Max", "Tac"}
end

function GetCamera()
	local ptCamera, ptCameraLookAt, camType, zoom, properties, fovX
	if camera3p.IsActive() then
		ptCamera, ptCameraLookAt = camera.GetEye(), camera3p.GetLookAt()
		camType = "3p"
	elseif cameraRTS.IsActive() then
		ptCamera, ptCameraLookAt = cameraRTS.GetPosLookAt()
		camType = "RTS"
		zoom = cameraRTS.GetZoom()
		properties = cameraRTS.GetProperties(1)
	elseif cameraMax.IsActive() then
		ptCamera, ptCameraLookAt = cameraMax.GetPosLookAt()
		camType = "Max"
	elseif cameraTac.IsActive() then
		ptCamera, ptCameraLookAt = cameraTac.GetPosLookAt()
		camType = "Tac"
		zoom = cameraTac.GetZoom()
		properties = { floor = cameraTac.GetFloor(), overview = cameraTac.GetIsInOverview() }
	else
		ptCamera, ptCameraLookAt = camera.GetEye(), camera.GetEye() + SetLen(camera.GetDirection(), 3 * guim)
	end
	fovX = camera.GetFovX()
	return ptCamera, ptCameraLookAt, camType, zoom, properties, fovX
end

if FirstLoad then
	ptLastCameraPos = false
	ptLastCameraLookAt = false
	cameraMax3DView = {
		toggle = false,
		old_pos = false,
		old_lookat = false,
	}
end

function cameraMax3DView:Clean()
	self.toggle = false
	self.old_pos = false
	self.old_lookat = false
end

-- returns the new camera pos and the look pos of the selection
local function cameraMax3DView_Rotate(view_direction)
	local sel = editor.GetSel()
	local cnt = #sel
	if cnt == 0 then
		print("You need to select object(s) for this operation")
		return
	end
	
	local center = point30
	for i = 1, cnt do
		local bsc = sel[i]:GetBSphere()
		center = center + bsc
	end
	if cnt > 0 then
		-- find center of the selection
		center = point( center:x() / cnt, center:y() / cnt, center:z() / cnt )

		-- find the radius of the bounding sphere of the selection
		local selSize = 0
		for i = 1, cnt do
			local bsc, bsr = sel[i]:GetBSphere()
			local dist = bsc:Dist(center) + bsr
			if selSize < dist then
				selSize = dist
			end
		end
		selSize = 2 * selSize -- get the diameter of the selection
		
		-- move the camera position to look in the center of the selection
		local half_fovY = MulDivRound(camera.GetFovY(), 1, 2)
		local fov_sin, fov_cos = sin(half_fovY), cos(half_fovY)
		local dist_from_camera = (fov_sin > 0) and MulDivRound((selSize/2), fov_cos, fov_sin) or (selSize/2)
		
		view_direction = SetLen(view_direction, dist_from_camera * 130 / 100)
		local pos = center + view_direction
		cameraMax.SetCamera( pos, center, 0 )
	end
end

function cameraMax3DView:SetViewUp()
	cameraMax3DView_Rotate(point(0,0,1))
end
function cameraMax3DView:SetViewDown()
	cameraMax3DView_Rotate(point(0,0,-1))
end
function cameraMax3DView:SetViewOld()
	cameraMax.SetCamera( cameraMax3DView.old_pos, cameraMax3DView.old_lookat, 0 )
end

function cameraMax3DView:RotateZ(dir)
	local pos, look_at = cameraMax.GetPosLookAt()
	local cam_angle = (camera.GetYaw() / 60) + 180
	local cam_quadrant = (cam_angle / 90) % 4 + 1
	local correction = 0
	local z_axis = point(0,0,1)
	
	if cam_angle % 90 ~= 0 then
		if cam_angle - 90*(cam_quadrant-1) < 90*cam_quadrant - cam_angle then
			correction = -(cam_angle - 90*(cam_quadrant-1))
		else
			correction = 90*cam_quadrant - cam_angle
		end
		cam_angle = cam_angle + correction
	end
	
	local view_dir = false
	if dir == "east" then
		view_dir = RotateAxis(pos, z_axis, (cam_angle - 90) * 60)
	else
		view_dir = RotateAxis(pos, z_axis, (cam_angle + 90) * 60)
	end
	
	if view_dir then
		cameraMax3DView_Rotate(Normalize(view_dir))
	end
end

function ViewPos(pos, dist, cam_type)
	local ptCamera, ptCameraLookAt = GetCamera()
	if not ptCamera then
		return
	end
	if pos == InvalidPos() then
		pos = nil
	end
	if not pos then
		if ptLastCameraPos then
			SetCamera(ptLastCameraPos, ptLastCameraLookAt, cam_type)
		end
		return
	end
	
	ptLastCameraPos, ptLastCameraLookAt = ptCamera, ptCameraLookAt

	if not pos:z() then
		pos = pos:SetTerrainZ()
	end

	local cameraVector = ptCameraLookAt - ptCamera
	if dist then
		cameraVector = SetLen(cameraVector, dist)
	end
	ptCamera = pos - cameraVector
	ptCameraLookAt = pos
	
	SetCamera(ptCamera, ptCameraLookAt, cam_type)
end

ViewObject = function(obj, dist)
	if type(obj) == "number" and HandleToObject[obj] then
		obj = HandleToObject[obj]
	end
	local pos = IsValid(obj) and obj:GetPos()
	if not pos or pos == InvalidPos() then
		return
	end
	if dist then
		ViewPos(pos, dist)
	else
		local center, radius = obj:GetBSphere()
		ViewPos(center, Max(guim, radius * 10))
	end
end

local ViewNextObjectCache
function OnMsg.ChangeMap()
	ViewNextObjectCache = nil
end

-- Cycles ViewObject in the array objs, viewing the next object every time it is called for the same set of parameters

function ViewNextObject(name, objs, select_obj)
	name = name or ""
	local last
	if not objs then
		if name == "" then
			last = SelectedObj
			name = last and last.class
			select_obj = true
		end
		if not IsKindOf(g_Classes[name], "MapObject") then
			return
		end
		objs = MapGet("map", name)
	end
	ViewNextObjectCache = ViewNextObjectCache or setmetatable({}, weak_values_meta)
	last = last or ViewNextObjectCache[name]
	local idx = last and table.find(objs, last) or 0
	last = objs[idx+1] or objs[1]
	ViewNextObjectCache[name] = last
	ViewObject(last)
	SelectObj(last)
end

function ViewObjects(objects)
	objects = objects or {}
	local dgs = XEditorSelectSingleObjects
	XEditorSelectSingleObjects = 1
	editor.ChangeSelWithUndoRedo(objects)
	XEditorSelectSingleObjects = dgs
	if #objects == 0 then
		return
	end
	local bbox = GetObjectsBBox(objects)
	local center, radius = bbox:GetBSphere()
	local cam_pos = camera.GetEye()
	local h = cam_pos:z() - terrain.GetSurfaceHeight(cam_pos)
	local eye = center:SetZ(0) + SetLen((cam_pos - center):SetZ(0), h)
	eye = eye:SetZ(terrain.GetSurfaceHeight(eye) + h)
	local dist = (eye - center):Len()
	local new_dist = Clamp(Max(dist, 2*radius), 10*guim, 100*guim)
	eye = center + MulDivRound(eye - center, new_dist, dist)
	local steps = 18
	local angle = 360 * 60 / steps
	local max_radius = 2 * guim
	local success = true
	local objects_map = {}
	for i=1,#objects do
		objects_map[objects[i]] = true
	end
	while true do
		local objs = IntersectSegmentWithObjects(eye, center, const.efVisible)
		if not objs then
			break
		end
		local objects_too_big = false
		for i=1,#objs do
			local obj = objs[i]
			if not objects_map[obj] then
				local center, radius = obj:GetBSphere()
				if radius > max_radius then
					objects_too_big = true
					break
				end
			end
		end
		if not objects_too_big then
			break
		end
		steps = steps - 1
		if steps <= 1 then
			success = false
			break
		end
		eye = RotateAroundCenter(center, eye, angle)
		eye = eye:SetZ(terrain.GetSurfaceHeight(eye) + h) 
	end
	if success then
		SetCamera(eye, center)
	end
end

if FirstLoad then
	SplitScreenType = false
	SplitScreenEnabled = true
	SecondViewEnabled = false
	SecondViewViewport = false
end

-- call this after every resolution/scene size change to recalc and setup appropriate views for single or split screen
function SetupViews(size)
	local w, h = 1000000, 1000000
	if SecondViewEnabled and SecondViewViewport then
		camera.SetViewCount(2)
		camera.SetViewport(box(0, 0, w, h), 1)
		camera.SetViewport(SecondViewViewport, 2)
	elseif SplitScreenEnabled then
		if SplitScreenType == "horizontal"	then
			camera.SetViewCount( 2 )
			camera.SetViewport( box( 0, 0, w, h/16*8 ), 1 )
			camera.SetViewport( box( 0, (h+15)/16*8, w, h ), 2 )
		elseif SplitScreenType == "vertical" then
			camera.SetViewCount( 2 )
			camera.SetViewport( box( 0, 0, w/16*8, h ), 1 )
			camera.SetViewport( box( (w+15)/16*8, 0, w, h ), 2 )
		else
			camera.SetViewCount( 1 )
			camera.SetViewport( box(0,0,w,h), 1 )
		end
	else
		if not SplitScreenType then
			camera.SetViewCount( 1 )
			camera.SetViewport( box(0,0,w,h), 1 )
		else
			camera.SetViewport( box(0,0,w,h), 1 )
		end
	end
end

if FirstLoad then
SplitScreenDisableReasons = {}
end

function SetSplitScreenEnabled( on, reason )
	assert(reason)
	SplitScreenDisableReasons[reason] = (on == false) or nil
	on = not next(SplitScreenDisableReasons)
	if SplitScreenEnabled ~= on then
		SplitScreenEnabled = on
		SetupViews()
		Msg("SplitScreenChange", true)
	end
end

function EnableSecondView(viewport)
	SecondViewEnabled = true
	SecondViewViewport = viewport
	SetupViews()
end

function DisableSecondView()
	SecondViewEnabled = false
	SetupViews()
end

function SetSplitScreenType( type )
	if type == "" then type = false end
	local bChange = SplitScreenType ~= type
	SplitScreenType = type
	if not CameraControlScene then
		SetupViews()
	end
	if bChange then
		Msg("SplitScreenChange")
	end
end

function IsSplitScreenEnabled()
	return SplitScreenEnabled and SplitScreenType and true
end

function IsSplitScreenHorizontal()
	return SplitScreenEnabled and SplitScreenType == "horizontal"
end

function IsSplitScreenVertical()
	return SplitScreenEnabled and SplitScreenType == "vertical"
end

function DbgLoadLocation(map, cam_params, editor_mode, map_rand)	
	if not MapData[map] then
		print("No such map:", map)
		return
	end
	CreateRealTimeThread(function()
		EditorDeactivate()
		if map ~= GetMapName() or map_rand and map_rand ~= MapLoadRandom then
			if map_rand then
				table.change(config, "DbgLoadLocation", { FixedMapLoadRandom = map_rand })
			end
			ChangeMap(map)
			table.restore(config, "DbgLoadLocation", true)
		end
		if editor_mode then
			EditorActivate()
		end
		if cam_params then
			if cam_params[3] == "Fly" then
				cam_params[3] = "Max"
				SetCamera(table.unpack(cam_params))
				cameraFly.Activate()
			else
				SetCamera(table.unpack(cam_params))
			end
		end
		CloseMenuDialogs()
		Msg("OnDbgLoadLocation")
	end)
end

function GetCameraLocationString()
	local cam_params
	if cameraFly.IsActive() then
		-- Fly camera doesn't expose its parameters, but it can be saved as Max and forced to Fly again on load
		cameraMax.Activate()
		cam_params = {GetCamera()}
		cam_params[3] = "Fly"
		cameraFly.Activate()
	else
		cam_params = {GetCamera()}
	end
	return string.format("DbgLoadLocation( \"%s\", %s, %s, %s)\n",
		GetMapName(),
		TableToLuaCode(cam_params, ' '),
		IsEditorActive() and "true" or "false",
		tostring(MapLoadRandom))
end

function OnMsg.BugReportStart(print_func)
	print_func(string.format("\nLocation: (paste in the console)\n%s", GetCameraLocationString()))
end

if FirstLoad then
	g_ResetSceneCameraViewportThread = false
end

function OnMsg.SystemSize(pt)
	--if FullscreenMode() == 0 then
		DeleteThread(g_ResetSceneCameraViewportThread)
		g_ResetSceneCameraViewportThread = CreateRealTimeThread(function()
			WaitNextFrame(1)
			SetupViews(pt)
		end)
	--end
end

local function IsValidCameraPos(pos)
	return pos and pos ~= point30 and pos ~= InvalidPos()
end

local function CanMoveCamBetween(pos0, pos1)
	local max_move_dist = const.MaxMoveCamDist or max_int
	if max_move_dist >= max_int or IsCloser(pos0, pos1, max_move_dist) then return true end
	return not terrain.IntersectSegment(pos0, pos1)
end

function ViewObjectRTS(obj, time, pos, zoom)
	if not obj then
		return
	end

	local la = IsPoint(obj) and obj or IsValid(obj) and (obj:HasMember("GetLogicalPos") and obj:GetLogicalPos() or obj:GetVisualPos())
	if not la or la == InvalidPos() then
		return
	end
	la = la:SetTerrainZ()
	
	local cur_pos, cur_la = cameraRTS.GetPosLookAt()
	if not pos then
		local cur_off = cur_pos - cur_la
		if not IsValidCameraPos(cur_pos) or cur_pos == cur_la then
			local lookatDist = const.DefaultCameraRTS.LookatDistZoomIn + (const.DefaultCameraRTS.LookatDistZoomOut - const.DefaultCameraRTS.LookatDistZoomIn) * cameraRTS.GetZoom()
			cur_off = SetLen(point(1, 1, 0), lookatDist*guim) + point(0, 0, cameraRTS.GetHeight()*guim)
			zoom = zoom or 0.5
		end
		pos = la + cur_off
	end
	pos, la = cameraRTS.Normalize(pos, la)
	
	if not IsValidCameraPos(cur_pos) or not CanMoveCamBetween(cur_pos, pos) then
		time = 0
	elseif not time then
		local min_dist, max_dist = 200*guim, 1000*guim
		local min_time, max_time = 200, 500
		local dist_factor = Clamp(pos:Dist2D(cur_pos) - min_dist, 0, max_dist) * 100 / (max_dist - min_dist)
		time = min_time + (max_time - min_time) * dist_factor / 100
	end

	cameraRTS.SetCamera(pos, la, time or 0, "Sin in/out")
	if zoom then
		cameraRTS.SetZoom(zoom, time or 0)
	end
end

CameraInterpolationTypes =
{
	linear = 0,
	spherical = 1,
	polar = 2
}

CameraMovementTypes =
{
	linear = 0,
	harmonic = 1,
	accelerated = 2,
	decelerated = 3,
}

function SetCameraPosMaxLookAt(pos, lookat, base_offset, base_angle, camera_view)
	cameraMax.SetPositionLookatAndRoll(base_offset + Rotate(pos, base_angle), base_offset + Rotate(lookat, base_angle), 0)
end

function InterpolateCameraMaxWakeup(camera1, camera2, duration, relative_to, interpolation, movement, camera_view)
	camera_view = camera_view or 1
	
	local base_offset = IsValid(relative_to) and relative_to:GetVisualPosPrecise(1000) or point30
	local base_angle = IsValid(relative_to) and relative_to:GetVisualAngle() or 0

	local camera2_pos = Rotate(camera2.pos * 1000 - base_offset, 360*60 - base_angle)
	local camera2_lookat = Rotate(camera2.lookat * 1000 - base_offset, 360*60 - base_angle)
	if duration > 1 then
		local camera1_pos = Rotate(camera1.pos * 1000 - base_offset, 360*60 - base_angle)
		local camera1_lookat = Rotate(camera1.lookat * 1000 - base_offset, 360*60 - base_angle)
		SetCameraPosMaxLookAt(camera1_pos, camera1_lookat, base_offset, base_angle, camera_view)
		for t = 1, duration do
			if WaitWakeup(1) then
				break
			end
			base_offset = IsValid(relative_to) and relative_to:GetVisualPosPrecise(1000) or point30
			base_angle = IsValid(relative_to) and relative_to:GetVisualAngle() or 0
			local p, l = CameraLerp(camera1_pos, camera1_lookat, camera2_pos, camera2_lookat, t, duration, CameraInterpolationTypes[interpolation] or 0, CameraMovementTypes[movement] or 0)
			SetCameraPosMaxLookAt(p, l, base_offset, base_angle, camera_view)
		end
	end
	SetCameraPosMaxLookAt(camera2_pos, camera2_lookat, base_offset, base_angle, camera_view)
end

function CheatToggleFlyCamera()
	if cameraFly.IsActive() then
		SetMouseDeltaMode(false)
		if rawget(_G, "GetPlayerControlObj") and GetPlayerControlObj() then
			ApplyCameraAndControllers()
		else
			SetupInitialCamera()
		end
	else
		print("Camera Fly")
		cameraFly.Activate(1)
		if rawget(_G, "GetPlayerControlObj") and GetPlayerControlObj() then
			PlayerControl_RecalcActive(true)
		end
		SetMouseDeltaMode(true)
	end
end
