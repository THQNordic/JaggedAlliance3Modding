MapVar("g_CollideLuaObjects", false)
MapVar("s_SelectedWires", false)

DefineClass.CollideLuaObject = {
	__parents = { "Object", "EditorObject", "EditorCallbackObject" },
}

function CollideLuaObject:Done()
	table.remove_entry(g_CollideLuaObjects, self)
end

function CollideLuaObject:EditorCallbackPlace()
	g_CollideLuaObjects = g_CollideLuaObjects or {}
	table.insert(g_CollideLuaObjects, self)
end

function CollideLuaObject:EditorCallbackDelete()
	table.remove_entry(g_CollideLuaObjects, self)
end

CollideLuaObject.EditorEnter = CollideLuaObject.EditorCallbackPlace
CollideLuaObject.EditorExit = CollideLuaObject.EditorCallbackDelete

function CollideLuaObject:GetBBox()
	return box(0, 0, 0, 0)
end

function CollideLuaObject:TestRay(pos, dir)
	return RayIntersectsAABB(pos, dir, self:GetBBox())
end

function CollideLuaObject:SetHighlighted(highlight)
	if highlight then
		self:SetHierarchyGameFlags(const.gofEditorHighlight)
	else
		self:ClearHierarchyGameFlags(const.gofEditorHighlight)
	end
end

function CollideLuaObjectGetBBox(obj)
	return obj:GetBBox()
end

function CollideLuaObjectTestRay(obj, pos, dir)
	return obj:TestRay(pos, dir)
end

DefineClass.Wire = {
	__parents = {"Mesh"},
	
	pos1 = false,
	pos2 = false,
	curve_type = false,
	curve_length_percents = false,
	color = false,
	points_step = false,

	bbox = false,
	samples_bboxes = false,
}

function Wire:CreatePstr()
	return pstr("")
end

DefineClass.SpotHelper = {
	__parents = {"Object", "EditorObject", "EditorCallbackObject"},
	
	obj = false,
	spot_type = false,
	spot_relative_index = false,
}

function SpotHelper:GetAttachPos()
	local first = self.obj:GetSpotRange(self.spot_type)
	local index = first + self.spot_relative_index
	
	return self.obj:GetSpotPos(index)
end

function SpotHelper:GetEditorRelatedObjects()
	return { self.obj }
end

local s_DefaultHelperSpot = "Wire"

DefineClass.TwoPointsAttachParent = {	-- only these support 2-point attaches
	__parents = {"Object", "EditorCallbackObject"},
}

function TwoPointsAttachParent:EditorCallbackClone(source)
	local dlg = GetDialog("XSelectObjectsTool")
	if dlg and IsKindOf(dlg.placement_helper, "XTwoPointAttachHelper") then
		self:AttachSpotHelpers()
	end
	local wires = MapGet(true, "TwoPointsAttach")
	for _, wire in ipairs(wires) do
		if wire.obj1 == source then
			CreateTwoPointsAttach(self, wire.spot_type1, wire.spot_index1, wire.obj2, wire.spot_type2, wire.spot_index2, wire.curve, wire.length_percents)
		elseif wire.obj2 == source then
			CreateTwoPointsAttach(wire.obj1, wire.spot_type1, wire.spot_index1, self, wire.spot_type2, wire.spot_index2, wire.curve, wire.length_percents)
		end	
	end
	EditorCallbackObject.EditorCallbackClone(self, source)
end

function TwoPointsAttachParent:GetEditorRelatedObjects()
	return MapGet(true, "TwoPointsAttach", function(obj) return obj.obj1 == self or obj.obj2 == self end)
end

function TwoPointsAttachParent:AttachSpotHelpers()
	local first, last = self:GetSpotRange(s_DefaultHelperSpot)
	for spot = first, last do
		local helper = PlaceObject("SpotHelper")
		self:Attach(helper, spot)
		helper.obj = self
		helper.spot_type = s_DefaultHelperSpot
		helper.spot_relative_index = spot - first
	end
end

