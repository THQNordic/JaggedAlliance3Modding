if FirstLoad then
	ProceduralMeshShaders = {}
	function InsertProceduralMeshShaders(ProceduralMeshShadersTable)
		RegisterProceduralMeshRules(ProceduralMeshShadersTable)

		for key, value in ipairs(ProceduralMeshShadersTable) do
			assert(not ProceduralMeshShaders[value.name], "Shader with that name already registered.")
			ProceduralMeshShaders[value.name] = value
		end
	end
	-- CommonShaders. Feel free to make such call in project specific render.lua
	InsertProceduralMeshShaders({
		{ shaderid = "ProceduralMesh.fx", defines = {}, name = "default_polyline", topology = const.ptLineStrip, cull_mode = const.cullModeNone,
			blend_mode = const.blendNone, depth_test = "runtime"  },
		{ shaderid = "ProceduralMesh.fx", defines = {}, name = "default_mesh", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
		{ shaderid = "ProceduralMesh.fx", defines = {}, name = "solid_mesh", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNone, depth_test = "always",  },
		{ shaderid = "ProceduralMesh.fx", defines = {}, name = "defer_mesh", topology = const.ptTriangleStrip, cull_mode = const.cullModeBack,
			blend_mode = const.blendNone, depth_test = "always", pass_type = const.PassDefer },
		{ shaderid = "ProceduralMesh.fx", defines = { "DEBUGM" }, name = "debug_mesh", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
		{ shaderid = "ProceduralMesh.fx", defines = { "SOFT" }, name = "soft_mesh", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime" },
		{ shaderid = "ProceduralMesh.fx", defines = {}, name = "mesh_linelist", topology = const.ptLineList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNone, depth_test = "runtime"  },
		{ shaderid = "ProceduralMesh.fx", defines = { "UI" }, name = "default_ui", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
		{ shaderid = "ProceduralMesh.fx", defines = { "UI", "TEX1_AS_SDF" }, name = "default_ui_sdf", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
		{ shaderid = "ProceduralMesh.fx", defines = {}, name = "blended_linelist", topology = const.ptLineList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	})
end