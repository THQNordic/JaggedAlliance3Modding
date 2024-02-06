DefineClass.XMenuEntry = {
	__parents = { "XButton", "XEmbedIcon", "XEmbedLabel" },
	properties = {
		{ category = "General", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "General", id = "IconMaxHeight", editor = "number", default = 26, },
		{ category = "General", id = "Shortcut", editor = "shortcut", default = "", },
		{ category = "General", id = "Toggled", editor = "bool", default = false, },
		{ category = "General", id = "ToggledBackground", editor = "color", default = RGBA(40, 163, 255, 128), },
		{ category = "General", id = "ToggledBorderColor", editor = "color", default = RGBA(0, 0, 0, 0), },
	},
	LayoutMethod = "HList",
	VAlign = "center",
	HAlign = "stretch",
	Padding = box(2, 2, 2, 2),
	Background = RGBA(0, 0, 0, 0),
	RolloverBackground = RGBA(40, 163, 255, 128),
	PressedBackground = RGBA(40, 163, 255, 140),
	AltPress = true,
}

function XMenuEntry:Init(parent, context)
	self.idIcon:SetMinWidth(self.IconReservedSpace)
	self.idIcon:SetMaxHeight(self.IconMaxHeight)
	self.idIcon:SetImageFit("scale-down")
end

LinkPropertyToChild(XMenuEntry, "IconReservedSpace", "idIcon", "MinWidth")
LinkPropertyToChild(XMenuEntry, "IconMaxHeight", "idIcon", "MaxHeight")
XMenuEntry.OnSetRollover = XButton.OnSetRollover

function XMenuEntry:SetShortcut(shortcut_text)
	local shortcut = rawget(self, "idShortcut") or shortcut_text ~= "" and XLabel:new({
		Dock = "right",
		VAlign = "center",
		Margins = box(10, 0, 0, 0),
	}, self)
	if shortcut then
		shortcut:SetEnabled(false)
		shortcut:SetFontProps(self)
		shortcut:SetText(shortcut_text)
	end
end

function XMenuEntry:GetShortcut()
	local shortcut = rawget(self, "idShortcut")
	return shortcut and shortcut:GetText() or ""
end

function XMenuEntry:SetToggled(toggled)
	toggled = toggled or false
	if self.Toggled ~= toggled then
		self.Toggled = toggled
		self:Invalidate()
	end
end

function XMenuEntry:CalcBackground()
	if not self.enabled then return self.DisabledBackground end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBackground
	end
	if self.state == "mouse-in" then
		return self.RolloverBackground
	end
	local FocusedBackground, Background = self.FocusedBackground, self.Toggled and self.ToggledBackground or self.Background
	if FocusedBackground == Background then return Background end
	return self:IsFocused() and FocusedBackground or Background
end

function XMenuEntry:CalcBorderColor()
	if not self.enabled then return self.DisabledBackground end
	if self.state == "pressed-in" or self.state == "pressed-out" then
		return self.PressedBackground
	end
	if self.state == "mouse-in" then
		return self.RolloverBackground
	end
	local FocusedBorderColor, BorderColor = self.FocusedBorderColor, self.Toggled and self.ToggledBorderColor or self.BorderColor
	if FocusedBorderColor == BorderColor then return BorderColor end
	return self:IsFocused() and FocusedBorderColor or BorderColor
end


----- XPopupMenu

DefineClass.XPopupMenu = {
	__parents = { "XPopupList", "XActionsView", "XFontControl" },
	properties = {
		{ category = "Actions", id = "ActionContextEntries", editor = "text", default = "", },
		{ category = "Actions", id = "MenuEntries", editor = "text", default = "", },
		{ category = "Actions", id = "ShowIcons", editor = "bool", default = false, },
		{ category = "Actions", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "Actions", id = "ButtonTemplate", editor = "choice", default = "XMenuEntry", items = function() return XTemplateCombo("XMenuEntry") end, },
	},
	LayoutMethod = "VList",
	Background = RGB(248, 248, 248),
	FocusedBackground = RGB(248, 248, 248),
	DisabledBackground = RGB(192, 192, 192),
	BorderWidth = 1,
}

function XPopupMenu:Open(...)
	XPopupList.Open(self, ...)
	self:OnUpdateActions()
end

function XPopupMenu:ClosePopupMenus()
	local focus = terminal.desktop:GetKeyboardFocus()
	while GetParentOfKind(focus, "XPopupMenu") do
		focus:SetFocus(false)
		focus = terminal.desktop:GetKeyboardFocus()
	end
end

function XPopupMenu:PopupAction(action_id, host, source)
	local menu = XPopupMenu:new({
		MenuEntries = action_id,
		Anchor = IsKindOf(source, "XWindow") and source.box,
		AnchorType = "right",
		popup_parent = self,
		GetActionsHost = function(self) return host end,
		DrawOnTop = true,
	}, terminal.desktop)
	menu:SetFontProps(self)
	menu:SetShowIcons(self.ShowIcons)
	menu:SetIconReservedSpace(self.IconReservedSpace)
	menu:Open()
