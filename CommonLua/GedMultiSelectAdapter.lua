__Undefined = rawget( _G, "__Undefined") or {}
setmetatable(__Undefined, {
	__toluacode = function(self, indent, pstr)
		local code = "__Undefined"
		if pstr then
			return pstr:append(code)
		else
			return code
		end
	end,
	__tostring = function(self)
		return "__Undefined__"
	end
})
function Undefined()
	return __Undefined
end

if FirstLoad then
	GedMultiSelectAdapters = setmetatable({}, weak_keys_meta)
end

DefineClass.GedMultiSelectAdapter = {
	__parents = { "PropertyObject", "InitDone" },
	__objects = {}, -- try to prevent name collisions; we store nested objs/lists directly in the object
	properties = false,
	property_merge_union = "any", -- or "all"
}

local dont_evaluate = { default = true, preset_filter = true, class_filter = true, setter = true, getter = true, dont_save = true }
local special_treat = { max = Min, min = Max }
local eval = prop_eval
local function MergePropMeta(prop_accumulator, prop_meta, object)
	if prop_meta.no_edit and eval(prop_meta.no_edit, object, prop_meta) then
		return nil
	end
	
	if not prop_accumulator then
		prop_accumulator = {}
		for meta_name, value in pairs(prop_meta) do
			prop_accumulator[meta_name] = dont_evaluate[meta_name] and value or eval(value, object, prop_meta)
		end
		if prop_accumulator.default == nil then
			prop_accumulator.default = PropertyObject.GetDefaultPropertyValue(object, prop_meta.id, prop_meta)
		end
		prop_accumulator.__count = 1
	else
		for meta_name, value in pairs(prop_meta) do
			value = dont_evaluate[meta_name] and value or eval(value, object, prop_meta)
			local acc_value = prop_accumulator[meta_name]
			local special_treat_fn = special_treat[meta_name]
			if special_treat_fn then
				prop_accumulator[meta_name] = special_treat_fn(acc_value, value)
			elseif not CompareValues(acc_value, value) then
				return nil
			end
		end
		prop_accumulator.__count = prop_accumulator.__count + 1
	end
	return prop_accumulator
end

