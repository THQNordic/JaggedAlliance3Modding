DefineClass.PresetParam = {
	__parents = { "PropertyObject", },
	properties = {
		{ id = "Name", editor = "text", default = false, },
		{ id = "Value", editor = "number", default = 0, },
		{ id = "Tag", editor = "text", translate = false, read_only = true, default = "", help = "Paste this tag into texts to display the parameter's value.", },
	},
	EditorView = Untranslated("Param <Name> = <Value>"),
	Type = "number",
}

function PresetParam:GetTag()
	return "<" .. (self.Name or "") .. ">"
end

function PresetParam:GetError()
	if not self.Name then
		return "Please name your parameter."
	elseif not self.Name:match("^[%w_]*$") then
		return "Parameter name must only contain alpha-numeric characters and underscores."
	end
end

DefineClass.PresetParamNumber = {
	__parents = { "PresetParam", },
	properties = {
		{ id = "Value", editor = "number", default = 0, },
	},
	EditorName = "New Param (number)",
}

DefineClass.PresetParamPercent = {
	__parents = { "PresetParam", },
	properties = {
		{ id = "Value", editor = "number", default = 0, scale = "%" },
	},
	EditorView = Untranslated("Param <Name> = <Value>%"),
	EditorName = "New Param (percent)",
}

function PresetParamPercent:GetTag()
	return "<" .. (self.Name or "") .. ">%"
end

function PickParam(root, obj, prop_id, ged)
	local param_obj = ged:GetParentOfKind(obj, "Preset").Parameters
	local params = {}
	local params_to_num = {}
	for _,item in ipairs(param_obj) do
		if item.Name then
			params[#params + 1] = item.Name
			params_to_num[item.Name] = item.Value
		end
	end
	
	if #params == 0 then
		ged:ShowMessage("Error", "There are no Parameters defined for this Preset.")
		return
	end
	
	local pick = obj.param_bindings and obj.param_bindings[prop_id] or params[1]
	if #params > 1 then
		pick = ged:WaitUserInput("Select Param", pick, params)
		if not pick then return end
	end
	obj.param_bindings = obj.param_bindings or {}
	obj.param_bindings[prop_id] = pick
	obj:SetProperty(prop_id, params_to_num[pick])
	GedForceUpdateObject(obj)
	ObjModified(obj)
	ObjModified(root)
end

local function PresetParamOnEditorNew(obj, parent, ged)
	local preset = ged:GetParentOfKind(parent, "Preset") or obj
	if obj:IsKindOf("PresetParam") then
		local preset_param_cache = g_PresetParamCache[preset] or {}
		preset_param_cache[obj.Name] = obj.Value
		g_PresetParamCache[preset] = preset_param_cache
	elseif preset:HasMember("HasParameters") and preset.HasParameters == true and not obj:HasMember("param_bindings") then
		rawset(obj, "param_bindings", false)
	end
end

local function PresetParamOnEditorSetProperty(obj, prop_to_change, prev_value, ged)
	local preset = ged.selected_object
	if not preset then return end
	
	if obj:IsKindOf("PresetParam") then
		local preset_param_cache = g_PresetParamCache[preset] or {}
		
		if prop_to_change == "Value" then
			preset:ForEachSubObject(function(subobj, parents, key, param_name, new_value)
				for prop, param in pairs(rawget(subobj, "param_bindings")) do
					if param == param_name then
						subobj:SetProperty(prop, new_value)
						ObjModified(subobj)
					end
				end
			end, obj.Name, obj.Value)
		elseif prop_to_change == "Name" then
			preset:ForEachSubObject(function(subobj, parents, key, new_name, old_name)
				for prop, param in pairs(rawget(subobj, "param_bindings")) do
					if param == old_name then
						subobj.param_bindings[prop] = new_name
						ObjModified(subobj)
					end
				end
			end, obj.Name, prev_value)
			
			preset_param_cache[prev_value] = nil
		end
		
		preset_param_cache[obj.Name] = obj.Value
		g_PresetParamCache[preset] = preset_param_cache
	elseif obj:HasMember("param_bindings") and obj.param_bindings and obj.param_bindings[prop_to_change] then
		obj.param_bindings[prop_to_change] = nil
	end
end

local function PresetParamOnEditorDelete(obj, parent, ged)
	local preset = ged.selected_object
	if not preset then return end
	
	if obj:IsKindOf("PresetParam") then
		preset:ForEachSubObject(function(subobj, parents, key, deleted_param)
			for prop, param in pairs(rawget(subobj, "param_bindings")) do
				if param == deleted_param then
					subobj.param_bindings[prop] = nil
					ObjModified(subobj)
				end
			end
		end, obj.Name)
		
		if g_PresetParamCache[preset] then
			g_PresetParamCache[preset][obj.Name] = nil
		end
	end
end

function OnMsg.GedNotify(obj, method, ...)
	if method == "OnEditorNew" then
		PresetParamOnEditorNew(obj, ...)
	elseif method == "OnEditorSetProperty" then
		PresetParamOnEditorSetProperty(obj, ...)
	elseif method == "OnAfterEditorDelete" then
		PresetParamOnEditorDelete(obj, ...)
	end
end
