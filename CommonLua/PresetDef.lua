function PresetClassesCombo(base_class, filter, param1, param2)
	return function (obj)
		return ClassDescendantsList(base_class or "Preset", filter, obj, param1, param2)
	end
end

DefineClass.PresetDef = {
	__parents = { "ClassDef" },
	properties = {
		{ category = "Misc", id = "DefGlobalMap", name = "GlobalMap", editor = "text", default = "", },
		{ category = "Misc", id = "DefHasGroups", name = "Organize in groups", editor = "bool", default = Preset.HasGroups, },
		{ category = "Misc", id = "DefPresetGroupPreset", name = "Groups preset class", editor = "choice", default = false, items = PresetClassesCombo(), },
		{ category = "Misc", id = "DefHasSortKey", name = "Has SortKey", editor = "bool", default = Preset.HasSortKey, },
		{ category = "Misc", id = "DefHasParameters", name = "Has parameters", editor = "bool", default = Preset.HasParameters, },
		{ category = "Misc", id = "DefHasCompanionFile", name = "Has companion file", editor = "bool", default = Preset.HasCompanionFile, },
		{ category = "Misc", id = "DefHasObsolete", name = "Has Obsolete", editor = "bool", default = Preset.HasObsolete, },
		{ category = "Misc", id = "DefSingleFile", name = "Store in single file", editor = "bool", default = Preset.SingleFile, },
		{ category = "Misc", id = "DefPropertyTranslation", name = "Translate property names", editor = "bool", default = Preset.PropertyTranslation, },
		{ category = "Misc", id = "DefPresetClass", name = "Preset base class", editor = "choice", default = false, items = PresetClassesCombo(), },
		{ category = "Misc", id = "DefContainerClass", name = "Container sub-items class", editor = "text", default = "", },
		{ category = "Misc", id = "DefPersistAsReference", name = "Persist as reference", editor = "bool", default = true, help = "When true preset instances will only be referenced by savegames, if false used preset instance data will be saved."},
		{ category = "Misc", id = "DefModItem", name = "Define ModItem", editor = "bool", default = false, },
		{ category = "Misc", id = "DefModItemName", name = "ModItem name", editor = "text", default = "", no_edit = function(self) return not self.DefModItem end, },
		{ category = "Misc", id = "DefModItemSubmenu", name = "ModItem submenu", editor = "text", default = "Other", no_edit = function(self) return not self.DefModItem end, },
		{ category = "Editor", id = "DefGedEditor", name = "Editor class", editor = "text", default = Preset.GedEditor, },
		{ category = "Editor", id = "DefEditorName", name = "Editor menu name", editor = "text", default = "", },
		{ category = "Editor", id = "DefEditorShortcut", name = "Editor shortcut", editor = "shortcut", default = Preset.EditorShortcut, },
		{ category = "Editor", id = "DefEditorIcon", name = "Editor icon", editor = "text", default = Preset.EditorIcon, },
		{ category = "Editor", id = "DefEditorMenubar", name = "Editor menu", editor = "combo", default = "Editors", items = ClassValuesCombo("Preset", "EditorMenubar"), },
		{ category = "Editor", id = "DefEditorMenubarSortKey", name = "Editor SortKey", editor = "text", default = "" },
		{ category = "Editor", id = "DefFilterClass", name = "Filter class", editor = "combo", items = ClassDescendantsCombo("GedFilter"), default = "", },
		{ category = "Editor", id = "DefSubItemFilterClass", name = "Subitems filter class", editor = "combo", items = ClassDescendantsCombo("GedFilter"), default = "", },
		{ category = "Editor", id = "DefAltFormat", name = "Alternative format string", editor = "text", default = "", },
		{ category = "Editor", id = "DefEditorCustomActions", name = "Custom editor actions", editor = "nested_list", default = false, base_class = "EditorCustomActionDef", inclusive = true },
		{ category = "Editor", id = "DefTODOItems", name = "TODO items", editor = "string_list", default = false, },
	},
	group = "PresetDefs",
	DefParentClassList = { "Preset" },
	GlobalMap = "PresetDefs",
	EditorViewPresetPrefix = "<color 75 105 198>[Preset]</color> ",
}

