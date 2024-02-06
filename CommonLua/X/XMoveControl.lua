DefineClass.XMoveControl = {
	__parents = { "XControl" },
	properties = {
		{ category = "Interaction", id = "ConstrainInParent", editor = "bool", default = false },
	},
	
	IdNode = false,
	Target = "node",
	HandleMouse = true,
	
	box_at_drag_start = false,
	pt_at_drag_start = false,
}

function XMoveControl:ApplyOffsetToTarget(target, offsetP)
	if target.Dock == "ignore" then
		local oldB = target.box
		target:SetBox(offsetP:x(), offsetP:y(), oldB:sizex(), oldB:sizey())
	else
		local unscale = MulDivRoundPoint(offsetP, point(1000, 1000), target.scale)
		target:SetMargins(box(unscale:x(), unscale:y(), 0, 0))
	end
end

function XMoveControl:OnMouseButtonDown(pt, button)
	if button == "L" then
		local target = self:ResolveId(self.Target) or GetParentOfKind(self, self.Target)
		local curB = target.box
		self:ApplyOffsetToTarget(target, curB:min())
		target:SetHAlign("left")
		target:SetVAlign("top")
		self:SetFocus()
		self.desktop:SetMouseCapture(self)
		self:OnDragStart()
		
		self.box_at_drag_start = target.box
		self.pt_at_drag_start = pt
		
		self:OnMousePos(pt)
	end
	return "break"
end

function XMoveControl:OnMousePos(pt)
	if self.desktop:GetMouseCapture() == self then
		local old_box = self.box_at_drag_start
		local diff = pt - self.pt_at_drag_start
		local newbox = sizebox(old_box:min() + diff, old_box:size())
		
		local target = self:ResolveId(self.Target) or GetParentOfKind(self, self.Target)
		if self.ConstrainInParent then
			local x1, y1, x2, y2 = target:GetEffectiveMargins()
			local margins = box(-x1, -y1, x2, y2)
			newbox = FitBoxInBox(newbox + margins, target.parent.box) - margins
		end

		self:OnDragDelta(newbox:min() - target.box:min())
		self:ApplyOffsetToTarget(target, newbox:min())
	end
	return "break"
end

function XMoveControl:OnMouseButtonUp(pt, button)
	if self.desktop:GetMouseCapture() == self and button == "L" then
		self:OnMousePos(pt)
		self.desktop:SetMouseCapture()
		self:OnDragEnd()
	end
	return "break"
end

function XMoveControl:OnDragStart()
end

function XMoveControl:OnDragEnd()
end

function XMoveControl:OnDragDelta(delta)
end
