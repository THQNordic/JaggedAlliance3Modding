IsInModTestingMode = empty_func

if not config.Mods then return end

--MODS
function ModDef:GetTags()
	local tags_used = { }
	for i,tag in ipairs(PredefinedModTags) do
		if self[tag.id] then
			table.insert(tags_used, tag.display_name)
		end
	end
	
	return tags_used
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
			QuickStartCampaign(pickedCampaign, {difficulty = "Normal", testModGame = true})
		elseif start_type == "normal" then
			if WaitQuestion(terminal.desktop, Untranslated("New Game"), Untranslated("A new test mod game will be started.\n\nUnsaved mod changes will not be applied. Continue?"), Untranslated("Yes"), Untranslated("No")) ~= "ok" then
				return
			end
			ProtectedModsReloadItems(nil, "force_reload")
			StartCampaign(pickedCampaign, {difficulty = "Normal", testModGame = true})
		end
	end)
end

function CheatSpawnEnemy()
	local p = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local freePoint = DbgFindFreePassPositions(p, 1, 20, xxhash(p))
	if not next(freePoint) then return end
	local unit = SpawnUnit("LegionRaider", tostring(RealTime()), freePoint[1])
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
				if not Platform.developer then
					GedOpHelpMod()
				end
			end
		end
	end)
end

function IsInModTestingMode()
	return IsModEditorMap(CurrentMap) or (Game and Game.testModGame)
end

if not Platform.developer and not Platform.asserts then
	function OnMsg.ChangeMapDone(map)
		ConsoleSetEnabled(IsInModTestingMode())
	end
end

function OpenModEditor(mod)
	for _, presets in pairs(Presets) do
		PopulateParentTableCache(presets)
	end

	local mod_path = ModConvertSlashes(mod:GetModRootPath())
	local context = {
		mod_items = GedItemsMenu("ModItem"),
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
	local editor = OpenGedApp("ModEditor", Container:new{ mod }, context)
	if editor then editor:Send("rfnApp", "SetSelection", "root", { 1 }) end
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
end

DefineModItemPreset("AppearancePreset", { EditorName = "Appearance preset", EditorSubmenu = "Unit" })

AppendClass.ModItemAppearancePreset = {
	properties = {
				{ id = "helpInfo", editor = "help", category = "Mod",
					help = Untranslated([[ <em>To see the different newly exported entities in the dropdowns below you need to add their appropriate class in the entity mod item.</em>
					
					<em>Part  -   Class</em>
					Body  -   CharacterBodyMale/Female
					Head  -   CharacterHeadMale/Female
					Pants -   CharacterPantsMale/Female
					Armor -   CharacterArmorMale/Female
					Chest -   CharacterChestMale/Female
					Hip   -   CharacterHipMale/Female
					Hat   -   CharacterHat/Female
					Hair  -   CharacterHairMale/Female
					]]), },
					},
}

local function UpdateAppearanceOnSpawnedObj(id)
	for _, unit in ipairs(g_Units) do
		if unit.Appearance and unit.Appearance == id then
			unit:ApplyAppearance(id, "force")
		end
	end
end

function ModItemAppearancePreset:TestModItem(ged)
	ModItem.TestModItem(self, ged)
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
	
	EditorName = "Translated Voices",
	EditorSubmenu = "Unit",
	
	properties = {
		{ id = "_", default = false, editor = "help", 
			help = Untranslated([[The <em>Translated Voices</em> mod item allows to supply to the game voices which will be used when the game is running in a specific language. You can use this to add new language voices of the existing voice lines, to override the existing voice lines, or to add entirely new voice content to the game.

1. Voice filenames need to match the localization IDs of the texts they correspond to; you can look up the localization IDs of existing lines in the game localization table (Game.csv) supplied with the mod tools.
2. Voice files should be in Opus format; it is recommended to combine this mod item with an <em>Convert & Import Assets</em> mod item targeting a folder inside your mod folder structure.
3. To supply voices in multiple languages, use one <em>Translated Voices</em> mod item per language.]]), },
		{ id = "language", name = "Language", editor = "dropdownlist", default = "", help = Untranslated("Based on this value, the mod will decide if it should load the voices located in the translation folder."),
			items = GetAllLanguages(), 
		},
		{ id = "translatedVoicesFolder", name = "Translated Voices Folder", editor = "browse", filter = "folder", default = "", help = Untranslated("The folder inside the mod in which the translated voices should be placed. If you use the Convert & Import mod item for creating the files, pick the same path as the one defined there.") },
		{ id = "btn", editor = "buttons", default = false, buttons = {{name = "Force mount folder", func = "TryMountFolder"}}, untranslated = true},

	}, 
}

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
			for _, loadedItem in ipairs(loadedMod.items) do
				if IsKindOf(loadedItem, "ModItemTranslatedVoices") then
					loadedItem:UnmountFolders()
					loadedItem:TryMountFolder()
				end
			end
		end
	end
end

function ModItemTranslatedVoices:GetError()
	if self.language == "" then
		return "Choose a language for the translated voices."
	end
end

function OnMsg.UnableToUnlockAchievementReasons(reasons, achievement)
	if IsInModTestingMode() then
		reasons["in mod testing mode"] = true
	end
end