config.NetCheckUpdates = config.NetCheckUpdates and Platform.pc and not Platform.developer

function ContentUpdateDelay()
	return GetMap() ~= ""
end

function OnMsg.ContentUpdate(def, description)
	MsgClear("ContentUpdate")
	netConnectionReasons["UpdateDownload"] = true
	CreateRealTimeThread(function()
		while ContentUpdateDelay() do
			Sleep(1000)
		end
		if not NetIsConnected() then return end
		if "ok" == WaitQuestion( terminal.desktop,
			T(976054118486, "New Update Available"),
			Untranslated(description),
			T(754206455981, "Download & Install"),
			T(967444875712, "Cancel")) 
		then
			AsyncCreatePath("AppData/Updates")
			local filename = string.format("AppData/Updates/%s", def.name)
			DebugPrint("Downloading update " .. filename)
			local err = NetDownloadContent(filename, def)
			NetDisconnect("UpdateDownload")
			if err then
				DebugPrint("Download failed " .. err)
				WaitMessage(terminal.desktop, T(727906756499, "Download error"), T(937469723848, "Download failed, please try again later."))
				return
			end
			if Platform.pc then
				DebugPrint("Starting update" .. filename)
				Msg("ContentUpdateStart", filename)
				NetForceDisconnect("Update")
				Sleep(200)
				os.exec(ConvertToOSPath(filename))
				quit()
			else
				DebugPrint("Cannot start update" .. filename)
			end
		end
	end)
end