DefineClass.MinimapObject = 
{
	__parents = { "CObject" },
	minimap_icon = "",
	minimap_icon_ping = "",
	minimap_icon_color = const.clrWhite,
	minimap_icon_flags = 0,
	minimap_icon_desaturation = -1,
	minimap_icon_zorder = 0, -- no sorting
	minimap_size = 5000,
	minimap_color = const.clrWhite,
	minimap_arrow_icon = "",
	minimap_arrow_icon_flags = const.mifRotates,
	minimap_arrow_icon_color = const.clrWhite,
	minimap_rollover = false,
}

function MinimapObject:VisibleOnMinimap()
	return self.minimap_icon ~= ""
end

function MinimapObject:VisibleArrowOnMinimap()
	return self.minimap_arrow_icon ~= ""
end

function MinimapObject:GetMinimapIconColor()
	return self.minimap_icon_color
end

function OnMsg.DoneMap()
	local filename = "memoryscreenshot/minimap.tga"
	if io.exists(filename) then
		local err = AsyncFileDelete(filename)
		if err then print(err, GetStack()) end
	end	
end

function PrepareMinimap()
	local map = GetMap()
	if mapdata.MapType == "system" or map == "" or string.find(map, "/__") then
		return
	end
	local map_filepath = map .. "minimap.tga"

	local filename = "memoryscreenshot/minimap.tga"
	if io.exists(filename) then
		local err = AsyncFileDelete(filename)
		if err then print(err) end
	end
	
	if io.exists(map_filepath) then
		local err = CopyFile(map_filepath, filename)
		if (err) then
			print("[Minimap] Copy existing image failed: " .. err)
		end
	else
		WaitSaveMinimap(filename, 100, config.MinimapScreenshotSize, MinimapOverrides:new())
	end
	InvalidateMinimap()
	Msg("MinimapReady")
end

if FirstLoad then
	g_SaveMinimapThread = false
end

function SaveMinimap(filename, scaleMinimap, forcedSize, overrides, editor)
	if IsValidThread(g_SaveMinimapThread) then
		assert(false, "Minimap saving already in progress!")
		return false
	end
	local map = GetMap()
	if not map or map == "" then
		return false
	end
	g_SaveMinimapThread = CreateRealTimeThread(function()
		for i=1,5 do
			if WaitRenderMode("scene") then
				break
			end
		end
		if GetRenderMode() ~= "scene" then
			assert(false, "Minimap can be saved in scene mode only!")
			return
		end
		
		scaleMinimap = scaleMinimap or 100
		filename = filename or (map .. "minimap.tga")
		
		local options = {}
		Msg("MinimapSaveStart", options)

		local start = GetPreciseTicks()
		local t = start
		
		SuspendPassEdits("MinimapSave")
		
		local editor_mode
		if not editor and IsEditorActive() then
			editor_mode = true
			EditorDeactivate()
		end
		
		local twidth, theight = terrain.GetMapSize()
		local width = twidth/guim
		local height = theight/guim

		local minimapSizeX = (scaleMinimap*twidth)/(100*guim)
		local minimapSizeY = (scaleMinimap*theight)/(100*guim)
		
		if forcedSize then
			minimapSizeX = forcedSize
			minimapSizeY = forcedSize
		end
		
		PauseAnim()
		Pause("Minimap")
		local lightmodel = options.Lightmodel and LightmodelPresets[options.Lightmodel]
		lightmodel = lightmodel or LightmodelPresets.Minimap or LightmodelPresets.ArtPreview
		local old_lm = CurrentLightmodel[1]
		SetLightmodel(1, lightmodel, 0)
		
		local tmin, tmax
		if options.OrthoTop and options.OrthoBottom then
			tmax = options.OrthoTop
			tmin = options.OrthoBottom
		else
			local tavg
			tavg, tmin, tmax = terrain.GetAreaHeight()
			MapForEach("map", "CObject", function(o)
					if o:GetEntity() ~= "" and type(o:GetRadius()) == "number" then
						local pt, radius = o:GetBSphere()
						local maxz = pt:z() + radius
						if maxz > tmax then
							tmax = maxz
						end
					end
				end)
				
			tmax = (tmax / 10) * 10 + guim    -- 1m to compensate for the NearZ=1m
		end

		local farz = tmax - tmin
		local res_width, res_height = GetResolution()
		local aspect = guim*res_height/res_width
		local hr_values = {
			InterfaceInScreenshot = 0,
			OrthoTop = tmax,
			OrthoBottom = tmin,
			NearZ = self.OrthoTop or guim,
			FarZ = self.OrthoBottom or guim,
			Shadowmap = 0,
			EnablePostprocess = 0,
			RenderBillboards = 0,
			RenderParticles = 0,
			RenderSkinned = 0,
			ShowRTEnable = 0,
			EnableCloudsShadow = 0,
		}
		-- hr_values["SceneWidth"] = minimapSizeX
		-- hr_values["SceneHeight"] = minimapSizeY
		hr_values["OrthoX"] = width*aspect
		hr_values["OrthoYScale"] = aspect*height*1000/(width*guim)
		local save_hr_values = {}
		local NIL = {}
		for k,v in pairs(hr_values) do
			save_hr_values[k] = hr[k] or NIL
			hr[k] = v
		end
		if overrides then
			overrides:InitOptions()
		end
		-- switch to ortho expilictly at the end
		save_hr_values["Ortho"] = hr.Ortho
		hr_values["Ortho"] = 1
		hr.Ortho = 1
		
		WaitNextFrame(5)
		SetupViews()
		
		local cam_params = {GetCamera()}
		camera.Lock(1)
		cameraMax.Activate(1)
		local pos = point(twidth/2, theight/2, tmax)
		
		cameraMax.SetCamera(pos, pos + point(0, -1, -1000), 0)
		WaitNextFrame(2)
		--print("[Minimap] Render setup time " .. tostring(GetPreciseTicks() - t)) t = GetPreciseTicks()
		--print("[Minimap] Saving to ", filename, "..." )
		local src_box = false
		local err = WaitCaptureScreenshot(filename, {
			width = minimapSizeX,
			height = minimapSizeY,
			interface = false,
			src = src_box
		})
		if err then
			print("[Minimap] Write screenshot failed: " .. err)
		else
			--print("[Minimap] Write time " .. tostring(GetPreciseTicks() - t)) t = GetPreciseTicks()
		end
		
		-- these two MUST be restored before postprocessing is enabled back on by restoring hr.EnablePostprocess
		-- hr.SceneWidth = save_hr_values.SceneWidth
		-- hr.SceneHeight = save_hr_values.SceneHeight
		
		for k,_ in pairs(hr_values) do
			local v = save_hr_values[k]
			if v == NIL then
				hr[k] = nil
			else
				hr[k] = v
			end
		end
		
		WaitNextFrame(2)
		SetupViews()
		
		camera.Unlock(1)
		SetCamera(unpack_params(cam_params))

		if overrides then
			overrides:ClearOptions()
		end
		
		SetLightmodel(1, old_lm, 0)
		WaitNextFrame(1)
		
		Resume("Minimap")
		ResumeAnim()
		ResumePassEdits("MinimapSave")
		Msg("MinimapSaveEnd")
		
		if editor_mode then
			EditorActivate()
		end
		
		--print("[Minimap] Restore render setup time " .. tostring(GetPreciseTicks() - t))
		--print("[Minimap] Total time " .. tostring(GetPreciseTicks() - start))
	end)
	return true
