-- TupleStorage works with tuples consisting of basic lua values and tables of basic lua values.
-- TupleStorage uses files named <storage_dir>/<file_name>.XXXXXX.lua.
-- Files are split when they grow above <max_file_size>.
-- Writes are buffered until the buffer gets to <max_buffer_size> or a new file is created
-- Write buffer is flushed (regardless of size) every <periodic_buffer_flush> milliseconds

DefineClass.TupleStorage = {
	__parents = { "InitDone", "EventLogger" },

	storage_dir = "Storage",
	sub_dir = "",
	file_name = "file",
	file_ext = "csv",
	event_source = "TupleStorage",
	single_file = false,

	max_file_size = 1024*1024,
	max_buffer_size = 64*1024,
	periodic_buffer_flush = 7717,

	min_file_index = 1,
	max_file_index = 1,

	buffer = false,
	buffer_offset = 0,

	flush_thread = false,
	flush_queue = false,
	
	done = false,
}

function TupleStorage:Init()
	if not self.storage_dir then
		local empty = function() end
		self.DeleteFiles = empty
		self.DeleteFile = empty
		self.Flush = empty
		self.WriteTuple = empty
		self.ReadTuple = empty
		self.ReadAllTuples = empty
		return
	end
	self.storage_dir = self.storage_dir .. self.sub_dir
	local err = AsyncCreatePath(self.storage_dir)
	if err then
		self:ErrorLog(err)
	end
	self.file_name = string.gsub(self.file_name, '[/?<>\\:*|"]', "_")
	if self.single_file then
		local file_name = string.format("%s/%s.%s", self.storage_dir, self.file_name, self.file_ext)
		self.GetFileName = function(self, index)
			assert(index == 1)
			return file_name
		end
		self.max_file_size = 1024*1024*1024
		self.event_source = string.format("TupleFile %s/%s", self.sub_dir, self.file_name)
		err, self.buffer_offset = AsyncGetFileAttribute(file_name, "size")
	else
		local err, files = AsyncListFiles(self.storage_dir, string.format("%s.*.%s", self.file_name, self.file_ext), "relative")
		local pattern = "%.(%d+)%." .. self.file_ext .. "$"
		if err then self:ErrorLog(err) return end
		local min, max = max_int, -1
		for i = 1, #files do
			local index = string.match(files[i], pattern)
			if index then
				index = tonumber(index)
				min = Min(min, index)
				max = Max(max, index)
			end
		end
		if min <= max then
			self.min_file_index = min
			self.max_file_index = max + 1
		end
		self.event_source = string.format("TupleStorage %s/%s", self.sub_dir, self.file_name)
	end
	self.buffer = pstr("", self.max_buffer_size)
	self.flush_queue = {}
	if self.periodic_buffer_flush then
		CreateRealTimeThread(function(self)
			while self.buffer do
				self:Flush()
				Sleep(self.periodic_buffer_flush)
			end
		end, self)
	end
end

function TupleStorage:Done()
	self.done = true
	self.RawWrite = function() return "done" end
	self.DeleteFile = function() return "done" end
	self.DeleteFiles = function() return "done" end
	self:Flush()
	if self.buffer then self.buffer:free() end
	self.buffer = false
end

function TupleStorage:GetFileName(index)
	return string.format("%s/%s.%08d.%s", self.storage_dir, self.file_name, index, self.file_ext)
end

function TupleStorage:DeleteFile(file_index)
	if self.min_file_index == file_index then
		self.min_file_index = file_index + 1
	end
	if self.max_file_index == file_index then
		self.buffer_offset = 0
		self.buffer = pstr("", self.max_buffer_size)
	end
	local err = AsyncFileDelete(self:GetFileName(file_index))
	if err then
		self:ErrorLog(err, self:GetFileName(file_index))
		return err
	end
end

function TupleStorage:DeleteFiles()
	local result
	self.min_file_index = nil
	self.max_file_index = nil
	self.buffer_offset = 0
	self.buffer = pstr("", self.max_buffer_size)
	for file_index = self.min_file_index, self.max_file_index - 1 do 
		local err = AsyncFileDelete(self:GetFileName(file_index))
		if err then
			result = result or err
			self:ErrorLog(err, self:GetFileName(file_index))
		end
	end
	return result
end

local function _load(loader, err, ...)
	if err then
		return err
	end
	return loader(...)
end

function TupleStorage:LoadTuple(loader, line, file_index)
	local err = _load(loader, LuaCodeToTupleFast(line))
	if err then
		self:ErrorLog(err, self:GetFileName(file_index), line)
		return err
	end
end

