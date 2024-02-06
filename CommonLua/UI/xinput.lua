if not config.XInput then
	XInput = {
	 	MaxControllers = function() return 0 end,
	 	IsControllerConnected = function() return false end,
		ControllerEnable = function() return false end,
	 	SetRumble = function() end,
	 	__GetState = function() end,
	 	IsEnabled = function() return false end,
		IsCtrlButtonPressed = function() return false end,
	}
	XEvent = function() end
end

XInput.Buttons = {
	"ButtonA", "ButtonB", "ButtonX", "ButtonY",
	"LeftThumbClick", "RightThumbClick", "TouchPadClick",
	"Start", "Back", "LeftShoulder", "RightShoulder",
	"DPadLeft", "DPadRight", "DPadUp", "DPadDown",
}
XInput.AnalogsAsButtons = { "LeftTrigger", "RightTrigger" }
XInput.AnalogsAsButtonsLevel = 64
--Thumb events are called like "LeftThumbDownRight"
XInput.ThumbsAsButtons = {"LeftThumb", "RightThumb"}
XInput.ThumbsAsButtonsLevel = 16384
XInput.LeftThumbDirectionButtons = {"LeftThumbUp", "LeftThumbUpRight", "LeftThumbRight", "LeftThumbDownRight", "LeftThumbDown", "LeftThumbDownLeft", "LeftThumbLeft", "LeftThumbUpLeft"}
XInput.RightThumbDirectionButtons = {"RightThumbUp", "RightThumbUpRight", "RightThumbRight", "RightThumbDownRight", "RightThumbDown", "RightThumbDownLeft", "RightThumbLeft", "RightThumbUpLeft"}
XInput.RepeatButtonTime = 250
XInput.InitialRepeatButtonTime = 350
XInput.TimeBeforeAcceleration = 700
XInput.RepeatButtonTimeAccelerated = 50

XInput.LeftThumbToDirection = {
	["LeftThumbUp"] = "DPadUp",
	["LeftThumbDown"] = "DPadDown",
	["LeftThumbLeft"] = "DPadLeft",
	["LeftThumbRight"] = "DPadRight",
}

if FirstLoad then
	XInput.CurrentState = {}
	XInput.defaultState = {
		DPadLeft = false,
		DPadRight = false,
		DPadUp = false,
		DPadDown = false,
		A = false,
		B = false,
		X = false,
		Y = false,
		LeftThumbClick = false,
		RightThumbClick = false,
		TouchPadClick = false,
		Start = false,
		Back = false,
		LeftShoulder = false,
		RightShoulder = false,
		LeftTrigger = 0,
		RightTrigger = 0,
		LeftThumb = point20,
		RightThumb = point20,
	}
	XInput.defaultState.__index = XInput.defaultState
	XInput.UpdateStateFunc = XInput.__GetState
	
	XInput.Callback = {}
	XInput.ComboCache = {}
	XInput.InitialButtonPressTime = {}
	XInput.ButtonPressTime = {}
	XInput.RepeatButtonTimeSpecific = {}
	XInput.InitialRepeatButtonTimeSpecific = {}
	XInput.IncompatibleButtons = {}
	XInput.LastPressTime = 0

	s_XInputControllersConnected = 0
end

function IsXInputControllerConnected()
	return s_XInputControllersConnected > 0
end

local orig_XInput_ControllerEnable = XInput.ControllerEnable
function XInput.ControllerEnable(who, bEnable)
	if who == "all" then
		ActiveController = false
		for i = 0, XInput.MaxControllers()-1 do
			orig_XInput_ControllerEnable(i, bEnable)
		end	
	else
		assert(type(who)=="number")
		ActiveController = who
		orig_XInput_ControllerEnable(who, bEnable)
	end
end

if not config.XInput then return end

local empty_state = { LeftThumb = point20, RightThumb = point20, LeftTrigger = 0, RightTrigger = 0}

