DefineClass.XList = {
	__parents = { "XScrollArea" },
	
	properties = {
		{ category = "General", id = "MultipleSelection", editor = "bool", default = false, },
		{ category = "General", id = "LeftThumbScroll", editor = "bool", default = true, },
		{ category = "General", id = "GamepadInitialSelection", Name = "Gamepad Initial Selection", editor = "bool", default = true, },
		{ category = "General", id = "CycleSelection", Name = "Cycle selection", editor = "bool", default = false, },
		{ category = "General", id = "ForceInitialSelection", editor = "bool", default = false, },
		{ category = "General", id = "SetFocusOnOpen", editor = "bool", default = false, },
		{ category = "General", id = "WorkUnfocused", editor = "bool", default = false, },
		
		{ category = "Actions", id = "ActionContext", editor = "text", default = "", },
		{ category = "Actions", id = "ItemActionContext", editor = "text", default = "", },

		{ category = "Visual", id = "MaxRowsVisible", editor = "number", default = 0, invalidate = "measure" },

		{ category = "Interaction", id = "OnSelection", editor = "func", params = "self, focused_item, selection", },
		{ category = "Interaction", id = "OnDoubleClick", editor = "func", params = "self, item_idx", },
	},
	
	Clip = "parent & self",
	LayoutMethod = "VList",
	Padding = box(2, 2, 2, 2),
	BorderWidth = 1,
	BorderColor = RGB(32, 32, 32),
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	
	focused_item = false,
	selection = false, -- table
	item_hashes = false, -- table, used when the LayoutMethod is Grid
	docked_win_count = 0, -- these must be the last children, and are not considered list items (usually scrollbars)
	force_keep_items_spawned = false,
}


----- helpers

local function IsItemSelectable(child)
	return (not child:HasMember("IsSelectable") or child:IsSelectable()) and child:GetVisible()
end

local function SetItemSelected(child, selected)
	if not child or not child:HasMember("SetSelected") then
		return
	end
	child:SetSelected(selected)
end

local function SetItemFocused(child, focused)
	if not child or not child:HasMember("SetFocused") then
		return
	end
	child:SetFocused(focused)
end


----- general methods

function XList:Init(parent, context)
	self.selection = {}
end

function XList:Open(...)
	self:GenerateItemHashTable()
	XScrollArea.Open(self, ...)
	self:CreateThread("SetInitialSelection", self.SetInitialSelection, self)
end

function XList:Clear()
	self.focused_item = false
	self.selection = {}
	for i = #self, 1, -1 do
		local win = self[i]
		if not win.Dock or win.Dock == "ignore" then
			win:delete()
		end
	end
	XScrollArea.Clear(self, "keep_children")
end

-- Counts docked child windows (usually scrollbars), and makes sure they are at the end of the children list
function XList:SortChildren()
	local docked = 0
	for _, win in ipairs(self) do
		if win.Dock and win.Dock ~= "ignore" then
			docked = docked + 1
			win.ZOrder = max_int
		end
	end
	self.docked_win_count = docked
	return XWindow.SortChildren(self)
end

function XList:GetItemCount()
	return #self - self.docked_win_count
end

function XList:GenerateItemHashTable()
	if self.LayoutMethod == "Grid" and self:GetItemCount() > 0 then
		self.item_hashes = {}
		for i, v in ipairs(self) do
			local x, y = v.GridX, v.GridY
			for j = x, x + v.GridWidth - 1 do
				for k = y, y + v.GridHeight - 1 do
					self.item_hashes[j .. k] = i
				end
			end
		end
	end
end

function XList:CreateTextItem(text, props, context)
	props = props or {}
	local item = XListItem:new({ selectable = props.selectable }, self)
	props.selectable = nil
	local text_control = XText:new(props, item, context)
	text_control:SetText(text)
	return item
end

