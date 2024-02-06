DefineClass.XPlaceMultipleObjectsToolBase = {
	__parents = { "XEditorBrushTool" },
	properties = {
		{ id = "Distance", editor = "number", default = 5 * guim, scale = "m", min = guim , max = 100 * guim, step = guim / 10,
		  slider = true, persisted_setting = true, auto_select_all = true, sort_order = -1, },
		{ id = "MinDistance", name = "Min distance", editor = "number", default = 0, scale = "m", min = 0, max = function(self) return self:GetDistance() end, step = guim / 10,
		  slider = true, persisted_setting = true, auto_select_all = true, sort_order = -1, },
	},
	
	deleted_objects = false,
	new_objects = false,
	new_positions = false,
	box_changed = false,
	init_terrain_type = false,
	terrain_normal = false,
	distance_visualization = false,
}

function XPlaceMultipleObjectsToolBase:Init()
	self.distance_visualization = Mesh:new()
	self.distance_visualization:SetMeshFlags(const.mfWorldSpace)
	self.distance_visualization:SetShader(ProceduralMeshShaders.mesh_linelist)
	self.distance_visualization:SetPos(point(0, 0))
end

function XPlaceMultipleObjectsToolBase:Done()
	self.distance_visualization:delete()
end

function XPlaceMultipleObjectsToolBase:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Distance" then
		self:SetMinDistance(Min(self:GetMinDistance(), self:GetDistance()))
	end
end

function XPlaceMultipleObjectsToolBase:UpdateCursor()
	local v_pstr = self:CreateCircleCursor()
	
	local strength = self:GetCursorHeight()
	if strength then
		v_pstr:AppendVertex(point(0, 0, 0))
		v_pstr:AppendVertex(point(0, 0, strength))
	end
	
	self.cursor_mesh:SetMeshFlags(self.cursor_default_flags + self:GetCursorExtraFlags())
	local pt = self:GetWorldMousePos()
	local radius = self:GetCursorRadius()
	self.box_changed = box(pt:x() - radius, pt:y() - radius, pt:x() + radius, pt:y() + radius)
	self.box_changed = terrain.ClampBox(self.box_changed)
	local distance = self:GetDistance()
	local bxDistanceGrid = self.box_changed / distance
	local vpstr = pstr("")
	for i = bxDistanceGrid:miny(), bxDistanceGrid:maxy() do
		for j = bxDistanceGrid:minx(), bxDistanceGrid:maxx() do
			local ptDistance = point(j, i)
			local ptReal = ptDistance * distance
			local color = self:GetCursorColor()
			if ptReal:Dist(pt) <= self:GetCursorRadius() then
				ptReal = ptReal:SetZ(terrain.GetHeight(ptReal))
				vpstr:AppendVertex(ptReal + point(-200, -200, 0), color)
				vpstr:AppendVertex(ptReal + point(200, 200, 0))
				vpstr:AppendVertex(ptReal + point(-200, 200, 0), color)
				vpstr:AppendVertex(ptReal + point(200, -200, 0))
			end
		end
	end
	self.distance_visualization:SetMesh(vpstr)
	self.cursor_mesh:SetMesh(v_pstr)
	self.cursor_mesh:SetPos(GetTerrainCursor())
end

function XPlaceMultipleObjectsToolBase:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

function XPlaceMultipleObjectsToolBase:MarkObjectsForDelete()
	local radius = self:GetCursorRadius()
	MapForEach(GetTerrainCursor(), radius, function(o)
		local classes = self:GetClassesForDelete() or {}
		if not self.deleted_objects[o] and not self.new_objects[o] and XEditorFilters:IsVisible(o) and IsKindOfClasses(o, classes)
			and (not self.init_terrain_type or self.init_terrain_type[terrain.GetTerrainType(o:GetPos())])then 
			self.deleted_objects[o] = true
			o:ClearEnumFlags(const.efVisible) 
		end 
	end)
end

