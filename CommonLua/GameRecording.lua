DefineClass("TestValidator")

IsGameReplayRunning = empty_func

if Platform.developer then
	RecursiveCallMethods.GetTestData = "call"
end

function IsGameRecordingSupported()
	return config.SupportGameRecording and Libs.Network == "sync"
end

GameRecordVersion = 2

function ApplyRecordVersion(record)
	local version = not record and GameRecordVersion or record.version or 1
	if version == GameRecordCurrentVersion then
		return
	end
	GameRecordCurrentVersion = version
	if version == 1 then
		RECORD_GTIME = 1
		RECORD_EVENT = 2
		RECORD_PARAM = 3
		--RECORD_RAND = 4
		--RECORD_HANDLE = 5
		RECORD_RTIME = 6
		RECORD_ETYPE = 7
		--RECORD_HASH = 8
		RECORD_SPEED = 9
	else
		RECORD_GTIME = 1
		RECORD_EVENT = 2
		RECORD_PARAM = 3
		RECORD_RTIME = 4
		RECORD_ETYPE = 5
		RECORD_SPEED = 6
	end
end

if FirstLoad then
	GameRecordCurrentVersion = false
	ApplyRecordVersion()
end

config.GameRecordsPath = "AppData/GameRecords"
local records_path = config.GameRecordsPath

MapVar("GameRecord", false) -- to be available in the saves
MapVar("GameReplay", false)
MapVar("GameReplayThread", false)

if FirstLoad then
	GameRecordScheduled = false
	
	GameReplayScheduled = false
	GameReplayPath = false
	GameReplaySaveLoading = false
	GameReplayUnresolved = false
	GameReplayWaitMap = false
	GameReplayToInject = false
	GameReplayFastForward = false

	GameRecordSaveRequests = false
end

function IsGameReplayRunning()
	return IsValidThread(GameReplayThread) and GameReplay
end

if not IsGameRecordingSupported() then
	return
end

local IsGameReplayRunning = IsGameReplayRunning

function OnMsg.ChangeMap()
	GameReplayPath = false
	GameRecordScheduled = false
	StopGameReplay()
end
 
function OnMsg.NewMapLoaded()
	GameReplay = false
	GameRecord = GameRecordScheduled
	GameRecordScheduled = false
	if not not GameRecord then
		Msg("GameRecordingStarted")
	end
end

function OnMsg.NetGameJoined()
	GameRecord = false
end

function OnMsg.GameTestsBegin(auto_test)
	table.change(config, "GameTests_GameRecording", {
		EnableGameRecording = false,
	})
end

function OnMsg.GameTestsEnd(auto_test)
	table.restore(config, "GameTests_GameRecording", true)
end

function SerializeRecordParams(...)
	return SerializeEx(const.SerializeCustom, CustomSerialize, ...)
end

function UnserializeRecordParams(params_str)
	return UnserializeEx(const.SerializeCustom, CustomUnserialize, params_str)
end

function PrepareRecordForSaving(record)
	record = record or GameRecord
	if record ~= GameRecord then return end
	record.game_time = GameTime()
end

