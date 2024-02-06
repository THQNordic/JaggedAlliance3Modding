if Libs.Network ~= "sync" then return end

if Platform.developer then
	function OnMsg.NetGameJoined(game_id, unique_id)
		pairs = totally_async_pairs
	end

	function OnMsg.NetGameLeft(reason)
		pairs = g_old_pairs
	end
end

local HashSendInterval = config.HashSendInterval or Platform.developer and 100 or 300

MapGameTimeRepeat("NetHashThread", HashSendInterval, function(sleep)
	if sleep and netInGame and Game then
		local hash = NetGetHashValue()
		NetUpdateHash("NetHashThread", GameTime() / sleep, hash)
		NetGameSend("rfnPlayerHash", GameTime() / sleep, hash)
		NetResetHashValue()
	end
end)


MapGameTimeRepeat("InteractionRandScheduleReset", 10000, function()
	ResetInteractionRand(now())
end)


----- AdvanceGameTime

MapVar("AdvanceToGameTimeLimit", 0)
MapVar("ForceAdvanceToGameTime", 0)

if FirstLoad then
__AdvanceGameTime = AdvanceGameTime
end
 
function AdvanceGameTime(time)
	if netInGame then
		if (AdvanceToGameTimeLimit or 0) - time < 0 then
			time = AdvanceToGameTimeLimit or 0
		end
		if (ForceAdvanceToGameTime or 0) - time > 0 then
			time = ForceAdvanceToGameTime or 0
			if time - GameTime() > 100 then
				time = GameTime() + 100
			end
		end
		if GameTime() - time > 0 then
			time = GameTime()
		end
	end
	__AdvanceGameTime(time)
end

function NetEvents.AdvanceTime(delta, time_factor, time)
	if AdvanceToGameTimeLimit then
		if AdvanceToGameTimeLimit - GameTime() > 50 * time_factor / 1000 then -- try to catch up if more than 50ms real time behind
			__SetTimeFactor(time_factor * 11 / 10)
		else
			__SetTimeFactor(time_factor)
		end
		ForceAdvanceToGameTime = AdvanceToGameTimeLimit - 2000
		AdvanceToGameTimeLimit = AdvanceToGameTimeLimit + delta * time_factor / 1000
	end
end

function OnMsg.NetGameJoined(game_id, unique_id)
	-- GameTime is conrolled by the online game
	ForceAdvanceToGameTime = GameTime()
	AdvanceToGameTimeLimit = GameTime()
end


----- Pause/Resume

if FirstLoad then
NetPause = false
end

if config.LocalToNetPause then

	function Pause(reason)
		reason = reason or false
		if next(PauseReasons) == nil then
			NetSetPause(true)
			PauseSounds(1, true)
			Msg("Pause", reason)
			PauseReasons[reason] = true
			if IsGameTimeThread() then InterruptAdvance() end
		else
			PauseReasons[reason] = true
		end
	end

	function Resume(reason)
		reason = reason or false
		if PauseReasons[reason] ~= nil then
			PauseReasons[reason] = nil
			if next(PauseReasons) == nil then
				NetSetPause(false)
				ResumeSounds(1)
				Msg("Resume", reason)
			end
		end
	end

	function IsPaused()
		return NetPause
	end

end

function NetSetPause(pause)
	NetPause = pause or false
	if netInGame then
		NetChangeGameInfo({ pause = NetPause })
	else
		SetTimeFactor(GetTimeFactor())
	end
end

function OnMsg.NetGameJoined(game_id, unique_id)
	if netGameInfo.pause == nil then
		NetSetPause(NetPause)
	else
		NetSetPause(netGameInfo.pause)
	end
end


----- TimeFactor

if FirstLoad then
__SetTimeFactor = SetTimeFactor
__GetTimeFactor = GetTimeFactor
end

function GetTimeFactor()
	return NetTimeFactor or const.DefaultTimeFactor
end
GameVar("NetTimeFactor", GetTimeFactor)

