local lUIViewModes = {
	{
		value = "Always",
		text = T(296490837983, "Always")
	},
	{
		value = "Combat",
		text = T(124570697841, "Combat Only")
	}
}

local Difficulties = {
	{
		value = "Normal",
		text = T(389262521478, "First Blood")
	},
	{
		value = "Hard",
		text = T(285690646012, "Commando")
	},
	{
		value = "VeryHard",
		text = T(120945667693, "Mission Impossible")
	},
}

local lInteractableHighlightMode = {
	{
		value = "Toggle",
		text = T(252778189879, "Toggle")
	},
	{
		value = "Hold",
		text = T(645245601207, "Hold")
	}
}

local lAspectRatioItems = 
{
	{value = 1, text = T(601695937982, "None"), real_value = -1}, 
	{value = 2, text = T(375403058307, "16:9"), real_value = 16./9.}, 
	{value = 3, text = T(830202883779, "21:9"), real_value = 21./9.}
}

local game_properties = {
	{ category = "Controls", id = "InvertRotation",           name = T(210910950476, "Invert Camera Rotation"),         editor = "bool",   default = false,     storage = "account", help = T(557409301877, "Inverts the camera rotation.") },
	{ category = "Controls", id = "InvertLook",               name = T(175826014125, "Invert Camera Rotation (Y axis)"),editor = "bool",   default = false,     storage = "account", no_edit = not Platform.trailer, },
	{ category = "Controls", id = "FreeCamRotationSpeed",     name = T(939095110164, "Controller Rotation Speed"),      editor = "number", default = 2000,      storage = "account", min = 100, max = 4000, step = 5, no_edit = not Platform.trailer, },
	{ category = "Controls", id = "FreeCamPanSpeed",          name = T(188537213687, "Controller Pan Speed"),           editor = "number", default = 1000,      storage = "account", min = 50, max = 2000, step = 5, no_edit = not Platform.trailer, },
	
	{ category = "Controls", id = "MouseScrollOutsideWindow", name = T(3587, "Panning outside window"),                 editor = "bool",   default = false,     storage = "account", help = T(787712595891, "Allows camera pan when the mouse cursor is outside the game window.") },
	{ category = "Controls", id = "LeftClickMoveExploration", name = T(988837649188, "Left-Click Move (Exploration)"),  editor = "bool",   default = false,     storage = "account", no_edit = function() return not terminal.IsMouseEnabled() end, help = T(344343486722, "Use left-click to move mercs while exploring a sector out of combat.") },
	{ category = "Controls", id = "ShowGamepadHints",         name = T(731273807036, "Control Hints"),                                editor = "bool",   default = true,      storage = "account", help = T(696057050384, "Shows control hints while in exploration and in combat.")},
	{ category = "Gameplay", id = "Difficulty",               name = T(944075953376, "Difficulty"),                     editor = "choice", default = "Normal",  storage = "local", SortKey = -1900, items = Difficulties, read_only = function() return netInGame and not NetIsHost() end , help = T(146186342821, "Changing the difficulty level of the game affects loot drops, financial rewards, and enemy toughness.<newline><newline><flavor>You can change the difficulty of the game at any time during gameplay.</flavor>") },
	{ category = "Gameplay", id = "AnalyticsEnabled",         name = T(989416075981, "Analytics Enabled"),              editor = "bool",   default = "Off",     storage = "account", SortKey = 5000, on_value = "On", off_value = "Off", help = T(700491171054, "Enables or disables tracking anonymous usage data for analytics.") },
	{ category = "Gameplay", id = "HideActionBar",            name = T(805746173830, "Hide Action Bar (Exploration)"),  editor = "bool",   default = true,      storage = "account", help = T(915209994351, "Hides the action bar UI while not in combat.")},
	{ category = "Gameplay", id = "ActionCamera",             name = T(227204678948, "Targeting Action Camera"),        editor = "bool",   default = false,     storage = "account", help = T(819569684768, "A special cinematic camera view will be used while aiming an attack.\n\nThe action camera is always used with long-range weapons like sniper rifles.")},
	{ category = "Gameplay", id = "PauseOperationStart",      name = T(195176176002, "Auto-pause: Operation Start"),    editor = "bool",   default = false,     storage = "account", SortKey = 1200, help = T(783599794850, "Pause time in SatView mode whenever an Operation is started and the Operations menu is closed.") },
	{ category = "Gameplay", id = "PauseActivityDone",        name = T(219275271774, "Auto-pause: Operation Done"),     editor = "bool",   default = true,      storage = "account", SortKey = 1200, help = T(861937087426, "Pause time in SatView mode whenever an Operation is completed.") },
	{ category = "Gameplay", id = "AutoPauseDestReached",     name = T(220585419104, "Auto-pause: Sector Reached"),     editor = "bool",   default = true,      storage = "account", SortKey = 1000, help = T(679389220889, "Pause time in SatView mode whenever a squad reaches its destination sector.") },
	{ category = "Gameplay", id = "AutoPauseConflict",        name = T(292439424575, "Auto-pause: Sector Conflict"),    editor = "bool",   default = true,      storage = "account", SortKey = 1100, help = T(271690416933, "Pause time in SatView mode whenever a squad is in conflict.") },
	{ category = "Gameplay", id = "PauseSquadMovement",       name = T(700874998799, "Auto-pause: Squad Movement"),     editor = "bool",   default = false,     storage = "account", SortKey = 1100, help = T(269721155831, "Pause time in SatView mode whenever a squad travel order is given.") },
	{ category = "Gameplay", id = "ShowNorth",                name = T(397596571548, "Show North"),                     editor = "bool",   default = true,      storage = "account", help = T(968463817287, "Indicates North with an icon on the screen border.")},
	{ category = "Gameplay", id = "ShowCovers",               name = T(693926475349, "Show Covers Shields"),            editor = "choice", default = "Combat",  storage = "account", items = lUIViewModes, help = T(549744366946, "Allows cover shields to be visible when not in combat.")},
	{ category = "Gameplay", id = "AlwaysShowBadges",         name = T(834175857662, "Show Merc Badges"),               editor = "choice", default = "Combat",  storage = "account", items = lUIViewModes, help = T(526076106085, "Shows UI elements with detailed information above the merc's heads.") },
	{ category = "Gameplay", id = "ShowLOF",                  name = T(304702880820, "Show Line of Fire"),              editor = "bool",   default = true,      storage = "account", help = T(426202778816, "Allows line of fire lines to be visible when in combat.") },
	{ category = "Gameplay", id = "PauseConversation",        name = T(146071242733, "Pause conversations"),            editor = "bool",   default = true,      storage = "account", help = T(118088730513, "Wait for input before continuing to the next conversation line.")},
	{ category = "Gameplay", id = "AutoSave",                 name = T(571339674334, "AutoSave"),                       editor = "bool",   default = true,      storage = "account", SortKey = -1500, help = T(690186765577, "Automatically create a savegame when a new day starts, when a sector is entered, when a combat starts or ends, when a conflict starts in SatView, and on exit.") },
	{ category = "Gameplay", id = "InteractableHighlight",    name = T(770074868053, "Highlight mode"),                 editor = "choice", default = "Toggle",  storage = "account", items = lInteractableHighlightMode, help = T(705105646677, "Interactables can highlighted for a time when a button is pressed or held down.") },
	{ category = "Gameplay", id = "ForgivingModeToggle",      name = T(836950884858, "Forgiving Mode"),                 editor = "bool",   default = false, storage = "local", no_edit = function (self) return not Game end, read_only = function() return netInGame and not NetIsHost() end, SortKey = -1600, help = T(983637939241, --[[GameRuleDef ForgivingMode description]] 'Lowers the impact of attrition and makes it easier to recover from bad situations (faster healing and repair, better income).<newline><newline><flavor>You cannot unlock the "Ironman" achievement while Forgiving mode is enabled.</flavor><newline><newline><flavor>You can change this option at any time during gameplay.</flavor>')},
	{ category = "Gameplay", id = "ActivePauseMode",          name = T(133670189455, "Active Pause"),                   editor = "bool",   default = true,  storage = "local", no_edit = function (self) return not Game end, read_only = function() return netInGame and not NetIsHost() end, SortKey = -1590, help = T(466566359686, "Allows pausing the game in Exploration mode. Actions can be ordered while in pause but any attack will unpause the game.<newline><newline><flavor>You can change this option at any time during gameplay.</flavor>")},
	{ category = "Display",  id = "AspectRatioConstraint",    name = T(125094445172, "UI Aspect Ratio"),                editor = "choice", default = 1, items = lAspectRatioItems, storage = "local", help = T(433997797079, "Constrain UI elements like the HUD to the set aspect ratio. Useful for Ultra Wide and Super Ultra Wide resolutions.") },
}

