DefineClass.XDragAndDropControl = {
	__parents = { "XContextControl" },
	
	properties = {
		{ category = "Interaction", id = "ClickToDrag", editor = "bool", default = false, help = "By default dragging starts when the window is clicked and dragged. With this option dragging will begin on click instead." },
		{ category = "Interaction", id = "ClickToDrop", editor = "bool", default = false, help = "By default dragging stops when the button is let go. With this option dragging will stop on a second click instead." },
		{ category = "Interaction", id = "NavigateScrollArea", editor = "bool", default = true, help = "Use scroll area, scroll with scrollbars and mouse wheel while draging" },
	},

	MouseCursor = "CommonAssets/UI/HandCursor.tga",
	drag_win = false,
	drag_target = false,
	drag_button = false,
	pt_pressed = false,
	drag_origin = false,
	dist_tostart_drag = 7, -- Unscaled pixels
	ChildrenHandleMouse = false,
}

if FirstLoad then
	DragSource = false
	DragScrollbar = false
end

-- Drag callbacks

function XDragAndDropControl:OnDragStart(pt, button)
end

function XDragAndDropControl:OnDragNewTarget(target, drag_win, drop_res, pt)
end

function XDragAndDropControl:OnDragDrop(target, drag_win, drop_res, pt)
end

function XDragAndDropControl:OnDragEnded(drag_win, last_target, drag_res)
end

-- Drop callbacks

function XDragAndDropControl:IsDropTarget(drag_win, pt, drag_source_win)
end

function XDragAndDropControl:OnDrop(drag_win, pt, drag_source_win)
end

function XDragAndDropControl:OnDropEnter(drag_win, pt, drag_source_win)
end

function XDragAndDropControl:OnDropLeave(drag_win)
end

-- Drag functions

function XDragAndDropControl:StartDrag(drag_win, pt)
	self.drag_win = drag_win
	DragSource = self
	drag_win:AddDynamicPosModifier{
		id = "Drag",
		target = Platform.console and "gamepad" or "mouse",
	}
	local winRelativePt = point(drag_win.box:minx() - pt:x(), drag_win.box:miny() - pt:y())
	drag_win:AddInterpolation{
		id = "Move",
		type = const.intRect,
		duration = 0,
		originalRect = drag_win.box,
		-- target rect is relative to the mouse position in this case.
		targetRect = box(winRelativePt:x(), winRelativePt:y(), drag_win.box:sizex() + winRelativePt:x(), drag_win.box:sizey() + winRelativePt:y()),
	}
	drag_win:SetDock("ignore")
	drag_win:SetParent(self.desktop)
	drag_win.DrawOnTop = true
	self:UpdateDrag(drag_win, pt)
	self.desktop:SetMouseCapture(self)
end

function XDragAndDropControl:InternalDragStart(pt)
	if self.drag_win then
		self:StopDrag()
	end
	local drag_win = self:OnDragStart(pt, self.drag_button)

	if not drag_win then
		return
	end
	self:StartDrag(drag_win, pt)
	self.pt_pressed = false
	return "break"
end

function XDragAndDropControl:InternalDragStop(pt)
	local drag_win = self.drag_win
	self:UpdateDrag(drag_win, pt)
	local target = self.drag_target
	local drop_res = target and target:OnDrop(drag_win, pt, self)
	self:OnDragDrop(target, drag_win, drop_res, pt)
	self:StopDrag(drop_res)
end

function XDragAndDropControl:StopDrag(drag_res)
	local drag_win = self.drag_win
	if drag_win then
		local last_target = self.drag_target
		self:UpdateDropTarget(nil, drag_win)
		self:OnDragEnded(drag_win, last_target, drag_res)
		drag_win:RemoveModifier("Drag")
		drag_win:RemoveModifier("Move")
	end
	DragSource = false
	self.drag_win = nil
	self.drag_target = nil
	self.desktop:SetMouseCapture()
end

