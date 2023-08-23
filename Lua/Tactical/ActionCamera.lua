ac_interpolation_time = 0
default_interpolation_time = 500
local ac_after_interpolation_idle = 700
local zoom_interpolation_time = 700
local hide_nearby_objs = {"Shrub", "SlabWallObject"}
local hide_nearby_objs_radius = 3*guim
local target_spots = {"Head", "Groin", "Hit"}
-- vignette
local ac_vignette_color = RGBA(22, 42, 22, 200)

MapVar("CameraBeforeActionCamera", false)
MapVar("ActionCameraInterpolatingTowards", false)
MapVar("VisibilityModesBeforeActionCamera", false)
MapVar("DOFBeforeActionCamera", false)
MapVar("ActionCameraFloatThread", false)
MapVar("ActionCameraInterpolationThread", false)
MapVar("ActionCameraTurnOffThread", false)
MapVar("CurrentActionCamera", false)
MapVar("ActionCameraPlaying", false)
MapVar("LocalACWillStartPlaying", false)
MapVar("ActionCameraHiddenObjs", {})

ActionCameraHidingModeCombo = {
	{
		id = "NoCMT",
		name = Untranslated("No CMT (Default)")
	},
	{
		id = "CMT",
		name = Untranslated("CMT (Hide TreeTops/Walls)")
	},
	{
		id = "ContourAll",
		name = Untranslated("Contour Everything")
	}
}

function SetActionCamera(attacker, target, disable_float, force_fp, ac_to_restore, interpolation_time, no_rotate)
	local new_pos, new_lookat, preset
	if not ac_to_restore then
		new_pos, new_lookat, preset = CalcActionCamera(attacker, target, nil, force_fp, no_rotate)
	end
	SetActionCameraDirect(attacker, target, new_pos, new_lookat, preset, disable_float, interpolation_time or ac_interpolation_time, true, ac_to_restore)
end

function SetActionCameraNoFallback(attacker, target, disable_float, interpolation_time, no_rotate, preset_filter, dontActiveAC)
	local new_pos, new_lookat, preset, fallback = CalcActionCamera(attacker, target, nil, nil, no_rotate)
	if fallback then return false end
	if preset_filter and table.find(preset_filter, preset.id) then return false end
	if not dontActiveAC then
		SetActionCameraDirect(attacker, target, new_pos, new_lookat, preset, disable_float, interpolation_time or ac_interpolation_time, true)
	end
	return true
end

function OnMsg.ActionCameraRemoved()
	if netInGame then
		if SelectedObj and SelectedObj:IsLocalPlayerControlled() then
			ObjModified(SelectedObj)
		end
	end
end

function OnMsg.SelectedObjChange(obj)
	Msg("ActionCameraWaitSignalEnd")
end

function OnMsg.WillStartSetpiece()
	RemoveActionCamera(true, 0)
end

function NetSyncEvents.ActionCameraRemoved()
	NetUpdateHash("ActionCameraPlaying", ActionCameraPlaying)
	if not ActionCameraPlaying or ActionCameraPlaying == 0 then
		return
	end
	ActionCameraPlaying = ActionCameraPlaying - 1
	--print("ActionCameraPlaying dec", ActionCameraPlaying)
	if ActionCameraPlaying <= 0 then
		ActionCameraPlaying = false
		Msg("ActionCameraRemoved")

		if IsGameReplayRunning() then
			_removeActionCamera(true)
		end
	end
	NetUpdateHash("ActionCameraPlaying", ActionCameraPlaying)
end

function NetSyncEvents.SetActionCameraDirect(playerNetId, attacker, target, new_pos, new_lookat, presetId, disable_float, interpolation_time, vignette, ac_to_restore)
	ActionCameraPlaying = (ActionCameraPlaying or 0) + 1
	NetUpdateHash("ActionCameraPlaying", ActionCameraPlaying)
	--print("ActionCameraPlaying inc", ActionCameraPlaying)
	
	if playerNetId == netUniqueId then
		LocalACWillStartPlaying = (LocalACWillStartPlaying or 0) - 1
		if LocalACWillStartPlaying <= 0 then
			LocalACWillStartPlaying = false
			Msg("LocalACWillStartPlaying")
		end
		_SetActionCameraDirect(attacker, target, new_pos, new_lookat, table.get(Presets, "ActionCameraDef", "Default", presetId), disable_float, interpolation_time, vignette, ac_to_restore)
	end
end

function SetActionCameraDirect(attacker, target, new_pos, new_lookat, preset, disable_float, interpolation_time, vignette, ac_to_restore)
	assert(preset)
	if not preset then return end
	LocalACWillStartPlaying = (LocalACWillStartPlaying or 0) + 1
	NetSyncEvent("SetActionCameraDirect", netUniqueId, attacker, target, new_pos, new_lookat, preset and preset.id, disable_float, interpolation_time, vignette, ac_to_restore)
end

