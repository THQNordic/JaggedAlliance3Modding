if not FirstLoad then return end

hr.TrimParticles = 1
hr.MaxVisHeight = 25

hr.EnablePostProcRadialBlur = 0
hr.EnablePostProcDistanceBlur = 0
hr.EnableScreenSpaceAmbientObscurance = 0
hr.EnablePostProcAA = 1

hr.Shadowmap = 1

hr.ShadowPCFSize = 3
hr.ShadowCSMCascades = (Platform.ps4 or Platform.xbox_one and not Platform.xbox_one_x) and 3 or 4
hr.ShadowCSMRangeMinimum = 30
hr.ShadowCSMRangeMultiplier = 200
hr.ShadowSDSMEnable = true

hr.SSRZThickness = 0.07
hr.SSRZThicknessCoef = 0.005

hr.EnableDeposition = 1
-- Trails
hr.MaxTrails = 128

hr.GrassFadeRangeMin = 80
hr.GrassFadeRangeMax = 120

-- camera default parameters
hr.FarZ     = 2048*1414 -- diagonal of 2048 map
hr.NearZ    = 500
hr.CameraMaxZoomSlow = "0.05"
hr.CameraMaxZoomSpeed = "0.5"
hr.CameraMaxPanSpeed = 3
hr.CameraMaxPanSpeedFast = 40
hr.CameraMaxClampZ = 1200000
hr.CameraMaxClampXY = 700000

ShadingConst = {}
SetupVarTable(ShadingConst, "ShadingConst.")
SetVarTableLock(ShadingConst, true)

ShadingConst.ConstructionStage0Color = RGBA(40,  125, 130, 30)
ShadingConst.ConstructionStage1Color = RGBA(50,   70, 130, 30)
ShadingConst.ConstructionStage2Color = RGBA(45,  185,  25, 30)

-- ==== Shadowmap bias and rendering settings ===

ShadowBias = {
	Small = {
		clamp  = "0.0",
		slope  = "0.0",
		offset = "0.0",
	},
	Medium = {
		clamp  = "0.0",
		slope  = "0.0",
		offset = "0.0",
	},
	Large = {
		clamp  = "0.0",
		slope  = "0.0",
		offset = "0.0",
	},
	LowSlope = {
		clamp = "0.0",
		slope = "0.0",
		offset = "0.0",
	},
	Terrain = {
		clamp  = "0.0",
		slope  = "0.0",
		offset = "0.0",
	}
}

hr.ShadowmapSize = 4096
hr.LightShadowsSize = 4096
hr.NumberOfLightsWithShadows = 64

if Platform.neo or Platform.scorpio then
hr.UIL_TextureWidth = 4096
hr.UIL_TextureHeight = 4096
else
hr.UIL_TextureWidth = 2048
hr.UIL_TextureHeight = 2048
end

hr.FovAngle = 70*60

hr.FovAngleAutoMinY = 40
hr.FovAngleAutoMaxY = 60
hr.FovAngleAutoLimits = 0

hr.HorizonWaterRange = 3000000

hr.ShadowFrustumNearCapOffset = 130

ShaderLists = {}

hr.ShadowFadeOutRangePercent = 30  -- shadows will fade more sharply, but keep their strength at longer distances

hr.ForceRefractionCopy = 1

hr.EnableShaderCompilation = 1

--  Setup for the sun path. Times assume 24h Earth day
hr.TODSunriseTime = 3*60 + 50
hr.TODSunriseAzi  = 114*60
hr.TODSunsetTime = 20*60 + 10
hr.TODSunsetAzi  = 246*60
hr.TODSunMaxElevation = 60*60
hr.TODSunShadowMinAltitude = 15*60

-- Change the celestial pole for a different planet
-- Coords are in Equatorial coordinate system, see Wiki
-- Defaults are for the pole on Earth (near Polaris). Example for Sirius:
-- hr.SkyCelestialPoleRightAscension = CSphereRA(6, 45, 9)
-- hr.SkyCelestialPoleDeclination = CSphereDec(-16, 42, 58)

