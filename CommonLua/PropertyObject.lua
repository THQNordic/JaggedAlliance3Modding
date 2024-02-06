RecursiveCallMethods.GetError = "or"
RecursiveCallMethods.GetWarning = "or"

-- these properties are tables - :Clone copies them via table.copy
TableProperties = {
	range = true,
	set = true,
	prop_table = true,
	objects = true,
	number_list = true,
	string_list = true,
	preset_id_list = true,
	T_list = true,
	point_list = true,
}

-- these properties don't store a value
PlaceholderProperties = {
	help = true,
	documentation = true,
	buttons = true,
	linked_presets = true,
}

-- these properties sometimes point at "parent", not "child" tables, and shouldn't be visited in recursive descents
MembersReferencingParents = {
	mod = true, -- ModItem keeps a .mod member to the parent ModDef
	env = true, -- ModDef keeps a .env which contains the current ModDef
	own_mod = true, -- in ModDependency
	container = true, -- ContinuousEffect.container
	__index = true,
	__mod = true, -- ModOptionsObject
}

DefineClass.PropertyObject = {
	__parents = {},
	__hierarchy_cache = true,
	properties = {},

	GedTreeChildren = false,
	GedEditor = false,
	EditorView = Untranslated("<class>"),
	Documentation = false, -- collapsible documentation to show in Ged on the place of the property with editor = "documentation"
	PropertyTranslation = false,
	StoreAsTable = false, -- use 'true' for much faster loading, however it doesn't call property setters
	GetPropertyForSave = false, -- use to override values while saving (or return nil to skip a property); works with StoreAsTable == false only!
}

function ChangeClassPropertyMeta(class, prop_id, field, value)
	assert(type(class) == "table")
	if type(class) == "table" then
		local prop_meta = table.find_value(class.properties, "id", prop_id)
		if prop_meta then
			prop_meta[field] = value
		end
	end
end

function PropertyObject.new(class, obj)
	return setmetatable(obj or {}, class)
end

function PropertyObject:delete()
end

function PropertyObject:ResolveValue(id)
	local value = self:GetProperty(id)
	if value ~= nil then return value end
	return rawget(self, id)
end

local function member_assert(self, key)
	if type(key) ~= "number" and not self:HasMember(key) then
		assert(false, self.class .. "." .. key .. " assignment - object should not have dynamic members", 2)
	end
end

function PropertyObject.__newindex(self, key, value)
	dbg(value ~= nil and member_assert(self, key))
	rawset(self, key, value)
end

function PropertyObject:EditorContext()
	return
end

function PropertyObject:OpenEditor()
	if self.GedEditor then
		return OpenGedApp(self.GedEditor, self, self:EditorContext())
	end
end

PropertyObject.IsReadOnly = empty_func -- Ged will not allow editing of objects for which this returns 'true'

-- Override to report a warning (for Ged) for any missing properties / data inconsistencies
-- tables with extra parameters are supported { warning_text, warning_color, underline_subitemidx1, underline_subitemidx2, ... }
PropertyObject.GetWarning = empty_func
PropertyObject.GetError = empty_func

function eval_items(items, obj, prop_meta)
	local validate_fn
	while type(items) == "function" do
		local ok
		ok, items, validate_fn = procall(items, obj, prop_meta, "validate_fn")
		if not ok then return "err" end
	end
	return items, validate_fn
end

