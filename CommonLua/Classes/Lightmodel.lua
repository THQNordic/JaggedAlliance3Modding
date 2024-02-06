function LocalToEarthTime(time)
	return time
end

function EarthToLocalTime(time)
	return time
end

g_ClassesToHideInCubemaps = { "EditorVisibleObject", "EditorEntityObject", "ShaderBall" }

function SetIceStrength() end


-------------------------------------- Lightmodel Features --------------------------------------
LightmodelFeatureToProperties = false


local function GetFeatureValuesHash(lm, feature)
	local prop_ids = LightmodelFeatureToProperties[feature]
	if not prop_ids then return 0 end

	local values = {}
	for _, prop in ipairs(prop_ids) do
		values[prop.id] = lm:GetProperty(prop.id)
	end
	return table.hash(values)
end

function CollectUniqueParts(feature)
	local hash_to_lmlist = {}
	-- fetch properties
	local preset_prop_id = "preset_" .. feature
	for _, lm in pairs(LightmodelPresets) do
		local part_id = lm:GetProperty(preset_prop_id)
		if not part_id or part_id == "" then
			local hash = GetFeatureValuesHash(lm, feature)
			local lm_list = hash_to_lmlist[hash] or {}
			table.insert(lm_list, lm.id)
			hash_to_lmlist[hash] = lm_list
		end
	end

	return hash_to_lmlist
end

function LightmodelEquivalenceByValue(lm, feature)
	local hash_to_list = CollectUniqueParts(feature)
	local current_hash = GetFeatureValuesHash(lm, feature)
	return hash_to_list[current_hash] or {}
end

function LightmodelFeatures()
	local p = {}

	for id in pairs(LightmodelFeatureToProperties) do
		if type(id) == "string" then
			table.insert(p, id)
		end
	end
	return p
end

DefineClass.LightmodelFeaturePreset = {
	__parents = {"Preset"},
	PresetClass = "LightmodelFeaturePreset",
	properties = {
		{id = "Group", category = "Preset", editor = "choice", items = LightmodelFeatures, default = false, },
		{category = "Diagnostics", id = "LightmodelRefs", read_only = true, dont_save = true, editor="preset_id_list", preset_class = "LightmodelPreset", default = false, },
		{category = "Diagnostics", id = "EquivalentLMs", read_only = true, dont_save = true, editor="number", default = 0, buttons = {
			{ name = "List", func = "ListEquivalentLMs"}
		} },
	},
	EditorMenubarName = "Lightmodel features",
	EditorMenubar = "Editors.Art",
}

function LightmodelFeaturePreset:GetFeature()
	return self.group
end 

function LightmodelFeaturePreset:GetProperties()
	local group = self.group
	if not group then
		return self.properties
	end
	local prop_ids = LightmodelFeatureToProperties[group]
	if not prop_ids then
		return self.properties
	end
	local properties = table.copy(self.properties)
	table.iappend(properties, prop_ids)
	return properties
end


function LightmodelFeaturePreset:GetLightmodelRefs()
	local ids = {}
	local prop_id = "preset_" .. self:GetFeature()
	for lm_id, lm in pairs(LightmodelPresets) do
		local referenced = lm:GetProperty(prop_id)
		if referenced == self.id then
			table.insert(ids, lm_id)
		end
	end
	return ids
end

function LightmodelFeaturePreset:GetEquivalentLMs()
	local list = LightmodelEquivalenceByValue(self, self:GetFeature())
	return #list
end

function LightmodelFeaturePreset:ListEquivalentLMs(root, prop_id, ged, param)
	local list = LightmodelEquivalenceByValue(self, self:GetFeature())
	ged:ShowMessage("EquivalentLMs", table.concat(list, "\n"))
end

function LightmodelFeaturePreset:IsLMProperty(prop_id)
	local prop = self:GetPropertyMetadata(prop_id)
	if prop and prop.feature and prop.feature == self:GetFeature() then
		return prop
	end
	return false
end

function LightmodelFeaturePreset:OnEditorSetProperty(prop_id, old_value, ged, multi)
	if not self:IsLMProperty(prop_id) then
		return false
	end
	local value = self:GetProperty(prop_id)
	for _, lm_id in ipairs(self:GetLightmodelRefs()) do
		local lm = LightmodelPresets[lm_id]
		lm:SetProperty(prop_id, value)
		ObjModified(lm)
		if LightmodelOverride and LightmodelOverride == lm then
			lm:OnEditorSetProperty(prop_id, old_value, ged)
		end
	end
end

DefineClass.LightmodelPart = {
	__parents = {"PropertyObject"},
	properties = {
	},
	PresetClass = "LightmodelPart",
}

-------------------------------------- END OF Lightmodel Features --------------------------------------
-- generate migration properties,

RainTypeItems = { 
	{ value = "RainLight",  text = "Light" },
	{ value = "RainMedium", text = "Medium" },
	{ value = "RainHeavy",  text = "Heavy" },
}

DefineClass.LightmodelRain = {
	__parents = {"LightmodelPart"},
	lightmodel_feature = "rain",
	lightmodel_category = "Rain",
	group = "LightmodelRain",
	properties = {
		{ name = "Rain", id = "rain_enable", editor = "bool", default = false, help = "Switches on and off rain." },
		{ name = "Rain Type", id = "rain_type", editor = "combo", default = "RainMedium", items = RainTypeItems, no_edit = PropChecker("rain_enable", false) },
		{ name = "Rain Color", id = "rain_color", editor = "color", default = RGBA(255, 255, 255, 255), help = "Models the light properties of the comprising liquid." },
		{ name = "Drops Count", id = "rain_drops_count", editor = "number", slider = true, min = 1, max = const.RainMaxDropsCount, default = 1, help = "Mean rain drops count per cubic meter." },
		{ name = "Drop Radius", id = "rain_drop_radius", editor = "number", slider = true, min = const.RainMinDropRadius, max = const.RainMaxDropRadius, default = const.RainMinDropRadius, help = "Mean radius used to model properties such as terminal velocity, volume, sprey in microns." },
		{ name = "Ground Wetness", id = "rain_ground_wetness", editor = "number", slider = true, min = 0, max = 100, default = 50, scale = 100, help = "How much material properties will be changed by rain shaders." },

		{ name = "Lightning",                 id = "lightning_enable",          editor = "bool",   default = false, blend = const.LightningBlendThreshold },
		{ name = "Lightning Delay Start",     id = "lightning_delay_start",     editor = "number", default = 15000, scale = "sec", slider = true },
		{ name = "Lightning Interval Min",    id = "lightning_interval_min",    editor = "number", default = 3000, scale = "sec", slider = true },
		{ name = "Lightning Interval Max",    id = "lightning_interval_max",    editor = "number", default = 120000, scale = "sec", slider = true },
		{ name = "Lightning Chance",          id = "lightning_strike_chance",   editor = "number", default = 40, scale = "%", min = 0, max = 100, slider = true, help = "out of 100, rest are distant thunder." },
		{ name = "Lightning Chance Vertical", id = "lightning_vertical_chance", editor = "number", default = 60, scale = "%", min = 0, max = 100, slider = true, help = "If the lightning strike is vertical, otherwise it's horizontal." },
	},
}

function OnMsg.LightmodelSetSceneParams(view, lm_buf, time, start_offset)
	SetSceneParam(view, "RainEnable", lm_buf.rain_enable and 1 or 0, 0, start_offset)
	SetSceneParamColor(view, "RainColor", lm_buf.rain_color, time, start_offset)
	SetSceneParam(view, "RainDropsCount", lm_buf.rain_drops_count, time, start_offset)
	SetSceneParam(view, "RainDropRadius", lm_buf.rain_drop_radius, time, start_offset)
	SetSceneParam(view, "RainGroundWetness", lm_buf.rain_ground_wetness, time, start_offset)
end

local default_raw_path = insideHG() and ConvertToBenderProjectPath("/DaVinci Resolve/RAW Screenshots/") or ConvertToOSPath("AppData/RAW Screenshots")

DefineClass.LightmodelColorGrading = {
	__parents = {"LightmodelPart"},
	lightmodel_feature = "color_grading",
	lightmodel_category = "Color Grading",
	group = "LightmodelColorGrading",
	properties = {
		{ name = "Gamma", id = "gamma", editor = "color", default = RGB(128, 128, 128), buttons = {{name = "Gray", func = "Gray"}}, help = "Performs nonlinear gamma correction." },
		{ name = "Desaturation", id = "desaturation", editor = "number", default = 0, min = -100, max = 100, scale = 100, slider = true, help = "Performs LDR color desaturation as part of tone mapping." },
		{ name = "Base Color Desat", id = "base_color_desat", editor = "number", default = 0, min = -1000, max = 1000, scale = 1000, slider = true, help = "Performs color desaturation on the diffuse texture" },
		{ name = "LUT", id = "grading_lut", editor = "preset_id", default = "Default", preset_class = "GradingLUTSource", help = string.format("Grading LUT in %s %s.", GetColorSpaceName(hr.ColorGradingLUTColorSpace), GetColorGammaName(hr.ColorGradingLUTColorGamma)) },
		{ name = "RAW Screenshot Path", id = "raw_screenshot_path", dont_save = true, editor = "browse", default = default_raw_path, filter = "OpenEXR (*.exr)|*.exr", os_path = true, allow_missing = true, folder = { { default_raw_path, os_path = true } }, buttons = {{name = "Screenshot", func = "CaptureRAWScreenshot"}}},
		{ name = "Post Grading LUT Path", id = "post_grading_lut_path", editor = "browse", default = "", filter = "LUT (*.cube)|*.cube", folder = { "svnAssets/Source/Editor/DeVinci Resolve/Viewing LUTs/" }, allow_missing = true},
		{ name = "Post Grading LUT Size", id = "post_grading_lut_size", editor = "choice", default = 65, items = { 16, 17, 32, 33, 64, 65 }, buttons = {{name = "Capture", func = "CapturePostGradingLUT"}} },
	},
}

function LightmodelColorGrading:CaptureRAWScreenshot(root, prop_id, ged)
	hr.PostProcRAWOutputPath = self.raw_screenshot_path
end

function LightmodelColorGrading:CapturePostGradingLUT(root, prop_id, ged)
	if self.post_grading_lut_path == "" then
		return
	end
	ExportToneMappingLUT(self.post_grading_lut_size, self.post_grading_lut_path)
end

function LightmodelColorGrading:Setpost_grading_lut_path(value)
	self.post_grading_lut_path = AppendDefaultExtension(value, ".cube")
end

function LightmodelColorGrading:Setraw_screenshot_path(value)
	self.raw_screenshot_path = AppendDefaultExtension(value, ".exr")
end

function OnMsg.LightmodelSetSceneParams(view, lm_buf, time, start_offset)
	SetSceneParamColor(view, "Gamma", lm_buf.gamma, time, start_offset, not "gamma-encoded")
	SetSceneParam(view, "Desaturation", lm_buf.desaturation, time, start_offset)
	SetSceneParam(view, "BaseColorDesat", lm_buf.base_color_desat, time, start_offset)
	
	local grading_lut_preset_id = lm_buf.grading_lut
	if grading_lut_preset_id == "" or not GradingLUTs[lm_buf.grading_lut] then
		grading_lut_preset_id = "Default"
	end
	
	local grading_lut_resource_id = ResourceManager.GetResourceID(GradingLUTs[grading_lut_preset_id]:GetResourcePath())
	SetGradingLUT(view, grading_lut_resource_id, time, start_offset)
end

