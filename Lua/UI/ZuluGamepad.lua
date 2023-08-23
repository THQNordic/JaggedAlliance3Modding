
function OnMsg.XInputInited()
	--lock gamepad thumbsticks while not in gamepad mode to avoid moving the camera
	--(also see OnMsg.GamepadUIStyleChanged in MarsMessengeQuestionBox.lua)
	local lock = GetUIStyleGamepad() and 0 or 1
	hr.XBoxLeftThumbLocked = lock
	hr.XBoxRightThumbLocked = lock
	hr.GamepadMouseSensitivity = 10
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
end

function OnMsg.NewGame()
	ZuluMouseViaGamepadDisableReasons = GetUIStyleGamepad() and {} or { "UIStyle" }
	ZuluMouseViaGamepadEnableReasons = {}

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

function IsZuluMouseViaGamepadEnabled()
	if ZuluMouseViaGamepadDisableReasons and #ZuluMouseViaGamepadDisableReasons > 0 then return false end
	if not ZuluMouseViaGamepadEnableReasons or #ZuluMouseViaGamepadEnableReasons == 0 then return false end
	return true
end

DefineClass.ZuluMouseViaGamepad = {
	__parents = { "MouseViaGamepad" },
	
	LeftClickButton = "ButtonA",
	RightClickButton = "ButtonX",
	DoubleClickTime = 200,
}

local function IsRSScrollButton(button)
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

	local pt = GamepadMouseGetPos()
	local target = terminal.desktop:UpdateMouseTarget(pt)
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
	
	return MouseViaGamepad.OnXButtonDown(self,button, controller_id)
end

function ZuluMouseViaGamepad:OnXButtonUp(button, controller_id)
	if not self.enabled then return end

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

function ShowMouseViaGamepad(show)
	local mouse_win = GetMouseViaGamepadCtrl()
	if not mouse_win and show then
		mouse_win = ZuluMouseViaGamepad:new({}, terminal.desktop)
	end
	if mouse_win then
		if show then
			ForceHideMouseCursor("MouseViaGamepad")
			GamepadMouseSetPos(terminal.GetMousePos())
			mouse_win:SetCursorImage(GetMouseCursor())
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
	T(357598959787, "Invert Satelite View controls"),
	T(965509635524, "Allows you to use the left thumbstick to scroll the map and the right thumbstick to move the cursor."),
	T(613515802678, "Hide selection helpers"),
	T(498814044233, "Hides the selection helper texts in the center of the screen in Tactical View."),
	T(447937688557, "Swap additional controls"),
	T(699900566044, "Swaps the actions done with <LeftTrigger> and <RightTrigger>."),
	
}

function WaitControllerDisconnectedMessage()
	local dialog = CreateMessageBox(
		terminal.desktop,
		T{836013651979, "Active <controller> disconnected", controller = T(704811499954, "Controller")},
		T(925406686039, "Please connect a controller to resume playing.")
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