local cardinal_dirs = {"east", "west", "north", "south"}
local dir_angle = { ["east"] = 90 * 60, ["west"] = 270 * 60, ["south"] = 180 * 60, ["north"] = 0 }

local function GetPlaneDir(plane)
	for _, dir in ipairs(cardinal_dirs) do
		if string.match(plane:lower(), dir) then
			return dir
		end
	end
end

MapVar("s_BorderBuildingAutoAttachesRequired", 0)
MapVar("s_BorderBuildingAutoAttachesCreated", 0)

DefineClass.BorderBuilding = {
	__parents = {"AutoAttachObject", "EditorCallbackObject", "EditorSelectedObject"},
	
	properties = {
		{category = "Windows Auto Attaches", id = "east", name = "East", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "west", name = "West", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "north", name = "North", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "south", name = "South", editor = "bool", default = true, help = "Uncheck to remove window auto attaches from this side"},
		{category = "Windows Auto Attaches", id = "Recalc", editor = "buttons", default = false,
			buttons = {
				{ name = "Recalc Visible Sides", func = function(self)
					self:CalcVisibleSides()
				end},
				{ name = "Turn All Sides ON", func = function(self)
					self:TurnAllSides(true)
				end},
				{ name = "Turn All Sides OFF", func = function(self)
					self:TurnAllSides(false)
				end},
			},
		},
	},
	
	texts = false,
}

function BorderBuilding:ShouldAttach(attach)
	s_BorderBuildingAutoAttachesRequired = s_BorderBuildingAutoAttachesRequired + 1
	
	local spot_ann = self:GetSpotAnnotation(attach.spot_idx)
	if not spot_ann then return true end
	
	local dir = GetPlaneDir(spot_ann)
	if not dir then return true end
	
	return self[dir]
end

function BorderBuilding:OnAttachCreated(attach, spot)
	s_BorderBuildingAutoAttachesCreated = s_BorderBuildingAutoAttachesCreated + 1
	
	if IsKindOfClasses(attach, "WindowTunnelObject", "Door") then
		attach.AttachLight = false
	end
end

function BorderBuilding:UpdateAutoAttaches()
	self:SetAutoAttachMode(self:GetAutoAttachMode())
end

function BorderBuilding:GatherWallWindows()
	local spots_used = {}
	local spots = table.imap(AutoAttachPresets[self.class], function(attach)
		spots_used[attach.name] = true
	end)
	local spots = table.keys(spots_used)
	
	local planes = {}
	local sides = {}
	for _, spot_name in ipairs(spots) do
		local first, last = self:GetSpotRange(spot_name)
		for spot_idx = first, last do
			local spot_pos = self:GetSpotPos(spot_idx)
			local spot_ann = self:GetSpotAnnotation(spot_idx)
			if spot_ann then
				local dir = GetPlaneDir(spot_ann)
				if dir then
					local spot = {pos = spot_pos, name = spot_name, idx = spot_idx}
					planes[spot_ann] = planes[spot_ann] or {dir = dir}
					table.insert(planes[spot_ann], spot)
					sides[dir] = sides[dir] or {}
					table.insert(sides[dir], spot)
				end
			end
		end
	end
	
	return planes, sides
end

function BorderBuilding:CalcVisibleSides()
	local center = GetMapBox():Center()
	local planes, sides = self:GatherWallWindows()
	local side_count = {}
	for plane_name, plane in pairs(planes) do
		local dir = GetPlaneDir(plane_name)
		local angle = self:GetAngle() + dir_angle[dir]
		local plane_norm = Rotate(point(4096, 0), angle)
		local plane_data = side_count[dir] or {total = 0, visible = 0}
		side_count[dir] = plane_data
		plane_data.total = plane_data.total + #plane
		if Dot(center - plane[1].pos, plane_norm) > 0 then
			plane_data.visible = plane_data.visible + #plane			
		end
	end
	
	for dir, side in pairs(side_count) do
		self:SetProperty(dir, side.visible > side.total / 2)
	end
	ObjModified(self)
	
	self:UpdateAutoAttaches()
end

function BorderBuilding:TurnAllSides(state)
	for _, dir in pairs(cardinal_dirs) do
		self:SetProperty(dir, state)
	end
	ObjModified(self)
	self:UpdateAutoAttaches()
end

function BorderBuilding:OnEditorSetProperty(prop_id)
	if table.find(cardinal_dirs, prop_id) then
		self:UpdateAutoAttaches()
	end
end

function BorderBuilding:DelayedRecalcAutoAttaches()
	DelayedCall(500, function(self)
		self:CalcVisibleSides()
		self:UpdateAutoAttaches()
	end, self)
end

BorderBuilding.EditorCallbackMove = BorderBuilding.DelayedRecalcAutoAttaches
BorderBuilding.EditorCallbackRotate = BorderBuilding.DelayedRecalcAutoAttaches
BorderBuilding.EditorCallbackPlace = BorderBuilding.DelayedRecalcAutoAttaches

function BorderBuilding:EditorSelect(selected)
	if selected then
		local center = self:GetPos()
		local high_z = self:GetObjectBBox():sizez() + guim
		local _, sides = self:GatherWallWindows()
		for dir, spots in pairs(sides) do
			local pos = point30
			for _, spot in pairs(spots) do
				pos = pos + spot.pos - center
			end
			pos = (pos / #spots):SetZ(high_z)
			local text = PlaceText(dir:upper(), pos, const.clrGreen)
			self:Attach(text)
			text:SetAttachOffset(pos)
			self.texts = self.texts or {}
			table.insert(self.texts, text)
		end
	elseif self.texts then
		for _, text in ipairs(self.texts) do
			if IsValid(text) then
				text:Detach()
				DoneObject(text)
			end
		end
		self.texts = false
	end
end

function BorderBuildingsRecalcVisibleSides()
	s_BorderBuildingAutoAttachesRequired = 0
	s_BorderBuildingAutoAttachesCreated = 0
	
	local buildings = 0
	MapForEach("map", "BorderBuilding", function(bld)
		buildings = buildings + 1
		bld:CalcVisibleSides()
		bld:UpdateAutoAttaches()
	end)
	
	printf("BorderBuilding(s): %d, Auto Attaches Created/Required: %d/%d(%d%%)", buildings, 
		s_BorderBuildingAutoAttachesCreated, s_BorderBuildingAutoAttachesRequired, 
		100 * s_BorderBuildingAutoAttachesCreated / s_BorderBuildingAutoAttachesRequired)
end

function SelectionBorderBuildingToggleWall(dir)
	for _, obj in ipairs(editor.GetSel() or empty_table) do
		if IsKindOf(obj, "BorderBuilding") then
			obj:SetProperty(dir, not obj:GetProperty(dir))
			obj:UpdateAutoAttaches()
		end
	end
end