local function CreateOrUpdateWire(pos1, pos2, wire, curve_type, curve_length_percents, color, points_step)
	color = color or const.clrBlack
	points_step = points_step or guim/10

	-- Do not recreate if all input parameteres are the same
	if wire then
		if wire.pos1 == pos1 and wire.pos2 == pos2 and wire.curve_type == curve_type and wire.curve_length_percents == curve_length_percents and wire.color == color and wire.points_step == points_step then
			return wire
		end
	end

	local catenary = curve_type == "Catenary"
	local axis = pos2 - pos1
	local axis_len = axis:Len()
	local wire_length = MulDivTrunc(axis_len, Max(100, curve_length_percents), 100)
	local get_curve_params = catenary and CatenaryToPointArcLength or ParabolaToPointArcLength
	local a, b, c = get_curve_params(axis, wire_length, 10000)
	if not (a and b) then
		return wire
	end
	
	local wire = wire or PlaceObject("Wire")
	wire.pos1 = pos1
	wire.pos2 = pos2
	wire.curve_length_percents = curve_length_percents
	wire.curve_type = curve_type
	wire.color = color
	wire.points_step = points_step

	local points = wire_length / points_step
	local geometry_pstr = wire:CreatePstr()
	local axis_len_2d = axis:Len2D()
	local samples_bboxes = {}
	local wire_pos = (pos1 + pos2) / 2
	local local_pos1 = pos1 - wire_pos
	local local_pos2 = pos2 - wire_pos
	local wire_width = 30 * guim / 100
	local width_vec = SetLen(Rotate(axis:SetInvalidZ(), 90 * 60), wire_width / 2):SetZ(0)
	local curve_value_at = catenary and CatenaryValueAt or ParabolaValueAt
	
	local thickness = MulDivRound(guim, 1, 100)
	local roundness = 10
	local axis2d = axis:SetZ(0)
	
	local last_pt = point()
	local tempPt = point()
	local CreateOrUpdateWire_AppendPt = CreateOrUpdateWire_AppendPt
	if points > 0 then
		for i = 0, points do
			local x = axis_len_2d * i / points
			local y = curve_value_at(x, a, b, c)

			tempPt:InplaceSet(axis)
			InplaceMulDivRound(tempPt, i, points)
			tempPt:InplaceSetZ(y)
			tempPt:InplaceAdd(local_pos1)
			if i > 0 then
				CreateOrUpdateWire_AppendPt(geometry_pstr, samples_bboxes, thickness, roundness, color, width_vec, axis2d, last_pt, tempPt)
			end
			last_pt:InplaceSet(tempPt)
		end
	end
	if last_pt ~= local_pos2 then
		CreateOrUpdateWire_AppendPt(geometry_pstr, samples_bboxes, thickness, roundness, color, width_vec, axis2d, last_pt, local_pos2)
	end
	
	-- calc bounding box - needed by the CollideLuaObject:TestRay()
	local bbox = samples_bboxes[1]
	for i = 2, #samples_bboxes do
		bbox:InplaceExtend(samples_bboxes[i])
	end

	wire:SetMesh(geometry_pstr)
	wire:SetShader(ProceduralMeshShaders.defer_mesh)
	wire:SetDepthTest(true)
	wire:SetPos(wire_pos)
	wire.samples_bboxes = samples_bboxes
	wire.bbox = bbox

	return wire
end

function CreateWire(pos1, pos2, curve_type, curve_length_percents, color, points_step)
	return CreateOrUpdateWire(pos1, pos2, nil, curve_type or "Parabola", curve_length_percents or 101, color, points_step)
end