function XList:GetItemAt(pt, allow_outside_items)
	local target = false
	local method = allow_outside_items and "PointInWindow" or "MouseInWindow"
	for idx, win in ipairs(self) do
		if (not target or win.DrawOnTop) and win[method](win, pt) then
			target = idx
			if self.LayoutMethod ~= "HOverlappingList" and self.LayoutMethod ~= "VOverlappingList" then
				return target
			end
		end
	end
	return target
end

function XList:Measure(max_width, max_height)
	local width, height = XScrollArea.Measure(self, max_width, max_height)
	local elements = self:GetItemCount()
	if self.MaxRowsVisible > 0 and elements > 0 then
		assert(self.LayoutMethod == "VList" or self.LayoutMethod == "HWrap")
		height = Min(height, self[1].measure_height * self.MaxRowsVisible)
	end
	return width, height
end

----- mouse/keyboard/controller

function XList:OnMouseButtonDown(pt, button)
	local target = self:GetItemAt(pt)
	if button == "L" then
		if not self.WorkUnfocused then
			self:SetFocus(true)
		end
		if not target or not IsItemSelectable(self[target]) then
			return "break"
		end
		
		self:OnItemClicked(target, button)
		
		local shift = terminal.IsKeyPressed(const.vkShift)
		local ctrl = terminal.IsKeyPressed(const.vkControl)
		if not self.MultipleSelection or not (shift or ctrl) then
			self:SetSelection(target)
		elseif ctrl then
			self:ToggleSelected(target)
		elseif shift then
			self:SelectRange(self.focused_item or target, target)
		end

		if self.MultipleSelection then
			self.desktop:SetMouseCapture(self)
		end
		return "break"
	elseif button == "R" then 
		if not self.WorkUnfocused then
			self:SetFocus(true)
		end
		local action_context = self.ItemActionContext
		if not target or not IsItemSelectable(self[target]) then
			action_context = self.ActionContext
		end
		local host = GetActionsHost(self, true)
		if host and host:OpenContextMenu(action_context, pt) then
			if target and IsItemSelectable(self[target]) and (not self.MultipleSelection or (not self:HasMember("selected")) or (#self.selected < 2)) then
				self:SetSelection(target)
			end
		end
		self:OnItemClicked(target, button)
		return "break"
	end
end

function XList:OnMouseButtonDoubleClick(pt, button)
	local shift = terminal.IsKeyPressed(const.vkShift)
	local ctrl = terminal.IsKeyPressed(const.vkControl)
	if button == "L" and not shift and not ctrl and self.focused_item then
		self:OnDoubleClick(self.focused_item)
		return "break"
	end
end

function XList:OnMousePos(pt)
	if self.desktop:GetMouseCapture() == self and self.focused_item then
		local target = self:GetItemAt(pt)
		if target and IsItemSelectable(self[target]) then
			self:SelectRange(self.focused_item, target)
		end
		return "break"
	end
end

function XList:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.desktop:SetMouseCapture()
		return "break"
	end
end

function XList:OnShortcut(shortcut, source, ...)
	local target, arrow_key = nil, nil
	shortcut = string.gsub(shortcut, "Shift%-", "") -- ignore shift
	if (self.LayoutMethod == "HList" or self.LayoutMethod == "HOverlappingList" or self.LayoutMethod == "HWrap") and (shortcut == "Left" or shortcut == "Ctrl-Left") or
		(self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and (shortcut == "Up" or shortcut == "Ctrl-Up")
	then
		target, arrow_key = self:NextSelectableItem(self.focused_item, -1, -1), true
	elseif (self.LayoutMethod == "HList" or self.LayoutMethod == "HOverlappingList" or self.LayoutMethod == "HWrap") and (shortcut == "Right" or shortcut == "Ctrl-Right") or
		(self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and (shortcut == "Down" or shortcut == "Ctrl-Down")
	then
		target, arrow_key = self:NextSelectableItem(self.focused_item, 1, 1), true
	elseif self.LayoutMethod == "Grid" and (shortcut == "Left" or shortcut == "Right" or shortcut == "Up" or shortcut == "Down" or
							shortcut == "Ctrl-Left" or shortcut == "Ctrl-Right" or shortcut == "Ctrl-Up" or shortcut == "Ctrl-Down") then
		target, arrow_key = self:NextGridItem(self.focused_item, shortcut), true
	elseif shortcut == "Home" or shortcut == "Ctrl-Home" then
		target = self:NextSelectableItem(1, 0, 1)
	elseif shortcut == "End" or shortcut == "Ctrl-End" then
		target = self:NextSelectableItem(self:GetItemCount(), 0, -1)
	elseif shortcut == "Pageup" then
		if self.focused_item then
			local offset = (self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and point(0, self.content_box:sizey()) or point(self.content_box:sizex(), 0)
			local child = self[self.focused_item]
			target = self:GetItemAt(child.content_box:Center() - offset, "allow_outside_items")
		end
		target = target or self:NextSelectableItem(1, 0, 1)
	elseif shortcut == "Pagedown" then
		if self.focused_item then
			local offset = (self.LayoutMethod == "VList" or self.LayoutMethod == "VOverlappingList" or self.LayoutMethod == "VWrap") and point(0, self.content_box:sizey()) or point(self.content_box:sizex(), 0)
			local child = self[self.focused_item]
			target = self:GetItemAt(child.content_box:Center() + offset, "allow_outside_items")
		end
		target = target or self:NextSelectableItem(self:GetItemCount(), 0, -1)
	elseif self.MultipleSelection and (shortcut == "Space" or shortcut == "Ctrl-Space") then
		if self.focused_item then
			self:ToggleSelected(self.focused_item)
		end
		return "break"
	elseif self.MultipleSelection and shortcut == "Ctrl-A" then
		self:SelectAll()
		return "break"
	end
	
	if target ~= nil then
		if target then
			if arrow_key and terminal.IsKeyPressed(const.vkControl) and self.MultipleSelection then
				self:SetFocusedItem(target)
			elseif terminal.IsKeyPressed(const.vkShift) and self.MultipleSelection then
				self:SelectRange(self.focused_item, target)
			else
				self:SetSelection(target)
			end
		end
		return "break"
	end
	
	if shortcut == "DPadUp" or (shortcut == "LeftThumbUp" and self.LeftThumbScroll) then
		return self:OnShortcut("Up", "keyboard", ...)
	elseif shortcut == "DPadDown" or (shortcut == "LeftThumbDown" and self.LeftThumbScroll) then
		return self:OnShortcut("Down", "keyboard", ...)
	elseif shortcut == "DPadLeft" or ((shortcut == "LeftThumbLeft" or shortcut == "LeftThumbDownLeft" or shortcut == "LeftThumbUpLeft") and self.LeftThumbScroll) then
		return self:OnShortcut("Left", "keyboard", ...)
	elseif shortcut == "DPadRight" or ((shortcut == "LeftThumbRight" or shortcut == "LeftThumbDownRight" or shortcut == "LeftThumbUpRight") and self.LeftThumbScroll) then
		return self:OnShortcut("Right", "keyboard", ...)
	elseif shortcut == "ButtonA" then
		return self:OnShortcut("Space", "keyboard", ...)
	end
end

function XList:NextSelectableItem(item, offset, step)
	local item_count = self:GetItemCount()
	if not item then
		return item_count > 0 and self:GetFirstValidItemIdx() or false
	end
	
	local i = item + offset
	while i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
		i = i + step
	end
	if self.CycleSelection then
		if i <= 0 then
			i = item_count
		elseif i > item_count then
			i = 1
		end
	end
	while i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
		i = i + step
	end
	return i > 0 and i <= item_count and i or false
end

function XList:NextGridItem(item, dir)
	local item_count = self:GetItemCount()
	if not item then
		return item_count > 0 and 1 or false
	end
	
	local current = self[item]
	local x, y = current.GridX, current.GridY
	if dir == "Left" then
		x = x - 1
	elseif dir == "Right" then
		x = x + (current.GridWidth - 1) + 1
	elseif dir == "Up" then
		y = y - 1
	elseif dir == "Down" then
		y = y + (current.GridHeight - 1) + 1
	end
	if x > 0 and y > 0 then
		local i = self.item_hashes[x .. y]
		-- find the first selectable item on the desired row
		while not i and x > 1 do
			x = x - 1
			i = self.item_hashes[x .. y]
		end
		while i and i > 0 and i <= item_count and not IsItemSelectable(self[i]) do
			i = self:NextGridItem(i, dir)
		end
		return i and i > 0 and i <= item_count and i or false
	end
end


----- focus (focused item is also used as single selection)

function XList:GetFocusedItem()
	return self.focused_item
end

function XList:GetScrollTarget()
	return self
end

function XList:SetFocusedItem(new_focused)
	if new_focused ~= self.focused_item then
		local old_focused = self.focused_item
		if old_focused then
			SetItemFocused(self[old_focused], false)
		end
		if new_focused then
			-- For potential virtual items, spawn a "sufficient quantity" of items between the last and the new
			-- focused item, so we can update the layout correctly - this is required for ScrollIntoView below
			if self.window_state == "open" and not self.content_box:IsEmpty() then
				local first, last = old_focused or 1, new_focused
				local step = first > new_focused and -1 or 1
				local from = Clamp(first + step, last - 100*step, last + 100*step) -- assume page size with no more than 100 items
				for idx = from, last, step do
					local item = self[idx]
					if item:HasMember("SetSpawned") then
						item:SetSpawned(true)
					end
				end
				
				local box = self.desktop.box
				self.desktop:UpdateMeasure(box:sizex(), box:sizey())
				self.force_keep_items_spawned = true -- prevent UpdateLayout below from despawning children outside of the list
				self:UpdateLayout()
				self.force_keep_items_spawned = false
			end
			
			local child = self[new_focused]
			self:GetScrollTarget():ScrollIntoView(child)
			local focus = self.desktop:GetKeyboardFocus()
			SetItemFocused(child, self.WorkUnfocused or (focus and focus:IsWithin(self)))
		end
		self.focused_item = new_focused
	end
end

function XList:OnSetFocus()
	if self.focused_item then
		SetItemFocused(self[self.focused_item], true)
	end
end

function XList:OnKillFocus()
	if self.focused_item then
		SetItemFocused(self[self.focused_item], false)
	end
end


----- selection

function XList:DeleteChildren()
	self.focused_item = false
	self.selection = {}
	XWindow.DeleteChildren(self)
end

function XList:ChildLeaving(child)
	-- keep selection valid by removing the entry and remapping the indexes
	local idx = XWindow.ChildLeaving(self, child)
	local selection = self.selection
	if #selection > 0 then
		table.remove_entry(selection, idx)
		for i, sel_idx in ipairs(selection) do
			if sel_idx > idx then
				self.selection[i] = sel_idx - 1
			end
		end
	end
end

function XList:ToggleSelected(item)
	local selection = self.selection
	local idx = table.find(selection, item)
	if idx then
		table.remove(selection, idx)
		SetItemSelected(self[item], false)
	else
		table.insert(selection, item)
		SetItemSelected(self[item], true)
	end
	self:SetFocusedItem(item)
	self:OnSelection(item, selection)
end

function XList:ScrollSelectionIntoView()
	for _, item in ipairs(self.selection) do
		if self[item] then
			self:ScrollIntoView(self[item])
		end
	end
end

function XList:SetBox(...)
	local old_box = self.content_box
	XScrollArea.SetBox(self, ...)
	if old_box ~= self.content_box then
		self:ScrollSelectionIntoView()
	end
end

function XList:SelectRange(from, to)
	local selection = self.selection
	if from < to then
		for i = from, to do
			local child = self[i]
			if IsItemSelectable(child) and not table.find(selection, i) then
				table.insert(selection, i)
				SetItemSelected(child, true)
			end
		end
	else
		for i = to, from do
			local child = self[i]
			if IsItemSelectable(child) and not table.find(selection, i) then
				table.insert(selection, i)
				SetItemSelected(child, true)
			end
		end
	end
	self:SetFocusedItem(to)
	self:OnSelection(to, selection)
end

function XList:GetSelection()
	return self.selection
end

function XList:SetSelection(selection, notify)
	for _, item in ipairs(self.selection) do
		SetItemSelected(self[item], false)
	end
	
	-- validate selection
	local item_count = self:GetItemCount()
	if type(selection) == "number" then
		if selection < 1 or selection > item_count or not IsItemSelectable(self[selection]) then
			selection = false
		end
	elseif type(selection) == "table" then
		selection = table.ifilter(selection, function(idx, value)
			return value >= 1 and value <= item_count and IsItemSelectable(self[value])
		end)
	end

	if not selection then
		self.selection = {}
		self:SetFocusedItem(false)
	elseif type(selection) == "number" then
		self.selection = { selection }
		self:SetFocusedItem(selection)
		SetItemSelected(self[selection], true)
	else
		assert(type(selection) == "table")
		self.selection = selection
		self:SetFocusedItem(selection[1] or false)
		for _, item in ipairs(selection) do
			SetItemSelected(self[item], true)
		end
	end
	
	if notify ~= false then
		self:OnSelection(self.focused_item, self.selection)
	end
end

function XList:SetInitialSelection(selection, force_ui_style)
	if selection then
		local item = selection and self[selection]
		if item and item:GetEnabled() and IsItemSelectable(item) then
			self:SetSelection(selection)
			return
		end
	end
	if self.ForceInitialSelection or (self.GamepadInitialSelection and (GetUIStyleGamepad() or force_ui_style)) then
		if not self:SelectFirstValidItem() then
			self:SetSelection(1) -- if all are disabled
		end
	elseif self.SetFocusOnOpen then
		self:SetFocus(true)
	end
end

function XList:GetFirstValidItemIdx()
	for idx, item in ipairs(self) do
		if item:GetEnabled() and IsItemSelectable(item) then
			return idx
		end
	end
end

function XList:SelectFirstValidItem()
	local item_idx = self:GetFirstValidItemIdx()
	if item_idx then
		self:SetSelection(item_idx)
		return true
	end
end

function XList:SelectLastValidItem()
	for i = #self, 1, -1 do
		local item = self[i]
		if item:GetEnabled() and IsItemSelectable(item) then
			self:SetSelection(i)
			return true
		end
	end
end

function XList:SelectAll()
	local item_count = self:GetItemCount()
	if item_count > 0 then
		self:SelectRange(item_count, 1)
	end
end

function XList:OnSelection(focused_item, selection)
end

function XList:OnDoubleClick(item_idx)
end

function XList:OnItemClicked(target, button)
end

----- XListItem

DefineClass.XListItem = {
	__parents = { "XContextControl" },
	properties = {
		{ category = "Visual", id = "SelectionBackground", editor = "color", default = RGB(204, 232, 255), },
	},
	FocusedBorderColor = RGB(32, 32, 32),
	BorderColor = RGBA(0, 0, 0, 0),
	BorderWidth = 1,
	HandleMouse = false,
	
	selectable = true,
	selected = false,
	focused = false,
}

function XListItem:IsSelectable()
	return self.selectable and self.Dock ~= "ignore"
end

function XListItem:SetSelected(selected)
	if self.selected ~= selected then
		self.selected = selected
		self:Invalidate()
	end
end

function XListItem:SetFocused(focused)
	if self.focused ~= focused then
		self.focused = focused
		self:Invalidate()
	end
end

function XListItem:CalcBackground()
	if self.selected then
		return self.SelectionBackground
	end
	return XContextControl.CalcBackground(self)
end

function XListItem:CalcBorderColor()
	if self.enabled and self.focused then
		return self.FocusedBorderColor
	end
	return XContextControl.CalcBorderColor(self)
end
