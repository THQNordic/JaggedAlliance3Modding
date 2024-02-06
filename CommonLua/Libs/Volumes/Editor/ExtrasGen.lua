if FirstLoad then
	-- settings taken into account by SelectRoomComponents & PlaceRoomGuides statements, if specified
	ExtrasGenParams = { North = true, South = true, East = true, West = true }
end

function GenExtras(id, initial_selection, seed)
	SuspendPassEdits("GenExtras")
	XEditorUndo:BeginOp{ name = id }
	ExtrasGenPrgs[id](seed, initial_selection)
	XEditorUndo:EndOp()
	ResumePassEdits("GenExtras")
end

DefineClass.ExtrasGen = {
	__parents = { "PrgPreset" },
	
	properties = {
		{ id = "Params", editor = false },
		{ id = "ToolbarSection", editor = "combo", default = "", items = function(self) return PresetsPropCombo("ExtrasGen", "ToolbarSection", "") end, },
		{ id = "Shortcut", editor = "shortcut", default = "", },
		{ id = "Shortcut2", editor = "shortcut", default = "", },
		{ id = "RequiresClass", editor = "choice", default = "", items = { "", "Slab", "EditorLineGuide", "Room" }, },
		{ id = "RequiresGuideType", editor = "choice", default = "", items = { "", "Horizontal", "Vertical" }, },
	},
	
	EditorMenubarName = "ExtrasGen Presets",
	EditorMenubar = "Map",
	EditorShortcut = "Ctrl-Alt-G",
	EditorIcon = "CommonAssets/UI/Icons/atom molecule science.png",
	
	Params = { "initial_selection" },
	StatementTags = { "Basics", "Objects", "ExtrasGen" },
	FuncTable = "ExtrasGenPrgs",
	GlobalMap = "ExtrasGenPresets",
}

function ExtrasGen:GenerateCodeAtFunctionStart(code)
	code:append("\tinitial_selection = initial_selection or editor.GetSel()\n")
	PrgPreset.GenerateCodeAtFunctionStart(self, code)
end

function ExtrasGen.FindPrgStatement(id_or_self, classes, prop_id, value, fn)
	local ret = false
	local prg = IsKindOf(id_or_self, "ExtrasGen") and id_or_self or ExtrasGenPresets[id_or_self]
	if prg then
		prg:ForEachSubObject("PrgStatement", function(obj)
			if IsKindOfClasses(obj, unpack_params(classes)) and (not prop_id or obj[prop_id] == value) and (not fn or fn(obj)) then
				ret = true
			end
		end)
	end	
	return ret
end

