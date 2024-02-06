if not config.Mods then return end

----- ModItemMapPatch

-- Game-specific function that determines if map patches can be created for this map. 
-- Can be overriden per game. Generic one returns true for any map.
function IsMapPatchable(map)
	return true
end

-- Game-specific function that returns all maps for which map patches can be created.
-- Can be overriden per game. Generic one filters all game maps based on IsMapPatchable(map).
function GetPatchableMaps()
	return table.ifilter(GetAllGameMaps(), function(idx, map) return IsMapPatchable(map) end)
end

-- Zulu specific IsMapPatchable()
function IsMapPatchable(map)
	local mapData = MapData[map]
	local modMap = mapData and mapData.ModMapPath
	return string.find(map, "^[A-Z]%-[0-9]+U? ") or map:starts_with("MainMenu") or modMap
end

DefineClass.ModItemMapPatch = {
	__parents = { "ModItemUsingFiles", },
	
	properties = {
		{ category = "Map", id = "Map", editor = "choice", default = false, items = GetPatchableMaps,
			read_only = function(self) return self.MapPatchPath or IsChangingMap() end,
		},
		
		{ category = "Map", id = "Buttons", editor = "buttons", default = false, 
			buttons = {
				{ name = "Edit map", func = "EditMap", is_hidden = function(self) return self:ShouldHideButton("edit") end },
				{ name = "Close map editor", func = "CloseMapEditor", is_hidden = function(self) return self:ShouldHideButton("close") end },
				{ name = "Delete patch", func = "DeleteMapPatch", is_hidden = function(self) return self:ShouldHideButton("delete") end }
			}, untranslated = true, },
		
		-- MapPatchPath is set only when a map patch has been created (or another ModItemMapPatch has been copied)
		{ category = "Map", id = "MapPatchPath", name = "Map patch created", editor = "text", default = false, read_only = true },
		{ id = "name", default = false, editor = false },
			
	},
	
	EditorName = "Map patch",
	EditorSubmenu = "Campaign & Maps",
	Documentation = "Allows making changes to an existing game map, stored as a patch containing the changes only.\n\nSaving your changes in the map editor with Ctrl-S will create the map patch and store it in the mod.\n\nFor better mod compatibility, widespread map changes are not recommended.",
	DocumentationLink = "Docs/ModTools/index.md.html",
	
	obj_hashes = false, -- hashes of the objects affected by the map patch
	affected_grids = false, -- names of the grids affected by the map patch
}

function ModItemMapPatch:GetModItemDescription()
	return Untranslated(self.Map or "MapPatch")
end

function OnMsg.ChangeMap()
	UpdateModEditorsPropPanels()
end

function OnMsg.ChangeMapDone()
	UpdateModEditorsPropPanels()
end

function ModItemMapPatch:ShouldHideButton(btn)
	if IsChangingMap() then return true end
	if btn == "edit" then
		return not self.Map or editor.IsModdingEditor()
	elseif btn == "close" then
		return not self.Map or not editor.IsModdingEditor()
	elseif btn == "delete" then
		return not self.MapPatchPath
	end
end

function ModItemMapPatch:OnEditorDelete(mod, ged)
	if self.Map == CurrentMap then
		editor.StopModdingEditor("return to mod map")
	end
	self:DeleteMapPatch(nil, nil, ged, "force_delete")
end

function ModItemMapPatch:GetDestinationFolder()
	return SlashTerminate(self.mod.content_path) .. "MapPatches"
end

function ModItemMapPatch:GetMapPatchName()
	return self.Map .. ".patch"
end

-- we can only have one "proper" MapPatch per mod, but multiple SetPieces, which are also MapPatches (and they do not conflict with MapPatches)
function CheckModItemMapPatchCompatibility(map_patch1, map_patch2)
	assert(IsKindOf(map_patch1, "ModItemMapPatch") and IsKindOf(map_patch2, "ModItemMapPatch"))
	if IsKindOf(map_patch1, "ModItemSetpiecePrg") or IsKindOf(map_patch2, "ModItemSetpiecePrg") then return true end
	return map_patch1.Map ~= map_patch2.Map