function _SetActionCameraDirect(attacker, target, new_pos, new_lookat, preset, disable_float, interpolation_time, vignette, ac_to_restore)
	if IsValidThread(ActionCameraInterpolationThread) then
		DeleteThread(ActionCameraInterpolationThread)
		if ActionCameraInterpolatingTowards then
			_setCameraFromSavedState(attacker, ActionCameraInterpolatingTowards, true)
			ActionCameraInterpolatingTowards = false
		end
		NetSyncEvent("ActionCameraRemoved")
	elseif CurrentActionCamera then
		NetSyncEvent("ActionCameraRemoved")
	end
	
	if not cameraTac.IsActive() then
		return
	end
	
	Msg("SettingActionCamera")
	CurrentActionCamera = ac_to_restore or {attacker, target, new_pos, new_lookat, preset}
	attacker = CurrentActionCamera[1]
	target = CurrentActionCamera[2]
	new_pos = CurrentActionCamera[3]
	new_lookat = CurrentActionCamera[4]
	preset = CurrentActionCamera[5]
	
	-- Record previous camera
	LockCamera("ActionCamera")
	local intTime = hr.CameraTacOverviewTime
	hr.CameraTacOverviewTime = 0
	cameraTac.SetOverview(false)
	hr.CameraTacOverviewTime = intTime
	
	local treeTopHidingRadius = const.CMT_HideTreeTopsCameraLookAt2DRadius
	const.CMT_HideTreeTopsCameraLookAt2DRadius = 14000
	
	local hidingMode = preset.HidingMode
	if VisibilityModesBeforeActionCamera then
		local enactedHidingMode = VisibilityModesBeforeActionCamera.hiding
		if enactedHidingMode then
			ActionCameraHiding(false, enactedHidingMode)
		end
		VisibilityModesBeforeActionCamera.hiding = hidingMode
	end
	
	if not CameraBeforeActionCamera then
		CameraBeforeActionCamera = pack_params(GetCamera())
		
		-- Restore camera to attacker.
		-- If attacker is invalid the position will be the destination position of any interpolation.
		local endPos, endLookAt, floor = GetCameraSnapToObjectParams(IsValid(attacker) and attacker:GetPos(), nil, "allow")
		CameraBeforeActionCamera[1] = endPos
		CameraBeforeActionCamera[2] = endLookAt
		if floor and CameraBeforeActionCamera[5] then
			CameraBeforeActionCamera[5].floor = floor
		end
	end
	VisibilityModesBeforeActionCamera = VisibilityModesBeforeActionCamera or { hiding = hidingMode, hideRad = treeTopHidingRadius }
	DOFBeforeActionCamera = DOFBeforeActionCamera or { GetDOFParams() }

	-- Setup camera
	table.change(hr, "ActionCamera", {
		CameraTacClampToTerrain = false,
		CameraTacUseVoxelBorder = false,
		EnableObjectMarking = 0,
	})
	local targetFloor = GetFloorOfPos(IsValid(target) and target:GetPos() or target)
	local attackerFloor = GetFloorOfPos(IsValid(attacker) and attacker:GetPos() or attacker)
	cameraTac.SetPosLookAtAndFloor(new_pos, new_lookat, Max(targetFloor, attackerFloor), interpolation_time)
	cameraTac.SetZoom(1000, interpolation_time/10)
	camera.SetFovX(preset.FovX, interpolation_time)
	
	preset:SetDOFParams(interpolation_time, attacker, target, new_pos)

	-- Setup visuals
	ActionCameraHiding(true, hidingMode)
	ShowActionCameraVignette(vignette)
	listener.DistanceFromCamera = "0.0"
	ActionCameraUpdateUIVisibility()
	
	-- Setup threads.
	DeleteThread(ActionCameraFloatThread)
	if ActionCameraTurnOffThread then
		DeleteThread(ActionCameraTurnOffThread)
		ActionCameraTurnOffThread = false
	end
	DeleteThread(ActionCameraInterpolationThread)
	ActionCameraInterpolationThread = CreateRealTimeThread(function()
		Sleep(interpolation_time)
		WaitActionCameraInterpolation(new_pos)
		Msg("ActionCameraInPosition")
	end)
	ActionCameraFloatThread = not disable_float and CreateRealTimeThread(function()
		Sleep(interpolation_time)
		WaitActionCameraInterpolation(new_pos)
		while true do
			local pt = GetRandomPosOnSphere(new_pos, preset.FloatSphereRadius)
			cameraTac.SetCamera(pt, new_lookat, preset.FloatInterpolationTime, preset.FloatEasing)
			Sleep(preset.FloatInterpolationTime)
			WaitActionCameraInterpolation(pt)
			Sleep(100 + AsyncRand(100))
		end
	end)
end

function _setCameraFromSavedState(attacker, state, force, interp_time)
	local int_time = not force and (interp_time or ac_interpolation_time) or 0
	cameraTac.SetZoom(state[4])
	if IsValid(attacker) then
		local pos = attacker:GetPos()
		pos = not pos:IsValidZ() and pos:SetTerrainZ() or pos
		local ptCamera, ptCameraLookAt = state[1], state[2]
		local cameraVector = ptCameraLookAt - ptCamera
		ptCamera = pos - cameraVector
		ptCameraLookAt = pos
		
		local extraParams = state[5]
		if extraParams and extraParams.floor then
			cameraTac.SetPosLookAtAndFloor(ptCamera, ptCameraLookAt, extraParams.floor, int_time)
		else
			cameraTac.SetCamera(ptCamera, ptCameraLookAt, int_time)
		end
	else
		cameraTac.SetCamera(state[1], state[2], int_time)
	end
	if state.set_auto_fov_x then
		SetAutoFovX(false, int_time)
	else
		camera.SetFovX(state[6], int_time)
	end
	return int_time
end

