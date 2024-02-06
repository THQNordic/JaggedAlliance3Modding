----- XContextWindow
-- Any lua value can be context of the window.
-- When the value or in case of a composite context any of the internal values are modified the window receives OnContextUpdate call.

DefineClass.XContextWindow = {
	__parents = { "XWindow" },
	properties = {
		{ category = "Interaction", id = "ContextUpdateOnOpen", editor = "bool", default = false, },
		{ category = "Interaction", id = "OnContextUpdate", editor = "func", params = "self, context, ...", },
	},
	context = false,
}

function XContextWindow:Init(parent, context)
	if context then
		self:SetContext(context, false)
	end
end

function XContextWindow:Done()
	self:SetContext(nil, false)
end

function XContextWindow:Open(...)
	XWindow.Open(self, ...)
	if self.ContextUpdateOnOpen then
		procall(self.OnContextUpdate, self, self.context, "open")
	end
end

function XContextWindow:OnContextUpdate(context, ...)
end

function XContextWindow:GetContext()
	return self.context
end

function XContextWindow:GetParentContext()
	local parent = self.parent
	if parent then
		return parent:GetContext()
	end
end

function XContextWindow:SetContext(context, update)
	if self.context == (context or false) and not update then return end
	ForEachObjInContext(self.context, function (obj, self)
		local windows = ObjToWindows[obj]
		if windows then
			table.remove_entry(windows, self)
			if #windows == 0 then
				ObjToWindows[obj] = nil
			end
		end
	end, self)
	self.context = context
	ForEachObjInContext(context, function (obj, self)
		local windows = ObjToWindows[obj]
		if windows then
			windows[#windows + 1] = self
		else
			ObjToWindows[obj] = { self }
		end
	end, self)
	if update ~= false then
		procall(self.OnContextUpdate, self, context, update or "set")
	end
end

--[[function XContextWindow:ResolveValue(id)
	local value = ResolveValue(self.context, id)
	if value ~= nil then return value end
	return PropertyObject.ResolveValue(self, id)
end]]


----- globals

if FirstLoad then
	ObjToWindows = setmetatable({}, weak_keys_meta)
	XContextUpdateLogging = false
end

function XContextUpdate(context, ...)
	if not context then return end
	for _, window in ipairs(ObjToWindows[context] or empty_table) do
		if XContextUpdateLogging then
			print("ContextUpdate:", FormatWindowPath(window))
		end
		procall(window.OnContextUpdate, window, window.context, ...)
	end
end

function OnMsg.ObjModified(obj)
	XContextUpdate(obj, "modified")
end

