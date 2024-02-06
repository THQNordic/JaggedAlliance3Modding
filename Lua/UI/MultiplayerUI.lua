-- http://mantis.haemimontgames.com/view.php?id=179671

--from game browser
local ADDRESS = 1
local NAME = 2
local VISIBLE = 3
local PLAYERS = 4
local MAX_PLAYERS = 5
local INFO = 6

function OnMsg.NetPlayerMessage(name, player_name, player_id, msg, other)
	--print("debug-netMsg", msg)
end

-------------------------------------
-- CO OP SQUAD CONTROL
-------------------------------------

function RefreshMercSelection()
	local sel = Selection
	--clear non controlled
	for i = #sel, 1, -1 do
		local obj = sel[i]
		if IsKindOf(obj, "Unit") then
			if not obj:IsLocalPlayerControlled() then
				SelectionRemove(obj)
			end
		end
	end
	
	if #sel <= 0 then
		--select something
		if g_Combat then
			g_Combat:NextUnit(false, true)
		else
			local dlg = GetInGameInterfaceModeDlg()
			if IsKindOf(dlg, "IModeExploration") then
				dlg:NextUnit()
			end
		end
	end
	
	if SelectedObj and IsKindOf(SelectedObj, "Unit") then
		if g_Combat then
			--show ready btn
			local igi = GetInGameInterfaceModeDlg()
			if IsKindOf(igi, "IModeCombatMovement") and igi.window_state ~= "destroying" then
				igi:SetAttacker(SelectedObj)
			end
			--show ready btn
			ObjModified(SelectedObj)
		end
	end
end

function OnMsg.Resume()
	if SelectedObj and IsKindOf(SelectedObj, "Unit") then
		--while game is paused ui actions are disabled (this was due to players being able to shoot during pause in coop)
		--if last ui action recalc was during pause all actions for the selected unit would be greyed out
		SelectedObj:RecalcUIActions()
	end
end

if FirstLoad then
	CloseCoopMercsManagement_watchdog = false
end

function OnMsg.NetGameLoaded()
	RefreshMercSelection()
end

function NetEvents.CloseCoopMercsManagement()
	local function TryClose()
		local dlg = GetDialog("CoopMercsManagement")
		if dlg then
			dlg:Close() 
			RefreshMercSelection()
			return true
		end
		return false
	end
	
	if not TryClose() then
		assert(CloseCoopMercsManagement_watchdog == false)
		CloseCoopMercsManagement_watchdog = CreateRealTimeThread(function()
			--dlg might not have openned yet
			--don't let it open after close cuz it will get stuck on client forever
			for i = 1, 30 do
				Sleep(50)
				if TryClose() then
					CloseCoopMercsManagement_watchdog = false
					return
				end
			end
			CloseCoopMercsManagement_watchdog = false
			assert(false) -- failed to close merc selection on merc selection close event;
		end)
	end
end

local function lOpenCoOpManagementDialog()
	local coOpControl = GetDialog("CoopMercsManagement")
	if not coOpControl then
		CloseDialog("PDADialog")
		CloseDialog("ModifyWeaponDlg")
		CloseDialog("FullscreenGameDialogs")
		local popupHost = GetDialog("PDADialogSatellite")
		popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
		OpenDialog("CoopMercsManagement", popupHost or GetInGameInterface())
	end
end

function NetSyncEvents.OpenCoopMercsManagement(onlyIfNoMercs)
	if IsValidThread(CloseCoopMercsManagement_watchdog) then
		DeleteThread(CloseCoopMercsManagement_watchdog)
		CloseCoopMercsManagement_watchdog = false
	end
	if mapdata.GameLogic and HasGameSession() and IsCoOpGame() then
		if onlyIfNoMercs and CountCoopUnits(2) > 0 then
			return
		end
		lOpenCoOpManagementDialog()
	end
end

local function lOpenCoOpSquadControlWhenGameTimeStarts()
	if not GameState.entered_sector then
		local g = Game
		CreateRealTimeThread(function()
			WaitMsg("EnterSector")
			if g ~= Game then return end -- Another game was started.
			lOpenCoOpSquadControlWhenGameTimeStarts()
		end)
		return
	end
	
	if not IsCoOpGame() then return end
	CreateGameTimeThread(function()
		local dlg = GetLoadingScreenDialog()
		while dlg do
			WaitMsg(dlg, 1000)
			dlg = GetLoadingScreenDialog()
		end
		dlg = GetDialog("XSetpieceDlg")
		while dlg do
			WaitMsg("SetpieceEnded", 1000)
			dlg = GetDialog("XSetpieceDlg")
		end
		FireNetSyncEventOnHostOnce("OpenCoopMercsManagement", "onlyIfNoMercs")
	end)
end
OnMsg.NetGameLoaded = lOpenCoOpSquadControlWhenGameTimeStarts

-------------------------------------
-- UI SUPPORT
-------------------------------------

function MultiplayerFillGames(ui, filterType)
	if not ui then return end
	
	filterType = filterType or ui:ResolveId("idSubMenu") and ui:ResolveId("idSubMenu").context and ui:ResolveId("idSubMenu").context.filter_type

	local msg = CreateUnclickableMessagePrompt(T(908809691453, "Multiplayer"), T(598836447701, "Updating game list..."))
	local err, available = NetCall("rfnSearchGames", "coop", nil, filterType and filterType == "friends" and "only", "fnJoinFilter", filterType, netGameAddress, netAccountId)
	if err then
		ShowMPLobbyError(false, err)
		return err
	end
	msg:Close()
	
	local list_dlg = ui:ResolveId("idSubContent")
	if not list_dlg then return end
	
	local context = list_dlg:GetContext()
	local filtered = {}
	for _, game in ipairs(available or empty_table) do
		local game_info = game[INFO]
		if game_info and game[ADDRESS] ~= netGameAddress and game[VISIBLE] == "public" and game[PLAYERS] < game[MAX_PLAYERS] and game[PLAYERS] > 0 then
			local hostId = game_info.host_id
			if (hostId and hostId ~= netAccountId) then -- Sometimes stuff messes up and your hosted game from the past is shown.
				table.insert(filtered, game) --filtering happens in the swarm
			end
		end
	end
	
	local new_context = {
		available_games = filtered,
		invited_player = false,
		invited_player_id = false,
		multiplayer_invite = false,
		filter_type = filterType or "all"
	}
	ui:ResolveId("idSubMenu"):ResolveId("idScrollArea"):RespawnContent()
	list_dlg:SetContext(new_context)
	local menu = ui:ResolveId("idSubMenu")
	menu:SetContext(new_context)

	local filterField = menu:ResolveId("idScrollArea") and menu:ResolveId("idScrollArea"):ResolveId("idFilterName")
	if filterField then
		local nameT = MultiplayerGameFiltersList[new_context.filter_type] and MultiplayerGameFiltersList[new_context.filter_type].Name
		filterField:SetName(T{383256091724, "Filter: <name>", name = nameT})
	end
	
	--gamepad select first if empty
	if not next(filtered) and GetUIStyleGamepad() then
		local list = ui:ResolveId("idMainMenuButtonsContent"):ResolveId("idList")
		local currSelIdx = list:GetSelection() and list:GetSelection()[1] or -1
		if list:GetFirstValidItemIdx() ~= currSelIdx then
			list:SelectFirstValidItem()
		end
	end
