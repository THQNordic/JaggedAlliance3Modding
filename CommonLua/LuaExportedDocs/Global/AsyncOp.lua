-- err, file = AsyncFileOpen(string filename, string mode = "r", bool create_path = false)
function AsyncFileOpen(filename, mode, create_path)
end

-- err = AsyncFileClose(object file)
function AsyncFileClose(file)
end

-- err = AsyncFileWrite(object file, string data, int offset = -2, bool flush = false)
-- data can be a string or a table of strings
-- offset -1 means write at end of file
-- offset -2 means use file pointer
function AsyncFileWrite(file, data, offset, flush)
end

-- err, data = AsyncFileRead(object file, int count = -1, int offset = -2, string mode = "string")
-- offset -2 means use file pointer
-- mode can be "string", "lines" - data is a table with lines, or "hash" which returs a hash string 1/1000 of the read part
function AsyncFileRead(file, count, offset, mode)
end

-- err = AsyncFileFlush(object file)
function AsyncFileFlush(file)
end

-- err = AsyncStringToFile(string filename, string data, offset = -2, timestamp = 0, compression = "none")
-- data can be a string or a table of strings
-- offset = -1 means append the file
-- offset = -2 means overwrite the entire file
-- sets the modification time of the file to timestamp
-- compression can be "none", "zlib", "lz4", "lz4hc", "zstd"; it is applied only when overwriting the entire file (offset = -2)
function AsyncStringToFile(filename, data, offset, timestamp, compression)
end

-- err, data = AsyncFileToString(string filename, int count = -1, int offset = 0, string mode = "", bool raw = false)
-- mode can be "string", "lines" - data is a table with lines, "hash" which returns a hash string 1/1000 of the read part, "pstr" or "compress"
-- raw = true means do not decompress
function AsyncFileToString(filename, count, offset, mode, raw)
end

-- err, idx = AsyncStringSearch(string str_data, string str_to_find, bool case_insensitive = false, bool match_whole_word = false)
function AsyncStringSearch(str_data, str_to_find, case_insensitive, match_whole_word)
end

-- err = AsyncCopyFile(string src, string dst, string mode = nil)
-- mode can be nil, "zlib" or "raw"
function AsyncCopyFile(src, dst, mode)
end

-- err = AsyncMountPack(string mount_path, string pack, string options = "final", string label, int mem = 0)
-- options is a string which can contain any of the following:
--   - in_mem - load the packfile in memory (equivalent to mem = -1)
--   - create - create and mount an empty packfile (includes write)
--   - write - mount the packfile writable
--   - compress - create a compressed packfile (useful only in combination with create)
--   - final - stops searching lower priority paths for paths matching the mount path
function AsyncMountPack(mount_path, pack, options, label, mem)
end

-- err = AsyncUnmount(path)
function AsyncUnmount(path)
end

-- err, exitcode, stdout, stderr = AsyncExec(string cmd, string working_dir = "", bool hidden = false, bool capture_output = false, string priority = "normal", int timeout = 0)
function AsyncExec(cmd, working_dir, hidden, capture_output, priority, timeout)
end

-- err, result = AsyncWebRequest(params)
-- params entries:
--- string url
--- string method = "GET"
--- table vars = {}
--- table files = {}
--- table headers = {}
--- string body = ""
--- int max_response_size = 1024*1024
--- bool pstr_response = false
-- returns err, response
function AsyncWebRequest(params)
end

-- err, files = AsyncListFiles(string path = "", string mask = "*", string mode = "")
-- mode can include:
--    "recursive" for recursive enumeration
--    "folders" to return folders only instead of files
--    "attributes" to have the attributes of each file in files.attributes
--    "size" to have the size of each file in files.size
--    "modified" to have a UNIX style modification timestamp of each file in files.modified
--    "relative" to return file paths relative to the search path
function AsyncListFiles(path, mask, mode)
end

-- err = AsyncCreatePath(string path)
function AsyncCreatePath(path)
end

-- err = AsyncFileDelete(string path)
function AsyncFileDelete(path)
end

-- err = AsyncPack(packfile, folder, index_table, params_table)
function AsyncPack(packfile, folder, index_table, params_table)

end

-- err, files = AsyncUnpack(string packfile, string dest = ".")
function AsyncUnpack(packfile, dest)
end

-- err, info = AsyncUnpack(string path, string rev_type = "", string query_key = "")
function AsyncGetSourceInfo(path, rev_type, query_key)
end

-- err = AsyncPlayStationSaveFromMemory(savename, displayname)
function AsyncPlayStationSaveFromMemory(savename, displayname)
end

-- err = AsyncPlayStationLoadToMemory(savename)
function AsyncPlayStationLoadToMemory(savename)
end

-- err = AsyncPlayStationSaveDataDelete(mountpoint)
function AsyncPlayStationSaveDataDelete(mountpoint)
end

--err, list = AsyncPlayStationSaveDataList()
function AsyncPlayStationSaveDataList()
end

--err, list = AsyncPlayStationSaveDataTotalSize()
function AsyncPlayStationSaveDataTotalSize()
end

--err, list = AsyncPlayStationGetUnlockedTrophies()
function AsyncPlayStationGetUnlockedTrophies()
end

--err, platinum_unlocked = AsyncPlayStationUnlockTrophy(id)
function AsyncPlayStationUnlockTrophy(id)
end

--err, auth_code = AsyncPSNGetAppTicket()
function AsyncPSNGetAppTicket()
end

--err, auth_code, auth_issuer_id = AsyncPlayStationGetAuthCode()
function AsyncPlayStationGetAuthCode()
end

--err = AsyncPlayStationShowBrowserDialog()
function AsyncPlayStationShowBrowserDialog()
end

--err = AsyncPlayStationShowFreeSpaceDialog()
function AsyncPlayStationShowFreeSpaceDialog()
end

--err, platinum_unlocked = AsyncGetFileAttribute(string filename, string attribute)
function AsyncGetFileAttribute(filename, attribute)
end