function OnMsg.Start()
	s_XInputControllersConnected = 0
	for nCtrlId = 0, XInput.MaxControllers() - 1 do
		if XInput.IsControllerConnected(nCtrlId) then
			s_XInputControllersConnected = s_XInputControllersConnected + 1
			XInput.CurrentState[nCtrlId] = empty_state
		else
			XInput.CurrentState[nCtrlId] = "disconnected"
		end
		XInput.ButtonPressTime[nCtrlId] = {}
		XInput.InitialButtonPressTime[nCtrlId] = {}
	end
	Msg("XInputInitialized")
end

--- Input devices disconnection handling ---
if (FirstLoad or ReloadForDlc) and config.AutoControllerHandling == nil then
	config.AutoControllerHandling = not Platform.developer
end
config.AutoControllerHandlingType = config.AutoControllerHandlingType or "popup" -- popup or auto

if FirstLoad then
	SwitchControlQuestionThread = false
end

function SwitchControls(gamepad)
	if AccountStorage and AccountStorage.Options then
		AccountStorage.Options.Gamepad = gamepad
	end
	SaveAccountStorage(5000)
	Msg("ApplyAccountOptions")
end

function UpdateActiveController()
	if GetUIStyleGamepad() then
		for i=0,XInput.MaxControllers()-1 do
			local present = XInput.IsControllerConnected(i)
			if present then
				XPlayerActivate(i)
				return
			end
		end
	end
	XPlayerActivate(false)
end

if not Platform.console then
	OnMsg.GamepadUIStyleChanged = UpdateActiveController

	function OnMsg.OnXInputControllerDisconnected(id)
		if not config.AutoControllerHandling or ActiveController ~= id or not GetUIStyleGamepad() then return end
		if config.AutoControllerHandlingType == "popup" then
			if not IsValidThread(SwitchControlQuestionThread) then
				SwitchControlQuestionThread = CreateRealTimeThread(function()
					ForceShowMouseCursor("control scheme change")
					if not IsXInputControllerConnected() then
						WaitSwitchControls(
							"keyboard", Platform.playstation and T(586099002482, --[[PS controller message]] "Controller disconnected") or T(395217005275, "Controller disconnected"),
							T(645742280363, "Do you want to switch to mouse/keyboard controls?")
						)
					end
					UnforceShowMouseCursor("control scheme change")
				end)
			end
		elseif config.AutoControllerHandlingType == "auto" then
			SwitchControls(false)
		end
	end
else
	if Platform.playstation then
		UpdateActiveController()
	end
	
	function OnMsg.OnXInputControllerDisconnected(id)
		if ActiveController == id then
			ConsolePlatformControllerDisconnected()
		end
	end
	
	function ConsolePlatformControllerDisconnected()
		XInput.ControllerEnable("all", true)
		if not IsValidThread(SwitchControlQuestionThread) then
			SwitchControlQuestionThread = CreateRealTimeThread(function()
				Pause("ControllerDisconnected")
				local _, _, controller_id
				while true do
					_, _, controller_id = WaitMessage(
						terminal.desktop,
						T{836013651979, "Active <controller> disconnected", controller = Platform.playstation and g_PlayStationWirelessControllerText or T(704811499954, "Controller")},
						Platform.playstation and T(306576723489, --[[PS controller message]] "Please connect a controller to resume playing.") or T(925406686039, "Please connect a controller to resume playing.")
					)
					if controller_id then
						break
					end
					Sleep(5)
				end
				XInput.ControllerEnable("all", false)
				XInput.ControllerEnable(controller_id, true)
				Resume("ControllerDisconnected")
			end)
		end
	end
end

local function IsValidlyPressedBtn(button, CurState, MaxState, PrevState)
	return not PrevState[button] and (CurState[button] or MaxState[button])
end

