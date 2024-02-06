local max_curve_points = 8

DefineClass.XCurveEditor = {
	__parents = { "XControl", "XActionsHost" },
	
	properties = {
		{ category = "General", id = "ControlPoints", editor = "number", default = 4, min = 2, max = max_curve_points, },
		{ category = "General", id = "MaxX", editor = "number", default = 1000, min = 1 },
		{ category = "General", id = "MinX", editor = "number", default = 0, min = 1 },
		{ category = "General", id = "MaxY", editor = "number", default = 1000, min = 1 },
		{ category = "General", id = "MinY", editor = "number", default = 0 },
		{ category = "General", id = "DisplayScaleX", editor = "number", default = 1000, min = 1, help = "Used for displaying numbers around the graph" },
		{ category = "General", id = "DisplayScaleY", editor = "number", default = 1000, min = 1, help = "Used for displaying numbers around the graph"},
		{ category = "General", id = "SnapX", editor = "number", default = 1, min = 1 },
		{ category = "General", id = "SnapY", editor = "number", default = 1, min = 1 },
		{ category = "General", id = "FixedX", editor = "bool", default = false },
		{ category = "General", id = "PushPointsOnMove", editor = "bool", default = true, },
		{ category = "General", id = "CurveColor", editor = "color", default = RGB(0,0,0),  },
		{ category = "General", id = "ControlPointMaxDist", editor = "number", default = 25,  },
		{ category = "General", id = "ControlPointColor", editor = "color", default = RGB(80, 80, 80),  },
		{ category = "General", id = "ControlPointCaptureColor", editor = "color", default = RGB(0,0,0),  },
		{ category = "General", id = "ControlPointHoverColor", editor = "color", default = RGB(130, 130, 130),  },
		{ category = "General", id = "GridUnitX", editor = "number", default = 100, },
		{ category = "General", id = "GridUnitY", editor = "number", default = 100, },
		{ category = "General", id = "GridColor", editor = "color", default = RGB(180, 180, 180),  },
		{ category = "General", id = "Smooth", editor = "bool", default = true, },
		{ category = "General", id = "ReadOnly", editor = "bool", default = false, },
		{ category = "General", id = "MinMaxRangeMode", editor = "bool", defalt = false, help = "Stores the /Min/ Value in point.z" },
	},
	
	OnCurveChanged = false,
	point_handles = false,
	capture_handle = false,
	hover_handle = false,
	points = false,
	scale_texts = false,
	font_id = false,

	text_space_required = false,
	MinMaxRangeMode = false,
}

-- debug helpers
for i = 1, max_curve_points do
	local xname = "x" .. i
	local yname = "y" .. i
	table.insert(XCurveEditor.properties, {
		category = "General", id = xname, editor = "number", min = 0, default = 0,
		max = function(obj) return obj.MaxX end, slider = true, --read_only = true,
		no_edit = function(obj) return i > obj.ControlPoints end,
	})
	table.insert(XCurveEditor.properties, {
		category = "General", id = yname, editor = "number", min = 0, default = 0,
		max = function(obj) return obj.MaxY end, slider = true, --read_only = true,
		no_edit = function(obj) return i > obj.ControlPoints end,
	})
	XCurveEditor["Get" .. xname] = function(obj) return obj.points[i]:x() end
	XCurveEditor["Get" .. yname] = function(obj) return obj.points[i]:y() end
	XCurveEditor["Set" .. xname] = function(obj, value) obj:MovePoint(i, obj.points[i]:SetX(value)) end
	XCurveEditor["Set" .. yname] = function(obj, value) obj:MovePoint(i, obj.points[i]:SetY(value)) end
end

function XCurveEditor:GeneratePointUIElements()
	self.point_handles = {}
	for idx, pt in pairs(self.points) do
		local main_handle = XCurveEditorHandle:new({
			point_idx = idx,
			curve_editor = self,
		})
		
		table.insert(self.point_handles, main_handle)

		if self.MinMaxRangeMode then
			local handle = XCurveEditorMinHandle:new({
				point_idx = idx,
				curve_editor = self,
				parent = main_handle,
			})
			
			table.insert(self.point_handles, handle)
			handle = XCurveEditorMaxHandle:new({
				point_idx = idx,
				curve_editor = self,
				parent = main_handle,
			})
			
			table.insert(self.point_handles, handle)
		end
	end
