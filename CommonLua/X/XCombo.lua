if FirstLoad then
	OpenXCombo = false
end

DefineClass.XComboButton = {
	__parents = { "XTextButton" },
	Dock = "right",
	Padding = box(1, 3, 1, 1),
	Margins = box(2, 0, 0, 0),
	Icon = "CommonAssets/UI/arrowdown-40.tga",
	IconScale = point(500, 500),
	Background = RGB(38, 146, 227),
	RolloverBackground = RGB(24, 123, 197),
	PressedBackground = RGB(13, 113, 187),
	DisabledBackground = RGB(128, 128, 128),
}

-- The actual combo list items inherit XComboListItem and are defined as XTemplates
DefineClass.XComboListItem = {
	__parents = { "XTextButton" },
	Image = "CommonAssets/UI/round-frame-20.tga",
	FrameBox = box(9, 9, 9, 9),
	ImageScale = point(500, 500),
	Background = RGBA(0, 0, 0, 0),
	RolloverTemplate = "GedPropRollover",
	UseClipBox = false,
}

DefineClass.XCombo = {
	__parents = { "XFontControl", "XContextControl" },
	properties = {
		{ category = "General", id = "Translate", editor = "bool", default = false, },
		{ category = "General", id = "VirtualItems", editor = "bool", default = false, },
		{ category = "General", id = "Value", editor = "text", default = "", no_edit = true },
		{ category = "General", id = "DefaultValue", editor = "text", default = "" },
		{ category = "General", id = "Items", editor = "expression", default = false, params = "self" },
		{ category = "General", id = "RefreshItemsOnOpen", editor = "bool", default = false },
		{ category = "General", id = "MaxItems", editor = "number", default = 25, },
		{ category = "General", id = "ArbitraryValue", name = "Allow arbitrary value", editor = "bool", default = true, },
		{ category = "General", id = "AutoSelectAll", editor = "bool", default = true, },
		{ category = "General", id = "SetValueOnLoseFocus", editor = "bool", default = true, },
		{ category = "General", id = "ButtonTemplate", editor = "choice", default = "XComboButton", items = function() return XTemplateCombo("XTextButton") end, },
		{ category = "General", id = "ListItemTemplate", editor = "choice", default = "XComboListItemLight", items = function() return XTemplateCombo("XComboListItem") end, },
		{ category = "General", id = "Hint", editor = "text", default = "", },
		{ category = "Most Recently Used Items", id = "MRUStorageId", name = "Storage Id",    editor = "text",   default = "", },
		{ category = "Most Recently Used Items", id = "MRUCount",     name = "Entries count", editor = "number", default =  5, },
		{ category = "Interaction", id = "OnValueChanged", editor = "func", params = "self, value", default = empty_func },
		{ category = "Interaction", id = "OnItemRightClicked", editor = "func", params = "self, value", default = empty_func },
	},
	Padding = box(2, 1, 1, 1),
	BorderWidth = 1,
	BorderColor = RGB(128, 128, 128),
	DisabledBorderColor = RGBA(128, 128, 128, 128),
	Background = RGB(240, 240, 240),
	FocusedBackground = RGB(255, 255, 255),
	PopupBackground = RGB(255, 255, 255),
	value = false,
	
	popup = false,
	last_text = false,
	mru_list = false,
	mru_value_changed = false,
	suppress_autosuggest = false,
	-- operation to be performed after items are fetched
	pending_input = false,
	pending_input_type = false,
}

local function ItemId(item)
	if type(item) == "table" then
		return item.id or (item.value ~= nil and item.value)
	end
	return item
end

local function ItemText(item)
	if type(item) == "table" then
		return item.name or item.text or item.id
	end
	return tostring(item)
end

local function RawText(text, translate)
	if translate then
		assert(not text or IsT(text))
		return text and TDevModeGetEnglishText(text)
	end
	return text
end

local function StringText(text, translate)
	if translate then
		assert(not text or IsT(text))
		return text and _InternalTranslate(text)
	end
	return text
end

