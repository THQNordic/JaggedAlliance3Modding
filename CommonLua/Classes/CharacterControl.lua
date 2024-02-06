if FirstLoad then
	LocalPlayersCount = 0
end

DefineClass.CharacterControl = {
	__parents = { "OldTerminalTarget", "InitDone" },
	active = false,
	character = false,
	camera_active = true,
	terminal_target_priority = -500,
}

function CharacterControl:Init(character)
	self.character = character
	terminal.AddTarget(self)
end

function CharacterControl:Done()
	terminal.RemoveTarget(self)
	self:SetActive(false)
end

function CharacterControl:SetActive(active)
	if self.active == active then
		return
	end
	if active then
		self.active = active
		self:OnActivate()
	else
		self.active = active
		self:OnInactivate()
	end
	ChangeGameState("CharacterControl", active)
end

function CharacterControl:SetCameraActive(active)
	self.camera_active = active
end

function CharacterControl:OnActivate()
	self:SyncWithCharacter()
end

function CharacterControl:OnInactivate()
	if not IsPaused() then
		self:SyncWithCharacter()
	end
end

function CharacterControl:GetBindingValue(binding)
end

function CharacterControl:GetActionBindings(action)
end

function CharacterControl:GetActionBinding1(action)
	local bindings = self:GetActionBindings(action)
	local binding = bindings and bindings[1]
	return binding and (binding.xbutton or binding.key or binding.mouse_button)
end

function CharacterControl:GetBindingsCombinedValue(action)
	local bindings = self:GetActionBindings(action)
	if not bindings then return end
	local best_value
	for i = 1, #bindings do
		local value = self:GetBindingValue(bindings[i])
		if value then
			if value == true then
				return true
			elseif type(value) == "number" then
				best_value = Max(value, best_value or 0)
			elseif IsPoint(value) then
				if not best_value or value:Len2() > best_value:Len2() then
					best_value = value
				end
			end	
		end
	end
	return best_value
end

function CharacterControl:CallBindingsDown(bindings, param, time)
	for i = 1, #bindings do
		local binding = bindings[i]
		if self:BindingModifiersActive(binding) then
			local result = binding.func(self.character, self, param, time)
			if result ~= "continue" then
				return result
			end
		end
	end
	return "continue"
end

function CharacterControl:CallBindingsUp(bindings)
	for i = 1, #bindings do
		local binding = bindings[i]
		local value = self:GetBindingsCombinedValue(binding.action)
		if not value then
			local result = binding.func(self.character, self)
			if result ~= "continue" then
				return result
			end
		end
	end
	return "continue"
end

function CharacterControl:SyncBindingsWithCharacter(bindings)
	for i = 1, #bindings do
		local binding = bindings[i]
		local value = binding.action and self:GetBindingsCombinedValue(binding.action)
		binding.func(self.character, self, value)
	end
end

function CharacterControl:SyncWithCharacter()
end

function BindToKeyboardAndMouseSync(action)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindToControllerSync(action, CC_KeyboardAndMouseSync)
	end
end

function BindToXboxControllerSync(action)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindToControllerSync(action, CC_XboxControllerSync)
	end
end

-- CharacterControlAction

DefineClass.CharacterControlAction = {
	__parents = {},
	ActionStop = false,
	IsKindOf = IsKindOf,
	HasMember = PropObjHasMember,
}

function CharacterControlAction:Action(character)
	print("No Action defined: " .. self.class)
	return "continue"