local function IsButtonDownCompatible(button, CurState, MaxState, PrevState)
	local incompatible_buttons = XInput.IncompatibleButtons
	for i = 1, #incompatible_buttons do
		local buttons_group = incompatible_buttons[i]
		if table.find(buttons_group, button) then
			for i = 1, #buttons_group do
				local btn = buttons_group[i]
				if btn ~= button and IsValidlyPressedBtn(btn, CurState, MaxState, PrevState) then
					return false
				end
			end
		end
	end
	return IsValidlyPressedBtn(button, CurState, MaxState, PrevState)
end

function XInput.GetButtonTreshold(button)
	local treshold
	if button == "LeftTrigger" or button == "RightTrigger" then
		treshold = XInput.AnalogsAsButtonsLevel
	elseif button == "LeftThumb" or button == "RightThumb" then
		treshold = XInput.ThumbsAsButtonsLevel
	else
		treshold = 1
	end
	return treshold
end

function XEvent(action, nCtrlId, button, ...)
	-- repeat support
	if action == "OnXButtonUp" then
		XInput.ButtonPressTime[nCtrlId][button] = nil
		XInput.InitialButtonPressTime[nCtrlId][button] = nil
	end

	if terminal.desktop.inactive then return end
	
	if action == "OnXNewPacket" then
		procall(terminal.XEvent, action, nil, nCtrlId, ...)
	else
		procall(terminal.XEvent, action, button, nCtrlId, ...)
	end
	
	-- repeat support
	if action == "OnXButtonDown" then
		local repeat_time = XInput.InitialRepeatButtonTimeSpecific[button] or XInput.InitialRepeatButtonTime
		local real_time = RealTime()
		XInput.LastPressTime = real_time
		XInput.ButtonPressTime[nCtrlId][button] = real_time + repeat_time
		XInput.InitialButtonPressTime[nCtrlId][button] = real_time
	end
end

-- returns nothing for not activated and 1..8 for directions
function XInput.PointToDirection(pt)
	if pt:Len2D() < XInput.ThumbsAsButtonsLevel then
		return
	end
	local grad = (472*60 + 30 - CalcOrientation(pt)) % (360 * 60)-- rotate -22.5 degrees
	return 1 + grad / (45 * 60)
end

function GenerateEvents(nCtrlId, CurState, MaxState, PrevState)
	local level = XInput.AnalogsAsButtonsLevel
	local l_cur = XInput.PointToDirection(CurState.LeftThumb)
	local l_prev = XInput.PointToDirection(PrevState.LeftThumb)
	local r_cur = XInput.PointToDirection(CurState.RightThumb)
	local r_prev = XInput.PointToDirection(PrevState.RightThumb)

	-- down events for buttons
	local buttons = XInput.Buttons
	for i = 1, #buttons do
		if IsButtonDownCompatible(buttons[i], CurState, MaxState, PrevState) then
			XEvent("OnXButtonDown", nCtrlId, buttons[i])
		end
	end

	-- down events for analog buttons
	local analog_buttons = XInput.AnalogsAsButtons
	for i = 1, #analog_buttons do
		local button = analog_buttons[i]
		if PrevState[button] < level and (CurState[button] >= level or MaxState[button] >= level) then
			XEvent("OnXButtonDown", nCtrlId, button)
		end
	end

	-- LeftThumb down event
	if l_cur and l_cur ~= l_prev then
		XEvent("OnXButtonDown", nCtrlId, XInput.LeftThumbDirectionButtons[l_cur])
	end

	-- RightThumb down event
	if r_cur and r_cur ~= r_prev then
		XEvent("OnXButtonDown", nCtrlId, XInput.RightThumbDirectionButtons[r_cur])
	end


	-- up events for buttons
	for i = 1, #buttons do
		local button = buttons[i]
		if not CurState[button] and (PrevState[button] or MaxState[button]) then
			XEvent("OnXButtonUp", nCtrlId, button)
		end
	end

	-- up events for analog buttons
	for i = 1, #analog_buttons do
		local button = analog_buttons[i]
		if CurState[button] < level and (PrevState[button] >= level or MaxState[button] >= level) then
			XEvent("OnXButtonUp", nCtrlId, button)
		end
	end

	-- LeftThumb up event
	if l_prev and l_cur ~= l_prev then
		XEvent("OnXButtonUp", nCtrlId, XInput.LeftThumbDirectionButtons[l_prev])
	end

	-- RightThumb up event
	if r_prev and r_cur ~= r_prev then
		XEvent("OnXButtonUp", nCtrlId, XInput.RightThumbDirectionButtons[r_prev])
	end
