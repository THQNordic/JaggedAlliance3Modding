GameDisabledOptions = {}

if FirstLoad then
	OptionsObj = false -- the one that is being edited
	OptionsObjOriginal = false -- the one that stores the values when the UI was opened, to be applied on Cancel()
end

g_PlayStationControllerText = T(521078061184, --[[PS controller]] "Controller")
g_PlayStationWirelessControllerText = T(424526275353, --[[PS controller message]] "Wireless Controller")

if config.DisableOptions then return end

MapVar("g_SessionOptions", {}) -- session options in savegame-type games are just a table in the savegame

function CheckIfMoreThanOneVideoPresetIsAllowed()
	local num_allowed_presets = 0
	for _, preset in pairs(OptionsData.Options.VideoPreset) do
		if not preset.not_selectable then
			num_allowed_presets = num_allowed_presets + 1
		end
	end
	
	return num_allowed_presets > 1
end

DefineClass.OptionsObject = {
	__parents = { "PropertyObject" },
	shortcuts = false,
	props_cache = false,
	
	-- storage is "local", "account", "session"
	-- items is Options.OptionsData[id], if not specified
	-- default values are taken from GetDefaultEngineOptions()
	properties = {
		-- Video
		{ name = T(590606477665, "Preset"), id = "VideoPreset", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().VideoPreset, no_edit = not CheckIfMoreThanOneVideoPresetIsAllowed() and Platform.goldmaster,
			help_text = T(582113441661, "A predefined settings preset for different levels of hardware performance."), },
		{ name = T(864821413961, "Antialiasing"), id = "Antialiasing", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Antialiasing, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(110177097630, "Smooths out jagged edges, reduces shimmering, and improves overall visual quality."), },
		{ name = T(809013434667, "Resolution Percent"), id = "ResolutionPercent", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().ResolutionPercent, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(111324603062, "Reduces the internal resolution used to render the game, improving performance at the expense on visual quality."), },
		{ name = T(956327389735, "Upscaling"), id = "Upscaling", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Upscaling,
			no_edit = function(self) return (Platform.console and Platform.goldmaster) or self.ResolutionPercent == "100" end,
			help_text = T(129568659116, "Method used to convert rendering to display resolution."), },
		{ name = T(964510417589, "Shadows"), id = "Shadows", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Shadows, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(500018129164, "Affects the quality and visibility of in-game sun shadows."), },
		{ name = T(940888056560, "Textures"), id = "Textures", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Textures, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(532136930067, "Affects the resolution of in-game textures."), },
		{ name = T(946251115875, "Anisotropy"), id = "Anisotropy", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Anisotropy, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(808058265518, "Affects the clarity of textures viewed at oblique angles."), },
		{ name = T(871664438848, "Terrain"), id = "Terrain", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Terrain, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(545382529099, "Affects the quality of in-game terrain textures and geometry."), },
		{ name = T(318842515247, "Effects"), id = "Effects", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Effects, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(563094626410, "Affects the quality of in-game visual effects."), },
		{ name = T(484841493487, "Lights"), id = "Lights", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Lights, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(307628509612, "Affects the quality and visibility of in-game lights and shadows."), },
		{ name = T(682371259474, "Postprocessing"), id = "Postprocess", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Postprocess, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(291876705355, "Adds additional effects to improve the overall visual quality."), },
		{ name = T(668281727636, "Bloom"), id = "Bloom", category = "Video", storage = "local", editor = "bool", on_value = "On", off_value = "Off", default = GetDefaultEngineOptions().Bloom, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(441093875283, "Simulates scattering light, creating a glow around bright objects."), },
		{ name = T(886248401356, "Eye Adaptation"), id = "EyeAdaptation", category = "Video", storage = "local", editor = "bool", on_value = "On", off_value = "Off", default = GetDefaultEngineOptions().EyeAdaptation, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(663427521283, "Affects the exposure of the image based on the brightess of the scene."), },
		{ name = T(281819101205, "Vignette"), id = "Vignette", category = "Video", storage = "local", editor = "bool", on_value = "On", off_value = "Off", default = GetDefaultEngineOptions().Vignette, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(177496557870, "Creates a darker border around the edges for a more cinematic feel."), },
		{ name = T(364284725511, "Chromatic Aberration"), id = "ChromaticAberration", category = "Video", storage = "local", editor = "bool", on_value = "On", off_value = "Off", default = GetDefaultEngineOptions().ChromaticAberration, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(584969955603, "Simulates chromatic abberation due to camera lens imperfections around the image's edges for a more cinematic feel."), },
		{ name = T(739108258248, "SSAO"), id = "SSAO", category = "Video", storage = "local", editor = "bool", on_value = "On", off_value = "Off", default = GetDefaultEngineOptions().SSAO, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(113014960666, "Simulates the darkening ambient light by nearby objects to improve the depth and composition of the scene."), },
		{ name = T(743968865763, "Reflections"), id = "SSR", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().SSR, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(806489659507, "Adjust the quality of in-game screen-space reflections."), },
		{ name = T(799060022637, "View Distance"), id = "ViewDistance", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().ViewDistance, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(987276010188, "Affects how far the game will render objects and effects in the distance."), },
		{ name = T(595681486860, "Object Detail"), id = "ObjectDetail", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().ObjectDetail, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(351986265823, "Affects the number of less important objects and the overall level of detail."), },
		{ name = T(717555024369, "Framerate Counter"), id = "FPSCounter", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().FPSCounter, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(773245251495, "Displays a framerate counter in the upper-right corner of the screen."), },
		{ name = T(489981061317, "Sharpness"), id = "Sharpness", category = "Video", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Sharpness, no_edit = Platform.console and Platform.goldmaster,
			help_text = T(540870423363, "Affects the sharpness of the image"), },
		
		-- Audio
		{ name = T(723387039210, "Master Volume"), id = "MasterVolume", category = "Audio", storage = "local", editor = "number", min = 0, max = const.MasterMaxVolume or 1000, slider = true, default = GetDefaultEngineOptions().MasterVolume, step = (const.MasterMaxVolume or 1000)/100,
			help_text = T(963240239070, "Sets the overall audio volume."), },
		{ name = T(490745782890, "Music"), id = "Music", category = "Audio", storage = "local", editor = "number", min = 0, max = const.MusicMaxVolume or 600, slider = true, default = GetDefaultEngineOptions().Music, step = (const.MusicMaxVolume or 600)/100,
			no_edit = function () return not IsSoundOptionEnabled("Music") end,
			help_text = T(186072536391, "Sets the volume for the music."), },
		{ name = T(397364000303, "Voice"), id = "Voice", category = "Audio", storage = "local", editor = "number", min = 0, max = const.VoiceMaxVolume or 1000, slider = true, default = GetDefaultEngineOptions().Voice, step = (const.VoiceMaxVolume or 1000)/100,
			no_edit = function () return not IsSoundOptionEnabled("Voice") end,
			help_text = T(792392113273, "Sets the volume for all voiced content."), },
		{ name = T(163987433981, "Sounds"), id = "Sound", category = "Audio", storage = "local", editor = "number", min = 0, max = const.SoundMaxVolume or 1000, slider = true, default = GetDefaultEngineOptions().Sound, step = (const.SoundMaxVolume or 1000)/100,
			no_edit = function () return not IsSoundOptionEnabled("Sound") end,
			help_text = T(582366412662, "Sets the volume for the sound effects like gunshots and explosions."), },
		{ name = T(316134644192, "Ambience"), id = "Ambience", category = "Audio", storage = "local", editor = "number", min = 0, max = const.AmbienceMaxVolume or 1000, slider = true, default = GetDefaultEngineOptions().Ambience, step = (const.AmbienceMaxVolume or 1000)/100,
			no_edit = function () return not IsSoundOptionEnabled("Ambience") end,
			help_text = T(674715210365, "Sets the volume for the non-ambient sounds like the sounds of waves and rain"), },
		{ name = T(706332531616, "UI"), id = "UI", category = "Audio", storage = "local", editor = "number", min = 0, max = const.UIMaxVolume or 1000, slider = true, default = GetDefaultEngineOptions().UI, step = (const.UIMaxVolume or 1000)/100,
			no_edit = function () return not IsSoundOptionEnabled("UI") end,
			help_text = T(597810411326, "Sets the volume for the user interface sounds."), },
		{ name = T(362201382843, "Mute when Minimized"), id = "MuteWhenMinimized", category = "Audio", storage = "local", editor = "bool", default = GetDefaultEngineOptions().MuteWhenMinimized, no_edit = Platform.console,
			help_text = T(365470337843, "All sounds will be muted when the game is minimized."), },
		{ name = T(3583, "Radio Station"), id = "RadioStation", category = "Audio", editor = "choice", default = GetDefaultEngineOptions().RadioStation,
			items = function() return DisplayPresetCombo("RadioStationPreset")() end,
			no_edit = not config.Radio, },
		
		--Gameplay
		--{ name = T{"Subtitles"}, id = "Subtitles", category = "Gameplay", storage = "account", editor = "bool", default = GetDefaultAccountOptions().Subtitles},
		--{ name = T{"Colorblind Mode"}, id = "Colorblind", category = "Gameplay", storage = "account", editor = "bool", default = GetDefaultAccountOptions().Colorblind},
		{ name = T(243042020683, "Language"), id = "Language", category = "Gameplay", SortKey = -1000, storage = "account", editor = "choice", default = GetDefaultAccountOptions().Language, no_edit = Platform.console,
			help_text = T(769937279342, "Sets the game language."), },
		{ name = T(267365977133, "Camera Shake"), id = "CameraShake", category = "Gameplay", SortKey = -900, storage = "account", editor = "bool", on_value = "On", off_value = "Off", default = GetDefaultEngineOptions().CameraShake,
			help_text = T(456226716309, "Allow camera shake effects."), },

		-- Display
		{ name = T(273206229320, "Fullscreen Mode"), id = "FullscreenMode", category = "Display", storage = "local", editor = "choice", default = GetDefaultEngineOptions().FullscreenMode,
			help_text = T(597120074418, "The game may run in a window or on the entire screen.")},
		{ name = T(124888650840, "Resolution"), id = "Resolution", category = "Display", storage = "local", editor = "choice", default = GetDefaultEngineOptions().Resolution,
			help_text = T(515304581653, "The number of pixels rendered on the screen; higher resolutions provide sharper and more detailed images."), },
		{ name = T(276952502249, "Vsync"), id = "Vsync", category = "Display", storage = "local", editor = "bool", default = GetDefaultEngineOptions().Vsync,
			help_text = T(456307855876, "Synchronizes the game's frame rate with the screen's refresh rate thus eliminating screen tearing. Enabling it may reduce performance."), },
		{ name = T(731920619011, "Graphics API"), id = "GraphicsApi", category = "Display", storage = "local", editor = "choice", default = GetDefaultEngineOptions().GraphicsApi, no_edit = function () return not Platform.pc end,
			help_text = T(184665121668, "The DirectX version used by the game renderer."), },
		{ name = T(899898011812, "Graphics Adapter"), id = "GraphicsAdapterIndex", category = "Display", storage = "local", dont_save = true, editor = "choice", default = GetDefaultEngineOptions().GraphicsAdapterIndex, no_edit = function () return not Platform.pc end,
			help_text = T(988464636767, "The GPU that would be used for rendering. Please use the dedicated GPU if possible."), },
		{ name = T(418391988068, "Frame Rate Limit"), id = "MaxFps", category = "Display", storage = "local", editor = "choice", default = GetDefaultEngineOptions().MaxFps,
			help_text = T(190152008288, "Limits the maximum number of frames that the GPU will render per second."), },
		{ name = T(313994466701, "Display Area Margin"), id = "DisplayAreaMargin", category = Platform.console and "Video" or "Display", storage = "local", editor = "number", min = const.MinDisplayAreaMargin, max = const.MaxDisplayAreaMargin, slider = true, default = GetDefaultEngineOptions().DisplayAreaMargin, no_edit = not Platform.xbox and Platform.goldmaster },
		{ name = T(106738401126, "UI Scale"), id = "UIScale", category = Platform.console and "Video" or "Display", storage = "local", editor = "number", min = function() return const.MinUserUIScale end, max = function() return const.MaxUserUIScaleHighRes end, slider = true, default = GetDefaultEngineOptions().UIScale, step = 5, snap_offset = 5,
			help_text = T(316233466560, "Affects the size of the user interface elements, such as menus and text."), },
		{ name = T(106487158051, "Brightness"), id = "Brightness", category = Platform.console and "Video" or "Display", storage = "local", editor = "number", min = -50, max = 1050, slider = true, default = GetDefaultEngineOptions().Brightness, step = 50, snap_offset = 50,
			help_text = T(144889353073, "Affects the overall brightness level."), },
	}
}

