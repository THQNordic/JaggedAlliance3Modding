local max_thumb_value = (1 << 15) - 1

DefineClass.MouseViaGamepad = {
	__parents = { "XWindow", "TerminalTarget" },
	properties = {
		{ category = "General", id = "enabled", name = "Enabled", editor = "bool", default = false },
	},
	
	Id = "idMouseViaGamepad",
	IdNode = true,
	HandleMouse = false,
	Dock = "box",
	ZOrder = 10000000, -- above everything, even above loading screens
	DrawOnTop = true,
	Clip = false,
	UseClipBox = false,
	
	LeftClickButton = "ButtonA",
	RightClickButton = "ButtonB",
	LastClickTimes = false,
	DoubleClickTime = 300, --ms
}

function MouseViaGamepad:Init()
	terminal.AddTarget(self)
	
	self.LastClickTimes = { }
	
	local image = XImage:new({
		Id = "idCursor",
		HAlign = "left",
		VAlign = "top",
		Clip = false,
		UseClipBox = false,
	}, self)
	image:AddDynamicPosModifier({id = "cursor", target = "gamepad"})
end

function MouseViaGamepad:Done()
	terminal.RemoveTarget(self)
end

function MouseViaGamepad:OnXNewPacket(_, controller_id, last_state, current_state)
	if not self.enabled then return end
	
	local left_trigger = current_state.LeftTrigger > 0
	local right_trigger = current_state.RightTrigger > 0
	hr.GamepadMouseEnabled = not left_trigger and not right_trigger
end

function MouseViaGamepad:OnXButtonDown(button, controller_id)
	if not self.enabled then return end
	
	if not self.visible then
		ForceHideMouseCursor("MouseViaGamepad")
		self:SetVisible(true)
		GamepadMouseSetPos(terminal.GetMousePos())
	end
	
	local mouse_btn = (button == self.LeftClickButton and "L") or (button == self.RightClickButton and "R")
	if mouse_btn then
		local pt = GamepadMouseGetPos()
		
		local now = now()
		local last_click_time = self.LastClickTimes[mouse_btn]
		self.LastClickTimes[mouse_btn] = now
		local is_double_click = last_click_time and (now - last_click_time) <= self.DoubleClickTime
		if is_double_click then
			return terminal.MouseEvent("OnMouseButtonDoubleClick", pt, mouse_btn, "gamepad")
		else
			return terminal.MouseEvent("OnMouseButtonDown", pt, mouse_btn, "gamepad")
		end
	end
	return "continue"
end

function MouseViaGamepad:OnXButtonUp(button, controller_id)
	local mouse_btn = (button == self.LeftClickButton and "L") or (button == self.RightClickButton and "R")
	if mouse_btn then
		local pt = GamepadMouseGetPos()
		return terminal.MouseEvent("OnMouseButtonUp", pt, mouse_btn)
	end
	return "continue"
end

function MouseViaGamepad:OnMousePos(pt)
	if not self.enabled then return end
	
	if self.visible then
		UnforceHideMouseCursor("MouseViaGamepad")
		self:SetVisible(false)
	end
	GamepadMouseSetPos(pt)
	
	return "continue"
end

function MouseViaGamepad:SetEnabled(enabled)
	self.enabled = enabled
	hr.GamepadMouseEnabled = enabled
	if enabled then
		if not self:IsThreadRunning("UpdateMousePosThread") then
			self:CreateThread("UpdateMousePosThread", self.UpdateMousePosThread, self)
		end
	else
		UnforceHideMouseCursor("MouseViaGamepad")
		if self:IsThreadRunning("UpdateMousePosThread") then
			self:DeleteThread("UpdateMousePosThread")
		end
	end
end

function MouseViaGamepad:SetCursorImage(image)
	self.idCursor:SetImage(image)
end

function MouseViaGamepad:UpdateMousePosThread()
	GamepadMouseSetPos(terminal.GetMousePos())

	local previous_pos
	while true do
		WaitNextFrame()
		local pos = GamepadMouseGetPos()
		if pos ~= previous_pos then
			terminal.SetMousePos(pos)
			self.parent:MouseEvent("OnMousePos", pos)
			
			previous_pos = pos
		end
	end
end

----------------------
function GetMouseViaGamepadCtrl()
	return terminal.desktop and rawget(terminal.desktop, "idMouseViaGamepad")
end

MouseViaGamepadHideSkipReasons = {
	["MouseViaGamepad"] = true,
}

function OnMsg.ShowMouseCursor(visible)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win then return end
	
	local show = not not next(ShowMouseReasons)
	
	local force_hide
	for reason in pairs(ForceHideMouseReasons) do
		if not MouseViaGamepadHideSkipReasons[reason] then
			force_hide = true
			break
		end
	end
	
	local my_visible = show and not force_hide
	
	mouse_win:SetVisible(my_visible)
end

function OnMsg.MouseCursor(cursor)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win then return end
	
	local path, name, ext = SplitPath(cursor)
	--local gamepad_cursor = string.format("%s%s_pad%s", path, name, ext)
	local gamepad_cursor = string.format("%s%s%s", path, name, ext)
	mouse_win:SetCursorImage(gamepad_cursor)
end

function ShowMouseViaGamepad(show)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win and show then
		mouse_win = MouseViaGamepad:new({}, terminal.desktop)
	end
	if mouse_win then
		if show then
			ForceHideMouseCursor("MouseViaGamepad")
			mouse_win:SetVisible(true)
			GamepadMouseSetPos(terminal.GetMousePos())
		end	
		mouse_win:SetEnabled(show)
	end
end

function DeleteMouseViaGamepad()
	local mouse_win = GetMouseViaGamepadCtrl()
	if mouse_win then
		mouse_win:delete()
	end	
end

function IsMouseViaGamepadActive()
	return hr.GamepadMouseEnabled == true or hr.GamepadMouseEnabled == 1
end
