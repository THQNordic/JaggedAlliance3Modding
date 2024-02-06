DefineClass.MetadataCache = {
	__parents = {"InitDone"},
	cache_filename = "saves:/save_metadata_cache.lua",
	folder = "saves:/",
	mask = "*.sav",
}

function MetadataCache:Save()
	local data_to_save = {}
	for _, data in ipairs(self) do
		data_to_save[#data_to_save + 1] = data
	end
	local err = AsyncStringToFile(self.cache_filename, ValueToLuaCode(data_to_save, nil, pstr("", 1024)))
	return err
end

function MetadataCache:Load()
	self:Clear()
	local err, data_to_load = FileToLuaValue(self.cache_filename)
	if err then return err end
	if not data_to_load then return end
	for _, data in ipairs(data_to_load) do
		self[#self + 1] = data
	end
end

function MetadataCache:Refresh()
	assert(CurrentThread())
	local err, new_entries = self:Enumerate()
	if err then return err end
	local cached_dict = {}
	for idx, cached in ipairs(self) do
		cached_dict[cached[1]] = cached
		cached_dict[cached[1]]["idx"] = idx
	end
	local new_entries_dict = {}
	for _, entry in ipairs(new_entries) do
		new_entries_dict[entry[1]] = entry
	end
	
	for key, entry in pairs(new_entries_dict) do
		local cached = cached_dict[key]
		if cached then --refresh existing
			for i = 3, #cached do
				if cached[i] ~= entry[i] then
					self[cached.idx] = entry
					err, meta = self:GetMetadata(entry[1])
					if err then
						return err
					end
					self[cached.idx][2] = meta
					break
				end
			end
		else --add new
			self[#self + 1] = entry
			local err, meta = self:GetMetadata(entry[1])
			if err then
				return err
			end
			self[#self][2] = meta
		end
		
	end
	
	for i = #self, 1, -1 do
		if not new_entries_dict[self[i][1]] then --remove inexistent
			table.remove(self, i)
		end
	end
end

function MetadataCache:Enumerate()
	local err, files = AsyncListFiles(self.folder, self.mask, "relative,size,modified")
	local result = {}
	if err then
		return err
	end
	for idx, file in ipairs(files) do
		result[#result + 1] = { file, false, files.size[idx], files.modified[idx] }
	end
	return err, result
end

function MetadataCache:GetMetadata(filename)
	local loaded_meta, load_err
	local err = Savegame.Load(filename, function(folder)
		load_err, loaded_meta = LoadMetadata(folder)
	end)
	return load_err, loaded_meta
end

function MetadataCache:Clear()
	table.iclear(self)
end