function XDragAndDropControl:UpdateDrag(drag_win, pt)
	local target = self:GetDropTarget(drag_win, pt)
	self:UpdateDropTarget(target, drag_win, pt)
end

function XDragAndDropControl:UpdateDropTarget(target, drag_win, pt)
	if (target or false) ~= self.drag_target then
		if self.drag_target then
			self.drag_target:OnDropLeave(drag_win, pt)
		end
		local drop_res
		if target then
			drop_res = target:OnDropEnter(drag_win, pt, self)
		end
		self.drag_target = target or nil
		-- !!! update mouse cursor
		self:OnDragNewTarget(target, drag_win, drop_res, pt)
	end
end

function XDragAndDropControl:OnTargetDragWnd(drag_win, pt)	
	return self
end

function XDragAndDropControl:GetDropTarget(drag_win, pt)
	local target = self.desktop.modal_window:GetMouseTarget(pt)
	if target == drag_win then
		target = self:OnTargetDragWnd(drag_win, pt)	
	end
	while target and not target:IsDropTarget(drag_win, pt, self) do
		target = target.parent
	end
	return target
end

-- XWindow functions

function XDragAndDropControl:OnMouseButtonDown(pt, button)
	if not self.enabled then
		return "break"
	end
	if self.drag_win then
		if self.NavigateScrollArea then
			-- simulate scrollbar mouse capture (it is captured by drag_win) by saving it in DragScrollbar and calling its mouse functions
			local target = self.desktop.modal_window:GetMouseTarget(pt)
			if target and IsKindOf(target,"XScrollControl") then
				DragScrollbar = target
				target:StartScroll(pt)
				target:OnMousePos(pt)
			end
		end
		if self.ClickToDrop and button == self.drag_button then
			self:InternalDragStop(pt)
		end
		return "break"
	end
	
	self.pt_pressed = pt
	self.drag_button = button
	if self.ClickToDrag then
		return self:InternalDragStart(pt)
	end
end

function XDragAndDropControl:OnMouseButtonUp(pt, button)
	if not self.enabled then return "break" end
	if self.pt_pressed and self.drag_button == button then
		self.pt_pressed = false
		self.drag_button = false
		return "break"
	end

	local drag_win = self.drag_win
	if drag_win and DragScrollbar then
		DragScrollbar:OnMousePos(pt)
		DragScrollbar = false
	end	
	if not drag_win and self.drag_button ~= button then
		return "break"
	end
	if not self.ClickToDrop then
		self:InternalDragStop(pt)
		return "break"
	end
end

function XDragAndDropControl:OnMousePos(pt)
	if not self.enabled then return "break" end
	local scaledDistance = ScaleXY(self.scale, self.dist_tostart_drag)
	if self.pt_pressed and pt:Dist2D(self.pt_pressed)>=scaledDistance  then
		self:InternalDragStart(self.pt_pressed)
		return "break"
   end
	local drag_win = self.drag_win
	if drag_win then
		self:UpdateDrag(drag_win, pt)
		if DragScrollbar then
			DragScrollbar:OnMousePos(pt)
		end
		return "break"
	end
end

function XDragAndDropControl:OnMouseWheelForward(pt)
	if self.NavigateScrollArea and self.drag_win then
		local target = self.desktop.modal_window:GetMouseTarget(pt)
		local wnd = GetParentOfKind(target,"XScrollArea")
		if wnd then
			wnd:OnMouseWheelForward()
			return "break"
		end	
	end
end

function XDragAndDropControl:OnMouseWheelBack(pt)
	if self.NavigateScrollArea and self.drag_win then
		local target = self.desktop.modal_window:GetMouseTarget(pt)
		local wnd = GetParentOfKind(target,"XScrollArea")
		if wnd then
			wnd:OnMouseWheelBack()
			return "break"
		end	
	end
end

function XDragAndDropControl:OnCaptureLost()
	if self.drag_win then
		self:StopDrag("capture_lost")
	end
	self:Invalidate()
end
