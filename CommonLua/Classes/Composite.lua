----- Composite objects with components of base class CompositeClass that can be turned on and off
--
-- create the specific classes, setting their components and properties, using the Ged editor that will appear
-- properties of all components that have template = true in their metadata are editable in the Ged editor
-- use AutoResolveMethod to defind how to combine methods present in multiple components

const.ComponentsPropCategory = "Components"

DefineClass.CompositeDef = {
	__parents = { "Preset" },
	properties = {
		{ category = "Preset", id = "object_class", name = "Object Class", editor = "choice", default = "", items = function(self) return ClassDescendantsCombo(self.ObjectBaseClass, true) end, },
		{ category = "Preset", id = "code", name = "Global Code", editor = "func", default = false, lines = 1, max_lines = 100, params = "",
			no_edit = function(self) return IsKindOf(self, "ModItem") end,
		},
	},
	
	-- Preset settings
	GeneratesClass = true,
	SingleFile = false,
	GedShowTemplateProps = true,
	
	-- CompositeDef settings
	ObjectBaseClass = false,
	ComponentClass = false,
	
	components_cache = false,
	components_sorting = false,
	properties_cache = false,
	EditorMenubarName = false,
	
	EditorViewPresetPostfix = Untranslated(" <style GedSmall><color 164 128 64><object_class></color></style>"),
	Documentation = "This is a preset that results in a composite class definition. You can look at it as a template from which objects are created.\n\nThe generated class will inherit the specified Object Class and all component classes.",
}

function CompositeDef.new(class, obj)
	local object = Preset.new(class, obj)
	object.object_class = CompositeDef.GetObjectClass(object)
	return object
end

function CompositeDef:GetObjectClass()
	return self.object_class ~= "" and self.object_class or self.ObjectBaseClass
end

function CompositeDef:GetComponents(filter)
	if not self.ComponentClass then return empty_table end

	local components_cache = self.components_cache
	if not components_cache then
		local sorting_keys = {}
		local component_class = g_Classes[self.ComponentClass]
		local blacklist = component_class.BlackListBaseClasses
		components_cache = ClassDescendantsList(self.ComponentClass, function(classname, class, base_class, base_def, sorting_keys, blacklist)
			if class:IsKindOf(base_class) or base_def:IsKindOf(classname)
				or IsKindOf(g_Classes[class.__generated_by_class or false], "CompositeDef")
				or class:IsKindOfClasses(blacklist) then
				return
			end
			if (class.ComponentSortKey or 0) ~= 0 then
				sorting_keys[classname] = class.ComponentSortKey
			end
			return true
		end, self.ObjectBaseClass, g_Classes[self.ObjectBaseClass], sorting_keys, blacklist)
		local classdef = g_Classes[self.class]
		rawset(classdef, "components_cache", components_cache)
		rawset(classdef, "components_sorting", sorting_keys)
	end
	if filter == "active" then
		return table.ifilter(components_cache, function(_, classname) return self:GetProperty(classname) end)
	elseif filter == "inactive" then
		return table.ifilter(components_cache, function(_, classname) return not self:GetProperty(classname) end)
	end
	return components_cache
end