function XCombo:Init(parent, context)
	local edit = XEdit:new({
		Id = "idEdit", 
		VAlign = "center",
		Padding = box(0, 0, 0, 0),
		Background = RGBA(0, 0, 0, 0),
		BorderColor = RGBA(0, 0, 0, 0),
		BorderWidth = 0,
		AllowEscape = false,
		Hint = self.Hint,
		OnMouseButtonDown = function(edit, pt, button)
			if button == "L" and not self.popup then
				self:OpenCombo()
				if self.AutoSelectAll then return "break" end
			end
			return XEdit.OnMouseButtonDown(edit, pt, button)
		end,
		OnShortcut = function(edit, shortcut, source, ...)
			if shortcut == "Enter" then
				self:TextChanged(self:GetText())
				if self:IsPopupOpen() then
					self:CloseCombo()
					return "break"
				end
			end
			if shortcut == "ButtonA" then
				self:OpenCombo("select")
				return "break"
			end
			return XEdit.OnShortcut(edit, shortcut, source, ...)
		end,
		OnKillFocus = function(edit, new_focus)
			local popup = self.popup
			if not self.SetValueOnLoseFocus or popup and new_focus and new_focus:IsWithin(popup) then
				return XEdit.OnKillFocus(edit)
			end
			local text = self:GetText()
			if text ~= self.last_text then
				self.last_text = text
				self:TextChanged(text)
			end
			return XEdit.OnKillFocus(edit)
		end,
		OnTextChanged = function(edit)
			XEdit.OnTextChanged(edit)
			if self.suppress_autosuggest then
				self.suppress_autosuggest = false
				return
			end
			self:OpenCombo("suggest")
		end,
	}, self, context)
	edit:SetFontProps(self)
	edit:SetTranslate(self.Translate)
	self:SetButtonTemplate(self.ButtonTemplate)
end

function XCombo:IsPopupOpen()
	return self.popup and self.popup.window_state ~= "destroying"
end

function XCombo:Open(...)
	if rawget(self, "value") == nil then
		self:SetValue(self.DefaultValue, true)
	end
	XContextWindow.Open(self, ...)
end

function XCombo:SetButtonTemplate(template_id)
	if self:HasMember("idButton") then
		if self.idButton.window_state == "open" then
			self.idButton:Close()
		else
			self.idButton:delete()
		end
	end	
	self.ButtonTemplate = template_id
	local button = XTemplateSpawn(self.ButtonTemplate, self, self.context)
	button:SetId("idButton")
	button.OnPress = function(button)
		if self:IsPopupOpen() then
			self:CloseCombo()
		else
			self:OpenCombo("select")
		end
	end
end

LinkFontPropertiesToChild(XCombo, "idEdit")
LinkPropertyToChild(XCombo, "Translate", "idEdit")

function XCombo:OnDelete()
	self:CloseCombo()
end

function XCombo:ResolveItems()
	local items = self.Items
	while type(items) == "function" do
		items = items(self)
	end
	return type(items) == "table" and items or empty_table
end

-- if value ~= text, SetValue needs to fetch the items. Use this function if you already know the text
-- This function is not validating the value!!!
function XCombo:SetValueWithText(value, text, dont_notify)
	self:SetText(text or "")
	local old_value = self:GetValue()
	if old_value ~= value then
		self.value = value
		if not dont_notify then
			self:OnValueChanged(self.value)
		end
	end
end

function XCombo:SetValue(value, do_not_validate)
	if not do_not_validate and not self.Items then
		self.pending_input = value
		self.pending_input_type = "value"
		self:FetchItemsAndValidate()
		return
	end
	
	for _, item in ipairs(self:ResolveItems()) do
		if ItemId(item) == value then
			self:SetText(ItemText(item))
			if self.value ~= ItemId(item) then
				self.value = ItemId(item)
				self:OnValueChanged(self.value)
			end
			return
		end
	end
	
	local old_value = self:GetValue()
	if self.ArbitraryValue or do_not_validate then
		self.value = value
		self:SetText(value == Undefined() and value or tostring(value))
	else
		self.value = nil
	end
	
	self:UpdateMRUList()
	
	if old_value ~= self:GetValue() then
		self:OnValueChanged(self:GetValue())
		return true
	end
end

function XCombo:SetText(text)
	self.suppress_autosuggest = true
	if text == Undefined() then
		self.idEdit:SetHint("Undefined")
		text = ""
	else
		self.idEdit:SetHint("")
	end
	self.idEdit:SetText(text)
	self.last_text = text
	self.idEdit.cursor_pos = #text
end

