EngineBinAssetsPrints = {}
EngineBinAssetsPrint  = CreatePrint { "", output = function(s) table.insert(EngineBinAssetsPrints, s) end }
EngineBinAssetsPrintf = CreatePrint { "", output = function(s) table.insert(EngineBinAssetsPrints, s) end, format = string.format }
EngineBinAssetsError  = CreatePrint { "EB_ERROR", output = function(s) table.insert(EngineBinAssetsPrints, s) end }
EngineBinAssetsErrorf = CreatePrint { "EB_ERROR", output = function(s) table.insert(EngineBinAssetsPrints, s) end, format = string.format }

local function MarkTestEntityTextures(texture_list)
	local tex_map = {}
	local test_assets_path = ConvertToOSPath("svnAssets/Bin/Common/Materials/")
	for texture_id, path in pairs(texture_list) do
		local texture_name = path:sub(path:find("[^\\]*$"))
		tex_map[texture_name] = {
			id = texture_id,
			path = path,
			skip = string.starts_with(path, test_assets_path),
		}
	end
	return tex_map;
end

local function AddTextureHashes(textures_data, cached_hashes)
	local cached_hashes = cached_hashes or {}
	for texture_id, texture_data in pairs(textures_data) do
		local tex_hash = cached_hashes[texture_id]
		if not tex_hash then 
			local err, hash = AsyncFileToString(texture_data.path, nil, nil, "hash")
			if err then
				EngineBinAssetsError("AsyncFileToString(" .. texture_data.path .. ") failed: " .. err)
				return err
			else
				tex_hash = tostring(hash)
			end
		end
		texture_data.hash = tex_hash
	end
end

local function GetTexturesCachedHashes()
	local err, hash_list = FileToLuaValue("svnAssets/BuildCache/TextureHashes.lua")
	if err then
		EngineBinAssetsError("Could not load hash map with material textures!")
	end

	local cached_hashes = {}
	for filename, v in pairs(hash_list or empty_table) do
		cached_hashes[filename:sub(filename:find("[^/]*$"))] = tostring(v.hash)
	end

	return cached_hashes
end

function MarkUniqueTextures(textures_data)
	local sorted_texture_ids = table.keys(textures_data)
	table.sort(sorted_texture_ids, function (a, b) return #a == #b and a < b or #a < #b end)
	local unique_hashes = {}
	for _, texture_id in ipairs(sorted_texture_ids) do
		local tex_data = textures_data[texture_id]
		if not tex_data.skip then
			local tex_alias = unique_hashes[tex_data.hash]
			
			if tex_alias then
				tex_data.alias = tex_alias
			elseif not tex_data.hash then
				EngineBinAssetsError("Missing texture hash for(" .. texture_id .. ")")
			else
				--tex_data.alias = texture_id -- not needed it its the same
				unique_hashes[tex_data.hash] = texture_id
			end
		end
	end
	local num_tex = table.count(textures_data)
	local num_unique = table.count(unique_hashes)
	EngineBinAssetsPrintf("Entity textures: %d (%d Unique, %d Duplicates)", num_tex, num_unique, num_tex - num_unique)	
	return unique_hashes
end

local function RemapMaterialTextures(mat_name, textures_data, used_tex, ent_textures)
	local num_sub_mats = GetNumSubMaterials(mat_name)
	for subi=1, num_sub_mats do
		local props = GetMaterialProperties(mat_name, subi-1)
		local new_props = false
		for prop, value in sorted_pairs(props) do
			if type(value) == "string" then
				local tex_name = value:sub(value:find("[^/]*$"))
				if tex_name then
					local tex_data = textures_data[tex_name]
					if tex_data then
						if tex_data.alias then
							new_props = new_props or {}
							new_props[prop] = textures_data[tex_data.alias].id

							ent_textures[tex_data.alias] = true

							local alias_data = textures_data[tex_data.alias]
							alias_data.used_in = alias_data.used_in or {}
							table.insert(alias_data.used_in, mat_name)
						else
							used_tex[tex_name] = tex_data.path
							ent_textures[tex_name] = true

							tex_data.used_in = tex_data.used_in or {}
							table.insert(tex_data.used_in, mat_name)
						end
					end
				elseif value:find("<unknown>", 1, "plain") then
					EngineBinAssetsPrintf("once", "Missing texture Textures/%s in material %s", value:match("Textures/(.*)%.<unknown>"), mat_name)
				end
			end
		end
		if new_props then
			SetMaterialProperties(mat_name, subi-1, new_props)
		end
	end
end

local function BuildTextureIdx(used_tex)
	local tex_idx = {}
	local textures = table.keys(used_tex)
	table.sort(textures, function (a, b) return #a == #b and a < b or #a < #b end)
	
	for _, tex_name in ipairs(textures) do
		tex_idx[#tex_idx+1] = string.format("Textures/%s=%s", tex_name, used_tex[tex_name])
	end
	
	local filename = "entities.txt"
	local path = "svnAssets/BuildCache/win32/TextureIdx/"
	local err = AsyncCreatePath(path)
	assert(not err, "Error creating textures idx path: " .. tostring(err))
	local err = StringToFileIfDifferent(path .. filename, table.concat(tex_idx, "\r\n"))
	assert(not err, "Error writing textures idx: " .. tostring(err))
end

local function ShortenTexturePaths(textures_data)
	for _, texture_data in pairs(textures_data) do
		texture_data.path = string.match(texture_data.path, "\\([^\\]+Assets.+)$")
	end
end

function CollapseMaterialTextures(texture_list, entities, cached_hashes, shorten_paths)
	local textures_data = MarkTestEntityTextures(texture_list)
	AddTextureHashes(textures_data, cached_hashes)
	if shorten_paths then
		ShortenTexturePaths(textures_data)
	end
	MarkUniqueTextures(textures_data)

	local materials_seen, entity_textures, used_tex = {}, {}, {}
	for entity, _ in sorted_pairs(entities) do
		if entity:sub(1,1) ~= "#" then
			local ent_textures = {}
			local states = GetStates(entity)
			for si=1, #states do
				local state = GetStateIdx(states[si])
				local num_lods = GetStateLODCount(entity, state)
				for li=1, num_lods do
					local material = GetStateMaterial(entity, state, li - 1)
					if not materials_seen[material] then
						RemapMaterialTextures(material, textures_data, used_tex, ent_textures)
						materials_seen[material] = entity
						entity_textures[entity] = ent_textures
					else
						local other_entity = materials_seen[material]
						entity_textures[entity] = entity_textures[other_entity]
					end
				end
			end
		end
	end	
	
	return materials_seen, used_tex, textures_data
end

function CollapseAllTextures()
	local all_entities = GetAllEntities()
	local texture_list = CollectMtlReferencedTextures()
	local cached_hashes = GetTexturesCachedHashes()

	local materials_seen, used_tex, textures_data = CollapseMaterialTextures(texture_list, all_entities, cached_hashes, true)

	BuildTextureIdx(used_tex)

	return materials_seen, used_tex, textures_data
end

function CollapseEntitiesTextures(entities)
	local texture_list = {}
	for entity, _ in sorted_pairs(entities) do
		local states = GetStates(entity)
		for si=1, #states do
			local state = GetStateIdx(states[si])
			local state_textures = GetStateMaterialTextures(entity, state)
			table.append(texture_list, state_textures)
		end
	end

	local materials_seen, used_tex, textures_data = CollapseMaterialTextures(texture_list, entities)

	return materials_seen, used_tex, textures_data
end