DefineClass.XTwoPointAttachHelper = {
	__parents = { "XEditorPlacementHelper", "XEditorToolSettings" },
	
	-- these properties get appended to the tool that hosts this helper
	properties = {
		persisted_setting = true,
		{ id = "WireLength", name = "Wire Length Increase %", editor = "number", min = 101, max = 1000,
			persisted_setting = true, default = 150, help = "Percents increase of straight line length",
		},
		{ id = "WireCurve", name = "Wire Curve", editor = "dropdownlist", persisted_setting = true, 
		  items = {"Parabola", "Catenary"}, default = "Catenary",
		},
		{ id = "Buttons", name = "Wire Length Increase %", editor = "buttons", default = false,
		  buttons = {{name = "Clear All Wires", func = function(self)
				MapDelete(true, "TwoPointsAttach")
		  end}},
		},
	},
	
	HasLocalCSSetting = false,
	HasSnapSetting = false,
	InXSelectObjectsTool = true,
	UsesCodeRenderables = true,

	Title = "Place wires (2)",
	Description = false,
	ActionSortKey = "32",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceWires.tga",
	ActionShortcut = "2",
	UndoOpName = "Attached wire",
	
	wire = false,
	start_helper = false,
}

function XTwoPointAttachHelper:Init()
	MapForEach("map", "TwoPointsAttachParent", function(obj)
		obj:AttachSpotHelpers()
	end)
end

function XTwoPointAttachHelper:Done()
	if self.wire then
		DoneObject(self.wire)
	end
	MapForEach(true, "SpotHelper", function(spot_helper)
		DoneObject(spot_helper)
	end)
end

function XTwoPointAttachHelper:GetDescription()
	return "(drag to place wires between electricity poles)\n(Shift-Mousewheel changes wire length)"
end

function XTwoPointAttachHelper:GetSpotHelperCursorObj()
	return GetNextObjectAtScreenPos(function(obj) return IsKindOf(obj, "SpotHelper") end)
end

function XTwoPointAttachHelper:CheckStartOperation(pt)
	return not not self:GetSpotHelperCursorObj()
end

function XTwoPointAttachHelper:StartOperation(pt)
	local obj = self:GetSpotHelperCursorObj()
	if not obj then return end
	
	self.operation_started = true
	self.start_helper = obj
	self:UpdateWire()
end

function XTwoPointAttachHelper:EndOperation()
	DoneObject(self.wire)
	self.wire = false
	local spot_helper = self:GetSpotHelperCursorObj()
	if spot_helper then
		local obj1, obj2 = self.start_helper.obj, spot_helper.obj
		local spot_type1, spot_type2 = self.start_helper.spot_type, spot_helper.spot_type
		local spot_index1, spot_index2 = self.start_helper.spot_relative_index, spot_helper.spot_relative_index
		local dlg = GetDialog("XSelectObjectsTool")		
		local curve = dlg:GetProperty("WireCurve")
		local length_percents = dlg:GetProperty("WireLength")
		if obj1 ~= obj2 and not GetTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2) then
			XEditorUndo:BeginOp{name = "Created wire"}
			XEditorUndo:EndOp({CreateTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length_percents)})
		end
	end
	self.start_helper = false
	self.operation_started = false
end

function XTwoPointAttachHelper:PerformOperation(pt)
	self:UpdateWire()
end

function XTwoPointAttachHelper:UpdateWire()
	if not self.start_helper then return end
	
	local pos1 = self.start_helper:GetAttachPos()
	local spot_helper = self:GetSpotHelperCursorObj()
	local pos2 = spot_helper and spot_helper:GetAttachPos() or GetTerrainCursor()
	local dlg = GetDialog("XSelectObjectsTool")
	local curve_type = dlg:GetProperty("WireCurve")
	local curve_length = dlg:GetProperty("WireLength")
	self.wire = CreateOrUpdateWire(pos1, pos2, self.wire, curve_type, curve_length)
end

function XTwoPointAttachHelper:OnShortcut(shortcut, source, ...)
	local delta
	if terminal.IsKeyPressed(const.vkControl) then
		if shortcut:ends_with("MouseWheelFwd") then
			delta = 1
		elseif shortcut:ends_with("MouseWheelBack") then
			delta = -1
		end
	end
	
	if delta then
		local tool = XEditorGetCurrentTool()
		local meta = self:GetPropertyMetadata("WireLength")
		tool:SetProperty("WireLength", Clamp(self:GetProperty("WireLength") + delta, meta.min, meta.max))
		ObjModified(tool)
		self:UpdateWire()
		return "break"
	end
