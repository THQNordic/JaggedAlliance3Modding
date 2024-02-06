if FirstLoad then
	EditorMeasureLines = false
end

function AddEditorMeasureLine(line)
	EditorMeasureLines = EditorMeasureLines or {}
	EditorMeasureLines[#EditorMeasureLines + 1] = line
end

function DestroyEditorMeasureLines()
	for _, line in ipairs(EditorMeasureLines or empty_table) do
		line:Done()
	end
	EditorMeasureLines = false
end

function UpdateEditorMeasureLines()
	for _, line in ipairs(EditorMeasureLines or empty_table) do
		line:Move(line.point0, line.point1)
	end
end

OnMsg.EditorHeightChanged = UpdateEditorMeasureLines
OnMsg.EditorPassabilityChanged = UpdateEditorMeasureLines
OnMsg.ChangeMap = DestroyEditorMeasureLines


----- XMeasureTool

DefineClass.XMeasureTool = {
	__parents = { "XEditorTool" },
	properties = {
		persisted_setting = true,
		{ id = "CamDist", editor = "help", default = false, persisted_setting = false,
			help = function(self)
				local frac = self.cam_dist % guim
				return string.format("Distance to screen: %d.%0".. (#tostring(guim) - 1) .."dm", self.cam_dist / guim, frac)
			end
		},
		{ id = "Slope", editor = "help", default = false, persisted_setting = false,
			help = function(self)
				return string.format("Terrain slope: %.1f°", self.slope / 60.0)
			end
		},
		{ id = "MeasureInSlabs", name = "Measure in slabs", editor = "bool", default = false, no_edit = not const.SlabSizeZ },
		{ id = "FollowTerrain", name = "Follow terrain", editor = "bool", default = false, },
		{ id = "IgnoreWalkables", name = "Ignore walkables", editor = "bool", default = false, },
		{ id = "MeasurePath", name = "Measure path", editor = "bool", default = false, },
		{ id = "StayOnScreen", name = "Stay on screen", editor = "bool", default = false, },
	},
	ToolTitle = "Measure",
	Description = {
		"Measures distance between two points.",
		"The path found using the pathfinder and slope in degrees are also displayed.",
	},
	ActionSortKey = "1",
	ActionIcon = "CommonAssets/UI/Editor/Tools/MeasureTool.tga", 
	ActionShortcut = "Alt-M",
	ToolSection = "Misc",
	UsesCodeRenderables = true,
	
	measure_line = false,
	measure_cam_dist_thread = false,
	cam_dist = 0,
	slope = 0,
}

function XMeasureTool:Init()
	self.measure_cam_dist_thread = CreateRealTimeThread(function()
		while true do
			local mouse_pos = terminal.GetMousePos()
			if mouse_pos:InBox2D(terminal.desktop.box) then
				RequestPixelWorldPos(mouse_pos)
				WaitNextFrame(6)
				self.cam_dist = camera.GetEye():Dist2D(ReturnPixelWorldPos())
				self.slope = terrain.GetTerrainSlope(GetTerrainCursor())
				ObjModified(self)
			end
			Sleep(50)
		end
	end)
end

function XMeasureTool:Done()
	if not self:GetStayOnScreen() then
		DestroyEditorMeasureLines()
	end
	DeleteThread(self.measure_cam_dist_thread)
end

function XMeasureTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		local terrain_cursor = GetTerrainCursor()
		if self.measure_line then
			self.measure_line = false
		else
			if not self:GetStayOnScreen() then
				DestroyEditorMeasureLines()
			end
			self.measure_line = PlaceObject("MeasureLine", {
				measure_in_slabs = self:GetMeasureInSlabs(),
				follow_terrain = self:GetFollowTerrain(),
				ignore_walkables = self:GetIgnoreWalkables(),
				show_path = self:GetMeasurePath()
			})
			self.measure_line:Move(terrain_cursor, terrain_cursor)
			AddEditorMeasureLine(self.measure_line)
		end
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

function XMeasureTool:UpdatePoints()
	local obj = self.measure_line
	if obj and IsValid(obj) then
		local pt = GetTerrainCursor()
		obj:Move(obj.point0, pt)
		obj:UpdatePath()
	end
end

function XMeasureTool:OnMousePos(pt, button)
	self:UpdatePoints()
end

function XMeasureTool:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "MeasureInSlabs" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.measure_in_slabs = self:GetMeasureInSlabs()
			line:UpdateText()
		end
	elseif prop_id == "FollowTerrain" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.follow_terrain = self:GetFollowTerrain()
			line:Move(line.point0, line.point1)
		end
	elseif prop_id == "IgnoreWalkables" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.ignore_walkables = self:GetIgnoreWalkables()
			line:Move(line.point0, line.point1)
		end
	elseif prop_id == "MeasurePath" then
		for _, line in ipairs(EditorMeasureLines or empty_table) do
			line.show_path = self:GetMeasurePath()
			line:UpdatePath()
		end
	end
	if prop_id == "StayOnScreen" and not self:GetStayOnScreen() then
		DestroyEditorMeasureLines()
		self.measure_line = false
	end
end


----- MeasureLine

DefineClass.MeasureLine = {
	__parents = { "Object" },

	point0 = point30,
	point1 = point30,
	path_distance = -1,
	line_distance = -1,
	horizontal_distance = -1,
	vertical_distance = -1,
	measure_in_slabs = false,
	show_path = false,
	follow_terrain = true,
}

function MeasureLine:Init()
	self.line = PlaceObject("Polyline")
	self.path = PlaceObject("Polyline")
	self.label = PlaceObject("Text")
end

function MeasureLine:Done()
	DoneObject(self.line)
	DoneObject(self.path)
	DoneObject(self.label)
end

function MeasureLine:DistanceToString(dist, slab_size, skip_slabs)
	dist = Max(0, dist)
	if self.measure_in_slabs then
		local whole = dist / slab_size
		return string.format(skip_slabs and "%d.%d" or "%d.%d slabs", whole, dist * 10 / slab_size - whole * 10)
	else
		local frac = dist % guim
		return string.format("%d.%0".. (#tostring(guim) - 1) .."dm", dist / guim, frac)
	end
end

function MeasureLine:UpdateText()
	local dist_string
	if self.measure_in_slabs then
		local x = self:DistanceToString(abs(self.point0:x() - self.point1:x()), const.SlabSizeX, true)
		local y = self:DistanceToString(abs(self.point0:y() - self.point1:y()), const.SlabSizeY, true)
		local z = self:DistanceToString(self.vertical_distance, const.SlabSizeZ, true)
		dist_string = string.format("x%s, y%s, z%s", x, y, z)
	else
		local h = self:DistanceToString(self.horizontal_distance)
		local v = self:DistanceToString(self.vertical_distance)
		dist_string = string.format("h%s, v%s", h, v)
	end
	local angle = atan(self.vertical_distance, self.horizontal_distance) / 60.0
	local l = self:DistanceToString(self.line_distance, const.SlabSizeX)
	if self.show_path then
		local p = "No path"
		if self.show_path and self.path_distance ~= -1 then
			p = self:DistanceToString(self.path_distance, const.SlabSizeX)
		end
		self.label:SetText(string.format("%s (%s, %.1f°) : %s", l, dist_string, angle, p))
	else
		self.label:SetText(string.format("%s (%s, %.1f°)", l, dist_string, angle))
	end
end

local function _GetZ(pt, ignore_walkables)
	if ignore_walkables then
		return terrain.GetHeight(pt)
	else
		return Max(GetWalkableZ(pt), terrain.GetSurfaceHeight(pt))
	end
end

local function SetLineMesh(line, p_pstr)
	line:SetMesh(p_pstr)
	return line
end

function MeasureLine:Move(point0, point1)
	self.point0 = point0:SetInvalidZ()
	self.point1 = point1:SetInvalidZ()
	
	local point0t = point(point0:x(), point0:y(), _GetZ(point0))
	local point1t = point(point1:x(), point1:y(), _GetZ(point1))
	local len = (point0t - point1t):Len()

	local points_pstr = pstr("")
	points_pstr:AppendVertex(point0t)
	points_pstr:AppendVertex(point0t + point(0, 0, 5 * guim))
	points_pstr:AppendVertex(point0t + point(0, 0, guim))
	
	local steps = len / (guim / 2)
	steps = steps > 0 and steps or 1
	local distance = 0
	local prev_point = point0t + point(0, 0, guim)
	for i = 0, steps do
		local pt = point0t + (point1t - point0t) * i / steps
		if self.follow_terrain then
			pt = point(pt:x(), pt:y(), _GetZ(pt, self.ignore_walkables))
			distance = distance + (prev_point - point(0, 0, guim)):Dist(pt)
		end
		prev_point = pt + point(0, 0, guim)
		points_pstr:AppendVertex(prev_point)
	end
	
	points_pstr:AppendVertex(point1t + point(0, 0, guim))
	points_pstr:AppendVertex(point1t + point(0, 0, 5 * guim))
	points_pstr:AppendVertex(point1t)
	
	self.line = SetLineMesh(self.line, points_pstr)
	
	-- update text label
	local middlePoint = (point0 + point1) / 2
	self.line:SetPos(middlePoint)
	self.path:SetPos(middlePoint)
	self.label:SetPos(middlePoint + point(0, 0, 4 * guim))
	self.label:SetTextStyle("EditorTextBold")

	self.line_distance = self.follow_terrain and distance or len
	self.horizontal_distance = (point0t - point1t):Len2D()
	self.vertical_distance = abs(point0t:z() - point1t:z())
	self:UpdateText()
end

local function SetWalkableHeight(pt)
	return pt:SetZ(_GetZ(pt))
end

-- will create a red line if *delayed* == true and a green line if *delayed* == false
function MeasureLine:SetPath(path, delayed)
	local v_points_pstr = pstr("")
	if path and #path > 0 then
		local v_prev = {}
		v_points_pstr:AppendVertex(SetWalkableHeight(self.point0), delayed and const.clrRed or const.clrGreen)
		v_points_pstr:AppendVertex(SetWalkableHeight(self.point0))
		local dist = 0
		for i = 1, #path do
			v_points_pstr:AppendVertex(SetWalkableHeight(path[i]))
			if i > 1 then
				dist = dist + path[i]:Dist(path[i - 1])
			end
		end
		self.path_distance = dist
	else
		v_points_pstr:AppendVertex(self.point0, delayed and const.clrRed or const.clrGreen)
		v_points_pstr:AppendVertex(self.point0)
		self.path_distance = -1
	end
	
	self.path = SetLineMesh(self.path, v_points_pstr)
	self:UpdateText()
end

function MeasureLine:UpdatePath()
	if self.show_path then
		local pts, delayed = pf.GetPosPath(self.point0, self.point1)
		self:SetPath(pts, delayed)
		self.path:SetEnumFlags(const.efVisible)
	else
		self:UpdateText()
		self.path:ClearEnumFlags(const.efVisible)
	end
end
