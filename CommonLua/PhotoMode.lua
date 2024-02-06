if FirstLoad then
	g_PhotoMode = false
	PhotoModeObj = false

	-- Used in PP_Rebuild
	g_PhotoFilter = false 
	g_PhotoFilterData = false
end

function PhotoModeDialogOpen() -- override in project
	OpenDialog("PhotoMode")
end

local function ActivateFreeCamera()
	Msg("PhotoModeFreeCameraActivated")
	--table.change(hr, "FreeCamera", { FarZ = 1500000 })
	local _, _, camType, zoom, properties, fov = GetCamera()
	PhotoModeObj.initialCamera = {
		camType = camType,
		zoom = zoom,
		properties = properties,
		fov = fov
	}
	cameraFly.Activate(1)
	cameraFly.DisableStickMovesChange()
	if g_MouseConnected then
		SetMouseDeltaMode(true)
	end
end

local function DeactivateFreeCamera()
	if g_MouseConnected then
		SetMouseDeltaMode(false)
	end
	cameraFly.EnableStickMovesChange()
	local current_pos, current_look_at = GetCamera()
	if config.PhotoMode_FreeCameraPositionChange then
		SetCamera(current_pos, current_look_at, PhotoModeObj.initialCamera.camType, PhotoModeObj.initialCamera.zoom, PhotoModeObj.initialCamera.properties, PhotoModeObj.initialCamera.fov)
	end
	PhotoModeObj.initialCamera = false
	Msg("PhotoModeFreeCameraDeactivated")
end

function PhotoModeEnd()
	if PhotoModeObj then
		CreateMapRealTimeThread(function()
			PhotoModeObj:Save()
		end)
	end
	if g_PhotoFilter and g_PhotoFilter.deactivate then
		g_PhotoFilter.deactivate(g_PhotoFilter.filter, g_PhotoFilterData)
	end
	g_PhotoMode = false
	g_PhotoFilter = false
	g_PhotoFilterData = false
	--restore from initial values
	table.restore(hr, "photo_mode")
	--rebuild the postprocess
	PP_Rebuild()
	--restore lightmodel
	SetLightmodel(1, PhotoModeObj.preStoredVisuals.lightmodel, 0)
	table.insert(PhotoModeObj.preStoredVisuals.dof_params, 0)
	SetDOFParams(unpack_params(PhotoModeObj.preStoredVisuals.dof_params))
	SetGradingLUT(1, ResourceManager.GetResourceID(PhotoModeObj.preStoredVisuals.LUT:GetResourcePath()), 0, 0)
	Msg("PhotoModeEnd")
end

function PhotoModeApply(pm_object, prop_id)
	if prop_id == "filter" then
		if g_PhotoFilter and g_PhotoFilter.deactivate then
			g_PhotoFilter.deactivate(g_PhotoFilter.filter, g_PhotoFilterData)
		end
		local filter = PhotoFilterPresetMap[pm_object.filter]
		if filter and filter.shader_file ~= "" then
			g_PhotoFilterData = {}
			if filter.activate then
				filter.activate(filter, g_PhotoFilterData)
			end
			g_PhotoFilter = filter:GetShaderDescriptor()
		else
			g_PhotoFilter = false
			g_PhotoFilterData = false
		end
		if not filter then
			pm_object:SetProperty("filter", pm_object.filter) --revert to default filter
		end
		PP_Rebuild()
	elseif prop_id == "fogDensity" then
		SetSceneParam(1, "FogGlobalDensity", pm_object.fogDensity, 0, 0)
	elseif prop_id == "bloomStrength" then
		SetSceneParamVector(1, "Bloom", 0, pm_object.bloomStrength, 0, 0)
	elseif prop_id == "exposure" then
		SetSceneParam(1, "GlobalExposure",  pm_object.exposure, 0, 0)
	elseif prop_id == "ae_key_bias" then
		SetSceneParam(1, "AutoExposureKeyBias",  pm_object.ae_key_bias, 0, 0)
	elseif prop_id == "vignette" then
		SetSceneParamFloat(1, "VignetteDarkenOpacity", (1.0 * pm_object.vignette) / pm_object:GetPropertyMetadata("vignette").scale, 0, 0)
	elseif prop_id == "colorSat" then
		SetSceneParam(1, "Desaturation", -pm_object.colorSat, 0, 0)
	elseif prop_id == "depthOfField" or prop_id == "focusDepth" or prop_id == "defocusStrength" then
		local detail = 3
		local focus_depth = Lerp(hr.NearZ, hr.FarZ, pm_object.focusDepth ^ detail, 100 ^ detail)
		local dof = Lerp(0, hr.FarZ - hr.NearZ, pm_object.depthOfField ^ detail, 100 ^ detail)
		local strength = sqrt(pm_object.defocusStrength * 100)
		SetDOFParams(
			strength, 
			Max(focus_depth - dof / 3, hr.NearZ), 
			Max(focus_depth - dof / 6, hr.NearZ),
			strength,
			Min(focus_depth + dof / 3, hr.FarZ), 
			Min(focus_depth + dof * 2 / 3, hr.FarZ),
			0)
	elseif prop_id == "freeCamera" then
		if pm_object.freeCamera then
			ActivateFreeCamera()
		else
			DeactivateFreeCamera()
		end
		return -- don't send Msg 
	elseif prop_id == "fov" then
		camera.SetAutoFovX(1, 0, pm_object.fov, 16, 9)
	elseif prop_id == "frame" then
		pm_object:ToggleFrame()
	elseif prop_id == "LUT" then
		if pm_object.LUT == "None" then
			SetGradingLUT(1, ResourceManager.GetResourceID(pm_object.preStoredVisuals.LUT:GetResourcePath()), 0, 0)
		else
			SetGradingLUT(1, ResourceManager.GetResourceID(GradingLUTs[pm_object.LUT]:GetResourcePath()), 0, 0)
		end
	end
	Msg("PhotoModePropertyChanged")
