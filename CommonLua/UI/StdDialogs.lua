if FirstLoad then
	g_OpenMessageBoxes = {}
end

DefineClass.StdDialog = {
	__parents = { "XDialog", "XDarkModeAwareDialog" },
	
	HAlign = "center",
	VAlign = "center",
	BorderWidth = 1,
	BorderColor = RGB(0, 0, 0),
	Background = RGBA(0, 0, 0, 255),
	MinWidth = 350,
	MinHeight = 150,
	Translate = true,
}

function StdDialog:Init(parent, context)
	context = context or empty_table
	if context.title then
		XLabel:new({
			Id = "idTitle",
			Dock = "top",
			Margins = box(4, 4, 4, 0),
			TextStyle = "GedTitle",
			Translate = context.translate,
		}, self)
		self.idTitle:SetText(context.title)
	end
	
	XWindow:new({
		Id = "idContainer",
		Background = RGB(240, 240, 240),
		BorderWidth = 1,
		BorderColor = RGB(160, 160, 160),
		Margins = box(6, 6, 6, 6),
		Padding = box(8, 8, 8, 8),
		MaxWidth = 900,
	}, self)
	XWindow:new({
		Id = "idButtonContainer",
		Dock = "bottom",
		LayoutMethod = "HList",
		LayoutHSpacing = 4,
		HAlign = "center",
		Margins = box(0, 11, 0, 0),
	}, self.idContainer)

	self:SetModal()
	local dark_mode
	if context.dark_mode ~= nil then 
		dark_mode = context.dark_mode
	else
		dark_mode = GetDarkModeSetting()
	end
	self:SetDarkMode(dark_mode)
end

function StdDialog:Open(...)
	RegisterMessageBox(self)
	XDialog.Open(self, ...)
	self:UpdateControlDarkMode(self)
	self:UpdateChildrenDarkMode(self)
end

function StdDialog:Close(...)
	UnregisterMessageBox(self)
	XDialog.Close(self, ...)
end

local list_bg = RGB(64, 64, 66)
local list_focus = RGB(150, 150, 150)
local l_list_bg = RGB(255, 255, 255)
local l_list_focus = RGB(255, 255, 255)
 
local item_selection =  RGB(100, 100, 100)
local l_item_selection = RGB(204, 232, 255)

local btn_bg = RGB(100, 100, 100)
local l_btn_bg = RGB(240, 240, 240)

local btn_selected = RGB(150, 150, 150)
local btn_rollover = RGB(120, 120, 120)

local l_btn_selected = RGB(204, 232, 255)
local l_btn_rollover = RGB(180, 180, 180)

local scroll = RGB(128, 128, 128)
local scroll_background = RGB(64, 64, 66)

local l_scroll = RGB(169, 169, 169)
local l_scroll_background = RGB(240, 240, 240)

function StdDialog:UpdateChildrenDarkMode(win)
	if IsKindOf(win, "XSleekScroll") then
		return
	end
	XDarkModeAwareDialog.UpdateChildrenDarkMode(self, win)
end

function StdDialog:UpdateControlDarkMode(control)
	XDarkModeAwareDialog.UpdateControlDarkMode(self, control)

	local dark_mode = self.dark_mode
	if IsKindOf(control, "XList") then
		control:SetBackground(dark_mode and list_bg or l_list_bg)
		control:SetFocusedBackground(dark_mode and list_focus or l_list_focus)
	end
	if IsKindOf(control, "XListItem") then 
		control:SetBackground(dark_mode and list_bg or l_list_bg)
		control:SetSelectionBackground(dark_mode and item_selection or l_item_selection)
	end
	if IsKindOf(control, "XTextButton") then 
		if control:GetBackground() ~= RGBA(0,0,0,0) then
			control:SetBackground(dark_mode and btn_bg or l_btn_bg)
			control:SetRolloverBackground(dark_mode and btn_rollover or l_btn_rollover)
			control:SetPressedBackground(dark_mode and btn_selected or l_btn_selected)
		end
	end
	if IsKindOf(control, "XSleekScroll") then
		control.idThumb:SetBackground(dark_mode and scroll or l_scroll)
		control:SetBackground(dark_mode and scroll_background or l_scroll_background)
	end