function PropertyObject:ValidateProperty(prop_meta, value, verbose, indent)
	local prop_eval = prop_eval
	local find = table.find
	local no_edit = prop_eval(prop_meta.no_edit, self, prop_meta)
	local no_validate = prop_eval(prop_meta.no_validate, self, prop_meta)
	if no_edit or no_validate then return false end
	
	local editor = prop_eval(prop_meta.editor, self, prop_meta)
	if editor == "text" then
		if Platform.developer and value and value ~= "" then
			local isT = IsT(value)
			local translate = prop_eval(prop_meta.translate, self, prop_meta)
			if not translate and IsT(value) then
				return string.format("Translated string '%s' set for a non-translated property.", TDevModeGetEnglishText(value))
			elseif translate then
				if not IsT(value) then
					return string.format("Untranslated string '%s' set for a translated property.", value)
				elseif config.RunUnpacked then
					local text = TDevModeGetEnglishText(value)
					if type(text) == "string" then
						local err = XTextCompileText(text)
						if err then return err end
						if text ~= ReplaceNonStandardCharacters(text) then
							return "Non-standard quotes, etc. in text, please run FixupPresetTs."
						end
					end
				end
			end
		end
	elseif editor == "preset_id" then
		if value and value ~= "" and value ~= prop_meta.extra_item and not PresetIdPropFindInstance(self, prop_meta, value) then
			return string.format("Missing preset '%s'.", value)
		end
	elseif editor == "preset_id_list" then
		for _, preset_id in ipairs(value or empty_table) do
			local extracted_preset_id = preset_id
			if prop_meta.weights then
				local value_key = prop_meta.value_key or "value"
				extracted_preset_id = preset_id[value_key]
			end
			if extracted_preset_id and extracted_preset_id ~= "" and extracted_preset_id ~= prop_meta.extra_item and not PresetIdPropFindInstance(self, prop_meta, extracted_preset_id) then
				return string.format("Missing preset '%s'.", extracted_preset_id)
			end
		end
	elseif editor == "number" then
		if type(value) == "number" then
			local min = prop_eval(prop_meta.min, self, prop_meta)
			local max = prop_eval(prop_meta.max, self, prop_meta)
			if min or max then
				if min and value < min then
					return "Value < min"
				end
				if max and value > max then
					return "Value > max"
				end
			end
		end
	elseif editor == "choice" or editor == "dropdownlist" or editor == "set" then
		local arbitrary_value = prop_eval(prop_meta.arbitrary_value, self, prop_meta)
		if arbitrary_value or not value or not prop_meta.items then return false end
		
		local items, validate_fn = eval_items(prop_meta.items, self, prop_meta)
		if not validate_fn then
			if not items then
				return "prop_meta.items is empty."
			elseif items == "err" then
				return "prop_meta.items has crashed."
			end
		end
		
		local table_values = items and type(items[1]) == "table"
		if editor == "set" then
			for key in pairs(value) do
				if validate_fn then
					if not validate_fn(key, self, prop_meta) then
						return string.format("Value %s not found in items.", key)
					end
				elseif not table_values then
					if not find(items, key) then
						return string.format("Value %s not found in items.", key)
					end
				elseif not find(items, "value", key) and not find(items, "id", key) then
					return string.format("Value %s not found in items.", key)
				end
			end
			return
		end
		
		if validate_fn then
			return not validate_fn(value, self, prop_meta) and "Current value is not in items" or nil
		elseif not table_values then
			if not find(items, value) then
				return string.format("Current value '%s' is not in items.", tostring(value))
			end
		elseif not find(items, "value", value) and not find(items, "id", value) then
			return "Current value is not in items."
		end
	elseif editor == "string_list" then
		local arbitrary_value = prop_eval(prop_meta.arbitrary_value, self, prop_meta)
		if arbitrary_value or not value or not prop_meta.items then return false end

		local items, validate_fn = eval_items(prop_meta.items, self, prop_meta)
		if not validate_fn then
			if not items then
				return "prop_meta.items is empty."
			elseif items == "err" then
				return "prop_meta.items has crashed."
			end
		end
		
		for _, subvalue in ipairs(value) do
			if subvalue then
				local extracted_subvalue = subvalue
				if prop_meta.weights then
					local value_key = prop_meta.value_key or "value"
					extracted_subvalue = subvalue[value_key]
				end
				if validate_fn then
					if not validate_fn(extracted_subvalue, self, prop_meta) then
						return string.format("Value '%s' is not in items.", extracted_subvalue)
					end
				elseif type(items[1]) ~= "table" then
					if not find(items, extracted_subvalue) then
						return string.format("Value '%s' is not in items.", extracted_subvalue)
					end
				else
					if not find(items, "value", extracted_subvalue) and not find(items, "id", value)  then
						return string.format("Value '%s' is not in items.", extracted_subvalue)
					end
				end
			end
		end
	elseif editor == "func" or editor == "expression" then
		local storage = UncompilableFuncPropsSources[self]
		if storage and storage[prop_meta.id] then
			return "The code doesn't compile. Lua code can't be saved until it is correct."
		end
		if value == missing_source_func then
			return "Missing function code."
		end
	elseif editor == "nested_obj" and value then
		local qualifier = "Nested obj '%s'"
		if not IsKindOf(value, "PropertyObject") then
			return "Invalid value type.", qualifier
		end
		return GetDiagnosticMessage(value, verbose, indent), qualifier
	elseif editor == "nested_list" then
		for i, obj in ipairs(value) do
			local qualifier = string.format("Nested list '%%s'[%d]", i)
			if obj and not IsKindOf(obj, "PropertyObject") then
				return "Invalid value type.", qualifier
			end
			local warn = obj and GetDiagnosticMessage(obj, verbose, indent)
			if warn then
				return warn, qualifier
			end
		end
	elseif editor == "script" and value then
		local qualifier = "Script '%s'"
		if not IsKindOf(value, "PropertyObject") then
			return "Invalid value type.", qualifier
		end
		local prop_params = prop_eval(prop_meta.params, self, prop_meta, "self")
		if prop_params ~= value.Params then
			return string.format("Script parameters mismatch - current '%s', expected '%s'.", value.Params, prop_params), qualifier
		end
		local warn = GetDiagnosticMessage(value, verbose, indent)
		if warn then
			return warn, qualifier
		end
		if value.eval then
			local code, has_upvalues = value:GenerateCode()
			local name, params, body, first, last, srclines = GetFuncSource(value.eval, has_upvalues and "no_cache")
			if type(body) == "string" then body = { body } end
			if has_upvalues then
				if not first then return "Can't find source code for script eval function." end
				-- find enclosing function that returns the eval function
				for i = first, 1, -1 do
					local line = srclines[i]
					if line:find("(function()", 1, true) then break end
					table.insert(body, 1, line)
				end
				table.insert(body, "end")
			end
			body = table.concat(body, "\n")
			if body:gsub("\t", "") ~= code:gsub("\t", "") then
				return string.format("Script compiled function is stale - please resave.\n%s\n%s", body, code), qualifier
			end
		end
	elseif editor == "ui_image" and value and value ~= "" and not self:IsDefaultPropertyValue(prop_meta.id, prop_meta, value) then
		if type(value) ~= "string" then
			return "Image path must be a string."
		end
		
		local extension = prop_meta.force_extension
		if extension and not value:ends_with(extension) then
			return string.format("Image file %s is expected to be with extention '%s'.", value, extension)
		end
		
		local mod_def = TryGetModDefFromObj(self)
		local preset = GetParentTableOfKindNoCheck(self, "Preset")
		local save_location = preset and preset:GetSaveLocationType() or "game"
		
		local dir, name, ext = SplitPath(value)
		local path_in_common = value:starts_with("CommonAssets/UI/")
		local os_path = prop_eval(prop_meta.os_path, self, prop_meta)
		if mod_def or Platform.goldmaster then
			local path = dir .. name
			local found_path = io.exists(path .. ".png") or io.exists(path .. ".tga") or io.exists(path .. ".dds") or io.exists(path .. ".jpg")

			if not found_path then
				return string.format("Image file %s missing.", value)
			end
		elseif save_location == "common" or path_in_common or os_path then
			if not os_path and not path_in_common then
				return "Image paths referenced from CommonLua presets must be in CommonAssets/UI/"
			end
			local path = dir .. name
			if not io.exists(path .. ".png") and not io.exists(path .. ".tga") and not io.exists(path .. ".dds") then
				return string.format("Image file %s missing.", path)
			end
		elseif save_location == "game" then
			local path = "svnAssets/Source/" .. dir .. name .. ".png" -- in the source art (images are picked in the browse popup from there)
			if not io.exists(path) then
				return string.format("Image file %s missing at %s", value, path)
			end
		end
	end
	return false
