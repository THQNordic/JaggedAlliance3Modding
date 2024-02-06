if not config.Mods then return end

DefineClass.ModItemSector =  {
	__parents = { "ModItemUsingFiles" },
	
	EditorName = "Satellite sector",
	EditorSubmenu = "Campaign & Maps",
	Documentation = "Allows for the creation of new satellite sectors and maps for them, or the modification of existing ones.\n\nSave your changes in the map editor using Ctrl-S.",
	DocumentationLink = "Docs/ModTools/index.md.html",
	TestDescription = "Starts the selected campaign of the sector and teleports you to the sector.",
	
	properties = {
		{ id = "mapName", default = false, no_edit = true, editor = "text" },
		{ category = "Satellite Sector", id = "campaignId", name = "Campaign", editor = "choice", default = false, items = function(self) return PresetsCombo("CampaignPreset") end,
			validate = function(self, new_campaignId) return self:IsDuplicateMap(new_campaignId, self.sectorId) end },
		{ category = "Satellite Sector", id = "sectorId", name = "Sector", editor = "combo", default = false, items = function(self) return GetCampaignSectorsIds(self) end, items_allow_tags = true, no_edit = function(self) return not CampaignPresets[self.campaignId] end,
			validate = function(self, new_sectorId) return ValidateSectorId(new_sectorId, "allow_underground") or self:IsDuplicateMap(self.campaignId, new_sectorId) end },
		{ category = "Satellite Sector", id = "btn", editor = "buttons",
			buttons = {
				{ name = "Edit map", func = "EditMap", is_hidden = function(self) return self:ShouldHideProp() or self:ShouldHideMapButton("edit") end},
				{ name = "Close map editor", func = "CloseMapEditor", is_hidden = function(self) return self:ShouldHideProp() or self:ShouldHideMapButton("close") end},
			}
		},
		{ category = "Satellite Sector", id = "SatelliteSectorObj", name = "Satellite sector", default = false, editor = "nested_obj", auto_expand = true, 
			base_class = "SatelliteSector", default = false, no_edit = function(self) return self:ShouldHideProp() end },
		{ id = "name", default = false, editor = false },
	},
}

function ModItemSector:OnEditorNew(parent, ged, is_paste)
	self:GenerateMapName()
	self:CreateMapFolder("EmptyMap")

	if is_paste then return end
	self.mod:ForEachModItem("ModItemCampaignPreset", function(modItem)
		self.campaignId = modItem.id
	end)
end

function ModItemSector:ModItemDescription()
	if not self.sectorId then
		return "SatelliteSector"
	else
		return self.sectorId
	end
end

function ModItemSector:IsReadOnly()
	return editor.IsModdingEditor()
end

function ModItemSector:GetWarning()
	if self.campaignId and self.sectorId then
		local campaignSectors = CampaignPresets[self.campaignId] and CampaignPresets[self.campaignId].Sectors
		if self:IsDirty() or not campaignSectors or (self.SatelliteSectorObj and not table.find(campaignSectors, "Map", self.SatelliteSectorObj.Map)) then
			return "Save the mod item to add the sector in the campaign preset."
		end
	end
end

function ModItemSector:GetError()
	if self:ShouldHideProp() then
		return "Campaign and Sector ID should not be empty!"
	end
	
	local satSectorObj = self.SatelliteSectorObj
	
	if not satSectorObj then
		local campaignPreset = CampaignPresets[self.campaignId]
		local existingCampaignSector = campaignPreset and table.find_value(campaignPreset.Sectors, "Id", self.sectorId)
		if not existingCampaignSector then
			return string.format("Missing Satellite sector for %s", self.sectorId)
		end
	end
	
	local mapPath = self:GetFolderPathOS()
	if not io.exists(mapPath .. "mapdata.lua") then
		return string.format("Missing map data for the mod item in '%s'", mapPath)
	end
	
	if satSectorObj and satSectorObj.GroundSector then
		if not self:IsDuplicateMap(self.campaignId, satSectorObj.GroundSector) and not DoesSectorExist(self.campaignId, satSectorObj.GroundSector) then
			return string.format("There is no ground sector '%s' for this underground sector '%s'", satSectorObj.GroundSector, self.sectorId)
		end
	end
end

function ModItemSector:ShouldHideMapButton(btnType)
	if IsChangingMap() then return true end
	if btnType == "edit" then
		return editor.IsModdingEditor()
	elseif btnType == "close" then
		return not editor.IsModdingEditor()
	end
