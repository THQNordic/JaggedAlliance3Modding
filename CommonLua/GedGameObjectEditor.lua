if FirstLoad then
	GedObjectEditor = false
end

function GedInvokedMapEditorUndo() XEditorUndo:UndoRedo("undo") end
function GedInvokedMapEditorRedo() XEditorUndo:UndoRedo("redo") end

local last_selection_idx = 1
function GedOpViewGameObject(socket, obj)
	local is_obj_starting_table = type(obj) == "table" and IsValid(obj[1])
	if IsKindOf(obj, "GedMultiSelectAdapter") or is_obj_starting_table then
		local objs = is_obj_starting_table and obj or obj.__objects
		if #objs == 0 then return end
		if #objs < last_selection_idx then
			last_selection_idx = 1
		end
		ViewObject(objs[last_selection_idx])
		last_selection_idx = last_selection_idx + 1
	else
		ViewObject(obj)
	end
end

local function GetSelectionTable(socket, obj, allow_root)
	if (type(obj) == "table" and obj[1] and IsValid(obj[1])) then
		return obj
	elseif IsKindOf(obj, "GedMultiSelectAdapter") then
		return obj.__objects
	elseif obj == socket:ResolveObj("root") then
		return allow_root and obj or {}
	else
		return {obj}
	end
end

function GedOpConvertToTemplate(socket, obj)
	local objs = GetSelectionTable(socket, obj)
	if #objs > 0 then
		Template.TurnObjectsIntoTemplates(objs)
	end
end

function GedOpConvertToObject(socket, obj)
	local objs = GetSelectionTable(socket, obj)
	if #objs > 0 then
		Template.TurnTemplatesIntoObjects(objs)
	end
end

local shown_spots = {}
function GedOpToggleSpotVisiblity(socket, obj)
	local objs = GetSelectionTable(socket, obj)
	if #objs == 0 then return nil end
	return ToggleSpotVisibility(objs)
end
	
function ToggleSpotVisibility(objs)
	if not shown_spots[objs[1]] then
		for _, obj in ipairs(objs) do
			if IsValid(obj) then
				obj:ShowSpots()
				shown_spots[obj] = true
			end
		end
	else
		for _, obj in ipairs(objs) do
			if IsValid(obj) then
				obj:HideSpots()
				shown_spots[obj] = nil
			end
		end
	end
end

function ToggleSurfaceVisibility(objs)
	if not ObjToShownSurfaces[objs[1]] then
		for _, obj in ipairs(objs) do
			if IsValid(obj) then
				obj:ShowSurfaces()
			end
		end
	else
		for _, obj in ipairs(objs) do
			if IsValid(obj) then
				obj:HideSurfaces()
			end
		end
	end
end

function GedOpSetSingleSel(socket, obj)
	if IsEditorActive() then
		editor.SetSel{ obj }
	else
		SelectObj(obj)
	end
end
	
function GedOpDisplaySpotsWithFilter(socket, obj)
	if not obj then return end
	
	-- List spots by name & autoattach
	local spots = {}
	if obj["HasEntity"] and obj:HasEntity() then
		local start_id, end_id = obj:GetAllSpots(obj:GetState())
		for i = start_id, end_id do
			local spot_name = GetSpotNameByType(obj:GetSpotsType(i))
			local annotation = obj:GetSpotAnnotation(i) or ""
			local attach_class = annotation:match(".*,(.*),.*")
			spots[spot_name .. (attach_class and ":"..attach_class or "")] = true
		end
	end
	
	-- Construct combo box items
	local items = table.keys(spots)
	if #items > 0 then
		table.sort(items)
		local spot_name = socket:WaitUserInput("Select Spots to Show", items[1], items)
		obj:HideSpots()
		if spot_name then
			obj:ShowSpots(unpack_params(spot_name:split(":")))
			shown_spots[obj] = true
		end
	else
		socket:ShowMessage("Information", "No spots to show for this object.")
	end
end

function GedOpRemoveDuplicated(socket, obj)
	local obj_list = GetSelectionTable(socket, obj, "allow_root")
	local selection = editor.GetSel()
	editor.ClearSel()
	DeleteDuplicates(obj_list)
	table.validate(selection)
	editor.AddToSel(selection)
end

function GedOpDeleteObject(socket, obj)
	local selection = editor.GetSel()
	editor.ClearSel()
	DoneObjects(GetSelectionTable(socket, obj))
	table.validate(selection)
	editor.AddToSel(selection)
end

function GedOpOpenEntityEditor(socket, obj)
	local objs = GetSelectionTable(socket, obj, "allow_root")
	if #objs > 0 then
		CreateEntityViewer(objs[1])
	end
end

function GedOpenAutoattachEditorButton(root, obj, prop_id, ged)
	if not root or not obj then return end
	OpenAutoattachEditor(root, true)
