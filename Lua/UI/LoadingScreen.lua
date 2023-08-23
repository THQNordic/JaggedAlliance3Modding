DefineClass.ZuluBaseLoadingScreen = {
	__parents = { "BaseLoadingScreen" },
	MouseCursor = "UI/Cursors/Loading.tga",
}

DefineClass.ZuluLoadingScreen = {
	__parents = { "ZuluBaseLoadingScreen" },
	FadeOutTime = 300,
 	Background = RGB(0, 0, 0),
}

GameVar("g_LoadingHintsSeen",{})
GameVar("g_LoadingHintsNextIdx",1)

if FirstLoad then
	g_DbgAutoClickLoadingScreenStart = Platform.developer and 1000 or false
	g_SplashScreen = "UI/SplashScreen"
	g_LoadingScreen = "UI/LoadingScreens/LoadingScreen"
	g_DefaultLoadingScreen = g_SplashScreen	
end	

function OnMsg.GameTestsBegin()
	g_DbgAutoClickLoadingScreenStart = Platform.developer and 1
end

function OnMsg.GameTestsEnd()
	g_DbgAutoClickLoadingScreenStart = Platform.developer and 1000 or false
end

--loading screen sync
table.insert(BlacklistedDialogClasses, "XZuluLoadingScreen")
local function OnLocalPlayerClicked()
	local dlg = GetDialog("XZuluLoadingScreen")
	if dlg then
		dlg.idStart:SetText(T(797976655881, "Ready"))
		PlayFX("Loadingscreen","StartPopup")
	end
end
local function InitLSClickSync()
	if not IsInMultiplayerGame() then return end
	InitPlayersClickedSync("LoadingScreen", 
		function() --on done waiting
			--LoadingScreenClose sleeps, which can pause the event dispatcher, hence in sep thread
			CreateGameTimeThread(LoadingScreenClose, "idLoadedLoadingScreen", "sync")
		end,
		function(player_id) --on player clicked
			if player_id == netUniqueId then
				OnLocalPlayerClicked()
			end
		end)
end

function SectorLoadingScreenOpen(id, reason, sector, metadata)
	LoadingScreenOpen(id, reason, sector, metadata)
	InitLSClickSync()
	if not sector then return end
	
	local dlg = GetDialog("XZuluLoadingScreen")
end

function SectorLoadingScreenClose(id, reason, sector)	
	if sector then
		local dlg = GetDialog("XZuluLoadingScreen")
		if dlg then
			local context = dlg:GetContext()
			if not context.loaded then
				dlg:DeleteThread("loading anim")
				dlg:SetContext(SubContext(context, {loaded = true, hint = dlg.idHint:GetText()}))		
				dlg.idStart:SetText(T(517032475186, "Start"))
				dlg:SetMouseCursor("UI/Cursors/Cursor.tga")
				PlayFX("Loadingscreen","StartPopup")
				LoadingScreenOpen("idLoadedLoadingScreen", "loaded")
				if IsInMultiplayerGame() then
					if IsWaitingForPlayerToClick(netUniqueId, "LoadingScreen") then
						LoadingScreenOpen("idLoadedLoadingScreen", "sync")
					else
						OnLocalPlayerClicked() --in case ls wasn't up yet
					end
				end
			end
		end
	end	
	LoadingScreenClose(id, reason)
	Msg("SectorLoadingScreenClosed")
end

local old_LoadingScreenClose = LoadingScreenClose
function LoadingScreenClose(id, reason)
	if reason == "pregame menu" then
		g_DefaultLoadingScreen = g_LoadingScreen
		g_DbgAutoClickLoadingScreenStart = false
	elseif reason == "loaded" then
		LocalPlayerClickedReady("LoadingScreen")
	end
	return old_LoadingScreenClose(id, reason)
end

g_SatelliteLoadingScreens = false
g_SatelliteLoadingScreens4k = false

function GetSatelliteLoadingScreen(campaign_folder, b_4k)
	if not g_SatelliteLoadingScreens then
		local err, screens = AsyncListFiles(campaign_folder, "SatelliteView*")
		if err then return end
		
		g_SatelliteLoadingScreens  = g_SatelliteLoadingScreens or {}
		g_SatelliteLoadingScreens4k  = g_SatelliteLoadingScreens4k or {}
		for i, s in ipairs(screens) do
			local path, filename = SplitPath(s)
			local item = path .. filename
			if filename:ends_with(".4k") then
				g_SatelliteLoadingScreens4k[#g_SatelliteLoadingScreens4k + 1] = item
			else
				g_SatelliteLoadingScreens[#g_SatelliteLoadingScreens + 1] = item
			end
		end
	end
	local tbl = g_SatelliteLoadingScreens
	if b_4k and next(g_SatelliteLoadingScreens4k) then
		tbl = g_SatelliteLoadingScreens4k
	end
	return table.rand(tbl)
end

function LoadingScreenGetClassById(id)
	if id == "idSaveProfile" then
		return "BaseSavingScreen"
	elseif id == "idAutosaveScreen" then
		return "AutosaveScreen"
	elseif id == "idQuickSaveScreen" then
		return "QuickSaveScreen"
	end
	return "XZuluLoadingScreen"
end

function GetLoadingScreenParamsFromMetadata(metadata, reason)
	local id = metadata and metadata.satellite and "idSatelliteView" or "idLoadingSavegame"
	local tip = metadata and not metadata.satellite and metadata.sector
	return id, reason or "load savegame", tip, metadata
end
