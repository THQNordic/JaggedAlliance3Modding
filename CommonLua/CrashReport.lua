local logs_folder				= "AppData/crashes"

function GatherMinidumps(ignore_pattern)
	local err, files = AsyncListFiles(logs_folder, "*.dmp", "recursive,modified")
	if err then
		print(string.format("Crash folder enum error: %s", err))
		return
	end
	
	if ignore_pattern then
		for i = #files, 1, -1 do
			local filepath = files[i]
			local _, filename = SplitPath(filepath)
			if string.match(filename, ignore_pattern) then
				table.remove(files, i)
				table.remove(files.modified, i)
			end
		end
	end
	
	return files
end

local function check(str, what)
	return string.starts_with(str, what, true)
end
	
function CrashFileParse(crash_file)
	local info = {}
	local crash_section_found, crash_section_complete
	local err, lines = AsyncFileToString(crash_file, nil, nil, "lines")
	if err then
		return err
	end
	PauseInfiniteLoopDetection("CrashFileParse")
	local crash_keys = { "Thread", "Module", "Address", "Function", "Process", "Error", "Details" }
	local header_keys = {"Lua revision", "Timestamp", "CPU", "GPU" }
	local patterns = {
		["Lua revision"] = '^Lua revision:%s*(%d+)',
		["Timestamp"] = "^Timestamp:%s*(%x+)",
		["CPU"] = "^CPU%s*(.+)",
		["GPU"] = "^GPU%s*(.+)",
	}
	local values = {}
	local _
	local bR = string.byte("R")
	local b_ = string.byte("-")
	local bkeys, hkeys = {}, {}
	for i, key in ipairs(crash_keys) do
		bkeys[i] = string.byte(key)
	end
	for i, key in ipairs(header_keys) do
		hkeys[i] = string.byte(key)
	end
	for i, line in ipairs(lines) do
		local b = string.byte(line)
		
		for i, key in ipairs(header_keys) do
			if b == hkeys[i] and check(line, key) then
				local pattern = patterns[key] or ('^' .. key .. ':%s+(.+)$')
				local value = string.match(line, pattern)
				value = value and string.trim_spaces(value)
				if value then
					value = string.gsub(value, "[\n\r]", "")
					if key == "GPU" then
						local idx = string.find_lower(value, 'Feature Level') or string.find_lower(value, '{')
						if idx then
							value = string.sub(value, 1, idx - 1)
							value = string.trim_spaces(value)
						end
					elseif key == "CPU" then
						if string.starts_with(value, 'name', true) then
							value = string.sub(value, 5)
							value = string.trim_spaces(value)
						end
					end
					info[#info + 1] = key .. ": " .. value
					values[key] = value
					table.remove(header_keys, i)
					table.remove(hkeys, i)
				end
				break
			end
		end
		
		if crash_section_complete then
			--
		elseif not crash_section_found then
			if b_ == b and check(line, "-- Exception Information") then
				crash_section_found = true
			end
		else
			if b == bR and check(line, "Registers:") or #crash_keys == 0 then
				crash_section_complete = true
			else
				for i, key in ipairs(crash_keys) do
					if b == bkeys[i] and check(line, key) then
						local value = string.match(line, '^' .. key .. ':%s+(.+)$')
						value = value and string.trim_spaces(value)
						if value then
							info[#info + 1] = key .. ": " .. value
							if key == "Thread" then
								_, value = string.match(value, '^(%d+)%s*\"(.+)\"$')
							elseif key == "Address" then
								value = string.sub(value, -4)
							end
							values[key] = value
							table.remove(crash_keys, i)
							table.remove(bkeys, i)
						end
						break
					end
				end
			end
		end
		if (#crash_keys == 0 or crash_section_complete) and (#header_keys == 0 or i > 1024) then
			break
		end
	end
	ResumeInfiniteLoopDetection("CrashFileParse")
	if not crash_section_found then
		return "Crash info not found"
	end
	local hash = xxhash(values.Address, values.Thread, values.Error, values.Details)
	local label = string.format("[Crash] @%s%s%s (%s) %s%s%s", 
		values.Address or "", values.Function and " " or "", values.Function or "",
		values.Thread or "",
		values.Error or "", values.Details and ": " or "", values.Details or "")
	local revision = values["Lua revision"]
	local revision_num = revision and tonumber(revision) or 0
	local info_str = table.concat(info, "\n")
	return nil, info_str, label, values, revision_num, hash
end

function CrashUploadToMantis(minidumps)
	local exception_info = {}
	local min_revision = config.BugReportCrashesMinRevision or 0
	local unmount
	local function report(dump_file)
		local dump_dir, dump_name, dump_ext = SplitPath(dump_file)
		local crash_file = dump_dir .. dump_name .. ".crash"
		local err, info_str, label, values, revision_num, hash = CrashFileParse(crash_file)
		if err or not info_str or revision_num < min_revision or exception_info[hash] then
			return
		end
		exception_info[hash] = true
		if MountsByPath("memorytmp") == 0 then
			local err = MountPack("memorytmp", "", "create", 16*1024*1024)
			if err then
				print("MountPack error:", err)
				return
			end
			unmount = true
		end
		local pack_file = "memorytmp/" .. dump_name .. ".hpk"
		local pack_index = {
			{ src = dump_file, dst = dump_name .. ".dmp", },
		}
		local err, log = AsyncPack(pack_file, "", pack_index)
		if err then
			print("Pack error:", err)
			return
		end
		
		--print(os.date("%T"), ConvertToOSPath(crash_file))
		local files = { crash_file, pack_file }
		local descr = "All crash and dump files are already attached." 
		WaitXBugReportDlg(label, descr, files, {
			summary_readonly = true,
			no_screenshot = true,
			no_extra_info = true,
			append_description = "\n----\n" .. info_str,
			tags = { "Crash" },
			severity = "crash",
		})
		AsyncFileDelete(pack_file)
	end
	for _, minidump in ipairs(minidumps) do
		report(minidump)
	end
	if unmount then
		local err = UnmountByPath("memorytmp")
		if err then
			print("UnmountByPath error:", err)
			return
		end
	end
end

function MinidumpUploadAsync(url, os_path)
	local err, json = LuaToJSON({upload_file_minidump=os_path})
	if err then
		print("Failed to convert minidump data to JSON", err)
		return
	end
	local err, info = AsyncWebRequest{
		url = url,
		method = "POST",
		headers = {["Content-Type"] = "application/json"},
		body = json,
	}
	err = err or info and info.error
	if err then
		print(string.format("Minidump upload fail: %s", err))
	end
end

function GetCrashFiles(file_spec)
	local _, crash_files = AsyncListFiles(logs_folder, file_spec or "*.crash", "recursive,modified")
	crash_files = crash_files or {}
	local crash_date, index = table.max(crash_files.modified)
	
	return crash_files, crash_files[index], crash_date, index
end

function EmptyCrashFolder()
	return AsyncEmptyPath(logs_folder)
end

function CrashReportingEnabled()
	if not Platform.pc then return end
	return config.UploadMinidump or config.BugReportCrashesOnStartup
end

function RenameCrashPair(minidump, new_minidump)
	AsyncFileRename(minidump, new_minidump)
	local crash_file = string.gsub(minidump, ".dmp$", ".crash")
	local new_crash_file = string.gsub(new_minidump, ".dmp$", ".crash")
	AsyncFileRename(crash_file, new_crash_file)
end

if FirstLoad then
	g_bCrashReported = false
end

function WaitBugReportCrashesOnStartup()
	local _, minidump = GetCrashFiles("*.dmp")
	if not minidump then return end
	CrashUploadToMantis({minidump})
	EmptyCrashFolder()
end

function OnMsg.EngineStarted()
	if not config.BugReportCrashesOnStartup or g_bCrashReported then return end
	g_bCrashReported = true
	CreateRealTimeThread(WaitBugReportCrashesOnStartup)
end

----

if FirstLoad then
	SymbolsFolders = false
	GedFolderCrashesInstance = false
	CrashCache = false
	CrashFilter = false
	CrashResolved = false
end

CrashCacheVersion = 4
local base_cache_folder = "AppData/CrashCache/"
local cache_file = base_cache_folder .. "CrashCache.bin"
local resolved_file = ConvertToBenderProjectPath("Logs/Crashes/__Resolved.lua")

CrashFolderSymbols = ConvertToBenderProjectPath("Logs/Pdbs/")
CrashFolderBender = ConvertToBenderProjectPath("Logs/Crashes")
CrashFolderSwarm = ConvertToBenderProjectPath("SwarmBackup/*/Storage/log-crash")
CrashFolderLocal = "AppData/crashes"

local defaults_groups = {
	SwarmBackup = ">Swarm",
}

local CrashInfoButtons = {
	{name = "LocateSymbols", func = "SymbolsFolderOpen"},
}

DefineClass.CrashInfo = {
	__parents = {"PropertyObject"},
	properties = {
		{ category = "Actions", id = "Actions", editor = "buttons", default = "", buttons = CrashInfoButtons },
		
		{ category = "Crash", id = "ExeTimestamp", name = "Exe Timestamp", editor = "text", default = "" },
		{ category = "Crash", id = "SymbolsFolder", name = "Symbols Folder", editor = "text", default = "", buttons = {{name = "Open", func = "SymbolsFolderOpen"}} },
	}
}

function CrashInfo:SymbolsFolderOpen()
	local bdb_folder = self.SymbolsFolder
	if bdb_folder ~= 0 then
		local os_command = string.format("cmd /c start \"\" \"%s\"", bdb_folder)
		os.execute(os_command)
	end
end

function CrashInfo:GetCacheFolder()
	local timestamp = self.ExeTimestamp
	if timestamp == "" then
		return "Missing timestamp!"
	end
	local cache_folder = base_cache_folder .. timestamp .. "/"
	if not io.exists(cache_folder) then
		local err = AsyncCreatePath(cache_folder)
		if err then
			return err
		end
	end
	return nil, cache_folder
end

function GedFolderCrashesRun(get)
	local crash = get.selected_object
	if crash then crash:OpenLogFile() end
end

DefineClass.FolderCrashGroup = {
	__parents = {"SortedBy", "GedFilter" },
	properties = {
		{ id = "name", editor = "text", default = "", read_only = true, buttons = {{name = "Export", func = "ExportToCSV"}} },
		{ id = "count", editor = "number", default = 0, read_only = true },
		{ id = "thread", name = "Show Thread", editor = "combo", default = false, items = function(self) return table.keys(self.threads, true) end },
		{ id = "timestamp", name = "Show Timestamp", editor = "combo", default = false, items = function(self) return table.keys(self.timestamps, true) end },
		{ id = "filter", name = "Show Name", editor = "combo", default = false, items = function(self) return table.keys(self.names, true) end },
		{ id = "cpu", name = "Show CPU", editor = "combo", default = false, items = function(self) return table.keys(self.cpus, true) end },
		{ id = "gpu", name = "Show GPU", editor = "combo", default = false, items = function(self) return table.keys(self.gpus, true) end },
		{ id = "unique", name = "Show Unique Only", editor = "bool", default = false },
		{ id = "resolved", name = "Show Resolved", editor = "bool", default = false },
		{ id = "shown_count", name = "Shown Count", editor = "number", default = 0, read_only = true },
	},
	shown = false,
	names = false,
	timestamps = false,
	threads = false,
	cpus = false,
	gpus = false,
}

function FolderCrashGroup:PrepareForFiltering()
	self.shown = {}
	self.shown_count = 0
end

function FolderCrashGroup:FilterObject(obj)
	local name = obj.name
	if self.unique then
		if self.shown[name] then
			return
		end
		self.shown[name] = true
	end
	if not self.resolved and CrashResolved and CrashResolved[obj.hash] then
		return
	end
	local timestamp = self.timestamp
	if timestamp and timestamp ~= obj.ExeTimestamp then
		return
	end
	local thread = self.thread
	if thread and thread ~= obj.thread then
		return
	end
	local cpu = self.cpu
	if cpu and cpu ~= obj.CPU then
		return
	end
	local gpu = self.gpu
	if gpu and gpu ~= obj.GPU then
		return
	end
	local filter = self.filter
	if filter and filter ~= name and not string.find(name, filter) then
		return
	end
	self.shown_count = self.shown_count + 1
	return true
end

function FolderCrashGroup:ExportToCSV()
	local name = string.starts_with(self.name, ">") and string.sub(self.name, 2) or self.name
	local path = base_cache_folder .. name .. ".csv"
	local err = SaveCSV(path, self, {"name", "thread", "date", "CPU", "GPU", "ExeTimestamp"}, {"name", "thread", "date", "CPU", "GPU", "Exe"})
	if err then
		print(err, "while exporting", path)
	else
		print("Exported to", path)
		OpenTextFileWithEditorOfChoice(path)
	end
end

function FolderCrashGroup:GetSortItems()
	return {"name", "timestamp", "thread", "date", "CPU", "GPU", "occurrences"}
end

function FolderCrashGroup:Cmp(c1, c2, sort_by)
	local n1, n2 = c1.name, c2.name
	local ts1, ts2 = c1.ExeTimestamp, c2.ExeTimestamp
	local d1, d2 = c1.DmpTimestamp, c2.DmpTimestamp
	local CPU1, CPU2 = c1.CPU, c2.CPU
	local GPU1, GPU2 = c1.GPU, c2.GPU
	local o1, o2 = c1.occurrences, c2.occurrences
	
	if sort_by == "occurrences" then
		if o1 ~= o2 then
			return o1 > o2
		end
	elseif sort_by == "date" then
		if d1 ~= d2 then
			return d1 < d2
		end
	elseif sort_by == "thread" then
		local t1, t2 = c1.thread, c2.thread
		if t1 ~= t2 then
			return t1 < t2
		end
	elseif sort_by == "timestamp" then
		if ts1 ~= ts2 then
			return ts1 < ts2
		end
	elseif sort_by == "CPU" then
		if CPU1 ~= CPU2 then
			return CPU1 < CPU2
		end
	elseif sort_by == "GPU" then
		if GPU1 ~= GPU2 then
			return GPU1 < GPU2
		end
	end
	if n1 ~= n2 then
		return n1 < n2
	end
	if ts1 ~= ts2 then
		return ts1 < ts2
	end
	if d1 ~= d2 then
		return d1 < d2
	end
	if o1 ~= o2 then
		return o1 > o2
	end
	if GPU1 ~= GPU2 then
		return GPU1 < GPU2
	end
	if CPU1 ~= CPU2 then
		return CPU1 < CPU2
	end
end

function FolderCrashGroup:GetEditorView()
	return string.format("%s  <color 128 128 128>%d</color>", self.name, self.count)
end

local FolderCrashButtons = {
	{name = "DebugInVS", func = "DebugDump"},
	{name = "LocateSymbols", func = "SymbolsFolderOpen"},
	{name = "OpenLog", func = "OpenLogFile"},
	{name = "Resolve", func = "ResolveCrash"},
}

DefineClass.FolderCrash = {
	__parents = {"CrashInfo"},
	properties = {
		{ category = "Actions", id = "Actions", editor = "buttons", default = "", buttons = FolderCrashButtons },
		{ category = "Actions", id = "Resolved", editor = "bool", default = false, read_only = true },
		
		{ category = "Crash", id = "ModuleName", editor = "text", default = "" },
		{ category = "Crash", id = "LocalModuleName", editor = "text", default = "", help = "Use it to change the symbols name locally, if the expected PDB name do not match" },
		
		{ category = "Crash", id = "name", name = "Summary", editor = "text", default = "" },
		{ category = "Crash", id = "occurrences", name = "Occurrences", editor = "number", default = 0, },
		{ category = "Crash", id = "date", name = "Dmp Date", editor = "text", default = "" },
		{ category = "Crash", id = "DmpTimestamp", name = "Dmp Timestamp", editor = "number", default = 0 },
		{ category = "Crash", id = "thread", editor = "text", default = "" },
		{ category = "Crash", id = "CPU", editor = "text", default = "" },
		{ category = "Crash", id = "GPU", editor = "text", default = "" },
		{ category = "Crash", id = "full_path", name = "Log Path", editor = "text", default = "", buttons = {{name = "Open", func = "OpenLogFile"}}, },
		{ category = "Crash", id = "crash_info", name = "Full Info", editor = "text", default = "", max_lines = 30, lines = 10, },
		
		{ category = "Crash", id = "dump_file", name = "text", editor = "text", default = "", no_edit = true, },
		{ category = "Crash", id = "group", name = "text", editor = "text", default = "", no_edit = true, },
		{ category = "Crash", id = "values", editor = "prop_table", default = false, no_edit = true, },
		{ category = "Crash", id = "hash", editor = "number", default = false, no_edit = true, },
	},
	StoreAsTable = true,
	CustomModuleName = false,
}

function WaitSaveCrashResolved()
	local code = pstr("return ", 1024)
	TableToLuaCode(CrashResolved, nil, code)
	local err = AsyncStringToFile(resolved_file, code)
	if err then
		print("once", "Failed to save the resolved crashes to", resolved_file, ":", err)
	end
end

function FolderCrash:GetModuleNameRaw()
	local module_file = self.values and self.values.Module
	if (module_file or "") == "" then
		return ""
	end
	local module_dir, module_name, module_ext = SplitPath(module_file)
	return module_name
end

function FolderCrash:GetModuleName()
	if (self.CustomModuleName or "") ~= "" then
		return self.CustomModuleName
	end
	return self:GetModuleNameRaw()
end

function FolderCrash:SetModuleName(module_name)
	self.CustomModuleName = (module_name or "") ~= "" and module_name ~= self:GetModuleNameRaw() and module_name or nil
end

function FolderCrash:GetResolved()
	return CrashResolved and CrashResolved[self.hash]
end

function FolderCrash:ResolveCrash(root, prop_id, ged)
	if self:GetResolved() then
		print(self.name, "is already resolved")
		return
	end
	if ged:WaitQuestion("Resolve", string.format("Mark crash \"%s\" as resolved?", self.name), "Yes", "No") ~= "ok" then
		return
	end
	CrashResolved = CrashResolved or {}
	CrashResolved[self.hash] = self.name .. " " .. self.ExeTimestamp
	DelayedCall(0, WaitSaveCrashResolved)
end

function FolderCrash:GetEditorView()
	local resolved = self:GetResolved()
	local color_start = resolved and "RESOLVED <color 128 128 128>" or ""
	local color_end = resolved and "</color>" or ""
	return string.format("<style GedMultiLine>%s%s%s <color 64 128 196>%s</color> <color 64 196 128>%s</color> <color 196 128 64>%s</color></style>",
		color_start, self.name, color_end, self.ExeTimestamp, self.CPU, self.GPU)
end

function FolderCrash:OpenLogFile()
	local full_path = self.full_path or ""
	if full_path ~= "" then
		OpenTextFileWithEditorOfChoice(full_path)
	end
end

function CopySymbols(cache_folder, src_folder, module_name, local_name)
	if (module_name or "") == "" then
		return "Invalid param!"
	end
	if (local_name or "") == "" then
		local_name = module_name
	end
	local pdbfile = cache_folder .. local_name .. ".pdb"
	if io.exists(pdbfile) then
		print("Using locally cached", pdbfile)
		return
	end
	if src_folder == "" then
		return "Symbols folder not found!"
	end
	local err, files = AsyncListFiles(src_folder, module_name .. ".*")
	if err then
		return print_format("Failed to list", src_folder, ":", err)
	end
	for _, file in ipairs(files) do
		local file_dir, file_name, file_ext =  SplitPath(file)
		local dest = cache_folder .. local_name .. file_ext
		print("Copying", file, "to", dest)
		local err = AsyncCopyFile(file, dest, "raw")
		if err then
			return print_format("Failed to copy", file, ":", err)
		end
	end
	if not io.exists(pdbfile) then
		return print_format("No symbols found at", src_folder)
	end
end

function FolderCrash:DebugDump()
	if not Platform.pc then
		print("Supported on PC only!")
		return
	end
	local err
	local module_name = self:GetModuleName() or ""
	if module_name == "" or string.lower(module_name) == "unknown" then
		print("Invalid module name!")
		return
	end
	local err, cache_folder = self:GetCacheFolder()
	if err then
		print("Failed to create working directory:", err)
		return
	end
	local orig_dump_file = self.dump_file
	local orig_dump_dir, dump_name, dump_ext = SplitPath(orig_dump_file)
	local dump_file = cache_folder .. dump_name .. dump_ext
	if not io.exists(dump_file) then
		if not io.exists(orig_dump_file) then
			print("No dump pack found!")
			return
		end
		local err = AsyncCopyFile(orig_dump_file, dump_file, "raw")
		if err then
			print("Failed to copy", orig_dump_file, ":", err)
			return
		end
	end
	local err = CopySymbols(cache_folder, self.SymbolsFolder, module_name, self.LocalModuleName)
	if err then
		print("Copy symbols error:", err)
		return
	end
	local os_path = ConvertToOSPath(dump_file)
	local os_command = string.format("cmd /c start \"\" \"%s\"", os_path)
	os.execute(os_command)
end

function FetchSymbolsFolders()
	local err
	local st = GetPreciseTicks()
	err, SymbolsFolders = AsyncListFiles(CrashFolderSymbols, "*", "folders")
	if err then
		print("Failed to fetch symbols folders from Bender:", err)
		SymbolsFolders = {}
	end
	print(#SymbolsFolders, "symbol folders found in", GetPreciseTicks() - st, "ms at", CrashFolderSymbols)
end

function ResolveSymbolsFolder(timestamp)
	if (timestamp or "") == "" then
		return
	end
	assert(SymbolsFolders)
	for _, folder in ipairs(SymbolsFolders) do
		if string.ends_with(folder, timestamp, true) then
			return folder
		end
	end
end

function OpenCrashFolderBrowser(location, timestamp)
	CreateRealTimeThread(WaitOpenCrashFolderBrowser, location, timestamp)
end

function WaitOpenCrashFolderBrowser(location, timestamp)
	print("Opening crash folder browser at", location)
	FetchSymbolsFolders()
	if not CrashCache then
		local err, str = AsyncFileToString(cache_file)
		if not err then
			CrashCache = dostring(str)
		end
		if not CrashCache or CrashCache.version ~= CrashCacheVersion then
			CrashCache = { version = CrashCacheVersion }
		end
	end
	if not CrashResolved then
		local err, str = AsyncFileToString(resolved_file)
		if not err then
			CrashResolved = dostring(str)
		end
		if not CrashResolved then
			CrashResolved = {}
		end
	end
	local to_read, to_delete = {}, {}
	local to_delete_count = 0
	local groups = {}
	local total_count = 0
	local function AddCrashTo(crash, crash_name, group_name)
		local group = groups[group_name]
		if not group then
			group = FolderCrashGroup:new{ name = group_name }
			groups[group_name] = group
			groups[#groups + 1] = group
		end
		group[#group + 1] = crash
	end
	local skipped = 0
	local function AddCrash(crash, group_name)
		if timestamp and timestamp ~= crash.ExeTimestamp then
			skipped = skipped + 1
			return
		end
		AddCrashTo(crash, crash.name, crash.group)
		AddCrashTo(crash, crash.name, ">All")
		total_count = total_count + 1
	end
	local created = 0
	local read = 0
	local function ReadCrash(info)
		read = read + 1
		local crashfile, folder = info[1], info[2]
		local file_dir, file_name, file_ext = SplitPath(crashfile)
		local dump_file = file_dir .. file_name .. ".dmp"
		local err, info, label, values, revision_num, hash, DmpTimestamp
		err, DmpTimestamp = AsyncGetFileAttribute(dump_file, "timestamp")
		if err then
			print(err, "while getting timestamp of", dump_file)
		else
			err, info, label, values, revision_num, hash = CrashFileParse(crashfile)
			if err then
				print(err, "error while reading", crashfile)
			end
		end
		if err then
			to_delete_count = to_delete_count + 1
			to_delete[#to_delete + 1] = crashfile
			to_delete[#to_delete + 1] = dump_file
			return
		end
		local group_name = string.sub(file_dir, #folder + 2)
		if group_name == "" then
			group_name = ">Ungrouped"
			for pattern, name in pairs(defaults_groups) do
				if file_dir:find(pattern) then
					group_name = name
					break
				end
			end
		else
			group_name = group_name:sub(1, -2)
			group_name = group_name:gsub("\\", "/")
		end
		local crash = FolderCrash:new{
			dump_file = dump_file,
			group = group_name,
			folder = file_dir,
			name = label,
			full_path = crashfile,
			crash_info = info,
			date = os.date("%y/%m/%d %H:%M:%S", DmpTimestamp),
			DmpTimestamp = DmpTimestamp,
			ExeTimestamp = values.Timestamp,
			SymbolsFolder = ResolveSymbolsFolder(values.Timestamp),
			CPU = values.CPU,
			GPU = values.GPU,
			thread = values.Thread,
			values = values,
			hash = hash,
		}
		CrashCache[crashfile] = crash
		AddCrash(crash)
		created = created + 1
		if read % 100 == 0 then
			print(#to_read - read, "remaining...")
		end
	end
	
	local folders
	if type(location) == "string" then
		folders = { location }
	elseif type(location) == "table" then
		folders = location
	else
		folders = { CrashFolderBender }
	end
	print("Fetching folder structure...")
	while true do
		local found
		for i=#folders,1,-1 do
			local folder = folders[i]
			local star_i = folder:find_lower("*")
			if star_i then
				found = true
				table.remove(folders, i)
				local base = folder:sub(1, star_i - 1)
				local sub = folder:sub(star_i + 1)
				local err, subfolders = AsyncListFiles(base, "*", "folders")
				if err then
					print("Failed to fetch issues from", base, ":", err)
				else
					for _, subfolder in ipairs(subfolders) do
						local f1 = subfolder .. sub
						if io.exists(f1) then
							folders[#folders + 1] = f1
						end
					end
				end
			end
		end
		if not found then
			break
		end
	end
	for _, folder in ipairs(folders) do
		if folder:ends_with("/") or folder:ends_with("\\") then
			folder = folder:sub(1, -2)
		end
		local st = GetPreciseTicks()
		local err, files = AsyncListFiles(folder, "*.crash", "recursive")
		if err then
			printf("Failed to fetch issues (%s) from '%s'", err, folder)
		else
			printf("%d crashes found in '%s'", #files, folder)
			for i, crashfile in ipairs(files) do
				local group_name
				local cache = CrashCache[crashfile]
				if cache then
					AddCrash(cache)
				else
					to_read[#to_read + 1] = { crashfile, folder }
				end
			end
		end
	end
	local st = GetPreciseTicks()
	parallel_foreach(to_read, ReadCrash)
	table.sortby_field(groups, "name")
	for _, group in ipairs(groups) do
		local names, timestamps, threads, gpus, cpus = {}, {}, {}, {}, {}
		group.names = names
		group.timestamps = timestamps
		group.threads = threads
		group.gpus = gpus
		group.cpus = cpus
		for _, crash in ipairs(group) do
			local name = crash.name
			names[name] = (names[name] or 0) + 1
			timestamps[crash.ExeTimestamp] = true
			threads[crash.thread] = true
			gpus[crash.GPU] = true
			cpus[crash.CPU] = true
		end
		for _, crash in ipairs(group) do
			crash.occurrences = names[crash.name]
		end
		group:Sort()
		group.count = #group
	end
	print("Crashes processed:", total_count, ", skipped:", skipped, ", time:", GetPreciseTicks() - st, "ms")
	if created > 0 then
		local code = pstr("return ", 1024)
		TableToLuaCode(CrashCache, nil, code)
		AsyncCreatePath(base_cache_folder)
		local err = AsyncStringToFile(cache_file, code, -2, 0, "zstd")
		if err then
			print("once", "Failed to save the crash cache to", cache_file, ":", err)
		end
	end
	local ged = OpenGedAppSingleton("GedFolderCrashes", groups)
	ged:SetSelection("root", { 1 }, nil, not "notify")
	if to_delete_count > 0 then
		if "ok" == WaitQuestion(terminal.desktop, "Warning", string.format("Confirm removal of %s invalid crash files?", to_delete_count)) then
			local err = AsyncFileDelete(to_delete)
			if err then
				print(err, "while deleting invalid crash files!")
			else
				print(to_delete_count, "invalid crash files removed.")
			end
		end
	end
end