end

local nested_obj_warn = { "One or more nested objects have warnings!", "warning" }
local nested_obj_err = { "One or more nested objects have errors!", "error" }
local subitem_warn = { "One or more subitems have warnings!", "warning" }
local subitem_err = { "One or more subitems have errors!", "error" }

local IsKindOf = IsKindOf

-- this function should be used to get the diagnostic message; it's replaced in PropertyObjectWarningsCache.lua
function GetDiagnosticMessage(obj, ...) return obj:GetDiagnosticMessage(...) end

local function process_msg(self, warn, verbose, indent, qualifier, prop, value, editor)
	if not warn then return end
	if type(warn) ~= "table" then
		warn = { warn, "error" }
	end
	
	local generic_warn, generic_err
	if editor == "nested_obj" or editor == "nested_list" then
		generic_warn, generic_err = nested_obj_warn, nested_obj_err
	elseif qualifier and qualifier:starts_with("Subitem") then
		generic_warn, generic_err = subitem_warn, subitem_err
	end
	
	if verbose or not generic_warn then
		local prop_name = ""
		if prop then
			local name = prop_eval(prop.name, self, prop)
			if IsT(name) then name = GedTranslate(name) end
			prop_name = name and name ~= "" and name or prop.id
		end
		return {
			string.format((qualifier or "Property '%s'") .. " of type '%s':\n%s%s", prop_name,
				warn[1] ~= "Invalid value type." and editor or type(value) == "table" and value.class or type(value),
				indent, warn[1]),
			warn[2]
		}
	else
		return warn[2] == "warning" and generic_warn or generic_err
	end
end

