
function OnMsg.XInputInited()
	--lock gamepad thumbsticks while not in gamepad mode to avoid moving the camera
	--(also see OnMsg.GamepadUIStyleChanged in MarsMessengeQuestionBox.lua)
	local lock = GetUIStyleGamepad() and 0 or 1
	hr.XBoxLeftThumbLocked = lock
	hr.XBoxRightThumbLocked = lock
	hr.GamepadMouseSensitivity = GetAccountStorageOptionValue("GamepadCursorMoveSpeed") or 11
	hr.GamepadMouseAcceleration = 400 -- in percent
	hr.GamepadMouseAccelerationMax = 1000 --  in percent (unlimited)
	hr.GamepadMouseAccelerationExponent = 200
	hr.GamepadMouseSpeedUp = 200 -- in percent
	hr.GamepadMouseSpeedUpTime = 1500
	hr.GamepadMouseSpeedDownTime = 200
	hr.GamepadMouseSpeedUpThreshold = 90
end

function OnMsg.GamepadUIStyleChanged()
	SetDisableMouseViaGamepad(not GetUIStyleGamepad(), "UIStyle")
	ObjModified("GamepadUIStyleChanged")
end

if FirstLoad then
ZuluMouseViaGamepadDisableReasons = false
ZuluMouseViaGamepadEnableReasons = false
ZuluMouseViaGamepadDisableRightClickReasons = false
end

function OnMsg.NewGame()
	ZuluMouseViaGamepadDisableReasons = GetUIStyleGamepad() and {} or { "UIStyle" }
	ZuluMouseViaGamepadEnableReasons = {}
	ZuluMouseViaGamepadDisableRightClickReasons = {}

	-- Some popups transcend game barriers (controller disconnected)
	local persistentDisablingPopups = {}
	for _, popup in ipairs(g_ZuluMessagePopup) do
		if popup.window_state ~= "destroying" then
			SetEnabledMouseViaGamepad(popup.GamepadVirtualCursor, popup)
			SetDisableMouseViaGamepad(not popup.GamepadVirtualCursor, popup)
		end
	end
end

function OnMsg.DoneGame()
	ZuluMouseViaGamepadDisableReasons = false
	ZuluMouseViaGamepadEnableReasons = false
	ZuluMouseViaGamepadDisableRightClickReasons = false
end

function SetDisableMouseViaGamepad(disable, reason)
	if not ZuluMouseViaGamepadDisableReasons then ZuluMouseViaGamepadDisableReasons = {} end

	local existingReasonIdx = table.find(ZuluMouseViaGamepadDisableReasons, reason)
	if existingReasonIdx and not disable then
		table.remove(ZuluMouseViaGamepadDisableReasons, existingReasonIdx)
	elseif not existingReasonIdx and disable then
		table.insert(ZuluMouseViaGamepadDisableReasons, reason)
	end
	
	local isEnabled = IsZuluMouseViaGamepadEnabled()
	ShowMouseViaGamepad(isEnabled)
end

function SetEnabledMouseViaGamepad(enable, reason)
	if not ZuluMouseViaGamepadEnableReasons then ZuluMouseViaGamepadEnableReasons = {} end

	local existingReasonIdx = table.find(ZuluMouseViaGamepadEnableReasons, reason)
	if not existingReasonIdx and enable then
		table.insert(ZuluMouseViaGamepadEnableReasons, reason)
	elseif existingReasonIdx and not enable then
		table.remove(ZuluMouseViaGamepadEnableReasons, existingReasonIdx)
	end
	
	local isEnabled = IsZuluMouseViaGamepadEnabled()
	ShowMouseViaGamepad(isEnabled)
end

function SetDisableMouseRightClickReason(disable, reason)
	if not ZuluMouseViaGamepadDisableRightClickReasons then ZuluMouseViaGamepadDisableRightClickReasons = {} end

	local existingReasonIdx = table.find(ZuluMouseViaGamepadDisableRightClickReasons, reason)
	if not existingReasonIdx and disable then
		table.insert(ZuluMouseViaGamepadDisableRightClickReasons, reason)
	elseif existingReasonIdx and not disable then
		table.remove(ZuluMouseViaGamepadDisableRightClickReasons, existingReasonIdx)
	end
end

