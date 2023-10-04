function CanOpenPhotoMode()
	if gv_SatelliteView then return "disabled" end
	if GetDialog("ConversationDialog") then return "disabled" end
	if GetDialog("ModifyWeaponDlg") then return "disabled" end
	return "enabled"
end

function PhotoModeDialogOpen()
    OpenDialog("PhotoMode")
end

function StartPhotoMode()
	--g_PrePhotoModeStoredVisuals = {}
	PhotoModeBegin()
	PhotoModeDialogOpen()
end

function OnMsg.InGameMenuOpen()
	CloseDialog("PhotoMode")
end

function OnMsg.PhotoModeEnd()
	SetCamera(unpack_params(PhotoModeObj.prev_camera))
	PhotoModeObj.freeCamera = false
	UnlockCamera("PhotoModeFlyCamera")
	cameraTac.Activate()
end

function OnMsg.PhotoModeFreeCameraActivated()
	local dlg = GetDialog("PhotoMode")
	if dlg then
		dlg:ResolveId("idContent"):ResolveId("idList").LeftThumbScroll = false
		dlg.isCameraUnlocked = true
		dlg.idFreeCameraWarning:SetVisible(true)
	end
	table.change(hr, "photo_mode_free_camera", {
		CameraFlyRightStickYMovesUpDown = false,
	})
	UnlockCamera("PhotoModeFlyCamera")
end

function OnMsg.PhotoModeFreeCameraDeactivated()
	local dlg = GetDialog("PhotoMode")
	if dlg then
		dlg:ResolveId("idContent"):ResolveId("idList").LeftThumbScroll = true
		dlg.isCameraUnlocked = false
		dlg.idFreeCameraWarning:SetVisible(false)
	end
	table.restore(hr, "photo_mode_free_camera")
	LockCamera("PhotoModeFlyCamera")
	local fov = PhotoModeObj and PhotoModeObj.fov
	if fov then
		camera.SetAutoFovX(1, 0, fov, 16, 9)
	end
end

function OnMsg.PhotoModeScreenshotTaken(file_path)
	local dlg = GetDialog("PhotoMode")
	if dlg and dlg.window_state ~= "destroying" then
		dlg:BlinkFilePath(file_path)
	end
end

function PhotoModeGetPropStep(gamepad_val, mouse_val)
	return GetUIStyleGamepad() and gamepad_val or mouse_val
end

function OnMsg.GamepadUIStyleChanged()
	local photo_mode = g_PhotoMode and GetDialog("PhotoMode")
	if not photo_mode then return end
	
	photo_mode:CallOnModeChange()
	if GetUIStyleGamepad() and cameraFly.IsActive() then
		UnlockCamera("PhotoModeFlyCamera")
	end
end