end

function CreateUnclickableMessagePrompt(title, message)
	local msg = ZuluMessageDialog:new(
		{actions = {}},
		terminal.desktop,
		{
			title = title,
			text = message,
			obj = "mp-error" -- So errors close these as well
		}
	)
	msg:Open()
	return msg
end

function CreateLateListMessageBox()
	local actions = {}
	
	actions[#actions + 1] = XAction:new({
		ActionId = "idOpenGame",
		ActionName = T(288784847013, "Host public"),
		ActionShortcut = "Enter",
		ActionGamepad = "ButtonA",
		ActionToolbar = "ActionBar",
		OnAction = function(self, host, source)
			host:Close("public")
			return "break"
		end
	})
	
	actions[#actions + 1] = XAction:new({
		ActionId = "idInvite",
		ActionName = T(471606302283, "Host private"),
		ActionShortcut = "I",
		ActionGamepad = "ButtonY",
		ActionToolbar = "ActionBar",
		OnAction = function(self, host, source)
			host:Close("private")
			return "break"
		end
	})
	
	actions[#actions + 1] = XAction:new({
		ActionId = "idCancel",
		ActionName = T(6879, "Cancel"),
		ActionShortcut = "Escape",
		ActionGamepad = "ButtonB",
		ActionToolbar = "ActionBar",
		OnAction = function(self, host, source)
			host:Close("close")
			return "break"
		end
	})

	local msg = ZuluMessageDialog:new(
		{actions = actions},
		terminal.desktop,
		{
			title = T(245562128624, "CO-OP LOBBY"),
			text = T(311338163398, "Other players may join your ongoing game. Do you want to host a public or private game?"),
			obj = "mp-error" -- So errors close these as well
		}
	)
	msg:Open()
	return msg
end

function CloseMessageBoxesOfType(objString, response)
	for dlg, _ in pairs(g_OpenMessageBoxes) do
		if dlg and dlg.window_state == "open" then
			local msgObj = dlg.context.obj
			local tp = type(objString)
			if tp=="string" and msgObj == objString or tp=="table" and table.find(objString, msgObj) then
				dlg:Close(response)
			end
		end
	end
end

function FindMessageBoxOfType(objString)
	for dlg, _ in pairs(g_OpenMessageBoxes) do
		if dlg and dlg.window_state == "open" then
			local msgObj = dlg.context.obj
			local tp = type(objString)
			if tp=="string" and msgObj == objString or tp=="table" and table.find(objString, msgObj) then
				return true
			end
		end
	end
	return false
end

function CloseMPErrors()
	CloseInvites()
	CloseMessageBoxesOfType({"mp-error", "leave-notify", "joining-game"}, "close")
end

function ShowMPLobbyError(context, err)
	CloseMPErrors()
	--print("error", context, err)
	
	local parent = GetDialog("PDADialog") and GetDialog("PDADialog"):ResolveId("idDisplayPopupHost") or terminal.desktop
	local msg = false
	local context_string = ""
	local error_string = ""
	
	if context == "join" then
		context_string = T(858607081078, "Could not join game.")
	elseif context == "invite" then
		context_string = T(192164122130, "Could not invite player.")
	elseif context == "platform-invite" then
		context_string = T(960708199674, "Could not open the invitation dialog.")
	elseif context == "connect" then
		context_string = T(918383291777, "Could not connect to the server!")
	elseif context == "disconnected" then
		if not netInGame then return false end
		context_string = T(789332217909, "Lost connection to multiplayer server.")
	elseif context == "disconnect-after-leave-game" then
		if not netInGame then return false end
		context_string = T(789332217909, "Lost connection to multiplayer server.")
	elseif context == "busy" then
		context_string = T(493609285611, "Player is busy.")
	elseif context == "mods" then
		msg = CreateMessageBox(parent, T(634182240966, "Error"), T{349914917388, "<ModsError(err)>", err = err}, T(325411474155, "OK"))
		err = nil
	elseif context == "dlc" then
		context_string = err
		err = nil
	else
		context_string = T(141784216225, "Error.")
	end
	if err then error_string = Untranslated{"<MPError(err)>", err = tostring(err)} end
	msg = msg or CreateMessageBox(parent, T(634182240966, "Error"), context_string .. error_string, T(325411474155, "OK"))
	msg.obj = "mp-error"
	return msg
end


local NetworkErrorsT = {
	["game full"] = T(366423230585, "Game is full"),
	["not found"] = T(506175657595, "Game not found"),
	["disconnected"] = T(321476715550, "Disconnected from server"),
	["host left"] = T(582246748693, "Game host left the game"),
	["player left"] = T(614992240157, "Other player left the game"),
	["rejected"] = T(513425499490, "Rejected"),
	["game not found"] = T(506175657595, "Game not found"),
	["restricted"] = T(766750482132, "Account restricted"),
	["banned"] = T(456051298754, "Banned"),
	["steam-auth"] = T(481937697290, "Authentication failed"),
	["gog-auth"] = T(481937697290, "Authentication failed"),
	["epic-auth"] = T(481937697290, "Authentication failed"),
	["psn-auth"] = T(481937697290, "Authentication failed"),
	["xbox-auth"] = T(481937697290, "Authentication failed"),
	["unknown-auth"] = T(481937697290, "Authentication failed"),
	["no account"] = T(481937697290, "Authentication failed"),
	["invalid code"] = T(138404081301, "Invalid code"),
	["no code"] = T(209543574847, "No code"),
	["no words"] = T(746887802931, "Could not fetch valid codes"),
	["invalid id"] = T(542223789460, "Invalid ID"),
	["incomplete game data"] = T(991087359493, "Incomplete game data"),
	["host not found"] = T(966517041398, "Host not found"),
	["already in game"] = T(492980200583, "Already in the game"),
	["game suspended"] = T(424413358716, "Game was suspended"),
	["xbox-services"] = T(113030388315, "Failed to reach Xbox Live services"),
	["xbox-mp-restricted"] = T(669934767175, "This account has restricted access to multiplayer"),
	["psn-signout"] = T(148770111050, "Signed out of PlayStation™Network"),
	["psn-id"] = T(949097051569, "Account for PlayStation™Network not found"),
	["psn-premium"] = T(819059531838, "Account for PlayStation™Network restricted from multiplayer"),
	["psn-create-player-session"] = T(530265215972, "Failed to create game session"),
	["psn-join-player-session"] = T(597091536965, "Failed to join the game session"),
	["psn-player-session-deleted"] = T(991318913065, "The game session was deleted."),
	["psn-player-session-kicked"] = T(760970143468, "You were removed from the game session."),
	["psn-availability"] = T(302254849087, "Network features are not available."),
	["psn-communication-restricted"] = T(302254849087, "Network features are not available."),
}

