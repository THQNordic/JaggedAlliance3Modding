DefineClass.SSSParameters = {
	__parents = { "PropertyObject" },
	properties = {
		{ name = "Samples", id = "SSSSamples", editor = "number", slider = true, min = 3, max = 35, step = 2, default = hr.SSSSamples },
		{ name = "Filter Width", id = "SSSFilterWidth", editor = "number", slider = true, min = 1, max = 200, scale = 100, default = hr.SSSFilterWidth },
		
		{ name = "Strength Red", id = "SSSStrengthR", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = hr.SSSStrengthR },
		{ name = "Strength Green", id = "SSSStrengthG", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = hr.SSSStrengthG },
		{ name = "Strength Blue", id = "SSSStrengthB", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = hr.SSSStrengthB },
		
		{ name = "Falloff Red", id = "SSSFalloffR", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = hr.SSSFalloffR },
		{ name = "Falloff Green", id = "SSSFalloffG", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = hr.SSSFalloffG },
		{ name = "Falloff Blue", id = "SSSFalloffB", editor = "number", slider = true, min = 0, max = 1000, scale = 1000, default = hr.SSSFalloffB },
    },
	
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "SSS Profile",
}

function SSSParameters:OnEditorSetProperty(prop_id, old_value, ged)
    hr[prop_id] = self[prop_id]
end

function RotateLightAroundObject(light, obj)
	CreateMapRealTimeThread(function()
		while(true) do
			local rotated = RotateAroundCenter(obj:GetPos(), light:GetPos(), 100)
			light:SetPos(rotated)
			Sleep(50)
		end
	end)
end

function OpenSSSParametersEditor()
	OpenGedApp("GedPropertyObject", SSSParameters:new())
end



DefineClass.ObjectMarkingParameters = {
	__parents = { "Preset" },
	properties = {
		{ id = "Group", editor = false },
		{ id = "ScanlineActiveTime", name = "Scanline Active Time", editor = "number", slider = true, min = 1, max = 10 * 1000, default = 1000 },
		{ id = "ScanlineInactiveTime", name = "Scanline Inctive Time", editor = "number", slider = true, min = 1, max = 10 * 1000, default = 1000 },
		{ id = "ScanlineHeight", name = "Scanline Height", editor = "number", slider = true, min = 1, max = 2 * guim, default = MulDivRound(guim, 4, 100) },
		{ id = "GrainStrength", name = "Grain Strength", editor = "number", slider = true, min = 0, max = 100, default = 50 },
	},
	
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Object Marking",
}

for i = 0, const.MaxObjectMarkingIDs - 1 or -1 do
	local propertyCategory = string.format("ID: %d", i)
	
	table.iappend(ObjectMarkingParameters.properties, {
		{
			id = string.format("color_%d", i),
			category = propertyCategory,
			name = "Color",
			editor = "color", default = RGBA(128, 128, 128, 128),
		},
		{
			id = string.format("interlaced_color_%d", i),
			category = propertyCategory,
			name = "Interlaced Color",
			editor = "color", default = RGBA(128, 128, 128, 128),
		},
		{
			id = string.format("rim_light_color_%d", i),
			category = propertyCategory,
			name = "Rim Light Color",
			editor = "color", default = RGBA(128, 128, 128, 128),
		},
		{
			id = string.format("scanline_color_%d", i),
			category = propertyCategory,
			name = "Scanline Color",
			editor = "color", default = RGBA(128, 128, 128, 255),
		},
	})
end

local function SetupObjectMarkingParameters(params)
	local paramsPerID = {}
	for i = 0, const.MaxObjectMarkingIDs - 1 or -1 do
		paramsPerID[i] = {
			color = params[string.format("color_%d", i)],
			interlaced_color = params[string.format("interlaced_color_%d", i)],
			rim_light_color = params[string.format("rim_light_color_%d", i)],
			scanline_color = params[string.format("scanline_color_%d", i)]
		}
	end
	SetObjectMarkingParams(params.ScanlineActiveTime, params.ScanlineInactiveTime, params.ScanlineHeight, params.GrainStrength, paramsPerID)
end

function ObjectMarkingParameters:OnEditorSetProperty(prop_id, old_value, ged)
	SetupObjectMarkingParameters(self)
end

