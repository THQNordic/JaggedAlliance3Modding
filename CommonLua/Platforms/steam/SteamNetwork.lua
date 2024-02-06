if FirstLoad then
	threadSteamGetAppTicket = false
end

config.NetCheckUpdates = false

function ProviderName()
	return "steam"
end

function PlatformGetProviderLogin(official_connection)
	local err, auth_provider, auth_provider_data, display_name
	
	if not IsSteamLoggedIn() then
		DebugPrint("IsSteamLoggedIn() failed\n")
		return "steam-auth"
	end

	auth_provider = "steam"
	display_name = SteamGetPersonaName()
	if not display_name then
		DebugPrint("SteamGetPersonaName() failed\n")
		return "steam-auth"
	end
	while threadSteamGetAppTicket do -- wait any other calls to AsyncSteamGetAppTicket
		Sleep(10)
	end
	threadSteamGetAppTicket = CurrentThread() or true
	err, auth_provider_data = AsyncSteamGetAppTicket(tostring(display_name))
	assert(threadSteamGetAppTicket == (CurrentThread() or true))
	threadSteamGetAppTicket = false

	if err then 
		DebugPrint("AsyncSteamGetAppTicket() failed: " .. err .. "\n")
		return "steam-auth" 
	end
	
	return err, auth_provider, auth_provider_data, display_name
end