DefineClass.LightmodelOpticalAnomalies = {
	__parents = {"LightmodelPart"},
	lightmodel_feature = "optical_anomalies",
	lightmodel_category = "Optical Anomalies",
	group = "LightmodelOpticalAnomalies",
	properties = {
		{ category = "Vignette", name = "Tint Color", id = "vignette_tint_color", editor = "color", default = RGBA(0,0,0,0), help = "Vignette tint color." },
		{ category = "Vignette", name = "Tint Start", id = "vignette_tint_start", editor = "number", float = true, slider = true, step = 0.001, min = 0.0, max = 1.0, default = 0.7, help = "Start radius of the gradient towards pure color." },
		{ category = "Vignette", name = "Tint Feather", id = "vignette_tint_feather", editor = "number", slider = true, float = true, step = 0.001, min = 0.0, max = 1.0, default = 1.0, help = "How large the gradient towards pure color is." },
		{ category = "Vignette", name = "Darken Opacity", id = "vignette_darken_opacity", editor = "number", float = true, slider = true, step = 0.001, min = 0, max = 1.0, default = 0.0, help = "The opacity of the vignette layer." },
		{ category = "Vignette", name = "Darken Start", id = "vignette_darken_start", editor = "number", float = true, slider = true, step = 0.001, min = 0.0, max = 1.0, default = 0.7, help = "Start radius of the gradient towards black." },
		{ category = "Vignette", name = "Darken Feather", id = "vignette_darken_feather", editor = "number", float = true, slider = true, step = 0.001, min = 0.0, max = 1.0, default = 1.0, help = "How large the gradient towards black is." },
		{ category = "Vignette", name = "Circularity", id = "vignette_circularity", editor = "number", float = true, slider = true, step = 0.01, min = 0.0, max = 1.0, default = 0.0, help = "Control gradient roundness." },

		{ category = "Chromatic Aberration", name = "Intensity", id = "chromatic_aberration_intensity", editor = "number", float = true, slider = true, step = 0.001, min = 0.0, max = 10.0, default = 0.0 },
		{ category = "Chromatic Aberration", name = "Start", id = "chromatic_aberration_start", editor = "number", float = true, slider = true, step = 0.001, min = 0.0, max = 1.0, default = 0.0 },
		{ category = "Chromatic Aberration", name = "Feather", id = "chromatic_aberration_feather", editor = "number", float = true, slider = true, step = 0.001, min = 0.0, max = 1.0, default = 1.0 },
		{ category = "Chromatic Aberration", name = "Circularity", id = "chromatic_aberration_circularity", editor = "number", float = true, slider = true, step = 0.01, min = 0.0, max = 1.0, default = 0.0 },
	},
}

function OnMsg.LightmodelSetSceneParams(view, lm_buf, time, start_offset)
	local vignette_tint_max = lm_buf:GetPropertyMetadata("vignette_tint_start").max
	local vignette_tint_end =
		lm_buf.vignette_tint_start + (vignette_tint_max - lm_buf.vignette_tint_start) * lm_buf.vignette_tint_feather

	SetSceneParamColor(view, "VignetteTintColor", lm_buf.vignette_tint_color, time, start_offset)
	SetSceneParamFloat(view, "VignetteTintStart", lm_buf.vignette_tint_start, time, start_offset)
	SetSceneParamFloat(view, "VignetteTintEnd", vignette_tint_end, time, start_offset)
	SetSceneParamFloat(view, "VignetteCircularity", lm_buf.vignette_circularity, time, start_offset)
	
	local vignette_darken_max = lm_buf:GetPropertyMetadata("vignette_darken_start").max
	local vignette_darken_end =
		lm_buf.vignette_darken_start + (vignette_darken_max - lm_buf.vignette_darken_start) * lm_buf.vignette_darken_feather
	
	SetSceneParamFloat(view, "VignetteDarkenOpacity", lm_buf.vignette_darken_opacity, time, start_offset)
	SetSceneParamFloat(view, "VignetteDarkenStart", lm_buf.vignette_darken_start, time, start_offset)
	SetSceneParamFloat(view, "VignetteDarkenEnd", vignette_darken_end, time, start_offset)

	local chromatic_aberration_max = lm_buf:GetPropertyMetadata("chromatic_aberration_start").max
	local chromatic_aberration_end =
		lm_buf.chromatic_aberration_start + (chromatic_aberration_max - lm_buf.chromatic_aberration_start) * lm_buf.chromatic_aberration_feather
	
	SetSceneParamFloat(view, "ChromaticAberrationIntensity", lm_buf.chromatic_aberration_intensity, time, start_offset)
	SetSceneParamFloat(view, "ChromaticAberrationStart", lm_buf.chromatic_aberration_start, time, start_offset)
	SetSceneParamFloat(view, "ChromaticAberrationEnd", chromatic_aberration_end, time, start_offset)
	SetSceneParamFloat(view, "ChromaticAberrationCircularity", lm_buf.chromatic_aberration_circularity, time, start_offset)
end

DefineClass.LightmodelTranslucency = {
	__parents = {"LightmodelPart"},
	lightmodel_feature = "translucency",
	lightmodel_category = "Translucency",
	group = "LightmodelTranslucency",
	properties = {
		{ name = "Scale", id = "translucency_scale", editor = "number", float = true, slider = true, step = 0.001, default = 0.3, min = 0.0, max = 1.0, help = "Translucency overall scale" },
		{ name = "Distort Sun Direction", id = "translucency_distort_sun_dir", editor = "number", float = true, slider = true, default = 0.12, min = 0.0, max = 2.0, help = "How much to distort the sun direction toward the material normal" },
		{ name = "Sun Falloff", id = "translucency_sun_falloff", editor = "number", float = true, slider = true, step = 0.001, default = 30.0, min = 0.0, max = 50.0, help = "Power that controls how fast the sun contribution falls off when with the difference of direction between the view and the sun" },
		{ name = "Sun Scale", id = "translucency_sun_scale", editor = "number", float = true, slider = true, step = 0.001, default = 0.2, min = 0.0, max = 1.0, help = "Sunlight contribution scale" },
		{ name = "Ambient Scale", id = "translucency_ambient_scale", editor = "number", float = true, slider = true, step = 0.001, default = 0.02, min = 0.0, max = 1.0, help = "Ambient contribution scale" },
		{ name = "Base Luminance", id = "translucency_base_luminance", editor = "number", float = true, slider = true, step = 0.001, default = 1.335, min = 0.0, max = 3.0, help = "Assumed base light luminance" },
		{ name = "Base Color Temperature", id = "translucency_base_k", editor = "number", float = true, slider = true, step = 1.0, default = 3600.0, min = 1000.0, max = 6500.0, help = "Assumed sunlight base temperature in degrees K" },
		{ name = "Reduce Color Temperature", id = "translucency_reduce_k", editor = "number", float = true, slider = true, step = 1.0, default = 1000.0, min = 0.0, max = 5000.0, help = "Color reduction temperature in degrees K" },
		{ name = "Desaturation", id = "translucency_desaturation", editor = "number", float = true, slider = true, step = 0.001, default = 0.3, min = 0.0, max = 1.0, help = "Amount to desaturate the color of translucent light" },		
	},
}

function OnMsg.LightmodelSetSceneParams(view, lm_buf, time, start_offset)
	SetSceneParamFloat(view, "TranslucencyScale", lm_buf.translucency_scale, time, start_offset)
	SetSceneParamFloat(view, "TranslucencySunDirDistort", lm_buf.translucency_distort_sun_dir, time, start_offset)
	SetSceneParamFloat(view, "TranslucencySunFalloff", lm_buf.translucency_sun_falloff, time, start_offset)
	SetSceneParamFloat(view, "TranslucencySunScale", lm_buf.translucency_sun_scale, time, start_offset)
	SetSceneParamFloat(view, "TranslucencyAmbientScale", lm_buf.translucency_ambient_scale, time, start_offset)
	SetSceneParamFloat(view, "TranslucencyBaseLuminance", lm_buf.translucency_base_luminance, time, start_offset)
	SetSceneParamFloat(view, "TranslucencyBaseK", lm_buf.translucency_base_k, time, start_offset)
	SetSceneParamFloat(view, "TranslucencyReduceK", lm_buf.translucency_reduce_k, time, start_offset)
	SetSceneParamFloat(view, "TranslucencyDesaturate", lm_buf.translucency_desaturation, time, start_offset)
end

DefineClass.LightmodelClouds = {
	__parents = {"LightmodelPart"},
	lightmodel_feature = "clouds",
	lightmodel_category = "Clouds",
	group = "LightmodelClouds",
	properties = {
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds shadow strength", id = "clouds_strength", default = 0, editor = "number", slider = true, min = 0, max = 1000, scale = 1000, help = "Maximum clouds darkness. Clouds source texture path is CommonAssets/System/clouds.dds." },
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds shadow coverage", id = "clouds_coverage", default = 500, editor = "number", slider = true, min = 0, max = 1000, scale = 1000, help = "How much of the surface is covered with clouds." },
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds shadow smoothness", id = "clouds_smoothness", default = 300, editor = "number", slider = true, min = 0, max = 1000, scale = 1000, help = "How sharp are the edges of the clouds." },
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds shadow scrub", id = "clouds_phase", default = 0, editor = "number", slider = true, min = 0, max = 1000, scale = 1000, help = "Scrub back and forth to see clouds move.", dont_save = true },
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds shadow scale", id = "clouds_scale", default = 1000, editor = "number", slider = true, min = 300, max = 10000, scale = 1000, help = "When interpolating lightmodels the clouds scale should be the same, otherwise the clouds will appear to move rapidly." },
		{ category = "Cloud shadows", feature = "clouds", name = "Oscillation period", id = "clouds_osci_period", default = 5000, editor = "number", slider = true, min = 2000, max = 3600 * 1000, scale = 1000, },
		{ category = "Cloud shadows", feature = "clouds", name = "Oscillation amplitude", id = "clouds_osci_amplitude", default = 0, editor = "number", slider = true, min = 0, max = 2000, scale = 1000, },
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds direction", id = "clouds_dir", default = 0, editor = "number", scale = "deg", slider = true, min = 0, max = 360*60, help = "The direction of cloud movement in degrees." },
		{ category = "Cloud shadows", feature = "clouds", name = "Wind strength", id = "clouds_wind_strength", default = 0, editor = "number", scale = 1000, slider = true, min = 0, max = 1000, help = "Should clouds be affected by wind?" },
		{ category = "Cloud shadows", feature = "clouds", name = "Clouds speed (m/s)", id = "clouds_speed", default = 3000, editor = "number", scale = 1000, slider = true, min = 0, max = 50*guim, help = "Clouds movement in meters per second." },
	}
}

function OnMsg.LightmodelSetSceneParams(view, lm_buf, time, start_offset)
	if not config.LightModelUnusedFeatures["clouds"] then
		SetSceneParam(view, "CloudsStrength", lm_buf.clouds_strength, time, start_offset)
		SetSceneParam(view, "CloudsCoverage", lm_buf.clouds_coverage, time, start_offset)
		SetSceneParam(view, "CloudsSmoothness", lm_buf.clouds_smoothness, time, start_offset)
		SetSceneParam(view, "CloudsSpeed", lm_buf.clouds_speed, time, start_offset)
		SetSceneParam(view, "CloudsPhase", lm_buf.clouds_phase, time, start_offset)
		SetSceneParam(view, "CloudsDirectionSP", lm_buf.clouds_dir, time, start_offset)
		SetSceneParam(view, "CloudsWindStrength", lm_buf.clouds_wind_strength, time, start_offset)
		SetSceneParam(view, "CloudsScale", lm_buf.clouds_scale, time, start_offset)
		SetSceneParam(view, "CloudsOsciPeriod", lm_buf.clouds_osci_period, time, start_offset)
		SetSceneParam(view, "CloudsOsciAmplitude", lm_buf.clouds_osci_amplitude, time, start_offset)
	end
end


AutoExposureInstructions = 
[[To adjust exposure:
- turn off via button to the right
- view a representative mid-brightness scene
- reset Exposure to default value
- adjust brightness using sun intensity, envmaps exposure, and if all else fails, Exposure
- switch to split mode using button to the right
- adjust Auto Exposure until the two parts of the screen match in brightness
- verify by moving the camera to a dark and to a bright spot]]

CubemapInstructions = [[Usually the sky is fetched from the cubemap, but when capturing the cubemap the sky is unavailable and approximated by a slower method.
 - Please use the "Cubemap capture preview" toggle to see the result of the slower method in real time.
 - Make sure to use this for "Bake" lightmodels.
]]

