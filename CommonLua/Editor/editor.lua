XEditorPasteFuncs = {}

function editor.SelectByClass(...)
	editor.ClearSel()
	editor.AddToSel(MapGet("map", ...) or empty_table)
end

function ToggleEnterExitEditor()
	if Platform.editor then
		CreateRealTimeThread(function()
			while IsChangingMap() or IsEditorSaving() do
				WaitChangeMapDone()
				if IsEditorSaving() then
					WaitMsg("SaveMapDone")
				end
			end
			if GetMap() == "" then
				print("There is no map loaded")
				return
			end
			if IsEditorActive() then
				EditorDeactivate()
			else
				EditorActivate()
			end
		end)
	end		
end

function EditorViewMapObject(obj, dist, selection)
	local la = IsValid(obj) and obj:GetVisualPos() or InvalidPos()
	if la == InvalidPos() then
		return
	end
	if not cameraMax.IsActive() then cameraMax.Activate(1) end
	local cur_pos, cur_la = cameraMax.GetPosLookAt()
	if cur_la == cur_pos then
		-- cam not initialized
		cur_pos = cur_la - point(guim, guim, guim)
	end
	la = la:SetTerrainZ()
	local pos = la - SetLen(cur_la - cur_pos, (dist or 40*guim) + obj:GetRadius())
	cameraMax.SetCamera(pos, la, 200, "Sin in/out")
	
	if selection then
		editor.ClearSel()
		editor.AddToSel{obj}
		OpenGedGameObjectEditor(editor.GetSel())
	end
end

local objs
function OnMsg.DoneMap()
	objs = nil
end
function _OpenGedGameObjectEditorInGame(reopen_only)
	if not GedObjectEditor then
		GedObjectEditor = OpenGedApp("GedObjectEditor", objs, { WarningsUpdateRoot = "root" }) or false
	else
		GedObjectEditor:UnbindObjs("root")
		if not reopen_only then
			GedObjectEditor:Call("rfnApp", "Activate")
		end
		GedObjectEditor:BindObj("root", objs)
	end
	GedObjectEditor:SelectAll("root")
	objs = nil
end

function OpenGedGameObjectEditorInGame(obj, reopen_only)
	if not obj or not GedObjectEditor and reopen_only then return end
	objs = table.create_add_unique(objs, obj)
	DelayedCall(0, _OpenGedGameObjectEditorInGame, reopen_only)
end
	
function CObject:AsyncCheatProperties()
	OpenGedGameObjectEditorInGame(self)
end

function OnMsg.SelectedObjChange(obj)
	OpenGedGameObjectEditorInGame(obj, "reopen_only")
end

function EditorWaitViewMapObjectByHandle(handle, map, ged)
	if GetMapName() ~= map then
		if ged then
			local answer = ged:WaitQuestion("Change map required!", string.format("Change map to %s?", map))
			if answer ~= "ok" then
				return
			end
		end
		CloseMenuDialogs()
		ChangeMap(map)
		StoreLastLoadedMap()
	end
	EditorActivate()
	WaitNextFrame()
	local obj = HandleToObject[handle]
	if not IsValid(obj) then
		print("ERROR: no such object")
		return
	end
	editor.ChangeSelWithUndoRedo({obj})
	EditorViewMapObject(obj)
end

----

if FirstLoad then
	GedSingleObjectPropEditor = false
end

function OpenGedSingleObjectPropEditor(obj, reopen_only)
	if not obj then return end
	CreateRealTimeThread(function()
		if not GedSingleObjectPropEditor and reopen_only then
			return
		end
		if not GedSingleObjectPropEditor then
			GedSingleObjectPropEditor = OpenGedApp("GedSingleObjectPropEditor", obj) or false
		else
			GedSingleObjectPropEditor:UnbindObjs("root")
			GedSingleObjectPropEditor:Call("rfnApp", "Activate")
			GedSingleObjectPropEditor:BindObj("root", obj)
		end
	end)
end

