DefineClass.Marker = {
	__parents = { "InitDone" },

	properties = {
		{ id = "name", name = "Name", editor = "text", read_only = true, default = false, },
		{ id = "type", editor = "text", default = "", read_only = true },
		{ id = "map", editor = "text", default = "", read_only = true },
		{ id = "handle", editor = "number", default = 0, read_only = true, buttons = {{name = "Teleport", func = "ViewMarker"}}},
		{ id = "pos", editor = "point", default = point(-1,-1)},
		{ id = "display_name", editor = "text", default = "", translate = true },
		{ id = "data", editor = "text", default = "", read_only = true },
		{ id = "data_version", editor = "text", default = "", read_only = true },
	},
	StoreAsTable = false,
}

if FirstLoad or ReloadForDlc then
	Markers = {}
end

function Marker:Register()
	local name = self.name
	if not name then 
		return
	end
	local old = Markers[name]
	if old then
		if old == self then
			return
		end
		print("Duplicated marker:", name, "\n\t1.", self.map, "at", self.pos, "\n\t2.", old.map, "at", old.pos)
		old:delete()
	end

	table.insert(Markers, self)
	Markers[name] = self
end

function Marker:__fromluacode(table)
	local obj = Container.__fromluacode(self, table)
	obj:Register()
	return obj
end

function OnMsg.PostLoad()
	table.sort(Markers, function(m1,m2) return CmpLower(m1.name, m2.name) end)
end

function Marker:GetEditorView()
	return self.name
end

function Marker:Init()
	self:Register()
end

function Marker:Done()
	table.remove_value(Markers, self)
	Markers[self.name] = nil
end

function OpenMarkerViewer()
	OpenGedApp("GedMarkerViewer", Markers)
end

function DeleteMapMarkers()
	if mapdata.LockMarkerChanges then
		print("Marker changes locked!")
		return
	end
	local maps = {}
	local maps_list = ListMaps()
	for i=1,#maps_list do
		maps[maps_list[i]] = true
	end
	local map = GetMapName()

	for i = #Markers, 1, -1 do
		local marker = Markers[i]
		if marker.map == map or not maps[marker.map] then
			marker:delete()
		end
	end
	ObjModified(Markers)
end

function RebuildMapMarkers()
	local t = GetPreciseTicks()
	Msg("MarkersRebuildStart")
	DeleteMapMarkers()
	local count = MapForEach("map", "MapMarkerObj", nil, nil, const.gofPermanent, function(obj)
		obj:CreateMarker()
	end)
	Msg("MarkersRebuildEnd")
	table.sort(Markers, function(m1,m2) return CmpLower(m1.name, m2.name) end)
	ObjModified(Markers)
	if mapdata.LockMarkerChanges then
		print("Marker changes locked!")
		return
	end

	local map_name = GetMapName()
	local markers = {}
	for _, marker in ipairs(Markers) do
		if marker.map == map_name then
			table.insert(markers, marker)
		end
	end
	mapdata.markers = markers
	Msg("MarkersChanged")
	DebugPrint(string.format("%d map markers rebuilt in %d ms\n", count, GetPreciseTicks() - t))
end

OnMsg.SaveMap = RebuildMapMarkers

DefineClass.MarkerBase = {
	__parents = { "Object", "EditorObject", "EditorCallbackObject" },
	flags = { efMarker = true },
}

DefineClass.MapMarkerObj = {
	__parents = { "MarkerBase", "MinimapObject", "EditorTextObject" },
	properties = {
		{ id = "MarkerName", category = "Gameplay", editor = "text", default = "", important = true, },
		{ id = "MarkerDisplayName", category = "Gameplay", editor = "text", default = "", translate = true, important = true },
	},
	marker_type = "",
	marker_name = false,
	editor_text_member = "MarkerName",
}

function MapMarkerObj:SetMarkerName(value)
	self.MarkerName = value
	self.marker_name = value ~= "" and GetMapName() .. " - " .. value or value
end

function MapMarkerObj:VisibleOnMinimap()
	return self.MarkerName ~= ""
end

function MapMarkerObj:SetMinimapRollover()
	self.minimap_rollover = nil -- resetting to the default value
end

if Platform.developer then

function MapMarkerObj:CreateMarker()
	if mapdata.LockMarkerChanges then
		print("Marker changes locked!")
		return
	end
	local marker_name = self.marker_name
	if (marker_name or "") == "" then return end
	return Marker:new{
		name = marker_name,
		type = self.marker_type,
		map = GetMapName(),
		handle = self.handle,
		pos = self:GetVisualPos(),
		display_name = self.MarkerDisplayName,
	}
end

end -- Platform.developer