function TFormat.MPError(ctx, err)
	local translatedT = NetworkErrorsT[err] and NetworkErrorsT[err] or IsT(err) and err
	if not translatedT and (not Platform.console) and err ~= "" then translatedT = Untranslated(err) end
	if translatedT then 
		return "\n" .. T{531841872242, "Reason: <err>", err = translatedT}
	else
		return ""
	end
end

function TFormat.ModsError(ctx, err)
	local missingMods = err[1]
	local unusedMods = err[2]
	
	local missingModsT = {}
	local unusedModsT = {}
	for count, mod in ipairs(missingMods) do
		if count < 10 then
			table.insert(missingModsT, mod.title)
		else
			table.insert(missingModsT, "...")
			break
		end
	end
	for count, mod in ipairs(unusedMods) do
		if count < 10 then
			table.insert(unusedModsT, mod.title)
		else
			table.insert(unusedModsT, "...")
			break
		end
	end
	
	local missingTitles
	local unusedTitles
	if next(missingMods) then
		missingTitles = T{433171451152, "To enter this game you need to install the following mods:\n<color 130 128 120><missingModsTitles></color>\n", missingModsTitles = Untranslated(table.concat(missingModsT, "\n"))}
	end
	if next(unusedMods) then
		unusedTitles = T{700577652991, "To enter this game you need to disable the following mods:\n<color 130 128 120><unusedModsTitles></color>\n", unusedModsTitles = Untranslated(table.concat(unusedModsT, "\n"))}
	end
	
	return T{410568555900, "<missingMods><unusedText>", missingMods = missingTitles or "", unusedText = unusedTitles or ""}
end

function GetMultiplayerLobbyDialog(skip_mode_check)
	local dlg = GetDialog("InGameMenu") or GetDialog("PreGameMenu")
	if skip_mode_check then return dlg end
	
	local subMenu = dlg and dlg.idSubMenu
	if not subMenu then return false end
	
	return subMenu:ResolveId("idMultiplayer") and dlg or false
end

function LeaveMultiplayer(reason)
	local multiplayer_game = IsInMultiplayerGame()
	local is_host = not multiplayer_game or NetIsHost()
	local multiplayer_ui = GetMultiplayerLobbyDialog(true)
	multiplayer_ui = multiplayer_ui and multiplayer_ui.Mode == "Multiplayer"
	
	NetLeaveGame()
	if not is_host then 
		OnGuestForceLeaveGame(reason) 
	else
		MultiplayerLobbySetUI("empty")
		if reason and (multiplayer_ui or multiplayer_game) then
			ShowMPLobbyError("disconnect-after-leave-game", reason)
		end
	end
end

function MultiplayerLobbySetUI(mode, param, campaignId) -- todo: check if param actually does anything
	if not CanYield() then
		CreateRealTimeThread(MultiplayerLobbySetUI, mode, param, campaignId)
		return
	end
	
	local ui = GetMultiplayerLobbyDialog(true)
	if not ui then return end
	
	if mode ~= "empty" and not netInGame then
		local err = PlatformCheckMultiplayerRequirements()
		if err then return ShowMPLobbyError("connect", err) end
	end
	
	-- Try to connect to the server first
	if mode ~= "empty" then
		local err = MultiplayerConnect()
		if err then
			ShowMPLobbyError("connect", err)
			mode = "empty"
		end
	end
	
	if mode == "multiplayer_host" and campaignId then
		local err = HostMultiplayerGame(param, campaignId)
		if err then
			ShowMPLobbyError(false, err)
			mode = "empty"
		end
	end
	
	local mpCampaignChoice
	if mode == "multiplayer_host_campaign_choice" then
		ui:ResolveId("idSubContent"):SetMode("newgame01", {mp = true, visibility = param})
		mpCampaignChoice = true
	end
	
	if ui.Mode == "" and mode ~= "empty" then 
		ui:SetMode("Multiplayer")
		ShowMultiplayerModsPopup("no_wait")
	elseif mode == "empty" then
		ui:SetMode("") 
	end
	if ui:ResolveId("idSubContent").Mode ~= mode and not mpCampaignChoice then
		ui:ResolveId("idSubContent"):SetMode(mode, param)
	end
	
	if mpCampaignChoice then
		mode = "multiplayer_host"
	end
	
	-- Todo: actions from mode should populate buttons
	local buttonMode = {
		["multiplayer_host"] = "multiplayer_host",
		["multiplayer_guest"] = "multiplayer_host",
		["multiplayer"] = "multiplayer_games",
		["empty"] = "mm"
	}
	local curButtonMode = buttonMode[mode]
	ui:ResolveId("idMainMenuButtonsContent"):SetMode(curButtonMode, param)
	--ui:SetMode(curButtonMode, param)
	
	-- Todo: this should be stored somewhere in the template, per mode.
	local titles = {
		["multiplayer_host"] = T(245562128624, "CO-OP LOBBY"),
		["multiplayer_guest"] = T(245562128624, "CO-OP LOBBY"),
		["multiplayer"] = T(139802124389, "MULTIPLAYER"),
		["empty"] = ""
	}
	local curTitle = titles[mode]
	ui:ResolveId("idSubMenuTittle"):SetText(curTitle)
	
	-- Todo: move this to the ui on mode open
	if mode == "multiplayer" then
		NewGameObj = false
		NetLeaveGame()
		CreateRealTimeThread(MultiplayerFillGames, ui, "all")
	elseif mode == "empty" and (not Game or param == "unlist") then -- Dont unlist if closing menu in game.
		NetLeaveGame("ui_closed")
	end
end

-------------------------------------
-- HOST+JOIN THROUGH BROWSER
-------------------------------------

function UIHostGame()
	if not CanYield() then
		CreateRealTimeThread(UIHostGame)
		return
	end

	local dlg = OpenDialog("MultiplayerHostQuestion", terminal.desktop)
	local visible_to = dlg:Wait()
	if not visible_to then
		local ui = GetMultiplayerLobbyDialog()
		local gamesList = ui and ui:ResolveId("idSubMenu") and ui:ResolveId("idSubMenu"):ResolveId("idScrollArea")
		if gamesList then
			gamesList:SelectFirstValidItem()
		else
			local mmButtons = ui:ResolveId("idMainMenuButtonsContent"):ResolveId("idList")
			if mmButtons then
				mmButtons:SelectFirstValidItem()
			end
		end
		return
	end
	
	NewGameObj = false
	if MultipleCampaignPresetsPresent() then
		MultiplayerLobbySetUI("multiplayer_host_campaign_choice", visible_to)
	else
		local err = HostMultiplayerGame(visible_to, "HotDiamonds")
		if err then
			ShowMPLobbyError(false, err)
			return
		end
		MultiplayerLobbySetUI("multiplayer_host", visible_to)
	end
end

function UIJoinGame(game, direct)
	if not CanYield() then
		CreateRealTimeThread(UIJoinGame, game, direct)
		return
	end
	
	local gameId = game and game[1]
	if not gameId then return end
	
	local ui = GetMultiplayerLobbyDialog()
	if not direct and not ui then return end
	
	-- todo: players shouldnt be able to join while an invite is being waited on
	
	local err = TryNetJoinGame(gameId)
	if err then
		if not direct then
			MultiplayerFillGames(ui) -- Refresh after error
		end
		ShowMPLobbyError("join", err)
		return
	end
