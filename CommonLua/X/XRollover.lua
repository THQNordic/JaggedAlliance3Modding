DefineClass.XRollover = {
	__parents = { "InitDone" },
	properties = {
		{ category = "Rollover", id = "RolloverTranslate", editor = "bool", default = true, },
		{ category = "Rollover", id = "RolloverTemplate", editor = "choice", default = "", items = function() return XTemplateCombo("XRolloverWindow") end, },
		{ category = "Rollover", id = "RolloverAnchor", editor = "choice", default = "smart", items = xpopup_anchor_types, },
		{ category = "Rollover", id = "RolloverAnchorId", editor = "text", default = "", },
		{ category = "Rollover", id = "RolloverText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("RolloverTranslate") end, lines = 3, },
		{ category = "Rollover", id = "RolloverDisabledText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("RolloverTranslate") end, lines = 3, },
		{ category = "Rollover", id = "RolloverOffset", editor = "margins", default = box(0, 0, 0, 0), },
	},
}

XGenerateGetSetFuncs(XRollover)

function XRollover:ResolveRolloverAnchor(context, pos)
	if context and context.anchor then return context.anchor end
	local anchor
	local id = self.RolloverAnchorId
	if id ~= "" then
		local node = self
		anchor = node and rawget(node, id)
		if not anchor then
			while true do
				node = node:ResolveId("node")
				if not node then break end
				if id == "node" or node.Id == id then
					anchor = node
					break
				end
				anchor = node and rawget(node, id)
				if anchor then break end
			end
		end
	end
	return anchor and (anchor.interaction_box or anchor.box) or pos and sizebox(pos:x(), pos:y(), 1, 1) or self.interaction_box or self.box
end

function XRollover:OnXTemplateSetProperty(prop_id, old_value)
	-- toggle text properties between Ts and strings when RolloverTranslate is edited
	if prop_id == "RolloverTranslate" then
		self:UpdateLocalizedProperty("RolloverText", self.RolloverTranslate)
		self:UpdateLocalizedProperty("RolloverDisabledText", self.RolloverTranslate)
		ObjModified(self)
	end
end


----- XRolloverWindow

DefineClass.XRolloverWindow = {
	__parents = { "XPopup", "XDrawCache" },
	HandleMouse = false,
	ChildrenHandleMouse = false,
	ZOrder = 1000000,
	RefreshInterval = 1000,
}

function XRolloverWindow:Init(parent, context)
	assert(context.control)
	if context.control then
		self:SetAnchor(context.control:ResolveRolloverAnchor(context))
		self:SetAnchorType(context.RolloverAnchor or context.control:GetRolloverAnchor())
	end
	if self.RefreshInterval then
		self:CreateThread("UpdateRolloverContent", function(self)
			while true do
				Sleep(self.RefreshInterval)
				self:UpdateRolloverContent()
			end
		end, self)
	end
end

function XRolloverWindow:ControlMove(control)
	self:SetAnchor(control:ResolveRolloverAnchor())
	self:InvalidateLayout()
end

function XRolloverWindow:UpdateRolloverContent()
	local content = rawget(self, "idContent")
	if content then
		content:OnContextUpdate(content.context)
	end
end

----- globals

if FirstLoad then
	RolloverWin = false
	RolloverControl = false
	RolloverGamepad = false
end

function XDestroyRolloverWindow(immediate)
	local win, control = RolloverWin, RolloverControl
	RolloverWin = false
	RolloverControl = false
	if win and win.window_state ~= "destroying" then
		Msg("DestroyRolloverWindow", win, control)
		if immediate then
			win:delete()
		else
			win:Close()
		end
	end
end

function XCreateRolloverWindow(control, gamepad, immediate, context)
	XDestroyRolloverWindow(immediate)
	local modal = terminal.desktop:GetModalWindow()
	if control and control:GetRolloverTemplate() ~= "" then
		local T_text = context and context.RolloverText or control:GetRolloverText()
		local T_context = SubContext(control:GetContext(), context)
		if (T_text or "") ~= "" and (not T_text or not IsT(T_text) or _InternalTranslate(T_text, T_context) ~= "") and (not modal or modal == terminal.desktop or control:IsWithin(modal)) then
			RolloverWin = control:CreateRolloverWindow(gamepad, context) or false
			RolloverControl = control
			RolloverGamepad = gamepad or false
			if Platform.ged then
				g_GedApp:UpdateChildrenDarkMode(RolloverWin)
			end
			Msg("CreateRolloverWindow", RolloverWin, control)
			Msg("XWindowRecreated", RolloverWin)
		end
	end
	return RolloverWin
end

function XGetRolloverControl(desktop)
	desktop = desktop or terminal.desktop
	local win = desktop.last_mouse_target or desktop.mouse_capture
	while win and win.window_state ~= "destroying" do
		local T_text = win:GetRolloverText()
		local T_context = win:GetContext()
		if win:GetRolloverTemplate() ~= "" and T_text ~= "" and (not T_text or not IsT(T_text) or _InternalTranslate(T_text, T_context) ~= "") then
			return win
		end
		win = win.parent
	end
end

function XRecreateRolloverWindow(win)
	if RolloverWin and RolloverControl == win and win.window_state ~= "destroying" then
		if XGetRolloverControl() == win then
			XCreateRolloverWindow(win, RolloverGamepad, true)
		end
	end
end

function XUpdateRolloverWindow(win)
	if RolloverWin and RolloverControl == win and win.window_state ~= "destroying" then
		RolloverWin:UpdateRolloverContent()
	end
end

----- Rollover thread
if FirstLoad then
	RolloverEnabled = true
	RolloverLastControl = false
	RolloverCurrentControl = false
end

function SetRolloverEnabled(enabled)
	RolloverEnabled = enabled
	if not enabled then
		XDestroyRolloverWindow(true)
	end
end

function MouseRollover()
	local last_pos = point20
	local timer
	local desktop = terminal.desktop
	local RolloverTime = const.RolloverTime
	local RolloverRefreshDistance = const.RolloverRefreshDistance
	
	while true do
		local pos = desktop.last_mouse_pos or terminal.GetMousePos()
		local ok, rollover_control = procall(XGetRolloverControl, desktop)
		RolloverCurrentControl = ok and rollover_control or false

		-- change rollover shortly
		if RolloverCurrentControl ~= RolloverLastControl
			or (RolloverLastControl and pos:Dist2D(last_pos) > RolloverRefreshDistance)
		then
			timer = timer or (RolloverCurrentControl ~= RolloverLastControl and RolloverTime or 0)
		elseif not RolloverLastControl then
			timer = false
		end

		if timer and timer < RolloverTime - const.RolloverDestroyTime then
			XDestroyRolloverWindow()
		end
		if timer and timer <= 0 and RolloverEnabled then
			XCreateRolloverWindow(RolloverCurrentControl, false)
			RolloverLastControl, last_pos = RolloverCurrentControl, pos
			timer = false
		end

		Sleep(100)
		timer = timer and timer - 100
	end
end

if FirstLoad then
	RolloverThread = false
end
if Platform.desktop then
	DeleteThread(RolloverThread)
	RolloverThread = CreateRealTimeThread(MouseRollover)
end

if Platform.console then
	function OnMsg.MouseConnected()
		DeleteThread(RolloverThread)
		RolloverThread = CreateRealTimeThread(MouseRollover)
	end

	function OnMsg.MouseDisconnected()
		DeleteThread(RolloverThread)
	end
end