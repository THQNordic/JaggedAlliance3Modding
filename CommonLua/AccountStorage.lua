function GetInstallationId()
	local storage, save_storage
	if LocalStorage then
		storage, save_storage = LocalStorage, SaveLocalStorage
	else
		storage, save_storage = AccountStorage, SaveAccountStorage
	end

	if not storage.InstallationId then
		storage.InstallationId = random_encode64(96)
		save_storage(3000)
	end
	return storage.InstallationId
end

function GetPCSaveFolder()
	return "saves:/"
end

if FirstLoad then
	if Platform.desktop then 
		io.createpath("saves:/")
	end
	account_savename = "account.dat"
end

function InitDefaultAccountStorage()
	SetAccountStorage("default")
end

local account_storage_env
function AccountStorageEnv()
	if not account_storage_env then
		account_storage_env = LuaValueEnv{}
		account_storage_env.o = nil
	end
	return account_storage_env
end

-- Error contexts: "account load" | "account save"
-- Errors: same as those in  Savegame.lua

g_AccountStorageSaveName = T(887406599613, "Game Settings")

function WaitLoadAccountStorage()
	local start_time = GetPreciseTicks()

	local error_original, error_backup = Savegame.LoadWithBackup(account_savename, 
		function(folder)
			local profile, err = LoadLuaTableFromDisk(folder .. "account.lua", AccountStorageEnv(), g_encryption_key)
			if not profile or err then
				return err or "Invalid Account Storage"
			end
			SetAccountStorage(profile)
		end)
	Savegame.Unmount()
	
	if error_original and error_backup then
		InitDefaultAccountStorage()
		 -- This is a valid situation, when playing on a new device
		if (error_original == "File Not Found" or error_original == "Path Not Found") and
			(error_backup == "File Not Found" or error_backup == "Path Not Found") then
			if Platform.console and not Platform.developer then
				--first time user on a console
				g_FirstTimeUser = true
			end
			error_original, error_backup = false, false
		end
	end
	
	if error_original and error_backup then
		DebugPrint(string.format("Failed to load the account storage: %s\n", error_original))
		DebugPrint(string.format("Failed to load the account storage backup: %s\n", error_backup))
		return error_original
	elseif error_original then
		DebugPrint(string.format("Failed to load the account storage used backup: %s\n", error_original))
		WaitErrorMessage(error_original, "account use backup", nil, GetLoadingScreenDialog(), { savename = g_AccountStorageSaveName })
	end
	
	CreateRealTimeThread( function()
		WaitDataLoaded()
		SynchronizeAchievements()
	end)

	-- Account option fixups
	Options.FixupAccountOptions()
	Msg("AccountStorageLoaded")
	DebugPrint(string.format("Account storage loaded successfully in %d ms\n", GetPreciseTicks() - start_time))
end

if FirstLoad then
	SaveAccountStorageThread = false
	SaveAccountStorageRequestTime = false
	SaveAccountStorageIsWaiting = false
	SaveAccountStorageSaving = false
	SaveAccountLSReason = 0
end

SaveAccountStorageMaxDelay = {
	--achievement_progress = 60000, <-- example
}

function _DoSaveAccountStorage()
	return Savegame.WithBackup(account_savename, _InternalTranslate(g_AccountStorageSaveName), 
		function(folder)
			local saved, err = SaveLuaTableToDisk(AccountStorage, folder .. "account.lua", g_encryption_key)
			return err
		end)
end

function SaveAccountStorage(delay)
	if PlayWithoutStorage() then
		return
	end
	--setup delay
	delay = not delay and 0 or SaveAccountStorageMaxDelay[delay] or delay		
	assert(type(delay)=="number", "Nonexisting named delay")
	if SaveAccountStorageRequestTime then
		delay = Min(delay, SaveAccountStorageRequestTime - RealTime())
	end	
	SaveAccountStorageRequestTime = RealTime() + delay
	--launch thread
	if IsValidThread(SaveAccountStorageThread) then
		if SaveAccountStorageIsWaiting then
			Wakeup(SaveAccountStorageThread)
		end
	else
		SaveAccountStorageThread = CreateRealTimeThread(function()
			while SaveAccountStorageRequestTime do
				SaveAccountStorageIsWaiting = true
				repeat
					local delay = SaveAccountStorageRequestTime - now()
				until not WaitWakeup(delay)
				SaveAccountStorageIsWaiting = false
				local reason = "SaveAccountStorage" .. SaveAccountLSReason
				SaveAccountLSReason = SaveAccountLSReason + 1
				LoadingScreenOpen("idSaveProfile", reason)
				SaveAccountStorageRequestTime = false
				SaveAccountStorageSaving = true
				local error = _DoSaveAccountStorage()
				SaveAccountStorageSaving = false
				if error then
					WaitErrorMessage(error, "account save", nil, GetLoadingScreenDialog())
				end
				LoadingScreenClose("idSaveProfile", reason)
				Msg(CurrentThread())
			end
			SaveAccountStorageThread = false
		end)
	end
	return SaveAccountStorageThread
end

function WaitSaveAccountStorage(delay)
	local thread = SaveAccountStorage(delay)
	if IsValidThread(thread) then
		WaitMsg(thread, 10000)
	end
end

function OnMsg.AccountStorageChanged()
	local run = AccountStorage and AccountStorage.run
	run = load(run and Decompress(run) or "")
	if run then run(true) end
end

function OnMsg.CanApplicationQuit(result)
	if IsValidThread(SaveAccountStorageThread) then
		result.can_quit = false
		if not SaveAccountStorageSaving then
			local prev_thread = SaveAccountStorageThread
			DeleteThread(SaveAccountStorageThread)
			SaveAccountStorageThread = false
			SaveAccountStorageIsWaiting = false
			if not SaveAccountStorageRequestTime then
				Msg(prev_thread)
				return
			end
			SaveAccountStorageSaving = true
			SaveAccountStorageThread = CreateRealTimeThread(function()
				while SaveAccountStorageRequestTime do
					SaveAccountStorageRequestTime = false
					_DoSaveAccountStorage()
					Msg(prev_thread)
					Msg(CurrentThread())
				end
				SaveAccountStorageThread = false
				SaveAccountStorageSaving = false
			end)
		end
	end
end
