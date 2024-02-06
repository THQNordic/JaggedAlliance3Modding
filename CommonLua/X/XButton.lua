DefineClass.XButton = {
	__parents = { "XContextControl" },

	properties = {
		{ category = "General", id = "RepeatStart", name = "Start repeating time", editor = "number", default = 0, },
		{ category = "General", id = "RepeatInterval", name = "Repeat interval", editor = "number", default = 0, },
		{ category = "General", id = "OnPressEffect", editor = "choice", default= "", items = {"", "close", "action"}, },
		{ category = "General", id = "OnPressParam", editor = "text", default = "" },
		{ category = "General", id = "OnPress", name = "On press", editor = "func", params = "self, gamepad" },
		{ category = "General", id = "AltPress", name = "Allow alternative press", editor = "bool", default = false, },
		{ category = "General", id = "OnAltPress", name = "On alt press", editor = "func", params = "self, gamepad" },
		
		{ category = "Visual", id = "RolloverBackground", name = "Rollover background", editor = "color", default = RGBA(255, 255, 255, 255), },
		{ category = "Visual", id = "RolloverBorderColor", name = "Rollover border color", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "PressedBackground", name = "Pressed background", editor = "color", default = RGBA(255, 255, 255, 255), },
		{ category = "Visual", id = "PressedBorderColor", name = "Pressed border color", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "PressedOffset", name = "Pressed offset", editor = "number", default = 1, },
	},

	Background = RGBA(255, 255, 255, 255),
	FocusedBackground = RGBA(255, 255, 255, 255),
	MouseCursor = "CommonAssets/UI/HandCursor.tga",
	state = "mouse-out",
	ChildrenHandleMouse = false,
	RolloverOnFocus = true,
	action = false,
	touch_press_dist = 20*20, -- square for max move distance before press
	
	AltPressButton = "ButtonX",
	AltPressButtonUp = "-ButtonX",
	AltPressButtonDown = "+ButtonX",
}

function XButton:Open(...)
	local host = GetActionsHost(self, true)
	if not self.action and self.OnPressEffect == "action" then
		self.action = host and host:ActionById(self.OnPressParam) or nil
	end
	if self:IsActionDisabled(host) then
		self:SetEnabled(false)
	end
	if self.action and self.action.ActionGamepadHold and self.action.ActionGamepad then
		host.action_hold_buttons = host.action_hold_buttons  or {}
		host.action_hold_buttons[self.action.ActionId] = self
	end

	if self.action and self.action.OnAltAction then
		self.AltPress = true
	end
	XContextControl.Open(self, ...)
end

function XButton:IsActionDisabled(host, ...)
	return self.action and self.action:ActionState(host, ...) == "disabled"
end

function XButton:Press(alt, force, gamepad)
	if alt and not self.AltPress then return end
	self:PlayActionFX(force)
	if not self.enabled and not force then
		return
	end
	if alt then
		self:OnAltPress(gamepad)
	else
		self:OnPress(gamepad)
	end
	if self.window_state ~= "destroying" then
		local host = GetActionsHost(self, true)
		if self:IsActionDisabled(host) then
			self:SetEnabled(false)
		end
	end
end

function XButton:OnPress(gamepad)
	local effect = self.OnPressEffect
	if effect == "close" then
		local win = self.parent
		while win and not win:IsKindOf("XDialog") do
			win = win.parent
		end
		if win then
			win:Close(self.OnPressParam ~= "" and self.OnPressParam or nil)
		end
	elseif self.action then
		local host = GetActionsHost(self, true)
		if host then
			host:OnAction(self.action, self, gamepad)
		end
	end
end

function XButton:OnAltPress(gamepad)
	if self.action and self.action.OnAltAction then
		local host = GetActionsHost(self, true)
		if host then
			self.action:OnAltAction(host, self, gamepad)
		end
	end
end

function XButton:OnButtonDown(alt, mouse)
	if alt and not self.AltPress then return end
	if not self.enabled then
		self:Press(alt, nil, not mouse) --play sound FX
		return "break"
	end
	if self.state == "mouse-in" or self.state == "mouse-out" then 
		self.state = "pressed-in"
		if mouse then
			self.desktop:SetMouseCapture(self)
		end
		self:Invalidate()
		if self.RepeatStart > 0 then
			self:DeleteThread("repeat")
			self:CreateThread("repeat", function(self, alt) 
				Sleep(self.RepeatStart)
				while self.state == "pressed-in" or self.state == "pressed-out" do
					self:Press(alt, nil, not mouse)
					Sleep(self.RepeatInterval)
				end
			end, self, alt)
		end
	end
	return "break"