end

function ModItemSector:PostLoad()	
	if self.SatelliteSectorObj then
		local newProperties = table.copy(self.SatelliteSectorObj.properties, "deep")
		for _, prop in ipairs(newProperties) do
			if prop.id == "Map" then
				prop.editor = "text"
				prop.read_only = true
			end
		end
		self.SatelliteSectorObj.properties = newProperties
	end
end

function ModItemSector:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "sectorId" or prop_id == "campaignId" then
		g_WeatherZones = false
		CreateRealTimeThread(function() self:UpdateCampaignSector(prop_id, old_value, ged) end)
	end
end

function ModItemSector:ShouldHideProp()
	if not self.campaignId or self.campaignId == "" then
		return true
	end
	
	if not self.sectorId or self.sectorId == "" then
		return true
	end
end

function ModItemSector:EditMap(root, prop_id, ged)
	CreateRealTimeThread(editor.StartModdingEditor, self, self:GetMapName())
end

function ModItemSector:CloseMapEditor(root, prop_id, ged)
	editor.StopModdingEditor("return to mod map")
end

local function PreSelectSectorInEditor(modItemSector)
	-- not game or different campaign will cause the creation of new campaign automatically
	if not Game or not next(gv_Sectors) or modItemSector.campaignId ~= Game.Campaign then
		ProtectedModsReloadItems(nil, "force_reload")
		QuickStartCampaign(modItemSector.campaignId or "HotDiamonds", {difficulty = "Normal"}, modItemSector.sectorId or "A1")
	end
	
	OpenGedSatelliteSectorEditor()
	WaitMsg("GedOpened", 5000)
	SelectEditorSatelliteSector({ modItemSector.SatelliteSectorObj })
	UpdateGedSatelliteSectorEditorSel()
end

function ModItemSector:POpenGedSatelliteSectorEditor(socket)
	if ChangingMap then return end
	
	if not self.SatelliteSectorObj then
		socket:ShowMessage("Warning", "No satellite sector created.")
	end
	
	CreateRealTimeThread(function()
		if editor.IsModdingEditor() then
			editor.StopModdingEditor("return to mod map")
			ObjModified(self)
			PreSelectSectorInEditor(self)
		else
			PreSelectSectorInEditor(self)
		end
	end)
end

function ModItemSector:GenerateMapName()
	self.mapName = ModDef.GenerateId()
end

function ModItemSector:GetMapName()
	return self.mapName
end

function ModItemSector:GetEditorMessage()
	return string.format("Saved in mod: %s", Literal(self.mod.title)) -- appears in editor's status bar
end

function ModItemSector:SaveMap()
	XEditorSaveMap()
end

function ModItemSector:GetFolderPathOS()
	return string.format("%sMaps/%s/", self.mod.content_path, self:GetMapName())
end

function ModItemSector:PostSave(...)
	self:AddToCampaign()
end

function ModItemSector:TestModItem(ged)
	if self:GetError() then
		ged:ShowMessage("Message", "Resolve related errors before testing this mod item.")
		return
	end
	
	local question = ged:WaitQuestion(
		"Warning", 
		"The test will create a new game campaign and teleport you to the created map.\nAny unsaved changes will be lost. Do you want to continue?", 
		"Yes", 
		"No")
	if question == "ok" then
		CreateRealTimeThread(function()
			ProtectedModsReloadItems(nil, "force_reload")
			QuickStartCampaign(self.campaignId, {difficulty = "Normal"}, self.sectorId)
		end)
	end
end

function ModItemSector:OnModLoad()
	self:PostLoad()
	self:AddToCampaign()
	ModItem.OnModLoad(self)
end

function ModItemSector:OnModUnload()
	self:RemoveFromCampaign()
	ModItem.OnModUnload(self)
end


function ModItemSector:CreateSatelliteSector(cloneFrom)
	local satObj = cloneFrom and cloneFrom:Clone() or SatelliteSector:new()
	satObj.generated = false
	satObj.modId = self.mod.id
	satObj.bidirectionalRoadApply = true
	satObj.bidirectionalBlockApply = true
	self.SatelliteSectorObj = satObj
	ParentTableModified(satObj, self, "recursive")
	self:PostLoad()
end

function ModItemSector:CleanSessionData(sectorId, campaignId)
	if next(gv_Sectors) and Game and Game.Campaign == campaignId then
		DeleteSessionCampaignObject({ Id = sectorId }, SatelliteSector, gv_Sectors)
		CreateSessionCampaignObject(table.find_value(CampaignPresets[campaignId].Sectors, "Id", sectorId), SatelliteSector, gv_Sectors, "Sectors")
	end