function OnMsg.DataLoaded()
	local preset = Presets.ObjectMarkingParameters and Presets.ObjectMarkingParameters.Default and Presets.ObjectMarkingParameters.Default[1]
	if preset then
		SetupObjectMarkingParameters(preset)
	end
end



DefineClass.ContourOuterParameters = {
	__parents = { "Preset" },
	properties = {
		{ id = "Group", editor = false },
	},
	
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Contour Outer",
}

local properties = {
	{
		id = "color",
		name = "Color",
		editor = "color", default = RGBA(128, 128, 128, 128),
	},
	{
		id = "size",
		name = "Pixel Width",
		editor = "number", min = 0, max = 100, default = 2,
		slider = true,
	},
	{
		id = "overlay",
		name = "Overlay Blending",
		editor = "bool", default = false,
	},
	{
		id = "period",
		name = "Period",
		editor = "number", default = 0, scale = 1000,
	},
	{
		id = "curvepow",
		name = "CurvePow",
		editor = "number", default = 0, scale = 1000,
	},
}

for i = 1, const.MaxContourOuterIDs or 0 do
	local propertyCategory = string.format("ID: %d", i)
	
	for _, prop in ipairs(properties) do
		local prop_copy = table.copy(prop)
		prop_copy.id = string.format("%s_%d", prop_copy.id, i)
		prop_copy.category = propertyCategory
		table.insert(ContourOuterParameters.properties, prop_copy)
	end
end

local function SetupContourOuterParameters(params)
	local paramsPerID = {
		[0] = { size = 0, color = RGBA(0, 0, 0, 0), overlay = false, period = 0, curvepow = 0 }
	}
	for i = 1, const.MaxContourOuterIDs or 0 do
		paramsPerID[i] = {}
		for _, prop in ipairs(properties) do
			paramsPerID[i][prop.id] = params[string.format("%s_%d", prop.id, i)]
		end
	end
	SetContourOuterIDParams(paramsPerID)
end

function ContourOuterParameters:OnEditorSetProperty(prop_id, old_value, ged)
	SetupContourOuterParameters(self)
end

function OnMsg.DataLoaded()
	local preset = Presets.ContourOuterParameters and Presets.ContourOuterParameters.Default and Presets.ContourOuterParameters.Default[1]
	if preset then
		SetupContourOuterParameters(preset)
	end
end



DefineClass.ContourInnerParameters = {
	__parents = { "Preset" },
	properties = {
		{ id = "Group", editor = false },
		{ id = "filler_color", name = "Filler", editor = "color", default = RGBA(100, 100, 100, 30), },
		{ id = "contour_color", name = "Contour", editor = "color", default = RGBA(100, 100, 100, 200), },
		
		{ id = "effect_strength", name = "Effect Strength", editor = "number", slider = true, min = 0, max = 255, default = 128, },		
		{ id = "interlacing_strength", name = "Interlacing Strength", editor = "number", slider = true, min = 0, max = 255, default = 128, },
		{ id = "grain_strength", name = "Grain Strength", editor = "number", slider = true, min = 0, max = 255, default = 128, },
		
		{ id = "aberration_shift", name = "Chromatic Aberration Shift", editor = "number", slider = true, min = 0, max = 20, default = 4, },
		{ id = "aberration_strength", name = "Chromatic Aberration Strength", editor = "number", slider = true, min = 0, max = 255, default = 128, },
	},
	
	EditorMenubar = "Editors.Art",
	EditorMenubarName = "Contour Inner",
}

local function SetupContourInnerParameters(params)
	hr.ContourInnerFillerColor = params.filler_color
	hr.ContourInnerContourColor = params.contour_color
	hr.ContourInnerGrainAndAberration = RGBA(
		params.grain_strength,
		params.aberration_shift,
		params.aberration_strength,
		0
	)
	hr.ContourInnerMisc = RGBA(
		params.effect_strength,
		params.interlacing_strength,
		0, 0
	)
end

function ContourInnerParameters:OnEditorSetProperty(prop_id, old_value, ged)
	SetupContourInnerParameters(self)
end

function OnMsg.DataLoaded()
	local preset = Presets.ContourInnerParameters and Presets.ContourInnerParameters.Default and Presets.ContourInnerParameters.Default[1]
	if preset then
		SetupContourInnerParameters(preset)
	end
end