end

function XCurveEditor:GetRange()
	return point(self.MaxX - self.MinX, self.MaxY - self.MinY, self.MaxY - self.MinY)
end

function XCurveEditor:GetRangeMin()
	return point(self.MinX, self.MinY, self.MinY)
end

function XCurveEditor:GetRangeMax()
	return point(self.MaxX, self.MaxY, self.MaxY)
end

function XCurveEditor:Init()
	self.points = {  }
	local max_points = self.ControlPoints - 1
	local range = self:GetRange()
	assert(range:x() > 0 and range:y() > 0)
	for i = 0, max_points do
		local y = i * range:y() / max_points
		table.insert(self.points, point(i * range:x() / max_points, y, y))
	end
	self:GeneratePointUIElements()

end

function XCurveEditor:GetControlPointSize()
	return point(ScaleXY(self.scale, 10, 10))
end

function XCurveEditor:GetGraphBox()
	local control_size = self:GetControlPointSize()
	local topleft_padding = control_size / 2
	local bottomright_padding = control_size / 2
	
	local text_space_required = self.text_space_required
	if text_space_required then
		bottomright_padding = point(Max(text_space_required:x(), bottomright_padding:x()), Max(text_space_required:y(), bottomright_padding:y()))
	end
	return box(self.content_box:min() + topleft_padding, self.content_box:max() - bottomright_padding)
end

function XCurveEditor:TransformPoint(pos)
	local draw_box = self:GetGraphBox()
	local ranges = self:GetRange()
	local base = point(draw_box:minx(), draw_box:maxy())

	pos = pos - self:GetRangeMin()
	pos = point(pos:x(), -pos:y())
	return base + MulDivRoundPoint(draw_box:size(), pos, ranges)
end

local function FitScaleTexts(min_value, max_value, display_scale, size_getter, available_space, min_space_between)
	local begin_text = FormatNumberProp(min_value, display_scale, 2)
	local end_text = FormatNumberProp(max_value, display_scale, 2)
	local text_list = {}
	local secondary_axis_length = 0

	local function subdivide(left_value, right_value, left_pos, right_pos)
		left_pos = left_pos + min_space_between
		right_pos = right_pos - min_space_between
		local diff = right_pos - left_pos
		if diff <= 10 then -- do not attempt to add text if we have less than 10 pixels
			return
		end
		local target_value = (left_value + right_value) / 2
		local text = FormatNumberProp(target_value, display_scale, 2)
		local size, secondary_len = size_getter(text)
		if size > diff then
			return
		end
		secondary_axis_length = Max(secondary_axis_length, secondary_len)
		table.insert(text_list, text)
		local mid = left_pos + diff / 2
		table.insert(text_list, mid - size / 2)

		subdivide(left_value, target_value, left_pos, mid - size / 2)
		subdivide(target_value, right_value, mid + size / 2, right_pos)
	end
	local begin_text_size, secondary_len1 = size_getter(begin_text)
	local end_text_size, secondary_len2 = size_getter(end_text)
	secondary_axis_length = Max(secondary_axis_length, Max(secondary_len1, secondary_len2))

	table.insert(text_list, begin_text)
	table.insert(text_list, 0)
	subdivide(min_value, max_value, 0, available_space)
	table.insert(text_list, end_text)
	table.insert(text_list, available_space - end_text_size)

	return text_list, secondary_axis_length
end

function XCurveEditor:Layout(x, y, width, height)
	local ret = XWindow.Layout(self, x, y, width, height)
	self:GenerateTexts()
	return ret
end

