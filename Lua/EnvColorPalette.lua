AppendClass.EntitySpecProperties = {
	properties = {
		{ id = "env_colorized", name = "EnvColorized Group", editor = "combo", items = GetEnvColorizedGroups, category = "Misc", default = "", entitydata = true, },
		{ id = "default_colors", name = "Default colors", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false,  },
	},
}

local function InsertClass(class_parent_str, new_class)
	if not new_class or new_class == "" then return class_parent_str end
	if not class_parent_str or class_parent_str == "" then
		class_parent_str = new_class
	elseif not string.find(class_parent_str, "EnvColorized") then
		class_parent_str = class_parent_str .. "," .. new_class
	end
	return class_parent_str
end

function OnMsg.ClassesGenerate()
	local old_ExportEntityDataForSelf = EntitySpecProperties.ExportEntityDataForSelf
	function EntitySpecProperties:ExportEntityDataForSelf()
		local data = old_ExportEntityDataForSelf(self)
		
		if self.env_colorized and self.env_colorized ~= "" and not self:IsPropertyDefault("env_colorized") then
			data.entity.class_parent = InsertClass(data.entity.class_parent, "EnvColorized")
		end
		
		return data
	end
end

--------- Environment ------------

EnvColorizedGroups = false

local function CollectGroups()
	if not EnvColorizedGroups then
		EnvColorizedGroups = { "EnvColorized" }
		local class_list = ClassDescendantsListInclusive("EnvColorized")
		local groups = { ["EnvColorized"] = true }
		for _, class in ipairs(class_list) do
			local class_table = _G[class]
			if not groups[class_table.env_colorized] then
				groups[class_table.env_colorized] = true
				table.insert(EnvColorizedGroups, class_table.env_colorized)
			end
		end
	end
	return EnvColorizedGroups
end

function GetEnvColorizedGroups()
	local list = table.copy(CollectGroups())
	table.insert(list, 1, "")
	return list
end

function GetEnvColorizedFilters(obj, prop_meta, validate_fn)
	if validate_fn == "validate_fn" then
		-- function for preset validation, checks whether the property value is from "items"
		return "validate_fn", function(value, obj, prop_meta)
			return table.find(CollectGroups(), value) or IsKindOf(g_Classes[value], "EnvColorized")
		end
	end
	
	local list = { }
	for _, group in ipairs(CollectGroups()) do
		local text = "GROUP " .. group
		if group == "EnvColorized" then
			text = "All EnvColorized Objects"
		end
		table.insert(list, { text = text, value = group } )
	end

	local class_list = ClassDescendantsList("EnvColorized")
	for _, class in ipairs(class_list) do
		table.insert(list, { text = class, value = class } )
	end

	return list
end

DefineClass.EnvColorized = {
	__parents = {"ColorizableObject", "CObject" },

	properties = {
		{ id = "env_colorized", name = "EnvColorized Group", editor = "text", read_only = true, dont_save = true},
	},
	flags = { cfEditorCallback = true, },

	env_colorized = "EnvColorized",
}

function EnvColorized:ColorizationReadOnlyReason()
	return "Object is EnvColorized. Colorization for such objects is controlled by EnvironmentColorPalette Editor."
end

function EnvColorized:ColorizationPropsDontSave(i)
	return true
end

------------------------------ EnvironmentColorEntryBase ------------------------------
DefineClass.EnvironmentColorEntryBase = {
	__parents = {"ColorizationPropSet"},
	properties = {},
	EditorExcludeAsNested = true,
}

function EnvironmentColorEntryBase:AcceptsClass(obj_class)
	return false
end

function EnvironmentColorEntryBase:AcceptsTerrain(terrain_id)
	return false
end

function EnvironmentColorEntryBase:__eq(b)
	return rawequal(self, b)
end

------------------------------ EnvironmentColorEntry (Entity colorization) ------------------------------
DefineClass.EnvironmentColorEntry = {
	__parents = {"EnvironmentColorEntryBase"},
	properties = {
		{ id = "filter_class", editor = "choice", items = GetEnvColorizedFilters, default = "", },
		{ id = "hue_variation1", editor = "number", slider = true, min = 0, default = 0, max = 900, scale = 10, },
		{ id = "hue_variation2", editor = "number", slider = true, min = 0, default = 0, max = 900, scale = 10, },
		{ id = "hue_variation3", editor = "number", slider = true, min = 0, default = 0, max = 900, scale = 10, },
	},
	EditorExcludeAsNested = true,
}

function EnvironmentColorEntry:GetEditorView()
	local filter_name = ""
	if self.filter_class == "EnvColorized" then filter_name = "All EnvColorized Objects"
	elseif rawget(_G, self.filter_class) then filter_name = "Entity " .. self.filter_class
	else filter_name = "Group " .. self.filter_class end

	return Untranslated(filter_name .. " " .. _InternalTranslate(ColorizationPropSet.GetEditorView(self)))
end