function SetTimeFactor(time_factor)
	NetTimeFactor = Clamp(time_factor or const.DefaultTimeFactor, 0, const.MaxTimeFactor)
	if netInGame then
		if netGameInfo.time_factor ~= NetTimeFactor then
			NetChangeGameInfo({ time_factor = NetTimeFactor })
		end
	else
		__SetTimeFactor(NetPause and 0 or NetTimeFactor)
	end
end

function OnMsg.NetGameInfo(info)
	if info.pause ~= nil or info.time_factor ~= nil then
		NetPause = netGameInfo.pause or false
		NetTimeFactor = netGameInfo.time_factor or const.DefaultTimeFactor
		__SetTimeFactor(NetTimeFactor)
	end
end

function OnMsg.LoadGame()
	SetTimeFactor(GetTimeFactor())
end
 
function OnMsg.NetGameJoined(game_id, unique_id)
	SetTimeFactor(netGameInfo.time_factor or GetTimeFactor())
end

function OnMsg.NetGameLeft()
	SetTimeFactor(GetTimeFactor())
end




----- Sync events

function SyncCheck_NetSyncEventDispatch()
	if config.IgnoreSyncCheckErrors then
		return true
	end
	return IsAsyncCode()
end

function ScheduleSyncEvent(event, params, time, ...)
	if not SyncEventsQueue then return end
	local func = NetSyncEvents[event]
	if not func then
		assert(false, "No such sync event: " .. tostring(event))
		return
	end
	time = time or GameTime()
	SyncEventsQueue[#SyncEventsQueue + 1] = { time, event, params or false, ... }
	Wakeup(PeriodicRepeatThreads["SyncEvents"])
end

local ScheduleOfflineSyncEvent = ScheduleSyncEvent

if Platform.developer then
	-- simulate network random delay in an offline game
	ScheduleOfflineSyncEvent = function(event, params)
		if netSimulateLagAvg == 0 then
			return ScheduleSyncEvent(event, params)
		end
		CreateRealTimeThread(function()
			local time = GameTime()
			Sleep(GetLagEventDelay())
			ScheduleSyncEvent(event, params, time)
		end)
	end
end

function NetSyncEvent(event, ...)
	assert(SyncCheck_NetSyncEventDispatch())
	assert(NetSyncEvents[event])
	if NetSyncLocalEffects[event] then
		NetSyncLocalEffects[event](...)
	end
	NetStats.events_sent = NetStats.events_sent + 1
	if netInGame then
		return SendEvent("rfnSyncEvent", event, ...)
	else
		local params, err = Serialize(...)
		assert(params, err)
		if netBufferedEvents then
			netBufferedEvents[#netBufferedEvents + 1] = pack_params(event, params)
			return
		end
		NetGossip("SyncEvent", GameTime(), event, params)
		return ScheduleOfflineSyncEvent(event, params)
	end
end

function ExecuteSyncEvent(event, ...)
	local revert_func = NetSyncRevertLocalEffects[event]
	if revert_func then
		procall(revert_func, ...)
	end
	
	Msg("SyncEvent", event, ...)
	NetUpdateHash("SyncEvent", event, ...)
	
	local func = NetSyncEvents[event]
	if not func then
		return false, "no such sync event"
	end
	
	return procall(func, ...)
end

local Sleep = Sleep
function WaitAllOtherThreads()
	Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0)
	Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0) Sleep(0)
end

function ExecuteSyncEventHook(event, params, ...)
end

MapVar("SyncEventsQueue", {})
MapGameTimeRepeat("SyncEvents", -1, function()
	if IsChangingMap() then
		WaitMsg("PostNewMapLoaded")
		assert(GameTime() == 0)
	end
	local queue = SyncEventsQueue
	while true do
		local event_data = queue[1]
		if not event_data then
			break
		end
		table.remove(queue, 1)
		local time, event, params = event_data[1], event_data[2], event_data[3]
		Sleep(time - GameTime())
		WaitAllOtherThreads()
		ExecuteSyncEventHook(event, params, unpack_params(event_data, 4))
		ExecuteSyncEvent(event, Unserialize(params))
		InterruptAdvance()
	end
	Msg("SyncEventsProcessed")
	WaitWakeup()
end)

