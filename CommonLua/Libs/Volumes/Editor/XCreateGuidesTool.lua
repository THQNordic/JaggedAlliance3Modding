if not const.SlabSizeX then return end

local offset = point(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ) / 2
local retrace = point(const.SlabSizeX, const.SlabSizeY, 0) / 2
local function snap_to_voxel_grid(pt)
	return SnapToVoxel(pt + offset) - retrace
end

DefineClass.XCreateGuidesTool = {
	__parents = { "XEditorTool" },
	properties = {
		persisted_setting = true,
		{ id = "Snapping", editor = "bool", default = true, },
		{ id = "Vertical", editor = "bool", default = true, },
		{ id = "Prg", name = "Apply Prg", editor = "choice", default = "", 
			items = function(self)
				return PresetsCombo("ExtrasGen", nil, "", function(prg)
					return prg.RequiresClass == "EditorLineGuide" and prg.RequiresGuideType == (self:GetVertical() and "Vertical" or "Horizontal")
				end)
			end,
		},
	},
	
	ToolTitle = "Create Guides",
	Description = {
		"(drag to place guide or guides)\n" ..
		"(<style GedHighlight>hold Ctrl</style> to disable snapping)",
	},
	UsesCodeRenderables = true,
	
	start_pos = false,
	guides = false,
	prg_applied = false,
	old_guides_hash = false,
}

function XCreateGuidesTool:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Vertical" then
		self:SetPrg("")
	end
end

function XCreateGuidesTool:Done()
	if self.start_pos then -- tool destroyed while dragging
		ResumePassEdits("XCreateGuidesTool")
		self:CreateGuides(0)
	end
end