const.MovieCorrectionDesaturation = 0
const.MovieCorrectionGamma = 1700

hr.ShadowSDSMReadbackLatency=1

if Platform.xbox then
	hr.EnableShaderCompilation = 0
end

InsertProceduralMeshShaders({
	-- Define project specific mesh shaders.
	{ shaderid = "RangeContours.fx", defines = {"RANGE_CONTOUR"}, name = "range_contour", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"RANGE_CONTOUR_DEFAULT"}, name = "range_contour_default", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"INSIDE_BORDER"}, name = "inside_border_active", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"COMBAT_BORDER"}, name = "combat_border", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	{ shaderid = "RangeContours.fx", defines = {"INSIDE_BORDER", "INACTIVE"}, name = "inside_border_inactive", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"INSIDE_BORDER", "INACTIVE"}, name = "enemy_aware_range", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "never"  },
	{ shaderid = "RangeContours.fx", defines = {"RANGE_CONTOUR"}, name = "path_contour", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	{ shaderid = "RangeContours.fx", defines = {"CENTERED_LINE"}, name = "centered_line", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	{ shaderid = "RangeContours.fx", defines = {"VISION_LINE"}, name = "vision_line", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	{ shaderid = "RangeContours.fx", defines = {"EXIT_ZONE"}, name = "exit_zone", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"CONE"}, name = "cone", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	{ shaderid = "RangeContours.fx", defines = {"MAP_BORDER"}, name = "map_border", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"GROUND_STROKES"}, name = "ground_strokes", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "runtime"  },
	{ shaderid = "RangeContours.fx", defines = {"DEPLOYMENT_GRID"}, name = "deployment_grid", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "Overwatch.fx", defines = {"AOE_TILES_SECTOR"}, name = "aoe_tiles_sector", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
		blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "Overwatch.fx", defines = {"OVERWATCH_WALLS"}, name = "overwatch_lines", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
		blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "Overwatch.fx", defines = {"GRENADE_SPHERE"}, name = "grenade_sphere", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
		blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "Overwatch.fx", defines = {"GRENADE_AOE_TILES_SPHERE"}, name = "grenade_aoe_tiles_sphere", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
		blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"MELEE_AOE_TILES"}, name = "melee_aoe_tiles", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
		blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"AOE_TILES_CIRCLE"}, name = "aoe_tiles_circle", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"AOE_TILES_CYLINDER"}, name = "aoe_tiles_cylinder", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
	{ shaderid = "RangeContours.fx", defines = {"AWARENESS_INDICATOR"}, name = "awareness_indicator", topology = const.ptTriangleList, cull_mode = const.cullModeNone,
			blend_mode = const.blendNormal, depth_test = "always"  },
})

-- Hair Parameters initial values for testing purposes
hr.HairRoughness = 100
hr.HairMetallic = 50

function LimitTextureMips()
	local resources = {
		{res = "UI/SatelliteView/SatView.dds", MinLevel = 1},
		{res = "Textures/2216029.dds", MinLevel = 2},
	}
	local folders = {
		"UI/Mercs/",
		"UI/Enemies/",
		"UI/NPCs/",
	}
	for _,folder in ipairs(folders) do
		local err, files = AsyncListFiles(folder, "*", "")
		for _,file in ipairs(files) do
			resources[#resources+1] = {res = file, MinLevel = 1}
		end
	end

	for _,res in ipairs(resources) do
		local updated = ResourceManager.SetMetadataField(ResourceManager.GetResourceID(res.res), "MinLevel", res.MinLevel)
		assert(updated)
	end
end

function OnMsg.Start()
	if Platform.ps4 and not Platform.ps4_pro or Platform.xbox_one and not Platform.xbox_one_x then
		LimitTextureMips()
	end
end