function OptionsObject:GetShortcuts()
	self["shortcuts"] = {}
	self.props_cache = false
	if Platform.console and not g_KeyboardConnected then
		return 
	end
	local actions = XShortcutsTarget and XShortcutsTarget:GetActions()
	if actions then
		for _, action in ipairs(actions) do
			if action.ActionBindable then
				local id = action.ActionId
				local defaultActions = false
				if action.default_ActionShortcut and action.default_ActionShortcut ~= "" then
					defaultActions = defaultActions or {}
					defaultActions[1] = action.default_ActionShortcut
				end
				if action.default_ActionShortcut2 and action.default_ActionShortcut2 ~= "" then
					defaultActions = defaultActions or {}
					defaultActions[2] = action.default_ActionShortcut2
				end
				if action.default_ActionGamepad and action.default_ActionGamepad ~= "" then
					defaultActions = defaultActions or {}
					defaultActions[3] = action.default_ActionGamepad
				end
				self[id] = defaultActions
				table.insert(self["shortcuts"], {
					name = action.ActionName,
					id = id,
					sort_key = action.ActionSortKey,
					mode = action.ActionMode or "",
					category = "Keybindings",
					action_category = action.BindingsMenuCategory,
					storage = "shortcuts",
					editor = "hotkey",
					keybinding = true,
					default = defaultActions,
					mouse_bindable = action.ActionMouseBindable,
					single_key = action.ActionBindSingleKey,
				})
			end
		end
	end
	table.stable_sort(self["shortcuts"], function(a, b)
		if a.action_category == b.action_category then
			return a.sort_key < b.sort_key
		else
			return a.action_category < b.action_category
		end
	end)
	
	local currentCategory = false
	for i, s in ipairs(self["shortcuts"]) do
		local newCategory = s.action_category
		if currentCategory ~= newCategory then
			local preset = table.get(Presets, "BindingsMenuCategory", "Default", newCategory)
			s.separator = preset and preset.Name or Untranslated(newCategory)
		end
		currentCategory = newCategory
	end