end

function OnMsg.NetPlayerJoin(info)
	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	local playerId = info.account_id
	if not playerId then return end
	
	local context
	if ui and not Game then
		-- Send the game info to the other player
		context = ui.context
		context.invited_player = info.name
		context.invited_player_id = playerId
		context.multiplayer_invite = "accepted"
		ui:SetContext(context, true)
	end
	
	CreateRealTimeThread(function()
		local err = NetCall("rfnPlayerMessage", playerId, "lobby-info", {start_info = NewGameObj, host_ready = context and context.host_ready, no_menu =  not ui or not not Game})
		if err then
			ShowMPLobbyError(false, err)
			return
		end
	end)
end

-- when remote goes to main menu it sends us an infinite net pause
local function lPreventNetPause()
	if NetPause and (not netInGame or table.count(netGamePlayers) <= 1) then
		PauseReasons = {}
		NetSetPause(false)
	end
end

function OnMsg.PreGameMenuOpen()
	NetLeaveGame("main menu")
	lPreventNetPause()
end

local was_client = false
function OnMsg.ChangeMap()
	was_client = netInGame and netUniqueId ~= 1
end

function OnMsg.NetDisconnect(reason)
	assert(not g_ForceLeaveGameDialog, "g_ForceLeaveGameDialog safe to ignore")
	CreateRealTimeThread(function()
		if GameState.loading_savegame then
			WaitGameState({loading_savegame = false})
		end
		if GameState.loading then -- loading screen
			WaitGameState({loading = false})
		end
		if reason == "ui_closed" or reason == "analytics" then return end
		if g_ForceLeaveGameDialog then return end
		g_ForceLeaveGameDialog = ShowMPLobbyError("disconnect-after-leave-game", reason)
		MultiplayerLobbySetUI("empty")
		if was_client then
			if g_ForceLeaveGameDialog then
				WaitMsg(g_ForceLeaveGameDialog)
				g_ForceLeaveGameDialog = false
			end
			
			if not GetDialog("PreGameMenu") then
				OpenPreGameMainMenu()
			end
		end
	end)
end

if FirstLoad then 
	g_ForceLeaveGameDialog = false
end

function OnGuestForceLeaveGame(reason)
	assert(not g_ForceLeaveGameDialog, "g_ForceLeaveGameDialog safe to ignore")
	if not CanYield() then
		CreateRealTimeThread(OnGuestForceLeaveGame, reason)
		return
	end
	
	if IsChangingMap() then
		WaitMsg("ChangeMapDone")
	end
	
	WaitLoadingScreenClose()
	
	if reason then
		if g_ForceLeaveGameDialog then return end
		g_ForceLeaveGameDialog = ShowMPLobbyError("disconnect-after-leave-game", reason)
		g_ForceLeaveGameDialog:Wait()
		g_ForceLeaveGameDialog = false
	end
	MultiplayerLobbySetUI("empty")
	if not GetDialog("PreGameMenu") then
		OpenPreGameMainMenu()
	end
	Msg("ForceLeaveGameEnd")
end

function NotifyPlayerLeft(player, reason)
	assert(not g_ForceLeaveGameDialog, "g_ForceLeaveGameDialog safe to ignore")
	if not CanYield() then
		CreateRealTimeThread(NotifyPlayerLeft, player, reason)
		return
	end

	if IsChangingMap() then
		WaitMsg("ChangeMapDone")
	end
	
	WaitLoadingScreenClose()
	
	CloseMessageBoxesOfType("leave-notify", "close")
	local hostLeft = false
	local leave_notify_obj	 = "leave-notify"
	if NetIsHost(player.id) then
		hostLeft = true
		NetLeaveGame("host left")
		
		if not GetDialog("PreGameMenu") then
			if g_ForceLeaveGameDialog then return end
			g_ForceLeaveGameDialog = CreateMessageBox(nil, T(687826475879, "Co-Op Lobby"), T{707106868307, "Game host - <u(name)> left the game. Returning to main menu.", name = player.name}, T(325411474155, "OK"), leave_notify_obj)
			g_ForceLeaveGameDialog:Wait()
			g_ForceLeaveGameDialog = false
			
			CloseBlockingDialogs() --this attempts to close weapon mod instantly, the next call closes it with a transition
			OpenPreGameMainMenu()
			Msg("ForceLeaveGameEnd")
			return
		else
			CreateMessageBox(nil, T(687826475879, "Co-Op Lobby"), T{372566450268, "Game host - <u(name)> left the lobby.", name = player.name}, T(325411474155, "OK"), leave_notify_obj)
		end
	else
		CreateMessageBox(nil, T(687826475879, "Co-Op Lobby"), T{479640131817, "<u(name)> left", name = player.name}, T(325411474155, "OK"), leave_notify_obj)
		if NetPause and (not netInGame or table.count(netGamePlayers) <= 1) and not next(PauseReasons) then
			NetSetPause(false)
		end
	end
	
	-- Update lobby UI, if open
	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if ui then
		local context = ui.context
		context.invited_player = false
		context.invited_player_id = false
		context.multiplayer_invite = false
		ui:SetContext(context, true)
	end
	
	if hostLeft then
		MultiplayerLobbySetUI("multiplayer")
	end
end
OnMsg.NetPlayerLeft = NotifyPlayerLeft

local function lReceiveLobbyInfo(name, player_id, msg, other)
	if not netInGame then return end
	NewGameObj = table.copy(other.start_info, "deep")
	if Platform.console and IsInMultiplayerGame() and not NetIsHost() then
		NewGameObj.campaign_name = GenerateMultiplayerGuestCampaignName()
	end
	
	if other.no_menu then return end
	
	local multiplayerAbleUI = GetMultiplayerLobbyDialog(true)
	local multiplayerUI = GetMultiplayerLobbyDialog()
	if multiplayerAbleUI then
		MultiplayerLobbySetUI("multiplayer_guest")
	end
	WaitAllOtherThreads()
	
	-- Read "invited_player" as "other_player", variable was
	-- named unfortunately, in the guest's case it means the host.
	local ui = GetMultiplayerLobbyDialog()
	local idSubMenu = ui and ui.idSubMenu
	if not idSubMenu then return end
	local context = idSubMenu.context or {}
	context.invited_player = name
	context.invited_player_id = player_id
	context.host_ready = other.host_ready or false
	idSubMenu:SetContext(context, true)
	if not other.no_scroll and GetUIStyleGamepad() then
		CreateRealTimeThread(function(idSubMenu)
			idSubMenu.idScrollArea:SelectFirstValidItem()
		end, idSubMenu)
	end
end

function OnMsg.NetPlayerMessage(randomTableIdk, player_name, player_id, msg, other) 
	if msg ~= "lobby-info" then return end
	CreateRealTimeThread(lReceiveLobbyInfo, player_name, player_id, msg, other)
end

function UICanStartGame()
	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if not ui then return false end
	
	local context = ui.context
	if not context then return false end
	
	local hasOtherPlayer = context.invited_player_id
	if hasOtherPlayer then
		local otherPlayerReady = context.multiplayer_invite == "ready"
		return context.host_ready and otherPlayerReady
	end
	
	-- Game can be started alone which will remain listed.
	return true
