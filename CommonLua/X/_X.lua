function LinkPropertyToChild(class, parent_property, idChild, child_property)
	child_property = child_property or parent_property
	class["Set" .. parent_property] = function (self, value)
		self[parent_property] = value
		local child = self:ResolveId(idChild)
		if child then
			child:SetProperty(child_property, value)
		end
	end
end

function LinkFontPropertiesToChild(class, idChild)
	LinkPropertyToChild(class, "TextStyle", idChild)
	LinkPropertyToChild(class, "TextFont", idChild)
	LinkPropertyToChild(class, "TextColor", idChild)
	LinkPropertyToChild(class, "RolloverTextColor", idChild)
	LinkPropertyToChild(class, "DisabledTextColor", idChild)
	LinkPropertyToChild(class, "DisabledRolloverTextColor", idChild)
	LinkPropertyToChild(class, "ShadowType", idChild)
	LinkPropertyToChild(class, "ShadowSize", idChild)
	LinkPropertyToChild(class, "ShadowColor", idChild)
	LinkPropertyToChild(class, "DisabledShadowColor", idChild)
end

function LinkTextPropertiesToChild(class, idChild)
	LinkPropertyToChild(class, "Translate", idChild)
	LinkPropertyToChild(class, "Text", idChild)
	LinkFontPropertiesToChild(class, idChild)
end

function OnMsg.ClassesGenerate(classdefs)
	ProcessClassdefChildren("XWindow", XGenerateGetSetFuncs)
end

local ClassdefHasMember = ClassdefHasMember
function XGenerateGetSetFuncs(classdef)
	for _, prop_meta in ipairs(classdef.properties or empty_table) do
		if prop_meta.type or prop_meta.editor then
			local prop_id = prop_meta.id
			if prop_meta.editor and prop_id:match("^%u") then -- camel-case properties only
				local get_name = "Get" .. prop_id
				local set_name = "Set" .. prop_id
				local invalidate = prop_meta.invalidate
				local init
				if not ClassdefHasMember(classdef, get_name) then
					init = true
					-- Get method
					classdef[get_name] = function(self)
						return self[prop_id]
					end
				end
				if not ClassdefHasMember(classdef, set_name) then
					init = true
					-- Set method
					local func
					if invalidate == "layout" then
						func = function(self, value)
							local old = self[prop_id]
							self[prop_id] = value
							if self[prop_id] == old then return end
							self:InvalidateMeasure()
							self:InvalidateLayout()
						end
					elseif invalidate == "measure" then
						func = function(self, value)
							local old = self[prop_id]
							self[prop_id] = value
							if self[prop_id] == old then return end
							self:InvalidateMeasure()
						end
					elseif invalidate then
						func = function(self, value)
							local old = self[prop_id]
							self[prop_id] = value
							if self[prop_id] == old then return end
							self:Invalidate()
						end
					else
						func = function(self, value)
							self[prop_id] = value
						end
					end
					classdef[set_name] = func
				end
				if init and prop_meta.default ~= nil then
					assert(classdef[prop_id] == nil, "duplicate default value")
					classdef[prop_id] = prop_meta.default
				end
			end
		end
	end
end
