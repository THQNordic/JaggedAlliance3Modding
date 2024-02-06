function NetRecord(label, ...)
	if not config.SwarmConnect then return end
	local _, context = ...
	local rec = Serialize(LuaRevision, os.time(), label, ...)
	CreateRealTimeThread(function(rec, context)
		local err = NetCall("rfnRec", Unserialize(rec))
		--do not try to save the account storage if the error originated from trying to save it in the first place
		if err and rawget(_G, "AccountStorage") and context ~= "account save" then
			AccountStorage.NetRecord = AccountStorage.NetRecord or {}
			AccountStorage.NetRecord[#AccountStorage.NetRecord + 1] = rec
			if #AccountStorage.NetRecord > 100 then
				table.remove(AccountStorage.NetRecord, 1)
			end
			SaveAccountStorage(30000)
		end
	end, rec, context)
end

-- log the most recent crash files to the server
function LogLatestCrash()
	if not (Platform.pc or Platform.osx or Platform.linux) or g_bCrashReported then return end
	-- find the most recent one
	g_bCrashReported = true
	local crash_files, latest_crash_file, latest_crash_date = GetCrashFiles("*.crash")
	if not latest_crash_file then
		return
	end
	local err, crash_log = AsyncFileToString(latest_crash_file)
	if err then
		return
	end
	
	local filename = tostring(latest_crash_date or os.date("!%d %b %Y %H:%M:%S"))
	NetLogFile("crash", filename, "crash", crash_log)
	
	if Platform.osx then
		local reports_dir = "/Users/" .. GetUsername() .. "/Library/Logs/DiagnosticReports"
		local reports_pattern = GetExecName() .. "_*.crash"
		local _, reports = AsyncListFiles(reports_dir, reports_pattern, "recursive,modified")
		reports = reports or {}
		
		for i=1, #(reports.modified or "") do
			reports.modified[i] = reports.modified[i] - latest_crash_date
		end
		
		local _, report_index = table.min(reports.modified or "")
		local report = reports[report_index] or ""
		
		local _, report_dump = AsyncFileToString(report)
		NetLogFile("crash", filename, "xdmp", report_dump)
		AsyncFileDelete(reports)
	else
		local dump_ext = Platform.linux and "ldmp" or "dmp"
		local dump_file = string.gsub(latest_crash_file, "%.crash$", "." .. dump_ext)--gsub returns 2 results, do not pass as function argument!!!
		local _, crash_dump = AsyncFileToString(dump_file)
		NetLogFile("crash", filename, dump_ext, crash_dump)
	end
	
	if #crash_files > 0 then
		NetGossip("Crashes",  #crash_files)	
	end
	EmptyCrashFolder()
end

function OnMsg.NetConnect()
	CreateRealTimeThread(function()
		local display = GetMainWindowDisplayIndex()
		NetGossip("Hardware", GetHardwareInfo(EngineOptions.GraphicsApi, EngineOptions.GraphicsAdapterIndex), GetFullEngineOptions())
		LogLatestCrash()
		if rawget(_G, "AccountStorage") and AccountStorage.NetRecord and AccountStorage.NetRecord[1] then
			while AccountStorage.NetRecord[1] do
				local err = NetCall("rfnRec", Unserialize(AccountStorage.NetRecord[1]))
				if err == "disconnected" then break end
				table.remove(AccountStorage.NetRecord, 1)
			end
			SaveAccountStorage(30000)
		end
	end)
end

if FirstLoad then
	g_TryConnectToServerThread = false
end

-- config.SwarmConnect can be false, "ping" or "reconnect"
function TryConnectToServer()
	if Platform.cmdline then return end
	g_TryConnectToServerThread = g_TryConnectToServerThread or CreateRealTimeThread(function()
		WaitInitialDlcLoad()
		while not AccountStorage do
			WaitMsg("AccountStorageChanged")
		end
		if Platform.xbox then
			WaitMsg("XboxUserSignedIn")
		end
		local wait = 60*1000
		while config.SwarmConnect do
			if not NetIsConnected() then
				local err, auth_provider, auth_provider_data, display_name = NetGetProviderLogin(false)
				if err then
					err, auth_provider, auth_provider_data, display_name = NetGetAutoLogin()
				end
				err = err or NetConnect(config.SwarmHost, config.SwarmPort, 
					auth_provider, auth_provider_data, display_name, config.NetCheckUpdates, "netClient")
				if err == "failed" or err == "version" then -- if we cannot login with these credentials stop trying
					return
				end
				if not err and config.SwarmConnect == "ping" or err == "bye" then
					NetDisconnect("netClient")
					return
				end
				wait = wait * 2 -- double the wait time on fail
				if err == "maintenance" or err == "not ready" then
					wait = 5*60*1000 -- wait exactly 5 mins if servers are not ready
				end
			end
			if NetIsConnected() then
				wait = 60*1000 -- on success reset the wait time
				if config.SwarmConnect == "ping" then
					NetDisconnect("netClient")
					return
				end
				WaitMsg("NetDisconnect")
			end
			Sleep(wait)
		end
	end)
end