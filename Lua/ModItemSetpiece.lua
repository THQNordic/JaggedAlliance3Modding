if not config.Mods then return end

DefineModItemPreset("SetpiecePrg", { EditorSubmenu = "Campaign & Maps", EditorName = "Setpiece", ModItemDescription = Untranslated("<u(id)> - <opt(Map)>") })

AppendClass.ModItemSetpiecePrg = {
	__parents = { "ModItemMapPatch" },
	properties = {
		{ category = "Map", id = "Help", editor = false }, -- remove prop from ModItemMapPatch
		{ category = "Map", id = "Map", editor = "choice", default = false, items = function() return GetPatchableMaps() end, read_only = IsChangingMap },
		{ category = "Map", id = "PlaceMarkers", editor = "buttons", default = "", --overwrite place marker buttons to modify their no_edit funcs
			buttons = function() return table.map(ClassLeafDescendantsList("SetpieceMarker"), function(class)
				return { name = "Place " .. g_Classes[class].DisplayName, func = SetpieceMarkerPlaceButton, param = class }
			end) end,
			no_edit = function(self) return not self.Map or self.Map ~= CurrentMap or not editor.IsModdingEditor() or IsChangingMap() end,
		},
		{ id = "mapName", default = false, no_edit = true, editor = "text" },
	},
	Documentation = "Creates a new setpiece which allows setting up a sequence of commands controlling various things such as actors behavior, camera behavior, animation, etc. Cut-scenes are usually created via setpieces.",
	TestDescription = "Starts the setpiece."
}

ModItemSetpiecePrg.__toluacode = ModItemUsingFiles.__toluacode
ModItemSetpiecePrg.Documentation = SetpiecePrg.Documentation ..
	"\n\nA Setpiece mod item will allow you to edit the map, and store your changes as a <style GedHighlight>map patch</style>."

function ModItemSetpiecePrg:GetModItemDescription()
	-- override ModItemMapPatch:GetModItemDescription() to restore the default behavior
	return self.ModItemDescription
end

function ModItemSetpiecePrg:OnEditorNew()
	self:GenerateMapName()
	AsyncCreatePath(self:GetDestinationFolder())
	self.Map = false end

function ModItemSetpiecePrg:OnEditorDelete()
	AsyncDeletePath(self:GetDestinationFolder())
end

function ModItemSetpiecePrg:GetEditorMessage()
	return string.format("Setpiece map patch in mod: %s", Literal(self.mod.title)) -- appears in editor's status bar
end

function ModItemSetpiecePrg:GetError()
	if not self.Map or self.Map == "" then
		return "The setpiece requires a map reference."
	end
end

function ModItemSetpiecePrg:TestModItem(ged)
	if self:GetError() then
		ged:ShowMessage("Warning", "Resolve errors before trying to test.")
		return
	end
	SetpiecePrg.Test(self, ged)
end

function ModItemSetpiecePrg:GetAffectedResources()
	local affected_resources = {}
	table.iappend(affected_resources, ModItemMapPatch.GetAffectedResources(self))
	table.iappend(affected_resources, ModItemPreset.GetAffectedResources(self))
	return affected_resources
end

function ModItemSetpiecePrg:GenerateMapName()
	self.mapName = self.id .. "_" .. ModDef.GenerateId()
	while io.exists(self:GetDestinationFolder()) do
		self.mapName = self.id .. "_" .. ModDef.GenerateId()
	end
end

function ModItemSetpiecePrg:GetDestinationSubFolder()
	return "MapPatches/SetPieces/" .. self.mapName
end

function ModItemSetpiecePrg:GetDestinationFolder()
	return SlashTerminate(self.mod.content_path) .. self:GetDestinationSubFolder()
end

function ModItemSetpiecePrg:GetCodeFileName(name)
	if self.HasCompanionFile or self.GetCompanionFilesList ~= Preset.GetCompanionFilesList then
		name = name or self.id
		return name and name ~= "" and
			string.format("%s/%s.lua", self:GetDestinationSubFolder(), name:gsub('[/?<>\\:*|"]', "_"))
	end
end

function ModItemSetpiecePrg:GetFilesContents(filesList)
	local files = ModItemMapPatch.GetFilesContents(self)
	files["prev_dest_folder"] = self:GetDestinationFolder()
	files["prev_map"] = self.Map
	return files
end

function ModItemSetpiecePrg:ResolvePasteFilesConflicts(ged)
	self.Map = self.CopyFiles.prev_map
	for _, copy_file in ipairs(self.CopyFiles) do
		copy_file.filename = copy_file.filename:gsub(self.CopyFiles.prev_dest_folder, self:GetDestinationFolder())
	end
end