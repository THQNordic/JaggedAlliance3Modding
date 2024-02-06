----- Generic undo support for object properties

function CompareValues(val1, val2)
	if not IsT(val1) and not IsT(val2) and type(val1) == "table" and type(val2) == "table" then
		local pstr1, pstr2 = pstr("", 1024), pstr("", 1024)
		ValueToLuaCode(val1, nil, pstr1)
		ValueToLuaCode(val2, nil, pstr2)
		return pstr1 == pstr2
	end
	return val1 == val2
end

function GedPropCapture(obj)
	if not IsKindOf(obj, "PropertyObject") or IsKindOf(obj, "CObject") and not IsValid(obj) then
		return
	end
	local prop_capture = {}
	for _, prop_meta in ipairs(obj:GetProperties()) do
		local no_edit = prop_eval(prop_meta.no_edit, obj, prop_meta)
		local read_only = prop_eval(prop_meta.read_only, obj, prop_meta)
		local dont_save = prop_eval(prop_meta.dont_save, obj, prop_meta)
		if not no_edit and not read_only and not dont_save then
			local editor = prop_meta.editor
			if editor == "object" or editor == "objects" then -- can't really undo nested game objects that get changed via a Ged button
				return
			end
			
			local id = prop_meta.id
			local value = obj:GetProperty(id)
			if not obj:IsDefaultPropertyValue(id, prop_meta, value) then
				prop_capture[id] = obj:ClonePropertyValue(value, prop_meta)
			end
		end
	end
	return prop_capture
end

function GedCreatePropValuesUndoFn(obj, old_capture)
	local new_capture = GedPropCapture(obj)
	if not old_capture or not new_capture then return end
	
	local changed, nils = {}, {}
	for _, key in ipairs(table.union(table.keys(new_capture), table.keys(old_capture))) do
		local old_value, new_value = rawget(old_capture, key), rawget(new_capture, key)
		if not CompareValues(old_value, new_value) then
			changed[key] = old_value
			nils[key] = old_value == nil or nil
		end
	end
	
	if next(changed) or next(nils) then
		return function()
			for key, value in pairs(changed) do obj:SetProperty(key, value) end
			for key, value in pairs(nils)    do obj:SetProperty(key, nil)   end
			if obj:IsKindOf("Preset") then
				obj:SortPresets()
			end
			ObjModified(obj)
		end
	end
end


----- Multiple-selection op helpers
--
-- Use to perform ops over multiple selection, if performing the
-- single op multiple times either forwards or backwards works