end


----- StdStatusDialog

DefineClass.StdStatusDialog = {
	__parents = { "StdDialog" },
	HandleMouse = false,
	MinWidth = 200,
	MinHeight = 50,
	DrawOnTop = true,
}

function StdStatusDialog:Init(parent, context)
	XText:new({
		Id = "idText",
		TextHAlign = "center",
		TextVAlign = "center",
		Translate = context and context.translate,
		Margins = box(10, 7, 10, 7),
	}, self)
	self.idText:SetText(context and context.status or "")
	self:SetModal(false)
end

function StdStatusDialog:SetStatus(text)
	self.idText:SetText(text)
	WaitNextFrame(3)
end


----- StdMessageDialog

DefineClass.StdMessageDialog = {
	__parents = { "StdDialog" },
	HandleKeyboard = true,
	DrawOnTop = true,
}

function StdMessageDialog:Init(parent, context)
	context = context or empty_table
	
	XScrollArea:new({
		Id = "idScrollArea",
		VAlign = "top",
		LayoutMethod = "VList",
		VScroll = "idScroll",
		IdNode = false,
	}, self.idContainer)
	XSleekScroll:new({
		Dock = "right",
		Target = "idScrollArea",
		Id = "idScroll",
		AutoHide = true,
	}, self.idContainer)
	XText:new({
		Id = "idText",
		TextVAlign = "center",
		Translate = context.translate,
	}, self.idScrollArea)
	self.idText:SetText(context.text or "")
	
	if context.choices then
		for i=1,#context.choices do
			XTextButton:new({
				Id = "idChoice" .. i,
				MinWidth = 100,
				Translate = context.translate,
				Text = context.choices[i],
				LayoutMethod = "VList",
				OnPress = function() self:Close(i) end,
			}, self.idButtonContainer)
		end
	else
		XTextButton:new({
			Id = "idOKText",
			MinWidth = 100,
			Translate = context.translate,
			Text = context.ok_text or context.translate and T(325411474155, "OK") or "OK",
			LayoutMethod = "VList",
			ActionShortcut = "Enter",
			ActionGamepad = "ButtonA",
			OnPress = function() self:Close("ok") end,
		}, self.idButtonContainer)
		if context.question then
			XTextButton:new({
				Id = "idCancelText",
				MinWidth = 100,
				Translate = context.translate,
				Text = context.cancel_text or context.translate and T(967444875712, "Cancel") or "Cancel",
				LayoutMethod = "VList",
				ActionShortcut = "Escape",
				ActionGamepad = "ButtonB",
				OnPress = function() self:Close("cancel") end,
			}, self.idButtonContainer)
		end
	end
	
	self:SetFocus()
end

function StdMessageDialog:PreventClose()
	if self:HasMember("idOKText") then
		self.idOKText:SetVisible(false)
	elseif self:HasMember("idCancelText") then 
		self.idCancelText:SetVisible(false)
	end
	self.OnShortcut = empty_func
end

function StdMessageDialog:OnShortcut(shortcut, ...)
	if self:HasMember("idOKText") and self.idOKText:IsVisible() and (shortcut == "Enter" or shortcut == "ButtonA") then
		self:Close("ok", ...)
		return "break"
	elseif self:HasMember("idCancelText") and self.idCancelText:IsVisible() and (shortcut == "Escape" or shortcut == "ButtonB") then
		self:Close("cancel", ...)
		return "break"
	end
end


----- StdInputDialog

DefineClass.StdInputDialog = {
	__parents = { "StdDialog" },
	
	FocusOnOpen = "",
}