function XCombo:TextChanged(text)
	local translate = self:GetTranslate()
	local raw_text = RawText(text, translate)
	
	if not self.Items then
		self.pending_input = raw_text
		self.pending_input_type = "text"
		self:FetchItemsAndValidate()
		return
	end
	
	for _, item in ipairs(self:ResolveItems()) do
		if RawText(ItemText(item), translate) == raw_text then
			if self.value ~= ItemId(item) then
				self.value = ItemId(item)
				self:OnValueChanged(self.value)
			end
			return
		end
	end
	
	if self.ArbitraryValue then
		if self.value ~= text then
			self.value = text
			self:OnValueChanged(self:GetValue())
		end
	else
		self:SetValue(self:GetValue()) -- revert to last valid value
	end
end

function XCombo:GetValue()
	local value = rawget(self, "value")
	if value == nil then
		return self.DefaultValue
	else
		return value
	end
end

function XCombo:GetText()
	return self.idEdit:GetText()
end

function XCombo:OnShortcut(shortcut, source, ...)
	local popup = self.popup
	if shortcut == "Down" then
		if not popup then
			self:OpenCombo("select")
		else
			popup:SetFocus()
			popup:OnShortcut(shortcut, source, ...)
		end
		return "break"
	elseif shortcut == "Escape" or shortcut == "ButtonB" then
		if self:IsPopupOpen() then
			self:CloseCombo()
			return "break"
		else
			self:SetValue(self:GetValue(), "do_not_validate") -- revert text field to the current/old value
		end
	elseif popup and popup.window_state ~= "destroying" then
		local res = popup:OnShortcut(shortcut, source, ...)
		return res
	end
end

function XCombo:SetFocusOrder(focus_order)
	self.idEdit:SetFocusOrder(focus_order)
end

function XCombo:GetFocusOrder(focus_order)
	self.idEdit:GetFocusOrder(focus_order)
end

function XCombo:SetFocus(set, children)
	return self.idEdit:SetFocus(set, children)
end

function XCombo:IsFocused(include_children)
	return self.idEdit:IsFocused(include_children)
end

function XCombo:OnKillFocus(new_focus)
	if not (new_focus and new_focus:IsWithin(self.popup)) then
		self:CloseCombo()
	end
end

function XCombo:CloseCombo()
	local popup = self.popup
	if popup and popup.window_state == "open" then
		self.idEdit:ClearSelection()
		popup:Close()
	end
	if self.RefreshItemsOnOpen then
		self.Items = nil
	end
end

function XCombo:LoadMRUList()
	local mru_id = self.MRUStorageId
	if mru_id == "" or self.mru_list then
		return
	end
	self.mru_list = {}
	
	LocalStorage.XComboMRU = LocalStorage.XComboMRU or {}
	local mru_data = LocalStorage.XComboMRU[mru_id] or empty_table
	if next(mru_data) then
		-- gather all valid items by id to filter out the valid MRU entries
		local items_by_id = {}
		for i, item in ipairs(self:ResolveItems()) do
			items_by_id[ItemId(item)] = item
		end
		mru_data = table.ifilter(mru_data, function(idx, id) return items_by_id[id] end)
		self.mru_list = table.map(mru_data, function(id) return items_by_id[id] end)
	end
end

function XCombo:UpdateMRUList()
	if not self.mru_list or not self.mru_value_changed then return end
	
	local item_id = self.value
	local list = table.map(self.mru_list, function(item) return ItemId(item) end)
	table.remove_value(list, item_id)
	table.insert(list, 1, item_id)
	if #list > self.MRUCount then
		table.remove(list)
	end
	
	LocalStorage.XComboMRU[self.MRUStorageId] = list
	SaveLocalStorageDelayed()
	self.mru_value_changed = nil
	self.mru_list = nil
end