end

function PhotoModeDoTakeScreenshot(frame_duration, max_frame_duration)
	local hideUIWindow
	if not config.PhotoMode_DisablePhotoFrame and PhotoModeObj.photoFrame then
		table.change(hr, "photo_mode_frame_screenshot", {
			InterfaceInScreenshot = true,
		})
		hideUIWindow = GetDialog("PhotoMode").idHideUIWindow
		hideUIWindow:SetVisible(false)
	end
	PhotoModeObj.shotNum = PhotoModeObj.shotNum or 0
	frame_duration = frame_duration or 0
	
	local folder = "AppPictures/"
	local proposed_name = string.format("Screenshot%04d.png", PhotoModeObj.shotNum)
	if io.exists(folder .. proposed_name) then
		local files = io.listfiles(folder, "Screenshot*.png")
		for i = 1, #files do
			PhotoModeObj.shotNum = Max(PhotoModeObj.shotNum, tonumber(string.match(files[i], "Screenshot(%d+)%.png") or 0))
		end
		PhotoModeObj.shotNum = PhotoModeObj.shotNum + 1
		proposed_name = string.format("Screenshot%04d.png", PhotoModeObj.shotNum)
	end
	local width, height = GetResolution()
	WaitNextFrame(3)
	LockCamera("Screenshot")
	if frame_duration == 0 and hr.TemporalGetType() ~= "none" then
		MovieWriteScreenshot(folder .. proposed_name, frame_duration, 1, frame_duration, width, height)
	else
		local quality = Lerp(128, 128, frame_duration, max_frame_duration)
		MovieWriteScreenshot(folder .. proposed_name, frame_duration, quality, frame_duration, width, height)
	end
	UnlockCamera("Screenshot")
	PhotoModeObj.shotNum = PhotoModeObj.shotNum + 1
	local file_path = ConvertToOSPath(folder .. proposed_name)
	Msg("PhotoModeScreenshotTaken", file_path)
	if Platform.steam and IsSteamAvailable() then
		SteamAddScreenshotToLibrary(file_path, "", width, height)
	end
	if hideUIWindow then
		hideUIWindow:SetVisible(true)
		table.restore(hr, "photo_mode_frame_screenshot")
	end
end

function PhotoModeTake(frame_duration, max_frame_duration)
	if IsValidThread(PhotoModeObj.shotThread) then return end
	PhotoModeObj.shotThread = CreateMapRealTimeThread(function()
		if Platform.console then
			local photoModeDlg = GetDialog("PhotoMode")
			local hideUIWindow = photoModeDlg.idHideUIWindow
			hideUIWindow:SetVisible(false)

			local err
			if Platform.xbox then
				err = AsyncXboxTakeScreenshot()
			elseif Platform.playstation then
				err = AsyncPlayStationTakeScreenshot()
			else
				err = "Not supported!"
			end
			if err then
				CreateErrorMessageBox(err, "photo mode")
			end
			hideUIWindow:SetVisible(true)
			photoModeDlg:ToggleUI(true) -- fix prop selection
		else  
			PhotoModeDoTakeScreenshot(frame_duration, max_frame_duration)
		end
		Sleep(1000) -- Prevent screenshot spamming
	end, frame_duration, max_frame_duration)
end