DefineClass.PersistedRenderVars = {
	__parents = { "Preset" },
	properties = {
		{ id = "Group", editor = false },
		{ id = "Active", editor = "bool", help = "Is this the currently active instance of the current PersistedRenderVar group?", default = false, }
	},
	EditorViewPresetPostfix = Untranslated("<select(Active,'',' [active]')>"),
	EditorMenubar = "Editors.Engine",
	EditorMenubarName = "Render vars",
	PresetClass = "PersistedRenderVars",
	group = "PersistedRenderVars",
}

function PersistedRenderVars:GetGroup()
	return self.class
end

function PersistedRenderVars:CopyHRVars()
	for _, prop in ipairs(self.properties) do
		if prop.hr == true then
			hr[prop.id] = self:GetProperty(prop.id)
		elseif type(prop.hr) == "string" then
			hr[prop.hr] = self:GetProperty(prop.id)
		end
	end
end

function PersistedRenderVars:Apply()
	self:CopyHRVars()
end

function PersistedRenderVars:OnEditorSetProperty(prop_id, old_value, ged)
	self:Apply()
end

function PersistedRenderVars:GetActiveInstance()
	local group_list = Presets.PersistedRenderVars
	if not group_list then return false end
	local relevant_group = group_list[self.group]
	if not relevant_group then return false end
	for idx, preset in ipairs(relevant_group) do
		if preset.Active then
			return preset
		end
	end
	return relevant_group[1]
end

function PersistedRenderVars:GetById(id, use_any_group)
	local group_list = Presets.PersistedRenderVars
	if not group_list then return false end
	local relevant_group = group_list[self.group]
	if relevant_group then
		local found = relevant_group[id]
		if found then return found end
	end

	if use_any_group then
		for _, group in ipairs(group_list) do
			if group[id] then
				return group[id]
			end
		end
	end
end

function PersistedRenderVars:SetActive(value)
	local old_value = self.Active
	local active_preset = self:GetActiveInstance()

	self.Active = value
	if value ~= old_value then
		if value and active_preset ~= self and active_preset then
			active_preset.Active = false
		end
		if not value then
			active_preset = self:GetActiveInstance()
			if active_preset then
				active_preset.Active = true
			end
		end
	end
end

function PersistedRenderVars:GetActive()
	return self.Active
end

function OnMsg.DataLoaded()
	local classes = ClassLeafDescendantsList("PersistedRenderVars")
	for _, class_name in ipairs(classes) do
		local class = _G[class_name]
		local preset = class:GetActiveInstance()
		if not preset then
			preset = class:new({})
			preset:Register()
			preset:SetId(preset:GenerateUniquePresetId("New" .. class_name))
		end
		preset:SetActive(true)
		preset:Apply()
	end
end

function ColorGradingLUTColorSpaceItems()
	local items = {}
	for item=1,const.ColorSpaceCount do
		items[item] = {
			text = GetColorSpaceName(item - 1),
			value = item - 1
		}
	end
	return items
end

function ColorGradingLUTColorGammaItems()
	local items = {}
	for item=1,const.ColorGammaCount do
		items[item] = {
			text = GetColorGammaName(item - 1),
			value = item - 1
		}
	end
	return items
end

DefineClass.CommonPersistedRenderVars = {
	__parents = {"PersistedRenderVars"},
	group = "CommonPersistedRenderVars",
	properties = {
		{ hr = true, id = "TerrainDistortedMinNormalRange", editor = "number", slider = true, min = 0, max = 10000, scale = 1000, default = 100 },
		{ hr = true, id = "TerrainDistortedMaxNormalRange", editor = "number", slider = true, min = 0, max = 20000, scale = 1000, default = 10 * 1000 },
				
		{ hr = true, id = "ColorGradingLUTSize", editor = "dropdownlist", items = { 16, 32, 64 }, default = hr.ColorGradingLUTSize },
		{ hr = true, id = "ColorGradingLUTColorSpace", editor = "dropdownlist", items = ColorGradingLUTColorSpaceItems, default = hr.ColorGradingLUTColorSpace },
		{ hr = true, id = "ColorGradingLUTColorGamma", editor = "dropdownlist", items = ColorGradingLUTColorGammaItems, default = hr.ColorGradingLUTColorGamma },
		-- feel free to insert any other misc/common engine hr vars
	},
}

function ToggleHR( param )
	if hr[param] == nil then return end
	if hr[param] == 0 then 
		hr[param] = 1 
	else 
		hr[param] = 0 
	end
	return hr[param] == 1
end