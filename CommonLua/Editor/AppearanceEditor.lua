DefineClass.CharacterEntity =
{
	__parents = {"CObject"},
	flags = {gofRealTimeAnim = true},
}

DefineClass.CharacterBody = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterBodyMale = { __parents = {"CharacterBody"} }
	DefineClass.CharacterBodyFemale = { __parents = {"CharacterBody"} }
DefineClass.CharacterHead = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterHeadMale = { __parents = {"CharacterHead"} }
	DefineClass.CharacterHeadFemale = { __parents = {"CharacterHead"} }
DefineClass.CharacterPants = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterPantsMale = { __parents = {"CharacterPants"} }
	DefineClass.CharacterPantsFemale = { __parents = {"CharacterPants"} }
DefineClass.CharacterShirts = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterShirtsMale = { __parents = {"CharacterShirts"} }
	DefineClass.CharacterShirtsFemale = { __parents = {"CharacterShirts"} }
DefineClass.CharacterArmor = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterArmorMale = { __parents = {"CharacterArmor"} }
	DefineClass.CharacterArmorFemale = { __parents = {"CharacterArmor"} }
DefineClass.CharacterHair = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterHairMale = { __parents = {"CharacterHair"} }
	DefineClass.CharacterHairFemale = { __parents = {"CharacterHair"} }
DefineClass.CharacterHat = { __parents = {"CharacterEntity"} }
DefineClass.CharacterChest = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterChestMale = { __parents = {"CharacterChest"} }
	DefineClass.CharacterChestFemale = { __parents = {"CharacterChest"} }
DefineClass.CharacterHip = { __parents = {"CharacterEntity"} }
	DefineClass.CharacterHipMale = { __parents = {"CharacterHip"} }
	DefineClass.CharacterHipFemale = { __parents = {"CharacterHip"} }

local function GetGender(appearance)
	return IsKindOf(g_Classes[appearance.Body], "CharacterBodyMale") and "Male" or "Female"
end

local function GetEntityClassInherits(entity_class, skip_none, filter)
	local inherits = ClassLeafDescendantsList(entity_class, function(class)
		return not table.find(filter, class)
	end)
	
	if not skip_none then
		table.insert(inherits, 1, "")
	end
	
	return inherits
end

function GetCharacterBodyComboItems()
	return GetEntityClassInherits("CharacterBody", "skip none", {"CharacterBodyMale", "CharacterBodyFemale"})
end

function GetCharacterHeadComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterHead" .. GetGender(appearance)) or {}
end

function GetCharacterPantsComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterPants" .. GetGender(appearance)) or {}
end

function GetCharacterShirtComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterShirts" .. GetGender(appearance)) or {}
end

function GetCharacterArmorComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterArmor" .. GetGender(appearance)) or {}
end

function GetCharacterHairComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterHair" .. GetGender(appearance)) or {}
end

function GetCharacterHatComboItems()
	return GetEntityClassInherits("CharacterHat")
end

function GetCharacterChestComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterChest" .. GetGender(appearance)) or {}
end

function GetCharacterHipComboItems(appearance)
	return IsKindOf(appearance, "AppearancePreset") and GetEntityClassInherits("CharacterHip" .. GetGender(appearance)) or {}
end

if FirstLoad then
	AppearanceEditor = false
end

function OpenAppearanceEditor(appearance)
	CreateRealTimeThread(function(appearance)
		if not AppearanceEditor or not IsValid(AppearanceEditor) then
			AppearanceEditor = OpenPresetEditor("AppearancePreset") or false
		end
	end, appearance)
end

function OnMsg.GedOpened(ged_id)
	local gedApp = GedConnections[ged_id]
	if gedApp and gedApp.app_template == "PresetEditor" and gedApp.context and gedApp.context.PresetClass == "AppearancePreset" then
		AppearanceEditor = gedApp
	end
end

function OnMsg.GedClosing(ged_id)
	if AppearanceEditor and AppearanceEditor.ged_id == ged_id then
		if cameraMax.IsActive() then
			cameraTac.Activate(1)
		end
		AppearanceEditor = false
	end	
end

function CloseAppearanceEditor()
	if AppearanceEditor then
		AppearanceEditor:Send("rfnApp", "Exit")
	end
end

local function UpdateAnimationMomentsEditor(appearance)
	local character = GetAnimationMomentsEditorObject()
	if character then
		local speed = character.anim_speed
		local frame = character.Frame
		character:ApplyAppearance(appearance)
		if speed == 0 then
			character:SetFrame(frame)
		end
	end
end

function OnMsg.GedPropertyEdited(ged_id, object, prop_id, old_value)
	if AppearanceEditor and AppearanceEditor.ged_id == ged_id then
		UpdateAnimationMomentsEditor(AppearanceEditor.selected_object.id)
	elseif AreModdingToolsActive() and g_Classes.ModItemAppearancePreset and IsKindOf(object, "ModItemAppearancePreset") then
		UpdateAnimationMomentsEditor(object.id)
	end
end

function OnMsg.GedOnEditorSelect(appearance, selected, ged)
	if selected and AppearanceEditor and AppearanceEditor.ged_id == ged.ged_id then
		UpdateAnimationMomentsEditor(appearance.id)
	end
end

OnMsg.ChangeMapDone = CloseAppearanceEditor

function RefreshApperanceToAllUnits(root, obj, context)
	local appearance = obj.id
	MapForEach("map", "AppearanceObject", function(obj)
		if obj.Appearance == appearance then
			obj:ApplyAppearance(appearance, "force")
		end
	end)
end

DefineClass.AppearanceWeight =
{
	__parents = {"PropertyObject"},
	
	properties =
	{
		{id = "Preset", name = "Preset", editor = "combo", items = PresetsCombo("AppearancePreset"), default = "" },
		{id = "Weight", name = "Weight", editor = "number", default = 1 },
		{id = "ViewInAppearanceEditorBtn", editor = "buttons", buttons = {{name = "View in Appearance Editor", func = "ViewInAppearanceEditor"}}, dont_save = true},
		{id = "ViewInAnimMetadataEditorBtn", editor = "buttons", buttons = {{name = "View in Anim Metadata Editor", func = "ViewInAnimMetadataEditor"}}, dont_save = true},		
		{id = "GameStates", name = "Game States Required",
			editor = "set", three_state = true, default = set(),
			items = function() return GetGameStateFilter() end,
			help = "Map states requirements for the Preset to be choosen.",
		},
	},
	EditorView = Untranslated("AppearanceWeight <u(Preset)> : <Weight>")
}

function AppearanceWeight:ViewInAppearanceEditor(prop_id, ged)
	local appearance = self.Preset
	local preset = AppearancePresets[appearance] or EntitySpecPresets[appearance]
	if preset then
		preset:OpenEditor()
	end
end

function AppearanceWeight:ViewInAnimMetadataEditor(prop_id, ged)
	OpenAnimationMomentsEditor(self.Preset)
end