function GedListMultiOp(socket, obj, op, mode, selection, ...)
	if not selection or not selection[1] then return end
	
	table.sort(selection)
	local idx1 = mode == "forward" and 1 or #selection
	local idx2 = mode == "forward" and #selection or 1
	local step = mode == "forward" and 1 or -1
	
	local new_sel, undo_fns = {}, {}
	for i = idx1, idx2, step do
		local sel, undo_fn = _G[op](socket, obj, selection[i], ...)
		if not sel or type(sel) == "string" then -- error
			for i = 1, #undo_fns do undo_fns[i]() end
			return sel
		end
		table.insert(undo_fns, 1, undo_fn)
		table.insert(new_sel, sel)
	end
	if mode == "delete" then
		new_sel = { new_sel[#new_sel] }
	else
		table.sort(new_sel)
	end
	
	return new_sel, function() for i = 1, #undo_fns do undo_fns[i]() end ObjModified(obj) end
end

function GedTreeMultiOp(socket, obj, op, mode, selection, ...)
	if not selection or not selection[1] then return end
	
	local node_path = selection[1]
	selection = selection[2]
	table.sort(selection)
	local idx1 = mode:starts_with("forward") and 1 or #selection
	local idx2 = mode:starts_with("forward") and #selection or 1
	local step = mode:starts_with("forward") and 1 or -1
	local shift = 0
	
	local new_sel_node
	local new_sel, undo_fns = {}, {}
	for i = idx1, idx2, step do
		local path = table.copy(node_path)
		path[#path] = selection[i] - (mode == "forward_inwards" and shift or 0)
		if mode == "forward_inwards" then
			path.parent_leaf_idx = new_sel_node and new_sel_node[#new_sel_node - 1]
		end
		local sel, undo_fn = _G[op](socket, obj, path, ...)
		if sel == nil or type(sel) == "string" then -- error
			for i = 1, #undo_fns do undo_fns[i]() end
			return sel
		end
		table.insert(undo_fns, 1, undo_fn)
		new_sel_node = mode ~= "delete" and new_sel_node or sel
		if sel then
			table.insert(new_sel, sel[#sel] + (mode == "backward_outwards" and shift or 0))
		end
		shift = shift + 1
	end
	if mode == "delete" then
		new_sel = { new_sel[#new_sel] }
	else
		table.sort(new_sel)
	end
	
	return { new_sel_node, new_sel }, function() for i = 1, #undo_fns do undo_fns[i]() end ObjModified(obj) end
end

function GedDisplayTempStatus(id, text, delay)
	delay = delay or 600
	return GedSetUiStatus(id, text, delay)
end


----- clipboard & duplicate

if FirstLoad then
	GedClipboard = { stored_objs = false, base_class = false, }
	GedPropertiesContainer = { data = false }
	GedSerializeInProgress = false
end

-- used when Ged needs to fully serialize a value for copy/paste/duplicate, or for undo purposes
-- ModItemWithFiles uses this to serialize the files associated to a ModItem as well, preventing "partial" copies
function GedSerialize(value)
	assert(not GedSerializeInProgress) -- sanity check
	GedSerializeInProgress = true
	local data = ValueToLuaCode(value)
	GedSerializeInProgress = false
	return data
end

-- 'class' is a base class for all objects, used for type-safe pasting
function GedCopyToClipboard(obj, base_class, idx_list, message)
	table.sort(idx_list)
	GedClipboard.base_class = base_class
	GedClipboard.mod_ids = {}
	local objs = {}
	for i = 1, #idx_list do
		local item = TreeNodeByPath(obj, idx_list[i])
		table.insert(objs, item)
		assert(item:IsKindOf(base_class))
		-- Save the mod ids of copied items so we can assign each to the correct mod on paste
		table.insert(GedClipboard.mod_ids, item.mod and item.mod.id)
	end
	GedClipboard.stored_objs = GedSerialize(objs)
	
	GedDisplayTempStatus("clipboard", string.format("%d %s copied", #idx_list, base_class))
end

local function __paste(class_name, ...)
	local class = g_Classes[class_name]
	return class:HasMember("__paste") and class:__paste(...) or class:__fromluacode(...)
end

function GedPasteObjCode(code, error_text)
	local old_place_obj = PlaceObj
	PlaceObj = __paste
	local err, objs = LuaCodeToTuple(code, _G)
	PlaceObj = old_place_obj
	if err then
		print(error_text, err)
		return
	end
	GenerateLocalizationIDs(objs)
	return objs
end

function GedRestoreFromClipboard(base_class)
	local clipboard_class = rawget(_G, GedClipboard.base_class)
	if not clipboard_class or base_class and not clipboard_class:IsKindOf(base_class) then
		return
	end
	return GedPasteObjCode(GedClipboard.stored_objs, "Ged: Error restoring object")
end

function GedDuplicateObjects(obj, idx_list)
	table.sort(idx_list)
	local objs = {}
	local mod_ids = {}
	for i = 1, #idx_list do
		local item = TreeNodeByPath(obj, idx_list[i])
		table.insert(objs, item)
		-- Temporary fix don't kill me - save mod_ids to assign them again on paste
		table.insert(mod_ids, item.mod and item.mod.id or false)
	end
	
	return GedPasteObjCode(GedSerialize(objs), "Ged: Error duplicating object"), mod_ids
end


----- generic ops (SetProperty, PropEditorButton, etc.)

local function ged_verify_set_prop(obj, prop_meta, prop_id, value, socket)
	value = GedToGameValue(value, prop_meta, obj)
	if value == nil then
		value = obj:GetDefaultPropertyValue(prop_id, prop_meta)
	elseif prop_meta.validate then
		local err, corrected_value = prop_meta.validate(obj, value, socket)
		if err then
			-- If the new value causes an error, display the old value again
			GedForceUpdateObject(obj)
			ObjModified(obj)
			
			return GedTranslate(err, obj, false)
		elseif corrected_value ~= nil then
			value = corrected_value
		end
	end
	
	local old_value
	if type(prop_id) == "string" then
		old_value = obj:GetProperty(prop_id)
	else
		old_value = obj[prop_id]
	end
	if ValueToLuaCode(value) ~= ValueToLuaCode(old_value) then
		return nil, value, obj:ClonePropertyValue(old_value, prop_meta)
	end
end

local function ged_set_prop(socket, obj, prop_id, value, old_value, multi)
	if type(prop_id) == "string" then
		obj:SetProperty(prop_id, value)
	else
		obj[prop_id] = value
	end
	ParentTableModified(value, obj, "recursive")
	GedMultiSelectAdapterObjModified(obj)
	socket:NotifyEditorSetProperty(obj, prop_id, old_value, multi)
	ObjModified(obj)
end

local function ged_set_props(socket, prop_id, values, old_values)
	local multi = #table.keys(values) > 1
	for obj, value in pairs(values) do
		ged_set_prop(socket, obj, prop_id, value, old_values[obj], multi)
	end
end

function GedSetProperty(socket, obj, prop_id, value, disable_undo, slider_drag_id)
	local objs = IsKindOf(obj, "GedMultiSelectAdapter") and obj.__objects or { obj }
	local values, old_values, prop_captures = {}, {}, {}
	for _, item in ipairs(objs) do
		local prop_meta = GedIsValidObject(item) and item:GetPropertyMetadata(prop_id)
		if prop_meta then
			local err, val, old_val = ged_verify_set_prop(item, prop_meta, prop_id, value, socket)
			if err then
				return err
			elseif val ~= nil then
				values[item] = val
				old_values[item] = old_val
				prop_captures[item] = GedPropCapture(item)
			end
		end
	end
	
	-- only perform the op if a property value would be changed
	if next(values) then
		ged_set_props(socket, prop_id, values, old_values)
		if IsKindOf(obj, "GedMultiSelectAdapter") and not value then
			obj:ClearNestedProperty(prop_id)
		end
		ObjModified(obj)
		
		if not disable_undo then
			-- the undo function will encompasses all object properties, so that extra changes to an object made in OnEditorSetProperty are also handled
			local undo_fns = {}
			for _, item in ipairs(objs) do
				undo_fns[#undo_fns + 1] = GedCreatePropValuesUndoFn(item, prop_captures[item])
			end
			return nil, function() for _, undo in ipairs(undo_fns) do undo() end ObjModified(obj) end, slider_drag_id
		else
			return nil, nil, slider_drag_id
		end
	end
end

function GedPropEditorButton(socket, obj, root_name, prop_id, btn_name, btn_func, btn_param, idx)
	if not btn_func then
		local prop_meta = obj:GetPropertyMetadata(prop_id)
		local buttons = prop_eval(prop_meta.buttons, obj, prop_meta)
		btn_func = table.find_value(buttons, "name", btn_name).func
	end
	
	local game_objects = IsEditorActive() and socket:GatherAffectedGameObjects(obj)
	if game_objects then
		XEditorUndo:BeginOp{ name = btn_name, objects = game_objects }
	end
	Msg("GedExecPropButtonStarted", obj)
	
	local root = socket:ResolveObj(root_name)
	local new_sel_or_err, undo_fn
	if IsKindOf(obj, "GedMultiSelectAdapter") then
		new_sel_or_err, undo_fn = obj:ExecPropButton(root, prop_id, socket, btn_func, btn_param, idx)
	else
		local prop_capture = not game_objects and GedPropCapture(obj)
		if type(btn_func) == "function" then
			new_sel_or_err, undo_fn = btn_func(obj, root, prop_id, socket, btn_param, idx)
		else
			new_sel_or_err, undo_fn = "Couldn't find property button function " .. (btn_func or "nil"), nil
			if PropObjHasMember(obj, btn_func) then
				new_sel_or_err, undo_fn = obj[btn_func](obj, root, prop_id, socket, btn_param, idx)
			elseif obj:IsKindOf("XTemplateWindow") and PropObjHasMember(g_Classes[obj.__class], btn_func) then
				new_sel_or_err, undo_fn = g_Classes[obj.__class][btn_func](obj, root, prop_id, socket, btn_param, idx)
			elseif PropObjHasMember(root, btn_func) then
				new_sel_or_err, undo_fn = root[btn_func](root, obj, prop_id, socket, btn_param, idx)
			elseif rawget(_G, btn_func) then
				new_sel_or_err, undo_fn = _G[btn_func](root, obj, prop_id, socket, btn_param, idx)
			end
		end
		
		-- setup automatic undo in Ged for properties
		local undo_props = not game_objects and GedCreatePropValuesUndoFn(obj, prop_capture)
		if undo_props then
			local old_undo_fn = undo_fn or empty_func
			undo_fn = function() old_undo_fn() undo_props() end
		end
	end
	
	Msg("GedExecPropButtonCompleted", obj)
	if game_objects then
		XEditorUndo:EndOp(game_objects)
	elseif type(new_sel_or_err) ~= "string" and undo_fn then
		GedDisplayTempStatus("buttons_undo", "Press Ctrl-Z for undo", 800)
	end
	return new_sel_or_err, undo_fn
end

function GedInvokeMethod(socket, obj, fn_name, ...)
	obj[fn_name](obj, ...)
end

function GedDiscardEditorChanges(ged)
	for _, group in ipairs(ged:ResolveObj("root")) do
		for _, preset in ipairs(group) do
			QueueReloadAllPresets(preset:GetLastSavePath(), "Modified", "force_reload")
		end
	end
end

function GedNotifyPropertyChanged(socket, parent_name, prop_id)
	socket:NotifyEditorSetProperty(socket:ResolveObj(parent_name), prop_id)
end

function GedGetObjectClass(obj)
	return obj and obj.class
end


----- tree ops

function TreeNodeChildren(node)
	local f = node and node.GedTreeChildren
	return f and (f(node) or empty_table) or node 
end

function RecursiveFindTreeItemPath(parent, obj, path)
	path = path or {}
	for idx, node in ipairs(TreeNodeChildren(parent)) do
		path[#path + 1] = idx
		if node == obj or RecursiveFindTreeItemPath(node, obj, path) then
			return path
		end
		table.remove(path)
	end
end

function RecursiveFindTreeItemPaths(root, objects)
	local obj_paths = {}
	for _, obj in ipairs(objects) do
		obj_paths[#obj_paths + 1] = RecursiveFindTreeItemPath(root, obj)
	end
	
	local parent_path = obj_paths[1]
	if parent_path then
		parent_path = table.copy(parent_path)
		local objects_idxs = { table.remove(parent_path) }
		for i = 2, #objects do
			local obj_path = obj_paths[i]
			objects_idxs[#objects_idxs + 1] = table.remove(obj_path)
			if not table.iequal(parent_path, obj_path) then
				return
			end
		end
		return obj_paths[1], objects_idxs
	end
end

function ParentNodeByPath(root, path)
	for i = 1, #path - 1 do
		if not root then return end
		local f = root.GedTreeChildren
		root = rawget(f and (f(root) or empty_table) or root, path[i])
	end
	return root
end

function GetNodeByPath(root, path)
	return TreeNodeChildren(ParentNodeByPath(root, path))[path[#path]]
end

function TreeRelocateNode(root, old_path, new_path)
	local old_parent = ParentNodeByPath(root, old_path)
	local new_parent = ParentNodeByPath(root, new_path)
	local node = table.remove(TreeNodeChildren(old_parent), old_path[#old_path])
	local parent_table = TreeNodeChildren(new_parent)
	local new_path_idx = Min(new_path[#new_path], #parent_table + 1)
	table.insert(parent_table, new_path_idx, node)
	ParentTableModified(node, parent_table)
	ObjModified(old_parent)
	ObjModified(new_parent)
	ObjModified(root)
end

function GetLowestCommonAncestor(path1, path2)
	local lca_path = {}
	local index = 1
	local node1 = path1[1]
	if not next(path1) or not next(path2) then return lca_path end
	while path1[index] == path2[index] do
		table.insert(lca_path, path1[index])
		index = index + 1
	end
	return lca_path
end

function IsTreeMultiSelection(selection)
	return type(selection) == "table" and (selection[1] == false or type(selection[1]) == "table")
end

function GedOpTreeMoveItemUp(socket, root, selection)
	if IsTreeMultiSelection(selection) then
		return GedTreeMultiOp(socket, root, "GedOpTreeMoveItemUp", "forward", selection)
	end

	if not selection then return end
	local new_path = table.copy(selection)
	local leaf_idx = table.remove(new_path)
	if leaf_idx > 1 then
		table.insert(new_path, leaf_idx - 1)
		TreeRelocateNode(root, selection, new_path)
		return new_path, function() TreeRelocateNode(root, new_path, selection) end
	end
end

function GedOpTreeMoveItemDown(socket, root, selection)
	if IsTreeMultiSelection(selection) then
		return GedTreeMultiOp(socket, root, "GedOpTreeMoveItemDown", "backward", selection)
	end
	
	if not selection then return end
	local parent = ParentNodeByPath(root, selection)
	local new_path = table.copy(selection)
	local leaf_idx = table.remove(new_path)
	if leaf_idx < #TreeNodeChildren(parent) then
		table.insert(new_path, leaf_idx + 1)
		TreeRelocateNode(root, selection, new_path)
		return new_path, function() TreeRelocateNode(root, new_path, selection) end
	end
end

function GedOpTreeMoveItemInwards(socket, root, selection)
	if IsTreeMultiSelection(selection) then
		return GedTreeMultiOp(socket, root, "GedOpTreeMoveItemInwards", "forward_inwards", selection)
	end

	if not selection then return end
	local parent = ParentNodeByPath(root, selection)
	local new_path = table.copy(selection)
	local leaf_idx = table.remove(new_path)
	if leaf_idx > 1 then
		local parent_leaf_idx = selection.parent_leaf_idx or (leaf_idx - 1)
		local new_parent = TreeNodeChildren(parent)[parent_leaf_idx]
		if not IsKindOf(new_parent, "Container") or not new_parent:IsValidSubItem(TreeNodeChildren(ParentNodeByPath(root, selection))[leaf_idx]) then
			return "error"
		end
		table.insert(new_path, parent_leaf_idx)
		table.insert(new_path, #TreeNodeChildren(new_parent) + 1)
		TreeRelocateNode(root, selection, new_path)
		return new_path, function() TreeRelocateNode(root, new_path, selection) end
	end
end

function GedOpTreeMoveItemOutwards(socket, root, selection)
	if IsTreeMultiSelection(selection) then
		return GedTreeMultiOp(socket, root, "GedOpTreeMoveItemOutwards", "backward_outwards", selection)
	end
	
	if not selection then return end
	local new_path = table.copy(selection)
	local leaf_idx = table.remove(new_path)
	if #new_path > 0 then
		table.insert(new_path, table.remove(new_path) + 1)
		local new_parent = ParentNodeByPath(root, new_path)
		if IsKindOf(new_parent, "Container") and not new_parent:IsValidSubItem(TreeNodeChildren(ParentNodeByPath(root, selection))[leaf_idx]) then
			return "error"
		end
		TreeRelocateNode(root, selection, new_path)
		return new_path, function() TreeRelocateNode(root, new_path, selection) end
	end
end

function RelocateTreeNodes(socket, root, selection, target_path)
	if not selection then return end
	-- 1) replace_default all the members in the selection with false and add them to another table
	-- 2) add them in reverse order to the target path
	-- 3) in reverse order remove all the falses from the original selection
	local node_path, sel_idxs
	if IsTreeMultiSelection(selection) then
		node_path = selection[1]
		sel_idxs = selection[2]
		table.sort(sel_idxs)
	else
		node_path = selection
		sel_idxs = { selection[#selection] }
	end

	local target_parent = ParentNodeByPath(root, target_path)
	if not IsKindOf(target_parent, "Container") then
		return "error"
	end
	local old_parent = ParentNodeByPath(root, node_path)
	local old_children = TreeNodeChildren(old_parent)
	for _, sel_idx in ipairs(sel_idxs) do
		if not target_parent:IsValidSubItem(old_children[sel_idx]) then
			return "error"
		end
	end
	local nodes = sync_set()
	for _, sel_idx in ipairs(sel_idxs) do
		nodes:insert(old_children[sel_idx])
		old_children[sel_idx] = false
	end
	local target_children = TreeNodeChildren(target_parent)
	local target_idx = target_path[#target_path]
	for _, node in ripairs(nodes) do
		table.insert(target_children, target_idx, node)
		ParentTableModified(node, target_children)
	end

	local hole_idxs = {}
	for i = #old_children, 1, -1 do
		if not old_children[i] then
			table.remove(old_children, i)
			hole_idxs[#hole_idxs + 1] = i
		end
	end

	local new_sel_idxs = {}
	for i, child in ipairs(target_children) do
		if nodes[child] then
			new_sel_idxs[#new_sel_idxs + 1] = i
		end
	end

	ObjModified(old_parent)
	ObjModified(target_parent)
	ObjModified(root)
	local sel_path = RecursiveFindTreeItemPath(root, target_children[new_sel_idxs[1]])
	local new_selection = { sel_path, new_sel_idxs }
	return new_selection, function()
		-- undo
		-- 1) add all the falses that were removed by the last do step
		-- 2) remove all the nodes that were added to the target path
		-- 3) fill all the falses with the removed nodes

		for _, hole_idx in ripairs(hole_idxs) do
			table.insert(old_children, hole_idx, false)
		end
		for i in ripairs(nodes) do
			table.remove(target_children, target_idx + i - 1)
		end
		for i, sel_idx in ipairs(sel_idxs) do
			local node = nodes[i]
			old_children[sel_idx] = node
			ParentTableModified(node, target_children)
		end
		ObjModified(old_parent)
		ObjModified(target_parent)
		ObjModified(root)
	end
end

function GedOpTreeDropItemUp(socket, root, selection, drop_path)
	-- drop path is unchanged
	return RelocateTreeNodes(socket, root, selection, drop_path)
end

function GedOpTreeDropItemDown(socket, root, selection, drop_path)
	drop_path[#drop_path] = drop_path[#drop_path] + 1
	return RelocateTreeNodes(socket, root, selection, drop_path)
end

function GedOpTreeDropItemInwards(socket, root, selection, drop_path)
	drop_path[#drop_path + 1] = 1
	return RelocateTreeNodes(socket, root, selection, drop_path)
end

function GedOpTreeDeleteItem(socket, root, selection)
	if IsTreeMultiSelection(selection) then
		return GedTreeMultiOp(socket, root, "GedOpTreeDeleteItem", "delete", selection)
	end
	
	if not selection then return end
	
	local parent = ParentNodeByPath(root, selection)
	local orig_path = table.copy(selection)
	local leaf_idx = table.remove(selection)
	local children = TreeNodeChildren(parent)
	local node = table.remove(children, leaf_idx)
	if not node then
		return "invalid selection"
	end
	
	local new_path = table.copy(selection)
	if leaf_idx <= #children then
		table.insert(new_path, leaf_idx)
	elseif leaf_idx > 1 then
		table.insert(new_path, leaf_idx - 1)
	elseif #new_path == 0 then
		new_path = false
	end
	ObjModified(root)
	if root ~= parent then
		ObjModified(parent)
	end
	
	local mod_id = node.mod and node.mod.id
	local undo_data = GedSerialize(node)
	GedNotifyRecursive(node, "OnEditorDelete", parent, socket)
	node:delete()
	GedNotifyRecursive(node, "OnAfterEditorDelete", parent, socket)
	return new_path, function()
		local err, node = LuaCodeToTuple(undo_data, _G)
		if err then
			print("Ged: Error restoring object", err)
			return
		end
		GedOpTreeNewItem(socket, root, table.copy(orig_path), node, leaf_idx, mod_id)
	end
end

function GedOpTreeNewItemInContainer(socket, root, path, class)
	path = path or {}
	
	-- find the first parent container we can insert the class into
	local path_len
	local obj = root
	local item_class = g_Classes[class]
	for i, key in ipairs(path) do
		if not obj then break end
		if IsKindOf(obj, "Container") and obj:IsValidSubItem(item_class) then
			path_len = i
		end
		obj = rawget(TreeNodeChildren(obj), key)
	end
	-- if there is no suitable parent try the leaf
	if (not path_len or path_len ~= #path) and IsKindOf(obj, "Container") and obj:IsValidSubItem(item_class) then
		path[#path + 1] = #obj
		path_len = #path
	end
	
	if path_len then
		-- cut the unused part of the path
		table.iclear(path, path_len + 1)
		return GedOpTreeNewItem(socket, root, path, class)
	end
end

-- pass idx == "child" to insert a child node (as opposed to a sibling after the currently selected one)
function GedOpTreeNewItem(socket, root, path, class_or_instance, idx, mod_id)
	path = path or {}
	
	local parent = ParentNodeByPath(root, path)
	local selected = TreeNodeByPath(root, unpack_params(path))
	if not GedIsValidObject(parent) and not GedIsValidObject(selected) or idx == "child" then
		idx, parent = "child", selected
	end
	while parent ~= root and IsKindOf(parent, "Container") and not parent:IsValidSubItem(class_or_instance) do
		table.remove(path)
		parent = ParentNodeByPath(root, path)
	end
	if IsKindOf(parent, "Container") and not parent:IsValidSubItem(class_or_instance) then
		return "error"
	end
	
	local item = class_or_instance
	if type(item) == "string" then
		item = _G[item]:new()
		GedNotifyRecursive(item, "OnEditorNew", parent, socket, nil, nil, mod_id)
	end
	
	local children = TreeNodeChildren(parent)
	if not IsParentTableOf(root, item) then -- presets add themselves to the tree in OnEditorNew
		local leaf_idx = max_int
		if idx ~= "child" then
			leaf_idx = idx or (#path == 0 and 1 or path[#path] + 1)
		end
		if leaf_idx > #children then
			table.insert(children, item)
		else
			table.insert(children, leaf_idx, item)
		end
		ParentTableModified(item, children)
	end
	PopulateParentTableCache(item)
	GedNotifyRecursive(item, "OnAfterEditorNew", parent, socket, nil, nil, mod_id)
	
	ObjModified(root)
	if parent ~= root then
		ObjModified(parent)
	end
	
	-- find newly added item path in the tree
	if ParentTableCache[item] == children then
		if idx ~= "child" then table.remove(path) end
		table.insert(path, table.find(children, item))
	else
		path = RecursiveFindTreeItemPath(root, item)
	end
	return path, function() GedOpTreeDeleteItem(socket, root, table.copy(path)) end
end

function GedOpTreeCut(socket, root, selection, item_class)
	GedOpTreeCopy(socket, root, selection, item_class)
	return GedOpTreeDeleteItem(socket, root, selection)
end

function GedOpTreeCopy(socket, root, selection, item_class)
	local node_path, idxs = selection[1], selection[2]
	if node_path then
		local parent = ParentNodeByPath(root, node_path)
		GedCopyToClipboard(parent, item_class, idxs)
	end
end

function GedOpTreePaste(socket, root, selection, items, mod_ids)
	if type(items) ~= "table" and GedClipboard.base_class == "PropertiesContainer" then 
		return GedOpPropertyPaste(socket)
	end
	
	local path = selection[1]
	local parent = path and ParentNodeByPath(root, path) or root
	local paste_into = false
	local restore_from_clipboard = not items or type(items) == "string"
	if restore_from_clipboard then -- restore items from clipboard
		local wrong_container_sibling = GedClipboard.base_class and IsKindOf(parent, "Container") and not parent:IsValidSubItem(GedClipboard.base_class)
		if parent ~= root and (not GedIsValidObject(parent) or wrong_container_sibling) then -- try to paste as child of selected item
			local children = TreeNodeChildren(parent)
			local selected_idxs = selection[2] or empty_table
			table.sort(selected_idxs)
			local idx = (#selected_idxs ~= 0 and selected_idxs[#selected_idxs] or #children)
			local node = children[idx]
			if not GedIsValidObject(node) or GedClipboard.base_class and IsKindOf(node, "Container") and node:IsValidSubItem(GedClipboard.base_class) then
				parent = node
				table.insert(selection[1], 1)
				selection[2] = { 1 }
				path = selection[1]
				paste_into = true
			end
		end
		
		if GedClipboard.base_class and IsKindOf(parent, "Container") and not parent:IsValidSubItem(GedClipboard.base_class) then
			return string.format("Can't paste %s items as children of this object, container of %s.", GedClipboard.base_class, tostring(parent.ContainerClass))
		end
		items = GedRestoreFromClipboard(items)
	end
	
	if items then
		local selected_idxs = selection[2] or empty_table
		table.sort(selected_idxs)
		
		local children = TreeNodeChildren(parent)
		local leaf_idx = (#selected_idxs ~= 0 and selected_idxs[#selected_idxs] or #children) + 1
		if paste_into then leaf_idx = leaf_idx - 1 end
		for i, item in ipairs(items) do
			local mod_id = restore_from_clipboard and GedClipboard.mod_ids and GedClipboard.mod_ids[i] or (mod_ids and mod_ids[i])
			GedNotifyRecursive(item, "OnEditorNew", parent, socket, "paste", nil, mod_id)
			if not IsParentTableOf(root, item) then  -- presets add themselves to the tree in OnEditorNew
				if leaf_idx > #children then
					table.insert(children, item)
				else
					table.insert(children, leaf_idx, item)
				end
				ParentTableModified(item, children)
			end
			PopulateParentTableCache(item)
			leaf_idx = leaf_idx + 1
		end
		
		if items[1] and items[1]:IsKindOf("Preset") then
			items[1]:SortPresets()
		end
		
		-- call OnAfterEditorNew for each item, then find their current indices; it might have re-sorted the children
		for i, item in ipairs(items) do
			local mod_id = restore_from_clipboard and GedClipboard.mod_ids and GedClipboard.mod_ids[i] or (mod_ids and mod_ids[i])
			GedNotifyRecursive(item, "OnAfterEditorNew", parent, socket, "paste", nil, mod_id)
		end
		ObjModified(root)
		if parent ~= root then
			ObjModified(parent)
		end
		
		-- if items are not pasted in the 'children' table, perform a fully recursive search for them to get the selection for Ged
		local items_in_children = true
		for _, item in ipairs(items) do
			if ParentTableCache[item] ~= children then
				items_in_children = false
				break
			end
		end
		local sel = {}
		if items_in_children then
			for _, item in ipairs(items) do
				table.insert(sel, table.find(children, item))
			end
			path = table.copy(path)
			path[Max(#path, 1)] = sel[1]
		else
			path, sel = RecursiveFindTreeItemPaths(root, items)
		end
		
		local selection = path and { path, sel } or nil
		return selection, function() GedOpTreeDeleteItem(socket, root, selection) end
	end
end

function GedOpTreeDuplicate(socket, root, selection, duplicated_class)
	local node_path, idxs = selection[1], selection[2]
	if not node_path then return end

	local parent = ParentNodeByPath(root, node_path)
	for _, idx in ipairs(idxs) do
		if duplicated_class and not IsKindOf(TreeNodeChildren(parent)[idx], duplicated_class) then
			return "error"
		end
	end
	local items, mod_ids = GedDuplicateObjects(parent, idxs)
	if items then
		return GedOpTreePaste(socket, root, selection, items, mod_ids) -- handles undo
	end
end


----- list ops

function GedOpListNewItemInClass(socket, obj, index, class_or_instance, parent_class)
	if not IsKindOf(obj, parent_class) then return "error" end
	return GedOpListNewItem(socket, obj, index, class_or_instance)
end

function GedOpListNewItem(socket, obj, index, class_or_instance)
	if IsKindOf(obj, "Container") and not obj:IsValidSubItem(class_or_instance) then return "error" end
	
	local item = class_or_instance
	if type(item) == "string" then
		item = _G[item]:new()
		GedNotifyRecursive(item, "OnEditorNew", obj, socket)
	end
	index = (index or #obj) + 1
	if index > #obj then
		table.insert(obj, item)
	else
		table.insert(obj, index, item)
	end
	ParentTableModified(item, obj, "recursive")
	GedNotifyRecursive(item, "OnAfterEditorNew", obj, socket)
	ObjModified(obj)
	index = table.find(obj, item) -- OnAfterEditorNew might have re-sorted the children
	return index, function() GedOpListDeleteItem(socket, obj, index) end
end

function GedOpListDeleteItem(socket, obj, selection)
	if type(selection) == "table" then
		return GedListMultiOp(socket, obj, "GedOpListDeleteItem", "delete", selection)
	end
	
	if not selection or not obj[selection] then return end
	local item = table.remove(obj, selection)
	local undo_data = GedSerialize(item)
	GedNotifyRecursive(item, "OnEditorDelete", obj, socket)
	if item then
		item:delete()
	end
	GedNotifyRecursive(item, "OnAfterEditorDelete", obj, socket)
	ObjModified(obj)
	
	return Clamp(selection, 1, #obj), function()
		local err, item = LuaCodeToTuple(undo_data, _G)
		if err then
			print("Ged: Error restoring object", err)
			return
		end
		GedOpListNewItem(socket, obj, selection - 1, item)
	end
end

function GedOpListCut(socket, obj, selection, base_class)
	if #selection == 0 then return end
	GedOpListCopy(socket, obj, selection, base_class)
	return GedOpListDeleteItem(socket, obj, selection)
end

function GedOpListCopy(socket, obj, selection, base_class)
	if #selection == 0 then return end
	GedCopyToClipboard(obj, base_class, selection)
end

function GedOpListPaste(socket, obj, selection, items)
	if type(items) ~= "table" and GedClipboard.base_class == "PropertiesContainer" then 
		local target = obj[selection[#selection]]
		return GedOpPropertyPaste(socket, target)
	end
	
	local index = (#selection > 0 and selection[#selection] or #obj) + 1 -- after last selected object, or at the end
	if not items or type(items) == "string" then -- restore from clipboard
		if GedClipboard.base_class and IsKindOf(obj, "Container") and not obj:IsValidSubItem(GedClipboard.base_class) then
			return "error"
		end
		items = GedRestoreFromClipboard(items)
	end
	
	if items then
		for i = 1, #items do
			local item = items[i]
			GedNotifyRecursive(item, "OnEditorNew", obj, socket, "paste")
			if index > #obj then
				table.insert(obj, item)
			else
				table.insert(obj, index, item)
			end
			ParentTableModified(item, obj, "recursive")
			GedNotifyRecursive(item, "OnAfterEditorNew", obj, socket, "paste")
			index = index + 1
		end
		ObjModified(obj)
		
		local sel = {}
		for _, item in ipairs(items) do
			table.insert(sel, table.raw_find(obj, item)) -- OnAfterEditorNew might have re-sorted the children
		end
		return sel, function() GedOpListDeleteItem(socket, obj, sel) end
	end
end

function GedOpListDuplicate(socket, obj, selection)
	if #selection == 0 then return end
	local items = GedDuplicateObjects(obj, selection)
	if items then
		return GedOpListPaste(socket, obj, { selection[#selection] }, items) -- paste after last object
	end
end

function GedOpListMoveUp(socket, obj, selection)
	if type(selection) == "table" then
		return GedListMultiOp(socket, obj, "GedOpListMoveUp", "forward", selection)
	end
	
	if not selection or selection <= 1 or selection > #obj then return end
	obj[selection], obj[selection - 1] = obj[selection - 1], obj[selection]
	GedNotify(obj[selection], "OnAfterEditorSwap", obj, socket, selection - 1, selection)
	ObjModified(obj)
	return selection - 1, function() GedOpListMoveDown(socket, obj, selection - 1) end
end

function GedOpListMoveDown(socket, obj, selection)
	if type(selection) == "table" then
		return GedListMultiOp(socket, obj, "GedOpListMoveDown", "backward", selection)
	end
	
	if not selection or selection <= 0 or selection >= #obj then return end
	obj[selection], obj[selection + 1] = obj[selection + 1], obj[selection]
	GedNotify(obj[selection], "OnAfterEditorSwap", obj, socket, selection, selection + 1)
	ObjModified(obj)
	return selection + 1, function() GedOpListMoveUp(socket, obj, selection + 1) end
end

local function ListRelocateItems(socket, list, selection, drop_idx)
	if #selection == 0 or not drop_idx then return end
	local sel_map = {}
	for _, sel_idx in ipairs(selection) do
		sel_map[sel_idx] = true
	end
	local new_list = {}
	local i = 1
	local new_list_cnt = 0
	for _, list_item in ipairs(list) do
		if new_list_cnt == drop_idx - 1 then
			break
		end
		if not sel_map[i] then
			new_list_cnt = new_list_cnt + 1
			new_list[new_list_cnt] = list_item
		end
		i = i + 1
	end
	local new_selection = {}
	for _, sel_idx in ipairs(selection) do
		new_list_cnt = new_list_cnt + 1
		new_list[new_list_cnt] = list[sel_idx]
		new_selection[#new_selection + 1] = new_list_cnt
	end
	for j = i, #list do
		if not sel_map[j] then
			new_list_cnt = new_list_cnt + 1
			new_list[new_list_cnt] = list[j]
		end
	end
	local old_list = {}
	for j = 1, new_list_cnt do
		old_list[j] = list[j]
		list[j] = new_list[j]
	end
	GedNotify(list[selection], "OnAfterEditorDragAndDrop", list, socket)
	ObjModified(list)
	return new_selection, function()
		for j = 1, new_list_cnt do
			list[j] = old_list[j]
		end
		GedNotify(list[selection], "OnAfterEditorDragAndDrop", list, socket)
		ObjModified(list)
		return selection
	end
end

function GedOpListDropUp(socket, obj, selection, drop_idx)
	if type(selection) == "number" then
		selection = { selection }
	end
	if selection[1] < drop_idx then
		drop_idx = Max(1, drop_idx - 1)
	end
	return ListRelocateItems(socket, obj, selection, drop_idx)
end

function GedOpListDropDown(socket, obj, selection, drop_idx)
	if type(selection) == "number" then
		selection = { selection }
	end
	if selection[1] > drop_idx then
		drop_idx = Min(#obj, drop_idx + 1)
	end
	return ListRelocateItems(socket, obj, selection, drop_idx)
end

----- Nested obj / nested list / script

function GedCreateNestedObj(socket, obj, prop_id, class)
	if not class or class == "" then return end
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	local old_value = obj:GetProperty(prop_id)
	local new_value = _G[class]:new()
	GedNotifyRecursive(new_value, "OnEditorNew", obj, socket)
	
	ged_set_prop(socket, obj, prop_id, new_value, old_value)
	GedNotifyRecursive(new_value, "OnAfterEditorNew", obj, socket)
	return nil, function() ged_set_prop(socket, obj, prop_id, old_value, new_value) end
end

if FirstLoad then
	g_EditedScript = false
	g_EditedScriptParent = false
	g_EditedScriptPropMeta = false
end

function OnMsg.GedObjectModified(obj)
	if obj == g_EditedScript then
		g_EditedScript:Compile()
		ObjModified(g_EditedScriptParent)
	end
end

function OnMsg.GedClosing(ged_id)
	if GedConnections[ged_id].app_template == "GedScriptEditor" then
		local parent = g_EditedScriptParent
		g_EditedScript = false
		g_EditedScriptParent = false
		g_EditedScriptPropMeta = false
		ObjModified(parent) -- remove highlight from currently edited script property
	end
end

function GedSaveScriptParentPreset(socket)
	if g_EditedScript then
		local preset = GetParentTableOfKind(g_EditedScript, "Preset")
		CreateRealTimeThread(function()
			GedSetUiStatus("preset_save", "Saving...")
			preset:Save(true)
			Sleep(200)
			GedSetUiStatus("preset_save")
		end, preset)
	end
end

function GedTestScript(socket)
	g_EditedScriptParent:Test(nil, nil, socket)
end

function GedCreateOrEditScript(socket, obj, prop_id, value)
	value = obj:GetProperty(prop_id) or value
	
	local undo_fn
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	if not value or type(value) == "string" then
		local class = value and g_Classes[value] or ScriptProgram
		value = class:new{ Params = prop_eval(prop_meta.params, obj, prop_meta) }
		ged_set_prop(socket, obj, prop_id, value)
		undo_fn = function() ged_set_prop(socket, obj, prop_id, nil) end
	end
	
	g_EditedScript, g_EditedScriptParent, g_EditedScriptPropMeta = value, obj, prop_meta
	ObjModified(obj) -- add highlight to currently edited script property
	if value.err then
		value:Compile() -- make sure GetFuncSource will work, and the script code will be displayed in 'eval', in the case of a compilation error
	end
	
	local ged = OpenGedAppSingleton("GedScriptEditor", value, {
		WarningsUpdateRoot = "root",
		ItemClass = value.ContainerClass,
		ScriptPresetClass = GetParentTableOfKind(g_EditedScript, "Preset").class,
		ScriptDomain = prop_meta.script_domain
	})
	local params = prop_eval(prop_meta.params, obj, prop_meta)
	if value.Params ~= params then
		ged:ShowMessage("Warning", string.format("Parameters changed from '%s' to '%s'.\n\nPlease fix the script accordingly!", value.Params, params))
		value.Params = params
	end
	return nil, undo_fn
end

function GedOpNestedListNewItem(socket, parent, parent_name, property_name, index, class_or_instance)
	local list_created = false
	local obj = parent:GetProperty(property_name)
	local obj_name = string.format("%s.%s", parent_name, property_name)
	if not obj then
		obj = {}
		parent:SetProperty(property_name, obj)
		-- send the Msg immediately, so GedMultiSelectAdapter updates nested_obj/nested_list props before the OnEditorSetProperty call
		ObjModified(parent, "instant")
		ParentTableModified(obj, parent)
		socket:rfnBindObj(obj_name, { parent_name, property_name })
		list_created = true
	end
	
	local selection, undo = GedOpListNewItem(socket, obj, index, class_or_instance)
	socket:NotifyEditorSetProperty(parent, property_name)
	ObjModified(parent)
	return nil, function()
		undo()
		if list_created then
			parent:SetProperty(property_name, false)
		end
		ObjModified(parent)
	end
end

function GedNestedObjCopy(socket, parent, prop_id, base_class)
	GedCopyToClipboard(parent, base_class, { prop_id })
end

function GedNestedObjPaste(socket, parent, prop_id, base_class)
	if not IsKindOf(g_Classes[GedClipboard.base_class], base_class) then
		local obj_text = GedClipboard.base_class == "PropertiesContainer" and "properties" or string.format("a %s object", GedClipboard.base_class)
		return string.format("Can't paste %s here.", obj_text)
	end
	
	local old_value = parent:GetProperty(prop_id)
	local new_value = GedRestoreFromClipboard(base_class)[1]
	GedNotifyRecursive(new_value, "OnEditorNew", parent, socket, "paste")
	parent:SetProperty(prop_id, new_value)
	ParentTableModified(new_value, parent, "recursive")
	GedNotifyRecursive(new_value, "OnAfterEditorNew", parent, socket, "paste")
	ObjModified(parent)
	return nil, function() parent:SetProperty(prop_id, old_value) ObjModified(parent) end
end

function GedNestedListCopy(socket, obj, base_class)
	if not obj then return end
	local idxs = {}
	for i = 1, #obj do idxs[#idxs + 1] = i end
	GedCopyToClipboard(obj, base_class, idxs)
end

function GedNestedListPaste(socket, parent, prop_id, base_class)
	if not IsKindOf(g_Classes[GedClipboard.base_class], base_class) then
		local obj_text = GedClipboard.base_class == "PropertiesContainer" and "properties" or string.format("%s objects", GedClipboard.base_class)
		return string.format("Can't paste %s here.", obj_text)
	end
	
	local old_value = parent:GetProperty(prop_id)
	local new_value = GedRestoreFromClipboard(base_class)
	for _, item in ipairs(new_value) do
		GedNotifyRecursive(item, "OnEditorNew", parent, socket, "paste")
	end
	parent:SetProperty(prop_id, new_value)
	ParentTableModified(new_value, parent, "recursive")
	for _, item in ipairs(new_value) do
		GedNotifyRecursive(item, "OnAfterEditorNew", parent, socket, "paste")
	end
	ObjModified(parent)
	return nil, function() parent:SetProperty(prop_id, old_value) ObjModified(parent) end
end

----- Preset ops

function GedPresetTree(obj, filter, format)
	format = format and format ~= "" and T{format} or nil
	local tree = {}
	local start_time = GetPreciseTicks()
	if filter then
		filter:PrepareForFiltering()
	end
	local total_displayed_items = 0
	for i, group in ipairs(obj or empty_table) do
		local tree_group = {}
		local preset_ids = { id = tostring(group) }
		local displayed_in_group = 0
		for j, preset in ipairs(group) do
			local item = {
				id = tostring(preset),
				name = format and GedTranslate(format, preset, not "check") or preset.id,
				rollover = preset:GetPresetRolloverText(),
			}
			if filter and not filter:FilterObject(preset) then
				item.filtered = true
			else
				displayed_in_group = displayed_in_group + 1
			end
			tree_group[j] = item
		end
		tree_group.name = string.format("%s <color 75 105 198>(%d)", group[1].group, displayed_in_group)
		tree_group.collapsed = GedTreePanelCollapsedNodes[group]
		tree_group.id = tostring(group)
		tree_group.filtered = filter and displayed_in_group == 0
		total_displayed_items = total_displayed_items + displayed_in_group
		tree[i] = tree_group
	end
	local _time = GetPreciseTicks() - start_time
	if _time > 500 then
		print("GedPresetTree took", _time, "ms")
	elseif _time > 50 then
		preset_print("GedPresetTree took %i ms", _time)
	end
	if filter then
		filter:DoneFiltering(total_displayed_items)
	end
	return tree
end

function GedFormatPresets(obj, filter, format)
	local count = 0
	for _, group in ipairs(obj or empty_table) do
		count = count + #group
	end
	return string.format("%s (%d)", GedFormatObject(obj, filter, format), count)
end

GedOpNewPreset = GedOpTreeNewItem
GedOpPresetDelete = GedOpTreeDeleteItem
GedOpPresetCut = GedOpTreeCut
GedOpPresetCopy = GedOpTreeCopy
GedOpPresetPaste = GedOpTreePaste
GedOpPresetDuplicate = GedOpTreeDuplicate

if FirstLoad then
	GedPresetSaveInProgress = false
	GedPresetSaveModsInProgress = false
end

function GedPresetSave(ged, obj, class_name, force_save_all)
	local class = _G[class_name]
	if class and not IsValidThread(GedPresetSaveInProgress) then
		local thread = CanYield() and CurrentThread()
		GedPresetSaveInProgress = CreateRealTimeThread(function()
			SuspendObjModified("preset_save")
			GedSetUiStatus("preset_save", "Saving...")
			class:SaveAll(force_save_all, "by_user_request", ged)
			GedSetUiStatus("preset_save")
			ResumeObjModified("preset_save")
			GedPresetSaveInProgress = false
			Wakeup(thread)
		end)
		if thread then WaitWakeup(30000) end
	end
end

function GedPresetSaveOne(ged, obj, class_name)
	obj = ged:ResolveObj(obj)
	if IsKindOf(obj, "Preset") and not IsValidThread(GedPresetSaveInProgress) then
		local thread = CanYield() and CurrentThread()
		GedPresetSaveInProgress = CreateRealTimeThread(function()
			SuspendObjModified("preset_save")
			GedSetUiStatus("preset_save", "Saving...")
			obj:Save("by_user_request", ged)
			GedSetUiStatus("preset_save")
			ResumeObjModified("preset_save")
			GedPresetSaveInProgress = false
			Wakeup(thread)
		end)
		if thread then WaitWakeup(30000) end
	end
end

function GedPresetSaveMods(ged, obj, class_name)
	if not IsValidThread(GedPresetSaveModsInProgress) then
		local thread = CanYield() and CurrentThread()
		GedPresetSaveModsInProgress = CreateRealTimeThread(function()
			-- Save the mods of edited ModItemPresets
			local mods = {}
			ForEachPresetExtended(class_name, function(preset, group)
				if preset.mod and (preset:IsDirty() or preset.mod:IsDirty()) and IsKindOf(preset, "ModItemPreset") and not preset:IsPacked() then
					mods[preset.mod] = preset.mod
				end
			end)
			
			local can_save = true
			for _, mod in pairs(mods) do
				if not mod:CanSaveMod(ged) then
					can_save = false
					break
				end
			end
			if can_save then
				GedSetUiStatus("mod_save", "Saving mods...")
				for _, mod in pairs(mods) do
					mod:SaveWholeMod()
					-- Update Mod Editor tree panel (if open)
					ObjModifiedMod(mod)
				end
				GedSetUiStatus("mod_save")
			end
			
			GedSetUiStatus("mod_save")
			GedPresetSaveModsInProgress = false
			Wakeup(thread)
		end)
		if thread then WaitWakeup(30000) end
	end
end

function GedOpOpenPresetEditor(socket, presets, selection, class)
	if not selection or #selection ~= 2 or #selection[1] ~= 2 then return end
	local group = presets[selection[1][1]]
	CreateRealTimeThread(function()
		for _, sel in ipairs(selection[2]) do
			local preset_id = group[sel].id
			if group[sel].class == "PresetDef" and PresetDefs[preset_id].DefEditorName then
				OpenPresetEditor(preset_id)
			end
		end
	end)
end

function GedOpSVNShowLog(socket, obj)
	if obj and IsKindOf(obj, "Preset") then 
		local file_path = obj:GetSavePath()
		if not file_path then return end
		SVNShowLog(file_path)
	end
end

function GedOpSVNShowBlame(socket, obj)
	if obj and IsKindOf(obj, "Preset") then
		local file_path = obj:GetSavePath()
		if not file_path then return end
		SVNShowBlame(file_path)
	end
end

local function LocatePreset(obj, class)
	if obj == class then
		return true
	end
	if type(obj) ~= "table" or IsT(obj) then
		return
	end
	if obj.class == class then
		return true
	end
	for _, item in ipairs(obj) do
		if LocatePreset(item, class) then
			return true
		end
	end
	if not obj.class then
		return
	end
	for _, prop in ipairs(obj:GetProperties()) do
		if prop.editor == "nested_obj" or prop.editor == "nested_list" or prop.editor == "script" or
			prop.editor == "preset_id" or prop.editor == "preset_id_list" or prop.editor == "property_array" or
			prop.editor == "combo" or prop.editor == "choice" or prop.editor == "dropdownlist" or prop.editor == "text_picker"
		then
			local item = obj:GetProperty(prop.id)
			if LocatePreset(item, class) then
				return true
			end
		end
	end
end

function GedOpLocatePreset(socket, obj)
	if not obj or not IsKindOf(obj, "Preset") then
		print("Can locate only presets!")
		return
	end
	local id = obj.id
	local hits = {}
	PauseInfiniteLoopDetection("LocatePreset")
	for name, groups in pairs(Presets) do
		for _, presets in ipairs(groups) do
			for _, preset in ipairs(presets) do
				if preset ~= obj and LocatePreset(preset, id) then
					hits[#hits + 1] = {name, preset.group, preset.id, preset.save_in}
				end
			end
		end
	end
	ResumeInfiniteLoopDetection("LocatePreset")
	print(#hits, "locations found for", obj.id)
	for i, hit in ipairs(hits) do
		print(" ", table.unpack(hit))
	end
end

if FirstLoad then
	l_GoToNext_id = false
	l_GoToNext_last = false
end

function GedOpGoToNext(socket, obj)
	if not obj or not IsKindOf(obj, "Preset") then
		print("Can locate only presets!")
		return
	end
	local id = obj.id
	while true do
		if l_GoToNext_id ~= id then
			l_GoToNext_id = id
			l_GoToNext_last = false
		end
		local search = not l_GoToNext_last
		for name, groups in pairs(Presets) do
			for _, presets in ipairs(groups) do
				for _, preset in ipairs(presets) do
					if search then
						if preset ~= obj and LocatePreset(preset, id) then
							l_GoToNext_last = preset
							print("Next occurence of", id, "is located in", preset.class, preset.group, preset.id, preset.save_in)
							CreateRealTimeThread(function()
								local ged = OpenPresetEditor(preset.class, preset:EditorContext())
								if ged then
									ged:SetSelection("root", PresetGetPath(preset))
								end
							end)
							return
						end
					elseif l_GoToNext_last == preset then
						search = true
					end
				end
			end
		end
		if not l_GoToNext_last then
			break
		end
		l_GoToNext_last = false
	end
	print("Cannot find any reference of", obj.id)
end

function GedOpSVNShowDiff(socket, obj)
	if obj and IsKindOf(obj, "Preset") then
		local file_path = obj:GetSavePath()
		if not file_path then return end
		SVNShowDiff(file_path)
	end
end


----- Game object ops (in list panel)

function GedOpObjectCut(socket, obj, selection)
	if #selection == 0 then return end
	GedOpObjectCopy(socket, obj, selection)
	return GedOpListDeleteItem(socket, obj, selection)
end

function GedOpObjectCopy(socket, obj, selection)
	if #selection == 0 then return end
	local objs = {}
	for _, idx in ipairs(selection) do
		table.insert(objs, obj[idx])
	end
	editor.ClearSel()
	editor.AddToSel(objs)
	editor.CopyToClipboard()
	GedClipboard.base_class = false -- to make sure any stored objects in Ged's own clipboard won't mess up the Paste op
	
	GedDisplayTempStatus("clipboard", string.format("%d game objects copied", #objs))
end

function GedOpObjectPaste(socket, obj)
	if GedClipboard.base_class == "PropertiesContainer" then 
		return GedOpPropertyPaste(socket)
	end
	editor.PasteFromClipboard()
	return nil, function() XEditorUndoQueue:UndoRedo("undo") end
end

function GedOpObjectDuplicate(socket, obj, selection)
	GedOpObjectCopy(socket, obj, selection)
	return GedOpObjectPaste(socket, obj)
end


----- General

function GedCallMethod(ged, obj_name, method, ...)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	obj[method](obj, ...)
end

function GedObjModified(ged, obj_name, ...)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	ObjModified(obj)
end

----- Copy/paste of property values

local eval = prop_eval

function GedOpPropertyCopy(socket, obj, properties, panel_context)
	if #properties == 0 then return end

	GedClipboard.base_class = "PropertiesContainer"
	local copy_data = { id = {}, value = {}, editor = {}, panel_context = false,  }
	local os_clipboard_data = {}
	for i, id in ipairs(properties) do
		local property_value = obj:GetProperty(id)
		local meta_data = obj:GetPropertyMetadata(id)
		copy_data.id[#copy_data.id + 1] = id
		copy_data.value[#copy_data.value + 1] = property_value
		local editor = eval(meta_data.editor, obj, meta_data)
		copy_data.editor[#copy_data.editor + 1] = editor
		local editor_class = g_Classes[GedPropEditors[editor]]
		if editor_class and editor_class.ConvertToText then
			local text = editor_class:ConvertToText(property_value, meta_data)
			text = IsT(text) and TDevModeGetEnglishText(text) or text
			if type(text) == "string" and #text > 0 then
				os_clipboard_data[#os_clipboard_data + 1] = IsT(text) and TDevModeGetEnglishText(text) or text
			end
		end
	end
	copy_data.panel_context = panel_context
	GedPropertiesContainer.data = copy_data
	GedClipboard.stored_objs = ValueToLuaCode(GedPropertiesContainer)
	if #os_clipboard_data > 0 then
		CopyToClipboard(table.concat(os_clipboard_data, "\n"))
	end
	GedDisplayTempStatus("clipboard", string.format("%d properties copied", #properties))
end

function ShowPropertyPasteWarning(socket, prop_ids)
	local text = "Properties with IDs: "
	for i=1, #prop_ids do
		text = text..prop_ids[i]
		if i == #prop_ids then 
			text = text.." could not be pasted!" 
		else 
			text = text..", " 
		end
	end
	socket:ShowMessage("Warning!", text)
end

local function CanUseTargetProperties(target, source_ids, source_editors, target_ids)
	if #source_ids ~= #(target_ids or "") then
		return false
	end
	for i = 1, #source_ids do
		local dst_id = target_ids[i]
		local dst_meta_data = target:GetPropertyMetadata(dst_id)
		if not dst_meta_data then
			return false
		end
		if source_editors[i] ~= eval(dst_meta_data.editor, target, dst_meta_data) then
			return false
		end
		local src_id = source_ids[i]
		local src_prefix = string.find(src_id, "%d+$" )
		local dst_prefix = string.find(dst_id, "%d+$" )
		if not src_prefix or src_prefix ~= dst_prefix then
			return false
		end
		if string.sub(src_id, 1, src_prefix - 1) ~= string.sub(dst_id, 1, dst_prefix - 1) then
			return false
		end
	end
	return true
end

function GedOpPropertyOSClipboardPaste(socket, target, target_properties, panel_context)
	if not IsKindOf(target, "PropertyObject") or #target_properties == 0 then return end
	local objs = IsKindOf(target, "GedMultiSelectAdapter") and target.__objects or { target }
	if not objs then return end
	local clipboard_split = string.split(GetFromClipboard(-1), "\n")
	local old_values
	for i = 1, Min(#clipboard_split, #target_properties) do
		local target_property = target_properties[i]
		local clipboard = clipboard_split[i]
		local meta_data = target:GetPropertyMetadata(target_property)
		if meta_data and not eval(meta_data.no_edit, target, meta_data) then
			local editor_class = g_Classes[GedPropEditors[meta_data.editor]]
			if editor_class and editor_class.accept_os_clipboard_paste and editor_class.ConvertFromText then
				local ok, value, invalid = pcall(editor_class.ConvertFromText, editor_class, clipboard, meta_data)
				if ok or invalid then
					local id = meta_data.id
					for _, obj in ipairs(objs) do
						local old_value = obj:GetProperty(id)
						old_values = old_values or {}
						old_values[obj] = old_values[obj] or {}
						old_values[obj][id] = old_value
						ged_set_prop(socket, obj, id, value, old_value)
					end
				end
			end
		end
	end
	if not old_values then return end
	ObjModified(target)
	socket:OnParentsModified(panel_context) -- the change might affect how our object is displayed in the parent object(s)
	return nil, function()
		for obj, obj_data in pairs(old_values) do
			for id, value in pairs(obj_data) do
				ged_set_prop(socket, obj, id, value, obj:GetProperty(id))
			end
		end
		ObjModified(target)
		socket:OnParentsModified(panel_context) -- the change might affect how our object is displayed in the parent object(s)
	end
end

function GedOpPropertyPaste(socket, target_override, target_properties, panel_context)
	local _, os_clipboard_undo_func = GedOpPropertyOSClipboardPaste(socket, target_override, target_properties, panel_context)
	if os_clipboard_undo_func then
		return nil, os_clipboard_undo_func
	end

	if GedClipboard.base_class ~= "PropertiesContainer" or not GedClipboard.stored_objs then return end 

	local err, container = LuaCodeToTuple(GedClipboard.stored_objs, _G)
	if err then
		print("Ged: Error restoring object", err)
		return
	end
	GenerateLocalizationIDs(container)
	
	local data = container.data
	local target = socket:ResolveObj(data.panel_context)
	if target_override and target_override:IsKindOf("PropertyObject") then
		if CanUseTargetProperties(target_override, data.id, data.editor, data.id) then
			target = target_override
		end
	end
	if not target then
		print("Failed to find a target to receive the copied properties!")
		return
	end
	local objs = target:IsKindOf("GedMultiSelectAdapter") and target.__objects or { target }
	
	local dst_prop_ids = CanUseTargetProperties(target, data.id, data.editor, target_properties) and target_properties or data.id
	local old_values = {} -- obj => { id => value }
	local pasted_ids, unmatched_ids = {}, {}
	for i = 1, #dst_prop_ids do
		local id = dst_prop_ids[i]
		local meta_data = target:GetPropertyMetadata(id)
		if meta_data and eval(meta_data.editor, target, meta_data) == data.editor[i] and not eval(meta_data.no_edit, target, meta_data) then
			local value = data.value[i]
			for _, obj in ipairs(objs) do
				local old_value = obj:GetProperty(id)
				old_values[obj] = old_values[obj] or {}
				old_values[obj][id] = old_value
				ged_set_prop(socket, obj, id, value, old_value)
			end
			pasted_ids[#pasted_ids + 1] = id
		else
			unmatched_ids[#unmatched_ids + 1] = id
		end
	end
	ObjModified(target)
	socket:OnParentsModified(data.panel_context) -- the change might affect how our object is displayed in the parent object(s)
	
	socket:Send("rfnApp", "SetPropSelection", data.panel_context, pasted_ids)
	if #unmatched_ids ~= 0 then
		ShowPropertyPasteWarning(socket, unmatched_ids)
	end
	
	local undo_func = function()
		for obj, obj_data in pairs(old_values) do
			for id, value in pairs(obj_data) do
				ged_set_prop(socket, obj, id, value, obj:GetProperty(id))
			end
		end
		ObjModified(target)
		socket:OnParentsModified(data.panel_context) -- the change might affect how our object is displayed in the parent object(s)
	end
	return nil, undo_func
end

function GedEditFunction(ged, obj_name, props)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	if not props or #props ~= 1 then return end

	local prop = props[1]
	if not prop then return end

	local value = obj:GetProperty(prop)
	if IsKindOf(value, "ScriptProgram") then
		value = value.eval
	end
	if type(value) ~= "function" then return end
	
	local info = debug.getinfo(value, "S")
	local first, last = info.linedefined, info.lastlinedefined
	local source = info.source
	if not info or not source or not first or not last then return end
	OpenFileLineInHaerald(source:sub(2), first)
end

function GedOpPresetIdNewInstance(ged, obj, prop_id, class_name)
	local id = ged:WaitUserInput("New Preset Name", class_name)
	if not id then return end
	
	local class = g_Classes[class_name]
	local preset = class:new{ id = id }
	local presets = Presets[class.PresetClass or class.class]
	GedNotifyRecursive(preset, "OnEditorNew", presets[preset.group] or presets, ged)
	PopulateParentTableCache(preset)
	GedNotifyRecursive(preset, "OnAfterEditorNew", presets[preset.group], ged)
	
	preset:OpenEditor()
	
	local old_value = obj:GetProperty(prop_id)
	obj:SetProperty(prop_id, preset.id)
	ObjModified(obj)
	
	return false, function()
		preset:delete()
		obj:SetProperty(prop_id, old_value)
		ObjModified(presets)
		ObjModified(obj)
	end
end

function PresetIdPropFindInstance(obj, prop_meta, id)
	local class_name = eval(prop_meta.preset_class, obj, prop_meta)
	local group_name = eval(prop_meta.preset_group, obj, prop_meta)
	local class = class_name and g_Classes[class_name]
	if not class then
		assert(false, "Preset class not found: " .. tostring(class_name))
		return
	end
	assert(class.GlobalMap or IsPresetWithConstantGroup(class) or group_name)
	if class.GlobalMap then
		return _G[class.GlobalMap][id]
	else
		group_name = group_name or class.group
		local preset_class = class.PresetClass or class_name
		local groups = Presets[preset_class]
		local presets = groups and groups[group_name]
		return presets and presets[id]
	end
end

function GedRpcEditPreset(ged, obj_name, prop_id, preset_id)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	
	if not prop_id and not preset_id then
		obj:OpenEditor() -- used by "linked_presets" property
		return
	end
	
	preset_id = preset_id or obj:GetProperty(prop_id)
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	local preset = PresetIdPropFindInstance(obj, prop_meta, preset_id)
	if preset then
		preset:OpenEditor()
	else
		local class = g_Classes[prop_meta.preset_class]
		if class then
			OpenPresetEditor(class.PresetClass or class.class)
		end
	end
end

function GedRpcBindPreset(ged, name, obj_name, prop_id, preset_id)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	
	preset_id = preset_id or obj:GetProperty(prop_id)
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	local preset = prop_meta and PresetIdPropFindInstance(obj, prop_meta, preset_id)
	if preset then
		ged:BindObj(name, preset)
	else
		ged:UnbindObj(name)
	end
end

function GedRpcInspectObj(ged, obj_name, prop_id, prop_obj)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	prop_obj = prop_obj or obj:GetProperty(prop_id)
	OpenGedGameObjectEditorInGame(prop_obj)
end

function GedViewPosButton(root, obj, prop_id, ged)
	local pos = obj:GetProperty(prop_id)
	if not IsValidPos(pos) then
		return
	end
	local local_space = pos:Len() < 5000 or table.get(obj:GetPropertyMetadata(prop_id), "local_space")
	if local_space and (not pos:z() or not IsValidPos(obj)) then
		return
	end
	pos = ValidateZ(pos)
	local pos0 = local_space and obj:GetVisualPos() or pos
	local vec = local_space and SetLen(pos, 2*guim) or 2*guim
	local color = local_space and red or white
	local v = PlaceVector(pos0, vec, color)
	local c = PlaceCircle(pos0, guim/2, color)
	if local_space then
		c:SetOrientation(vec)
	end
	ViewPos(pos0)
	Msg("RpcViewPos")
	CreateRealTimeThread(function()
		WaitMsg("RpcViewPos", 5000)
		DoneObject(v)
		DoneObject(c)
	end)
end

----- Support for "linked_presets" property

function FindLinkedPresetOfClass(obj, preset_class, id, save_in)
	id = id or obj.id
	save_in = save_in or obj.save_in

	local found
	ForEachPresetExtended(preset_class, function(preset)
		if preset.id == id and preset.save_in == save_in then
			found = preset
			return "break"
		end
	end)
	return found
end

function GedCreateLinkedPresets(root, obj, prop_id, ged)
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	local classes = eval(prop_meta.preset_classes, obj, prop_meta)
	for _, preset_class in ipairs(classes) do
		local preset = g_Classes[preset_class]:new{ id = obj.id, save_in = obj.save_in }
		preset:Register()
		for prop, value in pairs(prop_meta.default_props[preset_class]) do
			preset:SetProperty(prop, value)
		end
		for prop, how in pairs(prop_meta.mirror_props[preset_class]) do
			if type(how) == "function" then
				preset:SetProperty(prop, how(obj))
			else
				preset:SetProperty(prop, obj:GetProperty(how)) -- "how" is name of property to copy
			end
		end
		preset:MarkDirty()
		ObjModified(Presets[preset_class])
	end
	ObjModified(obj)
end

function GedDeleteLinkedPresets(root, obj, prop_id, ged)
	local prop_meta = obj:GetPropertyMetadata(prop_id)
	local classes = eval(prop_meta.preset_classes, obj, prop_meta)
	for _, preset_class in ipairs(classes) do
		local preset = FindLinkedPresetOfClass(obj, preset_class)
		if preset then
			preset:delete()
			ObjModified(Presets[preset_class])
		end
	end
	ObjModified(obj)
end

function GedRpcBindLinkedPreset(ged, name, obj_name, preset_class)
	local obj = ged:ResolveObj(obj_name)
	if not obj then return end
	
	local preset = FindLinkedPresetOfClass(obj, preset_class)
	if preset then
		ged:BindObj(name, preset)
	else
		ged:UnbindObj(name)
	end
end

LinkedPresetClasses = {}     -- <parent preset class> => { <linked class 1>, <linked class 2>, ... }
LinkedPresetMirrorProps = {} -- <property id> => { <copy from> => { <copy to>, <how> }, ... }

local function add_mirror_prop(class, linked_class, prop_id, how, final)
	local prop_data = LinkedPresetMirrorProps[prop_id] or {}
	table.insert(prop_data, { copy_from_class = class, copy_to_class = linked_class, how = how })
	LinkedPresetMirrorProps[prop_id] = prop_data
	
	-- directly mirrored properties are also copied back
	if not final and type(how) == "string" then
		add_mirror_prop(linked_class, class, how, prop_id, "final")
	end
end

function OnMsg.ClassesPostBuilt()
	ClassDescendantsList("Preset", function(class_name, class)
		if class.GedEditor and (not class:IsKindOf("CompositeDef") or class.ObjectBaseClass) then
			for _, prop_meta in ipairs(class:GetProperties()) do
				if prop_meta.editor == "linked_presets" then
					local classes = eval(prop_meta.preset_classes, class, prop_meta)
					LinkedPresetClasses[class_name] = table.iappend(LinkedPresetClasses[class_name] or {}, prop_meta.classes)
					
					for _, linked_class in ipairs(classes) do
						for prop_id, how in pairs(prop_meta.mirror_props[linked_class]) do
							add_mirror_prop(class_name, linked_class, prop_id, how) -- "BuildingCompositeDef", "Resource", "display_name", "display_name"
						end
						add_mirror_prop(class_name, linked_class, "SaveIn", "SaveIn")
						add_mirror_prop(class_name, linked_class, "Id", "Id")
					end
				end
			end
		end
	end)
end

local function mirror_prop(mirror_data, class, obj, prop_id, preset_id, preset_savein, processed_classes)
	for _, data in ipairs(mirror_data) do
		local from, to = data.copy_from_class, data.copy_to_class
		if from == class and not processed_classes[to] then
			-- mirror property
			local how = data.how
			local target = FindLinkedPresetOfClass(obj, to, preset_id, preset_savein)
			if target then
				if type(how) == "function" then
					target:SetProperty(prop_id, how(obj))
				else
					print("Set", prop_id, "from", from, "to", to)
					target:SetProperty(prop_id, obj:GetProperty(how)) -- "how" is name of property to copy
				end
			end
			
			processed_classes[to] = true
			mirror_prop(mirror_data, to, obj, prop_id, preset_id, preset_savein, processed_classes)
		end
	end
end

local function mirror_prop_message(ged, classes, prop_id)
	ged:ShowMessage("Linked Presets", 
		string.format("<center>The '%s' property was also updated\nin linked preset(s) %s.", prop_id, table.concat(table.keys2(classes, "sorted"), ", ")))
end

function OnMsg.GedPropertyEdited(ged_id, obj, prop_id, old_value)
	local data = LinkedPresetMirrorProps[prop_id]
	if data then
		local preset_id     = prop_id == "Id"     and old_value or obj.id
		local preset_savein = prop_id == "SaveIn" and old_value or obj.save_in
		local processed_classes = { [obj.class] = true }
		mirror_prop(data, obj.class, obj, prop_id, preset_id, preset_savein, processed_classes)
		
		processed_classes[obj.class] = nil
		if next(processed_classes) then
			DelayedCall(50, mirror_prop_message, GedConnections[ged_id], processed_classes, prop_id)
		end
	end
end

function OnMsg.PresetSave(class)
	-- go through dirty objects; if the preset they are linked to is of 'class', save them
	local dirty_paths = {}
	for obj in pairs(g_DirtyObjects) do
		for parent_preset, linked_presets in pairs(LinkedPresetClasses) do
			if table.find(linked_presets, obj.class) then
				local parent_preset = FindLinkedPresetOfClass(obj, parent_preset)
				if parent_preset and parent_preset.class == class then
					local paths = dirty_paths[obj.class] or {}
					paths[obj:GetNormalizedSavePath()] = true
					paths[obj:GetLastSavePath()] = true
					dirty_paths[obj.class] = paths
				end
			end
		end
	end
	
	for class, paths in pairs(dirty_paths) do
		_G[class]:SaveFiles(paths)
	end
end
