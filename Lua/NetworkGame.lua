local old_NetWaitGameStart = NetWaitGameStart
g_dbgFasterNetJoin = false --Platform.developer
function NetWaitGameStart(timeout)
	if netGamePlayers and table.count(netGamePlayers) <= 1 then
		--something fucks up in this scenario, when a player has left and we try to load a new game
		--server never starts the game even though we say we are ready
		NetGameSend("rfnStartGame")
		netDesync = false
		return false --not an error
	end
	return old_NetWaitGameStart(timeout)
end

local shield_vars = {}
local orig_cbs = {}

function OnMsg.ChangeMap()
	shield_vars = {}
end

--fire the ev once until cb fires and only on host
function FireNetSyncEventOnHostOnce(event, ...)
	if netInGame and not NetIsHost() then return end
	FireNetSyncEventOnce(event, ...)
end

function FireNetSyncEventOnce(event, ...)
	--sanity checks
	--if IsChangingMap() then return end --some events are fired before change map finishes..
	if GetMapName() == "" then return end
	if GameReplayScheduled then return end --dont play these events when waiting for record to start or they get played twice
	--if netGameInfo and netGameInfo.started == false then return end
	
	local shieldVarName = string.format("%s%d_fired", event, xxhash(Serialize(...)))
	local svv = shield_vars[shieldVarName]
	local time = AdvanceToGameTimeLimit or GameTime()
	if svv and time - svv < 1500 then return end
	
	orig_cbs[event] = orig_cbs[event] or NetSyncEvents[event]
	NetSyncEvents[event] = function(...)
		--print("FireNetSyncEventOnce received", event)
		shield_vars[shieldVarName] = nil
		NetSyncEvents[event] = orig_cbs[event]
		orig_cbs[event] = nil
		NetSyncEvents[event](...)
	end
	
	shield_vars[shieldVarName] = time
	--print("FireNetSyncEventOnce fire", event, GameTime(), AdvanceToGameTimeLimit, svv)
	NetSyncEvent(event, ...)
end

function IsInMultiplayerGame()
	return netInGame and table.count(netGamePlayers) > 1
end

function GetOtherNetPlayerInfo()
	local otherPlayer = netUniqueId == 1 and 2 or 1
	return netGamePlayers[otherPlayer]
end

function LoadNetGame(game_type, game_data, metadata)
	local success, err = sprocall(_LoadNetGame, game_type, game_data, metadata)
	return not success and err or false
end