local IsKindOf = IsKindOf
function EnvironmentColorEntry:AcceptsClass(obj_class)
	local filter_value = self.filter_class
	if not filter_value or filter_value == "" then return false end
	
	local class_table = _G[obj_class]
	if not IsKindOf(class_table, "EnvColorized") then return false end
	if filter_value == "EnvColorized" then return true end
	if filter_value == obj_class then return true end
	if filter_value == class_table.env_colorized then return true end

	return false
end

------------------------------ EnvironmentTerrainColorEntry (Terrain colorization) ------------------------------
DefineClass.EnvironmentTerrainColorEntry = {
	__parents = {"EnvironmentColorEntryBase"},
	properties = {
		{ id = "terrain_id", editor = "choice", items = PresetsCombo("TerrainObj"), default = "", },
	},
	EditorExcludeAsNested = true,
}

function EnvironmentTerrainColorEntry:GetEditorView()
	local filter_name = string.format("Terrain %s - %s", self.terrain_id,  _InternalTranslate(ColorizationPropSet.GetEditorView(self)))
	return filter_name
end

function EnvironmentTerrainColorEntry:AcceptsTerrain(terrain_id)
	return terrain_id == self.terrain_id
end

DefineClass.EnvironmentColorPalette = {
	__parents = { "Preset" },

	properties = {
		{ category = "Match (AND)", id = "regions", editor = "string_list", default = false, items = function (self) return PresetsCombo("GameStateDef", "region") end, help = "Match if current region is any of the list. Leave empty to always match."  },
		{ category = "Match (AND)", id = "lightmodels", editor = "preset_id_list",  preset_class = "LightmodelPreset", default = false, help = "Match if current lightmodel is any of the list. Leave empty to always match." },
		{ category = "Match (AND)", id = "enabled", editor = "bool", default = true, help = "Should match?" },
	},
	
	GlobalMap = "EnvironmentColorPalettes",
	ContainerClass = "EnvironmentColorEntryBase",
	HasSortKey = true,
	HasGroups = false,
	EditorCustomActions = {
		{
			FuncName = "ApplyOnCurrentMap",
			Icon = "CommonAssets/UI/Ged/play",
			Menubar = "Test",
			Name = "Apply",
			Toolbar = "main",
		},
	},
	Documentation = "Changes the color of various aspects of the environment like vegetation, terrains or rocks.",
}

function EnvironmentColorPalette:GetEditorView()
	local regions = "any"
	if self.regions and #self.regions > 0 and self.regions[1] then
		regions = table.concat(table.map(self.regions or {}, function(v) return v or "" end ), ", ")
	end
	local lightmodels = "any"
	if self.lightmodels and #self.lightmodels > 0 and self.lightmodels[1] then
		lightmodels = table.concat(table.map(self.lightmodels or {}, function(v) return v or "" end ), ", ")
	end
	
	local act_string = false
	if not self.enabled then
		act_string = "disabled"
	elseif regions == "any" and lightmodels == "any" and self.enabled then
		act_string = "always matched"
	else
		act_string = "[RG] " .. regions .. " [LM] " .. lightmodels
	end

	local preset_name = self.id
	local is_active = LastEnvColorizedCache and LastEnvColorizedCache.EnvColorSource == self.id
	if is_active then
		preset_name = "<color 89 192 98>" .. preset_name .. "</color>"
	end
	return Untranslated(preset_name .. "<color 128 128 168> - " .. act_string .. "</color>")
end

if FirstLoad then
	LastEnvColorizedCache = false
end


envpalette_print = CreatePrint{
	"envpalette",
	format = "printf",
	output = function() end,
}

function EnvironmentColorPalette:CalcEnvCache()
	local class_list = ClassDescendantsListInclusive("EnvColorized")
	local class_to_color = {}
	for _, class in ipairs(class_list) do
		class_to_color[class] = false
	end
	
	local terrain_to_color = {}
	ForEachPreset("TerrainObj", function(preset) terrain_to_color[preset.id] = false end)

	local IsKindOf = IsKindOf
	for _, child in ipairs(self) do
		for _, class in ipairs(class_list) do
			if child:AcceptsClass(class) then
				class_to_color[class] = child
			end
		end

		ForEachPreset("TerrainObj", function(preset)
			if child:AcceptsTerrain(preset.id) then
				terrain_to_color[preset.id] = child
			end
		end)
	end

	return {
		EnvColorizedToColor = class_to_color,
		TerrainToColor = terrain_to_color,
		EnvColorSource = self.id,
		EnvColorizedHash = table.hash(class_to_color),
		TerrainHash = table.hash(terrain_to_color),
	}
end

function ModifyHueByOffset(color, offset)
	if offset == 0 then return color end
	local r, g, b = GetRGB(color)
	local h, s, v = UIL.RGBtoHSV(r,g,b)
	h = h + offset
	if h < 0 then
		h = h + 256
	else
		h = h % 256
	end
	return RGB(UIL.HSVtoRGB(h, s, v))
end

