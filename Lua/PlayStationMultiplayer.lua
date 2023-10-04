if not Platform.playstation then return end 

-------------------[ Game Hooks ]---------------------

function PlatformCreateMultiplayerGame(game_type, game_name, game_id, visible_to, info, max_players)
	local msg = CreateUnclickableMessagePrompt(T(908809691453, "Multiplayer"), T(994790984817, "Connecting..."))
	
	local err = PSNPrepareContextAndCallbacks()
	if err then
		msg:Close()
		playstation_print("Failed to create push context and callback: ", err)
		return "psn-create-player-session"
	end
	
	local err, psn_session_id = PSNCreatePlayerSession_Zulu(game_type, game_name, game_id, visible_to, info, max_players)
	if err then 
		PSNClearContextAndCallbacks()
		msg:Close()
		return "psn-create-player-session"
	end
	
	if game_id then
		local err, result = PSNSetPlayerSessionInfo(psn_session_id, "customData1", tostring(game_id))
		if err then 
			PSNClearPlayerSession(psn_session_id)
			msg:Close()
			playstation_print("Failed to set player session info: ", err)
			return "psn-create-player-session"
		end
	end
	
	info.psn_session_id = psn_session_id
	
	msg:Close()
	return false, psn_session_id
end

function PlatformJoinMultiplayerGame(game_info, game_address)
	playstation_print("----------------------------------------------------------- PlatformJoinMultiplayerGame")
	local err = PSNPrepareContextAndCallbacks()
	if err then
		playstation_print("Failed to create push context and callback: ", err)
		return "psn-join-player-session-fail"
	end
	
	local err, result = PSNJoinPlayerSessionAsPlayer(game_info.psn_session_id)
	if err then
		return "psn-join-player-session"
	end
end

function PSNPlayerSessionEvent_SessionDeleted(json_data)
	if not netInGame then return end
	
	local err, data = JSONToLua(json_data)
	if err then return err end
	
	if netInGame and netGameInfo.psn_session_id == data then
		NetLeaveGame("psn-player-session-deleted")
		OnGuestForceLeaveGame("psn-player-session-deleted")
	end
end

function PSNPlayerSessionEvent_PlayerDeleted(json_data)
	if not netInGame then return end
	
	CreateRealTimeThread(function()
		local err, data = JSONToLua(json_data)
		if err then return err end
		
		local err, account_id = PlayStationGetUserAccountId()
		if err then return err end -- What to do in this situation? Could be safer to simply disconnect
		if data.member.players[1].accountId == account_id then
			NetLeaveGame("psn-player-session-kicked")
			OnGuestForceLeaveGame("psn-player-session-kicked")
		end
	end)
end

function OnMsg.NetGameLeft(reason, netGameInfo)
	PlayStationStopNotifyMultiplayer()
	playstation_print("--- StopNotifyMultiplayer")
	CreateRealTimeThread(function()
		if netGameInfo.psn_session_id then
			PSNClearPlayerSession(netGameInfo.psn_session_id)
		else
			playstation_print("psn_session_id not found")
		end
	end)
end

function OnMsg.NetGameInfo(info)
	if info.psn_session_id then
		netGameInfo.psn_session_id = info.psn_session_id
	end
end

function OnMsg.NetPlayerLeft(player, reason)
	if #netGamePlayers > 1 then return end
	PlayStationStopNotifyMultiplayer()
	playstation_print("--- StopNotifyMultiplayer")
end


function OnMsg.NetGameLoaded()
	CreateRealTimeThread(function()
		WaitLoadingScreenClose()
		
		local introDlg = GetDialog("Intro")
		if introDlg then
			introDlg:Wait()
		end
		
		if not netInGame or not Game or #netGamePlayers <= 1 then return end
		local property = "realtime-multi"
		for _, player in ipairs(netGamePlayers) do
			if netUniqueId ~= player.id then
				if not (player.platform == "playstation" or player.platform == "ps5" or player.platform == "ps4") then property = "realtime-cross" end
			end
		end
		PlayStationStartNotifyMultiplayer(property)
		playstation_print("--- StartNotifyMultiplayer (NetGameLoaded): " .. property)
	end)
end

-------------------[ Connection ]---------------------

function OnMsg.PlayStationSigninChanged(signed_in)
	if signed_in then return end
	if NetIsConnected() then NetDisconnect(nil, "psn-signout") end
end

-------------------[ Player Sessions ]---------------------

function PSNCreatePlayerSession_Zulu(game_type, game_name, game_id, visible_to, info, max_players)
	local players = {}
	table.insert(players, {
		accountId = "me",
		platform = "me",
		pushContexts = { { pushContextId = PlayStationCurrentPushContextId() } }
	})
	
	local localizedText = {}
	localizedText["en-US"] = game_name --!TODO: do we need to have translated names, here, because of unsupported characters/fonts?
	
	local playerSessions = {}
	table.insert(playerSessions,{
		maxPlayers = max_players,
		member = {
			players = players
		},
		supportedPlatforms = { "PS5", "PS4" },
		localizedSessionName = {
			defaultLanguage = "en-US",
			localizedText = localizedText
		},
		disableSystemUiMenu = { "PROMOTE_TO_LEADER", "UPDATE_JOINABLE_USER_TYPE", "UPDATE_INVITABLE_USER_TYPE" },
		swapSupported = false,
		nonPsnSupported = false,
		joinableUserType = (visible_to == "private") and "SPECIFIED_USERS" or "ANYONE",
	})
	
	local body = {
		playerSessions = playerSessions,
	}
	
	return PSNCreatePlayerSession(game_name, visible_to, body)
end

-------------------[ Game Intents ]---------------------

function PlayStationGetHostNameAndSwarmAddressFromSessionId(psn_session_id)
	local err, result = PSNGetPlayerSessionInfo(psn_session_id, {"@default", "customData1"})
	if err then return err end
	
	local err, data = JSONToLua(result)
	if err then return err end
	
	if not data or not data.playerSessions[1] then 
		playstation_print("No data in Player Session.")
		return "game not found" 
	end
	
	local game_address = data.playerSessions[1].customData1
	if not game_address then 
		playstation_print("No game_address found in player session data")
		return "game not found"
	end
	game_address = Decode64(game_address)
	
	local host_name = data.playerSessions[1].leader and data.playerSessions[1].leader.onlineId
	if not host_name then 
		playstation_print("No host_name found in player session data")
		return "game not found"
	end
	
	return false, host_name, game_address
end

function PlayStationJoinSessionIntent(psn_session_id)
	if not CanYield() then
		playstation_print("Reading game intent as <Join Session>. Session_id: " .. tostring(psn_session_id))
		CreateRealTimeThread(PlayStationJoinSessionIntent, psn_session_id)
		return
	end
	
	local err = PlatformCheckMultiplayerRequirements()
	if err then 
		ShowMPLobbyError("join", err)
		return 
	end
	
	local msg = CreateUnclickableMessagePrompt(T(908809691453, "Multiplayer"), T(994790984817, "Connecting..."))
	
	local host_name, game_address
	for i=1,3 do
		err, host_name, game_address = PlayStationGetHostNameAndSwarmAddressFromSessionId(psn_session_id)
		Sleep(2000)
		if not err then goto continue end
	end
	::continue::
	msg:Close()
	if err then 
		ShowMPLobbyError("connect", err)
		return
	end
	
	local err = MultiplayerConnect()
	if err then 
		ShowMPLobbyError("connect", err)
		return
	end
	
	UIReceiveInvite(host_name, nil, tonumber(game_address), "CoOp", nil)
end