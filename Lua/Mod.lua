if not config.Mods then return end

--Tags
function ModDef:GetTags()
	local tags_used = { }
	for i,tag in ipairs(PredefinedModTags) do
		if self[tag.id] then
			table.insert(tags_used, tag.display_name)
		end
	end
	
	return tags_used
end

PredefinedModTags = {
    { id = "TagIMPCharacter", display_name = "IMP Character" },
    { id = "TagMercs", display_name = "Mercs" },
    { id = "TagWeapons&Items", display_name = "Weapons & Items" },
    { id = "TagPerks&Talents&Skills", display_name = "Perks, Talents & Skills" },
    { id = "TagMines&Economy", display_name = "Mines & Economy" },
    { id = "TagSatview&Operations", display_name = "Sat view & Operations" },
    { id = "TagBalancing&Difficulty", display_name = "Balancing & Difficulty" },
    { id = "TagCombat&AI", display_name = "Combat & AI" },
    { id = "TagEnemies", display_name = "Enemies" },    
    { id = "TagGameSettings", display_name = "Game Settings" },
    { id = "TagUI", display_name = "UI" },
    { id = "TagVisuals&Graphics", display_name = "Visuals & Graphics" },
    { id = "TagLocalization", display_name = "Localization" },
    { id = "TagMusic&Sound&Voices", display_name = "Music, Sound & Voices" },
    { id = "TagQuest&Campaigns", display_name = "Quest & Campaigns" },
    { id = "TagLibs&ModdingTools", display_name = "Libs & Modding Tools" },
    { id = "TagOther", display_name = "Other" }
}

table.sortby_field(PredefinedModTags, "display_name")

PredefinedModTagsByName = { }
for i,tag in ipairs(PredefinedModTags) do
	PredefinedModTagsByName[tag.display_name] = tag
end

function OnMsg.ClassesGenerate(classdefs)
	local mod = classdefs["ModDef"]
	local properties = mod.properties
	
	for i,tag in ipairs(PredefinedModTags) do
		local prop_meta = { category = "Tags", id = tag.id, name = Untranslated(tag.display_name), editor = "bool", default = false }
		table.insert(properties, prop_meta)
	end
end

--Cheats
function CheatTestExploration()
	CreateRealTimeThread(function() DbgStartExploration() end)
end

function CheatEnable(id, side)
	NetSyncEvent("CheatEnable", id, nil, side)
end

function CheatActivate(id)
	NetSyncEvent(id)
end

function CheatToggleFlyCamera()
	XShortcutsTarget:ActionById("G_CameraChange"):OnAction()
end

function CheatResetMap()
	CreateRealTimeThread(function()
		ResetGameSession()
		ChangeMap(ModEditorMapName)
	end)
end

function CheatAddMerc(id)
	if table.find(g_Units, "session_id", id) then return end
	if not next(GetPlayerMercSquads()) then
		DbgStartExploration(nil, {id})
	else
		local ud = gv_UnitData[id]
		if not ud then -- Non-merc units will not have unit data.
			ud = CreateUnitData(id, id, InteractionRand(nil, "CheatAddMerc"))
		end
		UIAddMercToSquad(id)
		HiredMercArrived(gv_UnitData[id])
	end
end

function GetItemsIds()
	local items = {}
	ForEachPreset("InventoryItemCompositeDef", function(o)
		table.insert(items, o.id)
	end)
	return items
end

function CheatAddItem(id)
	UIPlaceInInventory(nil, InventoryItemDefs[id])
end

function CheatIsolatedScreenshot()
	IsolatedObjectScreenshot()
end

function CheatNewModGame(start_type)
	CreateRealTimeThread(function()
		local campaignPresets = {}
		for _, preset in pairs(CampaignPresets) do
			table.insert(campaignPresets, preset.id)
		end
		local pickedCampaign = WaitListChoice(nil, campaignPresets, "Select campaign", 1)
		if not pickedCampaign then return end
	
		if start_type == "quickstart" then
			if WaitQuestion(terminal.desktop, Untranslated("Quick Start"), Untranslated("A new quick test mod game will be started. It will skip the merc hire & arrival phase.\n\nUnsaved mod changes will not be applied. Continue?"), Untranslated("Yes"), Untranslated("No")) ~= "ok" then
				return
			end
			ProtectedModsReloadItems(nil, "force_reload")
			QuickStartCampaign(pickedCampaign, {difficulty = "Normal"})
		elseif start_type == "normal" then
			if WaitQuestion(terminal.desktop, Untranslated("New Game"), Untranslated("A new test mod game will be started.\n\nUnsaved mod changes will not be applied. Continue?"), Untranslated("Yes"), Untranslated("No")) ~= "ok" then
				return
			end
			ProtectedModsReloadItems(nil, "force_reload")
			StartCampaign(pickedCampaign, {difficulty = "Normal"})
		end
	end)
