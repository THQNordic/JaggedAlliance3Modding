local UpdateMsgTexts = {
	T(209497890803, "Game Updates"),
	T(755702963235, "Update History"),
	T(782866768194, "Update 1.1"), 
	T(563627360945, "Update 1.2"),
	T{980686444193, "Update <version>",version =Untranslated("1.1")},
	T(993430988583, "Includes the first stage of our modding support and some popularly requested features like Active pause and Photo mode. Introduces many gameplay tweaks and fixes to mechanics, quests and content."),
	T(270598651394, "Update 1.2 - Codename: Buns"),
	T{306805636908, "Update <version> - Codename: <codename>", version = Untranslated("1.2"), codename = T(545478640038, "Buns")},
	T(326658534616, "Update 1.2 focuses on the polish and quality of life changes related to the combat aspect of the game. It offers additional information in the UI, improves the bullet simulation and provides the option to play through massive combats at a faster pace."),
	T(752531448999, "Warning! You have active mods which may not work with this new update. We recommend disabling mods that have not been updated after the release of the patch by their authors."),
	T(492869850365, "Disable Mods"),
	T(407892869347, "Patch Notes"),
	T(188889149017, "Updates"),
}

g_UpdateNotes = {
	["default"]   = "https://steamcommunity.com/app/1084160/allnews/",
	["Update1_1"] = "https://store.steampowered.com/news/app/1084160/?emclan=103582791470748569&emgid=3645154111876890482",
	["Update1_2"] = false,
}

function OnMsg.PreGameMenuOpen()
	OpenGameUpdatesPopup()
end

function OpenGameUpdatesPopup(atHint, force)
	if Platform.console then
		return 
	end
	local first = Presets.GameUpdate.Default[1].id
	if not force and AccountStorage.GameUpdatesPopupVer and AccountStorage.GameUpdatesPopupVer == first then
		return
	end	
	AccountStorage.GameUpdatesPopupVer = first
	AccountStorage.GameUpdatesReadState = AccountStorage.GameUpdatesReadState or {}
	for id, hint in pairs(GameUpdates) do
		if hint.open_as_read and not AccountStorage.GameUpdatesReadState[id] then		
			AccountStorage.GameUpdatesReadState[id] = true
		end	
	end
	SaveAccountStorage(5000)

	atHint = atHint or first
	local parent = false
	local pda = GetDialog("PDADialog")
	if pda then
		parent = pda.idDisplayPopupHost
	end
	local popupUI = XTemplateSpawn("GameUpdatesPopup", parent, GetGameUpdateTexts())
	popupUI:Open()
	popupUI.idTitle:SetText(T(209497890803, "Game Updates"))
	popupUI.idHintChoices:SetVisible(true)
	popupUI.idPopupTitle:SetText(T(755702963235, "Update History"))
	popupUI:SetSelectedHint(atHint)
end

function GetGameUpdateTexts()
	return Presets.GameUpdate.Default	
end

function IsGameUpdateMsgRead(context)
	local hintId = context.id
	local state = AccountStorage.GameUpdatesReadState
	local read = state and state[context.id]
	return read
end

