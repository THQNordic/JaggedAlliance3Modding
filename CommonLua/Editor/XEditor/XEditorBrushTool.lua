----- XEditorBrushTool
--
-- Implements the following functionality:
--  1. Calls StartDraw, Draw, EndDraw, passing brush position in world coordinates
--  2. Supports horizontal/vertical snapping when holding Shift
--  3. Supports drawing a brush cursor

DefineClass.XEditorBrushTool = {
	__parents = { "XEditorTool" },
	properties = {
		{ id = "Size", editor = "number", default = 30 * guim, scale = "m", min = const.HeightTileSize, max = 300 * guim, step = guim / 10,
		  slider = true, persisted_setting = true, auto_select_all = true, sort_order = -1, exponent = 3, },
	},
	
	UsesCodeRenderables = true,
	
	first_pos = false,
	last_pos = false,
	snap_axis = 0,
	invalid_box = false,
	
	cursor_mesh = false,
	cursor_circles = 2,
	cursor_max_tiles = const.SlabSizeZ and (const.MaxTerrainHeight / const.SlabSizeZ) or 100,
	cursor_tile_size = const.SlabSizeX,
	cursor_verts = 100,
	cursor_default_flags = const.mfOffsetByTerrainCursor + const.mfTerrainDistorted + const.mfWorldSpace,
}

function XEditorBrushTool:Init()
	DelayedCall(0, self.CreateCursor, self)
end

function XEditorBrushTool:Done()
	if self.last_pos then -- destroyed while drawing
		self:OnMouseButtonUp()
	end
	self:DestroyCursor()
end


----- Drawing

function XEditorBrushTool:GetWorldMousePos()
	return GetTerrainCursor():SetInvalidZ()
end

function XEditorBrushTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.snap_axis = 0
		self.first_pos = self:GetWorldMousePos()
		self.last_pos = self.first_pos
		self.invalid_box = editor.GetSegmentBoundingBox(self.last_pos, self.last_pos, self:GetAffectedRadius(), self:IsCursorSquare())
		self:StartDraw(self.last_pos)
		self:Draw(self.last_pos, self.last_pos)
		self.desktop:SetMouseCapture(self)
		ForceHideMouseCursor("XEditorBrushTool")
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

function XEditorBrushTool:GetWorldPos()
	local pos = self:GetWorldMousePos()
	if terminal.IsKeyPressed(const.vkShift) then
		pos = self:SnapPosToAxis(pos)
	end
	return pos
end

function XEditorBrushTool:OnMousePos(pt, button)
	if self.last_pos then
		local pos = self:GetWorldPos()
		self.invalid_box:InplaceExtend(editor.GetSegmentBoundingBox(self.last_pos, pos, self:GetAffectedRadius(), self:IsCursorSquare()))
		self:Draw(self.last_pos, pos)
		self.last_pos = pos
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

function XEditorBrushTool:OnMouseButtonUp(pt, button)
	if self.last_pos then
		self.desktop:SetMouseCapture() -- calls OnCaptureLost below
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end

function XEditorBrushTool:OnCaptureLost()
	local pos = self:GetWorldPos()
	self.invalid_box:InplaceExtend(editor.GetSegmentBoundingBox(self.last_pos, pos, self:GetAffectedRadius(), self:IsCursorSquare()))
	self:EndDraw(self.last_pos, pos, self.invalid_box)
	UnforceHideMouseCursor("XEditorBrushTool")
	self.last_pos = false
end

function XEditorBrushTool:SnapPosToAxis(pos)
	local x0, y0 = self.first_pos:xy()
	local x1, y1 = pos:xy()
	if self.snap_axis == 0 then
		local dx, dy = abs(x1 - x0), abs(y1 - y0)
		if dx > guim and dy < guim then
			self.snap_axis = 1
		elseif dy > guim and dx < guim then
			self.snap_axis = 2
		elseif dx > guim and dy > guim then
			self.snap_axis = dx > dy and 1 or 2
		end
	end
	if self.snap_axis == 1 then
		return pos:SetY(y0)
	elseif self.snap_axis == 2 then
		return pos:SetX(x0)
	end
	return pos
end


----- Shortcuts 