end

-- Checks if there's another ModItemMapPatch in the same mod that patches the same map
function ModItemMapPatch:IsDuplicate()
	if self.mod and self.mod.items and self.Map then
		return self.mod:ForEachModItem("ModItemMapPatch", function(item)
			if item ~= self then
				if not CheckModItemMapPatchCompatibility(self, item) then
					return true
				end
			end
		end)
	end
	return false
end

function ModItemMapPatch:OnEditorSetProperty(prop_id, old_value, ged)
	-- NOTE: The Map property is made read only once a map patch is saved.
	-- This is done to prevent loss of data, because changing the Map after that will delete the patch with no undo.
	-- Also, doing that basically resets the mod item, so the user can do that by deleting it and creating a new one (which has undo).
	if prop_id == "Map" and self.Map and not self.MapPatchPath then
		CreateRealTimeThread(function()
			-- changing the map edited by the MapPatch mod item; reject if a map patch for the new map already exists
			if self:IsDuplicate() then
				ged:ShowMessage("Duplicate Map Patch!", string.format("A Map Patch for '%s' already exists in this mod!", self.Map))
				self.Map = old_value
				ObjModified(ged.bound_objects.root)
				ObjModified(self)
				return
			end
			
			-- start the map editor
			editor.StartModdingEditor(self, self.Map)
		end)
	end
	
	ModItem.OnEditorSetProperty(self, prop_id, old_value, ged)
end

function ModItemMapPatch:EditMap(root, prop_id, ged)
	if not self.Map then return end
	CreateRealTimeThread(editor.StartModdingEditor, self, self.Map)
end

function ModItemMapPatch:CloseMapEditor(root, prop_id, ged)
	editor.StopModdingEditor("return to mod map")
end

function ModItemMapPatch:SaveMap()
	if not self:CreateMapPatch() then
		CreateMessageBox(nil, T(634182240966, "Error"), T{564744087341, "Failed to save map changes to <filename>.", filename = self.MapPatchPath }, T(325411474155, "OK"))
	end
end

function ModItemMapPatch:CreateMapPatch()
	if not self.Map then return end
	
	self.MapPatchPath = SlashTerminate(self:GetDestinationFolder()) .. self:GetMapPatchName()
	self.obj_hashes, self.affected_grids, self.compacted_obj_boxes = XEditorCreateMapPatch(self.MapPatchPath)
	
	ObjModified(self)
	
	-- In modding editor after a map patch is created or applied the map is considered not dirty
	SetEditorMapDirty(false)
	
	-- Save the whole mod as well
	self.mod:SaveWholeMod()
	
	--save markers debug data for this patch in the mod
	CheckMarkersPos()
	local markers_data = GatherMarkerScriptingData()
	if markers_data and next(markers_data) then
		local map_name = self.Map
		local path = SlashTerminate(self:GetDestinationFolder()) .. map_name .. ".debug.lua"
		
		local err = StringToFileIfDifferent(path, TableToLuaCode(markers_data, nil, pstr("", 1024)))
		if err then return err end
	end
	
	return true
end

function ModItemMapPatch:DeleteMapPatch(root, prop_id, ged, force_delete, old_value)
	if ChangingMap then return end
	if self.MapPatchPath then
		CreateRealTimeThread(function()
			if not force_delete and ged and ged:WaitQuestion("Warning", "Deleting the map patch <style GedHighlight>can't be undone</style>.\n\nContinue?", "Yes", "No") ~= "ok" then
				return
			end
			
			AsyncDeletePath(self.MapPatchPath)
			if old_value then AsyncDeletePath(SlashTerminate(self:GetDestinationFolder()) .. old_value .. ".debug.lua") end
			self.MapPatchPath = nil
			ObjModified(self)
			if ged then
				ObjModified(ged:ResolveObj("root"))
			end
		end)
	end
