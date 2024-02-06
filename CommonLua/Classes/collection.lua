local max_collection_idx = const.GameObjectMaxCollectionIndex
local GetCollectionIndex = CObject.GetCollectionIndex

MapVar("Collections", {})
MapVar("CollectionsByName", {})
MapVar("g_ShowCollectionLimitWarning", true)

DefineClass.Collection = {
	__parents = { "Object" },
	flags = { efWalkable = false, efApplyToGrids = false, efCollision = false },
	
	properties = {
		category = "Collection",
		{ id = "Name", editor = "text", default = "", },
		{ id = "Index", editor = "number", default = 0, min = 0, max = max_collection_idx, read_only = true, },
		{ id = "Locked", editor = "bool", default = false, dont_save = true, },
		{ id = "ParentName", name = "Parent", editor = "text", default = "", read_only = true, dont_save = true, },
		{ id = "Type", editor = "text", default = "", read_only = true, },
		{ id = "HideFromCamera", editor = "bool", default = false, help = "Makes collection use HideTop system to hide from camera regardless of the presence of HideTop objects within it or the objects' position relative to the playable area."},
		{ id = "DontHideFromCamera", editor = "bool", default = false, help = "If true, HideTop objects in this collection will be ignored. HideFromCamera will override this."},
		{ id = "HandleCount", name = "Handles Count", editor = "number", default = 0, read_only = true, dont_save = true, },
		{ id = "Graft", name = "Change parent", editor = "dropdownlist", default = "",
			items = function(self)
				local names = GetCollectionNames()
				if self.Name ~= "" then
					table.remove_entry(names, self.Name)
				end
				return names
			end,
			buttons = { { name = "Set", func = "SetParentButton" } },
			dont_save = true,
		},
	},
	
	-- non-editor stubs
	UpdateLocked = empty_func,
	SetLocked = empty_func,
}

-- hide unnused properties from CObject
for i = 1, #CObject.properties do
	local prop = table.copy(CObject.properties[i])
	prop.no_edit = true
	table.insert(Collection.properties, prop)
end

-- property getters ----------------------------------

function Collection:GetParentName()
	local parent = self:GetCollection()
	return parent and parent.Name or ""
end

------------------------------------------------------

if Platform.developer then
	function Collection:SetCollectionIndex(new_index)
		local col_idx = self.Index
		if new_index and new_index ~= 0 and col_idx and col_idx ~= 0 then
			if new_index == col_idx then
				return false, "[Collection] The parent index is the same!"
			end
			local parent = Collections[new_index]
			if parent and parent:GetCollectionRelation(col_idx) then
				return false, "[Collection] The parent is a child!"
			end
		end
		return CObject.SetCollectionIndex(self, new_index)
	end
end

function Collection:GetObjIdentifier()
	return xxhash(self.Name, self.Index)
end

function Collection:GetHandleCount()
	local pool = 0
	local count = 0
	MapForEach("map", "attached", false, "collection", self.Index, true, "Object", function(obj)
		pool = pool + 1 + obj.reserved_handles
		count = count + 1
	end)
	return pool, count
end

function Collection:SetIndex(new_index)
	new_index = new_index or 0
	local old_index = self.Index
	local collections = Collections
	if old_index ~= new_index or not collections[old_index] then
		if new_index ~= 0 then
			-- Check if we're creating a new collection or loading an existing one on map load
			if collections[new_index] or new_index < 0 or new_index > max_collection_idx then
				new_index = AsyncRand(max_collection_idx) + 1
				
				local loop_index = new_index
				while collections[new_index] do
					new_index = new_index + 1
					if new_index == loop_index then
						break
					elseif new_index > max_collection_idx then
						new_index = 1 -- circle around after the last index
					end
				end
			end
			
			if not IsChangingMap() then
				if collections[new_index] then -- no free index was found
					CreateMessageBox(
						terminal.desktop,
						Untranslated("Error"),
						Untranslated("Collection not created - collection limit exceeded!")
					)
					return false
				end
				
				-- If there are less than 10% free collection indexes => display a warning
				if g_ShowCollectionLimitWarning then
					local collections_count = #table.keys(collections) + 1 -- account for the new collection
					if collections_count >= MulDivRound(max_collection_idx, 90, 100) then
						CreateMessageBox(
							terminal.desktop,
							Untranslated("Warning"),
							Untranslated(string.format("There are %d collections on this map, approaching the limit of %d.", collections_count, max_collection_idx))
						)
						g_ShowCollectionLimitWarning = false -- disable the warning until next map (re)load
					end
				end
			end
			
			collections[new_index] = self
		end
		
		if old_index ~= 0 and collections[old_index] == self then
			self:SetLocked(false)
			local parent_index = new_index ~= 0 and new_index or GetCollectionIndex(self)
			MapForEach(true, "collection", old_index, function(o, idx) o:SetCollectionIndex(idx) end, parent_index)
			collections[old_index] = nil
		end
		
		self.Index = new_index
		Collection.UpdateLocked()
	end
	return true