function PhotoModeBegin()
	local obj = PhotoModeObject:new()
	obj:StoreInitialValues()
	local props = obj:GetProperties()
	if AccountStorage.PhotoMode then
		for _, prop in ipairs(props) do
			local value = AccountStorage.PhotoMode[prop.id]
			if value ~= nil then --false could be a valid value
				obj:SetProperty(prop.id, value)
			end
		end
	else
		-- set initial values from current lightmodel
		obj:ResetProperties()
	end
	obj.prev_camera = pack_params(GetCamera())
	PhotoModeObj = obj

	Msg("PhotoModeBegin")
	g_PhotoMode = true
	table.change(hr, "photo_mode", {
		InterfaceInScreenshot = false,
		LODDistanceModifier = Max(hr.LODDistanceModifier, 200),
		DistanceModifier = Max(hr.DistanceModifier, 100),
		ObjectLODCapMin = Min(hr.ObjectLODCapMin, 0),
		EnablePostProcDOF = 1,
		Anisotropy = 4,
	})

	return obj
end

function OnMsg.AfterLightmodelChange()
	if g_PhotoMode and GetTimeFactor() ~= 0 then
		--in photo mode in resumed state
		local lm_name = CurrentLightmodel[1].id or ""
		PhotoModeObj.preStoredVisuals.lightmodel = lm_name ~= "" and lm_name or CurrentLightmodel[1]
	end
end