end

if FirstLoad then
g_FirstNetStart = false
end

function ExecCoopStartGame()
	g_FirstNetStart = true
	local abort = StartCampaign(NewGameObj and NewGameObj.campaignId, NewGameObj)
	g_FirstNetStart = false
	if abort then return end
	StartHostedGame("CoOp", GatherSessionData():str())
end

function UIStartGame()
	if not CanYield() then
		CreateRealTimeThread(UIStartGame)
		return
	end

	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if not ui then return end
	if not UICanStartGame() then return end
	
	NetSend("rfnPlayerMessage", ui.context.invited_player_id, "starting_game")
	
	ExecCoopStartGame()
end

if FirstLoad then
	StartingGameDialog = false
end

function OnMsg.NetPlayerMessage(name, player_name, player_id, msg)
	if not msg then return end
	if msg ~= "starting_game" then return end

	-- Create a message box without buttons to display to the guest while the host is loading.
	StartingGameDialog = CreateMessageBox(nil, T(687826475879, "Co-Op Lobby"), T(953960332662, "Starting game..."), T(967444875712, "Cancel"))
	StartingGameDialog:CreateThread("check-for-loading", function()
		while StartingGameDialog.window_state ~= "destroying" do
			local anyLoadingScreen = GetLoadingScreenDialog()
			if anyLoadingScreen or GameState.gameplay then
				StartingGameDialog:Close()
				StartingGameDialog = false
				return
			end
			WaitMsg("GameStateChanged", 100)
		end
	end)
	CreateRealTimeThread(function()
		local result = StartingGameDialog:Wait()
		if result == "ok" then
			NetLeaveGame("cancelled")
			MultiplayerLobbySetUI("multiplayer")
			CreateMessageBox(nil, T(965287931398, "Game cancelled"), T(984272003134, "You have left the game session."))
		end
	end)
end

-------------------------------------
-- READY
-------------------------------------

function UIHostReady(ready)
	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if not ui then return end
	
	if not netInGame or not NetIsHost() then return end
	assert(not Game)

	local context = ui.context
	context.host_ready = ready
	ui:SetContext(context, true)
	if GetUIStyleGamepad() then ObjModified("GamepadUIStyleChanged") end
	
	if context.invited_player_id then
		NetSend("rfnPlayerMessage", context.invited_player_id, "host_ready", ready)
	end
end

function OnMsg.NetPlayerMessage(name, player_name, player_id, msg, readyState)
	if not msg then return end
	if msg ~= "guest_ready" and msg ~= "host_ready" then return end

	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if not ui then return end
	local context = ui.context

	if msg == "guest_ready" then
		CloseDialog("MultiplayerInvitePlayers")
		context.multiplayer_invite = readyState and "ready" or "accepted"
		ui:SetContext(context, true)
	elseif msg == "host_ready" then -- Sent by host to other
		context.host_ready = readyState
		ui:SetContext(context, true)
		ObjModified("host_ready")
	end
end

-------------------------------------
-- INVITE
-------------------------------------

function UICancelInvite()
	if not CanYield() then
		CreateRealTimeThread(UICancelInvite)
		return
	end
	
	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if not ui then return end
	local context = ui.context

	NetSend("rfnPlayerMessage", context.invited_player_id, "cancel_invite")
	
	context.invited_player = false
	context.invited_player_id = false
	context.multiplayer_invite = false
	ui:SetContext(context, true)
end

function OnMsg.NetPlayerMessage(someTableIdk, player_name, player_id, msg, gameId)
	if not msg then return end
	if msg ~= "cancel_invite" and msg ~= "cancel_invite_busy" then return end

	local ui = GetMultiplayerLobbyDialog()
	ui = ui and ui.idSubMenu
	if not ui then return end
	local context = ui.context
	if not context then return end -- error with mods and dlc's reach this part and cause asserts down the line

	-- Sent by the host when cancelling invite, or the partner when declining an invite
	CloseInvites()
	context.invited_player = false
	context.invited_player_id = false
	context.multiplayer_invite = false
	ui:SetContext(context, true)
	
	if msg == "cancel_invite_busy" then
		ShowMPLobbyError("busy")
	end
end

function CloseInvites()
	CloseDialog("MultiplayerInvitePlayers")
	CloseMessageBoxesOfType("invite", "cancel")
end

function UIReceiveInvite(name, host_id, game_id, gameType, gameName)
	if not CanYield() then
		CreateRealTimeThread(UIReceiveInvite, name, host_id, game_id, gameType, gameName)
		return
	end
	
	if g_ForceLeaveGameDialog then
		g_ForceLeaveGameDialog:Close()
		WaitMsg("ForceLeaveGameEnd")
	end
	
	-- If already joining a game, then cancel the invite as busy.
	if FindMessageBoxOfType("joining-game") then
		NetCall("rfnPlayerMessage", host_id, "cancel_invite_busy", game_id)
		return
	end

	CloseInvites() -- Ensure only a single invite on screen

	if not g_dbgFasterNetJoin and (Game or g_DisclaimerSplashScreen) then
		local gameTypePreset = MultiplayerGameTypes[gameType]
		local gameTypeName = gameTypePreset and gameTypePreset.Name or Untranslated(gameType)

		local text = T{642324815808, "Are you sure you would like to join <u(name)>'s <gameType> multiplayer game?", name = name, gameType = gameTypeName}
		text = text .. T(612286933019, "<newline>Unsaved game progress will be lost.")

		local res = WaitQuestion(terminal.desktop,
			T(127683166549, "Invite"),
			text,
			T(689884995409, "Yes"),
			T(782927325160, "No"),
			"invite"
		)

		if res == "cancel" then
			NetCall("rfnPlayerMessage", host_id, "cancel_invite", game_id)
			return
		end
	end
	
	CloseDialog("Credits")

	if Game or g_DisclaimerSplashScreen then
		if g_DisclaimerSplashScreen then
			g_DisclaimerSplashScreen:Close("net join")
		end
		OpenPreGameMainMenu()
	else
		local pgmmDlg = GetDialog("PreGameMenu")
		if pgmmDlg then
			pgmmDlg:Close()
			OpenDialog("PreGameMenu")
		end
	end

	-- don't actually need host_id or gameName, only game_id
	local err = TryNetJoinGame(game_id, host_id, gameName)
	if err then
		local ui = GetMultiplayerLobbyDialog()
		ui = ui and ui.idSubMenu
		if ui then
			MultiplayerFillGames(ui) -- Refresh after error
		end
			
		ShowMPLobbyError(false, err)
		return
	end
end
OnMsg.GameInvite = UIReceiveInvite

-------------------------------------
-- LATE JOIN AND JOIN REQUESTS
-------------------------------------

function GetGameInfo(game_address)
	if type(game_address) ~= "number" then return "no game specified" end
	return NetCall("rfnGetGameInfo", game_address)
end

