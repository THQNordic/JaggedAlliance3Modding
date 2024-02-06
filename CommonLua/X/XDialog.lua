if FirstLoad then
	Dialogs = {}
end

function OpenDialog(template, parent, context, reason, id, prop_preset)
	id = id or template
	local dialog = GetDialog(id)
	if dialog then
		if context then
			dialog:SetContext(context)
		end
		local mode = ResolveValue(context, "Mode")
		if mode ~= nil then
			dialog:SetMode(mode)
		end
	else
		assert(Dialogs[id] == nil)
		dialog = XTemplateSpawn(template, parent, context)
		assert(IsKindOf(dialog, "XDialog"))
		if not dialog then
			return
		end
		dialog.XTemplate = XTemplates[template] and template or nil
		Dialogs[id] = dialog
		Dialogs[dialog] = id
		if not parent or parent.window_state == "open" then
			if prop_preset then
				dialog:CopyProperties(prop_preset, prop_preset:GatherTemplateProperties())
			end
			dialog:Open()
		end
	end
	if IsKindOf(dialog, "XDialog") then
		dialog:AddOpenReason(reason)
	end
	return dialog
end

function CloseDialog(id, result, reason)
	local dialog = GetDialog(id)
	if dialog then
		if IsKindOf(dialog, "XDialog") then
			dialog:RemoveOpenReason(reason, result)
		else
			dialog:Close(result)
		end
		return dialog
	end
end

