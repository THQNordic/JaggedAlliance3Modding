DefineClass.XCascade = {
	__parents = { "XActionsView" },
	properties = {
		{ category = "General", id = "MenuEntries", editor = "text", default = "", },
		{ category = "General", id = "ShowIcons", editor = "bool", default = false, },
		{ category = "General", id = "IconReservedSpace", editor = "number", default = 0, },
		{ category = "General", id = "CollapseTitles", editor = "bool", default = false, },
		{ category = "General", id = "ItemTemplate", editor = "text", default = "XTextButton" }
	},
	IdNode = true,
	VAlign = "stretch",
	HandleMouse = true,
	idSubCascade = false,
}

function XCascade:Init()
	XSleekScroll:new({
		Id = "idScroll",
		Target = "idContainer",
		Dock = "right",
		Margins = box(1, 1, 1, 1),
		AutoHide = true,
		MinThumbSize = 30,
	}, self)
	XScrollArea:new({
		Id = "idContainer",
		VAlign = "top",
		LayoutMethod = "VList",
		VScroll = "idScroll",
	}, self)
end

function XCascade:OnDelete()
	if IsKindOf(self.parent, "XCascade") then
		self.parent:SetCollapsed(false)
	end
end

function XCascade:PopupAction(action_id, host, source)
	if self.idSubCascade then
		self.idSubCascade:Close()
	end
	local menu = g_Classes[self.class]:new({
		Id = "idSubCascade",
		MenuEntries = action_id,
		Dock = "right",
		GetActionsHost = function(self) return host end,
		IconReservedSpace = self.IconReservedSpace,
		ShowIcons = self.ShowIcons,
		CollapseTitles = self.CollapseTitles,
		ItemTemplate = self.ItemTemplate,
	}, self)
	menu:Open()
	menu:SetFocus()
	self:SetCollapsed(true)
end

function XCascade:SetCollapsed(collapsed)
	self.idContainer:SetMaxWidth(collapsed and self.CollapseTitles and self.IconReservedSpace or 1000000)
	if collapsed then
		self.idScroll:SetAutoHide(false)
		self.idScroll:SetVisible(false)
	else
		self.idScroll:SetAutoHide(true)
	end
end

function XCascade:OnMouseButtonDown(pt, button)
	if button == "L" then
		self:SetFocus()
		if self.idSubCascade then
			self.idSubCascade:Close()
		end
		return "break"
	end
	if button == "R" then
		self:Close()
		return "break"
	end
end

function XCascade:RebuildActions(host)
	local menu = self.MenuEntries
	local context = host.context
	self.idContainer:DeleteChildren()
	for _, action in ipairs(host:GetMenubarActions(menu)) do
		if host:FilterAction(action) then
			local entry = XTemplateSpawn(self.ItemTemplate, self.idContainer, action) 
			entry.action = action
			entry:SetProperty("Translate", action.ActionTranslate)
			entry:SetProperty("Text", action.ActionName)
			entry:SetProperty("IconReservedSpace", self.IconReservedSpace)
			if self.ShowIcons then
				entry:SetProperty("Icon", action.ActionIcon)
			end
			entry:Open()
		end
	end
end
