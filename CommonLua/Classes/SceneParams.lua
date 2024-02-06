if FirstLoad then 
	g_DynamicSceneParams = {}
end

temp_default_table = {__index = {}}
function RegisterSceneParam(type, default_value)
	local name = type.id
	assert(name)
	if not name then return end
	type.default_value = default_value or type.default
	if not getmetatable(type) then
		type = setmetatable(type, temp_default_table)
	end

	local old_param = g_DynamicSceneParams[name]
	g_DynamicSceneParams[name] = type
	
	if old_param then
		table.remove_value(g_DynamicSceneParams, old_param)
	end
	table.insert(g_DynamicSceneParams, type)

	if type.define_param and (not old_param or (old_param.type ~= type.type and old_param.elements ~= old_param.elements)) then
		EngineDefineSceneParam(type, default_value)
	end
end

function SetSceneParamEx(view, param, ...)
	if type(param) == "string" then
		param = g_DynamicSceneParams[param]
	end

	assert(param)
	if not param then return end
	EngineSetSceneParamEx(view, param, ...)
end  

DefineClass.SceneParamDef = {
	__parents = {"Preset"},
	properties = {
		{ id = "type", editor = "choice", items = {"float", "int", "uint"}, default = "float", category = "SceneParam", },
		{ id = "elements", editor = "number", min = 1, max = 2048, default = 1, category = "SceneParam", },
		{ id = "define_param", editor = "bool", default = true, category = "SceneParam", help = "Should we define the SP in the engine?" },
		{ id = "scale", editor = "number", min = 1, max = 10000, default = 1000, category = "LuaProperty", },
		{ id = "prop_id", editor = "text", default = "", category = "LuaProperty", },
		{ id = "prop_name", editor = "text", default = "", category = "LuaProperty", },
		{ id = "prop_category", editor = "text", default = "", category = "LuaProperty", },
		{ id = "prop_type", editor = "choice", items = {"number", "color", "point", "number_list"}, default = "number", category = "LuaProperty", },
		{ id = "has_min_max", editor = "bool", default = false, category = "LuaProperty", },
		{ id = "prop_min", editor = "number", default = 0, scale = function(self) return self.scale end, category = "LuaProperty", },
		{ id = "prop_max", editor = "number", default = 0, scale = function(self) return self.scale end, category = "LuaProperty", },
		{
			id = "default_value",
			scale = function(self) return self.scale end,
			editor = function(self) return self.prop_type end,
			default = 0,
			category = "LuaProperty",
		},
	},
	EditorView = Untranslated("<color 0 128 0><prop_type></color> <id> <color 0 128 0><ValueText><color 128 128 128><opt(u(save_in), ' - ', '')>"),
	EditorMenubarName = "Scene params",
	EditorMenubar = "Editors.Engine",
}

for key, prop in ipairs(SceneParamDef.properties) do
	temp_default_table.__index[prop.id] = prop.default or SceneParamDef[prop.id]
end

function SceneParamDef:Setprop_type(type)
	self.prop_type = type
	self.default_value = self:GetDefaultValueOf(type)
end

function SceneParamDef:GetDefaultValueOf(prop_type)
	if prop_type == "number" then
		return 0
	elseif prop_type == "color" then
		return RGB(255, 255, 255)
	elseif prop_type == "point" then
		return point()
	elseif prop_type == "number_list" then
		return {}
	end
	assert(false)
end

function SceneParamDef:GetValueText()
	local t = self.prop_type
	if t == "number" then
		return FormatNumberProp(tonumber(self.default_value) or 0, self.scale)
	elseif t == "number_list" then
		return table.concat(self.default_value, ", ")
	elseif t == "color" then
		return string.format("%d %d %d %d", GetRGBA(self.default_value))
	end
	return "???"
end

function SceneParamDef:GetSavePath(save_in)
	local folder = self:GetSaveFolder(save_in)
	return folder .. "/__SceneParamDef.lua"
