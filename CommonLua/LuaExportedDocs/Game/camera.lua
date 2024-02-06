--- Camera control functions.
-- The engine supports different camera controllers, each possibly having a different Lua interface.
-- There are several general functions that work for all cameras - these are Lock, Unlock, IsLocked and GetPos.
-- The different cameras are activated by calling the 'Activate' functions of the camera namespace, e.g. 'CameraRTS.Activate()'.
-- The only other function present in each specific camera is 'IsActive'.
-- The camera specific for each game should be activated in 'gameautorun.lua'.
 
--- Returns the camera position.
-- @cstyle point camera.GetPos().
-- @return point.

function camera.GetPos()
end

--- Returns the camera position.
-- @cstyle point camera.GetEye().
-- @return point.

function camera.GetEye()
end

--- Returns the camera yaw in minutes.
-- @cstyle int camera.GetYaw().
-- @return int.

function camera.GetYaw()
end

--- Returns the camera pitch in minutes.
-- @cstyle int camera.GetPitch().
-- @return int.

function camera.GetPitch()
end

--- Returns the direction of the camera is looking.
-- @cstyle point camera.GetDirection().
-- @return point.

function camera.GetDirection()
end

--- Disallows camera movement.
-- @cstyle void camera.Lock().
-- @return void.

function camera.Lock(view)
end

--- Allows camera movement.
-- @cstyle void camera.Unlock().
-- @return void.

function camera.Unlock(view)
end

--- Returns if the camera can move.
-- @cstyle bool camera.IsLocked().
-- @return bool.

function camera.IsLocked(view)
end

--- Returns the terrain area observed by the camera (a trapeze).
-- @cstyle pt, pt, pt, pt camera.GetViewArea().
-- @return pt, pt, pt, pt. The four corners of the camera trapeze: left_top, right_top, right_bottom, left_bottom

function camera.GetViewArea()
end

--- Activates the fly the camera.
-- @cstyle void cameraFly.Activate(view).
-- @return void.

function cameraFly.Activate(view)
end

--- Returns if the camera is active.
-- @cstyle bool camera.IsActive().
-- @return bool.

function cameraFly.IsActive()
end

--- Set camera position and 'look at' point instantly.
-- @cstyle void cameraFly.SetCamera(point pos, point look_at).
-- @param pos point; new position of the camera.
-- @param look_at point; new look-at point of the camera.
-- @return void.
function cameraFly.SetCamera(pos, look_at)
end

--- Disables the change of s_CameraFly_LeftStickMovesFlat/s_CameraFly_RightStickYMovesUpDown when LT-B/RT-B is pressed.
-- @cstyle void cameraFly.DisableStickMovesChange().
-- @return void.
function cameraFly.DisableStickMovesChange()
end

--- Enables the change of s_CameraFly_LeftStickMovesFlat/s_CameraFly_RightStickYMovesUpDown when LT-B/RT-B is pressed.
-- @cstyle void cameraFly.EnableStickMovesChange().
-- @return void.
function cameraFly.EnableStickMovesChange()
end

--- Activates the 3rd person camera.
-- @cstyle void camera3p.Activate(view).
-- @return void.

function camera3p.Activate(view)
end

--- Returns if the 3rd person camera is active.
-- @cstyle bool camera3p.IsActive().
-- @return bool.

function camera3p.IsActive()
end

--- Changes the camera 'look at' position smoothly for the specified time.
-- @cstyle void camera3p.SetLookAt(point lookat_pos, int time).
-- @param lookat_pos point.
-- @param time int.
-- @return void.

function camera3p.SetLookAt(lookat_pos, time)
end

--- Changes the camera 'look at' position smoothly for the specified time; the position is in x10 resolution.
-- @cstyle void camera3p.SetLookAtPrecise(point lookat_pos, int time).
-- @param lookat_pos point.
-- @param time int.
-- @return void.

function camera3p.SetLookAtPrecise(lookat_pos, time)
end

--- Returns the camera 'look at' position.
-- @cstyle point camera3p.GetLookAt().
-- @return point.

function camera3p.GetLookAt()
end

--- Changes the position of the camera smoothly for the specified time.
-- @cstyle void camera3p.SetEye(point eye_pos, int time).
-- @param eye_pos point.
-- @param time int.
-- @return void.

