DefineClass.XSizeControl = {
	__parents = { "XWindow" },
	
	properties = {
		{ category = "Visual", id = "LeftSizeCursor",        editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize03.tga" },
		{ category = "Visual", id = "RightSizeCursor",       editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize03.tga" },
		{ category = "Visual", id = "TopSizeCursor",         editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize04.tga" },
		{ category = "Visual", id = "BottomSizeCursor",      editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize04.tga" },
		{ category = "Visual", id = "TopLeftSizeCursor",     editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize02.tga" },
		{ category = "Visual", id = "TopRightSizeCursor",    editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize01.tga" },
		{ category = "Visual", id = "BottomLeftSizeCursor",  editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize01.tga" },
		{ category = "Visual", id = "BottomRightSizeCursor", editor = "ui_image", force_extension = ".tga", default = "CommonAssets/UI/Controls/resize02.tga" },
	},
	
	BorderWidth = 5,
	BorderColor = RGBA(0, 0, 0, 0),
	Dock = "ignore",
	HandleMouse = true,
	ZOrder = -1,

	size_region = false,
	size_cursor = false,
	box_at_drag_start = false,
	pt_at_drag_start = false,
}

function XSizeControl:UpdateLayout()
	local parent_box = self.parent.box
	self:SetBox(parent_box:minx(), parent_box:miny(), parent_box:sizex(), parent_box:sizey())
end

function XSizeControl:PointInWindow(pt)
	if pt and self.window_state ~= "destroying" and self.visible then
		local bbox = self.box
		local border = self.BorderWidth
		if pt:InBox(bbox) then
			if not pt:InBox(box(bbox:minx() + border, bbox:miny() + border, bbox:maxx() - border, bbox:maxy() - border)) then
				return true
			end
		end
	end
end

function XSizeControl:ResolveSizeMoveRegion(pt)
	local border_width = self.BorderWidth
	local bbox = self.box
	if pt:InBox(sizebox(bbox:minx(), bbox:miny(), border_width, border_width)) then
		return "topleft", self.TopLeftSizeCursor
	elseif pt:InBox(sizebox(bbox:maxx() - border_width, bbox:miny(), border_width, border_width)) then
		return "topright", self.TopRightSizeCursor
	elseif pt:InBox(sizebox(bbox:maxx() - border_width, bbox:maxy() - border_width, border_width, border_width)) then
		return "bottomright", self.BottomRightSizeCursor
	elseif pt:InBox(sizebox(bbox:minx(), bbox:maxy() - border_width, border_width, border_width)) then
		return "bottomleft", self.BottomLeftSizeCursor
	else
		local center = self.box:Center()
		local diff = pt - center
		local x_percent = MulDivRound(diff:x(), 1000, self.box:sizex())
		local y_percent = MulDivRound(diff:y(), 1000, self.box:sizey())
		if abs(x_percent) < abs(y_percent) then
			if y_percent > 0 then
				return "bottom", self.BottomSizeCursor
			else
				return "top", self.TopSizeCursor
			end
		else
			if x_percent > 0 then
				return "right", self.RightSizeCursor
			else
				return "left", self.LeftSizeCursor
			end
		end
	end
end

function XSizeControl:GetMouseTarget(pt)
	if self.size_cursor then
		return self, self.size_cursor
	else
		local _, cursor_image = self:ResolveSizeMoveRegion(pt)
		return self, cursor_image
	end
end

function XSizeControl:OnMouseButtonDown(pt, button)
	if button == "L" then	
		self.parent:SetDock("ignore")
		self:SetFocus()
		self.desktop:SetMouseCapture(self)
		
		self.box_at_drag_start = self.box
		self.pt_at_drag_start = pt
		
		self.size_region, self.size_cursor = self:ResolveSizeMoveRegion(pt)
		
		self:OnMousePos(pt)
	end
end

function XSizeControl:OnMouseButtonUp(pt, button)
	if button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		self.size_region = false
		self.size_cursor = false
		return "break"
	end
end

function XSizeControl:OnMousePos(pt)
	if self.desktop:GetMouseCapture() ~= self then return "break" end
	
	local old_box = self.box_at_drag_start
	local old_pt = self.pt_at_drag_start
	local side = self.size_region
	local min_width = self.parent.MinWidth
	local max_width = self.parent.MaxWidth
	local min_height = self.parent.MinHeight
	local max_height = self.parent.MaxHeight
	local diff = pt - old_pt
	local new_box
	if side == "left" then
		local width = Clamp(old_box:sizex() - diff:x(), min_width, max_width)
		new_box = box(old_box:maxx() - width, old_box:miny(), old_box:maxx(), old_box:maxy())
	elseif side == "right" then
		local width = Clamp(old_box:sizex() + diff:x(), min_width, max_width)
		new_box = box(old_box:minx(), old_box:miny(), old_box:minx() + width, old_box:maxy())
	elseif side == "bottom" then
		local height = Clamp(old_box:sizey() + diff:y(), min_height, max_height)
		new_box = box(old_box:minx(), old_box:miny(), old_box:maxx(), old_box:miny() + height)
	elseif side == "top" then
		local height = Clamp(old_box:sizey() - diff:y(), min_height, max_height)
		new_box = box(old_box:minx(), old_box:maxy() - height, old_box:maxx(), old_box:maxy())
	elseif side == "topleft" then
		local height = Clamp(old_box:sizey() - diff:y(), min_height, max_height)
		local width = Clamp(old_box:sizex() - diff:x(), min_width, max_width)
		new_box = box(old_box:maxx() - width, old_box:maxy() - height, old_box:maxx(), old_box:maxy())
	elseif side == "topright" then
		local height = Clamp(old_box:sizey() - diff:y(), min_height, max_height)
		local width = Clamp(old_box:sizex() + diff:x(), min_width, max_width)
		new_box = box(old_box:minx(), old_box:maxy() - height, old_box:minx() + width, old_box:maxy())
	elseif side == "bottomleft" then
		local height = Clamp(old_box:sizey() + diff:y(), min_height, max_height)
		local width = Clamp(old_box:sizex() - diff:x(), min_width, max_width)
		new_box = box(old_box:maxx() - width, old_box:miny(), old_box:maxx(), old_box:miny() + height)
	elseif side == "bottomright" then
		local height = Clamp(old_box:sizey() + diff:y(), min_height, max_height)
		local width = Clamp(old_box:sizex() + diff:x(), min_width, max_width)
		new_box = box(old_box:minx(), old_box:miny(), old_box:minx() + width, old_box:miny() + height)
	end
	if new_box and new_box:IsValid() then
		self.parent:SetBox(new_box:minx(), new_box:miny(), new_box:sizex(), new_box:sizey())
	end

	return "break"
end