const.MaxUserUIScaleHighRes = 100

function OnMsg.ClassesGenerate(classdefs) 
	table.iappend(classdefs.OptionsObject.properties, game_properties)
	
	local gamepadOption = table.find_value(classdefs.OptionsObject.properties, "id", "Gamepad")
	if gamepadOption then
		gamepadOption.no_edit = true
	end
end

function OnMsg.ApplyAccountOptions()
	if AccountStorage then
		hr.CameraScrollOutsideWindow = GetAccountStorageOptionValue("MouseScrollOutsideWindow") == false and 0 or 1
		const.CameraControlInvertLook = GetAccountStorageOptionValue("InvertLook")
		const.CameraControlInvertRotation = GetAccountStorageOptionValue("InvertRotation")
		const.CameraControlControllerPanSpeed = GetAccountStorageOptionValue("FreeCamPanSpeed")
		hr.CameraFlyRotationSpeed = GetAccountStorageOptionValue("FreeCamRotationSpeed") / 1000.0
		UpdateAllBadgesAndModes()
	end
end

function SaveAccStorageAfterCameraSpeedOptionChange()
	SaveAccountStorage(2000)
end

function SyncCameraControllerSpeedOptions()
	SetAccountStorageOptionValue("FreeCamPanSpeed", const.CameraControlControllerPanSpeed)
	SetAccountStorageOptionValue("FreeCamRotationSpeed", hr.CameraFlyRotationSpeed * 1000)
	DelayedCall(1000, SaveAccStorageAfterCameraSpeedOptionChange)