function _LoadNetGame(game_type, game_data, metadata)
	assert(game_type == "CoOp")
	--why is this here:
	--when client is catching up to host this code will execute before sync part has finished executing
	--the code before the second fence changes game state and this will cause the already finished game to desync
	--this seems the easiest solution in this case, to wait for sync part to finish up and then load
	NetSyncEventFence()
	
	SectorLoadingScreenOpen(GetLoadingScreenParamsFromMetadata(metadata))
	WaitChangeMapDone()
	
	Msg("PreLoadNetGame")
	CloseBlockingDialogs()
	ResetZuluStateGlobals()
	
	Sleep(10) --give ui time to close "gracefully"...
	assert(game_data and #game_data > 0)
	NetSyncEventFence("init_buffer")
	NetStartBufferEvents()
	local err = LoadGameSessionData(game_data, metadata)
	NetStopBufferEvents()
	if not err then
		Msg("NetGameLoaded")
	end
	SectorLoadingScreenClose(GetLoadingScreenParamsFromMetadata(metadata))
end

function NetEvents.LoadGame(game_type, game_data, metadata)
	CreateRealTimeThread(function()
		-- if not netInGame then return end -- !TODO: very narrow timing issue, player may leave game just before this is run
		assert(netInGame)
		local err = LoadNetGame(game_type, Decompress(game_data), metadata)
		err = err or NetWaitGameStart()
		if err then
			NetLeaveGame(err)
			print("LoadNetGame failed:", err)
			OpenPreGameMainMenu("")
		end
	end)
end

function OnMsg.ResetGameSession()
	NetLeaveGame("ResetGameSession")
end

function OnMsg.NetGameJoined(game_id, unique_id)
	if Game and NetIsHost() then
		NetGameSend("rfnStartGame")
		AdvanceToGameTimeLimit = GameTime()
	end
end

function StartHostedGame(game_type, game_data, metadata)
	assert(NetIsHost())
	LoadingScreenOpen(GetLoadingScreenParamsFromMetadata(metadata, "host game"))
	if IsChangingMap() then
		WaitMsg("ChangeMapDone", 5000)
	end
	NetGameCall("rfnStopGame")
	Pause("net")
	if not string.starts_with(game_data, "return") then
		game_data = "return " .. game_data
	end
	local err = NetEvent("LoadGame", game_type, Compress(game_data), metadata)
	if err then
		print("NetEvent failed:", err)
	else
		err = LoadNetGame(game_type, game_data, metadata)
		if err then
			print("LoadNetGame failed:", err)
			OpenPreGameMainMenu("")
		else
			--TODO: enter sector already calls this, so if it timeouted there its gona have to timeout here as well before we actually do something
			err = NetWaitGameStart()
			if err then
				print("NetWaitGameStart failed:", err)
				OpenPreGameMainMenu("")
			end
		end
	end
	if err then NetLeaveGame("host error") end
	Resume("net")
	LoadingScreenClose(GetLoadingScreenParamsFromMetadata(metadata, "host game"))
	return err
end

PlatformCreateMultiplayerGame = rawget(_G, "PlatformCreateMultiplayerGame") or empty_func
PlatformJoinMultiplayerGame = rawget(_G, "PlatformJoinMultiplayerGame") or empty_func

function HostMultiplayerGame(visible_to)
	local err = MultiplayerConnect()
	if err then
		ShowMPLobbyError("connect", err)
		return err
	end

	local mods = g_ModsUIContextObj or ModsUIObjectCreateAndLoad()
	while not g_ModsUIContextObj or not g_ModsUIContextObj.installed_retrieved do
		Sleep(100)
	end
	local enabledMods = {}
	for mod, enabled in pairs(mods.enabled) do
		if enabled then
			local modDef = {
				luaRev = mods.mod_defs[mod].lua_revision,
				title = mods.mod_defs[mod].title,
				steamId = mods.mod_defs[mod].steam_id,
			}
			table.insert(enabledMods, modDef)
		end
	end
	
	local game_name = netDisplayName .. "'s game"
	local game_type = "CoopGame"
	local max_players = 2
	local info = {
		map = GetMapName(),
		campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds",
		mods = enabledMods,
		day = Game and TFormat.day() or 1,
		host_id = netAccountId,
		name = game_name,
		platform = Platform,
	}
	
	local err = PlatformCreateMultiplayerGame(game_type, game_name, nil, visible_to, info, max_players)
	if err then
		return err
	end
	
	local err, game_id = NetCall("rfnCreateGame", "CoopGame", "coop", game_name, visible_to, info, max_players)
	if err then
		return err
	end
	
	err = NetJoinGame(nil, game_id)
	if err then
		print("NetJoinGame", err)
		return err
	end
end

function MultiplayerConnect()
	if NetIsOfficialConnection() then return end

	local msg = CreateUnclickableMessagePrompt(T(908809691453, "Multiplayer"), T(994790984817, "Connecting..."))

	local err, auth_provider, auth_provider_data, display_name, developerMode = NetGetProviderLogin()
	if err then
		msg:Close()
		return err
	end
	
	if auth_provider == "auto" and not developerMode then
		msg:Close()
		return "unknown-auth"
	end
	
	-- It is possible to reach this NetConnect while being already connected but NetIsOfficialConnection == false
	-- due to the auto-connect thread. In this case we want to force a disconnection since NetConnect will not attempt to
	-- make a new official connection otherwise.
	NetForceDisconnect() 
	local err = NetConnect(config.SwarmHost, config.SwarmPort, auth_provider, auth_provider_data, display_name, config.NetCheckUpdates)
	msg:Close()
	
	if not err and netRestrictedAccount then
		err = "restricted"
		NetForceDisconnect()
	end
	
	if err then
		print("NetConnect", err)
	end

	return err
end

function AssignMercControl(merc_id, guest)
	if not NetIsHost() then
		return
	end
	local value = not not guest
	NetEchoEvent("AssignControl", merc_id, value)
end

function NetEvents.AssignControl(merc_id, value)
	local unit_data = gv_UnitData and gv_UnitData[merc_id]
	if not unit_data then return end
	local prop_value = value and 2 or 1
	unit_data:SetProperty("ControlledBy", prop_value)
	local unit = g_Units[merc_id]
	if unit then
		unit.ControlledBy = prop_value
		Msg("UnitControlChanged", unit, prop_value)
	else
		Msg("UnitDataControlChanged", unit_data, prop_value)
	end
	ObjModified(unit_data)
end

if FirstLoad then
	g_CoOpReadyToEnd = false
end

function NetSyncEvents.CoOpReadyToEndTurn(player_id, isReady)
	if not g_CoOpReadyToEnd then g_CoOpReadyToEnd = {} end

	g_CoOpReadyToEnd[player_id] = isReady
	if player_id == netUniqueId then
		ObjModified(SelectedObj)
		SelectObj(false)
	end
	
	local endTurnButton = GetInGameInterfaceModeDlg():ResolveId("idTurn")
	if endTurnButton then
		endTurnButton:OnContextUpdate(Selection)
	end
	
	local otherPlayerHasNoLivingUnits = true
	local team = GetCurrentTeam()
	for i, u in ipairs(team.units) do
		if not u:IsDead() and not u:IsLocalPlayerControlled() then
			otherPlayerHasNoLivingUnits = false
			break
		end
	end
	if otherPlayerHasNoLivingUnits then
		NetSyncEvent("EndTurn", netUniqueId)
		return
	end
	
	if not NetIsHost() or #g_CoOpReadyToEnd ~= #netGamePlayers then return end

	for uid, ready in pairs(g_CoOpReadyToEnd) do
		if not ready then
			return
		end
	end
	
	NetSyncEvent("EndTurn", netUniqueId)
end

function FireNetSyncEventOnHost(...)
	if not netInGame or NetIsHost() then
		NetSyncEvent(...)
	end
end

function NetStartBufferEvents()
	--print("start buffering", netBufferedEvents)
	netBufferedEvents = netBufferedEvents or {}
	--print("start buffering", netBufferedEvents)
end
--------------------------------------------------------
--synced clickage on uis and things common impl.
--------------------------------------------------------
--TODO: this needs a different pattern
--sooner or later players_clicked_premature_events gets leaked for the next time
--and there is not good time to reset it
--i guess it should start with a sync event maybe so both players can init
if FirstLoad then
	players_clicked_sync = false
	players_clicked_hooks = false
end

function ClickSyncDump()
	print(players_clicked_sync)
end

function InitPlayersClickedSync(reason, on_done_waiting, on_player_clicked)
	assert((netInGame and next(netGamePlayers)) or IsGameReplayRecording() or IsGameReplayRunning())
	--print("----------InitPlayersClickedSync", reason)
	players_clicked_sync = players_clicked_sync or {}
	players_clicked_hooks = players_clicked_hooks or {}
	players_clicked_sync[reason] = {}
	players_clicked_hooks[reason] = {["on_done_waiting"] = on_done_waiting, ["on_player_clicked"] = on_player_clicked}
	local t = players_clicked_sync[reason]
	for _, data in pairs(netGamePlayers) do
		t[data.id] = false
	end
end

function HaveAllPlayersClicked(reason)
	if not players_clicked_sync then return true end
	local t = players_clicked_sync[reason]
	if not t then return true end
	
	for _, v in pairs(t) do
		if not v then
			return false
		end
	end
	return true
end

function DoneWaitingForPlayersToClick(reason)
	if players_clicked_sync and players_clicked_sync[reason] then
		players_clicked_sync[reason] = nil
		local hooks = players_clicked_hooks[reason]
		players_clicked_hooks[reason] = nil
		if hooks.on_done_waiting then
			hooks.on_done_waiting()
		end
	end
end

function OnMsg.NetGameLeft(reason)
	for click_reason, data in pairs(players_clicked_sync or empty_table) do
		DoneWaitingForPlayersToClick(click_reason)
	end
end

function OnMsg.NetPlayerLeft(player, reason)
	for click_reason, data in sorted_pairs(players_clicked_sync or empty_table) do
		--this might not work for more than 2 players depending on how sync NetPlayerLeft is
		data[player.id] = nil
		if HaveAllPlayersClicked(click_reason) then
			DoneWaitingForPlayersToClick(click_reason)
		end
	end
end

function NetSyncEvents.PlayerClickedReady(player_id, reason, event_id)
	--print("NetSyncEvents.PlayerClickedReady", player_id, reason)
	if not PlayersClickedSync_IsInitializedForReason(reason) then
		return
	end
	local t = players_clicked_sync[reason]
	if t[player_id] ~= false then return end
	
	t[player_id] = true
	local all_clicked = HaveAllPlayersClicked(reason)
	
	if all_clicked then
		DoneWaitingForPlayersToClick(reason)
	else
		local hooks = players_clicked_hooks[reason]
		if hooks.on_player_clicked then
			hooks.on_player_clicked(player_id, t)
		end
	end
end

function IsWaitingForPlayerToClick(player_id, reason)
	if players_clicked_sync then
		if players_clicked_sync[reason] then
			return players_clicked_sync[reason][player_id] == false
		end
	end
	return false
end

function PlayersClickedSync_IsInitializedForReason(reason)
	if players_clicked_sync then
		if players_clicked_sync[reason] then
			return true
		end
	end
	return false
end

function LocalPlayerClickedReady(reason)
	--wait for netGameInfo.started, since it could go out 2 early and appear on only 1 client
	if netGameInfo.started and IsWaitingForPlayerToClick(netUniqueId, reason) then
		--TODO: on one hand, i dont like the player spamming net with clicks
		--on the other, event can get lost n shit;
		NetSyncEvent("PlayerClickedReady", netUniqueId, reason)
	end
end

--------------------------------------------------
--common outro/intro
--------------------------------------------------
local function lCloseSyncedDlg(self, msg)
	if self.window_state ~= "destroying" and self.window_state ~= "closing" then
		self:Close()
		Msg(msg)
	end
end

local function lOnPlayerClickedSyncDlg(self, player_id, data) --on player clicked
	if not self.idSkipHint:GetVisible() then
		self.idSkipHint:SetVisible(true)
	end
	if data[netUniqueId] then
		self.idSkipHint:SetText(T(221873989540, "Waiting for the other player..."))
	else
		self.idSkipHint:SetText(T{181264542969, "<Count>/<Total> players skipped the cutscene", Count = table.count(data, function(k, v) return v end), Total = table.count(netGamePlayers)})
	end
end
--------------------------------------------------
--outro impl
--------------------------------------------------
function ComicOnShortcut(self, shortcut, source, ...)
	if RealTime() - self.openedAt < 500 then return "break" end
	if RealTime() - terminal.activate_time < 500 then return "break" end
	
	if IsInMultiplayerGame() then
		if shortcut ~= "Escape" and shortcut ~= "ButtonB" and shortcut ~= "MouseL" then return end
		assert(PlayersClickedSync_IsInitializedForReason("Outro"))
		LocalPlayerClickedReady("Outro")
	else
		if not self.idSkipHint:GetVisible() then
			self.idSkipHint:SetVisible(true)
			return "break"
		end
		if shortcut ~= "Escape" and shortcut ~= "ButtonB" and shortcut ~= "MouseL" then return end
		self:Close()
	end
	return "break"
end


function ComicOnOpen(self, ...)
	XDialog.Open(self, ...)
	rawset(self, "openedAt", RealTime())
	
	if GetUIStyleGamepad(nil, self) then
		self.idSkipHint:SetText(T(576896503712, "<ButtonB> Skip"))
	else
		self.idSkipHint:SetText(T(696052205292, "<style SkipHint>Escape: Skip</style>"))
	end
	
	if IsInMultiplayerGame() then
		InitPlayersClickedSync("Outro",
			function() --on done
				OutroClose(self)
			end,
			function(player_id, data) --on player clicked
				lOnPlayerClickedSyncDlg(self, player_id, data)
			end)
	end
end

function OutroClose(self)
	lCloseSyncedDlg(self, "OutroClosed")
end

--------------------------------------------------
--intro impl
--------------------------------------------------
function IntroClose(self)
	lCloseSyncedDlg(self, "IntroClosed")
end

function IntroOnBtnClicked(self)
	if IsInMultiplayerGame() then
		if not PlayersClickedSync_IsInitializedForReason("Intro") then return end --click after end spam
		LocalPlayerClickedReady("Intro")
	else
		IntroClose(self)
	end
	return "break"
end

function IntroOnOpen(self)
	if IsInMultiplayerGame() then
		InitPlayersClickedSync("Intro",
			function() --on done
				IntroClose(self)
			end,
			function(player_id, data) --on player clicked
				lOnPlayerClickedSyncDlg(self, player_id, data)
			end)
	end
end

------------------------------------------------
--synced loaded/loading state and msg
------------------------------------------------
function WaitSyncLoadingDone()
	if GameState.sync_loading then
		WaitGameState({sync_loading = false})
	end
end

function NetSyncEvents.SyncLoadingStart()
	ChangeGameState("sync_loading", true)
end
function NetEvents.SyncLoadingStartEcho()
	local function Dispatch()
		CreateGameTimeThread(function()
			local idx = table.find(SyncEventsQueue, 2, "SyncLoadingStart")
			local t = idx and SyncEventsQueue[idx][1]
			PauseInfiniteLoopDetection("SyncLoadingHack")
			while not GameState.sync_loading and
					IsValidThread(PeriodicRepeatThreads["SyncEvents"]) and
					t == GameTime() do
				WaitAllOtherThreads()
			end
			ResumeInfiniteLoopDetection("SyncLoadingHack")
			ChangeGameState("sync_loading", true)
		end)
	end

	CreateRealTimeThread(function()
		WaitAllOtherThreads()
		local idx = table.find(SyncEventsQueue, 2, "SyncLoadingStart")
		local attempts = 4
		local attempt = 0
		while not idx and not IsChangingMap() do
			--sync event might not have arrived yet, and might still arrive
			Sleep(5)
			idx = table.find(SyncEventsQueue, 2, "SyncLoadingStart")
			attempt = attempt + 1
			if attempt > attempts then
				break
			end
		end
		
		if not idx then
			if not idx then
				Dispatch()
				return
			end
		end
		local ev = idx and SyncEventsQueue[idx]
		local t = ev[1]
		local ts = GameTime()
		--while GameTime() < t and ts <= GameTime() and netGameInfo.started and not IsChangingMap() do
		--netGameInfo.started  makes it fire too early when leaving game to load a new game. that makes some fake desync logs n messages (game is already over);
		while GameTime() < t and ts <= GameTime() and not IsChangingMap() do 
			Sleep(Min(t - GameTime(), 12))
		end
		
		Dispatch()
	end)
end

--function NetSyncEvents.SyncLoadingDone()
function NetSyncEvents.SyncLoadingDone()
	ChangeGameState("sync_loading", false)
	Msg("SyncLoadingDone")
end

function OnMsg.GameStateChanged(changed)
	if not netInGame or NetIsHost() then
		if changed.loading then
			NetSyncEvent("SyncLoadingStart")
			--due to fencing this should no longer be needed, also it causes rare fake desyncs when sync and non sync event are vry temporaly misaligned 
			--NetEchoEvent("SyncLoadingStartEcho") --fallback if we leave map and sync doesnt fire
			
			CreateRealTimeThread(function()
				WaitLoadingScreenClose()
				NetSyncEvent("SyncLoadingDone")
			end)
		end
	end
end

function IsNetGameStarted() --this is not sync!
	return not netInGame or netGameInfo.started
end

------------------------------------------------
--netsync ev on net disconnect watch dog
--tries to recover events potentially lost on net disconnect
------------------------------------------------
if FirstLoad then
	sent_events = {}
	events_sent_while_disconnecting = {}
	disconnecting = false
end

function OnMsg.NewMap()
	--in case our dispatcher gets killed due to map change this can hang to true
	disconnecting = false
end

local function DispatchList(lst)
	for i = 1, #lst do
		NetSyncEvent(lst[i][1], unpack_params(lst[i][2]))
	end
	table.clear(lst)
end

function OnMsg.ClassesGenerate()
	local orig_func = _G["NetSyncEvent"]
	_G["NetSyncEvent"] = function(event, ...)
		if netInGame or disconnecting then
			sent_events[#sent_events + 1] = {event, pack_params(...)}
			if disconnecting then
				return
			end
		end
		orig_func(event, ...)
	end
end

local function findFirstSentEvent(event)
	for i = 1, #sent_events do
		if sent_events[i][1] == event then
			return i
		end
	end
end

function OnMsg.SyncEvent(event, ...)
	if not disconnecting and not netInGame then
		return
	end
	if #sent_events <= 0 then
		return
	end
	
	local idx = findFirstSentEvent(event)
	if idx then
		if idx ~= 1 then
			--some dropped event exists, possibly due to change map
			table.move(sent_events, idx + 1, #sent_events, 1)
			local to = #sent_events - idx + 1
			for j = #sent_events, to, -1 do
				sent_events[j] = nil
			end
		else
			table.remove(sent_events, idx)
		end
	end
end

function OnMsg.NetDisconnect()
	if #sent_events <= 0 then
		return
	end
	disconnecting = true
	print("Thread Created", #sent_events)
	CreateGameTimeThread(function()
		while #SyncEventsQueue > 0 do
			local t = GetThreadStatus(PeriodicRepeatThreads["SyncEvents"])
			if t > GameTime() then
				Sleep(t - GameTime())
			end
			WaitAllOtherThreads()
			InterruptAdvance()
		end
		disconnecting = false
		print("RE-Sending events", #sent_events)
		DispatchList(sent_events)
	end)
end

--test, kill connection before 5 secs after calling this
local events = 0
local thread = false

function TestDisc()
	DeleteThread(thread)
	events = 0
	thread = CreateRealTimeThread(function()
		for i = 1, 500 do
			NetSyncEvent("Testing", i)
			events = events + 1
			Sleep(10)
		end
	end)
end

function NetSyncEvents.Testing(i)
	events = events - 1
	print("!!!!!!!!!!!!!!!Testing received!", i, events)
end

------------------------------------------
--fence
------------------------------------------

MapVar("g_NetSyncFence", false)
if FirstLoad then
	g_NetSyncFenceWaiting = false
	g_NetSyncFenceInitBuffer = false
end
function OnMsg.SyncLoadingDone()
	if g_NetSyncFenceWaiting then
		return
	end
	FenceDebugPrint("SyncLoadingDone")
	--NetUpdateHash("g_NetSyncFence", not not g_NetSyncFence) --fence can be asynchroniously started (loadnetgame), in which case this may cause a false positive
	g_NetSyncFence = false
end

function NetSyncEvents.FenceReceived(playerId)
	if not g_NetSyncFence then g_NetSyncFence = {} end
	FenceDebugPrint("-------FenceReceived", g_NetSyncFence, playerId)
	g_NetSyncFence[playerId] = true
	
	local eventNotFound = false
	for id, player in pairs(netGamePlayers) do
		if not g_NetSyncFence[id] then
			eventNotFound = true
			break
		end
	end
	
	if not eventNotFound then
		if g_NetSyncFenceInitBuffer then
			StartBufferingAfterFence()
			g_NetSyncFenceInitBuffer = false
		end
		Msg(g_NetSyncFence)
	end
end

function FenceDebugPrint(...)
	--print(...)
	if true then return end
	local args = {...}
	for i, a in ipairs(args) do
		args[i] = tostring(a)
	end
	DebugPrint(table.concat(args, ", ") .. "\n")
end

function StartBufferingAfterFence()
	--we want to start buffering asap after fence
	--basically, all events before the fence are for the current map and all events after the fence are for the next map
	--we don't want to drop any, which may happen if next map events are already scheduled for some reason or another
	NetStartBufferEvents()
	local q = SyncEventsQueue
	for i = 1, #(q or "") do
		--if events are already scheduled after the fence they will get dropped or executed before map change
		--presumably, these events are for the next map, so stick them in the buffer and rem from queue
		--tbh, I never got this to happen so it might not be possible
		local event_data = q[i]
		netBufferedEvents[#netBufferedEvents + 1] = pack_params(event_data[2], event_data[3], nil, nil)
	end
	table.clear(q)
	
	NetGameSend("rfnClearHash") --this clears passed caches stored server side so new hashes @ the same gametime doesn't cause desyncs
	if IsValidThread(PeriodicRepeatThreads["NetHashThread"]) then
		DeleteThread(PeriodicRepeatThreads["NetHashThread"]) --make sure no new hashes come from this map after hash reset
	end
end

-- Ensures that all previous net sync events in flight have been processed by the client
function NetSyncEventFence(init_buffer)
	assert(CanYield())
	
	if IsGameReplayRunning() then
		if not g_NetSyncFence then g_NetSyncFence = {} end
		g_NetSyncFenceWaiting = true
		while not g_NetSyncFence[netUniqueId] do
			WaitMsg(g_NetSyncFence, 100)
		end
		g_NetSyncFenceWaiting = false
		g_NetSyncFence = false
		Msg("ReplayFenceCleared")
		return "replay"
	end
	
	-- The sync event queue is a map thread and wouldn't be running at this point.
	if GetMapName() == "" then
		--print("fence early out")
		return "Not on map"
	end
	-- If threads are stopped we wont get a response so dont bother. Happens with synthetic tests;
	if GetGamePause() then
		--print("fence early out")
		return "Game paused"
	end
	--FenceDebugPrint("FENCE-PRE-PRE-START", GetStack())
	FenceDebugPrint("FENCE PRE-START", g_NetSyncFence, "netGamePlayers count:", table.count(netGamePlayers), g_NetSyncFenceWaiting)
	if not g_NetSyncFence then g_NetSyncFence = {} end
	-- This will queue as the last net sync event, meaning that once it loops back
	-- all previous events would have as well.
	NetSyncEvent("FenceReceived", netUniqueId)
	FenceDebugPrint("FENCE START", g_NetSyncFence)
	local timeout = GetPreciseTicks()
	assert(g_NetSyncFenceWaiting == false)
	g_NetSyncFenceWaiting = true
	g_NetSyncFenceInitBuffer = init_buffer or false
	while IsInMultiplayerGame() or not g_NetSyncFence[netUniqueId] do
		-- Just in case, to prevent endless loading if something goes wrong here
		if GetPreciseTicks() - timeout > 60 * 1000 then
			FenceDebugPrint("NETFENCE TIMEOUT")
			break
		end
	
		local ok = WaitMsg(g_NetSyncFence, 100)
		if ok then 
			FenceDebugPrint("FENCE Msg received")
			break
		end
	end
	g_NetSyncFenceWaiting = false
	g_NetSyncFenceInitBuffer = false
	FenceDebugPrint("FENCE DONE", IsInMultiplayerGame(), (GetPreciseTicks() - timeout))
	assert(not netInGame or #(g_NetSyncFence or "") >= table.count(netGamePlayers))
	g_NetSyncFence = false
end

if Platform.developer and false then
	--this is only valid when fencing change map;
	function OnMsg.ClassesGenerate()
		local f = _G["NetSyncEvent"]
		_G["NetSyncEvent"] = function(event, ...)
			assert(not g_NetSyncFence or event == "FenceReceived", "" .. event .. " fired during fence!")
			return f(event, ...)
		end
	end
end

--------------------------------------- 
--sat view hash check
if Platform.developer then --they play release version..
	local hashes
	
	function OnMsg.InitSatelliteView()
		hashes = false
	end
	
	function OnMsg.ChangeMap()
		hashes = false
	end
	
	function NetSyncEvents.SatDesync(...)
		if not netDesync then
			hashes = false
			NetSyncEvents.Desync(...)
		end
	end
	
	function NetEvents.SyncHashesOnSatMap(player_id, time, hash)
		if netDesync then return end
		hashes = hashes or {}
		hashes[player_id] = hashes[player_id] or {}
		assert(not hashes[player_id][time])
		hashes[player_id][time] = hash
		
		--assumes 2 players
		local h1 = hashes[1] and hashes[1][time]
		local h2 = hashes[2] and hashes[2][time]
		if h1 and h2 then
			hashes = false
			if h1 ~= h2 then
				--print(h1, h2, time)
				NetSyncEvent("SatDesync", netGameAddress, time, player_id, h1, h2)
			end
		end
	end
	
	function OnMsg.NewHour()
		if IsInMultiplayerGame() and not netDesync then
			NetEchoEvent("SyncHashesOnSatMap", netUniqueId, Game.CampaignTime, NetGetHashValue())
		end
	end
end
---------------------------------------
function NetEvents.RemoveClient(id, reason)
	if netUniqueId == id then
		NetLeaveGame(reason or "kicked")
	end
end

---------------------------------------
function OnSatViewClosed()
	if not gv_SatelliteView then return end
	gv_SatelliteView = false
	ObjModified("gv_SatelliteView")
	Msg("CloseSatelliteView")
end

function NetSyncEvents.SatelliteViewClosed()
	OnSatViewClosed()
end

-------------------------------------------
-------------------------------------------
-------------------------------------------

if Platform.developer then

--common stuff
function LaunchAnotherClient(varargs)
	local exec_path = GetExecDirectory() .. "/" .. GetExecName()
	local path = string.format("\"%s\" -no_interactive_asserts -slave_for_mp_testing", exec_path)
	if varargs then
		if type(varargs) == "string" then
			varargs = {varargs}
		end
		for i, v in ipairs(varargs) do
			path = string.format("%s %s", path, v)
		end
	end
	print("os.exec", path)
	os.exec(path)
end

local function lRunErrFunc(func_name, ...)
	local err = _G[func_name](...)
	if err then
		GameTestsPrintf("Function returned an error[" .. func_name .. "]: " .. err)
	end
	return err
end

local function lDbgHostMultiplayerGame()
	return lRunErrFunc("HostMultiplayerGame", "private")
end

function lDbgMultiplayerConnect()
	return lRunErrFunc("MultiplayerConnect")
end

function HostMpGameAndLaunchAndJoinAnotherClient(test_func_name)
	print("HostMpGameAndLaunchAndJoinAnotherClient...")
	Pause("JoiningClients")
	local err = lDbgMultiplayerConnect()
	err = err or lDbgHostMultiplayerGame()
	if err then
		Resume("JoiningClients")
		return err
	end
	local address = netGameAddress
	local varargs = {"-test_mp_game_address=" .. tostring(address)}
	if test_func_name then
		table.insert(varargs, "-test_mp_func_name=" .. test_func_name)
	end
	LaunchAnotherClient(varargs)
	print("Waiting for client!")
	local ok = WaitMsg("NetGameLoaded", 90000)
	Resume("JoiningClients")
	if not ok then
		local err = "Timeout waiting for other client to launch/join!"
		print(err)
		return err
	end
end

function TestCoopNewGame()
	if not IsRealTimeThread() then
		CreateRealTimeThread(TestCoopNewGame)
		return
	end
	
	if not g_MPTestSocket then
		--if no slave client running
		local varargs = {"-test_mp_dont_auto_quit"}
		InitMPTestListener()
		LaunchAnotherClient(varargs)
		if not WaitOtherClientReady() then
			return
		end
	end
	--todo: make a new game start from mm as well
	NetGameCall("rfnStopGame")
	DoneGame()
	CloseMPErrors()
	lDbgMultiplayerConnect()
	lDbgHostMultiplayerGame()
	g_MPTestSocket:Send("rfnJoinMeInGame", netGameAddress)
	if not WaitOtherClientReady() then
		return
	end
	
	ExecCoopStartGame()
end

if FirstLoad then
	TestCoopFuncs = {
	}
	g_MPTestingSlave = false
	g_MPTestingSocketPort = 6666
	g_MPTestListener = false
	g_MPTestSocket = false
end

DefineClass.MPTestSocket = {
	__parents = { "MessageSocket" },
	
	socket_type = "MPTestSocket",
}

function MPTestSocket:CheckHashes()
	--this is for when game is paused and won't work if game not paused
	CreateRealTimeThread(function()
		local hisHash = self:Call("rfnGiveMeYourHash")
		print("Hashes equal:", NetGetHashValue() == hisHash)
	end)
end

function MPTestSocket:rfnGiveMeYourHash()
	return NetGetHashValue()
end

function MPTestSocket:rfnQuit()
	quit()
end

function MPTestSocket:rfnHandshake()
	print("Handshake received")
	if g_MPTestSocket ~= self then
		if IsValid(g_MPTestSocket) then
			g_MPTestSocket:Send("rfnQuit")
			g_MPTestSocket:delete()
		end
		
		g_MPTestSocket = self
	end
	if not g_MPTestSocket then
		g_MPTestSocket = self
		g_MPTestSocket:Send("rfnHandshake")
	else
		assert(g_MPTestSocket == self)
	end
	g_MPTestSocket.master = not g_MPTestingSlave
	g_MPTestSocket.slave = g_MPTestingSlave
end

function WaitOtherClientReady()
	local ok, remote_err = WaitMsg("MPTest_OtherClientReady", 90000)
	if not ok then
		print("Timeout waiting for other client to boot")
	end
	return ok and not remote_err
end

function MPTestSocket:rfnReady(err)
	if err then
		print("rfnReady", err)
	end
	Msg("MPTest_OtherClientReady", err)
end

function MPTestSocket:rfnJoinMeInGame(game_address)
	CreateRealTimeThread(function()
		local err = lDbgMultiplayerConnect()
		err = err or lRunErrFunc("NetJoinGame", nil, game_address)
		if err then
			print("rfnJoinMeInGame", err)
		end
		Sleep(100)
		CloseMPErrors()
		self:Send("rfnReady", err)
	end)
end

function MPTestSocket:rfnTest(...)
	print("rfnTest", ...)
end

function InitMPTestListener()
	if IsValid(g_MPTestListener) then
		g_MPTestListener:delete()
		g_MPTestListener = false
	end
	
	g_MPTestListener = BaseSocket:new{
		socket_type = "MPTestSocket",
	}
	
	local err
	local port_start = g_MPTestingSocketPort
	local port_end = port_start + 100
	
	for port = port_start, port_end do
		err = g_MPTestListener:Listen("*", port)
		if not err then
			g_MPTestListener.port = port
			break
		elseif err == "address in use" then
			print("InitMPTestListener: Address in use. Trying with another port...")
		else
			print("InitMPTestListener: failed", err)
			g_MPTestListener:delete()
			g_MPTestListener = false
			return false
		end
		Sleep(100)
	end
	print("InitMPTestListener Initialized @ port", g_MPTestListener.port)
	return true
end

function MPTestConnectSocket()
	if not IsRealTimeThread() then
		CreateRealTimeThread(MPTestConnectToSlave)
		return
	end
	
	if IsValid(g_MPTestSocket) then
		g_MPTestSocket:delete()
		g_MPTestSocket = false
	end
	
	local err
	local port_start = g_MPTestingSocketPort
	local port_end = port_start + 100
	g_MPTestSocket = MPTestSocket:new()
	
	for port = port_start, port_end do
		err = g_MPTestSocket:WaitConnect(2000, "localhost", port)
		if not err then
			break
		elseif err == "no connection" then
			print("MPTestConnectSocket: not found on port", port, "trying next")
		else
			print("MPTestConnectSocket: failed", err)
			g_MPTestSocket:delete()
			g_MPTestSocket = false
			return false
		end
		Sleep(100)
	end
	
	if not err then
		print("MPTestConnectSocket Connected!")
		g_MPTestSocket:Send("rfnHandshake")
		return true
	else
		print("MPTestConnectSocket Failed to connect!")
		return false
	end
end

function OnMsg.Start()
	if true then return end
	local cmd = GetAppCmdLine()
	local is_slave_for_mp_testing = string.match(GetAppCmdLine() or "", "-slave_for_mp_testing")
	if is_slave_for_mp_testing then
		g_MPTestingSlave = true
		--generic second client entry point
		CreateRealTimeThread(function()
			WaitMsg("ChangeMapDone")
			print("im a slave", GetAppCmdLine())
			
			local address_str = string.match(GetAppCmdLine() or "", "-test_mp_game_address=(%S+)")
			local address = tonumber(address_str)
			
			if address then --if we got game address from cmd line join it
				Pause("JoiningClients")
				assert(address)
				local err
				err = lDbgMultiplayerConnect()
				err = err or lRunErrFunc("NetJoinGame", nil, address)
				if err then
					Sleep(5000)
					quit()
				end
				WaitMsg("NetGameLoaded")
				Resume("JoiningClients")
			end
			
			local test_func_name = string.match(GetAppCmdLine() or "", "-test_mp_func_name=(%S+)")
			if test_func_name then
				local func = TestCoopFuncs[test_func_name]
				if not func then
					print("Could not find test func from test_coop_func_name vararg!")
				else
					sprocall(func)
				end
			end
			
			print("client mp thread done!")
			if g_MPTestSocket then
				g_MPTestSocket:Send("rfnReady")
			end
			local dont_quit = string.match(GetAppCmdLine() or "", "-test_mp_dont_auto_quit")
			if not dont_quit then
				print("Quiting..")
				Sleep(5000)
				quit()
			end
		end)
	end
	if string.match(GetAppCmdLine() or "", "-mp_test_listen") then
		CreateRealTimeThread(InitMPTestListener)
	end
	if string.match(GetAppCmdLine() or "", "-mp_test_connect") then
		CreateRealTimeThread(function()
			Sleep(100) --give time if launching concurently
			MPTestConnectSocket()
		end)
	end
end

function GoToMM()
	if not IsRealTimeThread() then
		print("Not in rtt!")
		return
	end
	Sleep(100)
	OpenPreGameMainMenu()
	Sleep(100)
end

--test all attacks specific stuff
if FirstLoad then
	TestAllAttacksThreads = {
		KillPopupsThread = false,
		WatchDog = false,
		GameTimeProc = false,
		RealTimeProc = false,
	}
end
local function lKillUIPopups()
	Sleep(10)
	DeleteThread(TestAllAttacksThreads.KillPopupsThread)
	TestAllAttacksThreads.KillPopupsThread = CreateRealTimeThread(function()
		while true do
			local dlg = GetDialog("CoopMercsManagement") or GetDialog("PopupNotification")
			if dlg then
				dlg:Close()
			end
			Sleep(200)
		end
	end)
end

local function lTestDone()
	NetLeaveGame()
	NetDisconnect()
	Sleep(500)
	CloseMPErrors()
	print("HostStartAllAttacksCoopTest done")
end

local function lHostWatchDog()
	if IsValidThread(TestAllAttacksThreads.WatchDog) then
		DeleteThread(TestAllAttacksThreads.WatchDog)
	end
	TestAllAttacksThreads.WatchDog = CreateRealTimeThread(function()
		while TestAllAttacksTestRunning do
			if netDesync then
				GameTestsError("Test desynced!")
				break
			end
			if table.count(netGamePlayers) ~= 2 then
				GameTestsError("Client player left before test was done!")
				break
			end
			Sleep(250)
		end
		while IsChangingMap() do
			WaitMsg("ChangeMapDone")
		end
		
		DeleteThread(TestAllAttacksThreads.KillPopupsThread)
		DeleteThread(TestAllAttacksThreads.RealTimeProc)
		DeleteThread(TestAllAttacksThreads.GameTimeProc)
		
		lTestDone()
	end)
end

function HostStartAllAttacksCoopTest()
	--TODO: ping client @ other end to make sure everything is ok there
	for k, v in pairs(TestAllAttacksThreads) do
		DeleteThread(v)
		TestAllAttacksThreads[k] = false
	end
	
	if not IsRealTimeThread() then
		CreateRealTimeThread(HostStartAllAttacksCoopTest)
		return
	end
	local err
	GameTestsNightly_AllAttacks(function()
		err = HostMpGameAndLaunchAndJoinAnotherClient("TestAllAttacksClientSideFunc")
		if err then
			GameTestsError("HostMpGameAndLaunchAndJoinAnotherClient returned and error: " .. err)
			return err
		end
		lKillUIPopups()
		lHostWatchDog()
	end)
	
	lTestDone()
end

TestCoopFuncs.TestAllAttacksClientSideFunc = function()
	lKillUIPopups()
	while not TestAllAttacksThreads.GameTimeProc do
		--wait for test start sync msg
		Sleep(10)
	end
	while TestAllAttacksThreads.GameTimeProc do
		if netDesync or table.count(netGamePlayers) ~= 2 then
			--its over
			print("netDesync", netDesync)
			print("table.count(netGamePlayers)", table.count(netGamePlayers))
			return --caller will quit app, so we don't care if we leaked threads
		end
		Sleep(250)
	end
end

end --Platform.developer


function OnMsg.NetGameLeft(reason)
	--saw this leak once, not sure how
	if PauseReasons.net then
		Resume("net")
	end
end


function NetSyncEvents.tst()
	ResetVoxelStealthParamsCache()
end

--overwrite func to add check for the AnalyticsEnabled option
function NetGossip(gossip, ...)
	if gossip and netAllowGossip and GetAccountStorageOptionValue("AnalyticsEnabled") == "On" then
		--LogGossip(TupleToLuaCodePStr(gossip, ...))
		return NetSend("rfnGossip", gossip, ...)
	end
end

function OnMsg.GameOptionsChanged()
	CreateRealTimeThread(function()
		if GetAccountStorageOptionValue("AnalyticsEnabled") == "On" then
			TryConnectToServer()
		else
			NetDisconnect("netClient")
		end
	end)
end

--overwrite func to add check for the AnalyticsEnabled option or MP game for reconnecting to server
function TryConnectToServer()
	if Platform.cmdline then return end
	g_TryConnectToServerThread = IsValidThread(g_TryConnectToServerThread) or CreateRealTimeThread(function()
		WaitInitialDlcLoad()
		while not AccountStorage do
			WaitMsg("AccountStorageChanged")
		end
		local wait = 60*1000
		while config.SwarmConnect do
			if not NetIsConnected() and GetAccountStorageOptionValue("AnalyticsEnabled") == "On" then
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

function NetSyncEvents.NewMapLoaded(map, net_hash, map_random, seed_text)
	--for logging purposes
	--feel free to put sync code here
end

function OnMsg.PostNewMapLoaded()
	FireNetSyncEventOnHost("NewMapLoaded", CurrentMap, mapdata.NetHash, MapLoadRandom, Game and Game.seed_text)
end