function CompositeDef:GetProperties()
	local object_class = self:GetObjectClass()
	local object_def = g_Classes[object_class]
	assert(not object_class or object_def)
	if not object_def then
		return self.properties
	end
	
	local cache = self.properties_cache or {}
	if not cache[object_class] then
		local props, prop_data = {}, {}
		local function add_prop(prop, default, class)
			local added
			if not prop_data[prop.id] then
				added = true
				if prop.default ~= default then
					prop = table.copy(prop)
					prop.default = default
				end
				props[#props + 1] = prop
			else
				assert(prop_data[prop.id].default == default,
					string.format("Default value conflict for property '%s' in classes '%s' and '%s'", prop.id, prop_data[prop.id].class, class))
			end
			prop_data[prop.id] = { default = default, class = class }
			return added and prop or table.find_value(props, "id", prop.id)
		end
		
		for _, prop in ipairs(self.properties) do
			if prop.id ~= "code" then add_prop(prop, prop.default, self.class) end
		end
		for _, prop in ipairs(object_def.properties) do
			if prop.template then
				add_prop(prop, object_def:GetDefaultPropertyValue(prop.id), self.class)
			end
		end
		
		local components = self:GetComponents()
		for _, classname in ipairs(components) do
			local inherited = object_def:IsKindOf(classname) or false
			local help = inherited and "Inherited from the base class"
			local prop = { category = const.ComponentsPropCategory, id = classname, editor = "bool", default = inherited, read_only = inherited, help = help }
			add_prop(prop, inherited, self.class)
		end
		add_prop(table.find_value(self.properties, "id", "code"), self:GetDefaultPropertyValue("code"), self.class)
		for _, classname in ipairs(components) do
			if not object_def:IsKindOf(classname) then
				local component_def = g_Classes[classname]
				for _, prop in ipairs(component_def.properties) do
					local category = prop.category or classname
					local no_edit = prop.no_edit
					prop = table.copy(prop, "deep")
					prop.category = category
					prop = add_prop(prop, component_def:GetDefaultPropertyValue(prop.id), classname)
					local composite_owner_classes = prop.composite_owner_classes or {}
					composite_owner_classes[#composite_owner_classes + 1] = classname
					prop.composite_owner_classes = composite_owner_classes
					prop.no_edit = function(self, ...)
						if no_edit == true or type(no_edit) == "function" and no_edit(self, ...) then return true end
						local prop_meta = select(1, ...)
						for _, name in ipairs(prop_meta.composite_owner_classes or empty_table) do
							if rawget(self, name) then
								return
							end
						end
						return true
					end
				end
			end
		end
		
		-- store the cache in the class, this auto-invalidates it on Lua reload
		rawset(g_Classes[self.class], "properties_cache", cache)
		rawset(cache, object_class, props)
		return props
	end
	
	return cache[object_class]
end

function CompositeDef:SetProperty(prop_id, value)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.template and prop_meta.setter then
		return prop_meta.setter(self, value, prop_id, prop_meta)
	end
	if table.find(CompositeDef.properties, "id", prop_id) then
		return Preset.SetProperty(self, prop_id, value)
	end
	if value and table.find(self:GetComponents(), prop_id) and _G[prop_id]:HasMember("OnEditorNew") then
		_G[prop_id].OnEditorNew(self) -- OnEditorNew can initialize component property defaults of e.g. nested_obj/list component properties
	end	
	rawset(self, prop_id, value)
end

function CompositeDef:GetProperty(prop_id)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.template and prop_meta.getter then
		return prop_meta.getter(self, prop_id, prop_meta)
	end
	local value = Preset.GetProperty(self, prop_id)
	if value ~= nil then
		return value
	end
	return prop_meta and prop_meta.default
end

function CompositeDef:OnEditorSetProperty(prop_id, old_value, ged)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta and prop_meta.template and prop_meta.edited then
		return prop_meta.edited(self, old_value, prop_id, prop_meta)
	end
	return Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

function CompositeDef:__toluacode(...)
	-- clear properties of the inactive components
	local properties = self:GetProperties()
	local find = table.find
	local rawget = rawget
	for _, classname in ipairs(self:GetComponents("inactive")) do
		for _, prop in ipairs(g_Classes[classname].properties) do
			if rawget(self, prop.id) ~= nil and not find(properties, "id", prop.id) then
				self[prop.id] = nil
			end
		end
	end
	return Preset.__toluacode(self, ...)
end

-- supports generating a different class for each DLC, including property values for this DLC; see PresetDLCSplitting.lua
-- return a table with <key, file_name> pairs to generate multiple companion files, where key = dlc
function CompositeDef:GetCompanionFilesList(save_path)
	local files = { }
	for _, prop in pairs(self:GetProperties()) do
		local save_in = prop.dlc or ""
		if not files[save_in] then
			-- GetSavePath depends on self.group and self.id
			files[save_in] = self:GetCompanionFileSavePath(prop.dlc and self:GetSavePath(prop.dlc) or save_path)
		end
	end
	return files
end

function CompositeDef:GenerateCompanionFileCode(code, dlc)
	local class_exists_err = self:CheckIfIdExistsInGlobal()
	if class_exists_err then
		return class_exists_err
	end
	
	code:appendf("UndefineClass('%s')\nDefineClass.%s = {\n", self.id, self.id)
	self:GenerateParents(code)
	self:AppendGeneratedByProps(code)
	self:GenerateFlags(code)
	self:GenerateConsts(code, dlc)
	code:append("}\n\n")
	self:GenerateGlobalCode(code)
end

function CompositeDef:GenerateParents(code)
	local object_class = self:GetObjectClass()
	
	local list = self:GetComponents("active")
	if #list > 0 then
		assert(list ~= self.components_cache)
		local object_def = g_Classes[object_class]
		assert(object_def)
		if object_def then
			list = table.ifilter(list, function(_, classname) return not object_def:IsKindOf(classname) end)
		end
	end
	if #list == 0 then
		code:appendf('\t__parents = { "%s" },\n', object_class)
		return
	end
	
	if next(self.components_sorting) then
		table.insert(list, 1, object_class)
		local sorting_keys = self.components_sorting
		table.stable_sort(list, function(class1, class2)
			return (sorting_keys[class1] or 0) < (sorting_keys[class2] or 0)
		end)
		code:append('\t__parents = { "', table.concat(list, '", "'), '" },\n')
	else
		code:appendf('\t__parents = { "%s", "', object_class)
		code:append(table.concat(list, '", "'))
		code:append('" },\n')
	end
end

ClassNonInheritableMembers.composite_flags = true

function CompositeDef:GenerateFlags(code)
	local object_def = g_Classes[self:GetObjectClass()]
	assert(object_def)
	if not object_def then return end
	
	local flags = table.copy(object_def.composite_flags or empty_table)
	for _, component in ipairs(self:GetComponents("active")) do
		for flag, set in pairs(g_Classes[component].composite_flags) do
			assert(flags[flag] == nil)
			flags[flag] = set
		end
	end
	if not next(flags) then
		return
	end
	code:append('\tflags = { ')
	for flag, set in sorted_pairs(flags) do
		code:appendf("%s = %s, ", flag, set and "true" or "false")
	end
	code:append('},\n')
end

function CompositeDef:IncludePropAs(prop, dlc)
	local id = prop.id
	if Preset:GetPropertyMetadata(id) or id == "code" then
		return false
	end
	if not prop.dlc and not (dlc ~= "" and prop.dlc_override) or prop.dlc == dlc then
		return prop.maingame_prop_id or prop.id
	end
end

function CompositeDef:GenerateConsts(code, dlc)
	local props = self:GetProperties()
	code:append(#props > 0 and "\n" or "")
	local has_embedded_objects = false
	for _, prop in ipairs(props) do
		local id = prop.id
		local include_as = self:IncludePropAs(prop, dlc)
		if include_as then
			local value = rawget(self, id)
			if not self:IsDefaultPropertyValue(id, prop, value) then
				code:append("\t", include_as, " = ")
				ValueToLuaCode(value, 1, code, {} --[[ enable property injection ]])
				code:append(",\n")
			end
		end
	end
	return has_embedded_objects
end

function CompositeDef:GenerateGlobalCode(code)
	if self.code and self.code ~= "" then
		code:append("\n")
		local name, params, body = GetFuncSource(self.code)
		if type(body) == "table" then
			for _, line in ipairs(body) do
				code:append(line, "\n")
			end
		elseif type(body) == "string" then
			code:append(body)
		end
		code:append("\n")
	end
end

function CompositeDef:GetObjectClassLuaFilePath(path)
	if self.save_in == "" then
		return string.format("Lua/%s/__%s.generated.lua", self.class, self.ObjectBaseClass)
	elseif self.save_in == "Common" then
		return string.format("CommonLua/Classes/%s/__%s.generated.lua", self.class, self.ObjectBaseClass)
	elseif self.save_in:starts_with("Libs/") then -- lib
		return string.format("CommonLua/%s/%s/__%s.generated.lua", self.save_in, self.class, self.ObjectBaseClass)
	else -- save_in is a DLC name
		return string.format("svnProject/Dlc/%s/Presets/%s/__%s.generated.lua", self.save_in, self.class, self.ObjectBaseClass)
	end
end

function CompositeDef:GetWarning()
	if not g_Classes[self.id] then
		return "The class for this preset has not been generated yet.\nIt needs to be saved before it can be used or referenced from elsewhere."
	end
end

function CompositeDef:GetError()
	for _, component in ipairs(self:GetComponents()) do
		if self[component] then
			local err = g_Classes[component].GetError(self)
			if err then
				return err
			end
		end
	end
end

function OnMsg.ClassesPreprocess(classdefs)
	for name, classdef in pairs(classdefs) do
		if classdef.__parents and classdef.__parents[1] == "CompositeDef" then
			classdefs[classdef.ObjectBaseClass].__hierarchy_cache = true
		end
	end	
end

function OnMsg.ClassesBuilt()
	ClassDescendants("CompositeDef", function(class_name, class)
		if IsKindOf(class, "ModItem") then return end
		
		local objclass = class.ObjectBaseClass
		local path = class:GetObjectClassLuaFilePath()
		
		-- can't generate the file in packed builds, as we can't get Lua source for func properties
		if config.RunUnpacked and Platform.developer and not Platform.console then
			-- Map all component methods => list of components they are defined in
			local methods = {}
			for _, component in ipairs(class:GetComponents()) do
				for name, member in pairs(g_Classes[component]) do
					if type(member) == "function" and not RecursiveCallMethods[name] then
						local classlist = methods[name]
						if classlist then
							classlist[#classlist + 1] = component
						else
							methods[name] = { component }
						end
					end
				end
			end
			
			-- Generate the code for the CompositeDef's object class here
			local code = pstr(exported_files_header_warning, 16384)
			code:appendf("function __%sExtraDefinitions()\n", objclass)
			
			-- a) make GetComponents callable from the object class
			code:appendf("\t%s.components_cache = false\n", objclass)
			code:appendf("\t%s.GetComponents = %s.GetComponents\n", objclass, class_name)
			code:appendf("\t%s.ComponentClass = %s.ComponentClass\n", objclass, class_name)
			code:appendf("\t%s.ObjectBaseClass = %s.ObjectBaseClass\n\n", objclass, class_name)
			
			-- b) add default property values for ALL component properites, so accessing them is fine from the object class
			local objprops = _G[objclass].properties
			for _, prop in ipairs(class:GetProperties()) do
				if not table.find(class.properties, "id", prop.id) and not table.find(objprops, "id", prop.id) then
					code:append("\t", objclass, ".", prop.id, " = ")
					ValueToLuaCode(class:GetDefaultPropertyValue(prop.id, prop), nil, code, {} --[[ enable property injection ]])
					code:append("\n")
				end
			end
			code:append("end\n\n")
			code:appendf("function OnMsg.ClassesBuilt() __%sExtraDefinitions() end\n", objclass)
			
			-- Save the code and execute it now
			local err = SaveSVNFile(path, code, class.LocalPreset)
			if err then
				printf("Error '%s' saving %s", tostring(err), path)
				return
			end	
		end
		
		if io.exists(path) then
			dofile(path)
			_G[string.format("__%sExtraDefinitions", objclass)]()
		else
			-- saved in a DLC folder, in a pack file mounted somewhere in DlcFolders
			assert(path:starts_with("svnProject/Dlc/"))
			for _, dlc_folder in ipairs(rawget(_G, "DlcFolders")) do
				local path = string.format("%s/Presets/%s/__%s.generated.lua", dlc_folder, class_name, objclass)
				if io.exists(path) then
					dofile(path)
					_G[string.format("__%sExtraDefinitions", objclass)]()
					return
				end
			end
			assert(false, "Unable to find and execute " .. path .. " from a DLC folder.")
		end
	end)
end


----- Test/sample code below

--[[DefineClass.TestClass = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "General", id = "BaseProp1", editor = "text", default = "", translate = true, lines = 1, max_lines = 10, },
		{ category = "General", id = "BaseProp2", editor = "bool", default = true, },
	},
	Value = true,
	TestMethod = true,
}

DefineClass.TestClassComponent = {
	__parents = { "PropertyObject" }
}

DefineClass.TestClassComponent1 = {
	__parents = { "TestClassComponent" },
	properties = {
		{ id = "Component1Prop1", editor = "text", default = "", translate = true, lines = 1, max_lines = 10 },
		{ id = "Component1Prop2", editor = "bool", default = true },
	},
}

function TestClassComponent1:Value()
	return 1
end

function TestClassComponent1:TestMethod()
	return 1
end

DefineClass.TestClassComponent2 = {
	__parents = { "TestClassComponent" },
	properties = {
		{ id = "Component2Prop", editor = "number", default = 0 },
	},
}

function TestClassComponent2:Value()
	return 2
end

RecursiveCallMethods.Value = "+"
RecursiveCallMethods.TestMethod = "call"

DefineClass.TestCompositeDef = {
	__parents = { "CompositeDef" },
	
	-- composite def
	ObjectBaseClass = "TestClass",
	ComponentClass = "TestClassComponent",
	
	-- preset
	EditorMenubarName = "TestClass Composite Objects Editor",
	EditorMenubar = "Editors",
	EditorShortcut = "Ctrl-T",
	GlobalMap = "TestCompositeDefs",
}]]