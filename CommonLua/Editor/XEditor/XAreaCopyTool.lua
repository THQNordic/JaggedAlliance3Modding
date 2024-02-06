if FirstLoad then
	g_TerrainAreaMeshes = {}
	g_AreaUndoQueue = false -- a separate undo queue, active while the area copy tool is active
	LocalStorage.XAreaCopyTool = LocalStorage.XAreaCopyTool or {}
	AreaCopyBrushGrid = false
end

local snap_size = Max(const.SlabSizeX or 0, const.HeightTileSize, const.TypeTileSize)

local function SnapPt(pt)
	local x, y = pt:xy()
	return point(x / snap_size * snap_size, y / snap_size * snap_size)
end

DefineClass.XAreaCopyTool = {
	__parents = { "XEditorTool", "XMapGridAreaBrush" },
	properties = {
		{ id = "DrawingMode", name = "Drawing Mode", editor = "text_picker", name_on_top = true, 
			max_rows = 2, default = "Box areas", items = { "Box areas", "Brush" },
		},
		
		-- Overridden brush properties
		{ id = "Size", editor = "number", default = 3 * guim, scale = "m", min = const.HeightTileSize, 
			max = 300 * guim, step = guim / 10, slider = true, persisted_setting = true, auto_select_all = true, 
			sort_order = -1, exponent = 3, no_edit = function(self) return self.DrawingMode ~= "Brush" end
		},
		
		{	id = "TerrainDebugAlphaPerc", name = "Opacity", editor = "number",
			default = 50, min = 0, max = 100, slider = true, no_edit = function(self) return self.DrawingMode ~= "Brush" end
		},
		{	id = "WriteValue", name = "Value", editor = "texture_picker", default = 1,
			thumb_width = 101, thumb_height = 35, small_font = true, items = function(self) return self:GetGridPaletteItems() end,
			max_rows = 2, no_edit = function(self) return self.DrawingMode ~= "Brush" end
		},
	},
	
	ToolTitle = "Copy terrain & objects",
	ToolSection = "Misc",
	Description = { "Copies an entire area of a map.\n\nDrag to define selection areas, then\nuse <style GedHighlight>Ctrl-C</style> to copy and <style GedHighlight>Ctrl-V</style> twice to paste." },
	ActionIcon = "CommonAssets/UI/Editor/Tools/EnrichTerrain.tga",
	ActionShortcut = "O",
	ActionSortKey = "5",
	UsesCodeRenderables = true,
	
	GridName = "AreaCopyBrushGrid",
	GridTileSize = const.SlabSizeX or const.HeightTileSize,
	
	brush_area_boxes = false,
	
	old_undo = false,
	start_pos = false,
	operation = false,
	current_box = false,
	highlighted_objset = false,
	drag_area = false,
	drag_helper_id = false,
	
	filter_roofs = false,
	filter_floor = false,
}

function XAreaCopyTool:Init()
	-- make areas visible and highlight selected objects
	Collection.UnlockAll()
	for _, a in ipairs(self:GetAreas()) do
		a:SetVisible(true)
		a:Setbox(a.box) -- update according to current terrain height
	end

	-- set default roof visibility settings
	self.filter_floor = LocalStorage.FilteredCategories["HideFloor"]
	self.filter_roofs = LocalStorage.FilteredCategories["Roofs"]
	LocalStorage.FilteredCategories["HideFloor"] = 0
	LocalStorage.FilteredCategories["Roofs"] = true
	XEditorFilters:UpdateHiddenRoofsAndFloors()
	XEditorFilters:SuspendHighlights()
	
	-- highlight objects; this makes all non-highlighted objects have gofWhiteColored
	local objset = {}
	MapGet(true, function(obj) objset[obj] = true end)
	self.highlighted_objset = objset
	self:UpdateHighlights(true)
	
	-- replace undo queue
	self.old_undo = XEditorUndo
	g_AreaUndoQueue = g_AreaUndoQueue or XEditorUndoQueue:new()
	XEditorUndo = g_AreaUndoQueue
	XEditorUpdateToolbars()
	
	-- brush mode
	self.brush_area_boxes = {}
end

function XAreaCopyTool:Done()
	-- make areas invisible, remove highlights
	for _, a in ipairs(self:GetAreas()) do
		a:SetVisible(false)
	end
	MapGet(true, function(obj) obj:ClearGameFlags(const.gofWhiteColored) end)
	self.highlighted_objset = false
	
	-- restore filters
	LocalStorage.FilteredCategories["HideFloor"] = self.filter_floor
	LocalStorage.FilteredCategories["Roofs"] = self.filter_roofs
	XEditorFilters:UpdateHiddenRoofsAndFloors()
	XEditorFilters:ResumeHighlights()
	
	-- restore undo queue
	XEditorUndo = self.old_undo
	if GetDialog("XEditor") then
		XEditorUpdateToolbars()
	end
	
	-- free allocated grids
	if self.Grid then
		self.Grid:free()
	end
	
	-- delete brush areas
	for _, a in ipairs(self.brush_area_boxes) do
		a:delete()
	end
end