end

if FirstLoad then
	OriginalSatSectorsReplaced = {}
end

function ModItemSector:AddToCampaign()
	if not self.sectorId or not self.campaignId then return end -- the user hasn't filled in the campaign/sector yet
	
	local campaignPreset = CampaignPresets[self.campaignId]
	if not campaignPreset then return end

	local existingSectorIdx = table.find(campaignPreset.Sectors or empty_table, "Id", self.sectorId)
	if existingSectorIdx then
		if self.campaignId == "HotDiamonds" and not campaignPreset.Sectors[existingSectorIdx].modId then
			--before replacing original sat sectors - save them in case we remove the moditems replacing them.
			OriginalSatSectorsReplaced[self.sectorId] = campaignPreset.Sectors[existingSectorIdx]:Clone()
		end
	
		if self.SatelliteSectorObj then
			campaignPreset.Sectors[existingSectorIdx] = self.SatelliteSectorObj
		else
			local existingSector = campaignPreset.Sectors[existingSectorIdx]
			existingSector.modId = self.mod.id
			existingSector.Map = self:GetMapName()
			existingSector.Id = self.sectorId
		end
	elseif self.SatelliteSectorObj then
		campaignPreset.Sectors = table.create_add(campaignPreset.Sectors, self.SatelliteSectorObj)
	else
		campaignPreset.Sectors = table.create_add(
			campaignPreset.Sectors,
			SatelliteSector:new{
				template_key = "Sectors",
				Map = self:GetMapName(),
				Id = self.sectorId,
				modId = self.mod.id,
				generated = false
			}
		)
	end
	campaignPreset:RoundOutSectors()
end

function ModItemSector:RemoveFromCampaign(campaignId, sectorId)
	campaignId = campaignId or self.campaignId
	sectorId = sectorId or self.sectorId 

	local campaignPreset = CampaignPresets[campaignId]
	if not campaignPreset then return end
	
	local idx = table.find(campaignPreset.Sectors, "Id", sectorId)
	local satSectorData = campaignPreset.Sectors[idx]
	if satSectorData and satSectorData.modId then
		table.remove(campaignPreset.Sectors, idx)
		campaignPreset:RoundOutSectors()
		self:CleanSessionData(sectorId, campaignId)
		
		if campaignId == "HotDiamonds" and OriginalSatSectorsReplaced[sectorId] then
			--restore original sat sector
			local idx = table.find(campaignPreset.Sectors, "Id", sectorId)
			if idx then
				campaignPreset.Sectors[idx] = OriginalSatSectorsReplaced[sectorId]
			end
		end
	end
end

function ModItemSector:CopyMapFiles(mapToCopy, ged)
	if not mapToCopy or mapToCopy == "" then
		return
	end	
	
	local folderPath = self:GetFolderPathOS()
	if not io.exists(folderPath) then
		return
	end
	
	local originalMapDataPreset = mapToCopy and MapData[mapToCopy]
	local originalMapFolder = mapToCopy and originalMapDataPreset and originalMapDataPreset:GetSaveFolder()

	--delete all files inside if there are any
	local err, oldMapFiles = AsyncListFiles(folderPath, '*', 'recursive')
	if not err and folderPath ~= originalMapFolder then
		for _, mapFile in ipairs(oldMapFiles) do
			AsyncDeletePath(ConvertToOSPath(mapFile))
		end
	end
	
	if mapToCopy then
		if not io.exists(originalMapFolder .. "mapdata.lua") then -- the original map is not mounted
			err = MountMap(originalMapDataPreset.id)
			if err then
				ModLogF(true, "Failed to mount map %s. Reason: %s", originalMapDataPreset.id, err)
			else
				--err = AsyncUnpack(string.format("Packs/Maps/%s.hpk", originalMapDataPreset.id), folderPath)
				--if err then print(err) end
			end
		end
		
		-- copy files from the original map
		local mapFiles
		err, mapFiles = AsyncListFiles(originalMapFolder)
		
		if err or not originalMapFolder then
			ged:ShowMessage("Message", "Unable to copy the map data - an empty map will be created.")
			self:CopyMapFiles("EmptyMap", ged)
			return
		end
		
		for _, mapFile in ipairs(mapFiles) do
			local dir, file, ext = SplitPath(mapFile)
			err = AsyncCopyFile(mapFile, folderPath .. file .. ext, "raw")
			if err then
				ModLogF(true, "Failed to copy file: %s. Reason: %s", mapFile, err)
			end
		end
	end
	
	if CurrentMap == self:GetMapName() then
		ChangeMap(CurrentMap) -- force reload map if currently loaded
	end