end

function XPopupMenu:RebuildActions(host)
	local menu = self.MenuEntries
	local popup = self.ActionContextEntries
	
	local context = host.context
	local last_is_separator = false
	self.idContainer:DeleteChildren()
	for _, action in ipairs(host:GetActions()) do
		if (#popup == 0 and #menu ~= 0 and action.ActionMenubar == menu and host:FilterAction(action)) or (#popup ~= 0 and host:FilterAction(action, popup)) then
			local name = action.ActionName
			name = IsT(name) and _InternalTranslate(name, nil, false) or name
			if name:starts_with("---") then
				if not last_is_separator then
					local separator = XWindow:new({
						Background = RGBA(128, 128, 128, 196),
						MinHeight = 1,
						MaxHeight = 1,
						Margins = box(5, 2, 5, 2),
					}, self.idContainer)
					separator:Open()
					last_is_separator = true
				end
			else
				last_is_separator = false
				
				local entry = XTemplateSpawn(self.ButtonTemplate, self.idContainer, context)
				entry.OnPress = function(this, gamepad)
					if action.OnActionEffect ~= "popup" and not terminal.IsKeyPressed(const.vkShift) then
						self:ClosePopupMenus()
					end
					host:OnAction(action, this)
					if action.ActionToggle and self.window_state ~= "destroying" then
						self:RebuildActions(host)
					end
				end
				entry.action = action
				entry.OnAltPress = function(this, gamepad)
					self:ClosePopupMenus()
					if action.OnAltAction then 
						action:OnAltAction(host, this)
					end
				end
				entry:SetFontProps(self)
				entry:SetTranslate(action.ActionTranslate)
				entry:SetText(action.ActionName)
				entry:SetIconReservedSpace(self.IconReservedSpace)
				if action.ActionToggle then
					entry:SetToggled(action:ActionToggled(host))
				end
				if self.ShowIcons then
					entry:SetIcon(action:ActionToggled(host) and action.ActionToggledIcon ~= "" and action.ActionToggledIcon or action.ActionIcon)
				end
				entry:SetShortcut(Platform.desktop and action.ActionShortcut or action.ActionGamepad)
				if action:ActionState(host) == "disabled" then
					entry:SetEnabled(false)
				end
				entry:Open()
			end
		end
	end
	
	if last_is_separator then -- trailing separator
		self.idContainer[#self.idContainer]:Close()
	end
	if #self.idContainer == 0 then
		self:Close()
	end
end


----- XMenuBar

DefineClass.XMenuBar = {
	__parents = { "XActionsView", "XFontControl" },
	properties = {
		{ category = "Actions", id = "MenuEntries", editor = "text", default = "", },
		{ category = "Actions", id = "ShowIcons", editor = "bool", default = false, },
		{ category = "Actions", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "Actions", id = "AutoHide", editor = "bool", default = true, },
	},
	LayoutMethod = "HList",
	HAlign = "stretch",
	VAlign = "top",
	Background = RGB(255, 255, 255),
	FocusedBackground = RGB(255, 255, 255),
	DisabledBackground = RGB(255, 255, 255),
	TextColor = RGB(48, 48, 48),
	DisabledTextColor = RGBA(48, 48, 48, 160),
	FoldWhenHidden = true,
}

function XMenuBar:PopupAction(action_id, host, source)
	local menu = XPopupMenu:new({
		MenuEntries = action_id,
		Anchor = IsKindOf(source, "XWindow") and source.box,
		AnchorType = "drop",
		GetActionsHost = function(self) return host end,
		DrawOnTop = true,
		popup_parent = self,
	}, terminal.desktop)
	menu:SetFontProps(self)
	menu:SetShowIcons(self.ShowIcons)
	menu:SetIconReservedSpace(self.IconReservedSpace)
	menu:Open()
end

function XMenuBar:RebuildActions(host)
	local menu = self.MenuEntries
	local context = host.context
	self:DeleteChildren()
	for _, action in ipairs(host:GetMenubarActions(menu)) do
		if action.ActionName ~= "" and host:FilterAction(action) then
			local entry = XTextButton:new({
				HAlign = "stretch",
				OnPress = function(self)
					host:OnAction(action, self)
				end,
				Background = RGBA(0, 0, 0, 0),
				RolloverBackground = RGBA(40, 163, 255, 128),
				PressedBackground = RGBA(40, 163, 255, 140),
				Translate = action.ActionTranslate,
				Text = action.ActionName,
				Image = "CommonAssets/UI/round-frame-20.tga",
				FrameBox = box(9, 9, 9, 9),
				ImageScale = point(500, 500),
				Padding = box(2, 2, 2, 2),
			}, self, context)
			entry:SetFontProps(self)
			entry:Open()
		end
	end
	if self.AutoHide then
		self:SetVisibleInstant(#self > 0)
	end
end