function XCurveEditor:GenerateTexts()
	self.font_id = TextStyles.GedDefault:GetFontIdHeightBaseline(self.scale:y())
	self.text_space_required = point(0, 0)

	local _, font_height = UIL.MeasureText("AQj", self.font_id)
	local vertical_texts, min_width = FitScaleTexts(self.MinY, self.MaxY, self.DisplayScaleY, function(str)
		local width, height = UIL.MeasureText(str, self.font_id)
		return height, width
	end, self.content_box:sizey() - font_height, 10)
	local horizontal_texts = FitScaleTexts(0, self.MaxX, self.DisplayScaleX, function(str)
		local width, height = UIL.MeasureText(str, self.font_id)
		return width, height
	end, self.content_box:sizex() - min_width, 10)

	self.text_space_required = point(min_width, font_height)
	local graph_box = self:GetGraphBox()
	local content_box_min = self.content_box:min()

	self.scale_texts = {}
	for i = 2, #vertical_texts, 2 do
		local start_pos = point(graph_box:maxx(), graph_box:maxy() - vertical_texts[i] - font_height) - content_box_min
		vertical_texts[i] = sizebox(start_pos, point(UIL.MeasureText(vertical_texts[i - 1], self.font_id)))
	end
	for i = 2, #horizontal_texts, 2 do
		local start_pos = point(graph_box:minx() + horizontal_texts[i], graph_box:maxy()) - content_box_min
		horizontal_texts[i] = sizebox(start_pos, point(UIL.MeasureText(horizontal_texts[i - 1], self.font_id)))
	end

	table.iappend(vertical_texts, horizontal_texts)
	self.scale_texts = vertical_texts
end


local function min_point(a, b)
	return point(Min(a:x(), b:x()), Min(a:y(), b:y()), Min(a:z(), b:z()))
end
local function max_point(a, b)
	return point(Max(a:x(), b:x()), Max(a:y(), b:y()), Max(a:z(), b:z()))