function OnMsg.OnMapPatchBegin()
	local editor_tool = XEditorGetCurrentTool()
	if IsKindOf(editor_tool, "XAreaCopyTool") then
		XEditorUndo = editor_tool.old_undo
	end
end

function OnMsg.OnMapPatchEnd()
	if IsKindOf(XEditorGetCurrentTool(), "XAreaCopyTool") then
		XEditorUndo = g_AreaUndoQueue
	end
end

function XAreaCopyTool:CreateBrushGrid()
	if self.Grid then
		return self.Grid
	end
	
	local map_data = mapdata or _G.mapdata
	local map_size = point(map_data.Width - 1, map_data.Height - 1) * const.HeightTileSize
	local width, height = (map_size / self.GridTileSize):xy()
	-- brush grid to be used by XMapGridAreaBrush
	self.Grid = NewHierarchicalGrid(width, height, 64, 1) -- patch_size = 64
	
	return self.Grid
end

function XAreaCopyTool:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "DrawingMode" then
		if self.DrawingMode == "Brush" then
			-- Hide previously created area meshes
			for _, a in ipairs(g_TerrainAreaMeshes) do
				a:SetVisible(false)
			end
			
			self.WriteValue = 1 -- select the "Copy Area" brush value
			
			-- Show debug overlay
			hr.TerrainDebugDraw = 1
			
			-- Create the brush cursor
			self:CreateCursor()
			
			return XMapGridAreaBrush.OnEditorSetProperty(prop_id, old_value, ged)
		elseif self.DrawingMode == "Box areas" then
			-- Show previously create area meshes
			for _, a in ipairs(g_TerrainAreaMeshes) do
				a:SetVisible(true)
			end
			
			-- Delete existing area boxes
			for _, a in ipairs(self.brush_area_boxes) do
				a:delete()
			end
			
			-- Hide debug overlay
			hr.TerrainDebugDraw = 0 
			
			-- Destroy the brush cursor
			self:DestroyCursor()
		end
	end
end

function XAreaCopyTool:GetGridPaletteItems()
	local white = "CommonAssets/System/white.dds"
	local items = {}
	
	table.insert(items, { text = "Blank", value = 0, image = white, color = RGB(0, 0, 0) })
	table.insert(items, { text = "Copy Area", value = 1, image = white, color = RGB(10, 10, 150) })
	return items
end

function XAreaCopyTool:GetPalette()
	local palette = {
		[0] = RGB(0, 0, 0),
		[1] = RGB(10, 10, 150)
	}
	return palette
end

function XAreaCopyTool:OnCursorCreate(cursor_mesh)
	-- Destroy the brush cursor if we're not in brush mode
	if self.DrawingMode ~= "Brush" then
		self:DestroyCursor()
	end
end

function XAreaCopyTool:GetAreas()
	local area_list
	if self.DrawingMode == "Box areas" then
		area_list = g_TerrainAreaMeshes
	elseif self.DrawingMode == "Brush" then
		area_list = self.brush_area_boxes
	end
	
	for i = #area_list, 1, -1 do
		local area = area_list[i]
		if not IsValid(area) or area.box:IsEmpty() then
			table.remove(area_list, i)
		end
	end
	return area_list
end

function XAreaCopyTool:UpdateBrushAreaBoxes()
	if self.DrawingMode ~= "Brush" then return end
	
	-- Delete existing area boxes
	for _, a in ipairs(self.brush_area_boxes) do
		a:delete()
	end

	-- Create areas on the non-zero boxes of the brush grid
	local non_zero_boxes = editor.GetNonZeroInvalidationBoxes(self.Grid)
	for idx, bx in ipairs(non_zero_boxes) do
		local area = XEditableTerrainAreaMesh:new()
		local no_mesh = self.DrawingMode == "Brush"
		area:Setbox(bx * self.GridTileSize, "force_setpos", no_mesh)
		self.brush_area_boxes[idx] = area
	end
	self:UpdateHighlights(true)
end

function CanSelectWithMaskGrid(obj)
	if not obj then return CanSelect(obj) end

	if obj and mask_grid and mask_grid_tile and obj:IsValidPos() then
		local pos = obj:GetPos()
		if mask_grid:get(pos / mask_grid_tile) then
			return CanSelect(obj)
		end
	end
	
	return false
end

function XAreaCopyTool:GetBrushObjectSelector()
	local CanSelectWithMaskGrid = function(obj)
		if not obj then return CanSelect(obj) end

		if obj and self.Grid and self.GridTileSize and obj:IsValidPos() then
			local pos = obj:GetPos()
			if self.Grid:get(pos / self.GridTileSize) > 0 then
				return CanSelect(obj)
			end
		end
		
		return false
	end
	
	return CanSelectWithMaskGrid
end

function XAreaCopyTool:GetObjects(box_list)
	local selector_fn = self.DrawingMode == "Brush" and self:GetBrushObjectSelector() or CanSelect
	local objset = {}
	for _, b in ipairs(box_list) do
		b = IsKindOf(b, "XTerrainAreaMesh") and b.box or b
		for _, obj in ipairs(MapGet(b, "attached", false, selector_fn)) do 
			objset[obj] = obj:GetGameFlags(const.gofPermanent) ~= 0 and not IsKindOf(obj, "XTerrainAreaMesh") or nil
		end
	end
	return XEditorPropagateParentAndChildObjects(table.keys(objset))