end

function CheatSpawnEnemy(id)
	local p = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local freePoint = DbgFindFreePassPositions(p, 1, 20, xxhash(p))
	if not next(freePoint) then return end
	local unit = SpawnUnit(id or "LegionRaider", tostring(RealTime()), freePoint[1])
	unit:SetSide("enemy1")
end

--override open editor func to pass zulu related cheats info into the context
function ModEditorOpen(mod)
	CreateRealTimeThread(function()
		if not IsModEditorMap(CurrentMap) then
			ChangeMap(ModEditorMapName)
			CloseMenuDialogs()
		end
		if mod then
			OpenModEditor(mod)
		else
			local context = {
				dlcs = g_AvailableDlc or { },
				mercs = GetGroupedMercsForCheats(nil, nil, true),
				items = GetItemsIds(),
			}
			local ged = OpenGedApp("ModManager", ModsList, context)
			if ged then ged:BindObj("log", ModMessageLog) end
			if LocalStorage.OpenModdingDocs == nil or LocalStorage.OpenModdingDocs then
				if Platform.goldmaster then
					GedOpHelpMod()
				end
			end
		end
	end)
end

if not Platform.developer and not Platform.asserts then
	function OnMsg.ChangeMapDone(map)
		ConsoleSetEnabled(AreModdingToolsActive())
	end
end

function OpenModEditor(mod)
	local editor = GedConnections[mod.mod_ged_id]
	if editor then
		local activated = editor:Call("rfnApp", "Activate")
		if activated ~= "disconnected" then
			return editor
		end
	end
	
	for _, presets in pairs(Presets) do
		PopulateParentTableCache(presets)
	end
	
	local mod_path = ModConvertSlashes(mod:GetModRootPath())
	local mod_folder_supported = g_Classes.ModItemFolder and true or false
	local mod_items = GedItemsMenu("ModItem")
	
	--exception for ModItemMapPatch, as it is not a leaf node because of ModItemSetpiecePrg
	local modItemMapPatchClass = g_Classes.ModItemMapPatch
	if modItemMapPatchClass then
		table.insert_unique(mod_items, {
			Class = "ModItemMapPatch",
			EditorName = modItemMapPatchClass:HasMember("EditorName") and GedTranslate(modItemMapPatchClass.EditorName, modItemMapPatchClass, false) or "ModItemMapPatch",
			EditorIcon = rawget(modItemMapPatchClass, "EditorIcon"),
			EditorShortcut = rawget(modItemMapPatchClass, "EditorShortcut"),
			EditorSubmenu = rawget(modItemMapPatchClass, "EditorSubmenu"),
			ScriptDomain = rawget(modItemMapPatchClass, "ScriptDomain"), 
		})
	end
	
	local context = {
		mod_items = mod_items,
		mod_folder_supported = mod_folder_supported,
		dlcs = g_AvailableDlc or { },
		mod_path = mod_path,
		mod_os_path = ConvertToOSPath(mod_path),
		mod_content_path = mod:GetModContentPath(),
		WarningsUpdateRoot = "root",
		suppress_property_buttons = {
			"GedOpPresetIdNewInstance",
			"GedRpcEditPreset",
			"OpenTagsEditor",
		},
		mercs = GetGroupedMercsForCheats(nil, nil, true),
		items = GetItemsIds(),
	}
	Msg("GatherModEditorLogins", context)
	local container = Container:new{ mod }
	UpdateParentTable(mod, container)
	local editor = OpenGedApp("ModEditor", container, context)
	if editor then 
		editor:Send("rfnApp", "SetSelection", "root", { 1 })
		editor:Send("rfnApp", "SetTitle", string.format("Mod Editor - %s", mod.title))
	end
	return editor
end