function OnMsg.ShortcutsReloaded()
	local directions = { "North", "South", "East", "West" }
	
	local LayDecalsAlongGuide = { "LayDecalsAlongGuide" }
	local PlaceRoomGuides = { "PlaceRoomGuides" }
	local function check_relation(prg1, prg2)
		if prg1.ToolbarSection == "Room" or prg2.ToolbarSection == "Room" then return false end
		return
			prg1:FindPrgStatement(LayDecalsAlongGuide) and prg2:FindPrgStatement(PlaceRoomGuides, "Direction", "Inwards (wall)") or
			prg1.RequiresGuideType == "Horizontal"     and prg2:FindPrgStatement(PlaceRoomGuides, "Direction", "Outwards (room)") or
			prg1.RequiresGuideType == "Vertical"       and prg2:FindPrgStatement(PlaceRoomGuides, "Horizontal", false, function(obj) return obj.PlaceOn:starts_with("Wall") end)
	end
	
	ForEachPreset("ExtrasGen", function(prg)
		if prg.ToolbarSection ~= "" then
			XAction:new({
				ActionId = prg.id,
				ActionName = prg.Shortcut ~= "" and prg.id.."<right><style GedDefault><alpha 156>"..prg.Shortcut or prg.id,
				ActionTranslate = false,
				ActionMode = "Editor",
				ActionToolbar = "EditorRoomTools",
				ActionToolbarSection = prg.ToolbarSection,
				ActionShortcut = prg.Shortcut,
				ActionShortcut2 = prg.Shortcut2,
				RolloverText = prg.Comment,
				ActionState = function(self, host)
					if prg.RequiresClass ~= "" and not editor.IsSelectionKindOf(prg.RequiresClass) or not GetDialog("XEditorRoomTools") then
						return "disabled"
					end
					if prg.RequiresGuideType == "Horizontal" then
						for _, obj in ipairs(editor.GetSel()) do
							if not obj:IsHorizontal() then return "disabled" end
						end
					end
					if prg.RequiresGuideType == "Vertical" then
						for _, obj in ipairs(editor.GetSel()) do
							if not obj:IsVertical() then return "disabled" end
						end	
					end
				end,
				OnAction = function(self, host)
					GenExtras(prg.id)
				end,
				OnAltAction = function(self, host)
					ExtrasGenPresets[prg.id]:OpenEditor()
				end,
				GetRelatedActions = function(self, host) -- these actions get highlighted on rollover
					local related = {}
					for _, action in ipairs(host:GetActions()) do
						local action_prg = ExtrasGenPresets[action.ActionId]
						if action_prg and (check_relation(prg, action_prg) or check_relation(action_prg, prg)) then
							related[#related + 1] = action
						end
					end
					if prg:FindPrgStatement({"PrgSelectRoomComponents", "PlaceRoomGuides"}, "UseParams", true) then
						table.iappend(related, table.map(directions, function(dir) return host:ActionById(dir) end))
					end
					return related
				end,
			}, XShortcutsTarget)
		end
	end)
	
	for _, direction in ipairs(directions) do
		XAction:new({
			ActionId = direction,
			ActionName = direction,
			ActionTranslate = false,
			ActionMode = "Editor",
			ActionToolbar = "EditorRoomWallSelection",
			ActionToolbarSection = "Wall Selection",
			ActionToggle = true,
			ActionToggled = function(self, host)
				return ExtrasGenParams[direction]
			end,
			OnAction = function(self, host)
				ExtrasGenParams[direction] = not ExtrasGenParams[direction]
			end,
			GetRelatedActions = function(self, host)
				local related = {}
				for _, action in ipairs(host:GetActions()) do
					if ExtrasGen.FindPrgStatement(action.ActionId, {"PrgSelectRoomComponents", "PlaceRoomGuides"}, "UseParams", true) then
						related[#related + 1] = action
					end
				end
				return related
			end,
		}, XShortcutsTarget)
	end
	
	XAction:new({
		ActionId = "HoldShiftHelp",
		ActionName = "<center>(hold Shift for half-step)",
		ActionTranslate = false,
		ActionMode = "Editor",
		ActionState = function(self, host) return "disabled" end,
		ActionToolbar = "EditorRoomTools",
		ActionToolbarSection = "Guide Operations",
	}, XShortcutsTarget)
end

function OnMsg.EditorSelectionChanged()
	if GetDialog("XEditorRoomTools") then
		GetDialog("XEditorRoomTools"):ActionsUpdated()
	end
end


----- Common helper functions

local function find_intersecting_slab(obj, class, tolerance)
	local bbox = obj:IsKindOf("Slab") and obj:GetWorldBBox() or obj:GetObjectBBox()
	return MapGetFirst(obj:GetPos(), const.SlabSizeX * 2, class, function(o)
		local bbox2 = o:GetWorldBBox()
		if tolerance then
			bbox2 = bbox2:sizex() > bbox2:sizey() and bbox2:grow(-tolerance, 0, 0) or bbox2:grow(0, -tolerance, 0)
		end
		return o ~= obj and (bbox:Intersect(bbox2) ~= const.irOutside or obj:GetPos():InBox(bbox2))
	end)
end

local function get_wall_thickness(obj)
	local wall_slab =
		obj:IsKindOf("Room") and obj.spawned_walls.North[1] or
		obj:IsKindOf("SlabWallObject") and find_intersecting_slab(obj, "Slab") or
		obj:IsKindOf("Slab") and obj
	return wall_slab and wall_slab:GetEntityBBox():maxx() or 0
end

-- rotates the object so that axis1 before the rotation matches axis2 after the rotation
local function rotate_to_match(obj, axis1, axis2)
	axis1, axis2 = SetLen(axis1, 4096), SetLen(axis2, 4096)
	local axis = Cross(axis1, axis2)
	if axis ~= point30 then
		obj:Rotate(axis, GetAngle(axis1, axis2))
	end
end

local function create_collection(objs)
	XEditorUndo:BeginOp()
	local collection = Collection.Create()
	for _, obj in ipairs(objs) do
		obj:SetCollection(collection)
	end
	XEditorUndo:EndOp{collection}
end


----- Statements

DefineClass.PrgSelectRoomComponents = {
	__parents = { "PrgStatement" },
	properties = {
		{ id = "RoomsVar",  editor = "choice", default = "selected", items = PrgVarsCombo, },
		{ id = "AssignTo",  name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, },
		{ id = "All",       editor = "bool", default = true, },
		{ id = "Walls",     editor = "bool", default = true,  category = "Walls, Windows & Doors", },
		{ id = "Doors",     editor = "bool", default = true,  category = "Walls, Windows & Doors", },
		{ id = "Windows",   editor = "bool", default = true,  category = "Walls, Windows & Doors", },
		{ id = "UseParams", editor = "bool", default = false, category = "Walls, Windows & Doors", help = "Get whether North, South, West and East object should be returned from parameters passed to the ExtrasGen Prg", },
		{ id = "North",     editor = "bool", default = true,  category = "Walls, Windows & Doors", read_only = function(self) return self.UseParams end, },
		{ id = "South",     editor = "bool", default = true,  category = "Walls, Windows & Doors", read_only = function(self) return self.UseParams end, },
		{ id = "East",      editor = "bool", default = true,  category = "Walls, Windows & Doors", read_only = function(self) return self.UseParams end, },
		{ id = "West",      editor = "bool", default = true,  category = "Walls, Windows & Doors", read_only = function(self) return self.UseParams end, },
		{ id = "Corners",   editor = "bool", default = true, category = "Corners", },
		{ id = "CornersNW", editor = "bool", default = true, category = "Corners", },
		{ id = "CornersSW", editor = "bool", default = true, category = "Corners", },
		{ id = "CornersNE", editor = "bool", default = true, category = "Corners", },
		{ id = "CornersSE", editor = "bool", default = true, category = "Corners", },
		{ id = "Roof",      editor = "bool", default = true, },
		{ id = "Floors",    editor = "bool", default = true, },
		{ id = "FloorMin",  editor = "number", default =  1, min = 1, max = 10, category = "Floor Range", },
		{ id = "FloorMax",  editor = "number", default = 10, min = 1, max = 10, category = "Floor Range", },
	},
	EditorName = "Select room components",
	EditorView = Untranslated("Select <ComponentsText><FloorsText> (of rooms in '<RoomsVar>')<DirectionsText>"),
	EditorSubmenu = "Objects",
	StatementTag = "ExtrasGen",
}

function PrgSelectRoomComponents:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "All" then
		self.Walls = self.All
		self.Corners = self.All
		self.Roof = self.All
		self.Floors = self.All
		self.Doors = self.All
		self.Windows = self.All
	end
	if prop_id == "All" or prop_id == "Corners" then
		self.CornersNW = self.Corners
		self.CornersSW = self.Corners
		self.CornersNE = self.Corners
		self.CornersSE = self.Corners
	end
	self.Corners = self.CornersNW and self.CornersSW and self.CornersNE and self.CornersSE
	self.All = self.Walls and self.Corners and self.Roof and self.Floors and self.Doors and self.Windows
	GedForceUpdateObject(self)
end

function PrgSelectRoomComponents:GetComponentsText()
	local walls = self.North and self.South and self.East and self.West
	local corners = self.CornersNW and self.CornersSW and self.CornersNE and self.CornersSE
	local all = walls and corners and self.Roof and self.Floors and self.Doors and self.Windows
	if all then return "all components" end
	
	local texts = {}
	if corners then
		texts[#texts + 1] = "Corners"
	else
		for _, v in ipairs({ "CornersNW", "CornersSW", "CornersNE", "CornersSE" }) do
			texts[#texts + 1] = self[v] and v or nil
		end
	end
	for _, v in ipairs({ "Roof", "Floors", "Walls", "Doors", "Windows" }) do
		texts[#texts + 1] = self[v] and v or nil
	end
	return table.concat(texts, ", ")
end

function PrgSelectRoomComponents:GetFloorsText()
	if self.FloorMin == PrgSelectRoomComponents.FloorMin and self.FloorMax == PrgSelectRoomComponents.FloorMax then
		return ""
	end
	return string.format(", floors %s - %s", self.FloorMin, self.FloorMax)
end

function PrgSelectRoomComponents:GetDirectionsText()
	if self.UseParams then
		return "\n--> get directions for walls/doors/windows from params"
	end
	local texts = {}
	for _, v in ipairs({ "North", "South", "East", "West" }) do
		texts[#texts + 1] = self[v] and v or nil
	end
	return "\n--> only " .. table.concat(texts, ", ") .. " walls/doors/windows"
end

function PrgSelectRoomComponents.Get(room, component, North, South, East, West)
	if     component == "CornersNW" then return room.spawned_corners.North
	elseif component == "CornersSW" then return room.spawned_corners.West
	elseif component == "CornersNE" then return room.spawned_corners.East
	elseif component == "CornersSE" then return room.spawned_corners.South
	elseif component == "Roof"      then return room.roof_objs
	elseif component == "Floors"    then return room.spawned_floors
	elseif component == "Walls" and room.spawned_walls.North then
		local objs = {}
		if North then table.iappend(objs, room.spawned_walls.North) end
		if South then table.iappend(objs, room.spawned_walls.South) end
		if East  then table.iappend(objs, room.spawned_walls.East) end
		if West  then table.iappend(objs, room.spawned_walls.West) end
		return objs
	elseif component == "Doors" and room.spawned_doors then
		local objs = {}
		if North then table.iappend(objs, room.spawned_doors.North) end
		if South then table.iappend(objs, room.spawned_doors.South) end
		if East  then table.iappend(objs, room.spawned_doors.East) end
		if West  then table.iappend(objs, room.spawned_doors.West) end
		return objs
	elseif component == "Windows" and room.spawned_windows then
		local objs = {}
		if North then table.iappend(objs, room.spawned_windows.North) end
		if South then table.iappend(objs, room.spawned_windows.South) end
		if East  then table.iappend(objs, room.spawned_windows.East) end
		if West  then table.iappend(objs, room.spawned_windows.West) end
		return objs
	end
end

function PrgSelectRoomComponents.Add(room, component, floor_min, floor_max, objs, North, South, East, West)
	for _, obj in ipairs(PrgSelectRoomComponents.Get(room, component, North, South, East, West) or empty_table) do
		if obj and obj.floor >= floor_min and obj.floor <= floor_max then
			objs[#objs + 1] = obj
		end
	end
end

function PrgSelectRoomComponents:GenerateCode(code, indent)
	code:appendf("%slocal __sel = %s\n", indent, self.RoomsVar)
	if self.RoomsVar == self.AssignTo then
		code:appendf("%s%s = {}\n", indent, self.AssignTo)
	else
		local var_exists = self:VarsInScope()[self.AssignTo]
		if var_exists then
			code:appendf("%s%s = %s or {}\n", indent, self.AssignTo, self.AssignTo)
		else
			code:appendf("%slocal %s = {}\n", indent, self.AssignTo)
		end
	end
	code:appendf("%sfor _, obj in ipairs(__sel) do\n", indent)
	code:appendf("%s\tif IsKindOf(obj, \"Room\") then\n", indent)
	for _, component in ipairs({ "CornersNW", "CornersSW", "CornersNE", "CornersSE", "Roof", "Floors", "Walls", "Doors", "Windows" }) do
		if self[component] then
			code:appendf("%s\t\tPrgSelectRoomComponents.Add(obj, \"%s\", %d, %d, %s, %s, %s, %s, %s)\n",
				indent, component, self.FloorMin, self.FloorMax, self.AssignTo,
				self.UseParams and "ExtrasGenParams.North" or tostring(self.North),
				self.UseParams and "ExtrasGenParams.South" or tostring(self.South),
				self.UseParams and "ExtrasGenParams.East"  or tostring(self.East),
				self.UseParams and "ExtrasGenParams.West"  or tostring(self.West))
		end
	end
	code:appendf("%s\tend\n", indent)
	code:appendf("%send\n", indent)
end

function PrgSelectRoomComponents:GatherVars(vars)
	vars[self.AssignTo] = "local"
end


----- Modify objects

DefineClass.PrgModifyObjOrList = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
	},
	ExtraParams = { "rand" },
	EditorView = Untranslated("<EditorName> '<Variable>'"),
	EditorSubmenu = "Modify",
	StatementTag = "ExtrasGen",
}

function PrgModifyObjOrList.Modify(obj, ...)
	-- implement code to modify a single object here
end

function PrgModifyObjOrList:Exec(rand, Variable, ...)
	if IsKindOf(Variable, "Object") then
		local objs = { Variable }
		XEditorUndo:BeginOp{ objects = objs }
		self.Modify(rand, Variable, ...)
		XEditorUndo:EndOp(objs)
	else
		XEditorUndo:BeginOp{ objects = Variable }
		for _, obj in ipairs(Variable or empty_table) do
			self.Modify(rand, obj, ...)
		end
		XEditorUndo:EndOp(Variable)
	end
end


local default_color = RGB(200, 200, 200)

DefineClass.PrgColorize = {
	__parents = { "PrgModifyObjOrList" },
	properties = {
		{ id = "Reset1", name = "Reset color 1", editor = "bool", default = false, },
		{ id = "Color1", name = "Modify color 1", editor = "color", default = default_color, alpha = false, },
		{ id = "Reset2", name = "Reset color 2", editor = "bool", default = false, },
		{ id = "Color2", name = "Modify color 2", editor = "color", default = default_color, alpha = false, },
		{ id = "Reset3", name = "Reset color 3", editor = "bool", default = false, },
		{ id = "Color3", name = "Modify color 3", editor = "color", default = default_color, alpha = false, },
		{ id = "Reset4", name = "Reset color 4", editor = "bool", default = false, },
		{ id = "Color4", name = "Modify color 4", editor = "color", default = default_color, alpha = false, },
	},
	EditorName = "Colorize",
}

function PrgColorize.Modify(rand, obj, Reset1, Color1, Reset2, Color2, Reset3, Color3, Reset4, Color4)
	local slab
	if obj:IsKindOf("Slab") then
		if not obj.colors then
			obj.colors = ColorizationPropSet:new()
		end
		slab = obj
		obj = obj.colors
	end
	obj:SetEditableColor1(Reset1 and Color1 or InterpolateRGB(obj:GetEditableColor1(), Color1, 1, 2))
	obj:SetEditableColor2(Reset2 and Color2 or InterpolateRGB(obj:GetEditableColor2(), Color2, 1, 2))
	obj:SetEditableColor3(Reset3 and Color3 or InterpolateRGB(obj:GetEditableColor3(), Color3, 1, 2))
	if slab then
		slab:SetProperty("colors", obj)
	end
end

DefineClass.PrgScale = {
	__parents = { "PrgModifyObjOrList" },
	properties = {
		{ id = "Reset", editor = "bool", default = false, },
		{ id = "Scale", editor = "number", default = 100, scale = "%", min = 10, max = 250, slider = true },
		{ id = "Deviation", editor = "number", default = 0, min = 0, max = 250, slider = true },
	},
	EditorName = "Scale",
}

function PrgScale.Modify(rand, obj, Reset, Scale, Deviation)
	local scale = Scale + rand(Deviation * 2 + 1) - Deviation
	obj:SetScale(Reset and scale or MulDivRound(obj:GetScale(), scale, 100))
end

DefineClass.PrgOffset = {
	__parents = { "PrgModifyObjOrList" },
	properties = {
		{ id = "Local", "Local coordinates", editor = "bool", default = true, },
		{ id = "X",  "X offset",    editor = "number", default = 0, scale = "m", },
		{ id = "Xd", "X deviation", editor = "number", default = 0, scale = "m", },
		{ id = "Y",  "Y offset",    editor = "number", default = 0, scale = "m", },
		{ id = "Yd", "Y deviation", editor = "number", default = 0, scale = "m", },
		{ id = "Z",  "Z offset",    editor = "number", default = 0, scale = "m", },
		{ id = "Zd", "Z deviation", editor = "number", default = 0, scale = "m", },
	},
	EditorName = "Offset",
}

function PrgOffset.Modify(rand, obj, Local, X, Xd, Y, Yd, Z, Zd)
	local x = X + rand(Xd * 2 + 1) - Xd
	local y = Y + rand(Yd * 2 + 1) - Yd
	local z = Z + rand(Zd * 2 + 1) - Zd
	local offset = point(x, y, z)
	obj:SetPos(Local and obj:GetRelativePoint(offset) or (obj:GetPos() + offset))
end

DefineClass.PrgRotate = {
	__parents = { "PrgModifyObjOrList" },
	properties = {
		{ id = "Reset", editor = "bool", default = false, },
		{ id = "Local", "Local coordinates", editor = "bool", default = true, no_edit = function(self) return self.Reset end, },
		{ id = "Axis", editor = "point", default = axis_z, },
		{ id = "Angle", editor = "number", default = 0, scale = "deg", min = 0, max = 360 * 60, slider = true },
		{ id = "Deviation", editor = "number", default = 0, scale = "deg", min = 0, max = 180 * 60, slider = true },
	},
	EditorName = "Rotate",
}

function PrgRotate.Modify(rand, obj, Reset, Local, Axis, Angle, Deviation)
	local angle = Angle + rand(Deviation * 2 + 1) - Deviation
	local axis = Local and not Reset and (obj:GetRelativePoint(Axis) - obj:GetPos()) or Axis
	if Reset then
		obj:SetAxisAngle(axis, angle)
	else
		obj:SetAxisAngle(ComposeRotation(obj:GetAxis(), obj:GetAngle(), axis, angle))
	end
end

DefineClass.PrgAlign = {
	__parents = { "PrgModifyObjOrList" },
	properties = {
		{ id = "AlignTo", name = "Align to", editor = "choice", default = "Wall exterior",
		  items = { "Wall exterior", "Wall interior", "Wall top", "Wall bottom", "Roof", "Floor" } },
	},
	EditorName = "Align",
}

function PrgAlign:GetEditorView()
	return string.format("Align '%s' to '%s'", self.Variable, self.AlignTo:lower())
end

local wall_data = {
	{ coord = "x", box_member = "minx", setter = "SetX", axis = -axis_x, angle = 0 },
	{ coord = "x", box_member = "maxx", setter = "SetX", axis =  axis_x, angle = 180 * 60 },
	{ coord = "y", box_member = "miny", setter = "SetY", axis = -axis_y, angle = 90 * 60 },
	{ coord = "y", box_member = "maxy", setter = "SetY", axis =  axis_y, angle = -90 * 60 },
}

function PrgAlign.Modify(rand, obj, AlignTo)
	if not obj.room then return end
	
	local room_box = obj.room.box
	obj:ClearGameFlags(const.gofOnRoof)
	if AlignTo == "Roof" then
		obj.room:SnapObject(obj)
	elseif AlignTo == "Floor" then
		local x, y, z = obj:GetPosXYZ()
		obj:SetPos(x, y, room_box:minz())
		obj:SetAxisAngle(axis_z, 0)
	elseif AlignTo:starts_with("Wall") then
		-- find nearest wall
		local pos = obj:GetPos()
		local min_dist, min_wall
		for i, wall in ipairs(wall_data) do
			local dist = abs(pos[wall.coord](pos) - room_box[wall.box_member](room_box))
			if not min_dist or min_dist > dist then
				min_wall, min_dist = wall, dist
			end
		end
		
		-- snap to that wall
		pos = pos[min_wall.setter](pos, room_box[min_wall.box_member](room_box))
		if AlignTo == "Wall bottom" then
			local bbox = obj:GetEntityBBox()
			pos = pos:SetZ(room_box:minz())
		elseif AlignTo == "Wall top" then
			local bbox = obj:GetEntityBBox()
			pos = pos:SetZ(room_box:maxz())
		elseif AlignTo == "Wall interior" then
			pos = pos - SetLen(min_wall.axis, get_wall_thickness(obj.room))
		elseif AlignTo == "Wall exterior" then
			pos = pos + SetLen(min_wall.axis, get_wall_thickness(obj.room))
		end
		obj:SetPos(pos)
		obj:SetOrientation(min_wall.axis, min_wall.angle)
	end
end


----- Place objects

DefineClass.PlaceObjectData = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "EditorClass", editor = "choice", default = "", items = function() return XEditorPlaceableObjectsCombo end, },
		{ id = "Weight", editor = "number", default = 100, min = 1, max = 100, slider = true },
		{ id = "Scale", name = "Scale", editor = "number", default = 100, min = 10, max = 250, slider = true, },
		{ id = "Rotate", name = "Rotate", editor = "number", scale = "deg", default = 0, },
		{ id = "Mirror", editor = "bool", default = false, },
	},
	EditorView = Untranslated("<EditorClass> (<Weight>)"),
	StoreAsTable = true,
}

function PlaceObjectData.FormatList(list)
	local classes = {}
	for _, item in ipairs(list or empty_table) do
		classes[#classes + 1] = string.format("%s (%d)", item.EditorClass, item.Weight)
	end
	return table.concat(classes, ", ")
end

function PlaceObjectData.PlaceRandomObject(rand, list, pos, angle, axis, scale)
	local data = table.weighted_rand(list, "Weight", rand())
	local obj = XEditorPlaceObject(data.EditorClass)
	obj:SetGameFlags(const.gofPermanent)
	if IsKindOf(obj, "AlignedObj") then
		obj:AlignObj(pos, (angle or 0) + data.Rotate) -- axis ignored for aligned objects
	else
		obj:SetPos(pos)
		local axis, angle = axis or axis_z, angle or 0
		if data.Rotate ~= 0 then
			axis, angle = ComposeRotation(axis_z, data.Rotate, axis, angle)
		end
		obj:SetAxisAngle(axis, angle)
	end
	obj:SetScale(MulDivRound(data.Scale, scale or 100, 100))
	obj:SetMirrored(data.Mirror)
	return obj, data
end


DefineClass.PrgPlaceObject = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "Classes", editor = "nested_list", default = false, class = "PlaceObjectData" },
		{ id = "AlignTo", name = "Align to", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
		{ id = "Store", editor = "choice", default = "", items = { "", "Add to", "Assign to" }, },
		{ id = "AssignTo", name = "Variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true,
		  no_edit = function(obj) return obj.Store == "" end, },
	},
	ExtraParams = { "rand" },
	EditorName = "Place object",
	EditorSubmenu = "Objects",
	StatementTag = "ExtrasGen",
}

function PrgPlaceObject:GetEditorView()
	local ret = "Place object " .. PlaceObjectData.FormatList(self.Classes)
	if self.AlignTo ~= "" then
		ret = ret .. string.format("\n--> Align to '%s'", self.AlignTo)
	end
	if self.Store ~= "" then
		ret = ret .. string.format("\n--> %s variable '%s'", self.Store, self.AssignTo)
	end
	return ret
end

function PrgPlaceObject:Exec(rand, Classes, AlignTo, Store, AssignTo)
	if not next(Classes) then return end

	local obj
	XEditorUndo:BeginOp()
	if AlignTo then
		obj = PlaceObjectData.PlaceRandomObject(rand, Classes, AlignTo:GetPos(), AlignTo:GetAngle(), AlignTo:GetAxis(), AlignTo:GetScale())
		rawset(obj, "room", rawget(AlignTo, "room"))
	else
		obj = PlaceObjectData.PlaceRandomObject(rand, Classes)
	end
	Msg("EditorCallback", "EditorCallbackPlace", {obj})
	XEditorUndo:EndOp{obj}
	
	if Store == "Assign to" then
		return obj -- the code generated by PrgExec will assign this to the AssignTo variable
	elseif Store == "Add to" then
		local objs = IsKindOf(AssignTo, "Object") and { AssignTo } or AssignTo or {}
		objs[#objs + 1] = obj
		return objs -- see above
	end
end


----- Placing, moving, deleting guides (EditorLineGuide objects)

local not_on_wall = function(obj) return not obj.PlaceOn:starts_with("Wall") end

DefineClass.PlaceRoomGuides = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "RoomsVar", name = "Rooms variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ category = "Input/output", id = "AssignTo", name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
		{ category = "Placement", id = "PlaceOn", name = "Place on", editor = "choice", default = "Wall exterior", items = { "Wall exterior", "Wall interior", "Floor", "Roof" }, },
		{ category = "Placement", id = "UseParams", editor = "bool", default = false, no_edit = not_on_wall, help = "Get whether North, South, West and East object should be returned from parameters passed to the ExtrasGen Prg" }, 
		{ category = "Placement", id = "North",     editor = "bool", default = true,  no_edit = not_on_wall, read_only = function(self) return self.UseParams end, },
		{ category = "Placement", id = "South",     editor = "bool", default = true,  no_edit = not_on_wall, read_only = function(self) return self.UseParams end, },
		{ category = "Placement", id = "East",      editor = "bool", default = true,  no_edit = not_on_wall, read_only = function(self) return self.UseParams end, },
		{ category = "Placement", id = "West",      editor = "bool", default = true,  no_edit = not_on_wall, read_only = function(self) return self.UseParams end, },
		{ category = "Placement", id = "Horizontal", editor = "bool", default = true, },
		{ category = "Placement", id = "StartFrom", name = "Start from", editor = "choice", default = "Both",
			items = function(obj) return obj.Horizontal and { "Top", "Bottom", "Middle", "Both" } or { "Left", "Right", "Middle", "Both" } end,
		},
		{ category = "Placement", id = "Count", editor = "number", default = 1, },
		{ category = "Placement", id = "FirstOffset", name = "First offset (slabs)", editor = "number", default = 0,
			scale = function(obj) return obj.Horizontal and const.SlabSizeX or const.SlabSizeZ end,
		},
		{ category = "Placement", id = "DiminishOffset", name = "Diminish offset", editor = "number", default = 0, min = 0, max = 100, scale = "%" },
		{ category = "Placement", id = "Direction", editor = "choice", default = "Inwards (wall)",
			items = { "Inwards (wall)", "Outwards (wall)", "Inwards (room)", "Outwards (room)" },
			read_only = function(self) return self.PlaceOn == "Floor" or self.PlaceOn == "Roof" end,
		},
	},
	EditorName = "Place room guides", -- Places horizontal & vertical guides along room features
	EditorSubmenu = "Guides",
	StatementTag = "ExtrasGen",
}

