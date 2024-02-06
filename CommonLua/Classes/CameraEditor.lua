if FirstLoad then
	s_CameraFadeThread = false
end

function DeleteCameraFadeThread()
	if s_CameraFadeThread then
		DeleteThread(s_CameraFadeThread)
		s_CameraFadeThread = false
	end
end

function CameraShowClose(last_camera)
	DeleteCameraFadeThread()
	if last_camera then
		last_camera:RevertProperties()
	end	
	UnlockCamera("CameraPreset")
end

function SwitchToCamera(camera, old_camera, in_between_callback, dont_lock, ged)
	if not CanYield() then
		DeleteCameraFadeThread()
		s_CameraFadeThread = CreateRealTimeThread(function()
			SwitchToCamera(camera, old_camera, in_between_callback, dont_lock, ged)
		end)
		return
	end

	if IsEditorActive() then
		editor.ClearSel()
		editor.AddToSel({camera})
	end
	if old_camera then
		old_camera:RevertProperties(not(camera.flip_to_adjacent and old_camera.flip_to_adjacent))
	end
	if in_between_callback then
		in_between_callback()
	end
	camera:ApplyProperties(dont_lock, not(camera.flip_to_adjacent and old_camera.flip_to_adjacent), ged)
end

function ShowPredefinedCamera(id)
	local cam = PredefinedCameras[id]
	if not cam then
		print("No such camera preset: ", id)
		return
	end
	CreateRealTimeThread(cam.ApplyProperties, cam, "dont_lock")
end

function GedOpCreateCameraDest(ged, selected_camera)
	if not selected_camera or not IsKindOf(selected_camera, "Camera") then return end
	selected_camera:SetDest(selected_camera)
	GedObjectModified(selected_camera)
end

function GedOpUpdateCamera(ged, selected_camera)
	if not selected_camera or not IsKindOf(selected_camera, "Camera") then return end
	selected_camera:QueryProperties()
	GedObjectModified(selected_camera)
end

function GedOpViewMovement(ged, selected_camera)
	if not selected_camera or not IsKindOf(selected_camera, "Camera") then return end
	SwitchToCamera(selected_camera, nil, nil, "don't lock")
end

function GedOpIsViewMovementToggled()
	return not not GetDialog("Showcase")
end

local function TakeCameraScreenshot(ged, path, sector, camera)
	if GetMapName() ~= camera.map then
		ChangeMap(camera.map)
	end
	
	camera:ApplyProperties()
	local oldInterfaceInScreenshot = hr.InterfaceInScreenshot
	hr.InterfaceInScreenshot = camera.interface and 1 or 0
	
	local image = string.format("%s/%s.png", path, sector)
	AsyncFileDelete(image)
	WaitNextFrame(3)
	local store = {}
	Msg("BeforeUpsampledScreenshot", store)
	WaitNextFrame()
	MovieWriteScreenshot(image, 0, 64, false, 3840, 2160)
	WaitNextFrame()
	Msg("AfterUpsampledScreenshot", store)
	
	hr.InterfaceInScreenshot = oldInterfaceInScreenshot
	camera:RevertProperties()
	return image
end

function GedOpTakeScreenshots(ged, camera)
	if not camera then return end
	
	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local sectors = campaign_presets[campaign] and campaign_presets[campaign].Sectors or empty_table
	local map_to_sector = {[false] = ""}
	for _, sector in ipairs(sectors) do
		if sector.Map then
			map_to_sector[sector.Map] = sector.Id
		end
	end
	
	local path = string.format("svnAssets/Source/UI/LoadingScreens/%s", campaign)
	local err = AsyncCreatePath(path)
	if err then
		local os_path = ConvertToOSPath(path)
		ged:ShowMessage("Error", string.format("Can't create '%s' folder!", os_path))
		return
	end
	local ok, result = SVNAddFile(path)
	if not ok then
		ged:ShowMessage("SVN Error", result)
	end
	
	StopAllHiding("CameraEditorScreenshots", 0, 0)
	local size = UIL.GetScreenSize()
	ChangeVideoMode(3840, 2160, 0, false, true)
	WaitChangeVideoMode()
	LockCamera("Screenshot")
	
	local images = {}
	if IsKindOf(camera, "Camera") then
		images[1] = TakeCameraScreenshot(ged, path, map_to_sector[camera.map], camera)
	else
		local cameras = IsKindOf(camera, "GedMultiSelectAdapter") and camera.__objects or camera
		table.sort(cameras, function(a, b) return a.map < b.map end)
		for _, cam in ipairs(cameras) do
			table.insert(images, TakeCameraScreenshot(ged, path, map_to_sector[cam.map], cam))
		end
	end

	UnlockCamera("Screenshot")
	ChangeVideoMode(size:x(), size:y(), 0, false, true)
	WaitChangeVideoMode()
	ResumeAllHiding("CameraEditorScreenshots")
	
	local ok, result = SVNAddFile(images)
	if not ok then
		ged:ShowMessage("SVN Error", result)
	end
	print("Taking screenshots and adding to SubVersion done.")