function StdInputDialog:Init(parent, context)
	if context.free_input then
		XWindow:new({
			Id = "idSubContainer",
			Dock = "top",
		}, self.idContainer)
		XText:new({
			Id = "idFreeLabel",
			Dock = "left",
			Translate = true,
		}, self.idSubContainer):SetText(T(998885500683, "Input: "))
		XEdit:new({
			Id = "idFreeInput",
			Dock = "top",
			Margins = box(0, 0, 0, 7),
			Background = RGB(255, 255, 255),
			FocusedBackground = RGB(255, 255, 255),
			AutoSelectAll = true,
			AllowEscape = false,
			MaxLen = context.max_len,
		}, self.idSubContainer)
	end

	XTextButton:new({
		Id = "idOKText",
		MinWidth = 100,
		Translate = true,
		Text = T(325411474155, "OK"),
		LayoutMethod = "VList",
		OnPress = function() self:SelectAndClose() end,
	}, self.idButtonContainer)
	XTextButton:new({
		Id = "idCancelText",
		MinWidth = 100,
		Translate = true,
		Text = T(967444875712, "Cancel"),
		LayoutMethod = "VList",
		OnPress = function() self:Close() end,
	}, self.idButtonContainer)
	
	if context.items and context.combo then
		XCombo:new({
			Id = "idInput",
			VAlign = "center",
			Background = RGB(255, 255, 255),
			FocusedBackground = RGB(255, 255, 255),
			Items = context.items,
			VirtualItems = true,
		}, self.idContainer)
		self.idInput:SetValue(context.items[context.default])
		self.idInput:SetFocus()
	elseif context.items then
		if context.free_input then
			XWindow:new({
				Id = "idSubContainer2",
				Dock = "top",
			}, self.idContainer)
			XText:new({
				Id = "idFilterLabel",
				Dock = "left",
				Translate = true,
			}, self.idSubContainer2):SetText(T(173389874804, "Filter:"))
		end
		XEdit:new({
			Id = "idFilter",
			Dock = "top",
			Margins = box(0, 0, 0, 7),
			AllowEscape = false,
			OnTextChanged = function(edit)
				self.idInput:Clear()
				local pattern = edit:GetText()
				local lower_pattern = string.lower(pattern)
				
				local sorted_items = {}
				for idx, item in ipairs(context.items) do
					local match, score, match_indices = string.fuzzy_match(pattern, item)
					if pattern == "" or match then
						local s, e = string.find(string.lower(item), lower_pattern, 1, true)
						if s then
							match_indices = {}
							for i = s, e do 
								match_indices[#match_indices + 1] = i
							end
							sorted_items[#sorted_items + 1] = { 
								idx = idx,
								text = HighlightFuzzyMatches(item, match_indices, "<style GedSearchHighlightPartial>", "</style>"),
								score = 1000000,
							}
						else
							sorted_items[#sorted_items + 1] = { 
								idx = idx,
								text = match_indices and HighlightFuzzyMatches(item, match_indices, "<style GedSearchHighlight>", "</style>") or item,
								score = score,
							}
						end
					end
				end
				table.stable_sort(sorted_items, function(a, b) return a.score > b.score end)
				for k, v in ipairs(sorted_items) do
					local item = self.idInput:CreateTextItem(v.text, { selectable = true })
					rawset(item, "choice_idx", v.idx)
				end
				self.idInput:SetSelection(1)
				Msg("XWindowRecreated", self.idInput)
			end,
			OnShortcut = function(edit, shortcut, ...)
				if shortcut == "Up" or shortcut == "Down" or shortcut == "Ctrl-Home" or shortcut == "Ctrl-End" or
					shortcut == "Pageup" or shortcut == "Pagedown" or shortcut == "DPadUp" or shortcut == "DPadDown" then
					return self.idInput:OnShortcut(shortcut, ...)
				end
				return XEdit.OnShortcut(edit, shortcut, ...)
			end,
		}, context.free_input and self.idSubContainer2 or self.idContainer)
		
		XWindow:new({
			Id = "idListParent",
			BorderWidth = 1,
		}, self.idContainer)
		local list = XList:new({
			Id = "idInput",
			VAlign = "center",
			WorkUnfocused = true,
			FocusedBackground = RGB(255, 255, 255),
			VScroll = "idScroll",
			MultipleSelection = context.multiple,
			BorderWidth = 0,
			
			OnDoubleClick = function(this, item_idx)
				local item = context.items[this[item_idx].choice_idx]
				self:Close(context.multiple and { item } or item)
			end,
			}, self.idListParent)
		XSleekScroll:new({
			Id = "idScroll",
			Dock = "right",
			AutoHide = true,
			MinThumbSize = 30,
			FixedSizeThumb = false,
			Target = "idInput",
		}, self.idListParent)
		if context.multiple then
			XText:new({ Dock = "bottom", TextHAlign = "center" }, self.idContainer):SetText("(hold Ctrl or Shift to select multiple items)")
		end
		
		for k, v in ipairs(context.items) do
			local text = v
			if type(v) == "table" and v.text then
				text = v.text
			end
			local item = list:CreateTextItem(text, { selectable = true })
			rawset(item, "choice_idx", k)
		end
		
		local itemHeight = #list > 0 and list[1][1]:GetFontHeight() or 0 
		local lCnt = Clamp(context.lines or 18, 5, 18)
		list:SetMaxHeight(lCnt * itemHeight)
		list:SetMinHeight(Min(lCnt, #list) * itemHeight)
		if context.multiple then
			list:SetSelection(context.multiple and context.default)
		else
			list:SetSelection(table.find(context.items, context.default) or 1)
		end
		if context.free_input then
			self.idFreeInput:SetFocus()
		else
			self.idFilter:SetFocus()
		end
	else
		XText:new({
			Id = "idError",
			Dock = "bottom",
			Translate = true,
			HideOnEmpty = true,
			FoldWhenHidden = true,
		}, self.idContainer)
		if context.description and context.description ~= "" then
			local desc = XText:new({
				Dock = "top",
				Translate = context.translate,
				TextHAlign = "center",
			}, self.idContainer)
			desc:SetText(context.description .. "\n\n")
		end
		XEdit:new({
			Id = "idInput",
			VAlign = "center",
			Background = RGB(255, 255, 255),
			FocusedBackground = RGB(255, 255, 255),
			AutoSelectAll = true,
			AllowEscape = false,
			MaxLen = context.max_len,
			OnTextChanged = function(ctrl)
				if (self.idError:GetText() or "") ~= "" then
					self:VerifyInputText()
				end
				XEdit.OnTextChanged(ctrl)
			end
		}, self.idContainer)
		self.idInput:SetText(context.default)
		self.idInput:SetFocus()
	end
end

function StdInputDialog:VerifyInputText()
	local free_text = self.idFreeInput and self.idFreeInput:GetText() or ""
	local closeParam = (free_text ~= "") and free_text or self.idInput:GetText()
	local error_text = self.context.verifier and self.context.verifier(closeParam) or ""
	self.idError:SetText(error_text)
	return (error_text or "") == ""
end

function StdInputDialog:OpenControllerTextInput(title, description)
	if not self:IsThreadRunning("keyboard") then
		self:CreateThread("keyboard", function()
			local current_text = self.idInput and self.idInput:GetText() or ""
			local text, err, shown = WaitControllerTextInput(current_text, title, 
									description, 256)
			if not err and self.window_state ~= "destroying" then
				text = text:trim_spaces()
				if text ~= current_text then
					self:OnControllerTextInput(text)
				end
			end
		end)
	end
end

function StdInputDialog:OnControllerTextInput(text)
	self.idInput:SetText(text)
end

function StdInputDialog:SelectAndClose(...)
	local input = self.idInput
	local closeParam = false
	local closeCond = true
	local free_text = self.idFreeInput and self.idFreeInput:GetText() or ""
	if free_text ~= "" then
		closeParam = free_text
	elseif input:IsKindOf("XCombo") then 
		closeParam = input:GetValue() 
	elseif input:IsKindOf("XList") then
		local list = self.idInput
		local items = self.context.items
		if self.context.multiple then
			local selection = input:GetSelection()
			closeParam = selection and table.map(selection, function(sel_idx) return items[list[sel_idx].choice_idx] end)
		else
			closeParam = input:GetFocusedItem() and items[list[input:GetFocusedItem()].choice_idx]
		end
	else
		closeParam = input:GetText()
		closeCond = self:VerifyInputText()
	end
	
	if closeCond then
		self:Close(closeParam, ...)
	end
end

function StdInputDialog:OnShortcut(shortcut, ...)
	if shortcut == "ButtonY" then
		if HasControllerTextInput() then
			self:OpenControllerTextInput(IsT(self.context.title) and self.context.title or Untranslated(self.context.title), "")
		end
		return
	end
	if self.idOKText:IsVisible() and (shortcut == "Enter" or shortcut == "ButtonA") then
		self:SelectAndClose(...)
		return "break"
	elseif self.idCancelText:IsVisible() and (shortcut == "Escape" or shortcut == "ButtonB") then
		self:Close(nil, ...)
		return "break"
	end
end


----- StdChoiceDialog

DefineClass.StdChoiceDialog = {
	__parents = {"StdDialog"},
	MaxWidth = 900,
}

function StdChoiceDialog:Init(parent, context)
	XCameraLockLayer:new({}, self)
	XPauseLayer:new({}, self)
	XScrollArea:new({
		Id = "idScrollArea",
		VAlign = "top",
		LayoutMethod = "VList",
		VScroll = "idScroll",
		IdNode = false,
	}, self.idContainer)
	XSleekScroll:new({
		Dock = "right",
		Target = "idScrollArea",
		Id = "idScroll",
		AutoHide = true,
	}, self.idContainer)
	XText:new({
		Id = "idText",
		TextVAlign = "center",
		Translate = context.translate,
	}, self.idScrollArea)
	self.idText:SetText(context.text or "")
	local i = 1
	local disabled = context.disabled
	local buttons = self.idButtonContainer
	buttons:SetLayoutMethod("VList")
	buttons:SetLayoutVSpacing(5)
	while true do
		local choice = context["choice" .. i]
		if not choice and i == 1 then
			choice = T(325411474155, "OK")
		end
		if not choice then break end
		local res = i
		local button = XTextButton:new({
			OnPress = function(self, gamepad)
				GetDialog(self):Close(res)
			end,
			Background = RGB(175,175,175),
		}, buttons)
		local text = XText:new({
			Translate = context.translate,
		}, button)
		text:SetText(T{choice, context.params, context})
		if disabled and disabled[i] then
			button:SetEnabled(false)
		end
		i = i + 1
	end
end

function WaitPopupChoice(parent, context, id)
	local dialog = StdChoiceDialog:new({Id = id}, parent or terminal.desktop, context)
	dialog:Open()
	return dialog:Wait()
end

function WaitInputText(parent, caption, text, max_len, verifier, id, description)
	if not caption or caption == "" then caption = "Enter text:" end
	if not text or text == "" then text = "Text..." end
	local dialog = StdInputDialog:new({Id = id}, parent or terminal.desktop, { title = caption, default = text, max_len = max_len, verifier = verifier, description = description })
	dialog:Open()
	if HasControllerTextInput() and GetUIStyleGamepad() then
		dialog:OpenControllerTextInput(IsT(caption) and caption or Untranslated(caption), "")
	end
	return dialog:Wait()
end

function WaitListChoice(parent, items, caption, start_selection, lines, free_input, id)
	if not caption or caption == "" then caption = "Please select:" end
	if not items or type(items) ~= "table" or #items == 0 then items = {""} end
	if not start_selection then start_selection = items[1] end

	local dialog = StdInputDialog:new({Id = id}, parent or terminal.desktop, {
		title = caption, default = start_selection, items = items, lines = lines, free_input = free_input})
	dialog:Open()
	return dialog:Wait()
end

function WaitListMultipleChoice(parent, items, caption, start_selection, lines, id)
	if not caption or caption == "" then caption = "Please select one or more:" end
	if not items or type(items) ~= "table" or #items == 0 then items = {""} end
	if not start_selection then start_selection = {1} end
	
	local dialog = StdInputDialog:new({Id = id}, parent or terminal.desktop, { multiple = true, title = caption, default = start_selection, items = items, lines = lines } )
	dialog:Open()
	return dialog:Wait()
end

-- Message Box functions ---

function CreateMessageBox(parent, caption, text, ok_text, obj)
	if not caption or caption == "" then caption = Untranslated("Enter text:") end
	if not text then text = "" end
	ok_text = ok_text or T(325411474155, "OK")
	parent = parent or terminal.desktop
	
	local dialog = StdMessageDialog:new({}, parent, { title = caption, text = text, translate = true, obj = obj })
	dialog.idOKText:SetText(ok_text)
	dialog:Open()
	return dialog
end

-- function should always be called in a thread

function WaitMessage(parent, caption, text, ok_text, obj)
	local dialog = CreateMessageBox(parent, caption, text, ok_text, obj)
	local result, dataset, controller_id = dialog:Wait()
	return result, dataset, controller_id
end

-- Message Question Box functions ---

function CreateQuestionBox(parent, caption, text, ok_text, cancel_text, obj)
	local dialog = StdMessageDialog:new({}, parent or terminal.desktop, {
		title = caption or "",
		text = text or "",
		ok_text = ok_text or T(325411474155, "OK"),
		cancel_text = cancel_text or T(967444875712, "Cancel"),
		translate = true,
		question = true,
		obj = obj
	})
	dialog:Open()
	return dialog
end

function WaitQuestion(parent, caption, text, ok_text, cancel_text, obj)
	parent = parent or terminal.desktop
	if type(caption) == "string" then caption = Untranslated(caption) end
	if type(text) == "string" then text = Untranslated(text) end
	assert(type(parent) == "table" and parent.IsKindOf and parent:IsKindOf("XWindow"), "The first argument must be a parent window. Don't just create 'global' messages, attach them to the correct parent so they'd share their lifetimes.", 1)
	local dialog
	if IsKindOf(caption, "XDialog") then
		dialog = caption
	else
		dialog = CreateQuestionBox(parent, caption, text, ok_text, cancel_text, obj)
	end
	local result, dataset, controller_id = dialog:Wait()
	return result, dataset, controller_id
end

function CreateMultiChoiceQuestionBox(parent, caption, text, obj, ...)
	local dialog = StdMessageDialog:new({}, parent or terminal.desktop, {
		title = caption or "",
		text = text or "",
		choices = { ... },
		translate = true,
		obj = obj
	})
	dialog:Open()
	return dialog
end

function WaitMultiChoiceQuestion(parent, caption, text, obj, ...)
	assert(type(parent) == "table" and parent.IsKindOf and parent:IsKindOf("XWindow"), "The first argument must be a parent window. Don't just create 'global' messages, attach them to the correct parent so they'd share their lifetimes.", 1)
	local dialog
	if IsKindOf(caption, "XDialog") then
		dialog = caption
	else
		dialog = CreateMultiChoiceQuestionBox(parent, caption, text, obj, ...)
	end
	local result, dataset, controller_id = dialog:Wait() 
	return result, dataset, controller_id
end

function RegisterMessageBox(message_box)
	g_OpenMessageBoxes[message_box] = true
	Msg("MessageBoxRegister", message_box)
end

function UnregisterMessageBox(message_box)
	g_OpenMessageBoxes[message_box] = nil
	Msg("MessageBoxUnregister", message_box)
end

function CloseAllMessagesAndQuestions()
	for window,dummy in pairs(g_OpenMessageBoxes) do
		if window.window_state ~= "destroying" then
			window:Close()
		end
	end
end

function AreMessageBoxesOpen()
	return next(g_OpenMessageBoxes)
end

function IsMessageBoxOpen(id_or_dlg)
	if g_OpenMessageBoxes[id_or_dlg] then return true end
	for message_box in pairs(g_OpenMessageBoxes) do
		if message_box.Id == id_or_dlg then
			return true
		end
	end
end