function _removeActionCamera(force, interp_time)
	-- Stop threads
	DeleteThread(ActionCameraFloatThread)
	ActionCameraFloatThread = false
	DeleteThread(ActionCameraInterpolationThread)
	ActionCameraInterpolationThread = false

	local attacker = CurrentActionCamera and CurrentActionCamera[1]
	local preset = CurrentActionCamera and CurrentActionCamera[5]
	listener.DistanceFromCamera = "1.0"
	
	if CameraBeforeActionCamera then
		if VisibilityModesBeforeActionCamera then
			if VisibilityModesBeforeActionCamera.hideRad then
				const.CMT_HideTreeTopsCameraLookAt2DRadius = VisibilityModesBeforeActionCamera.hideRad
			end
		end

		local int_time = _setCameraFromSavedState(attacker, CameraBeforeActionCamera, force, interp_time)
		ActionCameraInterpolatingTowards = CameraBeforeActionCamera
		ActionCameraInterpolationThread = CreateRealTimeThread(function()
			Sleep(int_time)
			table.restore(hr, "ActionCamera")
			CurrentActionCamera = false
			ActionCameraUpdateUIVisibility()
			UnlockCamera("ActionCamera")
			NetSyncEvent("ActionCameraRemoved")
			ActionCameraInterpolatingTowards = false
		end)
		if DOFBeforeActionCamera then
			local params = table.copy(DOFBeforeActionCamera)
			table.insert(params, int_time)
			SetDOFParams(table.unpack(params))
		end

		local hidingMode =  VisibilityModesBeforeActionCamera and VisibilityModesBeforeActionCamera.hiding or preset.HidingMode
		if hidingMode and not IsChangingMap() then 
			ActionCameraHiding(false, hidingMode)
		end
		
		ShowActionCameraVignette(false, force)
		if not force then
			Sleep(interp_time or ac_interpolation_time)
		end
		CameraBeforeActionCamera = false
		VisibilityModesBeforeActionCamera = false
		DOFBeforeActionCamera = false
		return
	end

	hr.CameraTacClampToTerrain = true
	hr.CameraTacUseVoxelBorder = true
	CurrentActionCamera = false
	ActionCameraUpdateUIVisibility()
	UnlockCamera("ActionCamera")
	NetSyncEvent("ActionCameraRemoved")
end

function RemoveActionCamera(force, interp_time)
	if not force and ActionCameraAutoRemoveThread then
		return false
	end
	if not CurrentActionCamera then
		return false
	end
	if ActionCameraTurnOffThread then
		DeleteThread(ActionCameraTurnOffThread)
		ActionCameraTurnOffThread = false
	end
	if force then
		_removeActionCamera(force)
	else
		ActionCameraTurnOffThread = CreateGameTimeThread(function()
			if CurrentActionCamera and CurrentActionCamera.wait_signal then
				WaitMsg("ActionCameraWaitSignalEnd", 5000)
			end
			_removeActionCamera(force, interp_time)
		end)
	end
end

function OnMsg.ActionCameraWaitSignalEnd()
	if CurrentActionCamera then CurrentActionCamera.wait_signal = false end
end

function OnMsg.ChangeMap()
	RemoveActionCamera("force")
end

local function lCalcCamPosLookat(a_pos, t_pos, ortog_a, ortog_t, target_z_offs, preset)
	local pos = a_pos
	local look_at = t_pos
	if ortog_a then
		pos = pos + ortog_a
	end
	if ortog_t then
		look_at = look_at + ortog_t 
	end
	pos = look_at + Lengthen(pos - look_at, preset.EyeBackOffset)
	local cameraPos = pos:SetZ(pos:z() + preset.EyeZOffset)
	local cameraLookAt = look_at:SetZ(look_at:z() + target_z_offs)
	
	local terrainZCameraPos = terrain.GetHeight(cameraPos)
	if terrainZCameraPos > cameraPos:z() then
		cameraPos = cameraPos:SetZ(terrainZCameraPos + guim)
	end
	
	return cameraPos, cameraLookAt
end

local function lGetAttackAndTargetPos(attacker, target, preset, no_rotate)
	local a_pos = IsPoint(attacker) and attacker or attacker:GetSpotLoc(attacker:GetSpotBeginIndex("Groin"))
	
	local spotToCheck = target:GetSpotBeginIndex("Groin") == -1 and "Hit" or "Groin"
	local t_pos = GetActionCameraTargetPos(target, spotToCheck, attacker)

	if attacker == target then -- Jumping through windows, stuff that only focuses on one merc, etc
		local temp = t_pos
		t_pos = a_pos
		a_pos = temp + Rotate(point(guim * 5, 0, 0), attacker:GetAngle())
	end
	
	local target_z_offs, ortog_t, ortog_a
	if no_rotate then
		local currentCamera = CameraBeforeActionCamera or pack_params(GetCamera())
		local currentCamRot = Normalize(currentCamera[1] - currentCamera[2])
		local dist = (a_pos - t_pos):SetZ(0):Len()
		a_pos = t_pos + SetLen(currentCamRot, dist)

		target_z_offs = 0
		ortog_t = point30
		ortog_a = point30
	else
		local vector = (a_pos - t_pos):SetZ(0)
		local dist = vector:Len()
		local target_lookat_offs = Max(guim, MulDivRound(dist, preset.LookAtTargetOffset, preset.AttackerTargetDistParam))

		target_z_offs = MulDivRound(dist, preset.LookAtZOffset, preset.AttackerTargetDistParam)
		ortog_t = SetLen(point(-vector:y(), vector:x(), 0), target_lookat_offs)
		ortog_a = SetLen(point(vector:y(), - vector:x(), 0), preset.EyeAttackerOffset)
	end

	return a_pos, t_pos, target_z_offs, ortog_a, ortog_t
end

