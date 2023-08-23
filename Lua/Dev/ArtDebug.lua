function GetEntityMeshesMaterialsWithoutSSS(entity, required)
	local state_idx_name = {}
	for state_name, state_idx in pairs(EntityStates) do
		state_idx_name[state_idx] = state_name
	end
	
	local meshes_no_SSS, material_marked = {}, {}
	local mesh_states_map, mesh_lod_map = GetEntityMaterialsMap(entity)
	for mesh_name, mesh_states in pairs(mesh_states_map) do
		local lod = mesh_lod_map[mesh_name]
		for _, state_idx in ipairs(mesh_states) do
			local state_name = state_idx_name[state_idx]
			local material = GetStateMaterial(entity, state_name, lod)
			if material and not material_marked[material] then
				local num_sub_mtls = GetNumSubMaterials(material)
				local any, all = false, true
				for i = 1, num_sub_mtls do
					local mat_props = GetMaterialProperties(material, i - 1)
					if mat_props.SSS == 0 then
						all = false
					else
						any = true
					end
				end
				if required == "all" then
					if not all then
						table.insert(meshes_no_SSS, material)
						material_marked[material] = true
					end
				else--if required == "any" then
					if not any then
						table.insert(meshes_no_SSS, material)
						material_marked[material] = true
					end
				end
			end
		end
	end
	
	return next(meshes_no_SSS) and meshes_no_SSS
end


function GetHeadsTopsWithoutSSS()
	local classes = table.union(ClassDescendantsList("CharacterHead"), ClassDescendantsList("CharacterBody"))
	local entities = {}
	for _, class_name in ipairs(classes) do
		local class = g_Classes[class_name]
		local entity = class:GetEntity() or class.entity
		if IsValidEntity(entity) then
			table.insert(entities, entity)
		end
	end
	local meshes_no_SSS = {}
	for _, entity in ipairs(entities) do
		local meshes = GetEntityMeshesMaterialsWithoutSSS(entity, "any")
		if meshes then
			table.iappend(meshes_no_SSS, meshes)
		end
	end
	table.sort(meshes_no_SSS)
	print(string.format("Meshes with materials without SSS: %d", #meshes_no_SSS))
	
	return meshes_no_SSS
end