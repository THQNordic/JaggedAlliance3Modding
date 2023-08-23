if not Platform.steam_thq_wrapper then return end

function ProviderName()
	return THQSteamWrapperGetPlatform() or "steam"
end

function SteamIsWorkshopAvailable()
	return (ProviderName() == "steam") and IsSteamAvailable()
end

function PlatformGetProviderLogin(official_connection)
	local err, auth_provider, auth_provider_data, display_name

	auth_provider = ProviderName()
	display_name = SteamGetPersonaName()
	if not display_name then
		DebugPrint("SteamGetPersonaName() failed\n") 
		return "steam-auth"
	end

	if auth_provider == "gog" then
		while threadSteamGetAppTicket do -- wait any other calls to AsyncSteamGetAppTicket
			Sleep(1)
		end
		
		threadSteamGetAppTicket = CurrentThread() or true
		err, auth_provider_data = AsyncTHQSteamGetGogEncryptedAppTicket(Encode64(display_name))
		assert(threadSteamGetAppTicket == (CurrentThread() or true))
		threadSteamGetAppTicket = false
		
		if err then 
			return "gog-auth" 
		end
	elseif auth_provider == "steam" then
		if not IsSteamLoggedIn() then
			DebugPrint("IsSteamLoggedIn() failed\n")
			return "steam-auth"
		end

		while threadSteamGetAppTicket do -- wait any other calls to AsyncSteamGetAppTicket
			Sleep(1)
		end
		threadSteamGetAppTicket = CurrentThread() or true
		err, auth_provider_data = AsyncSteamGetAppTicket(tostring(display_name))
		assert(threadSteamGetAppTicket == (CurrentThread() or true))
		threadSteamGetAppTicket = false

		if err then 
			DebugPrint("AsyncSteamGetAppTicket() failed: " .. err .. "\n")
			return "steam-auth" 
		end
	elseif auth_provider == "epic" then
		local active_epic_user = THQSteamWrapperGetPlatformPlayerId()
		if not active_epic_user then
			DebugPrint("THQSteamWrapperGetPlatformPlayerId/epic failed")
			return "epic-auth"
		end
		
		local err, _, login_token = AsyncTHQSteamGetEpicToken()
		if err then
			DebugPrint("AsyncTHQSteamGetEpicToken() failed: " .. err .. "\n")
			return "epic-auth"
		end
		
		auth_provider_data = { active_epic_user, login_token, true }
	else
		return "unknown-auth"
	end

	return err, auth_provider, auth_provider_data, display_name
end

if THQSteamWrapperGetPlatform() ~= "steam" then
	_InternalFilterUserTexts = _DefaultInternalFilterUserTexts
end