end

function Collection.GetRoot(col_idx)
	if col_idx and col_idx ~= 0 then
		local locked_idx = editor.GetLockedCollectionIdx()
		if col_idx ~= locked_idx then
			local collections = Collections
			while true do
				local col_obj = collections[col_idx]
				if not col_obj then
					assert(false, "Root collection error")
					return 0
				end
				local parent_idx = GetCollectionIndex(col_obj)
				if not parent_idx or parent_idx == 0 or parent_idx == locked_idx then
					break
				end
				col_idx = parent_idx
			end
		end
	end
	return col_idx
end

function Collection:Init()
	self:SetGameFlags(const.gofPermanent)
end

function Collection:Done()
	self:SetIndex(false)
	self:SetName(false)
end

function Collection:SetName(new_name)
	new_name = new_name or ""
	local old_name = self.Name
	local CollectionsByName = CollectionsByName
	if old_name ~= new_name or not CollectionsByName[old_name] then
		CollectionsByName[old_name] = nil
		if new_name ~= "" then
			local orig_prefix, new_name_idx
			while CollectionsByName[new_name] do
				if not orig_prefix then
					-- Check if the name ends with a number
					local idx = string.find(new_name, "_%d+$")
					-- The old name with unique incremented index
					orig_prefix = idx and string.sub(new_name, 1, idx - 1) or new_name
					new_name_idx = idx and tonumber(string.sub(new_name, idx + 1)) or 0
				end
				new_name_idx = new_name_idx + 1
				new_name = string.format("%s_%d", orig_prefix , new_name_idx)
			end
			CollectionsByName[new_name] = self
		end
		self.Name = new_name
	end
	return new_name
end

function Collection:SetCollection(collection)
	if collection and collection.Index == editor.GetLockedCollectionIdx() then
		editor.AddToLockedCollectionIdx(self.Index)
	end
	CObject.SetCollection(self, collection)
end

function Collection:OnEditorSetProperty(prop_id, old_value, ged)
	ged:ResolveObj("root"):UpdateTree()
end

function Collection.Create(name, idx, obj)
	idx = idx or -1
	local col = Collection:new(obj)
	if col:SetIndex(idx) then
		if name then
			col:SetName(name)
		end
		UpdateCollectionsEditor()
		return col
	end
	DoneObject(col)
end

function Collection:IsEmpty(permanents)
	return MapCount("map", "collection", self.Index, true, nil, nil, permanents and const.gofPermanent or nil ) == 0
end

local function RemoveTempObjects(objects)
	for i = #(objects or ""), 1, -1 do
		local obj = objects[i]
		if obj:GetGameFlags(const.gofPermanent) == 0 or obj:GetParent() then
			table.remove(objects, i)
		end
	end
end