end
function OnMsg.ClassesPostprocess()
	ClassDescendants("CharacterControlAction", function(class_name, class)
		if class.GetAction == CharacterControlAction.GetAction and class.Action then
			local f = function(...)
				return class:Action(...)
			end
			class.GetAction = function() return f end
		end
		if class.GetActionSync == CharacterControlAction.GetActionSync and class.ActionStop then
			local action_name = string.sub(class_name, #"CCA_" + 1)
			local function f(character, controller)
				local value = controller:GetBindingsCombinedValue(action_name)
				if not value then
					class:ActionStop(character, controller)
				end
				return "continue"
			end
			class.GetActionSync = function() return f end
		end
	end)
end
function CharacterControlAction:GetAction()
end
function CharacterControlAction:GetActionSync()
end

function CharacterControlAction:BindToControllerSync(action, bindings)
	local f = self:GetActionSync()
	if f and not table.find(bindings, "func", f) then
		table.insert(bindings, { action = action, func = f })
	end
end

function CharacterControlAction:BindKey(action, key, mod1, mod2)
	local f = self:GetAction()
	if f then
		if mod1 == "double-click" then
			BindToKeyboardEvent(action, "double-click", f, key, mod2)
		elseif mod1 == "hold" then
			BindToKeyboardEvent(action, "hold", f, key, mod2)
		else
			BindToKeyboardEvent(action, "down", f, key, mod1, mod2)
		end
	end
	if mod1 == "double-click" or mod1 == "hold" then
		mod1, mod2 = mod2, nil
	end
	f = self:GetActionSync()
	if f then
		BindToKeyboardEvent(action, "up", f, key)
		if mod1 then
			BindToKeyboardEvent(action, "up", f, mod1)
		end
		if mod2 then
			BindToKeyboardEvent(action, "up", f, mod2)
		end
	end
end

function CharacterControlAction:BindMouse(action, button, key_mod)
	assert(key_mod ~= "double-click" and key_mod ~= "hold", "Not supported mouse modifiers")
	local f = self:GetAction()
	if f then
		if button == "MouseMove" then
			BindToMouseEvent(action, "mouse_move", f, nil, key_mod)
		else
			BindToMouseEvent(action, "down", f, button, key_mod)
		end
	end
	f = self:GetActionSync()
	if f then
		if button ~= "MouseMove" then
			BindToMouseEvent(action, "up", f, button)
		end
		if key_mod then
			BindToKeyboardEvent(action, "up", f, key_mod)
		end
	end
end

function CharacterControlAction:BindXboxController(action, button, mod1, mod2)
	local f = self:GetAction()
	if f then
		if mod1 == "hold" then
			BindToXboxControllerEvent(action, "hold", f, button, mod2)
		else
			BindToXboxControllerEvent(action, "down", f, button, mod1, mod2)
		end
	end
	if mod1 == "hold" then
		mod1, mod2 = mod2, nil
	end
	f = self:GetActionSync()
	if f then
		BindToXboxControllerEvent(action, "up", f, button)
		if mod1 then
			BindToXboxControllerEvent(action, "up", f, mod1)
		end
		if mod2 then
			BindToXboxControllerEvent(action, "up", f, mod2)
		end
	end
end

-- Navigation

if FirstLoad then
	UpdateCharacterNavigationThread = false
end

function OnMsg.DoneMap()
	UpdateCharacterNavigationThread = false
end

local function CalcNavigationVector(controller, camera_view)
	local pt = controller:GetBindingsCombinedValue("Move_Direction")
	if pt then
		return Rotate(pt:SetX(-pt:x()), XControlCameraGetYaw(camera_view) - 90*60)
	end
	local x = (controller:GetBindingsCombinedValue("Move_CameraRight") and 32767 or 0) + (controller:GetBindingsCombinedValue("Move_CameraLeft") and -32767 or 0)
	local y = (controller:GetBindingsCombinedValue("Move_CameraForward") and 32767 or 0) + (controller:GetBindingsCombinedValue("Move_CameraBackward") and -32767 or 0)
	if x ~= 0 or y ~= 0 then
		return Rotate(point(-x,y), XControlCameraGetYaw(camera_view) - 90*60)
	end
end

function UpdateCharacterNavigation(character, controller)
	local dir = CalcNavigationVector(controller, character.camera_view)
	character:SetStateContext("navigation_vector", dir)
	if dir and not IsValidThread(UpdateCharacterNavigationThread) then
		UpdateCharacterNavigationThread = CreateMapRealTimeThread(function()
			repeat
				Sleep(20)
				if IsPaused() then break end
				local update
				for loc_player = 1, LocalPlayersCount do
					local o = PlayerControlObjects[loc_player]
					if o and o.controller then
						local dir = CalcNavigationVector(o.controller, o.camera_view)
						o:SetStateContext("navigation_vector", dir)
						update = update or dir and true
					end
				end
			until not update
			UpdateCharacterNavigationThread = false
		end)
	end
	return "continue"
end

DefineClass("CCA_Navigation", "CharacterControlAction")
DefineClass("CCA_Move_CameraForward", "CCA_Navigation")
DefineClass("CCA_Move_CameraBackward", "CCA_Navigation")
DefineClass("CCA_Move_CameraLeft", "CCA_Navigation")
DefineClass("CCA_Move_CameraRight", "CCA_Navigation")

function CCA_Navigation:BindKey(action, key)
	BindToKeyboardEvent(action, "down", UpdateCharacterNavigation, key)
	BindToKeyboardEvent(action, "up", UpdateCharacterNavigation, key)
end
function CCA_Navigation:BindXboxController(action, button)
	BindToXboxControllerEvent(action, "down", UpdateCharacterNavigation, button)
	BindToXboxControllerEvent(action, "up", UpdateCharacterNavigation, button)
end
function CCA_Navigation:GetActionSync()
	return UpdateCharacterNavigation
end

-- Move_Direction
DefineClass("CCA_Move_Direction", "CharacterControlAction")
function CCA_Move_Direction:BindKey(action, key, mod1, mod2)
	assert(false, "Can't bind 2D direction to a key")
end
function CCA_Move_Direction:BindMouse(action, button, key_mod)
	assert(false, "Mouse cursor could be converted to a direction. Not implemented.")
end
function CCA_Move_Direction:BindXboxController(action, button)
	assert(button == "LeftThumb" or button == "RightThumb")
	BindToXboxControllerEvent(action, "change", UpdateCharacterNavigation, button)
end
function CCA_Move_Direction:GetActionSync()
	return UpdateCharacterNavigation
end

-- RotateCamera
function UpdateCameraRotate(character, controller)
	if not g_LookAtObjectSA then
		local dir = (controller:GetBindingsCombinedValue("CameraRotate_Left") and -1 or 0) + (controller:GetBindingsCombinedValue("CameraRotate_Right") and 1 or 0)
		camera3p.SetAutoRotate(90*60*dir)
	end
	return "continue"
end

DefineClass("CCA_CameraRotate", "CharacterControlAction")
DefineClass("CCA_CameraRotate_Left", "CCA_CameraRotate")
DefineClass("CCA_CameraRotate_Right", "CCA_CameraRotate")

function CCA_CameraRotate:BindKey(action, key)
	BindToKeyboardEvent(action, "down", UpdateCameraRotate, key)
	BindToKeyboardEvent(action, "up", UpdateCameraRotate, key)
end
function CCA_CameraRotate:BindXboxController(action, button)
	BindToXboxControllerEvent(action, "down", UpdateCameraRotate, button)
	BindToXboxControllerEvent(action, "up", UpdateCameraRotate, button)
end
function CCA_CameraRotate:GetActionSync()
	return UpdateCameraRotate
end

if FirstLoad then
	InGameMouseCursor = false
end

-- CameraRotate_Mouse
DefineClass("CCA_CameraRotate_Mouse", "CharacterControlAction")
function CCA_CameraRotate_Mouse:Action(character)
	if not (character and character.controller and character.controller.camera_active) then
		return "continue"
	end
	if InGameMouseCursor then
		HideMouseCursor("InGameCursor") -- although MouseRotate(true) hides the mouse, IsMouseCursorHidden() depends on it
	else
		SetMouseDeltaMode(false)
	end
	MouseRotate(true)
	Msg("CameraRotateStart", "mouse")
	return "break"
end
function CCA_CameraRotate_Mouse:ActionStop(character)
	MouseRotate(false)
	if InGameMouseCursor then
		ShowMouseCursor("InGameCursor")
	else
		HideMouseCursor("InGameCursor")
		SetMouseDeltaMode(true) -- prevents the mouse to leave the game window
	end
	Msg("CameraRotateStop", "mouse")
	return "continue"
end
function CCA_CameraRotate_Mouse:GetActionSync(character, controller)
	local function f(character, controller)
		local value = not CameraLocked and (MouseRotateCamera == "always" or controller:GetBindingsCombinedValue("CameraRotate_Mouse"))
		if value then
			return self:Action(character, controller)
		else
			return self:ActionStop(character, controller)
		end
	end
	return f
end

-- KeyboardAndMouse Control

DefineClass.CC_KeyboardAndMouse = {
	__parents = { "CharacterControl" },
	KeyHoldButtonTime = 350,
	KeyDoubleClickTime = 300,
	key_hold_thread = false,
	key_last_double_click = false,
	key_last_double_click_time = 0,
}

function CC_KeyboardAndMouse:OnActivate()
	CharacterControl.OnActivate(self)
	if InGameMouseCursor then
		ShowMouseCursor("InGameCursor")
	end
end

function CC_KeyboardAndMouse:OnInactivate()
	CharacterControl.OnInactivate(self)
	DeleteThread(self.key_hold_thread)
	self.key_hold_thread = nil
	self.key_last_double_click = nil
	self.key_last_double_click_time = nil
	HideMouseCursor("InGameCursor")
	MouseRotate(false)
end

function CC_KeyboardAndMouse:SetCameraActive(active)
	CharacterControl.SetCameraActive(self, active)
	if self.active and not self.camera_active then
		MouseRotate(false)
	end
end

function CC_KeyboardAndMouse:GetActionBindings(action)
	return CC_KeyboardAndMouse_ActionBindings[action]
end

function CC_KeyboardAndMouse:GetBindingValue(binding)
	if not self.active or binding.key and not terminal.IsKeyPressed(binding.key) then
		return false
	end
	if binding.mouse_button then
		local pressed = self:IsMouseButtonPressed(binding.mouse_button)
		if pressed == false then
			return false
		end
	end
	if not self:BindingModifiersActive(binding) then
		return false
	end
	return true
end

function CC_KeyboardAndMouse:IsMouseButtonPressed(button)
	local pressed, _
	if button == "LButton" then
		pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "RButton" then
		_, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "MButton" then
		_, _, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "XButton1" then
		_, _, _, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "XButton2" then
		_, _, _, _, pressed = terminal.IsLRMX1X2MouseButtonPressed()
	elseif button == "MouseWheelFwd" or button == "MouseWheelBack" then
		return false
	end
	return pressed
end

function CC_KeyboardAndMouse:BindingModifiersActive(binding)
	local keys = binding.key_modifiers
	if keys then
		for i = 1, #keys do
			local key_or_button = keys[i]
			if key_or_button == "MouseWheelFwd" or key_or_button == "MouseWheelBack" then
				return false
			end
			local pressed = self:IsMouseButtonPressed(key_or_button)
			if pressed == nil then
				pressed = terminal.IsKeyPressed(key_or_button)
			end
			if not pressed then
				return false
			end
		end
	end
	return true
end

-- keyboard events
function CC_KeyboardAndMouse:OnKbdKeyDown(virtual_key, repeated, time)
	if repeated or not self.active then
		return "continue"
	end
	-- double click
	if CC_KeyboardKeyDoubleClick[virtual_key] then
		if self.key_last_double_click == virtual_key and RealTime() - self.key_last_double_click_time < self.KeyDoubleClickTime then
			self.key_last_double_click = false
			self:CallBindingsDown(CC_KeyboardKeyDoubleClick[virtual_key], true, time)
		else
			self.key_last_double_click = virtual_key
			self.key_last_double_click_time = RealTime()
		end
	end
	-- hold
	if CC_KeyboardKeyHold[virtual_key] then
		DeleteThread(self.key_hold_thread)
		self.key_hold_thread = CreateRealTimeThread(function(self, virtual_key, time)
			Sleep(self.KeyHoldButtonTime)
			self.key_hold_thread = false
			if terminal.IsKeyPressed(virtual_key) then
				self:CallBindingsDown(CC_KeyboardKeyHold[virtual_key], true, time)
			end
		end, self, virtual_key, time)
	end
	-- down
	local result
	if CC_KeyboardKeyDown[virtual_key] then
		result = self:CallBindingsDown(CC_KeyboardKeyDown[virtual_key], true, time)
	end
	return result or "continue"
end

function CC_KeyboardAndMouse:OnKbdKeyUp(virtual_key)
	if not self.active then
		return "continue"
	end
	if CC_KeyboardKeyHold[virtual_key] and self.key_hold_thread then
		DeleteThread(self.key_hold_thread)
		self.key_hold_thread = false
	end
	if CC_KeyboardKeyUp[virtual_key] then
		local result = self:CallBindingsUp(CC_KeyboardKeyUp[virtual_key])
		return result
	end
	return "continue"
end

-- mouse events

function CC_KeyboardAndMouse:OnMouseButtonDown(button, pt, time)
	if not self.active then
		return "continue"
	end
	if CC_MouseButtonDown[button] then
		local result = self:CallBindingsDown(CC_MouseButtonDown[button], true, time)
		if result ~= "continue" then
			return result
		end
	end
	return "continue"
end

function CC_KeyboardAndMouse:OnMouseButtonUp(button, pt, time)
	if not self.active then
		return "continue"
	end
	if CC_MouseButtonUp[button] then
		local result = self:CallBindingsUp(CC_MouseButtonUp[button], false, time)
		if result ~= "continue" then
			return result
		end
	end
	return "continue"
end

function CC_KeyboardAndMouse:OnLButtonDown(...)
	return self:OnMouseButtonDown("LButton", ...)
end
function CC_KeyboardAndMouse:OnLButtonUp(...)
	return self:OnMouseButtonUp("LButton", ...)
end
function CC_KeyboardAndMouse:OnLButtonDoubleClick(...)
	return self:OnMouseButtonDown("LButton", ...)
end
function CC_KeyboardAndMouse:OnRButtonDown(...)
	return self:OnMouseButtonDown("RButton", ...)
end
function CC_KeyboardAndMouse:OnRButtonUp(...)
	return self:OnMouseButtonUp("RButton", ...)
end
function CC_KeyboardAndMouse:OnRButtonDoubleClick(...)
	return self:OnMouseButtonDown("RButton", ...)
end
function CC_KeyboardAndMouse:OnMButtonDown(...)
	return self:OnMouseButtonDown("MButton", ...)
end
function CC_KeyboardAndMouse:OnMButtonUp(...)
	return self:OnMouseButtonUp("MButton", ...)
end
function CC_KeyboardAndMouse:OnMButtonDoubleClick(...)
	return self:OnMouseButtonDown("MButton", ...)
end
function CC_KeyboardAndMouse:OnXButton1Down(...)
	return self:OnMouseButtonDown("XButton1", ...)
end
function CC_KeyboardAndMouse:OnXButton1Up(...)
	return self:OnMouseButtonUp("XButton1", ...)
end
function CC_KeyboardAndMouse:OnXButton1DoubleClick(...)
	return self:OnMouseButtonDown("XButton1", ...)
end
function CC_KeyboardAndMouse:OnXButton2Down(...)
	return self:OnMouseButtonDown("XButton2", ...)
end
function CC_KeyboardAndMouse:OnXButton2Up(...)
	return self:OnMouseButtonUp("XButton2", ...)
end
function CC_KeyboardAndMouse:OnXButton2DoubleClick(...)
	return self:OnMouseButtonDown("XButton2", ...)
end

function CC_KeyboardAndMouse:OnMouseWheelForward(pt, time)
	if not self.active then
		return "continue"
	end
	local result = self:CallBindingsDown(CC_MouseWheelFwd, true, time)
	if result ~= "break" then
		result = self:CallBindingsDown(CC_MouseWheel, 1, time)
	end
	return result
end
function CC_KeyboardAndMouse:OnMouseWheelBack(pt, time)
	if not self.active then
		return "continue"
	end
	local result = self:CallBindingsDown(CC_MouseWheelBack, true, time)
	if result ~= "break" then
		result = self:CallBindingsDown(CC_MouseWheel, -1, time)
	end
	return result
end

function CC_KeyboardAndMouse:OnMousePos(pt, time)
	if not self.active then
		return "continue"
	end
	local result = self:CallBindingsDown(CC_MouseMove, pt, time)
	return result
end

function CC_KeyboardAndMouse:SyncWithCharacter()
	self:SyncBindingsWithCharacter(CC_KeyboardAndMouseSync)
end

local function ResetKeyboardAndMouseBindings()
	CC_KeyboardKeyDown = {}
	CC_KeyboardKeyUp = {}
	CC_KeyboardKeyHold = {}
	CC_KeyboardKeyDoubleClick = {}
	CC_MouseButtonDown = {}
	CC_MouseButtonUp = {}
	CC_MouseWheel = {}
	CC_MouseWheelFwd = {}
	CC_MouseWheelBack = {}
	CC_MouseMove = {}
	CC_KeyboardAndMouse_ActionBindings = {}
	CC_KeyboardAndMouseSync = {}
end

if FirstLoad then
	ResetKeyboardAndMouseBindings()
end

function BindKey(action, key, mod1, mod2)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindKey(action, key, mod1, mod2)
	end
end

function BindMouse(action, button, key_mod)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindMouse(action, button, key_mod)
	end
end

local function ResolveRefBindings(list, bindings)
	for i = 1, #list do
		local action = list[i][1]
		local blist = bindings[action]
		for j = #blist, 1, -1 do
			local binding = blist[j]
			for k = #binding, 1, -1 do
				local ref = bindings[binding[k]]
				if ref then
					if #ref == 0 then
						table.remove(blist,j)
					else
						table.remove(binding, k)
						for m = 2, #ref do
							table.insert(blist, j, table.copy(binding))
						end
						for m = 1, #ref do
							local rt = ref[m]
							local binding_mod = blist[j+m-1]
							for n = #rt, 1, -1 do
								table.insert(binding_mod, k+n-1, rt[n])
							end
						end
					end
				end
			end
		end
	end
end

function ReloadKeyboardAndMouseBindings(default_bindings, predefined_bindings)
	ResetKeyboardAndMouseBindings()
	if not default_bindings then
		return
	end
	local bindings = {}
	for i = 1, #default_bindings do
		local default_list = default_bindings[i]
		local action = default_list[1]
		bindings[action] = {}
		local predefined_list = predefined_bindings and predefined_bindings[action]
		for j = 1, Max(predefined_list and #predefined_list or 0, #default_list-1) do
			local binding = predefined_list and predefined_list[j] or nil
			if binding == nil then
				binding = default_list and default_list[j+1]
			end
			if binding and #binding > 0 then
				local t = {}
				for k = 1, #binding do
					t[k] = type(binding[k]) == "string" and const["vk"..binding[k]] or binding[k]
				end
				table.insert(bindings[action], t)
			end
		end
	end
	ResolveRefBindings(default_bindings, bindings)
	for i = 1, #default_bindings do
		local action = default_bindings[i][1]
		local blist = bindings[action]
		for j = 1, #blist do
			local binding = blist[j]
			if type(binding[1]) == "number" then
				BindKey(action, binding[1], binding[2], binding[3])
			else
				BindMouse(action, binding[1], binding[2], binding[3])
			end
			if binding[2] then
				if type(binding[2]) == "number" then
					BindKey(action, binding[2], binding[1], binding[3])
				else
					BindMouse(action, binding[2], binding[1], binding[3])
				end
			end
			if binding[3] then
				if type(binding[3]) == "number" then
					BindKey(action, binding[3], binding[1], binding[2])
				else
					BindMouse(action, binding[3], binding[1], binding[2])
				end
			end
		end
		BindToKeyboardAndMouseSync(action)
	end
end

function BindToKeyboardEvent(action, event, func, key, mod1, mod2)
	local binding = { action = action, key = key, func = func }
	if mod1 or mod2 then
		binding.key_modifiers = {}
		binding.key_modifiers[#binding.key_modifiers+1] = mod1
		binding.key_modifiers[#binding.key_modifiers+1] = mod2
	end
	local list
	if event == "down" then
		list = CC_KeyboardKeyDown
		CC_KeyboardAndMouse_ActionBindings[action] = CC_KeyboardAndMouse_ActionBindings[action] or {}
		table.insert(CC_KeyboardAndMouse_ActionBindings[action], binding)
	elseif event == "up" then
		list = CC_KeyboardKeyUp
	elseif event == "hold" then
		list = CC_KeyboardKeyHold
	elseif event == "double-click" then
		list = CC_KeyboardKeyDoubleClick
	end
	list[key] = list[key] or {}
	table.insert(list[key], binding)
end

function BindToMouseEvent(action, event, func, button, key_mod)
	local binding = { action = action, mouse_button = button, func = func }
	if key_mod then
		binding.key_modifiers = {}
		binding.key_modifiers[#binding.key_modifiers+1] = key_mod
	end
	if event == "down" or button == "MouseWheel" then
		CC_KeyboardAndMouse_ActionBindings[action] = CC_KeyboardAndMouse_ActionBindings[action] or {}
		table.insert(CC_KeyboardAndMouse_ActionBindings[action], binding)
	end
	if button == "MouseWheel" then
		table.insert(CC_MouseWheel, binding)
	elseif button == "MouseWheelFwd" then
		table.insert(CC_MouseWheelFwd, binding)
	elseif button == "MouseWheelBack" then
		table.insert(CC_MouseWheelBack, binding)
	elseif event == "down" then
		CC_MouseButtonDown[button] = CC_MouseButtonDown[button] or {}
		table.insert(CC_MouseButtonDown[button], binding)
	elseif event == "up" then
		CC_MouseButtonUp[button] = CC_MouseButtonUp[button] or {}
		table.insert(CC_MouseButtonUp[button], binding)
	elseif event == "mouse_move" then
		table.insert(CC_MouseMove, binding)
	end
end


-- XboxController

DefineClass.CC_XboxController = {
	__parents = { "CharacterControl" },
	xbox_controller_id = false,
	XboxHoldButtonTime = 350,
	xbox_hold_thread = false,
	XBoxComboButtonsDelay = 100,
	xbox_last_combo_button = false,
	xbox_last_combo_button_time = 0,
}

function CC_XboxController:Init(character, controller_id)
	self.xbox_controller_id = controller_id
end

function CC_XboxController:OnActivate()
	CharacterControl.OnActivate(self)
	if self.xbox_controller_id and self.camera_active then
		camera3p.EnableController(self.xbox_controller_id)
	end
end

function CC_XboxController:SetCameraActive(active)
	CharacterControl.SetCameraActive(self, active)
	if self.xbox_controller_id and self.active then
		if self.camera_active then
			camera3p.EnableController(self.xbox_controller_id)
		else
			camera3p.DisableController(self.xbox_controller_id)
		end
	end
end

function CC_XboxController:OnInactivate()
	CharacterControl.OnInactivate(self)
	DeleteThread(self.xbox_hold_thread)
	self.xbox_hold_thread = nil
	if self.xbox_controller_id then
		XInput.SetRumble(self.xbox_controller_id, 0, 0)
		camera3p.DisableController(self.xbox_controller_id)
	end
end

function CC_XboxController:GetActionBindings(action)
	return CC_XboxController_ActionBindings[action]
end

function CC_XboxController:GetBindingValue(binding)
	if not self.active then
		return
	end
	local button = binding.xbutton
	if button and not XInput.IsCtrlButtonPressed(self.xbox_controller_id, button) then
		return
	end
	if not self:BindingModifiersActive(binding) then
		return
	end
	local value = XInput.CurrentState[self.xbox_controller_id][button]
	return value
end

function CC_XboxController:BindingModifiersActive(binding)
	local buttons = binding.x_modifiers
	if buttons then
		for i = 1, #buttons do
			if not XInput.IsCtrlButtonPressed(self.xbox_controller_id, buttons[i]) then
				return false
			end
		end
	end
	return true
end

function CC_XboxController:OnXButtonDown(button, controller_id)
	if not self.active or controller_id ~= self.xbox_controller_id then
		return "continue"
	end
	-- hold
	if CC_XboxButtonHold[button] then
		DeleteThread(self.xbox_hold_thread)
		self.xbox_hold_thread = CreateRealTimeThread(function(self, button, controller_id)
			Sleep(self.XboxHoldButtonTime)
			self.xbox_hold_thread = false
			if XInput.IsCtrlButtonPressed(self.xbox_controller_id, button) then
				local xstate = XInput.CurrentState[controller_id]
				self:CallBindingsDown(CC_XboxButtonHold[button], xstate[button])
			end
		end, self, button, controller_id)
	end
	local result
	if CC_XboxButtonDown[button] then
		result = self:CallBindingsDown(CC_XboxButtonDown[button], true)
	end
	if CC_XboxButtonCombo[button] then
		local handlers = self.xbox_last_combo_button and RealTime() - self.xbox_last_combo_button_time < self.XBoxComboButtonsDelay and CC_XboxButtonCombo[button][self.xbox_last_combo_button]
		if handlers then
			local result = self:CallBindingsDown(handlers, true)
			if result and result ~= "continue" then
				self.xbox_last_combo_button = false
				return result
			end
		end
		self.xbox_last_combo_button = button
		self.xbox_last_combo_button_time = RealTime()
	end
	return result or "continue"
end

function CC_XboxController:OnXButtonUp(button, controller_id)
	if not self.active or controller_id ~= self.xbox_controller_id then
		return "continue"
	end
	if self.xbox_last_combo_button == button then
		self.xbox_last_combo_button = false
	end
	if CC_XboxButtonHold[button] and self.xbox_hold_thread then
		DeleteThread(self.xbox_hold_thread)
		self.xbox_hold_thread = false
	end
	if CC_XboxButtonUp[button] then
		local result = self:CallBindingsUp(CC_XboxButtonUp[button])
		if result ~= "continue" then
			return result
		end
	end
	return "continue"
end

function CC_XboxController:OnXNewPacket(_, controller_id, last_state, current_state)
	if not self.active or controller_id ~= self.xbox_controller_id then
		return "continue"
	end
	for i = 1, #CC_XboxControllerNewPacket do
		local button = CC_XboxControllerNewPacket[i]
		self:CallBindingsDown(CC_XboxControllerNewPacket[button], current_state[button])
	end
	return "continue"
end

function CC_XboxController:SyncWithCharacter()
	self:SyncBindingsWithCharacter(CC_XboxControllerSync)
end

local function ResetXboxControllerBindings()
	CC_XboxButtonDown = {}
	CC_XboxButtonUp = {}
	CC_XboxButtonHold = {}
	CC_XboxButtonCombo = {}
	CC_XboxControllerNewPacket = {}
	CC_XboxController_ActionBindings = {}
	CC_XboxControllerSync = {}
	table.insert(CC_XboxControllerSync,{ func = function() MouseRotate(false) end})
end

if FirstLoad then
	ResetXboxControllerBindings()
end

function ReloadXboxControllerBindings(default_bindings, predefined_bindings)
	ResetXboxControllerBindings()
	if not default_bindings then
		return
	end
	local bindings = {}
	for i = 1, #default_bindings do
		local default_list = default_bindings[i]
		local action = default_list[1]
		bindings[action] = {}
		local predefined_list = predefined_bindings and predefined_bindings[action]
		for i = 1, Max(predefined_list and #predefined_list or 0, #default_list-1) do
			local binding = predefined_list and predefined_list[i] or nil
			if binding == nil then
				binding = default_list and default_list[i+1]
			end
			if binding and #binding > 0 then
				local t = {}
				for k = 1, #binding do
					t[k] = binding[k]
				end
				table.insert(bindings[action], t)
			end
		end
	end
	ResolveRefBindings(default_bindings, bindings)
	for i = 1, #default_bindings do
		local action = default_bindings[i][1]
		local blist = bindings[action]
		for j = 1, #blist do
			local binding = blist[j]
			BindXboxController(action, unpack_params(binding))
		end
		BindToXboxControllerSync(action)
	end
end

function BindXboxController(action, button, mod1, mod2)
	local class = _G["CCA_"..action]
	assert(class)
	if class then
		class:BindXboxController(action, button, mod1, mod2)
	end
end

function BindToXboxControllerEvent(action, event, func, button, mod1, mod2)
	if event == "sync" then
		if action or not table.find(CC_XboxControllerSync, "func", func) then
			local binding = { action = action, func = func }
			table.insert(CC_XboxControllerSync, binding)
		end
		return
	end
	local binding = { action = action, xbutton = button, func = func }
	if mod1 or mod2 then
		binding.x_modifiers = {}
		binding.x_modifiers[#binding.x_modifiers+1] = mod1
		binding.x_modifiers[#binding.x_modifiers+1] = mod2
	end
	local list
	if event == "down" then
		CC_XboxController_ActionBindings[action] = CC_XboxController_ActionBindings[action] or {}
		table.insert(CC_XboxController_ActionBindings[action], binding)
		list = CC_XboxButtonDown
	elseif event == "up" then
		list = CC_XboxButtonUp
		table.insert_unique(CC_XboxButtonUp, button)
	elseif event == "hold" then
		list = CC_XboxButtonHold
	elseif event == "combo" then
		list = CC_XboxButtonCombo
	elseif event == "change" then
		CC_XboxController_ActionBindings[action] = CC_XboxController_ActionBindings[action] or {}
		table.insert(CC_XboxController_ActionBindings[action], binding)
		table.insert_unique(CC_XboxControllerNewPacket, button)
		list = CC_XboxControllerNewPacket
	else
		return
	end
	if not list[button] then
		list[button] = {}
	end
	table.insert(list[button], binding)
end