local sky_custom_sun_ro = function(self) return not self.sky_custom_sun or self.use_time_of_day end 
local shadow_range_ro = function(self) return not self.shadow end
local custom_sun_ro = function(self) return self.use_time_of_day end 
local tod_ro = function(self) return not self.use_time_of_day end 
DefineClass.Lightmodel = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Sun", feature = "phys_sky", name = "Sun diffuse color", id = "sun_diffuse_color", editor = "color", default = RGB(255, 255, 255), help = "The color of sunlight.\nAffects the diffuse contribution of the Sun." },
		{ category = "Sun", feature = "phys_sky", name = "Sun diffuse intensity", id = "sun_intensity", editor = "number", slider=true, min = 0, max = 2500, default = 100, help = "The intensity of the sun diffuse contribution." },
		{ category = "Sun", feature = "phys_sky", name = "Sun specular intensity", id = "sun_angular_radius", editor = "number", slider=true, min = 0, max = 2500, default = 100, help = "The intensity of the sun specular contribution." },		
		{ category = "Sun", feature = "shadow", name = "Shadow", id = "shadow", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = 1000, help = "Shadow strength." },
		{ category = "Sun", feature = "shadow", name = "Shadow range", id = "shadow_range", editor = "number", slider = true, min = 0, max = 10000 * guim, scale = "m", default = 500 * guim, help = "Limits the distance at which the shadows are visible.", read_only = shadow_range_ro },
	
		{ category = "Sun (dev tools)", feature = "sun_path", id = "_help", editor = "help", help = "These are not saved; use to tweak sun parameters for testing." },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Sunrise time", id = "sunrise_time", editor = "number", default = 8*60, help = "", dont_save = true },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Sunset time", id = "sunset_time", editor = "number", default = 20*60, help = "", dont_save = true },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Earth time info", id = "sun_earthtime_info", editor = "text", default = "", help = "", dont_save = true, read_only = true},
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Sunrise azi",  id = "sunrise_azi", editor = "number", default = 54*60, slider = true, min = 0*60, max = 360*60, scale = "deg", help = "Azimuth is from 0Deg North, 90Deg East ... 360Deg. Sunrise azi + Sunset azi generally should make 360Deg.", dont_save = true },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Sunset azi",  id = "sunset_azi", editor = "number", default = 306*60, help = "Azimuth is from 0Deg North, 90Deg East ... 360Deg. Sunrise azi + Sunset azi generally should make 360Deg.", slider = true, min = 0*60, max = 360*60, scale = "deg", dont_save = true },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Sun max elevation",  id = "sun_max_elevation", editor = "number", default = 70*60, help = "This is the maximum angle from the horizon to the center of the sun disk (reached at noon).", slider = true, min = 0, max = 89*60, scale = "deg", dont_save = true },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "Sun shadow min",  id = "sun_shadow_min", editor = "number", default = 15*60, help = "This is the min elevation that the sun will cast shadows from to avoid super long shadows.", slider = true, min = 0, max = 89*60, scale = "deg", dont_save = true },
		{ category = "Sun (dev tools)", feature = "sun_path", name = "North rotation",  id = "sun_nr", editor = "number", default = 0, help = "Add this angle to all azimuths to effectively rotate where North is on the map.", slider = true, min = 0*60, max = 360*60, scale = "deg", dont_save = true },
		
		{ category = "Sun Pos", feature = "phys_sky", name = "Use time of day", id = "use_time_of_day", editor = "bool", default = true, help = "Sun position is determined by the current time of day setup." },
		{ category = "Sun Pos", feature = "phys_sky", name = "Start Time (h)", id = "time", editor = "number", default = 12*60, scale = 60, min = 0, max = 24*60, slider = true, help = "This is the time when the blending to this model will start. View shows it ignoring blending.", read_only = tod_ro, buttons = {{name = "View", func = "PreviewStart"}}},
		{ category = "Sun Pos", feature = "phys_sky", name = "End Time", id = "time_next", editor = "text", default = "", help = "This is the time when the blending to next model will start. View shows it ignoring blending.", read_only = true, dont_save = true, buttons = {{name = "View", func = "PreviewEnd"}}},
		{ category = "Sun Pos", feature = "phys_sky", name = "Blend Duration (m)", id = "blend_time", editor = "number", default = 60, help = "Controls the duration of the blend. View buttons take into account the blending, i.e. 'Start' shows accurately the end of the previous model.", read_only = tod_ro, buttons = {{name = "Start", func = "PreviewBlendStart"}, {name = "End", func = "PreviewBlendEnd"}, {name = "Preview", func = "PreviewBlend"}}},
		{ category = "Sun Pos", feature = "phys_sky", name = "Sun alt", id = "sun_alt", min = -1800, max = 1800, editor = "number", slider = true, scale = 10, default = 250, help = "At what angle (in 1/10 degrees) relative to the horizon (height) is the Sun.", read_only = custom_sun_ro },
		{ category = "Sun Pos", feature = "phys_sky", name = "Sun shadow alt", id = "sun_shadow_height", editor = "number", default = 0, slider = true, scale = 10, min = 0, max = 1800, help = "0 = Use sun alt for shadow direction. > 0 forces shadows as if the sun is at this altitutude", read_only = custom_sun_ro},
		{ category = "Sun Pos", feature = "phys_sky", name = "Sun azi", id = "sun_azi", min = 0, max = 360, editor = "number" , slider = true, default = 180, help = "The position of the Sun relative to the world, specified as an angle in degrees.", read_only = custom_sun_ro },
		{ category = "Sun Pos", feature = "phys_sky", name = "Sky custom sun", id = "sky_custom_sun", editor = "bool" , default = false, help = "If checked allows overriding the disk sun position with a separate custom one for the sun in the sky.", read_only = custom_sun_ro },
		{ category = "Sun Pos", feature = "phys_sky", name = "Sky custom sun azi", id = "sky_custom_sun_azi", min = 0, max = 360, editor = "number" , slider = true, default = 180, help = "The azimuth of Sun in the Sky, specified as an angle in degrees." , read_only = sky_custom_sun_ro },
		{ category = "Sun Pos", feature = "phys_sky", name = "Sky custom sun alt", id = "sky_custom_sun_alt", min = -1800, max = 1800, editor = "number", slider = true, default = 0, help = "The altitude of Sun in the Sky, specified as an angle in degrees.", read_only = sky_custom_sun_ro},
		
		{ category = "Sky", feature = "phys_sky", id = "__", editor = "help", name = "Cubemap help", help = CubemapInstructions, },
		{ category = "Sky", feature = "phys_sky", name = "Mie coefs",      id = "mie_coefs", editor = "color", default = RGB(210, 210, 210), help = "Mie coefficients control sun color. It is also affected by the Rayleight param." },
		{ category = "Sky", feature = "phys_sky", name = "Rayleigh coefs", id = "ray_coefs", editor = "color", default = RGB(55, 130, 221), help = "Rayleigh coefficient control sky color. It is also affected by the Mie param." },
		{ category = "Sky", feature = "phys_sky", name = "Mie scale height",      id = "mie_sh", editor = "number", slider = true, min=100, max = 10000,  default = 1200, help = "Mie scale height controls the height at which the atmosphere is half dense for this scattering." },
		{ category = "Sky", feature = "phys_sky", name = "Rayleigh scale height", id = "ray_sh", editor = "number", slider = true, min=1000, max = 16000, default = 7994, help = "Rayleigh scale height controls the height at which the atmosphere is half dense for this scattering." },
		{ category = "Sky", feature = "phys_sky", name = "Mie Shape", id = "mie_mc", editor = "number", slider = true, min=750, max = 999, default = 860, help = "The G param (mean cosine) controls the asymmetry (shape) of the mie phase function." },
		{ category = "Sky", feature = "phys_sky", name = "Exposure", id = "sky_exp", min = -1000, max = 1000, default = 0, editor = "number" , slider = true, help = "The exposure control in 1/100 EV. Intensity change is pow(2, E / 100)" },
		{ category = "Sky", feature = "phys_sky", name = "Sky IS", id = "sky_is", editor=false, dont_save = true, default = false, help = "Toggles realtime update of sky contribution with importance sampling (for lightmodel tweak only)" },
		{ category = "Sky", feature = "phys_sky", name = "Cubemap capture preview", editor = "bool", dont_save = true, id = "cubemap_capture_preview", default = false, help = "Mostly enables Sky importance sampling, among other things" },
				
		{ category = "Cubemap", feature = "phys_sky", name = "Exterior Env map", id = "exterior_envmap", default = "PainterStudioDaylight", editor = "dropdownlist", help = "The current exterior environment map texture.", items = function() return GetEnvMapsList("Exterior") end },
		{ category = "Cubemap", feature = "phys_sky", name = "Exterior Env Exposure", id = "ext_env_exposure", min = -1000, max = 1000, default = 0, editor = "number" , slider = true, help = "The exterior env exposure control in 1/100 EV. Intensity change is pow(2, E / 100)" },
		{ category = "Cubemap", feature = "phys_sky", name = "Exterior Env Map Image", id = "ExteriorEnvmapImage", editor = "image", default = "", dont_save = true, img_size = 128, img_box = 1 },
		{ category = "Cubemap", feature = "phys_sky", name = "Interior Env map", id = "interior_envmap", default = "PainterStudioDaylight", editor = "dropdownlist", help = "The current interior environment map texture.", items = function() return GetEnvMapsList("Interior") end },
		{ category = "Cubemap", feature = "phys_sky", name = "Interior Env Exposure", id = "int_env_exposure", min = -1000, max = 1000, default = 0, editor = "number" , slider = true, help = "The interior env exposure control in 1/100 EV. Intensity change is pow(2, E / 100)" },
		{ category = "Cubemap", feature = "phys_sky", name = "Interior Env Map Image", id = "InteriorEnvmapImage", editor = "image", default = "", dont_save = true, img_size = 128, img_box = 1 },

		{ category = "Night Sky", feature = "phys_sky", name = "Stars Intensity", id = "stars_intensity",     min = 0, max = 1000, scale = 1000, editor = "number", slider = true, default = 0, help = "Controls the brightness of the stars." },
		{ category = "Night Sky", feature = "phys_sky", name = "Stars Blue tint", id = "stars_blue_tint",     min = 0, max = 100, scale = 100,  editor = "number", slider = true, default = 30, help = "Faint stars are tinted blue to simulate human perception in low-light conditions." },
		{ category = "Night Sky", feature = "phys_sky", name = "MilkyWay Intensity", id = "mw_intensity",     min = 0, max = 1000, scale = 1000, editor = "number", slider = true, default = 0, help = "Controls the brightness of the milky way texture." },
		{ category = "Night Sky", feature = "phys_sky", name = "MilkyWay Blue tint", id = "mw_blue_tint",     min = 0, max = 100, scale = 100,  editor = "number", slider = true, default = 30, help = "MilkyWay is tinted blue to simulate human perception in low-light conditions." },
		{ category = "Night Sky", feature = "phys_sky", name = "Rotation", id =  "stars_rotation",       min = 0, max = 3600, editor = "number", slider = true, default = 0, scale = 10, help = "Rotation angle of the stars around the celestial pole" },
		{ category = "Night Sky", feature = "phys_sky", name = "Celestial Pole Altitude", id = "stars_pole_alt", min = 0, max = 1800, editor = "number", slider = true, default = 0, scale = 10, help = "Celestial pole altitude in degrees. Approximately equal to the observer's latitude position on Earth." },
		{ category = "Night Sky", feature = "phys_sky", name = "Celestial Pole Azimuth", id = "stars_pole_azi", min = 0, max = 3600, editor = "number", slider = true, default = 0, scale = 10, help = "Celestial pole azimuth in degrees. Should point to North on Earth. Related to the Sun azimuth." },
		
		{ category = "Env Capture", feature = "phys_sky", name = "Sky Exp Exterior Adjust", id = "env_exterior_capture_sky_exp", editor="number", default = "", min = -1000, max = 1000, default = 0, editor = "number" , slider = true, help = "Adjusts the sky exposure in the captured exterior cubemap"},
		{ category = "Env Capture", feature = "phys_sky", name = "Sun Int Exterior Adjust", id = "env_exterior_capture_sun_int", editor="number", default = "", min = -2500, max = 2500, default = 0, editor = "number" , slider = true, help = "Adjusts the sun intensity in the captured exterior cubemap"},
		{ category = "Env Capture", feature = "phys_sky", name = "Exterior Capture Pos", id = "env_exterior_capture_pos", editor="point", default = InvalidPos(), helper = "absolute_pos", help = "The position to capture the exterior env map from.", buttons = {{name = "View", func = "ViewExteriorEnvPos" }, {name ="Use Shaderball", func = "UseSelectionAsExteriorEnvPos"}}, scale = "m"},
		{ category = "Env Capture", feature = "phys_sky", name = "Sky Exp Interior Adjust", id = "env_interior_capture_sky_exp", editor="number", default = "", min = -1000, max = 1000, default = 0, editor = "number" , slider = true, help = "Adjusts the sky exposure in the captured interior cubemap"},
		{ category = "Env Capture", feature = "phys_sky", name = "Sun Int Interior Adjust", id = "env_interior_capture_sun_int", editor="number", default = "", min = -2500, max = 2500, default = 0, editor = "number" , slider = true, help = "Adjusts the sun intensity in the captured interior cubemap"},
		{ category = "Env Capture", feature = "phys_sky", name = "Interior Capture Pos", id = "env_interior_capture_pos", editor="point", default = InvalidPos(), helper = "absolute_pos", help = "The position to capture the interior env map from.", buttons = {{name = "View", func = "ViewInteriorEnvPos" }, {name ="Use Shaderball", func = "UseSelectionAsInteriorEnvPos"}}, scale = "m"},
		{ category = "Env Capture", feature = "phys_sky", name = "Map for Cubemaps", id = "env_capture_map", editor="text", default = "", read_only=true, help = "The map name on which the position of the last capture is"},
		{ category = "Env Capture", feature = "phys_sky", name = "Capture", id = "env_capture", editor="text", default = "", read_only=true, help = "Click to capture cubemaps", buttons = {{name = "Exterior", func = "CaptureExteriorEnvmap"}, {name = "Interior", func = "CaptureInteriorEnvmap"}, {name = "Both", func = "CaptureBothEnvmaps"}}},
		{ category = "Env Capture", feature = "phys_sky", name = "View Map", id = "env_view_site", editor = "dropdownlist", items = {"Exterior", "Interior"}, default = "Exterior", dont_save = true, buttons = {{name = "View", func = "ViewEnv"}, {name = "Hide", func = "HideEnv"}}},
		{ category = "Env Capture", feature = "phys_sky", name = "Convert HDR Pano", id = "hdr_pano", editor = "browse", default = false, filter = "Radiance HDR File|*.hdr", default = "", dont_save = true, buttons = {{name = "Exterior", func = "ConvertExteriorEnvmap"}, {name = "Interior", func = "ConvertInteriorEnvmap"}}},
		{ category = "Env Capture", feature = "phys_sky", name = "Lightmodel for Capture", id = "lm_capture", editor = "preset_id", preset_class = "LightmodelPreset", default = "", help = "Indicates which light model should be used for the baking.", no_validate = true,  },
		
		{ category = "Fog", feature = "fog", name = "Fog color", id = "fog_color", default = RGB(180, 180, 180), editor = "color", help = "The default color of the fog." },
		{ category = "Fog", feature = "fog", name = "Fog density", id = "fog_density", default = 20, min = 0, max = 2000, scale = 100, editor = "number", slider = true, help = "The fog thickness." },
		{ category = "Fog", feature = "fog", name = "Fog height falloff", id = "fog_height_falloff" , default = 1500, min = 1, max = 2500, editor = "number", slider = true, help = "The fog thickness change with height" },
		{ category = "Fog", feature = "fog", name = "Fog start (m)", id = "fog_start", default = 0, min = 0, max = 1000 * 1000, scale = 1000, editor = "number" , slider = true, help = "The distance to fog start, in meters."},
		
		{ category = "Water", feature = "water", name = "Water Color", id = "water_color", editor = "color", default = RGB(127, 127, 127), help = "The color of the terrain water" },
		{ category = "Water", feature = "water", name = "Opacity Modifier", id = "absorption_coef", min = 0, max = 100, default = 100, scale = 100, editor = "number", slider = true, help = "How much light does the water absorb" },
		{ category = "Water", feature = "water", name = "Reflection Modifier", id = "minimum_depth", min = 0, max = 200, default = 100, scale = 100, editor = "number", slider = true, help = "How deep will the water appear minimally" },
		
		{ category = "Ice", feature = "ice", name = "Ice color", id = "ice_color", editor = "color", default = RGB(255, 255, 255), help = "The color of the ice that will affect the buildings and rocks" },
		{ category = "Ice", feature = "ice", name = "Ice strength", id = "ice_strength", min = 0, max = 100, default = 0, scale = 100, editor = "number", slider = true, help = "How strong will be ice get" },
		
		{ category = "Snow", feature = "snow", name = "Snow color", id = "snow_color", editor = "color", default = RGB(167, 167, 167), help = "The color of the snow of the terrain" },
		{ category = "Snow", feature = "snow", name = "Snow direction X", 	id = "snow_dir_x", 	editor = "number", slider = true, default = 0, 	min = -1000, max = 1000, scale = 1000, help = "Snowfall direction X" },
		{ category = "Snow", feature = "snow", name = "Snow direction Y", 	id = "snow_dir_y", 	editor = "number", slider = true, default = 0, 	min = -1000, max = 1000, scale = 1000, help = "Snowfall direction Y" },
		{ category = "Snow", feature = "snow", name = "Snow direction Z", 	id = "snow_dir_z", 	editor = "number", slider = true, default = 1000, min = -1000, max = 1000, scale = 1000, help = "Snowfall direction Z" },
		{ category = "Snow", feature = "snow", name = "Snow strength",		id = "snow_str",	editor = "number", slider = true, default = 0, 	min = 0,  max = 1000, scale = 1000, help = "The constant snow strength" },
		{ category = "Snow", feature = "snow", name = "Snow", id = "snow_enable", editor = "bool", default = false, },
		
		{ category = "Wind", id = "wind", name = "Wind", editor = "preset_id", default = false, preset_class = "WindDef" },
		
		{ category = "Heat Haze", id = "enable_heat_haze", name = "Enable Heat Haze", editor = "bool", default = false },
		
		{ category = "Distance Blur and Desaturation", feature = "dist_blur_desat", name = "Blur", id = "pp_blur", min = 0, max = 100, default = 0, editor = "number",slider = true, help = "The intensity of the blur effect for distant objects." },
		{ category = "Distance Blur and Desaturation", feature = "dist_blur_desat", name = "Blur distance", id = "pp_blur_distance", min = 0, max = 600, default = 0, editor = "number", slider = true, help = "The distance at which the distant objects start to get blurry." },
		{ category = "Distance Blur and Desaturation", feature = "dist_blur_desat", name = "Desaturation", id = "pp_desaturation", min = 0, max = 100, default = 0, editor = "number", slider = true, help = "How intense is the desaturation of colors of the distant objects." },
		{ category = "Distance Blur and Desaturation", feature = "dist_blur_desat", name = "Desaturation distance", id = "pp_desaturation_distance", min = 0, max = 600, default = 0, editor = "number", slider = true, help = "The distance at which the distant objects' colors get desaturated." },
		
		{ category = "Exposure", feature = "autoexposure", id="_", editor="help", default=false, help = AutoExposureInstructions, buttons =  {{name = "[On]", func = "AutoExposureOn"},{name = "[Off]", func = "AutoExposureOff"}, {name = "[Split]", func = "AutoExposureSplit"}, {name="[Debug]", func="AutoExposureDebugToggle"}}  },
		{ category = "Exposure", feature = "autoexposure", name = "Exposure", id = "exposure", min = -200, max = 200, default = 0, editor = "number" , slider = true, help = "The global exposure control in 1/100 EV. Intensity change is pow(2, E / 100)" },
		{ category = "Exposure", feature = "autoexposure", name = "Auto Exposure (AE)",    id="ae_key_bias",          min = -3000000, max = 3000000, default = 0, scale = 1000000, editor = "number" , slider = true, help = "Exposure key value multiplier." },
		{ category = "Exposure", feature = "autoexposure", name = "Scene lum min",    id="ae_lum_min",           min = -14*10000, max = 20*10000, default = -14*10000, scale = 10000, editor = "number" , slider = true, help = "Clamps average scene luminance.", no_edit = true },
		{ category = "Exposure", feature = "autoexposure", name = "Scene lum max",    id="ae_lum_max",           min = -14*10000, max = 20*10000, default =  20*10000, scale = 10000, editor = "number" , slider = true, help = "Clamps average scene luminance.", no_edit = true },
		{ category = "Exposure", feature = "autoexposure", name = "Adaptation speed bright",id="ae_adapt_speed_bright", min = 1, max = 1500, default = 500, scale = 100, editor = "number" , slider = true, help = "How fast the eye adapts to brighter scenes.", no_edit = true },
		{ category = "Exposure", feature = "autoexposure", name = "Adaptation speed dark",  id="ae_adapt_speed_dark",   min = 1, max = 1500, default = 500, scale = 100, editor = "number" , slider = true, help = "How fast the eye adapts to darker scenes.", no_edit = true },
		{ category = "Exposure", feature = "autoexposure", name = "AE Lum Min", id="ae_darkness_ign", min = 0, max = 99, default = 20, scale = "%", editor = "number" , slider = true, help = "From what percentage of the luminance of the scene to consider." },
		{ category = "Exposure", feature = "autoexposure", name = "AE Lum Max", id="ae_brightness_ign", min = 1, max = 100, default = 95, scale = "%", editor = "number" , slider = true, help = "Until what percentage of the luminance of the scene to consider." },
		{ category = "Exposure", feature = "autoexposure", name = "Use Constant Exposure",  id="ae_disable", editor="bool", default=false, help = "Turn autoexposure on/off", },

		{ category = "Bloom", feature = "hdr bloom", name = "Strength", id = "pp_bloom_strength", min = 0, max = 100, default = 0, scale = 100, editor = "number", slider = true, help = "How much Bloom affects the resulting picture." },
		{ category = "Bloom", feature = "hdr bloom", name = "Threshold", id = "pp_bloom_threshold", min = 0, max = 100, default = 100, scale = 100, editor = "number", slider = true, help = "The luminance threshold after which colours bloom." },
		{ category = "Bloom", feature = "hdr bloom", name = "Contrast", id = "pp_bloom_contrast", min = 0, max = 100, default = 0, scale = 100, editor = "number", slider = true, help = "The contrast of the final Bloom effect." },
		{ category = "Bloom", feature = "hdr bloom", name = "Bloom colorization", id = "pp_bloom_colorization", min = 0, max = 100, scale = 100, default = 30, editor = "number", slider = true, help = "The mixing ratio between the original Bloom color and the tint." },
		{ category = "Bloom", feature = "hdr bloom", name = "Inner tint", id = "pp_bloom_inner_tint", default = RGB(180, 180, 180), editor = "color", help = "Bloom effect's inner tint." },
		{ category = "Bloom", feature = "hdr bloom", name = "Outer tint", id = "pp_bloom_outer_tint", default = RGB(180, 180, 180), editor = "color", help = "Bloom effect's outer tint." },
		{ category = "Bloom", feature = "hdr bloom", name = "Mip2 radius", id = "pp_bloom_mip2_radius" , min = 1, max = 64, default = 16, editor = "number", slider = true, help = "Gauss blur radius for mip2." },
		{ category = "Bloom", feature = "hdr bloom", name = "Mip3 radius", id = "pp_bloom_mip3_radius" , min = 4, max = 64, default = 16, editor = "number", slider = true, help = "Gauss blur radius for mip3." },
		{ category = "Bloom", feature = "hdr bloom", name = "Mip4 radius", id = "pp_bloom_mip4_radius" , min = 8, max = 64, default = 32, editor = "number", slider = true, help = "Gauss blur radius for mip4." },
		{ category = "Bloom", feature = "hdr bloom", name = "Mip5 radius", id = "pp_bloom_mip5_radius" , min = 8, max = 64, default = 32, editor = "number", slider = true, help = "Gauss blur radius for mip5." },
		{ category = "Bloom", feature = "hdr bloom", name = "Mip6 radius", id = "pp_bloom_mip6_radius" , min = 8, max = 64, default = 32, editor = "number", slider = true, help = "Gauss blur radius for mip6." },

		{ category = "Exposure", name = "Emissive Boost", id = "emissive_boost", min = 100, max = 10000, default = 100, scale = 10000, editor = "number", slider = true },
		{ category = "Exposure", name = "Particle Exposure Additive", id = "ps_exposure", min = -1000, max = 1000, default = 0, editor = "number" , slider = true, help = "EV Control in 1/100 EV to adjust particle brightness when blending. Intensity change is pow(2, E / 100)" },
		
		{ category = "Other", name = "AO texture darkness", id = "ao_lower_limit", editor = "number", slider = true, min = 0, max = 255, default = 0, scale = 255, help = "Fits the values of the Ambient Occlusion Map of all meshes in a new range that has the specified minimum value." },
		{ category = "Other", name = "SSAO strength", id = "pp_ssao_strength", min = 0, max = 200, editor = "number" , slider = true, default = 0, scale = 100, help = "The intensity of Screen-Space Ambient Occlusion in percents." },

		{ category = "Other", feature = "three_point_lighting", name = "Three Point Lighting", id = "three_point_lighting", editor = "preset_id", default = "", preset_class = "ThreePointLighting" },
		{ category = "Other", feature = "Unit_Lighting", name = "Unit Lighting Strength", id = "unit_lighting_strength", editor = "number", slider = true, min = 0, max = 100, default = 50, scale = 100, help = "The intensity of the Unit Lighting effect." },
		{ category = "Other", feature = "Unit_Lighting", name = "Unit Lighting Contrast", id = "unit_lighting_contrast", editor = "number", slider = true, min = 0, max = 100, default = 0, scale = 100, help = "The contrast strength of the Unit Lighting effect." },
		
		{ category = "Lights", name = "Light Shadows", id = "light_shadows", 	editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = 1000, feature = "shadow", help = "Shadows from lights strength." },
		{ category = "Lights", name = "LightColorA",   id = "lightcolor1",  	editor = "color", default = RGB(255, 255, 255), alpha = false, help = "This color can be used by point&spot lights." },
		{ category = "Lights", name = "LightColorB",   id = "lightcolor2", 	editor = "color", default = RGB(255, 255, 255), alpha = false, help = "This color can be used by point&spot lights." },
		{ category = "Lights", name = "LightColorC",   id = "lightcolor3", 	editor = "color", default = RGB(255, 255, 255), alpha = false, help = "This color can be used by point&spot lights." },
		{ category = "Lights", name = "LightColorD",   id = "lightcolor4", 	editor = "color", default = RGB(255, 255, 255), alpha = false, help = "This color can be used by point&spot lights." },
		{ category = "Lights", feature = "night", name = "Night Lights", id = "night", blend = const.NightBlendThreshold, editor = "bool", default = false, help = "Determines whether the lights should be switched on or off." },
	},
}