end

function ApplyOptions(host, next_mode)
	CreateRealTimeThread(function(host)
		local obj = ResolvePropObj(host:ResolveId("idScrollArea").context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local category = host:GetCategoryId()
		if not obj:WaitApplyOptions(original_obj) then
			WaitMessage(terminal.desktop, T(824112417429, "Warning"), T(862733805364, "Changes could not be applied and will be reverted."), T(325411474155, "OK"))
		else
			local object_detail_changed = obj.ObjectDetail ~= original_obj.ObjectDetail
			obj:CopyCategoryTo(original_obj, category)
			SaveEngineOptions()
			SaveAccountStorage(5000)
			if category == "Keybindings" then
				ReloadShortcuts()
			elseif category == "Gameplay" then
				ApplyLanguageOption()
				ApplyDifficultyOption()
				ApplyGameplayOption()
			elseif category == "Video" then
				if object_detail_changed then
					SetObjectDetail(obj.ObjectDetail)
				end
			end
			Msg("GameOptionsChanged", category)
		end
		if not next_mode then
			--SetBackDialogMode(host)
		else
			--SetDialogMode(host, next_mode)
		end
	end, host)
end

function CancelOptions(host, clear)
	CreateRealTimeThread(function(host)
		if host.window_state == "destroying" then return end
		local obj = OptionsObj
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local category = host:GetCategoryId()
		original_obj:WaitApplyOptions()
		original_obj:CopyCategoryTo(obj,category)
		if clear then 
			local sideButtuonsDialog = GetDialog(host):ResolveId("idMainMenuButtonsContent")
			if sideButtuonsDialog and GetDialogMode(sideButtuonsDialog) == "keybindings" then
				GetDialog(host):ResolveId("idMainMenuButtonsContent"):SetMode("mm")
			else
				local mmDialog = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
				mmDialog:SetMode("")
			end
			GetDialog(host):SetMode("empty") 
		end
		GetDialog(host):ResolveId("idSubSubContent"):SetMode("empty") 
	end, host)
end

function ApplyDisplayOptions(host, next_mode)
	CreateRealTimeThread( function(host)
		if host.window_state == "destroying" then return end
		local obj = ResolvePropObj(host:ResolveId("idScrollArea").context)
		local original_obj = ResolvePropObj(host.idOriginalOptions.context)
		local graphics_api_changed = obj.GraphicsApi ~= original_obj.GraphicsApi
		local graphics_adapter_changed = obj.GraphicsAdapterIndex ~= original_obj.GraphicsAdapterIndex
		local ok = obj:ApplyVideoMode()
		if ok == "confirmation" then
			ok = WaitQuestion(terminal.desktop, T(145768933497, "Video mode change"), T(751908098091, "The video mode has been changed. Keep changes?"), T(689884995409, "Yes"), T(782927325160, "No")) == "ok"
		end
		--options obj should always show the current resolution
		obj:SetProperty("Resolution", point(GetResolution()))
		if ok then
			obj:CopyCategoryTo(original_obj, "Display")
			original_obj:SaveToTables()
			SaveEngineOptions() -- save the original + the new display options to disk, in case user cancels options menu
		else
			-- user doesn't like it, restore
			original_obj:ApplyVideoMode()
			original_obj:CopyCategoryTo(obj, "Display")
		end
		local restartRequiredOptionT
		if graphics_api_changed and graphics_adapter_changed then
			restartRequiredOptionT = T(918368138749, "More than one option will only take effect after the game is restarted.")
		elseif graphics_api_changed then
			restartRequiredOptionT = T(419298766048, "Changing the Graphics API option will only take effect after the game is restarted.")
		elseif graphics_adapter_changed then
			restartRequiredOptionT = T(133453226856, "Changing the Graphics Adapter option will only take effect after the game is restarted.")
		end
		if restartRequiredOptionT then
			WaitMessage(terminal.desktop, T(1000599, "Warning"), restartRequiredOptionT, T(325411474155, "OK"))
		end
	end, host)
end

function CancelDisplayOptions(host, clear)
	local obj = ResolvePropObj(host:ResolveId("idScrollArea").context)
	local original_obj = ResolvePropObj(host.idOriginalOptions.context)
	original_obj:CopyCategoryTo(obj, "Display")
	obj:SetProperty("Resolution", point(GetResolution()))
	if clear then 
		GetDialog(host):SetMode("empty")
		local mmDialog = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
		mmDialog:SetMode("")
		GetDialog(host):ResolveId("idSubSubContent"):SetMode("empty") 
	end
end

function OnMsg.OptionsChanged()
	local mm = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
	if mm then
		local resetApplyButtons = mm:ResolveId("idSubMenu"):ResolveId("idOptionsActionsCont")[1]
		local applyOpt = resetApplyButtons:ResolveId("idapplyOptions") or resetApplyButtons:ResolveId("idapplyDisplayOptions")
		if applyOpt then
			applyOpt.action.enabled = true
			applyOpt:SetEnabled(true)
			ObjModified("action-button-mm")
		end
		
		local resetOpt = resetApplyButtons:ResolveId("idresetToDefaults")
		if resetOpt then
			resetOpt.action.enabled = true
			resetOpt:SetEnabled(true)
			ObjModified("action-button-mm")
		end
	end
end

local lDialogsToApplyAspectRatioTo = {
	function()
		local igi = GetInGameInterface()
		return igi and igi.mode_dialog
	end,
	function()
		local weaponMod = GetDialog("ModifyWeaponDlg")
		return weaponMod and weaponMod.idModifyDialog
	end,
	function()
		local menu = GetDialog("PreGameMenu")
		return menu and menu.idMainMenu
	end,
	function()
		local menu = GetDialog("InGameMenu")
		return menu and menu.idMainMenu
	end,
}

function GetUIScale(res)
	--the user ui scale option now works on top of the previously automatic scale (multiplication).
	local screen_size = Platform.ged and UIL.GetOSScreenSize() or res or UIL.GetScreenSize()
	local xrez, yrez = screen_size:xy()
	
	local aspectRatioContraint = GetAspectRatioConstraintAmount("unscaled")
	xrez = xrez - aspectRatioContraint * 2
	
	local scale_x, scale_y = 1000 * xrez / 1920, 1000 * yrez / 1080
	-- combine the X and Y scale
	local scale = (scale_x + scale_y) / 2
	-- do not exceed the lower scale with more than 20%
	scale = Min(scale, scale_x * 120 / 100)
	scale = Min(scale, scale_y * 120 / 100)
	-- make the UI somewhat smaller on higher resolutions - having more pixels increases readability despite the lower size
	if scale > 1000 then
		scale = 1000 + (scale - 1000) * 900 / 1000
	end
	local controller_scale = table.get(AccountStorage, "Options", "Gamepad") and IsXInputControllerConnected() and const.ControllerUIScale or 100
	-- apply user scale and controller scale as multipliers
	return MulDivRound(scale, GetUserUIScale(scale) * controller_scale, 100 * 100)
end

function GetAspectRatioConstraintAmount(unscaled)
	local screen_size = Platform.ged and UIL.GetOSScreenSize() or UIL.GetScreenSize()
	local x, y = screen_size:xy()
	
	local constraint = lAspectRatioItems[EngineOptions.AspectRatioConstraint]
	constraint = constraint and constraint.real_value or 0
	
	local constraintMargin = 0
	if constraint > 0 and (0.0 + x) / y > constraint then
		local smallerWidth = round(y * constraint, 1)
		local xx = DivRound(x - smallerWidth, 2)
		
		if not unscaled then
			local scale = GetUIScale()
			constraintMargin = MulDivRound(xx, 1000, scale)
		else
			constraintMargin = xx
		end
	end
	return constraintMargin
end

function ApplyAspectRatioConstraint()
	local constraintMargin = GetAspectRatioConstraintAmount()
	
	for i, dlg in ipairs(lDialogsToApplyAspectRatioTo) do
		local dlgInstance = false
		if type(dlg) == "function" then
			dlgInstance = dlg()
		elseif type(dlg) == "string" then
			dlgInstance = GetDialog(dlg)
		end
		if dlgInstance then
			dlgInstance:SetMargins(box(constraintMargin, 0, constraintMargin, 0))
		end
	end
end

function OnMsg.IGIModeChanging()
	ApplyAspectRatioConstraint()
end

function OnMsg.SystemSize()
	ApplyAspectRatioConstraint()
end

function OnMsg.DialogOpen()
	ApplyAspectRatioConstraint()
end

local baseSetDisplayAreaMargin = OptionsObject.SetDisplayAreaMargin
function OptionsObject:SetDisplayAreaMargin(x)
	baseSetDisplayAreaMargin(self, 0)
end

function OptionsObject:SetAspectRatioConstraint(x)
	self.AspectRatioConstraint = x
	ApplyAspectRatioConstraint()
end

function ApplyDifficultyOption()
	if not Game then return end
	local newValue = OptionsObj and OptionsObj.Difficulty
	if netInGame then
		NetSyncEvent("MP_ApplyDifficulty", newValue)
	else
		ApplyDifficulty(newValue)
	end
end

function NetSyncEvents.MP_ApplyDifficulty(newValue)
	ApplyDifficulty(newValue)
end

function ApplyDifficulty(newValue)
	if newValue and Game.game_difficulty ~= newValue then
		Game.game_difficulty = newValue
		Msg("DifficultyChange")
	end
	if OptionsObj then
		OptionsObj:SetProperty("Difficulty", newValue)
		ObjModified(OptionsObj)
	end
	SetDifficultyOption()
end

function ChangeGameRule(rule, value)
	if Game and IsGameRuleActive(rule) ~= value then
		if value then
			Game:AddGameRule(rule)
		else
			Game:RemoveGameRule(rule)
		end
		Msg("ChangeGameRule", rule, value)
	end
end

function SetForgivingModeOption(val)
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	OptionsObj:SetProperty("ForgivingModeToggle", val ~= nil and val or IsGameRuleActive("ForgivingMode"))
	ApplyOptionsObj(OptionsObj)
end	

function SetActivePauseModeOption(val)
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	OptionsObj:SetProperty("ActivePauseMode", val ~= nil and val or IsGameRuleActive("ActivePause"))
	ApplyOptionsObj(OptionsObj)
end	


function ApplyGameplayOption()
	local newValue = OptionsObj and OptionsObj.ForgivingModeToggle
	NetSyncEvent("ChangeForgivingMode", newValue)
	NetSyncEvent("ChangeActivePauseMode", OptionsObj and OptionsObj.ActivePauseMode)
end

function NetSyncEvents.ChangeForgivingMode(newValue)
	ChangeGameRule("ForgivingMode", newValue)
	if OptionsObj then
		OptionsObj:SetProperty("ForgivingModeToggle", newValue)
		ObjModified(OptionsObj)
	end
	SetForgivingModeOption(newValue)
end

function NetSyncEvents.ChangeActivePauseMode(newValue)
	ChangeGameRule("ActivePause", newValue)
	if OptionsObj then
		OptionsObj:SetProperty("ActivePauseMode", newValue)
		ObjModified(OptionsObj)
	end
	SetActivePauseModeOption(newValue)
	
	if not IsGameRuleActive("ActivePause") and IsActivePaused() then
		CreateGameTimeThread(ToggleActivePause)
	end	
end

function OnMsg.ZuluGameLoaded(game)
	SetForgivingModeOption()
	SetDifficultyOption()
	SetActivePauseModeOption()
end

function SetDifficultyOption()
	OptionsObj = OptionsObj or OptionsCreateAndLoad()
	OptionsObj:SetProperty("Difficulty", Game.game_difficulty)
	ApplyOptionsObj(OptionsObj)
end

function OnMsg.NetGameLoaded()
	--in mp aply these options to the guest
	if not NetIsHost() then
		SetForgivingModeOption()
		SetDifficultyOption()
		SetActivePauseModeOption()
	end
end

local s_oldHideObjectsByDetailClass = HideObjectsByDetailClass

function HideObjectsByDetailClass(optionals, future_extensions, eye_candies, ...)
	return s_oldHideObjectsByDetailClass(optionals, future_extensions, eye_candies, true)
end
