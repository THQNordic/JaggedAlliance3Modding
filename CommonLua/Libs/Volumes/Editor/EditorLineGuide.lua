-- ExtrasGen based editor tools place fences, decals, etc. alongside these line guide helper objects
--
-- The line guide is aligned to the object's X axis, and the line normal direction - to the Z axis.
-- The line guide length is determined by the object's Scale; it is StandardLength long at normal scale.

DefineClass.EditorLineGuide = {
	__parents = { "Mesh", "CollideLuaObject", "EditorVisibleObject", "EditorCallbackObject" },
	
	StandardLength = 10 * guim, -- length at 100% scale
	NormalColor = RGB(240, 240, 240),
	HighlightColor = RGB(240, 230, 150),
	SelectedColor = RGB(240, 230, 40),
	
	collide_mesh = false,
	color = RGB(240, 240, 240),
}

-- rotates the object so that axis1 before the rotation matches axis2 after the rotation
local function rotate_to_match(obj, axis1, axis2)
	axis1, axis2 = SetLen(axis1, 4096), SetLen(axis2, 4096)
	local axis = Cross(axis1, axis2)
	if axis ~= point30 then
		obj:Rotate(axis, GetAngle(axis1, axis2))
	end
end

function EditorLineGuide:Set(pos1, pos2, normal)
	local pos = (pos1 + pos2) / 2
	self:SetPos(pos)
	self:SetOrientation(normal, 0)
	self:SetScale(MulDivRound((pos1 - pos2):Len(), 100, self.StandardLength))
	
	local axis1 = self:GetRelativePoint(axis_y) - self:GetPos()
	local axis2 = pos1 - self:GetPos()
	rotate_to_match(self, axis1, axis2)
	
	self:SetGameFlags(const.gofPermanent)
	self:UpdateVisuals()
end

function EditorLineGuide:GetLength()
	return MulDivRound(self.StandardLength, self:GetScale(), 100)
end

function EditorLineGuide:SetLength(length)
	self:SetScale(MulDivRound(length, 100, self.StandardLength))
	self:UpdateVisuals()
end

function EditorLineGuide:GetPos1()
	return self:GetRelativePoint(SetLen(axis_y, self.StandardLength / 2))
end

function EditorLineGuide:GetPos2()
	return self:GetRelativePoint(-SetLen(axis_y, self.StandardLength / 2))
end

function EditorLineGuide:GetNormal()
	return self:GetRelativePoint(axis_z) - self:GetVisualPos()
end

function EditorLineGuide:IsHorizontal()
	local tangent = self:GetRelativePoint(axis_y) - self:GetPos()
	local angle = GetAngle(tangent, axis_z) / 60
	return abs(angle) > 85
end

function EditorLineGuide:IsVertical()
	local tangent = self:GetRelativePoint(axis_y) - self:GetPos()
	local angle = GetAngle(tangent, axis_z) / 60
	return angle < 5 or angle > 175
end

function EditorLineGuide:UpdateVisuals()
	if self:GetScale() == 0 then
		self:SetMesh(pstr(""))
		return
	end

	local offset = SetLen(axis_y, self.StandardLength / 2)
	local arrowlen = MulDivRound(guim / 2, 100, self:GetScale())
	local normal = SetLen(axis_z, arrowlen)
	local along = SetLen(offset, arrowlen / 2)

	local str = pstr("")
	str:AppendVertex(offset, self.color)
	str:AppendVertex(-offset)
	str:AppendVertex(-along)
	str:AppendVertex(normal)
	str:AppendVertex(normal)
	str:AppendVertex(along)
	self:SetShader(ProceduralMeshShaders.mesh_linelist)
	self:SetMesh(str)
	
	if IsEditorActive() then
		self:SetEnumFlags(const.efVisible)
	end
end

EditorLineGuide.EditorCallbackPlaceCursor = EditorLineGuide.UpdateVisuals
EditorLineGuide.EditorCallbackPlace       = EditorLineGuide.UpdateVisuals
EditorLineGuide.EditorCallbackScale       = EditorLineGuide.UpdateVisuals
EditorLineGuide.EditorEnter               = EditorLineGuide.UpdateVisuals

function EditorLineGuide:GetBBox()
	local grow = guim / 4
	local length = self:GetLength()
	return GrowBox(box(0, -length / 2, 0, 0, length / 2, 0), grow, grow, grow)
end

function EditorLineGuide:TestRay(pos, dir)
	-- TODO: Refactor C++ code to expect intersection point to be returned
	return true
end


----- Selection and highlighting on hover

if FirstLoad then
	SelectedLineGuides = {}
end

function EditorLineGuide:SetHighlighted(highlight)
	local selected = table.find(SelectedLineGuides, self)
	self.color = selected  and self.SelectedColor  or
	             highlight and self.HighlightColor or self.NormalColor
	self:UpdateVisuals()
end

function OnMsg.EditorSelectionChanged(objects)
	local lines = table.ifilter(objects, function(idx, obj) return IsKindOf(obj, "EditorLineGuide") end )
	if #lines > 0 then
		for _, line in ipairs(table.subtraction(lines, SelectedLineGuides)) do
			line.color = line.SelectedColor
			line:UpdateVisuals()
		end
	end
	if #SelectedLineGuides > 0 then
		for _, line in ipairs(table.subtraction(SelectedLineGuides, lines)) do
			if IsValid(line) then
				line.color = nil
				line:UpdateVisuals()
			end
		end
	end
	SelectedLineGuides = lines
end
