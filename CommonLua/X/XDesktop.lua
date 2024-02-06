DefineClass.XDesktop = {
	__parents = { "XActionsHost" },
	LayoutMethod = "Box",

	keyboard_focus = false,
	modal_window = false,
	modal_log = false,
	mouse_capture = false,
	touch = false,
	last_mouse_pos = false,
	last_mouse_target = false,
	inactive = false,
	mouse_target_update = false,
	last_event_at = false,
	terminal_target_priority = -1,
	layout_thread = false,
	mouse_target_thread = false,
	focus_logging_enabled = false,
	rollover_logging_enabled = false,
	
	HandleMouse = true,
	IdNode = true,
}

function XDesktop:Init()
	self.desktop = self
	self.focus_log = {}
	self.modal_log = {}
	self.touch = {}
	self.modal_window = self
end

function XDesktop:WindowLeaving(win)
	local last_target = self.last_mouse_target
	if last_target and last_target:IsWithin(win) then
		local current = last_target
		while current do
			current:OnMouseLeft(self.last_mouse_pos, last_target)
			if current == win then break end
			current = current.parent
		end
		repeat
			win = win.parent
		until not win or win.HandleMouse
		self.last_mouse_target = win
	end
end

function XDesktop:WindowLeft(win)
	if self.mouse_capture == win then
		self:SetMouseCapture(false)
	end
	self:RemoveModalWindow(win)
	self:RemoveKeyboardFocus(win)
	if RolloverControl == win then
		XDestroyRolloverWindow("immediate")
	end
	for id, touch in pairs(self.touch) do
		if touch.target == win then
			touch.target = nil
		end
		if touch.capture == win then
			touch.capture = nil
		end
	end
end

----- keyboard

function XDesktop:NextFocusCandidate()
	for i = #self.focus_log, 1, -1 do
		local win = self.focus_log[i]
		if win:IsWithin(self.modal_window) and win:IsVisible() and win:GetEnabled() then
			return win
		end
	end
	return false
end

function XDesktop:RestoreFocus()
	self:SetKeyboardFocus(self:NextFocusCandidate())
end

function XDesktop:SetKeyboardFocus(focus)
	assert(not focus or focus:IsWithin(self))
	local last_focus = self.keyboard_focus
	if last_focus == focus or focus and not focus:IsWithin(self) then
		return
	end

	if self.focus_logging_enabled then
		print("New Focus:", FormatWindowPath(focus))
		print(GetStack(2))
	end

	if focus then
		table.remove_entry(self.focus_log, focus)
		table.insert(self.focus_log, focus or nil)
		if not focus:IsWithin(self.modal_window) or not focus:IsVisible() then
			return
		end
	end

	if self.inactive then
		self.keyboard_focus = focus
		return
	end

	self.keyboard_focus = focus
	local common_parent = XFindCommonParent(last_focus, focus)
	local win = last_focus
	while win and win ~= common_parent do
		win:OnKillFocus(focus)
		win = win.parent
	end
	win = focus
	while win and win ~= common_parent do
		win:OnSetFocus(focus)
		win = win.parent
	end
end

function XDesktop:RemoveKeyboardFocus(win, children)
	local is_focused = win:IsFocused(children)
	local log = self.focus_log
	if children then
		for i = #log, 1, -1 do
			if log[i]:IsWithin(win) then
				table.remove(log, i)
			end
		end
	else
		table.remove_entry(log, win)
	end
	if is_focused then
		self:RestoreFocus()
	end
end

function XDesktop:GetKeyboardFocus()
	return self.keyboard_focus
end

function GetKeyboardFocus()
	local desktop = terminal and terminal.desktop
	return desktop and desktop:GetKeyboardFocus()
end

function WaitSwitchControls(state, title, text, ok_text, cancel_text)
	ok_text = ok_text or T(1138, "Yes")
	cancel_text = cancel_text or T(1139, "No")
	if WaitQuestion(terminal.desktop, title, text, ok_text, cancel_text, {forced_ui_style = state}) == "ok" then
		SwitchControls(state == "gamepad")
	end
end