function camera3p.SetEye(eye_pos, time)
end

--- Changes the position of the camera smoothly for the specified time; the position is in x10 resolution.
-- @cstyle void camera3p.SetEyePrecise(point eye_pos, int time).
-- @param eye_pos point.
-- @param time int.
-- @return void.

function camera3p.SetEyePrecise(eye_pos, time)
end

--- Returns the camera position.
-- @cstyle point camera3p.GetEye().
-- @return point.

function camera3p.GetEye()
end

--- Changes the roll of the camera smoothly for the specified time.
-- @cstyle void camera3p.SetRoll(int roll, int time).
-- @param roll int angle in minutes.
-- @param time int.
-- @return void.

function camera3p.SetRoll(roll, time)
end

--- Returns the camera roll in minutes.
-- @cstyle int camera3p.GetRoll().
-- @return int.

function camera3p.GetRoll()
end

--- Returns the camera yaw in minutes.
-- @cstyle int camera3p.GetYaw().
-- @return int.

function camera3p.GetYaw()
end


--- Returns the camera pitch in minutes.
-- @cstyle int camera3p.GetPitch().
-- @return int.

function camera3p.GetPitch()
end

--- Changes the offset of the camera 'look at' position smoothly for the specified REAL time;.
-- the offset is added to the position set by SetLookAt to calculate the final camera 'look at' position.
-- @cstyle void camera3p.SetLookAtOffset(point lookat_pos_offset, int time).
-- @usage The offsets members are intended for use in camera effects which are independent on the main camera logic(see camera shake).
-- @param lookat_pos_offset point.
-- @param time int.
-- @return void.

function camera3p.SetLookAtOffset(lookat_pos_offset, time)
end

--- Returns the offset of the camera 'look at' position.
-- @cstyle point camera3p.GetEye().
-- @return point.

function camera3p.GetLookAtOffset()
end

--- Changes the offset of the camera position smoothly for the specified time;.
-- the offset is added to the position set by SetEye to calculate the final camera eye position.
-- @cstyle void camera3p.SetLookAtOffset(point eye_offset, int time).
-- @usage The offsets members are intended for use in camera effects which are independent on the main camera logic(see camera shake).
-- @param eye_offset point.
-- @param time int.
-- @return void.

function camera3p.SetEyeOffset(eye_offset, time)
end

--- Returns the offset of the camera position.
-- @cstyle point camera3p.GetEye().
-- @return point.

function camera3p.GetEyeOffset()
end

--- Changes the offset of the camera roll smoothly for the specified REAL time;.
-- the offset is added to the value set by SetRoll to calculate the final camera roll angle.
-- @cstyle void camera3p.SetRollOffset(int roll_offset, int time).
-- @usage The offsets members are intended for use in camera effects which are independent on the main camera logic(see camera shake).
-- @param roll_offset int angle in minutes.
-- @param time int.
-- @return void.

function camera3p.SetRollOffset(roll_offset, time)
end

--- Returns the offset of the camera roll in minutes.
-- @cstyle int camera3p.GetEye().
-- @return int.
function camera3p.GetRollOffset()
end

--- Activates the RTS camera.
-- @cstyle void cameraRTS.Activate(view).
-- @return void.

function cameraRTS.Activate(view)
end

--- Returns whether the RTS camera is active.
-- @cstyle bool cameraRTS.IsActive().
-- @return bool.

function cameraRTS.IsActive()
end

--- Sets camera properties from a given table; the table may contain the following fields.
-- MinHeight, MaxHeight - sets the min and max height of the camera.
-- HeightInertia - the larger the number, the faster the camera height comes to rest when changed.
-- MoveSpeedNormal, MoveSpeedFast - normal and fast camera movement speed; fast is used when Ctrl is pressed.
-- RotateSpeed - the camera rotation speed.
-- LookatDist - 2D distance from the camera position to the 'look at' point.
-- CameraYawRestore - 0 to toogle yaw restore off, 1 to toggle it on.
-- UpDownSpeed - the speed the camera moves vertically.
-- @cstyle void cameraRTS.SetProperties(view, table prop).
-- @return void.

