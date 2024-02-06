local function FlavorAnimsCombo()
	local states = GetStates("Male")
	table.insert(states, 1, "")
	return states
end

DefineClass.WaypointMarker = {
	__parents = {"GridMarker"},
	properties =
	{
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = PresetGroupCombo("GridMarkerType", "Default"), default = "Waypoint", no_edit = true },
		{ category = "Marker", id = "AreaHeight", name = "Area Height", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes", no_edit = true },
		{ category = "Marker", id = "AreaWidth",  name = "Area Width", editor = "number", default = 0, help = "Defining a voxel-aligned rectangle with North-South and East-West axes", no_edit = true },
		{ category = "Marker", id = "Color",      name = "Color", editor = "color", default = RGB(255, 255, 0)},
		{ category = "Flavor", id = "FlavorAnim", name = "Animation", editor = "dropdownlist", items = FlavorAnimsCombo, default = "" },
	},
	EditorRolloverText = "Sequence of points to move between",
	EditorIcon = "CommonAssets/UI/Icons/refresh repost retweet.tga",
	recalc_area_on_pass_rebuild = false,
}

marker_group_filter = function(m, group) return IsKindOf(m, "WaypointMarker") and m:IsValidPos() end

function WaypointMarker:Init()
	local init_groups = {"Waypoint"}
	self:SetGroups(init_groups)
	self:SetGroupNumberId(init_groups)
end

function WaypointMarker:OnDelete()
	if self.Groups and #self.Groups > 0 then
		self:AddToIndicesAfter(-1)
	end
end

function WaypointMarker:EditorCallbackDelete()
	self:OnDelete()
	GridMarker.EditorCallbackDelete(self)
end

function WaypointMarker:OnEditorDelete()
	self:OnDelete()
end

function WaypointMarker:OnEditorSetProperty(prop, old_value, ged, multi)
	if prop ~= "Groups" then return end
	if multi then return end
	if old_value and #old_value > 0 then
		self:AddToIndicesAfter(-1, old_value[1])
	end
	self:SetGroupNumberId(self.Groups, "current marker on map")
end

function WaypointMarker:SetGroupNumberId(groups, current_marker_on_map)
	local cnt = MapCountMarkers("GridMarker", groups[1], marker_group_filter)
	self.ID = tostring(current_marker_on_map and cnt or cnt + 1)
end

function WaypointMarker:EditorCallbackClone(marker)
	GridMarker.EditorCallbackClone(self, marker)
	if not self.Groups or #self.Groups == 0 then
		return false
	end
	marker:AddToIndicesAfter(1)
	self:SetID(tostring(tonumber(marker.ID) + 1))
end

function WaypointMarker:EditorCallbackMove()
	GridMarker.EditorCallbackMove(self)
	for _, group in ipairs(self.Groups) do
		DrawGroupPath(group)
	end
end

function WaypointMarker:AddToIndicesAfter(value, group)
	local markers = MapGetMarkers("GridMarker", group or self.Groups[1], marker_group_filter)
	local id = tonumber(self.ID)
	for i, m in ipairs(markers) do
		local m_id = tonumber(m.ID)
		if m_id and m_id > id then
			m:SetID(tostring(m_id + value))
		end
	end
end

function WaypointMarker:GetError()
	if (IsKindOf(self, "WaypointMarker") or self.Type == "Entrance" or self.Type == "Defender") and not GetPassSlab(self) then
		return "Marker placed on impassable."
	end
	
	if self.Groups and #self.Groups > 1 then
		return "Waypoint markers should have only one group."
	end	
end

function OnMsg.EditorSelectionChanged(objects)
	objects = objects or {}
	local waypoint_groups = {}
	for _, obj in ipairs(objects) do
		if IsKindOf(obj, "WaypointMarker") then
			if obj.Groups and #obj.Groups > 0 then
				waypoint_groups[obj.Groups[1]] = true
			end
		end
	end 
	
	UpdateDrawnGroupWaypointPaths(waypoint_groups)
end

function AddThickLine(p_pstr, p1, p2, thickness_divisor, color)
	thickness_divisor = thickness_divisor or 20
	color = color or const.clrPaleBlue
	if not p1:IsValidZ() then
		p1 = p1:SetTerrainZ()
	end
	if not p2:IsValidZ() then
		p2 = p2:SetTerrainZ()
	end
	local dir = p2 - p1
	local orth = point(-dir:y(), dir:x())
	orth = Normalize(orth)
	local delta_vector = (orth/thickness_divisor):SetZ(0)
	p_pstr:AppendVertex(p1 + delta_vector,  color)
	p_pstr:AppendVertex(p2 + delta_vector)
	p_pstr:AppendVertex(p1 - delta_vector)
	p_pstr:AppendVertex(p1 - delta_vector)
	p_pstr:AppendVertex(p2 + delta_vector)
	p_pstr:AppendVertex(p2 - delta_vector)
end

MapVar("WaypointMarkersMeshes", {})
MapVar("LastTimeDrawnWaypointMarkerMeshes", false)

function UpdateDrawnGroupWaypointPaths(groups_to_draw)
	for group, value in pairs(groups_to_draw) do
		if value then
			DrawGroupPath(group)
		end
	end
	for group, value in pairs(WaypointMarkersMeshes) do
		if value and not groups_to_draw[group] then
			WaypointMarkersMeshes[group]:delete()
			WaypointMarkersMeshes[group] = false
		end
	end
end

function DrawGroupPath(group)
	if WaypointMarkersMeshes[group] then
		WaypointMarkersMeshes[group]:delete()
		WaypointMarkersMeshes[group] = false
	end
	local waypoints = {}
	local impassable = {}
	local markers = MapGetMarkers("GridMarker", group, marker_group_filter)
	table.sort(markers, function(a, b) return a.ID < b.ID end)
	for i, marker in ipairs(markers) do
		local idx = table.find(markers, "ID", tostring(i))
		if not idx then
			return
		end
		local pass_pos = GetPassSlab(marker)
		waypoints[i] = pass_pos or marker:GetPos()
		impassable[i] = not pass_pos
	end
	local mesh = PlaceObject("Mesh")
	local p_pstr = pstr("")
	for i = 1, #waypoints - 1 do
		if impassable[i] or impassable[i+1] then
			AddThickLine(p_pstr, waypoints[i], waypoints[i+1], nil,const.clrRed)
		else
			if waypoints[i] ~= waypoints[i+1] then
				local has_path, closest_pos = pf.HasPosPath(waypoints[i], waypoints[i+1])
				if not has_path or closest_pos ~= waypoints[i+1] then
					assert(has_path, "Waypoint markers path blocked or two consecutive markers are too far.")
					break
				end
				local path = pf.GetPosPath(waypoints[i], waypoints[i+1])
				local p0 = path[#path]
				for i = #path-1, 1, -1 do
					local p1 = path[i]
					if p1:IsValid() then
						AddThickLine(p_pstr, p0, p1)
						p0 = p1
					end
				end
			end
		end
	end
	mesh:SetMesh(p_pstr)
	mesh:SetPos(0, 0, 0)
	WaypointMarkersMeshes[group] = mesh
end
