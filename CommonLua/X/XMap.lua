local UIL = UIL
DefineClass.XMap = {
	__parents = { "XControl" },
	
	properties = {
		{ id = "UseCustomTime", editor = "bool", default = true, help = "If true, map object animations are done in Lua time, which is read from hr.UIL_CustomTime." },
		{ id = "map_size", name = "Map Size", editor = "point2d", default = point(1000, 1000) },
	},
	
	Clip = "self",
	UseClipBox = false, -- Disable UIL level clipping of children. Renderer will clip.
	MouseCursor = "UI/Cursors/Pda_Cursor.tga",
	
	translation_modId = 0,
	scale_modId = 1,

	scroll_start_pt = false,
	last_box = false,
	last_current_scale = false,
	last_scale = false,

	MouseWheelStep = 300,
	
	map_time_reference = false,
	real_time_reference = false,
	time_factor = 1000,
	
	max_zoom = 5000,
	
	rollover_padding = 15
}

function XMap:Init()
	local mapModifier = {
		id = "map-window",
		type = const.intParamRect,
		translateParam = self.translation_modId,
		scaleParam = self.scale_modId,
		interpolate_clip = false
	}
	-- Reset params
	UIL.SetParam(self.translation_modId, 0, 0, 0)
	UIL.SetParam(self.scale_modId, 1000, 1000, 0)
	self:AddInterpolation(mapModifier)
	self.map_time_reference = 0
	self.real_time_reference = GetPreciseTicks()
end

function XMap:ScrollMap(dx, dy, time, int)
	local transX, transY = UIL.GetParam(self.translation_modId, "end")
	return self:SetMapScroll(transX + dx, transY + dy, time, int)
end

function XMap:SetMapScroll(transX, transY, time, int)
	-- Clamp to map bounds.
	local scale = UIL.GetParam(self.scale_modId, "end")
	local win_box = self.box
	transX = Clamp(transX, - self.map_size:x() * scale / 1000 + win_box:maxx() + 1, win_box:minx())
	transY = Clamp(transY, - self.map_size:y() * scale / 1000 + win_box:maxy() + 1, win_box:miny())
	UIL.SetParam(self.translation_modId, transX, transY, time or 100, int)
end

function XMap:CenterScrollOn(x, y, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, "end")
	x = MulDivRound(x, scaleX, 1000)
	y = MulDivRound(y, scaleY, 1000)
	local winSize = self.box:size()
	self:SetMapScroll(winSize:x() / 2 - x, winSize:y() / 2 - y, time)
end

function XMap:ZoomMap(scale, time, origin_pos)
	return self:SetMapZoom(UIL.GetParam(self.scale_modId, "end") + scale, time, origin_pos)
end

function XMap:GetScaledMaxZoom()
	return MulDivRound(self.max_zoom, self.scale:x(), 1000)
end

function XMap:SetMapZoom(scale, time, origin_pos)
	local current_scale = UIL.GetParam(self.scale_modId)
	local min_scale = Max(1000 * self.box:sizex() / self.map_size:x(), 1000 * self.box:sizey() / self.map_size:y())
	scale = Clamp(scale, min_scale, self:GetScaledMaxZoom())
	time = time or 100
	UIL.SetParam(self.scale_modId, scale, scale, time)
	if origin_pos then
		local transX, transY = UIL.GetParam(self.translation_modId)
		local dx = origin_pos:x() - MulDivRound(origin_pos:x() - transX, scale, current_scale)
		local dy = origin_pos:y() - MulDivRound(origin_pos:y() - transY, scale, current_scale)
		self:SetMapScroll(dx, dy, time)
	end

	self.last_scale = current_scale
	self.current_scale = scale
	for _, win in ipairs(self) do
		if win.UpdateZoom then
			win:UpdateZoom(current_scale, scale, time)
		end
	end
end