function XCreateGuidesTool:CreateGuides(count)
	self.guides = self.guides or {}
	
	local guides = self.guides
	if count == #guides then return end
	
	for i = 1, Max(count, #guides) do
		if i <= count and not guides[i] then
			guides[i] = EditorLineGuide:new()
			guides[i]:SetOpacity(self:GetPrg() == "" and 100 or 0)
		elseif i > count and guides[i] then
			DoneObject(guides[i])
			guides[i] = nil
		end
	end
end

function XCreateGuidesTool:UpdateGuides(pt_min, pt_max)
	local x1, y1 = pt_min:xy()
	local x2, y2 = pt_max:xy()
	local z = Max(
		terrain.GetHeight(point(x1, y1)),
		terrain.GetHeight(point(x1, y2)),
		terrain.GetHeight(point(x2, y1)),
		terrain.GetHeight(point(x2, y2))
	)
	if x1 == x2 then
		local count = y1 == y2 and 0 or 1
		self:CreateGuides(count)
		if count == 0 then return end
		
		local pos, lookat = GetCamera()
		local dot = Dot(SetLen((lookat - pos):SetZ(0), 4096), axis_x)
		self.guides[1]:Set(point(x1, y1, z), point(x1, y2, z), dot > 0 and -axis_x or axis_x)
	elseif y1 == y2 then
		self:CreateGuides(1)
		
		local pos, lookat = GetCamera()
		local dot = Dot(SetLen((lookat - pos):SetZ(0), 4096), axis_y)
		self.guides[1]:Set(point(x1, y1, z), point(x2, y1, z), dot > 0 and -axis_y or axis_y)
	else
		self:CreateGuides(4)
		self.guides[1]:Set(point(x1, y1, z), point(x1, y2, z), -axis_x)
		self.guides[2]:Set(point(x2, y1, z), point(x2, y2, z),  axis_x)
		self.guides[3]:Set(point(x1, y1, z), point(x2, y1, z), -axis_y)
		self.guides[4]:Set(point(x1, y2, z), point(x2, y2, z),  axis_y)
	end
end

function XCreateGuidesTool:GetGuidesHash()
	local hash = 42
	for _, guide in ipairs(self.guides or empty_table) do
		hash = xxhash(hash, guide:GetPos1(), guide:GetPos2(), guide:GetNormal())
	end
	return hash
end	

function XCreateGuidesTool:ApplyPrg()
	local hash = self:GetGuidesHash()
	if self:GetPrg() ~= "" and hash ~= self.old_guides_hash and self.guides and #self.guides ~= 0 then
		if self.prg_applied then
			XEditorUndo:UndoRedo("undo")
		end
		
		-- create copies of the guides and apple the Prg to them (some Prgs change the guides)
		local guides = {}
		for _, guide in ipairs(self.guides) do
			local g = EditorLineGuide:new()
			g:Set(guide:GetPos1(), guide:GetPos2(), guide:GetNormal())
			guides[#guides + 1] = g
		end
		GenExtras(self:GetPrg(), guides)
		for _, guide in ipairs(guides) do
			DoneObject(guide)
		end
		
		self.old_guides_hash = hash
		self.prg_applied = true
	end
end

function XCreateGuidesTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.start_pos = GetTerrainCursor()
		self.snapping = self:GetSnapping() and not terminal.IsKeyPressed(const.vkControl)
		if self.snapping then
			self.start_pos = snap_to_voxel_grid(self.start_pos)
		end
		self.desktop:SetMouseCapture(self)
		SuspendPassEdits("XCreateGuidesTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

local function MinMaxPtXY(f, p1, p2)
	return point(f(p1:x(), p2:x()), f(p1:y(), p2:y()))
end

function XCreateGuidesTool:OnMousePos(pt, button)
	local start_pos = self.start_pos
	if start_pos then
		if self:GetVertical() then
			local eye, lookat = GetCamera()
			local cursor = ScreenToGame(pt)
			
			-- vertical plane parallel to screen
			local pt1, pt2, pt3 = start_pos, start_pos + axis_z, start_pos + SetLen(Cross(lookat - eye, axis_z), 4096)
			local intersection = IntersectRayPlane(eye, cursor, pt1, pt2, pt3)
			intersection = ProjectPointOnLine(pt1, pt2, intersection)
			intersection = self.snapping and snap_to_voxel_grid(intersection) or intersection
			if start_pos ~= intersection then
				local angle = CalcSignedAngleBetween2D(axis_x, eye - lookat)
				local axis = Rotate(axis_x, CardinalDirection(angle))
				if start_pos:Dist(intersection) > guim / 2 then
					self:CreateGuides(1)
					self.guides[1]:Set(start_pos, intersection, axis)
				end
			end
			self:ApplyPrg()
			return "break"
		end
		
		local pt_new = GetTerrainCursor()
		if self.snapping then
			pt_new = snap_to_voxel_grid(pt_new)
		else
			if abs(pt_new:x() - start_pos:x()) < guim / 2 then pt_new = pt_new:SetX(start_pos:x()) end
			if abs(pt_new:y() - start_pos:y()) < guim / 2 then pt_new = pt_new:SetY(start_pos:y()) end
		end
		local pt_min = MinMaxPtXY(Min, pt_new, start_pos)
		local pt_max = MinMaxPtXY(Max, pt_new, start_pos)
		self:UpdateGuides(pt_min, pt_max)
		self:ApplyPrg()
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

function XCreateGuidesTool:OnMouseButtonUp(pt, button)
	local start_pos = self.start_pos
	if start_pos then
		if self.prg_applied then
			self:CreateGuides(0)
		elseif self.guides and #self.guides > 1 then
			XEditorUndo:BeginOp{ name = "Created guides" }
			local collection = Collection.Create()
			for _, obj in ipairs(self.guides) do
				obj:SetCollection(collection)
			end
			editor.ChangeSelWithUndoRedo(self.guides)
			XEditorUndo:EndOp(table.iappend(self.guides, { collection }))
		end
		
		self.desktop:SetMouseCapture()
		self.start_pos = nil
		self.prg_applied = nil
		self.guides = nil
		ResumePassEdits("XCreateGuidesTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end