end

function OptionsObject:GetProperties()
	if self.props_cache then
		return self.props_cache
	end
	local props = {}
	local static_props = PropertyObject.GetProperties(self)
	-- add keybindings
	if not self["shortcuts"] or not next(self["shortcuts"]) then	
		self:GetShortcuts()
	end
	props = table.copy(static_props,"deep")
	table.stable_sort(props, function(a,b)
		return (a.SortKey or 0) < (b.SortKey or 0)
	end)
	props = table.iappend(props,self["shortcuts"])
	self.props_cache = props
	return props
end

function OptionsObject:SaveToTables(properties)
	properties = properties or self:GetProperties()
	local storage_tables = {
		["local"] = EngineOptions,
		account = AccountStorage and AccountStorage.Options,
		session = g_SessionOptions,
		shortcuts = AccountStorage and AccountStorage.Shortcuts,
	}
	for _, prop in ipairs(properties) do
		local storage = prop.storage or "account"
		local storage_table = storage_tables[storage]
		if storage_table then
			local saved_value
			local value = self:GetProperty(prop.id)
			-- only add differences to storage tables
			local default = prop_eval(prop.default, self, prop)

			if value ~= default then
				if type(value) == "table" then
					saved_value = table.copy(value)
					for key, val in pairs(saved_value or empty_table) do
						if default and default[key] == val then
							saved_value[key] = nil
						end
					end
					if not next(saved_value) then
						saved_value = nil
					end
				else
					saved_value = prop_eval(value, self, prop)
				end
			end
			storage_table[prop.id] = saved_value
		end
	end