end

function XButton:OnButtonUp(alt, mouse)
	if alt and not self.AltPress then return end
	if self.state == "pressed-in" then
		self.state = "mouse-in"
		self:Invalidate()
		if mouse then
			self.desktop:SetMouseCapture()
		end
		self:Press(alt, nil, not mouse)
	elseif self.state == "pressed-out" then 
		self.state = "mouse-out"
		self:Invalidate()
		if mouse then
			self.desktop:SetMouseCapture()
		end
	end
	return "break"
end

function XButton:OnMouseButtonDown(pt, button)
	if button == "L" then
		return self:OnButtonDown(false, true)
	elseif button == "R" then
		return self:OnButtonDown(true, true)
	end
end

function XButton:OnMouseButtonUp(pt, button)
	if button == "L" then
		return self:OnButtonUp(false, true)
	elseif button == "R" then
		return self:OnButtonUp(true, true)
	end
end

function XButton:OnSetRollover(rollover)
	XControl.OnSetRollover(self, rollover)
	if rollover then
		if self.state == "mouse-out" then
			self.state = "mouse-in"
		elseif self.state == "pressed-out" then
			self.state = "pressed-in"
		end
	else
		if self.state == "mouse-in" then
			self.state = "mouse-out"
		elseif self.state == "pressed-in" then
			self.state = "pressed-out"
		end
	end
	self:Invalidate()
end

function XButton:OnCaptureLost()
	if self.state == "pressed-in" then
		self.state = "mouse-in"
	elseif self.state == "pressed-out" then
		self.state = "mouse-out"
	end
	self:Invalidate()
end

-- touch
function XButton:OnTouchBegan(id, pos, touch)
	if self.state == "mouse-in" or self.state == "mouse-out" then
		touch.start_pos = pos
		touch.start_time = RealTime()
		self.state = "pressed-out"
		self:OnTouchMoved(id, pos, touch)
		return "capture"
	end
end

function XButton:OnTouchMoved(id, pos, touch)
	if touch.capture == self then
		local dist_diff = pos:Dist2D2(touch.start_pos)
		if dist_diff > self.touch_press_dist then
			-- if there is an ancestor of type XScrollArea, allow it to be scrolled
			local scroll_area = GetParentOfKind(self, "XScrollArea")
			if scroll_area then
				self:OnTouchCancelled(id, pos, touch)
				touch.capture = nil -- release capture
				touch.target = scroll_area -- target is now the scroll area
				return scroll_area:OnTouchBegan(id, pos, touch)
			end
		end
		if self.state == "pressed-in" and not self:PointInWindow(pos) then
			self.state = "pressed-out"
			self:Invalidate()
			self:PlayHoverFX(false)
		elseif self.state == "pressed-out" and self:PointInWindow(pos) then
			self.state = "pressed-in"
			self:Invalidate()
			self:PlayHoverFX(true)
		end
		return "break"
	end
end

function XButton:OnTouchEnded(id, pos, touch)
	self:OnTouchMoved(id, pos, touch)
	if self.state == "pressed-in" then
		self:Press(false)
	end
	return self:OnTouchCancelled(id, pos, touch)
end

function XButton:OnTouchCancelled(id, pos, touch)
	if self.state ~= "mouse-out" then
		if self.state == "pressed-in" then
			self:PlayHoverFX(false)
		end
		self.state = "mouse-out"
		self:Invalidate()
		return "break"
	end
end

function XButton:OnShortcut(shortcut, source, ...)
	if shortcut == "Enter" or shortcut == "Space" or shortcut == "ButtonA" then
		self:Press(false)
		return "break"
	elseif self.AltPress and (shortcut == "Alt-Enter" or shortcut == "Alt-Space" or shortcut == self.AltPressButton) then
		self:Press(true)
		return "break"
	elseif shortcut == "+ButtonA" then
		return self:OnButtonDown(false)
	elseif shortcut == self.AltPressButtonDown then
		return self:OnButtonDown(true)
	elseif shortcut == "-ButtonA" then
		return self:OnButtonUp(false)
	elseif shortcut == self.AltPressButtonUp then
		return self:OnButtonUp(true)
	end
end

function XButton:CalcBackground()
	if not self.enabled then return self.DisabledBackground end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBackground
	end
	if self.state == "mouse-in" then
		return self.RolloverBackground
	end
	local FocusedBackground, Background = self.FocusedBackground, self.Background
	if FocusedBackground == Background then return Background end
	return self:IsFocused() and FocusedBackground or Background
