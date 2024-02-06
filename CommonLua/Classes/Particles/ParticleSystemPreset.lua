DefineClass.BehaviorFilter = {
	__parents = { "GedFilter" },
	properties = {
		{ id = "bins", name = "Bins", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" }, max_items_in_set = 1 },
	},
	bins = set(),
}

function BehaviorFilter:FilterObject(o)
	if not self.bins or not IsSet(self.bins) then return false end
	
	for bin, value in pairs(self.bins) do
		if value and o:HasMember("bins") and not o.bins[bin] then
			return false -- filter item
		end
	end

	return true -- don't filter item
end

DefineClass.ParticleSystemSubItem = {
	__parents = { "InitDone" },
	EditorName = "Particle System Element",
	EditorSubmenu = "Other",
}

DefineClass.ParticleSystemPreset = {
	__parents = { "Preset" },
	properties = {
		{ id = "ui", name = "UI Particle System" , editor = "bool", default = false },
		{ id = "simul_fps", name = "Simul FPS", editor = "number", slider = true, min = 1, max = 60, help = "The simulation framerate" },
		{ id = "speed_up", name = "Speed-up", editor = "number", slider = true, min = 10, max = 10000, scale = 1000, help = "How many times the particle simulation is being sped up." }, 
		{ id = "presim_time", name = "Presim time", editor = "number", scale = "sec", help = "How many seconds to presimulate, before showing the system for the first time", min = 0, max = 120000, slider = true },
		{ id = "max_initial_catchup_time", name = "Initial Catchup Time", editor = "number", scale = 1000, help = "How much work should newly created renderobjs do before displaying them. 0 here is equivalent to ignore_game_object_age"},
		{ id = "rand_start_time", name = "Max starting phase time", editor = "number", scale = "sec", help = "Maximum additional presim time used to randomize the starting phase of the particle system.", min = 0, max = 10000, slider = true },
		
		{ id = "distance_bias", name = "Camera distance offset", editor = "number", min = -100000, max = 100000, scale = 1000, help = "How much to offset the particle system relative to the camera. It is used to make the particle system to appear always on top of some other transparent object.", slider = true },
		{ id = "particles_scale_with_object", name = "Particles scale with object", editor = "bool", help = "Particle size scales with the object scale" },
		{ id = "game_time_animated", name = "Game time animated", editor = "bool", help = "Will animate in game time, i.e. will pause when the game is paused or slowed down", read_only = function(self) return self.ui end },
		{ id = "ignore_game_object_age", name = "Ignore GameObject age", editor = "bool", default = false, help = "Long running particles remember when they were created, and try to catch up if they lose their state. Enables/disables this behaviour.", read_only = function(self) return self.ui end },
		{ id = "vanish", name = "Vanish when killed", editor = "bool", help = "Fx will disappear completely when destroyed, without waiting the existing particles to reach their age" },
		{ id = "post_lighting", name = "Post Lighting" , editor = "bool", default = false, help = "Render after lighting related post processing." },
		{ id = "stable_cam_distance", name = "Stable Camera Distance" , editor = "bool", default = false, help = "Render in consistent order while the camera & the particle system are not moving. This has a performance penalty for systems with particles far away from the center." },
		{ id = "testcode", category = "Custom Test Setup", name = "Test code", editor = "func", params = "self, ged, enabled", default = false, no_edit = function(self) return not self.ui end, },
	},
	
	simul_fps = 30,
	speed_up = 1000,
	presim_time = 0,
	max_initial_catchup_time = 2000, -- 0 is a better default, but 2000 is the "old" one, so we don't have to rework parsys
	rand_start_time = 0,
	distance_bias = 0,
	particles_scale_with_object = false,
	game_time_animated = false,
	vanish = false,
	
	
	-- Preset settings
	SingleFile = false,
	Actions = false,
	GlobalMap = "ParticleSystemPresets",
	ContainerClass = "ParticleSystemSubItem", -- can be ParticleBehavior or ParticleParam
	SubItemFilterClass = "BehaviorFilter",
	GedEditor = "GedParticleEditor",
	SingleGedEditorInstance = false,
	EditorMenubarName = false, 
	EditorMenubar = false,
}

if FirstLoad then
	ParticleSystemPreset_FXDetailThreshold = false
end

function ParticleSystemPreset:GetTextureFolders()
	return {
		{"svnAssets/Source/Textures/Particles/"}
	}
end

function ParticleSystemPreset:GetTextureBasePath()
	return "svnAssets/Source/"
end

function ParticleSystemPreset:GetTextureTargetPath()
	return "Textures/Particles/"
end

function ParticleSystemPreset:GetTextureTargetGamePath()
	return "Textures/Particles"
end

function ParticleSystemPreset:DynamicParams()
	return self:EditorData().dynamic_params or false
end

function ParticleSystemPreset:RefreshThread()
	return self:EditorData().refresh_thread or false
end

function ParticleSystemPreset:OverrideEmitterFuncs()
end

function GedOpOpenParticleEditor(ged, obj, locked)
	obj:OpenEditor(locked)
end

function ParticleSystemPreset:OpenEditor(lock_preset)
	if not IsRealTimeThread() then
		CreateRealTimeThread(ParticleSystemPreset.OpenEditor, self, lock_preset)
		return
	end
	lock_preset = not not lock_preset

	local context = ParticleSystemPreset:EditorContext()
	context.lock_preset = lock_preset
	local ged = OpenPresetEditor("ParticleSystemPreset", context)
	ged:SetSelection("root", PresetGetPath(self))
end

function GedListParticleSystemBehaviors(obj, filter, format, restrict_class)
	if not IsKindOf(obj, "ParticleSystemPreset") then
		return {}
	end
	
	local format = T{format}
	local objects, ids = {}, {}
	for i = 1, #obj do
		local item = obj[i]
		objects[#objects + 1] = type(item) == "string" and item or _InternalTranslate(format, item, false)
		ids[#ids + 1] = tostring(item)
	end
	
	-- Do filtering
	local filtered = {}
	if filter then
		for i = 1, #obj do
			local item = obj[i]
			-- filter by bins
			for bin, value in pairs(filter.bins) do
				if value and item:HasMember("bins") and not item.bins[bin] then
					filtered[i] = true
				end
			end
		end
	end
	objects.filtered = filtered
	objects.ids = ids
	return objects
end

if FirstLoad then
	l_streams_to_update = false
	g_ParticleLuaDefsLoaded = false
end

local load_lua_defs = Platform.developer and Platform.pc and IsFSUnpacked()

local particle_editors = {}
function OnMsg.GedOpened(ged_id)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == "GedParticleEditor" then
		hr.TrackParticleTimes = 1
		ParticleSystemPreset_FXDetailThreshold = hr.FXDetailThreshold
		
		if load_lua_defs and not g_ParticleLuaDefsLoaded then
			LoadLuaParticleSystemPresets()
			
			if Platform.developer then
				ParticleSystemPreset.TryUpdateKnownInvalidStreams(l_streams_to_update)
			end
		end
		
		particle_editors[ged_id] = true
	end
end

function OnMsg.GedClosing(ged_id)
	if particle_editors[ged_id] then
		hr.FXDetailThreshold = ParticleSystemPreset_FXDetailThreshold
		particle_editors[ged_id] = nil
	end
end

if FirstLoad then
	UIParticlesTestControl = false
	UIParticlesTestId = false
end

local function UpdateGedStatus()
	GedSetUiStatus("select_xcontrol", "Select UI control to attach this particle to.")
end

function GedTestUIParticle(ged, enabled)
	if UIParticlesTestControl and UIParticlesTestControl.window_state == "open" and UIParticlesTestControl:HasParticle(UIParticlesTestId) then
		UIParticlesTestControl:KillParSystem(UIParticlesTestId)
		UIParticlesTestControl = false
		UIParticlesTestId = false
		return
	end
	UIParticlesTestControl = false
	UIParticlesTestId = false

	local particle_sys = ged:ResolveObj("SelectedPreset")
	if not particle_sys then
		XRolloverMode(false)
		return
	end
	
	if particle_sys.testcode then
		particle_sys.testcode(particle_sys, ged, enabled)
		return
	end

	if not enabled then
		XRolloverMode(false)
		return
	end

	if not particle_sys.ui then
		ged:ShowMessage("Invalid selection", "Select a UI particle first!")
		XRolloverMode(false)
		return
	end

	GedSetUiStatus("select_xcontrol", "Select UI control to attach this particle to.")
	XRolloverMode(true, function(window, status)
		if window and window:IsKindOf("XControl") then
			XFlashWindow(window)
			if status == "done" then
				-- spawn particles
				UIParticlesTestControl = window
				UIParticlesTestId = window:AddParSystem(UIParticlesTestId, particle_sys.id, UIParticleInstance:new({
					lifetime = -1,
				}))
			end
		end
		if status == "done" or status == "cancel" then
			GedSetUiStatus("select_xcontrol")
		end
	end)
end

function GedSetParticleEmitDetail(ged, detail_name)
	local levels = OptionsData.Options.Effects
	local idx = table.find(levels, "value", detail_name)
	assert(idx)

	EngineOptions.Effects = levels[idx].value
	Options.ApplyEngineOptions(EngineOptions)

	local selected_preset = ged:ResolveObj("SelectedPreset")
	if selected_preset and selected_preset:IsKindOf("ParticleSystemPreset") then
		if selected_preset.ui then
			if UIParticlesTestControl and UIParticlesTestControl:HasParticle(UIParticlesTestId) then
				UIParticlesTestControl:KillParSystem(UIParticlesTestId)
			end
		else
			selected_preset:ResetParSystemInstances()
		end
	end
	print(string.format("Particle detail level '%s' preview set.", levels[idx].value))

	local detail_level_names = {"Low", "Medium", "High", "Ultra"}
	for i = 1, 4 do
		ged:Send("rfnApp", "SetActionToggled", "Preview" .. detail_level_names[i], detail_level_names[i] == levels[idx].value)
	end
end

if FirstLoad then
	ParticleSystemPresetCommitThread = false
end
function GedParticleSystemPresetCommit()
	ParticleSystemPresetCommitThread = IsValidThread(ParticleSystemPresetCommitThread) or CreateRealTimeThread(function()
		local assets_path = ConvertToOSPath("svnAssets/")
		local project_path = ConvertToOSPath("svnProject/")
		local err, exit_code = AsyncExec(string.format("cmd /c %s/Build TexturesParticles-win32", project_path))
		if err then 
			assert("Failed to build particle textures" and false)
			return
		end
		local err, exit_code = AsyncExec("cmd /c Build ParticlesSeparateFallbacks", project_path, true, true)
		if not err and exit_code == 0 then
			print("Fallbacks updated.")
		else
			print("Fallbacks failed to update", err, exit_code)
			assert("Failed to build particle fallbacks" and false)
			return
		end
		err, exit_code = AsyncExec(string.format("cmd /c TortoiseProc /command:commit /path:%s", assets_path))
		if err then assert("Failed to open commit dialog" and false) end
	end)
end

function ParticleSystemPreset:GetPresetStatusText()
	if IsValidThread(UpdateTexturesListThread) or IsValidThread(ParticleSystemPresetCommitThread) then
		return "Compress tasks in progress..."
	end
	return ""
end

function ParticleSystemPreset:SwitchParam(obj, prop, id)
	obj:ToggleProperty(prop, self:DynamicParams())
	ObjModified(obj)
end

function ParticleSystemPreset:BindParam(idx, userdata)
	local param = self[idx]
	local dp = { index = userdata, type = param.type, default_value = param.default_value }
		
	if param.type == "number" then
		dp.size = 1
	elseif param.type == "color" then
		dp.size = 1
	elseif param.type == "point" then
		dp.size = 3
	elseif param.type == "bool" then
		dp.size = 1
	end
	
	self:DynamicParams()[param.label] = dp
	
	return dp.size
end

function ParticleSystemPreset:BindParams()
	local idx = 1 -- start at 1 because custom data [0] is the particle system creation time
	self:EditorData().dynamic_params = {}
	for i = 1, #self do
		if IsKindOf(self[i], "ParticleParam") then
			idx = idx + self:BindParam(i, idx)
			if idx > const.CustomDataCount - 1 then
				print(string.format("warning: parameter %s exceeded the available userdata values!", self[i].label))
			end
		end
	end
end

function ParticleSystemPreset:EnableDynamicToggles()
	for i = 1, #self do
		if self[i]:IsKindOf("ParticleBehavior") then
			self[i]:EnableDynamicToggle(self:DynamicParams())
		end
	end
end

function ParticleSystemPreset:BindParamsAndUpdateProperties()
	self:BindParams()
	self:EnableDynamicToggles()
end

function OnMsg.DataLoading()
	for _, folder in ipairs(ParticleDirectories()) do
		LoadingBlacklist[folder] = true
	end
end

function LoadLuaParticleSystemPresets()
	if g_ParticleLuaDefsLoaded then
		return g_ParticleLuaDefsLoaded
	end
	
	local start_time = GetPreciseTicks()

	for _, folder in ipairs(ParticleDirectories()) do
		LoadingBlacklist[folder] = false
		LoadPresetFolder(folder)
	end

	local old_load_lua_defs = load_lua_defs
	load_lua_defs = false
	local count = 0
	ForEachPreset("ParticleSystemPreset", function(preset)
		preset:PostLoad()
		count = count + 1
	end)
	load_lua_defs = old_load_lua_defs

	if Platform.developer then
		--print("Loaded", count, "particle lua defs in", GetPreciseTicks() - start_time, "ms");
	end

	ObjModified(Presets.ParticleSystemPreset)


	-- Replace bins with lua defs in the engine. Log which happened to be different (outdated bins) and in case we want to resave them later
	local streams_to_update = ParticlesReload(false, false)
	l_streams_to_update = l_streams_to_update or {}
	for _, parsys in ipairs(streams_to_update) do
		local err = ParticleSystemPresets[parsys]:TestStream()
		if err then
			GameTestsError("ParSys", parsys, "error: ", err)
			table.insert(l_streams_to_update, parsys)
		end
	end

	g_ParticleLuaDefsLoaded = true
	return g_ParticleLuaDefsLoaded
end

function OnMsg.DataLoaded()
	local failed_to_load = {}
	for _, folder in ipairs(ParticleDirectories()) do
		LoadStreamParticlesFromDir(folder, failed_to_load)
	end
	l_streams_to_update = failed_to_load


	if load_lua_defs then
		LoadLuaParticleSystemPresets()
	end
end

function ParticleSystemPreset:OnEditorNew(parent, ged, is_paste)
	if load_lua_defs then
		ParticlesReload(self.id)
	end
	g_PresetLastSavePaths[self] = nil
	if Platform.editor then
		XEditorUpdateObjectPalette()
	end
end

function ParticleSystemPreset:OnEditorSelect(now_selected, ged)
	if now_selected then
		self:RefreshBehaviorUsageIndicators()
		self:BindParamsAndUpdateProperties()
		ged:Send("rfnApp", "SetIsUIParticle", self.ui)
	else
		self:ResetParSystemInstances()
	end
end

function BinAssetsUpdateInvalidParticleStreams()
	ParticleUpdateBinaryStreams()
end


function ParticleSystemPreset.TryUpdateKnownInvalidStreams(l_streams_to_update)
	if not l_streams_to_update or #l_streams_to_update == 0 then
		return
	end
	local streams_to_update = table.copy(l_streams_to_update)
	table.clear(l_streams_to_update)
	CreateRealTimeThread(function()
		local changed_outlines = ParticleUpdateOutlines()
		if #changed_outlines > 0 then
			print("Saving", #changed_outlines, "particles with modified outlines")
			for i=1,#changed_outlines do
				SaveParticleSystem(changed_outlines[i])
			end
			QueueCompressParticleTextures()
		end
		if #streams_to_update > 0 then
			ParticleNameListSaveToStream(streams_to_update)
		end
		ParticleUpdateBinaryStreams("create_missing_only")
	end)
end

function ParticleSystemPreset:RefreshBehaviorUsageIndicators(do_now)
	local editor_data = self:EditorData()
	local refresh_func = function(self)
		-- Search the behaviors to identify those with disabled emitters.
		-- Scheduled in a thread to avoid executing simultaneous refresh requests.
		for i = 1, #self do
			local behavior = self[i]
			if behavior:IsKindOf("ParticleBehavior") and not behavior:IsKindOf("ParticleEmitter") then
				local behavior_bins = behavior.bins
				local active_emitters = 0
				for j = 1, #self do
					local emitter = self[j]
					if emitter:IsKindOf("ParticleEmitter") and emitter.enabled then
						local emitter_bins = emitter.bins
						for bin, value in pairs(emitter_bins) do
							if value and behavior_bins[bin] then
								active_emitters = active_emitters + 1
							end
						end
					end
				end
				local new_active = active_emitters > 0
				if new_active ~= behavior.active then
					behavior.active = new_active
					ObjModified(self)
				end
				
				local flags = ParticlesGetBehaviorFlags(self.id, i - 1)
				if flags then
					local str = ""
					flags["emitter"] = nil
					for name, active in sorted_pairs(flags) do
						if GetDarkModeSetting() then active = not active end
						local color = active and RGB(74, 74, 74) or RGB(192, 192, 192)
						local r,g,b = GetRGB(color)
						str = string.format("%s<color %s %s %s>%s</color>", str, r,g,b, string.sub(name, 1, 1))
					end
					behavior.flags_label = str
				end
			end
		end
		editor_data.refresh_thread = nil
	end
	
	local refresh_thread = self:RefreshThread()
	if do_now and not refresh_thread then
		refresh_func(self)
	else
		editor_data.refresh_thread = refresh_thread or CreateRealTimeThread(refresh_func, self)
	end
end

function ParticleSystemPreset:PostLoad()
	Preset.PostLoad(self)
	
	if Platform.developer then self:CheckIntegrity() end
	self:BindParams()
	if load_lua_defs then ParticlesReload(self.id) end
end

function ParticleSystemPreset:CheckIntegrity()
	local count = table.maxn(self)
	for i = count, 1, -1 do
		if not rawget(self, i) then
			assert(false, "Particle system '" .. self.name .. "' initialization failed at: " .. tostring(i))
			self[i] = false
			table.remove(self, i)
		end
	end
end

local function KillParticlesWithName(name)
	if UIParticlesTestControl and UIParticlesTestControl:GetParticleName(UIParticlesTestId) == name then
		UIParticlesTestControl = false
		UIParticlesTestId = false
	end

	local xcontrols = GetChildrenOfKind(terminal.desktop, "XControl")
	for _, control in ipairs(xcontrols) do
		control:KillParticlesWithName(name)
	end
end

function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if not GedConnections[ged_id] then return end

	local parent = GetParentTableOfKindNoCheck(object, "ParticleSystemPreset")
	if object:IsKindOf("ParticleParam") and parent then
		parent:BindParamsAndUpdateProperties()
		g_DynamicParamsDefs = {} -- invalidate the cached params
		ParticlesReload(parent:GetId())
	end
	if object:IsKindOf("ParticleSystemPreset") and prop_id == "Id" then
		KillParticlesWithName(old_value)
		ParticlesReload()
		ObjModified(GedConnections[ged_id]:ResolveObj("root"))
		if Platform.editor then
			XEditorUpdateObjectPalette()
		end
	elseif (object:IsKindOf("ParticleBehavior") or object:IsKindOf("ParticleSystemPreset")) and parent then
		parent:RefreshBehaviorUsageIndicators()
		if object:IsKindOf("ParticleEmitter") and object:IsOutlineProp(prop_id) then
			object:GenerateOutlines("forced")
		end
		ParticlesReload(parent:GetId())
		g_DynamicParamsDefs = {} -- invalidate the cached params
	end
end

function ParticleSystemPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "ui" then
		for _, behaviour in ipairs(self) do
			if IsKindOf(behaviour, "ParticleEmitter") then
				behaviour:Setui(self.ui)
			end
		end
	end
	ParticlesReload(self:GetId())
	self:RefreshBehaviorUsageIndicators()
	
	if prop_id == "NewBehavior" then
		ParticleSystemPreset.ActionAddBehavior(ged:ResolveObj("root"), self, prop_id, ged)
	end

	Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

function ParticleSystemPreset:ResetParSystemInstances()
	MapForEach("map", "ParSystem",
		function(x)
			if x:GetParticlesName() == self.id then
				x:SetParticlesName(self.id) -- resets time and flags in GO
				x:DestroyRenderObj()
			end
		end)
end

function GedResetAllParticleSystemInstances()
	MapForEach("map", "ParSystem", function(obj)
		obj:SetParticlesName(obj:GetParticlesName())
		obj:DestroyRenderObj()
	end)
end

function ParticleSystemPreset:SaveToStream(bin_name, skip_adding_to_svn)
	bin_name = bin_name or self:GetBinFileName()
	local id = self:GetId()
	if bin_name ~= "" then
		ParticlesReload(self:GetId(), false)
		local count, err = ParticlesSaveToStream(bin_name, id, true)
		self:EditorData().stream_error = err
		if err then
			printf("\"%s\" while trying to persist \"%s\" in \"%s\"", err, id, bin_name)
			return false, err
		end
		if not skip_adding_to_svn then
			SVNAddFile(bin_name)
		end
	end
	return bin_name
end

function ParticleSystemPreset:DeleteStream(bin_name)
	bin_name = bin_name or self:GetBinFileName()
	if bin_name ~= "" then
		SVNDeleteFile(bin_name)
	end
end

function ParticleSystemPreset:GetBinFileName(id)
	local path = self:GetSavePath()
	if not path or path == "" then return "" end
	return path:gsub(".lua$", ".bin")
end

function ParticleSystemPreset:TestStream()
	local binPath = self:GetBinFileName()
	if binPath then
		local id = self.id
		local err = ParticlesTestStream(binPath, id)
		self:EditorData().stream_error = err
		if err then
			return err
		end
	end
end

function ParticleSystemPreset:GetError()
	if #self > 55 then
		return "Too many particle behaviors."
	elseif #self < 1 then
		return "There are no particle behaviors. Please add some."
	end
	if self.ui then
		-- TODO: Figure out how this code can go in the ParticleEmitter
		for _, behavior in ipairs(self) do
			if IsKindOf(behavior, "ParticleEmitter") then
				if behavior.softness ~= 0 and behavior.enabled then
					return "A particle emitter with softness > 0 found. They are not supported in UI particles."
				end
			end
		end
	end
	local editor_data = self:EditorData()
	if editor_data.stream_error then
		return "Persist error:" .. editor_data.stream_error
	end
end
 
ParticleSystemPreset.ReloadWaitThread = false 


function ParticleSystemPreset:AddSourceTexturesToSVN()
	local textures = {}
	for i = 1, #self do
		local behavior = self[i]
		if IsKindOf(behavior, "ParticleEmitter") then
			if behavior.texture ~= "" then textures[#textures + 1] = "svnAssets/Source/" .. behavior.texture end
			if behavior.normalmap ~= "" then textures[#textures + 1] = "svnAssets/Source/" .. behavior.normalmap end
		end
	end
	if #textures > 0 then
		SVNAddFile(textures)
	end
end

function ParticleSystemPreset:OnPreSave(user_requested)
	local file_exists = io.exists(self:GetBinFileName())
	local last_save_path = g_PresetLastSavePaths[self]
	
	for i = 1, #self do
		local behavior = self[i]
		if IsKindOf(behavior, "ParticleEmitter") then
			behavior:GenerateOutlines()
		end
	end

	self:BindParamsAndUpdateProperties() -- generates the "fake" properties for dynamic params
	
	-- remove no longer used bin files.
	if last_save_path and last_save_path ~= self:GetSavePath() then
		local old_bin_path = (last_save_path or ""):gsub(".lua", ".bin")
		if old_bin_path ~= "" then
			self:DeleteStream(old_bin_path)
		end
	end

	QueueCompressParticleTextures()
	self:AddSourceTexturesToSVN()
	self:SaveToStream(false, not "dont_add_to_svn")
	
	print(#self, "particle behaviors in", self:GetId(), "saved")
	ObjModified(self)
end 

function ParticleSystemPreset:OnEditorDelete(...)
	self:DeleteStream()
end

function GetParticleBehaviorsCombo()
	local list = {}
	ClassDescendants("ParticleBehavior", function(name, class_def, list)
		if rawget(class_def, "EditorName") then
			list[#list + 1] = {value = name, text = class_def.EditorName}
		end
	end, list)
	table.sortby_field(list, "text")
	table.insert(list, 1, {value = "", text = ""})
	return list
end

function ParticleUpdateOutlines()
	local updated = {}
	ClearOutlinesCache()
	local list = GetParticleSystemList()
	for i = 1,#list do
		local parsys = list[i]
		for j = 1, #parsys do
			local behavior = parsys[j]
			if IsKindOf(behavior, "ParticleEmitter") then
				local success, generated = behavior:GenerateOutlines("update")
				if success then
					updated[parsys] = true
				end
				if generated and CanYield() then
					Sleep(10)
				end
			end
		end
	end
	updated = table.keys(updated)
	table.sort(updated, function(a, b) return CmpLower(a.id, b.id) end)
	return updated
end

function ParticleUpdateBinaryStreams(create_missing_only)
	if not g_ParticleLuaDefsLoaded then
		print("ParticleUpdateBinaryStreams: Particle defs not loaded.")
		return
	end

	local existing = {}
	
	for _, folder in ipairs(ParticleDirectories()) do
		local err, files = AsyncListFiles(folder, "*.bin")
		if err then
			print("Particle files listing failed:", err)
		else
			for i = 1, #files do
				existing[files[i]] = true
			end
		end
	end
	
	local particle_systems = GetParticleSystemList()
	
	local streams = {}
	local to_create = {}
	for i = 1, #particle_systems do
		local parsys = particle_systems[i]
		local stream = parsys:GetBinFileName()
		streams[stream] = true
		if not create_missing_only or not existing[stream] then
			to_create[#to_create + 1] = parsys
		end
	end
	
	if #to_create > 0 then
		local created = {}
		print("Creating", #to_create, "particle streams...")
		for i = 1, #to_create do
			local parsys = to_create[i]
			local stream = parsys:GetBinFileName()
			local success, err = parsys:SaveToStream(stream, "skip adding to svn")
			if success then
				created[#created + 1] = stream
			end
		end
		SVNAddFile(created)
		print("Created", #created, "/", #to_create, "particle streams.")
	end
	--[[
	if #updated > 0 then
		print(#updated, "particle stream(s) saved:")
		for i=1,#updated do
			print("\t", i, updated[i])
		end
	end
	--]]
	
	local to_delete = {}
	for stream in pairs(existing) do
		if not streams[stream] then
			to_delete[#to_delete + 1] = stream
		end
	end
	if #to_delete > 0 then
		print("Deleting", #to_delete, "particle streams...")
		local result, err = SVNDeleteFile(to_delete)
		if not result then
			err = err or ""
			printf("Failed to delete binary streams! %s", tostring(err))
		end 
	end
end

function ParticleSystemPreset:Getname()
	return self.id
end

function LoadStreamParticlesFromDir(dir, failed_to_load)
	local err, files = AsyncListFiles(dir, "*.bin")
	if err then
		print("Particle files listing failed:", err, " directory ", dir)
	else
		local start = GetPreciseTicks()
		local success = 0
		local failed_due_to_ver = 0
		for i = 1, #files do
			local err, count = ParticlesLoadFromStream(files[i])
			if not err and count ~= 0 then
				success = success + 1
			elseif err == "persist_version" then
				failed_due_to_ver = failed_due_to_ver + 1

				local _, parsys, __ = SplitPath(files[i])
				table.insert(failed_to_load, parsys)
			else
				print("Particles", files[i], "loading failed!", err)
				local _, parsys, __ = SplitPath(files[i])
				table.insert(failed_to_load, parsys)
			end
		end
		DebugPrint(print_format(success, "/", #files, "particle streams loaded in", GetPreciseTicks() - start, "ms.\n"))
		if failed_due_to_ver > 0 then
			print("Particle streams could not be loaded. Using", failed_due_to_ver, "lua descriptions instead. Reason: Persist version mismatch.")
		end
	end
end

function ParticleNameListSaveToStream(streams_to_update)
	local updated = {}
	print("Updating", #streams_to_update, "particle streams...")
	for i = 1, #streams_to_update do
		local parsys = GetParticleSystem(streams_to_update[i])
		if parsys then
			local success, err = parsys:SaveToStream()
			if success then
				updated[#updated + 1] = parsys
			end
		end
	end
	print("Updated", #updated, "/", #streams_to_update, "particle streams.")
end

function CheckParticleTextures()
	local source_path = "svnAssets/Source/Textures/Particles/"
	local packed_path = "Textures/Particles/"
	if not io.exists(source_path) then
		print("You need to checkout source textures for particles.")
		return {}
	end
	local err, rel_paths = AsyncListFiles(source_path, "*", "relative, recursive")
	local packed_paths = {}
	table.map(rel_paths, function(rel_path) packed_paths[#packed_paths+1] = packed_path .. rel_path end)
	
	local refs = {}
	local refs_lower = {}
	local instances = GetParticleSystemList()
	for i=1, #instances do
		local parsystem = instances[i]
		for b=1, #parsystem do
			local behavior = parsystem[b]
			if IsKindOf(behavior, "ParticleEmitter") then
				refs[behavior.texture] = parsystem:GetId()
				refs[behavior.normalmap] = parsystem:GetId()
				refs_lower[string.lower(behavior.texture)] = parsystem:GetId()
				refs_lower[string.lower(behavior.normalmap)] = parsystem:GetId()
			end
		end
	end	
	refs[""] = nil
	
	local unref = {}
	local present = {}
	local present_lower = {}
	local missing = {}
	local wrong_casing = {}
	
	for i=1, #packed_paths do
		local texture = packed_paths[i]
		local texture_lower = string.lower(texture)
		present[texture] = true
		present_lower[texture_lower] = true
		if not refs[texture] then
			if refs_lower[texture_lower] then
				wrong_casing[#wrong_casing+1] = texture
			else
				unref[#unref+1] = texture
			end
		end
	end
	for texture, parsys in pairs(refs) do
		if not present_lower[string.lower(texture)] then
			missing[texture] = parsys
		end
	end
	return refs, unref, wrong_casing, missing
end

if FirstLoad then
	UpdateTexturesListThread = false
end
function QueueCompressParticleTextures()
	if Platform.ged then return end
	if UpdateTexturesListThread then
		DeleteThread(UpdateTexturesListThread)
		UpdateTexturesListThread = false
	end
	UpdateTexturesListThread = CreateRealTimeThread(function()
		Sleep(300)
		local filepath = "svnProject/Data/ParticleSystemPreset/Textures.txt"
		local refs, _, wrong_casing, missing = CheckParticleTextures()
		local idx = {}
		local full_os_path = ConvertToOSPath("svnAssets/Source/"):gsub("\\", "/")
		local os_path = string.match(full_os_path, "/([^/]+/Source/)$")
		for texture, _ in sorted_pairs(refs) do
			if not missing[texture] and not table.find(wrong_casing, texture) then
				idx[#idx+1] = texture .. "=" .. os_path .. texture
			end
		end	
		AsyncStringToFile(filepath, table.concat(idx, "\r\n"))
		print("Textures.txt updated")

		local dir = ConvertToOSPath("svnProject/")
		local err, exit_code, other = AsyncExec("cmd /c Build TexturesParticles", dir, true, true)
		if err or exit_code ~= 0 then
			print("Particles failed to compress", err, exit_code, other)
		end

		local err, exit_code = AsyncExec("cmd /c Build ParticlesSeparateFallbacks", dir, true, true)
		if not err and exit_code == 0 then
			print("Fallbacks updated.")
		else
			print("Fallbacks failed to update", err, exit_code)
		end

		UpdateTexturesListThread = false
	end)
end



DefineClass.ParticleSystem = {
	__parents = {"PropertyObject"},
	StoreAsTable = false,
	properties = {{id = 'name', editor = 'text', default = '', },},
	
	simul_fps = 30,
	speed_up = 1000,
	presim_time = 0,
	max_initial_catchup_time = 2000,
	rand_start_time = 0,
	distance_bias = 0,
	particles_scale_with_object = false,
	game_time_animated = false,
	vanish = false,
}

function OnMsg.ClassesGenerate()
	table.iappend(ParticleSystem.properties, ParticleSystemPreset.properties)
end

function ParticleSystem:__fromluacode(...)
	local obj = PropertyObject.__fromluacode(self, ...)
	local converted = ParticleSystemPreset:new(obj)
	converted:SetId(obj.name)
	converted:SetGroup("Default")
	return converted
end