function XDesktop:KeyboardEvent(event, button, ...)
	if config.AutoControllerHandling and event == "OnXButtonDown" and AccountStorage and not GetUIStyleGamepad() then
		if config.AutoControllerHandlingType == "popup" then
			if not IsValidThread(SwitchControlQuestionThread) then
				SwitchControlQuestionThread = CreateRealTimeThread(function()
					WaitSwitchControls("gamepad", T(383758760550, "Switch to controller?"), T(207085726945, "Are you sure you want to use a controller?"))
				end)
				return "break"
			end
		elseif config.AutoControllerHandlingType == "auto" then
			SwitchControls(true)
		end
	end

	self.last_event_at = RealTime()
	local target = self.keyboard_focus
	while target do
		if target.HandleKeyboard then
			if target[event](target, button, ...) == "break" then
				-- print(tostring(target), event, ...)
				return "break"
			end
		end
		target = target.parent
	end
end

function XDesktop:OnShortcut(shortcut, source, ...)
	if source == "mouse" then
		local target = self.last_mouse_target or self.mouse_capture
		while target and target ~= self do
			if target.window_state ~= "destroying" then
				if target:OnShortcut(shortcut, source, ...) == "break" then
					return "break"
				end
			end
			target = target.parent
		end
	else
		local focus = self.keyboard_focus
		while focus and focus ~= self do
			if focus.HandleKeyboard then
				if focus:OnShortcut(shortcut, source, ...) == "break" then
					return "break"
				end
			end
			focus = focus.parent
		end
	end
end

function XDesktop:OnSystemVirtualKeyboard()
	ConsoleLogResize()
	ConsoleResize()
end

----- gamepad

function XDesktop:XEvent(event, ...)
	if not self.inactive then
		if not IsMouseViaGamepadActive() then
			self:SetLastMouseTarget(false)
			self:ResetMousePosTarget()
		end
		return self:KeyboardEvent(event, ...)
	end
end

----- mouse

function XDesktop:SetMouseCapture(win)
	if not win or not win:IsWithin(self.modal_window) then
		win = false
	end
	local old_capture = self.mouse_capture
	if old_capture == win then return end
	self.mouse_capture = win
	if old_capture then
		old_capture:OnCaptureLost(self.last_mouse_pos)
	end
end

function XDesktop:GetMouseCapture()
	return self.mouse_capture
end

function XDesktop:RestoreModalWindow()
	local win
	local log = self.modal_log
	for i = #log,1,-1 do
		if log[i]:IsVisible() and (not win or log[i]:IsOnTop(win)) then
			win = log[i]
		end
	end
	self.desktop:SetModalWindow(win or self)
end