end

function ModItemSector:CreateMapFolder()
	local newPathInMod = self:GetFolderPathOS()
	AsyncCreatePath(newPathInMod)
end

function ModItemSector:DeleteMapFolder()
	local mapName = self:GetMapName()
	local mapDataPreset = MapData[mapName]
	if mapDataPreset then
		mapDataPreset:delete()
	end
	local mapFolderPath = self:GetFolderPathOS()
	AsyncDeletePath(mapFolderPath)
end

function ModItemSector:OnEditorDelete(mod, ged)
	if self.sectorId and self.campaignId and self:GetMapName() == CurrentMap then
		editor.StopModdingEditor("return to mod map")
	end
	self:DeleteMapFolder()
	self:RemoveFromCampaign()
end

function ModItemSector:CopySatelliteSectorData(ged, copyFrom)
	local campaignPreset = CampaignPresets[self.campaignId]
	local satelliteSectorData
	if copyFrom then
		satelliteSectorData = table.find_value(campaignPreset.Sectors, "Map", copyFrom)
		if not satelliteSectorData then
			return copyFrom
		end
	else
		satelliteSectorData = table.find_value(campaignPreset.Sectors, "Id", self.sectorId)
		if not satelliteSectorData then
			ged:ShowMessage("Message", string.format("Unable to copy satellite sector data of %s", self.sectorId))
			return 
		end
	end
	
	self:CreateSatelliteSector(satelliteSectorData)
	
	self.SatelliteSectorObj.Id = self.sectorId
	self.SatelliteSectorObj.Map = self:GetMapName()
	ObjModified(ged:ResolveObj("root"))
	ObjModified(self)
	return satelliteSectorData and satelliteSectorData.Map
end

function ModItemSector:UpdateCampaignSector(prop_id, old_value, ged)
	local newValue = self[prop_id]

	if prop_id == "campaignId" and old_value then
		self:RemoveFromCampaign(old_value, self.sectorId)
		if not newValue then
			self.sectorId = false
			self.SatelliteSectorObj = false
		end
	elseif prop_id == "sectorId" and old_value then
		self:RemoveFromCampaign(self.campaignId, old_value)
		if not newValue then
			self.SatelliteSectorObj = false
		end
	end
	
	
	if self:ShouldHideProp() then return end
	
	local isMapFound = DoesSectorExist(self.campaignId, self.sectorId)
	
	if not old_value and (not self.SatelliteSectorObj or not self.SatelliteSectorObj.Map) then --1. first time selecting sector 
		if isMapFound then --1.1. found map
			local res = ged:WaitQuestion(
				"Copy Map",
				string.format("Copy the existing map of %s?", self.sectorId),
				"Yes",
				"No, add an empty map"
			)
			
			if res == "ok" then --1.1.1. copy existing map
				local mapName = self:CopySatelliteSectorData(ged)
				self:CopyMapFiles(mapName, ged)
			else --1.1.2. create empty map
				self:CopyMapFiles("EmptyMap", ged)
				self:CreateSatelliteSector()
			end
		else --1.2 existing map not found
			local mapToCopy = ged:WaitListChoice(GetAllGameMaps(), "Copy an existing sector map?")
			if mapToCopy then --1.2.1. copy from existing map
				local mapName = self:CopySatelliteSectorData(ged, mapToCopy)
				self:CopyMapFiles(mapName, ged)
			else --1.2.2. create empty map
				self:CopyMapFiles("EmptyMap", ged)
				self:CreateSatelliteSector()
			end
		end
	else --2. map already created, but user wants to change campaignId or sectorId
		if isMapFound then --2.1. found existing map
			local res = ged:WaitQuestion(
				"Copy Map",
				string.format("Copy the existing map of '%s'? This will overwrite the current map and satellite sector data.", self.campaignId .. "_" .. self.sectorId),
				"Yes, overwrite",
				string.format("No, just update %s to %s", prop_id, newValue)
			)
			
			if res == "ok" then --2.1.1. copy from existing map and override all exisitng data so far
				local mapName = self:CopySatelliteSectorData(ged)
				self:CopyMapFiles(mapName, ged)
			end
		end
	end
	self:UpdateSectorData(self.campaignId, self.sectorId, old_value, prop_id)
