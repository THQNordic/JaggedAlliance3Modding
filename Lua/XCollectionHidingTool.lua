local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0

--------------------------------------------------------------------------------------------------------------------------------------------
--assign to wall/roof tool
--------------------------------------------------------------------------------------------------------------------------------------------
if FirstLoad then
	CollectionsToHideVisualMeshes = false
end

--mostly cpy paste of building rules container
MapVar("g_CollectionsToHideContainer", false)

function GetCollectionsToHideContainer()
	if not g_CollectionsToHideContainer then
		local t = MapGet("detached", "CollectionsToHideContainer")
		
		if t and #t > 1 then
			--like in highlander, there can be only one
			for i = #t, 2, -1 do
				DoneObject(t[i])
				t[i] = nil
			end
		end
		
		g_CollectionsToHideContainer = t and t[1] or PlaceObject("CollectionsToHideContainer")
	end
	
	g_CollectionsToHideContainer.contents = g_CollectionsToHideContainer.contents or {}
	return g_CollectionsToHideContainer
end

function GetCollectionsToHide()
	return GetCollectionsToHideContainer().contents
end

function GetCollectionsToHideDataForRoom(r, create)
	local c = GetCollectionsToHide()
	local idx = table.find(c, "room", r)
	if idx then
		return c[idx], c
	elseif create then
		assert(XEditorUndo:AssertOpCapture())
		local data = PlaceObject("CollectionsToHidePersistableData", {room = r}) -- will add itself to the list
		return data, c
	else
		return false, c
	end
end

local tMembers = {
	"West",
	"East",
	"North",
	"South",
	"Roof",
}

function GetCollectionsToHideAssociatedRooms(col)
	local ret
	local c = GetCollectionsToHide()
	for i = 1, #c do
		local d = c[i]
		if d then
			for j = 1, #tMembers do
				local idx = table.find(d[tMembers[j]] or empty_table, col)
				if idx then
					ret = ret or {}
					ret[d.room] = ret[d.room] or {}
					table.insert(ret[d.room], tMembers[j])
				end
			end
		end
	end
	return ret
end

MapVar("colToRoomCache", false) --[col] = { [room] = {"West", "Roof", etc.}, etc.}
MapVar("roomToColCache", false) --[room] = { ["West"] = {col1, col2, etc.}, etc.}

local function GetCollectionsToHideForRoom(r, side)
	local t = table.get(roomToColCache, r, side)
	if t == nil then
		local data = GetCollectionsToHideDataForRoom(r)
		t = data and data[side] or false
		roomToColCache = roomToColCache or {}
		roomToColCache[r] = roomToColCache[r] or {}
		roomToColCache[r][side] = t
	end
	return t
end

function GetRoomDataForCollection(col)
	if not col then return false end
	local t2 = nil
	if colToRoomCache then
		t2 = colToRoomCache[col]
	end
	
	if t2 == nil then
		t2 = GetCollectionsToHideAssociatedRooms(col) or false
		colToRoomCache = colToRoomCache or {}
		colToRoomCache[col] = t2
	end
	
	return t2
end

function GetRoomDataForObjCollection(obj)
	local col = obj:GetRootCollection()
	return GetRoomDataForCollection(col)
end

if FirstLoad then
	CollectionsRelations = false
end

function BuildCollectionsRelations()
	CollectionsRelations = {}
	local t = CollectionsRelations
	local function insertC(c)
		if t[c] then return end
		local p = c:GetCollection()
		t[c] = { parent = p, children = false }
		if p then
			insertC(p)
			t[p].children = t[p].children or {}
			table.insert(t[p].children, c)
		end
	end
	
	for idx, c in pairs(Collections) do
		insertC(c)
	end
end