function XEditorBrushTool:OnShortcut(shortcut, source, ...)
	local key = string.gsub(shortcut, "^Shift%-", "") -- ignore Shift, use it to decrease step size
	local divisor = terminal.IsKeyPressed(const.vkShift) and 10 or 1
	if shortcut == "Shift-MouseWheelFwd" then
		self:SetSize(self:GetSize() + (self:IsCursorSquare() and const.SlabSizeX or guim * (self:GetSize() < 10 * guim and 1 or 5)))
		return "break"
	elseif shortcut == "Shift-MouseWheelBack" then
		self:SetSize(self:GetSize() - (self:IsCursorSquare() and const.SlabSizeX or guim * (self:GetSize() <= 10 * guim and 1 or 5)))
		return "break"
	elseif key == "]" then
		self:SetSize(self:GetSize() + (self:IsCursorSquare() and const.SlabSizeX or guim / divisor))
		return "break"
	elseif key == "[" then
		self:SetSize(self:GetSize() - (self:IsCursorSquare() and const.SlabSizeX or guim / divisor))
		return "break"
	end
	
	-- don't change tool modes, allow undo, etc. while in the process of dragging
	if terminal.desktop:GetMouseCapture() and shortcut ~= "Ctrl-F1" and shortcut ~= "Escape" then
		return "break"
	end
	
	return XEditorTool.OnShortcut(self, shortcut, source, ...)
end


----- Cursor

function XEditorBrushTool:CreateCursor()
	if self.cursor_mesh then
		self:DestroyCursor()
	end

	local cursor = Mesh:new()
	cursor:SetShader(ProceduralMeshShaders.mesh_linelist)
	self.cursor_mesh = cursor
	self:UpdateCursor()
	
	self:CreateThread("UpdateCursorThread", function()
		while true do
			self:UpdateCursor()
			Sleep(100)
		end
	end)
	self:OnCursorCreate(self.cursor_mesh)
end

function XEditorBrushTool:OnCursorCreate(cursor_mesh)
end

function XEditorBrushTool:CreateCircleCursor()
	local vpstr = pstr("")
	
	local cursor_verts = self.cursor_verts
	local inner_rad, outer_rad = self:GetCursorRadius()

	vpstr = AppendCircleVertices(nil, nil, inner_rad, self:GetCursorColor())
	vpstr = AppendCircleVertices(vpstr, nil, outer_rad, self:GetCursorColor())
	return vpstr
end

function XEditorBrushTool:CreateSquareCursor()
	local vpstr = pstr("")
	
	local inner_rad, outer_rad = self:GetCursorRadius()
	local tilesize = self.cursor_tile_size
	local tiles = outer_rad * 2 / tilesize
	local offset_x, offset_y, offset_xy = point(tilesize, 0, 0), point(0, tilesize, 0), point(tilesize, tilesize, 0)
	for x = 0, tiles - 1 do
		for y = 0, tiles - 1 do
			local start_pt = point(x * tilesize - outer_rad, y * tilesize - outer_rad, 0)
			vpstr:AppendVertex(start_pt, self:GetCursorColor(), 0)
			vpstr:AppendVertex(start_pt + offset_x)
			vpstr:AppendVertex(start_pt)
			vpstr:AppendVertex(start_pt + offset_y)
			if x == tiles - 1 then
				vpstr:AppendVertex(start_pt + offset_x)
				vpstr:AppendVertex(start_pt + offset_xy)
			end
			if y == tiles - 1 then
				vpstr:AppendVertex(start_pt + offset_y)
				vpstr:AppendVertex(start_pt + offset_xy)
			end
		end
	end
	
	return vpstr
end

function XEditorBrushTool:UpdateCursor()
	local v_pstr 
	if self:IsCursorSquare() then
		v_pstr = self:CreateSquareCursor()
	else
		v_pstr = self:CreateCircleCursor()
	end
	
	local strength = self:GetCursorHeight()
	if strength then
		v_pstr:AppendVertex(point(0, 0, 0))
		v_pstr:AppendVertex(point(0, 0, strength))
	end
	
	self.cursor_mesh:SetMeshFlags(self.cursor_default_flags + self:GetCursorExtraFlags())
	self.cursor_mesh:SetMesh(v_pstr)
	self.cursor_mesh:SetPos(GetTerrainCursor())
	self.cursor_mesh:SetGameFlags(const.gofAlwaysRenderable)
end

function XEditorBrushTool:DestroyCursor()
	if not self.cursor_mesh then return end
	self:DeleteThread("UpdateCursorThread")
	DoneObject(self.cursor_mesh)
	self.cursor_mesh = nil
end


----- Overrides

function XEditorBrushTool:StartDraw(pt)
end

function XEditorBrushTool:Draw(pt1, pt2)
end

function XEditorBrushTool:EndDraw(pt1, pt2)
end

function XEditorBrushTool:GetCursorRadius()
	return 5 * guim, 5 * guim
end

function XEditorBrushTool:GetAffectedRadius()
	local _, outer_radius = self:GetCursorRadius()
	return outer_radius
end

function XEditorBrushTool:GetCursorColor()
	return RGB(255, 255, 255)
end

function XEditorBrushTool:GetCursorHeight()
end

function XEditorBrushTool:IsCursorSquare()
	return false
end

function XEditorBrushTool:GetCursorExtraFlags()
	return 0
end