function ViewMarker(root, marker, prop_id, ged)
	local map = marker.map
	local handle = marker.handle
	EditorWaitViewMapObjectByHandle(marker.handle, marker.map, ged)
end

function ViewMarkerProp(editor_obj, obj, prop_id)
	local name = obj[prop_id]
	local marker = Markers[name]
	if marker then
		ViewMarker(editor_obj, marker)
	end
end

DefineClass.PosMarkerObj = { 
	__parents = { "MapMarkerObj", "EditorVisibleObject", "StripCObjectProperties" },
	entity = "WayPoint",
	marker_type = "pos",
	flags = { efCollision = false, efApplyToGrids = false, },
}

----

DefineClass.EditorMarker = {
	__parents = { "MarkerBase", "EditorVisibleObject", "EditorTextObject", "EditorColorObject", },
	
	properties = {
		{ id = "DetailClass", name = "Detail Class", editor = "dropdownlist", default = "Default",
			items = {{text = "Default", value = 0}}, no_edit = true
		},
	},
	
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false },
	entity = "WayPoint",
	editor_text_offset = point(0, 0, 13*guim),
}

----

DefineClass.RadiusMarker = {
	__parents = { "EditorMarker", "EditorSelectedObject" },
	editor_text_color = RGB(50, 50, 100),
	editor_color = RGB(150, 150, 0),
	radius_mesh = false,
	radius_prop = false,
	show_radius_on_select = false,
}

function RadiusMarker:EditorSelect(selected)
	if self.show_radius_on_select then
		self:ShowRadius(selected)
	end
end

function RadiusMarker:GetMeshRadius()
	return self.radius_prop and self[self.radius_prop]
end

function RadiusMarker:GetMeshColor()
	return self.editor_color
end

function RadiusMarker:UpdateMeshRadius(radius)
	if IsValid(self.radius_mesh) then
		local scale = self:GetScale()
		radius = radius or self:GetMeshRadius() or guim
		radius = MulDivRound(radius, 100, scale)
		self.radius_mesh:SetScale(MulDivRound(radius, 100, 10*guim))
	end
end

function RadiusMarker:ShowRadius(show)
	local radius = show and self:GetMeshRadius()
	if not radius then
		DoneObject(self.radius_mesh)
		self.radius_mesh = nil
		return
	end
	if not IsValid(self.radius_mesh) then
		local radius_mesh = CreateCircleMesh(10*guim, self:GetMeshColor(), point30)
		self.radius_mesh = radius_mesh
		self:Attach(radius_mesh)
	end
	self:UpdateMeshRadius(radius)
end

function RadiusMarker:EditorEnter(...)
	if not self.show_radius_on_select or editor.IsSelected(self)  then
		self:ShowRadius(true)
	end
end

function RadiusMarker:EditorExit(...)
	self:ShowRadius(false)
end

function RadiusMarker:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == self.radius_prop then
		self:UpdateMeshRadius()
	end
	EditorMarker.OnEditorSetProperty(self, prop_id, old_value, ged)
end

----

DefineClass.EnumMarker = {
	__parents = { "RadiusMarker", "EditorTextObject" },
	properties = {
		{ category = "Enum", id = "EnumClass",      name = "Class",      editor = "text",       default = false, help = "Accept children from the given class only" },
		{ category = "Enum", id = "EnumCollection", name = "Collection", editor = "bool",       default = false, help = "Use the marker's collection to filter children" },
		{ category = "Enum", id = "EnumRadius",     name = "Radius",     editor = "number",     default = 64*guim, scale = "m", min = 0, max = function(self) return self.EnumRadiusMax end, slider = true, help = "Max children distance" },
		{ category = "Enum", id = "EnumInfo",       name = "Objects",    editor = "prop_table", default = false, read_only = true, dont_save = true, lines = 3, indent = "" },
	},
	editor_text_color = white,
	editor_color = white,
	radius_prop = "EnumRadius",
	children_highlight = false,
	EnumRadiusMax = 64*guim,
}

function EnumMarker:GetEnumInfo()
	local class_to_count = {}
	for _, obj in ipairs(self:GatherObjects()) do
		if IsValid(obj) then
			class_to_count[obj.class] = (class_to_count[obj.class]or 0) + 1
		end
	end
	return class_to_count
end

function EnumMarker:HightlightObjects(enable)
	local prev_highlight = self.children_highlight
	if not enable and not prev_highlight then
		return
	end
	for _, obj in ipairs(prev_highlight) do
		if IsValid(obj) then
			ClearColorModifierReason(obj, "EnumMarker")
		end
	end
	self.children_highlight = enable and self:GatherObjects() or nil
	for _, obj in ipairs(self.children_highlight) do
		SetColorModifierReason(obj, "EnumMarker", white)
	end
	return prev_highlight