function XMap:MapToScreenPt(pos, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return point(
		MulDivRound(pos:x(), scaleX, 1000) + transX,
		MulDivRound(pos:y(), scaleY, 1000) + transY
	)
end

function XMap:MapToScreenBox(b, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return box(
		MulDivRound(b:minx(), scaleX, 1000) + transX,
		MulDivRound(b:miny(), scaleY, 1000) + transY,
		MulDivRound(b:maxx(), scaleX, 1000) + transX,
		MulDivRound(b:maxy(), scaleY, 1000) + transY
	)
end

function XMap:ScreenToMapPt(pos, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return point(
		MulDivRound(pos:x() - transX, 1000, scaleX),
		MulDivRound(pos:y() - transY, 1000, scaleY)
	)
end

function XMap:ScreenToMapBox(b, time)
	local scaleX, scaleY = UIL.GetParam(self.scale_modId, time)
	local transX, transY = UIL.GetParam(self.translation_modId, time)

	return box(
		MulDivRound(b:minx() - transX, 1000, scaleX),
		MulDivRound(b:miny() - transY, 1000, scaleY),
		MulDivRound(b:maxx() - transX, 1000, scaleX),
		MulDivRound(b:maxy() - transY, 1000, scaleY)
	)
end

-- Don't move children as their positions are relative to the map.
function XMap:SetBox(x, y, width, height, move_children, ...)
	return XWindow.SetBox(self, x, y, width, height, "dont-move", ...)
end

function XMap:Layout(x, y, width, height)
	-- do not use a layout method to position the children, this is already done
end

function XMap:UpdateLayout()
	for _, win in ipairs(self) do
		if IsKindOf(win, "XMapWindow") then
			assert(win.Dock == "ignore") -- XMapWindow children should not participate in the "classical" layout, they are positioned here
			win:SetBox(win:GetMapSpaceBox())
		end
	end
	XControl.UpdateLayout(self)
end

function XMap:OnLayoutComplete()
	if self.last_box ~= self.box then
		-- Force a reclamp to the map area.
		self:ScrollMap(0, 0, 0)
		self:ZoomMap(0, 0)
		self.last_box = self.box
	else
		-- Children's UpdateZoom needs to be ran after layout.
		for _, win in ipairs(self) do
			if win.UpdateZoom then
				win:UpdateZoom(self.last_scale, self.current_scale, 0)
			end
		end
	end
end

function XMap:GetMouseTarget(pt)
	return XWindow.GetMouseTarget(self, self:ScreenToMapPt(pt))
end

function XMap:OnMouseButtonDown(pt, button)
	if button == "L" or button == "M" then
		self.scroll_start_pt = pt
		UIL.SetParam(self.translation_modId, UIL.GetParam(self.translation_modId))
		self:ScrollStart()
	end
end

function XMap:ScrollStart()

end

function XMap:ScrollStop()
	self.scroll_start_pt = false
end

function XMap:OnMouseButtonUp(pt, button)
	if button == "L" or button == "M" then
		-- Calculations here are based on what feels good, and are not scientific :P
		local prevPos = self:ScreenToMapPt(self.scroll_start_pt or pt)
		local currentPos = self:ScreenToMapPt(pt)
		local diff = (currentPos - prevPos)
		
		local diffClamped = Min(diff:Len(), 500)
		local inertiaPower = Lerp(500, 1, diffClamped, 500) -- boost inertia based on difference
		inertiaPower = inertiaPower / 100
		diff = diff * inertiaPower
		
		self:ScrollStop()
		self:ScrollMap(diff:x(), diff:y(), 500, "cubic out") -- interpolate based on distance
	end
end

function XMap:OnMousePos(pt)
	if self.scroll_start_pt then
		self:ScrollMap(pt:x() - self.scroll_start_pt:x(), pt:y() - self.scroll_start_pt:y(), 25)
		self.scroll_start_pt = pt
	end
end

function XMap:OnMouseWheelForward(pos)
	self:ScrollStop()
	self:ZoomMap(self.MouseWheelStep, 100, pos)
	return "break"
end

function XMap:OnMouseWheelBack(pos)
	self:ScrollStop()
	self:ZoomMap(-self.MouseWheelStep, 100, pos)
	return "break"
end

function XMap:OnMouseLeft()
	self:ScrollStop()
end

function XMap:OnCaptureLost()
	self:ScrollStop()
end

function XMap:SetTimeFactor(factor)
	local mapTime = self:GetMapTime()
	self.map_time_reference = mapTime
	self.real_time_reference = GetPreciseTicks()
	local oldFactor = factor
	self.time_factor = factor
	for _, win in ipairs(self) do
		if win.UpdateTimeFactor then
			win:UpdateTimeFactor(oldFactor, factor, mapTime)
		end
	end
end

function XMap:GetMapTime()
	local timeDifference = GetPreciseTicks() - self.real_time_reference
	return self.map_time_reference + MulDivRound(timeDifference, self.time_factor, 1000)
end


----- XMapWindow

DefineClass.XMapWindow = {
	__parents = { "XWindow", "XMapRolloverable" },
	Dock = "ignore",
	UseClipBox = false,
	ScaleWithMap = true,
	
	HAlign = "center",
	VAlign = "center",
	
	-- Position in map coordinates
	PosX = 0,
	PosY = 0,
	
	map = false
}

function XMapWindow:SetWidth(width)
	self.MinWidth = width
	self.MaxWidth = width
end

function XMapWindow:SetHeight(height)
	self.MinHeight = height
	self.MaxHeight = height
end

function XMapWindow:GetMapSpaceBox()
	local minX, minY = ScaleXY(self.scale, self.MinWidth, self.MinHeight)
	local maxX, maxY = ScaleXY(self.scale, self.MaxWidth, self.MaxHeight)
	
	local width = Clamp(self.measure_width, minX, maxX)
	local height = Clamp(self.measure_height, minY, maxY)
	
	local x, y = self.PosX, self.PosY
	local HAlign, VAlign = self.HAlign, self.VAlign
	if HAlign == "center" then
		x = x - width / 2
	elseif HAlign == "right" then
		x = x + width
	end
	
	if VAlign == "center" then
		y = y - height / 2
	elseif VAlign == "bottom" then
		y = y + height
	end
	
	return x, y, width, height
end

function XMapWindow:SetParent(...)
	XWindow.SetParent(self, ...)
	self.map = GetParentOfKind(self, "XMap")
end

function XMapWindow:UpdateMeasure(max_width, max_height)
	if self.map then
		max_width, max_height = self.map.map_size:xy()
	end
	return XWindow.UpdateMeasure(self, max_width, max_height)
end

function XMapWindow:PointInWindow(pt)
	local f = pt[self.Shape] or pt.InBox
	local box = self:GetInterpolatedBox(false, self.interaction_box)
	return f(pt, box)
end

local no_scale = point(1000, 1000)
function XMapWindow:SetOutsideScale(scale)
	-- scale is already taken into account in XMap
	return XWindow.SetOutsideScale(self, self.ScaleWithMap and no_scale or scale)
end

function XMapWindow:UpdateTimeFactor(oldFactor, newFactor, currentMapTime)
	for i, w in ipairs(self) do
		if w.UpdateTimeFactor then
			w:UpdateTimeFactor(oldFactor, newFactor, currentMapTime)
		end
	end
end

function XMapWindow:UpdateZoom(prevZoom, newZoom, time)
	if self.ScaleWithMap then
		self:RemoveModifier("reverse-zoom")
		return
	end
	
	self:AddInterpolation({
		id = "reverse-zoom",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = function(modifier, window)
			modifier.originalRect = sizebox(self.PosX, self.PosY, newZoom, newZoom)
			modifier.targetRect = sizebox(self.PosX, self.PosY, 1000, 1000)
		end,
		duration = 0
	})
end

-- Should be inherited by child windows of XMapWindows
DefineClass.XMapRolloverable = {
	__parents = { "XWindow", "XRollover" }
}

function XMapRolloverable:ResolveRolloverAnchor(context, pos)
	local b = #(self.RolloverAnchorId or "") > 0 and XRollover.ResolveRolloverAnchor(self, context, pos) or self:GetInterpolatedBox()
	local map = GetParentOfKind(self, "XMap")
	return map and map:MapToScreenBox(b, "end") or b
end

function XMapRolloverable:SetupMapSafeArea(wnd)
	local map = GetParentOfKind(self, "XMap")
	wnd.GetSafeAreaBox = function()
		local x, y, mx, my = map.box:xyxy()
		local rolloverPadX, rolloverPadY = ScaleXY(map.scale, map.rollover_padding, map.rollover_padding)
		return x + rolloverPadX, y + rolloverPadY, mx - rolloverPadX * 2, my - rolloverPadY * 2
	end
	wnd.GetAnchor = function(s)
		return self:ResolveRolloverAnchor(wnd.context)
	end
end

function XMapRolloverable:CreateRolloverWindow(gamepad, context, pos)
	context = SubContext(self:GetContext(), context)
	context.control = self
	context.anchor = self:ResolveRolloverAnchor(context, pos)
	context.gamepad = gamepad
	
	local win = XTemplateSpawn(self:GetRolloverTemplate(), nil, context)
	if not win then return false end
	self:SetupMapSafeArea(win)
	win:Open()
	local map = GetParentOfKind(self.parent, "XMap")
	if map then
		DelayedCall(0, function()
			map:InvalidateLayout()
		end)
	end
	return win
end


----- XMapObject

DefineClass.XMapObject = {
	__parents = { "XMapWindow" },
	HandleMouse = true,
	currentInterp = false,
	currentResize = false,
}

function XMapObject:GetPos()
	return point(self.PosX, self.PosY)
end

function XMapObject:GetVisualPos()
	local uiBox = self.layout_update and sizebox(self:GetMapSpaceBox()) or self.box
	local b = self:GetInterpolatedBox("move", uiBox)
	
	local x, y = b:minxyz()
	local width, height = uiBox:sizexyz()
	
	local HAlign, VAlign = self.HAlign, self.HAlign
	if HAlign == "center" then
		x = x + width / 2
	elseif HAlign == "right" then
		x = x - width
	end
	
	if VAlign == "center" then
		y = y + height / 2
	elseif VAlign == "bottom" then
		y = y - height
	end
	
	return point(x, y)
end

function XMapObject:GetVisualSize()
	local uiBox = self.layout_update and sizebox(self:GetMapSpaceBox()) or self.box
	local b = self:GetInterpolatedBox("resize", uiBox)
	return b:size()
end

function XMapObject:UpdateTimeFactor(...)
	if self.currentInterp then
		local interp = self.currentInterp
		local x, y, time = self:GetContinueInterpolationParams(interp.startX, interp.startY, interp.endX, interp.endY, interp.time, self:GetVisualPos())
		if x then self:SetPos(x, y, time) end
	end
	if self.currentResize then
		local interp = self.currentResize
		local x, y, time = self:GetContinueInterpolationParams(interp.startX, interp.startY, interp.endX, interp.endY, interp.time, self:GetVisualSize())
		if x then self:SetSize(x, y, time, interp.hOrigin, interp.vOrigin) end
	end
	
	XMapWindow.UpdateTimeFactor(self, ...)
end

function GetContinueInterpolationParams(startX, startY, endX, endY, totalTime, currentXY)
	-- Inverse lerp to find where along the path the object is
	local start = point(startX, startY)
	local diff = point(endX, endY) - start
	local passed = currentXY - start
	local passedDDiff = Dot(passed, diff)
	local percentPassed = passedDDiff ~= 0 and MulDivRound(passedDDiff, 1000, Dot(diff, diff)) or 0

	-- Find time left (in real time)
	local timeLeft = totalTime - MulDivRound(totalTime, percentPassed, 1000)
	if timeLeft <= 0 then
		return false
	end
	
	return endX, endY, timeLeft
end

function XMapObject:GetContinueInterpolationParams(...)
	return GetContinueInterpolationParams(...)
end

function XMapObject:SetPos(posX, posY, time)
	if not time or time == 0 then
		if self:RemoveModifier("move") then
			Msg(self)
		end
		self.currentInterp = false
		if self.PosX == posX and self.PosY == posY then return end
		self.PosX = posX
		self.PosY = posY
		self:InvalidateLayout()
		return
	end

	if self:FindModifier("move") then
		-- Find where we've interpolated to and apply that as the current pos.
		local visualPos = self:GetVisualPos()
		self.PosX, self.PosY = visualPos:xy()
	end

	self.currentInterp = { startX = self.PosX, startY = self.PosY, endX = posX, endY = posY, time = time }
	local map = self.map
	if map then
		if map.time_factor == 0 then
			time = 0
		else
			time = MulDivRound(time, 1000, map.time_factor)
		end
	end

	local diffX = self.PosX - posX
	local diffY = self.PosY - posY
	self.PosX = posX
	self.PosY = posY
	self:InvalidateLayout()

	self:AddInterpolation({
		id = "move",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = XMapObjectInterpolationOnLayoutComplete,
		originalRect = sizebox(0, 0, 1000, 1000),
		targetRect = sizebox(diffX, diffY, 1000, 1000),
		duration = time,
		autoremove = time ~= 0,
		on_complete = function()
			if time == 0 then return end -- Frozen time
			self.currentInterp = false
			Msg(self)
		end,
		flags = map.UseCustomTime and bor(const.intfInverse, const.intfUILCustomTime) or const.intfInverse,
		no_invalidate_on_remove = true
	}, 1)
end

local function lGetResizeOrigins(hOrigin, vOrigin, width, height, startWidth, startHeight)
	local posX, posY = 0, 0
	if hOrigin == "right" then
		posX = startWidth - width
	end
	if vOrigin == "bottom" then
		posY = startHeight - height
	end
	return posX, posY
end

function XMapObject:SetSize(width, height, time, hOrigin, vOrigin)
	if not time or time == 0 then
		self:RemoveModifier("resize")
		self.currentResize = false
		
		local posX, posY = lGetResizeOrigins(hOrigin, vOrigin, width, height, self.MaxWidth, self.MaxHeight)
		self.PosX = self.PosX + posX
		self.PosY = self.PosY + posY
		
		self:SetWidth(width)
		self:SetHeight(height)
		
		self:InvalidateLayout()
		self:InvalidateMeasure()
		return
	end

	if self:FindModifier("resize") then
		local visualSize = self:GetVisualSize()
		local vwidth, vheight = visualSize:xy()
	
		-- Calculate position offset
		local current = self.currentResize
		local posX, posY = lGetResizeOrigins(current.hOrigin, current.vOrigin, vwidth, vheight, current.startX, current.startY)
		self.PosX = self.PosX + posX
		self.PosY = self.PosY + posY
		self:SetWidth(vwidth)
		self:SetHeight(vheight)
		self:RemoveModifier("resize")
		self:InvalidateMeasure()
		self:InvalidateLayout()
	end

	self.currentResize = {
		startX = self.MaxWidth,
		startY = self.MaxHeight,
		endX = width,
		endY = height,
		time = time,
		hOrigin = hOrigin,
		vOrigin = vOrigin
	}
	local map = self.map
	if map then
		if map.time_factor == 0 then
			time = 0
		else
			time = MulDivRound(time, 1000, map.time_factor)
		end
	end
	
	if time == 0 then
		return
	end

--[[	if time == 0 then
		local visSize = self:GetVisualSize()
		width = visSize:x()
		height = visSize:y()
	end]]
	
	local posX, posY = lGetResizeOrigins(hOrigin, vOrigin, width, height, self.MaxWidth, self.MaxHeight)
	self:AddInterpolation{
		id = "resize",
		type = const.intRect,
		interpolate_clip = false,
		OnLayoutComplete = XMapObjectInterpolationOnLayoutComplete,
		originalRect = sizebox(0, 0, self.MaxWidth, self.MaxHeight),
		targetRect = sizebox(posX, posY, width, height),
		duration = time,
		autoremove = time ~= 0,
		on_complete = function()
			if time == 0 then return end -- Frozen time
			self.currentResize = false
			self.PosX = self.PosX + posX
			self.PosY = self.PosY + posY
			self:SetWidth(width)
			self:SetHeight(height)
			self:InvalidateMeasure()
			self:InvalidateLayout()
		end,
		flags = map.UseCustomTime and const.intfUILCustomTime,
	}

	self:InvalidateLayout()
	self:InvalidateMeasure()
end

function XMapObjectInterpolationOnLayoutComplete(modifier, window)
	local ogRect = modifier.unoffsetOgRect or modifier.originalRect
	local tarRect = modifier.unoffsetTarRect or modifier.targetRect

	if not modifier.unoffsetOgRect then
		modifier.unoffsetOgRect = ogRect
		modifier.unoffsetTarRect = tarRect
	end

	modifier.originalRect = Offset(ogRect, window.box:min())
	modifier.targetRect = Offset(tarRect, window.box:min())
end


----- Test

if FirstLoad then
winTest = false
end

function XMap:DrawContent()
	-- Draw debug checkerboard
	local colorOne = RGB(255, 255, 255)
	local colorTwo = RGB(0, 0, 0)

	for y = 0, self.map_size:y(), 100 do
		for x = 0, self.map_size:x(), 100 do
			local color = (x / 100 + y / 100) % 2 == 0 and colorTwo or colorOne
			UIL.DrawSolidRect(sizebox(x, y, 100, 100), color)
		end
	end
end

function TestXMap()
	if winTest then
		winTest:Close()
		winTest = false
	end

	winTest = XTemplateSpawn("XWindow")
	winTest:SetMinWidth(1200)
	winTest:SetMinHeight(800)
	winTest:SetMaxWidth(1200)
	winTest:SetMaxHeight(800)
	winTest:SetHAlign("center")
	winTest:SetVAlign("center")
	winTest:SetId("idTest")

	local map = XTemplateSpawn("XMap", winTest)
	rawset(map, "test_obj", false)
	map.UseCustomTime = false

	map.OnMouseButtonUp = function(self, pt, button)
		if button == "R" then
			local map_pos = self:ScreenToMapPt(pt)
			if self.test_obj then
				self.test_obj:SetPos(map_pos:x(), map_pos:y(), 300)
			else
				self.test_obj = AddTestObjectToMap(map_pos:xy())
			end
		end
		return XMap.OnMouseButtonUp(self, pt, button)
	end

	winTest:Open()
end

function AddTestObjectToMap(posX, posY, map)
	map = map or winTest and winTest[1]
	if not map then return end
	
	local obj = XTemplateSpawn("XMapObject", map)
	obj:SetBackground(RGB(44, 88, 151))
	obj.PosX = posX
	obj.PosY = posY
	obj:SetWidth(30)
	obj:SetHeight(60)

	obj:Open()
	return obj
end

--]]