end

function GedOpRemoveUnselected(socket, obj)
	local objs = GetSelectionTable(socket, obj)
	editor.ClearSel()
	editor.AddToSel(objs)
end

local function UpdateAnimationTimeFlags(oldsel, newsel)
	if IsEditorActive() then
		if oldsel then
			for _, o in ipairs(oldsel) do
				if IsValid(o) then 
					if IsKindOf(o, "ParSystem") then
						if o:ShouldBeGameTime() then
							ObjectAnimToGameTime(o)
						end
					elseif GetClassGameFlags(o.class, const.gofRealTimeAnim) == 0 then
						ObjectAnimToGameTime(o)
					end
				end
			end
		end
		if newsel then
			for _, o in ipairs(newsel) do
				o:SetRealtimeAnim(true)
			end
		end
	end
end

local function UpdateForcedLODs(oldsel, newsel)
	if IsEditorActive() then
		if oldsel then
			for _, o in ipairs(oldsel) do
				if IsValid(o) then
					o:RestoreForcedLODState()
					ObjModified(o)
				end
			end
		end
		
		if newsel then
			for _, o in ipairs(newsel) do
				o:CacheForcedLODState()
				if o:GetForcedLODMin() then
					o:SetForcedLOD(Max(o:GetLODsCount(), 1) - 1)
				end
				ObjModified(o)
			end
		end
	end
end

local function EditorFilterObjList(objects)
	if not EditorSettings:GetLimitObjectEditorItems() then
		return objects
	end

	-- show no more than 500 objects in the Object Editor (otherwise the performance is abysmal)
	local i, n, ret = 1, 1, {}
	while i <= #objects and n <= 500 do
		local obj = objects[i]
		if IsValid(obj) and not IsKindOf(obj, "PropertyHelper") then
			ret[n] = obj
			n = n + 1
		end
		i = i + 1
	end
	return ret
end

local obj_modified_list = {}
local obj_modified_thread = false
local obj_rebind_thread = false

local function mark_modified(obj)
	obj_modified_list[obj] = true
	for _, attach in ipairs(obj:GetAttaches() or empty_table) do
		mark_modified(attach)
	end
end

function OnMsg.EditorObjectOperation(op_finished, obj_list)
	if GedObjectEditor and op_finished then
		for _, obj in ipairs(obj_list) do
			mark_modified(obj)
		end
		obj_modified_thread = obj_modified_thread or CreateRealTimeThread(function()
			Sleep(250)
			obj_modified_thread = false
			for obj in pairs(obj_modified_list) do
				ObjModified(obj)
			end
			obj_modified_list = {}
		end)
	end
end

function OnMsg.EditorSelectionChanged(objects)
	if GedObjectEditor and not GedObjectEditor.objects_locked then
		-- no need to call ObjModified if we will rebind everything
		DeleteThread(obj_modified_thread)
		obj_modified_thread = false
		obj_modified_list = {}
		
		-- add 100 ms delay, restart everything if selection is changed again (as in the drag to select case)
		DeleteThread(obj_rebind_thread)
		obj_rebind_thread = CreateRealTimeThread(function()
			Sleep(100)
			if GedObjectEditor then
				local root = GedObjectEditor:ResolveObj("root")
				if objects and #objects == 1 and IsKindOf(objects[1], "PropertyHelper") then
					objects = root -- keep all objects, but filter invalids
				end
				objects = EditorFilterObjList(objects)

				UpdateAnimationTimeFlags(root, objects)
				UpdateForcedLODs(root, objects)
				GedObjectEditor:UnbindObjs("root")
				GedObjectEditor:BindObj("root", objects)
				GedObjectEditor:SelectAll("root")
			end
		end)
	end
end

function OpenGedGameObjectEditor(objects, locked_objs)
	CreateRealTimeThread(function(objects)
		if not GedObjectEditor then
			objects = EditorFilterObjList(objects)

			UpdateAnimationTimeFlags(nil, objects)
			UpdateForcedLODs(nil, objects)
			GedObjectEditor = OpenGedApp("GedObjectEditor", objects, { WarningsUpdateRoot = "root" }) or false
			GedObjectEditor:SelectAll("root")
		else
			GedObjectEditor:Call("rfnApp", "Activate")
		end
		rawset(GedObjectEditor, "objects_locked", locked_objs or false)
	end, objects)
end

function OnMsg.GedClosing(ged_id)
	if GedObjectEditor and GedObjectEditor.ged_id == ged_id then
		local objects = GedObjectEditor:ResolveObj("root")
		table.validate(objects)
		UpdateAnimationTimeFlags(objects, nil)
		UpdateForcedLODs(objects, nil)
		GedObjectEditor = false
	end
end
