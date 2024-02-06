DefineClass.ParticleParam =
{
	__parents = { "ParticleSystemSubItem" },
	PropEditorCopy = true,

	properties = {
		{ id = "label", name = "Name", editor = "text" },
		{ id = "type", name = "Type", editor = "dropdownlist", items = { "number", "point", "color", "bool" } },
		{ id = "default_value", name = "Default value", editor = "number" },
	},
	
	label = "<empty>",
	type = "number",
	default_value = 0,
	EditorView = Untranslated("<FormatNameForGed>"),
	EditorName = "Particle Param",
}

function ParticleParam:FormatNameForGed()
	return string.format("<color 95 12 200>%s: %s (%s)", self.class, self.label, self.type)
end

-- Called only by ged's OP, so parent is always a preset and not data isntance
function ParticleParam:OnAfterEditorNew(parent, socket)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	container:BindParamsAndUpdateProperties()
end

-- Called only by ged's OP, so parent is always a preset and not data isntance
function ParticleParam:OnAfterEditorDelete(parent, socket)
	local container = socket:GetParentOfKind("SelectedObject", "ParticleSystemPreset")
	if not container then return end
	container:BindParamsAndUpdateProperties()
end

function ParticleParam:Settype(new_type)
	if self.type == new_type then
		return
	end
	self.type = new_type
	self.default_value = self:GetDefaultPropertyValue("default_value")
end

function ParticleParam:Getdefault_value()
	local raw_value = rawget(self, "default_value")
	if raw_value and raw_value ~= 0 then
		return raw_value
	else
		return self:GetDefaultPropertyValue("default_value")
	end
end

function ParticleParam:Setdefault_value(v)
	self.default_value = v
end

function ParticleParam:GetProperties()
	if self.type == "number" then
		return self.properties
	else
		local props = table.copy(self.properties)
		local idx = table.find(props, "id", "default_value")
		props[idx ] = { id = "default_value", name = "Default value", editor = self.type }
		return props
	end
end

function ParticleParam:GetDefaultPropertyValue(prop, prop_meta)
	if prop == "default_value" then
		local def = {
			point = point30,
			color = 255,
			number = 0,
			bool = false,
		}
		return def[self.type]
	end
	return InitDone.GetDefaultPropertyValue(self, prop, prop_meta)
end