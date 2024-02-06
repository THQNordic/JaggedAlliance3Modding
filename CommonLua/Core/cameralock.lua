if FirstLoad then
	s_CameraLockReasons = {}
	s_CameraUnlockReasons = {}
end

function LockCamera(reason)
	local locked = IsCameraLocked()
	s_CameraLockReasons[reason or false] = true
	UpdateCameraLock()
	if locked ~= IsCameraLocked() then
		Msg("OnLockCamera")
	end
end

function UnlockCamera(reason)
	s_CameraLockReasons[reason or false] = nil
	UpdateCameraLock()
end

function ForceUnlockCameraStart(reason)
	s_CameraUnlockReasons[reason or false] = true
	UpdateCameraLock()
end

function ForceUnlockCameraEnd(reason)
	s_CameraUnlockReasons[reason or false] = nil
	UpdateCameraLock()
end

function OnMsg.ChangeMap()
	s_CameraLockReasons = {}
	s_CameraUnlockReasons = {}
	UpdateCameraLock()
end

function UpdateCameraLock()
	if next(s_CameraUnlockReasons) or next(s_CameraLockReasons) == nil then
		camera.Unlock(1)
	else
		camera.Lock(1)
	end
end

function IsCameraLocked(reason)
	if not reason then
		return next(s_CameraLockReasons) ~= nil 
	end
	for r, _ in pairs(s_CameraLockReasons) do
		if r == reason then
			return true
		end
	end
	return false
end

function OnMsg.OnLockCamera() -- free mouse when locking camera (ex. don't leave unresponsive game state when opening a dialog during camera rotation)
	SetMouseDeltaMode(false)
end

local function _PrintCameraLockReasons(reasons, print_func, indent)
	print_func = print_func or print
	for reason in pairs(reasons) do
		print_func(indent, type(reason) == "table" and reason.class or tostring(reason))
	end
end

function OnMsg.BugReportStart(print_func)
	if next(s_CameraLockReasons) ~= nil then
		print_func("Active camera lock reasons:")
		_PrintCameraLockReasons(s_CameraLockReasons, print_func, "\t")
		print_func("")
	end
	if next(s_CameraUnlockReasons) ~= nil then
		print_func("Active camera unlock reasons:")
		_PrintCameraLockReasons(s_CameraUnlockReasons, print_func, "\t")
		print_func("")
	end
end