function PresetDef:GenerateConsts(code)
	self:AppendConst(code, "HasGroups")
	self:AppendConst(code, "PresetGroupPreset", "")
	self:AppendConst(code, "HasSortKey")
	self:AppendConst(code, "HasParameters")
	self:AppendConst(code, "HasCompanionFile")
	self:AppendConst(code, "HasObsolete")
	self:AppendConst(code, "SingleFile")
	self:AppendConst(code, "PropertyTranslation")
	self:AppendConst(code, "GlobalMap", "")
	self:AppendConst(code, "PresetClass", "")
	self:AppendConst(code, "ContainerClass")
	self:AppendConst(code, "PersistAsReference")
	self:AppendConst(code, "GedEditor")
	self:AppendConst(code, "EditorMenubarName", false, "DefEditorName")
	self:AppendConst(code, "EditorShortcut")
	self:AppendConst(code, "EditorIcon")
	self:AppendConst(code, "EditorMenubar")
	self:AppendConst(code, "EditorMenubarSortKey")
	self:AppendConst(code, "FilterClass", "")
	self:AppendConst(code, "SubItemFilterClass", "")
	self:AppendConst(code, "AltFormat", "")
	self:AppendConst(code, "TODOItems")
	
	if self.DefEditorCustomActions and #self.DefEditorCustomActions > 0 then
		local result = {}
		for idx, action in ipairs(self.DefEditorCustomActions) do
			if action.Name ~= "" then
				local action_copy = table.raw_copy(action)
				table.insert(result, action_copy)
			end
		end
		code:append("\tEditorCustomActions = ")
		code:appendv(result)
		code:append(",\n")
	end
	ClassDef.GenerateConsts(self, code)
end

function PresetDef:GenerateMethods(code)
	if self.DefModItem then
		code:appendf('DefineModItemPreset("%s", { EditorName = "%s", EditorSubmenu = "%s" })\n\n', self.id, self.DefModItemName, self.DefModItemSubmenu)
	end
	ClassDef.GenerateMethods(self, code)
end

function PresetDef:GetError()
	if self.DefModItem and (self.DefModItemName or "") == "" then
		return "ModItem name must be specified."
	end
	return ClassDef.GetError(self)
end


----- ClassAsGroupPresetDef

DefineClass.ClassAsGroupPresetDef = {
	__parents = { "PresetDef", },
	properties = {
		{ category = "Preset", id = "GroupPresetClass", name = "Preset group class", editor = "choice", default = false, 
			items = PresetClassesCombo("Preset", function(class_name, class) return class.PresetClass == class_name end), 
			help = "Only Presets with .PresetClass == <class_name> are listed here"},
		{ id = "DefHasGroups", editor = false },
		{ id = "DefGedEditor", editor = false },
		{ id = "DefEditorName", editor = false },
		{ id = "DefEditorShortcut", editor = false },
		{ id = "DefEditorIcon", editor = false },
		{ id = "DefEditorMenubar", editor = false },
		{ id = "DefEditorMenubarSortKey", editor = false },
		{ id = "DefFilterClass", editor = false },
		{ id = "DefSubItemFilterClass", editor = false },
		{ id = "DefEditorCustomActions", editor = false },
		{ id = "DefTODOItems", editor = false },
		{ id = "DefPresetClass", editor = false },
	},
	EditorViewPresetPrefix = Untranslated("<color 75 105 198>[<def(GroupPresetClass,'GroupPreset')>]</color> "),
}

function ClassAsGroupPresetDef:Init()
	self.DefParentClassList = rawget(self, "DefParentClassList") or self.GroupPresetClass and { self.GroupPresetClass } or nil
end

function ClassAsGroupPresetDef:GetDefaultPropertyValue(id, prop_meta)
	if id == "DefParentClassList" then
		return { self.GroupPresetClass }
	end
	return PresetDef.GetDefaultPropertyValue(self, id, prop_meta)
end

