XEditorCopyScriptTag = "--[[HGE place script 2.0]]"
if FirstLoad then
	XEditorUndo = false
	EditorMapDirty = false
	EditorDirtyObjects = false
	EditorPasteInProgress = false
	EditorUndoPreserveHandles = false
end

local function init_undo()
	XEditorUndo = XEditorUndoQueue:new()
	SetEditorMapDirty(false)
end
OnMsg.ChangeMap = init_undo
OnMsg.LoadGame = init_undo

function OnMsg.SaveMapDone()
	SetEditorMapDirty(false)
end

function SetEditorMapDirty(dirty)
	EditorMapDirty = dirty
	if dirty then
		Msg("EditorMapDirty")
	end
end

local s_IsEditorObjectOperation = {
	["EditorCallbackMove"] = true,
	["EditorCallbackRotate"] = true,
	["EditorCallbackScale"] = true,
	["EditorCallbackClone"] = true,
}

function OnMsg.EditorCallback(id, objects)
	if s_IsEditorObjectOperation[id] then
		Msg("EditorObjectOperation", false, objects)
	end
end

-- the following object data keys are undo-related and not actual object properties
local special_props = { __undo_handle = true, class = true, op = true, after = true, eFlags = true, gFlags = true }
local ef_to_restore = const.efVisible | const.efCollision | const.efApplyToGrids
local gf_to_restore = const.gofPermanent | const.gofMirrored
local ef_to_ignore = const.efSelectable | const.efAudible
local gf_to_ignore = const.gofEditorHighlight | const.gofSolidShadow | const.gofRealTimeAnim | const.gofEditorSelection | const.gofAnimated

DefineClass.XEditorUndoQueue = {
	__parents = { "InitDone" },
	
	last_handle = 0,
	obj_to_handle = false,
	handle_to_obj = false,
	handle_remap = false, -- when pasting, store old_handle => new_handle for each pasted object here
	
	current_op = false,
	tracked_obj_data = false,
	collapse_with_previous = false,
	op_depth = 0,
	
	undo_queue = false,
	undo_index = 0,
	last_save_undo_index = 0,
	names_index = 1,
	names_to_queue_idx_map = false,
	watch_thread = false,
	undoredo_in_progress = false,
	update_collections_thread = false,
}

function XEditorUndoQueue:Init()
	self.obj_to_handle = {}
	self.handle_to_obj = {}
	self.undo_queue = {}
	self.names_to_queue_idx_map = {}
	self.watch_thread = CreateRealTimeThread(function()
		while true do
			while self.op_depth == 0 or terminal.desktop:GetMouseCapture() do
				Sleep(250)
			end
			--assert(false, "Undo error detected - please report this and the last thing you did in the editor!")
			self.op_depth = 0
			Sleep(250)
		end
	end)
end

function XEditorUndoQueue:Done()
	DeleteThread(self.watch_thread)
end


----- Handles

function XEditorUndoQueue:GetUndoRedoHandle(obj)
	assert(type(obj) == "table" and (obj.class or obj.Index))
	local handle = self.obj_to_handle[obj]
	if not handle then
		handle = self.last_handle + 1
		self.last_handle = handle
		self.obj_to_handle[obj] = handle
		self.handle_to_obj[handle] = obj
	end
	return handle
end

function XEditorUndoQueue:GetUndoRedoObject(handle, is_collection, assign_specific_object)
	if not handle then return false end
	
	-- support for pasting objects
	local obj = self.handle_to_obj[handle]
	if self.handle_remap then
		local new_handle = self.handle_remap[handle]
		if new_handle then
			return self.handle_to_obj[new_handle]
		else
			new_handle = assign_specific_object and self.obj_to_handle[assign_specific_object] or self.last_handle + 1
			
			self.handle_remap[handle] = new_handle
			handle = new_handle
			self.last_handle = Max(self.last_handle, handle)
			obj = nil
		end
	end
	
	if not obj then
		obj = assign_specific_object or {}
		self.handle_to_obj[handle] = obj
		self.obj_to_handle[obj] = handle
		if is_collection then
			Collection.SetIndex(obj, -1)
		end
	end
	return obj
end

function XEditorUndoQueue:UndoRedoHandleClear(handle)
	handle = self.handle_remap and self.handle_remap[handle] or handle
	local obj = self.handle_to_obj[handle]
	self.handle_to_obj[handle] = nil
	self.obj_to_handle[obj] = nil
end


----- Storing/restoring object properties

local function store_objects_prop(value)
	if not value then return false end
	local ret = {}
	for k, v in pairs(value) do
		ret[k] = IsValid(v) and XEditorUndo:GetUndoRedoHandle(v) or store_objects_prop(v)
	end
	return ret
end

local function restore_objects_prop(value)
	if not value then return false end
	local ret = {}
	for k, v in pairs(value) do
		ret[k] = type(v) == "table" and restore_objects_prop(v) or XEditorUndo:GetUndoRedoObject(v)
	end
	return ret
end

function XEditorUndoQueue:ProcessPropertyValue(obj, id, prop_meta, value)
	local editor = prop_meta.editor
	if id == "CollectionIndex" then
		return self:GetUndoRedoHandle(obj:GetCollection())
	elseif editor == "objects" then
		return store_objects_prop(value)
	elseif editor == "object" then
		return self:GetUndoRedoHandle(value)
	elseif editor == "nested_list" then
		local ret = value and {}
		for i, o in ipairs(value) do ret[i] = o:Clone() end
		return ret
	elseif editor == "nested_obj" or editor == "script" then
		return value and value:Clone()
	elseif editor == "grid" and value then
		return value:clone()
	else
		return value
	end