end

function SceneParamDef:GetSaveData(file_path, presets, code_pstr)
	local code = code_pstr or pstr(exported_files_header_warning, 16384)
	local props = SceneParamDef:GetProperties()
	for idx, preset in ipairs(presets) do
		code:append("DefineSceneParam")
		TableToLuaCode(preset, nil, code)
		code:append("\n")
	end
	return code
end

function LoadSceneParams()
	LoadPresets("CommonLua/Data/__SceneParamDef.lua")
	ForEachLib("Data/__SceneParamDef.lua", function (lib, path)
		LoadPresets(path)
	end)
	LoadPresets("Data/__SceneParamDef.lua")
	for _, dlc_folder in ipairs(DlcFolders or empty_table) do
		LoadPresets(dlc_folder .. "/Code/__SceneParamDef.lua")
	end
end

local old_root = Presets.SceneParamDef
Presets.SceneParamDef = {}
local groups = Presets.SceneParamDef
local default_group = Preset.group
function DefineSceneParam(obj)
	obj = setmetatable(obj, temp_default_table)
	
	local obj_id = obj.id or ""
	local obj_group = obj.group or default_group
	assert(obj.group ~= "")
	local group = groups[obj_group]
	if group then
		group[#group + 1] = obj
		group[obj_id] = obj
	else
		group = { obj }
		group[obj_id] = obj
		
		groups[obj_group] = group
		groups[#groups + 1] = group
	end
	
	RegisterSceneParam(obj, obj.default_value)
	g_PresetLastSavePaths[obj] = PresetsLoadingFileName
end

local function FixSceneParamsMetatables()
	ForEachPresetExtended("SceneParamDef", function(preset, group, SceneParamDef)
		setmetatable(preset, SceneParamDef)
	end, SceneParamDef)
	
	SceneParamDef:SortPresets()
	GedRebindRoot(old_root, Presets.SceneParamDef)
end

LoadSceneParams()

function RegisterSceneParamDefs()
	ForEachPreset(SceneParamDef, function(preset)
		RegisterSceneParam(preset, preset.default_value)
	end)
end

function OnMsg.ClassesBuilt()
	FixSceneParamsMetatables()
	RegisterSceneParamDefs()
end


DefineClass.LightmodelSceneParams = {
	__parents = { "LightmodelPart" },
	lightmodel_feature = "gamespec",
	lightmodel_category = "GameSpecific",
	properties = {},
}

function LightmodelSceneParams:GetLightmodelProperties(properties)
	properties = properties or {}
	for _, param in ipairs(g_DynamicSceneParams) do
		if param.prop_id ~= false then
	
			local editor = "number"
			if param.elements > 1 then
				editor = "number_list"
			end
			if param.prop_type == "color" then
				assert(param.elements >= 3 and param.elements <= 4)
				assert(param.type == "float")
				editor = "color"
			end
			
			table.insert(properties, {
				feature = "gamespec",
				category = param.prop_category or "Misc",
				editor = editor,
				id = param.prop_id ~= "" and param.prop_id or param.id,
				name = param.prop_name ~= "" and param.prop_name or param.prop_id ~= "" and param.prop_id or param.id,
				default = param.default_value or false,
				scale = param.scale,
				min = param.has_min_max and param.prop_min or false,
				max = param.has_min_max and param.prop_max or false,
				slider = param.prop_min and param.prop_max and param.prop_min ~= param.prop_max,
			})
			assert(properties[#properties].id)
		end
	end
	return properties
end
	
function OnMsg.LightmodelSetSceneParams(view, lm_buf, time, start_offset)
	for _, param in ipairs(g_DynamicSceneParams) do
		if param.prop_id ~= false then
			local prop_id = param.prop_id ~= "" and param.prop_id or param.id
			local value = lm_buf[prop_id]
			assert(value ~= nil)
			SetSceneParamEx(view, param, value, time, start_offset)
		end
	end
end