end

-- Returns a table with the default values of all option properties with the given storage
-- This will capture option props defined only in one game and those who don't have defaults in DefaultEngineOptions
function GetTableWithStorageDefaults(storage)
	local obj = OptionsObject:new()
	local defaults_table = {}
	for _, prop in ipairs(obj:GetProperties()) do
		local prop_storage = prop.storage or "account"
		
		if not storage or prop_storage == storage then
			defaults_table[prop.id] = prop_eval(prop.default, obj, prop)
		end
	end
	
	return defaults_table
end

function OptionsObject:SetProperty(id, value)
	local ret = PropertyObject.SetProperty(self, id, value)
	local preset = self.VideoPreset
	if OptionsData.VideoPresetsData[preset] and OptionsData.VideoPresetsData[preset][id] and
		PresetVideoOptions[id] and value ~= self:FindFirstSelectable(id, OptionsData.VideoPresetsData[preset][id]) then
		PropertyObject.SetProperty(self, "VideoPreset", "Custom")
		ObjModified(self)
	end
	return ret
end

function OptionsObject:SyncUpscaling()
	local not_selectable = function(item)
		if type(item.not_selectable) == "function" then
			return item.not_selectable(item, self)
		end
		return item.not_selectable
	end
	
	if self.ResolutionPercent == "100" and not IsTemporalAntialiasingOption(self.Antialiasing) then
		if self.Upscaling ~= "Off" then
			PropertyObject.SetProperty(self, "Upscaling", "Off")
		end
		return
	end

	local uscaling_option = table.find_value(OptionsData.Options.Upscaling, "value", self.Upscaling)
	if not_selectable(uscaling_option) then
		local upscaling_index = table.findfirst(OptionsData.Options.Upscaling, function(idx, item) return not not_selectable(item) end)
		uscaling_option = OptionsData.Options.Upscaling[upscaling_index]
		if self.Upscaling ~= uscaling_option.value then
			PropertyObject.SetProperty(self, "Upscaling", uscaling_option.value)
		end
	end
	
	local resolution_percent_option = table.find_value(OptionsData.Options.ResolutionPercent, "value", self.ResolutionPercent)
	if not resolution_percent_option then
		--handle case where self.ResolutionPercent is not in the list OptionsData.Options.ResolutionPercent
		--this way it will go in the logic below to find the closest available option
		resolution_percent_option = { hr = {ResolutionPercent = self.ResolutionPercent}, not_selectable = function() return true end }
	end
	if not_selectable(resolution_percent_option) then
		local original_percent = resolution_percent_option.hr.ResolutionPercent
		local closest_percent = max_int
		for _, current_option in ipairs(OptionsData.Options.ResolutionPercent) do
			if not not_selectable(current_option) then
				local current_percent = current_option.hr.ResolutionPercent
				if abs(current_percent - original_percent) < abs(closest_percent - original_percent) then
					closest_percent = current_percent
					resolution_percent_option = current_option
				end
			end
		end
	end
	
	if self.ResolutionPercent ~= resolution_percent_option.value then
		PropertyObject.SetProperty(self, "ResolutionPercent", resolution_percent_option.value)
	end