-- err = loader(line, file_index, ...)
function TupleStorage:ReadAllTuplesRaw(loader, file_filter, mem_limit)
	local result, stop_enum, mem
	if mem_limit then
		collectgarbage("stop")
		mem = collectgarbage("count")
	end
	local process_thread
	for file_index = self.min_file_index, self.max_file_index do
		local file_name = self:GetFileName(file_index)
		if self.done then result = "done" break end
		if not file_filter or file_filter(self, file_name, file_index) then
			local err, data = AsyncFileToString(file_name, nil, nil, "lines")
			if not err or (err ~= "Path Not Found" and err ~= "File Not Found") then -- some journal/blob files are going to be deleted, we want to skip these
				if not err then
					if IsValidThread(process_thread) then
						WaitMsg(process_thread)
					end
					process_thread = CreateRealTimeThread(function(data)
						for i = 1, #data do
							local err = loader(data[i], file_index)
							result = result or err
						end
						data = nil
						if mem_limit and collectgarbage("count") - mem > mem_limit then
							collectgarbage("collect")
							collectgarbage("stop")
							mem = collectgarbage("count")
						end
						Msg(CurrentThread())
					end, data)
				else
					self:ErrorLog("ReadAllTuplesRaw", err, file_name)
					result = result or err
				end
			end
		end
	end
	if IsValidThread(process_thread) then
		WaitMsg(process_thread)
	end
	if mem_limit then
		collectgarbage("collect")
		collectgarbage("restart")
	end
	return result
end

function TupleStorage:RawRead(file_index, file_offset, data_size)
	-- read from flush queue
	local queue = self.flush_queue
	for i = 1, #queue do
		local qfile_index, qbuffer, qoffset = unpack_params(queue[i])
		if file_index == qfile_index and file_offset >= qoffset and file_offset < qoffset + #qbuffer then
			local offset = file_offset - qoffset
			return qbuffer:sub(offset, offset + data_size)
		end
	end
	-- read from buffer
	if self.buffer and file_index == self.max_file_index and file_offset >= self.buffer_offset then
		local offset = file_offset - self.buffer_offset
		return qbuffer:sub(offset, offset + data_size)
	end
	-- read from file
	local err, data = AsyncFileToString(self:GetFileName(file_index), data_size, file_offset)
	if err then
		self:ErrorLog("RawRead", err, self:GetFileName(file_index), file_offset, data_size)
		return err
	end
	return nil, data
end

--[[
function TupleStorage:ReadAllTuples_old(loader, file_filter, mem_limit)
	return self:ReadAllTuplesRaw(function(line, file_index)
		return self:LoadTuple(loader, line, file_index)
	end, file_filter, mem_limit)
end
--]]

function TupleStorage:ReadAllTuples(loader, file_filter, mem_limit)
	local result, mem
	if mem_limit then
		collectgarbage("stop")
		mem = collectgarbage("count")
	end
	local process_thread
	for file_index = self.min_file_index, self.max_file_index do
		local file_name = self:GetFileName(file_index)
		if self.done then result = "done" break end
		if not file_filter or file_filter(self, file_name, file_index) then
			local err, data = AsyncFileToString(file_name, nil, nil, "pstr")
			if not err or (err ~= "Path Not Found" and err ~= "File Not Found") then
				if not err then
					if IsValidThread(process_thread) then
						WaitMsg(process_thread)
					end
					process_thread = CreateRealTimeThread(function(data, file_name)
						local err_table = data:parseTuples(loader)
						data:free()
						for i, err in ipairs(err_table) do
							if err then
								self:ErrorLog("ReadAllTuples", err, file_name, i)
							end
							result = result or err
						end
						if mem_limit and collectgarbage("count") - mem > mem_limit then
							collectgarbage("collect")
							collectgarbage("stop")
							mem = collectgarbage("count")
						end
						Msg(CurrentThread())
					end, data, file_name)
				else
					self:ErrorLog("ReadAllTuples", err, file_name)
					result = result or err
				end
			end
		end
	end
	if IsValidThread(process_thread) then
		WaitMsg(process_thread)
	end
	if mem_limit then
		collectgarbage("collect")
		collectgarbage("restart")
	end
	return result
end

function TupleStorage:ReadTuple(loader, file_index, file_offset, data_size)
	local err, line = self:RawRead(file_index, file_offset, data_size)
	if err then return err end
	return self:LoadTuple(loader, line, file_index)
end

function TupleStorage:PreFlush(filename, data, offset)
end

