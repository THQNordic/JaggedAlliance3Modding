DefineClass.ScaleGizmo = {
	__parents = { "XEditorGizmo" },
	
	HasLocalCSSetting = false,
	HasSnapSetting = false,
	
	Title = "Scale gizmo (R)",
	Description = false,
	ActionSortKey = "3",
	ActionIcon = "CommonAssets/UI/Editor/Tools/ScaleGizmo.tga",
	ActionShortcut = "R",
	UndoOpName = "Scaled %d object(s)",

	side_mesh_a = pstr(""),
	side_mesh_b = pstr(""),
	side_mesh_c = pstr(""),
	
	b_over_a = false,
	b_over_b = false,
	b_over_c = false,
	
	scale = 100,
	thickness = 100,
	opacity = 255,
	sensitivity = 100,
	
	operation_started = false,
	initial_scales = false,
	text = false,
	scale_text = "",
	init_pos = false,
	init_mouse_pos = false,
	group_scale = false,
}

function ScaleGizmo:Done()
	self:DeleteText()
end

function ScaleGizmo:DeleteText()
	if self.text then
		self.text:delete()
		self.text = nil
		self.scale_text = ""
	end
end

function ScaleGizmo:CheckStartOperation(pt)
	return #editor.GetSel() > 0 and self:IntersectRay(camera.GetEye(), ScreenToGame(pt))
end

function ScaleGizmo:StartOperation(pt)
	self.text = XTemplateSpawn("XFloatingText")
	self.text:SetTextStyle("GizmoText")
	self.text:AddDynamicPosModifier({id = "attached_ui", target = self:GetPos()})
	self.text.TextColor = RGB(255, 255, 255)
	self.text.ShadowType = "outline"
	self.text.ShadowSize = 1
	self.text.ShadowColor = RGB(64, 64, 64)
	self.text.Translate = false
	self.init_pos = self:GetPos()
	self.init_mouse_pos = terminal.GetMousePos()
	self.initial_scales = {}
	for _, obj in ipairs(editor.GetSel()) do
		self.initial_scales[obj] = { scale = obj:GetScale(), offset = obj:GetVisualPos() - self.init_pos }
	end
	self.group_scale = terminal.IsKeyPressed(const.vkAlt)
	self.operation_started = true
end

function ScaleGizmo:PerformOperation(pt)
	local screenHeight = UIL.GetScreenSize():y()
	local mouseY = 4096.0 * (terminal.GetMousePos():y() - screenHeight / 2) / screenHeight
	local initY = 4096.0 * (self.init_mouse_pos:y() - screenHeight / 2) / screenHeight
	local scale
	if mouseY < initY then
		scale = 100 * (mouseY + 4096) / (initY + 4096) + 250  * (initY - mouseY) / (initY + 4096)
	else
		scale = 100 * (4096 - mouseY) / (4096 - initY) + 10  * (mouseY - initY) / (4096 - initY)
	end
	scale = 100 + MulDivRound(scale - 100, self.sensitivity, 100)
	self:SetScaleClamped(scale)
	
	for obj, data in pairs(self.initial_scales) do
		obj:SetScaleClamped(MulDivRound(data.scale, scale, 100))
		if self.group_scale then
			XEditorSetPosAxisAngle(obj, self.init_pos + data.offset * scale / 100)
		end
	end
	
	local objs = table.keys(self.initial_scales)
	self.scale_text = #objs == 1 and
		string.format("%.2f", objs[1]:GetScale() / 100.0) or
		((scale >= 100 and "+" or "-") .. string.format("%d%%", abs(scale - 100)))
	Msg("EditorCallback", "EditorCallbackScale", objs)
end

function ScaleGizmo:EndOperation()
	self:DeleteText()
	self:SetScale(100)
	self.init_pos = false
	self.init_mouse_pos = false
	self.initial_scales = false
	self.group_scale = false
	self.operation_started = false
end