end

local function remove_defaults(t, defaults)
	local r = {}
	for k, v in pairs(t) do
		if v ~= defaults[k] then
			r[k] = v
		end
	end
	return r
end

function XInput.__ProcessState(nCtrlId)
	local PrevState = XInput.CurrentState[nCtrlId]
	local LastState, CurState = XInput.UpdateStateFunc(nCtrlId)

	if LastState and CurState then
		if XInput.Record then
			local max_state
			table.insert(XInput.Record[nCtrlId], { 
				RealTime() - XInput.RecordStartTime, 
				remove_defaults(LastState, XInput.defaultState), 
				remove_defaults(CurState, XInput.defaultState) })
		end
		XInput.CurrentState[nCtrlId] = CurState
		if PrevState == "disconnected" then
			if CurState ~= "disconnected" then
				s_XInputControllersConnected = s_XInputControllersConnected + 1
				--GenerateEvents(nCtrlId, CurState, LastState, empty_state)
				XInput.ButtonPressTime[nCtrlId] = {}
				XInput.InitialButtonPressTime[nCtrlId] = {}
				Msg("OnXInputControllerConnected", nCtrlId)
			end
		elseif CurState == "disconnected" then
			if PrevState ~= "disconnected" then
				s_XInputControllersConnected = s_XInputControllersConnected - 1
				--GenerateEvents(nCtrlId, empty_state, empty_state, PrevState)
				XInput.ButtonPressTime[nCtrlId] = {}
				XInput.InitialButtonPressTime[nCtrlId] = {}
				Msg("OnXInputControllerDisconnected", nCtrlId)
			end
		else
			XEvent("OnXNewPacket", nCtrlId, false, LastState, CurState)
			GenerateEvents(nCtrlId, CurState, LastState, PrevState)
		end
	end

	-- generate repeat events
	local ButtonPressTime = XInput.ButtonPressTime[nCtrlId]
	if ButtonPressTime and next(ButtonPressTime) then
		local now = RealTime()
		for button, time in pairs(ButtonPressTime) do
			if now - time > 0 then
				local repeat_time = XInput.RepeatButtonTimeSpecific[button] or XInput.RepeatButtonTime
				if (XInput.InitialButtonPressTime[nCtrlId][button] + XInput.TimeBeforeAcceleration) < now then
					repeat_time = XInput.RepeatButtonTimeAccelerated
				end
				ButtonPressTime[button] = ButtonPressTime[button] + repeat_time
				XEvent("OnXButtonRepeat", nCtrlId, button)
			end
		end
	end
end

function XInput.ReplayStartRecording()
	XInput.Record = {}
	XInput.RecordStartTime = RealTime()
	XInput.Record.Connected = {}
	for nCtrlId = 0, XInput.MaxControllers() - 1 do
		XInput.Record[nCtrlId] = {}
		XInput.Record.Connected[nCtrlId] = not not XInput.IsControllerConnected(nCtrlId)
	end
end

function XInput.ReplayStopRecording(filename)
	local record = XInput.Record
	XInput.Record = nil
	CreateRealTimeThread(function()
		AsyncStringToFile(filename or "demo.lua", {"XInput.Playback = ", TableToLuaCode(record)})
	end)
end