end

function OptionsObject:SetAntialiasing(value)
	self.Antialiasing = value
	self:SyncUpscaling()
end

function OptionsObject:SetResolutionPercent(value)
	self.ResolutionPercent = value
	self:SyncUpscaling()
end

function OptionsObject:SetUpscaling(value)
	self.Upscaling = value
	self:SyncUpscaling()
end

function IsSoundOptionEnabled(option)
	return config.SoundOptionGroups[option]
end

function OptionsObject:SetMasterVolume(x)
	self.MasterVolume = x
	for option in pairs(config.SoundOptionGroups) do
		self:UpdateOptionVolume(option)
	end
end

function OptionsObject:UpdateOptionVolume(option, volume)
	volume = volume or self[option]
	self[option] = volume
	SetOptionVolume(option, volume * self.MasterVolume / 1000)
end

function OnMsg.ClassesPreprocess()
	for option in sorted_pairs(config.SoundOptionGroups) do
		OptionsObject["Set" .. option] = function(self, x)
			self:UpdateOptionVolume(option, x)
		end
	end
end

function OptionsObject:SetMuteWhenMinimized(x)
	self.MuteWhenMinimized = x
	config.DontMuteWhenInactive = not x
end

function OptionsObject:SetMuteWhenMinimized(x)
	self.MuteWhenMinimized = x
	config.DontMuteWhenInactive = not x
end

function OptionsObject:SetBrightness(x)
	self.Brightness = x
	ApplyBrightness(x)
end

function OptionsObject:SetDisplayAreaMargin(x)
	if self.DisplayAreaMargin == x then return end
	self.DisplayAreaMargin = x
	self:UpdateUIScale()
end

function OptionsObject:UpdateUIScale()
	if Platform.playstation or not const.UIScaleDAMDependant then return end
	
	local dam_value = self.DisplayAreaMargin or 0
	local ui_scale_value = self.UIScale or 100
	local mapped_value = MapRange(dam_value, const.MinUserUIScale, const.MaxUserUIScaleHighRes, const.MaxDisplayAreaMargin, const.MinDisplayAreaMargin)
	
	local prop_meta = self:GetPropertyMetadata("UIScale")
	local step = prop_meta and prop_meta.step or 1
	self.UIScale = Clamp(Min(ui_scale_value, round(mapped_value, step)), const.MinUserUIScale, const.MaxUserUIScaleHighRes)
end

function OptionsObject:SetUIScale(x)
	if self.UIScale == x then return end
	self.UIScale = x
	self:UpdateDisplayAreaMargin()
end

function OptionsObject:UpdateDisplayAreaMargin()
	if Platform.playstation or not const.UIScaleDAMDependant then return end
	
	local dam_value = self.DisplayAreaMargin or 0
	local ui_scale_value = self.UIScale or 100
	local mapped_value = MapRange(ui_scale_value, const.MinDisplayAreaMargin, const.MaxDisplayAreaMargin, const.MaxUserUIScaleHighRes, const.MinUserUIScale)
	
	local prop_meta = self:GetPropertyMetadata("DisplayAreaMargin")
	local step = prop_meta and prop_meta.step or 1
	self.DisplayAreaMargin = Clamp(Min(dam_value, round(mapped_value, step)), const.MinDisplayAreaMargin, const.MaxDisplayAreaMargin)
