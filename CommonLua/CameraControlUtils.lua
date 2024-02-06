function GetCameraEyeOverTerrain(EyePt, LookAtPt)
	local height = GetWalkableZ(EyePt)+const.CameraMinTerrainDist
	local EyePt = EyePt
	if height > EyePt:z() then
		EyePt = EyePt:SetZ(height)
	end
	return EyePt, LookAtPt
end

--- Moves camera look at and eye pos smoothly over the given period of time.
-- @cstyle int MoveCamera(function get_look_at, function get_eye, int time);
-- @param get_look_at function; a callback function that receives time as parameter and returns the camera look at position; the callback function is called every 33ms.
-- @param get_eye function; a callback function that receives time and look at position as parameter and returns the camera eye position; the callback function is called every 33ms.
-- @param time int.
-- @return int; orientation in minutes.

function MoveCamera(get_look_at, get_eye, time)
	if not camera3p.IsActive() then
		return
	end
	local sleep = 33
	local time_from_start = 0
	while true do
		local time_to_end = time - time_from_start
		local sleep_time = Min(sleep, time - time_from_start)
		local target_time = Min(time_from_start+sleep_time, time)

		local look_at = get_look_at(target_time)
		local eye     = get_eye    (look_at, target_time)
		eye = GetCameraEyeOverTerrain(eye, look_at)
		camera3p.SetLookAt(look_at, sleep_time)
		camera3p.SetEye   (eye    , sleep_time)
		if sleep_time > 0 then
			Sleep(sleep_time)
		end
		if not camera3p.IsActive() then
			return
		end
		time_from_start = time_from_start + sleep_time
		if time_from_start >= time then
			break
		end
	end
end

--- Return a callback function that is to be used as get_look_at parameter of MoveCamera function.
-- The callback will move the current look at position from the camera current look at postion to the target_pos.
-- 'observing' the target object's movement - the farther the target moves from his start position, the farther.
-- the camera look at will move away from its initial position and will approach the target_pos.
-- @cstyle function LookAtFollowCharacter(object target, point target_pos, int total_time).
-- @param target object.
-- @param target_pos point.
-- @param total_time int.
-- @return function.
function LookAtFollowCharacter(target, target_pos, total_time)
	if not camera3p.IsActive() then
		return
	end
	local start_pt = camera3p.GetLookAt()
	local last_dist = 0
	local max_dist = start_pt:Dist(target_pos)
	local pos_lerp = ValueLerp(start_pt, target_pos, max_dist)
	local height_lerp = ValueLerp(start_pt:z(), target_pos:z(), total_time)
	local last_pos
	return function(time)
		if IsValid(target) then
			local pos = GetPosFromPosSpot(target)
			local dist = Min(pos:Dist(start_pt), max_dist)
			if dist > last_dist then
				last_dist = dist
			end
		end
		return pos_lerp(last_dist):SetZ(height_lerp(time))
	end
end

--- Return a callback function that is to be used as get_eye parameter of MoveCamera function.
-- The callback will move smoothly the camera eye's z to the targetz, rotate the camera to the target_yaw, keeping the 2d distance from the eye to the look at to dist_eye_look_at.
-- @cstyle function RotateKeepDistEye(int target_eyez, int target_yaw, point dist_eye_look_at, int total_time).
-- @param target_eyez int.
-- @param target_yaw int.
-- @param dist_eye_look_at int.
-- @param total_time int.
-- @return function.
function RotateKeepDistEye(target_eyez, target_yaw, dist_eye_look_at, total_time)
	local pt = point(-dist_eye_look_at, 0, 0)
	local angle_lerp = AngleLerp(camera.GetYaw(), target_yaw, total_time)
	local eye_height_lerp = ValueLerp(camera.GetEye():z(), target_eyez, total_time)
	return function(look_at_pos, time)
		local eye = look_at_pos + Rotate(pt, angle_lerp(time))
		eye = eye:SetZ(eye_height_lerp(time))
		return eye
	end
end

--- This function will smoothly move/rotate the camera according the given parameters, mimicking the XCamera default behavior.
-- @cstyle void DefMoveCamera(point pos, int yaw, int pitch, int rot_speed, int move_speed, int move_time, int yaw_time, int pitch_time).
-- @param pos point; target camera look at position.
-- @param yaw int; targer camera yaw.
-- @param pitch int; target camera pitch.
-- @param rot_speed int; camera rotation speed in angular minutes per sec; can be omitted; used to calculate move_time in case move_time is omitted.
-- @param move_speed int; camera movement speed in angular minutes per sec; can be omitted; used to calculate yaw_time and pitch_time in case yaw_time or pitch_time are omitted.
-- @param move_time int; the time the camera should reach the target position; if omitted the time will be calculated from move_speed parameter.
-- @param yaw_time int; the time the camera should reach the target yaw; if omitted the time will be calculated from rot_speed parameter.
-- @param pitch_time int; the time the camera should reach the target position; if omitted the time will be calculated from rot_speed parameter.
-- @return void.
function DefMoveCamera(pos, yaw, dist_scale, pitch, rot_speed, move_speed, move_time, yaw_time, pitch_time)
	if not camera3p.IsActive() then
		return
	end
	if not pos:IsValidZ() then
		pos = pos:SetTerrainZ()
	end
	local start_look_at, start_pitch, start_yaw = camera3p.GetLookAt(), camera3p.GetPitch(), camera3p.GetYaw()
	local look_at_height_offset = (const.CameraScale*const.CameraVerticalOffset/100)*dist_scale/100

	rot_speed = rot_speed or const.CameraRotationDegreePerSec
	move_speed = move_speed or const.CameraResetMmPerSec
	
	local pitch_time	= pitch_time or abs(AngleDiff(start_pitch, pitch)/60)*1000/rot_speed
	local yaw_time		= yaw_time or abs(AngleDiff(start_yaw, yaw)/60)*1000/rot_speed
	local move_time		= move_time or pos:Dist(start_look_at)*1000/move_speed
	local yaw_lerp = AngleLerp(start_yaw, yaw, yaw_time, true)
	local pos_lerp = ValueLerp(start_look_at, pos:SetZ(look_at_height_offset + (pos:z() or terrain.GetHeight(pos))), move_time, true)
	local start_l, start_h = GetCameraLH(start_pitch, camera3p.DistanceAtPitch(start_pitch) * dist_scale / 100)
	local end_l  , end_h   = GetCameraLH(      pitch, camera3p.DistanceAtPitch(      pitch) * dist_scale / 100)
	
	local l_lerp, h_lerp = ValueLerp(start_l, end_l, pitch_time, true), ValueLerp(start_h, end_h, pitch_time, true)
	
	
	local function LookAt(t)
		return pos_lerp(t)
	end
	
	local function EyePt(look_at, t)
		local yaw = yaw_lerp(t)
		local l, h = l_lerp(t), h_lerp(t)

		local eye = (look_at+Rotate(point(-l, 0, 0), yaw)):SetZ(h+look_at:z())
		return eye
	end
	
	MoveCamera(LookAt, EyePt, Max(pitch_time, yaw_time, move_time))
end