function XInput.ReplayStartPlayback(filename)
	dofile(filename or "demo.lua")

	local old_IsControllerConnected = XInput.IsControllerConnected
	XInput.IsControllerConnected = function(nCtrlId)
		return XInput.Playback.Connected[nCtrlId]
	end

	local old_UpdateState = XInput.UpdateStateFunc
	local playback_start = RealTime()
	local controllers_done = 0
	local controllers_all = shift(1, XInput.MaxControllers()) - 1
	XInput.UpdateStateFunc = function(nCtrlId)
		local index = XInput.Playback[nCtrlId].index or 1
		local res = XInput.Playback[nCtrlId][index]
		if res then
			if res[1] > RealTime() - playback_start then -- too early to replay packet
				return
			end
			XInput.Playback[nCtrlId].index = index + 1
			setmetatable(res[2], XInput.defaultState)
			setmetatable(res[3], XInput.defaultState)
			return res[2], res[3]
		else
			controllers_done = bor(controllers_done, shift(1, nCtrlId))
			if controllers_done == controllers_all then
				XInput.UpdateStateFunc = old_UpdateState
				XInput.IsControllerConnected = old_IsControllerConnected
				XInput.Playback = nil
				return old_UpdateState(nCtrlId)
			end
		end
	end
end

function XInput.ReplayIsPlaying()
	return XInput.Playback ~= nil
end

function XInput.ReplayIsRecording()
	return XInput.Record ~= nil
end

if FirstLoad then
	local refresh = config.XInputRefreshTime
	CreateRealTimeThread(function()
		while true do
			for nCtrlId = 0, XInput.MaxControllers() - 1 do
				XInput.__ProcessState(nCtrlId)
			end
			Sleep(refresh)
		end
	end)
end

originalSetRumble = rawget(_G, "originalSetRumble") or XInput.SetRumble
XInput.RumbleState = {}

function XInput.SetRumble(id, left, right)
	if id and config.Vibration == 1 then
		XInput.RumbleState[id] = {left, right}
		originalSetRumble(id, left, right)
	end
end

-- checks if button state is above some treshold on specified controller
function XInput.IsCtrlButtonAboveTreshold(ctrlId, button, treshold)
	local state = ctrlId and XInput.CurrentState[ctrlId]
	local value = state and state[button]

	local button_type = type(value)
	if button_type ~= "number" then
		if button_type == "boolean" then
			value = value and 1 or 0
		elseif button_type == "nil" then
			value = 0
		elseif IsPoint(value) then
			value = value:Len()
		end
	end
	if value >= treshold then
		return true
	end
	return false
end

local function CheckThumbButtonEvent(button, thumb_buttons, thumb_position)
	if not table.find(thumb_buttons, button) then
		return false
	end
	local dir = XInput.PointToDirection(thumb_position)
	return dir and thumb_buttons[dir] == button
end

-- checks if button is pressed on specified controller(above its predefined treshold)
function XInput.IsCtrlButtonPressed(ctrlId, button, treshold)
	local state = ctrlId and XInput.CurrentState[ctrlId]
	if not state then return false end
	return CheckThumbButtonEvent(button, XInput.LeftThumbDirectionButtons, state.LeftThumb) or
	       CheckThumbButtonEvent(button, XInput.RightThumbDirectionButtons, state.RightThumb) or
	       XInput.IsCtrlButtonAboveTreshold(ctrlId, button, treshold or XInput.GetButtonTreshold(button))
end

-- Replace pause and resume functions for handle controller rumble

local function StopRumble()
	for i = 0, XInput.MaxControllers() - 1 do
		if XInput.IsControllerConnected(i) then
			originalSetRumble(i, 0, 0)
		end
	end
end

OnMsg.DoneMap = StopRumble
OnMsg.Pause = StopRumble

function OnMsg.Resume()
	for i = 0, XInput.MaxControllers() - 1 do
		if XInput.IsControllerConnected(i) and XInput.RumbleState[i] then
			originalSetRumble(i, unpack_params(XInput.RumbleState[i]))
		end
	end
end

function OnMsg.DebuggerBreak()
	StopRumble()
end

if FirstLoad then
	function OnMsg.Autorun()
		hr.XBoxRightThumbLocked = 0
		hr.XBoxLeftThumbLocked = 0
	end
end

