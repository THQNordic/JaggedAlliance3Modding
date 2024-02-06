if FirstLoad then
	PostProc_DefinePasses {
		{ shader = "PostProcCommon.fx" },
		{ name = "down_4x" },
		{ name = "sqgauss" },
		{ name = "sqgauss9" },
		{ name = "sqgauss9_coc" },
		{ name = "coc_down_4x" },
		{ name = "coc_max" },
		{ name = "dof_apply" },
		{ name = "blur_desat" },
		{ name = "radial_blur" },
		{ name = "square_grid" },
		{ name = "grid45" },
		{ name = "hexgrid" },
		{ name = "isolines" }, { name = "isolines2" },
		{ name = "bilinear_scaling" },
		
		{ shader = "PostProcFSR.fx" },
		{ name = "fsr_upscale_fp32", dispatchX = 16, dispatchY = 16 },
		{ name = "fsr_rcas_fp32", dispatchX = 16, dispatchY = 16 },
		
		{ shader = "PostProcUpsample.fx" },
		{ name = "upscale_fmt_unorm_r24_uint_g8" },
		
		{ shader = "PostProcBloom.fx" },
		{ name = "hgauss_tint" },
		{ name = "hgauss_ldr" },
		{ name = "hgauss" },
		{ name = "vgauss_add" },
		{ name = "vgauss_ldr" },
		{ name = "vgauss" },		
		{ name = "bloom_output_raw_auto_exposure_split" },
		{ name = "bloom_output_raw" },
		{ name = "bloom_auto_exposure_split" },
		{ name = "bloom" },		
		{ name = "output_raw_auto_exp_split" },
		{ name = "output_raw" },
		{ name = "compose" },
		{ name = "auto_exp_split" },		
		{ name = "bright_pass_and_down_4x" },
		
		{ shader = "PostProcFXAA.fx" },
		{ name = "fxaa" },
		
		{ shader = "PostProcSMAA.fx" },
		{ name = "edge_detection" },
		{ name = "blending_weight_calc" },
		{ name = "neighborhood_blending" },

		{ shader = "PostProcHeatHaze.fx" },
		{ name = "heat_haze" },

		{ shader = "PostProcDebug.fx" },
		{ name = "debug_chroma_key" },
		{ name = "debug_color_pick" },
		
		{ shader = "PhotoFilter.fx" },
		{ name = "black_and_white_1" },
		{ name = "black_and_white_2" },
		{ name = "black_and_white_3" },
		{ name = "bleach_bypass" },
		{ name = "cover_art" },
		{ name = "orton_effect" },
		
		{ shader = "PostProcContour.fx" },
		{ name = "contour_inner" },
		{ name = "contour_inner_motion_vectors" },

		{ shader = "PostProcDebugMode.fx" },
		{ name = "debug_hue" },
		{ name = "debug_saturation" },
		{ name = "debug_lightness" },
	}
end

local function GetLinearBackbufferFormat()
	local format = GetBackBufferFormat()
	if GetSupportedShaderModel() ~= const.ShaderModelHLSL5_0 then
		format = GetLinearDataFormat(format)
	end 
	return format
end