function ClassAsGroupPresetDef:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "GroupPresetClass" then
		table.remove_entry(self.DefParentClassList, old_value)
		self.DefParentClassList = rawget(self, "DefParentClassList") or {}
		for _, class_name in ipairs(self.DefParentClassList) do
			local class = g_Classes[class_name]
			if class and class.__ancestors[self.GroupPresetClass] then
				return
			end
		end
		table.insert(self.DefParentClassList, 1, self.GroupPresetClass)
	end
	return PresetDef.OnEditorSetProperty(self, prop_id, old_value, ged)
end

function ClassAsGroupPresetDef:GenerateConsts(code)
	PresetDef.GenerateConsts(self, code)
	code:appendf("\tgroup = \"%s\",\n", self.id)
end


----- EditorCustomActionDef

DefineClass.EditorCustomActionDef = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Name", editor = "text", default = "", },
		{ id = "Rollover", editor = "text", default = "", },
		{ id = "FuncName", editor = "text", default = "", },
		{ id = "IsToggledFuncName", editor = "text", default = "" },
		{ id = "Toolbar", editor = "text", default = "", },
		{ id = "Menubar", editor = "text", default = "", },
		{ id = "SortKey", editor = "text", default = "", },
		{ id = "Shortcut", editor = "shortcut", default = "", },
		{ id = "Icon", editor = "ui_image", default = "CommonAssets/UI/Ged/cog.tga" },
	},
	EditorView = Untranslated("<Name><opt(u(Shortcut),' - ','')>"),
}


----- DCLPropertiesDef

local blacklist = {
	ClassDef = true, FXPreset = true, XTemplate = true, AnimMetadata = true,
	SoundPreset = true, SoundTypePreset = true, ReverbDef = true, NoisePreset = true,
}

DefineClass.DLCPropertiesDef = {
	__parents = { "ClassDef" },
	properties = {
		{ id = "SaveIn", name = "Add properties in DLC", editor = "choice", default = "", 
			items = function(obj) return obj:GetPresetSaveLocations() end, },
		{ id = "add_to_preset", name = "In preset class", editor = "choice", default = "",
			-- try to list only game-specific presets
			items = ClassDescendantsCombo("Preset", false, function(name, preset)
				local class = preset.PresetClass or preset.class
				return preset.class == class and next(Presets[class]) and Presets[class][1][1].save_in == "" and not blacklist[class]
			end)
		},
		{ id = "DefParentClassList", editor = false, },
		{ id = "DefPropertyTranslation", editor = false, },
		{ id = "DefStoreAsTable", editor = false, },
		{ id = "DefPropertyTabs", editor = false, },
		{ id = "DefUndefineClass", editor = false, },
	},
}

function DLCPropertiesDef:GetObjectClass()
	local preset_class = g_Classes[self.add_to_preset]
	local is_composite = preset_class:IsKindOf("CompositeDef")
	return is_composite and preset_class.ObjectBaseClass or self.add_to_preset, is_composite
end

function DLCPropertiesDef:GeneratePropExtraCode(prop_def)
	local object_class, is_composite = self:GetObjectClass()
	local override_prop = object_class and g_Classes[object_class]:GetPropertyMetadata(prop_def.id)
	assert(not override_prop or override_prop.dlc_override or override_prop.dlc == self.save_in)
	local template_str = is_composite and "template = true, " or ""
	return override_prop and not override_prop.dlc and
		string.format('%sdlc = "%s", maingame_prop_id = "%s", id = "%s%sDLC"', template_str, self.save_in, prop_def.id, prop_def.id, self.save_in) or
		string.format('%sdlc = "%s"', template_str, self.save_in)
end

function DLCPropertiesDef:GenerateGlobalCode(code)
	ClassDef.GenerateGlobalCode(self, code)
	code:appendf('DefineDLCProperties("%s", "%s", "%s", "%s")\n\n',
		self:GetObjectClass(), self.add_to_preset, self.save_in, self.id)
end

local hintColor = RGB(210, 255, 210)
function DLCPropertiesDef:GetError()
	if self.save_in == "" then
		return { "Specify the DLC to add the properties of this class to.", hintColor }
	elseif self.add_to_preset == "" then
		return { "Add the properties to which preset?\n\nIn case of composite objects, specify the CompositDef preset; properties will be added to its ObjectBaseClass.", hintColor }
	end
end