end

--- Updates the mod item id, map and renames the map folder and the id in mapdata.lua
function ModItemSector:UpdateSectorData(newCampaignId, newSectorId, oldVal, propId)
	local newValue = self[propId]
		
	if self.SatelliteSectorObj then
		self.SatelliteSectorObj.Id = self.sectorId
		self.SatelliteSectorObj.Map = self:GetMapName()
	
		if self.SatelliteSectorObj.Id and self.SatelliteSectorObj.Id:ends_with("_Underground") then
			self.SatelliteSectorObj.GroundSector = self.SatelliteSectorObj.Id:gsub("_Underground", "")
		else
			self.SatelliteSectorObj.GroundSector = false
		end
	end
	
	local mapData
	local fenv = LuaValueEnv{
		DefineMapData = function(data)
			local mapName = self:GetMapName()
			local mapDataPreset = MapData[mapName]
			if mapDataPreset then
				mapDataPreset:delete()
			end
			 mapData = MapDataPreset:new(data)
		end,
	}
	
	if newValue then
		local ok, def = pdofile(self:GetFolderPathOS() .. "mapdata.lua", fenv)
		if ok then
			local newId = self:GetMapName()
			local newModMapPath = self:GetFolderPathOS()
			
			mapData.id = newId
			mapData.ModMapPath = newModMapPath
			mapData.Comment = string.format("Sector %s (%s)", self.sectorId, self.campaignId) -- for MapData editor
			mapData.DisplayName = Untranslated(mapData.Comment) -- for display in the editor's status bar
			self:CleanDevPropsFromMapData(mapData)
			mapData:Register()
			mapData:PostLoad()
			mapData:Save()
		end
	end
	ObjModified(self)
	ObjModified(self.SatelliteSectorObj)
end

function ModItemSector:CleanDevPropsFromMapData(data)
	data.Author = nil
	data.ScriptingAuthor = nil
	data.Status = nil
	data.SoundStatus = nil
	data.ScriptingStatus = nil
	data.SaveEntityList = nil
end

function ModItemSector:IsDuplicateMap(campaignId, sectorId, mod)
	mod = mod or self.mod
	if not campaignId or not sectorId then return false end
	return mod:ForEachModItem("ModItemSector", function(mod_item)
		if mod_item ~= self and mod_item.campaignId == campaignId and mod_item.sectorId == sectorId then
			return string.format("The sector %s for campaign %s already exists in your mod!", sectorId, campaignId)
		end
	end)
end

function ModItemSector:GetAffectedResources()
	if self.campaignId and self.sectorId and self.campaignId == "HotDiamonds" and string.find(self.sectorId, "^[A-Z][0-9]+") then
		local affected_resources = {}
		table.insert(affected_resources, ModResourcePreset:new({
			mod = self.mod,
			Class = self.class,
			Id = string.format("%s_%s", self.campaignId, self.sectorId),
			ClassDisplayName = self.EditorName,
		}))
		
		return affected_resources
	end
	
	return empty_table
end

function ModItemSector:ApplyBiDirectionalLinks()
	if self.SatelliteSectorObj and self.SatelliteSectorObj.bidirectionalRoadApply then
		SatelliteSectorSetDirectionsProp(self.SatelliteSectorObj, "Roads", "session_update_only")
	end
	
	if self.SatelliteSectorObj and self.SatelliteSectorObj.bidirectionalBlockApply then
		SatelliteSectorSetDirectionsProp(self.SatelliteSectorObj, "BlockTravel", "session_update_only")
	end
end

--loading save or starting new game will apply all bidirectional links after the gv_Sectors have been created
function OnMsg.PreLoadSessionData()
	ModsApplyBiDirectionalLinks()
end

function OnMsg.InitSessionCampaignObjects()
	ModsApplyBiDirectionalLinks()
end

--------------------------------------------
-------------Helper functions---------------
--------------------------------------------

function ModsApplyBiDirectionalLinks()
	for _, mod in ipairs(ModsLoaded) do
		mod:ForEachModItem("ModItemSector", function(item)
			item:ApplyBiDirectionalLinks()
		end)
	end
end