function XDesktop:SetModalWindow(win)
	if not win or not win:IsWithin(self) or win == self.modal_window then
		return
	end

	table.remove_entry(self.modal_log, win)
	if win ~= self then
		self.modal_log[#self.modal_log + 1] = win
	end

	if not win:IsVisible() or not win:IsOnTop(self.modal_window) then
		return
	end

	if self.focus_logging_enabled then
		print("Modal window:", FormatWindowPath(win))
	end
	self.modal_window = win
	
	for id, touch in pairs(self.touch) do
		if not touch.capture and not touch.target:IsWithin(win) then
			touch.target:OnTouchCancelled(id, touch.pos, touch)
			touch.target = nil
		end
	end

	if RolloverControl and not RolloverControl:IsWithin(win) then
		XDestroyRolloverWindow("immediate")
	end

	if self.keyboard_focus and not self.keyboard_focus:IsWithin(win) then
		self:SetKeyboardFocus(false)
	end
	self:RestoreFocus()

	if self.mouse_capture and not self.mouse_capture:IsWithin(win) then
		self:SetMouseCapture(false)
	end
	self:UpdateMouseTarget()
end

function XDesktop:RemoveModalWindow(win)
	table.remove_entry(self.modal_log, win)
	if self.modal_window == win then
		self.modal_window = false
		self:RestoreModalWindow()
		assert(self.modal_window)
	end
end

function XDesktop:GetModalWindow()
	return self.modal_window
end

if FirstLoad then
	prev_cursor = false
end

function XDesktop:UpdateCursor(pt)
	pt = pt or self.last_mouse_pos
	if not pt then return end
	local target, cursor = self.modal_window:GetMouseTarget(pt)
	target = target or self.modal_window
	if self.mouse_capture and target ~= self.mouse_capture then
		cursor = self.mouse_capture:GetMouseCursor()
		target = false
	end
	
	local curr_cursor = cursor or const.DefaultMouseCursor
	if prev_cursor ~= curr_cursor then
		SetUIMouseCursor(curr_cursor)
		Msg("MouseCursor", curr_cursor)
		prev_cursor = curr_cursor
	end
	return target
end

function XDesktop:SetLastMouseTarget(target, pt)
	local last_target = self.last_mouse_target
	if last_target == target then return end
	
	pt = pt or self.last_mouse_pos
	assert(not self.mouse_target_update, "Recursive mouse target update!")
	
	if self.rollover_logging_enabled then
		print("MouseTarget:", FormatWindowPath(target))
		if last_target then last_target:Invalidate() end
		if target then target:Invalidate() end
	end
	
	self.mouse_target_update = true
	self.last_mouse_target = target
	local common_parent = XFindCommonParent(last_target, target)
	local win = last_target
	while win and win ~= common_parent do
		win:OnMouseLeft(pt, last_target)
		win = win.parent
	end
	win = target
	while win and win ~= common_parent do
		win:OnMouseEnter(pt, target)
		win = win.parent
	end
	self.mouse_target_update = false
end

function XDesktop:UpdateMouseTarget(pt)
	pt = pt or self.last_mouse_pos
	local target = self:UpdateCursor(pt) or false
	self:SetLastMouseTarget(target, pt)
	
	return target or self.mouse_capture
end

function XDesktop:MouseEvent(event, pt, button, time)
	local target = self:UpdateMouseTarget(pt)
	if config.AutoControllerHandling and event == "OnMouseButtonDown" and GetUIStyleGamepad() and (button == "L" or button == "R")
		and not GetParentOfKind(target, "DeveloperInterface")
		and not GetParentOfKind(target, "XPopupMenu")
		and not GetParentOfKind(target, "XBugReportDlg")
		and time ~= "gamepad"
	then
		if config.AutoControllerHandlingType == "popup" then
			if not IsValidThread(SwitchControlQuestionThread) then
				SwitchControlQuestionThread = CreateRealTimeThread(function()
					ForceShowMouseCursor("control scheme change")
					WaitSwitchControls("keyboard", T(477820487236, "Switch to mouse?"), T(184341668469, "Are you sure you want to switch to keyboard/mouse controls?"))
					UnforceShowMouseCursor("control scheme change")
				end)
				return "break"
			end
		elseif config.AutoControllerHandlingType == "auto" then
			SwitchControls(false)
		end
	end
	
	self.last_mouse_pos = pt
	self.last_event_at = RealTime()

	while target do
		if target.window_state ~= "destroying" then
			if target[event](target, pt, button) == "break" then
				-- print(event, button, pt, _GetUIPath(target))
				--[[
				if event == "OnMouseButtonDown" then
					local info = debug.getinfo(target[event])
					print("\t", info.short_src, info.linedefined)
				end
				--]]
				return "break"
			end
		end
		target = target.parent
	end
end

function XDesktop:ResetMousePosTarget()
	self.last_mouse_pos = false
	self.last_mouse_target = false
end

----- activation

function XDesktop:OnSystemActivate()
	if self.inactive then
		self:KeyboardEvent("OnSetFocus")
		self.inactive = false
		Msg("SystemActivate")
	end
end

function XDesktop:OnSystemInactivate()
	if not self.inactive then
		self.inactive = true
		self:KeyboardEvent("OnKillFocus")
		self:SetMouseCapture(false)
		Msg("SystemInactivate")
	end
end

function XDesktop:OnSystemMinimize()
	Msg("SystemMinimize")
end

function XDesktop:OnSystemSize(pt)
	local x, y = pt:xy()
	if x == 0 or y == 0 then
		return
	end
	local scale = GetUIScale(pt)
	self:SetOutsideScale(point(scale, scale))
	self:SetBox(0, 0, x, y)
	self:InvalidateMeasure()
	self:InvalidateLayout()
	Msg("SystemSize", pt)
end

function XDesktop:OnMouseInside()
	Msg("MouseInside")
end

function XDesktop:OnMouseOutside()
	Msg("MouseOutside")
end

function XDesktop:OnFileDrop(filename)
	if Platform.developer or Platform.asserts then
		if string.ends_with(filename, ".sav", true) then
			CreateRealTimeThread(function()
				WaitDataLoaded()
				local err = LoadGame(filename, { save_as_last = true })
				if err then
					OpenPreGameMainMenu()
				end
			end)
		end
		if string.ends_with(filename, ".fbx", true) then
			OpenSceneImportEditor(filename)
		end
	end
end

-- touch

function XDesktop:TouchEvent(event, id, pos)
	local touch = self.touch[id]
	if touch then
		touch.event = event
		touch.pos = pos
	else
		touch = { id = id, event = event, pos = pos }
		self.touch[id] = touch
	end
	if event == "OnTouchEnded" or event == "OnTouchCancelled" then
		self.touch[id] = nil
	end
	
	local result
	if touch.capture then
		result = touch.capture[event](touch.capture, id, pos, touch)
	end
	
	if not result then
		local target = self:UpdateMouseTarget(pos)
		while target do
			if target.window_state ~= "destroying" then
				touch.target = target
				result = target[event](target, id, pos, touch)
				if result then
					break
				end
			end
			target = target.parent
		end
	end
	if result == "capture" then
		touch.capture = touch.target
		result = "break"
	end
	return result
end

-- draw

local UIL = UIL
function XDesktop:Invalidate()
	if self.invalidated then return end
	self.invalidated = true
	UIL.Invalidate()
end

if false then -- debug invalidation
	IgnoreInvalidateSources = {
		"DeveloperInterface.lua",
		"uiConsoleLog.lua",
		"XControl.lua.* SetText",
		"KeyboardEventDispatch",
		"method ChangeHappiness",
	}
	function XDesktop:Invalidate()
		if not self.invalidated then
			local stack = GetStack()
			local show = true
			for _, text in ipairs(IgnoreInvalidateSources) do
				if stack:find(text) then
					show = false
					break
				end
			end
			if show then
				self.invalidated = true
				print(stack)
			end
		end
		UIL.Invalidate()
	end
	function XTranslateText:OnTextChanged(text)
		if not GetParentOfKind(self, "DeveloperInterface") then
			print(string.concat(" ", "TEXT CHANGE", self.text, "-->", text))
		end
	end
end

function XDesktop:InvalidateMeasure(child)
	if self.measure_update then return end
	XActionsHost.InvalidateMeasure(self, child)
	if self.invalidated then return end
	self:RequestLayout()
end

function XDesktop:InvalidateLayout()
	if self.layout_update then return end
	XActionsHost.InvalidateLayout(self)
	if self.invalidated then return end
	self:RequestLayout()
end

function XDesktop:MeasureAndLayout()
	local w, h = self.box:sizexyz()
	self:UpdateMeasure(w, h)
	self:UpdateLayout()
	self:UpdateMouseTarget()
	if self.measure_update or self.layout_update then
		self:UpdateMeasure(w, h)
		self:UpdateLayout()
		self:UpdateMouseTarget()
	end
end

function XDesktop:RequestLayout()
	if IsValidThread(self.layout_thread) then
		Wakeup(self.layout_thread)
	else
		self.layout_thread = CreateRealTimeThread(function(self)
			while true do
				if next(TextStyles) and not self.invalidated then -- if there is a redraw pending let it do the MeasureAndLayout
					PauseInfiniteLoopDetection("XDesktop.MeasureAndLayout")
					procall(self.MeasureAndLayout, self)
					ResumeInfiniteLoopDetection("XDesktop.MeasureAndLayout")
				end
				WaitWakeup()
			end
		end, self)
		if Platform.developer then
			ThreadsSetThreadSource(self.layout_thread, "LayoutThread")
		end
	end
end

function XDesktop:RequestUpdateMouseTarget()
	if IsValidThread(self.mouse_target_thread) then
		Wakeup(self.mouse_target_thread)
	else
		self.mouse_target_thread = CreateRealTimeThread(function(self)
			while true do
				procall(self.UpdateMouseTarget, self)
				WaitWakeup()
			end
		end, self)
	end
end

function XRender()
	if not next(TextStyles) then return end
	
	PauseInfiniteLoopDetection("XRender")
	local desktop = terminal.desktop
	desktop:MeasureAndLayout()
	desktop:DrawWindow(desktop.box)
	ResumeInfiniteLoopDetection("XRender")
end

-- start

function OnMsg.Start()
	terminal.desktop = XDesktop:new()
	terminal.AddTarget(terminal.desktop)
	UIL.Register("XRender", terminal.desktop.terminal_target_priority)
	terminal.desktop:OnSystemSize(UIL.GetScreenSize())
	terminal.desktop:Open()
	Msg("DesktopCreated")
end

-- margin update

function OnMsg.EngineOptionsSaved()
	local desktop = terminal.desktop
	if desktop then
		desktop:InvalidateMeasure()
		desktop:InvalidateLayout()
	end
end

-- debug

if Platform.developer then
	function FormatWindowPath(win)
		if not win then return "" end
		local path = {}
		repeat
			table.insert(path, 1, _InternalTranslate(T(357840043382, "<class> <Id>"), win, false))
			win = win.parent
		until not win
		return table.concat(path, " / ")
	end
end