function AddActionCameraForPreset(attacker, target, preset, valid_cameras, all_cameras, cam_positioning, no_rotate)
	local a_pos, t_pos, target_z_offs, ortog_a, ortog_t = lGetAttackAndTargetPos(attacker, target, preset, no_rotate)
	
	-- camera behind right shoulder
	local camera
	if cam_positioning ~= "Left" then
		local r_new_pos, r_new_lookat = lCalcCamPosLookat(a_pos, t_pos, ortog_a, ortog_t, target_z_offs, preset)
		local r_obstacles = GetActionCameraObstacles(r_new_pos, target, attacker)
		if r_obstacles then
			camera = {r_new_pos, r_new_lookat, preset, r_obstacles}
			if #r_obstacles == 0 and valid_cameras then
				valid_cameras[#valid_cameras + 1] = camera
			end
			all_cameras[#all_cameras + 1] = camera
		end
	end
	
	-- camera behind left shoulder
	if cam_positioning ~= "Right" then
		local l_new_pos, l_new_lookat = lCalcCamPosLookat(a_pos, t_pos, -ortog_a, -ortog_t, target_z_offs, preset)
		local l_obstacles = GetActionCameraObstacles(l_new_pos, target, attacker)
		if l_obstacles then
			camera = {l_new_pos, l_new_lookat, preset, l_obstacles}
			if #l_obstacles == 0 and valid_cameras then
				valid_cameras[#valid_cameras + 1] = camera
			end
			all_cameras[#all_cameras + 1] = camera
		end
	end
end

function GetFPCameraFromPreset(attacker, target, preset, no_rotate)
	local a_pos, t_pos, target_z_offs, ortog_a, ortog_t = lGetAttackAndTargetPos(attacker, target, preset, no_rotate)
	local pos, lookat = lCalcCamPosLookat(a_pos, t_pos, false, false, target_z_offs, preset)
	return {pos, lookat, preset}
end

VisionCollisionFilter = function(o)
	return (not IsKindOf(o, "SlabWallObject") or not o:IsWindow()) and IsVisible(o) and not IsKindOf(o, "RoofPlaneSlab")
end

VisionCollisionFilterNoTerrain = function(o)
	return VisionCollisionFilter(o) and not IsKindOf(o, "TerrainCollision")
end

local function lIsActionCameraHideableObject(cam_pos, o)
	if IsKindOf(o, "SlabWallObject") then
		if o:IsDoor() or not ActionCameraShouldHideWindow(cam_pos, o) then 
			return false
		end
	end
	return IsKindOfClasses(o, hide_nearby_objs)
end

function GetACamsForPreset(attacker, target, preset, cam_positioning, no_rotate, output)
	local ts = GetPreciseTicks()
	local sources = output.sources
	local dests = output.dests
	local test_to_cam = output.test_to_cam
	local targets = output.targets
	local cameras = output.cameras
	local a_pos, t_pos, target_z_offs, ortog_a, ortog_t = lGetAttackAndTargetPos(attacker, target, preset, no_rotate)
	
	local function pushTest(src, dest, cam, target)
		sources[#sources + 1] = src
		dests[#dests + 1] = dest
		test_to_cam[#test_to_cam + 1] = cam
		targets[#targets + 1] = target
	end
	
	local function fillOutput(cam_pos, cam_look_at)
		if cam_pos:z() - terrain.GetHeight(cam_pos) < guim then
			return
		end
		
		local cam = {cam_pos, cam_look_at, preset, {target_visible = true, min_dist = max_int}, begin_idx = #sources + 1}
		cameras[#cameras + 1] = cam
		--local target_pos = C_GetActionCameraTargetPos(attacker, "Torso")
		local target_pos = GetActionCameraTargetPos(attacker, "Torso")
		pushTest(cam_pos, target_pos, cam, attacker)
		for _, spot in ipairs(target_spots) do
			local hasSpot = target:GetSpotBeginIndex(spot) ~= -1
			if not hasSpot then goto continue end
		
			--target_pos = C_GetActionCameraTargetPos(target, spot, attacker)
			target_pos = GetActionCameraTargetPos(target, spot, attacker)
			pushTest(cam_pos, target_pos, cam, target)
			
			::continue::
		end
	end
	if cam_positioning ~= "Left" then --behind right shldr, idk why its inversed
		local r_new_pos, r_new_lookat = lCalcCamPosLookat(a_pos, t_pos, ortog_a, ortog_t, target_z_offs, preset)
		fillOutput(r_new_pos, r_new_lookat)
	end
	if cam_positioning ~= "Right" then --behind lft shldr
		local l_new_pos, l_new_lookat = lCalcCamPosLookat(a_pos, t_pos, -ortog_a, -ortog_t, target_z_offs, preset)
		fillOutput(l_new_pos, l_new_lookat)
	end
end

local buffer = point(guim, guim, guim)
function CalcActionCamera(attacker, target, cam_positioning, force_fp, no_rotate)
	no_rotate = no_rotate or false
	local fp_cam
	if force_fp then
		fp_cam = GetFPCameraFromPreset(attacker, target, Presets.ActionCameraDef.Default.FirstPerson_Cam)
		return fp_cam[1], fp_cam[2], fp_cam[3]
	end
	local valid_cameras, all_cameras = {}, {}
	local output = {
		sources = {},
		dests = {}, --target pt
		targets = {}, --target obj
		cameras = {},
		test_to_cam = {},
	}
	local sources = output.sources
	local dests = output.dests
	local test_to_cam = output.test_to_cam
	local targets = output.targets
	local cameras = output.cameras
	
	local stance = attacker.stance
	if #(stance or "") == 0 then
		stance = "Crouch" -- attacker.species ~= "Human"
	end
	for _, preset in ipairs(Presets.ActionCameraDef.Default) do
		local isHigherCam = preset.id == "Z_HigherCamera"
		assert(preset:HasMember(stance), "Invalid stance in ActionCameraDef properties")
		if preset[stance] and not preset.SetPieceOnly and (preset.NoRotate == no_rotate or isHigherCam) then
			if (not no_rotate and preset.id == "FirstPerson_Cam") or (no_rotate and isHigherCam) then
				fp_cam = GetFPCameraFromPreset(attacker, target, preset, no_rotate)
			else
				GetACamsForPreset(attacker, target, preset, cam_positioning, no_rotate, output)
			end
		end
	end
	
	if #sources > 0 then
		ACVisibilityBatchTest(sources, dests,
			function(obj, idx, pos, dist)
				local src = sources[idx]
				if VisionCollisionFilter(obj) and not lIsActionCameraHideableObject(src, obj) and obj ~= target then
					local cam = test_to_cam[idx]
					local obstacles = cam[4]
					--table.insert(obstacles, obj)
					obstacles[#obstacles + 1] = obj
					obstacles.min_dist = Min(obstacles.min_dist, dist)
					if targets[idx] == target then
						obstacles.target_visible = false
					end
				end
			end)
			
		for i, cam in ipairs(cameras) do
			if cam[3].id ~= "Z_HigherCamera" then
				local obstacles = cam[4]
				if #obstacles <= 0 then
					--test for units blocking view
					local j = cam.begin_idx + 1
					while test_to_cam[j] == cam do
						--[[for _, unit in ipairs(g_Units) do
							if unit ~= target and unit ~= attacker and ClipSegmentWithBox3D(sources[j], dests[j], unit) then
								table.insert(obstacles, unit)
								obstacles.target_visible = false
								break
							end
						end]]
						local s, d = sources[j], dests[j]
						local min = point(Min(s:x(), d:x()), Min(s:y(), d:y()), Min(s:z(), d:z())) - buffer
						local max = point(Max(s:x(), d:x()), Max(s:y(), d:y()), Max(s:z(), d:z())) + buffer
						local b = box(min, max)
						MapForEach(b, "Unit", function(unit)
							if unit ~= target and unit ~= attacker and ClipSegmentWithBox3D(sources[j], dests[j], unit) then
								obstacles[#obstacles + 1] = unit
								obstacles.target_visible = false
								return "break"
							end
						end)
						if not obstacles.target_visible then
							break
						end
						j = j + 1
					end
					
					if #obstacles <= 0 then
						valid_cameras[#valid_cameras + 1] = cam
					end
				end
			end
		end
	end
	all_cameras = cameras
	
	if next(valid_cameras) then
		local seed = xxhash(IsPoint(attacker) and attacker or attacker:GetPos(), GetActionCameraTargetPos(target))
		local rand = BraidRandom(seed, #valid_cameras)
		local camera = valid_cameras[1 + rand]
		return camera[1], camera[2], camera[3]
	end
	
	local tie
	local best_match
	for i = 1, #all_cameras do
		local cam = all_cameras[i]
		if cam[4].target_visible then
			if not best_match then
				best_match = cam
			elseif #cam[4] < #best_match[4] then
				best_match = cam
			elseif #cam[4] == #best_match[4] then
				tie = #cam[4]
			end
		end
	end
	
	if tie then
		for i = 1, #all_cameras do
			local cam = all_cameras[i]
			local col_cam = cam[4]
			if #col_cam == tie then
				local col_best_match = best_match[4]
				if col_cam.min_dist > col_best_match.min_dist then
					best_match = cam
				end
			end
		end
	end
	assert(fp_cam)
	local fallback = not best_match
	best_match = best_match or fp_cam
	return best_match[1], best_match[2], best_match[3], fallback
end

function GetActionCameraTargetPos(target, spot_id, attacker)
	if IsPoint(target) then
		local valid_z = (target:IsValidZ() and target:z()) or spot_id and attacker and attacker:GetSpotLoc(attacker:GetSpotBeginIndex(spot_id)):z()
		return valid_z and target:SetZ(valid_z) or target:SetTerrainZ()
	elseif spot_id then
		return target:GetSpotLoc(target:GetSpotBeginIndex(spot_id))
	else
		return target:GetPos()
	end
end

GetActionCameraTargetPos = C_GetActionCameraTargetPos

function GetRandomPosOnSphere(center, radius)
	local z = AsyncRand(2*radius + 1) - radius
	local circle_radius = sqrt(radius*radius - z*z)
	local rand_angle = AsyncRand(360)
	local x = circle_radius * sin(rand_angle*60) / 4096
	local y = circle_radius * cos(rand_angle*60) / 4096
	return center + point(x, y, z)
end

function WaitActionCameraInterpolation(dest_pt)
	local step = 10
	local time = 0
	while GetCamera() ~= dest_pt do 
		Sleep(step)
		time = time + step
		
		if time > 2000 then -- timeout after 2000 ms
			if not IsEditorActive() then
				assert(hr.CameraTacClampToTerrain == false)
				assert(hr.CameraTacUseVoxelBorder == false)
				assert(not CurrentActionCamera.wait_signal)
			end
			break
		end
	end
end

function OnMsg.UnitStanceChanged(unit)
	CreateRealTimeThread(function()
		Sleep(1) -- Wait for the change stance command to finish.
		if not CurrentActionCamera or IsValidThread(ActionCameraTurnOffThread) then return end
		local attacker, target, pos, lookat, preset = table.unpack(CurrentActionCamera)
		if unit == attacker and preset[unit.stance] ~= true and unit:CanBeControlled() then
			SetActionCamera(attacker, target)
		end
	end)
end

function KeepCurrentActionCamera(attacker, target)
	return CurrentActionCamera and CurrentActionCamera[1] == attacker and CurrentActionCamera[2] == target
end

MapVar("ActionCameraAutoRemoveThread", false)
local function WaitAutoRemoveActionCamera(sleep, ac_to_restore, interp_time, interp_time_end)
	if not interp_time_end then interp_time_end = interp_time end
	if IsValidThread(ActionCameraAutoRemoveThread) then
		ac_to_restore = false
	end

	DeleteThread(ActionCameraAutoRemoveThread)
	ActionCameraAutoRemoveThread = CreateGameTimeThread(function()
		local total_t = 0
		assert(CurrentActionCamera)
		while not CurrentActionCamera do
			--wait for it to boot?
			Sleep(100)
			total_t = total_t + 100
			if total_t >= 10000 then
				return --no ac to remove
			end
		end
		if CurrentActionCamera then
			CurrentActionCamera.autoremove = true
			if not sleep then
				CurrentActionCamera.wait_signal = true
			end
		end
	
		Sleep((sleep or 100) + (interp_time and interp_time or ac_interpolation_time))
		if CurrentActionCamera and CurrentActionCamera.wait_signal then
			WaitMsg("ActionCameraWaitSignalEnd", 5000)
		else
			Sleep(500)
		end
		ActionCameraAutoRemoveThread = false
		if CurrentActionCamera then
			if ac_to_restore then
				SetActionCamera(nil, nil, nil, nil, ac_to_restore, interp_time_end)
			else
				RemoveActionCamera(false, interp_time_end)
			end
		end
	end)
end

function SetActionCameraNoFallbackSync(attacker, target, disable_float, interpolation_time, no_rotate, preset_filter, dontActiveAC)
	local new_pos, new_lookat, preset, fallback = CalcActionCamera(attacker, target, nil, nil, no_rotate)
	--NetUpdateHash("SetActionCameraNoFallbackSync", new_pos, new_lookat, attacker, target, preset.id, fallback, dontActiveAC, no_rotate)
	if fallback then return false end
	if preset_filter and table.find(preset_filter, preset.id) then return false end
	
	assert(preset)
	if not preset then return end
	if not dontActiveAC then
		LocalACWillStartPlaying = (LocalACWillStartPlaying or 0) + 1
	end
	NetSyncEvents.SetActionCameraDirect(not dontActiveAC and netUniqueId, attacker, target, new_pos, new_lookat, preset and preset.id, disable_float, interpolation_time or ac_interpolation_time, true)
	return true
end


--[[function SetActionCameraDirectSync(attacker, target, new_pos, new_lookat, preset, disable_float, interpolation_time, vignette, ac_to_restore, dontActiveAC)
	assert(preset)
	if not preset then return end
	if not dontActiveAC then
		LocalACWillStartPlaying = (LocalACWillStartPlaying or 0) + 1
	end
	NetSyncEvents.SetActionCameraDirect(not dontActiveAC and netUniqueId, attacker, target, new_pos, new_lookat, preset and preset.id, disable_float, interpolation_time, vignette, ac_to_restore)
end]]

function SetAutoRemoveActionCamera(attacker, target, sleep, restore_prev_ac, interp_time, interp_time_end, no_wait, dontActiveAC)
	if GetInGameInterfaceModeDlg("IModeAIDebug") then
		return
	end
		
	local ac_to_restore
	if restore_prev_ac and CurrentActionCamera and not CurrentActionCamera.autoremove then
		ac_to_restore = CurrentActionCamera
	end
	local no_rotate = not attacker:IsLocalPlayerTeam()
	
	local foundCamera = SetActionCameraNoFallbackSync(attacker, target, "disable_float", interp_time, no_rotate, {"Z_HigherCamera"}, dontActiveAC)
	if not foundCamera then
		CinematicKillDebugPrint("Was going to play action camera, but found no suitable preset. Oh well.")
		--return -- no return so both clients sleep the same amount of time!
	end
	if not dontActiveAC and foundCamera then
		WaitAutoRemoveActionCamera(sleep, ac_to_restore, interp_time, interp_time_end)
	end
	
	
	if not no_wait then
		Sleep(ac_interpolation_time + ac_after_interpolation_idle)
	end
end

function ActionCameraShouldHideWindow(camera_pos, window)
	local attacker = CurrentActionCamera[1]
	local target = CurrentActionCamera[2]
	local a_pos = IsPoint(attacker) and attacker or attacker:GetSpotLoc(attacker:GetSpotBeginIndex("Head"))
	local window_bbox = window:GetObjectBBox()
	if ClipSegmentWithBox3D(camera_pos, a_pos, window_bbox) then
		return true
	end
	for _, spot in ipairs(target_spots) do
		local hasSpot = target:GetSpotBeginIndex(spot) ~= -1
		if not hasSpot then goto continue end
		local t_pos = GetActionCameraTargetPos(target, spot, attacker)
		if ClipSegmentWithBox3D(camera_pos, t_pos, window_bbox) then
			return true
		end
		::continue::
	end
	return false
end



local function lHidingMode_NoCMT(bHide)
	if bHide then
		StopAllHiding("ActionCamera", 0, 0)
		
		local camera_pos = CurrentActionCamera[3]
		local lookat = CurrentActionCamera[4]
		MapForEach(camera_pos, lookat, hide_nearby_objs_radius, hide_nearby_objs, const.efVisible, function(o)
			local hide = lIsActionCameraHideableObject(camera_pos, o)
			if hide then
				o:SetShadowOnlyImmediate(true)
				ActionCameraHiddenObjs[#ActionCameraHiddenObjs + 1] = o
			end
		end)
	else
		ResumeAllHiding("ActionCamera")

		for _, o in ipairs(ActionCameraHiddenObjs) do
			if IsValid(o) then
				o:SetShadowOnlyImmediate(false)
			end
		end
		ActionCameraHiddenObjs = {}
	end
end

local function lHidingMode_CMT(bHide)
	if bHide then
		local camera_pos = CurrentActionCamera[3]
		local lookat = CurrentActionCamera[4]
		MapForEach(camera_pos, lookat, hide_nearby_objs_radius, hide_nearby_objs, const.efVisible, function(o)
			local hide = lIsActionCameraHideableObject(camera_pos, o)
			if hide then
				o:SetShadowOnlyImmediate(true)
				ActionCameraHiddenObjs[#ActionCameraHiddenObjs + 1] = o
			end
		end)
	else
		for _, o in ipairs(ActionCameraHiddenObjs) do
			if IsValid(o) then
				o:SetShadowOnlyImmediate(false)
			end
		end
		ActionCameraHiddenObjs = {}
	end
end

local function lIsActionCameraHideableContourMode(cam_pos, o)
	-- Dont contour items that the CMT manages
	if IsContourObject(o) and o:GetGameFlags(const.gofContourInner) ~= 0 then return end
	if IsKindOf(o, "Unit") then return end
	if IsKindOf(o, "Slab") and o.floor == 1 then -- Dont hide slabs on the first floor (ground floor)
		return false
	end
	return true
end

local contour_hiding_parts_check = { "Torso", "Groin", "Head" }

local function lHidingMode_ContourAll(bHide)
	if bHide then
		StopAllHiding("ActionCamera", 0, 0)

		-- Get possibly visible units.
		local camera_pos = CurrentActionCamera[3]
		local targets = MapGet(camera_pos, CurrentActionCamera[4], hide_nearby_objs_radius, "Unit")
		
		-- Make sure all body parts of theirs are visible.
		for i, t in ipairs(targets) do
			for _, part in ipairs(contour_hiding_parts_check) do
				local lookat = t and GetActionCameraTargetPos(t, part)
				local parallels_src, parallels_tar = GetParallelSourceTargetPairs(camera_pos, lookat)
				if not lookat then goto continue end

				for i, src in ipairs(parallels_src) do
					local tar = parallels_tar[i]
					local objectsInWay = IntersectObjectsOnSegment(src, tar, const.efVisible)
					for i, o in ipairs(objectsInWay) do
						local hide = lIsActionCameraHideableContourMode(camera_pos, o)
						if hide then
							o:SetShadowOnlyImmediate(true)
							o:SetHierarchyGameFlags(const.gofContourInner)
							ActionCameraHiddenObjs[#ActionCameraHiddenObjs + 1] = o
						end
					end
				end
				::continue::
			end
		end
	else
		ResumeAllHiding("ActionCamera")
	
		for _, o in ipairs(ActionCameraHiddenObjs) do
			if IsValid(o) then
				o:SetShadowOnlyImmediate(false)
				o:ClearHierarchyGameFlags(const.gofContourInner)
			end
		end
		ActionCameraHiddenObjs = {}
	end
end

local hidingModeSwitch = {
	["CMT"] = lHidingMode_CMT,
	["NoCMT"] = lHidingMode_NoCMT,
	["ContourAll"] = lHidingMode_ContourAll,
}

function ActionCameraHiding(bHide, hidingMode)
	local func = hidingModeSwitch[hidingMode]
	if func then
		func(bHide)
	end
end


local parallel_src_target_pairs_deltas = {50, 60, 70, 80, 90, 100}
function GetParallelSourceTargetPairs(src, tar)
	local result_src = {src}
	local result_tar = {tar}
	local dir = tar - src
	local dir_x = dir:x()
	local dir_y = dir:y()
	local dir_z = dir:z()
	local orth_vector = point(-dir_y, dir_x, 0)
	local dir_orth_vectors = {}
	for i = 1, 6 do
		dir_orth_vectors[i] = RotateAxis(orth_vector, dir, i * 60 * 60)
	end
	local s, t
	for _, v in ipairs(dir_orth_vectors) do
		for _, d in ipairs(parallel_src_target_pairs_deltas) do
			v = SetLen(v, d)
			s = src + v
			t = tar + v
			result_src[#result_src + 1] = s
			result_tar[#result_tar + 1] = t
		end
	end
	return result_src, result_tar
end

local query_flags = const.cqfSorted | const.cqfResultIfStartInside | const.cqfFrontAndBack
function CalcSrcTarObstacles(src, tar, obstacles, ignore_min_dist, is_tar)
	local result, inter_pt
	local dir = tar - src
	collision.Collide(src, point(100, 100, 20), 100, dir, query_flags, 0, -1, function(obj, idx, param)
		if VisionCollisionFilter(obj) and not lIsActionCameraHideableObject(src, obj) then
			result = obj
			inter_pt = src + SetLen(dir, MulDivRound(dir:Len(), param * 10000, 10000))
			return true
		end
	end)

	if result and obstacles then
		if not ignore_min_dist then
			local closest_dist = src:Dist(inter_pt)
			obstacles.min_dist = (closest_dist < obstacles.min_dist) and closest_dist or obstacles.min_dist
		end
		obstacles[#obstacles + 1] = src
		if is_tar and obstacles["target_visible"] then
			obstacles["target_visible"] = false
		end
	end
end

function GetActionCameraObstacles(camera_pos, target, attacker)
	if camera_pos:z() - terrain.GetHeight(camera_pos) < guim then
		return false
	end
	local obstacles = {min_dist = max_int}
	local t_pos
	local s_pos = GetActionCameraTargetPos(attacker, "Torso")
	CalcSrcTarObstacles(camera_pos, s_pos, obstacles)
	
	obstacles["target_visible"] = true
	for _, spot in ipairs(target_spots) do
		local hasSpot = target:GetSpotBeginIndex(spot) ~= -1
		if not hasSpot then goto continue end
		
		t_pos = GetActionCameraTargetPos(target, spot, attacker)
		CalcSrcTarObstacles(camera_pos, t_pos, obstacles, nil, true)
		for _, unit in ipairs(g_Units) do
			if unit ~= target and unit ~= attacker and ClipSegmentWithBox3D(camera_pos, t_pos, unit) then
				obstacles[#obstacles + 1] = unit
				obstacles["target_visible"] = false
			end
		end
		::continue::
	end
	return obstacles
end

function ActionCameraUpdateUIVisibility()
	local dlg = GetInGameInterfaceModeDlg()
	local menu = dlg and dlg:ResolveId("idMenu")
	if not menu then return end
	menu:SetVisible(not CurrentActionCamera and not CheatEnabled("CombatUIHidden"))
end

function ShowActionCameraVignette(bShow, force)
	local time = not force and ac_interpolation_time or 0
	if bShow then
		hr.EnablePostProcVignette = 1
		SetSceneParamColor(1, "VignetteTintColor", ac_vignette_color, time, 0)
	else
		hr.EnablePostProcVignette = EngineOptions.Vignette == "On" and 1 or 0
		if CurrentLightmodel and CurrentLightmodel[1] then
			SetSceneParamColor(1, "VignetteTintColor", CurrentLightmodel[1].vignette_tint_color, time, 0)
		end
	end
end

function ZoomActionCamera()
	local cam = CurrentActionCamera
	assert(cam)

	local pos, lookat, target_pos = CurrentActionCamera[3], CurrentActionCamera[4], CurrentActionCamera[2]:GetPos()
	if not target_pos:IsValidZ() then
		target_pos = target_pos:SetTerrainZ(500)
	end
	-- Zoom in along the camera-target line. Action camera logic should have
	-- ensured that there is no blocking objects along it.
	local zoomAmount = guim * 15
	local vecTargetCamera = target_pos - pos
	local length = vecTargetCamera:Len()
	if length < zoomAmount then -- Camera is already close, change zoom to % of length.
		zoomAmount = MulDivRound(length, 100, 1000)
	end
	if zoomAmount < guim * 2 then
		return
	end

	if ActionCameraFloatThread then
		DeleteThread(ActionCameraFloatThread)
		ActionCameraFloatThread = false
	end

	if ActionCameraInterpolationThread then
		DeleteThread(ActionCameraInterpolationThread)
		ActionCameraInterpolationThread = false
	end

	local zoomed_pos = target_pos - SetLen(vecTargetCamera, zoomAmount)
	cameraTac.SetCamera(zoomed_pos, target_pos, zoom_interpolation_time)
end

-- test action camera
DefineClass.ActionCameraTestDummy =
{
	__parents = { "Object", "EditorVisibleObject", "EditorTextObject" },
	
	flags = { gofWhiteColored = true },
	editor_text_offset = point(0,0,2*guim),
}

function ActionCameraTestDummy:Init()
	self:EditorTextUpdate(true)
	local other_dummies = MapGet("map", self.class)
	if #(other_dummies or "") > 1 then
		for _, obj in ipairs(other_dummies) do
			if obj ~= self then
				DoneObject(obj)
			end
		end
		print("only one object of this class should exist: ", self.class)
	end
end

DefineClass.ActionCameraTestDummy_Player =
{
	__parents = { "ActionCameraTestDummy" },
	entity = "Female",
}

DefineClass.ActionCameraTestDummy_Enemy =
{
	__parents = { "ActionCameraTestDummy" },
	entity = "Male",
}

local l_cycle_right_left = 0
function ExecTestActionCamera(def)
	local attacker = MapGetFirst("map", "ActionCameraTestDummy_Player")
	local target = MapGetFirst("map", "ActionCameraTestDummy_Enemy")
	
	if not attacker or not target then
		CreateMessageBox(nil, T(634182240966, "Error"), T(626828916856, "ActionCameraTestDummy_Player or ActionCameraTestDummy_Target do not exist on the map"))
		return
	end
	
	local valid_cameras, all_cameras = {}, {}
	AddActionCameraForPreset(attacker, target, def, valid_cameras, all_cameras)
	
	local new_pos, new_lookat = all_cameras[l_cycle_right_left+1][1], all_cameras[l_cycle_right_left+1][2]
	SetCamera(new_pos, new_lookat, nil, 1000, nil, def.FovX)
	l_cycle_right_left = (l_cycle_right_left + 1) % 2

	if def.DOFStrengthFar > 0 or def.DOFStrengthNear > 0 then
		def:SetDOFParams(0, attacker, target)
	end
end

function WaitActionCamDonePlayingSync(timeout)
	while ActionCameraPlaying do
		WaitMsg("ActionCameraRemoved", timeout or 100)
	end
end