function cameraRTS.SetProperties(view, prop)
end

--- Set the YawRestore flag of the camera.
-- @cstyle void cameraRTS.SetYawRestore(bool bRestore).
-- @param bRestore bool true to enable or false to disable.
-- @return void.

function cameraRTS.SetYawRestore(bRestore)
end

--- Return current YawRestore flag of the camera.
-- @cstyle bool cameraRTS.GetYawRestore().
-- @return bool.

function cameraRTS.GetYawRestore()
end

--- Set camera position and orientation instantly or gradually over time; gradual transition requires the camera to be locked beforehand.
-- @cstyle void SetCamera(point pos, point lookat, int time).
-- @param pos point new position of the camera.
-- @param lookat point new look-at point of the camera.
-- @param time int (optional) time for adjusting the camera to the new position and look-at point.
-- @param easingType string the type of easing to use (see list in const.Easing: Linear, SinIn, SinOut, SinInOut, CubicIn, CubicOut, CubicInOut, QuinticIn, QuinticOut, QuinticInOut, etc.)
-- @return void.

function cameraRTS.SetCamera(pos, lookat, time, easingType)
end

--- Set PRECISELY camera position and orientation instantly or gradually over time; gradual transition requires the camera to be locked beforehand. Precisely means that position and orientation are multiplied by 1000 for some interpolation reasons(like in the camera editor rendering). The parameters are divided by 1000 right before setting them in the engine.
-- @cstyle void SetCameraPrecise(point pos, point lookat, int time).
-- @param pos; new precise(*1000) position of the camera.
-- @param lookat; new precise(*1000) look-at point of the camera.
-- @param time int (optional) time for adjusting the camera to the new position and look-at point.
-- @return void.

function cameraRTS.SetCameraPrecise(pos, lookat, time)
end

--- Returns camera position and 'look at' point.
-- @cstyle point,point cameraRTS.GetPosLookAt().
-- @return point,point.

function cameraRTS.GetPosLookAt()
end

--- Returns camera position.
-- @cstyle point cameraRTS.GetPos().
-- @return point.

function cameraRTS.GetPos()
end

--- Returns camera 'look at' point.
-- @cstyle point GetLookAt().
-- @return point.

function cameraRTS.GetLookAt()
end

--- Sets mouse invertion for camera rotation; independent for x and y.
-- @cstyle void InvertMouse(bool inv_x, bool inv_y).
-- @param inv_x bool.
-- @param inv_y bool.
-- @return void.

function cameraRTS.InvertMouse(inv_x, inv_y)
end

--- Returns the camera minimal and maximal pitch above the ground.
-- @cstyle int, int GetPitchInterval().
-- @return int, int; minimal and maximal pitch.

function cameraRTS.GetPitchInterval()
end

--- Returns the camera current height above the 'look at' position.
-- @cstyle int GetHeight().
-- @return int.
function cameraRTS.GetHeight()
end

--- Returns the camera current look at ditance.
-- @cstyle int GetLookatDist().
-- @return int.
function cameraRTS.GetLookatDist()
end

--- Returns the camera yaw in degrees (the angle around the vertical axis).
-- @cstyle int GetYaw().
-- @return int.

function cameraRTS.GetYaw()
end

--- Returns the current zoom
-- @cstyle int GetZoom().
-- @return int; curent zoom value
function cameraRTS.GetZoom()
end

--- Changes the current zoom
-- @cstyle void SetZoom(int zoom, int time).
-- @param zoom int.
-- @param time int.
-- @return void.
function cameraRTS.SetZoom()
end

--- Activates the 3D Studio MAX camera.
-- @cstyle void cameraMax.Activate(view).
-- @return void.

function cameraMax.Activate(view)
end

--- Returns if the 3D Studio MAX camera is active.
-- @cstyle bool cameraMax.IsActive().
-- @return bool.

function cameraMax.IsActive()
end

--- Set camera position and 'look at' point instantly.
-- @cstyle void cameraMax.SetCamera(point pos, point look_at).
-- @param pos point; new position of the camera.
-- @param look_at point; new look-at point of the camera.
-- @return void.
function cameraMax.SetCamera(pos, look_at)
end