function ScaleGizmo:RenderGizmo()
	local FloorPtA = MulDivRound(point(0, 4096, 0), self.scale * 25, 40960)
	local FloorPtB = MulDivRound(point(-3547, -2048, 0), self.scale * 25, 40960)
	local FloorPtC = MulDivRound(point(3547, -2048, 0), self.scale * 25, 40960)
	local UpperPt = MulDivRound(point(0, 0, 5900), self.scale * 25, 40960)
	local PyramidSize = FloorPtA:Dist(FloorPtB)
	
	self.side_mesh_a = self:RenderPlane(nil, UpperPt, FloorPtB, FloorPtC)
	self.side_mesh_b = self:RenderPlane(nil, FloorPtA, UpperPt, FloorPtC)
	self.side_mesh_c = self:RenderPlane(nil, FloorPtA, UpperPt, FloorPtB)
	
	if self.text then
		self.text:SetText(self.scale_text)
	end
	
	local vpstr = pstr("")
	vpstr = self:RenderCylinder(vpstr, PyramidSize, FloorPtA, 90, FloorPtB)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, FloorPtB, 90, FloorPtC)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, FloorPtC, 90, FloorPtA)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, Cross(FloorPtA, axis_z), 35, FloorPtA)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, Cross(FloorPtB, axis_z), 35, FloorPtB)
	vpstr = self:RenderCylinder(vpstr, PyramidSize, Cross(FloorPtC, axis_z), 35, FloorPtC)
	
	if self.b_over_a then vpstr = self:RenderPlane(vpstr, UpperPt, FloorPtB, FloorPtC)
	elseif self.b_over_b then vpstr = self:RenderPlane(vpstr, FloorPtA, UpperPt, FloorPtC)
	elseif self.b_over_c then vpstr = self:RenderPlane(vpstr, FloorPtA, UpperPt, FloorPtB) end
	return vpstr
end

function ScaleGizmo:ChangeScale()
	local eye = camera.GetEye()
	local dir = self:GetVisualPos()
	local ray = dir - eye
	local cameraDistanceSquared = ray:x() * ray:x() + ray:y() * ray:y() + ray:z() * ray:z()
	local cameraDistance = 0
	if cameraDistanceSquared >= 0 then cameraDistance = sqrt(cameraDistanceSquared) end
	self.scale = cameraDistance / 20 * self.scale / 100
end

function ScaleGizmo:Render()
	local obj = not XEditorIsContextMenuOpen() and selo()
	if obj then
		self:SetPos(CenterOfMasses(editor.GetSel()))
		self:ChangeScale()
		self:SetMesh(self:RenderGizmo())
	else self:SetMesh(pstr("")) end
end

function ScaleGizmo:CursorIntersection(mouse_pos)
	if self.b_over_a or self.b_over_b or self.b_over_c then
		local pos = self:GetVisualPos()
		local planeB = pos + axis_z
		local planeC = pos + axis_x
		local pt1 = camera.GetEye()
		local pt2 = ScreenToGame(mouse_pos)
		local intersection = IntersectRayPlane(pt1, pt2, pos, planeB, planeC)
		return ProjectPointOnLine(pos, pos + axis_z, intersection)
	end
end

function ScaleGizmo:IntersectRay(pt1, pt2)
	self.b_over_a = false
	self.b_over_b = false
	self.b_over_c = false
	
	local overA, lenA = IntersectRayMesh(self, pt1, pt2, self.side_mesh_a)
	local overB, lenB = IntersectRayMesh(self, pt1, pt2, self.side_mesh_b)
	local overC, lenC = IntersectRayMesh(self, pt1, pt2, self.side_mesh_c)
	
	if not (overA or overB or overC) then return end
	
	if lenA and lenB then
		if lenA < lenB then self.b_over_a = overA
		else self.b_over_b = overB end
	elseif lenA and lenC then
		if lenA < lenC then self.b_over_a = overA
		else self.b_over_c = overC end
	elseif lenB and lenC then
		if lenB < lenC then self.b_over_b = overB
		else self.b_over_c = overC end
	elseif lenA then self.b_over_a = overA
	elseif lenB then self.b_over_b = overB
	elseif lenC then self.b_over_c = overC end
	
	return self.b_over_a or self.b_over_b or self.b_over_c
end

function ScaleGizmo:RenderPlane(vpstr, ptA, ptB, ptC)
	vpstr = vpstr or pstr("")
	vpstr:AppendVertex(ptA, RGBA(255, 255, 0, MulDivRound(200, self.opacity, 255)))
	vpstr:AppendVertex(ptB)
	vpstr:AppendVertex(ptC)
	return vpstr
end

function ScaleGizmo:RenderCylinder(vpstr, height, axis, angle, offset)
	vpstr = vpstr or pstr("")
	local center = point(0, 0, 0)
	local radius = 0.10 * self.scale * self.thickness / 100
	local color = RGBA(0, 192, 192, self.opacity)
	return AppendConeVertices(vpstr, center, point(0, 0, height), radius, radius, axis, angle, color, offset)
end