end

function XEditorUndoQueue:GetObjectData(obj)
	local data = {
		__undo_handle = self:GetUndoRedoHandle(obj),
		class = obj.class
	}
	for _, prop_meta in ipairs(obj:GetProperties()) do
		local id = prop_meta.id
		assert(not special_props[id])
		local value = obj:GetProperty(id)
		if (EditorUndoPreserveHandles and id == "Handle") or not obj:ShouldCleanPropForSave(id, prop_meta, value) then
			data[id] = self:ProcessPropertyValue(obj, id, prop_meta, value)
		end
	end
	data.eFlags = band(obj:GetEnumFlags(), ef_to_restore)
	data.gFlags = band(obj:GetGameFlags(), gf_to_restore)
	return data
end

local function get_flags_xor(flags1, flags2, flagsList)
	local result = {}
	for i, flag in pairs(flagsList) do
		if flag ~= "gofDirtyTransform" and flag ~= "gofDirtyVisuals" and flag ~= "gofEditorSelection" then
			if band(flags1, shift(1, i - 1)) ~= band(flags2, shift(1, i - 1)) then
				table.insert(result, flag.name or flag)
			end
		end
	end
	return table.concat(result, ", ")
end

function XEditorUndoQueue:RestoreObject(obj, obj_data, prev_data)
	if not IsValid(obj) then return end
	assert(obj.class ~= "CollectionsToHideContainer")
	for _, prop_meta in ipairs(obj:GetProperties()) do
		local id = prop_meta.id
		local value = obj_data[id]
		if value == nil and prev_data and prev_data[id] then
			value = obj:GetDefaultPropertyValue(id, prop_meta)
		end
		if value ~= nil then
			local prop = prop_meta.editor
			if id == "CollectionIndex" then
				if value == 0 then
					CObject.SetCollectionIndex(obj, 0)
				else
					local collection = self:GetUndoRedoObject(value, "Collection")
					if obj_data.class == "Collection" and collection.Index == editor.GetLockedCollectionIdx() then
						editor.AddToLockedCollectionIdx(obj.Index)
					end
					CObject.SetCollectionIndex(obj, collection.Index)
				end
			elseif prop == "objects" then
				obj:SetProperty(id, restore_objects_prop(value))
			elseif prop == "object" then
				obj:SetProperty(id, self:GetUndoRedoObject(value))
			elseif prop == "nested_list" then
				local objects = {}
				for i, o in ipairs(value) do objects[i] = o:Clone() end
				obj:SetProperty(id, value and objects)
			elseif prop == "nested_obj" then
				obj:SetProperty(id, value and value:Clone())
			elseif id == "Handle" then
				if EditorUndoPreserveHandles and not EditorPasteInProgress then
					-- resolve handle collisions, e.g. from multiple applied map patches
					local start, size = GetHandlesAutoLimits()
					while HandleToObject[value] do
						value = value + 1
						if value >= start + size then
							value = start
						end
					end
					obj:SetProperty(id, value)
				end
			else
				obj:SetProperty(id, value)
			end
		end
	end
	if obj_data.eFlags then
		obj:SetEnumFlags(obj_data.eFlags) obj:ClearEnumFlags(band(bnot(obj_data.eFlags), ef_to_restore))
		obj:SetGameFlags(obj_data.gFlags) obj:ClearGameFlags(band(bnot(obj_data.gFlags), gf_to_restore))
		obj:ClearGameFlags(const.gofEditorHighlight)
	end
	return obj
end


----- Undo/redo operations
--
-- Capturing undo data works using the concept of tracked objects. Start capturing an undo operation
-- by calling BeginOp; complete it with EndOp; in-between add extra tracked objects via StartTracking.
-- 
-- Objects are assigned "undo handles" to keep their identity between undo & redo operations that might
-- delete them. The tracked objects' initial states are kept by handle in 'tracked_obj_data'. For newly
-- created objects the value kept will be 'false'.
--
-- Complex objects such as Volumes/Rooms are handles via the concept of "children" objects (e.g. Slab).
-- Whenever the an object is tracked, we get related objects via GetEditorRelatedObjects/GetEditorParentObject.
-- The state of those object also get tracked automatically.
--
-- BeginOp takes a table of settings to provide it with information about what needs to be tracked:
-- 1. Pass a list of objects in the "objects" field.
-- 2. Mark any grid that will be changed as a "true" field in settings, e.g. { terrain_type = true }.
-- 3. Pass the operation name for the list of operations combo as e.g. { name = "Deleted objects" }.
--
-- EndOp only takes a list of extra objects to be tracked - usually newly created objects during the operation.
--
-- BeginOp/EndOp calls can be nested - a new undo operation is created and pushed into the undo queue when
-- the last EndOp call balances out with BeginOp calls. This allows for easy tracking of editor operations
-- that use other operations to complete, or merging different editor operations into a single one.
--
-- The editor's copy/paste & map patching funcionalities uses the same mechanism for capturing/storing objects.
-- When pasting or applying a patch, newly created objects are assigned new handles via a handle remapping
-- mechanism to prevent collisions with existing handles (see handle_remap member).
--
-- The 'data' member of ObjectsEditOp is a single table with entries for each affected object in order:
--  { op = "delete", __undo_handle = 1, <props>... },
--  { op = "create", __undo_handle = 1, <props>... },
--  { op = "update", __undo_handle = 1, after = { <new_props>... }, <old_props>... },