end

function EnumMarker:EditorSelect(selected)
	if IsValid(self) then
		self:HightlightObjects(selected)
	end
	return RadiusMarker.EditorSelect(self, selected)
end

function EnumMarker:GatherObjects(radius)
	radius = radius or self.EnumRadius
	local collection = self:GetCollectionIndex()
	if not self.EnumCollection then
		return MapGet(self, radius, "attached", false, self.EnumClass or nil)
	elseif collection == 0 then
		return MapGet(self, radius, "attached", false, "collected", false, self.EnumClass or nil)
	else
		return MapGet(self, radius, "attached", false, "collection", collection, self.EnumClass or nil)
	end
end

function EnumMarker:GetError()
	if self.EnumRadius ~= self.EnumRadiusMax then
		local t1 = self:GatherObjects() or ""
		local t2 = self:GatherObjects(self.EnumRadiusMax) or ""
		if #t1 ~= #t2 then
			return "Not all collection objects are inside the enum radius!"
		end
	end
end

function EnumMarker.UpdateAll()
	local st = GetPreciseTicks()
	MapForEach("map", "EnumMarker", function(obj) obj:GatherObjects() end)
	DebugPrint("Container markers updated in", GetPreciseTicks() - st, "ms")
end
OnMsg.PreSaveMap = EnumMarker.UpdateAll

----

MapVar("ForcedImpassableMarkers", false)

DefineClass.ForcedImpassableMarker = {
	__parents = { "EditorMarker", "EditorSelectedObject", "EditorCallbackObject" },
	properties = {
		{ category = "Area", id = "SizeX", editor = "number", default = 0, scale = "m", min = 0 },
		{ category = "Area", id = "SizeY", editor = "number", default = 0, scale = "m", min = 0 },
		{ category = "Area", id = "SizeZ", editor = "number", default = 0, scale = "m", min = 0 },
	},
	editor_color = RGB(255, 0, 0),
	editor_text_color = white,
	mesh_obj = false,
	area = false,
}

function ForcedImpassableMarker:Init()
	if not ForcedImpassableMarkers then
		ForcedImpassableMarkers = {}
	end
	self:SetColorModifier(self.editor_color)
	table.insert(ForcedImpassableMarkers, self)
end

function ForcedImpassableMarker:EditorGetText()
	return self.class
end

function ForcedImpassableMarker:Done()
	table.remove_value(ForcedImpassableMarkers, self)
	if self.area then
		RebuildGrids(self.area)
	end
end

function ForcedImpassableMarker:GetArea()
	if not self.area then
		if self:IsValidPos() then
			local posx, posy, posz = self:GetVisualPosXYZ()
			local sizex, sizey, sizez = self.SizeX, self.SizeY, self.SizeZ
			if sizez > 0 then
				-- clear terrain and slab passability inside the box
				self.area = box(
					posx - sizex/2,
					posy - sizey/2,
					posz - sizez/2,
					posx + sizex/2 + 1,
					posy + sizey/2 + 1,
					posz + sizez/2 + 1)
			else
				-- clear terrain only passability inside the 2D box
				self.area = box(
					posx - sizex/2,
					posy - sizey/2,
					posx + sizex/2 + 1,
					posy + sizey/2 + 1)
			end
		else
			self.area = box()
		end
	end
	return self.area
end

function OnMsg.OnPassabilityRebuilding(clip)
	for i, marker in ipairs(ForcedImpassableMarkers) do
		local bx = marker:GetArea()
		if clip:Intersect2D(bx) ~= const.irOutside then
			terrain.ClearPassabilityBox(bx)
		end
	end
end

function ForcedImpassableMarker:ShowArea(show)
	DoneObject(self.mesh_obj)
	self.mesh_obj = nil
	if show then
		self.mesh_obj = PlaceBox(self:GetArea(), self.editor_color, false, "depth test")
		self:Attach(self.mesh_obj)
	end
end

function ForcedImpassableMarker:EditorSelect(selected)
	self:ShowArea(selected)
end

function ForcedImpassableMarker:RebuildArea()
	SuspendPassEdits("ForcedImpassableMarker")
	if self.area then
		RebuildGrids(self.area)
		self.area = false
	end
	RebuildGrids(self:GetArea())
	ResumePassEdits("ForcedImpassableMarker")
	if self.mesh_obj then
		self:ShowArea(true)
	end
end

function ForcedImpassableMarker:EditorCallbackPlace()
	self:RebuildArea()
end

function ForcedImpassableMarker:EditorCallbackMove()
	self:RebuildArea()
end

function ForcedImpassableMarker:OnEditorSetProperty(prop_id, old_value, ged)
	self:RebuildArea()
end