end

DefineClass.TwoPointsAttach = {
	__parents = {"Object", "EditorCallbackObject", "CollideLuaObject"},
	flags = {gofPermanent = true},
	
	properties = {
		{id = "obj1", name = "Object 1", editor = "object", default = false},
		{id = "spot_type1", name = "Spot Type 1", editor = "text", default = s_DefaultHelperSpot},
		{id = "spot_index1", name = "Spot Index 1", editor = "text", default = "invalid"},
		{id = "obj2", name = "Object 2", editor = "object", default = false},
		{id = "spot_type2", name = "Spot Type 2", editor = "text", default = s_DefaultHelperSpot},
		{id = "spot_index2", name = "Spot Index 2", editor = "text", default = "invalid"},
		{id = "curve", name = "Curve", editor = "text", default = "Catenary"},
		{id = "length_percents", name = "Length Percents", editor = "number", default = 150},
		{id = "Pos", dont_save = true},
	},
	
	wire = false,
}

function TwoPointsAttach:Done()
	DoneObject(self.wire)
end

function TwoPointsAttach:SetPositions(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length_percents, color, points_step)
	self.obj1, self.spot_type1, self.spot_index1 = obj1, spot_type1, spot_index1
	self.obj2, self.spot_type2, self.spot_index2 = obj2, spot_type2, spot_index2
	self.curve, self.length_percents = curve, length_percents
	if IsValid(self.obj1) and IsValid(self.obj2) and type(self.spot_index1) == "number" and type(self.spot_index2) == "number"  then
		local start1 = obj1:GetSpotRange(spot_type1)
		local start2 = obj2:GetSpotRange(spot_type2)
		local pos1 = obj1:GetSpotLocPos(start1 + spot_index1, obj1:TimeToInterpolationEnd())
		local pos2 = obj2:GetSpotLocPos(start2 + spot_index2, obj2:TimeToInterpolationEnd())
		self.wire = CreateOrUpdateWire(pos1, pos2, self.wire, curve, length_percents, color, points_step)
		self:SetPos(self.wire:GetPos())
	end
end

function TwoPointsAttach:UpdatePositions(color, points_step)
	self:SetPositions(self.obj1, self.spot_type1, self.spot_index1,
		self.obj2, self.spot_type2, self.spot_index2, self.curve, self.length_percents, color, points_step)
end

function TwoPointsAttach:GetBBox()
	return self.wire.bbox
end

function TwoPointsAttach:TestRay(pos, dir)
	local samples_bboxes = self.wire.samples_bboxes
	local dest = pos + dir
	for _, bbox in ipairs(samples_bboxes) do
		if RayIntersectsAABB(pos, dest, bbox) then
			return true
		end
	end
end

function TwoPointsAttach:SetHighlighted(highlighted)
	highlighted = highlighted or (s_SelectedWires and s_SelectedWires[self])
	self:UpdatePositions(highlighted and const.clrGray or const.clrBlack)
end

function TwoPointsAttach:SetVisible(visible)
	if not IsValid(self.wire) then return end
	if visible then
		self.wire:SetEnumFlags(const.efVisible)
	else
		self.wire:ClearEnumFlags(const.efVisible)
	end
end

function TwoPointsAttach:PostLoad(reason)
	if not IsValid(self.obj1) or not IsValid(self.obj2) then
		DoneObject(self)
	else
		self:UpdatePositions()
	end
end

local function CheckValidTwoPointsAttach(obj)
	if not IsValid(obj.obj1) then
		StoreErrorSource(obj, "Wire obj1 is invalid!", obj.handle)
	end
	if not IsValid(obj.obj2) then
		StoreErrorSource(obj, "Wire obj2 is invalid!", obj.handle)
	end
end

function OnMsg.PreSaveMap()
	MapForEach(true, "TwoPointsAttach", CheckValidTwoPointsAttach)
end