function GetCampaignSectorsIds(obj)
	local sectors = GetSatelliteSectors(nil, CampaignPresets[obj.campaignId])
	local sectorIdsCombo = {}
	for _, sector in ipairs(sectors) do
		local id = sector.Id
		local emptyText = sector.generated and "(empty)" or ""
		local noMap = not MapData[sector.Map] and "(no map)" or ""
		table.insert(sectorIdsCombo, { value = id, name = id, combo_text = string.format("%s<right><alpha 156>\t%s %s", id, emptyText, noMap) })
	end
	return sectorIdsCombo
end

function DoesSectorExist(campaignId, sectorId)
	local campaignPreset = campaignId and CampaignPresets[campaignId]
	local foundSector = campaignPreset and table.find_value(campaignPreset.Sectors, "Id", sectorId)
	if foundSector and foundSector.Map and foundSector.Map ~= "" then
		return foundSector.Map
	else
		return false
	end
end

function ValidateSectorId(value, allow_underground)
	local normal_match = string.match(value, "^%u%u?%-?%d%d?$")
	local underground_match = string.match(value, "^%u%u?%-?%d%d?_Underground$")
	return not (normal_match or allow_underground and underground_match) and
		string.format("Sector ID format is incorrect. It needs to follow the pattern:\n'[upper case sector letter][optional upper case sector letter to indicate going into negatives in the grid][optional symbol '-' to indicate going into negatives in the grid][digit][optional digit]%s'",
			allow_underground and "[optional symbols '_Underground']" or "")
end

function ModItemSector:GetFilesList()
	local path = self:GetFolderPathOS()
	local files_list = io.listfiles(path, "*")
	return files_list
end

function ModItemSector:ResolveSectorConflictOnPaste(ged, skip_msg)
	local mod = self.mod
	
	local dup = self:IsDuplicateMap(self.campaignId, self.sectorId, mod)
	local initial_sector = self.sectorId
	if dup then
		local sectorList = GetCampaignSectorsIds(self)
		local association_list = {}
		local trimmed_sectors = {}
		for _, sector_combo in ipairs(sectorList) do
			association_list[sector_combo.combo_text] = sector_combo
			table.insert(trimmed_sectors, sector_combo.combo_text)
		end
		
		if not skip_msg  and CanYield() then
			while dup do
				local confirm_text = dup .. "\n\nDo you want to change the copy to another sector?"
				local response = ged:WaitQuestion("Paste Satellite Sector", confirm_text, "Change sector", "Cancel")
				if response == "cancel" then
					return false
				else
					local new_sector = ged:WaitListChoice(trimmed_sectors, "Pick sector:")
					if new_sector == "cancel" or not new_sector then return false end
					self.sectorId = association_list[new_sector].value
					self.ChangedSectorOnPaste = initial_sector
					dup = self:IsDuplicateMap(self.campaignId, self.sectorId, mod)
				end
			end
		else
			return false
		end
	end
	return true
end

function ModItemSector:ResolvePasteFilesConflicts(ged)
	if not self.CopyFiles then return end
	
	local prev_sector = self.sectorId
	
	-- pick new folder name
	local existing_sectors = {}
	self.mod:ForEachModItem("ModItemSector", function(mod_item)
		existing_sectors[mod_item.mapName] = mod_item
	end)
	while existing_sectors[self.mapName] and existing_sectors[self.mapName] ~= self do
		self:GenerateMapName()
	end
	self:CreateMapFolder()
	
	-- resolve duplicate sector (either user picks valid one, or the paste file data are cleared
	local res = self:ResolveSectorConflictOnPaste(ged, false)
	if not res then
		self.sectorId = false
		self.SatelliteSectorObj = false
		self.CopyFiles = false
		ModLogF(string.format("Satellite Sector <%s> already exists in mod <%s>! Created empty sector, instead.", prev_sector, self.mod.id))
		self.CopyFiles = {}
		return
	end
	
	local firstfilename = self.CopyFiles[1].filename
	local prev_os_path = firstfilename:match("^(" .. self.CopyFiles.mod_content_path .. "Maps/[^/]*/)")
	for _, file in ipairs(self.CopyFiles) do
		file.filename = file.filename:gsub(prev_os_path, self:GetFolderPathOS())
	end
	
	if self.ChangedSectorOnPaste  then
		prev_sector = self.ChangedSectorOnPaste
		self.ChangedSectorOnPaste = nil
	end
	
	return { prev_sector = prev_sector }
end

function ModItemSector:OnAfterPasteFiles(changes_meta)
	local prev_sector = changes_meta and changes_meta.prev_sector or self.sectorId
	self:UpdateSectorData(self.campaignId, self.sectorId, prev_sector, "sectorId")
end