DefineClass.LightmodelPreset = {
	__parents = { "Preset", "Lightmodel" },
	
	GlobalMap = "LightmodelPresets",
	GedEditor = "LightmodelEditor",
	EditorMenubarName = "Lightmodels",
	EditorMenubar = "Editors.Art",
	EditorShortcut = "Ctrl-M",
	EditorIcon = "CommonAssets/UI/Icons/bulb ecology energy lamp light power.png",
	ValidateAfterSave = true,
	PropertyTabs = {
		{ TabName = "Preset", Categories = { Preset = true }, },
		{ TabName = "Sun", Categories = { Sun = true, ["Sun Path"] = true, ["Sun Pos"] = true, } },
		{ TabName = "Sky", Categories = { Sky = true, ["Night Sky"] = true, ["Env Capture"] = true, ["Cubemap"] = true, } },	
		{ TabName = "Weather", Categories = { Fog = true, Rain = true, Clouds = true, ["Cloud shadows"] = true, ["Wind"] = true, } },	
		{ TabName = "Environment", Categories = { Water = true, Snow = true, Ice = true, Frost = true, } },	
		{ TabName = "Effects", Categories = { Exposure = true, Bloom = true, Other = true, Vignette = true, ["Chromatic Aberration"] = true, ["Color Grading"] = true, Lights = true, } },	
	}
}