end

function OnMsg.GedOnEditorSelect(obj, selected, ged_editor)
	if obj and IsKindOf(obj, "Camera") and selected then 
		SwitchToCamera(obj, IsKindOf(ged_editor.selected_object, "Camera") and ged_editor.selected_object, nil, "don't lock", ged_editor)
	end
end

function GedOpUnlockCamera()
	camera.Unlock()
end

function GedOpMaxCamera()
	cameraMax.Activate(1)
end

function GedOpTacCamera()
	cameraTac.Activate(1)
end

function GedOpRTSCamera()
	cameraRTS.Activate(1)
end

function GedOpSaveCameras()
	local class = _G["Camera"]
	class:SaveAll("save all", "user request")
end

function GedOpCreateReferenceImages()
	CreateReferenceImages()
end

-- run to save a screenshot with every camera at correct video mode!
function CreateReferenceImages()
	if not IsRealTimeThread() then
		CreateRealTimeThread(CreateReferenceImages)
		return
	end
	
	local folder = "svnAssets/Tests/ReferenceImages"
	local cameras = Presets.Camera["reference"]
	SetMouseDeltaMode(true)
	SetLightmodel(0, LightmodelPresets.ArtPreview, 0)
	local size = UIL.GetScreenSize()
	ChangeVideoMode(512, 512, 0, false, true)
	WaitChangeVideoMode()
	local created = 0
	for _, cam in ipairs(cameras) do
		if GetMapName() ~= cam.map then
			ChangeMap(cam.map)
		end
		cam:ApplyProperties()
		Sleep(3000)
		AsyncCreatePath(folder)
		local image = string.format("%s/%s.png", folder, cam.id)
		AsyncFileDelete(image)
		if not WriteScreenshot(image, 512, 512) then
			print(string.format("Failed to create screenshot '%s'", image))
		else
			created = created + 1
		end
		Sleep(300)
		cam:RevertProperties()
	end
	SetMouseDeltaMode(false)
	ChangeVideoMode(size:x(), size:y(), 0, false, true)
	WaitChangeVideoMode()
	print(string.format("Creating %d reference images in '%s' finished.", created, folder))
end

function GetShowcaseCameras(context)
	local cameras = Presets.Camera[context and context.group or "reference"] or {}
	table.sort(cameras, function(a, b) 
		if a.map==b.map then		
			return a.order < b.order 
		else 
			return a.map<b.map 
		end	
	end)
	
	return cameras
end

function OpenShowcase(root, obj, context)
	if GetDialog("Showcase") then
		CloseDialog("Showcase")
		return
	end
	
	if obj and IsKindOf(obj, "Camera") then
		local group = obj.group
		context = context or {}
		context.group = group
	elseif obj and type(obj)== "table" and next(obj) then
		local group = obj[1].group
		context = context or {}
		context.group = group
	end
	OpenDialog("Showcase", nil, context)	
end

function OnMsg.GameEnterEditor()
	CloseDialog("Showcase")
end

function IsCameraEditorOpened()
	local ged = FindGedApp("PresetEditor")
	if not ged then return end
	
	local sel = type(ged.selected_object) == "table" and ged.selected_object[1] or ged.selected_object
	
	return IsKindOf(sel, "Camera")
end