function OnMsg.GedClosing(ged_id)
	if GedSingleObjectPropEditor and GedSingleObjectPropEditor.ged_id == ged_id then
		GedSingleObjectPropEditor = false
	end
end

----

-- Grounds all selected objects.
-- If *relative* is true, grounds only the lowest one and then sets the rest of them relative to it
function editor.ResetZ(relative)
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	
	local min_z_ground = false
	local min_z_air = false
	local min_idx = false

	if relative then
		-- Get the lowest of all objects and where it will be grounded
		for i = 1, #sel do
			local obj = sel[i]
			
			local _, _, pos_z = obj:GetVisualPosXYZ()
			
			if not min_z_air or min_z_air > pos_z then
				min_z_air = pos_z
				min_idx = i
			end
		end

		if min_idx then
			local obj = sel[min_idx]

			local pos = obj:GetVisualPos2D()
			local o, z = GetWalkableObject( pos )
			if o ~= nil and not IsFlagSet( obj:GetEnumFlags(), const.efWalkable ) then
				min_z_ground = z
			else
				min_z_ground = terrain.GetSurfaceHeight(pos)
			end
		end
	end

	SuspendPassEditsForEditOp()
	XEditorUndo:BeginOp{ objects = sel, name = "Snap to terrain" }
	for i = 1, #sel do	
		local obj = sel[i]
		
		obj:ClearGameFlags(const.gofOnRoof)
		
		local pos = obj:GetVisualPos()
		local pos_z = pos:z()
		pos = pos:SetInvalidZ()
		local o, z = GetWalkableObject( pos )

		if o ~= nil and not IsFlagSet( obj:GetEnumFlags(), const.efWalkable ) then
			if relative and min_z_air and min_z_ground then
				pos = point( pos:x(), pos:y(), pos_z - min_z_air + min_z_ground)
			else
				pos = point( pos:x(), pos:y())
			end
		elseif relative and min_z_air and min_z_ground then
			pos = point( pos:x(), pos:y(), pos_z - min_z_air + min_z_ground)
		end

		obj:SetPos( pos )
	end
	local objects = {}
	local cfEditorCallback = const.cfEditorCallback
	for i = 1, #sel do
		if sel[i]:GetClassFlags(cfEditorCallback) ~= 0 then
			objects[#objects + 1] = sel[i]
		end
	end
	if #objects > 0 then
		Msg("EditorCallback", "EditorCallbackMove", objects)
	end
	Msg("EditorResetZ")
	XEditorUndo:EndOp(sel)
	ResumePassEditsForEditOp()
end

-- this method correctly resets anim back to game time, i.e. it resets the anim timestamps so it doesn't have to wait far in the future to start
function ObjectAnimToGameTime(object)
	object:SetRealtimeAnim(false)
	local e = object:GetEntity()
	if IsValidEntity(e) then
		object:SetAnimSpeed(1, object:GetAnimSpeed(), 0) -- so the obj can set its anim timestamps correctly in game time
	end
end

function editor.GetObjectsCenter(objs)
	local min_z
	local b = box()
	for i = 1, #objs do
		local pos = objs[i]:GetPos()
		b = Extend(b, pos)
		if pos:IsValidZ() then
			min_z = Min(min_z or pos:z(), pos:z())
		end
	end
	local center = b:Center()
	center = min_z and center:SetZ(min_z) or center
	return center
end

function editor.Serialize(objs, collections, center, options)
	local objs_orig = objs
	center = center or editor.GetObjectsCenter(objs)
	options = options or empty_table
	
	local GetVisualPosXYZ = CObject.GetVisualPosXYZ
	local GetHeight = terrain.GetHeight
	local GetTerrainNormal = terrain.GetTerrainNormal
	local GetOrientation = CObject.GetOrientation
	local IsValidZ = CObject.IsValidZ
	local GetClassFlags = CObject.GetClassFlags
	local GetGameFlags = CObject.GetGameFlags
	local GetCollectionIndex = CObject.GetCollectionIndex
	local IsValidPos = CObject.IsValidPos
	local cfLuaObject = const.cfLuaObject
	local InvalidPos = InvalidPos
	local IsT = IsT
	
	if not collections then
		collections = {}
		for i = 1, #objs do
			local col_idx = GetCollectionIndex(objs[i])
			if col_idx ~= 0 then
				collections[col_idx] = true
			end
		end
	end
	local cols = {}
	for idx in pairs(collections) do
		cols[#cols + 1] = Collections[idx]
	end
	
	local cobjects
	if options.compact_cobjects then
		if objs == objs_orig then objs = table.icopy(objs) end
		for i = #objs,1,-1 do
			local obj = objs[i]
			if GetClassFlags(obj, cfLuaObject) == 0 then
				cobjects = cobjects or {}
				cobjects[#cobjects + 1] = obj
				table.remove(objs, i)
			end
		end
	end
	
	local get_collection_index_func
	local locked_idx = editor.GetLockedCollectionIdx()
	if locked_idx ~= 0 and not options.ignore_locked_coll then
		get_collection_index_func = function(obj)
			local idx = GetCollectionIndex(obj)
			if idx ~= locked_idx then
				return idx
			end
		end
	end
	
	local no_translation = options.no_translation
	local function get_prop(obj, prop_id)
		if prop_id == "CollectionIndex" and get_collection_index_func then
			return get_collection_index_func(obj)
		elseif prop_id == "Pos" then
			return IsValidPos(obj) and (obj:GetPos() - center) or InvalidPos()
		end
		local value = obj:GetProperty(prop_id)
		if no_translation and value ~= "" and IsT(value) then
			StoreErrorSource(obj, "Translation found for property", prop_id)
			return ""
		end
		return value
	end
	
	local code = pstr("", 1024)
	code:append(options.comment_tag or "--[[HGE place script]]--")
	code:append("\nSetObjectsCenter(")
	code:appendv(center)
	code:append(")\n")

	ObjectsToLuaCode(cols, code, get_prop)
	ObjectsToLuaCode(objs, code, get_prop)
	
	local err
	if cobjects then
		local test_encoding = options.test_encoding
		local collection_remap
		if get_collection_index_func then
			collection_remap = {}
			for _, obj in ipairs(cobjects) do
				collection_remap[obj] = get_collection_index_func(obj)
			end
		end
		code:append("\n--[[COBJECTS]]--\n")
		code:append("PlaceCObjects(\"")
		code, err = __DumpObjPropsForSave(code, cobjects, true, center, nil, nil, collection_remap, test_encoding)
		code:append("\")\n")
	end
	if not options.pstr then
		local str = code:str()
		code:free()
		code = str
	end
	return code, err
end

function editor.Unserialize(script, no_z, forced_center)
	return LuaCodeToObjs(script, {
		no_z = no_z,
		pos = forced_center or (terminal.desktop.inactive and GetTerrainGamepadCursor() or GetTerrainCursor())
	})
end

function editor.CopyToClipboard()
	if IsEditorActive() and #editor.GetSel() > 0 then
		local objs = editor.GetSel()
		local script = editor.Serialize(objs, empty_table)
		CopyToClipboard(script)
	end
end

function editor.PasteFromClipboard(no_z)
	if not IsEditorActive() then
		return
	end
	
	local script = GetFromClipboard(-1)
	local objs = editor.Unserialize(script, no_z)
	if not objs then
		return
	end
	
	objs = table.ifilter(objs, function (idx, o) return not o:IsKindOf("Collection") end)
	
	XEditorUndo:BeginOp{name = "Pasted objects"}
	XEditorUndo:EndOp(objs)
	
	editor.ClearSel()
	editor.AddToSel(objs)
	
	local objects = {}
	for i = 1,#objs do
		if IsFlagSet(objs[i]:GetClassFlags(), const.cfEditorCallback) then
			objects[#objects + 1] = objs[i]
		end
	end
	if #objects > 0 then
		SuspendPassEditsForEditOp()
		Msg("EditorCallback", "EditorCallbackPlace", objects)
		ResumePassEditsForEditOp()
	end
	return objs
end

editor.SelectDuplicates = function()
	local l = MapGet("map") or empty_table
	local num = #l
	
	print( num )

	local function cmp_x(o1,o2) return o1:GetPos():x() < o2:GetPos():x() end
	table.sort( l, cmp_x )

	editor.ClearSel()	

	for i = 1,num do
		local pt = l[i]:GetPos()
		local axis = l[i]:GetAxis()
		local angle = l[i]:GetAngle()
		local class = l[i].class

		local function TestDuplicate(idx)
			local obj = l[idx]
			if pt == obj:GetPos() and axis == obj:GetAxis() and angle == obj:GetAngle() and class == obj.class then
				editor.AddToSel({obj})
				return true
			end
			return false
		end

		local j = i + 1
		local x = pt:x()
		while j <= num and x == l[j]:GetPos():x() do
			if TestDuplicate(j) then
				table.remove( l, j )
				num = num-1
			else
				j = j+1
			end
		end
	end
end

local function SetReplacedObjectDefaultFlags(new_obj)
	new_obj:SetGameFlags(const.gofPermanent)
	new_obj:SetEnumFlags(const.efVisible)
	local entity = new_obj:GetEntity()
	local passability_mesh = HasMeshWithCollisionMask(entity, const.cmPassability)
	local entity_collisions = HasAnySurfaces(entity, EntitySurfaces.Collision) or passability_mesh
	local entity_apply_to_grids = HasAnySurfaces(entity, EntitySurfaces.ApplyToGrids) or passability_mesh
	new_obj:SetCollision(entity_collisions)
	new_obj:SetApplyToGrids(entity_apply_to_grids)
end

function editor.ReplaceObject(obj, class)
	if g_Classes[class] and IsValid(obj) then
		XEditorUndo:BeginOp{ objects = {obj}, name = "Replaced 1 objects" }
		Msg("EditorCallback", "EditorCallbackDelete", {obj}, "replace")
		local new_obj = PlaceObject(class)
		new_obj:CopyProperties(obj)
		DoneObject(obj)
		SetReplacedObjectDefaultFlags(new_obj)
		Msg("EditorCallback", "EditorCallbackPlace", {new_obj}, "replace")
		XEditorUndo:EndOp({new_obj})
		return new_obj
	end
	return obj
end

function editor.ReplaceObjects(objs, class)
	if g_Classes[class] and #objs > 0 then
		SuspendPassEditsForEditOp()
		PauseInfiniteLoopDetection("ReplaceObjects")
		XEditorUndo:BeginOp{ objects = objs, name = string.format("Replaced %d objects", #objs) }
		Msg("EditorCallback", "EditorCallbackDelete", objs, "replace")
		local ol = {}
		for i = 1 , #objs do
			local new_obj = PlaceObject(class)
			new_obj:CopyProperties(objs[i])
			DoneObject(objs[i])
			SetReplacedObjectDefaultFlags(new_obj)
			ol[#ol + 1] = new_obj
		end
		if ol then
			editor.ClearSel()
			editor.AddToSel(ol)
		end
		Msg("EditorCallback", "EditorCallbackPlace", ol, "replace")
		XEditorUndo:EndOp(ol)
		ResumeInfiniteLoopDetection("ReplaceObjects")
		ResumePassEditsForEditOp()
	else
		print("No such class: " .. class)
	end
end

function OnMsg.EditorCallback(id, objects, ...)	
	if id == "EditorCallbackClone" then
		local old = ...
		for i = 1, #old do
			local object = objects[i]
			if IsValid(object) and object:IsKindOf("EditorCallbackObject") then
				object:EditorCallbackClone(old[i])
			end
		end
	else
		local place = id == "EditorCallbackPlace"
		local clone = id == "EditorCallbackClone"
		local delete = id == "EditorCallbackDelete"
		for i = 1, #objects do
			local object = objects[i]
			if IsValid(object) then
				if (place or clone) and object:IsKindOf("AutoAttachObject") and object:GetForcedLODMin() then
					object:SetAutoAttachMode(object:GetAutoAttachMode())
				end
				if IsKindOf(object, "EditorCallbackObject") then
					object[id](object, ...)
				end
				if place then
					if IsKindOf(object, "EditorObject") then
						object:EditorEnter()
					end
				elseif delete then
					if IsKindOf(object, "EditorObject") then
						object:EditorExit()
					end
				end
			end
		end
	end
end

function editor.GetSingleSelectedCollection(objs)
	local collections, remaining = editor.ExtractCollections(objs or editor.GetSel())
	local first = collections and next(collections)
	return #remaining == 0 and first and not next(collections, first) and Collections[first]
end

function editor.ExtractCollections(objs)
	local collections
	local remaining = {}
	local locked_idx = editor.GetLockedCollectionIdx()
	for _, obj in ipairs(objs or empty_table) do
		local coll_idx = 0
		if obj:IsKindOf("Collection") then
			coll_idx = obj.Index
		else
			coll_idx = obj:GetCollectionIndex()
			if locked_idx ~= 0 then
				local relation = obj:GetCollectionRelation(locked_idx)
				if relation == "child" then -- add just this object
					coll_idx = 0
				elseif relation == "sub" then -- add the whole collection (use GetCollectionRoot)
					coll_idx = Collection.GetRoot(coll_idx)
				end
			else
				if coll_idx ~= 0 then -- try to find root
					coll_idx = Collection.GetRoot(coll_idx)
				end
			end
		end
		
		if coll_idx == 0 then -- add just this object
			remaining[#remaining + 1] = obj
		else -- add the whole collection
			collections = collections or {}
			collections[coll_idx] = true
		end
	end
	return collections, remaining
end

function editor.SelectionPropagate(objs)
	local collections, selection = nil, objs or {}
	if XEditorSelectSingleObjects == 0 then
		collections, selection = editor.ExtractCollections(objs)
	end
	for coll_idx, _ in sorted_pairs(collections or empty_table) do
		table.iappend(selection, MapGet("map", "collection", coll_idx, true))
	end
	
	if const.SlabSizeX then
		if terminal.IsKeyPressed(const.vkControl) then
			local visited = {}
			for _, obj in ipairs(objs) do
				if IsKindOf(obj, "StairSlab") and not visited[obj] then
					local gx, gy, gz = obj:GetGridCoords()
					table.iappend(selection, EnumConnectedStairSlabs(gx, gy, gz, 0, visited))
				end
			end
		end
	end
	
	return selection
end

MapVar("EditorCursorObjs", {}, weak_keys_meta)
PersistableGlobals.EditorCursorObjs = nil

function editor.GetPlacementPoint(pt)
	local eye = camera.GetEye()
	local target = pt:SetTerrainZ()
	
	local objs = IntersectSegmentWithObjects(eye, target, const.efBuilding | const.efVisible)
	local pos, dist
	if objs then
		for _, obj in ipairs(objs) do
			if not EditorCursorObjs[obj] and obj:GetGameFlags(const.gofSolidShadow) == 0 then
				local hit = obj:IntersectSegment(eye, target)
				if hit then
					local d = eye:Dist(hit)
					if not dist or d < dist then
						pos, dist = hit, d
					end
				end
			end
		end
	end
	return pos or pt:SetInvalidZ()
end

function editor.CycleDetailClass()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	XEditorUndo:BeginOp{ objects = sel, name = "Toggle Detail Class" }
	local seldc = {}
	for _, obj in ipairs(sel) do
		local dc = obj:GetDetailClass()
		seldc[dc] = seldc[dc] or 0
		seldc[dc] = seldc[dc] + 1
	end
	
	local next_dc = "Eye Candy"
	if seldc["Eye Candy"] then 
		next_dc = "Optional" 
	elseif seldc["Optional"] then 
		next_dc = "Essential" 
	end
	
	for _, obj in ipairs(sel) do
		obj:SetDetailClass(next_dc)
	end

	XEditorUndo:EndOp(sel)
end

function editor.ForceEyeCandy()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	XEditorUndo:BeginOp{ objects = sel, name = "Force Eye Candy" }
	SuspendPassEditsForEditOp(sel)
	for _, obj in ipairs(sel) do
		obj:ClearEnumFlags(const.efCollision + const.efApplyToGrids)
		obj:SetDetailClass("Eye Candy")
	end

	ResumePassEditsForEditOp(sel)
	XEditorUndo:EndOp(sel)
end


----- Modding editor
--
-- The Mod Editor starts the map editor in this mode when a user is editing a map.
--
-- The Mod Item that contains the map (or map patch) is stored in editor.ModItem;
-- for ModItemMapPatch Ctrl-S generates a patch via XEditorCreateMapPatch.
-- This mode also disables some shortcuts, e.g. closing the editor.

if FirstLoad then
	editor.ModdingEditor = false
end	

function editor.IsModdingEditor()
	return editor.ModdingEditor
end

function editor.AskSavingChanges()
	if editor.ModdingEditor and editor.ModItem and EditorMapDirty then
		if GedAskEverywhere("Warning", "There are unsaved changes on the map.\n\nSave before proceeding?", "Yes", "No") == "ok" then
			editor.ModItem:SaveMap()
		end
		SetEditorMapDirty(false)
	end
end

-- When changing the map via F5, ask the user for saving changes;
-- (in case the map is changed via editor.StartModdingEditor, we call editor.AskSavingChanges before updating editor.ModItem)
function OnMsg.ChangingMap(map, mapdata, handler_fns)
	table.insert(handler_fns, editor.AskSavingChanges)
end

function editor.StartModdingEditor(mod_item, map)
	if ChangingMap then return end
	
	editor.AskSavingChanges()
	
	editor.ModdingEditor = true
	editor.ModItem = mod_item
	editor.ModItemMap = map
	
	ReloadShortcuts()
	UpdateModEditorsPropPanels() -- update buttons in Mod Item properties, e.g. "Edit Map"
	
	if editor.PreviousModItem ~= mod_item or CurrentMap ~= map then
		editor.PreviousModItem = mod_item
		ChangeMap(map)
	end
	
	if not IsEditorActive() then
		EditorActivate()
	end
end

function editor.StopModdingEditor(return_to_mod_map)
	if ChangingMap or not editor.ModdingEditor then return end
	
	CreateRealTimeThread(function()
		-- change map first, so the OnMsg.ChangingMap asks for saving changes
		if return_to_mod_map and CurrentMap ~= ModEditorMapName then
			editor.PreviousModItem = false
			ChangeMap(ModEditorMapName)
		end
		
		editor.ModdingEditor = false
		editor.ModItem = nil
		editor.ModItemMap = nil
		
		ReloadShortcuts()
		UpdateModEditorsPropPanels() -- update buttons in Mod Item properties, e.g. "Edit Map"
		
		if IsEditorActive() then
			EditorDeactivate()
		end
	end)
end

function OnMsg.GedClosing(ged_id)
	local conn = GedConnections[ged_id]
	if conn and conn.app_template == "ModEditor" then
		if editor.ModdingEditor and editor.ModItem and conn.bound_objects.root[1] == editor.ModItem.mod then
			editor.StopModdingEditor("return to mod map") -- close map editor if the mod editor for its edited map is closed
		end
	end
end

-- the user may change the map to another one; if it is a mod-created map, find its mod item
function OnMsg.ChangeMap(map)
	if editor.ModdingEditor and editor.ModItemMap ~= map then
		editor.ModItemMap = nil
		editor.ModItem = nil
		for _, mod in ipairs(ModsLoaded) do
			mod:ForEachModItem(function(mod_item)
				if mod_item:GetMapName() == map then
					editor.ModItem = mod_item
					return "break"
				end
			end)
		end
		UpdateModEditorsPropPanels() -- update buttons in Mod Item properties, e.g. "Edit Map"
	end
end