--MODS UI
function ModsUIClosePopup(win)
	local dlg = GetDialog(win)
	local obj = dlg.context
	obj.popup_shown = false
	local wnd = dlg:ResolveId("idPopUp")
	if wnd and wnd.window_state ~= "destroying" then
		wnd:Close()
	end
	dlg:UpdateActionViews(dlg)
	if GetDialog("PreGameMenu") then
		CreateRealTimeThread(function()
			LoadingScreenOpen("idLoadingScreen", "main menu")
			OpenPreGameMainMenu("")
			LoadingScreenClose("idLoadingScreen", "main menu")
		end)
	end
end

--Undefine moditem classes not used in Zulu
function OnMsg.ClassesPreprocess(classdefs)
	UndefineClass('ModItemShelterSlabMaterials')
	UndefineClass('ModItemStoryBit')
	UndefineClass('ModItemStoryBitCategory')
	UndefineClass('ModItemActionFXColorization')
	UndefineClass("ModItemGameValue")
	UndefineClass("ModItemCompositeBodyPreset")
end

DefineModItemPreset("AppearancePreset", { 
	EditorName = "Appearance preset", 
	EditorSubmenu = "Unit", 
	TestDescription = "Updates the appearance of the object if already spawned.", 
	Documentation = "This mod item allows to change the appearance of existing units in the game and create new appearances for custom units.",
	DocumentationLink = "Docs/ModItemAppearancePreset.md.html"
})

local function UpdateAppearanceOnSpawnedObj(id)
	for _, unit in ipairs(g_Units) do
		if unit.Appearance and unit.Appearance == id then
			unit:ApplyAppearance(id, "force")
		end
	end
end

function ModItemAppearancePreset:TestModItem(ged)
	UpdateAppearanceOnSpawnedObj(self.id)
end

function ModItemAppearancePreset:OnEditorSetProperty(prop_id, old_value, ged)
	ModItemPreset.OnEditorSetProperty(self, prop_id, old_value, ged)
	UpdateAppearanceOnSpawnedObj(self.id)
end

function ApplyModOptions(modsOptions)
	CreateRealTimeThread(function(modsOptions)
		for _, modOptions in ipairs(modsOptions) do
			local mod = modOptions.__mod
			AccountStorage.ModOptions = AccountStorage.ModOptions or { }
			local storage_table = AccountStorage.ModOptions[mod.id] or { }
			for _, prop in ipairs(modOptions:GetProperties()) do
				local value = modOptions:GetProperty(prop.id)
				value = type(value) == "table" and table.copy(value) or value
				storage_table[prop.id] = value
			end
			AccountStorage.ModOptions[mod.id] = storage_table
			rawset(mod.env, "CurrentModOptions", modOptions)
			Msg("ApplyModOptions", mod.id)
		end
		SaveAccountStorage(1000)
	end, modsOptions)
end

function ModItemOption:GetOptionMeta()
	local display_name = self.DisplayName
	if not display_name or display_name == "" then
		display_name = self.name
	end
	
	return {
		id = self.name,
		name = T(display_name),
		editor = self.ValueEditor,
		default = self.DefaultValue,
		help = Untranslated(self.Help),
		modId = self.mod.id,
	}
end

DefineClass.ModItemTranslatedVoices =  {
	__parents = { "ModItem" },
	
	EditorName = "Translated voices",
	EditorSubmenu = "Unit",
	
	properties = {
		{ id = "_", default = false, editor = "help", 
			help = [[The <style GedHighlight>Translated Voices</style> mod item allows to supply to the game voices which will be used when the game is running in a specific language. You can use this to add new language voices of the existing voice lines, to override the existing voice lines, or to add entirely new voice content to the game.

1. Voice filenames need to match the localization IDs of the texts they correspond to; you can look up the localization IDs of existing lines in the game localization table (Game.csv) supplied with the mod tools.
2. Voice files should be in Opus format; it is recommended to combine this mod item with an <style GedHighlight>Convert & Import Assets</style> mod item targeting a folder inside your mod folder structure.
3. To supply voices in multiple languages, use one <style GedHighlight>Translated Voices</style> mod item per language.]], },
		{ id = "language", name = "Language", editor = "dropdownlist", default = "", help = "Based on this value, the mod will decide if it should load the voices located in the translation folder.",
			items = GetAllLanguages(), 
		},
		{ id = "translatedVoicesFolder", name = "Translated Voices Folder", editor = "browse", filter = "folder", default = "", help = "The folder inside the mod in which the translated voices should be placed. If you use the Convert & Import mod item for creating the files, pick the same path as the one defined there." },
		{ id = "btn", editor = "buttons", default = false, buttons = {{name = "Force mount folder", func = "TryMountFolder"}}, untranslated = true},

	}, 
}