end

function OptionsCreateAndLoad()
	local storage_tables = {
		["local"] = EngineOptions,
		account = AccountStorage and AccountStorage.Options,
		session = g_SessionOptions,
		shortcuts = AccountStorage and AccountStorage.Shortcuts,
	}
	EngineOptions.DisplayIndex = GetMainWindowDisplayIndex()
	Options.InitVideoModesCombo()
	local obj = OptionsObject:new()
	for _, prop in ipairs(obj:GetProperties()) do
		local storage = prop.storage or "account"
		local storage_table = storage_tables[storage]
		if storage_table then
			local default = prop_eval(prop.default, obj, prop)
			local value = storage_table[prop.id]
			local loaded_val

			if value ~= default then
				if type(value) == "table" then
					-- merge saved and default values
					loaded_val = table.copy(value)
					table.set_defaults(loaded_val, default)
				elseif value ~= nil then
					loaded_val = prop_eval(value, obj, prop)
				else
					loaded_val = default
				end
			end
			if loaded_val ~= nil then --false could be a valid value
				obj:SetProperty(prop.id, loaded_val)
			end
		end
	end
	Options.InitGraphicsAdapterCombo(obj.GraphicsApi)
	return obj
end

function OptionsObject:SetGraphicsApi(api)
	self.GraphicsApi = api
	local adapterData = EngineOptions.GraphicsAdapter or {}
	Options.InitGraphicsAdapterCombo(api)
	self:SetProperty("GraphicsAdapterIndex", GetRenderDeviceAdapterIndex(api, adapterData))
end

function OptionsObject:SetGraphicsAdapterIndex(adapterIndex)
	self.GraphicsAdapterIndex = adapterIndex
	EngineOptions.GraphicsAdapter = GetRenderDeviceAdapterData(self.GraphicsApi, adapterIndex)
end 

function OptionsObject:FindFirstSelectable(option, item_names)
	local is_selectable = function(option, item_name, options_obj)
		local item = table.find_value(OptionsData.Options[option], "value", item_name)
		local not_selectable = item.not_selectable 
		if type(not_selectable) == "function" then 
			not_selectable = not_selectable(item, options_obj) 
		end
		return not not_selectable
	end

	if type(item_names) == "function" then
		item_names = item_names()
	end
	if type(item_names) == "table" then
		for _, item_name in ipairs(item_names) do
			if is_selectable(option, item_name, self) then
				return item_name
			end
		end
	else
		if is_selectable(option, item_names, self) then
			return item_names
		end
	end
end

function OptionsObject:SetVideoPreset(preset)
	for k, v in pairs(OptionsData.VideoPresetsData[preset]) do
		local first_selectable = self:FindFirstSelectable(k, v)
		if first_selectable then
			self:SetProperty(k, first_selectable)
		else
			printf("Video preset %s's option %s is not a selectable value %s!", preset, k, tostring(v))
		end
	end
	self.VideoPreset = preset
end

function OptionsObject:WaitApplyOptions()
	self:SaveToTables()
	Options.ApplyEngineOptions(EngineOptions)
	WaitNextFrame(2)
	Msg("OptionsApply")
	return true
end

function ApplyVideoPreset(preset)
	local obj = OptionsCreateAndLoad()
	obj:SetVideoPreset(preset)
	ApplyOptionsObj(obj)
end

function ApplyOptionsObj(obj)
	obj:SaveToTables()
	Options.ApplyEngineOptions(EngineOptions)
	Msg("OptionsApply")
end

function OptionsObject:CopyCategoryTo(other, category)
	for _, prop in ipairs(self:GetProperties()) do
		if prop.category == category then
			local value = self:GetProperty(prop.id)
			value = type(value) == "table" and table.copy(value) or value
			other:SetProperty(prop.id, value)
		end
	end
end

function WaitChangeVideoMode()
	while GetVideoModeChangeStatus() == 1 do
		Sleep(50)
	end

	if GetVideoModeChangeStatus() ~= 0 then
		return false
	end
	
	-- wait a few frames for all systems to allocate resources for the new video mode
	for i = 1, 2 do
		WaitNextFrame()
	end
	
	return true
end

