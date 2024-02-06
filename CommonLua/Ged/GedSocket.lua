DefineClass.GedSocket = {
	__parents = { "MessageSocket" },
	msg_size_max = 256*1024*1024,
	bound_objects = false, -- mapping name -> object
	app = false,
}

function GedSocket:Init()
	self.bound_objects = {}
end

function GedSocket:Done()
	self:CloseApp()
end

function GedSocket:OnDisconnect(reason)
	self:CloseApp()
end

function GedSocket:CloseApp()
	if self.app and self.app.window_state == "open" then
		self.app:Close()
		if not self.app.in_game then
			quit()
		end
	end
end

function GedSocket:rfnGedQuit()
	self:delete()
end

function GedSocket:Obj(name)
	return self.bound_objects[name]
end

function GedSocket:BindObj(name, obj_address, func_name, ...)
	self:Send("rfnBindObj", name, obj_address, func_name, ...)
end

function GedSocket:BindFilterObj(target, name, class_or_instance)
	self:Send("rfnBindFilterObj", target, name, class_or_instance)
end

function GedSocket:UnbindObj(name, to_prefix)
	self:Send("rfnUnbindObj", name, to_prefix)
	self.bound_objects[name] = nil
	if to_prefix then
		local pref = name .. to_prefix
		for obj_name in pairs(self.bound_objects) do
			if string.starts_with(obj_name, pref) then
				self.bound_objects[obj_name] = nil
			end
		end
	end
end

function GedSocket:rfnObjValue(name, value, is_code)
	if is_code then
		local err, obj = LuaCodeToTuple(value)
		if err then
			printf("Error deserializing %s", name)
			return
		end
		value = obj
	end
	self.bound_objects[name] = value
	
	local obj_name, view = name:match("(.+)|(.+)")
	PauseInfiniteLoopDetection("GedUpdateContext")
	XContextUpdate(obj_name or name, view)
	ResumeInfiniteLoopDetection("GedUpdateContext")
end

function GedSocket:rfnOpenApp(template_or_class, context, id)
	context = context or {}
	context.connection = self
	local app = OpenDialog(id or template_or_class, context.in_game and GetDevUIViewport(), context)
	assert(IsKindOf(app, "GedApp"))
	if not app then return "xtemplate" end
	if app.AppId == "" then
		app:SetAppId(template_or_class)
		app:ApplySavedSettings()
	end
	if app:GetTitle() == "" then
		app:SetTitle(template_or_class)
	end
	XShortcutsTarget:SetDarkMode(GetDarkModeSetting())
	
	LogOnlyPrint("Initializing ged app: " .. tostring(template_or_class))
end

function GedSocket:rfnClose()
	quit()
end

function GedSocket:rfnApp(func, ...)
	local app = self.app
	if not app or app.window_state == "destroying" then return "app" end
	if not app:HasMember(func) then return "func" end
	return app[func](app, ...)
end

if Platform.ged then
	function OnMsg.ApplicationQuit()
		for _, win in ipairs(terminal.desktop) do
			if win:IsKindOf("GedApp") then
				win:Close()
			end
		end
	end
end