function GetNetGameJoinCode(id)
	local words = GetEnglishNounsTable()
	if not words or not next(words) then return false, "no words" end
	
	id = id or netGameAddress
	if not id or id <= 0 then return false, "invalid id" end

	local wordsZeroIndexed = #words - 1
	local leftOver = id
	local code = {}
	while leftOver > 0 do
		local index = leftOver % #words
		code[#code + 1] = words[index + 1]
		leftOver = leftOver / #words
	end
	
	return table.concat(code, " ")
end

function GetGameIdFromJoinCode(code)
	if not code or #code == 0 then return false, "no code" end
	
	local words = GetEnglishNounsTable()
	if not words or not next(words) then return false, "no words" end
	
	local codeParts = string.split(code, " ")
	local codeIndices = {}
	for i, c in ipairs(codeParts) do
		if not c then return false, "invalid code" end
	
		local index = table.find(words, string.upper(c))
		if not index then return false, "invalid code" end
		codeIndices[#codeIndices + 1] = index - 1
	end
	
	local gameIdReconstructed = 0
	for i = #codeIndices, 1, -1 do
		gameIdReconstructed = gameIdReconstructed * #words + codeIndices[i]
	end
	
	return gameIdReconstructed
end

function UIJoinGameByJoinCode(code)
	if not CanYield() then
		CreateRealTimeThread(UIJoinGameByJoinCode, code)
		return
	end
	
	local gameId, err = GetGameIdFromJoinCode(code)
	if err then
		ShowMPLobbyError("join", err)
		return
	end
	
	-- Try to connect to the server first
	local err = MultiplayerConnect()
	if err then
		ShowMPLobbyError("connect", err)
		return
	end
	
	local err = TryNetJoinGame(gameId)
	if err then
		local ui = GetMultiplayerLobbyDialog()
		ui = ui and ui.idSubMenu
		if ui then
			MultiplayerFillGames(ui) -- Refresh after error
		end
			
		ShowMPLobbyError(false, err)
	end
end

function TryNetJoinGame(game_id, host_id, game_name)
	local msg = CreateMessageBox(terminal.desktop,
		T(687826475879, "Co-Op Lobby"),
		T(138349749027, "Joining game..."),
		T(6879, "Cancel"),
		"joining-game"
	)
	
	if not host_id then
		local err, gameInfo = GetGameInfo(game_id, game_name)
		if err then return err end
		host_id = gameInfo and gameInfo.host_id
	end
	if not host_id then return "host not found" end
	
	local err = NetSend("rfnPlayerMessage", host_id, "request_join", game_id, game_name)
	if err then
		return err
	end
	
	-- The message will either be cleared by an error or the host approving the game.
	local result = msg:Wait()
	if result == "rejected" then
		return "rejected"
	elseif result == "ok" then -- cancelled by user
		print("---------- Sent cancel")
		return NetSend("rfnPlayerMessage", host_id, "request_cancel", game_id)
	end
end

function WaitSavableState()
	-- Wait for the same things as above as things could've happened while the popup was open.
	WaitPlayerControl({no_coop_pause = true})

	-- Wait for host to be able to save
	-- (auto save id passed to allow for joining during combat with iron man mode on)
	while not CanSaveGame({ autosave_id = "combatStart" }) do
		WaitNextFrame()
	end
end

if FirstLoad and Platform.playstation then
	function AddPlayerToJoinableList(player_id)
		if Platform.playstation and netGameInfo.visible_to == "private" then
			local err, psn_id = NetGetPSNID(player_id)
			if err then
				playstation_print("Failed to get player psn_id")
				return err
				-- return NetSend("rfnPlayerMessage", player_id, "request_rejected", gameId, gameName)
			end
			
			local err = PSNAddJoinableSpecifiedUserToPlayerSession(netGameInfo.psn_session_id, psn_id)
			if err then
				playstation_print("Failed to add player to PSN's joinable specified user list")
				return err
				-- return NetSend("rfnPlayerMessage", player_id, "request_rejected", gameId, gameName)
			end
			return
		end
		return
	end
	
	function RemovePlayerFromJoinableList(player_id)
		if Platform.playstation and netGameInfo.visible_to == "private" then
			local err, psn_id = NetGetPSNID(player_id)
			if err then
				playstation_print("Failed to get player psn_id")
				return err
				-- return NetSend("rfnPlayerMessage", player_id, "request_rejected", gameId, gameName)
			end
			
			local err = PSNRemoveJoinableSpecifiedUserToPlayerSession(netGameInfo.psn_session_id, psn_id)
			if err then
				playstation_print("Failed to add player to PSN's joinable specified user list")
				return err
				-- return NetSend("rfnPlayerMessage", player_id, "request_rejected", gameId, gameName)
			end
			return
		end
		return
	end
end

function HandleJoinRequestMessageProc(someTableIdk, player_name, player_id, msg, gameId, gameName)
	assert(CanYield())
	if ChangingMap then
		WaitChangeMapDone()
		Sleep(200)
	end
	
	-- this makes it not wait for main menu pause
	WaitPlayerControl({no_coop_pause = true})
	
	-- just in case
	while terminal.desktop.modal_window ~= terminal.desktop do
		WaitNextFrame()
	end

	local hasAddedPlayerToJoinableList = false	
	if msg == "request_join" and (Game or GameState.loading) and not g_dbgFasterNetJoin then
		if Platform.playstation and netGameInfo.visible_to == "private" then
			local err = AddPlayerToJoinableList(player_id)
			if err then return NetSend("rfnPlayerMessage", player_id, "request_rejected", gameId, gameName) end
			hasAddedPlayerToJoinableList = true
		end
		
		local res = WaitQuestion(terminal.desktop,
			T(687826475879, "Co-Op Lobby"),
			T{242614432594, "<u(name)> would like to join your game. Play together?", name = player_name},
			T(689884995409, "Yes"),
			T(782927325160, "No"),
			"invite"
		)
		
		if res ~= "cancel" then
			CloseBlockingDialogs()
		end

		WaitSavableState()

		if res == "cancel" then
			if Platform.playstation then RemovePlayerFromJoinableList(player_id) end
			return NetCall("rfnPlayerMessage", player_id, "request_rejected")
		end
	end
	
	if msg == "request_join" then
		if Platform.playstation and netGameInfo.visible_to == "private" then
			if not hasAddedPlayerToJoinableList then
				local err = AddPlayerToJoinableList(player_id)
				if err then return NetSend("rfnPlayerMessage", player_id, "request_rejected", gameId, gameName) end
			end
		end
		return NetSend("rfnPlayerMessage", player_id, "request_approved", gameId, gameName)
	end
	
	if msg == "request_approved" then
		local err, info = GetGameInfo(gameId, gameName)
		if err then return err end
		
		-- Check if same dlcs
		local dlcs = info.dlcs
		if dlcs then
			for i, d in ipairs(dlcs) do
				if not IsDlcAvailable(d) then
					return T{270767785964, "Missing dlc: <dlc>", dlc = Untranslated(d)}, "dlc"
				end
			end
		end
		
		-- Check if host has my dlcs
		local myDlcs = GetAvailableDlcList()
		local allPresent = false
		for i, d in ipairs(myDlcs) do
			local hasTheDlc = table.find(info.dlcs, d)
			if not hasTheDlc then
				return T{813744621008, "Host doesn't have dlc: <dlc>", dlc = Untranslated(d)}, "dlc"
			end
		end
		
		--check mods between the players
		local missingMods = {}
		local unusedMods = {}
		local requiredMods = info.mods
		local myMods = g_ModsUIContextObj or ModsUIObjectCreateAndLoad()
		while not g_ModsUIContextObj or not g_ModsUIContextObj.installed_retrieved do
			Sleep(100)
		end
		local myEnabledMods = {}
		
		for mod, enabled in pairs(myMods.enabled) do
			if enabled then
				local modDef = myMods.mod_defs[mod]
				local matchIdx = table.find(requiredMods, "steamId", modDef.steam_id)
				if matchIdx then
					table.remove(requiredMods, matchIdx)
				else
					table.insert(unusedMods, modDef)
				end
			end
		end
		
		missingMods = requiredMods
		
		if next(missingMods) or next(unusedMods) then
			return {missingMods, unusedMods}, "mods"
		end
		
		local campaignId = info.campaign
		if campaignId and not CampaignPresets[campaignId] then
			return T{783069802257, "Campaign <em><u(id)></em> missing", id = info.campaign} , "join"
		end
		
		local err = PlatformCheckMultiplayerRequirements()
		if err then
			CloseMessageBoxesOfType("joining-game", err)
			return err
		end
		
		local err = PlatformJoinMultiplayerGame(info, gameId)
		if err then
			CloseMessageBoxesOfType("joining-game", err)
			return err
		end
		CloseMessageBoxesOfType("joining-game", "close")
		CloseInvites()
		return NetJoinGame(nil, gameId), "join"
	end	
	
	if msg == "request_rejected" then
		return CloseMessageBoxesOfType("joining-game", "rejected")
	end	
	
	if msg == "request_cancel" then
		return CloseInvites()
	end
end

function OnMsg.NetPlayerMessage(someTableIdk, player_name, player_id, msg, gameId, gameName)
	if not msg then return end
	if msg ~= "request_join" and msg ~= "request_cancel" and msg ~= "request_approved" and msg ~= "request_rejected" then return end
	CreateRealTimeThread(function()
		local err, step = HandleJoinRequestMessageProc(someTableIdk, player_name, player_id, msg, gameId, gameName)
		if err then
			ShowMPLobbyError(step, err)
			NetCall("rfnPlayerMessage", player_id, "cancel_invite")
			NetCall("rfnPlayerMessage", player_id, "invite_failed", step or err)
		end
	end)
end

function OnMsg.NetPlayerMessage(someTableIdk, player_name, player_id, msg, err)
	if msg == "invite_failed" then
		ShowMPLobbyError("invite", err)
	end
end

-- Player has joined a game in progress (through an approved request), send the data over.
function OnMsg.NetPlayerJoin(info)
	if not Game then return end
	local ui = GetMultiplayerLobbyDialog()
	if ui then ui:Close() end
	CoOpSendSave()
end

PlatformCheckMultiplayerRequirements = rawget(_G, "PlatformCheckMultiplayerRequirements") or empty_func

function MultiplayerInGameHostSetUI()
	if not CanYield() then
		CreateRealTimeThread(MultiplayerInGameHostSetUI)
		return
	end
	
	if not netInGame then
		local err = PlatformCheckMultiplayerRequirements()
		if err then return ShowMPLobbyError("connect", err) end
	end
	
	-- Listed game
	if netInGame then
		MultiplayerLobbySetUI(NetIsHost() and "multiplayer_host" or "multiplayer_guest")
		WaitAllOtherThreads()
		
		local ui = GetMultiplayerLobbyDialog()
		local subMenu = ui and ui.idSubMenu
		if not subMenu then return end
	
		if table.count(netGamePlayers) > 1 then
			local otherPlayer = netUniqueId == 1 and 2 or 1 -- Is this right?
			local otherPlayerData = netGamePlayers[otherPlayer]
			if not otherPlayerData then return end
			
			local context = {}
			context.multiplayer_invite = "in-game"
			context.invited_player_id = otherPlayerData.accountId
			context.invited_player = otherPlayerData.name
			subMenu:SetContext(context, true)
			if GetUIStyleGamepad() then
				CreateRealTimeThread(function(subMenu)
					subMenu.idScrollArea:SelectFirstValidItem()
				end, subMenu)
			end
		end
		
		return
	end
	
	local r = ShowMultiplayerModsPopup()
	if not r then return end

	-- Try to connect to the server first
	local err = MultiplayerConnect()
	if err then
		ShowMPLobbyError("connect", err)
		return
	end

	local prompt = CreateLateListMessageBox()
	local resp = prompt:Wait()
	if not resp or resp == "close" then return end
	
	if resp == "private" then
		-- Auto-host a private game
		local err = HostMultiplayerGame("private")
		if err then
			ShowMPLobbyError(false, err)
			return
		end
		MultiplayerLobbySetUI("multiplayer_host")
		WaitAllOtherThreads()
		
		local ui = GetMultiplayerLobbyDialog()
		local subMenu = ui and ui.idSubMenu
		if not ui or not subMenu then return end
	elseif resp == "public" then
		-- Auto-host a public game
		local err = HostMultiplayerGame("public")
		if err then
			ShowMPLobbyError(false, err)
			return
		end
	
		MultiplayerLobbySetUI("multiplayer_host")
	end
end

function OnMsg.UnitDied(unit, attacker, results)
	if netInGame and NetIsHost() then
		ObjModified("coop button")
	end
end

function OnMsg.NetPlayerInfo(player, info)
	ObjModified("coop button")
end

function OnMsg.NetGameJoined()
	ObjModified("coop button")
end

function OnMsg.NetGameLeft()
	ObjModified("coop button")
end

function OnMsg.NetPlayerLeft(player)
	if StartingGameDialog and (StartingGameDialog.window_state == "open" or StartingGameDialog.window_state == "closing") then
		StartingGameDialog:Close()
	end
	ObjModified("coop button")
end

-------------------------------------
-- DESYNC
-------------------------------------

MapVar("last_desync_log_path", false)
MapVar("last_desync_log_data", false)
local tempdir = "AppData/BugReport"
local desync_msg = false

function NetEvents.HereIsMyHashLog(player_id, cdata, pass_grid_hash, tunnel_hash)
	Msg("OtherPlayerHashLogArrived", player_id, DecompressPstr(cdata), pass_grid_hash, tunnel_hash)
end

function NetEvents.GiveMeYourHashLog()
	if last_desync_log_data then
		NetEvent("HereIsMyHashLog", netUniqueId, CompressPstr(last_desync_log_data), terrain.HashPassability(), terrain.HashPassabilityTunnels())
	else
		print("GiveMeYourHashLog no local desync log data")
	end
end

function ReportDesync()
	Pause("ReportDesync")
	PauseCampaignTime("ReportDesync")
	local msg = CreateMessageBox(nil, T(273706464856, "Bug report"), Untranslated("Reporting..."), T(325411474155, "OK"))
	msg:PreventClose()
	Sleep(100)
	
	local success, err = io.createpath(tempdir)
	if not success then
		print("[ReportDesync] Failed to create a temp folder for bug report:", err)
		tempdir = ""
	end
	
	--get both log files
	local my_data = last_desync_log_data
	if not my_data then
		print("[ReportDesync] no local desync log data")
	end
	local fname_base = "%s/BugReportHashLog" .. tostring(netGameAddress) .. "-%d-%d.desync.log"
	local max = 99
	local i = 1
	while i <= max do
		local name = string.format(fname_base, tempdir, i, netUniqueId)
		if not io.exists(name) then
			break
		end
		i = i + 1
	end
	if i > max then
		i = 1
	end
	
	local my_path = string.format(fname_base, tempdir, i, netUniqueId)
	local err = AsyncStringToFile(my_path, my_data)
	if err then
		my_path = nil
		print("[ReportDesync] failed to save local desync log:", err)
	end
	
	NetEvent("GiveMeYourHashLog")
	local his_path
	local ok, his_id, his_data, his_pass_grid_hash, his_tunnel_hash = WaitMsg("OtherPlayerHashLogArrived", 10 * 1000)
	if not ok or not his_data then
		print("[ReportDesync] failed to get other player hash log.")
	else
		his_path = string.format(fname_base, tempdir, i, his_id)
		err = AsyncStringToFile(his_path, his_data)
	end
	
	local summary = "[Desync] Game: " .. tostring(netGameAddress) .. " Player: " .. netUniqueId
	local my_pass_grid_hash = terrain.HashPassability()
	local my_tunnel_hash = terrain.HashPassabilityTunnels()
	local descr = string.format("PASSHASH v2\nMy pass grid hash:%s\nHis pass grid hash:%s\nPass hash equality:%s\n\nMy tunnel hash:%s\nHis tunnel hash:%s\nTunnel hash equality:%s", my_pass_grid_hash, his_pass_grid_hash, tostring(my_pass_grid_hash == his_pass_grid_hash), my_tunnel_hash, his_tunnel_hash, tostring(my_tunnel_hash == his_tunnel_hash))
	local files = {
		my_path,
		his_path
	}
	local report_params = {
		tags = { "Multiplayer" },
	}
	
	WaitXBugReportDlg(summary, descr, files, report_params)
	msg:Close()
	Resume("ReportDesync")
	ResumeCampaignTime("ReportDesync")
end

function OnMsg.GameDesynced(desync_path, desync_data)
	last_desync_log_path = desync_path
	last_desync_log_data = desync_data
	CreateRealTimeThread(function()
		if desync_msg and desync_msg.window_state ~= "destroying" then return end

		WaitPlayerControl()
		
		if not IsInMultiplayerGame() then return end
		
		local titleT = T(581122640598, "Game Desynchronized")
		local choiceResyncT = T(610827620841, "Resync")
		local choiceCloseT = T(175313021861, "Close")
		if config.IncludeDesyncReports then
			local text = T(788212590733, "Press 'Report' to submit a bug. Please describe what you were doing. It's generally not necessary for both players to report, but you can if it's something very peculiar.")
			desync_msg = CreateZuluPopupChoice(nil, {
				translate = true,
				text = text,
				title = titleT,
				choice1 = choiceResyncT,
				choice1_gamepad_shortcut = "ButtonA",
				choice1_state_func = function() return NetIsHost() and "enabled" or "disabled" end,
				choice2 = choiceCloseT,
				choice2_gamepad_shortcut = "ButtonB",
				choice3 = T(134550621660, "Report"),
				choice3_gamepad_shortcut = "ButtonY",
			})
		else
			local text = T(496968450861, "Sorry, a desync multiplayer error has occured. The host can use the 'Resync' button to try to continue your session.")
			desync_msg = CreateZuluPopupChoice(nil, {
				translate = true,
				text = text,
				title = titleT,
				choice1 = choiceResyncT,
				choice1_state_func = function() return NetIsHost() and "enabled" or "disabled" end,
				choice1_gamepad_shortcut = "ButtonA",
				choice2 = choiceCloseT,
				choice2_gamepad_shortcut = "ButtonB",
			})
		end
		
		desync_msg:Open()
		desync_msg:SetZOrder(9999)
		local result = desync_msg:Wait()
		desync_msg = false
		if result == 1 then
			CreateRealTimeThread(function()
				CloseBlockingDialogs()
				WaitSavableState()
				CoOpSendSave()
			end)
		elseif result == 3 then
			ReportDesync()
		end
	end)
end

function CloseBlockingDialogs()
	CancelDrag()
	CloseDialog("SatelliteConflict")
	CloseDialog("CoopMercsManagement")
	CloseDialog("PDADialog") --this used to stay open between sessions..
	CloseDialog("PreGameMenu")
	CloseDialog("PopupNotification")
	CloseDialog("ModifyWeaponDlg", true)
	CloseDialog("FullscreenGameDialogs")
	CloseBugReporter()
	if desync_msg and desync_msg.window_state ~= "destroying" then
		desync_msg:Close(2) --close/cancel
	end
end

function CoOpSendSave()
	if not netInGame then return end --server could have dropped by now
	assert(NetIsHost())
	local metadata = GatherGameMetadata();
	AddSystemMetadata(metadata)
	CreateRealTimeThread(function()
		local err = StartHostedGame("CoOp", GatherSessionData():str(), metadata)
		if not err then
			NetSyncEvent("ZuluGameLoaded")
		end
	end)
end

--Overwrite Steam funcs for zulu
function NetSteamGameInviteAccepted(game_address, lobby)
	local cid = SteamGetLobbyOwner(lobby)
	if not cid then 
		return "could not find steam lobby owner (cid)"
	end
	local owner_name = SteamGetFriendPersonaName(tonumber(cid))
	if not owner_name then
		return "could not find steam lobby owner (name)"
	end

	local err = MultiplayerConnect()
	if err then
		ShowMPLobbyError("connect", err)
		return
	end

	UIReceiveInvite(owner_name, nil, game_address, "CoOp", nil)
end

function GetSteamLobbyVisibility()
	local visibility = netGameInfo.visible_to
	if visibility == "friends" or visibility == "public" then
		return "friendsonly"
	else
		return "invisible"
	end
end

function OnMsg.ZuluGameLoaded(name)
	if NetIsHost() then --update game info when loading save
		NetChangeGameInfo({ 
			map = GetMapName(),
			campaign = Game and Game.Campaign,
			day = Game and TFormat.day() or 1,
		})
	end
end

function ShowMultiplayerModsPopup(no_wait)
	if not next(ModsLoaded) then return "no-mods" end
	if netInGame then return end

	local msg = CreateMessageBox(nil,
		T(137802317861, "Warning"),
		T(704807574482, "Playing multiplayer games with mods enabled may cause desyncs to occur during your playthrough."),
		T(325411474155, "OK")
	)
	if no_wait then return "ok" end
	
	return msg:Wait()
end

function UpdateWeaponModificationPartsCounter()
	local dlg = GetDialog("ModifyWeaponDlg")
	if dlg then
		local uiObj = table.get(dlg, "idModifyDialog", "idModificationResults", 1, 1)
		if uiObj then
			uiObj:OnContextUpdate(uiObj:GetContext())
		end
	end
end