function PropertyObject:GetDiagnosticMessage(verbose, indent)
	local ok, current_error = procall(self.GetError, self)
	if not ok then
		return { string.format("'%s' GetError has crashed.", self.class), "error" }
	elseif current_error then
		if type(current_error) == "table" then
			if current_error[#current_error] ~= "error" then
				table.insert(current_error, "error")
			end
			return current_error
		end
		return { current_error, "error" }
	end
	
	local ok, current_warning = procall(self.GetWarning, self)
	if not ok then
		return { string.format("'%s' GetWarning has crashed.", self.class), "error" }
	elseif current_warning then
		if type(current_warning) == "table" then
			if current_warning[#current_warning] ~= "warning" then
				table.insert(current_warning, "warning")
			end
			return current_warning
		end
		return { current_warning, "warning" }
	end
	
	indent = verbose and ((indent or "") .. "\t") or " "
	
	local ok, properties = procall(self.GetProperties, self)
	if not ok or not properties then
		return "GetProperties has crashed."
	end
	
	local GetProperty = self.GetProperty
	for _, prop in ipairs(properties) do
		local ok, value = procall(GetProperty, self, prop.id)
		if not ok then
			return process_msg(self, "Getter has crashed.", verbose, indent, nil, prop, nil, prop.editor)
		end
		if value ~= Undefined() then
			local warn, qualifier = self:ValidateProperty(prop, value, verbose, indent)
			if warn then
				return process_msg(self, warn, verbose, indent, qualifier, prop, value, prop.editor)
			end
		end
	end
	
	for i, subitem in ipairs(self) do
		local warn = IsKindOf(subitem, "PropertyObject") and GetDiagnosticMessage(subitem, verbose, indent)
		if warn then
			local message = process_msg(self, warn, verbose, indent, string.format("Subitem #%d%%s", i), nil, subitem)
			if message then return message end
		end
	end
end

function PropertyObject:FindSubObjectParentList(subobj)
	if subobj == self then return {} end

	for _, prop_meta in ipairs(self:GetProperties()) do
		local editor = prop_meta.editor
		if editor == "nested_obj" or editor == "script" then
			local obj = self:GetProperty(prop_meta.id)
			if obj then
				local list = obj:FindSubObjectParentList(subobj, self)
				if list then
					table.insert(list, 1, self)
					return list
				end
			end
		elseif editor == "nested_list" then
			local value = self:GetProperty(prop_meta.id)
			for _, obj in ipairs(value or empty_table) do
				local list = obj:FindSubObjectParentList(subobj, self)
				if list then
					table.insert(list, 1, self)
					return list
				end
			end
		end
	end
	for _, obj in ipairs(self) do
		local list = obj:FindSubObjectParentList(subobj, self)
		if list then
			table.insert(list, 1, self)
			return list
		end
	end
end

function PropertyObject:FindSubObjectLocation(obj)
	local info = self:ForEachSubObject(function(subobj, parents, key, obj)
		if subobj == obj then
			return { parents[#parents], key }
		end
	end, obj)
	if not info then return end
	return info[1], info[2]
end

function PropertyObject:ForEachSubObject(class, func, ...)
	if type(class) == "function" then
		return self:ForEachSubObject(false, class, func, ...)
	end
	
	local function traverse(self, class, func, parents, key, ...)
		if not class or IsKindOf(self, class) then
			local res = func(self, parents, key, ...)
			if res ~= nil then
				return res
			end
		end
		if not IsKindOf(self, "PropertyObject") then return end
		table.insert(parents, self)
		for _, prop_meta in ipairs(self:GetProperties()) do
			local editor = prop_meta.editor
			if editor == "nested_obj" or editor == "script" then
				local obj = self:GetProperty(prop_meta.id)
				if obj then
					local res = traverse(obj, class, func, parents, prop_meta.id, ...)
					if res ~= nil then
						return res
					end
				end
			elseif editor == "nested_list" then
				local value = self:GetProperty(prop_meta.id)
				for _, obj in ipairs(value or empty_table) do
					local res = traverse(obj, class, func, parents, prop_meta.id, ...)
					if res ~= nil then
						return res
					end
				end
			end
		end
		for i, obj in ipairs(self) do
			if type(obj) == "table" then
				local res = traverse(obj, class, func, parents, i, ...)
				if res ~= nil then
					return res
				end
			end
		end
		table.remove(parents)
	end

	return traverse(self, class, func, {}, false, ...)
end

function IsKindOfClasses(object, class, ...)
	if not object or not class then
		return false
	elseif type(class) == "table" then
		for i = 1, #class do
			if IsKindOf(object, class[i]) then
				return true
			end
		end
		return false
	elseif IsKindOf(object, class) then
		return true
	end
	return IsKindOfClasses(object, ...)
end

PropertyObject.IsKindOf = IsKindOf
PropertyObject.IsKindOfClasses = IsKindOfClasses

setmetatable(PropertyGetMethod, {
	__index = function (table, name)
		local method = "Get" .. tostring(name)
		table[name] = method
		return method
	end
})

setmetatable(PropertySetMethod, {
	__index = function (table, name)
		local method = "Set" .. tostring(name)
		table[name] = method
		return method
	end
})

PropertyObject.GetProperty = PropObjGetProperty
PropertyObject.SetProperty = PropObjSetProperty
PropertyObject.HasMember = PropObjHasMember

local g_Classes = g_Classes
local FuncProps = {
	["func"] = true,
	["expression"] = true,
	["script"] = true,
}
function PropertyObject:GetDefaultPropertyValue(prop, prop_meta)
	local default = g_Classes[self.class][prop]
	if default ~= nil then
		return default
	end
	prop_meta = prop_meta or self:GetPropertyMetadata(prop)
	if prop_meta then
		default = prop_meta.default
		if not FuncProps[prop_meta.editor] then
			while type(default) == "function" do
				default = default(self) or false
			end
		end
		return default
	end
end

function PropertyObject:PrepareForEditing()
	-- table properties with defaults coming from the class need to be copied in order to be edited
	for _, prop_meta in ipairs(self:GetProperties()) do
		local prop_id = prop_meta.id
		if not prop_eval(prop_meta.read_only, self, prop_meta) then
			local value = self:GetProperty(prop_id)
			if type(value) == "table" and value == self:GetDefaultPropertyValue(prop_id, prop_meta) then
				local clone = self:ClonePropertyValue(value, prop_meta)
				if clone ~= value then
					self:SetProperty(prop_id, clone)
				end
			end
		end
	end
end

function PropertyObject:IsPropertyDefault(prop, prop_meta)
	return self:IsDefaultPropertyValue(prop, prop_meta, self:GetProperty(prop))
end

function PropertyObject:IsDefaultPropertyValue(prop, prop_meta, value)
	prop_meta = prop_meta or self:GetPropertyMetadata(prop)
	local default_value = self:GetDefaultPropertyValue(prop, prop_meta)
	return value == nil or value == default_value or
		type(value) == "table" and type(default_value) == "table" and table.hash(value) == table.hash(default_value)
end

function PropertyObject:GetRandomPropertyValue(prop, prop_meta, seed)
	prop_meta = prop_meta or self:GetPropertyMetadata(prop)
	seed = seed or AsyncRand()
	local items = prop_meta.items
	if type(items) == "function" then items = items(self) end
	if type(items) == "table" and #items > 0 then
		local value
		local random_chances = prop_meta.random_chances
		if random_chances then
			local sum = 0
			for i = 1, #items do
				sum = sum + (random_chances[items[i]] or 100)
			end
			local r = 1 + BraidRandom(seed, sum)
			sum = 0
			for i = 1, #items do
				value = items[i]
				sum = sum + (random_chances[value] or 100)
				if sum >= r then
					break
				end
			end
		else
			value = items[1 + BraidRandom(seed, #items)]
		end
		if type(value) == "table" and value.value ~= nil then
			return value.value
		end
		return value
	end
	
	if prop_meta.editor == "color" then
		if prop_meta.pallete and #prop_meta.pallete > 0 then
			return prop_meta.pallete[1 + BraidRandom(seed, #prop_meta.pallete)]
		end
		if prop_meta.color and prop_meta.variation then
			return GenerateColor(prop_meta.color, prop_meta.variation)
		end
	elseif prop_meta.editor == "number" then
		local min = prop_meta.min or 0
		local max = prop_meta.max or 100
		return ValidateNumberPropValue(min + BraidRandom(seed, max - min + 1), prop_meta)
	elseif prop_meta.editor == "bool" then
		return BraidRandom(seed, 1000000) < 500000
	end
end

function PropertyObject:RandomizeProperties(seed)
	seed = seed or AsyncRand()
	local props = self:GetProperties()
	for i = 1, #props do
		local prop_meta = props[i]
		if prop_meta.randomize then
			local value = self:GetRandomPropertyValue(prop_meta.id, prop_meta, xxhash(seed, prop_meta.id))
			if value ~= nil then
				self:SetProperty(prop_meta.id, value)
			end
		end
	end
end

function PropertyObject:GetPropertyMetadata(property_id)
	return table.find_value(self:GetProperties(), "id", property_id)
end

function PropertyObject:GetProperties()
	return self.properties
end

function PropertyObject:SetProperties(props)
	local all_props = self:GetProperties()
	for i = 1, #all_props do
		local id = all_props[i].id
		local value = props[id]
		if value ~= nil then
			self:SetProperty(id, value)
		end
	end
end

function PropertyObject:ClonePropertyValue(value, prop_meta)
	local editor = prop_meta.editor
	if value then
		if editor == "nested_obj" or editor == "script" then
			return value:Clone()
		elseif editor == "nested_list" then
			local ok, new_value = procall(table.imap, value, function(obj) return obj:Clone() end)
			if not ok then return {} end
			return new_value
		elseif TableProperties[editor] then
			return table.copy(value)
		elseif editor == "property_array" then
			value = GedDynamicProps:Instance(self, value, prop_meta)
			return value:Clone()
		end
	end
	return value
end

function PropertyObject:CopyProperties(source, properties)
	properties = properties or self:GetProperties()
	for i = 1, #properties do
		local prop_meta = properties[i]
		if not prop_eval(prop_meta.dont_save, source, prop_meta) then
			local prop_id = prop_meta.id
			local value = source:GetProperty(prop_id)
			if not self:IsDefaultPropertyValue(prop_id, prop_meta, value) then
				self:SetProperty(prop_id, self:ClonePropertyValue(value, prop_meta))
			end
		end
	end
end

function PropertyObject:Clone(class, ...)
	class = class or self.class
	local obj = g_Classes[class]:new(...)
	obj:CopyProperties(self)
	return obj
end

function CloneObject(obj)
	if obj then
		return obj:Clone()
	end
end

function CopyPropertiesBlacklisted(src, dest, blacklist)
	local props
	if blacklist and #blacklist > 0 then
		props = table.icopy(src:GetProperties())
		for _, id in ipairs(blacklist) do
			table.remove_entry(props, "id", id)
		end
	end
	dest:CopyProperties(src, props)
end

function PropertyObject:__enum()
	local keys, key = {}
	local t = self
	repeat
		key = next(t, key)
		if key ~= nil then
			if keys[key] == nil then
				keys[key] = t[key]
			end
		else
			t = getmetatable(t)
			if t then t = t.__index end
		end
	until type(t) ~= "table"
	return next, keys, nil
end

function PropGetter(prop_name)
	return function(self)
		return self:GetProperty(prop_name)
	end
end

function PropChecker(prop_id, prop_value, neg)
	if prop_value == nil then
		prop_value = false
	end
	return function(self)
		if neg then
			return prop_value ~= self:GetProperty(prop_id)
		else
			return prop_value == self:GetProperty(prop_id)
		end
	end
end

function PropertyObject.ReplacePropertyMeta(class, prop_id, new_meta)
	local class_properties = class.properties
	local idx = table.find(class_properties, "id", prop_id)
	assert(idx ~= nil)
	class_properties[idx] = new_meta
end

-- flatten all property lists, so that GetProperties is an O(1) operation
function OnMsg.ClassesPreprocess(classdefs)
	local HasMember = ClassdefHasMember
	local props
	local function ResolveProperties(class_name, props_to_idx, ancestors)
		local classdef = classdefs[class_name]
		props_to_idx = props_to_idx or {}
		ancestors = ancestors or {}
		if not classdef or ancestors[class_name] then
			return props
		end
		ancestors[class_name] = true
		
		local parents = classdef.__parents or {}
		for i = 1, #parents do
			ResolveProperties(parents[i], props_to_idx, ancestors)
		end
		
		local class_properties = classdef.properties
		if class_properties then
			props = props or {}
			for i = 1, #class_properties do
				local prop = class_properties[i]
				local id = prop.id
				local idx = props_to_idx[id]
				
				if not idx then
					idx = #props + 1
					props_to_idx[id] = idx
				end
				props[idx] = prop
			end
		end
	end

	-- if a property has no accessors, it is accessed by 'object[prop.id]'
	-- report conflicts between the property default and the property value in the classdef (if it exists)
	-- define the member that holds the property value for properties without accessors (if not explicitly defined)
	ProcessClassdefChildren("PropertyObject", function(classdef, class_name)
		local existing_props = {}
		for _, prop_meta in ipairs(classdef.properties or empty_table) do
			local prop_id = prop_meta.id
			if existing_props[prop_id] then
				printf("Duplicate property %s.%s", class_name, prop_id)
			end
			existing_props[prop_id] = prop_id
			if not HasMember(classdef, "Get" .. prop_id) or not HasMember(classdef, "Set" .. prop_id) then
				local default = prop_meta.default
				if not FuncProps[prop_meta.editor] then
					while type(default) == "function" do
						default = default(classdef) or false
					end
				end	
				if classdef[prop_id] ~= nil and default ~= nil then
					printf("%s.%s has default value both as a class member, and in the property definition", class_name, prop_id)
					if classdef[prop_id] ~= default then
						-- report conflict
						printf("Also, the values are different: class default is \"%s\" and property default is \"%s\"",
							tostring(classdef[prop_id]),
							tostring(default))
					end
				elseif default ~= nil then
					classdef[prop_id] = default -- define property member
					if prop_meta.modifiable and prop_meta.editor == "number" then
						classdef["base_" .. prop_id] = default
					end
				elseif prop_meta.editor and not PlaceholderProperties[prop_meta.editor] and not HasMember(classdef, prop_id) then
					printf("%s.%s must have either Get/Set accessors, or a default value", class_name, prop_id)
				end
			end
		end
	end)
	
	-- apply class-wide property metadata defaults
	for name, classdef in pairs(classdefs) do
		props = classdef.properties or empty_table
		for id, value in pairs(props) do
			if type(id) == "string" then
				for _, prop_meta in ipairs(props) do
					if prop_meta[id] == nil then
						prop_meta[id] = value
					end
				end
			end
		end
	end
	
	local remove = table.remove
	for name, classdef in pairs(classdefs) do
		if classdef.properties or #(classdef.__parents or empty_table) > 1 then
			props = nil
			ResolveProperties(name)
			if props then
				-- remove properties without editor. editor=false is the way to remove parent properties in child classes that don't want them
				for i = #props, 1, -1 do
					if not props[i].editor then
						remove(props, i)
					end
				end
				classdef.__properties = props
			end
		end
	end
	
	-- apply flattened properties
	for name, classdef in pairs(classdefs) do
		classdef.properties = classdef.__properties
		classdef.__properties = nil
	end
end

-- support for instancing classes during Lua loading, when the class system is not present yet
-- the object tables are created, and they are made into class instances in-place, on the ClassesPostprocess message
local delayed_place_objs = {}

function PlaceObj(class_name, tbl, arr, ...)
	local class = g_Classes[class_name]
	if not class then
		if not delayed_place_objs then
			assert(false, "Trying to place non-existent class " .. class_name)
			return
		elseif tbl and type(tbl[1]) == "string" or arr then -- StoreAsTable == false
			arr = arr or {}
			arr.class = class_name
			arr.__props__ = tbl
			table.insert(delayed_place_objs, arr)
			return arr
		else -- StoreAsTable == true
			tbl = tbl or {}
			tbl.class = class_name
			table.insert(delayed_place_objs, tbl)
			return tbl
		end
	end
	return class:__fromluacode(tbl, arr, ...)
end

function OnMsg.ClassesPostprocess() -- WARNING: Can't be OnMsg.ClassesBuilt, e.g. for DefineModifiableClassTemplates
	local objs, classes = delayed_place_objs, g_Classes
	delayed_place_objs = nil
	for _, obj in ipairs(objs) do
		local class_def = classes[obj.class]
		assert(class_def, "Trying to place non-existent class " .. obj.class)
		if obj.__props__ then
			local props = obj.__props__
			obj.__props__ = nil
			class_def:new(obj)
			SetObjPropertyList(obj, props)
		else
			class_def:new(obj)
		end
		obj.class = nil
	end
end

local SetObjPropertyList = SetObjPropertyList
function PropertyObject:__fromluacode(table, arr)
	if self.StoreAsTable then
		assert(not table or type(table[1]) ~= "string", "Object was saved with StoreAsTable == false")
		return self:new(table)
	end

	local obj = self:new(arr)
	SetObjPropertyList(obj, table)
	return obj
end

local prop_eval = prop_eval
local copy = table.copy
local list_props = { set = true, T_list = true, nested_list = true, preset_id_list = true, string_list = true, number_list = true, point_list = true }

function PropertyObject:ShouldCleanPropForSave(id, prop_meta, value)
	return
		prop_eval(prop_meta.dont_save, self, prop_meta) or -- property with dont_save == true
		self:IsDefaultPropertyValue(id, prop_meta, value) or -- default value
		list_props[prop_meta.editor] and next(self:GetDefaultPropertyValue(id, prop_meta)) == nil and next(value) == nil -- {} or false for a list/set property
end

function PropertyObject:CleanupForSave(injected_props, restore_data)
	restore_data = restore_data or {}
	
	-- gather properties
	local props_by_id = {}
	for _, prop_meta in ipairs(injected_props) do
		props_by_id[prop_meta.id] = prop_meta
	end
	for _, prop_meta in ipairs(self:GetProperties()) do
		local id = prop_meta.id
		props_by_id[id] = prop_meta
		if injected_props and prop_eval(prop_meta.inject_in_subobjects, self, prop_meta) then
			injected_props[#injected_props + 1] = prop_meta
		end
	end
	
	-- perform cleanup
	local class = getmetatable(self)
	for key, value in pairs(self) do
		local prop_meta = props_by_id[key]
		if prop_meta then
			if self:ShouldCleanPropForSave(key, prop_meta, value) then
				-- cleanup members corresponding to properties that shouldn't be saved; these are restored afterwards
				restore_data[#restore_data + 1] = { obj = self, key = key, value = value }
				self[key] = nil
			end
			
			-- call recursively for nested objects
			local editor = prop_meta.editor
			if (editor == "nested_obj" or editor == "script") and IsKindOf(value, "PropertyObject") then
				value:CleanupForSave(injected_props, restore_data)
			elseif editor == "nested_list" then
				for _, obj in ipairs(value or empty_table) do
					obj:CleanupForSave(injected_props, restore_data)
				end
			end
		elseif type(key) == "number" then
			if IsKindOf(value, "PropertyObject") then
				value:CleanupForSave(injected_props, restore_data)
			end
		elseif injected_props and not class:HasMember(key) then
			restore_data[#restore_data + 1] = { obj = self, key = key, value = value }
			self[key] = nil
		end
	end
	
	return restore_data
end

function PropertyObject:RestoreAfterSave(restore_data)
	for _, data in ipairs(restore_data) do
		data.obj[data.key] = data.value
	end
end

function PropertyObject:__toluacode(indent, pstr, GetPropFunc, injected_props)
	self:GenerateLocalizationContext(self)
	
	if self.StoreAsTable then
		assert(not GetPropFunc)
		local restore_data = self:CleanupForSave(injected_props)
		if not pstr then
			local ret = string.format("PlaceObj('%s', %s)", self.class, TableToLuaCode(self, indent))
			self:RestoreAfterSave(restore_data)
			return ret
		end
		pstr:appendf("PlaceObj('%s', ", self.class)
		pstr:appendt(self, indent, false, injected_props)
		pstr:append(")")
		self:RestoreAfterSave(restore_data)
		return pstr
	end
	
	if not pstr then
		local props = ObjPropertyListToLuaCode(self, indent, GetPropFunc or self.GetPropertyForSave, nil, nil, injected_props)
		local arr = ArrayToLuaCode(self, indent, injected_props)
		if arr then
			return string.format("PlaceObj('%s', %s, %s)", self.class, props or "nil", arr)
		else
			return string.format("PlaceObj('%s', %s)", self.class, props or "nil")
		end
	else
		pstr:appendf("PlaceObj('%s', ", self.class)
		if not ObjPropertyListToLuaCode(self, indent, GetPropFunc or self.GetPropertyForSave, pstr, nil, injected_props) then
			pstr:append("nil")
		end
		local len0 = #pstr
		if #self > 0 then
			pstr:append(", ")
			if not ArrayToLuaCode(self, indent, pstr, injected_props) then
				pstr:resize(len0)
			end
		end
		return pstr:append(")")
	end
end

function PropertyObject:CreateInstance(instance)
	local meta = self.__index == self and self or { __index = self }
	instance = setmetatable(instance or {}, meta)
	instance.Instance = true
	return instance
end

function PropertyObject:LocalizationContextBase()
end

function PropertyObject:GenerateLocalizationContext(obj, visited, base)
	base = base or self:LocalizationContextBase()
	if not base then return end

	visited = visited or {}
	for key, value in pairs(obj) do
		if not MembersReferencingParents[key] then
			if value ~= "" and IsT(value) then
				if not ContextCache[value] then
					local prop_meta = ObjectClass(obj) and obj:GetPropertyMetadata(key)
					local context = prop_meta and prop_meta.context or ""
					if type(context) == "function" then
						context = context(obj, prop_meta, self)
					end
					ContextCache[value] = string.concat(" ", base, key, context ~= "" and context)
				end
			elseif type(value) == "table" and not visited[value] then
				visited[value] = true
				self:GenerateLocalizationContext(value, visited, base)
			end
		end
	end
end

local loc_id_cache = setmetatable({}, weak_keys_meta)
function PropertyObject:UpdateLocalizedProperty(prop_id, translate)
	local text = rawget(self, prop_id)
	if text and text ~= "" then
		if translate and type(text) == "string" then
			local id = loc_id_cache[self]
			self[prop_id] = id and T{id, text} or T{text}
		elseif not translate and IsT(text) then
			loc_id_cache[self] = TGetID(text) or nil
			self[prop_id] = TDevModeGetEnglishText(text)
		end
	end
end

local PropertyObjectHash
local table_hash
local IsKindOf = IsKindOf
local xxhash = xxhash
local tostring = tostring

local function ValueHash(value, injected_props, processed)
	local value_type = type(value)
	if value_type == "table" then
		if IsKindOf(value, "PropertyObject") then
			return PropertyObjectHash(value, injected_props, processed)
		else
			return table_hash(value, injected_props, processed)
		end
	elseif value_type == "function" then
		return xxhash(tostring(value))
	elseif value_type ~= "thread" then
		return xxhash(value)
	end
end

table_hash = function(table, injected_props, processed)
	local hash
	if next(table) then
		local key_hash, value_hash
		for key, value in sorted_pairs(table) do
			key_hash = ValueHash(key, injected_props, processed)
			value_hash = ValueHash(value, injected_props, processed)
			hash = xxhash(hash, key_hash, value_hash)
		end
	end
	return hash
end

PropertyObjectHash = function(obj, injected_props, processed)
	-- prevent stack overflow in the case of circular references
	processed = processed or {}
	if processed[obj] then
		return 1
	end
	processed[obj] = true
	
	local hash = 13482575171670380201
	local properties = obj:GetProperties()
	local prop_count = #properties
	for i = 1, prop_count + (injected_props and #injected_props or 0) do
		local property = i > prop_count and injected_props[i - prop_count] or properties[i]
		if property.editor then
			local value = obj:GetProperty(property.id)
			if not obj:ShouldCleanPropForSave(property.id, property, value) then -- will skip props with dont_save
				local subhash = ValueHash(value, injected_props, processed)
				hash = xxhash(hash, property.id, subhash)
			end
			if injected_props and i <= prop_count and prop_eval(property.inject_in_subobjects, obj, property) then
				table.insert_unique(injected_props, property)
			end
		end
	end
	if obj.StoreAsTable then
		-- array part
		for _, value in ipairs(obj) do
			local obj_hash = IsKindOf(value, "GedEditedObject") and value:EditorData().current_hash -- reuse calculated hash
			hash = xxhash(hash, obj_hash or ValueHash(value, injected_props, processed))
		end
	else
		for _, value in ipairs(obj) do
			if IsKindOf(value, "PropertyObject") then
				local obj_hash = IsKindOf(value, "GedEditedObject") and value:EditorData().current_hash -- reuse calculated hash
				hash = xxhash(hash, obj_hash or PropertyObjectHash(value, injected_props, processed))
			end
		end
	end
	return hash
end

-- function that calculates the hash of a PropertyObject's value - but only the part of it that gets persisted
function PropertyObject:CalculatePersistHash()
	return PropertyObjectHash(self, {} --[[ make PropertyObjectHash process property injection ]] )
end

local function GetProperty(object, prop)
	local _GetProperty = object.GetProperty
	if _GetProperty and _GetProperty ~= GetProperty then
		return _GetProperty(object, prop)
	end
	return object[prop]
end
_G.GetProperty = GetProperty

function SetProperty(object, prop, value)
	if IsKindOf(object, "PropertyObject") then
		object:SetProperty(prop, value)
		return
	end
	object[prop] = value
end

function ValidateNumberPropValue(value, prop_meta)
	local step = prop_meta.step
	if step then
		value = (value + step / 2) / step * step
	end
	if prop_meta.min and prop_meta.max then
		value = Clamp(value, prop_meta.min, prop_meta.max)
	end
	return value
end

g_traceMeta = rawget(_G, "g_traceMeta") or { __name = "trace_log", }
g_traceEntryMeta = rawget(_G, "g_traceEntryMeta") or
{
	__tostring = function(o)
		return TraceEntryToStr(o)
	end
}

function TraceEntryToStr(entry)
	return string.gsub(entry[2], "%{(%d+)%}", function(item)
		local idx = tonumber(item)
		if idx == 0 then
			return "<?>"
		end
		return ValueToStr(entry[2 + idx])
	end)
end

if config.TraceEnabled then
	function PropertyObject:TraceCall(member)
		assert(self:HasMember(member) and type(self[member]) == "function", "TraceCall unexisting member given as parameter")

		local orig_member_fn = self[member]
		self[member] = function(self, ...)
			self:Trace("[Call]", member, GetStack(2), ...)
			return orig_member_fn(self, ...)
		end
	end

	function PropertyObject:Trace(...)
		local t = rawget(self, "trace_log")
		if not t then
			t = {}
			setmetatable(t, g_traceMeta)
			rawset(self, "trace_log", t)
		end
		local threshold = GameTime() - (config.TraceLogTime or 60000)
		while #t >= 50 and t[#t][1] < threshold do
			table.remove(t)
		end
		local data = { GameTime(), ...}
		setmetatable(data, g_traceEntryMeta)
		table.insert(t, 1, data)
	end
else
	function PropertyObject:TraceCall()
	end

	function PropertyObject:Trace()
	end
end

function ValidateGameObjectProperties(class)
	return function()
		MapForEach("map", class, function(obj)
			local msg = obj:GetDiagnosticMessage("verbose")
			if not msg then
				--
			elseif msg[#msg] == "warning" then
				StoreWarningSource(obj, msg[1])
			else
				StoreErrorSource(obj, msg[1])
			end
		end)
	end
end

if Platform.developer then

function PropertyObject:FindAssociatedThreads()
	local threads
	for thread, src in pairs(ThreadsRegister) do
		local found = ForEachThreadUpvalue(thread, function(name, value, self)
			return value == self
		end, self)
		if found then
			if type(src) ~= "string" then
				src = "<no source>"
			end
			threads = table.create_add(threads, src)
		end
	end
	table.sort(threads)
	return threads
end

end


-- !!! backwards compatibility
----- RecursiveCalls

DefineClass("RecursiveCalls")

function RecursiveCalls:Recursive(method, ...)
	return self[method](self, ...)
end

function RecursiveCalls:RecursiveCall(_, method, ...)
	return self[method](self, ...)
end



-- InitDone class

DefineClass("InitDone", "PropertyObject", "RecursiveCalls")

RecursiveCallMethods.Init = "procall"
RecursiveCallMethods.Done = "procall_parents_last"

InitDone.Init = empty_func
InitDone.Done = empty_func

function InitDone.new(class, obj, ...)
	obj = obj or {}
	setmetatable(obj, class)
	obj:Init(...)
	return obj
end

function InitDone:delete(...)
	self:Done(...)
end


if Platform.developer then
-- verifying if classes that do not inherit InitDone have Init() or Done() methods
function OnMsg.ClassesBuilt()
	for name, class in pairs(g_Classes) do
		if name ~= "InitDone" and not class.__ancestors["InitDone"] and (class.Init or class.Done) then
			assert(false, "Class " .. name .. " must inherit InitDone class to use Init() or Done()")
		end
	end
end
end -- Platform.developer


----- cleanup edit values of developer-only properties

if not Platform.developer then
	function OnMsg.ClassesPreprocess(classdefs)
		for name, class in pairs(classdefs) do
			for _, prop_meta in ipairs(class.properties or empty_table) do
				if prop_meta.developer then
					prop_meta.no_edit = true
					prop_meta.name = nil
					prop_meta.category = nil
					prop_meta.help = nil
				end
				prop_meta.developer = nil
			end
		end
	end
end

function GetPropScale(scale)
	return type(scale) == "number" and scale or const.Scale[scale] or 1
end

function ClassCategoriesCombo(class, add)
	return function()
		assert(g_Classes[class])
		local categories = {}
		for _, prop_meta in ipairs(g_Classes[class] and g_Classes[class]:GetProperties() or empty_table) do
			categories[prop_meta.category or ""] = true
		end
		return table.keys2(categories, true, add)
	end
end

function ClassPropertiesCombo(class, category_field, add)
	return function(obj)
		assert(g_Classes[class])
		local category = category_field and obj[category_field]
		local items = { add }
		for _, prop_meta in ipairs(g_Classes[class] and g_Classes[class]:GetProperties() or empty_table) do
			if not category or (prop_meta.category or "") == category then
				items[#items + 1] = prop_meta.id
			end
		end
		return items
	end
end


--- property time scale

local time_scales = {"sec", "h", "days", "months", "years", "turns"}
local valid_time_scales
function GetTimeScalesCombo()
	if not valid_time_scales then
		valid_time_scales = {""}
		for _, scale in ipairs(time_scales) do
			if const.Scale[scale] then
				valid_time_scales[#valid_time_scales + 1] = scale
			end
		end
	end
	return valid_time_scales
end