function PlaceRoomGuides:GetEditorView()
	local ret = string.format("Place %s %s guides on room %s:", self.Count, self.Horizontal and "horizontal" or "vertical", self.PlaceOn:lower())
	
	ret = ret .. string.format("\n--> To rooms in variable '%s'", self.RoomsVar)
	ret = ret .. string.format("\n--> Starting from %s", self.StartFrom)
	
	local size = (self.Horizontal and const.SlabSizeX or const.SlabSizeZ) * 1.0
	if self.FirstOffset ~= 0    then ret = ret .. string.format(", first offset %0.1f", self.FirstOffset / size) end
	if self.DiminishOffset ~= 0 then ret = ret .. string.format(", diminish by %d%%", self.DiminishOffset) end
	
	ret = ret .. string.format("\n--> Direction = %s", self.Direction)
	
	if self.AssignTo ~= ""      then ret = ret .. string.format("\n--> Add to variable '%s'", self.AssignTo) end
	return ret
end

function PlaceRoomGuides:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "PlaceOn" and (self.PlaceOn == "Floor" or self.PlaceOn == "Roof") then
		self.Direction = "Inwards (wall)"
	end
end

-- expects the start/end points of the edge that corresponds to Right or Top
function PlaceRoomGuides.OnWall(room, objs, edge_pt1, edge_pt2, along_vec, room_inward_vec,
	Horizontal, StartFrom, Count, FirstOffset, DiminishOffset, Direction, skip_first
)
	if Horizontal then
		local along = edge_pt1 - edge_pt2 
		edge_pt1 = edge_pt2
		edge_pt2 = edge_pt2 + along_vec
		along_vec = along
	end
	
	if StartFrom ~= "Right" and StartFrom ~= "Top" then
		local params = { room_inward_vec, false, "Right", Count, FirstOffset, DiminishOffset, Direction }
		if StartFrom == "Left" or StartFrom == "Bottom" then
			PlaceRoomGuides.OnWall(room, objs, edge_pt1 + along_vec, edge_pt2 + along_vec, -along_vec, unpack_params(params))
		elseif StartFrom == "Middle" then
			PlaceRoomGuides.OnWall(room, objs, edge_pt1 + along_vec / 2, edge_pt2 + along_vec / 2, along_vec, unpack_params(params))
			table.insert(params, "skip_first")
			PlaceRoomGuides.OnWall(room, objs, edge_pt1 + along_vec / 2, edge_pt2 + along_vec / 2, -along_vec, unpack_params(params))
		elseif StartFrom == "Both" then
			PlaceRoomGuides.OnWall(room, objs, edge_pt1, edge_pt2, along_vec, unpack_params(params))
			PlaceRoomGuides.OnWall(room, objs, edge_pt1 + along_vec, edge_pt2 + along_vec, -along_vec, unpack_params(params))
		end
		return
	end
	
	local normal =
		Direction == "Inwards (wall)"  and  along_vec or
		Direction == "Outwards (wall)" and -along_vec or
		Direction == "Inwards (room)"  and  room_inward_vec or
		Direction == "Outwards (room)" and -room_inward_vec
	local pt1, pt2 = edge_pt1, edge_pt2
	local offset, offset_add = FirstOffset, FirstOffset
	for i = 1, Count do
		local offset_vec = SetLen(along_vec, offset)
		pt1 = pt1 + offset_vec
		pt2 = pt2 + offset_vec
		offset_add = MulDivRound(offset_add, 100 - DiminishOffset, 100)
		offset = offset + offset_add
		if not (skip_first and i == 1 and FirstOffset == 0) then
			local guide = EditorLineGuide:new()
			guide:Set(pt1, pt2, normal)
			objs[#objs + 1] = guide
		end
	end
end

function PlaceRoomGuides:Exec(RoomsVar, AssignTo, PlaceOn, UseParams, North, South, East, West, Horizontal, ...)
	local objs = {}
	RoomsVar = IsKindOf(RoomsVar, "Object") and { RoomsVar } or RoomsVar
	for _, room in ipairs(RoomsVar or empty_table) do
		if PlaceOn:starts_with("Wall") then
			local size = PlaceOn:ends_with("interior") and -get_wall_thickness(room) or get_wall_thickness(room)
			local room_box = GrowBox(room.box, size, size, 0)
			local x1, y1, z1, x2, y2, z2 = room_box:xyzxyz()
			if UseParams and ExtrasGenParams.North or not UseParams and North then
				PlaceRoomGuides.OnWall(room, objs, point(x1, y1, z1), point(x1, y1, z2), point(x2 - x1, 0, 0), point(0, y2 - y1, 0), Horizontal, ...)
			end
			if UseParams and ExtrasGenParams.East or not UseParams and East then
				PlaceRoomGuides.OnWall(room, objs, point(x2, y1, z1), point(x2, y1, z2), point(0, y2 - y1, 0), point(x1 - x2, 0, 0), Horizontal, ...)
			end
			if UseParams and ExtrasGenParams.South or not UseParams and South then
				PlaceRoomGuides.OnWall(room, objs, point(x2, y2, z1), point(x2, y2, z2), point(x1 - x2, 0, 0), point(0, y1 - y2, 0), Horizontal, ...)
			end
			if UseParams and ExtrasGenParams.West or not UseParams and West then
				PlaceRoomGuides.OnWall(room, objs, point(x1, y2, z1), point(x1, y2, z2), point(0, y1 - y2, 0), point(x2 - x1, 0, 0), Horizontal, ...)
			end
		elseif PlaceOn == "Floor" or PlaceOn == "Roof" then
			local x1, y1, z1, x2, y2, z2 = room.box:xyzxyz()
			local z = PlaceOn == "Floor" and z1 or z2
			local inwards_vec = PlaceOn == "Floor" and point(0, 0, z2 - z1) or point(0, 0, z1 - z2)
			local first_idx = #objs + 1
			if room.roof_direction == "North-South" or room.roof_direction == "East" or room.roof_direction == "West" then
				PlaceRoomGuides.OnWall(room, objs, point(x1, y1, z), point(x2, y1, z), point(0, y2 - y1, 0), inwards_vec, Horizontal, ...)
			else
				PlaceRoomGuides.OnWall(room, objs, point(x1, y1, z), point(x1, y2, z), point(x2 - x1, 0, 0), inwards_vec, Horizontal, ...)
			end
			if PlaceOn == "Roof" then
				if room.roof_type == "Gable" then
					if not Horizontal then
						-- split each guide into two parts, one for each slope of the roof
						for i = first_idx, #objs do
							local old = objs[i]
							local new = EditorLineGuide:new()
							new:Set(old:GetPos1(), old:GetPos(), old:GetNormal())
							objs[i] = new
							new = EditorLineGuide:new()
							new:Set(old:GetPos(), old:GetPos2(), old:GetNormal())
							objs[#objs + 1] = new
							old:delete()
						end
					else
						-- duplicate the guide in the middle (if it exists) into two guides in opposite directions
						for i = first_idx, #objs do
							local old = objs[i]
							if old:GetPos():Dist2D(room:GetPos()) < 5 * guic and Dot(old:GetNormal(), axis_z) == 0 then
								local new = EditorLineGuide:new()
								new:Set(old:GetPos1(), old:GetPos2(), -old:GetNormal())
								objs[#objs + 1] = new
								break
							end
						end
					end
				end
				
				-- adjust each guide to match the slope of the roof
				for i = first_idx, #objs do
					local guide = objs[i]
					
					local pt, pt1, pt2 = guide:GetPos(), guide:GetPos1(), guide:GetPos2()
					local z1, z2 = room:GetRoofZAndDir(pt1), room:GetRoofZAndDir(pt2)
					pt1, pt2 = pt1:SetZ(z1), pt2:SetZ(z2)
					
					local normal_start, normal_end = pt1, pt1 + SetLen(guide:GetNormal(), const.SlabSizeX * 2)
					local normal_end_z = room:GetRoofZAndDir(normal_end)
					normal_end = normal_end:SetZ(normal_end_z)
					
					guide:Set(pt1, pt2, normal_end - normal_start)
				end
			end
		end
	end
	
	create_collection(objs)
	XEditorUndo:BeginOp()
	XEditorUndo:EndOp(objs)
	return table.iappend(AssignTo or {}, objs)
end

DefineClass.PlaceGuidesAroundSlabs = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "SlabsVar", name = "Slabs variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ category = "Input/output", id = "AssignTo", name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
		{ category = "Placement", id = "Top", editor = "bool", default = false, },
		{ category = "Placement", id = "Bottom", editor = "bool", default = true, },
		{ category = "Placement", id = "Left", editor = "bool", default = false, },
		{ category = "Placement", id = "Right", editor = "bool", default = false, },
		{ category = "Placement", id = "OnExterior", name = "On exterior wall", editor = "bool", default = true, },
		{ category = "Placement", id = "OrientOutwards", name = "Orient outwards", editor = "bool", default = false, },
	},
	EditorName = "Place guides around slabs", -- Places guides along edges of a slab / window / door
	EditorSubmenu = "Guides",
	StatementTag = "ExtrasGen",
}

function PlaceGuidesAroundSlabs:GetEditorView()
	local dirs = {}
	if self.Top    then dirs[#dirs + 1] = "top"    end
	if self.Bottom then dirs[#dirs + 1] = "bottom" end
	if self.Left   then dirs[#dirs + 1] = "left"   end
	if self.Right  then dirs[#dirs + 1] = "right"  end

	local ret = string.format("Place guides at %s of slabs in '%s'", table.concat(dirs, ", "), self.SlabsVar)
	if self.OnExterior     then ret = ret .. "\n--> On exterior wall" else ret = ret .. "\n--> On interior wall" end
	if self.AssignTo ~= "" then ret = ret .. string.format("\n--> Add to variable '%s'", self.AssignTo) end
	return ret
end

function PlaceGuidesAroundSlabs.CreateGuide(obj, pt1_local, pt2_local, axis_local, objs)
	local pt1 = obj:GetRelativePoint(pt1_local)
	local pt2 = obj:GetRelativePoint(pt2_local)
	local normal = obj:GetRelativePoint(axis_local) - obj:GetVisualPos()

	local guide = EditorLineGuide:new()
	guide:Set(pt1, pt2, normal)
	objs[#objs + 1] = guide
end

function PlaceGuidesAroundSlabs:Exec(SlabsVar, AssignTo, Top, Bottom, Left, Right, OnExterior, OrientOutwards)
	local objs = {}
	for _, obj in ipairs(SlabsVar or empty_table) do
		local bbox = obj:GetEntityBBox()
		local minx, miny, minz, maxx, maxy, maxz = bbox:xyzxyz()
		local size = OnExterior and get_wall_thickness(obj) or -get_wall_thickness(obj)
		local create_fn = PlaceGuidesAroundSlabs.CreateGuide
		local slab_axis = OnExterior and axis_x or -axis_x
		if Top    then create_fn(obj, point(size, miny, maxz), point(size, maxy, maxz), OrientOutwards and slab_axis or  axis_z, objs) end
		if Bottom then create_fn(obj, point(size, miny, minz), point(size, maxy, minz), OrientOutwards and slab_axis or -axis_z, objs) end
		if Left   then create_fn(obj, point(size, maxy, minz), point(size, maxy, maxz), OrientOutwards and slab_axis or  axis_y, objs) end
		if Right  then create_fn(obj, point(size, miny, minz), point(size, miny, maxz), OrientOutwards and slab_axis or -axis_y, objs) end
	end
	
	create_collection(objs)
	XEditorUndo:BeginOp()
	XEditorUndo:EndOp(objs)
	return table.iappend(AssignTo or {}, objs)
end

DefineClass.PlaceGuidesBetweenSlabs = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "SlabsVar", name = "Slabs variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ category = "Input/output", id = "AssignTo", name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
	},
	EditorName = "Place guides between slabs",
	EditorView = Untranslated("Place guides between each two slabs from <SlabsVar> in '<AssignTo>'"),
	EditorSubmenu = "Guides",
	StatementTag = "ExtrasGen",
}

function PlaceGuidesBetweenSlabs:Exec(SlabsVar, AssignTo, Top, Bottom, Left, Right, OnExterior, OrientOutwards)
	local slabs = table.copy(SlabsVar or empty_table)
	if #slabs < 2 then
		print("Please select 2 or more slabs.")
		return
	end
	table.sort(slabs, function(a, b)
		local ax, ay = a:GetPos():xy()
		local bx, by = b:GetPos():xy()
		if ax == bx then return ay < by end
		return ax < bx
	end)
	
	local function slab_snap_x(x) return (x + const.SlabSizeX / 2) / const.SlabSizeX * const.SlabSizeX end
	local function slab_snap_y(y) return (y + const.SlabSizeY / 2) / const.SlabSizeY * const.SlabSizeY end
	local function slab_snap_z(z) return (z + const.SlabSizeZ / 2) / const.SlabSizeZ * const.SlabSizeZ end

	local objs = {}
	for i = 1, #slabs - 1 do
		local obj = EditorLineGuide:new()
		local o1, o2 = slabs[i], slabs[i + 1]
		local p1, p2 = o1:GetPos(), o2:GetPos()
		local b1, b2 = o1:GetWorldBBox(), o2:GetWorldBBox()
		local dx, dy, dz = p2:x() - p1:x(), p2:y() - p1:y(), abs(p2:z() - p1:z())
		local normal = o1:GetRelativePoint(axis_x) - p1
		if dx >= dy and dx >= dz then -- x diff is largest
			local x = (b1:maxx() + b2:minx()) / 2
			local y = (p1:y() + p2:y()) / 2
			local z1, z2 = Min(b1:minz(), b2:minz()), Max(b1:maxz(), b2:maxz())
			obj:Set(point(x, y, slab_snap_z(z1)), point(x, y, slab_snap_z(z2)), normal)
		elseif dy >= dx and dy >= dz then -- y diff is largest
			local x = (p1:x() + p2:x()) / 2
			local y = (b1:maxy() + b2:miny()) / 2
			local z1, z2 = Min(b1:minz(), b2:minz()), Max(b1:maxz(), b2:maxz())
			obj:Set(point(x, y, slab_snap_z(z1)), point(x, y, slab_snap_z(z2)), normal)
		else
			local z = p1:z() > p2:z() and (b1:minz() + b2:maxz()) / 2 or (b2:minz() + b1:maxz()) / 2
			local x1, x2 = Min(b1:minx(), b2:minx()), Max(b1:maxx(), b2:maxx())
			local y1, y2 = Min(b1:miny(), b2:miny()), Max(b1:maxy(), b2:maxy())
			if abs(x1 - x2) > abs(y1 - y2) then
				obj:Set(point(slab_snap_x(x1), p1:y(), z), point(slab_snap_x(x2), p1:y(), z), normal)
			else
				obj:Set(point(p1:x(), slab_snap_y(y1), z), point(p1:x(), slab_snap_y(y2), z), normal)
			end
		end
		objs[#objs + 1] = obj
	end
	
	create_collection(objs)
	XEditorUndo:BeginOp()
	XEditorUndo:EndOp(objs)
	return table.iappend(AssignTo or {}, objs)
end

DefineClass.RemoveRoomGuides = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "RoomsVar", name = "Rooms variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
	},
	EditorName = "Remove room guides",
	EditorSubmenu = "Guides",
	StatementTag = "ExtrasGen",
}

function RemoveRoomGuides:Exec(RoomsVar)
	local objs = {}
	for _, room in ipairs(RoomsVar or empty_table) do
		for _, guide in ipairs(MapGet(GrowBox(room.box, const.SlabSizeX / 2), "EditorLineGuide")) do
			objs[#objs + 1] = guide
		end
	end
	XEditorUndo:BeginOp{ objects = objs }
	for _, obj in ipairs(objs) do obj:delete() end
	XEditorUndo:EndOp()
end

local slab_move_units = {
	{ text = "Meters", value = "m" },
	{ text = "Slabs (auto detect direction)", value = 1 },
	{ text = "Horizontal slabs", value = const.SlabSizeX },
	{ text = "Vertical slabs", value = const.SlabSizeZ },
}

DefineClass.MoveSizeGuides = {
	__parents = { "PrgExec" },
	properties = {
		{ id = "GuidesVar", name = "Guides variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ id = "UpDownScale", name = "Up / down scale", editor = "choice", default = "m", items =
		  { { text = "Meters", value = "m" }, { text = "Vertical slabs", value = const.SlabSizeZ }, }, },
		{ id = "UpDown", name = "Up / down", editor = "number", default = 0, scale = function(self) return self.UpDownScale end, },
		{ id = "AlongScale", name = "Along scale", editor = "choice", default = "m", items = slab_move_units },
		{ id = "Along", name = "Along guide direction", editor = "number", default = 0, scale = function(self) return self.AlongScale end, },
		{ id = "SizeChangeScale", name = "Size change scale", editor = "choice", default = "m", items = slab_move_units },
		{ id = "SizeChange", name = "Size change", editor = "number", default = 0, scale = function(self) return self.SizeChangeScale end, },
		{ id = "ShiftForHalfStep", name = "Shift for half-step", editor = "bool", default = false, },
	},
	EditorName = "Move/size room guides",
	EditorSubmenu = "Guides",
	StatementTag = "ExtrasGen",
}

function MoveSizeGuides:GetEditorView()
	local function format_change(scale, amount, up_text, down_text)
		amount = amount * 1.0 / GetPropScale(scale)
		local units = scale == "m" and "m" or
			scale == const.SlabSizeX and " horiz. slabs" or 
			scale == const.SlabSizeY and " vert. slabs" or " slabs"
		local prefix = ""
		if up_text and down_text then
			prefix = up_text .. " "
			if amount < 0 then
				amount = -amount
				prefix = down_text .. " "
			end
		end
		return string.format("%s%0.1f%s", prefix, amount, units)
	end
	local ret = string.format("Move guides %s, %s along, %s",
		format_change(self.UpDownScale, self.UpDown, "up", "down"),
		format_change(self.AlongScale, self.Along),
		format_change(self.SizeChangeScale, self.SizeChange, "increase size by", "decrease size by"))
	return self.ShiftForHalfStep and ret .. "\n--> Allow holding Shift for half-step" or ret
end

function MoveSizeGuides:Exec(GuidesVar, _, UpDown, AlongScale, Along, SizeChangeScale, SizeChange, ShiftForHalfStep)
	GuidesVar = GuidesVar or empty_table
	if IsValid(GuidesVar) then GuidesVar = { GuidesVar } end
	XEditorUndo:BeginOp{ objects = GuidesVar }
	for _, guide in ipairs(GuidesVar) do
		local along = AlongScale == 1 and Along * (CalcAngleBetween(guide:GetNormal(), axis_z) > 89*60 and const.SlabSizeX or const.SlabSizeZ) or Along
		local size_change = SizeChangeScale == 1 and SizeChange * (guide:IsVertical() and const.SlabSizeZ or const.SlabSizeX) or SizeChange
		local up_down = UpDown
		if ShiftForHalfStep and terminal.IsKeyPressed(const.vkShift) then
			up_down = up_down / 2
			along = along / 2
			size_change = size_change / 2
		end
		guide:SetPos(guide:GetVisualPos() + point(0, 0, up_down) + SetLen(guide:GetNormal(), along))
		local len = guide:GetLength()
		if guide:GetLength() + size_change >= guim then
			guide:SetLength(guide:GetLength() + size_change)
		end
	end
	XEditorUndo:EndOp(GuidesVar)
end


----- Place objects along guides

DefineClass.LaySlabsAlongGuides = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "GuidesVar", name = "Guides variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ category = "Input/output", id = "AssignTo", name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
		{ category = "Placement", id = "_", editor = "help", default = false,
			help = "Starts placing slabs from left-to-right for horizontal guides that point *outwards*, and bottom-to-top for vertical ones." },
		{ category = "Placement", id = "SnapToVoxels", name = "Snap", editor = "bool", default = true, },
		{ category = "Placement", id = "SnapToVoxelEdge", name = "Snap to voxel edges", editor = "bool", default = true, no_edit = function(self) return not self.SnapToVoxels end, },
		{ category = "Placement", id = "SnapToNearestWall", name = "Snap to nearest wall", editor = "bool", default = true, no_edit = function(self) return self.SnapToVoxels end, },
		{ category = "Placement", id = "StartGap", name = "Start gap (slabs)", editor = "number", default = 0, },
		{ category = "Placement", id = "Fill", name = "Fill entire length", editor = "bool", default = true, },
		{ category = "Placement", id = "Count", name = "Slabs to fill", editor = "number", default = 1,
			no_edit = function(obj) return obj.Fill end,
		},
		{ category = "Placement", id = "BetweenGap", name = "Between gap (slabs)", editor = "number", default = 0, },
		{ category = "Placement", id = "EndGap", name = "End gap (slabs)", editor = "number", default = 0, },
		{ category = "Placement", id = "SkipDoors", name = "Skip doors/windows", editor = "bool", default = true, },
		{ category = "Placement", id = "SkipInterior", name = "Skip interior", editor = "bool", default = false, },
		{ category = "Objects", id = "Start", name = "Start slab(s) 1", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "Start2", name = "Start slab(s) 2", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "Middle", name = "Middle slab(s)", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "End1", name = "End slab(s) 1", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "End2", name = "End slab(s) 2", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Object Settings", id = "StartIsCorner", name = "Start is corner slab", editor = "bool", default = false, },
		{ category = "Object Settings", id = "EndIsCorner", name = "End is corner slab", editor = "bool", default = false, },
		{ category = "Object Settings", id = "StartIsColumnBase", name = "Start is column base", editor = "bool", default = false, },
		{ category = "Object Settings", id = "EndIsColumnTop", name = "End 1 is column top", editor = "bool", default = false, },
		{ category = "Object Settings", id = "Start2FixedDist", name = "Start 2 at fixed distance", editor = "number", scale = "m", default = 0, },
		{ category = "Object Settings", id = "End2FixedDist", name = "End 2 at fixed distance", editor = "number", scale = "m", default = 0, },
		{ category = "Object Settings", id = "StartIsSlab", name = "Start is floor slab", editor = "bool", default = false, },
		{ category = "Object Settings", id = "EndIsSlab", name = "End is floor slab", editor = "bool", default = false, },
	},
	ExtraParams = { "rand" },
	EditorName = "Lay slabs along guides",
	EditorSubmenu = "Objects",
	StatementTag = "ExtrasGen",
}

function LaySlabsAlongGuides:GetEditorView()
	local ret = string.format("Lay slabs along the guides in '%s'", self.GuidesVar)
	
	local items = {}
	if self.SnapToVoxels   then items[#items + 1] = "snap to voxels" end
	if self.StartGap > 0   then items[#items + 1] = string.format("gap %d", self.StartGap) end
	if self.Fill           then items[#items + 1] = "fill entire length" end
	if not self.Fill       then items[#items + 1] = string.format("repeat %d", self.Count) end
	if self.BetweenGap > 0 then items[#items] = items[#items] .. string.format(" with gap %d", self.BetweenGap) end
	if self.EndGap > 0     then items[#items + 1] = string.format("gap %d", self.EndGap) end
	if self.SkipDoors      then items[#items + 1] = "skip doors" end
	if #items > 0 then
		ret = ret .. string.format("\n--> %s", table.concat(items, ", "))
	end
	
	if next(self.Start)  then ret = ret .. string.format("\n--> Start slabs 1 %s", PlaceObjectData.FormatList(self.Start)) end
	if next(self.Start2) then ret = ret .. string.format("\n--> Start slabs 2 %s", PlaceObjectData.FormatList(self.Start2)) end
	if next(self.Middle) then ret = ret .. string.format("\n--> Middle slabs %s", PlaceObjectData.FormatList(self.Middle)) end
	if next(self.End1)   then ret = ret .. string.format("\n--> End slabs 1 %s", PlaceObjectData.FormatList(self.End1)) end
	if next(self.End2)   then ret = ret .. string.format("\n--> End slabs 2 %s", PlaceObjectData.FormatList(self.End2)) end
	if self.AssignTo ~= ""     then ret = ret .. string.format("\n--> Add to variable '%s'", self.AssignTo) end
	return ret
end

function LaySlabsAlongGuides.GetModifiedBBox(obj)
	if not obj:IsKindOf("Slab") then
		return obj:GetObjectBBox()
	end
	-- remove the part of the bounding box that goes into the room interior
	local bbox = GetEntityBBox(obj)
	bbox = box(bbox:min():SetX(0), bbox:max())
	return obj:GetRelativeBox(bbox)
end

function LaySlabsAlongGuides.Place(rand, list, vertical, pt, normal, SkipDoors, SkipInterior, objs, rotate)
	local angle = CalcSignedAngleBetween2D(axis_x, normal) - (rotate and 90*60 or 0)
	local obj = PlaceObjectData.PlaceRandomObject(rand, list, pt, angle)
	local slab_size = 1
	if obj:IsKindOf("SlabWallObject") then
		slab_size = vertical and obj.height or obj.width
	end
	
	if SkipDoors and not obj:IsKindOf("SlabWallObject") and find_intersecting_slab(obj, "SlabWallObject", 20 * guic) then
		obj:delete()
	elseif SkipInterior and EnumVolumes(LaySlabsAlongGuides.GetModifiedBBox(obj), function(vol)
		local pos = obj:GetPos()
		if (pos:x() == vol.box:minx() or pos:x() == vol.box:maxx()) and (pos:y() == vol.box:miny() or pos:y() == vol.box:maxy()) then
			return false -- allow placing columns at the exact room edges as an exception
		end
		return not vol.none_wall_mat_does_not_affect_nbrs
	end) then
		obj:delete()
	else
		objs[#objs + 1] = obj
	end
	return slab_size
end

function LaySlabsAlongGuides:Exec(rand, GuidesVar, AssignTo, SnapToVoxels, SnapToVoxelEdge, SnapToNearestWall, StartGap, Fill, Count, BetweenGap, EndGap, SkipDoors, SkipInterior, Start, Start2, Middle, End1, End2, StartIsCorner, EndIsCorner, StartIsColumnBase, EndIsColumnTop, Start2FixedDist, End2FixedDist, StartIsSlab, EndIsSlab)
	local all_objs = {}
	if IsValid(GuidesVar) then GuidesVar = { GuidesVar } end
	for _, guide in ipairs(GuidesVar or empty_table) do
		local objs = {}
		local slab_size = const.SlabSizeX
		local pt1, pt2, normal = guide:GetPos1(), guide:GetPos2(), guide:GetNormal()
		if SnapToVoxels then
			if SnapToVoxelEdge then
				local offset = point(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ) / 2
				local retrace = point(const.SlabSizeX, const.SlabSizeY, 0) / 2
				pt1, pt2 = SnapToVoxel(pt1 + offset) - retrace, SnapToVoxel(pt2 + offset) - retrace
			else
				local offset = point(0, 0, const.SlabSizeZ / 2) + SetLen(normal, slab_size / 2)
				local along = SetLen(pt2 - pt1, slab_size) / 2
				pt1, pt2 = SnapToVoxel(pt1 + offset + along) - along, SnapToVoxel(pt2 + offset - along) + along
			end
		elseif SnapToNearestWall then
			local pos = guide:GetPos():SetInvalidZ()
			local slab = MapFindNearest(pos, pos, const.SlabSizeX / 2, "WallSlab")
			if slab then
				normal = slab:GetRelativePoint(axis_x) - slab:GetPos()
				local vec = pos - slab:GetPos() -- 2D vector from slab to pos
				local len = Dot2D(vec, normal) / normal:Len()
				local offs = SetLen(normal, len)
				pt1 = pt1 - offs
				pt2 = pt2 - offs
			end
		end
		
		local angle = GetAngle(pt1 - pt2, axis_z) / 60
		local vertical = abs(angle) < 30 or abs(angle - 180) < 30
		if vertical then
			slab_size = const.SlabSizeZ
			if pt1:z() > pt2:z() then
				pt1, pt2 = pt2, pt1 -- start placing bottom to top
			end
		elseif Cross(pt1 - pt2, normal):z() > 0 then
			pt1, pt2 = pt2, pt1 -- start placing left to right
		end
		
		if pt1 ~= pt2 then
			local forward = SetLen(pt2 - pt1, slab_size)
			if not vertical then
				pt1 = pt1 + forward / 2
				pt2 = pt2 + forward / 2
			end
			pt1 = pt1 + forward * StartGap
			pt2 = pt2 - forward * EndGap
			
			if next(Start) then
				if StartIsSlab then
					LaySlabsAlongGuides.Place(rand, Start, vertical, pt1 - forward, normal, false, SkipInterior, objs)
				elseif StartIsCorner then
					LaySlabsAlongGuides.Place(rand, Start, vertical, pt1 - forward / 2, normal, false, SkipInterior, objs)
				elseif StartIsColumnBase then
					LaySlabsAlongGuides.Place(rand, Start, vertical, pt1, normal, SkipDoors, SkipInterior, objs)
				else
					local size = LaySlabsAlongGuides.Place(rand, Start, vertical, pt1, normal, SkipDoors, SkipInterior, objs)
					pt1 = pt1 + forward * size
				end
				if #objs > 0 and Dot(pt2 - pt1, forward) < 0 then
					table.remove(objs):delete()
				end
			end
			if next(Start2) then
				if Start2FixedDist ~= 0 then
					LaySlabsAlongGuides.Place(rand, Start2, vertical, pt1 + SetLen(forward, Start2FixedDist), normal, SkipDoors, SkipInterior, objs)
				else
					local size = LaySlabsAlongGuides.Place(rand, Start2, vertical, pt1, normal, SkipDoors, SkipInterior, objs)
					pt1 = pt1 + forward * size
				end
				if #objs > 0 and Dot(pt2 - pt1, forward) < 0 then
					table.remove(objs):delete()
				end
			end
			
			-- place End slabs before Middle ones, so we know their size; we will move them after Middle later
			local endobjs = {}
			local pt = pt1
			if next(End1) then
				if EndIsSlab then
					LaySlabsAlongGuides.Place(rand, End1, vertical, pt, normal, false, SkipInterior, endobjs)
				elseif EndIsCorner then
					LaySlabsAlongGuides.Place(rand, End1, vertical, pt - forward / 2, normal, false, SkipInterior, endobjs, "rotate")
				elseif EndIsColumnTop then
					LaySlabsAlongGuides.Place(rand, End1, vertical, pt - forward, normal, SkipDoors, SkipInterior, endobjs)
				else
					local size = LaySlabsAlongGuides.Place(rand, End1, vertical, pt, normal, SkipDoors, SkipInterior, endobjs)
					pt = pt + forward * size
				end
				if #endobjs > 0 and Dot(pt2 - pt, forward) < 0 then
					table.remove(endobjs):delete()
				end
			end
			if next(End2) then
				if End2FixedDist ~= 0 then
					LaySlabsAlongGuides.Place(rand, End2, vertical, pt - SetLen(forward, End2FixedDist), normal, SkipDoors, SkipInterior, endobjs)
				else
					local size = LaySlabsAlongGuides.Place(rand, End2, vertical, pt, normal, SkipDoors, SkipInterior, endobjs)
					pt = pt + forward * size
				end
				if #endobjs > 0 and Dot(pt2 - pt, forward) < 0 then
					table.remove(endobjs):delete()
				end
			end
			
			if BetweenGap > 0 and (next(Start) or next(Start2)) then
				pt = pt + forward * BetweenGap
				pt1 = pt1 + forward * BetweenGap
			end
			local available = Dot(pt2 - pt, forward) < 0 and 0 or (pt2 - pt + forward / 2):Len() / forward:Len()
			local slabs = Fill and available or Max(available, Count)
			local orig_slabs = slabs
			if BetweenGap > 0 and (next(End1) or next(End2)) then
				slabs = slabs - BetweenGap
				orig_slabs = orig_slabs + BetweenGap
			end
			
			if next(Middle) and slabs > 0 then
				local size
				while slabs > 0 do
					size = LaySlabsAlongGuides.Place(rand, Middle, vertical, pt1, normal, SkipDoors, SkipInterior, objs)
					pt1 = pt1 + forward * (size + BetweenGap)
					slabs = slabs - (size + BetweenGap)
				end
				slabs = slabs + BetweenGap
				if #objs > 0 and slabs < 0 then
					table.remove(objs):delete()
					slabs = slabs + size + BetweenGap
				end
			else
				slabs = 0
			end
			
			for _, obj in ipairs(endobjs) do
				if obj:IsKindOf("AlignedObj") then
					obj:AlignObj(obj:GetVisualPos() + forward * (orig_slabs - slabs))
				else
					obj:SetPos(obj:GetVisualPos() + forward * (orig_slabs - slabs))
				end
			end
			
			table.iappend(objs, endobjs)
			create_collection(objs)
			table.iappend(all_objs, objs)
		end
	end
	
	ComputeSlabVisibilityOfObjects(all_objs)
	XEditorUndo:BeginOp()
	Msg("EditorCallback", "EditorCallbackPlace", all_objs)
	XEditorUndo:EndOp(all_objs)
	return table.iappend(AssignTo or {}, all_objs)
end


DefineClass.PlaceObjectDataDecal = {
	__parents = { "PlaceObjectData" },
	properties = {
		{ category = "Decal Adjustments", id = "FlipVertically", editor = "bool", default = false, },
		{ category = "Decal Adjustments", id = "MoveDownPercent", editor = "number", default = 0, },
		{ category = "Decal Adjustments", id = "ScaleAfterPlace", editor = "number", default = 100, },
	}
}

DefineClass.LayDecalsAlongGuide = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "GuidesVar", name = "Guides variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ category = "Input/output", id = "AssignTo", name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
		{ category = "Objects", id = "Decals", name = "Decal(s)", editor = "nested_list", class = "PlaceObjectDataDecal", default = false, },
		{ category = "Objects", id = "FitSingle", name = "Fit single decal", editor = "bool", default = false, },
	},
	ExtraParams = { "rand" },
	EditorName = "Lay decals along guides",
	EditorSubmenu = "Objects",
	StatementTag = "ExtrasGen",
}

function LayDecalsAlongGuide:GetEditorView()
	local ret = string.format("Lay decals along the guides in '%s'", self.GuidesVar)
	if next(self.Decals) then ret = ret .. string.format("\n--> Decals %s", PlaceObjectData.FormatList(self.Decals)) end
	return ret
end

function LayDecalsAlongGuide:Exec(rand, GuidesVar, AssignTo, Decals, FitSingle)
	if not next(Decals) then return AssignTo end

	local all_objs = {}
	if IsValid(GuidesVar) then GuidesVar = { GuidesVar } end
	for _, guide in ipairs(GuidesVar or empty_table) do
		local objs = {}
		local pt, pt_end, normal = guide:GetPos1(), guide:GetPos2(), guide:GetNormal()
		local along = SetLen(pt_end - pt, 4096)
		
		while Dot(pt_end - pt, along) > 0 do
			local obj, data = PlaceObjectData.PlaceRandomObject(rand, Decals, pt)
			obj:SetAxisAngle(guide:GetAxis(), guide:GetAngle())
			obj:Rotate(obj:GetRelativePoint(axis_y) - obj:GetVisualPos(), -90*60)
			
			local b = obj:GetEntityBBox()
			local pt1 = obj:GetRelativePoint(point(0, b:miny(), 0))
			if FitSingle then
				local pt2 = obj:GetRelativePoint(point(0, b:maxy(), 0))
				obj:SetScale(MulDivRound(obj:GetScale(), (pt_end - pt):Len(), (pt2 - pt1):Len()))
			end
			
			local y = Dot(pt1 - pt, along) > 0 and b:miny() or b:maxy()
			obj:SetPos(obj:GetRelativePoint(point(b:maxx(), y, 0)))
			pt = obj:GetRelativePoint(point(b:minx(), y, 0))
			objs[#objs + 1] = obj
			
			if data.MoveDownPercent ~= 0 then
				obj:SetPos(obj:GetRelativePoint(point(MulDivRound(-b:sizex(), data.MoveDownPercent, 100), 0, 0)))
			end
			if data.FlipVertically then
				-- the following is a workaround for rotation at 180 degrees not working in one particular case
				obj:Rotate(obj:GetRelativePoint(axis_y) - obj:GetPos(), 90 * 60)
				obj:Rotate(obj:GetRelativePoint(axis_y) - obj:GetPos(), 90 * 60)
			end
			if data.ScaleAfterPlace ~= 100 then
				obj:SetScale(MulDivRound(obj:GetScale(), data.ScaleAfterPlace, 100))
			end
			
			if FitSingle then break end
		end

		create_collection(objs)
		table.iappend(all_objs, objs)
	end
	
	XEditorUndo:BeginOp()
	Msg("EditorCallback", "EditorCallbackPlace", all_objs)
	XEditorUndo:EndOp(all_objs)
	return table.iappend(AssignTo or {}, all_objs)
end

DefineClass.LayObjectsAlongGuides = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "GuidesVar", name = "Guides variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ category = "Input/output", id = "AssignTo", name = "Add to variable", editor = "combo", default = "", items = PrgVarsCombo, variable = true, },
		{ category = "Placement", id = "StartGap", name = "Start gap", editor = "number", scale = "m", default = 0, },
		{ category = "Placement", id = "MinDistance", name = "Min distance", editor = "number", scale = "m", default = 0, },
		{ category = "Placement", id = "AngleDeviation", name = "Angle deviation", editor = "number", scale = "deg", default = 0, },
		{ category = "Placement", id = "EndGap", name = "End gap", editor = "number", scale = "m", default = 0, },
		{ category = "Placement", id = "PointUp", name = "Point up", editor = "bool", default = false, },
		{ category = "Objects", id = "Start", name = "Start object(s)", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "Middle1", name = "Middle object(s)", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "Middle2", name = "Middle object(s) 2", editor = "nested_list", class = "PlaceObjectData", default = false, },
		{ category = "Objects", id = "End", name = "End object(s)", editor = "nested_list", class = "PlaceObjectData", default = false, },
	},
	ExtraParams = { "rand" },
	EditorName = "Lay objects along guides",
	EditorSubmenu = "Objects",
	StatementTag = "ExtrasGen",
}

function LayObjectsAlongGuides:GetEditorView()
	local ret = string.format("Lay objects along the guides in '%s'", self.GuidesVar)
	
	local items = {}
	if self.StartGap > 0       then items[#items + 1] = string.format("gap %0.1f", self.StartGap / (guim * 1.0)) end
	if self.MinDistance > 0    then items[#items + 1] = string.format("distance %0.1f", self.MinDistance / (guim * 1.0)) end
	if self.AngleDeviation > 0 then items[#items + 1] = string.format("angle ±%d", self.AngleDeviation / 60) end
	if self.EndGap > 0         then items[#items + 1] = string.format("gap %0.1f", self.EndGap / (guim * 1.0)) end
	if self.PointUp            then items[#items + 1] = "objects point up" end
	if #items > 0 then
		ret = ret .. string.format("\n--> %s", table.concat(items, ", "))
	end
	
	if next(self.Start)   then ret = ret .. string.format("\n--> Start objs %s", PlaceObjectData.FormatList(self.Start)) end
	if next(self.Middle1) then ret = ret .. string.format("\n--> Middle objs %s", PlaceObjectData.FormatList(self.Middle1)) end
	if next(self.Middle2) then ret = ret .. string.format("\n--> Middle objs(2) %s", PlaceObjectData.FormatList(self.Middle2)) end
	if next(self.End)     then ret = ret .. string.format("\n--> End objs %s", PlaceObjectData.FormatList(self.End)) end
	if self.AssignTo ~= ""      then ret = ret .. string.format("\n--> Add to variable '%s'", self.AssignTo) end
	return ret
end

function LayObjectsAlongGuides.AlignObj(obj, rand, pt, along, normal, AngleDeviation, PointUp)
	obj:SetPos(pt)
	obj:SetOrientation(PointUp and axis_z or normal, 0)

	if not PointUp or along:SetZ(0) ~= point30 then
		local edge = obj:GetRelativePoint(point(guim, 0, 0)) - pt
		rotate_to_match(obj, edge, PointUp and along:SetZ(0) or along)
	end
	obj:Rotate(obj:GetRelativePoint(axis_z) - pt, rand(2 * AngleDeviation + 1) - AngleDeviation)
	return obj
end

function LayObjectsAlongGuides.MaxEntityBBoxSize(list)
	-- we need to place the objects, as we can't get the class/entity from EditorClass
	local max_size = 0
	for _, data in ipairs(list) do
		local obj = XEditorPlaceObject(data.EditorClass)
		max_size = Max(max_size, obj:GetEntityBBox():sizex())
		obj:delete()
	end
	return max_size
end

function LayObjectsAlongGuides:Exec(rand, GuidesVar, AssignTo, StartGap, MinDistance, AngleDeviation, EndGap, PointUp, Start, Middle1, Middle2, End)
	local all = {}
	if IsValid(GuidesVar) then GuidesVar = { GuidesVar } end
	for _, guide in ipairs(GuidesVar or empty_table) do
		local pt, pt_end, normal = guide:GetPos1(), guide:GetPos2(), guide:GetNormal()
		local along = pt_end - pt
		pt = pt + SetLen(along, StartGap)
		pt_end = pt_end - SetLen(along, EndGap)
		
		local first_obj
		if next(Start) then
			first_obj = PlaceObjectData.PlaceRandomObject(rand, Start, pt)
			LayObjectsAlongGuides.AlignObj(first_obj, rand, pt, along, normal, 0, PointUp)
			pt = pt + SetLen(along, first_obj:GetEntityBBox():maxx())
		end
		local last_obj
		if next(End) then
			last_obj = PlaceObjectData.PlaceRandomObject(rand, End, pt_end)
			LayObjectsAlongGuides.AlignObj(last_obj, rand, pt_end, along, normal, 0, PointUp)
			pt_end = pt_end + SetLen(along, last_obj:GetEntityBBox():minx())
		end
		
		local objs = {}
		if next(Middle1) then
			local orig_len = (pt_end - pt):Len() - MinDistance
			local len = orig_len
			if next(Middle2) then
				-- place first object and account for its length
				local obj = PlaceObjectData.PlaceRandomObject(rand, Middle1, pt_end)
				len = len - (obj:GetEntityBBox():sizex() + MinDistance)
				if len > 0 then
					objs[#objs + 1] = obj
				else
					obj:delete()
				end
				
				-- place objects as close as possible until we run out of space
				while true do
					local obj2 = PlaceObjectData.PlaceRandomObject(rand, Middle2, pt)
					local obj1 = PlaceObjectData.PlaceRandomObject(rand, Middle1, pt)
					local newlen = len - (obj1:GetEntityBBox():sizex() + obj2:GetEntityBBox():sizex() + MinDistance * 2)
					if newlen > 0 then
						objs[#objs + 1] = obj2
						objs[#objs + 1] = obj1
						len = newlen
					else
						obj1:delete()
						obj2:delete()
						break
					end
				end
			else
				while true do
					local obj = PlaceObjectData.PlaceRandomObject(rand, Middle1, pt)
					local newlen = len - (obj:GetEntityBBox():sizex() + MinDistance)
					if newlen > 0 then
						objs[#objs + 1] = obj
						len = newlen
					else
						obj:delete()
						break
					end
				end
			end
			
			-- space out and align objects
			local total_gaps = #objs + 1
			for i = 1, #objs do
				local obj = objs[i]
				local gap = MulDivTrunc(len, i, total_gaps) - MulDivTrunc(len, i - 1, total_gaps)
				pt = pt + SetLen(along, -obj:GetEntityBBox():minx() + MinDistance + gap)
				LayObjectsAlongGuides.AlignObj(obj, rand, pt, along, normal, AngleDeviation, PointUp)
				pt = pt + SetLen(along, obj:GetEntityBBox():maxx())
			end
		end
		
		if first_obj then table.insert(objs, 1, first_obj) end
		if last_obj then table.insert(objs, last_obj) end
		create_collection(objs)
		table.iappend(all, objs)
	end
	
	XEditorUndo:BeginOp()
	Msg("EditorCallback", "EditorCallbackPlace", all)
	XEditorUndo:EndOp(all)
	return table.iappend(AssignTo or {}, all)
end


----- Other

DefineClass.SelectInEditor = {
	__parents = { "PrgExec" },
	properties = {
		{ category = "Input/output", id = "ObjectsVar", name = "Objects variable", editor = "choice", default = "selected", items = PrgVarsCombo, variable = true, },
		{ id = "SelectInEditor", name = "Select in editor", editor = "bool", default = true, },
		{ id = "CreateCollection", name = "Create collection", editor = "bool", default = true, },
	},
	EditorName = "Select in editor",
	EditorView = Untranslated("Select '<ObjectsVar>' in the editor"),
	EditorSubmenu = "Objects",
	StatementTag = "ExtrasGen",
}

function SelectInEditor:GetEditorView()
	if self.SelectInEditor and self.CreateCollection then
		return Untranslated("Select '<ObjectsVar>' in the editor, create collection")
	elseif self.SelectInEditor then
		return Untranslated("Select '<ObjectsVar>' in the editor")
	elseif self.CreateCollection then
		return Untranslated("Create collection from objects in '<ObjectsVar>'")
	end
	return "SelectInEditor - please check at least one operation!"
end

function SelectInEditor:Exec(ObjectsVar, SelectInEditor, CreateCollection)
	XEditorUndo:BeginOp{ objects = ObjectsVar }
	if CreateCollection then
		create_collection(ObjectsVar)
	end
	if SelectInEditor then
		editor.SetSel(ObjectsVar)
	end
	XEditorUndo:EndOp(ObjectsVar)
end

DefineClass.ReduceSpaceOut = {
	__parents = { "PrgFilterObjs" },
	properties = {
		{ id = "MinDist", editor = "number", default = 2 * guim, min = guim, max = 25 * guim, scale = "m", slider = true, step = guim / 10 },
	},
	ExtraParams = { "rand" },
	EditorName = "Reduce objects (space out)",
	StatementTag = "ExtrasGen",
}

function ReduceSpaceOut:GetEditorView()
	return string.format("Reduce objects in '%s'\n--> space them out %0.1fm or more", self.AssignTo, self.MinDist * 1.0 / guim)
end

function ReduceSpaceOut:Exec(rand, objs, MinDist)
	local ret = {}
	local obstacles = table.copy(objs)
	-- pick objects and remove all others in the MinDist radius until we're done
	while #obstacles > 0 do
		local obj = obstacles[rand(#obstacles) + 1]
		local pos = obj:GetPos()
		for i = #obstacles, 1, -1 do
			if obstacles[i]:GetDist(pos) <= MinDist then
				table.remove(obstacles, i)
			end
		end
		ret[#ret + 1] = obj
	end
	return ret
end
