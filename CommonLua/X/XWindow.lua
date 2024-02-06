DefineClass.XWindow = {
	__parents = { "TerminalTarget", "XRollover", "XFxModifier" },
	__hierarchy_cache = true,
	__persist = false, -- trying to persist a window will result in error and persisting a nil value instead
	
	properties = {
		{ category = "General", id = "Id", editor = "text", default = "", }, -- register itself in its ancestor with id_node = true: ancestor[self.id] = self
		{ category = "General", id = "IdNode", editor = "bool", default = false, }, -- windows with id_node = true will "catch" the ids of all ther descendants: self[descendant.id] = descendant
		{ category = "General", id = "Parent", editor = "object", default = false, dont_save = true, no_edit = true,},
		{ category = "General", id = "_dbg_context_type", name = "Context type & value", editor = "text", default = false, translate = false, dont_save = true, read_only = true,
			buttons = { { name = "Inspect", func = function(self) Inspect(self:GetContext()) end, } },
		},
		{ category = "General", id = "_dbg_context", hide_name = true, editor = "text", default = false, translate = false, dont_save = true, read_only = true,
			lines = 1, max_lines = 10, no_auto_select = true,
		},
		
		{ category = "Layout", id = "ZOrder", editor = "number", default = 1, help = "Higher values mean 'front'" },
		{ category = "Layout", id = "Margins", editor = "margins", default = box(0, 0, 0, 0), invalidate = "layout", },
		{ category = "Layout", id = "MarginPolicy", editor = "choice", items = {"Fixed", "AddSafeArea", "FitInSafeArea"}, default = "Fixed", invalidate = "layout", },
		{ category = "Layout", id = "BorderWidth", name = "Border width", editor = "number", default = 0, invalidate = "layout", },
		{ category = "Layout", id = "Padding", editor = "padding", default = box(0, 0, 0, 0), invalidate = "layout", },
		{ category = "Layout", id = "Shape", name = "Shape", editor = "choice", default = "InBox", items = {"InBox", "InVHex", "InHHex", "InEllipse", "InRhombus"}, },
		{ category = "Layout", id = "Dock", name = "Dock in parent", editor = "choice", default = false, items = {false, "left", "right", "top", "bottom", "box", "ignore"}, invalidate = "layout", },
		{ category = "Layout", id = "HAlign", name = "Horizontal alignment", editor = "choice", default = "stretch", items = {"none", "left", "right", "center", "stretch"}, invalidate = "layout", },
		{ category = "Layout", id = "VAlign", name = "Vertical alignment", editor = "choice", default = "stretch", items = {"none", "top", "bottom", "center", "stretch"}, invalidate = "layout", },
		{ category = "Layout", id = "MinWidth", name = "Min width", editor = "number", default = 0, invalidate = "measure", },
		{ category = "Layout", id = "MinHeight", name = "Min height", editor = "number", default = 0, invalidate = "measure", },
		{ category = "Layout", id = "MaxWidth", name = "Max width", editor = "number", default = 1000000, invalidate = "measure", },
		{ category = "Layout", id = "MaxHeight", name = "Max height", editor = "number", default = 1000000, invalidate = "measure", },
		{ category = "Layout", id = "GridX", name = "Column in grid", editor = "number", default = 1, invalidate = "layout", },
		{ category = "Layout", id = "GridY", name = "Row in grid", editor = "number", default = 1, invalidate = "layout", },
		{ category = "Layout", id = "GridWidth", name = "Colspan in grid", editor = "number", default = 1, invalidate = "layout", },
		{ category = "Layout", id = "GridHeight", name = "Rowspan in grid", editor = "number", default = 1, invalidate = "layout", },
		{ category = "Layout", id = "GridStretchX", name = "Stretch grid column width", editor = "bool", default = true, invalidate = "layout", },
		{ category = "Layout", id = "GridStretchY", name = "Stretch grid row height", editor = "bool", default = true, invalidate = "layout", },
		
		{ category = "Layout", id = "ScaleModifier", name = "Scale modifier", editor = "point2d", default = point(1000, 1000), invalidate = "measure", lock_ratio = true, },
		{ category = "Layout", id = "scale", name = "Scale", editor = "point2d", default = point(1000, 1000), dont_save = true, read_only = true, },
		
		{ category = "Layout", id = "last_max_width", name = "Last max width", editor = "number", dont_save = true, read_only = true, default = 0 },
		{ category = "Layout", id = "last_max_height", name = "Last max height", editor = "number", dont_save = true, read_only = true, default = 0 },
		{ category = "Layout", id = "content_measure_width", name = "Content measure width", editor = "number", dont_save = true, read_only = true, default = 0 },
		{ category = "Layout", id = "content_measure_height", name = "Content measure height", editor = "number", dont_save = true, read_only = true, default = 0 },
		{ category = "Layout", id = "content_box_size", name = "Content size", editor = "point2d", dont_save = true, read_only = true, default = point(0, 0) },
		{ category = "Layout", id = "box", name = "Box", editor = "rect", default = box(0, 0, 0, 0), dont_save = true, read_only = true, },
		{ category = "Layout", id = "interaction_box", name = "Interaction box", editor = "rect", default = false, dont_save = true, read_only = true, },
		{ category = "Layout", id = "content_box", name = "Content box", editor = "rect", default = box(0, 0, 0, 0), dont_save = true, read_only = true, },
		{ category = "Layout", id = "measure_width", name = "Measure width", editor = "number", default = 0, dont_save = true, read_only = true, },
		{ category = "Layout", id = "measure_height", name = "Measure height", editor = "number", default = 0, dont_save = true, read_only = true, },
		{ category = "Layout", id = "OnLayoutComplete", editor = "func", default = function() end, help = "Use to start Interpolation after .box is known, or position controls with dock == 'ignore'" },
		
		{ category = "Children", id = "LayoutMethod", name = "Layout method", editor = "choice", default = "Box", items = function() return XWindowLayoutMethods end, },
		{ category = "Children", id = "FillOverlappingSpace", name = "Overlapping list fills space", editor = "bool", default = false, },
		{ category = "Children", id = "LayoutHSpacing", name = "Horizontal spacing", editor = "number", default = 0, invalidate = "layout", },
		{ category = "Children", id = "LayoutVSpacing", name = "Vertical spacing", editor = "number", default = 0, invalidate = "layout", },
		{ category = "Children", id = "UniformColumnWidth", name = "Uniform column width", editor = "bool", default = false, invalidate = "layout", },
		{ category = "Children", id = "UniformRowHeight", name = "Uniform row height", editor = "bool", default = false, invalidate = "layout", },
		{ category = "Children", id = "Clip", name = "Clip children", editor = "choice", default = false, items = {false, "self", "parent & self", }, invalidate = true, },
		{ category = "Children", id = "UseClipBox", name = "Use clip box", editor = "bool", default = true, help = "When set to false allows drawing outside the clip box, useful with dynamic position modifiers", invalidate = "measure" },
		
		{ category = "Visual", id = "Visible", editor = "bool", default = true, help = "Non-visible/hidden controls still take space during layout - they just don't draw." },
		{ category = "Visual", id = "FoldWhenHidden", name = "Fold when hidden", editor = "bool", default = false, invalidate = "measure", help = "When checked and the control is hidden/non-visible it will not take any space druing layout (fold)."},
		{ category = "Visual", id = "DrawOnTop", name = "Draw on top", editor = "bool", default = false, invalidate = true, help = "When selected will draw the window on top of all other windows within the same parent window ignoring the Z order."},
		{ category = "Visual", id = "BorderColor", name = "Border color", editor = "color", default = RGB(0, 0, 0), invalidate = true, },
		{ category = "Visual", id = "Background", name = "Background", editor = "color", default = RGBA(0, 0, 0, 0), invalidate = true, },
		{ category = "Visual", id = "BackgroundRectGlowSize", editor = "number", default = 0, invalidate = true, },
		{ category = "Visual", id = "BackgroundRectGlowColor", editor = "color", default = RGBA(0,0,0,255), invalidate = true, },
		{ category = "Visual", id = "FadeInTime", name = "Fade-in time", editor = "number", default = 0, },
		{ category = "Visual", id = "FadeOutTime", name = "Fade-out time", editor = "number", default = 0, },
		{ category = "Visual", id = "Transparency", editor = "number", default = 0, min = 0, max = 255, slider = true, invalidate = true, },
		{ category = "Visual", id = "RolloverZoom", editor = "number", default = 1000, "When its rollover is shown, the window is size changes (zooms) to this many 1/1000ths.", },
		{ category = "Visual", id = "RolloverZoomInTime", editor = "number", default = 100, },
		{ category = "Visual", id = "RolloverZoomOutTime", editor = "number", default = 100, },
		{ category = "Visual", id = "RolloverZoomX", editor = "bool", default = true, },
		{ category = "Visual", id = "RolloverZoomY", editor = "bool", default = true, },
		{ category = "Visual", id = "RolloverDrawOnTop", name = "Rollover draw on top", editor = "bool", default = false, help = "When its rollover is shown, the window will draw on top of the windows in its parent window." },
		{ category = "Visual", id = "RolloverOnFocus", name = "Rollover on focus", editor = "bool", default = false, },
		
		{ category = "Interaction", id = "HandleKeyboard", editor = "bool", default = true, },
		{ category = "Interaction", id = "HandleMouse", editor = "bool", default = false, },
		{ category = "Interaction", id = "MouseCursor", editor = "ui_image", force_extension = ".tga", default = "", },
		{ category = "Interaction", id = "DisabledMouseCursor", editor = "ui_image", force_extension = ".tga", default = "", },
		{ category = "Interaction", id = "ChildrenHandleMouse", editor = "bool", default = true, },
		{ category = "Interaction", id = "FocusOrder", editor = "point2d", default = false, help = "Coordinates in a virtual grid used for tab and gamepad navigation."},
		{ category = "Interaction", id = "RelativeFocusOrder", editor = "choice", default = "", items = {"", "new-line", "next-in-line", "skip"}, help = "Used to generate the focus order field."},
		{ category = "Interaction", id = "IncreaseRelativeXOnSkip", editor = "bool", default = false, },
		{ category = "Interaction", id = "IncreaseRelativeYOnSkip", editor = "bool", default = false, },
	},
	
	PropertyTabs = XWindowPropertyTabs,
	GedTreeCollapsedByDefault = true, -- for XWindow inspector
	
	window_state = "open", -- "open", "closing", "destroying"
	
	-- hierarchy
	desktop = false,
	parent = false,
	
	-- box model
	--   - margins is the area around the window
	--   - box is the area covered by the window (not including its margins)
	--   - content_box is the area covered by the window content (not including border and padding)
	--   - box = content_box + padding + border
	--   - Margins, BorderWidth and Padding are kept unscaled while box and content_box are in screen coordinates (with scaling applied)
	visible = true,
	target_visible = true,
	outside_parent = false, -- allows excluding children from being drawn; see XScrollArea, XVirtualContent
	invalidated = false, -- used for optimization only (when tons of children of the same parent are getting invalidated)
	transparency = 0,
	MouseCursor = false,
	DisabledMouseCursor = false,
	layout_update = false,
	measure_update = false,
	modifiers = false,
	real_time_threads = false,
	rollover = false,
}