end

function WaitSaveMinimap(...)
	for i=1,#GroundDetailClassGroups do
		local group = GroundDetailClassGroups[i]
		DecimateObjects(group.classes, 0)
		local particles = type(group.particles) == "function" and group.particles() or group.particles
		DecimateParticles(particles, 0)
	end
	DecimateObjects(NotNeededForScreenshot, 0)
	SaveMinimap(...)
	WaitMinimapSaving()
	for i=1,#GroundDetailClassGroups do
		local group = GroundDetailClassGroups[i]
		DecimateObjects(group.classes, g_CurrentGroundDetailKeepPercent)
		local particles = type(group.particles) == "function" and group.particles() or group.particles
		DecimateParticles(particles, g_CurrentGroundDetailKeepPercent)
	end
	DecimateObjects(NotNeededForScreenshot, 100)
end

function WaitMinimapSaving()
	while IsValidThread(g_SaveMinimapThread) and not WaitMsg("MinimapSaveEnd", 100) do
	end
end

DefineClass.MinimapOverrides =
{
	__parents = { "CObject" },
	ingame = false
}

function MinimapOverrides:InitOptions()
	hr.RenderCodeRenderables=0
	hr.RenderSkinned=1
end

function MinimapOverrides:ClearOptions()
	hr.RenderCodeRenderables=1
end

if not Platform.developer then return end

function UpdateMinimaps(maps)
	local thread = CreateRealTimeThread(function()
		maps = maps or ListMaps()
		local ide = IgnoreDebugErrors(true)
		print("STARTED")
		for i=1,#maps do
			local map = maps[i]
			printf("MAP %d/%d: %s", i, #maps, map)
			
			ChangeMap(map)
			
			if not WaitSaveMinimap() then
				print("FAILED")
				IgnoreDebugErrors(ide)
				return
			end
		end
		IgnoreDebugErrors(ide)
		print("FINISHED")
	end)
end
