if not FirstLoad or not Platform.ios or not Platform.developer then return end

local Updating = true
local FolderSyncRequests = 0
local OriginalLuaAllocLimit = 0
local SyncStart = 0
local DownloadedFiles = {}
local DeletedFiles = {}

luadebugger.UploadFile = function(self, filepath, part, all_parts, part_size, total_size, max_part_size)
	self.binary_mode = true
	self.binary_handler = function(data)
		self.binary_mode = false
		CreateRealTimeThread(function()
			local data_size = string.len(data)
			if (part_size ~= string.len(data)) then
				print(string.format("[Error] Invalid packet size - %d KB, (expected %d KB)", data_size/1024, part_size/1024)) 
				return
			end
			if part + 1 == all_parts then
				DownloadedFiles[#DownloadedFiles+1] = filepath
			end
			if all_parts > 1 then
				print(string.format("[downloaded part %d/%d (%d/%d KB)] %s ", (part+1), all_parts, (part*max_part_size + part_size)/1024, total_size/1024, filepath))
			else
				print(string.format("[downloaded %d KB] %s ", ((string.len(data))/1024), filepath))
			end
			local folder = SplitPath(filepath)
			if folder ~= "" and not io.exists(folder) then
				print("Create folder: ", folder)
				io.createpath(folder)
			end
			local mode = part > 0 and "a" or "w"
			local f,err = io.open(filepath, mode)
			if f then
				f:write(data);
				f:close()
			else
				print("[Error] ", err);
			end
		end)
	end
end

luadebugger.DeleteFile = function(self, filepath)
	local ok, err = os.remove(filepath)
	if not ok and err == "File Not Found" then
		print("[Warning] File not found when trying to delete! "..filepath);
		ok = true
		err = false
	end
	if ok then
		print(string.format("[deleted] %s ", filepath))
		DeletedFiles[#DeletedFiles+1] = filepath
	end
end

luadebugger.RequestFolderSync = function(self, folder, remote_folder, recursive)
	local info = {}
	local files = io.listfiles(folder, "*", recursive)
	for fi=1, #files do
		local file = files[fi]
		info[file:sub(folder:len()+1)] = io.getmetadata(file, "modification_time")
	end
	--print(info)
	FolderSyncRequests = FolderSyncRequests + 1
	self:Send({Event="RequestFolderSync", LocalFolder = folder, LocalFiles = info, Recursive = recursive, RemoteFolder = remote_folder})		
end

luadebugger.FolderSynced = function(self)
	CreateRealTimeThread(function()
		FolderSyncRequests = FolderSyncRequests - 1
		if (FolderSyncRequests <= 0) then
			config.ReportLuaAlloc = OriginalLuaAllocLimit
			Updating = false
			print(string.format("Project synced in %d s", (GetPreciseTicks() - SyncStart)/1000))
		end
	end)
end

function ProjectSync()
	if g_LuaDebugger then
		SyncStart = GetPreciseTicks()
		
		OriginalLuaAllocLimit = config.ReportLuaAlloc
		config.ReportLuaAlloc = 0
		local remote_build_folder = string.format("%s\\Build\\%s", config.Haerald.ProjectAssetsPath, GetPlatformName())
		g_LuaDebugger:RequestFolderSync("AppData/Build", remote_build_folder, "recursive")
		return true;
	else
		print("Project sync skipped - no debugger")
		return false
	end
end

CreateRealTimeThread(function()
	if Platform.ios and not config.Haerald then
		config.Haerald = {}
		config.Haerald.ip = GetBundleSetting("HaeraldIP")
		config.Haerald.RemoteRoot = GetBundleSetting("RemoteRoot")
		config.Haerald.ProjectFolder = GetBundleSetting("ProjectFolder")
	end
	config.Haerald.platform = GetPlatformName()
	SetupRemoteDebugger(config.Haerald.ip or "localhost", config.Haerald.RemoteRoot or "", config.Haerald.ProjectFolder or "")		
	StartDebugger()
	local started = ProjectSync()
	if not started then
		Updating = false
	end
end)

while(Updating) do
	local t = GetPreciseTicks()
	AdvanceThreads(t)
	os.sleep(10)
end

for i=1, #DownloadedFiles do
	local filepath = DownloadedFiles[i]
	if filepath:find("Lua.hpk") then
		-- notify user that lua boot changes will not be available
		-- this run. Restart is required for them.
	end
end

-- unmount and mount again all packs
if #DownloadedFiles > 0 then
	print("Remounting all packs...")
	dofile("mount.lua") 
end