local ScaleXY = ScaleXY
local Min, Max = Min, Max
local Clamp = Clamp
local find = table.find
local remove = table.remove
local insert = table.insert
local remove_value = table.remove_value


----- creation/destruction

function XWindow:delete(result, ...)
	assert(self.window_state ~= "destroying")
	if self.window_state == "destroying" then return end
	self.desktop:WindowLeaving(self)
	self.window_state = "destroying"
	self:OnDelete(result, ...)
	self.desktop:WindowLeft(self)
	self:Done(result, ...)
end

function XWindow:OnDelete()
end

function XWindow:Init(parent, context)
	self.window_state = "new"
	self:SetParent(parent)
end

function XWindow:Done(result)
	self:DeleteAllThreads()
	self:DeleteChildren()
	self:SetParent(nil)
end

-- called after all properties are set and the hierarchy is ready
function XWindow:Open(...)
	assert(self.window_state == "new")
	self.window_state = nil -- "open"
	for _, win in ipairs(self) do
		win:Open(...)
	end
	if self.FadeInTime > 0 and self.visible then
		self:SetVisible(false, true)
		self:SetVisible(true)
	end
end

function XWindow:Close(result)
	assert(self.window_state == "open" or self.window_state == "closing",
				string.format("XWindow:Close window is neither closing nor open, self.class[%s]", tostring(self.class)))
	self.window_state = "closing"
	if self.FadeOutTime > 0 and self.target_visible then
		self:SetId("") -- This allows a new control with the same id to be created while this one is fading
		self:SetVisible(false)
		self:FindModifier("fade").on_complete = function(self, int)
			self:delete(result)
		end
	else
		self:delete(result)
	end
end


----- hierarchy

function XWindow:SetParent(parent)
	local id = self.Id
	local old_parent = self.parent
	if old_parent == parent then return end
	if old_parent then
		if id ~= "" then
			local node = old_parent
			while node and not node.IdNode do
				node = node.parent
			end
			if node and rawget(node, id) == self then
				rawset(node, id, nil)
			end
		end
		old_parent:ChildLeaving(self)
	end
	self.parent = parent
	if parent then 
		self.desktop = parent.desktop
		if id ~= "" then 
			local node = parent
			while node and not node.IdNode do
				node = node.parent
			end
			if node then
				rawset(node, id, self)
			end
		end
		parent:ChildJoining(self)
	end
end

function XWindow:GetParent(parent)
	return self.parent
end

function XWindow:SetId(id)
	local node = self.parent
	while node and not node.IdNode do
		node = node.parent
	end
	if node then
		local old_id = self.Id
		if old_id ~= "" then
			rawset(node, old_id, nil)
		end
		if id ~= "" then
			local win = rawget(node, id)
			if win and win ~= self then
				printf("[UI WARNING] Assigning window id '%s' of %s to %s", tostring(id), win.class, self.class)
			end
			rawset(node, id, self)
		end
	end
	self.Id = id
end

-- find the window with this id which is in the same IdNode parent
-- this is used to link windows by specifying their ids only
function XWindow:ResolveId(id)
	if (id or "") == "" then return end
	local win = rawget(self, id)
	if win then
		return win
	end
	local node = self.parent
	while node and not node.IdNode do
		node = node.parent
	end
	if id == "node" then return node end
	return node and rawget(node, id)
end

function XWindow:ChildLeaving(child)
	local idx = remove_value(self, child)
	if not idx then return end
	self:InvalidateMeasure(true)
	self:InvalidateLayout()
	self:Invalidate()
	
	if Platform.developer then
		Msg("XWindowModified", self, child, true)
	end
	return idx
end