function NetCloudSocket:rfnEvent(event, params, advance_time, time_factor)
	if params:byte(1) == 255 then
		params = DecompressPstr(params, 2)
	end
	if netBufferedEvents then
		netBufferedEvents[#netBufferedEvents + 1] = pack_params(event, params, advance_time, time_factor)
		return
	end
	NetStats.events_received = NetStats.events_received + 1
	if NetEvents[event] then
		sprocall(NetEvents[event], Unserialize(params))
		ProcessMissingHandles(event, params)
	end
	if NetSyncEvents[event] then
		local time = AdvanceToGameTimeLimit or GameTime()
		assert(time >= 0)
		if advance_time then
			NetEvents.AdvanceTime(advance_time, time_factor)
		end
		ScheduleSyncEvent(event, params, time)
	end
end

function NetSyncEvents.ObjFunc(obj, rfn, ...)
	if not obj then
		assert(false, "Unresolved object calling " .. rfn)
		return
	end
	if not string.starts_with(rfn, "rfn") then
		assert(false, "Invalid method name " .. rfn)
		return
	end
	local func = obj[rfn]
	if type(func) ~= "function" then
		assert(false, "No such method " .. obj.class .. "." .. rfn)
		return
	end
	func(obj, ...)
end

function NetSyncEvents.MultiObjFunc(objs, rfn, ...)
	for _, obj in ipairs(objs) do
		NetSyncEvents.ObjFunc(obj, rfn, ...)
	end
end


------ Game ready/start/stop

function NetGameSetReadyToStart(ready)
	return NetGameSend("rfnReadyToStart", ready and true or false)
end

function NetWaitGameStart(timeout)
	if netGameInfo.started then return end
	local err = NetGameSetReadyToStart(true)
	if err then return err end
	local time = RealTime() + (timeout or 60000)
	while RealTime() - time < 0 do
		WaitMsg("NetGameInfo", 500)
		if netGameInfo.started then
			netDesync = false
			return
		end
	end
	return "timeout"
end


----- NetUpdateHash

-- these two cannot be used in a Sync network
function NetTempObject(obj) end
function NetObject(obj) end

function Desync()
	NetUpdateHash("Forced Desync")
end

function OnMsg.NetGameJoined(game_id, unique_id)
	NetResetHashLog(HashLogSize)
	NetSetUpdateHash()
end

function OnMsg.NetGameLeft(reason)
	NetResetHashLog(HashLogSize)
	NetSetUpdateHash()
end

--[[ the check is performed on the C side
function NetUpdateHashCheck(reason, ...)
	local ok = IsGameTimeThread() or CurrentMap == "" or IsEditorActive() or GameTime() == 0 or ChangingMap or config.RealTimeNetUpdateHash
	if not ok then
		local params = {reason, ...}
		assert(ok, "NetUpdateHashCheck failed (real time thread?)")
		local text = pstr("", 256)
		for i, param in ipairs(params) do
			if i > 1 then text:append(", ") end
			if type(param) == "string" then
				text:append('"', param, '"')
			elseif IsValid(param) then
				text:appendf("%s(%d)", param.class, rawget(param, "handle") or 0)
			else
				text:append(tostring(param) or "???")
			end
		end
		print("NetUpdateHashCheck failed params", text)
	end
end
--]]

oldNotify = Notify
function Notify(obj, method)
	if GameTime() == 0 then
		return oldNotify(obj, method)
	end
	CreateGameTimeThread(function(obj, method)
		if IsValid(obj) then
			if type(method) == "function" then
				method(obj)
			else
				obj[method](obj)
			end
		end
	end, obj, method)
end

function CancelNotify()
	assert(not "Not present in sync network")
end