DefineClass.SHDiffuseIrradiance = {
	__parents = { "Preset" },
	properties = {
		{ name = "SH9 Coefficients",	 id = "sh9_coefficients", editor = "text", default = "", read_only = true },
	},
	EditorMenubarName = "",
	EditorMenubar = false,
}

function DoSetLightmodel(view, lm_buf, time, start_offset)
	if view < 1 or view > camera.GetViewCount() then return end
	start_offset = start_offset or 0
		
	SetSceneParam(view, "UseTimeOfDay", lm_buf.use_time_of_day and 1 or 0, 0, start_offset)
	if not lm_buf.use_time_of_day then
		local prev_azi = (GetSceneParam(view, "SunWidth") / 1000 + 360) % 360
		local azi = (lm_buf.sun_azi + mapdata.MapOrientation) % 360
		if abs(azi - prev_azi) > 180 then -- we better interpolate through 360
			if azi > 180 then
				prev_azi = prev_azi + 360
			else
				azi = azi + 360
			end
		end
		SetSceneParam(view, "SunWidth", prev_azi * 1000, 0, start_offset)
		SetSceneParam(view, "SunWidth", azi * 1000, time, start_offset)
		SetSceneParam(view, "SunHeight", lm_buf.sun_alt * 100, time, start_offset)
		if lm_buf.sky_custom_sun then
			SetSceneParam(view, "SkySunAzi", lm_buf.sky_custom_sun_azi * 1000, time, start_offset)
			SetSceneParam(view, "SkySunAlt", lm_buf.sky_custom_sun_alt * 100, time, start_offset)
		else
			SetSceneParam(view, "SkySunAzi", -1, 0, 0)
			SetSceneParam(view, "SkySunAlt", -1, 0, 0)
		end
		SetSceneParam(view, "SunShadowHeight", lm_buf.sun_shadow_height * 100, time, start_offset)
	end
	
	SetSceneParam(view, "Shadow", lm_buf.shadow, time, start_offset)
	if lm_buf.shadow then
		SetSceneParam(view, "ShadowRange", lm_buf.shadow_range, time, start_offset)
	end

	SetSceneParamColor(view, "MieCoefs", lm_buf.mie_coefs, time, start_offset)
	SetSceneParamColor(view, "RayCoefs", lm_buf.ray_coefs, time, start_offset)
	SetSceneParam(view, "MieSH", lm_buf.mie_sh, time, start_offset)
	SetSceneParam(view, "RaySH", lm_buf.ray_sh, time, start_offset)
	SetSceneParam(view, "MieMC", lm_buf.mie_mc, time, start_offset)
	SetSceneParam(view, "SkyExp", lm_buf.sky_exp, time, start_offset)
	SetSceneParamColor(view, "SunDiffuseColor", lm_buf.sun_diffuse_color, time, start_offset, false)
	SetSceneParam(view, "SunIntensity", lm_buf.sun_intensity, time, start_offset)

	SetSceneParam(view, "StarsIntensity", lm_buf.stars_intensity, time, start_offset)
	SetSceneParam(view, "StarsBlueTint", lm_buf.stars_blue_tint, time, start_offset)
	SetSceneParam(view, "StarsRotation", lm_buf.stars_rotation, time, start_offset)
	SetSceneParam(view, "StarsPoleAlt", lm_buf.stars_pole_alt, time, start_offset)
	SetSceneParam(view, "StarsPoleAzi", lm_buf.stars_pole_azi, time, start_offset)
	SetSceneParam(view, "MilkyWayIntensity", lm_buf.mw_intensity, time, start_offset)
	SetSceneParam(view, "MilkyWayBlueTint", lm_buf.mw_blue_tint, time, start_offset)

	SetSceneParam(view, "SunAngularRadius", lm_buf.sun_angular_radius, time, start_offset)
	SetSceneParam(view, "GlobalExposure", lm_buf.exposure, time, start_offset)
	SetSceneParam(view, "EmissiveBoost", lm_buf.emissive_boost, time, start_offset)
	SetSceneParam(view, "ExtEnvExposure", lm_buf.ext_env_exposure, time, start_offset)
	SetSceneParam(view, "IntEnvExposure", lm_buf.int_env_exposure, time, start_offset)
	SetSceneParam(view, "ParticleExposure", lm_buf.ps_exposure, time, start_offset)

	SetSceneParamColor(view, "FogColor", lm_buf.fog_color, time, start_offset)
	SetSceneParam(view, "FogGlobalDensity", lm_buf.fog_density, time, start_offset)
	SetSceneParam(view, "FogHeightFalloff", lm_buf.fog_height_falloff, time, start_offset)
	SetSceneParam(view, "FogStart", lm_buf.fog_start, time, start_offset)

	SetIceStrength(lm_buf.ice_strength, "Lightmodel", view, time, start_offset)
	SetSceneParamColor(view, "IceColor", lm_buf.ice_color, time, start_offset)
	SetSceneParamColor(view, "SnowColor", lm_buf.snow_color, time, start_offset)
	
	SetSceneParam(view, "SnowDirX", lm_buf.snow_dir_x, time, start_offset)
	SetSceneParam(view, "SnowDirY", lm_buf.snow_dir_y, time, start_offset)
	SetSceneParam(view, "SnowDirZ", lm_buf.snow_dir_z, time, start_offset)
	SetSceneParam(view, "SnowStr", lm_buf.snow_str, time, start_offset)
	
	SetSceneParamColor(view, "WaterColor", lm_buf.water_color, time, start_offset)
	SetSceneParam(view, "AbsorptionCoef", lm_buf.absorption_coef, time, start_offset)
	SetSceneParam(view, "MinimumDepth", lm_buf.minimum_depth, time, start_offset)
	
	SetSceneParam(view, "AutoExposureKeyBias", lm_buf.ae_key_bias, time, start_offset)
	SetSceneParam(view, "AutoExposureLumMin", lm_buf.ae_lum_min, time, start_offset)
	SetSceneParam(view, "AutoExposureLumMax", lm_buf.ae_lum_max, time, start_offset)
	SetSceneParam(view, "AutoExposureAdaptSpeedBright", lm_buf.ae_adapt_speed_bright, time, start_offset)
	SetSceneParam(view, "AutoExposureAdaptSpeedDark", lm_buf.ae_adapt_speed_dark, time, start_offset)
	SetSceneParam(view, "AutoExposureBrightnessIgnorance", 100 - lm_buf.ae_brightness_ign, time, start_offset)
	SetSceneParam(view, "AutoExposureDarknessIgnorance", lm_buf.ae_darkness_ign, time, start_offset)
	SetSceneParam(view, "AutoExposureDisable", lm_buf.ae_disable and 1 or 0, time, start_offset)

	if not config.LightModelUnusedFeatures["dist_blur_desat"] then
		SetSceneParamVector(view, "PostProc", 0, lm_buf.pp_blur, time, start_offset)
		SetSceneParamVector(view, "PostProc", 1, lm_buf.pp_desaturation, time, start_offset)
		SetSceneParamVector(view, "PostProc", 2, lm_buf.pp_blur_distance, time, start_offset)
		SetSceneParamVector(view, "PostProc", 3, lm_buf.pp_desaturation_distance, time, start_offset)
	end

	SetSceneParamColor(view, "BloomInnerTint", lm_buf.pp_bloom_inner_tint, time, start_offset)
	SetSceneParamColor(view, "BloomOuterTint", lm_buf.pp_bloom_outer_tint, time, start_offset)
	SetSceneParamVector(view, "Bloom", 0, lm_buf.pp_bloom_strength, time, start_offset)
	SetSceneParamVector(view, "Bloom", 1, lm_buf.pp_bloom_threshold, time, start_offset)
	SetSceneParamVector(view, "Bloom", 2, lm_buf.pp_bloom_contrast, time, start_offset)
	SetSceneParamVector(view, "Bloom", 3, lm_buf.pp_bloom_colorization, time, start_offset)
	SetSceneParamVector(view, "BloomRadii", 0, lm_buf.pp_bloom_mip2_radius, time, start_offset)
	SetSceneParamVector(view, "BloomRadii", 1, lm_buf.pp_bloom_mip3_radius, time, start_offset)
	SetSceneParamVector(view, "BloomRadii", 2, lm_buf.pp_bloom_mip4_radius, time, start_offset)
	SetSceneParamVector(view, "BloomRadii", 3, lm_buf.pp_bloom_mip5_radius, time, start_offset)
	SetSceneParamVector(view, "BloomRadii", 4, lm_buf.pp_bloom_mip6_radius, time, start_offset)

	SetSceneParamVector(view, "AOLowerLimit", 0, lm_buf.ao_lower_limit, time, start_offset)
	SetSceneParamVector(view, "SSAO", 0, lm_buf.pp_ssao_strength, time, start_offset)

	SetPostProcPredicate("heat_haze", lm_buf.enable_heat_haze)

	if not config.LightModelUnusedFeatures["three_point_lighting"] then
		if lm_buf.three_point_lighting ~= "" then
			Presets.ThreePointLighting.ThreePointLightingRenderVars[lm_buf.three_point_lighting]:Apply()
			table.change_base(hr, { EnableThreePointLighting = 1 })
		else
			table.change_base(hr, { EnableThreePointLighting = 0 })
		end
	end

	-- set up the cube map for the env mapped objects
	if lm_buf.exterior_envmap and lm_buf.exterior_envmap ~= "" then
		local exterior_sh = Presets.SHDiffuseIrradiance.Default[lm_buf.exterior_envmap .. "Exterior"] 
		if not exterior_sh then print("once", "Lightmodel", lm_buf.exterior_envmap .. "Exterior", "needs to be recaptured!") end
		local err = SetCubemap(view, string.format("Textures/Cubemaps/%sExterior", lm_buf.exterior_envmap), exterior_sh and Decode64(exterior_sh.sh9_coefficients) or "", 0, time, start_offset)
		if err then
			print("SetCubemap failed", err)
		end
	end
	if lm_buf.interior_envmap and lm_buf.interior_envmap ~= "" then
		local interior_sh = Presets.SHDiffuseIrradiance.Default[lm_buf.interior_envmap .. "Interior"] 
		if not interior_sh then print("once", "Lightmodel", lm_buf.interior_envmap .. "Interior", "needs to be recaptured!") end
		local err = SetCubemap(view, string.format("Textures/Cubemaps/%sInterior", lm_buf.interior_envmap), interior_sh and Decode64(interior_sh.sh9_coefficients) or "", 1, time, start_offset) 
		if err then
			print("SetCubemap failed", err)
		end
	end
	
	SetSceneParam(view, "LightShadows", lm_buf.light_shadows, time, start_offset)
	
	SetSceneParam(view, "GameSpecificData0", lm_buf.unit_lighting_strength, time, start_offset)
	SetSceneParam(view, "GameSpecificData1", lm_buf.unit_lighting_contrast, time, start_offset)

	for i = 1, 4 do
		SetSceneParamColor(view, "LightColor" .. i, lm_buf["lightcolor" .. i], time, start_offset)
	end

	Msg("LightmodelSetSceneParams", view, lm_buf, time, start_offset)
