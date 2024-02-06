DefineClass.DevDSForceModeDlg = {
	__parents = { "XDialog" },
}

if FirstLoad then
	DebugForceModeIdx = {
		gbuffers = 0,
		stencil = 0,
		misc = 0,
		lights = 0,
	}
end

local DebugForceModeList = {
	["gbuffers"]     = { "NORMAL", "GEOMETRY_NORMAL", "BASECOLOR", "COLORMAP", "ROUGHNESS", "METALLIC", "AO",  "SI", "TANGENT", "ENCODED_NORMAL", "DEPTH", "NONE"},

	["stencil"]      = { "STENCIL", "NONE" },
	
	["misc"]         = { "BRDF", "ENV_IRRAD","ENV_DIFFUSE", "SUN_DIFFUSE", "DIFFUSE",
	                     "ENV_SPECULAR","SUN_SPECULAR", "SPECULAR", "SUN_SHADOW", 
	                     "TRANSLUCENCY", "REFLECTION", "REFLECTION_ITERATIONS", "PRECISE_SELECTION_IDS", "NONE"},

	["lights"]       = { "LIGHTS", "LIGHTS_DIFFUSE", "LIGHTS_SPECULAR", "LIGHTS_SHADOW",
	                     "LIGHTS_COUNT", "LIGHTS_ATTENUATION", "LIGHTS_CLUSTER", "NONE"}
}

local DebugForceModeRemap = {
	["COLORMAP"] = "BASECOLOR",
	["TANGENT"] = "NORMAL",
}

local DebugForceModeHROptions =
{
	["STENCIL"]  = { ShowStencil = 2, ShowRT = "show_rt_buffer", ShowRTEnable = 1, },
	["COLORMAP"] = { ForceColorizationRGB = 1, DisableBaseColorMaps = 1, RenderClutter = 0, },
	["TANGENT"] = { UseTangentNormalMap = 1 },
	["REFLECTION"] = { EnableScreenSpaceReflections = 1, RenderClutter = 0, SSRDebug = 1 },
	["REFLECTION_ITERATIONS"] = { EnableScreenSpaceReflections = 1, RenderClutter = 0, SSRDebug = 2 },
	["PRECISE_SELECTION_IDS"] = { ShowPreciseSelectionIDs = 1, RenderTransparent = 1 },
}

function DevDSForceModeDlg:Init()
	XText:new({
		Id = "idText",
		Margins = box(100, 80, 0, 0),
		TextStyle= "GizmoText",
		HandleMouse = false,
	}, self)
	self.idText:SetText(self.context.text or "")
end

function DevDSForceModeDlg:Done()
	table.restore(hr, "ForceModeSpecific")
	table.restore(hr, "ForceMode")
	RecreateRenderObjects()
end

function OpenDevDSForceModeDlg(mode)
	CloseDialog("DevDSForceModeDlg")
	table.change(hr, "ForceMode", { 
		EnablePostprocess = 0,
		EnableScreenSpaceReflections = 0,
		EnableSubsurfaceScattering = 0,
		RenderTransparent = 0,
		RenderParticles = 0,
		ShowStencil = 0,
		ShowRT = "",
		ShowRTEnable = 0,
		DeferMode = DeferModes[DebugForceModeRemap[mode] or mode],
	})
	table.change(hr, "ForceModeSpecific", DebugForceModeHROptions[mode] or {})
	RecreateRenderObjects()
	OpenDialog("DevDSForceModeDlg", terminal.desktop, { text = mode })
end

function ToggleDebugForceMode(debug_type)
	if not debug_type then
		CloseDialog("DevDSForceModeDlg")
		return
	end
	local modes = DebugForceModeList[debug_type]
	local index = (DebugForceModeIdx[debug_type] % #modes) + (GetDialog("DevDSForceModeDlg") and 1 or 0)
	DebugForceModeIdx[debug_type] = index
	if index ~= #modes then
		OpenDevDSForceModeDlg(modes[index])
	else
		CloseDialog("DevDSForceModeDlg")
	end
	PP_Rebuild()
	RecreateRenderObjects()
end

if FirstLoad then
	g_PostProcDebugMode = "Off"
end

local PostProcDebugModesIdxs = {
	HsvDebug = 0,
}

local PostProcDebugModes = {
	HsvDebug = { names = {   			"Hue", 		"Saturation", 			"Lightness", 			"Lighness_WO_Shadows", 												"Off" },
					hr_vars = { 			{},			{},						{},			 			{ Shadowmap = 0, EnableScreenSpaceAmbientObscurance = 0 },	{} },
					debug_passes = { 	"debug_hue",	"debug_saturation",	"debug_lightness", 	"debug_lightness",														"Off" },
	}
}

DefineClass.PostProcDebugFeatureDlg = {
	__parents = { "XDialog" },
}

function PostProcDebugFeatureDlg:Init()
	XText:new({
		Id = "idText",
		Margins = box(20, 90, 0, 0),
		TextStyle= "EditorText",
		HandleMouse = false,
	}, self)
	self.idText:SetText(self.context.text or "")
end

function PostProcDebugFeatureDlg:Done()
	table.restore(hr, "PostProcForceMode")
end

function OpenPostProcDebugFeatureDlg(mode, idx)
	CloseDialog("PostProcDebugFeatureDlg")
	
	local hr_options = {}
	for op, value in pairs(PostProcDebugModes[mode].hr_vars[idx]) do
		hr_options[op] = value
	end
	table.change(hr, "PostProcForceMode", hr_options)
	
	OpenDialog("PostProcDebugFeatureDlg", terminal.desktop, { text = PostProcDebugModes[mode].names[idx] })
end

function ToggleHsvDebugForceMode(mode)
	local num_modes = #PostProcDebugModes[mode].debug_passes
	local idx = (PostProcDebugModesIdxs[mode] % num_modes) + 1
	PostProcDebugModesIdxs[mode] = idx
	
	if idx ~= num_modes then
		OpenPostProcDebugFeatureDlg(mode, idx)
	else
		CloseDialog("PostProcDebugFeatureDlg")
	end
	
	g_PostProcDebugMode = PostProcDebugModes[mode].debug_passes[idx]
	PP_Rebuild()
end