function OptionsObject:FindValidVideoMode(display)
	local modes = GetVideoModes(display, 1024, 720)
	table.sort(modes, function(a, b)
		if a.Height ~= b.Height then
			return a.Height > b.Height
		end
		return a.Width > b.Width
	end)
	local best = modes[1]
	self.Resolution = point(best.Width, best.Height)
end

function OptionsObject:IsValidVideoMode(display)
	local modes = GetVideoModes(display, 1024, 720)
	for _, mode in ipairs(modes) do
		if mode.Width == self.Resolution:x() and
			mode.Height == self.Resolution:y() then
				return true
		end
	end
	return false
end

function OptionsObject:ApplyVideoMode()
	local display = GetMainWindowDisplayIndex()
	ChangeVideoMode(self.Resolution:x(), self.Resolution:y(), self.FullscreenMode, self.Vsync, false)

	if not WaitChangeVideoMode() then return false end
	--recalc viewport
	SetupViews()
	EngineOptions.DisplayIndex = display
	local UIScale_meta = self:GetPropertyMetadata("UIScale")
	self:SaveToTables({UIScale_meta})
	terminal.desktop:OnSystemSize(UIL.GetScreenSize())
	
	local value = table.find_value(OptionsData.Options.MaxFps, "value", self.MaxFps)
	if value then
		for k,v in pairs(value.hr or empty_table) do
			hr[k] = v
		end
	end
	Msg("VideoModeApplied")

	if self.FullscreenMode > 0 then
		return "confirmation"
	end
	
	return true
end

function OptionsObject:ResetOptionsByCategory(category, sub_category, additional_skip_props)
	additional_skip_props = additional_skip_props or {}
	if category == "Keybindings" then
		if sub_category then
			for key, shortcut in pairs(AccountStorage.Shortcuts) do
				local actionCat = table.find_value(OptionsObj:GetProperties(),"id",key).action_category
				if actionCat == sub_category then
					AccountStorage.Shortcuts[key] = nil
				end
			end
		else
			AccountStorage.Shortcuts = {}
		end
		ReloadShortcuts()
		self:GetShortcuts()
	end
	local skip_props = {}
	if category == "Display" then
		skip_props = {
			FullscreenMode = true,
			Resolution = true,
		}
	end
	for _, prop in ipairs(self:GetProperties()) do
		local isFromSubCat = sub_category and prop.action_category == sub_category or not sub_category
		if prop.category == category and not skip_props[prop.id] and not additional_skip_props[prop.id] and not GameDisabledOptions[prop.id] and not prop_eval(prop.no_edit, self, prop) and isFromSubCat then
			local default = table.find_value(OptionsData.Options[prop.id], "default", true)
			local default_prop_value = self:GetDefaultPropertyValue(prop.id)
			default = (default and default.value) or (default_prop_value and prop_eval(default_prop_value, self, prop)) or false
			--copy from default value so that we don't try to write to it or remove it afterwards
			if type(default) == "table" then
				default = table.copy(default)
			end
			self:SetProperty(prop.id, default)
		end
	end
end

function OptionsObject:SetRadioStation(station)
	local old = rawget(self, "RadioStation")
	if not old or old ~= station then
		self.RadioStation = station
		StartRadioStation(station)
	end
end

function GetAccountStorageOptionValue(prop_id)
	local value = table.get(AccountStorage, "Options", prop_id)
	if value ~= nil then return value end
	return rawget(OptionsObject, prop_id)
end

function SyncCameraControllerSpeedOptions()
end

function SetAccountStorageOptionValue(prop_id, val)
	if AccountStorage and AccountStorage.Options and AccountStorage.Options[prop_id] then
		AccountStorage.Options[prop_id] = val
	end
end