end

MapVar("CurrentLightmodel", {})
MapVar("LastSetLightmodel", {})

if FirstLoad then
	LightmodelOverride = false
end

function GetEnvMapsList(site)
	local maps = { "" }
	for _,v in ipairs(io.listfiles("Textures/Cubemaps")) do
		local map = string.match(v, "Textures/Cubemaps/(.*)" .. site .. "Env%.dds")
		if map then
			maps[#maps + 1] = map
		end
	end
	table.sort(maps)
	return maps
end

function PreloadLightmodelCubemaps(lightmodel)
	if not lightmodel or lightmodel == "" then
		return
	end

	local lm_buf = LightmodelPresets[lightmodel]
	if not lm_buf then
		return
	end

	local function preload_path(path)
		local image_id = ResourceManager.GetResourceID(path)
		if image_id == const.InvalidResourceID then
			printf("once", "Could not load image %s!", path or "")
			return
		end
		
		local image = AsyncGetResource(image_id)
		return image
	end
	local exterior_map = string.format("Textures/Cubemaps/%sExterior", lm_buf.exterior_envmap)
	local interior_map = string.format("Textures/Cubemaps/%sInterior", lm_buf.interior_envmap)

	local result = {
		Done = function(self)
			if self.exterior_specular then self.exterior_specular:ReleaseRef() end
			if self.interior_specular then self.interior_specular:ReleaseRef() end
		end,
		exterior_specular = preload_path(exterior_map .. "Specular"),
		interior_specular = preload_path(interior_map .. "Specular"),
	}
	return result
end

function SetLightmodelOverride(view, lightmodel)
	view = view or 1	
	lightmodel = LightmodelPresets[lightmodel] or lightmodel
	lightmodel = type(lightmodel) == "table" and lightmodel or false
	if LightmodelOverride ~= lightmodel then
		LightmodelOverride = lightmodel
		SetLightmodel(view, LastSetLightmodel and LastSetLightmodel[1] or lightmodel, 0, "from_override")
	end
end

function SetLightmodel(view, lightmodel, time, from_override)
	if not CurrentLightmodel then return end --not on map
	view = view or 1
	time = time or 0
	lightmodel = LightmodelPresets[lightmodel] or lightmodel
	if type(lightmodel) ~= "table" then 
		if type(lightmodel) == "string" then
			assert(false, "lightmodel not found: " .. tostring(lightmodel))
		end
		lightmodel = LightmodelPresets.ArtPreview
	end
	if view < 1 or view > camera.GetViewCount() then return end
	if LastSetLightmodel then
		LastSetLightmodel[view] = lightmodel
	end
	lightmodel = LightmodelOverride or lightmodel
	local prev_lm = CurrentLightmodel[view]
	if prev_lm and not IsKindOf(prev_lm, "LightmodelPreset") then
		setmetatable(prev_lm, LightmodelPreset) -- !!! backwards compatibility
	end
	CurrentLightmodel[view] = lightmodel
	
	hr.TODForceTime = -1
	local override = LightmodelOverride == lightmodel
	if override then
		if lightmodel.use_time_of_day then
			hr.TODForceTime = LocalToEarthTime(lightmodel.time*1000)
		end
	end
	--override is true when overriding and false when restoring
	--from_override is true for both calls
	Msg("LightmodelChange", view, lightmodel, time, prev_lm, from_override)
	DoSetLightmodel(view, lightmodel, time)
	Msg("AfterLightmodelChange", view, lightmodel, time, prev_lm, from_override)
end

do
	local unused_features = config.LightModelUnusedFeatures or empty_table
	for _, prop in ipairs(Lightmodel.properties) do
		if prop.feature and unused_features[prop.feature] then
			prop.no_edit = true
		end
	end
end

function LightmodelPreset:ListEquivalentLMs(root, prop_id, ged, param)
	local feature = string.match(prop_id, "preset_(.+)")
	local list = LightmodelEquivalenceByValue(self, feature)
	ged:ShowMessage("Equivalent Lightmodels", table.concat(list, "\n"))
end

function LightmodelPreset:SetFeaturePreset(ref_preset)
	if not ref_preset then return end
	local feature = ref_preset.group
	if not feature then return end
	local feature_data = LightmodelFeatureToProperties[feature]
	for _, prop in ipairs(feature_data) do
		self:SetProperty(prop.id, ref_preset:GetProperty(prop.id))
	end
end

function LightmodelPreset:SetFeaturePresetId(feature, feature_preset_id)
	local presets = Presets.LightmodelFeaturePreset or empty_table
	local feature_group = presets[feature] or empty_table
	self:SetFeaturePreset(feature_group[feature_preset_id])
end

local function EarlyClassDescendants(classdefs, target_class, callback)
	local cache = {}

	local function EarlyIsKindOf(obj_class, target_class)
		local cache_hit = cache[obj_class]
		if cache_hit ~= nil then
			return cache_hit
		end

		if obj_class == target_class then
			cache[obj_class] = true
			return true
		end
		local class = classdefs[obj_class]
		for _, parent in ipairs(class and class.__parents) do
			if(EarlyIsKindOf(parent, target_class)) then
				return true
			end
		end
		cache[obj_class] = false
		return false
	end


	for class_name in pairs(classdefs) do
		if EarlyIsKindOf(class_name, target_class) then
			callback(class_name, classdefs[class_name])
		end
	end
end
   
function OnMsg.ClassesGenerate(classdefs)
	LightmodelFeatureToProperties = {}

	local properties = {}
	EarlyClassDescendants(classdefs, "LightmodelPart", function(class_name, classdef)
		local classProperties = {}
	
		if classdef.GetLightmodelProperties then
			classdef:GetLightmodelProperties(classProperties)
		else
			table.iappend(classProperties, classdef.properties)
		end
		
		local uses_preset = function(chain_func)
			return function(self, ...)
				local preset_id = "preset_" .. classdef.lightmodel_feature
				local uses_preset = self[preset_id] and self[preset_id] ~= ""
				if uses_preset then return uses_preset end
				if type(chain_func) == "function" then return chain_func(self, ...) end
				if chain_func then return chain_func end
				return false
			end
		end
		for k, prop in ipairs(classProperties) do
			if not prop.category then
				prop.category = classdef.lightmodel_category
			end
			if not prop.feature then
				prop.feature = classdef.lightmodel_feature
			end
			local lm_prop = table.copy(prop)
			lm_prop.dont_save = uses_preset(lm_prop.dont_save)
			lm_prop.read_only = uses_preset(lm_prop.read_only)
			properties[#properties + 1] = lm_prop

			for _,button in ipairs(lm_prop.buttons or empty_table) do
				if not Lightmodel[button.func] and classdef[button.func] then
					Lightmodel[button.func] = classdef[button.func]
				elseif Lightmodel[button.func] and not classdef[button.func] then
					classdef[button.func] = Lightmodel[button.func]
				end
			end
		end	
	end)
	
	for _, prop in ipairs(properties) do
		local feature = prop.feature
		if feature then
			local feature_list = LightmodelFeatureToProperties[feature]
			if not feature_list then
				feature_list = {}
				LightmodelFeatureToProperties[feature] = feature_list
			end
			table.insert(feature_list, prop)
		end
	end

	-- Generate Additional LM properties
	for feature, feature_data in pairs(LightmodelFeatureToProperties) do
		local preset_feature_prop_id = "preset_" .. feature
		feature_data.preset_feature_prop_id = preset_feature_prop_id
		table.insert(Lightmodel.properties, {
			id = preset_feature_prop_id,
			editor = "preset_id",
			preset_class = "LightmodelFeaturePreset",
			preset_group = feature,
			default = "",
			category = (feature_data[1] or empty_table).category, 
			buttons = {{ name = "List",  func = "ListEquivalentLMs"}}
		})

		table.iappend(Lightmodel.properties, feature_data)
	end
end

function OnMsg.DataLoaded()
	for _, lm in pairs(LightmodelPresets) do
		for feature, data in pairs(LightmodelFeatureToProperties) do
			local preset_id = lm:GetProperty(data.preset_feature_prop_id)
			lm:SetFeaturePresetId(feature, preset_id)
		end
	end
end

local lightmodel_properties
function OnMsg.ClassesBuilt()
	lightmodel_properties = {}
	local preset = LightmodelPreset
	for _, prop_meta in ipairs(preset:GetProperties()) do
		if prop_meta.category ~= "Preset" and not prop_eval(prop_meta.no_edit, preset, prop_meta) and not prop_eval(prop_meta.read_only, preset, prop_meta)then
			lightmodel_properties[#lightmodel_properties + 1] = prop_meta
		end
	end
end


function BlendLightmodels(result, lm1, lm2, num, denom)
	SuspendObjModified("BlendLightmodels")
	local firstHalf = 2*num < denom
	for _, prop_meta in ipairs(lightmodel_properties) do
		local prop_id = prop_meta.id
		local v1 = lm1:GetProperty(prop_id)
		local v2 = lm2:GetProperty(prop_id)
		local value
		local prop_blend = prop_meta.blend
		if num >= denom or v1 == v2 or prop_blend == "set" then
			value = v2
		elseif num <= 0 or prop_blend == "suppress" then
			value = v1
		else
			value = v2
			local prop_editor = prop_meta.editor
			if prop_editor == "number" or prop_editor == "point" then
				value = Lerp(v1, v2, num, denom)
			elseif prop_editor == "color" then
				value = InterpolateRGB(v1, v2, num, denom)
			elseif type(prop_blend) == "number" and prop_blend ~= 50 then
				-- "blend" here is a number indicating the descrete value change threshold
				if prop_editor == "bool" then
					value = v1 and 100 * num < prop_blend * denom or v2 and 100 * num >= (100 - prop_blend) * denom
				elseif 100 * num < prop_blend * denom then
					value = v1
				end
			elseif firstHalf then
				value = v1
			end
		end
		result:SetProperty(prop_id, value)
	end
	ResumeObjModified("BlendLightmodels")
end

function LightmodelPreset:GetInteriorEnvmapImage()
	return "Textures/Cubemaps/Thumbnails/" .. self.interior_envmap .. "Interior.jpg"
end

function LightmodelPreset:GetExteriorEnvmapImage()
	return "Textures/Cubemaps/Thumbnails/" .. self.exterior_envmap .. "Exterior.jpg"
end

function LightmodelPreset:Sethdr_pano(value)
	self.hdr_pano = value
end

local function AppendDefaultExtension(path, default_extension)
	if path and path ~= "" then
		local _, _, extension = SplitPath(path)
		if not extension or extension == "" then
			path = path .. default_extension
		end
	end
	return path
end

if Platform.developer then
	function LightmodelPreset:Setsky_custom_sun(b)
		self.sky_custom_sun = b
		if b then
			self.sky_custom_sun_alt = self.sun_alt
			self.sky_custom_sun_azi = self.sun_azi
		else
			self.sky_custom_sun_alt = 0
			self.sky_custom_sun_azi = 180
		end
		ObjModified(self)
	end
end

function LightmodelPreset:Setuse_time_of_day(b)
	self.use_time_of_day = b
	ObjModified(self)
end

function LightmodelPreset:Setshadow(b) 
	self.shadow = b
	ObjModified(self)
end

function LightmodelPreset:Setae_brightness_ign(b)
	self.ae_brightness_ign = b
	if (self.ae_brightness_ign - self.ae_darkness_ign <= 1) then
		self.ae_darkness_ign = self.ae_brightness_ign - 1
	end
end

function LightmodelPreset:Setae_darkness_ign(b)
	self.ae_darkness_ign = b
	if (self.ae_brightness_ign - self.ae_darkness_ign <= 1) then
		self.ae_brightness_ign = self.ae_darkness_ign + 1
	end
end

function LightmodelPreset:Getsun_earthtime_info()
	local sunrise = hr.TODSunriseTime
	local sunset = hr.TODSunsetTime
	local noon =	 sunrise + (sunset - sunrise) / 2
	return string.format("Sunrise %02d:%02d Noon %02d:%02d Sunset %02d:%02d",
		sunrise / 60, sunrise % 60,
		noon / 60, noon % 60,
		sunset / 60, sunset % 60
		)
end

function LightmodelPreset:Getsunrise_time() return EarthToLocalTime(hr.TODSunriseTime) end
function LightmodelPreset:Getsunrise_azi() return hr.TODSunriseAzi end
function LightmodelPreset:Getsunset_time() return EarthToLocalTime(hr.TODSunsetTime) end
function LightmodelPreset:Getsunset_azi() return hr.TODSunsetAzi end
function LightmodelPreset:Getsun_max_elevation() return hr.TODSunMaxElevation end

function LightmodelPreset:Getsun_shadow_min() return hr.TODSunShadowMinAltitude end
function LightmodelPreset:Setsun_shadow_min(v) hr.TODSunShadowMinAltitude = v end

function LightmodelPreset:Getsun_nr() return hr.TODNorthRotation end
function LightmodelPreset:Setsun_nr(v) hr.TODNorthRotation = v end

function LightmodelPreset:Setsunrise_time(v) 
	hr.TODSunriseTime = LocalToEarthTime(v)
	ObjModified(self) 
end
function LightmodelPreset:Setsunrise_azi(v) 
	hr.TODSunriseAzi = v
	ObjModified(self) 
end
function LightmodelPreset:Setsunset_time(v) 
	hr.TODSunsetTime = LocalToEarthTime(v)
	ObjModified(self) 
end
function LightmodelPreset:Setsunset_azi(v) 
	hr.TODSunsetAzi = v
	ObjModified(self) 
end
function LightmodelPreset:Setsun_max_elevation(v) 
	hr.TODSunMaxElevation = v
	ObjModified(self)
end

function LightmodelPreset:Settime(v)
	self.time = v
	if hr.TODForceTime >= 0 then
		hr.TODForceTime = LocalToEarthTime(self.time*1000)
	end
end

function LightmodelPreset:GetListName()
	return self.group --string.match(self.id, "(%w+)_") or "*"
end

function LightmodelPreset:Gettime_next(v)
	local list_name = self:GetListName()
	local next_lm = FindNextLightmodel(list_name, self.time+1)
	if not next_lm then return "" end
	return string.format("%02d:%02d (%s)", next_lm.time / 60, next_lm.time % 60, next_lm.id)
end

function LightmodelPreset:PreviewStart()
	if not self:EditorCheck(true) then return end
	
	SetLightmodelOverride(1, self.id)
	hr.TODForceTime = LocalToEarthTime(self.time*1000)
end

function LightmodelPreset:PreviewEnd()
	if not self:EditorCheck(true) then return end
	
	local list_name = self:GetListName()
	local next_lm = FindNextLightmodel(list_name, self.time+1)
	SetLightmodelOverride(1, self.id)
	hr.TODForceTime = LocalToEarthTime(next_lm.time*1000)
end

function LightmodelPreset:PreviewBlendStart()
	if not self:EditorCheck(true) then return end
	
	local list_name = self:GetListName()
	local prev_lm = FindPrevLightmodel(list_name, self.time - 1)
	SetLightmodelOverride(1, prev_lm.id)
	hr.TODForceTime = LocalToEarthTime(self.time*1000)
end

function LightmodelPreset:PreviewBlendEnd()
	if not self:EditorCheck(true) then return end
	
	SetLightmodelOverride(1, self.id)
	hr.TODForceTime = LocalToEarthTime((self.time + self.blend_time)*1000)
end

function LightmodelPreset:PreviewBlend()
	if IsEditorActive() then
		print("Lightmodel blending preview works only outside the in-game editor!")
		return
	end
	if not self:EditorCheck(true) then return end
	
	CreateRealTimeThread(function()
		local list_name = self:GetListName()
		local prev_lm = FindPrevLightmodel(list_name, self.time - 1)
		CancelRendering()
		SetLightmodelOverride(1, false)
		SetLightmodel(1, prev_lm.id, 0)
		Sleep(50)
		ResumeRendering()
		local start_time = LocalToEarthTime(self.time*1000)
		local end_time   = LocalToEarthTime((self.time+self.blend_time)*1000)
		hr.TODForceTime = start_time
		Sleep(1000)
		local blend_time = MulDivRound(self.blend_time, const.HourDuration, 60)
		SetLightmodel(1, self.id, blend_time)
		local step = MulDivRound(60*1000, 10, const.HourDuration)
		CreateGameTimeThread(function()
			for time = start_time, end_time, step do
				hr.TODForceTime = time
				Sleep(10)
			end
			self:PreviewBlendEnd(self)
		end)
	end)
end

function LightmodelsCombo()
	return table.keys2(LightmodelPresets, true, "")
end

DefineConstInt("Disaster", "LightningHorizontalMaxDistance", 600, "m")
DefineConstInt("Disaster", "LightningHorizontalMinDistance", 300, "m")
DefineConstInt("Disaster", "LightningVerticalMaxDistance", 600, "m")
DefineConstInt("Disaster", "LightningVerticalMinDistance", 300, "m")

function WaitLightingStrike(view)
	local lm = CurrentLightmodel[view]
	if not lm or not lm.lightning_enable then
		return
	end
	Sleep(AsyncRand(lm.lightning_interval_min, lm.lightning_interval_max))
	lm = CurrentLightmodel[view]
	if not lm or not lm.lightning_enable then
		return
	end
	local eye, lookat, _, _, _, fov = GetCamera()
	if AsyncRand(100) < lm.lightning_strike_chance then
		local disaster = const.Disaster
		local min, max, lightning_fx
		if AsyncRand(100) < lm.lightning_vertical_chance then
			min, max, lightning_fx = disaster.LightningVerticalMinDistance, disaster.LightningVerticalMaxDistance, "LightningFarVertical"
		else
			min, max, lightning_fx = disaster.LightningHorizontalMinDistance, disaster.LightningHorizontalMaxDistance, "LightningFarHorizontal"
		end
		local fov_safe_area = 20 * 60
		fov = Max(Min(fov + fov_safe_area, 360 * 60), 0)
		local rot_angle_in_frustum = AsyncRand(fov) - DivRound(fov, 2) + camera.GetYaw()
		local rot_radius = AsyncRand(min, max)
		local pos = RotateRadius(rot_radius, rot_angle_in_frustum, lookat):SetTerrainZ()
		PlayFX(lightning_fx, "start", pos, pos, pos)
	else
		local pos = RotateRadius(100 * guim, AsyncRand(60 * 360), eye)
		PlayFX("LightningThunderAround", "start", pos)
	end
	return true
end

if FirstLoad then
	LightningThreads = false
end

function UpdateLightingThread(view)
	local lm = CurrentLightmodel[view]
	local lightning_thread = LightningThreads and LightningThreads[view]
	if not lm or not lm.lightning_enable then
		DeleteThread(lightning_thread)
		if LightningThreads then LightningThreads[view] = nil end
		return
	end
	if IsValidThread(lightning_thread) then
		return
	end
	LightningThreads = LightningThreads or {}
	LightningThreads[view] = CreateMapRealTimeThread(function(view)
		local lm = CurrentLightmodel[view]
		Sleep(lm and lm.lightning_delay_start or 0)
		while WaitLightingStrike(view) do end
		LightningThreads[view] = nil
	end, view)
end

function OnMsg.DoneMap()
	for view, thread in pairs(LightningThreads) do
		DeleteThread(thread)
	end
	LightningThreads = false
end

function OnMsg.LoadGame()
	for view in pairs(CurrentLightmodel) do
		UpdateLightingThread(view)
	end
end

function OnMsg.LightmodelChange(view, lm, time, prev_lm)
	local target_fx_class = "View" .. view
	PlayFX("SetLightmodel", "end", prev_lm and prev_lm.id or "", target_fx_class)
	PlayFX("SetLightmodel", "start", lm.id, target_fx_class)
	UpdateLightingThread(view)
end

function OnMsg.DoneMap()
	if not CurrentLightmodel then
		return
	end
	for view = 1, 1 do
		local target_fx_class = "View" .. view
		local lm = CurrentLightmodel[view]
		if lm then
			if lm.night then
				PlayFX("Day", "end", lm.id or "", target_fx_class)
			else
				PlayFX("Night", "end", lm.id or "", target_fx_class)
			end
			PlayFX("Rain", "end", lm.id or "", target_fx_class)
			PlayFX("Stormy", "end", lm.id or "", target_fx_class)
			PlayFX("SetLightmodel", "end", lm.id or "", target_fx_class)
		end
	end
end

function OnMsg.GedClosing(id)
	local app = GedConnections[id]
	if app.app_template == "LightmodelEditor" then
		hr.AutoExposureMode = EngineOptions.EyeAdaptation == "On" and 1 or 0
		hr.EnablePostProcExposureSplit = 0
	end
end

function OnMsg.GatherFXActions(list)
	list[#list+1] = "Day"
	list[#list+1] = "Night"
	list[#list+1] = "Rain"
	list[#list+1] = "SetLightmodel"
end

if FirstLoad then
	LightmodelLists = false
end

function UpdateLightmodelLists()
	local lists = {}
	ForEachPreset(LightmodelPreset, function(lm, group_list)
		if lm.use_time_of_day then
			local list_name = lm:GetListName()
			local list = lists[list_name] or {}
			local entry = { time = lm.time, blend_time = lm.blend_time, id = lm.id }
			list[#list+1] = entry
			lists[list_name] = list
		end
	end)
	for list_name, list in pairs(lists) do
		table.sort(list, function(lm1, lm2) return lm1.time < lm2.time end)	
	end
	LightmodelLists = lists
end

OnMsg.BinAssetsLoaded = UpdateLightmodelLists

function FindNextLightmodel(list_name, time_of_day)
	local list = LightmodelLists and LightmodelLists[list_name]
	if not list then return end
	assert(time_of_day >= -24*60 and time_of_day < 2*24*60) -- time of 
	time_of_day = (time_of_day + 2*24*60) % (24*60)
	for i = 1, #list do 
		local lm = list[i]
		if lm.time >= time_of_day then
			return LightmodelPresets[lm.id]
		end
	end	
	return list[1]
end

function FindPrevLightmodel(list_name, time_of_day)
	local list = LightmodelLists and LightmodelLists[list_name]
	if not list then return end
	assert(time_of_day >= -24*60 and time_of_day < 2*24*60) -- time of 
	time_of_day = (time_of_day + 2*24*60) % (24*60)
	for i = #list, 1, -1 do 
		local lm = list[i]
		if lm.time <= time_of_day then
			return LightmodelPresets[lm.id]
		end
	end
	return list[#list]
end

------------- Editor only actions -----------------

function OnMsg.GedOpened(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == "LightmodelEditor" then
		local root = conn:ResolveObj("root")
		local active_lightmodel = LightmodelPreset.GetInitialSelection()
		if active_lightmodel then
			local selection = {
				table.find(root, root[active_lightmodel.group]),
				table.find(root[active_lightmodel.group], active_lightmodel),
			}
			conn:Send("rfnApp", "SetSelection", "root", selection)
		end
	end
end

function LightmodelPreset.GetInitialSelection()
	local id, val = next(LightmodelPresets)
	if not id then return end
	return LightmodelPresets[CurrentLightmodel and CurrentLightmodel[1] and CurrentLightmodel[1].id] or val
end

if FirstLoad then
	ChangeLightmodelOverrideThread = false
	CelestialPoleDebugThread = false
end

function SetLightmodelOverrideDelay(view, lm)
	if ChangeLightmodelOverrideThread then
		DeleteThread(ChangeLightmodelOverrideThread)
	end
	ChangeLightmodelOverrideThread = CreateRealTimeThread(function()
		Sleep(100)
		SetLightmodelOverride(view, lm)
		ChangeLightmodelOverrideThread = false
	end)
end

function LightmodelPreset:OnEditorSelect(selection, ged)
	if not self:EditorCheck() then return end

	if IsKindOf(ged:ResolveObj("SelectedPreset"), "GedMultiSelectAdapter") then
		return
	end

	if selection then
		SetLightmodelOverrideDelay(1, self)
		FXCache = false
	else
		SetLightmodelOverrideDelay(1, false)
	end
end

local function AdjustColor(obj, prop, brightness)
	local h, s, v = UIL.RGBtoHSV(GetRGB(obj[prop]))
	obj[prop] = RGB(UIL.HSVtoRGB(h, s, MulDivRound(v, brightness, 100)))
end

local function DebugMarkPole()
	hr.SkyCelestialPoleDebug = 1
	DeleteThread(CelestialPoleDebugThread)
	CelestialPoleDebugThread = CreateRealTimeThread(function()
		Sleep(60000)
		hr.SkyCelestialPoleDebug = 0
	end)
end

function LightmodelPreset:Getcubemap_capture_preview()
	return table.changed(hr, "CubemapCapturePreview") and true
end

function LightmodelPreset:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "env_view_site" then
		if table.changed(hr, "ViewEnv") then
			self:ViewEnv()
		end
		return
	elseif prop_id == "sky_is" then
		if self[prop_id] then
			hr.DeferFlags = hr.DeferFlags | const.DeferFlagSkyIS
		else
			hr.DeferFlags = hr.DeferMode & ~const.DeferFlagSkyIS
		end
		return
	elseif prop_id == "cubemap_capture_preview" then
		if self[prop_id] then
			CubemapCaptureMode(true, "CubemapCapturePreview")
		else
			CubemapCaptureMode(false, "CubemapCapturePreview")
		end
	elseif prop_id == "env_exterior_capture_pos" or prop_id == "env_interior_capture_pos" then
		self.env_capture_map = GetMapName()
		ObjModified(self)
	elseif prop_id == "stars_rotation" or prop_id == "stars_pole_alt" or prop_id == "stars_pole_azi" then
		DelayedCall(50, DebugMarkPole)
	elseif prop_id == "Group" or prop_id == "use_time_of_day" or prop_id == "time" or prop_id == "blend_time" then
		UpdateLightmodelLists()
	end
	for feature, feature_data in pairs(LightmodelFeatureToProperties) do
		if prop_id == feature_data.preset_feature_prop_id then
			self:SetFeaturePresetId(feature, self:GetProperty(prop_id))
		end
	end
	if self:EditorCheck() then
		DoSetLightmodel(1, self, 0)
		DelayedCall(300, function(object)
			Msg("LightmodelChange", 1, object, 0, object)
		end, self)
	end
end

function LightmodelPreset:Gray(root, prop, ged)
	local r, g, b = GetRGB( self[prop] )
	local gray = (33 * r + 50 * g + 17 * b) / 100
	return GedSetProperty(ged, self, prop, RGB(gray, gray, gray)) -- a call to the Ged Op for undo support
end

function LightmodelPreset:ViewExteriorEnvPos()
	editor.ClearSelWithUndoRedo()
	ViewPos(self.env_exterior_capture_pos, 20*guim)
end

function LightmodelPreset:ViewInteriorEnvPos()
	editor.ClearSelWithUndoRedo()
	ViewPos(self.env_interior_capture_pos, 20*guim)
end

if FirstLoad then
	g_LightmodelViewEnvLastCam = false
end

function LightmodelPreset:ViewEnv()
	local envmap_name = self.id .. self.env_view_site
	local envmap_path = "Textures/Cubemaps/" .. envmap_name
	
	if not io.exists(envmap_path .. "Env.dds") then
		assert(not "Env map must be captured before viewed!")
		return
	end
	
	local envmap_sh = Presets.SHDiffuseIrradiance.Default[envmap_name] 
	envmap_sh = envmap_sh and Decode64(envmap_sh.sh9_coefficients)
	
	DoSetLightmodel(1, LightmodelPresets.ArtPreview, 0)
	SetCubemap(1, envmap_path, envmap_sh, 0, 0, 0)
	SetCubemap(1, envmap_path, envmap_sh, 1, 0, 0)
	
	if not table.changed(hr, "ViewEnv") then
		table.change(hr, "ViewEnv", {
			DeferFlags = const.DeferFlagEnvMapOnly,
			RenderCodeRenderables = 0,
			RenderTransparent = 0,
			RenderParticles = 0,
			RenderLights = 0,
			EnableScreenSpaceReflections = 0,
		})
		if not g_LightmodelViewEnvLastCam then
			g_LightmodelViewEnvLastCam = { GetCamera() }
			cameraFly.Activate(1)
		end
	end
end

function LightmodelPreset:HideEnv()
	if table.changed(hr, "ViewEnv") then
		table.restore(hr, "ViewEnv")
		DoSetLightmodel(0, self, 0)
		if g_LightmodelViewEnvLastCam then
			SetCamera(table.unpack(g_LightmodelViewEnvLastCam))
			g_LightmodelViewEnvLastCam = false
		end
	end
end

function LightmodelPreset:UseSelectionAsExteriorEnvPos()
	if IsEditorActive() and #editor.GetSel() > 0 then
		if IsKindOf(editor.GetSel()[1], "ShaderBall") then
			self.env_exterior_capture_pos = editor.GetSel()[1]:GetBSphere()
			self.env_capture_map = GetMapName()
			ObjModified(self)
		else
			print("Please use a Shaderball object to mark the desired environment capture position")
		end
	end
end

function LightmodelPreset:UseSelectionAsInteriorEnvPos()
	if IsEditorActive() and #editor.GetSel() > 0 then
		if IsKindOf(editor.GetSel()[1], "ShaderBall") then
			self.env_interior_capture_pos = editor.GetSel()[1]:GetBSphere()
			self.env_capture_map = GetMapName()
			ObjModified(self)
		else
			print("Please use a Shaderball object to mark the desired environment capture position")
		end
	end
end

if FirstLoad then
	g_LMCaptureQueue = {}
	g_LMCaptureThread = false
end

function LightmodelPreset:CaptureEnvmap(site, ged)
	if self.env_capture_map ~= GetMapName() then
		if MapData[self.env_capture_map] then
			ChangeMap(self.env_capture_map)
		else
			assert(false, "Capture map doesn't exist")
			return "Capture map doesn't exist: " .. self.env_capture_map
		end
	end

	local env_capture_pos = site == "Interior" and self.env_interior_capture_pos or self.env_exterior_capture_pos
	
	if not env_capture_pos:IsValidZ() then
		return "Capture position must not be a 2D position (on the terrain)"
	end
	
	local map_x, map_y = terrain.GetMapSize()
	if env_capture_pos:x() > map_x or 
		env_capture_pos:y() > map_y or 
		env_capture_pos:x() < 0 or 
		env_capture_pos:y() < 0 then
		assert(false, "Camera is out of map!")
		g_CapturingLightmodel = false
		return "Camera is out of map!"
	end
	
	local lightmodel_for_capture = LightmodelPresets[self.lm_capture] or self
	
	local sky_exp = GetSceneParam("SkyExp")
	local sun_int = GetSceneParam("SunIntensity")
	
	DoSetLightmodel(1, lightmodel_for_capture, 0)
	SetSceneParam(1, "RainEnable", 0, 0, 0)
	
	if site == "Exterior" then
		SetSceneParam(1, "SkyExp", lightmodel_for_capture.sky_exp + lightmodel_for_capture.env_exterior_capture_sky_exp, 0, 0)
		SetSceneParam(1, "SunIntensity", lightmodel_for_capture.sun_intensity + lightmodel_for_capture.env_exterior_capture_sun_int , 0, 0)
	else
		SetSceneParam(1, "SkyExp", lightmodel_for_capture.sky_exp + lightmodel_for_capture.env_interior_capture_sky_exp, 0, 0)
		SetSceneParam(1, "SunIntensity",  lightmodel_for_capture.sun_intensity + lightmodel_for_capture.env_interior_capture_sun_int, 0, 0)
	end
	
			
	-- hide undesired objects from environment
	local objs_to_restore = {}
	MapForEach("map", g_ClassesToHideInCubemaps or "EditorVisibleObject", function(object)
		if object:GetEnumFlags(const.efVisible) > 0 then
			table.insert(objs_to_restore, object)
			object:ClearEnumFlags(const.efVisible)
		end
	end)
	WaitNextFrame(10)
	
	HDRCubemapExportAll("Textures/Cubemaps/", self.id, site, env_capture_pos)
	WaitNextFrame(10)
	-- return hidden objects in environment if needed
	for _, object in pairs(objs_to_restore) do
		if IsValid(object) then
			object:SetEnumFlags(const.efVisible)
		end
	end
	self:SetProperty("sky_is", false)
	self:SetProperty(site:lower() .. "_envmap", self.id)
	SetSceneParam(1, "SkyExp", sky_exp, 0, 0)
	SetSceneParam(1, "SunIntensity", sun_int, 0, 0)
	WaitNextFrame(10)
	ObjModified(self)
	DoSetLightmodel(1, self, 0)
	
	if ged then
		local result = ged:Send("rfnApp", "ReloadImage", ConvertToOSPath("Textures/Cubemaps/Thumbnails/" .. self.id .. site .. ".jpg"))
		assert(not result)
	end
end

function LMCaptureThread()
	while g_LMCaptureQueue[1] do
		local lm, site, ged = table.unpack(g_LMCaptureQueue[1])
		table.remove(g_LMCaptureQueue, 1)
		lm:CaptureEnvmap(site, ged)
		print(lm.id)
	end
	g_LMCaptureThread = false
end

function AddLMCapture(lm, site, ged)
	table.insert(g_LMCaptureQueue, {lm, site, ged})
	if not g_LMCaptureThread then
		g_LMCaptureThread = CreateRealTimeThread( LMCaptureThread )
	end
end

function LightmodelPreset:CaptureExteriorEnvmap(root, prop_id, ged)
	if not self:EditorCheck(true) then return end
	AddLMCapture(self, "Exterior", ged)
end

function LightmodelPreset:CaptureInteriorEnvmap(root, prop_id, ged)
	if not self:EditorCheck(true) then return end
	AddLMCapture(self, "Interior", ged)
end

function LightmodelPreset:CaptureBothEnvmaps(root, prop_id, ged)
	if not self:EditorCheck(true) then return end
	AddLMCapture(self, "Exterior", ged)
	AddLMCapture(self, "Interior", ged)
end

function LightmodelPreset:ConvertHDRPano(site, ged)
	if not self:EditorCheck(true) or self.hdr_pano == "" then
		return
	end
	local _, base_name, _ = SplitPath(pano_path)
	HDRCubemapFromPano("Textures/Cubemaps/", base_name, site, self.hdr_pano)
	if ged then
		local result = ged:Send("rfnApp", "ReloadImage", ConvertToOSPath("Textures/Cubemaps/Thumbnails/" .. base_name .. site .. ".jpg"))
		assert(not result)
	end
end

function LightmodelPreset:ConvertExteriorEnvmap(root, prop_id, ged)
	self:ConvertHDRPano("Exterior", ged)
end

function LightmodelPreset:ConvertInteriorEnvmap(root, prop_id, ged)
	self:ConvertHDRPano("Interior", ged)
end

function LightmodelPreset:EditorCheck(print_err)
	if CurrentMap == "" then
		if print_err then
			print("Load a map to access this Lightmodel action.")
		end
		return false
	end
	return true
end

function LightmodelPreset:GetCubemapWarning()
	if not MapData[self.env_capture_map] then
		return string.format("Map for capturing cubemaps doesn't exist: %s", self.env_capture_map)
	end
end

function LightmodelPreset:GetWarning()
	local cubemap_warning = self:GetCubemapWarning()
	if cubemap_warning then
		return cubemap_warning
	end
end

function LightmodelPreset:AutoExposureOn()
	hr.AutoExposureMode = 1
	hr.EnablePostProcExposureSplit = 0
end

function LightmodelPreset:AutoExposureOff()
	hr.AutoExposureMode = 0
	hr.EnablePostProcExposureSplit = 0
end

function LightmodelPreset:AutoExposureSplit()
	hr.EnablePostProcExposureSplit = 1
end

function LightmodelPreset:AutoExposureDebugToggle()
	ToggleHR "AutoExposureDebug"
end

function LightmodelEditorTakeScreenshots(ged, obj)
	local lightmodels = obj:IsKindOf("GedMultiSelectAdapter") and obj.__objects or { obj }
	local prefix = os.date("%Y%m%d_%H%M%S_", os.time())
	local items = {}
	AsyncCreatePath("AppData/LightmodelScreenshots")
	for i, lm in ipairs(lightmodels) do
		DoSetLightmodel(1, lm, 0)
		WaitNextFrame(3)
		LockCamera("Screenshot")
		local filename = string.format("AppData/LightmodelScreenshots/%s_%s.png", prefix, lm.id)
		MovieWriteScreenshot(filename, 0, 16, false)
		items[#items+1] = ScreenshotItem:new{ display_name = lm.id, file_path = filename }
		UnlockCamera("Screenshot")
		WaitNextFrame(1)
	end
	local sdv = OpenGedApp("ScreenshotDiffViewer", items)
	for _, s in ipairs(items) do
		sdv:Send("rfnApp", "rfnSetSelectedFilePath", s.file_path, true)
	end
end