local function add_child_objects(objects, method, param)
	local added = {}
	for _, obj in ipairs(objects) do
		added[obj] = true
	end
	for _, obj in ipairs(objects) do
		for _, related in ipairs(obj[method or "GetEditorRelatedObjects"](obj, param)) do
			if IsValid(related) and not added[related] then
				objects[#objects + 1] = related
				added[related] = true
			end
		end
	end
end

local function add_parent_objects(objects, for_copy, locked_collection)
	local added = {}
	for _, obj in ipairs(objects) do
		added[obj] = true
	end
	local i = 1
	while i <= #objects do
		local obj = objects[i]
		local parent = obj:GetEditorParentObject()
		if not for_copy and IsValid(parent) and not added[parent] then
			objects[#objects + 1] = parent
			added[parent] = true
		end
		local collection = obj:GetCollection()
		if IsValid(collection) and collection ~= locked_collection and not added[collection] then
			objects[#objects + 1] = collection
			added[collection] = true
		end
		i = i + 1
	end
end

function XEditorUndoQueue:TrackInternal(objects, idx, created)
	local data = self.tracked_obj_data
	assert(data) -- tracking an object is only possible after :BeginOp is called to create an undo operation
	if not data then return end
	for i = idx, #objects do
		local obj = objects[i]
		local handle = self:GetUndoRedoHandle(obj)
		if data[handle] == nil then
			data[handle] = not created and self:GetObjectData(obj)
		end
	end
end

function XEditorUndoQueue:StartTracking(objects, created, omit_children)
	objects = table.copy_valid(objects)
	for idx, obj in ipairs(objects) do
		assert(obj.class ~= "CollectionsToHideContainer")
	end
	if #objects == 0 then return end
	if not omit_children then
		add_child_objects(objects)
	end
	self:TrackInternal(objects, 1, created)
	
	local start_idx = #objects + 1
	add_parent_objects(objects)
	self:TrackInternal(objects, start_idx) -- non-explicit parents are assumed to have existed before the operation
	
	Msg("EditorObjectOperation", false, objects)
	EditorDirtyObjects = table.union(objects, table.validate(EditorDirtyObjects))
end

function XEditorUndoQueue:BeginOp(settings)
	if self.undoredo_in_progress then return end
	
	settings = settings or empty_table
	self.current_op = self.current_op or { clipboard = settings.clipboard }
	self.tracked_obj_data = self.tracked_obj_data or {}
	self.op_depth = self.op_depth + 1
	if self.op_depth == 1 then
		self.collapse_with_previous = settings.collapse_with_previous
		EditorDirtyObjects = empty_table
	end
	
	PauseInfiniteLoopDetection("Undo")
	
	if settings.objects then
		self:StartTracking(settings.objects)
	end
	
	-- store the "before" state of selection and edited grids
	local op = self.current_op
	if not op.selection then
		op.selection = SelectionEditOp:new()
		for i, obj in ipairs(editor.GetSel()) do
			op.selection.before[i] = self:GetUndoRedoHandle(obj)
		end
	end
	for _, grid in ipairs(editor.GetGridNames()) do
		if settings[grid] and not op[grid] then
			op[grid] = GridEditOp:new{ name = grid, before = editor.GetGrid(grid) }
		end
	end
	
	op.name = op.name or settings.name
	ResumeInfiniteLoopDetection("Undo")
end

-- collections must be at the front of undo data; collections need to be created first
-- and allocate/restore their indexes before objects are added to them via SetCollection
local function add_obj_data(data, obj_data)
	if obj_data then
		if obj_data.class == "Collection" then
			table.insert(data, 1, obj_data)
		else
			data[#data + 1] = obj_data
		end
	end
end

local function is_nop(obj_data)
	local after = obj_data.after
	for k, v in pairs(after) do
		if not special_props[k] and not CompareValues(obj_data[k], v) then
			return false
		end
	end
	for k in pairs(obj_data) do
		if after[k] == nil then
			return false
		end
	end
	return true
end

function XEditorUndoQueue:OpCaptureInProgress()
	return self.op_depth > 0
end

function XEditorUndoQueue:AssertOpCapture()
	return not IsEditorActive() or IsChangingMap() or XEditorUndo.undoredo_in_progress or XEditorUndo:OpCaptureInProgress()
end

function XEditorUndoQueue:EndOpInternal(objects, bbox)
	assert(self:OpCaptureInProgress(), "Unbalanced calls between BeginOp and EndOp")
	if not self:OpCaptureInProgress() then return end
	
	PauseInfiniteLoopDetection("Undo")
	
	if objects then
		self:StartTracking(objects, "created")
	end
	
	-- messages for final cleanup when an editor operation involving objects ends
	if self.op_depth == 1 then
		-- keeping op_depth == 1 at this point prevents an infinite loop if the Msgs invoke undo ops
		if next(self.tracked_obj_data) then
			Msg("EditorObjectOperation", true, table.validate(EditorDirtyObjects))
			Msg("EditorObjectOperationEnding")
		end
		EditorDirtyObjects = false
	end
	self.op_depth = self.op_depth - 1
	
	-- finalize operation when the BeginOp/EndOp calls become balanced
	if self.op_depth == 0 then
		local edit_operation = self.current_op
		
		-- drop selection op if selection is the same
		if edit_operation.selection then
			local selDiff = #editor.GetSel() ~= #edit_operation.selection.before
			for i, obj in ipairs(editor.GetSel()) do
				edit_operation.selection.after[i] = self:GetUndoRedoHandle(obj)
				if edit_operation.selection.after[i] ~= edit_operation.selection.before[i] then
					selDiff = true
				end
			end
			if not selDiff then
				edit_operation.selection:delete()
				edit_operation.selection = nil
			end
		end
		
		-- calculate grid diffs
		for _, grid in ipairs(editor.GetGridNames()) do
			local grid_op = edit_operation[grid]
			if grid_op then
				local before, after = grid_op.before, editor.GetGrid(grid)
				-- Find the boxes where there are differences between the two grids and save them in the op's array part
				local diff_boxes = editor.GetGridDifferenceBoxes(grid, after, before, bbox)
				if diff_boxes then
					for idx, box in ipairs(diff_boxes) do
						local change = {
							box = box,
							before = editor.GetGrid(grid, box, before),
							after = editor.GetGrid(grid, box, after),
						}
						table.insert(grid_op, change)
					end
				end
				before:free()
				after:free()
				grid_op.before = nil
			end
		end
		
		-- capture the "after" data and create the object undo operation
		self.handle_remap = nil
		if next(self.tracked_obj_data) then
			local data = {}
			for handle, obj_data in sorted_pairs(self.tracked_obj_data) do
				local obj = self.handle_to_obj[handle]
				if obj_data then
					if IsValid(obj) then
						obj_data.after = self:GetObjectData(obj)
						obj_data.op = "update"
						if is_nop(obj_data) then
							obj_data = nil
						end
					else
						if self.handle_to_obj[handle] then
							self:UndoRedoHandleClear(handle)
						end
						obj_data.op = "delete"
					end
				elseif IsValid(obj) then
					obj_data = self:GetObjectData(obj)
					obj_data.op = "create"
				end
				add_obj_data(data, obj_data)
			end
			edit_operation.objects = ObjectsEditOp:new{ data = data }
		end
		
		self.current_op = false
		self.tracked_obj_data = false
		ResumeInfiniteLoopDetection("Undo")
		return edit_operation
	end
	
	ResumeInfiniteLoopDetection("Undo")
end

function XEditorUndoQueue:EndOp(objects, bbox)
	if self.undoredo_in_progress then return end
	
	local edit_operation = self:EndOpInternal(objects, bbox)
	if edit_operation then
		self:AddEditOp(edit_operation)
		if self.collapse_with_previous and self:CanMergeOps(self.undo_index - 1, self.undo_index, "same_names") then
			self:MergeOps(self.undo_index - 1, self.undo_index)
		end
		self.collapse_with_previous = false
		
		self:UpdateOnOperationEnd(edit_operation)
	end
end

function XEditorUndoQueue:AddEditOp(edit_operation)
	self.undo_index = self.undo_index + 1
	self.undo_queue[self.undo_index] = edit_operation
	for i = self.undo_index + 1, #self.undo_queue do
		self.undo_queue[i] = nil
	end
end

local allowed_keys = { name = true, objects = true }
function XEditorUndoQueue:CanMergeOps(idx1, idx2, same_names)
	if idx1 < 0 then return end
	local name = same_names and self.undo_queue[idx1].name
	for idx = idx1, idx2 do
		local edit_op = self.undo_queue[idx]
		for k in pairs(edit_op) do
			if not allowed_keys[k] then return end
		end
		if name and edit_op.name ~= name then return end
	end
	return true
end

function XEditorUndoQueue:MergeOps(idx1, idx2, name)
	local before, after = {}, {} -- these store object data by handle, just like in tracked_obj_data
	for idx = idx1, idx2 do
		local edit_op = self.undo_queue[idx]
		local objs_data = edit_op and edit_op.objects and edit_op.objects.data
		for _, obj_data in ipairs(objs_data) do
			local op = obj_data.op
			local handle = obj_data.__undo_handle
			if before[handle] == nil then
				before[handle] = op ~= "create" and obj_data or false
			end
			after[handle] = op == "create" and obj_data or op == "update" and obj_data.after or false
		end
	end
	
	local data = {}
	for handle, obj_data in sorted_pairs(before) do
		if not obj_data then
			obj_data = after[handle]
			if obj_data then
				obj_data.op = "create"
			end
		elseif after[handle] then
			obj_data.after = after[handle]
			obj_data.op = "update"
		else
			obj_data.op = "delete"
		end
		add_obj_data(data, obj_data)
	end
	
	name = name or self.undo_queue[idx1].name
	for idx = idx1, #self.undo_queue do
		self.undo_queue[idx] = nil
	end
	table.insert(self.undo_queue, { name = name, objects = ObjectsEditOp:new{ data = data }})
	self.undo_index = idx1
end

function XEditorUndoQueue:UndoRedo(op_type, update_map_hashes)
	local undo = op_type == "undo"
	local edit_op = undo and self.undo_queue[self.undo_index] or self.undo_queue[self.undo_index + 1]
	if not edit_op then return end
	self.undo_index = undo and self.undo_index - 1 or self.undo_index + 1
	if self.undo_index < 0 or self.undo_index > #self.undo_queue then
		self.undo_index = Clamp(self.undo_index, 0, #self.undo_queue)
		return
	end
	
	self.undoredo_in_progress = true
	SuspendPassEditsForEditOp(edit_op.objects and edit_op.objects.data or empty_table)
	PauseInfiniteLoopDetection("XEditorEditOps")
	SuspendObjModified("XEditorEditOps")
	for _, op in sorted_pairs(edit_op) do
		if IsKindOf(op, "EditOp") then
			procall(undo and op.Undo or op.Do, op)
			if update_map_hashes then
				op:UpdateMapHashes()
			end
		end
	end
	if edit_op.clipboard then
		CopyToClipboard(edit_op.clipboard)
	end
	self:UpdateOnOperationEnd(edit_op)
	ResumeObjModified("XEditorEditOps")
	ResumeInfiniteLoopDetection("XEditorEditOps")
	ResumePassEditsForEditOp()
	self.undoredo_in_progress = false
end

function XEditorUndoQueue:UpdateOnOperationEnd(edit_op)
	for key in pairs(edit_op) do
		if key ~= "selection" and key ~= "clipboard" then
			SetEditorMapDirty(true)
		end
	end
	XEditorUpdateToolbars() -- doesn't update the toolbar if it was updated soon
	
	-- these are okay to be delayed by 1 sec.
	if edit_op.objects and not self.update_collections_thread then
		self.update_collections_thread = CreateRealTimeThread(function()
			Sleep(1000)
			UpdateCollectionsEditor()
			self.update_collections_thread = false
		end)
	end
end


----- Editor statusbar combo

function XEditorUndoQueue:GetOpNames(plain)
	local names = { "No operations" }
	local idx_map = { 0 }
	local cur_op_passed, cur_op_idx = false, false
	for i = 1, #self.undo_queue do
		local cur = self.undo_queue[i] and self.undo_queue[i].name
		cur_op_passed = cur_op_passed or i == self.undo_index + 1
		if cur then
			local prev = names[#names]
			if prev and string.ends_with(prev, cur) and not cur_op_passed then
				local n = (tonumber(string.match(prev, "%s(%d+)[^%s%d]")) or 1) + 1
				cur = string.format("%d. %dX %s", #names - 1, n, cur)
				names[#names] = cur
				idx_map[#idx_map] = i
			else
				if cur_op_passed then
					cur_op_idx = #idx_map
					cur_op_passed = false
				end
				table.insert(names, string.format("%d. %s", #names, cur))
				table.insert(idx_map, i)
			end
		end
	end
	
	if not plain then
		self.names_to_queue_idx_map = idx_map
		self.names_index = cur_op_idx or Max(#idx_map, 1)
		for i = self.names_index + 1, #names do
			names[i] = "<color 96 96 96>" .. names[i] .. "</color>"
		end
	end
	return names
end

function XEditorUndoQueue:GetCurrentOpNameIdx()
	return self.names_index
end

function XEditorUndoQueue:RollToOpIndex(new_index)
	if new_index ~= self.names_index then
		local new_undo_index = self.names_to_queue_idx_map[new_index]
		local op = self.undo_index > new_undo_index and "undo" or "redo"
		while self.undo_index ~= new_undo_index do
			self:UndoRedo(op)
		end
		self.names_index = new_index
	end
end


----- EditOp classes

DefineClass.EditOp = {
	__parents = { "InitDone" },
	StoreAsTable = true,
}

function EditOp:Do()
end

function EditOp:Undo()
end

function EditOp:UpdateMapHashes()
end

DefineClass.ObjectsEditOp = {
	__parents = { "EditOp" },
	data = false, -- see comments above XEditorUndo:BeginOp for details
	by_handle = false,
}

function ObjectsEditOp:GetAffectedObjectsBefore()
	local ret = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		if op == "delete" or op == "update" then
			local handle = obj_data.__undo_handle
			table.insert(ret, XEditorUndo:GetUndoRedoObject(handle))
		end
	end
	return ret
end

function ObjectsEditOp:GetAffectedObjectsAfter()
	local ret = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		if op == "create" or op == "update" then
			local handle = obj_data.__undo_handle
			table.insert(ret, XEditorUndo:GetUndoRedoObject(handle))
		end
	end
	return ret
end

function ObjectsEditOp:EditorCallbackPreUndoRedo()
	local objs = {}
	for _, obj_data in ipairs(self.data) do
		table.insert(objs, XEditorUndo.handle_to_obj[obj_data.__undo_handle]) -- don't use GetUndoRedoObject, it has side effects
	end
	Msg("EditorCallbackPreUndoRedo", table.validate(objs))
end

function ObjectsEditOp:Do()
	self:EditorCallbackPreUndoRedo()
	local newobjs = {}
	local oldobjs = {}
	local movedobjs = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		local handle = obj_data.__undo_handle
		local obj = XEditorUndo:GetUndoRedoObject(handle)
		if op == "delete" then
			XEditorUndo:UndoRedoHandleClear(handle)
			oldobjs[#oldobjs + 1] = obj
		elseif op == "create" then
			obj = XEditorPlaceObjectByClass(obj_data.class, obj)
			XEditorUndo:RestoreObject(obj, obj_data)
			newobjs[#newobjs + 1] = obj
		else -- update
			XEditorUndo:RestoreObject(obj, obj_data.after, obj_data)
			if obj_data.after and obj_data.Pos ~= obj_data.after.Pos then
				movedobjs[#movedobjs + 1] = obj
			end
			ObjModified(obj)
		end
	end
	
	for _, obj_data in ipairs(self.data) do
		if obj_data.op ~= "delete" then
			local obj = XEditorUndo:GetUndoRedoObject(obj_data.__undo_handle)
			if IsValid(obj) and obj:HasMember("PostLoad") then
				obj:PostLoad("undo")
			end
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", table.validate(newobjs), "undo")
	Msg("EditorCallback", "EditorCallbackDelete", table.validate(oldobjs), "undo")
	Msg("EditorCallback", "EditorCallbackMove", table.validate(movedobjs), "undo")
	DoneObjects(oldobjs)
end

function ObjectsEditOp:Undo()
	self:EditorCallbackPreUndoRedo()
	local newobjs = {}
	local oldobjs = {}
	local movedobjs = {}
	for _, obj_data in ipairs(self.data) do
		local op = obj_data.op
		local handle = obj_data.__undo_handle
		local obj = XEditorUndo:GetUndoRedoObject(handle)
		if op == "delete" then
			obj = XEditorPlaceObjectByClass(obj_data.class, obj)
			XEditorUndo:RestoreObject(obj, obj_data)
			newobjs[#newobjs + 1] = obj
		elseif op == "create" then
			XEditorUndo:UndoRedoHandleClear(handle)
			oldobjs[#oldobjs + 1] = obj
		else -- update
			XEditorUndo:RestoreObject(obj, obj_data, obj_data.after)
			if obj_data.after and obj_data.Pos ~= obj_data.after.Pos then
				movedobjs[#movedobjs + 1] = obj
			end
			ObjModified(obj)
		end
	end
	
	for _, obj_data in ipairs(self.data) do
		if obj_data.op ~= "create" then
			local obj = XEditorUndo:GetUndoRedoObject(obj_data.__undo_handle)
			if IsValid(obj) and obj:HasMember("PostLoad") then
				obj:PostLoad("undo")
			end
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", table.validate(newobjs), "undo")
	Msg("EditorCallback", "EditorCallbackDelete", table.validate(oldobjs), "undo")
	Msg("EditorCallback", "EditorCallbackMove", table.validate(movedobjs), "undo")
	DoneObjects(oldobjs)
end

function ObjectsEditOp:UpdateMapHashes()
	local hash = table.hash(self.data)
	mapdata.ObjectsHash = xxhash(mapdata.ObjectsHash, hash)
	mapdata.NetHash = xxhash(mapdata.NetHash, hash)
end

DefineClass.SelectionEditOp = {
	__parents = { "EditOp" },
	before = false,
	after = false,
}

function SelectionEditOp:Init()
	self.before = {}
	self.after = {}
end

function SelectionEditOp:Do()
	editor.SetSel(table.map(self.after, function(handle) return XEditorUndo:GetUndoRedoObject(handle) end))
end

function SelectionEditOp:Undo()
	editor.SetSel(table.map(self.before, function(handle) return XEditorUndo:GetUndoRedoObject(handle) end))
end

DefineClass.GridEditOp = {
	__parents = { "EditOp" },
	name = false,
	before = false,
	after = false,
	box = false,
}

function GridEditOp:Do()
	for _, change in ipairs(self) do
		editor.SetGrid(self.name, change.after, change.box)
		if self.name == "height" then
			Msg("EditorHeightChanged", true, change.box)
		end
		if self.name == "terrain_type" then
			Msg("EditorTerrainTypeChanged", change.box)
		end
	end
end

function GridEditOp:Undo()
	for _, change in ipairs(self) do
		editor.SetGrid(self.name, change.before, change.box)
		if self.name == "height" then
			Msg("EditorHeightChanged", true, change.box)
		end
		if self.name == "terrain_type" then
			Msg("EditorTerrainTypeChanged", change.box)
		end
	end
end

function GridEditOp:UpdateMapHashes()
	if self.name == "height" or self.name == "terrain_type" then
		for _, change in ipairs(self) do
			local hash = change.after:hash()
			mapdata.TerrainHash = xxhash(mapdata.TerrainHash, hash)
			mapdata.NetHash = xxhash(mapdata.NetHash, hash)
		end
	end
end


----- Serialization for copy/paste/duplicate

function XEditorSerialize(objs, root_collection)
	local obj_data = {}
	local org_count = #objs
	
	objs = table.copy(objs)
	add_child_objects(objs)
	add_parent_objects(objs, "for_copy", root_collection)
	table.remove_value(objs, root_collection)
	
	Msg("EditorPreSerialize", objs) -- some debug functionalities hook up here to clear temporary visualization properties
	PauseInfiniteLoopDetection("XEditorSerialize")
	for idx, obj in ipairs(objs) do
		local data = XEditorUndo:GetObjectData(obj)
		if obj.class == "Collection" then
			data.Index = -1 -- force creation of new collections indexes when pasting collections
		end
		if obj:GetCollection() == root_collection or XEditorSelectSingleObjects == 1 then
			data.CollectionIndex = nil -- ignore collection
		end
		data.__original_object = idx <= org_count or nil
		add_obj_data(obj_data, data)
	end
	ResumeInfiniteLoopDetection("XEditorSerialize")
	Msg("EditorPostSerialize", objs)
	return { obj_data = obj_data }
end

function XEditorDeserialize(data, root_collection, ...)
	EditorPasteInProgress = true
	PauseInfiniteLoopDetection("XEditorPaste")
	SuspendPassEditsForEditOp(data.obj_data)
	XEditorUndo:BeginOp()
	XEditorUndo.handle_remap = {} -- will force the creation of new objects when resolving handles
	
	local objs, orig_objs = {}, {}
	for _, obj_data in ipairs(data.obj_data) do
		local obj = XEditorUndo:GetUndoRedoObject(obj_data.__undo_handle)
		obj = XEditorPlaceObjectByClass(obj_data.class, obj)
		obj = XEditorUndo:RestoreObject(obj, obj_data)
		if root_collection and not obj:GetCollection() then
			obj:SetCollection(root_collection) -- paste in the currently locked collection
		end
		objs[#objs + 1] = obj
		if obj_data.__original_object then
			orig_objs[#orig_objs + 1] = obj
		end
	end
	
	-- call PostLoad; it sometimes deletes objects (e.g. wires if they are partially unattached)
	for _, obj in ipairs(objs) do
		if obj:HasMember("PostLoad") then
			obj:PostLoad("paste")
		end
	end
	Msg("EditorCallback", "EditorCallbackPlace", table.validate(table.copy(orig_objs)), ...)
	
	XEditorUndo:EndOp(table.validate(objs))
	ResumePassEditsForEditOp()
	ResumeInfiniteLoopDetection("XEditorPaste")
	EditorPasteInProgress = false
	return orig_objs
end

function XEditorToClipboardFormat(data)
	return ValueToLuaCode(data, nil, pstr(XEditorCopyScriptTag, 32768)):str()
end

function XEditorPaste(lua_code)
	local err, data = LuaCodeToTuple(lua_code, LuaValueEnv{ GridReadStr = GridReadStr })
	if err or type(data) ~= "table" or not data.obj_data then
		print("Error restoring objects:", err)
		return
	end
	local fn = data.paste_fn or "Default"
	if not XEditorPasteFuncs[fn] then
		print("Error restoring objects: invalid paste function ", fn)
		return
	end
	procall(XEditorPasteFuncs[fn], data, lua_code, "paste")
end


----- Interface functions for copy/paste/duplicate

function XEditorPasteFuncs.Default(data, lua_code, ...)
	XEditorUndo:BeginOp{ name = "Paste" }
	
	local objs = XEditorDeserialize(data, Collection.GetLockedCollection(), ...)
	local place = editor.GetPlacementPoint(GetTerrainCursor())
	local offs = (place:IsValidZ() and place or place:SetTerrainZ()) - data.pivot
	objs = XEditorSelectAndMoveObjects(objs, offs)
	
	XEditorUndo.current_op.name = string.format("Pasted %d objects", #objs)
	XEditorUndo:EndOp(objs)
end

function XEditorCopyToClipboard()
	local objs = editor.GetSel("permanent")
	
	local data = XEditorSerialize(objs, Collection.GetLockedCollection())
	data.pivot = CenterPointOnBase(objs)
	CopyToClipboard(XEditorToClipboardFormat(data))
end

function XEditorPasteFromClipboard()
	local lua_code = GetFromClipboard(-1)
	if lua_code:starts_with(XEditorCopyScriptTag) then
		XEditorPaste(lua_code)
	end
end

function XEditorClone(objs)
	-- cloned objects from a single selected collection are added to their current collection, as per level designers request
	local locked_collection = Collection.GetLockedCollection()
	local single_collection = editor.GetSingleSelectedCollection(objs)
	if single_collection and #objs < MapCount("map", "collection", single_collection.Index, true) then
		locked_collection = single_collection
	end
	return XEditorDeserialize(XEditorSerialize(objs, locked_collection), locked_collection, "clone")
end


----- Map patches (storing and restoring map changes from their undo operations)

function OnMsg.SaveMapDone()
	XEditorUndo.last_save_undo_index = XEditorUndo.undo_index
end

local function redo_and_capture(name)
	local op = XEditorUndo.undo_queue[XEditorUndo.undo_index + 1]
	local affected = { name = name }
	for key in pairs(op) do
		if key ~= "name" then
			affected[key] = true
		end
	end
	if op.objects then
		affected.objects = op.objects:GetAffectedObjectsBefore() 
	end
	
	XEditorUndo:BeginOp(affected)
	XEditorUndo:UndoRedo("redo", IsChangingMap() and "update_map_hashes")
	XEditorUndo:EndOp(op.objects and op.objects:GetAffectedObjectsAfter())
end

-- TODO: Only save hash_to_handle information for handles that are actually referenced in the patch
local function create_combined_patch_edit_op()
	if XEditorUndo.undo_index <= XEditorUndo.last_save_undo_index then
		return {}
	end
	
	Msg("OnMapPatchBegin")
	SuspendPassEditsForEditOp()
	PauseInfiniteLoopDetection("XEditorCreateMapPatch")
	
	-- undo operations back to the last map save
	local undo_index = XEditorUndo.undo_index
	while XEditorUndo.undo_index ~= XEditorUndo.last_save_undo_index do
		XEditorUndo:UndoRedo("undo")
	end
	
	-- store object identifying information (for objects that are to be deleted or modified - all they have undo handles)
	local hash_to_handle = {}
	for handle, obj in pairs(XEditorUndo.handle_to_obj) do
		if IsValid(obj) then
			assert(not hash_to_handle[obj:GetObjIdentifier()]) -- hash collision, likely the data used to construct the hash is identical
			hash_to_handle[obj:GetObjIdentifier()] = handle
		end
	end
	
	-- redo all undo operations, collapsing them into a single one
	EditorUndoPreserveHandles = true
	XEditorUndo:BeginOp()
	
	for idx = XEditorUndo.undo_index, undo_index - 1 do
		assert(XEditorUndo.undo_index == idx)
		redo_and_capture()
	end
	ResumeInfiniteLoopDetection("XEditorCreateMapPatch")
	ResumePassEditsForEditOp()
	
	-- get and cleanup the combined operation
	local edit_op = XEditorUndo:EndOpInternal()
	local obj_datas = edit_op.objects and edit_op.objects.data or empty_table
	for idx, obj_data in ipairs(obj_datas) do
		local op, handle = obj_data.op, obj_data.__undo_handle
		if op == "delete" then
			obj_datas[idx] = { op = op, __undo_handle = handle }
		elseif op == "update" then
			local after = obj_data.after
			for k, v in pairs(after) do
				if not special_props[k] and CompareValues(obj_data[k], v) then
					after[k] = nil
				end
			end
			obj_datas[idx] = { op = op, __undo_handle = handle, after = obj_data.after }
		end
	end
	edit_op.hash_to_handle = hash_to_handle
	edit_op.selection = nil
	
	assert(XEditorUndo.undo_index == undo_index)
	EditorUndoPreserveHandles = false
	Msg("OnMapPatchEnd")
	
	return edit_op
end

function XEditorCreateMapPatch(filename, add_to_svn)
	local edit_op = create_combined_patch_edit_op()
	
	-- serialize this combined operation, along with the object identifiers
	local str = "return " .. ValueToLuaCode(edit_op, nil, pstr("", 32768)):str()
	filename = filename or "svnAssets/Bin/win32/Bin/map.patch"
	local path = SplitPath(filename)
	AsyncCreatePath(path)
	local err = AsyncStringToFile(filename, str)
	if err then
		print("Failed to write patch file", filename)
		return
	end
	if add_to_svn then
		SVNAddFile(path)
		SVNAddFile(filename)
	end
	
	local affected_grids = {}
	for _, grid in ipairs(editor.GetGridNames()) do
		if edit_op[grid] then
			affected_grids[grid] = edit_op[grid].box
		end
	end
	
	edit_op.compacted_obj_boxes = empty_table
	if edit_op.objects then
		local affected_objs = edit_op.objects:GetAffectedObjectsAfter()
		local obj_box_list = {}
		for _, obj in ipairs(affected_objs) do
			assert(IsValid(obj))
			if IsValid(obj) then
				table.insert(obj_box_list, obj:GetObjectBBox())
			end
		end
		edit_op.compacted_obj_boxes = CompactAABBList(obj_box_list, 4 * guim, "optimize_boxes")
	end
	
	-- return:
	--  - hashes of changed objects (newly created objects are not included), 
	--  - affected grid boxes
	--  - a compacted list of the affected objects' bounding boxes (updated and created objects)
	return (edit_op.hash_to_handle and table.keys(edit_op.hash_to_handle)), affected_grids, edit_op.compacted_obj_boxes
end

function XEditorApplyMapPatch(filename)
	filename = filename or "svnAssets/Bin/win32/Bin/map.patch"
	
	local func, err = loadfile(filename)
	if err then
		print("Failed to load patch", filename)
		return
	end
	
	local edit_op = func()
	if not next(edit_op) then return end
	
	Msg("OnMapPatchBegin")
	XEditorUndo.handle_remap = {} -- as with pasting, generate new undo handles for the objects from the patch
	EditorUndoPreserveHandles = true -- restore object handles that were stored in the patch
	
	-- lookup objects to be deleted/modified by their stored identifier hashes
	local hash_to_handle = edit_op.hash_to_handle
	MapForEach(true, "attached", false, function(obj)
		local hash = obj:GetObjIdentifier()
		local handle = hash_to_handle[hash]
		if handle then
			XEditorUndo:GetUndoRedoObject(handle, nil, obj) -- "assign" this object to the handle, via handle_remap
		end
	end)
	
	-- apply the changes via the "redo" mechanism
	XEditorUndo:AddEditOp(edit_op)
	XEditorUndo.undo_index = XEditorUndo.undo_index - 1
	redo_and_capture("Applied map patch")
	
	-- remove the added edit op and readjust the undo index
	table.remove(XEditorUndo.undo_queue, XEditorUndo.undo_index - 1)
	XEditorUndo.undo_index = XEditorUndo.undo_index - 1
	
	EditorUndoPreserveHandles = false
	MapPatchesApplied = true
	Msg("OnMapPatchEnd")
end


----- Misc

function CenterPointOnBase(objs)
	local minz
	for _, obj in ipairs(objs) do
		local pos = obj:GetVisualPos()
		local z = Max(terrain.GetHeight(pos), pos:z())
		if not minz or minz > z then
			minz = z
		end
	end
	return CenterOfMasses(objs):SetZ(minz)
end

function XEditorSelectAndMoveObjects(objs, offs)
	editor.SetSel(objs)
	SuspendPassEditsForEditOp()
	objs = editor.SelectionCollapseChildObjects()
	if const.SlabSizeX and HasAlignedObjs(objs) then -- snap offset to a whole number of voxels, so auto-snapped object don't get displaced
		local x = offs:x() / const.SlabSizeX * const.SlabSizeX
		local y = offs:y() / const.SlabSizeY * const.SlabSizeY
		local z = offs:z() and (offs:z() + const.SlabSizeZ / 2) / const.SlabSizeZ * const.SlabSizeZ or 0
		offs = point(x, y, z)
	end
	for _, obj in ipairs(objs) do
		if obj:IsKindOf("AlignedObj") then
			obj:AlignObj(obj:GetPos() + offs)
		elseif obj:IsValidPos() then
			obj:SetPos(obj:GetPos() + offs)
		end
	end
	Msg("EditorCallback", "EditorCallbackMove", objs)
	ResumePassEditsForEditOp()
	return objs
end

-- Makes sure that if a parent object (as per GetEditorParentObject) is in the input list,
-- then all children objects are in the output, and vice versa. Used by XAreaCopyTool.
function XEditorPropagateParentAndChildObjects(objs)
	add_parent_objects(objs)
	add_child_objects(objs)
	return objs
end

function XEditorPropagateChildObjects(objs)
	add_child_objects(objs)
	return objs
end

function XEditorCollapseChildObjects(objs)
	local objset = {}
	for _, obj in ipairs(objs) do
		objset[obj] = true
	end
	
	local i, count = 1, #objs
	while i <= count do
		local obj = objs[i]
		if objset[obj:GetEditorParentObject()] then
			objs[i] = objs[count]
			objs[count] = nil
			count = count - 1
		else
			i = i + 1
		end
	end
	return objs
end