function ApplyOptions(host, next_mode)
	CreateRealTimeThread(function(host)
		if host.window_state == "destroying" then return end
		local obj = ResolvePropObj(host.context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local category = host:GetCategoryId()
		if not obj:WaitApplyOptions() then
			WaitMessage(terminal.desktop, T(824112417429, "Warning"), T(862733805364, "Changes could not be applied and will be reverted."), T(325411474155, "OK"))
		else
			local object_detail_changed = obj.ObjectDetail ~= original_obj.ObjectDetail
			obj:CopyCategoryTo(original_obj, category)
			SaveEngineOptions()
			SaveAccountStorage(5000)
			ReloadShortcuts()
			ApplyLanguageOption()
			if category == obj:GetPropertyMetadata("UIScale").category then
				terminal.desktop:OnSystemSize(UIL.GetScreenSize()) -- force refresh, UIScale might be changed
			end
			if object_detail_changed then
				SetObjectDetail(obj.ObjectDetail)
			end
			Msg("GameOptionsChanged", category)
		end
		if not next_mode then
			SetBackDialogMode(host)
		else
			SetDialogMode(host, next_mode)
		end
	end, host)
end

function CancelOptions(host, next_mode)
	CreateRealTimeThread(function(host)
		if host.window_state == "destroying" then return end
		local obj = ResolvePropObj(host.context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local category = host:GetCategoryId()
		original_obj:WaitApplyOptions()
		original_obj:CopyCategoryTo(obj,category)
		if not next_mode then
			SetBackDialogMode(host)
		else
			SetDialogMode(host, next_mode)
		end
	end, host)
end

function ApplyDisplayOptions(host, next_mode)
	CreateRealTimeThread( function(host)
		if host.window_state == "destroying" then return end
		local obj = ResolvePropObj(host.context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local graphics_device_changed = obj.GraphicsApi ~= original_obj.GraphicsApi
		if not graphics_device_changed then
			local originalAdapter = GetRenderDeviceAdapterData(original_obj.GraphicsApi, original_obj.GraphicsAdapterIndex)
			local adapter = GetRenderDeviceAdapterData(obj.GraphicsApi, obj.GraphicsAdapterIndex)
			graphics_device_changed = 
				originalAdapter.vendorId ~= adapter.vendorId or
				originalAdapter.deviceId ~= adapter.deviceId or
				originalAdapter.localId ~= adapter.localId
		end
		local ok = obj:ApplyVideoMode()
		if ok == "confirmation" then
			ok = WaitQuestion(terminal.desktop, T(145768933497, "Video mode change"), T(751908098091, "The video mode has been changed. Keep changes?"), T(689884995409, "Yes"), T(782927325160, "No")) == "ok"
		end
		--options obj should always show the current resolution
		obj:SetProperty("Resolution", point(GetResolution()))
		if ok then
			obj:CopyCategoryTo(original_obj, "Display")
			original_obj:SaveToTables()
			SaveEngineOptions() -- save the original + the new display options to disk, in case user cancels options menu
		else
			-- user doesn't like it, restore
			original_obj:ApplyVideoMode()
			original_obj:CopyCategoryTo(obj, "Display")
		end
		if graphics_device_changed then
			WaitMessage(terminal.desktop, T(1000599, "Warning"), T(714163709235, "Changing the Graphics API or Graphics Adapter options will only take effect after the game is restarted."), T(325411474155, "OK"))
		end
		if not next_mode then
			SetBackDialogMode(host)
		else
			SetDialogMode(host, next_mode)
		end
	end, host)
end

function CancelDisplayOptions(host, next_mode)
	local obj = ResolvePropObj(host.context)
	local original_obj = ResolvePropObj(host.idOriginalOptions.context)
	original_obj:CopyCategoryTo(obj, "Display")
	obj:SetProperty("Resolution", point(GetResolution()))
	if not next_mode then
		SetBackDialogMode(host)
	else
		SetDialogMode(host, next_mode)
	end
end

function SetupOptionRollover(rollover, options_obj, option)
	local help_title = prop_eval(option.help_title, option, options_obj)
	local help_text = prop_eval(option.help_text, option, options_obj)
	if help_text then
		rollover:SetRolloverText(help_text)
		if not help_title then
			help_title = prop_eval(option.name, option, options_obj)
		end
	end
	if help_title then
		rollover:SetRolloverTitle(help_title)
	end
end

function DbgLoadOptions(video_preset, options_obj)
	assert(options_obj and options_obj.class)
	
	if video_preset and video_preset ~= "Custom" then
		options_obj:SetVideoPreset(video_preset)
	end
	
	CreateRealTimeThread(function()
		options_obj:ApplyVideoMode()
	end)
	
	ApplyOptionsObj(options_obj)
end

function GetOptionsString()
	local options_obj = OptionsCreateAndLoad()
	-- Serialize all prop values, even defaults, in case they've been changed since the bug was reported.
	-- However we can skip the shortcuts/keybindings.
	options_obj.IsDefaultPropertyValue = function(self, id, prop, value)
		return prop.storage == "shortcuts" and true or false
	end
	return string.format("DbgLoadOptions(\"%s\", %s)\n", options_obj.VideoPreset, ValueToLuaCode(options_obj))
end

function ToggleFullscreen()
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	OptionsObj.FullscreenMode = FullscreenMode() == 0 and 1 or 0
	OptionsObj:ApplyVideoMode()
	OptionsObj:SaveToTables()
	SaveEngineOptions()
end