end

function XButton:CalcBorderColor()
	if not self.enabled then return self.DisabledBorderColor end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBorderColor
	end
	if self.state == "mouse-in" then
		return self.RolloverBorderColor
	end
	local FocusedBorderColor, BorderColor = self.FocusedBorderColor, self.BorderColor
	if FocusedBorderColor == BorderColor then return BorderColor end
	return self:IsFocused() and FocusedBorderColor or BorderColor
end

function XButton:GetRolloverTemplate()
	local template = self.RolloverTemplate
	if template ~= "" then return template end
	local action = self.action
	return action and action:GetRolloverTemplate() or ""
end

function XButton:GetRolloverText()
	local enabled = self:GetEnabled()
	local text = not enabled and self.RolloverDisabledText ~= "" and self.RolloverDisabledText or self.RolloverText
	if text ~= "" then return text end
	local action = self.action
	local disabled_text = action and action:GetRolloverDisabledText()
	return action and (not enabled and disabled_text ~= "" and disabled_text or action:GetRolloverText()) or ""
end

function OnMsg.ClassesPostprocess()
	if not config.GamepadAltPressUseButtonY then return end
	ClassDescendants("XButton", function(class_name, class)
		class.AltPressButton = "ButtonY"
		class.AltPressButtonUp = "-ButtonY"
		class.AltPressButtonDown = "+ButtonY"
	end)
	XButton.AltPressButton = "ButtonY"
	XButton.AltPressButtonUp = "-ButtonY"
	XButton.AltPressButtonDown = "+ButtonY"
end

----- XTextButton

DefineClass.XTextButton = {
	__parents = { "XButton", "XFrame", "XEmbedIcon", "XEmbedLabel" },
	properties = {
		{ category = "Image", id = "ColumnsUse", editor = "text", default = "aaaaa", }, -- 'help' is generated below
		{ category = "Image", id = "ShowGamepadShortcut", editor = "bool", default = false, },
		{ category = "Visual", id = "ShowKeyboardShortcut", editor = "bool", default = false, },
		{ category = "Visual", id = "KeyboardShortcutTextStyle", editor = "text", default = "", },
	},
	ContextUpdateOnOpen = true,
	LayoutMethod = "HList",
	LayoutHSpacing = 2,
	HandleMouse = true,
	SqueezeX = false,
	SqueezeY = false,
}

function XTextButton:Init()
	self.idLabel:SetHAlign("center")
	self:SetColumnsUse(self.ColumnsUse)
end

function XTextButton:OnHoldButtonTick(i, shortcut)
	if not self.action or not self.action.ActionGamepadHold then return end
	self.idHoldShortcut:SetVisible(not not i)
	
	if i then 
		self.idHoldShortcut:SetImage("UI/DesktopGamepad/hold" .. i)
	end
end

function XTextButton:Open()
	XButton.Open(self)
	local action = self.action
	if action then
		local action_ui_style = action.ActionUIStyle
		if self.ShowGamepadShortcut and (action_ui_style == "auto" and GetUIStyleGamepad() or action_ui_style == "gamepad") and action.ActionGamepad ~= "" then
			local keys = SplitShortcut(action.ActionGamepad)
			for i = 1, #keys do
				local image_path, scale = GetPlatformSpecificImagePath(keys[i])
				local img = XImage:new({
					Id = "idActionShortcut",
					Image = image_path,
					ZOrder = 0,
					ImageScale = point(scale, scale),
					enabled = self.enabled,
				}, self)
				if action.ActionGamepadHold then
					local over_img = XImage:new({
						Id = "idHoldShortcut",
						Image = "UI/DesktopGamepad/hold0",
						ZOrder = 0,
						ImageScale = point(scale, scale),
						enabled = self.enabled,
					}, self)
				end
				img:Open()
				if action.ActionGamepadHold then
					over_img:Open()
				end
			end
		elseif self.ShowKeyboardShortcut and (action_ui_style == "auto" and not GetUIStyleGamepad() or action_ui_style == "keyboard") and action.ActionShortcut ~= "" then
			local label = XLabel:new({
				Id = "idActionShortcut",
				ZOrder = 0,
				TextStyle = self.KeyboardShortcutTextStyle ~= "" and self.KeyboardShortcutTextStyle or self.TextStyle,
				VAlign = "center",
				Translate = true,
				enabled = self.enabled,
			}, self):Open()
			local name = KeyNames[VKStrNamesInverse[action.ActionShortcut]]
			label:SetText(T{629765447024, "<name>", name = name})
		end
	end