function XPlaceMultipleObjectsToolBase:PlaceObjects(pt)
	local newobjs = {}
	local distance = self:GetDistance()
	local min_distance = self:GetMinDistance()
	local bxDistanceGrid = self.box_changed / distance
	for i = bxDistanceGrid:miny(), bxDistanceGrid:maxy() do
		for j = bxDistanceGrid:minx(), bxDistanceGrid:maxx() do
			local ptDistance = point(j, i)
			local ptReal = ptDistance * distance
			local offset = (distance - min_distance) / 2
			local randX = -offset + AsyncRand(2 * offset)
			local randY = -offset + AsyncRand(2 * offset)
			ptReal = ptReal + point(randX, randY)
			local classes = self:GetClassesForPlace(ptReal)
			local class = classes and classes[AsyncRand(#classes) + 1]
			local terrainNormal, scale, scaleDeviation, angle, colorMin, colorMax = self:GetParams(ptReal)
			if ptReal:InBox2D(GetMapBox()) and ptReal:Dist(pt) <= self:GetCursorRadius() and (not self.new_positions[j] or not self.new_positions[j][i]) and class and scale
			  and (not self.init_terrain_type or self.init_terrain_type[terrain.GetTerrainType(ptReal)]) then
				local axis = terrainNormal and terrain.GetTerrainNormal(ptReal) or axis_z
				local obj = XEditorPlaceObject(class)
				scaleDeviation = scaleDeviation == 0 and 0 or -scaleDeviation + AsyncRand(2 * scaleDeviation)
				scale = Clamp(MulDivRound(scale, 100 + scaleDeviation, 100), 10, 250)
				angle = angle * 60
				angle = AsyncRand(-angle, angle)
				local minR, minG, minB = GetRGB(colorMin)
				local maxR, maxG, maxB = GetRGB(colorMax)
				minR, maxR = MinMax(minR, maxR)
				minG, maxG = MinMax(minG, maxG)
				minB, maxB = MinMax(minB, maxB)
				local color = RGB(AsyncRand(minR, maxR), AsyncRand(minG, maxG), AsyncRand(minB, maxB))
				obj:SetPos(ptReal)
				obj:SetInvalidZ()
				obj:SetScale(scale)
				obj:SetOrientation(axis, angle)
				obj:SetColorModifier(color)
				obj:RestoreHierarchyEnumFlags() -- will rebuild surfaces if required
				obj:SetHierarchyEnumFlags(const.efVisible)
				obj:SetGameFlags(const.gofPermanent)
				obj:SetCollection(Collections[editor.GetLockedCollectionIdx()])
				self.new_positions[j] = self.new_positions[j] or {}
				self.new_positions[j][i] = true
				self.new_objects[obj] = true
				newobjs[#newobjs + 1] = obj
			end
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", newobjs)
end

function XPlaceMultipleObjectsToolBase:StartDraw(pt)
	SuspendPassEdits("XEditorPlaceMultipleObjects")
	self.deleted_objects = {}
	self.new_objects = {}
	self.new_positions = {}
	if terminal.IsKeyPressed(const.vkControl) then self.init_terrain_type = {[terrain.GetTerrainType(pt)] = true} end
	if terminal.IsKeyPressed(const.vkAlt) then self.terrain_normal = true end
end

function XPlaceMultipleObjectsToolBase:Draw(pt1, pt2)
	self:MarkObjectsForDelete()
	self:PlaceObjects(pt2)
end

function XPlaceMultipleObjectsToolBase:EndDraw(pt)
	local objs = table.validate(table.keys(self.deleted_objects))
	for _, obj in ipairs(objs) do obj:SetEnumFlags(const.efVisible) end
	XEditorUndo:BeginOp({ objects = objs, name = "Placed multiple objects" })
	Msg("EditorCallback", "EditorCallbackDelete", objs)
	for _, obj in ipairs(objs) do obj:delete() end
	XEditorUndo:EndOp(table.keys(self.new_objects))
	
	ResumePassEdits("XEditorPlaceMultipleObjects", true)
	self.deleted_objects = false 
	self.new_objects = false
	self.new_positions = false
	self.init_terrain_type = false
	self.terrain_normal = false
end

function XPlaceMultipleObjectsToolBase:GetParams()
end

function XPlaceMultipleObjectsToolBase:GetClassesForDelete()
end

function XPlaceMultipleObjectsToolBase:GetClassesForPlace(pt)
end