function IsZuluMouseViaGamepadEnabled()
	if ZuluMouseViaGamepadDisableReasons and #ZuluMouseViaGamepadDisableReasons > 0 then return false end
	if not ZuluMouseViaGamepadEnableReasons or #ZuluMouseViaGamepadEnableReasons == 0 then return false end
	return true
end

DefineClass.ZuluMouseViaGamepad = {
	__parents = { "MouseViaGamepad" },
	
	LeftClickButton = "ButtonA",
	LeftClickButtonAlt = "TouchPadClick",
	RightClickButton = "ButtonX",
	DoubleClickTime = 250,
}

local function IsRSScrollButton(button)
	local button = GetInvertPDAThumbsShortcut(button)

	return button=="RightThumbUp" or button=="RightThumbUpLeft" or button=="RightThumbUpRight"   
		 or button=="RightThumbDown"  or button=="RightThumbDownLeft" or button=="RightThumbDownRight" 
end

local function GetRSScrollTarget(pt)
	local target =  terminal.desktop.modal_window:GetMouseTarget(pt)
	local scroll = target and GetParentOfKind(target, "XScrollArea")
	return scroll
end

local function ExecRSScrollFn(pt, fn, button, controller_id )
	if IsRSScrollButton(button)  then
		local scroll = GetRSScrollTarget(pt)
		if scroll then
			scroll[fn](scroll, button, controller_id)
			return "break"
		end		
		return true
	end	
end

function ZuluMouseViaGamepad:OnXButtonDown(button, controller_id)
	if not self.enabled then return end
	
	if button == self.LeftClickButtonAlt then
		button = self.LeftClickButton
	end

	local pt = GamepadMouseGetPos()
	local trg = terminal.desktop:UpdateMouseTarget(pt)
	local target = trg
	if IsKindOf(target, "XDragAndDropControl") and target.drag_win then
		target = target.drag_win
		if ExecRSScrollFn(pt, "OnXButtonDown", button, controller_id )  then
			return "break"	
		end
	end
	while target~=terminal.desktop do
		local res = target:OnXButtonDown(button, controller_id)
		if res=="break" then
			return "break"
		end	
		target = target.parent
	end
	
	if not self.visible then
		ForceHideMouseCursor("MouseViaGamepad")
		self:SetVisible(true)
		GamepadMouseSetPos(terminal.GetMousePos())
	end
	
	local mouse_btn = false
	if button == self.LeftClickButton then
		mouse_btn = "L"
	elseif button == self.RightClickButton then
		if #(ZuluMouseViaGamepadDisableRightClickReasons or empty_table) == 0 then
			mouse_btn = "R"
		end
	end

	if mouse_btn then
		local now = now()
		local last_click_time = self.LastClickTimes[mouse_btn]
		self.LastClickTimes[mouse_btn] = now
		local is_double_click = last_click_time and (now - last_click_time) <= self.DoubleClickTime
		if is_double_click then
			local target = trg
			while target~=terminal.desktop do
				local res = target:OnMouseButtonDoubleClick( pt, mouse_btn, "gamepad")
				if res=="break" then
					return "break"
				end	
				target = target.parent
			end
			return terminal.MouseEvent("OnMouseButtonDoubleClick", pt, mouse_btn, "gamepad")
		else
			return terminal.MouseEvent("OnMouseButtonDown", pt, mouse_btn, "gamepad")
		end
	end
	
	return "continue"
end

function ZuluMouseViaGamepad:OnXButtonUp(button, controller_id)
	if not self.enabled then return end

	if button == self.LeftClickButtonAlt then
		button = self.LeftClickButton
	end

	local pt = GamepadMouseGetPos()
	local target = terminal.desktop:UpdateMouseTarget(pt)
	if IsKindOf(target, "XDragAndDropControl") and target.drag_win then
		target = target.drag_win
		if ExecRSScrollFn(pt, "OnXButtonUp", button, controller_id ) then
			return "break"	
		end
	end
	while target and target~=terminal.desktop do
		local res = target:OnXButtonUp(button, controller_id)
		if res=="break" then
			return "break"
		end	
		target = target.parent
	end
	return MouseViaGamepad.OnXButtonUp(self, button, controller_id)
end