local function pushChildren(col, t)
	local cr = CollectionsRelations
	local children = cr[col].children
	for i = 1, #(children or "") do
		local child = children[i]
		pushChildren(child, t)
		t[#t + 1] = child.Index
	end
end

function OnMsg.DoneMap()
	CollectionsRelations = false
end
OnMsg.ChangeMapDone = BuildCollectionsRelations
OnMsg.GameExitEditor = BuildCollectionsRelations

function IsAnyCollectionLinkedToRooms(col)
	local cr = CollectionsRelations
	local rc = col:GetRootCollection() or col
	local function overflowHelper(c)
		if IsCollectionLinkedToRooms(c) then
			return true
		end
		local children = cr[c] and cr[c].children
		for i = 1, #(children or "") do
			if overflowHelper(children[i]) then
				return true
			end
		end
		return false
	end
	return overflowHelper(rc)
end

function IsCollectionLinkedToRooms(col)
	if type(col) == "number" then
		col = Collections[col]
	end
	return GetRoomDataForCollection(col) ~= false
end

local function ClearCollectionsToHideCache(col, room)
	if roomToColCache then
		roomToColCache[room] = nil
	end
	if colToRoomCache then
		colToRoomCache[col] = nil
	end
end

DefineClass.CollectionsToHideContainer = {
	__parents = { "Object" },
	flags = { gofPermanent = false, efWalkable = false, efCollision = false, efApplyToGrids = false },
	properties = {
		{ id = "contents", editor = "objects", default = false },
	},
}

function CollectionsToHideContainer:GetEditorRelatedObjects()
	assert(false) -- the container's contents should not be saved in undo information; its children will auto add/remove themselves from the parent
end

function CollectionsToHideContainer:CleanBadEntries()
	assert(XEditorUndo:AssertOpCapture())
	colToRoomCache = false
	roomToColCache = false
	
	local to_delete = {}
	local t = self.contents
	for i = #t, 1, -1 do
		local o = t[i]
		o:CleanBadEntries()
		if not IsValid(o.room) or o:IsEmpty() then
			table.insert(to_delete, o)
		end
	end
	
	XEditorUndo:BeginOp{ objects = to_delete, name = "Linked collection deletion" }
	DoneObjects(to_delete)
	XEditorUndo:EndOp()
end

function CollectionsToHideContainer:PostLoad(reason)
	if reason == "undo" then
		colToRoomCache = false
		roomToColCache = false
	end
end

function OnMsg.EditorObjectOperationEnding()
	if g_CollectionsToHideContainer then
		g_CollectionsToHideContainer:CleanBadEntries()
	end
	
	local selection = editor.GetSel()
	if HasAlignedObjs(selection) then -- proxy for having rooms
		CreateRealTimeThread(RefreshCollectionHidingVisuals, selection)
	end	
end

DefineClass.CollectionsToHidePersistableData = {
	__parents = { "Object" },
	flags = { gofPermanent = true, efWalkable = false, efCollision = false, efApplyToGrids = false },
	properties = {
		{ id = "room", editor = "object", default = false },
		{ id = "West", editor = "objects", default = false },
		{ id = "East", editor = "objects", default = false },
		{ id = "North", editor = "objects", default = false },
		{ id = "South", editor = "objects", default = false },
		{ id = "Roof", editor = "objects", default = false },
	},
}

function CollectionsToHidePersistableData:GetObjIdentifier()
	return xxhash(42357, self.room:GetObjIdentifier())
end

function CollectionsToHidePersistableData:Init()
	if not IsChangingMap() or XEditorUndo.undoredo_in_progress then
		table.insert(GetCollectionsToHide(), self)
	end
end

function CollectionsToHidePersistableData:Done()
	table.remove_value(GetCollectionsToHide(), self)
end

function CollectionsToHidePersistableData:ClearColTooRoomCacheForAffectedCols() --unused
	if not colToRoomCache then return end
	for j = 1, #tMembers do
		for k = 1, #(self[tMembers[j]] or "") do
			colToRoomCache[self[tMembers[j]][k]] = nil
		end
	end
end

function CollectionsToHidePersistableData:IsEmpty()
	for i = 1, #tMembers do
		local m = self[tMembers[i]]
		if m and #m > 0 then
			return false
		end
	end
	return true
end

function CollectionsToHidePersistableData:CleanBadEntries()
	if not IsKindOf(self.room, "Room") or not IsValid(self.room) then
		print("<color 255 0 0>Found non room room in CollectionsToHidePersistableData and removed it[" .. (self.room and rawget(self.room, "name") or "") .. ", " .. (self.room and self.room.class or tostring(self.room) or "") .. "]!</color>")
		return
	end
	for i = 1, #tMembers do
		local m = tMembers[i]
		local t = self[m]
		for j = #(t or ""), 1, -1 do
			local e = t[j]
			if not IsValid(e) then
				table.remove(t, j)
				print("<color 255 0 0>Found invalid collection in CollectionsToHidePersistableData[".. m .. ", " .. self.room.name .."]!</color>")
			end
		end
		if t and #t <= 0 then
			self[m] = nil
		end
		if self[m] then
			local room = self.room
			if m == "Roof" and not room:HasRoof() then
				print(string.format("<color 255 0 0>Removed hook to %s's roof because the roof does not exist.</color>", room.name))
				self[m] = nil
			end
		end
	end
end

-- handles adding the object that keeps visibility data about a room to the data for room copy/paste operations
function OnMsg.GatherRoomRelatedObjects(room, objs)
	local data = GetCollectionsToHideDataForRoom(room)
	if data then
		objs[#objs + 1] = data
	end
end

local function _ReadInputHelper(obj)
	if not IsKindOf(obj, "Slab") or IsKindOf(obj, "FloorSlab") then
		return
	end
	local r = rawget(obj, "room")
	if not r then
		return
	end
	--figure out side
	local side
	if IsKindOfClasses(obj, "RoofSlab", "RoofWallSlab") then
		side = "Roof"
	else
		side = obj.side
	end
	return r, side
end

function LinkUnlinkCollectionToElement(collection, r, side, op)
	ClearCollectionsToHideCache(collection, r)
	rawset(collection, "hidden", nil)
	
	XEditorUndo:BeginOp{ objects = GetCollectionsToHide(), name = op == "link" and "Link collection to room" or "Unlink collection from room" }
	
	local d, c = GetCollectionsToHideDataForRoom(r)
	if (not op or op == "unlink") and d and table.remove_entry(d[side] or empty_table, collection) then
		if d:IsEmpty() then
			table.remove_entry(c, d)
			DoneObject(d)
		end
		op = "unlink"
	elseif (not op or op == "link") then -- add the entry
		d = GetCollectionsToHideDataForRoom(r, true)
		d[side] = d[side] or {}
		table.insert_unique(d[side], collection)
		op = "link"
	end
	print(string.format("%s %s %s", op == "link" and "Linking" or "Unlinking", r.name, side))
	
	XEditorUndo:EndOp(GetCollectionsToHide())
	return op
end

local d_call_args_show = false
local d_call_args_hide = false

local function pushDelayedCollectionsToHideCall(args, r, side, fnHide, t)
	args = args or {}
	local k = xxhash(r.handle, side)
	args[k] = pack_params(r, side, fnHide, t) --consequitive calls overwrite
	return args
end

function CancelDelayedCollectionProcessing(args, r, side)
	if not args then return end
	local k = xxhash(r.handle, side)
	args[k] = nil
end

function CollectionsToHideHideCollections(r, side, fnHide)
	local t = GetCollectionsToHideForRoom(r, side)
	if not t or #t <= 0 then
		return
	end
	
	CancelShowDelayedCollection(r, side)
	d_call_args_hide = pushDelayedCollectionsToHideCall(d_call_args_hide, r, side, fnHide, t)
end

function CancelShowDelayedCollection(r, side)
	CancelDelayedCollectionProcessing(d_call_args_show, r, side)
end

function CancelHideDelayedCollection(r, side)
	CancelDelayedCollectionProcessing(d_call_args_hide, r, side)
end

local function finishCollectionsToHideProcessing(colls, func, edit, hide, cleanup)
	local qf
	if func then
		qf = function(o)
			func(o, hide)
		end
	elseif edit then
		qf = function(o)
			o:SetShadowOnlyImmediate(hide)
		end
	else
		qf = function(o)
			o:SetShadowOnly(hide)
		end
	end

	if not edit then
		MapForEach("map", "collection", colls, false, qf) --we use the CollectionsRelations table to get children quickly
	else
		MapForEach("map", "collection", colls, true, qf) --CollectionsRelations is not up to date in editor
	end

	if cleanup then
		print("Found bad collections in data, running cleanup!")
		g_CollectionsToHideContainer:CleanBadEntries()
	end
end

function CollectionsToHideProcessDelayedHides()
	if not d_call_args_hide then return end
	local cleanup = false
	local edit = IsEditorActive()
	local colls = {}
	local func
	local pc = not edit and pushChildren or empty_func
	
	for k, params in pairs(d_call_args_hide) do --map query sorts, so we can pairs this
		local r, side, fnHide, t = unpack_params(params)
		func = func or fnHide
		assert(not func or func == fnHide) --expects the same functor for all calls;
		for j = 1, #t do
			local col = t[j]
			if IsValid(col) then
				if edit or not rawget(col, "hidden") then
					colls[#colls + 1] = col.Index
					pc(col, colls)
					rawset(col, "hidden", true)
				end
			elseif not cleanup then
				cleanup = true
			end
		end
	end
	d_call_args_hide = false
	if #colls <= 0 then return end
	finishCollectionsToHideProcessing(colls, func, edit, true, cleanup)
end

local function ShouldStillShowCollection(col)
	local data = GetRoomDataForCollection(col)
	for room, sides in pairs(data or empty_table) do
		for j = 1, #sides do
			--if room ~= r or sides[j] ~= side then --this only works if not delayed
				if not IsElementVisible(room, sides[j]) then --this will only work in a delayed call
					return false
				end
			--end
		end
	end
	return true
end

function CollectionsToHideProcessDelayedShows()
	if not d_call_args_show then return end
	local cleanup = false
	local edit = IsEditorActive()
	local colls = {}
	local func
	local pc = not edit and pushChildren or empty_func
	
	for k, params in pairs(d_call_args_show) do
		local r, side, fnHide, t = unpack_params(params)
		func = func or fnHide
		assert(not func or func == fnHide) --expects the same functor for all calls;
		for j = 1, #t do
			local col = t[j]
			if IsValid(col) then
				if edit or rawget(col, "hidden") then
					if ShouldStillShowCollection(col) then --i guess state of trigger could have changed
						colls[#colls + 1] = col.Index
						pc(col, colls)
						rawset(col, "hidden", nil)
					--else --was testing if this actually happens, yes it does
						--print("Trigger state changed!!!")
					end
				end
			elseif not cleanup then
				cleanup = true
			end
		end
	end
	
	d_call_args_show = false
	if #colls <= 0 then return end
	finishCollectionsToHideProcessing(colls, func, edit, false, cleanup)
end

function IsElementVisible(r, side)
	local cd = VT2CollapsedWalls and VT2CollapsedWalls[r]
	if cd then
		if side == "Roof" and next(cd) or 
			side ~= "Roof" and cd[side] == "full" and r.size:z() > 1 then
			return false
		end
	end
	
	if not cd and side == "Roof" and not r.is_roof_visible then
		return false --alt way of catching invisible roofs for rooms wiht no walls
	end
	
	local bld = r.building
	local f = VT2TouchedBuildings and VT2TouchedBuildings[bld]
	if f and f < r.floor then
		--if in touched bld and above touched floor
		return false
	end
	
	return true
end

function CollectionsToHideShowCollections(r, side, fnHide)
	local t = GetCollectionsToHideForRoom(r, side)
	if not t or #t <= 0 then
		return --no need to go through the whole shabang if no data
	end
	CancelHideDelayedCollection(r, side)
	d_call_args_show = pushDelayedCollectionsToHideCall(d_call_args_show, r, side, fnHide, t)
end

function OnMsg.GameEnterEditor()
	d_call_args_show = false --cleanup
	d_call_args_hide = false
end

function CollectionsToHide_GetCollectionVisibilityState(col)
	local t2 = GetRoomDataForCollection(col)
	for room, t3 in pairs(t2 or empty_table) do
		for j = 1, #t3 do
			--if room ~= r or t3[j] ~= side then --this only works if not delayed
				if not IsElementVisible(room, t3[j]) then --this will only work in a delayed call
					goto continue
				end
			--end
		end
		
		return true
	end
	
	::continue::
end

local function PutInTHelper(cols, col)
	if col then
		cols = cols or {}
		cols[col] = true
	end
	return cols
end

function ExtractCollectionsFromObjs(objs)
	local cols
	for i = 1, #(objs or "") do
		local obj = objs[i]
		if IsValid(obj) then
			cols = PutInTHelper(cols, obj:GetRootCollection())
			cols = PutInTHelper(cols, obj:GetCollection())
		end
	end
	
	return cols
end

function OnMsg.EditorCallback(id, objs, reason)
	if id == "EditorCallbackDelete" and reason ~= "undo" then
		--handle deletion
		--gather agents
		local cols
		local rooms
		
		for i = 1, #(objs or "") do
			local obj = objs[i]
			if IsValid(obj) then
				cols = PutInTHelper(cols, obj:GetRootCollection())
				cols = PutInTHelper(cols, obj:GetCollection())
				if IsKindOf(obj, "Collection") then
					cols = PutInTHelper(cols, obj)
				elseif IsKindOf(obj, "Room") then
					rooms = rooms or {}
					rooms[obj] = true
				end
			end
		end
		
		local function isCollectionEmptyNow(col)
			local ret = true
			MapForEach("map", "collection", col.Index, true, function(o, objs)
				if not table.find(objs, o) then
					ret = false
					return "break"
				end
			end, objs)
			
			return ret
		end
		
		for col, _ in pairs(cols or empty_table) do
			--if not col:IsEmpty() then --doesn't work in current context
			if not isCollectionEmptyNow(col) then
				cols[col] = nil
			end
		end
		
		CollectionsToHideDeletionHandlerHelper(cols, rooms)
	end
end

function CollectionsToHideDeletionHandlerHelper(cols, rooms)
	if not (cols and next(cols)) and not (rooms and next(rooms)) then
		return
	end
	
	assert(XEditorUndo:AssertOpCapture())
	XEditorUndo:StartTracking(GetCollectionsToHide(), not "created", "omit_children")
	
	-- clear cache
	local allData = GetCollectionsToHide()
	roomToColCache = false
	colToRoomCache = false
	
	-- cleanup rooms
	for room, _ in pairs(rooms or empty_table) do
		local idx = table.find(allData or empty_table, "room", room)
		if idx then
			local d = allData[idx]
			DoneObject(d) -- d also used in message below
			print(string.format("<color 255 144 0>Clearing CollectionsToHidePersistableData hook - room deleted[%s]!</color>", d.room and d.room.name or tostring(d.room)))
		end
	end
	
	-- cleanup cols
	for col, _ in pairs(cols or empty_table) do
		for i = (#allData or ""), 1, -1 do
			local d = allData[i]
			for j = 1, #tMembers do
				local idx = table.find(d[tMembers[j]] or empty_table, col)
				if idx then
					print(string.format("<color 255 144 0>Removing CollectionsToHidePersistableData hook to collection from delete handler (collection deleted)[%s, %s]!</color>", d.room and d.room.name or tostring(d.room), tMembers[j]))
					table.remove(d[tMembers[j]], idx)
					if #d[tMembers[j]] <= 0 then
						d[tMembers[j]] = false
						print(string.format("<color 255 144 0>CollectionsToHidePersistableData hook empty on side, removing[%s]!</color>", tMembers[j]))
					end
				end
			end
			
			if d:IsEmpty() then
				DoneObject(d)
				print(string.format("<color 255 144 0>CollectionsToHidePersistableData hook empty, removing[%s]!</color>", d.room and d.room.name or tostring(d.room)))
			end
		end
	end
end

function RefreshCollectionHidingVisuals(selection)
	for i = #(CollectionsToHideVisualMeshes or ""), 1, -1 do
		DoneObject(CollectionsToHideVisualMeshes[i])
		CollectionsToHideVisualMeshes[i] = nil
	end
	
	CollectionsToHideVisualMeshes = false
	
	local cleanup = false
	local cols = ExtractCollectionsFromObjs(selection or empty_table)
	for col, _ in pairs(cols or empty_table) do
		local d = GetRoomDataForCollection(col)
		for room, sides in pairs(d or empty_table) do
			CollectionsToHideVisualMeshes = CollectionsToHideVisualMeshes or {}
			for j = 1, #sides do
				local s = sides[j]
				if s == "Roof" then
					if room:HasRoof() and room.roof_box then
						table.insert(CollectionsToHideVisualMeshes, PlaceBox(room.roof_box:grow(voxelSizeX, voxelSizeY, voxelSizeZ), RGB(255, 0, 0)))
					else
						cleanup = true
					end
				else
					local b = room:GetWallBox(s):grow(voxelSizeX, voxelSizeY, voxelSizeZ)
					table.insert(CollectionsToHideVisualMeshes, PlaceBox(b, RGB(255, 0, 0)))
				end
			end
		end
	end
	
	if cleanup then
		print("Found bad entries in data, running cleanup!")
		g_CollectionsToHideContainer:CleanBadEntries()
	end
end

function OnMsg.EditorSelectionChanged(selection)
	RefreshCollectionHidingVisuals(selection)
end

DefineClass.XCollectionHidingTool = {
	__parents = { "XEditorTool" },
	
	ToolTitle = "Link collection to wall",
	ToolSection = "Misc",
	Description = {
		"Click on a wall slab to link the selected collection(s) to the wall, so that they are hidden together.",
		"(click again to unlink)",
	},
	ActionSortKey = "2",
	ActionIcon = "CommonAssets/UI/Editor/Tools/LinkToWall.tga", 
	ActionShortcut = "C",
	ActionMode = "Editor",
	ToolKeepSelection = true,
	
	time_activated = false,
	selected_collections = false,
}

function XCollectionHidingTool:Init()
	self.time_activated = now()
	self:SetCollectionsHelper(editor.GetSel())
end

function XCollectionHidingTool:CheckStartOperation(pt)
	--todo
end

function XCollectionHidingTool:SetCollectionsHelper(selection)
	self.selected_collections = ExtractCollectionsFromObjs(selection) or false
end

function XCollectionHidingTool:OnShortcut(shortcut, source, repeated)
	local released1 = string.format("-%s", self.ActionShortcut)
	local released2 = string.format("-%s", self.ActionShortcut2)
	if shortcut == self.ActionShortcut or shortcut == self.ActionShortcut2 then
		return "break"
	elseif (shortcut == released1 or shortcut == released2) and (now() - self.time_activated > 100) then
		XEditorSetDefaultTool()
		return "break"
	end
end

function XCollectionHidingTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		local updateSelection = false
		local cols = self.selected_collections
		if cols and next(cols) then
			local so = GetObjectAtCursor()
			local didWork
			if IsValid(so) and IsKindOf(so, "Slab") and not IsKindOf(so, "FloorSlab") then
				local slabs = MapGet(so, 0, "Slab", function(o) -- connect with all walls on this spot, so look for invisible slabs as well
					return not IsKindOf(o, "FloorSlab")
				end)
				local op
				for i, lo in ipairs(slabs) do
					if IsValid(lo) then
						local r, side = _ReadInputHelper(lo)
						if r then
							for col in pairs(cols) do
								op = LinkUnlinkCollectionToElement(col, r, side, op)
							end
							didWork = true
						end
					end
				end
			end
			if not didWork then
				updateSelection = true
			else
				RefreshCollectionHidingVisuals()
				local isCHeld = terminal.IsKeyPressed(const.vkC)
				if not isCHeld then
					XEditorSetDefaultTool()
				end
			end
		else
			updateSelection = true
		end
		
		if updateSelection then
			local o = GetObjectAtCursor()
			local sel = editor.SelectionPropagate({o})
			editor.SetSel(sel)
			self:SetCollectionsHelper(sel)
		end
	end
end

function OnMsg.GameExitEditor()
	HideFloorsAbove(999)
	
	MapForEach("map", "collected", true, function(obj)
		local col = obj:GetCollection()
		if col and rawget(col, "hidden") then
			obj:SetShadowOnly(true)
		end
	end)
end

function OnMsg.FloorsHiddenAbove(floor, fnHide)
	SuspendPassEdits("HidingCollectionsAndObjects")
	
	local c = GetCollectionsToHide()
	for i = 1, #c do
		local r = c[i].room
		if r.floor <= floor then
			--show
			for j = 1, #tMembers do
				CollectionsToHideShowCollections(r, tMembers[j], fnHide)
			end
		else
			--hide
			for j = 1, #tMembers do
				CollectionsToHideHideCollections(r, tMembers[j], fnHide)
			end
		end
	end
	
	CollectionsToHideProcessDelayedHides()
	CollectionsToHideProcessDelayedShows()
	
	EnumVolumes(function(r, floor)
		HideShowRoomObjects(r, r.floor > floor, "inEditor", fnHide)
	end, floor)
	
	ResumePassEdits("HidingCollectionsAndObjects")
end