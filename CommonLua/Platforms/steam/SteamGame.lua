function IsDlcOwned(dlc)
	return Platform.developer or IsSteamAvailable() and SteamIsDlcAvailable(dlc.steam_dlc_id)
end

function GetPCSaveFolder()
	local path = "saves:/"
	if IsSteamAvailable() then
		path = string.format("saves:/%s/", tostring(SteamGetUserId64()))
	end
	local ok, err = io.createpath(path)
	if not ok then
		print("Failed to create save path", err)
	end
	return path
end

function GetSteamLobbyVisibility(visible)
	visible = visible or netGameInfo.visible_to
	if not visible or visible == "friends" or visible == "public" then
		return "friendsonly"
	else
		return "invisible"
	end
end

function OnMsg.NetGameJoined()
	CreateRealTimeThread( function()
		if netGameInfo.steam_lobby then
			local err = AsyncSteamJoinLobby( tonumber(netGameInfo.steam_lobby) )
			if err then
				DebugPrint("AsyncSteamJoinLobby failed: " .. err)
			end
		else
			local err, lobby = AsyncSteamCreateLobby( GetSteamLobbyVisibility(), netGameInfo.max_players or 4 )
			if err then
				DebugPrint("AsyncSteamCreateLobby failed: " .. err)
				return
			end
			SteamSetLobbyData(tonumber(lobby), "game_address", tostring(netGameAddress))
			NetChangeGameInfo( { steam_lobby = tonumber(lobby) } )
		end
	end) 
end

function OnMsg.NetGameLeft()
	if netGameInfo.steam_lobby then
		SteamLeaveLobby( tonumber(netGameInfo.steam_lobby) )
	end
end

function OnMsg.NetGameInfo(info)
	if info.visible_to ~= nil then
		CreateRealTimeThread(function()
			if netInGame and netGameInfo.steam_lobby then
				SteamSetLobbyType(netGameInfo.steam_lobby, GetSteamLobbyVisibility(info.visible_to))
			end
		end)
	end
end

function OnSteamEnterLobby(lobby)
end

function ProcessSteamInvite(lobby)
	CreateRealTimeThread( function()
		local lobbyNumber = tonumber(lobby)
		local err = AsyncSteamJoinLobby( lobbyNumber )
		if err then
			DebugPrint("AsyncSteamJoinLobby failed: " .. err)
			return
		end
		local game_address = tonumber(SteamGetLobbyData(lobbyNumber, "game_address"))
		if game_address == 0 then
			DebugPrint("invalid game address for lobby")
			return
		end
		local err = NetSteamGameInviteAccepted(game_address, lobbyNumber)
		if err then 
			DebugPrint(err) 
			return
		end
	end )
end

OnSteamGameLobbyJoinRequest = ProcessSteamInvite

function OnMsg.StartAcceptingInvites()
	local lobby = GetAppCmdLine():match("%+connect_lobby%s+(%d+)")	
	if lobby then
		ProcessSteamInvite(lobby)
	end
end

function NetSteamGameInviteAccepted(game_address, lobby)
	print("Steam Invitation accepted for ", game_address, lobby)
	return "Need to override NetSteamGameInviteAccepted for current game"
end

function OnMsg.BugReportStart(print_func)
	local steam_beta, steam_branch = SteamGetCurrentBetaName()
	if (steam_branch or "") ~= "" then
		print_func("Steam Branch:", steam_branch)
	end
end

if Platform.steam and IsSteamAvailable() then
	_InternalFilterUserTexts = function(unfilteredTs)
		local filteredTs = {}
		local errors = {}
		for _, T in ipairs(unfilteredTs) do
			local res = SteamFilterText(T._user_text_type or "", T._steam_id or "0", TDevModeGetEnglishText(T, "deep", "no_assert") or "")
			if res == nil then
				table.insert(errors, { error = "Unknown Steam Error", user_text = T})
			end
			filteredTs[T] = res
		end
		if next(errors) == nil then errors =false end
		return errors, filteredTs
	end
end