function ZuluMouseViaGamepad:OnXButtonRepeat(button, controller_id)
	if not self.enabled then return end

	local pt = GamepadMouseGetPos()
	local target = terminal.desktop:UpdateMouseTarget(pt)
	if IsKindOf(target, "XDragAndDropControl") and target.drag_win then
		target = target.drag_win
		if ExecRSScrollFn(pt, "OnXButtonRepeat", button, controller_id ) then
			return "break"	
		end
	end
	
	while target and target~=terminal.desktop do
		local res = target:OnXButtonRepeat(button, controller_id)
		if res=="break" then
			return "break"
		end	
		target = target.parent
	end
	return "continue"
end

function ZuluMouseViaGamepad:OnMousePos(pt)
	return "continue"
end

MouseViaGamepadHideSkipReasons["GamepadActive"] = true
MouseViaGamepadHideSkipReasons["MouseDisconnected"] = true

function ShowMouseViaGamepad(show)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win and show then
		mouse_win = ZuluMouseViaGamepad:new({}, terminal.desktop)
	end
	if mouse_win then
		if show then
			ForceHideMouseCursor("MouseViaGamepad")
			
			local _, val = terminal.desktop:GetMouseTarget(GamepadMouseGetPos())
			local cursor = val
			if (cursor or "") == "" then
				cursor = const.DefaultMouseCursor
			end

			mouse_win:SetCursorImage(cursor)
			mouse_win:SetEnabled(true)
			
			-- Consoles with no mouse attached will not have this thread active.
			-- We start the rollover thread and assign it both to the global and
			-- as managed by the UI in order to ensure it is cleaned up properly and
			-- also it wont duplicate if an actual mouse is connected to the console.
			if not IsValidThread(RolloverThread) then
				mouse_win:CreateThread("rollover-thread", MouseRollover)
				RolloverThread = mouse_win:GetThread("rollover-thread")
			end
		else
			DeleteMouseViaGamepad()
			UnforceHideMouseCursor("MouseViaGamepad")
			XDestroyRolloverWindow(true)
			terminal.desktop.last_mouse_pos = terminal.GetMousePos()
			terminal.SetMousePos(GamepadMouseGetPos())
		end
		hr.GamepadMouseEnabled = show
	end
end

DefineClass.VirtualCursorManager = {
	__parents = { "XWindow" },
	properties = {
		{ id = "Reason", editor = "text", default = "", help = "Reason for disable or enable of the virtual mouse." },
		{ id = "ActionType", name = "Enable", editor = "bool", default = true, help = "true: enable virtual mouse, false: disable virtual mouse" },
	}
}

function VirtualCursorManager:Open()
	XWindow.Open(self)
	if self.ActionType then
		SetEnabledMouseViaGamepad(true, self.Reason)
	else
		SetDisableMouseViaGamepad(true, self.Reason)
	end
end

function VirtualCursorManager:OnDelete()
	if self.ActionType then
		SetEnabledMouseViaGamepad(false, self.Reason)
	else
		SetDisableMouseViaGamepad(false, self.Reason)
	end
end

function OnMsg.ClassesGenerate(classes)
	table.insert(classes.SplashScreen.__parents, "ZuluModalDialog")
end
	
local lCommonSplashText = SplashText
function SplashText(...)
	local dlg = lCommonSplashText(...)
	SetDisableMouseViaGamepad(true, "splash")
	dlg.OnDelete = function()
		SetDisableMouseViaGamepad(false, "splash")
	end
	return dlg
end

texts_to_add_in_loc = {
	--Additional Options
	T(613515802678, "Hide selection helpers"),
	T(498814044233, "Hides the selection helper texts in the center of the screen in Tactical View."),
}

function WaitControllerDisconnectedMessage()
	local dialog = CreateMessageBox(
		terminal.desktop,
		T{836013651979, "Active <controller> disconnected", controller = Platform.playstation and g_PlayStationWirelessControllerText or T(704811499954, "Controller")},
		Platform.playstation and T(306576723489, --[[PS controller message]] "Please connect a controller to resume playing.") or T(925406686039, "Please connect a controller to resume playing.")
	)
	dialog:SetZOrder(BaseLoadingScreen.ZOrder + 1)
	dialog:SetModal(true)
	dialog:SetDrawOnTop(true)
	local _, _, controller_id = dialog:Wait()
	return controller_id