function ModItemTranslatedVoices:OnEditorNew(parent, ged, is_paste)
	self.name = "TranslatedVoices"
end

function ModItemTranslatedVoices:GetMountLabel()
	return self.mod.id .. "/" .. self.language
end

function ModItemTranslatedVoices:TryMountFolder()
	if self.translatedVoicesFolder ~= "" and (GetLanguage() == self.language or self.language == "Any") then
		local err = MountFolder("CurrentLanguage/Voices", self.translatedVoicesFolder, "seethrough,label:" .. self:GetMountLabel())
		if err then
			ModLogF(true, "Failed to mount translated voice folder '%s': %s", self.translatedVoicesFolder, err)
		end
	end
end

function ModItemTranslatedVoices:UnmountFolders()
	UnmountByLabel(self:GetMountLabel())
end

function ModItemTranslatedVoices:OnModLoad()
	ModItem.OnModLoad(self)
	self:TryMountFolder()
end

function ModItemTranslatedVoices:OnModUnload()
	self:UnmountFolders()
	
	ModItem.OnModUnload(self)
end

function OnMsg.TranslationChanged()
	for _, loadedMod in ipairs(ModsLoaded) do
		if loadedMod:ItemsLoaded() then
			loadedMod:ForEachModItem("ModItemTranslatedVoices", function(loadedItem)
				if loadedItem.mod then
					loadedItem:UnmountFolders()
					loadedItem:TryMountFolder()
				end
			end)
		end
	end
end

function ModItemTranslatedVoices:GetError()
	if self.language == "" then
		return "Choose a language for the translated voices."
	end
end

function OnMsg.UnableToUnlockAchievementReasons(reasons, achievement)
	if AreModdingToolsActive() then
		reasons["modding tools active"] = true
	end
end

-- Mods Presets (UI)
-- A preset contains a list of mod id's with the idea to easily 
-- enable a specific set of mods.

function InitModPresets()
	local firstTimeDefaultPreset = not LocalStorage.ModPresets
	LocalStorage.ModPresets = LocalStorage.ModPresets or { 
		{id = "default", mod_ids = {}}, 
		{id = "create new preset", mod_ids = {}, input_field = true}, 
	}
	if firstTimeDefaultPreset then
		FirstLoadOfDefaultPreset()
	end
	SaveLocalStorageDelayed()
end

function FirstLoadOfDefaultPreset()
	for _, modDef in ipairs(ModsLoaded) do
		AddModToModPreset("Default", modDef.id)
	end
	
	SortModPresets()
	SelectModPreset("default", "firstime")
end

function CreateModPreset(preset_id)
	preset_id = string.lower(preset_id)
	if table.find(LocalStorage.ModPresets, "id", preset_id) then
		return false, T{846096667197, "A mod preset with the name <em><u(name)></em> already exists.", name = preset_id}
	end
	
	table.insert(LocalStorage.ModPresets, { id = preset_id, mod_ids = {}, timestamp = os.time() })
	SortModPresets()
	SaveLocalStorageDelayed()
	return true
end

function DeleteModPreset(preset_id)
	preset_id = string.lower(preset_id)
	local presetDataIdx = table.find(LocalStorage.ModPresets, "id", preset_id)
	if not presetDataIdx then return end
	
	table.remove(LocalStorage.ModPresets, presetDataIdx)
	SaveLocalStorageDelayed()
end

function AddModToModPreset(preset_id, mod_id)
	preset_id = string.lower(preset_id)
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if not presetData then return end
	
	table.insert(presetData.mod_ids, mod_id)
	SaveLocalStorageDelayed()
end

function RemoveModFromModPreset(preset_id, mod_id)
	preset_id = string.lower(preset_id)
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if not presetData then return end
	
	local modIdx = table.find(presetData.mod_ids, mod_id)
	if not modIdx then return end
	
	table.remove(presetData.mod_ids,modIdx)
	SaveLocalStorageDelayed()
end