local function PP_RebuildInternal()
	local screen_blur = hr.EnablePostProcScreenBlur > 0
	local auto_exposure_split = hr.EnablePostProcExposureSplit == 1
	local object_marking = hr.EnableObjectMarking > 0
	local contour_inner = hr.EnableContourInner > 0
	local temporal_type = hr.TemporalGetType()
	local temporal = temporal_type== "fsr2" or temporal_type == "dlss" or temporal_type == "xess"
	local fxaa = hr.EnablePostProcAA == 1 and not temporal and not screen_blur
	local smaa = hr.EnablePostProcAA == 2 and not temporal and not screen_blur
	local bloom = hr.EnablePostProcBloom > 0 and not screen_blur
	local dof = hr.EnablePostProcDOF > 0 and not screen_blur
	local distance_blur = hr.EnablePostProcDistanceBlur > 0 and not screen_blur
	local radial_blur = hr.EnablePostProcRadialBlur > 0 and not screen_blur
	local upscaling = hr.ResolutionPercent < 100 and not screen_blur
	local fsr_upscale = hr.ResolutionUpscale == "fsr" and upscaling
	local sharpen = hr.Sharpness > 0.0 and not screen_blur
	local output_raw = hr.PostProcRAWOutputPath ~= ""

	local registers = {}
	local stages = {}

	local regFlags = 0

	if distance_blur then table.iappend( registers, {
		{ name = "blur0", size_div = 4, register_flags = regFlags },
		{ name = "blur1", size_div = 4, register_flags = regFlags }})
	end
	
	if object_marking then
		table.iappend( registers, {
			{ name = "object_marking_depth", size_div = 1, register_flags = regFlags, format = const.fmt_unorm16_c1, resource_flags = const.GFXResourceFlagUsageDSV },
		})
	end
	
	if bloom then table.iappend( registers, {
		{ name = "mip1",  size_div = 2, register_flags = regFlags },
		{ name = "mip2",  size_div = 4, register_flags = regFlags },
		{ name = "mip3",  size_div = 8, register_flags = regFlags },
		{ name = "mip4",  size_div = 16, register_flags = regFlags },
		{ name = "mip5",  size_div = 32, register_flags = regFlags },
		{ name = "mip6",  size_div = 64, register_flags = regFlags },
		
		{ name = "mip2hb",  size_div = 4, register_flags = regFlags },
		{ name = "mip3hb",  size_div = 8, register_flags = regFlags },
		{ name = "mip4hb",  size_div = 16, register_flags = regFlags },
		{ name = "mip5hb",  size_div = 32, register_flags = regFlags },
		{ name = "mip6hb",  size_div = 64, register_flags = regFlags }})
	end
	
	if output_raw then
		table.iappend( registers, {
			{ name = "raw",  size_div = 1, register_flags = regFlags, format = const.fmt_unorm_r10g10b10a2 },
		})
	end
	
	if smaa then
		local SMAA_SearchTex_id = ResourceManager.GetResourceID("CommonAssets/System/SMAA_SearchTex.dds")
		local SMAA_AreaTex_id = ResourceManager.GetResourceID("CommonAssets/System/SMAA_AreaTex.dds")
		table.iappend( registers, {
			{ name = "SMAA_edgesTex", size_div = 1, register_flags = regFlags, format = const.fmt_unorm8_c2 },
			{ name = "SMAA_blendTex", size_div = 1, register_flags = regFlags, format = const.fmt_unorm8_c4 },
			{ name = "SMAA_SearchTex", texture = AsyncGetResource(SMAA_SearchTex_id) },
			{ name = "SMAA_AreaTex", texture = AsyncGetResource(SMAA_AreaTex_id) },
		})
	end

	if dof then table.iappend( registers, {
		{ name="dof_heavy", size_div = 4, register_flags = regFlags },
		{ name="dof_heavy_blurred", size_div = 4, register_flags = regFlags },
		{ name="dof_medium", size_div = 2, register_flags = regFlags },
		{ name="dof_medium_blurred", size_div = 2, register_flags = regFlags },
		{ name="coc_small", size_div = 4, register_flags = regFlags, format = const.fmt_unorm8_c1 },
		{ name="coc_small_blurred", size_div = 4, register_flags = regFlags, format = const.fmt_unorm8_c1 },
		{ name="coc_max", size_div = 4, register_flags = regFlags, format = const.fmt_unorm8_c1 },
	})
	end

	table.iappend( registers, {
		{ name="composed_ldr", size_div = 1, format = GetBackBufferFormat(), resource_flags = const.GFXResourceFlagUsageSRV | const.GFXResourceFlagUsageRTV },
	})

	if upscaling or temporal then 		
		table.iappend( registers, {
			{ name="fsr_upscale", size_div = 1, register_flags = const.rfBackbufferBaseSize, format = GetLinearDataFormat(GetBackBufferFormat()), resource_flags = const.GFXResourceFlagUsageSRV | const.GFXResourceFlagUsageUAV | const.GFXResourceFlagUsageRTV },
		})
	end

	if sharpen then
		table.iappend( registers, {
			{ name="sharpen", size_div = 1, register_flags = const.rfBackbufferBaseSize | const.rfDontClear, format = GetLinearDataFormat(GetBackBufferFormat()), resource_flags = const.GFXResourceFlagUsageSRV | const.GFXResourceFlagUsageUAV | const.GFXResourceFlagUsageRTV },
		})
	end
	
	if contour_inner then
		table.iappend( registers, {
			{ name="contour_inner_depth", size_div = 1, register_flags = const.rfBackbufferBaseSize, format = const.fmt_float32_c1, resource_flags = const.GFXResourceFlagUsageSRV | const.GFXResourceFlagUsageDSV },
		}) 
	end
	
	table.iappend( registers, {
		{ name="contour_outer_ping", size_div = 1, register_flags = const.rfBackbufferBaseSize | const.rfDontClear, format = const.fmt_uint32_c1, resource_flags = const.GFXResourceFlagUsageSRV | const.GFXResourceFlagUsageUAV },
		{ name="contour_outer_pong", size_div = 1, register_flags = const.rfBackbufferBaseSize | const.rfDontClear, format = const.fmt_uint32_c1, resource_flags = const.GFXResourceFlagUsageSRV | const.GFXResourceFlagUsageUAV },
	})

	local screen = "#screen"
	local screen_ldr = "composed_ldr"

	if contour_inner then
		table.iappend( stages, {
			{ custom = "Contour Inner Objects", outputs = "contour_inner_depth" },
		})
	end

	table.iappend( stages, {
		{ custom = "Contour Outer Objects", outputs = { "#depth", "contour_outer_ping", "contour_outer_pong" } },
	})

	-- blur & desat
	-- disable old postproc until we see what to do with it
	if distance_blur then table.iappend( stages, {
		{ name = "Scene 4x down", inputs = screen, outputs = "blur0", pass = "down_4x" },
		{ name = "Scene blur", inputs = "blur0", outputs = "blur1", pass = "sqgauss" },
		{ name = "Blur + Desat", inputs = { "blur1", screen, "#depth" }, outputs = screen, pass = "blur_desat" }})
	end

	if dof then table.iappend( stages, {
		{ name = "Circle of confusion small", inputs = "#depth", outputs = "coc_small", pass = "coc_down_4x" },
		{ name = "Circle of confusion blurred", inputs = "coc_small", outputs = "coc_small_blurred", pass = "sqgauss9_coc" },
		{ name = "Circle of confusion max", inputs = { "coc_small", "coc_small_blurred" }, outputs = "coc_max", pass = "coc_max" },
		{ name = "Circle of confusion max blurred", inputs = "coc_max", outputs = "coc_small", pass = "sqgauss9_coc" },
		{ name = "DOF Medium", inputs = screen, outputs = "dof_medium", pass = "down_4x" },
		{ name = "DOF Medium Blur", inputs = "dof_medium", outputs = "dof_medium_blurred", pass = "sqgauss9" },
		{ name = "DOF High", inputs = "dof_medium_blurred", outputs = "dof_heavy", pass = "down_4x" },
		{ name = "DOF High Blur", inputs = "dof_heavy", outputs = "dof_heavy_blurred", pass = "sqgauss9" },
		{ name = "DOF apply", inputs = { screen, "dof_medium_blurred", "dof_heavy_blurred", "coc_small", "#depth" }, outputs = screen, pass = "dof_apply" }})
	end

	if radial_blur then table.iappend( stages, {
		{ name = "Radial blur", inputs = screen, outputs = screen, pass = "radial_blur", predicates = "radial_blur" }})
	end
	
	if bloom then
		stages[#stages+1] = {
			name = "Bloom Bright + 2x down AE", inputs = { screen, "#Exposure" }, outputs = "mip1", pass = "bright_pass_and_down_4x"
		}
			
		table.iappend( stages, {
			{ name = "Bloom mip2", inputs = "mip1", outputs = "mip2", pass = "down_4x" },
			{ name = "Bloom mip3", inputs = "mip2", outputs = "mip3", pass = "down_4x" },
			{ name = "Bloom mip4", inputs = "mip3", outputs = "mip4", pass = "down_4x" },
			{ name = "Bloom mip5", inputs = "mip4", outputs = "mip5", pass = "down_4x" },
			{ name = "Bloom mip6", inputs = "mip5", outputs = "mip6", pass = "down_4x" },
			
			{ name = "Bloom HGauss mip6", inputs = "mip6", outputs = "mip6hb", pass = "hgauss_tint" },
			{ name = "Bloom VGauss mip6", inputs = "mip6hb", outputs = "mip6", pass = "vgauss" },
			
			{ name = "Bloom HGauss mip5", inputs = "mip5", outputs = "mip5hb", pass = "hgauss_tint" },
			{ name = "Bloom VGauss + Add mip5", inputs = { "mip5hb", "mip6" }, outputs = "mip5" , pass = "vgauss_add" },
			
			{ name = "Bloom HGauss mip4", inputs = "mip4", outputs = "mip4hb", pass = "hgauss_tint" },
			{ name = "Bloom VGauss + Add mip4", inputs = { "mip4hb", "mip5" }, outputs = "mip4" , pass = "vgauss_add" },
			
			{ name = "Bloom HGauss mip3", inputs = "mip3", outputs = "mip3hb", pass = "hgauss_tint" },
			{ name = "Bloom VGauss + Add mip3", inputs = { "mip3hb", "mip4" }, outputs = "mip3" , pass = "vgauss_add" },
			
			{ name = "Bloom HGauss mip2", inputs = "mip2", outputs = "mip2hb", pass = "hgauss_tint" },
			{ name = "Bloom VGauss + Add mip2", inputs = { "mip2hb", "mip3" }, outputs = "mip2" , pass = "vgauss_add" },
		})
	end

	local composition_pass = false
	if bloom then
		if output_raw then
			if auto_exposure_split then
				composition_pass = "bloom_output_raw_auto_exposure_split"
			else
				composition_pass = "bloom_output_raw"
			end
		else
			if auto_exposure_split then
				composition_pass = "bloom_auto_exposure_split"
			else
				composition_pass = "bloom"
			end
		end
	else
		if output_raw then
			if auto_exposure_split then
				composition_pass = "output_raw_auto_exposure_split"
			else
				composition_pass = "output_raw"
			end
		else
			if auto_exposure_split then
				composition_pass = "auto_exposure_split"
			else
				composition_pass = "compose"
			end
		end
	end
	
	stages[#stages + 1] = {
		name = "Composition",
		inputs = { bloom and "mip2" or "#none", screen, "#Exposure", "#ColorGradingLUT" },
		outputs = { screen_ldr, output_raw and "raw" or "#none" },
		pass = composition_pass
	}
	
	if output_raw then
		table.iappend( stages, {
			{ custom = "Export Register", inputs = "raw", outputs = { { texture = hr.PostProcRAWOutputPath, format = const.fmt_float16_c3 } } },
		})
	end
	
	if contour_inner then
		local contour_inner_pass = "contour_inner"
		local contour_inner_outputs = { screen_ldr }
		if temporal then
			contour_inner_pass = contour_inner_pass .. "_motion_vectors"
			contour_inner_outputs[#contour_inner_outputs+1] = "#ReactiveMask"
			contour_inner_outputs[#contour_inner_outputs+1] = "#TransparentMask"
		end
		table.iappend( stages, {
			{ name = "Contour Inner", inputs = { "#depth", "contour_inner_depth", screen_ldr }, outputs = contour_inner_outputs, pass = contour_inner_pass, predicates = "contour_inner" },
		})
	end
	
	table.iappend( stages, {
		{ custom = "Memory Copy", inputs = screen_ldr, outputs = screen_ldr },
		{ custom = "Post Lighting Objects", inputs = { screen_ldr, "#GBufferBaseColor", "#GBufferGeometryNormal", "contour_outer_ping" }, outputs = { "#depth", screen_ldr } },
	})
	
	if object_marking then
		table.iappend( stages, {
			{ custom = "Memory Copy", inputs = screen_ldr, outputs = screen_ldr },
			{ custom = "Object Marking", inputs = { screen_ldr }, outputs = { screen_ldr, "object_marking_depth" } },
		})
	end

	do
		local grids_outputs = {screen_ldr}
		if temporal then
			grids_outputs[#grids_outputs+1] = "#ReactiveMask"
		end
	table.iappend( stages, {
		{ name = "Editor grid", inputs = { "#depth", "#GBufferBaseColor" }, outputs = grids_outputs, pass = "square_grid", predicates = "square_grid" },
		{ name = "Editor grid", inputs = { "#depth", "#GBufferBaseColor" }, outputs = grids_outputs, pass = "grid45", predicates = "grid45" },
		{ name = "Editor grid", inputs = { "#depth", "#GBufferBaseColor" }, outputs = grids_outputs, pass = "hexgrid", predicates = "hexgrid" },
		{ name = "Editor grid", inputs = { "#depth", "#GBufferBaseColor" }, outputs = grids_outputs, pass = "isolines", predicates = "isolines" },
		{ name = "Editor grid", inputs = { "#depth", "#GBufferBaseColor" }, outputs = grids_outputs, pass = "isolines2", predicates = "isolines2" },
	})
	end
	
	local handle_image_based_aa = function(screen_ldr)
		local screen_ldr_binding = { texture = screen_ldr, format = GetSRGBDataFormat(GetBackBufferFormat()) }
		if fxaa then
			table.iappend( stages, {{ name = "FXAA", inputs = { screen_ldr_binding }, outputs = { screen_ldr_binding }, pass = "fxaa" }})
		end

		if smaa then
			table.iappend( stages, {
				{ name = "SMAA_edge_detection", inputs = { screen_ldr_binding }, outputs = "SMAA_edgesTex", pass = "edge_detection" },
				{ name = "SMAA_blending_weight_calc", inputs = { "SMAA_edgesTex", "SMAA_SearchTex", "SMAA_AreaTex" }, outputs = "SMAA_blendTex", pass = "blending_weight_calc" },
				{ name = "SMAA_neighborhood_blending", inputs = { screen_ldr_binding, "SMAA_blendTex", "SMAA_edgesTex" }, outputs = { screen_ldr_binding }, pass = "neighborhood_blending" },
			})
		end
	end

	if screen_blur then
		if temporal then
			table.iappend( stages, {
				{ custom = "Temporal", inputs = { screen_ldr, "#depth" }, outputs = "fsr_upscale" },
			})
			screen_ldr = "fsr_upscale"
		end
		local screen_ldr_binding = { texture = screen_ldr, format = GetSRGBDataFormat(GetBackBufferFormat()) }
		table.iappend( stages, {
			{ name = "Screen blur HGauss", inputs = { screen_ldr_binding }, outputs = { screen_ldr_binding }, pass = "hgauss_ldr" },
			{ name = "Screen blur VGauss", inputs = { screen_ldr_binding }, outputs = "#BackBuffer", pass = "vgauss_ldr" },
		})
		screen_ldr = "#BackBuffer"
	else
		handle_image_based_aa(screen_ldr)
		if temporal then
			table.iappend( stages, {
				{ custom = "Temporal", inputs = { screen_ldr, "#depth" }, outputs = "fsr_upscale" },
			})
			screen_ldr = "fsr_upscale"
		elseif upscaling then
			if fsr_upscale then
				table.iappend( stages, {
					{ name = "FidelityFX Upscale", inputs = { { texture = screen_ldr, format = GetLinearBackbufferFormat() } }, outputs = "fsr_upscale", pass = "fsr_upscale_fp32" },
				})
			else
				table.iappend( stages, {
					{ name = "Bilinear Scaling", inputs = { { texture = screen_ldr, format = GetLinearBackbufferFormat() } }, outputs = "fsr_upscale", pass = "bilinear_scaling" },
				})
			end
			screen_ldr = "fsr_upscale"
		end
		
		local format_haze = GetSRGBDataFormat(GetBackBufferFormat())
		table.iappend( stages, {
			{ custom = "Rain Streaks", inputs = "#depth", outputs = { { texture = screen_ldr, format = format_haze } } },
			{ name = "Heat Haze", inputs = { { texture = screen_ldr, format = format_haze }, "#depth", "#TerrainHeight" }, outputs = { { texture = screen_ldr, format = format_haze } }, pass = "heat_haze", predicates = "heat_haze" },
		})
	end

	if sharpen then
		local pass_rcas = "fsr_rcas_fp32"
		table.iappend( stages, {
			{ name = "FidelityFX RCAS",    inputs = { { texture = screen_ldr, format = GetLinearBackbufferFormat() } }, outputs = "sharpen", pass = pass_rcas },
			{ custom = "Memory Copy",      inputs = "sharpen", outputs = "#BackBuffer" },
		})
	elseif screen_ldr ~= "#BackBuffer" and (screen_ldr ~= "#screen_ldr" or upscaling) then
		-- if we're rendering to #screen_ldr without upscaling, that's already the renamed #BackBuffer
		table.iappend( stages, {
			{ custom = "Memory Copy",      inputs = screen_ldr, outputs = "#BackBuffer" },
		})
	end

	if Platform.developer then
		table.iappend( stages, {
			{ name = "Debug chroma key", inputs = { "#BackBuffer", "#depth" }, outputs = "#BackBuffer", pass = "debug_chroma_key", predicates = "debug_chroma_key" },
			{ name = "Debug color pick", inputs = "#BackBuffer", outputs = "#BackBuffer", pass = "debug_color_pick", predicates = "debug_color_pick" },
		})
	end
	
	if rawget(_G, "g_PhotoFilter") and g_PhotoFilter.pass ~= "" then
		local input_textures = { "#BackBuffer", "#depth", "#GBufferNormal", "#GBufferBaseColor", "#GBufferRM" }

		if g_PhotoFilter.tex1 and g_PhotoFilter.tex1 ~= "" then
			registers[#registers+1] = { name = "filter_tex_1", texture = g_PhotoFilter.tex1, id="filter_tex_1" }
			input_textures[#input_textures + 1] = "filter_tex_1"
		end
		if g_PhotoFilter.tex2 and g_PhotoFilter.tex2 ~= "" then
			registers[#registers+1] = { name = "filter_tex_2", texture = g_PhotoFilter.tex2, id="filter_tex_2" }
			input_textures[#input_textures + 1] =  "filter_tex_2"
		end

		
		table.iappend( stages, {
			{ name = "Photo Filter", inputs = input_textures, outputs = "#BackBuffer", pass = string.lower(g_PhotoFilter.pass) },
		})
	end
	
	if Platform.developer then
		local postproc_debug_mode = rawget(_G, "g_PostProcDebugMode")
		if postproc_debug_mode ~= "Off" then
			table.iappend( stages, {
				{ name = "Post Proc Debug", inputs = { "#BackBuffer" }, outputs = "#BackBuffer", pass = postproc_debug_mode },
			})
		end
	end
	
	PostProc_SetRegistersAndStages(registers, stages)
end

local RebuildThread = false

function PP_Rebuild()
	DeleteThread(RebuildThread)
	RebuildThread = CreateRealTimeThread(function()
		PP_RebuildInternal()
		RebuildThread = false
	end)
end

function OnMsg.ReportResources(resIds)
	local SMAA_SearchTex_id = ResourceManager.GetResourceID("CommonAssets/System/SMAA_SearchTex.dds")
	local SMAA_AreaTex_id = ResourceManager.GetResourceID("CommonAssets/System/SMAA_AreaTex.dds")
	resIds[SMAA_SearchTex_id] = ""
	resIds[SMAA_AreaTex_id] = ""
end