end

function ConsolePlatformControllerDisconnected()
	XInput.ControllerEnable("all", true)
	if IsValidThread(SwitchControlQuestionThread) then return end

	SwitchControlQuestionThread = CreateRealTimeThread(function()
		if not netInGame then 
			SetPauseLayerPause(true, "ControllerDisconnected")
		end
		local controller_id
		while true do
			controller_id = WaitControllerDisconnectedMessage()
			if controller_id then
				break
			end
			Sleep(5)
		end
		XInput.ControllerEnable("all", false)
		XInput.ControllerEnable(controller_id, true)
		if not netInGame then
			SetPauseLayerPause(false, "ControllerDisconnected")
		end
	end)
end

local function lGetMousePosVirtualAware()
	if GetUIStyleGamepad() then
		if IsMouseViaGamepadActive() then
			return GamepadMouseGetPos()
		else
			return point20
		end
	end
	return false
end

-- Prevent moving the hardware mouse from showing rollovers etc.
local oldMouseEvent = XDesktop.MouseEvent
function XDesktop:MouseEvent(event, pt, button, meta, ...)
	if event == "OnMouseButtonDown" and GetUIStyleGamepad() and meta ~= "gamepad" then
		SwitchControls(false)
	end

	pt = lGetMousePosVirtualAware() or pt
	return oldMouseEvent(self, event, pt, button, meta, ...)
end

local function lMouseSwitchControlSwitchProc()
	local currentTime = RealTime()
	
	local previous_hardwareMouse_pos = HardwareGetMousePos()
	while true do
		local hardwareMousePos = HardwareGetMousePos()

		local scaledThreshold = MulDivRound(200, GetUIScale(), 1000)
		if hardwareMousePos:Dist(previous_hardwareMouse_pos) > scaledThreshold then
			DelayedCall(0, SwitchControls, false)
			break
		end
		
		if RealTime() - currentTime > 1000 then
			previous_hardwareMouse_pos = hardwareMousePos
		end
		
		Sleep(15)
	end
end

if FirstLoad then
	HardwareGetMousePos = terminal.GetMousePos
	function terminal.GetMousePos()
		return lGetMousePosVirtualAware() or HardwareGetMousePos()
	end
	
	HardwareSetMousePos = terminal.SetMousePos
	function terminal.SetMousePos(p)
		local recreateSwitchThread = false
		if IsValidThread(MouseMoveToSwitchControlsThread) then
			DeleteThread(MouseMoveToSwitchControlsThread)
			MouseMoveToSwitchControlsThread = false
			recreateSwitchThread = true
		end
		
		HardwareSetMousePos(p)
		
		if recreateSwitchThread then
			MouseMoveToSwitchControlsThread = CreateRealTimeThread(lMouseSwitchControlSwitchProc)
		end
	end
end

function ZuluMouseViaGamepad:UpdateMousePosThread()
	--GamepadMouseSetPos(GamepadMouseGetPos())

	local previous_pos
	while true do
		WaitNextFrame()
		local pos = GamepadMouseGetPos()
		if pos ~= previous_pos then
			--terminal.SetMousePos(pos)
			self.parent:MouseEvent("OnMousePos", pos)
			
			previous_pos = pos
		end
	end
end

if FirstLoad then
MouseMoveToSwitchControlsThread = false
end

function OnMsg.GamepadUIStyleChanged()
	if IsValidThread(MouseMoveToSwitchControlsThread) then
		DeleteThread(MouseMoveToSwitchControlsThread)
	end
	if not GetUIStyleGamepad() then return end
	
	GamepadMouseSetPos(HardwareGetMousePos())
	MouseMoveToSwitchControlsThread = CreateRealTimeThread(lMouseSwitchControlSwitchProc)
end

function MouseViaGamepad:OnXNewPacket(_, controller_id, last_state, current_state)
	--nop override common
end

function OnMsg.OnXInputControllerDisconnected(controller)
	XInput.ControllerEnable("all", true)
end

function OnMsg.OnXInputControllerConnected(controller)
	local _, id = GetActiveGamepadState()
	if id then
		XInput.ControllerEnable("all", false)
		XInput.ControllerEnable(id, true)
	end
end