function OpenXWindowInspector(context)
	PauseLuaThreads("XWindowInspector")
	CreateRealTimeThread(function()
		local target = terminal.desktop:GetMouseTarget(terminal.GetMousePos()) or terminal.desktop
		local gedTarget = GetParentOfKind(target, "GedApp")
		if gedTarget then
			context.dark_mode = gedTarget.dark_mode
		end
		local ged = OpenGedApp("XWindowInspector", terminal.desktop, context)
		if ged then
			GedXWindowInspectorSelectWindow(ged, target)
		else
			ResumeLuaThreads("XWindowInspector")
		end
	end)
end

function OnMsg.LuaThreadsPaused()
	ObjModified(terminal.desktop) -- updates the status text, which is bound with context "root" (which happens to be the desktop)
end

function GedThreadsPausedStatus()
	return AreLuaThreadsPaused() and "<style GedError>Lua threads are PAUSED to freeze the UI!" or "Threads currently running..."
end

function GedTogglePauseLuaThreads(ged)
	local was_paused = next(PauseLuaThreadsReasons)
	if was_paused then
		ResumeLuaThreads("XWindowInspector")
		local pause_reason = next(PauseLuaThreadsReasons)
		if pause_reason then
			ged:ShowMessage("Warning", string.format("Lua threads are still paused due to reason %s", pause_reason))
		end
	else
		PauseLuaThreads("XWindowInspector")
	end
end

if FirstLoad then
	GedXWindowInspectors = {}
	GedXWindowInspectorSelection = setmetatable({}, weak_keys_meta)
	GedXWindowInspectorTerminalTarget = false
end