function ListDialogs()
	local dlgs = {}
	for k,v in pairs(Dialogs) do
		if type(k)=="string" then
			dlgs[#dlgs + 1] = k
		end
	end
	table.sort(dlgs)
	return dlgs	
end

function ListAllDialogs()
	return PresetsCombo("XTemplate", nil, "InGameInterface")()
end

function RemoveOpenReason(reason, result)
	for dialog in pairs(Dialogs) do
		if IsKindOf(dialog, "XDialog") then
			dialog:RemoveOpenReason(reason, result)
		end
	end
end

function GetDialog(id_or_win)
	if type(id_or_win) == "table" and IsKindOf(id_or_win, "XWindow") then
		return GetParentOfKind(id_or_win, "XDialog")
	end
	return Dialogs[id_or_win]
end

function WaitDialog(...)
	local dialog = OpenDialog(...)
	if dialog then
		return dialog:Wait()
	end
end

function EnsureDialog(dlg)
	local dialog = GetDialog(dlg)
	if not dialog then
		local t = GetInGameInterface()
		if not t then
			ShowInGameInterface(true)
			t = GetInGameInterface()
		end
		dialog = OpenDialog(dlg, t)
	end
	return dialog
end

function GetDialogMode(id_or_win)
	local dlg = GetDialog(id_or_win)
	return dlg and dlg.Mode
end

function GetDialogModeParam(id_or_win)
	local dlg = GetDialog(id_or_win)
	return dlg and dlg.mode_param
end

function SetDialogMode(id_or_win, mode, mode_param)
	local dlg = GetDialog(id_or_win)
	if dlg then
		dlg:SetMode(mode, mode_param)
	end
end

function SetBackDialogMode(id_or_win)
	local dlg = GetDialog(id_or_win)
	if dlg then
		local mode = table.remove(dlg.mode_log)
		if mode then
			dlg:SetMode(mode[1], mode[2])
			table.remove(dlg.mode_log)
		end
	end
end

function GetDialogContext(id_or_win)
	local dlg = GetDialog(id_or_win)
	return dlg and dlg.context
end

function _GetUIPath(win, parent)
	win = win or (parent or terminal.desktop):GetMouseTarget(terminal:GetMousePos())
	parent = parent or false
	local wins = {}
	local w = win
	local f
	while w and w ~= parent do
		local name = Dialogs[w] or rawget(w, "XTemplate") or w.class
		local id = rawget(w, "Id")
		if id and name ~= id and id ~= "" then
			name = name .. "(" .. id .. ")"
		end
		local z = w.ZOrder ~= 1 and w.ZOrder
		if z then
			name = name .. "[" .. z .. "]"
		end
		if not w:IsVisible() then
			name = name .. "|X|"
		end
		if not f and w:IsFocused() then
			f = w
			name = name .. "*"
		end
		table.insert(wins, 1, name)
		w = w.parent or false
	end
	return table.concat(wins, " - ")
end

function _PrintDialogs(print_func, indent, except)
	except = except or {}
	indent = indent or ""
	print_func = print_func or print
	local texts = {}
	for name, dlg in pairs(Dialogs) do
		if type(name) == "string" and type(dlg) == "table" and not table.find(except,name) then
			texts[#texts + 1] = _GetUIPath(dlg, terminal.desktop)
			
			if dlg:IsKindOf("BaseLoadingScreen") then
				texts[#texts + 1] = "\t" .. ValueToLuaCode(dlg:GetOpenReasons())
			end
		end
	end
	table.sort(texts)
	local indents = {}
	for i=1,#texts do
		local txt = texts[i]
		for j=i+1,#texts do
			local t = texts[j]
			 local b, e = string.find(t, txt, 1, true)
			 if b then
				indents[j] = (indents[j] or 0) + 1
				texts[j] = string.sub(t, e+1)
			 end
		end
	end
	for i=1,#texts do
		local txt = texts[i]
		if indents[i] then
			txt = string.rep("\t", indents[i]) .. txt
		end
		print_func(indent, txt)
	end
end

function OnMsg.BugReportStart(print_func)
	print_func("Screen size: ", UIL.GetScreenSize())
	if next(Dialogs) ~= nil then
		print_func("Opened dialogs: (notation: (n) = Id, [n] = ZOrder, |X| = Invisible, * = Focused)")
		_PrintDialogs(print_func, "\t")
		print_func("")
	end
end

function CloseAllDialogs(except, force_loading_screens)
	if Platform.xbox then
		AsyncOpCancel(ActiveVirtualKeyboard)
	end
	CloseAllMessagesAndQuestions()
	local dialogs = ListDialogs()
	for i = 1, #dialogs do
		local dialog = dialogs[i]
		if except and except[dialog] then
			print("Skipping dialog " .. dialog)
		elseif not force_loading_screens and (IsKindOf(GetDialog(dialog), "BaseLoadingScreen") or IsKindOf(GetDialog(dialog), "BaseSavingScreen")) then
			-- should be closed by the code that opened them
		else
			CloseDialog(dialog)
		end
	end
end

function CloseDialogs(id, ...)
	if not id then return end
	CloseDialog(id)
	return CloseDialogs(...)
end

----- XDialog

DefineClass.XDialog = {
	__parents = { "XActionsHost" },
	properties = {
		{ category = "General", id = "InitialMode", editor = "text", default = "" },
		{ category = "General", id = "Mode", editor = "text", default = "", read_only = true, },
		{ category = "General", id = "InternalModes", name = "Internal modes", editor = "text", default = "", help = "A list of internal modes. When present, any mode outside of the list will be propagated to the parent dialog."},
		{ category = "General", id = "gamestate", Name = "Game state", editor = "text", default = "" },
		{ category = "General", id = "FocusOnOpen", editor = "choice", default = "self", items = {"", "self", "child"}, },
		{ category = "Visual", id = "HideInScreenshots", editor = "bool", default = false },
	},
	XTemplate = false,
	Translate = true,
	IdNode = true,
	open_reasons = false,
	result = false,
	close_controller_id = false, -- which controller was used to close the dialog
	mode_log = false,
	mode_param = false,
}

function XDialog:Init(parent, context)
	self.InitialMode = ResolveValue(context, "Mode") or self.InitialMode
	self.mode_log = ResolveValue(context, "mode_log") or {}
end

function XDialog:Close(reason, source, controller_id, ...)
	if source == "gamepad" then
		self.close_controller_id = controller_id
	end
	XActionsHost.Close(self, reason, source, controller_id, ...)
end

function XDialog:Done(result)
	Msg("DialogClose", self, result)
	local id = Dialogs[self]
	Dialogs[self] = nil
	if id and Dialogs[id] == self then
		Dialogs[id] = nil
		if self.gamestate ~= "" then
			ChangeGameState(self.gamestate, false)
		end
	end
	self.result = result
	Msg(self)
end

function XDialog:Open(...)
	if not self.HostInParent then
		self:ResolveRelativeFocusOrder()
	end
	self:SetFocus_OnOpen(self.FocusOnOpen)
	XActionsHost.Open(self, ...)
	Msg("DialogOpen", self, self.InitialMode)
	if self.InitialMode ~= "" then
		self:SetMode(self.InitialMode)
	end
	if self.gamestate ~= "" then
		ChangeGameState(self.gamestate, true)
	end
end

function XDialog:SetFocus_OnOpen(focus)
	focus = focus or self.FocusOnOpen
	if focus == "self" then
		self:SetFocus()
	elseif focus == "child" then
		local child = self:GetRelativeFocus(point(1, 1), "nearest")
		if child then
			child:SetFocus()
		end
	end
end

function XDialog:Wait()
	assert(IsAsyncCode())
	if self.window_state == "open" then
		assert(not self:GetThreadName(), "The window thread will be deleted before self:Wait() returns")
		WaitMsg(self)
	end
	return self.result, self, self.close_controller_id
end

function XDialog:AddOpenReason(reason)
	self.open_reasons = self.open_reasons or {}
	self.open_reasons[reason or true] = true
end

function XDialog:RemoveOpenReason(reason, result)
	local open_reasons = self.open_reasons
	reason = reason or true
	if open_reasons and open_reasons[reason] then
		open_reasons[reason] = nil
		if next(open_reasons) == nil and self.window_state ~= "destroying" then
			self:Close(result)
			return true
		end
	end
end

function XDialog:GetOpenReasons()
	return self.open_reasons or empty_table
end

local function callOnModeChange(win, mode, dialog)
	if win == dialog or not IsKindOf(win, "XDialog") then
		for _, win in ipairs(win or empty_table) do
			callOnModeChange(win, mode, dialog)
		end
	end
	win:OnDialogModeChange(mode, dialog)
end

function MatchDialogMode(mode, list)
	if not list or list == "" then return end
	if mode == "" then
		return list:starts_with(",") -- the first mode in the list can be ""
	end
	if mode == list then
		return true
	end
	if not list:find(mode, 1, true) then
		return
	end
	for m in list:gmatch("([%w%-_]+)") do
		if m == mode then
			return true
		end
	end	
end

function XDialog:GetModes(list)
	list = list or self.InternalModes or ""
	local arr = { list:starts_with(",") and "" or nil }
	for m in list:gmatch("([%w%-_]+)") do
		arr[#arr + 1] = m
	end	
	return arr
end

function XDialog:SetMode(mode, mode_param)
	if not MatchDialogMode(mode, self.InternalModes) then
		local dlg = GetParentOfKind(self.parent, "XDialog")
		if dlg then
			dlg:SetMode(mode, mode_param)
			return
		end
	end
	self.mode_log[#self.mode_log + 1] = { self.Mode, self.mode_param }
	local old_mode = self.Mode
	self.Mode = mode
	self.mode_param = mode_param
	Msg("DialogSetMode", self, mode, mode_param, old_mode)
	self:CallOnModeChange()
end

function XDialog:CallOnModeChange()
	callOnModeChange(self, self.Mode, self)
end

----- XLayer

DefineClass.XLayer = {
	__parents = { "XDialog" },
	FocusOnOpen = "",
}


----- XOpenLayer

DefineClass.XOpenLayer = {
	__parents = { "XWindow" },
	properties = {
		{ category = "General", id = "Layer", editor = "combo", default = "", items = function() return XTemplateCombo("XLayer") end, },
		{ category = "General", id = "LayerId", editor = "text", default = "", },
		{ category = "General", id = "Mode", editor = "text", default = false, },
	},
	Dock = "ignore",
	visible = false,
	dialog = false,
	xtemplate = false,
}

function XOpenLayer:Open()
	if self.Layer ~= "" then
		local context = self:GetContext()
		if self.Mode then
			context = SubContext(context, { Mode = self.Mode })
		end
		local id = self.LayerId ~= "" and self.LayerId or nil
		self.dialog = OpenDialog(self.Layer, nil, context, self, id, self.xtemplate)
	end
end

function XOpenLayer:Done()
	if self.dialog then
		CreateRealTimeThread(self.dialog.RemoveOpenReason, self.dialog, self)
	end
end


----- XContentTemplate

DefineClass.XContentTemplate = {
	__parents = { "XActionsHost" },
	properties = {
		{ category = "Template", id = "RespawnOnContext", name = "Respawn on context update", editor = "bool", default = true, },
		{ category = "Template", id = "RespawnOnDialogMode", name = "Respawn on mode change", editor = "bool", default = true, },
		{ category = "Template", id = "RespawnExpression", name = "Respawn on expression change", editor = "expression", default = empty_func, params = "self, context", 
			dont_save = function(self) return self.RespawnOnContext end },
	},
	IdNode = true,
	HostInParent = true,
	xtemplate = false,
	respawn_value = false,
}

function XContentTemplate:Init(parent, context, xtemplate)
	self.xtemplate = xtemplate
	self.respawn_value = self:RespawnExpression(context)
end

function XContentTemplate:OnContextUpdate(context, ...)
	if self.RespawnOnContext then
		if self.window_state == "open" then
			self:RespawnContent()
		end
	else
		local respawn_value = self:RespawnExpression(context)
		if rawget(self, "respawn_value") ~= respawn_value then
			self.respawn_value = respawn_value
			if self.window_state == "open" then
				self:RespawnContent()
			end
		end
	end
end

function XContentTemplate:OnDialogModeChange(mode, dialog)
	if self.RespawnOnDialogMode then
		self:RespawnContent()
	end
end

function XContentTemplate:RespawnContent()
	local xtemplate = self.xtemplate
	if xtemplate then
		local desktop = self.desktop
		local focus = desktop.keyboard_focus
		local focus_order = focus and focus:IsWithin(self) and focus:GetFocusOrder()
		local gamepad_rollover = RolloverControl and RolloverControl == focus and RolloverGamepad
		local mouse_rollover = RolloverControl and RolloverControl == desktop.last_mouse_target and RolloverControl:IsWithin(self)
		self:DeleteChildren()
		self:ClearActions()
		xtemplate:EvalChildren(self, self.context)
		for _, win in ipairs(self) do
			win:Open()
		end
		self:InvalidateMeasure()
		self:InvalidateLayout()
		local host = GetActionsHost(self, true)
		if not host or host == self then
			self:ResolveRelativeFocusOrder()
		elseif host and not host:GetThread("resolve_focus") then
			host:CreateThread("resolve_focus", host.ResolveRelativeFocusOrder, host)
		end
		self:DeleteThread("rollover")
		self:CreateThread("rollover", function(self, focus_order, gamepad_rollover, mouse_rollover)
			local focus = self:GetRelativeFocus(focus_order, "nearest")
			if focus then
				focus:SetFocus()
			end
			if focus and gamepad_rollover then
				XCreateRolloverWindow(focus, true, true)
			elseif mouse_rollover then
				local win = XGetRolloverControl()
				if win and win:IsWithin(self) then
					XCreateRolloverWindow(win, false, true)
				end
			end
		end, self, focus_order, gamepad_rollover, mouse_rollover)
		Msg("XWindowRecreated", self)
	end
end


----- XContentTemplateScrollArea

DefineClass.XContentTemplateScrollArea = {
	__parents = { "XScrollArea", "XContentTemplate" },
}


----- XContentTemplateList

DefineClass.XContentTemplateList = {
	__parents = { "XList", "XContentTemplate" },
	MouseScroll = false,
	properties = {
		{ category = "General", id = "KeepSelectionOnRespawn", editor = "bool", default = false },
	},
}

function XContentTemplateList:OnShortcut(shortcut, source, ...)
	if XList.OnShortcut(self, shortcut, source, ...) == "break" then
		return "break"
	end
	return XActionsHost.OnShortcut(self, shortcut, source, ...)
end

function XContentTemplateList:Open(...)
	self:GenerateItemHashTable()
	XContentTemplate.Open(self, ...)
	self:CreateThread("SetInitialSelection", self.SetInitialSelection, self)
end

function XContentTemplateList:RespawnContent()
	local last_selection
	if self.KeepSelectionOnRespawn and next(self.selection) then
		last_selection = self.selection[1]
	end
	XContentTemplate.RespawnContent(self)
	self:GenerateItemHashTable()
	self:DeleteThread("SetInitialSelection")
	self:CreateThread("SetInitialSelection", self.SetInitialSelection, self, last_selection)
end