function XCombo:GetCurrentComboItems(mode)
	local recently_used
	local items, extra_items = {}, {}
	
	local selected_item = false
	local translate = self:GetTranslate()
	local prefix_lower = string.trim_spaces(string.lower(StringText(self:GetText(), translate)))
	for i, item in ipairs(self:ResolveItems()) do
		local itemText = ItemText(item)
		itemText = string.lower(StringText(itemText, translate))
		local match = itemText:starts_with(prefix_lower)
		if mode ~= "suggest" or match then
			items[#items + 1] = item
		elseif itemText:find(prefix_lower, 1, true) then
			extra_items[#extra_items + 1] = item
		end
		if match and not selected_item then
			selected_item = item
		end
	end
	
	-- if not searching, put most recently used entries on top
	if prefix_lower == "" or mode ~= "suggest" then
		self:LoadMRUList()
		if next(self.mru_list) then
			assert(#extra_items == 0)
			extra_items = items
			items = table.copy(self.mru_list)
			recently_used = true
		end
	end
	
	return items, extra_items, selected_item, recently_used
end

function XCombo:OpenCombo(mode)
	if not self.enabled then return end
	if OpenXCombo then
		OpenXCombo:CloseCombo()
		if not mode then return end
	end
	self:SetFocus()
	
	if not self.Items then
		self.pending_input = mode
		self.pending_input_type = "opencombo"
		self:FetchItemsAndValidate()
		return
	end
	
	local items, extra_items, selected_item, recently_used = self:GetCurrentComboItems(mode)
	local sep_idx
	if extra_items and #extra_items > 0 then
		sep_idx = #items
		table.iappend(items, extra_items)
	end
	if #items == 0 then
		return
	end
	
	-- open popup
	local popup = XPopupList:new({
		AutoFocus = false,
		DrawOnTop = true,
	}, self.desktop:GetModalWindow() or self.desktop)
	
	-- popup should have the same scale as the combo
	popup:SetScaleModifier(self.scale)
	popup:SetOutsideScale(point(1000, 1000))
	
	local translate = self:GetTranslate()
	local virtual_items = self.VirtualItems
	for i, item in ipairs(items) do
		local context = SubContext(self.context, {
			idx = i,
			dimmed = not recently_used and sep_idx and i > sep_idx,
			combo = self,
			popup = popup,
			item = item,
			translate = translate,
			on_press = function(self)
				local combo = self.context.combo
				local popup = self.context.popup
				if combo:GetEnabled() then
					local value = combo.value
					combo:SetValue(ItemId(self.context.item))
					if value ~= combo.value then
						combo.mru_value_changed = true -- means we will update MRU list upon deleting the control
					end
				end
				if popup.window_state ~= "destroying" then
					combo:CloseCombo()
				end
			end,
			on_alt_press = self.OnItemRightClicked ~= empty_func and function(self)
				local combo = self.context.combo
				combo:OnItemRightClicked(ItemId(self.context.item))
			end
		})
		
		local entry = virtual_items and
			NewXVirtualContent(popup.idContainer, context, self.ListItemTemplate) or
			XTemplateSpawn(self.ListItemTemplate, popup.idContainer, context)
		if not recently_used then
			if mode == "select" then
				if self.value == ItemId(item) then
					entry:SetFocus()
					popup.idContainer:ScrollIntoView(entry)
				end
			elseif selected_item == item then
				popup.idContainer:ScrollIntoView(entry)
			end
		end
		
		if i == sep_idx then
			XWindow:new({ Background = RGBA(0, 0, 0, 196), MinHeight = 1, Margins = box(3, 0, 3, 0) }, popup.idContainer)
		end
	end
	popup.idContainer:SetBackground(self.PopupBackground)
	popup:SetAnchor(self.box)
	popup:SetAnchorType("drop")
	popup:SetMaxItems(self.MaxItems)
	popup.Close = function(...)
		OpenXCombo = false
		self.popup = false
		XPopupList.Close(...)
	end
	popup:Open()
	
	popup.popup_parent = self
	Msg("XWindowRecreated", popup)
	
	if self.AutoSelectAll and not mode then
		self.idEdit:SelectAll()
	end
	OpenXCombo = self
	self.popup = popup
	return popup
end

function XCombo:FetchItemsAndValidate()
	assert(not self.Items)
	if self:IsThreadRunning("FetchItems") then
		return
	end
	self:CreateThread("FetchItems", function()
		self.Items = self:OnRequestItems() -- might sleep
		if self.window_state == "destroying" then
			return
		end
		
		local focused = self:IsFocused()
		if self.pending_input_type == "value" then
			self:SetValue(self.pending_input)
			if self.RefreshItemsOnOpen then
				self.Items = nil
			end
		elseif self.pending_input_type == "text" and not focused then
			self:TextChanged(self.pending_input)
		elseif self.pending_input_type == "opencombo" and (focused or self.desktop.keyboard_focus == self) then
			self:OpenCombo(self.pending_input)
		else
			self:SetValue(self:GetValue()) -- revalidate current value
		end
		self.pending_input = false
		self.pending_input_type = false
	end)
end

function XCombo:OnRequestItems()
	return {}
end
