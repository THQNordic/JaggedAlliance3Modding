Options = {}  -- namespace for global functions
OptionsData = { Options = {} } -- configuration per-project, what options mean
OptionsData.VideoPresetsData = {}
if FirstLoad then
	PresetVideoOptions = {}
	EngineOptionFixups = {} -- namespace for engine option fixups
	AccountOptionFixups = {} -- namespace for account option fixups
end

local function GetAvailableGraphicsApis()
	local available = GetSupportedGraphicsApis()
	if config.OfficialPCGraphicsApis and Platform.pc and not Platform.developer and not insideHG() then
		available = table.intersection(available, config.OfficialPCGraphicsApis)
	end
	return available
end

function GetValidVideoMode(displayIndex, width, height)
	local modes = GetVideoModes(displayIndex, width, height)
	if #modes > 0 then
		table.sort(modes, function(a, b)
			if a.Height ~= b.Height then
				return a.Height < b.Height
			end
			return a.Width < b.Width
		end)
		local best = modes[1]
		return best.Width, best.Height
	end
	local current = GetDisplayMode(displayIndex)
	return current.displayWidth, current.displayHeight
end

function Options.Startup()
	if config.DisableOptions then return end

	local options = EngineOptions
	if not options.DisplayIndex then
		options.DisplayIndex = config.DisplayIndex
	end

	if config.GraphicsApi ~= "" and not table.find(GetSupportedGraphicsApis(), config.GraphicsApi) then
		config.GraphicsApi = "" -- Requested API is not supported, use options' value or default.
	end
	if config.GraphicsApi == "" then -- Do not override, if manually picked.
		local availableGraphicsApis = GetAvailableGraphicsApis()
		config.GraphicsApi = type(options.GraphicsApi) == "string" and options.GraphicsApi or ""
		if not config.GraphicsApi or not table.find(availableGraphicsApis, config.GraphicsApi) then
			config.GraphicsApi = GetDefaultGraphicsApi()
		end
		if not table.find(availableGraphicsApis, config.GraphicsApi) and #availableGraphicsApis > 0 then
			config.GraphicsApi = availableGraphicsApis[1]
		end
	end
	options.GraphicsApi = config.GraphicsApi
	 
	local prevAdapter = options.GraphicsAdapter or { vendorId = 0, deviceId = 0 }
	config.GraphicsAdapterIndex = GetRenderDeviceAdapterIndex(config.GraphicsApi, prevAdapter)
	options.GraphicsAdapter = GetRenderDeviceAdapterData(config.GraphicsApi, config.GraphicsAdapterIndex)
	options.GraphicsAdapterIndex = config.GraphicsAdapterIndex
	if not options.GraphicsAdapter or prevAdapter.vendorId ~= options.GraphicsAdapter.vendorId or prevAdapter.deviceId ~= options.GraphicsAdapter.deviceId then
		Options.Autodetect(options)		
		if Platform.developer and config.Width ~= 0 then
			-- Set engine display options using the values in the config
			options.FullscreenMode = config.FullscreenMode
			options.DisplayIndex = config.DisplayIndex
			
			-- Don't override Resolution if it was already set in DefaultEngineOptions
			if not IsPoint(options.Resolution) then
				options.Resolution = point(config.Width, config.Height)
			end
		end
		SaveEngineOptions()
	end
	
	if options.GraphicsAdapter then
		local gpu = string.lower(options.GraphicsAdapter.name)
		if Platform.pc and (options.GraphicsAdapter.vendorId == const.VendorIds.AMD or string.find(gpu, "amd") or string.find(gpu, "radeon")) then
			hr.D3D12PresentWaitOnAcquire = 1
			hr.SwapchainBuffers = 3
			hr.SSRFullTile8x8 = 1
		end
	end

	-- Update the config display options using the engine options values
	config.DisplayIndex = options.DisplayIndex
	config.FullscreenMode = options.FullscreenMode or 0
	
	if IsPoint(options.Resolution) then
		if options.FullscreenMode and not Platform.console then
			options.Resolution = point(GetValidVideoMode(options.DisplayIndex, options.Resolution:xy()))
		end
		config.Width, config.Height = options.Resolution:xy()
	elseif not config.Width or not config.Height then
		config.Width, config.Height = 0, 0
	end
	
	if options.Vsync ~= nil then
		config.Vsync = options.Vsync
	else
		config.Vsync = true
	end
end

--[[
Option Fixups 

Option fixups can be used to force change option values for all users. They work similarly to 
savegame fixups but hey are separated into two namespaces: EngineOptionFixups and 
AccountOptionFixups. As the names suggest one is for EngineOptions options and the other is 
for AccountOptions.

The fixup function will receive the corresponding table with options as the first parameter.
This is EngineOptions for engine option fixups or AccountStorage.Options for account option 
fixups. The second parameter is the last lua revision where a fixup was applied.

Fixup examples:

function EngineOptionFixups.SMAAAntialiasing(engine_options, last_applied_fixup_revision)
	engine_options.Antialiasing = "SMAA"
end

function AccountOptionFixups.Autosave(account_options, last_applied_fixup_revision)
	account_options.Autosave = true
end
--]]