end

function XTextButton:SetText(text)
	self.Text = text
	local label = self:ResolveId("idLabel")
	if label then
		label:SetDock(text == "" and "ignore" or false)
		label:SetText(text)
	end
end

local a_charcode = string.byte("a")
function XTextButton:SetColumnsUse(columns_use)
	local max = 1
	for i = 1, #columns_use do
		max = Max(max, string.byte(columns_use, i))
	end
	self.ColumnsUse = columns_use
	self.Columns = max - a_charcode + 1
	self:Invalidate()
end

function XTextButton:SetColumn()
	assert(false)
end

function XTextButton:SetRollover(rollover)
	XButton.SetRollover(self, rollover)
	local label = self:ResolveId("idLabel")
	if label then
		label:SetRollover(rollover)
	end
end

function XTextButton:OnSetRollover(rollover)
	XButton.OnSetRollover(self, rollover)
end

local state_to_column = {
	["mouse-out"  ] = 1,
	["mouse-in"   ] = 2,
	["pressed-out"] = 3,
	["pressed-in" ] = 4,
	["disabled"   ] = 5,
}

function XTextButton:GetColumn()
	local column = state_to_column[self.enabled and self.state or "disabled"]
	return (string.byte(self.ColumnsUse, column) or a_charcode) - a_charcode + 1
end

do
	local columns_use_prop = table.find_value(XTextButton.properties, "id", "ColumnsUse")
	local column_to_state = table.invert(state_to_column)
	columns_use_prop.help = ""
	for i=1,#column_to_state do
		columns_use_prop.help = string.format("%s%d - %s\n", columns_use_prop.help, i, column_to_state[i])
	end
end

----- XStateButton

DefineClass.XStateButton = {
	__parents = { "XTextButton" },
	TextColor = RGB(32, 32, 32),
	IconColor = RGB(32, 32, 32),
	DisabledTextColor = RGBA(32, 32, 32, 128),
	DisabledIconColor = RGBA(32, 32, 32, 128),
	Icon = "CommonAssets/UI/check-40.tga",
	IconScale = point(480, 480),
	IconRows = 2,
}

function XStateButton:OnRowChange(row)
end

function XStateButton:OnPress()
	local row = self.IconRow + 1
	if row > self.IconRows then
		row = 1
	end
	self:SetIconRow(row)
	self:OnRowChange(row)
	XTextButton.OnPress(self)
end


----- XCheckButton

DefineClass.XCheckButton = {
	__parents = { "XStateButton" },
	properties = {
		{ category = "General", id = "Check", editor = "bool", default = false, },
		{ category = "General", id = "OnChange", name = "On change", editor = "func", params = "self, check" },
	},
	Background = RGBA(0, 0, 0, 0),
	RolloverBackground = RGBA(0, 0, 0, 0),
	FocusedBackground = RGBA(0, 0, 0, 0),
	PressedBackground = RGBA(0, 0, 0, 0),
}

function XCheckButton:SetCheck(check)
	self:SetIconRow(check and 2 or 1)
end

function XCheckButton:GetCheck()
	return self.IconRow ~= 1
end

XCheckButton.SetToggled = XCheckButton.SetCheck

function XCheckButton:OnChange(check)
end

function XCheckButton:OnRowChange(state)
	self:OnChange(state ~= 1)
end


----- XToggleButton

DefineClass.XToggleButton = {
	__parents = { "XTextButton" },

	properties = {
		{ category = "General", id = "Toggled", editor = "bool", default = false, },
		{ category = "General", id = "OnChange", name = "On change", editor = "func", params = "self, toggled" },
		{ category = "Visual", id = "ToggledBackground", name = "Toggled background", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "ToggledBorderColor", name = "Toggled border color", editor = "color", default = RGBA(0, 0, 0, 0), },
	},
}

function XToggleButton:OnPress()
	self:SetToggled(not self.Toggled)
	XTextButton.OnPress(self)
end

function XToggleButton:SetToggled(toggled)
	toggled = toggled or false
	if self.Toggled ~= toggled then
		self.Toggled = toggled
		self:OnChange(self.Toggled)
		self:Invalidate()
	end
end

function XToggleButton:OnChange(toggled)
end

function XToggleButton:CalcBackground()
	return self.Toggled and self.ToggledBackground or XTextButton.CalcBackground(self)
end

function XToggleButton:CalcBorderColor()
	return self.Toggled and self.ToggledBorderColor or XTextButton.CalcBorderColor(self)
end
