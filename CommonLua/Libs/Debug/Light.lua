Light.SetCastShadows = function(self, cast)
	if cast then
		self:SetLightFlags(const.elfCastShadows)
	else
		self:ClearLightFlags(const.elfCastShadows)
	end
	self:ConfigureInvisibleObjectHelper(self:GetAttach("InvisibleObjectHelper"))
end

if FirstLoad then
	DbgClusterCameraPos = false
	DbgClusterCameraLookAt = false
	StatsLightShadowsThread = false
end

function DBGLightsShowFirstLight(store_camera)
	CreateRealTimeThread(function()
		if store_camera then
			DbgClusterCameraPos, DbgClusterCameraLookAt = cameraMax.GetPosLookAt()
		else
			cameraMax.SetCamera(DbgClusterCameraPos, DbgClusterCameraLookAt)
			WaitNextFrame(10)
		end
		DbgClearVectors()
		hr.DbgAutoClearLimit = 20000
		hr.LightsClusterWireframe = 3
	end)
end

function HideLightShadowsStats()
	hr.LightShadowsStatistics = 0
	if IsValidThread(StatsLightShadowsThread) then
		DeleteThread(StatsLightShadowsThread)
		MapForEach("map", "Light", function(light)
			local text = rawget(light, "StatsText")
			if text ~= nil then
				text:Detach()
				text:delete()
				rawset(light, "StatsText", nil)
			end
		end)
	end
	StatsLightShadowsThread = false
end

function ShowLightShadowsStats(frequency)
	HideLightShadowsStats()
	hr.LightShadowsStatistics = 1
	
	StatsLightShadowsThread = CreateRealTimeThread(function()
		local prev_frame = GetRenderFrame() - 1
		while true do
			local curr_frame = GetRenderFrame()
			local frames = curr_frame - prev_frame
			prev_frame = curr_frame
			
			local lights = GetLights()
			for _, light in ipairs(lights) do
				if rawget(light, "StatsText") == nil then
					local text = Text:new{ hide_in_editor = false }
					rawset(light, "StatsText", text)
					light:Attach(text)
				end
				if light:GetCastShadows() then
					local rops_per_frame = DivRound(light:GetShadowStatsROPs(), Max(frames, 1))
					local polygons_per_frame = DivRound(light:GetShadowStatsPolygons(), Max(frames, 1))
					local pushed_objects_per_frame = DivRound(light:GetShadowStatsPushedGOs(), Max(frames, 1))
					light:SetShadowStatsROPs(0)
					light:SetShadowStatsPolygons(0)
					light:SetShadowStatsPushedGOs(0)
					light.StatsText:SetText(string.format("%s(%s)%s\n%d Objects/frame\n%d Polygons/frame\nGathered Objects/frame\n%d",
						light.class, light:GetDetailClass(),
						light:GetDetailClass() == "Optional" and "[Visible due to CastShadow=true]" or "",
						rops_per_frame, polygons_per_frame, pushed_objects_per_frame
					))
					if rops_per_frame > 5000 or polygons_per_frame > 300000 or pushed_objects_per_frame > 30000 then
						light.StatsText:SetColor(const.clrRed)
					elseif rops_per_frame > 2000 or polygons_per_frame > 100000 or pushed_objects_per_frame > 10000 then
						light.StatsText:SetColor(const.clrYellow)
					else
						light.StatsText:SetColor(const.clrGreen)
					end
				else
					light.StatsText:SetText(string.format("%s(%s)\nNo Shadow",
						light.class, light:GetDetailClass()
					))
					light.StatsText:SetColor(const.clrGreen)
				end
			end
			Sleep(frequency)
		end
	end)
end

if FirstLoad then
	g_LightSelected = false
	g_CapturedScreenLights = false
end

function CaptureScreenLights(clear)
	if clear then
		g_CapturedScreenLights = false
		print("Captured Lights on Screen cleared")
		return
	end
	
	g_CapturedScreenLights = GatherObjectsInScreenRect(point20, point(GetResolution()), "Light")
	print(string.format("Captured %d/%d Lights on Screen", #g_CapturedScreenLights, #GetLights()))
end

function ViewNextLight(dir, screen_lights)
	local lights = screen_lights and (g_CapturedScreenLights or empty_table) or GetLights()
	if #lights == 0 then return end
	
	g_LightSelected = (g_LightSelected or 0) + dir
	if g_LightSelected > #lights then
		g_LightSelected = 1
	elseif g_LightSelected < 1 then
		g_LightSelected = #lights
	end
	local light = lights[g_LightSelected]
	if not screen_lights then
		ViewObject(light)
	end
	editor.ClearSel()
	editor.AddObjToSel(light)
	ViewObject(light)
	print(string.format("%sLight(%s-%s) %d/%d", screen_lights and "Screen " or "", light.class, light:GetDetailClass(), g_LightSelected, #lights))
end

function OnMsg.NewMapLoaded()
	g_LightSelected = false
	g_CapturedScreenLights = false
end

function OnMsg.GameOptionsChanged(category)
	if category == "Video" then
		g_LightSelected = false
		CaptureScreenLights("clear")
	end
end