function TupleStorage:Flush(wait)
	local buffer = self.buffer
	if not buffer or #buffer == 0 then return end
	local flush_request = {self.max_file_index, buffer, self.buffer_offset}
	self.flush_queue[#self.flush_queue + 1] = flush_request
	self.buffer_offset = self.buffer_offset + #buffer
	if self.buffer_offset > self.max_file_size then
		self.buffer_offset = 0
		self.max_file_index = self.max_file_index + 1
	end
	self.buffer = pstr("", self.max_buffer_size)
	if not IsValidThread(self.flush_thread) then
		self.flush_thread = CreateRealTimeThread(function()
			while self.flush_queue[1] do
				local data = self.flush_queue[1]
				local file_index, buffer, offset = data[1], data[2], data[3]
				local file_name = self:GetFileName(file_index)
				self:PreFlush(file_index, buffer, offset)
				local err = AsyncStringToFile(file_name, buffer, offset ~= 0 and offset)
				table.remove(self.flush_queue, 1)
				Msg(data)
				if err then
					self:ErrorLog(err, file_name, offset, #buffer)
				end
				buffer:free()
			end
			self.flush_thread = false
		end)
	end
	if wait then
		WaitMsg(flush_request)
	end
end

function TupleStorage:WriteTuple(...)
	return self:RawWrite(TupleToLuaCodePStr(...), true)
end

function TupleStorage:WriteTupleChecksum(...)
	return self:RawWrite(TupleToLuaCodeChecksumPStr(...), true)
end
	
function TupleStorage:RawWrite(data, free)
	local data_size = #data
	local size = #self.buffer + data_size + 1
	-- flush if needed
	if self.buffer_offset + size > self.max_file_size or size > self.max_buffer_size then
		self:Flush()
	end
	-- write to buffer
	local buffer = self.buffer
	local tuple_offset = self.buffer_offset + #buffer
	buffer:append(data, "\n")

	if free then data:free() end
	return nil, self.max_file_index, tuple_offset, data_size
end

function TableLoader(t)
	return function(...) t[#t + 1] = {...} end
end

--[[ Tests

local function pr(err)
	if err then
		print("Error:", err)
	end
end

local value_len = 160
local values_count = 5

function StorageWriteTest(records)
	Sleep(200)
	records = records or 10000
	printf("Writing storage test with %d records of %d values of len %d", records, values_count, value_len)
	local storage = TupleStorage:new{ storage_dir = "TestStorage",
		-- max_buffer_size = 10*1024*1024,
	}
	print("Deleting files")
	pr(storage:DeleteFiles())
	local item = string.rep("v", value_len)
	local data = {}
	for i = 1, values_count do
		data[i] = item
	end
	print("Writing")
	local time = GetPreciseTicks(1000)
	for i = 1, records do
		pr(storage:WriteTuple(unpack_params(data)))
	end
	printf("Writing done for %d ms", GetPreciseTicks(1000) - time)
	print("Flushing")
	time = GetPreciseTicks(1000)
	storage:Flush(true)
	printf("Flushing done for %d ms", GetPreciseTicks(1000) - time)
	storage:delete()
end

local records, values, len = 0, 0, 0
local function loader(...)
	local data = {...}
	records = records + 1
	for i = 1, #data do
		values = values + 1
		len = len + #data[i]
	end
end

function StorageReadTest()
	Sleep(200)
	records, values, len = 0, 0, 0
	
	printf("Reading all storage records test")
	local storage = TupleStorage:new{ storage_dir = "TestStorage" }
	print("Reading")
	local time = GetPreciseTicks(1000)
	storage:ReadAllTuples(loader)
	printf("Reading done for %d ms", GetPreciseTicks(1000) - time)
	if values == 0 then
		print("Nothing read")
	else
		printf("Read %d records with avg %d values of avg len %d", records, values / records, len / values)
	end
	storage:delete()
end

function StorageReadTest2(n, threads)
	Sleep(200)
	n = n or 1000

	printf("Reading random storage records test")
	local storage = TupleStorage:new{ storage_dir = "TestStorage" }
	print("Reading")
	local time = GetPreciseTicks(1000)
	local rand, seed = BraidRandom(time)
	local record_size = values_count * (value_len + 2) + values_count
	local records_in_file = (storage.max_file_size + record_size - 1) / record_size
	threads = threads or 1
	n = n / threads
	for k = 1, threads do
		CreateRealTimeThread(function()
			for i = 1, n do
				rand, seed = BraidRandom(seed, 10000)
				storage:ReadTuple(loader, rand / records_in_file + 1, (rand % records_in_file) * record_size, record_size)
			end
			threads = threads - 1
			if threads == 0 then
				Msg("Test2Done")
			end
		end)
	end
	WaitMsg("Test2Done")
	printf("Reading done for %d ms", GetPreciseTicks(1000) - time)
	if values == 0 then
		print("Nothing read")
	else
		printf("Read %d records with avg %d values of avg len %d", records, values / records, len / values)
	end
	storage:delete()
end

--]]