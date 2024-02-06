DefineClass.XArrayPlacementHelper = {
	__parents = { "XEditorPlacementHelper" },
	
	-- these properties get appended to the tool that hosts this helper
	properties = {
		persisted_setting = true,
		{ id = "RepeatCount", name = "Repeat Count", editor = "number", default = 2, 
		  min = 1, max = 20, help = "Number of times to clone the selected objects",
		},
	},
	
	HasLocalCSSetting = false,
	HasSnapSetting = true,
	InXSelectObjectsTool = true,
	
	clones = false,
	
	Title = "Array placement (3)",
	Description = false,
	ActionSortKey = "8",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceObjectsInARow.tga",
	ActionShortcut = "3",
	UndoOpName = "Placed array of objects",
}

function XArrayPlacementHelper:Clone(count)
	local objs = {}
	local sel = editor.GetSel()
	for i = 1, count do
		local clones = {}
		for j, obj in ipairs(sel) do
			clones[j] = obj:Clone()
			objs[#objs + 1] = obj
		end
		if XEditorSelectSingleObjects == 0 then
			Collection.Duplicate(clones)
		end
		self.clones[#self.clones + 1] = clones
	end
	Msg("EditorCallback", "EditorCallbackPlace", objs)
end

function XArrayPlacementHelper:Move()
	local objs = editor.GetSel()
	local start_point = CenterOfMasses(objs)
	local end_point = GetTerrainCursor()
	local interval = (end_point - start_point) / #self.clones
	
	local clones = {}
	local snapBySlabs = HasAlignedObjs(objs)
	local start_height = terrain.GetHeight(start_point)
	for i, group in ipairs(self.clones) do
		local vMove = interval * i
		vMove = vMove:SetZ(terrain.GetHeight(start_point + vMove) - start_height)
		for j, obj in ipairs(group) do
			XEditorSnapPos(obj, objs[j]:GetPos(), vMove, snapBySlabs)
			clones[#clones + 1] = obj
		end
	end
	Msg("EditorCallback", "EditorCallbackMove", clones)
end

function XArrayPlacementHelper:Remove(count)
	for i = 1, count do
		local objs = self.clones[#self.clones]
		Msg("EditorCallback", "EditorCallbackDelete", objs)
		DoneObjects(objs)
		self.clones[#self.clones] = nil
	end
end

function XArrayPlacementHelper:ChangeCount(count)
	local newCount = count - #self.clones
	if newCount > 0 then
		self:Clone(newCount)
	elseif newCount < 0 then
		self:Remove(-newCount)
	end
	self:Move()
end

function XArrayPlacementHelper:GetDescription()
	return "(drag to clone objects in a straight line)\n(use [ and ] to change number of copies)"
end

function XArrayPlacementHelper:CheckStartOperation(pt)
	return not terminal.IsKeyPressed(const.vkShift) and editor.IsSelected(GetObjectAtCursor())
end

function XArrayPlacementHelper:StartOperation(pt)
	local dlg = GetDialog("XSelectObjectsTool")
	local clones_count = dlg:GetProperty("RepeatCount")
	self.clones = {}
	self:Clone(clones_count)
	self.operation_started = true
end

function XArrayPlacementHelper:PerformOperation(pt)
	self:Move()
end

function XArrayPlacementHelper:EndOperation(objects)
	local selCoM = CenterOfMasses(editor.GetSel())
	local CoMs = {}
	CoMs[selCoM:x()] = {}
	CoMs[selCoM:x()][selCoM:y()] = true
	local groupCount = #self.clones
	for i = 1, groupCount do
		local group = self.clones[i]
		local CoM = CenterOfMasses(group)
		if not CoMs[CoM:x()] then CoMs[CoM:x()] = {} end
		if not CoMs[CoM:x()][CoM:y()] then
			CoMs[CoM:x()][CoM:y()] = true
			editor.AddToSel(group)
		else
			DoneObjects(group)
			self.clones[i] = nil
		end
	end
	local objectsCloned = self.clones and #self.clones > 0
	self.clones = false
	self.operation_started = false
	if objectsCloned then 
		local dlg = GetDialog("XSelectObjectsTool")
		dlg:SetHelperClass("XSelectObjectsHelper")
	end
end

function XArrayPlacementHelper:OnShortcut(shortcut, source, ...)
	if shortcut == "[" or shortcut == "]" then
		local dir = shortcut == "[" and -1 or 1
		self:SetProperty("RepeatCount", self:GetProperty("RepeatCount") + dir)
		if self.operation_started then
			self:ChangeCount(self:GetProperty("RepeatCount"))
		end
		return "break"
	end
end