function GetPhotoModeFilters()
	local filters = {}
	ForEachPreset("PhotoFilterPreset", function(preset, group, filters)
		filters[#filters + 1] = { value = preset.id, text = preset.display_name }
	end, filters)
	
	return filters
end

function GetPhotoModeFrames()
	local frames = {}
	ForEachPreset("PhotoFramePreset", function(preset, group, frames)
		frames[#frames + 1] = { value = preset.id, text = preset:GetName()}
	end, frames)
	
	return frames
end

function GetPhotoModeLUTs()
	local LUTs = {}
	LUTs[#LUTs + 1] = { value = "None", text = T(1000973, "None")}
	ForEachPreset("GradingLUTSource", function(preset)
		if preset.group == "PhotoMode" or preset:IsModItem() then 
			LUTs[#LUTs + 1] = { value = preset.id, text = preset:GetDisplayName()}
		end
	end, LUTs)
	
	return LUTs
end

function PhotoModeGetPropStep(gamepad_val, mouse_val)
	return GetUIStyleGamepad() and gamepad_val or mouse_val
end

DefineClass.PhotoModeObject = {
	__parents = {"PropertyObject"},
	properties =
	{
		{ name = T(335331914221, "Free Camera"), id = "freeCamera", editor = "bool", default = false, dont_save = true, },
		{ name = T(915562435389, "Photo Filter"), id = "filter", editor = "choice", default = "None", items = GetPhotoModeFilters, no_edit = not not config.PhotoMode_DisablePhotoFilter}, -- enabled when config.DisablePhotoFilter doesn't exist
		{ name = T(650173703450, "Motion Blur"), id = "frameDuration", editor = "number", slider = true, default = 0, min = 0, max = 100, step = function() return PhotoModeGetPropStep(5, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = true},
		{ name = T(281819101205, "Vignette"), id = "vignette", editor = "number", slider = true, default = 0, min = 0, max = 255, scale = 255, step = function() return PhotoModeGetPropStep(10, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(394842812741, "Exposure"), id = "exposure", editor = "number", slider = true, default = 0, min = -200, max = 200, step = function() return PhotoModeGetPropStep(20, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = function(obj) return hr.AutoExposureMode == 1 end, },
		{ name = T(394842812741, "Exposure"), id = "ae_key_bias", editor = "number", slider = true, default = 0, min = -3000000, max = 3000000, step = function() return PhotoModeGetPropStep(100000, 10000) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = function(obj) return hr.AutoExposureMode == 0 end, },
		{ name = T(764862486527, "Fog Density"), id = "fogDensity", editor = "number", slider = true, default = 0, min = 0, max = 1000, step = function() return PhotoModeGetPropStep(50, 1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(493626846649, "Depth of Field"), id = "depthOfField", editor = "number", slider = true, default = 100, min = 0, max = 100, step = 1, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableDOF },
		{ name = T(775319101921, "Focus Depth"), id = "focusDepth", editor = "number", slider = true, default = 0, min = 0, max = 100, step = 1, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableDOF},
		{ name = T(194124087753, "Defocus Strength"), id = "defocusStrength", editor = "number", slider = true, default = 10, min = 0, max = 100, step = 1, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableDOF },
		{ name = T(462459069592, "Bloom Strength"), id = "bloomStrength", editor = "number", slider = true, default = 0, min = 0, max = 100, step = function() return PhotoModeGetPropStep(5,1) end, dpad_only = config.PhotoMode_SlidersDpadOnly, no_edit = not not config.PhotoMode_DisableBloomStrength}, -- enabled when config.DisableBloomStrength doesn't exist
		{ name = T(265619974713, "Saturation"), id = "colorSat", editor = "number", slider = true, default = 0, min = -100, max = 100, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(3451, "FOV"), id = "fov", editor = "number", default = const.DefaultCameraRTS and const.DefaultCameraRTS.FovX or 90*60, slider = true, min = 20*60, max = 120*60, scale = 60, step = function() return PhotoModeGetPropStep(300, 10) end, dpad_only = config.PhotoMode_SlidersDpadOnly, },
		{ name = T(985831418702, "Photo Frame"), id = "frame", editor = "choice", default = "None", items = GetPhotoModeFrames, no_edit = not not config.PhotoMode_DisablePhotoFrame }, -- enabled when config.DisablePhotoFrame doesn't exist
		{ name = T(970914453104, "Color Grading"), id = "LUT", editor = "choice", default = "None", items = GetPhotoModeLUTs, no_edit = not not config.PhotoMode_DisablePhotoLUTs }, -- enabled when config.PhotoMode_DisablePhotoLUTs doesn't exist
	},
	preStoredVisuals = false,
	shotNum = false,
	shotThread = false,
	initialCamera = false,
	photoFrame = false,
}

function PhotoModeObject:StoreInitialValues()
	self.preStoredVisuals = {}
	local lm_name = CurrentLightmodel[1].id or ""
	self.preStoredVisuals.lightmodel = self.preStoredVisuals.lightmodel or (lm_name ~= "" and lm_name or CurrentLightmodel[1])
	self.preStoredVisuals.dof_params = self.preStoredVisuals.dof_params or { GetDOFParams() }
	local lut_name = CurrentLightmodel[1].grading_lut or "Default"
	self.preStoredVisuals.LUT = self.preStoredVisuals.LUT or (GradingLUTs[lut_name] or GradingLUTs["Default"])
end

function PhotoModeObject:SetProperty(id, value)
	local ret = PropertyObject.SetProperty(self, id, value)
	PhotoModeApply(self, id)
	return ret
end

function PhotoModeObject:ResetProperties()
	for i, prop in ipairs(self:GetProperties()) do
		if not prop.dont_save then
			self:SetProperty(prop.id, nil)
		end
	end
	self:SetProperty("fogDensity", CurrentLightmodel[1].fog_density)
	self:SetProperty("bloomStrength", CurrentLightmodel[1].pp_bloom_strength)
	self:SetProperty("exposure", CurrentLightmodel[1].exposure)
	self:SetProperty("ae_key_bias", CurrentLightmodel[1].ae_key_bias)
	self:SetProperty("colorSat", -CurrentLightmodel[1].desaturation)
	self:SetProperty("vignette", floatfloor(CurrentLightmodel[1].vignette_darken_opacity * self:GetPropertyMetadata("vignette").scale))

	self.photoFrame = false
end

function PhotoModeObject:Save()
	AccountStorage.PhotoMode = {}
	local storage_table = AccountStorage.PhotoMode
	for _, prop in ipairs(self:GetProperties()) do
		if not prop.dont_save then
			local value = self:GetProperty(prop.id)
			storage_table[prop.id] = value
		end
	end
	SaveAccountStorage(5000)
end

function PhotoModeObject:Pause()
	Pause(self)
end

function PhotoModeObject:Resume(force)
	Resume(self)
	local lm_name = CurrentLightmodel[1].id or ""
	if (lm_name ~= "" and lm_name or CurrentLightmodel[1]) ~= PhotoModeObj.preStoredVisuals.lightmodel then
		SetLightmodel(1, PhotoModeObj.preStoredVisuals.lightmodel, 0)
	end
end

function PhotoModeObject:DeactivateFreeCamera()
	if PhotoModeObj.freeCamera then
		self:SetProperty("freeCamera", nil)
	end
end

function PhotoModeObject:ToggleFrame()
	if config.PhotoMode_DisablePhotoFrame then return end
	local dlg = GetDialog("PhotoMode")
	if dlg and dlg.idFrameWindow then
		local frameName = self:GetProperty("frame")
		if frameName == "None" then
			dlg.idFrameWindow:SetVisible(false)
			self.photoFrame = false
		else
			dlg.idFrameWindow:SetVisible(true)
			local photoFramePreset = PhotoFramePresetMap[frameName]
			if not photoFramePreset then
				self:SetProperty("frame", "None")
				dlg.idFrameWindow:SetVisible(false)
				self.photoFrame = false
				dlg.idScrollArea:RespawnContent()
			elseif not photoFramePreset.frame_file then
				self.photoFrame = false
				dlg.idFrameWindow:SetVisible(false)
			else
				self.photoFrame = true
				dlg.idFrameWindow.idFrame:SetImage(photoFramePreset.frame_file)
			end
		end
	end
end