end

function XAreaCopyTool:UpdateHighlights(highlight)
	PauseInfiniteLoopDetection("XAreaCopyTool:UpdateHighlights")
	
	local new = highlight and self:GetObjects(self:GetAreas()) or empty_table
	local old_set = self.highlighted_objset or empty_table
	local new_set = {}
	for _, obj in ipairs(new) do
		if not old_set[obj] then
			obj:ClearHierarchyGameFlags(const.gofWhiteColored)
		else
			old_set[obj] = nil
		end
		new_set[obj] = true
	end
	for obj in pairs(old_set) do
		obj:SetHierarchyGameFlags(const.gofWhiteColored)
	end
	self.highlighted_objset = new_set
	
	ResumeInfiniteLoopDetection("XAreaCopyTool:UpdateHighlights")
end

function XAreaCopyTool:EndDraw(pt1, pt2, invalid_box)
	XMapGridAreaBrush.EndDraw(self, pt1, pt2, invalid_box)
	self:UpdateBrushAreaBoxes()	
end

function XAreaCopyTool:OnMouseButtonDown(pt, button)
	if self.DrawingMode == "Box areas" then
		if button == "L" then
			self.desktop:SetMouseCapture(self)
			self.start_pos = SnapPt(GetTerrainCursor())
			
			-- are we starting a drag to move/resize an area?
			for _, a in ipairs(self:GetAreas()) do
				local helper_id = a:UpdateHelpers(pt)
				if helper_id then
					self.operation = "movesize"
					self.drag_area = a
					self.drag_helper_id = helper_id
					
					XEditorUndo:BeginOp{ name = "Moves/sized area", objects = { self.drag_area } }
					self.drag_area:DragStart(self.drag_helper_id, self.start_pos)
					return "break"
				end
			end
			
			self.operation = "place"
			self.current_box = XEditableTerrainAreaMesh:new()
			g_TerrainAreaMeshes[#g_TerrainAreaMeshes + 1] = self.current_box
			return "break"
		end
		
		if button == "R" then
			for _, a in ipairs(self:GetAreas()) do
				a:delete()
			end
			self:UpdateHighlights(true)
			return "break"
		end
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnMouseButtonDown(self, pt, button)
	end
end

local function MinMaxPtXY(f, p1, p2)
	return point(f(p1:x(), p2:x()), f(p1:y(), p2:y()))
end

function XAreaCopyTool:OnMousePos(pt)
	if self.DrawingMode == "Box areas" then
		XEditorRemoveFocusFromToolbars()
		
		if self.operation == "place" then
			local pt1, pt2 = self.start_pos, SnapPt(GetTerrainCursor())
			local new_box = box(MinMaxPtXY(Min, pt1, pt2), MinMaxPtXY(Max, pt1, pt2) + point(snap_size, snap_size))
			local old_box = self.current_box.box
			local no_mesh = self.DrawingMode == "Brush"
			self.current_box:Setbox(new_box, "force_setpos", no_mesh)
			self:UpdateHighlights(true)
			return "break"
		end
		
		if self.operation == "movesize" then
			self.drag_area:DragMove(self.drag_helper_id, SnapPt(GetTerrainCursor()))
			self:UpdateHighlights(true)
			return "break"
		end
		
		local areas = self:GetAreas()
		for _, a in ipairs(areas) do
			a:UpdateHelpers(pt)
		end
		local hovered
		for _, a in ipairs(areas) do
			a:UpdateHover(hovered)
			hovered = hovered or a.hovered
		end
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnMousePos(self, pt)
	end
end

function XAreaCopyTool:OnMouseButtonUp(pt, button)
	if self.DrawingMode == "Box areas" then
		if self.operation then
			self.desktop:SetMouseCapture()
			return "break"
		end
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnMouseButtonUp(self, pt, button)
	end
end

function XAreaCopyTool:OnCaptureLost()
	if self.DrawingMode == "Box areas" then
		if self.operation == "place" then
			XEditorUndo:BeginOp{ name = "Added area" }
			XEditorUndo:EndOp{ self.current_box }
		end
		if self.operation == "movesize" then
			XEditorUndo:EndOp{ self.drag_area }
		end
		self.start_pos = nil
		self.operation = nil
		self.current_box = nil
		self.drag_area = nil
		self.drag_helper_id = nil
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnCaptureLost(self)
	end
end

function XAreaCopyTool:OnShortcut(shortcut, source, ...)
	-- don't change tool modes, allow undo, etc. while in the process of dragging
	if terminal.desktop:GetMouseCapture() and shortcut ~= "Ctrl-F1" and shortcut ~= "Escape" then
		return "break"
	end
	
	if shortcut == "Ctrl-C" then
		ExecuteWithStatusUI("Copying terrain & objects...", function() self:CopyToClipboard() end)
		return "break"
	end
	
	if self.DrawingMode == "Box areas" then
		if shortcut == "Delete" then
			for _, a in ipairs(self:GetAreas()) do
				if a.hovered then
					XEditorUndo:BeginOp{ name = "Deleted area", objects = { a } }
					a:delete()
					XEditorUndo:EndOp()
					self:UpdateHighlights(true)
					return "break"
				end
			end
		end
		return XEditorTool.OnShortcut(self, shortcut, source, ...)
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnShortcut(self, shortcut, source, ...)
	end
end

function XAreaCopyTool:OnKbdKeyDown(vkey)
	if self.DrawingMode == "Box areas" then
		return XEditorTool.OnKbdKeyDown(self, vkey)
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnKbdKeyDown(self, vkey)
	end
end

function XAreaCopyTool:OnKbdKeyUp(vkey)
	if self.DrawingMode == "Box areas" then
		return XEditorTool.OnKbdKeyUp(self, vkey)
	elseif self.DrawingMode == "Brush" then
		return XMapGridAreaBrush.OnKbdKeyUp(self, vkey)
	end
end

function XAreaCopyTool:CopyToClipboard()
	self:UpdateBrushAreaBoxes()

	local areas = self:GetAreas()
	if #areas == 0 then return end
	
	-- create XTerrainGridData for each area to capture all grids
	local area_datas = {}
	for _, a in ipairs(areas) do
		local data = XTerrainGridData:new()
		local mask = self.DrawingMode == "Brush" and self.Grid or nil
		data:CaptureData(a.box, mask, mask and self.GridTileSize or nil)
		area_datas[#area_datas + 1] = data
	end
	
	-- copy area data and objects to clipboard with a custom PasteTerrainAndObjects paste function
	local data = XEditorSerialize(area_datas)
	data.objs = XEditorSerialize(XEditorCollapseChildObjects(self:GetObjects(areas)))
	data.pivot = CenterPointOnBase(areas)
	data.paste_fn = "PasteTerrainAndObjects"
	data.mask_grid_tile_size = self.GridTileSize
	CopyToClipboard(XEditorToClipboardFormat(data))
	
	-- delete areas and select default editor tool
	XEditorUndo:BeginOp{ objects = table.copy(areas), name = "Copied terrain & objects" }
	for _, a in ipairs(areas) do
		a:delete()
	end
	for _, a in ipairs(area_datas) do
		a:delete()
	end
	XEditorUndo:EndOp()
	XEditorSetDefaultTool()
end


----- XTerrainAreaMesh

function OnMsg.PreSaveMap()  MapForEach("map", "XTerrainAreaMesh", function(obj) obj:ClearGameFlags(const.gofPermanent) end) end
function OnMsg.PostSaveMap() MapForEach("map", "XTerrainAreaMesh", function(obj) obj:  SetGameFlags(const.gofPermanent) end) end

DefineClass.XTerrainAreaMesh = {
	__parents = { "Mesh", "EditorCallbackObject" },
	properties = {
		{ id = "box", editor = "box" },
	},
	
	outer_color = RGB(255, 255, 255),
	inner_color = RGBA(255, 255, 255, 80),
	outer_border = 6 * guic,
	inner_border = 4 * guic,
	box = empty_box,
}

function XTerrainAreaMesh:Init()
	self:SetGameFlags(const.gofPermanent) -- so it can be copied by XEditorSerialize
	self:SetShader(ProceduralMeshShaders.default_mesh)
	self:SetDepthTest(true)
end

function XTerrainAreaMesh:GetPivot()
	local pivot = self.box:Center()
	return pivot:SetZ(self:GetHeight(pivot))
end

function XTerrainAreaMesh:GetHeight(pt)
	return terrain.GetHeight(pt)
end

function XTerrainAreaMesh:AddQuad(v_pstr, pivot, pt1, pt2, pt3, pt4, color)
	local offs = 30 * guic
	pt1 = (pt1 - pivot):SetZ(self:GetHeight(pt1) - pivot:z() + offs)
	pt2 = (pt2 - pivot):SetZ(self:GetHeight(pt2) - pivot:z() + offs)
	pt3 = (pt3 - pivot):SetZ(self:GetHeight(pt3) - pivot:z() + offs)
	pt4 = (pt4 - pivot):SetZ(self:GetHeight(pt4) - pivot:z() + offs)
	v_pstr:AppendVertex(pt1, color)
	v_pstr:AppendVertex(pt2)
	v_pstr:AppendVertex(pt3)
	v_pstr:AppendVertex(pt2)
	v_pstr:AppendVertex(pt3)
	v_pstr:AppendVertex(pt4)
end

function XTerrainAreaMesh:AddTriangle(v_pstr, pivot, pt1, pt2, pt3, color)
	local offs = 30 * guic
	pt1 = (pt1 - pivot):SetZ(self:GetHeight(pt1) - pivot:z() + offs)
	pt2 = (pt2 - pivot):SetZ(self:GetHeight(pt2) - pivot:z() + offs)
	pt3 = (pt3 - pivot):SetZ(self:GetHeight(pt3) - pivot:z() + offs)
	v_pstr:AppendVertex(pt1, color)
	v_pstr:AppendVertex(pt2)
	v_pstr:AppendVertex(pt3)
end

function XTerrainAreaMesh:Setbox(bbox, force_setpos, no_mesh)
	self.box = bbox
	
	if no_mesh then
		if force_setpos or self:GetPos() == InvalidPos() then
			self:SetPos(self:GetPivot())
		end
		return
	end
	
	-- for too large areas, we make the lines sparser for better performance
	-- 'n' below is the n in the statement "we will only draw every nth line"
	local treshold_size = snap_size * 32
	local n = Max(bbox:sizex(), bbox:sizey()) / treshold_size + 1
	local inner_border = self.inner_border + self.inner_border * (n - 1) / 2
	local outer_border = self.outer_border + self.outer_border * (n - 1) / 2
	
	-- generate mesh
	local step = snap_size
	local v_pstr = pstr("", 65536)
	local pivot = self:GetPivot()
	for x = bbox:minx(), bbox:maxx(), step do
		for y = bbox:miny(), bbox:maxy(), step do
			if x + step <= bbox:maxx() then
				local outer = y == bbox:miny() or y + step > bbox:maxy()
				if outer or (y - bbox:miny()) / step % n == 0 then
					local d = outer and outer_border or inner_border
					local pt1, pt2 = point(x, y - d), point(x + step, y - d)
					local pt3, pt4 = point(x, y + d), point(x + step, y + d)
					self:AddQuad(v_pstr, pivot, pt1, pt2, pt3, pt4, outer and self.outer_color or self.inner_color)
				end
			end
			if y + step <= bbox:maxy() then
				local outer = x == bbox:minx() or x + step > bbox:maxx()
				if outer or (x - bbox:minx()) / step % n == 0 then
					local d = outer and outer_border or inner_border
					local pt1, pt2 = point(x - d, y), point(x - d, y + step)
					local pt3, pt4 = point(x + d, y), point(x + d, y + step)
					self:AddQuad(v_pstr, pivot, pt1, pt2, pt3, pt4, outer and self.outer_color or self.inner_color)
				end
			end
		end
	end
	if force_setpos or self:GetPos() == InvalidPos() then
		self:SetPos(pivot)
	end
	self:SetMesh(v_pstr)
end

function XTerrainAreaMesh:Getbox(bbox)
	return self.box
end

-- handles updating the area tool when undo/redo places or deletes an area
local function UpdateAreas(self)
	if self then
		table.insert_unique(g_TerrainAreaMeshes, self)
	end
	if GetDialogMode("XEditor") == "XAreaCopyTool" then
		CreateRealTimeThread(function() XAreaCopyTool:UpdateHighlights(true) end)
	end
end

XTerrainAreaMesh.EditorCallbackPlace = UpdateAreas
XTerrainAreaMesh.EditorCallbackDelete = UpdateAreas
OnMsg.EditorFiltersChanged = UpdateAreas


----- XEditableTerrainAreaMesh

local helpers_data = {
	{ x = 0, y = 0, x1 =  true, y1 =  true, x2 = false, y2 = false, point(0, 0), point(3, 0), point(0, 3) },
	{ x = 1, y = 0, x1 = false, y1 =  true, x2 = false, y2 = false, point(-2, 0), point(2, 0), point(0, 2), stretch_x = true },
	{ x = 2, y = 0, x1 = false, y1 =  true, x2 =  true, y2 = false, point(-3, 0), point(0, 0), point(0, 3) },
	{ x = 0, y = 1, x1 =  true, y1 = false, x2 = false, y2 = false, point(0, -2), point(0, 2), point(2, 0), stretch_y = true },
	{ x = 1, y = 1, x1 =  true, y1 =  true, x2 =  true, y2 =  true, point(-3, 0), point(3, 0), point(0, 3), point(-3, 0), point(3, 0), point(0, -3) },
	{ x = 2, y = 1, x1 = false, y1 = false, x2 =  true, y2 = false, point(0, -2), point(0, 2), point(-2, 0), stretch_y = true },
	{ x = 0, y = 2, x1 =  true, y1 = false, x2 = false, y2 =  true, point(0, 0), point(3, 0), point(0, -3) },
	{ x = 1, y = 2, x1 = false, y1 = false, x2 = false, y2 =  true, point(-2, 0), point(2, 0), point(0, -2), stretch_x = true },
	{ x = 2, y = 2, x1 = false, y1 = false, x2 =  true, y2 =  true, point(-3, 0), point(0, 0), point(0, -3) },
}

DefineClass.XEditableTerrainAreaMesh = {
	__parents = { "XTerrainAreaMesh" },
	
	hover_color = RGBA(240, 230, 150, 100),
	helper_color = RGBA(255, 255, 255, 30),
	helper_size = 40 * guic,
	helpers = false,
	hovered = false,
	start_pt = false,
	start_box = false,
	last_delta = false,
}

function XEditableTerrainAreaMesh:Done()
	self:DoneHelpers()
end

function XEditableTerrainAreaMesh:DoneHelpers()
	for _, helper in ipairs(self.helpers) do
		helper:delete()
	end
end

function XEditableTerrainAreaMesh:SetVisible(value)
	for _, helper in ipairs(self.helpers) do
		helper:SetVisible(value)
	end
	XTerrainAreaMesh.SetVisible(self, value)
end

function XEditableTerrainAreaMesh:Setbox(bbox, force_setpos, no_mesh)
	XTerrainAreaMesh.Setbox(self, bbox, force_setpos, no_mesh)
	if no_mesh then
		return
	end
	self:UpdateHelpers()
end

function XEditableTerrainAreaMesh:UpdateHelpers(pt, active_idx)
	-- ray for checks whether helpers are under the mouse cursor
	local pt1, pt2
	if pt then
		pt1, pt2 = camera.GetEye(), ScreenToGame(pt)
	end
	
	-- scale up for larger areas
	local treshold_size = snap_size * 32
	local n = Max(self.box:sizex(), self.box:sizey()) / treshold_size + 1
	local helper_size = self.helper_size + self.helper_size * (n - 1) / 2
	if self.box:sizex() <= snap_size * 2 or self.box:sizey() <= snap_size * 2 then
		helper_size = helper_size / 2
	end
	
	local pivot = self:GetPivot()
	self.helpers = self.helpers or {}
	for idx, data in ipairs(helpers_data) do
		local active = idx == active_idx or pt and self.helpers[idx] and IntersectRayMesh(self, pt1, pt2, self.helpers[idx].vertices_pstr)
		active_idx = active_idx or active and idx
		
		local color = active and self.hover_color or self.helper_color
		local helper = self.helpers[idx] or Mesh:new()
		local v_pstr = pstr("", 64)
		helper:SetShader(ProceduralMeshShaders.default_mesh)
		helper:SetDepthTest(false)
		for t = 1, #data, 3 do
			local function trans(pt)
				if data.stretch_x then
					pt = pt:SetX(pt:x() * self.box:sizex() / (helper_size * 6))
				end
				if data.stretch_y then
					pt = pt:SetY(pt:y() * self.box:sizey() / (helper_size * 6))
				end
				return pt * helper_size + point(self.box:minx() + data.x * self.box:sizex() / 2, self.box:miny() + data.y * self.box:sizey() / 2)
			end
			self:AddTriangle(v_pstr, pivot, trans(data[t]), trans(data[t + 1]), trans(data[t + 2]), color)
		end
		helper:SetMesh(v_pstr)
		helper:SetPos(self:GetPos())
		self.helpers[idx] = helper
	end
	return active_idx
end

function XEditableTerrainAreaMesh:UpdateHover(unhover_only)
	local hovered = not unhover_only and GetTerrainCursor():InBox2D(self.box)
	if hovered ~= self.hovered then
		self.hovered = hovered
		self.outer_color = hovered and RGB(240, 220, 120) or nil
		XTerrainAreaMesh.Setbox(self, self.box)
	end
	return hovered
end

function XEditableTerrainAreaMesh:DragStart(idx, pt)
	self.start_pt = pt
	self.start_box = self.box
	self.last_delta = nil
end

function XEditableTerrainAreaMesh:DragMove(idx, pt)
	local data = helpers_data[idx]
	local x1, y1, x2, y2 = self.start_box:xyxy()
	local delta = pt - self.start_pt
	if delta ~= self.last_delta then
		if data.x1 then x1 = Min(x2 - snap_size, x1 + delta:x()) end
		if data.y1 then y1 = Min(y2 - snap_size, y1 + delta:y()) end
		if data.x2 then x2 = Max(x1 + snap_size, x2 + delta:x()) end
		if data.y2 then y2 = Max(y1 + snap_size, y2 + delta:y()) end
		self:Setbox(box(x1, y1, x2, y2), "force_setpos")
		self:UpdateHelpers(pt, idx)
		self.last_delta = delta
	end
end


----- XTerrainGridData

DefineClass.XTerrainGridData = {
	__parents = { "XTerrainAreaMesh", "AlignedObj" },
}

function XTerrainGridData:Done()
	for _, grid in ipairs(editor.GetGridNames()) do
		local data = rawget(self, grid .. "_grid")
		if data then
			data:free()
		end
		
		local mask = rawget(self, grid .. "_grid_mask")
		if mask then
			mask:free()
		end
	end
end

function XTerrainGridData:AlignObj(pos, angle)
	-- keep a full slab offset from the original position to make sure aligned objects
	-- being pasted won't be displaced relative to the terrain and other objects
	local pivot = self:GetPivot()
	local offs = (pos or self:GetPos()) - pivot
	if const.SlabSizeX then
		local x = offs:x() / const.SlabSizeX * const.SlabSizeX
		local y = offs:y() / const.SlabSizeY * const.SlabSizeY
		local z = offs:z() and (offs:z() + const.SlabSizeZ / 2) / const.SlabSizeZ * const.SlabSizeZ
		offs = point(x, y, z)
	end
	if XEditorSettings:GetSnapMode() == "BuildLevel" and offs:z() then
		local step = const.BuildLevelHeight
		offs = offs:SetZ((offs:z() + step / 2) / step * step)
	end
	self:SetPosAngle(pivot + offs, angle or self:GetAngle())
end

-- generated properties to persist all terrain grids
function XTerrainGridData:GetProperties()
	local props = table.copy(XTerrainAreaMesh:GetProperties())
	for _, grid in ipairs(editor.GetGridNames()) do
		props[#props + 1] = { id = grid .. "_grid", editor = "grid", default = false }
		props[#props + 1] = { id = grid .. "_grid_mask", editor = "grid", default = false }
	end
	return props
end

function XTerrainGridData:SetProperty(prop_id, value)
	if prop_id == "box" then
		self.box = value -- just store the value, as we need height_grid to update the mesh
		return
	end
	if prop_id:ends_with("_grid") then
		rawset(self, prop_id, value)
		return
	end
	PropertyObject.SetProperty(self, prop_id, value)
end

function XTerrainGridData:PostLoad(reason)
	self:Setbox(self.box) -- update the mesh after height_grid is restored
end

function XTerrainGridData:CaptureData(bbox, mask_grid, mask_grid_tile_size)
	for _, grid in ipairs(editor.GetGridNames()) do
		local copied_area, mask_area = editor.GetGrid(grid, bbox, nil, mask_grid or nil, mask_grid_tile_size or nil)
		rawset(self, grid .. "_grid", copied_area or false)
		rawset(self, grid .. "_grid_mask", mask_area)
	end
	self.box = bbox
end

function XTerrainGridData:RotateGrids()
	local angle = self:GetAngle() / 60
	if angle == 0 then return end

	local transform, transpose
	if angle == 90 then
		transform = function(x, y, w, h) return y, w - x end
		transpose = true
	elseif angle == 180 then
		transform = function(x, y, w, h) return w - x, h - y end
		transpose = false
	elseif angle == 270 then
		transform = function(x, y, w, h) return h - y, x end
		transpose = true
	end
	
	for _, grid in ipairs(editor.GetGridNames()) do
		local old = rawget(self, grid .. "_grid")
		if old then
			local new = old:clone()
			local sx, sy = old:size()
			if transpose then
				sx, sy = sy, sx
				new:resize(sx, sy)
			end
			local sx1, sy1 = sx - 1, sy - 1
			for x = 0, sx do
				for y = 0, sy do
					new:set(x, y, old:get(transform(x, y, sx1, sy1)))
				end
			end
			rawset(self, grid .. "_grid", new)
		end
	end
	
	if transpose then
		local b = self.box - self:GetPivot()
		b = box(b:miny(), b:minx(), b:maxy(), b:maxx())
		self.box = b + self:GetPivot()
	end
end

function XTerrainGridData:ApplyData(paste_grids, mask_grid_tile_size)
	local pos = self:GetPos()
	if not pos:IsValidZ() then
		pos = pos:SetTerrainZ()
	end
	local offset = pos - self:GetPivot()
	for _, grid in ipairs(editor.GetGridNames()) do
		if paste_grids[grid] then
			local data = rawget(self, grid .. "_grid")
			if data then
				local mask_grid = rawget(self, grid .. "_grid_mask")
				if grid == "height" then
					data = data:clone()
					-- Calculate Z offset for the terrain height grid
					local offset_z_scaled = offset:z() / const.TerrainHeightScale
					local sx, sy = data:size()
					for x = 0, sx do
						for y = 0, sy do
							-- If there's a mask, offset z only for tiles where the mask is 1
							if not mask_grid or mask_grid:get(x, y) ~= 0 then
								local new_z = data:get(x, y) + offset_z_scaled
								new_z = Clamp(new_z, 0, const.MaxTerrainHeight / const.TerrainHeightScale)
								data:set(x, y, new_z)
							end
						end
					end
					-- The mask slice for the height grid uses the height tile
					editor.SetGrid(grid, data, self.box + offset, mask_grid or nil, mask_grid and const.HeightTileSize or nil)
					data:free()
				else
					editor.SetGrid(grid, data, self.box + offset, mask_grid or nil, mask_grid and mask_grid_tile_size or nil)
				end
			end
		end
	end
end

function XTerrainGridData:GetHeight(pt)
	pt = (pt - self.box:min() + point(const.HeightTileSize / 2, const.HeightTileSize / 2)) / const.HeightTileSize
	return self.height_grid:get(pt) * const.TerrainHeightScale
end

XTerrainGridData.EditorCallbackPlace = UpdateAreas
XTerrainGridData.EditorCallbackDelete = UpdateAreas


----- Two-step pasting logic
-- a) paste the areas first and let the user move them with Move Gizmo
-- b) the second Ctrl-V pastes the stored terrain and objects
-- c) cancel the entire operation if the editor tool is changed from Move Gizmo

local areas, undo_index, op_in_progress

local function UpdatePasteOpState()
	if op_in_progress then return end
	op_in_progress = true
	if not areas then
		if IsKindOf(selo(), "XTerrainGridData") then
			local ops = XEditorUndo:GetOpNames()
			local index
			for i = #ops, 2, -1 do
				if string.find(ops[i], "Started pasting", 1, true) then
					index = i - 1
					break
				end
			end
			undo_index = index or XEditorUndo:GetCurrentOpNameIdx()
			areas = editor.GetSel()
			XEditorSetDefaultTool("MoveGizmo", {
				rotation_arrows_on = true,
				rotation_arrows_z_only = true,
			})
		end
	else
		if not XEditorUndo.undoredo_in_progress then
			XEditorUndo:RollToOpIndex(undo_index)
		end
		areas = nil
		undo_index = nil
	end
	op_in_progress = false
end

OnMsg.EditorToolChanged = UpdatePasteOpState
OnMsg.EditorSelectionChanged = UpdatePasteOpState

function calculate_center(objs, method)
	local pos = point30
	for _, obj in ipairs(objs) do
		pos = pos + ValidateZ(obj[method](obj))
	end
	return pos / #objs
end

function XEditorPasteFuncs.PasteTerrainAndObjects(clipboard_data, clipboard_text)
	CreateRealTimeThread(function()
		PauseInfiniteLoopDetection("PasteTerrainAndObjects")
		
		local grid_to_item_map = {
			BiomeGrid = "Biome",
			height = "Terrain height",
			terrain_type = "Terrain texture",
			grass_density = "Grass density",
			impassability = "Impassability",
			passability = "Passability",
			colorize = "Terrain colorization",
			---
			["Biome"] = "BiomeGrid",
			["Terrain height"] = "height",
			["Terrain texture"] = "terrain_type",
			["Grass density"] = "grass_density",
			["Impassability"] = "impassability",
			["Passability"] = "passability",
			["Terrain colorization"] = "colorize",
		}
		
		if const.CaveTileSize then
			grid_to_item_map.CaveGrid = "Caves"
			grid_to_item_map.Caves = "CaveGrid"
		end
		
		-- first step
		if not areas or #table.validate(areas) == 0 then
			op_in_progress = true
			XEditorUndo:BeginOp{ name = "Started pasting", clipboard = clipboard_text }
			local areas = XEditorDeserialize(clipboard_data)
			XEditorSelectAndMoveObjects(areas, editor.GetPlacementPoint(GetTerrainCursor()) - clipboard_data.pivot)
			XEditorUndo:EndOp(areas)
			op_in_progress = false
			UpdatePasteOpState() -- activates the Move Gizmo and starts the second paste step
		else -- second step
			op_in_progress = true
			XEditorSetDefaultTool()
			
			local op = {}
			local grids = {}
			local items = {}
			local starting_selection = {}
			for idx, grid in ipairs(editor.GetGridNames()) do
				op[grid] = true
				grids[idx] = grid
				-- Read last choice from local storage
				if LocalStorage.XAreaCopyTool[grid] then
					table.insert(starting_selection, idx)
				end
				-- Map from grid name to item name
				if grid_to_item_map[grid] then
					table.insert(items, grid_to_item_map[grid])
				end
			end
			
			local result = WaitListMultipleChoice(nil, items, "Choose grids to paste:", starting_selection)
			if not result then
				-- Cancel
				for _, a in ipairs(areas) do
					a:delete()
				end
				
				areas = nil
				undo_index = nil
				op_in_progress = nil
				ResumeInfiniteLoopDetection("PasteTerrainAndObjects")
				return
			end
			if #result == 0 then
				-- Nothing chosen
				result = items
			end
			
			local paste_grids = {}
			for _, item in ipairs(result) do
				-- Map from item name to grid name
				if grid_to_item_map[item] then
					local grid = grid_to_item_map[item]
					paste_grids[grid] = true
				end
			end
			
			-- Save choice in local storage
			LocalStorage.XAreaCopyTool = table.copy(paste_grids)
			SaveLocalStorage()
			
			op.name = "Pasted terrain & objects"
			op.objects = areas
			op.clipboard = clipboard_text
			XEditorUndo:BeginOp(op)
			
			local offs = calculate_center(areas, "GetPos") - calculate_center(areas, "GetPivot")
			local angle = areas[1]:GetAngle()
			local center = CenterOfMasses(areas)
			for _, a in ipairs(areas) do
				a:RotateGrids()
				a:ApplyData(paste_grids, clipboard_data.mask_grid_tile_size)
				a:delete()
			end
			
			local objs = XEditorDeserialize(clipboard_data.objs, nil, "paste")
			objs = XEditorSelectAndMoveObjects(objs, offs)
			editor.ClearSel()
			
			if angle ~= 0 then
				local rotate_logic = XEditorRotateLogic:new()
				SuspendPassEditsForEditOp()
				rotate_logic:InitRotation(objs, center, 0)
				rotate_logic:Rotate(objs, "group_rotation", center, axis_z, angle)
				ResumePassEditsForEditOp()
			end
			
			XEditorUndo:EndOp(objs)
			areas = nil
			undo_index = nil
			op_in_progress = nil
		end
		
		ResumeInfiniteLoopDetection("PasteTerrainAndObjects")
	end)
end

function OnMsg.ChangeMap()
	areas = nil
	undo_index = nil
	op_in_progress = nil
end