function OnMsg.NewMapLoaded()
	MapForEach(true, "TwoPointsAttach", function(obj)
		if obj.spot_index1 == "invalid" then
			obj.spot_index1 = obj.spot1
		end
		if obj.spot_index2 == "invalid" then
			obj.spot_index2 = obj.spot2
		end
		obj:UpdatePositions()
		CheckValidTwoPointsAttach(obj)
		if not obj.wire and IsValid(obj.obj1) and IsValid(obj.obj2) then
			StoreErrorSource(obj, "Wire is invalid!", obj.handle, obj.obj1, obj.obj2)
		end
	end)
end

local function FilterTwoPointsAttachParents(objects)
	local two_points_parents = {}
	for _, obj in ipairs(objects) do
		if IsKindOf(obj, "TwoPointsAttachParent") then
			table.insert(two_points_parents, obj)
		end
	end
	
	return two_points_parents
end

function ForEachConnectedWire(objects, func)
	local two_points_parents = FilterTwoPointsAttachParents(objects)
	if #two_points_parents == 0 then return end

	local wires = MapGet(true, "TwoPointsAttach")
	for _, obj in ipairs(two_points_parents) do
		for _, wire in ipairs(wires) do
			if wire.obj1 == obj or wire.obj2 == obj then
				func(wire)
			end
		end
	end
end

function OnMsg.EditorCallback(id, objects)
	if id == "EditorCallbackDelete" then
		ForEachConnectedWire(objects, function(wire)
			if IsValid(wire) then
				DoneObject(wire)
			end
		end)
	elseif id == "EditorCallbackMove" or id == "EditorCallbackRotate" or id == "EditorCallbackScale" then
		ForEachConnectedWire(objects, function(wire)
			wire:UpdatePositions()
		end)
	end
end

function OnMsg.WireCurveTypeChanged(new_curve_type)
	s_SelectedWires = s_SelectedWires or {}
	for wire in pairs(s_SelectedWires) do
		if wire.curve ~= new_curve_type then
			wire.curve = new_curve_type
			wire:UpdatePositions()
		end
	end
end

function OnMsg.EditorSelectionChanged(objects)
	s_SelectedWires = s_SelectedWires or {}
	local cur_sel = {}
	for _, obj in ipairs(objects) do
		if IsKindOf(obj, "TwoPointsAttach") then
			cur_sel[obj] = true
			if not s_SelectedWires[obj] then
				s_SelectedWires[obj] = true
				obj:SetHighlighted("highlighted")
			end
		end
	end
	local to_unselect = {}
	for wire in pairs(s_SelectedWires) do
		if not cur_sel[wire] then
			table.insert(to_unselect, wire)
		end
	end
	for _, wire in ipairs(to_unselect) do
		s_SelectedWires[wire] = nil
		if IsValid(wire) then
			wire:SetHighlighted(false)
		end
	end
	local sel_types = {}
	for wire in pairs(s_SelectedWires) do
		if not sel_types[wire.curve] then
			sel_types[wire.curve] = true
			table.insert(sel_types, wire.curve)
		end
	end
	if #sel_types == 1 then
		local dlg = GetDialog("XSelectObjectsTool")
		if dlg then
			dlg:SetProperty("WireCurve", sel_types[1])
		end
	end
end

function CreateTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length)
	local real_wire = PlaceObject("TwoPointsAttach")
	real_wire:SetPositions(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2, curve, length)
	return real_wire
end

function GetTwoPointsAttach(obj1, spot_type1, spot_index1, obj2, spot_type2, spot_index2)
	local wires = MapGet(true, "TwoPointsAttach")
	for _, wire in ipairs(wires) do
		if	wire.obj1 == obj1 and wire.spot_type1 == spot_type1 and wire.spot_index1 == spot_index1 and 
			wire.obj2 == obj2 and wire.spot_type2 == spot_type2 and wire.spot_index2 == spot_index2 then
			return wire
		end
		if	wire.obj1 == obj2 and wire.spot_type1 == spot_type2 and wire.spot_index1 == spot_index2 and 
			wire.obj2 == obj1 and wire.spot_type2 == spot_type1 and wire.spot_index2 == spot_index1 then
			return wire
		end
	end
end