function OnMsg.ClassesGenerate()
	assert(not (XWindow.TreeView or XWindow.PlacementText or XWindow.OnEditorSelect))
	XWindow.TreeView = T(408752573312, "<NodeColor><class> <color 128 128 128><Id><PlacementText>")
	XWindow.NodeColor = function(self)
		return self.IdNode and #self > 0 and "<color 75 105 198>" or ""
	end
	XWindow.PlacementText = function(self)
		local ret = { (self:GetProperty("Id") ~= "") and "" or nil }
		local dbg_template = rawget(self, "__dbg_template_template") or rawget(self, "__dbg_template")
		if dbg_template then
			ret[#ret+1] = "T: " .. dbg_template
		end
		local dock = self:GetProperty("Dock")
		if dock then
			ret[#ret+1] = "Dock: " .. dock
		end
		local dbg_template_comment = rawget(self, "__dbg_template_comment")
		if dbg_template_comment then
			ret[#ret+1] = "<color 0 128 0>" .. dbg_template_comment
		end
		return Untranslated(table.concat(ret, " "))
	end
	XWindow.OnEditorSelect = function(self, selected, ged)
		if selected then
			GedXWindowInspectorSelection[ged] = self
		end
	end
end

local function GedUpdateActionToggled(actionid, value)
	for k, socket in pairs(GedConnections) do
		if socket.app_template == "XWindowInspector" or socket.app_template == "GedParticleEditor" then
			socket:Send("rfnApp", "SetActionToggled", actionid, value)
		end
	end
end

local function GedUpdateInspectorActions(socket)
	socket:Send("rfnApp", "SetActionToggled", "FocusLogging", terminal.desktop.focus_logging_enabled)
	socket:Send("rfnApp", "SetActionToggled", "RolloverLogging", terminal.desktop.rollover_logging_enabled)
	socket:Send("rfnApp", "SetActionToggled", "ContextLogging", XContextUpdateLogging)
	socket:Send("rfnApp", "SetActionToggled", "RolloverMode", GedXWindowInspectorTerminalTarget and GedXWindowInspectorTerminalTarget.enabled)
end

function OnMsg.GedOpened(ged_id)
	local ged = GedConnections[ged_id]
	if ged and ged.app_template == "XWindowInspector" then
		table.insert(GedXWindowInspectors, ged)
	end
	if ged and (ged.app_template == "XWindowInspector" or ged.app_template == "GedParticleEditor") then
		GedUpdateInspectorActions(ged)
	end
end

function GedRpcBindToGlobal(ged, path, global_name)
	local obj = ged:ResolveObj(path)
	rawset(_G, global_name, obj)
end

function OnMsg.GedClosing(ged_id)
	table.remove_entry(GedXWindowInspectors, "ged_id", ged_id)
	if not next(GedXWindowInspectors) then
		ResumeLuaThreads("XWindowInspector")
	end
end

function OnMsg.XWindowModified(win, child, leaving)
	if #GedXWindowInspectors == 0 then return end

	if leaving then
		-- validate selected windows
		for ged, selection in pairs(GedXWindowInspectorSelection) do
			if child == selection then
				GedXWindowInspectorSelection[ged] = win
			end
		end
		
		-- close inspectors with deleted root objects
		for _, inspector in ipairs(GedXWindowInspectors) do
			if child == inspector:ResolveObj("root") then
				inspector:Close()
			end
		end
	end

	repeat
		for _, inspector in ipairs(GedXWindowInspectors) do
			if win == inspector:ResolveObj("root") then
				-- go through a thread, so multiple changes to a XWindow only result in a single call
				if not win:IsThreadRunning("XWindowInspectorObjModified") then
					local ged, modified = inspector, win
					win:CreateThread("XWindowInspectorObjModified", function()
						ObjModified(modified)
						GedXWindowInspectorSelectWindow(ged, GedXWindowInspectorSelection[ged])
					end)
				end
			end
		end
		win = win.parent
	until not win
end

local function GetItemPath(root, control)
	local path = {}
	if not root or not control or not control:IsWithin(root) then
		return path
	end
	local target = control
	while target.parent and target ~= root do
		local idx = table.find(target.parent, target)
		table.insert(path, 1, idx)
		target = target.parent
	end
	return path
end

function GedXWindowInspectorSelectWindow(socket, win)
	local root = socket:ResolveObj("root")
	if socket.selected_object ~= win then
		socket:SetSelection("root", GetItemPath(root, win))
		socket.selected_object = win
	end
end

function GedGetXWindowPath(obj)
	local data = {}
	repeat
		table.insert(data, 1, {
			text = _InternalTranslate(XWindow.TreeView, obj, false),
			path = GetItemPath(terminal.desktop, obj),
		})
		obj = obj.parent
	until not obj
	return data
end

DefineClass.RolloverModeTerminalTarget = {
	__parents = { "TerminalTarget" },
	
	enabled = false,
	callback = false,
	terminal_target_priority = 20000000,
}

function RolloverModeTerminalTarget:MouseEvent(event, pt, button, time)
	if not self.enabled then
		return "continue"
	end
	
	local target = terminal.desktop:GetMouseTarget(pt) or terminal.desktop
	if event == "OnMouseButtonDown" then
		self.enabled = false
		if button == "R" then
			self.callback(target, "cancel")
		else
			self.callback(target, "done")
		end
		GedUpdateActionToggled("RolloverMode", false)
	else
		self.callback(target, "update")
	end
	return "break"
end

function RolloverModeTerminalTarget:EnableRolloverMode(enabled, callback)
	if self.callback and self.enabled then
		self.callback(false, "cancel")
	end
	self.enabled = enabled
	self.callback = callback
	GedUpdateActionToggled("RolloverMode", self.enabled)
end

local flashing_window = false
function XRolloverMode(enabled, callback)
	if not GedXWindowInspectorTerminalTarget then
		GedXWindowInspectorTerminalTarget = RolloverModeTerminalTarget:new()
		terminal.AddTarget(GedXWindowInspectorTerminalTarget)
	end
	GedXWindowInspectorTerminalTarget:EnableRolloverMode(enabled, callback)
end

function GedRpcRolloverMode(socket, enabled)
	local old_sel = socket:ResolveObj("SelectedWindow")
	XRolloverMode(enabled, function(window, status)
		if window then
			if status == "cancel" then
				GedXWindowInspectorSelectWindow(socket, old_sel)
			else
				GedXWindowInspectorSelectWindow(socket, window)
			end
		end
	end)
end

function GedRpcColorPickerRollover(ged, name, prop_id)
	local obj = ged:ResolveObj(name)
	if not obj then return end

	local thread_status = "updating"
	CreateRealTimeThread(function()
		flashing_window = {
			BorderWidth = 2,
			BorderColor = RGB(200, 0, 0),
			Box = terminal.desktop.box,
			Thread = false,
		}
		UIL.Invalidate()

		SetPostProcPredicate("debug_color_pick", true)

		local old_value = obj:GetProperty(prop_id)
		while thread_status == "updating" do
			local pixel = ReturnPixel()
			if pixel and pixel ~= obj:GetProperty(prop_id) then
				obj:SetProperty(prop_id, pixel)
				ObjModified(obj)
			end
			Sleep(10)
		end
		if thread_status == "cancel" then
			obj:SetProperty(prop_id, old_value)
			ObjModified(obj)
		end

		SetPostProcPredicate("debug_color_pick", false)
		
		flashing_window = false
		UIL.Invalidate()
	end)
	XRolloverMode(true, function(window, status)
		if status == "done" then
			thread_status = "done"
		elseif status == "cancel" then
			thread_status = "cancel"
		else			
			local pos = terminal.GetMousePos()
			RequestPixel(pos:x(), pos:y())
		end
	end)
	terminal.BringToTop()
end

function GedRpcInspectFocusedWindow(socket)
	local desktop = terminal.desktop
	local target = desktop:GetKeyboardFocus() or desktop:NextFocusCandidate()
	socket:Send("rfnApp", "SetSelection", "root", target and GetItemPath(socket:ResolveObj("root"), target))
end

function GedRpcToggleFocusLogging(socket, enabled)
	terminal.desktop.focus_logging_enabled = enabled
	GedUpdateActionToggled("FocusLogging", enabled)
end

function GedRpcToggleRolloverLogging(socket, enabled)
	terminal.desktop.rollover_logging_enabled = enabled
	GedUpdateActionToggled("RolloverLogging", enabled)
end

function GedRpcToggleContextLogging(socket, enabled)
	XContextUpdateLogging = enabled
	GedUpdateActionToggled("ContextLogging", enabled)
end

function XFlashWindow(obj)
	if not obj then return end
	if flashing_window then
		DeleteThread(flashing_window.Thread)
	end
	flashing_window = {
		BorderWidth = 1,
		BorderColor = RGB(0, 0, 0),
		Box = box(0, 0, 0, 0),
		Thread = false,
	}
	flashing_window.Thread = CreateRealTimeThread(function()
		for i = 1, 5 do
			local target = obj.interaction_box or obj.box
			if obj.window_state == "destroying" or not target then
				break
			end
			flashing_window.Box = target
			flashing_window.BorderColor = RGB(255, 255, 255)
			UIL.Invalidate()
			Sleep(50)
			flashing_window.BorderColor = RGB(0, 0, 0)
			UIL.Invalidate()
			Sleep(50)
		end
		flashing_window = false
		UIL.Invalidate()
	end)
end

function GedRpcFlashWindow(socket, obj_name)
	local obj = socket:ResolveObj(obj_name)
	XFlashWindow(obj)
end

function GedRpcXWindowInspector(socket, obj_name)
	local obj = socket:ResolveObj(obj_name)
	CreateRealTimeThread(function()
		OpenGedApp("XWindowInspector", obj)
	end)
end

function GedXWindowInspectorFlashWindow()
	if flashing_window then
		local border_width = flashing_window.BorderWidth
		UIL.DrawBorderRect(flashing_window.Box, border_width, border_width, flashing_window.BorderColor, RGBA(0, 0, 0, 0))
	end
end

function OnMsg.Start()
	if Platform.desktop then
		UIL.Register("GedXWindowInspectorFlashWindow", XDesktop.terminal_target_priority + 1)
	end
end