function XWindow:ChildJoining(child)
	self[#self + 1] = child
	child:SetOutsideScale(self.scale)
	if child.measure_update then
		self:InvalidateMeasure(true)
	else
		child:InvalidateMeasure()
	end
	self:InvalidateLayout()
	self:Invalidate()

	if Platform.developer then
		Msg("XWindowModified", self, child, false)
	end
end

function XWindow:DeleteChildren()
	while #self > 0 do
		self[#self]:delete()
	end
end

function XWindow:IsWithin(window)
	if not window then return end
	local win = self
	while win and win ~= window do
		if win.window_state == "destroying" then return end
		win = win.parent
	end
	return win == window and window.window_state ~= "destroying"
end

function XWindow:SetZOrder(order)
	if self.ZOrder == order then return end
	self.ZOrder = order
	local parent = self.parent
	if parent then
		if self.Dock and self.Dock ~= "ignore" or parent.LayoutMethod == "HPanel" or parent.LayoutMethod == "VPanel" then
			parent:InvalidateMeasure()
		end
		parent:InvalidateLayout()
		parent:Invalidate()
	end
end

function XWindow:GetEffectiveMargins()
	local policy = self:GetMarginPolicy()
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	if policy == "Fixed" then
		return margins_x1, margins_y1, margins_x2, margins_y2
	end
	local area_x1, area_y1, area_x2, area_y2 = GetSafeAreaBox()
	local w, h = UIL.GetScreenSize():xy()
	area_x2 = w - area_x2
	area_y2 = h - area_y2
	if policy == "FitInSafeArea" then
		margins_x1 = Max(margins_x1, area_x1)
		margins_y1 = Max(margins_y1, area_y1)
		margins_x2 = Max(margins_x2, area_x2)
		margins_y2 = Max(margins_y2, area_y2)
	elseif policy == "AddSafeArea" then
		margins_x1 = margins_x1 + area_x1
		margins_y1 = margins_y1 + area_y1
		margins_x2 = margins_x2 + area_x2
		margins_y2 = margins_y2 + area_y2
	end
	return margins_x1, margins_y1, margins_x2, margins_y2
end

function XGetDepth(win)
	local n = 0
	while win do
		win = win.parent
		n = n + 1
	end
	return n
end

function XFindCommonParent(win1, win2, d1, d2)
	d1 = d1 or XGetDepth(win1)
	d2 = d2 or XGetDepth(win2)
	for i = d2 + 1, d1 do
		win1 = win1 and win1.parent
	end
	for i = d1 + 1, d2 do
		win2 = win2 and win2.parent
	end
	while win1 and win2 and win1 ~= win2 do
		win1 = win1.parent
		win2 = win2.parent
	end
	return win1 == win2 and win1
end

function GetParentOfKind(win, class)
	while win and not IsKindOf(win, class) do
		win = win.parent
	end
	return win
end

function GetChildrenOfKind(win, class, results)
	if not results then 
		results = {}
	end
	for _, child in ipairs(win) do
		if IsKindOf(child, class) then 
			insert(results, child)
		end
		GetChildrenOfKind(child, class, results)
	end
	return results
end

function XWindow:IsOnTop(win2)
	if not win2 then return true end
	local win1 = self
	local d1 = XGetDepth(win1)
	local d2 = XGetDepth(win2)
	local parent = XFindCommonParent(win1, win2, d1, d2)
	if not parent then return false end
	if win1 == parent then return false end
	if win2 == parent then return true end
	local d = XGetDepth(parent)
	for i = d + 2, d1 do
		win1 = win1 and win1.parent
	end
	for i = d + 2, d2 do
		win2 = win2 and win2.parent
	end
	local i1 = find(parent, win1)
	local i2 = find(parent, win2)
	assert(i1 and i2)
	return i1 > i2
end

function XDbgHierarchy(win)
	if not win then return end
	if win == win.desktop then
		return { "desktop" }
	end
	local parent = win.parent
	if not parent then return end
	local hierarchy = XDbgHierarchy(parent)
	if hierarchy then
		local i = find(parent, win) or 0
		hierarchy[#hierarchy + 1] = win.Id ~= "" and string.format("%d %s", i, win.Id) or i
	end
	return hierarchy
end

function XWindow:GetContext()
	local parent = self.parent
	if parent then
		return parent:GetContext()
	end
end

function XWindow:Get_dbg_context_type()
	local context = self:GetContext()
	if type(context) == "table" then
		return Debugger_ToString(context)
	end
	return type(context)
end

function XWindow:Get_dbg_context()
	local context = self:GetContext()
	if type(context) ~= "table" then
		return Debugger_ToString(context)
	end
	local t = { "{" }
	for k, v in sorted_pairs(context) do
		t[#t + 1] = string.format("%s = %s", Debugger_ToString(k), Debugger_ToString(v))
	end
	return table.concat(t, "\n\t") .. "\n}"
end

function XWindow:OnDialogModeChange(mode, dialog)
end


----- box
local box0 = box(0, 0, 0, 0)
function XWindow:SetInteractionBox(x, y, scale, move_children)
	local children_handle_mouse = self.ChildrenHandleMouse
	-- no need to calculate interaction boxes if nobody is going to use them
	if not self.HandleMouse and not children_handle_mouse then return end
	scale = scale or point(1000, 1000)
	local pos_box = self.box
	local width, height = ScaleXY(scale, pos_box:sizex(), pos_box:sizey())
	local old_box = self.interaction_box or box0
	if width == 0 or height == 0 or (old_box:minx() == x and old_box:miny() == y and old_box:sizex() == width and old_box:sizey() == height) then
		return
	end
	local margins_x1, margins_y1, margins_x2, margins_y2 = self:GetEffectiveMargins()
	margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(scale, margins_x1, margins_y1, margins_x2, margins_y2)
	local self_box = sizebox(x + margins_x1, y + margins_y1, width, height)
	self.interaction_box = self_box
	if children_handle_mouse then
		local dx = self_box:minx() - old_box:minx()
		local dy = self_box:miny() - old_box:miny()
		if dx ~= 0 or dy ~= 0 then
			move_children = move_children or not self.layout_update -- if we're not updating the layout - move all children
			for _, win in ipairs(self) do
				if move_children or win.HAlign == "none" or win.VAlign == "none" or win.Dock == "ignore" then
					local margins_x, margins_y = win:GetEffectiveMargins()
					margins_x, margins_y = ScaleXY(scale, margins_x, margins_y)
					local win_box = win.box
					local win_x, win_y, pos_x, pos_y = ScaleXY(scale, win_box:minx() - margins_x, win_box:miny() - margins_y, pos_box:minx(), pos_box:miny())
					local diff_x = win_x - pos_x
					local diff_y = win_y - pos_y
					win:SetInteractionBox(self_box:minx() + diff_x, self_box:miny() + diff_y, scale, move_children)
				end
			end
		end
	end
end

function XWindow:InvalidateInteractionBox()
	self.interaction_box = false
	for _, win in ipairs(self) do
		win:InvalidateInteractionBox()
	end
end

XWindow.OnBoxChanged = empty_func -- update OnBoxChanged methods to call the base class if you change this

function XWindow:SetBox(x, y, width, height, move_children)
	width = Max(width, 0)
	height = Max(height, 0)
	local self_box = self.box
	if self_box:minx() == x and self_box:miny() == y and self_box:sizex() == width and self_box:sizey() == height then
		return
	end
	self:Invalidate()
	self_box = sizebox(x, y, width, height)
	self.box = self_box
	-- fix zoom modifiers rects
	if width > 0 and height > 0 then
		local intRect = const.intRect
		for _, modifier in ipairs(self.modifiers or empty_table) do
			if modifier.type == intRect then
				if modifier.originalRectAutoZoom then
					modifier.originalRect = self:CalcZoomedBox(modifier.originalRectAutoZoom)
				end
				if modifier.targetRectAutoZoom then
					modifier.targetRect = self:CalcZoomedBox(modifier.targetRectAutoZoom)
				end
			end
		end
	end
	self:OnBoxChanged()
	local content_box, border_width, padding = self_box, self.BorderWidth, self.Padding
	if padding ~= empty_box or border_width ~= 0 then
		local scale = self.scale
		local border_x, border_y = ScaleXY(scale, self.BorderWidth, self.BorderWidth)
		local padding_x1, padding_y1, padding_x2, padding_y2 = ScaleXY(scale, self.Padding:xyxy())
		content_box = self_box:grow(border_x + padding_x1, border_y + padding_y1, - border_x - padding_x2, - border_y - padding_y2)
	end
	local old_box = self.content_box
	if content_box == old_box then
		return
	end
	self.content_box = content_box
	if content_box:sizex() ~= old_box:sizex() or content_box:sizey() ~= old_box:sizey() then
		self:InvalidateLayout()
	end
	local dx = content_box:minx() - old_box:minx()
	local dy = content_box:miny() - old_box:miny()
	if (dx ~= 0 or dy ~= 0) and move_children ~= "dont-move" then
		move_children = move_children or not self.layout_update -- if we're not updating the layout - move all children
		for _, win in ipairs(self) do
			if move_children or win.HAlign == "none" or win.VAlign == "none" or win.Dock == "ignore" then
				local win_box = win.box
				win:SetBox(win_box:minx() + dx, win_box:miny() + dy, win_box:sizex(), win_box:sizey())
			end
		end
		CallMember(self.modifiers, "OnWindowMove", self)
	end
	if RolloverWin and (self == RolloverControl or (self.Id or "") ~= "" and self.Id == RolloverControl.RolloverAnchorId) then
		RolloverWin:ControlMove(RolloverControl)
	end
end

function XWindow:Getcontent_box_size()
	return self.content_box:size()
end

function XWindow:SetLayoutSpace(space_x, space_y, space_width, space_height)
	local margins_x1, margins_y1, margins_x2, margins_y2 = self:GetEffectiveMargins()
	local h_align = self.HAlign
	local v_align = self.VAlign
	local box = self.box
	local x, y, width, height
	
	if h_align == "stretch" then
		width = space_width - margins_x1 - margins_x2
		x = space_x + margins_x1
	elseif h_align == "left" then
		width = Min(self.measure_width, space_width) - margins_x1 - margins_x2
		x = space_x + margins_x1
	elseif h_align == "right" then
		width = Min(self.measure_width, space_width) - margins_x1 - margins_x2
		x = space_x + space_width - width - margins_x2
	elseif h_align == "center" then
		width = Min(self.measure_width, space_width) - margins_x1 - margins_x2
		x = space_x + margins_x1 + (space_width - width - margins_x1 - margins_x2) / 2
	else
		width = box:sizex()
		x = box:minx()
	end
	
	if v_align == "stretch" then
		height = space_height - margins_y1 - margins_y2
		y = space_y + margins_y1
	elseif v_align == "top" then
		height = Min(self.measure_height, space_height) - margins_y1 - margins_y2
		y = space_y + margins_y1
	elseif v_align == "bottom" then
		height = Min(self.measure_height, space_height) - margins_y1 - margins_y2
		y = space_y + space_height - height - margins_y2
	elseif v_align == "center" then
		height = Min(self.measure_height, space_height) - margins_y1 - margins_y2
		y = space_y + margins_y1 + (space_height - height - margins_y1 - margins_y2) / 2
	else
		height = box:sizey()
		y = box:miny()
	end
	
	self:SetBox(x, y, width, height)
end


----- scale

function XWindow:SetScaleModifier(modifier)
	self.ScaleModifier = modifier
	local parent = self.parent
	if parent then
		self:SetOutsideScale(parent.scale)
	end
end

local one = point(1000, 1000)
function XWindow:SetOutsideScale(scale)
	if self.ScaleModifier ~= one then
		scale = point(ScaleXY(scale, self.ScaleModifier:xy()))
	end
	if self.scale == scale then return end
	assert(scale:x() ~= 0 or scale:y() ~= 0)
	self.scale = scale
	self:InvalidateMeasure()
	self:OnScaleChanged(scale)
	for _, child in ipairs(self) do
		child:SetOutsideScale(scale)
	end
end

function XWindow:OnScaleChanged(scale)
end


----- measure

function XWindow:InvalidateMeasure(child)
	if self.measure_update then
		if not child then
			self.measure_update = "force"
		end
		return
	end
	self.measure_update = child or "force"
	
	local parent = self.parent
	if parent then
		return parent:InvalidateMeasure(true)
	end
end

local function MarkChildrenForMeasure(children)
	if not children then return end
	for _, win in ipairs(children) do
		win.measure_update = true
		MarkChildrenForMeasure(win)
	end
end

function XWindow:SortChildren()
	local change
	-- sort the children by their .ZOrder field
	-- insertion sort because it is stable and O(n) when already sorted
	for i = 2, #self do
		local win = self[i]
		local ZOrder = win.ZOrder
		for j = i - 1, 1, -1 do
			if self[j].ZOrder > ZOrder then
				self[j + 1] = self[j]
				self[j] = win
				change = true
			else
				break
			end
		end
	end
	return change
end

function XWindow:UpdateMeasure(max_width, max_height)
	self.last_max_width = max_width
	self.last_max_height = max_height
	if not self.measure_update then return end
	if self.measure_update == "force" then
		MarkChildrenForMeasure(self)
	end
	if self.FoldWhenHidden and not self.visible then
		if self.measure_width ~= 0 or self.measure_height ~= 0 then
			self.measure_width = 0
			self.measure_height = 0
			if self.parent then
				self.parent:InvalidateLayout()
			end
		end
		self.measure_update = false
		return
	end
	if self:SortChildren() then
		self:InvalidateLayout()
	end
	-- remove padding, borders and margins
	local scale = self.scale
	local minWidth, minHeight, maxWidth, maxHeight = 
		ScaleXY(scale, self.MinWidth, self.MinHeight, self.MaxWidth, self.MaxHeight)
	local padding_x1, padding_y1, padding_x2, padding_y2 = ScaleXY(scale, self.Padding:xyxy())
	local margins_x1, margins_y1, margins_x2, margins_y2 = self:GetEffectiveMargins()
	local border_x, border_y = ScaleXY(scale, self.BorderWidth, self.BorderWidth)
	max_width = max_width - margins_x1 - margins_x2
	max_height = max_height - margins_y1 - margins_y2
	max_width = Clamp(max_width, minWidth, maxWidth)
	max_height = Clamp(max_height, minHeight, maxHeight)
	max_width, max_height = self:MeasureSizeAdjust(max_width, max_height)
	max_width = max_width - padding_x1 - padding_x2 - 2 * border_x
	max_height = max_height - padding_y1 - padding_y2 - 2 * border_y
	-- measure
	local width, height = self:Measure(max_width, max_height)
	-- add padding, borders and margins
	width = Clamp(width + padding_x1 + padding_x2 + 2 * border_x, minWidth, maxWidth)
		 + margins_x1 + margins_x2
	height = Clamp(height + padding_y1 + padding_y2 + 2 * border_y, minHeight, maxHeight)
		 + margins_y1 + margins_y2
	-- update values if necessary
	if width ~= self.measure_width or height ~= self.measure_height then
		self.measure_width = width
		self.measure_height = height
		if self.parent then
			self.parent:InvalidateLayout()
		end
	end
	self.measure_update = false
end

function XWindow:MeasureSizeAdjust(max_width, max_height)
	return max_width, max_height
end

-- Measure returns the minimum control width/height given a maximum width/height
function XWindow:Measure(max_width, max_height)
	self.content_measure_width = max_width
	self.content_measure_height = max_height

	if #self == 0 then return 0, 0 end
	local docked_windows
	for _, win in ipairs(self) do
		local dock = win.Dock
		if dock then
			docked_windows = true
			win:UpdateMeasure(max_width, max_height)
			if dock == "left" or dock == "right"  then
				max_width = Max(0, max_width - win.measure_width)
			elseif dock == "top" or dock == "bottom" then
				max_height = Max(0, max_height - win.measure_height)
			else
			end
		end
	end
	-- measure the rest of the windows
	local width, height = XWindowMeasureFuncs[self.LayoutMethod](self, max_width, max_height)
	if docked_windows then
		for i = #self, 1, -1 do
			local win = self[i]
			local dock = win.Dock
			if dock then
				if dock == "left" or dock == "right" then
					width = width + win.measure_width
					height = Max(height, win.measure_height)
				elseif dock == "top" or dock == "bottom" then
					width = Max(width, win.measure_width)
					height = height + win.measure_height
				elseif dock == "box" then
					width = Max(width, win.measure_width)
					height = Max(height, win.measure_height)
				end
			end
		end
	end
	return width, height
end


----- layout

function XWindow:InvalidateLayout()
	if self.layout_update then return end
	self.layout_update = true
	local parent = self.parent
	if parent then
		return parent:InvalidateLayout()
	end
end

function XWindow:UpdateLayout()
	if not self.layout_update then return end
	
	-- calculate the layout of docked children
	local x, y = self.content_box:minxyz()
	local width, height = self.content_box:sizexyz()
	for _, win in ipairs(self) do
		local dock = win.Dock
		if dock then
			if dock == "left" then
				local item_width = Min(win.measure_width, width)
				width = width - item_width
				win:SetLayoutSpace(x, y, item_width, height)
				x = x + item_width
			elseif dock == "right" then
				local item_width = Min(win.measure_width, width)
				width = width - item_width
				win:SetLayoutSpace(x + width, y, item_width, height)
			elseif dock == "top" then
				local item_height = Min(win.measure_height, height)
				height = height - item_height
				win:SetLayoutSpace(x, y, width, item_height)
				y = y + item_height
			elseif dock == "bottom" then
				local item_height = Min(win.measure_height, height)
				height = height - item_height
				win:SetLayoutSpace(x, y + height, width, item_height)
			elseif dock == "box" then
				win:SetLayoutSpace(x, y, width, height)
			end
		end
	end

	self:Layout(x, y, width, height)
	self:LayoutChildren()
	
	local iterations, updated = 0
	repeat
		procall(self.FinalizeLayout, self)
		updated = self:LayoutChildren() -- update children layout in case it was invalidated in OnLayoutComplete
		--if updated then
		--	CreateRealTimeThread(print, "UI layout nested update", self.Id ~= "" and self.Id or self.class, updated.Id ~= "" and updated.Id or updated.class)
		--end
		iterations = iterations + 1
	until not updated or iterations > 5
	assert(GameTestsRunning or iterations <= 5, "Too many nested layout updates caused by OnLayoutComplete.")
	
	self.layout_update = false
end

function XWindow:LayoutChildren()
	local updated
	for _, win in ipairs(self) do
		if win.layout_update then
			win:UpdateLayout()
			assert(not win.layout_update, "UpdateLayout methods doesn't clear .layout_update?")
			updated = win
		end
	end
	return updated
end

function XWindow:FinalizeLayout()
	self:OnLayoutComplete() -- set box of children with dock = "ignore", start interpolations here
	CallMember(self.modifiers, "OnLayoutComplete", self) -- layout modifiers
end

function XWindow:Layout(x, y, width, height)
	if #self > 0 then
		XWindowLayoutFuncs[self.LayoutMethod](self, x, y, width, height)
	end
end


----- draw

function XWindow:Invalidate()
	self.invalidated = true -- used for optimization only (when tons of children of the same parent are getting invalidated)
	local parent = self.parent
	if parent and not parent.invalidated then
		return parent:Invalidate()
	end
end

local visualize_invalidation = false
local invalidate_visible_time = 2000

--visualize_invalidation = true -- uncomment to see invalidated windows on the screen
if visualize_invalidation then
	XWindow.InvalidateColor = 0
	XWindow.InvalidateTime = 0

	local invalidated_windows = {}
	local clearing_rects = false

	function XWindow:Invalidate()
		self.invalidated = true -- used for optimization only (when tons of children of the same parent are getting invalidated)
		local parent = self.parent
		if parent and not parent.invalidated then
			if clearing_rects then
				self.InvalidateColor = 0
				invalidated_windows[self] = nil
			else
				self.InvalidateColor = RandColor()
				self.InvalidateTime = GetPreciseTicks()
				invalidated_windows[self] = true
			end
			return parent:Invalidate()
		end
	end

	MapRealTimeRepeat("ClearInvalidatedWindows", 500, function()
		clearing_rects = true
		for win in pairs(invalidated_windows) do
			if GetPreciseTicks() - win.InvalidateTime > invalidate_visible_time then
				win:Invalidate()
			end
		end
		clearing_rects = false
	end)
end

local PushClipRect = UIL.PushClipRect
local PopClipRect = UIL.PopClipRect
local ModifiersSetTop = UIL.ModifiersSetTop
local ModifiersGetTop = UIL.ModifiersGetTop
local PushModifier = UIL.PushModifier
local irOutside = const.irOutside

function XWindow:DrawWindow(clip_box)
	--[[if self.window_state ~= "open" and self.window_state ~= "closing" then
		UIL.DrawSolidRect(self.box)
		return
	end]]
	local modifiers = self.modifiers
	local prev_int = ModifiersGetTop()
	if modifiers then
		local i = 1
		while i <= #modifiers do
			local int = modifiers[i]
			if PushModifier(int) then
				i = i + 1
			else
				remove(modifiers, i)
				if #modifiers == 0 then
					self.modifiers = nil
				end
			end
		end
	end
	self:DrawBackground()
	local clip = self.Clip
	if clip then
		clip_box = clip == "self" and self.content_box or IntersectRects(clip_box, self.content_box)
		PushClipRect(clip_box, false)
	end
	self:DrawContent(clip_box)
	self:DrawChildren(clip_box)
	if clip then
		PopClipRect()
	end
	if self.desktop.rollover_logging_enabled and self == self.desktop.last_mouse_target then
		UIL.DrawBorderRect(self.box, 1, 1, RGB(0, 255, 0), 0, 0, 0)
	end
	if visualize_invalidation and GetPreciseTicks() - self.InvalidateTime < invalidate_visible_time then
		UIL.DrawBorderRect(self.content_box, 1, 1, self.InvalidateColor, 0, 0, 0)
	end
	ModifiersSetTop(prev_int)
	self.invalidated = nil
end

function XWindow:DrawBackground()
	local border = self.BorderWidth
	local background = self:CalcBackground() or 0
	local glow_size = self.BackgroundRectGlowSize
	if border ~= 0 or background ~= 0 or glow_size ~= 0 then
		local border_width, border_height = ScaleXY(self.scale, border, border)
		glow_size = ScaleXY(self.scale, glow_size)
		UIL.DrawBorderRect(self.box, border_width, border_height, self:CalcBorderColor(), background, glow_size, self.BackgroundRectGlowColor)
	end
end

function XWindow:DrawContent(clip_box)
end

local Intersect2D = box().Intersect2D
function XWindow:DrawChildren(clip_box)
	local chidren_on_top
	local UseClipBox = self.UseClipBox
	for _, win in ipairs(self) do
		if win.visible and not win.outside_parent and (not UseClipBox or Intersect2D(win.box, clip_box) ~= irOutside) then
			if win.DrawOnTop then
				chidren_on_top = true
			else
				win:DrawWindow(clip_box)
			end
		end
	end
	if chidren_on_top then
		for _, win in ipairs(self) do
			if win.DrawOnTop and win.visible and not win.outside_parent and (not UseClipBox or Intersect2D(win.box, clip_box) ~= irOutside) then
				win:DrawWindow(clip_box)
			end
		end
	end
end

function XWindow:CalcBackground()
	return self.Background
end

function XWindow:CalcBorderColor()
	return self.BorderColor
end

function XWindow:SetOutsideParent(outside_parent)
	self.outside_parent = outside_parent
end


------ visibility

function XWindow:GetVisible()
	return self.target_visible
end

function XWindow:SetVisible(visible, instant, callback)
	if self.window_state == "destroying" then return end
	visible = visible and true or false
	local old_target_visible = self.target_visible
	self.target_visible = visible
	if instant then
		self:RemoveModifier("fade")
		self:SetVisibleInstant(visible)
		return
	end
	if old_target_visible == visible then
		return
	end
	
	local action_duration = visible and self.FadeInTime or self.FadeOutTime
	if action_duration <= 0 then
		self:RemoveModifier("fade")
		self:SetVisibleInstant(visible)
		return
	end
	self:SetVisibleInstant(true)
	self:_ContinueInterpolation{
		id = "fade",
		type = const.intAlpha,
		startValue = visible and 0 or (255 - self.transparency),
		endValue = visible and (255 - self.transparency) or 0,
		duration = action_duration,
		visible = visible,
		autoremove = true,
		callback = callback,
		on_complete = function(self, int)
			self:SetVisibleInstant(int.visible)
			if int.callback then
				int.callback(self, int)
			end
		end,
	}
end

function XWindow:SetVisibleInstant(visible)	
	if self.visible == (visible or false) then
		return
	end
	self.visible = visible
	self.target_visible = visible
	if self.FoldWhenHidden then
		self:InvalidateMeasure()
	end
	if not visible and self.window_state ~= "destroying" then
		local desktop = self.desktop
		if desktop:GetModalWindow():IsWithin(self) then
			desktop:RestoreModalWindow()
		end
		local focus = desktop:GetKeyboardFocus()
		if focus and focus:IsWithin(self) then
			desktop:RestoreFocus()
		end
	end
	
	self:Invalidate()
end

function XWindow:IsVisible()
	local win = self
	while win and win.visible and win.window_state ~= "destroying" do
		local parent = win.parent
		if not parent then
			return win == self.desktop
		end
		win = parent
	end
end

local interpolateClipDontModify = 4
function XWindow:SetTransparency(transparency, time, easing)
	local existingTransp = self:FindModifier("_transparency")
	if existingTransp and self.transparency == transparency and existingTransp.duration == (time or 0) then
		return
	end

	local prev = self.transparency
	transparency = Clamp(transparency, 0, 255)
	self.transparency = transparency
	self:RemoveModifier("_transparency")
	if transparency <= 0 and not time then
		return
	end
	if time then
		self:AddInterpolation{
			id = "_transparency",
			type = const.intAlpha,
			startValue = 255 - prev,
			endValue = 255 - transparency,
			duration = time,
			easing = easing or 0,
			interpolate_clip = interpolateClipDontModify
		}
	else
		self:AddInterpolation{
			id = "_transparency",
			type = const.intAlpha,
			startValue = 255 - transparency,
			interpolate_clip = interpolateClipDontModify
		}
	end
end

function XWindow:GetTransparency()
	return self.transparency
end


----- keyboard

function XWindow:SetModal(set)
	local desktop = self.desktop
	if set == false then
		return desktop and desktop:RemoveModalWindow(self)
	end
	return desktop and desktop:SetModalWindow(self)
end

function XWindow:SetFocus(set, children)
	local desktop = self.desktop
	if set == false then
		return desktop and desktop:RemoveKeyboardFocus(self, children)
	end
	return desktop and desktop:SetKeyboardFocus(self)
end

function XWindow:IsFocused(include_children)
	local desktop = self.desktop
	local focus = desktop and desktop:GetKeyboardFocus()
	if not desktop then return end
	if include_children then
		return focus and focus:IsWithin(self)
	else
		return focus == self
	end
end

function XWindow:OnSetFocus(focus)
	if self.RolloverOnFocus then
		self:SetRollover(true)
		if self:GetRolloverTemplate() ~= "" and self:GetRolloverText() ~= "" then
			XCreateRolloverWindow(self, GetUIStyleGamepad())
		end
	end
end

function XWindow:OnKillFocus()
	if self.RolloverOnFocus and self.desktop.last_mouse_target ~= self then
		self:SetRollover(false)
		if self == RolloverControl then
			XDestroyRolloverWindow()
		end
	end
end

function XWindow:OnKbdIMEStartComposition(char, virtual_key, repeated, time, lang) --char, vkey, repeat, time, lang
end

function XWindow:OnKbdIMEEndComposition(...) --char, vkey, repeat, time, lang
end

function XWindow:GetEnabled()
	return true
end


------ mouse

function XWindow:PointInWindow(pt)
	local f = pt[self.Shape] or pt.InBox
	local box = self.interaction_box or self.box
	return f(pt, box)
end

function XWindow:MouseInWindow(pt)
	if self.visible and not self.outside_parent and self.window_state ~= "destroying" then
		return self:PointInWindow(pt)
	end
end

function XWindow:GetMouseTarget(pt)
	if self.ChildrenHandleMouse then
		local target, mouse_cursor
		for i = #self, 1, -1 do
			local win = self[i]
			if (not target or win.DrawOnTop) and win:MouseInWindow(pt) then
				local newTarget, newMouse_cursor = win:GetMouseTarget(pt)
				if newTarget then
					target, mouse_cursor = newTarget, newMouse_cursor
					if win.DrawOnTop then
						break
					end
				end
			end
		end
		if target then
			return target, mouse_cursor or self:GetMouseCursor()
		end
	end
	if self.HandleMouse then
		return self, self:GetMouseCursor()
	end
end

function XWindow:SetMouseCursor(image)
	local old = self.MouseCursor
	self.MouseCursor = image ~= "" and image or nil
	if old ~= self.MouseCursor then
		self:Invalidate()
	end
end

function XWindow:SetDisabledMouseCursor(image)
	self.DisabledMouseCursor = image ~= "" and image or nil
end

function XWindow:GetMouseCursor()
	return not self:GetEnabled() and self.DisabledMouseCursor or self.MouseCursor
end

function XWindow:GetDisabledMouseCursor()
	return self.DisabledMouseCursor
end

function XWindow:OnCaptureLost()
end

function XWindow:OnMouseEnter(pt, child)
	self:SetRollover(true)
end

function XWindow:OnMouseLeft(pt, child)
	if not self.RolloverOnFocus or not self:IsFocused() then
		self:SetRollover(false)
	end
end

function XWindow:SetRollover(rollover)
	rollover = rollover or false
	if self.rollover == rollover then return end
	self.rollover = rollover
	self:OnSetRollover(rollover)
end

function XWindow:OnSetRollover(rollover)
	if self.RolloverDrawOnTop then
		self:SetDrawOnTop(rollover)
	end
	if self:GetEnabled() and self.RolloverZoom ~= 1000 then
		self:AddInterpolation{
			id = "zoom",
			type = const.intRect,
			duration = rollover and self.RolloverZoomInTime or self.RolloverZoomOutTime,
			originalRect = self.box,
			originalRectAutoZoom = 1000,
			targetRect = self:CalcZoomedBox(self.RolloverZoom),
			targetRectAutoZoom = self.RolloverZoom,
			flags = not rollover and const.intfInverse or nil,
			autoremove = not rollover or nil,
		}
	end
	local idRollover = rawget(self, "idRollover")
	if idRollover then
		idRollover:SetVisible(rollover)
	end
end

function XWindow:CalcZoomedBox(promils)
	local self_box = self.box
	local width, height = self_box:sizexyz()
	local new_width = self.RolloverZoomX and (width * promils / 1000) or width
	local new_height = self.RolloverZoomY and (height * promils / 1000) or height
	return sizebox(
		self_box:minx() - (new_width - width) / 2, 
		self_box:miny() - (new_height - height) / 2, 
		new_width,
		new_height)
end

function XWindow:IsDropTarget(draw_win, pt)
end


----- threads

function XWindow:DeleteThread(name)
	if not self.real_time_threads then return end
	if self.real_time_threads[name] then
		DeleteThread(self.real_time_threads[name])
		self.real_time_threads[name] = nil
	end
end

function XWindow:CreateThread(name, func, ...)
	func = func or name
	assert(not func or type(func) == "function")
	self.real_time_threads = self.real_time_threads or {}
	assert(not self.real_time_threads[name] or not IsValidThread(self.real_time_threads[name]), "Window thread '" .. tostring(name or "default") .. "' is being created anew")
	DeleteThread(self.real_time_threads[name])
	self.real_time_threads[name] = CreateRealTimeThread(func, ...)
	dbg(ThreadsSetThreadSource(self.real_time_threads[name], self.class, name))
end

function XWindow:WakeupThread(name)
	local thread = self.real_time_threads and self.real_time_threads[name]
	if thread then
		Wakeup(thread)
	end
end

function XWindow:GetThread(name)
	local thread = self.real_time_threads and self.real_time_threads[name]
	return IsValidThread(thread) and thread
end

function XWindow:IsThreadRunning(name)
	return IsValidThread(self.real_time_threads and self.real_time_threads[name])
end

function XWindow:GetThreadName(thread)
	thread = thread or CurrentThread()
	for name, _thread in pairs(self.real_time_threads) do
		if _thread == thread then
			return name
		end
	end
end

-- Internal use only
function XWindow:DeleteAllThreads()
	if not self.real_time_threads then return end
	local current_thread = CurrentThread()
	local current_thread_name
	for name, thread in pairs(self.real_time_threads) do
		if current_thread == thread then
			-- Someone called :delete() from one of his threads, which is fine. 
			--	He shouldn't do anything else after that though (we'll check!)
			current_thread_name = name or "default"
		else
			DeleteThread(thread)
		end
	end
	--[[
	-- Let's check if someone forgot returning from his window thread after calling :destroy
	--		It shouldn't be alive at the end of the same millisecond.
	if current_thread_name then
		CreateRealTimeThread(function() 
			assert(not IsValidThread(current_thread), "Window thread " .. current_thread_name .. " is still alive after calling :delete()!")
			DeleteThread(current_thread) -- shouldn't be necessary!
		end)
	end --]]
end


----- modifiers/interpolations

function IntRectTopLeftRelative(modifier, window)
	-- Rects are expected to be relative to 0,0
	local originalRect = modifier.originalRect
	local targetRect = modifier.targetRect
	local box = window.box

	modifier.originalRect = Offset(originalRect,
		box:minx() - originalRect:minx(), 
		box:miny() - originalRect:miny())
	modifier.targetRect = Offset(targetRect,
		box:minx() - targetRect:minx(),
		box:miny() - targetRect:miny())
end

function IntRectCenterRelative(modifier, window)
	-- Rects are expected to be relative to 0,0
	local originalRect = modifier.originalRect
	local targetRect = modifier.targetRect
	local box = window.box
	
	modifier.originalRect = Offset(originalRect,
		(box:minx() + box:maxx()) / 2 - (originalRect:minx() + originalRect:maxx()) / 2,
		(box:miny() + box:maxy()) / 2 - (originalRect:miny() + originalRect:maxy()) / 2)
	modifier.targetRect = Offset(targetRect,
		(box:minx() + box:maxx()) / 2 - (targetRect:minx() + targetRect:maxx()) / 2,
		(box:miny() + box:maxy()) / 2 - (targetRect:miny() + targetRect:maxy()) / 2)
end

function IntRectTopRightRelative(modifier, window)
	-- Rects are expected to be relative to 0,0
	local originalRect = modifier.originalRect
	local targetRect = modifier.targetRect
	local box = window.box

	modifier.originalRect = Offset(originalRect,
		box:maxx() - originalRect:maxx(), 
		box:miny() - originalRect:miny())
	modifier.targetRect = Offset(targetRect,
		box:maxx() - targetRect:maxx(),
		box:miny() - targetRect:miny())
end

local function ValidateModifierTarget(modifier)
	local target = modifier.target
	if IsPoint(target) then
		assert(target:IsValid())
		assert(target:IsValidZ())
	end
end

function XWindow:AddInterpolation(int, idx)
	if not int then return end

	local modifiers = self.modifiers
	if not modifiers then
		modifiers = {}
		self.modifiers = modifiers
	elseif int.id then
		-- adding an interpolation with id removes any preivous ones with that id
		remove_value(modifiers, "id", int.id)
	end

	dbg(ValidateModifierTarget(int))
	
	int.modifier_type = const.modInterpolation
	insert(modifiers, idx or #modifiers + 1, int)

	local bGameTime = IsFlagSet(int.flags or 0, const.intfGameTime)
	local bCustomTime = IsFlagSet(int.flags or 0, const.intfUILCustomTime)
	assert((bCustomTime and bGameTime) == false) --can't both be true
	local time = bGameTime and GameTime() or (bCustomTime and hr.UIL_CustomTime or GetPreciseTicks())
	int.start = int.start or time
	int.duration = int.duration or 0
	int.endValue = int.endValue or int.startValue
	int.startValue = int.startValue or int.endValue
	if int.autoremove or int.on_complete then
		local time_to_end = int.start + int.duration - time
		local CreateThread = bGameTime and CreateGameTimeThread or CreateRealTimeThread
		local lOnDone = function(self, int)
			if self.window_state ~= "destroying" then
				if int.autoremove then
					if self:RemoveModifier(int) then
						(int.on_complete or empty_func)(self, int)
					end
				elseif self:FindModifier(int) then
					int.on_complete(self, int)
				end
			end
		end
		CreateThread(function(self, int, time_to_end, bCustomTime)
			if not bCustomTime then
				Sleep(time_to_end)
			else
				local end_time = int.start + int.duration
				while end_time > hr.UIL_CustomTime do
					WaitMsg("UILCustomTimeAdvanced", 100)
				end
			end
			
			lOnDone(self, int)
		end, self, int, time_to_end, bCustomTime)
	end
	if int.OnLayoutComplete then int:OnLayoutComplete(self) end
	self:Invalidate()
	return int
end

function SetUILCustomTime(time)
	hr.UIL_CustomTime = time
	Msg("UILCustomTimeAdvanced")
end

function XWindow:AddShaderModifier(modifier)
	if not modifier then return end
	local modifiers = self.modifiers
	if not modifiers then
		modifiers = {}
		self.modifiers = modifiers
	elseif modifier.id then
		-- adding an modifier with id removes any previous ones with that id
		remove_value(modifiers, "id", modifier.id)
	end
	modifiers[#modifiers + 1] = modifier
	modifier.modifier_type = const.modShader
	if modifier.OnLayoutComplete then modifier:OnLayoutComplete(self) end
	self:Invalidate()
	return modifier
end

function XWindow:AddDynamicPosModifier(modifier)
	if not modifier then return end
	local modifiers = self.modifiers
	if not modifiers then
		modifiers = {}
		self.modifiers = modifiers
	elseif modifier.id then
		-- adding a modifier with id removes any preivous ones with that id
		remove_value(modifiers, "id", modifier.id)
	end
	
	if modifier.faceTargetOffScreen and not modifier.OnLayoutComplete then
		modifier.OnLayoutComplete = function(mod, wnd) mod.modWindowSize = wnd.box:size() end
	end
	
	dbg(ValidateModifierTarget(modifier))
	
	modifiers[#modifiers + 1] = modifier
	modifier.modifier_type = const.modDynPos
	if modifier.OnLayoutComplete then modifier:OnLayoutComplete(self) end
	self:Invalidate()
	return modifier
end

-- Utility function like AddInterpolation, but will attempt to continue from the current state instead of restarting
--	Wouldn't work for non-linear easings. Caller must be sure all other settings are compatible as well (flags, etc)
function XWindow:_ContinueInterpolation(int)
	assert( not int.easing or int.easing == "Linear" or int.easing == GetEasingIndex("Linear") )
	assert( not int.start ) -- In the calculations below we assume we start now
	local old = find(self.modifiers, "id", int.id)
	if old then
		old = self.modifiers[old]
		assert( not old.easing or old.easing == "Linear" or old.easing == GetEasingIndex("Linear") )
		int.flags = int.flags or old.flags

		local time = GetPreciseTicks()
		local oldElapsed = time - old.start
		local currentValue
		if old.duration == 0 or oldElapsed > old.duration then
			currentValue = old.endValue
		else
			currentValue = old.startValue + MulDivTrunc( old.endValue - old.startValue , oldElapsed, old.duration)
		end
		local targetDuration = MulDivTrunc( int.duration, int.endValue - currentValue, int.endValue - int.startValue )
		int.startValue = currentValue
		int.duration = targetDuration
	end
	return self:AddInterpolation(int)
end

function XWindow:GetInterpolatedBox(specific_modifier, boxOverride)
	local winBox = boxOverride or self.box
	if not self.modifiers then return winBox end

	for i = #self.modifiers, 1, -1 do
		local m = self.modifiers[i]
		if m.type ~= const.intRect or (specific_modifier and m.id ~= specific_modifier) then goto continue end
		if m.exclude_from_interpbox then goto continue end
		
		local t = false
		if IsFlagSet(m.flags or 0, const.intfGameTime) then
			t = GameTime()
		elseif IsFlagSet(m.flags or 0, const.intfUILCustomTime) then
			t = hr.UIL_CustomTime
		else
			t = GetPreciseTicks()
		end
		t = t - m.start
		local duration = m.duration
		if IsFlagSet(m.flags or 0, const.intfInverse) then
			t = duration - t
		end
		
		if m.force_in_interpbox == "start" then
			t = m.start
		elseif m.force_in_interpbox == "end" then
			t = m.start + duration
		end

		local ogMinX, ogMinY, ogMaxX, ogMaxY = m.originalRect:xyxy()
		ogMaxX = ogMaxX - ogMinX
		ogMaxY = ogMaxY - ogMinY
		
		local tarMinX, tarMinY, tarMaxX, tarMaxY = m.targetRect:xyxy()
		tarMaxX = tarMaxX - tarMinX
		tarMaxY = tarMaxY - tarMinY

		local curMinX, curMinY, curMaxX, curMaxY = false, false, false, false
		if t >= duration or duration == 0 then
			curMinX, curMinY, curMaxX, curMaxY = tarMinX, tarMinY, tarMaxX, tarMaxY
		elseif t <= 0 then
			curMinX, curMinY, curMaxX, curMaxY = ogMinX, ogMinY, ogMaxX, ogMaxY
		else
			local easing = m.easing
			if easing then
				t = EaseCoeff(easing, t, duration)
			end
			curMinX, curMinY, curMaxX, curMaxY = Lerp(m.originalRect, m.targetRect, t, duration):xyxy()
			curMaxX = curMaxX - curMinX
			curMaxY = curMaxY - curMinY
		end

		local winMinX, winMinY, winMaxX, winMaxY = winBox:xyxy()
		winBox = box(
			(ogMaxX>0) and (curMinX + MulDivRound(winMinX - ogMinX, curMaxX, ogMaxX)) or curMinX,
			(ogMaxY>0) and (curMinY + MulDivRound(winMinY - ogMinY, curMaxY, ogMaxY)) or curMinY,
			(ogMaxX>0) and (curMinX + MulDivRound(winMaxX - ogMinX, curMaxX, ogMaxX)) or curMinX,
			(ogMaxY>0) and (curMinY + MulDivRound(winMaxY - ogMinY, curMaxY, ogMaxY)) or curMinY
		)

		::continue::
	end
	
	return winBox
end

-- int is either a modifier or an id of a modifier 
function XWindow:RemoveModifier(int)
	local modifiers = self.modifiers
	if not modifiers or not int then
		return false
	end
	for i = #modifiers, 1, -1 do
		local modifier = modifiers[i]
		if modifier == int or modifier.id == int then
			int = remove(modifiers, i)
			if #modifiers == 0 then
				self.modifiers = nil
			end
			if not int.no_invalidate_on_remove then
				self:Invalidate()
			end
			return int
		end
	end
end

function XWindow:RemoveModifiers(modifier_type)
	local modifiers = self.modifiers
	if not modifiers then
		return false
	end
	local init_count = #modifiers
	for i = #modifiers, 1, -1 do
		local modifier = modifiers[i]
		if modifier.modifier_type == modifier_type then
			remove(modifiers, i)
		end
	end
	if init_count == #modifiers then
		return
	end
	if #modifiers == 0 then
		self.modifiers = nil
	end
	self:Invalidate()
end

function XWindow:FindModifier(int)
	local modifiers = self.modifiers
	if not modifiers then
		return false
	end	
	for i = 1, #modifiers do
		if (modifiers[i] == int or modifiers[i].id == int) then
			return modifiers[i]
		end	
	end
end

function XWindow:ClearModifiers()
	self.modifiers = nil
	self:Invalidate()
end


----- Rollover

function XWindow:CreateRolloverWindow(gamepad, context, pos)
	context = SubContext(self:GetContext(), context)
	context.control = self
	context.anchor = self:ResolveRolloverAnchor(context, pos)
	context.gamepad = gamepad
	
	local win = XTemplateSpawn(self:GetRolloverTemplate(), nil, context)
	if not win then return false end
	win:Open()
	return win
end


----- Focus order - DPad/Tab

function XWindow:EnumFocusChildren(f)
	for _, win in ipairs(self) do
		if win.visible then
			local order = win:GetFocusOrder()
			if order then
				f(win, order:xy())
			else
				win:EnumFocusChildren(f)
			end
		end
	end
end

function XWindow:ResolveRelativeFocusOrder(focus_order)
	for _, win in ipairs(self) do
		local relative = win:GetRelativeFocusOrder()
		if relative ~= "" then
			if relative == "new-line" then
				focus_order = focus_order and point(focus_order:x(), focus_order:y() + 1) or point(1, 1)
				win:SetFocusOrder(focus_order)
			elseif relative == "next-in-line" then
				focus_order = focus_order and point(focus_order:x() + 1, focus_order:y()) or point(1, 1)
				win:SetFocusOrder(focus_order)
			elseif relative == "skip" then
				if focus_order then
					if win.IncreaseRelativeXOnSkip then
						focus_order = point(focus_order:x() + 1, focus_order:y())
					end
					if win.IncreaseRelativeYOnSkip then
						focus_order = point(focus_order:x(), focus_order:y() + 1)
					end
				end
			else
				assert(false, "Unknown relative focus order")
			end
		else
			local order = win:GetFocusOrder()
			if order then
				focus_order = order
			else
				focus_order = win:ResolveRelativeFocusOrder(focus_order)
			end
		end
	end
	return focus_order
end

function XWindow:GetRelativeFocus(order, relation)
	if not order then return false end
	local x, y = order:xy()
	local best, best_x, best_y = false
	
	if relation == "exact" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if child_x == x and child_y == y then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "next" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if (child_y > y or child_y == y and child_x > x) and
				(not best or child_y < best_y 
					or child_y == best_y and child_x < best_x)
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "prev" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if (child_y < y or child_y == y and child_x < x) and
				(not best or child_y > best_y 
					or child_y == best_y and child_x > best_x)
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "nearest" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if not best or abs(child_y - y) < abs(best_y - y)
				or abs(child_y - y) == abs(best_y - y) and abs(child_x - x) < abs(best_x - x)
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "left" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if child_x < x and
				(not best or (abs(child_y - y) < abs(best_y - y)
					or abs(child_y - y) == abs(best_y - y) and child_x > best_x))
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "right" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if child_x > x and
				(not best or (abs(child_y - y) < abs(best_y - y)
					or abs(child_y - y) == abs(best_y - y) and child_x < best_x))
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "up" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if child_y < y and
				(not best or (abs(child_x - x) < abs(best_x - x)
					or abs(child_x - x) == abs(best_x - x) and child_y > best_y))
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	elseif relation == "down" then
		self:EnumFocusChildren(function(child, child_x, child_y)
			if child_y > y and
				(not best or (abs(child_x - x) < abs(best_x - x)
					or abs(child_x - x) == abs(best_x - x) and child_y < best_y))
			then
				best, best_x, best_y = child, child_x, child_y
			end
		end)
	else
		assert(false, "unknown relation")
	end
	return best
end