function SelectModPreset(preset_id, firstTime)
	preset_id = string.lower(preset_id) 
	AllModsOff()
	
	--clear tags when selecting preset
	ModsUIClearFilter("temp_installed_tags")
	ModsUISetInstalledTags()
	if g_ModsUIContextObj then
		g_ModsUIContextObj:GetInstalledMods()
	end
	ObjModified(PredefinedModTags)
	
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if not presetData then return end
	
	for _, mod_id in ipairs(presetData.mod_ids) do
		if Mods[mod_id] and not ModIdBlacklist[mod_id] then
			TurnModOn(mod_id)
		end
	end
	LocalStorage.LastSelectedModPreset = preset_id
	SaveLocalStorageDelayed()
	if not firstTime then g_CantLoadMods = {} end
	CreateRealTimeThread(WaitErrorLoadingMods, T(907697247489, "The following mods from the preset couldn't be loaded and have been disabled:\n"))
end

function SortModPresets()
	if next(LocalStorage.ModPresets) then
		table.sort(LocalStorage.ModPresets, function(a, b) 
			local specialFieldA = a.input_field or not a.timestamp
			local specialFieldB = b.input_field or not b.timestamp
			if specialFieldA and specialFieldB then
				return string.lower(a.id) < string.lower(b.id)
			elseif not specialFieldA and not specialFieldB then
				return a.timestamp > b.timestamp
			end
			if specialFieldA then return true end
			if specialFieldB then return false end
		end)
	end
	SaveLocalStorageDelayed()
end

function GetModPresetName(preset_id)
	preset_id = string.lower(preset_id)
	local presetData = table.find_value(LocalStorage.ModPresets, "id", preset_id)
	if presetData then
		if presetData.id == "default" then
			return T(366064427094, "Default")
		elseif presetData.id == "create new preset" then
			return T(804320297184, "Create New Preset")
		else
			return Untranslated(presetData.id)
		end
	end
end

function TurnModOn(id, updatePreset)
	table.insert_unique(AccountStorage.LoadMods, id)
	if updatePreset then
		AddModToModPreset(LocalStorage.LastSelectedModPreset, id)
	end
end

function TurnModOff(id, updatePreset)
	table.remove_entry(AccountStorage.LoadMods, id)
	if updatePreset then
		RemoveModFromModPreset(LocalStorage.LastSelectedModPreset, id)
	end
end

OnMsg.ModsUIDialogStarted = InitModPresets

function AreAllTagsEnabled()
	if not g_ModsUIContextObj then return false end
	local predifinedCount = PredefinedModTags and #PredefinedModTags or 0
	local enabledCount = 0
	if g_ModsUIContextObj and next(g_ModsUIContextObj.temp_installed_tags) then
		enabledCount = #table.keys(g_ModsUIContextObj.temp_installed_tags)
	end
	return predifinedCount == enabledCount
end

