local unavailable_msg = "Not available in game mode! Retry in the editor!"

function Collection:GetLocked()
	return self.Index == editor.GetLockedCollectionIdx()
end

function Collection:SetLocked(locked)
	local idx = self.Index
	if idx == 0 then
		return
	end
	local prev_locked = self:GetLocked()
	if locked and prev_locked or not locked and not prev_locked then
		return
	end
	Collection.UnlockAll()
	if prev_locked then
		return
	end
	editor.ClearSel()
	editor.SetLockedCollectionIdx(idx)
	MapSetGameFlags(const.gofWhiteColored, "map", "CObject")
	MapForEach("map", "collection", idx, true, function(o) o:ClearHierarchyGameFlags(const.gofWhiteColored) end)
end

function Collection.GetLockedCollection()
	local locked_idx = editor.GetLockedCollectionIdx()
	return locked_idx ~= 0 and Collections[locked_idx]
end

function Collection.UnlockAll()
	if editor.GetLockedCollectionIdx() == 0 then
		return false
	end
	editor.SetLockedCollectionIdx(0)
	MapClearGameFlags(const.gofWhiteColored, "map", "CObject")
	return true
end

-- clone the collections in the given group of objects
function Collection.Duplicate(objects)
	local duplicated = {}
	local collections = {}
	-- clone and assign collections:
	local locked_idx = editor.GetLockedCollectionIdx()
	for i = 1, #objects do
		local obj = objects[i]
		if IsValid(obj) then
			local col = obj:GetCollection()
			if not col then
				obj:SetCollectionIndex(locked_idx)
			elseif col.Index ~= locked_idx then
				local new_col = duplicated[col]
				if not new_col then
					new_col = col:Clone()
					duplicated[col] = new_col
					collections[#collections + 1] = col
				end
				obj:SetCollection(new_col)
			else
				obj:SetCollection(col)
			end
		end
	end
	
	-- fix collection hierarchy
	local i = #collections
	while i > 0 do
		local col = collections[i]
		local new_col = duplicated[col]
		local parent = col:GetCollection()
		i = i - 1
		
		if parent and parent.Index ~= locked_idx then
			local new_parent = duplicated[parent]
			if not duplicated[parent] then
				new_parent = parent:Clone()
				duplicated[parent] = new_parent
				i = i + 1
				collections[i] = parent
			end
			new_col:SetCollection(new_parent)
		else
			new_col:SetCollectionIndex(locked_idx)
		end
	end
	
	UpdateCollectionsEditor()
end

function Collection.UpdateLocked()
	editor.SetLockedCollectionIdx(editor.GetLockedCollectionIdx())
end

function OnMsg.NewMap()
	editor.SetLockedCollectionIdx(0)
end

----

DefineClass.CollectionContent = {
	__parents = { "PropertyObject" },
	properties = {},
	col = false,
	children = false,
	objects = false,

	EditorView = Untranslated("<Name> <style GedConsole><color 0 255 200><Index></color></style>"),
}

function CollectionContent:GedTreeChildren()
	return self.children
end

function CollectionContent:GetName()
	local name = self.col.Name
	return #name > 0 and name or "[Unnamed]"
end

function CollectionContent:GetIndex()
	local index = self.col.Index
	return index > 0 and index or ""
end

function CollectionContent:SelectInEditor()
	local ged = GetCollectionsEditor()
	if not ged then
		return
	end

	local root = ged:ResolveObj("root")

	local path = {}
	local iter = self
	while iter and iter ~= root do
		local parent_idx = iter.col:GetCollectionIndex()
		if parent_idx and parent_idx > 0 then
			local parent = root.collection_to_gedrepresentation[Collections[parent_idx]]
			table.insert(path, 1, table.find(parent.children, iter))
			iter = parent
		else
			table.insert(path, 1, table.find(root, iter))
			break
		end
	end
	ged:SetSelection("root", path)
end


function CollectionContent:OnEditorSelect(selected, ged)
	local is_initial_selection = not ged:ResolveObj("CollectionObjects")
	
	if selected then
		ged:BindObj("CollectionObjects", self.objects) -- for idObjects panel
		ged:BindObj("SelectedObject", self.col) -- for idProperties panel
	end

	if not IsEditorActive() then
		return
	end
	if selected then
		-- If this is the initial selection (when the editor is first opened) => don't move the camera
		ged:ResolveObj("root"):Select(self, not is_initial_selection and "show_in_editor")
	end
end


function CollectionContent:ActionUnlockAll()
	if not IsEditorActive() then
		print(unavailable_msg)
		return
	end
	Collection.UnlockAll()
end

----

DefineClass.CollectionRoot = {
	__parents = { "InitDone" },

	collection_to_gedrepresentation = false,
	selected_col = false,
}

function GedCollectionEditorOp(ged, name)
	if not IsEditorActive() then
		print(unavailable_msg)
		return
	end
	
	local gedcol = ged:ResolveObj("SelectedCollection")
	local root = ged:ResolveObj("root")
	local col = gedcol and gedcol.col
	local col_to_select = false
	
	if not col then
		return
	end
	
	if name == "new" then
		Collection.Collect()
	elseif name == "delete" then
		-- Prepare next collection to be selected in the editor
		local root_index = table.find(root, gedcol) or 0
		local nextColContent = root[root_index + 1]
		if nextColContent and nextColContent:GetIndex() ~= 0 then
			col_to_select = Collections[nextColContent:GetIndex()]
		end
		col:Destroy()
	elseif name == "lock" then
		col:SetLocked(true)
	elseif name == "unlock" then
		Collection.UnlockAll()
	elseif name == "collect" then
		col_to_select = Collection.Collect(editor.GetSel())
	elseif name == "uncollect" then
		DoneObject(col)
	elseif name == "view" then
		if gedcol and gedcol.objects then
			ViewObjects(gedcol.objects)
		end
	end
	root:UpdateTree()
	
	if root.collection_to_gedrepresentation and col_to_select then
		-- Select a new collection in the editor
		local gedrepr = root.collection_to_gedrepresentation[col_to_select]
		if gedrepr then
			gedrepr:SelectInEditor()
		end
	end
end

function CollectionRoot:Select(obj, show_in_editor)
	if not IsEditorActive() or self.selected_collection == obj.col then
		return
	end

	local col = obj.col
	if not col:GetLocked() then
		local parent = col:GetCollection()
		if parent then
			parent:SetLocked(true)
		else
			Collection.UnlockAll()
		end
	end
	
	if show_in_editor then
		local col_objects = MapGet("map", "attached", false, "collection", col.Index)
		editor.ChangeSelWithUndoRedo(col_objects, "dont_notify")
		ViewObjects(col_objects)
	end
	
	self.selected_collection = obj.col
end

function CollectionRoot:Init()
	self:UpdateTree()
end

function CollectionRoot:SelectPlainCollection(col)
	local obj = self.collection_to_gedrepresentation[col]
	if obj then
		self.selected_collection = obj.col
		obj:SelectInEditor()
	end
end

function CollectionRoot:UpdateTree()
	table.iclear(self)
	if not Collections then
		return
	end
	self.collection_to_gedrepresentation = {}
	local collection_to_children = {}
	local col_to_objs = {}
	MapForEach("map", "attached", false, "collected", true, function(obj, col_to_objs)
		local idx = obj:GetCollectionIndex()
		col_to_objs[idx] = table.create_add(col_to_objs[idx], obj)
	end, col_to_objs)
	local count = 0
	for col_idx, col_obj in sorted_pairs(Collections) do
		local objects = col_to_objs[col_idx] or {}
		table.sortby_field(objects, "class")
		collection_to_children[col_obj.Index] = collection_to_children[col_obj.Index] or {}
		local children = collection_to_children[col_obj.Index]
		local gedrepr = CollectionContent:new({col = col_obj, objects = objects, children = children})
		self.collection_to_gedrepresentation[col_obj] = gedrepr

		local parent_index = col_obj:GetCollectionIndex()
		if parent_index > 0 then
			collection_to_children[parent_index] = collection_to_children[parent_index] or {}
			table.insert(collection_to_children[parent_index], gedrepr)
		else
			count = count + 1
			self[count] = gedrepr
		end
	end
	table.sort(self, function(a, b) a, b = a.col.Name, b.col.Name return #a > 0 and #b == 0 or #a > 0 and a < b end)
	ObjModified(self)
end

function OnMsg.EditorCallback(id)
	if id == "EditorCallbackPlace" then
		UpdateCollectionsEditor()
	end
end

local openingCollectionEditor = false
function OpenCollectionEditorAndSelectCollection(obj)
	if openingCollectionEditor then return end
	openingCollectionEditor = true -- deal with multi selection and multiple calls from the button
	CreateRealTimeThread(function()
		local col = obj and obj:GetRootCollection()
		if not col then
			return
		end
		local ged = GetCollectionsEditor()
		if not ged then
			OpenCollectionsEditor(col)
			while not ged do
				Sleep(100)
				ged = GetCollectionsEditor()
			end
		end
		
		openingCollectionEditor = false
	end)
end

function OnMsg.EditorSelectionChanged(objects)
	local ged = GetCollectionsEditor()
	if not ged then
		return
	end
	local col = objects and objects[1] and objects[1]:GetRootCollection()
	if not col then return end

	local root = ged:ResolveObj("root")
	root:SelectPlainCollection(col)
end

local function get_auto_selected_collection()
	-- is the editor selection a single collection?
	local count, collections = editor.GetSelUniqueCollections()
	if count == 1 then
		return next(collections)
	end
	
	return Collection.GetLockedCollection()
end

function OpenCollectionsEditor(collection_to_select)
	local ged = GetCollectionsEditor()
	if not ged then
		collection_to_select = collection_to_select or get_auto_selected_collection()
		
		CreateRealTimeThread(function()
			ged = OpenGedApp("GedCollectionsEditor", CollectionRoot:new{}) or false
			
			while not ged do
				Sleep(100)
				ged = GetCollectionsEditor()
			end
			
			local root = ged:ResolveObj("root")
			
			if collection_to_select then
				-- Wait for the initial GedPanel selection to finish (to call OnEditorSelect()) to avoid an infinite selection loop
				Sleep(100)
				root:SelectPlainCollection(collection_to_select)
				return
			end
			
			local firstColContent = root and root[1]
			local select_col = collection_to_select or (root and root[1])
			
			-- Select the first collection in the editor
			if firstColContent and firstColContent:GetIndex() ~= 0 then
				local firstCollection = Collections[firstColContent:GetIndex()]
				root:SelectPlainCollection(firstCollection)
			end
		end)
	end
	return ged
end

function GetCollectionsEditor()
	for id, ged in pairs(GedConnections) do
		if IsKindOf(ged:ResolveObj("root"), "CollectionRoot") then
			return ged
		end
	end
end

function UpdateCollectionsEditor(ged)
	if ged then
		local root = ged:ResolveObj("root")
		if root then
			root:UpdateTree()
		end
	else
		ged = GetCollectionsEditor()
		if ged then
			DelayedCall(0, UpdateCollectionsEditor, ged)
		end
	end
end

function Collection:SetParentButton(_, __, ged)
	local parent = self.Graft ~= "" and CollectionsByName[ self.Graft ]
	if parent then
		local col = parent.Index
		while true do
			if col == 0 then break end
			if col == self.Index then
				printf("Can't set %s as parent, because it is a child of %s", self.Graft, self.Name)
				return
			end
			col = Collections[col]:GetCollectionIndex()
		end
		self:SetCollectionIndex( parent.Index )
	else
		self:SetCollectionIndex(0)
	end
	UpdateCollectionsEditor(ged)
end