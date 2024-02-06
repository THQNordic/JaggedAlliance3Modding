const.HoldButtonFillTime = 1000

DefineClass.XHoldButton = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Interaction" ,id = "CursorsFolder", editor = "text", default = "UI/Cursors/", },
		{ category = "Interaction", id = "CursorsCount", editor = "number", default = 6, },
		{ category = "Interaction", id = "OnHoldDown", editor = "func", params = "self, pt, button"},
	},
	pt_pressed = false,
	pressed_button =  false, 
	delay_wait_time = false,
	start_time = false,
	prev_mouse_cursor = false,
	registered_buttons = false,
}

function XHoldButton:InitButtons()
	local list = self.HoldGamepadButtons or ""
	self.registered_buttons = { list:starts_with(",") and "" or nil }
	for btn in list:gmatch("([%w%-_]+)") do
		self.registered_buttons[btn] = true
	end	
end

--print("pressed, onhold", pt, button)
function XHoldButton:OnHoldDown(pt, button)
	
end

function XHoldButton:OnHoldButtonTick(i, shortcut)	
	if not i then -- restore after up
		if self.prev_mouse_cursor then
			self:SetMouseCursor(self.prev_mouse_cursor)		
			Msg("MouseCursor",self.prev_mouse_cursor)
		end	
		return
	end
	local img = self.CursorsFolder.."hold"..i..".tga"
	self:SetMouseCursor(img)
	Msg("MouseCursor",img)
end

function XHoldButton:OnHoldButtonRepeat(button, controller_id)	
	--print("repeat A", button, self.delay_wait_time and now() - self.delay_wait_time)
	if self.pressed_button and self.pressed_button==button and not self:IsThreadRunning("hold button") and (now() - self.delay_wait_time)>=300 and not self.start_time then				
		self.start_time = now()
		self.prev_mouse_cursor = self.prev_mouse_cursor or self:GetMouseCursor() or const.DefaultMouseCursor
		-- start button 		
		local count = self.CursorsCount
		local sleep_time = const.HoldButtonFillTime/count
		local last = const.HoldButtonFillTime - sleep_time*count
		self:OnHoldButtonTick(0, button)	
		self:CreateThread("hold button", function()
			for i=1, (count-1) do
				--print("change cursor", i)
				if i == (count - 1) then
					sleep_time = sleep_time + last
				end	
				Sleep(sleep_time)
				self:OnHoldButtonTick(i, button)	
			end		
		end)
	end	
end

function XHoldButton:OnHoldButtonDown(button, controller_id)
	if not self.pressed_button then
		self.pt_pressed = GamepadMouseGetPos()
		self.pressed_button = button
		self.delay_wait_time= now()
		--print("pressed A",self.delay_wait_time)
	end	
end

function XHoldButton:OnHoldButtonUp(button, controller_id)
--call on hold if time is passed or cancel if less
	local success
	if self.pressed_button and button==self.pressed_button then
		self:DeleteThread("hold button")
		--print("release A",self.start_time)
		if self.start_time and (now() - self.start_time) >= const.HoldButtonFillTime then
			self:OnHoldDown(self.pt_pressed,self.pressed_button)
			success = true
		end
		
		self.pt_pressed = false
		self.pressed_button = false
		self.delay_wait_time = false
		self.start_time = false
		
		self:OnHoldButtonTick(false, button)
		self.prev_mouse_cursor = false
	end
	return success
end
---------------------------
DefineClass.XHoldButtonControl = {
	__parents = {"XHoldButton", "XContextControl" },
	properties = {
		{ category = "Interaction", id = "HoldGamepadButtons", editor = "text"},
	},
	MouseCursor = "CommonAssets/UI/HandCursor.tga",
	pt_pressed = false,
	pressed_button =  false, 
	delay_wait_time = false,
	start_time = false,
	prev_mouse_cursor = false,
	registered_buttons = false,
}

function XHoldButtonControl:Open()
	XHoldButton.InitButtons(self)
	XContextControl.Open(self)
end

--print("pressed, onhold", pt, button)
function XHoldButtonControl:OnHoldDown(pt, button)
	
end

-- XWindow functions
function XHoldButtonControl:OnXButtonRepeat(button, controller_id)	
	if not self.registered_buttons or not self.registered_buttons[button]then return end
	return XHoldButton.OnHoldButtonRepeat(self, button, controller_id)	
end

function XHoldButtonControl:OnXButtonDown(button, controller_id)
	if not self.registered_buttons or not self.registered_buttons[button]then return end
	return XHoldButton.OnHoldButtonDown(self,button, controller_id)
end

function XHoldButtonControl:OnXButtonUp(button, controller_id)
	if not self.registered_buttons or not self.registered_buttons[button]then return end
	return XHoldButton.OnHoldButtonUp(self, button, controller_id)
end