-- Engine option fixups
-- Executed after the first call to Options.Startup() and before InitRenderEngine()
function Options.FixupEngineOptions()
	EngineOptions.fixups_meta = EngineOptions.fixups_meta or GetDefaultOptionFixupMeta()
	local meta = EngineOptions.fixups_meta
	meta.AppliedOptionFixups = meta.AppliedOptionFixups or {}
	local count, applied = 0, {}

	for fixup, func in sorted_pairs(EngineOptionFixups) do
		if not meta.AppliedOptionFixups[fixup] and type(func) == "function" then
			procall(func, EngineOptions, meta.last_applied_fixup_revision)
			count = count + 1
			applied[#applied + 1] = fixup
			meta.AppliedOptionFixups[fixup] = true
			meta.last_applied_fixup_revision = LuaRevision
		end
	end
	
	if count > 0 then
		SaveEngineOptions()
		DebugPrint(string.format("Applied %d engine option fixup(s): %s\n", count, table.concat(applied, ", ")))
	end
	
	return count
end

-- Account option fixups
-- Executed after a new AccountStorage is loaded
function Options.FixupAccountOptions()
	AccountStorage.Options = AccountStorage.Options or {}
	local opt = AccountStorage.Options
	opt.fixups_meta = opt.fixups_meta or GetDefaultOptionFixupMeta()
	local meta = opt.fixups_meta
	meta.AppliedOptionFixups = meta.AppliedOptionFixups or {}
	local count, applied = 0, {}
	
	for fixup, func in sorted_pairs(AccountOptionFixups) do
		if not meta.AppliedOptionFixups[fixup] and type(func) == "function" then
			procall(func, AccountStorage.Options, meta.last_applied_fixup_revision)
			count = count + 1
			applied[#applied + 1] = fixup
			meta.AppliedOptionFixups[fixup] = true
			meta.last_applied_fixup_revision = LuaRevision
		end
	end
	
	if count > 0 then
		SaveAccountStorage()
		DebugPrint(string.format("Applied %d account option fixup(s): %s\n", count, table.concat(applied, ", ")))
	end
	
	return count
end

local option_groups = config.SoundOptionGroups or {}
config.SoundOptionGroups = option_groups
local option_sound_groups = {}
for option, groups in pairs(option_groups) do
	for _, group in ipairs(groups) do
		option_sound_groups[group] = true
	end
end
if config.SoundGroups then
	for _, group in ipairs(config.SoundGroups) do
		if not option_sound_groups[group] then
			option_groups[group] = option_groups[group] or {group}
		end
	end
else
	config.SoundGroups = table.keys(option_sound_groups, true)
end

if not config.DisableOptions then

function OnMsg.Autorun()
	local taa_option = table.find_value(OptionsData.Options.Antialiasing, "value", "TAA")
	if Platform.pc then
		local graphics_adapter = GetRenderDeviceAdapterData(config.GraphicsApi, config.GraphicsAdapterIndex)
		local gpu_name = string.lower(graphics_adapter.name)
		local is_intel =
			graphics_adapter.vendorId == const.VendorIds.Intel or
			string.find(gpu_name, "intel") or
			string.find(gpu_name, "arc")

		local dlss = hr.TemporalIsTypeSupported("dlss")
		local fsr2 = hr.TemporalIsTypeSupported("fsr2")
		local xess = hr.TemporalIsTypeSupported("xess")

		if dlss then
			taa_option.hr = table.find_value(OptionsData.Options.Antialiasing, "value", "DLSS").hr
		elseif (is_intel or not fsr2) and xess then
			taa_option.hr = table.find_value(OptionsData.Options.Antialiasing, "value", "XESS").hr
		elseif fsr2 then
			taa_option.hr = table.find_value(OptionsData.Options.Antialiasing, "value", "FSR2").hr
		end
	end

	if taa_option.hr == empty_table then
		 -- if for some reason TAA is selected while not_selectable, naming the option "Off" will inform the user of the current situation.
		taa_option.text = T(392695272733, --[[options:Antialiasing is turned off]] "Off")
	end

	local OverrideOptionValues = function(baseValues, overrideValues, skipKeys)
		for overrideKey,overrideValue in pairs(overrideValues) do
			if not table.find(skipKeys, overrideKey) then
				if type(overrideValue) == "table" then
					for key, value in pairs(overrideValue) do
						baseValues[overrideKey][key] = value
					end
				else
					baseValues[overrideKey] = overrideValue
				end
			end
		end
	end

	for option,projectOptionValues in pairs(rawget(_G, "ProjectOptions") or empty_table) do
		if OptionsData.Options[option] then
			for _,projectOptionValue in ipairs(projectOptionValues) do
				local options = OptionsData.Options[option]
				local baseOptionValue = table.find_value(options, "value", projectOptionValue.value)
				if baseOptionValue then
					OverrideOptionValues(baseOptionValue, projectOptionValue, { "value", "text" })
				else
					options[#options + 1] = projectOptionValue
				end
			end
		else
			OptionsData.Options[option] = projectOptionValues
		end
	end

	for option,optionValues in pairs(OptionsData.Options) do
		table.stable_sort(optionValues, function(a, b)
			if a.SortKey and b.SortKey then
				return a.SortKey < b.SortKey
			else
				return a.SortKey
			end
		end)
	end

	if EngineOptions then
		-- Apply video options and save EngineOptions
		local preset = EngineOptions.VideoPreset
		ApplyVideoPreset(preset)
		SaveEngineOptions()
		
		-- Reload account options when reloading Lua
		ApplyAccountOptions()
	end
	Options.InitGraphicsApiCombo()
end

--reload account options when we get new account storage, something that happens on the xbox
function OnMsg.AccountStorageChanged()
	if AccountStorage and next(AccountStorage.Shortcuts) then
		DelayedCall(0, ReloadShortcuts)
	end
	DelayedCall(0, ApplyLanguageOption)
end

function OnMsg.LocalStorageChanged()
	Options.ApplyEngineOptions(EngineOptions)
	terminal.desktop:OnSystemSize(UIL.GetScreenSize())
end

function OnMsg.SystemSize(pt)
	EngineOptions.Resolution = pt
	EngineOptions.DisplayIndex = GetMainWindowDisplayIndex()
	Options.UpdateVideoModesCombo()
	if OptionsObj then
		OptionsObj:SetProperty("Resolution", pt)
		ObjModified(OptionsObj)
	end
end

if Platform.desktop then

function OnMsg.ApplicationQuit()
	local display_index =  GetMainWindowDisplayIndex()
	if EngineOptions.DisplayIndex ~= display_index then
		EngineOptions.DisplayIndex = display_index
		SaveEngineOptions()
	end
end

end -- if Platform.pc

end -- if not config.DisableOptions then

function Options.PickVideoPreset(preset_regexes, gpu)
	for _, v in ipairs(preset_regexes) do
		for _, re in ipairs(v[1]) do
			if gpu:match(re) then
				return v.preset
			end
		end
	end
	
	
	if Platform.xbox_one then
		preset = Platform.xbox_one_x and "xbox_one_x" or "xbox_one"
	elseif Platform.xbox_series then
		preset = Platform.xbox_series_x and "xbox_series_x" or "xbox_series_s"
	elseif Platform.ps4 then
		preset = Platform.xbox_ps4_pro and "ps4_pro" or "ps4"
	elseif Platform.ps5 then
		preset = "ps5"
	end
	if preset then
		return DefaultEngineOptions[preset].VideoPreset
	end
	
	return "High"
end

-- this uses data coming from config table, as ProjectOptions and its data isn't yet loaded
function Options.Autodetect(options)
	if Platform.pc or Platform.steamdeck then
		if not IsPoint(options.Resolution) then
			local currentMode = GetDisplayMode(options.DisplayIndex)
			options.Resolution = point(currentMode.displayWidth, currentMode.displayHeight)
		end
	end

	if not options.GraphicsAdapter then
		options.VideoPreset = "Low"
		return
	end
	
	options.VideoPreset = Options.PickVideoPreset(config.VideoPresetAutodetect or empty_table, string.lower(options.GraphicsAdapter.name))
	
	options.Textures = "High"
	for _,v in ipairs(config.TextureMemoryThresholds or empty_table) do
		if options.GraphicsAdapter.videoRam < v.threshold * 1024 * 1024 then
			options.Textures = v.value
			break
		end
	end
end

function Options.ApplyEngineOptions(local_options)
	local engine_options_defaults = GetTableWithStorageDefaults("local")
	local options_data = OptionsData.Options
	local hr_override

	for k,v in pairs(engine_options_defaults) do
		-- Keys from the defaults
		-- Values from the local EngineOptions
		v = local_options[k]

		local value = table.find_value(options_data[k], "value", v)
		local hr = options_data[k] and options_data[k].hr or value and value.hr
		for hrk, hrv in pairs(hr or empty_table) do
			if type(hrv) == "function" then
				hrv = hrv(v, hrk)
			end
			if hrv ~= nil then
				hr_override = hr_override or {}
				if hr_override[hrk] then
					printf("once", "OptionsData.Options.%s sets hr.%s which was already set by another table", k, hrk)
				end
				hr_override[hrk] = hrv
			end
		end
	end

	if hr_override then
		hr.TR_ReloadSuspended = hr.TR_ReloadSuspended | 1
		table.change_base(hr, hr_override)
		hr.TR_ReloadSuspended = hr.TR_ReloadSuspended & ~1
	end
	
	ApplySoundOptions(local_options)
end

function SetOptionVolume(option, volume)
	for _, group in ipairs(config.SoundOptionGroups[option]) do
		SetOptionsGroupVolume(group, volume)
	end
end

function ApplySoundOptions(local_options)
	local master_volume = local_options.MasterVolume or 1000
	for option in pairs(config.SoundOptionGroups) do
		SetOptionVolume(option, master_volume * (local_options[option] or 1000)/ 1000)
	end
	config.DontMuteWhenInactive = local_options.MuteWhenMinimized ~= nil and not local_options.MuteWhenMinimized or false
end

function Options.InitVideoModesCombo()
	local modes = {}
	for i, mode in ipairs(GetVideoModes(EngineOptions.DisplayIndex, 1024, 720)) do
		local resolution = point(mode.Width, mode.Height)
		local key = tostring(resolution)
		modes[key] = resolution
	end
	if Platform.developer then
		local ultrawide = point(120*21, 120*9)
		modes[tostring(ultrawide)] = ultrawide
	end
	local sorted_modes = table.values(modes)
	table.sort(sorted_modes, function(a, b) return a:x() * a:y() < b:x() * b:y() end)
	OptionsData.Options.Resolution = {}
	for i, v in ipairs(sorted_modes) do
		OptionsData.Options.Resolution[i] = { value = v, text = T{664014484626, "<FormatResolution(pt)>", pt = v}}
	end
	--add custom option if needed
	Options.UpdateVideoModesCombo()
end

function Options.InitGraphicsApiCombo()
	local available = GetAvailableGraphicsApis()	
	OptionsData.Options.GraphicsApi = {
		{ value = "d3d11", text = Untranslated("DirectX 11 (deprecated)"), not_selectable = not table.find(available, "d3d11") },
		{ value = "d3d12", text = Untranslated("DirectX 12"), not_selectable = not table.find(available, "d3d12") },
	}

	if table.count(OptionsData.Options.GraphicsApi, "not_selectable", false) <= 1 then
		local graphicsApiOption = table.find_value(OptionsObject.properties, "id", "GraphicsApi")
		graphicsApiOption.dont_save = true
		graphicsApiOption.no_edit = true
	end
end

function Options.InitGraphicsAdapterCombo(graphicsApi)
	local adapters = {}
	for i = 0,GetNumRenderDeviceAdapters(graphicsApi)-1 do
		local adapterData = GetRenderDeviceAdapterData(graphicsApi, i)
		adapters[i+1] = { value = i, text = Untranslated(adapterData.name) }
	end
	OptionsData.Options.GraphicsAdapterIndex = adapters
end

function Options.UpdateVideoModesCombo()
	local v = point(GetResolution())
	--remove any custom items
	local custom_idx = table.find(OptionsData.Options.Resolution, "custom", true)
	local idx = table.find(OptionsData.Options.Resolution, "value", v)
	if custom_idx and custom_idx ~= idx then
		table.remove(OptionsData.Options.Resolution, custom_idx)
	end
	if not idx then
		--insert current value in correct position
		local entry = { value = v, text = T{664014484626, "<FormatResolution(pt)>", pt = v}, custom = true}
		table.insert_sorted(OptionsData.Options.Resolution, entry, "value")
	end
end

OptionsData.Options.VideoPreset = {
	{ value = "Low", text = T(644, "Low"), not_selectable = Platform.console },
	{ value = "Medium", text = T(645, "Medium"), not_selectable = Platform.console },
	{ value = "High", text = T(7375, "High"), not_selectable = Platform.console },
	{ value = "Ultra", text = T(3551, "Ultra"), not_selectable = Platform.console },
	{ value = "XboxOne", text = Untranslated("*XboxOne"), not_selectable = not Platform.developer },
	{ value = "XboxOneX", text = Untranslated("*XboxOneX"), not_selectable = not (Platform.xbox_one_x or Platform.developer) },
	{ value = "XboxSeriesS", text = Untranslated("*XboxSeriesS"), not_selectable = not (Platform.xbox_series_s or Platform.developer) },
	{ value = "XboxSeriesXQuality", text = Platform.developer and Untranslated("*XboxSeriesXQuality") or T(709029849246, "Quality"), not_selectable = not (Platform.xbox_series_x or Platform.developer) },
	{ value = "XboxSeriesXPerformance", text = Platform.developer and Untranslated("*XboxSeriesXPerformance") or T(731233321844, "Performance"), not_selectable = not (Platform.xbox_series_x or Platform.developer) },
	{ value = "PS4", text = Untranslated("*PS4"), not_selectable = not Platform.developer },
	{ value = "PS4Pro", text = Untranslated("*PS4Pro"), not_selectable = not Platform.developer },
	{ value = "PS5Quality", text = Platform.developer and Untranslated("*PS5Quality") or T(709029849246, "Quality"), not_selectable = not (Platform.ps5 or Platform.developer) },
	{ value = "PS5Performance", text = Platform.developer and Untranslated("*PS5Performance") or T(731233321844, "Performance"), not_selectable = not (Platform.ps5 or Platform.developer) },
	{ value = "Switch", text = Untranslated("*Switch"), not_selectable = not Platform.developer },
	{ value = "SteamDeck", text = Untranslated("Steam Deck"), not_selectable = not (Platform.steamdeck or Platform.developer) },
	{ value = "Custom", text = T(6843, "*Custom"), not_selectable = Platform.console },
}

OptionsData.Options.FullscreenMode = {
	{ value = 0, text = T(443238066363, --[[Options dialog fullscreen mode]] "Windowed"), },
	{ value = 1, text = T(873558273070, --[[Options dialog fullscreen mode]] "Fullscreen"), },
}

OptionsData.Options.MaxFps = {
	{ value = "30", text = Untranslated("30 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 30 } },
	{ value = "60", text = Untranslated("60 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 60 } },
	{ value = "120", text = Untranslated("120 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 120 } },
	{ value = "144", text = Untranslated("144 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 144 } },
	{ value = "240", text = Untranslated("240 ") .. T(206424973826, --[[options: frame limit]] "FPS"), hr = { MaxFps = 240 } },
	{ value = "Unlimited", text = T(715166204973, --[[options: frame limit]] "Unlimited"), hr = { MaxFps = 0 } },
}
OptionsData.Options.SSAO = {
	{ value = "Off", text = T(549548241533, "Off"), hr = { EnableScreenSpaceAmbientObscurance = 0 } },
	{ value = "On", text = T(336462699824, "On"), hr = { EnableScreenSpaceAmbientObscurance = 1 } },}

OptionsData.Options.SSR = {
	{ value = "Off", text = T(347421390938, --[[options:SSR is off]] "Off"), hr = { EnableScreenSpaceReflections = 0 } },
	{ value = "Low", text = T(967597583816, --[[options:SSR is turned to low]] "Low"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 4, SSRSkipPixels = 2, SSRPassBehindPixels = -32, SSRThresholdParentDistance = 0 } },
	{ value = "Medium", text = T(711881918198, --[[options:SSR is turned to Medium]] "Medium"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 2, SSRSkipPixels = 1, SSRPassBehindPixels = -96, SSRThresholdParentDistance = config.SSRThresholdParentDistance } },
	{ value = "High", text = T(350030693801, --[[options:SSR is turned to high]] "High"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 1, SSRPassBehindPixels = -192, SSRThresholdParentDistance = config.SSRThresholdParentDistance } },
	{ value = "Ultra", text = T(363062651990, --[[options:SSR is turned to Ultra]] "Ultra"), hr = { EnableScreenSpaceReflections = 1, SSRDownsampleCoef = 1, SSRPassBehindPixels = -192, SSRThresholdParentDistance = 0 } },
}

OptionsData.Options.Bloom = {
	{ value = "Off", text = T(897923163870, --[[options:Bloom is off]] "Off"), hr = { EnablePostProcBloom = 0 } },
	{ value = "On", text = T(962119091084, --[[options:Bloom is on]] "On"), hr = { EnablePostProcBloom = 1 } },
}

OptionsData.Options.EyeAdaptation = {
	{ value = "Off", text = T(764902318645, --[[options:Eye Adaptation is off]] "Off"), hr = { AutoExposureMode = 0 } },
	{ value = "On", text = T(310678453010, --[[options:Eye Adaptation is on]] "On"), hr = { AutoExposureMode = 1 } },
}

OptionsData.Options.Vignette = {
	{ value = "Off", text = T(173515508906, --[[options:Vignette is off]] "Off"), hr = { EnablePostProcVignette = 0 } },
	{ value = "On", text = T(724497759523, --[[options:Vignette is on]] "On"), hr = { EnablePostProcVignette = 1} },
}

OptionsData.Options.ChromaticAberration = {
	{ value = "Off", text = T(535014732326, --[[options:Chromatic Aberration is off]] "Off"), hr = { PostProcChromaticAberration = 0 } },
	{ value = "On", text = T(945084644408, --[[options:Chromatic Aberration is on]] "On"), hr = { PostProcChromaticAberration = 100 } },
}

OptionsData.Options.FPSCounter = {
	{ value = "Off", text = T(290121664929, --[[options:FPS counter is off]] "Off"), hr = { FpsCounter = 0 } },
	{ value = "Fps", text = T(783476822556, --[[options:FPS counter shows frames per second]] "FPS"), hr = { FpsCounter = 1 } },
	{ value = "Ms", text = T(271886807258, --[[options:FPS counter shows miliseconds]] "ms"), hr = { FpsCounter = 2 } },
}

OptionsData.Options.Textures = {
	{ value = "Low", text = T(812680094837, --[[options:Texture quality is set to Low]] "Low"), hr = { StreamingVideoMemory = 384, BillboardMaterialQualityReductionLevel = 1 } },
	{ value = "Low (Consoles)", text = Untranslated("Low (Consoles)"), hr = { StreamingVideoMemory = 512, BillboardMaterialQualityReductionLevel = 1 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Medium (Consoles)", text = Untranslated("Medium (Consoles)"), hr = { StreamingVideoMemory = 1024, BillboardMaterialQualityReductionLevel = 1 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Medium", text = T(645, --[[options:Texture quality is set to Medium]] "Medium"), hr = { StreamingVideoMemory = 1024, BillboardMaterialQualityReductionLevel = 0 } },
	{ value = "High", text = T(396237728087, --[[options:Texture quality is set to High]] "High"), hr = { StreamingVideoMemory = 2048, BillboardMaterialQualityReductionLevel = 0 } },
	{ value = "Ultra", text =  T(324283091069, --[[options:Texture quality is set to Ultra]] "Ultra"), hr = { StreamingVideoMemory = 4096, BillboardMaterialQualityReductionLevel = 0 } },
}

OptionsData.Options.Terrain = {
	{ value = "Low (Switch)", text = Untranslated("*Low (Switch)"), hr = { TR_ChunkSize = 256, TR_MaxChunks = 64, TR_MaxChunksPerFrame = 1, TR_MaterialQualityReductionLevel = 2, TR_UseQualityCompression = 0 }, not_selectable = not Platform.developer },
	{ value = "Low", text = T(619416576830, --[[options:Terrain detail is set to Low]] "Low"), hr = { TR_ChunkSize = 256, TR_MaxChunks = 64, TR_MaxChunksPerFrame = 1, TR_MaterialQualityReductionLevel = 2 } },
	{ value = "Medium", text = T(482982848821, --[[options:Terrain detail is set to Medium]] "Medium"), hr = { TR_ChunkSize = 256, TR_MaxChunks = 128, TR_MaxChunksPerFrame = 2, TR_MaterialQualityReductionLevel = 1 } },
	{ value = "High", text = T(424607201144, --[[options:Terrain detail is set to High]] "High"), hr = { TR_ChunkSize = 512, TR_MaxChunks = 128, TR_MaxChunksPerFrame = 2, TR_MaterialQualityReductionLevel = 0 } },
	{ value = "Ultra", text = T(340208038771, --[[options:Terrain detail is set to Ultra]] "Ultra"), hr = { TR_ChunkSize = 512, TR_MaxChunks = 128, TR_MaxChunksPerFrame = 5, TR_MaterialQualityReductionLevel = 0 } },
}

OptionsData.Options.Effects = {
	{ value = "Low (Switch)", text = Untranslated("*Low (Switch)"), hr = { FXDetailThreshold = 70, RainQuality = const.RainQualityVeryLow, RainStreaksCount = 16 * 1024, MaxParticles = 6000, TargetParticles = 5000, MaxParticlesWithCollision = 0, }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Low", text = T(921959811873, --[[options:Effects detail is set to Low]] "Low"), hr = { FXDetailThreshold = 70, RainQuality = const.RainQualityLow, MaxParticles = 6000, TargetParticles = 5000, MaxParticlesWithCollision = 50,  } },
	{ value = "Medium", text = T(177066169751, --[[options:Effects detail is set to Medium]] "Medium"), hr = { FXDetailThreshold = 50, RainQuality = const.RainQualityMedium, MaxParticles = 7500, TargetParticles = 6500, MaxParticlesWithCollision = 150,} },
	{ value = "High", text = T(354778733499, --[[options:Effects detail is set to High]] "High"), hr = { FXDetailThreshold = 0, RainQuality = const.RainQualityHigh, MaxParticles = 30000, TargetParticles = 29000, MaxParticlesWithCollision = 300, } },
	{ value = "Ultra", text = T(107890243019, --[[options:Effects detail is set to Ultra]] "Ultra"), hr = { FXDetailThreshold = 0, RainQuality = const.RainQualityUltra, MaxParticles = 100000, TargetParticles = 95000, MaxParticlesWithCollision = 500,  } },
}

OptionsData.Options.ViewDistance = {
	{ value = "Low (Switch)", text = Untranslated("*Low (Switch)"), hr = { LODDistanceModifier = 10, BillboardDistanceModifier = 25, DistanceModifier = 30 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Low", text = T(157135452050, --[[options:View distance is set to Low]] "Low"), hr = { LODDistanceModifier = 50, BillboardDistanceModifier = 30, DistanceModifier = 54 } },
	{ value = "Medium", text = T(108271291689, --[[options:View distance is set to Medium]] "Medium"), hr = { LODDistanceModifier = 75, BillboardDistanceModifier = 40, DistanceModifier = 72 } },
	{ value = "High", text = T(215175247095, --[[options:View distance is set to High]] "High"), hr = { LODDistanceModifier = 100, BillboardDistanceModifier = 50, DistanceModifier = 100 } },
	{ value = "Ultra", text = T(239271893639, --[[options:View distance is set to Ultra]] "Ultra"), hr = { LODDistanceModifier = 120, BillboardDistanceModifier = 50, DistanceModifier = 150 } },
}

OptionsData.Options.Shadows = {
	{ value = "Off", text = T(642008481801, --[[options:Shadows are turned off]] "Off"), hr = { Shadowmap = 0, ShadowmapSize = 0, LightShadows = 0 } },
	{ value = "Low", text = T(770274668602, --[[options:Shadows quality is set to Low]] "Low"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 1536,
		ShadowPCFSize = 1,
		ShadowCSMProjectionFit = 1,
		ShadowCSMResolutionPercent = -65,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 1024,
		LightShadowsHighQuality = 2,
		LightShadowsLowQuality = 32 }},
	{ value = "Medium (PS4,XboxOne)", text = Untranslated("*Medium (PS4,XboxOne)"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 2048,
		ShadowPCFSize = 2,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = -50,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 0,
		LightShadowsSize = 0 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Medium", text = T(955331005438, --[[options:Shadows quality is set to Medium]] "Medium"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 2048,
		ShadowPCFSize = 2,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = -50,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 2048,
		LightShadowsHighQuality = 8,
		LightShadowsLowQuality = 32 }},
	{ value = "High", text = T(875151214288, --[[options:Shadows quality is set to High]] "High"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 4096,
		ShadowPCFSize = 3,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = 0,
		ShadowReceiversRatio = 100,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 4096,
		LightShadowsHighQuality = 8,
		LightShadowsLowQuality = 128 }},
	{ value = "High (PS4Pro)", text = Untranslated("*High (PS4Pro)"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 4096,
		ShadowPCFSize = 3,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent = -50,
		ShadowReceiversRatio = 1,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 0,
		LightShadowsSize = 0 }, not_selectable = Platform.pc and not Platform.developer },
	{ value = "Ultra", text = T(3551, --[[options:Shadows quality is set to Ultra]] "Ultra"), hr = {
		Shadowmap = 1,
		ShadowmapSize = 6144,
		ShadowPCFSize = 3,
		ShadowCSMProjectionFit = 2,
		ShadowCSMResolutionPercent=0,
		ShadowReceiversRatio = 100,
		ShadowSDSMEnable = 1,
		ShadowCSMUpdateFrequency = "0",
		LightShadows = 1,
		LightShadowsSize = 8192,
		LightShadowsHighQuality = 8,
		LightShadowsLowQuality = 128 }},
}

local function ResolveAntialiasingOption(antialiasing)
	if antialiasing == "TAA" then
		local antialiasing_option = table.find_value(OptionsData.Options.Antialiasing, "value", antialiasing)
		local antialiasing_index = table.findfirst(OptionsData.Options.Antialiasing, function(idx, item)
			return item.value ~= antialiasing_option.value and item.hr.ResolutionUpscale == antialiasing_option.hr.ResolutionUpscale
		end)
		return OptionsData.Options.Antialiasing[antialiasing_index].value
	end
	return antialiasing
end

local function NotSelectableTemporalUpscalingOption(self, options_obj)
	return ResolveAntialiasingOption(options_obj.Antialiasing) ~= self.value
end

function IsTemporalAntialiasingOption(antialiasing_value)
	local antialiasing_option = table.find_value(OptionsData.Options.Antialiasing, "value", antialiasing_value)
	local method = antialiasing_option.hr.ResolutionUpscale
	return method and hr.IsTemporalResolutionUpscale(method)
end

OptionsData.Options.Upscaling = {
	{ value = "Off", text = T(392695272733, --[[options:Upscaling is turned off]] "Off"), hr = { ResolutionUpscale = "none" }, not_selectable = true },
	{ value = "DLSS", text = Untranslated("NVIDIA DLSS 2"), not_selectable = NotSelectableTemporalUpscalingOption,
		help_text = T(727329502546, "This option is forced based on the current anti-aliasing option.") },
	{ value = "FSR2", text = Untranslated("AMD FSR 2"), not_selectable = NotSelectableTemporalUpscalingOption,
		help_text = T(727329502546, "This option is forced based on the current anti-aliasing option.") },
	{ value = "XESS", text = Untranslated("Intel XeSS"), not_selectable = NotSelectableTemporalUpscalingOption,
		help_text = T(727329502546, "This option is forced based on the current anti-aliasing option.") },
	{ value = "FSR", text = Untranslated("AMD FSR 1.0"), hr = { ResolutionUpscale = "fsr" },
		not_selectable = function(self, options_obj) return IsTemporalAntialiasingOption(options_obj.Antialiasing) end,
		help_text = T(237540095950, "AMD FidelityFX Super Resolution 1.0 is a cutting edge super-optimized spatial upscaling technology that produces impressive image quality at fast framerates.") },
	{ value = "Bilinear", text = T(663907815524, --[[options:Bilinear upscaling method]] "Bilinear"), hr = { ResolutionUpscale = "none", },
		not_selectable = function(self, options_obj) return IsTemporalAntialiasingOption(options_obj.Antialiasing) end,
		help_text = T(168111358410, "The final image is upscaled using a quick bilinear filter.") },
}

OptionsData.Options.ResolutionPercent = {
	{ value = "100", text = T(372575555234, --[[options:Resolution percent 100%]] "Native (<percent(100)>)"), hr = { ResolutionPercent = 100, },
		not_selectable = function(self, options_obj) return options_obj.Antialiasing == "XESS" end, },
	{ value = "77", text = T(908658168865, --[[options:Resolution percent 77%]] "Ultra Quality (<percent(77)>)"), hr = { ResolutionPercent = 77, }, },
	{ value = "67", text = T(924914589055, --[[options:Resolution percent 67%]] "Quality (<percent(67)>)"), hr = { ResolutionPercent = 67, }, },
	{ value = "59", text = T(359371270894, --[[options:Resolution percent 59%]] "Balanced (<percent(59)>)"), hr = { ResolutionPercent = 59, }, },
	{ value = "50", text = T(326717026030, --[[options:Resolution percent 50%]] "Performance (<percent(50)>)"), hr = { ResolutionPercent = 50, }, },
	{ value = "33", text = T(243189993265, --[[options:Resolution percent 33%]] "Ultra Performance (<percent(33)>)"), hr = { ResolutionPercent = 33, },
		not_selectable = function(self, options_obj) return not IsTemporalAntialiasingOption(options_obj.Antialiasing) or options_obj.Antialiasing == "XESS" end, },
}

OptionsData.Options.Antialiasing = {
	{ value = "Off", text = T(392695272733, --[[options:Antialiasing is turned off]] "Off"), hr = { EnablePostProcAA = 0, } },
	{ value = "FXAA", text = Untranslated("FXAA"), hr = { EnablePostProcAA = 1 },
		help_text = T(261152948496, "Fast Approximate Anti-Aliasing (FXAA) is a high performance and high quality screen-space software approximation to anti-aliasing.") },
	{ value = "SMAA", text = Untranslated("SMAA"), hr = { EnablePostProcAA = 2 },
		help_text = T(941529887409, "Enhanced Subpixel Morphological Anti-Aliasing (SMAA) is an image-based, post-processing anti-aliasing technique.") },
	{ value = "TAA",
		text = Untranslated("TAA"), hr = empty_table,
		not_selectable = function(self) return self.hr == empty_table end,
		help_text = T(872180326804, "Automatically picks a temporal anti-aliasing technique based on the machine's GPU.") },
	{ value = "DLSS",
		text = T{629765447024, "<name>", name = function() return Untranslated(OptionsObj and OptionsObj.ResolutionPercent == "100" and "NVIDIA DLAA 2" or "NVIDIA DLSS 2") end},
		hr = { ResolutionUpscale = "dlss" },
		not_selectable = function(self) return not hr.TemporalIsTypeSupported(self.hr.ResolutionUpscale) end,
		help_text = T(931850450677, "NVIDIA DLSS uses AI Super Resolution to provide the highest possible frame rates at maximum graphics settings. DLSS requires an NVIDIA RTX graphics card.") },
	{ value = "FSR2",
		text = Untranslated("AMD FSR 2"),
		hr = { ResolutionUpscale = "fsr2" },
		not_selectable = function(self) return not hr.TemporalIsTypeSupported(self.hr.ResolutionUpscale) end,
		help_text = T(266757012718, "AMD FidelityFX Super Resolution 2 is a cutting-edge temporal upscaling algorithm that produces high resolution frames from lower resolution inputs.") },
	{ value = "XESS",
		text = Untranslated("Intel XeSS"),
		hr = { ResolutionUpscale = "xess" },
		not_selectable = function(self) return not hr.TemporalIsTypeSupported(self.hr.ResolutionUpscale) end,
		help_text = T(825363827167, "Intel Xe Super Sampling (XeSS) technology uses machine learning to deliver higher performance with exceptional image quality.") },
}

OptionsData.Options.Anisotropy = {
	{ value = "Off", text = T(692210423102, --[[options:Anisotropy is turned off]] "Off"), hr = { Anisotropy = 0 } },
	{ value = "2x", text = Untranslated("2x"), hr = { Anisotropy = 1 } },
	{ value = "4x", text = Untranslated("4x"), hr = { Anisotropy = 2 } },
	{ value = "8x", text = Untranslated("8x"), hr = { Anisotropy = 3 } },
	{ value = "16x", text = Untranslated("16x"), hr = { Anisotropy = 4 } },
}

OptionsData.Options.Lights = {
	{ value = "Low", text = T(709410953049, --[[options:Lights are turned to Low]] "Low"), hr = { LightsRadiusModifier = 90 } },
	{ value = "Medium", text = T(943866004028, --[[options:Lights are turned to Medium]] "Medium"), hr = { LightsRadiusModifier = 95} },
	{ value = "High", text = T(364201072641, --[[options:Lights are turned to High]] "High"), hr = { LightsRadiusModifier = 100 } },
}

OptionsData.Options.ObjectDetail = {
	{ value = "Very Low", SortKey = 1000, text = T(717573023955, --[[options:Object detail is turned to Very Low]] "Very Low"),
		ObjectLODPercents = 50, Optionals = 50, EyeCandies = 0,
		hr = { ObjectLODCapMin = 1, LightShadowsDetailLevel = 0, LightShadowsMinContribDistance = 0, ClutterDetail = 0.0, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 0,
			AnimUpdateF_Dist0 = 150000, AnimUpdateF_Dist1 = 600000, },
	},
	{ value = "Low", SortKey = 2000, text = T(215633457448, --[[options:Object detail is turned to Low]] "Low"),
		ObjectLODPercents = 50, Optionals = 50, EyeCandies = 33,
		hr = { ObjectLODCapMin = 0, LightShadowsDetailLevel = 1, LightShadowsMinContribDistance = 40, ClutterDetail = 0.25, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 400,
			AnimUpdateF_Dist0 = 200000, AnimUpdateF_Dist1 = 800000, },
	},
	{ value = "Medium", SortKey = 3000, text = T(679289081998, --[[options:Object detail is turned to Medium]] "Medium"),
		ObjectLODPercents = 75, Optionals = 75, EyeCandies = 66,
		hr = { ObjectLODCapMin = 0, LightShadowsDetailLevel = 2, LightShadowsMinContribDistance = 60, ClutterDetail = 0.50, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 600,
			AnimUpdateF_Dist0 = 300000, AnimUpdateF_Dist1 = 900000, },
	},
	{ value = "High", SortKey = 4000, text = T(564085803851, --[[options:Object detail is turned to High]] "High"),
		ObjectLODPercents = 100,  Optionals = 100, EyeCandies = 100,
		hr = { ObjectLODCapMin = 0, LightShadowsDetailLevel = 3, LightShadowsMinContribDistance = 100, ClutterDetail = 1.0, UpdatedInstancesBudget = -1, BillboardDirectionsMaxDistance = 750,
			AnimUpdateF_Dist0 = 500000, AnimUpdateF_Dist1 = 2000000, },
	},
}

OptionsData.Options.Postprocess = {
	{ value = "Low", text = T(432248124587, --[[options:Postprocessing is turned to Low]] "Low"), hr = { SAOQuality = 0, SAOMipBase = 2 } },
	{ value = "Medium", text = T(550662244805, --[[options:Postprocessing is turned to Medium]] "Medium"), hr = { SAOQuality = 0, SAOMipBase = 1, } },
	{ value = "High", text = T(157332897114, --[[options:Postprocessing is turned to High]] "High"), hr = { SAOQuality = 1, SAOMipBase = 1, } },
	{ value = "Ultra", text = T(591239139006, --[[options:Postprocessing is turned to Ultra]] "Ultra"), hr = { SAOQuality = 2, SAOMipBase = 0, } },
}

OptionsData.Options.Sharpness = {
	{ value = "Off", text = T(571191621995, --[[options:Sharpness is turned Off]] "Off"), hr = { Sharpness = 0 } },
	{ value = "Low", text = T(291279322471, --[[options:Sharpness is turned to Low]] "Low"), hr = { Sharpness = 0.2 } },
	{ value = "Medium", text = T(548203462360, --[[options:Sharpness is turned to Medium]] "Medium"), hr = { Sharpness = 0.5 } },
	{ value = "High", text = T(213880173168, --[[options:Sharpness is turned to High]] "High"), hr = { Sharpness = 0.8 } },
}

OptionsCategories = {
	{id = "Display",     display_name = T(412409389789, "Display"),        caps_name = T(517337015408, "DISPLAY"), no_edit = Platform.console and Platform.goldmaster, },
	{id = "Video",       display_name = T(255390845026, "Video"),          caps_name = T(325469437176, "VIDEO")},
	{id = "Audio",       display_name = T(973319776875, "Audio"),          caps_name = T(278460229053, "AUDIO")},
	{id = "Controls",    display_name = T(437489721989, "Controls"),       caps_name = T(431903983139, "CONTROLS")},
	{id = "Gameplay",    display_name = T(350787334289, "Gameplay"),       caps_name = T(858632259775, "GAMEPLAY")},
	{id = "Keybindings", display_name = T(867036363190, "Key Bindings"),   caps_name = T(852769320242, "KEY BINDINGS"), 
		no_edit = function() return Platform.console end, },
	{id = "ModOptions",  display_name = T(454731851212, "Mod Options"),             caps_name = T(655539268008, "MOD OPTIONS"), 
		no_edit = function() return not config.Mods or not HasModsWithOptions() end },
	{id = "ChangeUser",  display_name = T(173037664401, "Change Profile"), caps_name = T(584707216514, "CHANGE PROFILE"), 
		no_edit = function() return HideChangeUserCategory() or not (Platform.xbox or Platform.windows_store) or GameState.gameplay end, 
		run = function() CreateRealTimeThread(function() if Platform.xbox then XboxChangeProfile() else WindowsStoreSignInUser() end end) end, },
	{id = "Credits",     display_name = T(283802894796, "Credits"),           caps_name = T(465539577876, "CREDITS"),
		no_edit = function() return GameState.gameplay or HideCreditsInOptions() end,},
}

function HideChangeUserCategory()
	return false
end

function HideCreditsInOptions()
	return false
end

function ApplyAccountOptions()
	Msg("ApplyAccountOptions")
	ApplyProjectAccountOptions()
end

function ApplyProjectAccountOptions() end -- actual work must be done in project-specific ProjectOptions.lua
function ApplyMapEngineSettings(map) end -- override this in project-specific code to tweak engine options per map

function OnMsg.OptionsApply()
	ApplyAccountOptions()
	clutter.Regenerate()
end

OnMsg.AccountStorageChanged = ApplyAccountOptions

function GetObjectDetailsName()
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	return OptionsObj.ObjectDetail
end

function SetObjectDetail(details, all_hrs, dont_apply_filters)
	local on_map = (GetMap() ~= "")
	
	if on_map then
		SuspendPassEdits("SetObjectDetail")
	end
	
	local params = {}
	Msg("SetObjectDetail", "init", params)
	
	local entry = table.find_value(OptionsData.Options.ObjectDetail, "value", details)
	if all_hrs then
		for hr_name, hr_value in pairs(entry.hr) do
			hr[hr_name] = hr_value
		end
	else
		hr.LightShadowsDetailLevel = entry.hr.LightShadowsDetailLevel
	end
	
	if on_map then
		HideObjectsByDetailClass(entry.Optionals, 100, entry.EyeCandies)

		if not dont_apply_filters and IsEditorActive() then
			XEditorFiltersApply()
		end
	end
	
	Msg("SetObjectDetail", "done", params)	
	
	if on_map then
		ResumePassEdits("SetObjectDetail")
	end
	
	return entry.Optionals, entry.EyeCandies
end

function EngineSetObjectDetail(details, dont_apply_filters)
	if EngineOptions.ObjectDetail == details then return end
	
	EngineOptions.ObjectDetail = details
	SaveEngineOptions()
	SaveAccountStorage(5000)
	local optionals, eye_candies = SetObjectDetail(EngineOptions.ObjectDetail, "all hrs", dont_apply_filters)
	Msg("GameOptionsChanged", "Video")
	print(string.format("Object details: %s, Optionals: %d%%, Eye candies: %d%%, Lights: %d",
		EngineOptions.ObjectDetail, optionals, eye_candies, #GetLights()
	))
	XEditorUpdateStatusText()
end

local s_PreSaveMapDetails = false

function OnMsg.PreSaveMap()
	local current_details = GetObjectDetailsName()
	if current_details ~= "High" then
		s_PreSaveMapDetails = current_details
		SetObjectDetail("High", nil, "dont_apply_filters")
	end
end

function OnMsg.PostSaveMap()
	if s_PreSaveMapDetails then
		SetObjectDetail(s_PreSaveMapDetails, nil, "dont_apply_filters")
		s_PreSaveMapDetails = false
	end
end

function OnMsg.PostNewMapLoaded()
	CreateGameTimeThread(function()
		SetObjectDetail(GetObjectDetailsName(), "all hrs")
	end)
end

function ApplyLanguageOption()
	--cannot change language on consoles
	if Platform.console then
		return
	end
	local new_lang = GetAccountStorageOptionValue("Language")
	if SetLanguage(new_lang) then --set global variable
		SaveLanguageOption(GetLanguage()) --save permanently the result in the registry (e.g. "Auto" would be resolved into a specific lang)
		MountLanguage()
		LoadTranslationTables() --reload loc table
		InitWindowsImeState()
	end
end

function ApplyBrightness(val)
	val = val or EngineOptions.Brightness
	if val then
		hr.DisplayGamma = 1500 - val
	end
end

function UpdateUIStyleGamepad(gamepad)
	gamepad = gamepad and (Platform.console or IsXInputControllerConnected())
	ChangeGamepadUIStyle({ [1] = gamepad })
end

function OnMsg.ApplyAccountOptions()
	if AccountStorage then
		UpdateUIStyleGamepad(GetAccountStorageOptionValue("Gamepad"))
	else
		UpdateUIStyleGamepad(not not Platform.console)
	end
end

function GetDisplayAreaMargin()
	if Platform.playstation then
		local safe_w, safe_h = UIL.GetSafeArea()
		
		local screen_size = UIL.GetScreenSize()
		local screen_w, screen_h = screen_size:xy()
		local margin = MulDivRound(safe_w, 100, screen_w)
		
		return margin
	else
		return EngineOptions and EngineOptions.DisplayAreaMargin or 0
	end
end