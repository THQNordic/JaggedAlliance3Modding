function CanOpenPhotoMode()
	if gv_SatelliteView then return "disabled" end
	if GetDialog("ConversationDialog") then return "disabled" end
	if GetDialog("ModifyWeaponDlg") then return "disabled" end
	if GetDialog("CoopMercsManagement") then return "disabled" end
	return "enabled"
end

function PhotoModeDialogOpen()
    OpenDialog("PhotoMode")
	PhotoModeObj:ToggleFrame() -- This should be called after the dialog is opened
end

function OnMsg.InGameMenuOpen()
	CloseDialog("PhotoMode")
end

function OnMsg.PhotoModeEnd()
	SetCamera(unpack_params(PhotoModeObj.prev_camera))
	UnlockCamera("PhotoModeFlyCamera")
	cameraTac.Activate()
end

function OnMsg.PhotoModeFreeCameraActivated()
	local dlg = GetDialog("PhotoMode")
	if dlg then
		dlg.idScrollArea.LeftThumbScroll = false
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
		dlg.idScrollArea.LeftThumbScroll = true
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

function OnMsg.PhotoModePropertyChanged()
	local pm = GetDialog("PhotoMode")
	if pm and pm.areValuesDefault then
		pm.areValuesDefault = false
		pm.idActionBar:RespawnContent()
	end
end


function PhotoModeObject:AreValuesDefault()
	local pm = GetDialog("PhotoMode")
	if pm then
		for i, prop in ipairs(self:GetProperties()) do
			local default
			if(prop.id == "fogDensity") then
				default = CurrentLightmodel[1].fog_density
			elseif(prop.id == "bloomStrength") then
				default = CurrentLightmodel[1].pp_bloom_strength
			elseif(prop.id == "exposure") then
				default = CurrentLightmodel[1].exposure
			elseif(prop.id == "ae_key_bias") then
				default = CurrentLightmodel[1].ae_key_bias
			elseif(prop.id == "colorSat") then
				default = -CurrentLightmodel[1].desaturation
			elseif(prop.id == "vignette") then
				default = CurrentLightmodel[1].vignette_darken_opacity
			else
				default = prop.default
			end
			
			if not (self:GetProperty(prop.id) == default or self:GetProperty(prop.id) == nil) then
				return false
			end
		end
	end
	return true
end

function OnMsg.CanSaveGameQuery(query)
	if g_PhotoMode then 
		query.photoMode = true
	end
end