local xxhash = xxhash
local MulDivRound = MulDivRound
local function ApplyToObject(class_to_color, obj)
	local palette = class_to_color[obj:GetEntity()] or class_to_color[obj.class]
	if not palette then return end
	obj:SetColorization(palette)
	local x, y = obj:GetPosXYZ()
	local seed = xxhash(x, y)
	local offset1 = palette.hue_variation1 - MulDivRound((seed >> 0 ) & 0xFF, palette.hue_variation1 * 2, 0xFF)
	local offset2 = palette.hue_variation2 - MulDivRound((seed >> 8 ) & 0xFF, palette.hue_variation2 * 2, 0xFF)
	local offset3 = palette.hue_variation3 - MulDivRound((seed >> 16) & 0xFF, palette.hue_variation3 * 2, 0xFF)
	obj:SetEditableColor1(ModifyHueByOffset(obj:GetEditableColor1(), offset1 / 10))
	obj:SetEditableColor2(ModifyHueByOffset(obj:GetEditableColor2(), offset2 / 10))
	obj:SetEditableColor3(ModifyHueByOffset(obj:GetEditableColor3(), offset3 / 10))
	return true
end

function ApplyCurrentEnvColorizedToObj(obj)
	if not LastEnvColorizedCache or not IsKindOf(obj, "EnvColorized") then
		return false
	end
	return ApplyToObject(LastEnvColorizedCache.EnvColorizedToColor, obj)
end

function EnvironmentColorPalette:ApplyOnCurrentMap(force)
	local oldEnvCache = LastEnvColorizedCache
	local envcache = self:CalcEnvCache()
	LastEnvColorizedCache = envcache

	if force or not oldEnvCache or oldEnvCache.EnvColorizedHash ~= envcache.EnvColorizedHash then
		MapForEach("map", "EnvColorized", function(obj, envcache)
			ApplyToObject(envcache.EnvColorizedToColor, obj)
		end, envcache)
	end

	if force or not oldEnvCache or oldEnvCache.TerrainHash ~= envcache.TerrainHash then
		ReloadTerrains() -- Moves terrain data form lua to C
		hr.TR_ForceReloadNoTextures = 1 -- Updates the terrain itself
	end

	ObjModified(Presets.EnvironmentColorPalette)
end

function EnvColorizedTerrainColor(terrain_obj) -- Called from C
	local color_mod = terrain_obj.color_modifier
	if LastEnvColorizedCache then
		local override_value = LastEnvColorizedCache.TerrainToColor[terrain_obj.id]
		if override_value then
			color_mod = override_value:GetEditableColor1()
		end
	end

	return color_mod
end

local ApplyCurrentEnvColorizedToObj = ApplyCurrentEnvColorizedToObj
function OnMsg.EditorCallback(id, objects, ...)
	if id == "EditorCallbackPlace" or id == "EditorCallbackPlaceCursor" or id == "EditorCallbackClone" then
		for i = 1, #objects do
			local obj = objects[i]
			ApplyCurrentEnvColorizedToObj(obj)
			for _, attach in ipairs(obj:GetAttaches()) do
				ApplyCurrentEnvColorizedToObj(attach)
			end
		end
	end
end


local ignore_lightmodels = {"SatelliteView"}
local function FindEnvColorPalette(region, lightmodel)
	for _, lm_name in ipairs(ignore_lightmodels) do
		if string.find(lightmodel, lm_name) then
			return false
		end
	end

	local best_match = false
	ForEachPreset(EnvironmentColorPalette, function(preset)
		local lm_found = not preset.lightmodels or #preset.lightmodels == 0 or table.find(preset.lightmodels, lightmodel)
		local region_found = not preset.regions or #preset.regions == 0 or table.find(preset.regions, region)
		if lm_found and region_found and preset.enabled and not best_match then
			best_match = preset
		end
	end)
	return best_match
end

function ApplyCurrentEnvironmentColorPalette(force)
	local lightmodel_id = CurrentLightmodel and CurrentLightmodel[1] and CurrentLightmodel[1].id
	local region_id = CurrentMap and CurrentMap ~= "" and MapData[CurrentMap] and MapData[CurrentMap].Region
	local envpalette = FindEnvColorPalette(region_id, lightmodel_id)
	envpalette_print("Applying palette '%s' from region '%s' and lightmodel '%s', forced '%s'. Previous '%s'",
		envpalette and envpalette.id or "none", region_id, lightmodel_id, not not force, LastEnvColorizedCache and LastEnvColorizedCache.EnvColorSource or "none")
	if envpalette then
		envpalette:ApplyOnCurrentMap(force)
		return true
	end
end

function OnMsg.LightmodelChange(view, lightmodel, time, prev_lm)
	if lightmodel then
		if not ChangingMap then
			ApplyCurrentEnvironmentColorPalette()
		end
	end
end

function OnMsg.NewMapLoaded()
	LastEnvColorizedCache = false
	ApplyCurrentEnvironmentColorPalette(true)
end