end

function ModItemMapPatch:GetAffectedResources()
	if self.MapPatchPath then
		local ok, edit_op
		-- If the map patch was not created in this session, read the object hashes and affected grids from the patch file
		if not self.obj_hashes or not self.affected_grids or not self.compacted_obj_boxes then
			ok, edit_op = pdofile(self.MapPatchPath)
			
			self.obj_hashes = ok and edit_op and edit_op.hash_to_handle and table.keys(edit_op.hash_to_handle)
			
			self.affected_grids = {}
			for _, grid in ipairs(editor.GetGridNames()) do
				if edit_op[grid] then
					self.affected_grids[grid] = edit_op[grid].box
				end
			end
			
			self.compacted_obj_boxes = ok and edit_op and edit_op.compacted_obj_boxes or empty_table
		end
		
		local affected_resources = {}
		table.insert(affected_resources, ModResourceMap:new({
			mod = self.mod,
			Map = self.Map,
			-- Use 'false' instead of empty tables to shorten the serialized code in the mod metadata
			Objects = not table.iequal(self.obj_hashes, empty_table) and self.obj_hashes,
			Grids = not table.iequal(self.affected_grids, empty_table) and self.affected_grids,
			ObjBoxes = not table.iequal(self.compacted_obj_boxes, empty_table) and self.compacted_obj_boxes,
		}))
		
		return affected_resources
	end
	
	return empty_table
end

function ModItemMapPatch:GetFilesList()
	if not self.Map then return end
	local map_name = self.Map
	return {
		SlashTerminate(self:GetDestinationFolder()) .. map_name .. ".debug.lua", 
		SlashTerminate(self:GetDestinationFolder()) .. map_name .. ".patch"
	}
end

function ModItemMapPatch:ResolvePasteFilesConflicts(ged)
	if self:IsDuplicate() then
		ModLogF(string.format("Map patch <%s> already exists in mod <%s>, created empty map patch instead.", self.Map, self.mod.id))
		self.CopyFiles = {}
		self.Map = false
		self.MapPatchPath = false
		ObjModified(self)
	end
	for _, copy_file in ipairs(self.CopyFiles) do
		copy_file.filename = copy_file.filename:gsub(self.CopyFiles.mod_content_path, self.mod.content_path)
	end
end

function ModItemMapPatch:OnAfterPasteFiles(changes_meta)
	if not self.Map then return end
	local target_path = SlashTerminate(self:GetDestinationFolder()) .. self:GetMapPatchName()
	if io.exists(target_path) then
		self.MapPatchPath = target_path
	end
end

function ModItemMapPatch:GetEditorMessage()
	return string.format("Map patch in mod: %s", Literal(self.mod.title)) -- appears in editor's status bar
end

function OnMsg.NewMapLoadAdditionalObjects(map)
	if not IsMapPatchable(map) then return end
	
	-- Apply map patches
	if not editor.IsModdingEditor() then
		-- If the editor is NOT in modding mode, apply map patches from all loaded mods
		for _, mod in ipairs(ModsLoaded) do
			mod:ForEachModItem("ModItemMapPatch", function(mod_item)
				if mod_item.Map == map and mod_item.MapPatchPath then
					XEditorApplyMapPatch(mod_item.MapPatchPath)
				end
			end)
		end
	else
		-- Otherwise if the editor IS in modding mode, apply only the map patch from the mod item that opened the modding editor
		local mod_item = editor.ModItem
		if not mod_item then return end
		
		if mod_item.Map == map and mod_item.MapPatchPath then
			XEditorApplyMapPatch(mod_item.MapPatchPath)
		end
	end
	
	-- After a map patch is created or applied the map is considered not dirty
	SetEditorMapDirty(false)
end