end
function XCurveEditor:MovePoint(index, pos)
	local z = pos:z()
	assert(z and type(z) == "number")
	local points = self.points
	assert(index >= 1 and index <= self.ControlPoints and index <= #points)

	local old_pos = points[index]
	local min_pos = self:GetRangeMin()
	local max_pos = self:GetRangeMax()

	if self.FixedX or index == 1 or index == #points then
		min_pos = min_pos:SetX(old_pos:x())
		max_pos = max_pos:SetX(old_pos:x())
	end

	if not self.PushPointsOnMove then
		if index > 1 then
			min_pos = max_point(min_pos, points[index - 1])
		end
		if index < #point then
			max_pos = min_point(max_pos, points[index + 1])
		end
	end

	pos = point((pos:x() + self.SnapX / 2) / self.SnapX * self.SnapX,
				(pos:y() + self.SnapY / 2) / self.SnapY * self.SnapY,
				(pos:z() + self.SnapY / 2) / self.SnapY * self.SnapY)

	pos = min_point(max_point(pos, min_pos), max_pos)
	points[index] = pos

	if self.PushPointsOnMove and not self.FixedX then
		for i = 1, index - 1 do
			if points[i]:x() > pos:x() then
				points[i] = points[i]:SetX(pos:x())
			end
		end
		for i = index + 1, #points do
			if points[i]:x() < pos:x() then
				points[i] = points[i]:SetX(pos:x())
			end
		end
	end

	if self.OnCurveChanged and old_pos ~= pos then
		self.OnCurveChanged(self)
		self:Invalidate()
	end

	return pos
end


function XCurveEditor:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.capture_handle = self.hover_handle
		self:SetFocus()
		self.desktop:SetMouseCapture(self)
		self:OnMousePos(pt)
		return "break"
	end
end

function XCurveEditor:OnSetRollover(rollover)
	XControl.OnSetRollover(self, rollover)
	if not rollover then
		self.hover_handle = false
		self:Invalidate()
	end
end

function XCurveEditor:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.capture_handle = false
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		self:Invalidate()
		return "break"
	end
end

function XCurveEditor:GetHoveredHandle(pt)
	local handles = self.point_handles
	local best_handle = -1
	local best_dist = 999999
	for i, handle in ipairs(handles) do
		local dist = handle:HoverScore(self:TransformPoint(handle:GetPos()), pt)
		if dist < best_dist then
			best_handle = handle
			best_dist = dist
		end
	end

	local max_dist = ScaleXY(self.scale, self.ControlPointMaxDist)
	if best_dist < max_dist * max_dist then
		return best_handle
	end
	return false
end

function XCurveEditor:OnMousePos(pt)
	local old_hover = self.hover_handle
	self.hover_handle = self:GetHoveredHandle(pt)
	if old_hover ~= self.hover_handle then
		self:Invalidate()
	end
	if self.desktop:GetMouseCapture() ~= self then 
		self.capture_handle = false
		return "break"
	end
	if not self.capture_handle then
		return "break"
	end
	if self.ReadOnly then 
		return "break"
	end
	local content_box = self:GetGraphBox()
	local pos = self:GetRangeMin() + MulDivRoundPoint(point(pt:x() - content_box:minx(), content_box:maxy() - pt:y()), self:GetRange(), content_box:size())
	self.capture_handle:SetPos(pos)
	return "break"
end

local function RoundUp(x, alignment)
	if x % alignment == 0 then return x end
	return (x / alignment) * alignment + alignment
end

function XCurveEditor:DrawGrid()
	local range = self:GetRange()
	local max_values = self:GetRangeMax()
	local min_values = self:GetRangeMin()
	
	if self.GridUnitX > 0 then
		for x = RoundUp(min_values:x(), self.GridUnitX), max_values:x(), self.GridUnitX do
			UIL.DrawLine(self:TransformPoint(point(x, min_values:y())), self:TransformPoint(point(x, max_values:y())), self.GridColor)
		end
	end
	if self.GridUnitY > 0 then
		for y = RoundUp(min_values:y(), self.GridUnitY), max_values:y(), self.GridUnitY do
			UIL.DrawLine(self:TransformPoint(point(min_values:x(), y)), self:TransformPoint(point(max_values:x(), y)), self.GridColor)
		end
	end
end

function XCurveEditor:DrawControlPoints()
	local graph_box = self:GetGraphBox()
	local base = point(graph_box:minx(), graph_box:maxy())
	local points = self.points
	local size = self:GetControlPointSize() / 2

	for idx = 1, #self.point_handles do
		local handle = self.point_handles[idx]
		local color = self.ControlPointColor
		if handle:IsCaptured() then
			color = self.ControlPointCaptureColor
		elseif handle:IsHovered() then
			color = self.ControlPointHoverColor
		end
		
		local pixel_pos = self:TransformPoint(handle:GetPos(true))
		handle:Draw(graph_box, base, size, color, pixel_pos)
	end
end

function XCurveEditor:DrawGraphBackground(graph_box, points)

end

function XCurveEditor:DrawScaleTexts()
	--display current value whiel dragging
	if self.capture_handle then
		local pos = self.capture_handle:GetPos()
		local graph_box = self:GetGraphBox()
		
		local x_pos_text = FormatNumberProp(pos:x(), self.DisplayScaleX, 2)
		local x_pos_text_size = point(UIL.MeasureText(x_pos_text, self.font_id))
		local y_pos_text = FormatNumberProp(pos:y(), self.DisplayScaleY, 2)
		local y_pos_text_size = point(UIL.MeasureText(y_pos_text, self.font_id))
		local pixel_pos = self:TransformPoint(pos)
		
		local draw_text_x = Min(Max(pixel_pos:x() - x_pos_text_size:x() / 2, 0), graph_box:maxx() - x_pos_text_size:x())
		UIL.StretchText(x_pos_text, sizebox(point(draw_text_x, graph_box:maxy()), x_pos_text_size), self.font_id, self.CurveColor)
		local draw_text_y = Min(Max(pixel_pos:y() - x_pos_text_size:y() / 2, 0), graph_box:maxy() - x_pos_text_size:y())
		UIL.StretchText(y_pos_text, sizebox(point(graph_box:maxx(), draw_text_y), y_pos_text_size), self.font_id, self.CurveColor)
		return
	end

	local content_box_min = self.content_box:min()
	-- draw static texts. Cached and recalcualted only when needed as we might need to do more complex logic to decide out what to render and where
	local texts = self.scale_texts
	if not texts then
		self:GenerateTexts()
		texts = self.scale_texts
	end
	if texts then
		local StretchText = UIL.StretchText
		for i = 1, #texts, 2 do
			StretchText(texts[i], Offset(texts[i + 1], content_box_min), self.font_id, self.CurveColor)
		end
	end
end

local function DrawCurveWithPoints(smooth, points, color)
	if smooth then
		local step = 3
		local last_pt = points[1]
		for i = 1, #points - 1 do
			local left_pt_prev = points[i - 1] or points[i]
			local left_pt = points[i]
			local right_pt = points[i + 1]
			local diff_x = right_pt:x() - left_pt:x()
			local right_pt_next = points[i + 2] or points[i + 1]
			for x = left_pt:x() + step, right_pt:x(), step do
				--TODO: Use some other sample func
				local pt = CatmullRomSpline(left_pt_prev, left_pt, right_pt, right_pt_next, MulDivRound(x - left_pt:x(), 1000, diff_x ), 1000)
				pt = pt:SetX(x)
				UIL.DrawLine(last_pt, pt, color)
				last_pt = pt
			end
		end
	else
		local last_pt = points[1]
		for i = 2, #points do
			local pt = points[i]
			UIL.DrawLine(last_pt, pt, color)
			last_pt = pt
		end
	end
end
function XCurveEditor:DrawCurve()
	assert(self.points[1]:z())
	local graph = self:GetGraphBox()
	local points = {}
	for key, value in ipairs(self.points) do
		points[key] = self:TransformPoint(value)
	end
	DrawCurveWithPoints(self.Smooth, points, self.CurveColor)
	if self.MinMaxRangeMode then
		points = {}
		for key, value in ipairs(self.points) do
			points[key] = self:TransformPoint(point(value:x(), value:z()))
		end
		DrawCurveWithPoints(self.Smooth, points, self.CurveColor)
	end

	UIL.DrawLine(point(graph:maxx(), graph:miny()), graph:max(), self.CurveColor)
	UIL.DrawLine(point(graph:minx(), graph:maxy()), graph:max(), self.CurveColor)
end

function XCurveEditor:DrawContent()
	local graph_box = self:GetGraphBox()
	self:DrawGraphBackground(graph_box, self.points)
	self:DrawGrid()
	self:DrawCurve()
	self:DrawControlPoints()

	self:DrawScaleTexts()
end

function XCurveEditor:ValidatePoints()
	for i = 1, #self.points do
		local pt = self.points[i]
		self.points[i] = max_point(min_point(pt, self:GetRangeMax()), self:GetRangeMin())
	end
	self.points[1] = self.points[1]:SetX(self.MinX)
	self.points[#self.points] = self.points[#self.points]:SetX(self.MaxX)
end

------------ XCurveEditorHandle -------------
-- Spec of movable UI elements in the graph

DefineClass.XCurveEditorHandle = {
	__parents = {"PropertyObject"},

	type = false,
	point_idx = false,
	curve_editor = false,
	box = false,
	parent = false,
}

function XCurveEditorHandle:SetPos(pt)
	local old_pt = self.curve_editor.points[self.point_idx]
	local height = (old_pt:z() - old_pt:y()) / 2
	local new_point = point(pt:x(), pt:y() - height, pt:y() + height)

	self.curve_editor:MovePoint(self.point_idx, new_point)
	return self:GetPos("refetch")
end

function XCurveEditorHandle:GetPos(refetch)
	local pt = self.curve_editor.points[self.point_idx]
	return point(pt:x(), (pt:y() + pt:z()) / 2)
end

function XCurveEditorHandle:GetBox()
	local old_pt = self.curve_editor.points[self.point_idx]
	if self.curve_editor.MinMaxRangeMode then
		local height = (old_pt:z() - old_pt:y())
		local height_in_pixels = MulDivRound(height, self.curve_editor:GetGraphBox():sizey(), self.curve_editor:GetRange():y())
		local half_control_point_width = self.curve_editor:GetControlPointSize():x() / 4
		local pixel_pos = self.curve_editor:TransformPoint(old_pt)
		self.box = box(point(pixel_pos:x() - half_control_point_width, pixel_pos:y() - height_in_pixels),
					   point(pixel_pos:x() + half_control_point_width, pixel_pos:y()))
	else
		local half_control_point_width = self.curve_editor:GetControlPointSize():x() / 2
		local pixel_pos = self.curve_editor:TransformPoint(old_pt)
		self.box = box(point(pixel_pos:x() - half_control_point_width, pixel_pos:y() - half_control_point_width),
					   point(pixel_pos:x() + half_control_point_width, pixel_pos:y() + half_control_point_width))
	end
	return self.box
end

function XCurveEditorHandle:HoverScore(self_pt, mouse_pt)
	if terminal.IsKeyPressed(const.vkShift) then
		return 1000000
	end

	local is = self:GetBox():Intersect(box(mouse_pt - point(10, 10), mouse_pt + point(10, 10)))
	if is ~= const.irOutside then
		return 0
	end
	
	return mouse_pt:Dist2(self_pt)
end

function XCurveEditorHandle:Draw(graph_box, base, size, color, pixel_pos)
	UIL.DrawSolidRect(self:GetBox(), color)
end

DefineClass.XCurveEditorMinHandle = {
	__parents = {"XCurveEditorHandle"},
}

function XCurveEditorMinHandle:SetPos(pt)
	local old_pt = self.curve_editor.points[self.point_idx]
	local new_pt = point(pt:x(), Min(pt:y(), old_pt:z()), old_pt:z())

	self.curve_editor:MovePoint(self.point_idx, new_pt)
	return self:GetPos("refetch")
end

function XCurveEditorHandle:IsCaptured()
	local capture = self.curve_editor.capture_handle
	local current = self
	while current do
		if capture == current then return true end
		current = current.parent
	end
	return false
end

function XCurveEditorHandle:IsHovered()
	local capture = self.curve_editor.hover_handle
	local current = self
	while current do
		if capture == current then return true end
		current = current.parent
	end
	return false
end

function XCurveEditorMinHandle:GetPos(refetch)
	local pt = self.curve_editor.points[self.point_idx]
	return point(pt:x(), pt:y())
end


function XCurveEditorMinHandle:HoverScore(self_pt, mouse_pt)
	return mouse_pt:Dist2(self_pt)
end

function XCurveEditorMinHandle:Draw(graph_box, base, size, color, pixel_pos)
	UIL.DrawSolidRect(box(pixel_pos - size, pixel_pos + size), color)
end


DefineClass.XCurveEditorMaxHandle = {
	__parents = {"XCurveEditorHandle"},
}

function XCurveEditorMaxHandle:SetPos(pt)
	local old_pt = self.curve_editor.points[self.point_idx]
	local new_pt = point(pt:x(), old_pt:y(), Max(pt:y(), old_pt:y()))

	self.curve_editor:MovePoint(self.point_idx, new_pt)
	return self:GetPos("refetch")
end

function XCurveEditorMaxHandle:GetPos(refetch)
	local pt = self.curve_editor.points[self.point_idx]
	return point(pt:x(), pt:z())
end


function XCurveEditorMaxHandle:HoverScore(self_pt, mouse_pt)
	return mouse_pt:Dist2(self_pt)
end

function XCurveEditorMaxHandle:Draw(graph_box, base, size, color, pixel_pos)
	UIL.DrawSolidRect(box(pixel_pos - size, pixel_pos + size), color)
end


DefineClass.TestPicker = {
	__parents = {"PropertyObject"},
	properties = {
		{id = "test1", editor = "packedcurve", default = PackCurveParams(point(0, 127000), point(40000, 0), point(80000, 255000), point(255000, 0)),}
	}
}