DefineModItemPreset("CampaignPreset", { EditorName = "Campaign", EditorSubmenu = "Campaign & Maps", TestDescription = "Starts the created campaign." })
DefineModItemPreset("QuestsDef", { EditorName = "Quest", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("Conversation", { EditorName = "Conversation", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("Email", { EditorName = "Email", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("HistoryOccurence", { EditorName = "History occurrence", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("TutorialHint", { EditorName = "Tutorial hint", EditorSubmenu = "Campaign & Maps" })
DefineModItemPreset("EnvironmentColorPalette", { EditorSubmenu = "Campaign & Maps", EditorName = "Environment Palette" })

function ModItemCampaignPreset:TestModItem()
	CreateRealTimeThread(function(self)
		ProtectedModsReloadItems(nil, "force_reload")
		QuickStartCampaign(self.id, {difficulty = "Normal"})
	end, self)
end

function ModItemQuestsDef:GetEditorView()
	return T{506003151811, "<mod_text> <original_text>", mod_text = Untranslated("<color 128 128 128>" .. self.EditorName .. "</color>"), original_text = QuestsDef.GetEditorView(self)}
end

function ModItem:OnEditorNew(parent, ged, is_paste, duplicate_id, mod_id)
	-- Mod item presets can also be added through Preset Editors (see GedOpClonePresetInMod)
	-- In those cases the reference to the mod will be set from the mod_id parameter

	self.mod = (IsKindOf(parent, "ModDef") and parent or parent.mod) or (mod_id and Mods and Mods[mod_id])
	assert(self.mod, "Mod item has no reference to a mod")

	if not is_paste and self.campaign then
		local lastCampaign
		self.mod:ForEachModItem("ModItemCampaignPreset", function(modItem)
			lastCampaign = modItem.id
		end)
		if lastCampaign then
			self.campaign = lastCampaign
		end
	end
end

OnMsg.ModsReloaded = RebuildGroupToConversation
OnMsg.NewGame = RebuildGroupToConversation

function OnMsg.ModsReloaded()
	for _, mod_def in ipairs(ModsLoaded) do
		if mod_def.saved_with_revision < 348693 then -- A random revision from the day this fixup was written.
			local property_to_scale = {
				vignette_circularity = 100.0,
				vignette_darken_feather = 1000.0,
				vignette_darken_start = 1000.0,
				vignette_tint_feather = 1000.0,
				vignette_tint_start = 1000.0,
				chromatic_aberration_circularity = 100.0,
				chromatic_aberration_feather = 1000.0,
				chromatic_aberration_start = 1000.0,
				chromatic_aberration_intensity = 1000.0,
				translucency_scale = 1000.0,
				translucency_distort_sun_dir = 1000.0,
				translucency_sun_falloff = 1000.0,
				translucency_sun_scale = 1000.0,
				translucency_ambient_scale = 1000.0,
				translucency_base_luminance = 1000.0,
				translucency_base_k = 1.0,
				translucency_reduce_k = 1.0,
				translucency_desaturation = 1000.0,
			}
			mod_def:ForEachModItem("ModItemLightmodelPreset", function(item)
				for prop_id, scale in pairs(property_to_scale) do
					if rawget(item, prop_id) then
						item[prop_id] = item[prop_id] / scale
					end
				end
				if rawget(item, "vignette_darken_opacity") then
					item.vignette_darken_opacity = MulDivRound(item.vignette_darken_opacity, 1000, 255) / 1000.0
				end
			end)
		end
	end
end


---- Map Editor

-- add custom button to open map editor documentation (uses Zulu-specific parameter of CreateMessageBox)
function XEditor:ShowHelpText()
	self.help_popup = CreateMessageBox(XShortcutsTarget,
		Untranslated("Welcome to the Map Editor!"),
		Untranslated([[Here are some short tips to get you started.

Camera controls:
  • <mouse_wheel_up> - zoom in/out
  • hold <middle_click> - pan the camera
  • hold Ctrl - faster movement
  • hold Alt - look around
  • hold Ctrl+Alt - rotate camera

Look through the editor tools on the left - for example, press N to place objects.

Use <right_click> to access object properties and actions.

Read More opens detailed game-specific help.]]),
		Untranslated("OK"),
		nil, -- context obj
		XAction:new({
			ActionId = "idReadMore",
			ActionTranslate = false,
			ActionName = "Read More",
			ActionToolbar = "ActionBar",
			OnAction = function(self, host)
				GedOpHelpMod(nil, nil, "MapEditor.md.html")
				host:Close()
			end,
		})
	)
end

-- override editor.StartModdingEditor to close some game-specific UIs
old_StartModdingEditor = editor.StartModdingEditor

function editor.StartModdingEditor(mod_item, map)
	CloseGedSatelliteSectorEditor()
	CloseSatelliteView(true)
	CloseDialog("ModifyWeaponDlg", true)
	Sleep(1000)
	old_StartModdingEditor(mod_item, map)
end

-- override to check for mod maps
function MountMap(map, folder)
	folder = folder or GetMapFolder(map)
	if not IsFSUnpacked() and not MapData[map].ModMapPath then
		local map_pack = MapPackfile[map] or string.format("Packs/Maps/%s.hpk", map)
		local err = AsyncMountPack(folder, map_pack, "seethrough")
		assert(not err, "Map data is missing!")
		if err then return err end
	elseif not io.exists(folder) then
		assert(false, "Map folder is missing!")
		return "Path Not Found"
	end
end

AppendClass.Lightmodel = {
	properties = {
		{ id = "ice_color", editor = false, default = RGB(255, 255, 255) },
		{ id = "ice_strength", default = 0, editor = false },
		{ id = "snow_color", editor = false, default = RGB(167, 167, 167) },
		{ id = "snow_dir_x", 	editor = false, default = 0 },
		{ id = "snow_dir_y", 	editor = false, default = 0 },
		{ id = "snow_dir_z", 	editor = false, default = 1000 },
		{ id = "snow_str",	editor = false, default = 0 },
		{ id = "snow_enable", editor = false, default = false, },
	},
}