local function CalculatePropertyMetadata(objects)
	local prop_ids = {} -- keep the order of the properties.
	local properties_accumulator = {}
	local prop_ids_with_mismatches = {}
	
	for _, object in ipairs(objects) do
		local properties = object:GetProperties()
		
		for _, prop_meta in ipairs(properties) do
			if not prop_ids_with_mismatches[prop_meta.id] then
				local acc = properties_accumulator[prop_meta.id]
				if not acc then
					prop_ids[#prop_ids+1] = prop_meta.id
				end
				local resulting_acc = MergePropMeta(acc, prop_meta, object)
				properties_accumulator[prop_meta.id] = resulting_acc
				if resulting_acc == nil then
					prop_ids_with_mismatches[prop_meta.id] = true
				end
			end
		end
	end
	
	-- convert to standard prop table
	return properties_accumulator, prop_ids
end

local function MultiselectAdapterGetProperties(objects, property_merge_union)
	local props = {}
	local metas, order = CalculatePropertyMetadata(objects)

	for _, prop_id in ipairs(order) do
		local meta = metas[prop_id]
		if meta then
			if property_merge_union == "any" or (meta.__count == #objects and property_merge_union == "all") then
				table.insert(props, meta)
				props[prop_id] = meta
			end
		end
	end
	return props
end

function GedMultiSelectAdapter:Init()
	local objects = self.__objects
	for i = #objects, 1, -1 do
		if not GedIsValidObject(objects[i]) then
			table.remove(objects, i)
		end
	end
	for _, obj in ipairs(objects) do
		Msg("GedBindObj", obj)
	end
	
	self:UpdatePropertyMetadatas()
	GedMultiSelectAdapters[self] = true
end

function GedMultiSelectAdapter:UpdatePropertyMetadatas()
	self.properties = MultiselectAdapterGetProperties(self.__objects, self.property_merge_union)
	
	-- creates copies of any nested_obj/nested_list properties in the object for Ged to edit
	for _, prop in ipairs(self.properties) do
		local editor, id = prop.editor, prop.id
		if editor == "nested_obj" or editor == "nested_list" then
			local value = self:GetProperty(id)
			if value ~= Undefined() and rawget(self, id) == nil then
				rawset(self, id, self:CopyNestedObjOrList(value))
			end
		end
	end
end

function GedMultiSelectAdapter:CopyNestedObjOrList(value)
	local ret = false
	if value then
		if IsKindOf(value, "PropertyObject") then
			ret = value:Clone()
		else
			ret = {}
			for i, item in ipairs(value) do
				ret[i] = item:Clone()
			end
		end
	end
	return ret
end

function GedMultiSelectAdapter:CopyNestedPropValueToObjects(id)
	for _, obj in ipairs(self.__objects) do
		obj:SetProperty(id, self:CopyNestedObjOrList(self[id]))
	end
end

function GedMultiSelectAdapter:OnEditorSetProperty(prop_id, old_value, ged)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta.editor == "nested_obj" or prop_meta.editor == "nested_list" then
		self:CopyNestedPropValueToObjects(prop_id)
	end
end

function GedMultiSelectAdapter:ClearNestedProperty(prop_id)
	local prop_meta = self:GetPropertyMetadata(prop_id)
	if prop_meta.editor == "nested_obj" or prop_meta.editor == "nested_list" then
		self[prop_id] = nil
	end
end

function GedMultiSelectAdapterObjModified(obj)
	if IsKindOf(obj, "GedMultiSelectAdapter") then
		obj:UpdatePropertyMetadatas()
		return
	end
	for adapter in pairs(GedMultiSelectAdapters) do
		for id, value in pairs(adapter) do
			if (rawequal(obj, value) or type(value) == "table" and table.find(value, obj)) and table.find(adapter.properties, "id", id) then
				adapter:CopyNestedPropValueToObjects(id)
			end
		end
	end
end

OnMsg.GedObjectModified = GedMultiSelectAdapterObjModified

function GedMultiSelectAdapter:GetProperty(prop_id)
	local value = rawget(self, prop_id)
	if value ~= nil then
		return value
	end
	for _, obj in ipairs(self.__objects) do
		if GedIsValidObject(obj) then
			local new_val = GetProperty(obj, prop_id)
			if new_val ~= nil then
				if value ~= nil and not CompareValues(new_val, value) then
					return Undefined()
				end
				value = new_val
			end
		end
	end
	return value
end

function GedMultiSelectAdapter:GetDefaultPropertyValue(prop_id, prop_meta)
	if prop_meta then
		local value = rawget(prop_meta, "default")
		if value ~= nil then
			return value
		end
	end
	return self.properties[prop_id].default
end

function GedMultiSelectAdapter:ExecPropButton(root, prop_id, ged, func, param)
	SuspendObjModified("GedMultiSelectAdapter:ExecPropButton")
	local errs, undos = {}, {}
	for _, obj in ipairs(self.__objects) do
		if GedIsValidObject(obj) then
			local err, undo
			local prop_capture = GedPropCapture(obj)
			if type(func) == "function" then
				err, undo = func(obj, root, prop_id, ged, param)
			elseif obj:HasMember(func) then
				err, undo = obj[func](obj, root, prop_id, ged, param)
			elseif type(rawget(_G, func)) == "function" then
				err, undo = _G[func](root, obj, prop_id, ged, param)
			end
			
			local undop = GedCreatePropValuesUndoFn(obj, prop_capture)
			if type(err)   == "string"   then errs [#errs  + 1] = err   end
			if type(undo)  == "function" then undos[#undos + 1] = undo  end
			if type(undop) == "function" then undos[#undos + 1] = undop end
		end
	end
	ResumeObjModified("GedMultiSelectAdapter:ExecPropButton")
	
	return
		next(errs) and table.concat(errs, "\n"),
		#undos > 0 and function() for i = 1, #undos do undos[i]() end end or nil
end

function GedMultiSelectAdapter:OnEditorSelect(...)
	for _, obj in ipairs(self.__objects) do
		if GedIsValidObject(obj) and PropObjHasMember(obj, "OnEditorSelect") then
			obj:OnEditorSelect(...)
		end
	end
end