function PlayGameRecord(record, start_idx)
	record = record or GameReplayScheduled
	if not record then return end
	assert(IsGameTimeThread())
	assert(record.start_rand == MapLoadRandom)
	start_idx = start_idx or 1
	GameReplay = record
	GameReplayScheduled = false
	GameReplaySaveLoading = false
	GameReplayThread = CurrentThread()
	if GameReplayWaitMap then
		WaitWakeup() -- ensure the map loading is complete
	end
	ApplyRecordVersion(record)
	local desync_any
	local total_time = Max((record[#record] or empty_table)[RECORD_GTIME] or 0, record.game_time or 0)
	local start_time = GameTime()
	if start_idx > #record or start_time > record[start_idx][RECORD_GTIME] then
		GameTestsPrint("Replay injection start mismatch!")
		start_idx = 1
		while start_idx <= #record and start_time > record[start_idx][RECORD_GTIME] do
			start_idx = start_idx + 1
		end
	end
	local version = record.version or 1
	GameTestsPrint("Replay start at", Min(start_idx, #record), "/", #record, "events", "|", start_time, "/", total_time, "ms", "|", "Lua rev", record.lua_rev or 0, "/", LuaRevision, "|", "assets rev", record.assets_rev or 0, "/", AssetsRevision)
	for i = start_idx,#record do
		local event_time = record[i][RECORD_GTIME]
		local delay = event_time - now()
		local yield
		if delay > 0 then
			yield = record[i][RECORD_SPEED] == 0
			Sleep(delay)
		else
			local last_record = record[i - 1]
			local prev_real_time = last_record and last_record[RECORD_RTIME] or record.real_time
			yield = prev_real_time ~= record[i][RECORD_RTIME]
		end
		if yield then
			-- make sure all game time threads created by the previous event have been started 
			WaitAllOtherThreads()
		end
		if GameReplayThread ~= CurrentThread() or GameReplay ~= record then
			return
		end
		print("Replay", i, '/', #record)
		CreateGameTimeThread(function(record, i)
			local entry = record[i]
			local event, params_str = entry[RECORD_EVENT], entry[RECORD_PARAM]
			GameReplayUnresolved = false
			local success, err = ExecuteSyncEvent(event, UnserializeRecordParams(params_str))
			if not success then
				GameTestsError("Replay", i, '/', #record, event, err)
			end
			if GameReplayUnresolved then
				GameTestsPrint("Replay", i, '/', #record, event, "unresolved objects:")
				for _, data in ipairs(GameReplayUnresolved) do
					local handle, class, pos = table.unpack(data)
					GameTestsPrint("\t", class, handle, "at", pos)
				end
			end
			Msg("GameRecordPlayed", i, record)
		end, record, i)
	end
	Sleep((record.game_time or 0) - now())
	Sleep(0) Sleep(0) Sleep(0) Sleep(0)
	
	GameTestsPrint("Replay finished")
	Msg("GameReplayEnd", record)
end

local function IsSameClass(obj, class)
	if not obj then
		return -- object handle changed or object not yet spawned
	end
	if not class or obj.class == class then
		return true
	end
	local classdef = g_Classes[class]
	return not classdef or IsKindOf(classdef, obj.class) or IsKindOf(obj, class) -- recorded class renamed
end

function CustomSerialize(obj)
	local handle = obj.handle
	if handle and IsValid(obj) and obj:IsValidPos() then
		if obj:GetGameFlags(const.gofSyncObject | const.gofPermanent) == 0 then
			StoreErrorSource(obj, "Async object in sync event")
		end
		local record = GameRecord
		local handles = record and record.handles
		if handles then
			local class = obj.class
			handles[handle] = class
			return { handle, class, obj:GetPos() }
		end
	end
end

function CustomUnserialize(tbl)
	local handle, class, pos = table.unpack(tbl)
	local obj = HandleToObject[handle]
	if IsSameClass(obj, class) then
		return obj
	end
	local map_obj = MapGetFirst(pos, 0, class)
	if map_obj then
		return map_obj
	end
	GameReplayUnresolved = table.create_add(GameReplayUnresolved, tbl)
end

function CreateRecordedEvent(event_type)
	local origGameEvent = _G[event_type]
	_G[event_type] = function(event, ...)
		if IsGameReplayRunning() then
			if not config.GameReplay_EventsDuringPlaybackExpected then
				print("Ignoring", event_type, event, "during replay!")
			end

			return
		end
		local record = GameRecord
		if record then
			local params, err = SerializeRecordParams(...)
			assert(params, err)
			CreateGameTimeThread(function(event, event_type, record, params)
				-- in a thread to have the correct sync values (as the event will be started in a thread)
				local time = GameTime()
				local n = #record
				while n > 0 and record[n][RECORD_GTIME] > time do
					record[n] = nil
					n = n - 1
				end
				n = n + 1
				record[n] = {
					[RECORD_GTIME] = time,
					[RECORD_EVENT] = event,
					[RECORD_PARAM] = params,
					[RECORD_RTIME] = RealTime(),
					[RECORD_ETYPE] = event_type,
					[RECORD_SPEED] = GetTimeFactor(),
				}
				if config.GameRecordingAutoSave then 
					SaveGameRecord()
				end
			end, event, event_type, record, params)
		end
		return origGameEvent(event, ...)
	end
end

function CreateRecordedMapLoadRandom()
	local origInitMapLoadRandom = InitMapLoadRandom
	InitMapLoadRandom = function()
		local rand
		if GameReplayScheduled then
			CreateGameTimeThread(PlayGameRecord)
			rand = GameReplayScheduled.start_rand
		else
			rand = origInitMapLoadRandom()
			if mapdata and mapdata.GameLogic and config.EnableGameRecording then
				assert(Game)
				assert(not IsGameReplayRunning())
				GameReplay = false
				GameRecordScheduled = {
					start_rand = rand,
					map_name = GetMapName(),
					map_hash = mapdata.NetHash,
					os_time = os.time(),
					real_time = RealTime(),
					game = CloneObject(Game),
					lua_rev = LuaRevision,
					assets_rev = AssetsRevision,
					handles = {},
					version = GameRecordVersion,
					net_update_hash = config.DebugReplayDesync,
				}
				Msg("GameRecordScheduled")
			end
		end
		return rand
	end
end

function CreateRecordedGenerateHandle()
	local origGenerateSyncHandle = GenerateSyncHandle
	GenerateSyncHandle = function(self)
		local h0, h = NextSyncHandle, origGenerateSyncHandle()
		if IsGameReplayRunning() and GameReplay.NextSyncHandle and GameReplay.handles and not IsSameClass(self, GameReplay.handles[h]) then
			-- the handle should be associated with another object, not yet spawn because of a previois desync
			NextSyncHandle = GameReplay.NextSyncHandle
			h = origGenerateSyncHandle()
			NextSyncHandle = h0
		end
		return h
	end
end

function RegisterGameRecordOverrides()
	CreateRecordedEvent("NetSyncEvent")
	CreateRecordedMapLoadRandom()
	CreateRecordedGenerateHandle()
end

function OnMsg.ClassesGenerate()
	RegisterGameRecordOverrides()
	GameTests.PlayGameRecords = TestGameRecords
end

function TestGameRecords()
	local list = {}
	for _, test in ipairs(GetHGProjectTests()) do
		for _, info in ipairs(test.test_replays) do
			local name = string.format("%s.%s", test.id, info:GetRecordName())
			if info.Disabled then
				GameTestsPrint("Skipping disabled test replay", name)
			else
				list[#list + 1] = {name = name, record = info.Record}
			end
		end
	end
	GameTestsPrintf("Found %d game records to test.", #(list or ""))
	for i, entry in ipairs(list) do
		GameTestsPrintf("Testing record %d/%d %s", i, #list, entry.name)
		local st = RealTime()
		local err, record = LoadGameRecord(entry.record)
		if err then
			GameTestsPrintf("Failed to load record %s", entry.record, err)
		else
			err = ReplayGameRecord(record)
			if err then
				GameTestsError("Replay error:", err)
			elseif not WaitReplayEnd() then
				GameTestsError("Replay timeout.")
			else
				GameTestsPrint("Replay finished in:", RealTime() - st, "ms")
			end
		end
	end
end

local function GenerateRecordPath(record)
	local err = AsyncCreatePath(records_path)
	if err then 
		assert(err)
		return false
	end
	record = record or GameRecord
	local name = string.format("Record_%s_%s", os.date("%Y_%m_%d_%H_%M_%S", record.os_time), GetMapName())
	if record.continue then
		name = name .. "_continue"
	end
	return string.format("%s/%s.lua", records_path, name)
end

function SaveGameRecord()
	if not GameRecord then return end
	local path = GameReplayPath or GenerateRecordPath(GameRecord)
	GameRecord.NextSyncHandle = NextSyncHandle
	if not GameRecordSaveRequests then
		GameRecordSaveRequests = {}
		CreateRealTimeThread(function()
			while true do
				for path, record in pairs(GameRecordSaveRequests) do
					GameRecordSaveRequests[path] = nil
					WaitSaveGameRecord(path, record)
				end
				if not next(GameRecordSaveRequests) then
					GameRecordSaveRequests = false
					break
				end
			end
		end)
	end
	GameRecordSaveRequests[path] = GameRecord
end

function WaitSaveGameRecord(path, record)
	record = record or GameRecord
	if not record then return end
	PrepareRecordForSaving(record)
	local code = pstr("return ", 64*1024)
	TableToLuaCode(record, nil, code)
	path = path or GenerateRecordPath(record)
	local err = AsyncStringToFile(path, code)
	if err then return err end
	Msg("GameReplaySaved", path)
	return nil, path
end

function ReplayGameRecord(record)
	record = record or not IsGameReplayRunning() and GameRecord or GameReplay
	local err
	if type(record) == "string" then
		local _, _, ext = SplitPath(record)
		local path = ext ~= "" and record or string.format("%s/%s.lua", records_path, record)
		err, record = LoadGameRecord(path)
	end
	if not record then
		return err or "No record found!"
	end
	PrepareRecordForSaving(record)
	Msg("GameRecordEnd", record)
	StopGameReplay()
	Msg("GameReplayStart", record)
	GameReplayScheduled = record
	if record.start_save then
		GameReplaySaveLoading = true
		GameReplayThread = CreateRealTimeThread(ReplayLoadGameSpecificSave, record)
	else
		CloseMenuDialogs()
		CreateRealTimeThread(function()
			LoadingScreenOpen("idLoadingScreen", "ReplayGameRecord")
			GameReplayWaitMap = true
			local game = CloneObject(record.game)
			ChangeMap("")
			NewGame(game)
			local map_name = record.map_name
			local map_hash = record.map_hash
			if map_hash and map_hash ~= table.get(MapData, map_name, "NetHash") then
				local matched
				for map, data in sorted_pairs(MapData) do
					if map_hash == data.NetHash then
						matched = map
						break
					end
				end
				if not matched then
					GameTestsPrint("Replay map has been modified!")
				elseif matched ~= map_name then
					GameTestsPrint("Replay map changed to", matched)
				end
				map_name = matched or map_name
			end
			ChangeMap(map_name)
			GameReplayWaitMap = false
			Wakeup(GameReplayThread)
			LoadingScreenClose("idLoadingScreen", "ReplayGameRecord")
		end)
	end
end

function ResaveGameRecord(path)
	local _, _, ext = SplitPath(path)
	local path = ext ~= "" and path or string.format("%s/%s.lua", records_path, path)
	local err, record = LoadGameRecord(path)
	if not record then
		return err or "No record found!"
	end
	StopGameReplay()
	if record.start_save then
		assert(false, "Not implemented!")
	else
		CloseMenuDialogs()
		CreateRealTimeThread(function()
			table.change(config, "ResaveGameRecord", {
				FixedMapLoadRandom = record.start_rand,
				StartGameOnPause = true,
			})
			ChangeMap(record.map_name)
			table.restore(config, "ResaveGameRecord")
			GameReplayPath = path
		end)
	end
end

function WaitReplayEnd()
	while not WaitMsg("GameReplayEnd", 100) do
		if not IsChangingMap() and not IsValidThread(GameReplayThread) then
			return
		end
	end
	return true
end

function StopGameReplay()
	local thread = not GameReplaySaveLoading and GameReplayThread
	if not IsValidThread(thread) then return end
	GameReplayScheduled = false
	GameReplayThread = false
	Msg("GameReplayEnd")
	DeleteThread(thread, true)
	return true
end

function LoadGameRecord(path)
	local func, err = loadfile(path, nil, _ENV)
	if not func then
		return err
	end
	local success, record = procall(func)
	if not success then return record end
	return nil, record
end

function OnMsg.LoadGame()
	if not GameReplayToInject then
		return
	end
	StopGameReplay()
	if not GameRecord then
		print("Replay injection failed: No saved record found (maybe a saved game during a replay?)")
		return
	end
	for _, key in ipairs{"start_rand", "map_name", "os_time", "lua_rev", "assets_rev"} do
		if GameRecord[key] ~= GameReplayToInject[key] then
			print("Replay injection failed: Wrong game!")
			return
		end
	end
	print("Replay Injection Success.")
	CreateGameTimeThread(PlayGameRecord, GameReplayToInject, #GameRecord + 1)
	GameReplayToInject = false
end

function ToggleGameReplayInjection(record)
	record = record or GameRecord or GameReplay
	if record and record == GameReplayToInject then
		record = false
		print("Replay Injection Cancelled")
	elseif record then
		print("Replay Injection Ready")
	else
		print("No record found to inject")
	end
	GameReplayToInject = record
end

----

function ReplayLoadGameSpecificSave(save, callbackOnload)
	print("You must implement your game loading function in ReplayLoadGameSpecificSave to use game replays with saves.")
	return true
end

function ReplayToggleFastForward(set)
	if not IsGameReplayRunning() then
		set = false
	elseif set == nil then
		set = not GameReplayFastForward
	end
	if GameReplayFastForward == set then
		return
	end
	GameReplayFastForward = set
	TurboSpeed(set, true)
end

function OnMsg.GameReplayEnd(record)
	if GameReplayFastForward then
		ReplayToggleFastForward()
	end
	-- allow to continue the recording
	if record then
		record.continue = true
		GameRecord = record
	end
end

function OnMsg.GameRecordPlayed(i, record)
	if record and GameReplayFastForward then
		local events_before_end = config.ReplayFastForwardBeforeEnd or 10
		if i >= #record - events_before_end then
			print(events_before_end, "events before the end reached, stopping fast forward...")
			ReplayToggleFastForward()
			SetTimeFactor(0)
		end
	end
end

----

if config.DebugReplayDesync then

if FirstLoad then
	GameRecordSyncLog = false
	GameRecordSyncTest = false
	GameRecordSyncIdx = false
	HashLogSize = 32
end

function OnMsg.AutorunEnd()
	pairs = totally_async_pairs
end

function OnMsg.ReloadLua()
	pairs = g_old_pairs
end

function OnMsg.NetUpdateHashReasons(enable_reasons)
	local record = GameRecord or GameRecordScheduled or GameReplay or GameReplayScheduled
	enable_reasons.GameRecord = record and record.net_update_hash and true or nil
end

function OnMsg.LoadGame()
	GameRecordSyncLog = false
end

local function StartSyncLogSaving(replay)
	local err = AsyncCreatePath("AppData/ReplaySyncLogs")
	if err then
		print("Failed to create NetHashLogs folder:", err)
		return
	end
	GameRecordSyncLog = true
	GameRecordSyncTest = replay and ((GameRecordSyncTest or 0) + 1) or false
	GameRecordSyncIdx = 1
end

function OnMsg.GameRecordScheduled()
	StartSyncLogSaving()
end

function OnMsg.GameReplayStart()
	StartSyncLogSaving(true)
end

function OnMsg.GameReplayEnd(record)
	NetSaveHashLog("E", "Replay", GameRecordSyncTest)
	GameRecordSyncLog = false
end

function OnMsg.GameRecordEnd(record)
	NetSaveHashLog("E", "Record")
	GameRecordSyncLog = false
end

function OnMsg.SyncEvent()
	if not GameRecordSyncIdx then
		return
	end
	if GameRecordSyncTest then
		NetSaveHashLog(GameRecordSyncIdx, "Replay", GameRecordSyncTest)
	else
		NetSaveHashLog(GameRecordSyncIdx, "Record")
	end
	GameRecordSyncIdx = GameRecordSyncIdx + 1
end

function NetSaveHashLog(prefix, logtype, suffix)
	if not GameRecordSyncLog then
		return
	end
	local str = pstr("")
	NetGetHashLog(str)
	if #str == 0 then
		return
	end
	local path = string.format("AppData/ReplaySyncLogs/%s%s%s.log", (prefix and tostring(prefix) .. "_" or ""), logtype, suffix and ("_" .. tostring(suffix)) or "")
	CreateRealTimeThread(function(path, str)
		local err = AsyncStringToFile(path, str)
		if err then
			printf("Failed to save %s: %s", path, err)
		end
	end, path, str)
end

function OnMsg.BugReportStart(print_func)
	local replay = IsGameReplayRunning()
	if not replay then return end
	print_func("\nGame replay running:", replay.lua_rev, replay.assets_rev)
end

end -- config.DebugReplayDesync

if Platform.developer then

function TestValidator:CollectTestData()
	local data = {}
	if Platform.developer then
		self:GetTestData(data)
	end
	return data
end

function TestValidator:rfnTestData(orig_data)
	local new_data = self:CollectTestData()
	local ignore_missing = true -- avoid breaking existing tests when adding or removing test validation entries
	if table.equal_values(orig_data, new_data, -1, ignore_missing) then
		return
	end
	GameTestsError("Test data validation failed for", self.class,
		"\n--- Orig data: ", ValueToStr(orig_data),
		"\n--- New data: ", ValueToStr(new_data))
end

function TestValidator:CreateValidation()
	local data = self:CollectTestData()
	if next(data) == nil then
		print("No test data to validate!")
		return
	end
	NetSyncEvent("ObjFunc", self, "rfnTestData", data)
	print("Test data collected:", ValueToStr(data))
end

function TestValidator:AsyncCheatValidate()
	self:CreateValidation()
end

function ReplayCreateUpdateScript()
	local record = GameReplay or GameRecord
	if not record then
		print("No replay running!")
		return
	end

	local lua_rev = record.lua_rev or LuaRevision
	local assets_rev = record.assets_rev or AssetsRevision
	
	local src_path = ConvertToOSPath("svnSrc/")
	local assets_path = ConvertToOSPath("svnAssets/")
	
	local scrip = {
		"@echo off",
		"cd " .. src_path,
		"svn cleanup",
		"svn up -r " .. lua_rev,
		"cd " .. assets_path,
		"svn cleanup",
		"svn up -r " .. assets_rev,
	}
	local path = string.format("%sUpdateToRev_%d_%d.bat", src_path, lua_rev, assets_rev)
	local err = AsyncStringToFile(path, table.concat(scrip, "\n"))
	if err then
		print("Failed to create script:", err)
	else
		print("Script created at:", path)
	end
end

end -- Platform.developer