function Collection.Collect(objects)
	local uncollect = true
	local trunk
	local locked = Collection.GetLockedCollection()
	objects = objects or empty_table
	RemoveTempObjects(objects)
	if #objects > 0 then
		trunk = objects[1]:GetRootCollection()
		for i = 2, #objects do
			if trunk ~= objects[i]:GetRootCollection() then
				uncollect = false
				break
			end
		end
	end
	if trunk and trunk ~= locked and uncollect then
		local op_name = string.format("Removed %d objects from collection", #objects)
		table.insert(objects, trunk) -- add 'trunk' collection to the list of affected objects, as it could be deleted
		XEditorUndo:BeginOp{ objects = objects, name = op_name }
		for i = 1, #objects - 1 do
			objects[i]:SetCollection(locked)
		end
		if trunk:IsEmpty() then
			print("Destroyed collection: " .. trunk.Name)
			table.remove(objects) -- 'trunk' is at the last index
			Msg("EditorCallback", "EditorCallbackDelete", { trunk })
			DoneObject(trunk)
		else
			print(op_name .. ":" .. trunk.Name)
		end
		XEditorUndo:EndOp(objects)
		UpdateCollectionsEditor()
		return false
	end
	
	local col = Collection.Create()
	if not col then
		return false
	end
	
	XEditorUndo:BeginOp{ objects = objects, name = "Created collection" }
	
	col:SetCollection(locked)
	local classes = false
	if #objects > 0 then
		classes = {}
		local obj_to_add = {}
		for i = 1, #objects do
			local obj = objects[i]
			classes[obj.class] = (classes[obj.class] or 0) + 1
			while true do
				local obj_col = obj:GetCollection()
				if not obj_col or obj_col == locked then
					break
				end
				obj = obj_col
			end
			obj_to_add[obj] = true
		end
		for obj in pairs(obj_to_add) do
			obj:SetCollection(col)
		end
		table.insert(objects, col)
		UpdateCollectionsEditor()
	end
	
	local name = false
	if classes then
		local max = 0
		for class, count in pairs(classes) do
			if max < count then
				max = count
				name = class
			end
		end
	end
	col:SetName("col_" .. (name or col.Index))
	
	XEditorUndo:EndOp(objects)
	
	print("Collection created: " .. col.Name)
	return col
end

function Collection.AddToCollection()
	local sel = editor.GetSel()
	RemoveTempObjects(sel)
	local locked_col = Collection.GetLockedCollection()
	local dest_col
	local objects = {}
	for i = 1, #sel do
		local col = sel[i] and sel[i]:GetRootCollection()
		if col and col ~= locked_col then
			objects[col] = true
			dest_col = col
		else
			objects[sel[i]] = true
		end
	end
	if dest_col then
		XEditorUndo:BeginOp{ objects = sel, name = string.format("Added %d objects to collection", #sel) }
		for obj in pairs(objects) do
			if obj ~= dest_col then
				obj:SetCollection(dest_col)
			end
		end
		XEditorUndo:EndOp(sel)
		UpdateCollectionsEditor()
		print("Collection modified: " .. dest_col.Name)
	end
end

function Collection.GetPath(idx)
	local path = {}
	while idx ~= 0 do
		local collection = Collections[idx]
		if not collection then
			break
		end
		table.insert(path, 1, collection.Name)
		idx = GetCollectionIndex(collection)
	end
	return table.concat(path, '/')
end

local function GetSavePath(name)
	return string.format("data/collections/%s.lua", name)
end

local function DoneSilent(col)
	Collections[col.Index] = nil
	col.Index = 0
	DoneObject(col)
end

local function add_obj(obj, list)
	local col = obj:GetCollection()
	if not col then
		return
	end
	local objs = list[col]
	if objs then
		objs[#objs + 1] = obj
	else
		list[col] = {obj}
	end
end

local function GatherCollectionsEnum(obj, cols, is_deleted)
	local col_idx = GetCollectionIndex(obj)
	if col_idx ~= 0 and not is_deleted[obj] then
		cols[col_idx] = true
	end
end

function Collection.DestroyEmpty()
	local to_delete, is_deleted = {}, {}
	local work_done
	repeat
		local cols = {}
		MapForEach(true, "collected", true, GatherCollectionsEnum, cols, is_deleted)
		work_done = false
		for index, col in pairs(Collections) do
			if not is_deleted[col] and not cols[index] then
				table.insert(to_delete, col)
				is_deleted[col] = true
				work_done = true
			end
		end
	until not work_done
	
	XEditorUndo:BeginOp{ objects = to_delete, name = "Deleted empty collections" }
	Msg("EditorCallback", "EditorCallbackDelete", to_delete)
	DoneObjects(to_delete)
	XEditorUndo:EndOp()
end

-- cleanup empty collections after every operation
OnMsg.EditorObjectOperationEnding = Collection.DestroyEmpty

-- returns all collections containing objects and remove the rest if specified
function Collection.GetValid(remove_invalid, min_objs_per_col)
	min_objs_per_col = min_objs_per_col or 1
	local colls = {}
	local col_to_subs = {}
	MapForEach("detached" , "Collection", function(obj)
		colls[#colls + 1] = obj
		add_obj(obj, col_to_subs)
	end)
	local col_to_objs = {}
	MapForEach("map", "attached", false, "collected", true, "CObject", function(obj)
		add_obj(obj, col_to_objs)
	end)
	local count0 = #colls
	while true do
		local ready = true
		for i = #colls,1,-1 do
			local col = colls[i]
			local objects = col_to_objs[col] or ""
			if #objects == 0 then
				local subs = col_to_subs[col] or ""
				if #subs < 2 then
					ready = false
					local parent_idx = GetCollectionIndex(col) or 0
					for j=1,#subs do
						subs[j]:SetCollectionIndex(parent_idx)
					end
					local parent_subs = parent_idx and col_to_subs[parent_idx]
					if parent_subs then
						table.remove_value(parent_subs, col)
						table.iappend(parent_subs, subs)
					end
					col_to_subs[col] = nil
					table.remove(colls, i)
					if remove_invalid then
						DoneSilent(col)
					else
						col:SetCollection(false)
					end
				end
			end
		end
		if ready then
			break
		end
	end
	for col, objs in pairs(col_to_objs) do
		local subs = col_to_subs[col] or ""
		if #subs > 0 then
			assert(#objs > 0, "Invalid collection detected")
		elseif #objs < min_objs_per_col then
			local parent_idx = GetCollectionIndex(col) or 0
			for i=1,#objs do
				objs[i]:SetCollectionIndex(parent_idx)
			end
			table.remove_entry(colls, col)
			if remove_invalid then
				DoneSilent(col)
			else
				col:SetCollection(false)
			end
		end
	end
	UpdateCollectionsEditor()
	return colls, count0 - #colls
end


-- remove all nested collections on the map (max_cols is 0 by default, which means remove all collections from the map)
function Collection.RemoveAll(max_cols)
	max_cols = max_cols or 0
	local removed = 0
	if max_cols > 0 then
		local map = {}
		MapForEach("map", "CObject", function(obj)
			local levels = 0
			local col = obj:GetCollection()
			if not col then
				return
			end
			local new_col = map[col]
			if new_col == nil then
				local cols = {col}
				local col_i = col
				while true do
					col_i = col_i:GetCollection()
					if not col_i then
						break
					end
					cols[#cols + 1] = col_i
					assert(#cols < 100)
				end
				new_col = #cols > max_cols and cols[#cols - max_cols + 1]
				map[col] = new_col
			end
			if new_col then
				obj:SetCollection(new_col)
			end
		end)
		for col, new_col in pairs(map) do
			if new_col then
				DoneSilent(col)
				removed = removed + 1
			end
		end
		MapForEach("detached", "Collection", function(col)
			if map[col] == nil then
				DoneSilent(col)
				removed = removed + 1
			end
		end)
	else
		MapForEach("map", "CObject", function(obj)
			obj:SetCollectionIndex(0)
		end	)
		MapForEach("detached", "Collection", function(col)
			DoneSilent(col)
			removed = removed + 1
		end)
	end
	UpdateCollectionsEditor()
	return removed
end

-- remove all contained objects including those in nested collections
function Collection:Destroy(center, radius)
	local idx = self.Index
	if idx ~= 0 then
		SuspendPassEdits(self)
		if center and radius then
			MapDelete(center, radius, "attached", false, "collection", idx, true)
		else
			MapDelete("map", "attached", false, "collection", idx, true)
		end
		for _, col in pairs(Collections) do
			if col:GetCollectionRelation(idx) then
				DoneSilent(col)
			end
		end
		ResumePassEdits(self)
	end
	DoneSilent(self)
	UpdateCollectionsEditor()
end

UpdateCollectionsEditor = empty_func