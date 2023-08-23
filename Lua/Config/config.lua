-------------------------------------------------------------------------------
-------------    General Config    --------------------------------------------
-------------------------------------------------------------------------------

config.SaveObjectsOrder = {
	{ "GridMarker" },
}

Libs.Volumes = true

config.Sim = false
config.Mods = true
config.GedFunctionObjectsTestHarness = true
config.SaveGameScreenshot = true
config.GamepadTestOnly = false
config.ScreenshotsWithUI = true
config.AutosaveAllowed = true

if Platform.developer then
config.RegisterSavFileHandler = true
end

if insideHG() then
	local bender_folder = "Zulu"
	if Platform.pc then
		config.CrashFolder = string.format("\\\\bender.haemimontgames.com\\%s\\Logs\\Crashes", bender_folder)
	elseif Platform.linux then
		config.CrashFolder = string.format("/media/bender/%s/Logs/Crashes", bender_folder)
	elseif Platform.osx then
		config.CrashFolder = string.format("/Volumes/%s/Logs/Crashes", bender_folder)
	end
	
	config.DesyncPath = string.format("\\\\bender.haemimontgames.com\\%s\\Logs\\Desyncs", bender_folder)
end

const.PerObjectHandlePool = 8*1024

function OnMsg.XInputInited()
	--lock gamepad thumbsticks while not in gamepad mode to avoid moving the camera
	--(also see OnMsg.GamepadUIStyleChanged in MarsMessengeQuestionBox.lua)
	local lock = GetUIStyleGamepad() and 0 or 1
	hr.XBoxLeftThumbLocked = lock
	hr.XBoxRightThumbLocked = lock
end

-- User-visible version string. Please keep in sync with the string in Src/Project.h!
UserVersion = "Version 0.01"
UserVersionNum = "0.01"

-- configurable for developer convenience
config.Vibration = 1
config.EditorWarnings = 1
config.FullscreenMode = 2
const.MaxScale = 200

config.RunUnfocused = 1
config.ClipCursor = 2

config.XInput = 1
config.XInputRefreshTime = 30

config.LightModelUnusedFeatures = {
	["water foam"] = true,
	["water waves"] = true,
	["dist_blur_desat"] = true,
}

-- Memory allocation related
config.ObjectPoolMem    = 144 * 1024        -- in KB
config.BonesMemory      = 8   * 1024 * 1024 -- in Bytes

config.MemorySavegameSize = 96*1024*1024
config.MemoryScreenshotSize = 16*1024*1024

config.GedLanguageEnglish = Platform.desktop -- don't mount/load English translation table on non-desktop platforms

config.postProcPredicates = {	
	-- none currently
}

config.FloatingTextEnabled = true

config.ConsoleDim = 0

config.OSVersionMajorReq = 0
config.OSVersionMinorReq = 0

if Platform.pc then
	config.OSVersionMajorReq = 6
	config.OSVersionMinorReq = 0
elseif Platform.osx then
	config.OSVersionMajorReq = 10
	config.OSVersionMinorReq = 7
elseif Platform.linux then
	config.OSVersionMajorReq = 3
	config.OSVersionMinorReq = 0
end

config.MapSlotsBand = 0 -- area outside map which is still covered by map slots; in meters

config.DefaultTerrainTileSize = 8000

config.MinimapScreenshotSize = 2048

config.LuaDebugInfo = true

config.SSRThresholdParentDistance = 0.05

hr.D3D11ParallelCompilation = 0

hr.EnableCloudsShadow = 1

hr.RenderTerrainFirst = 1

hr.AutoFadeDistanceScale = 2200
hr.FadeCullRadius = 550

hr.ObjAnimDefaultCrossfadeTime = 300

-- Statistics settings (To use in Gold Master, define STATISTICS in DefaultEngineConfig.h)
-- hr.RenderStatistics = 1
-- hr.DetailReport = 0

--[[ Extra Statistics -----------------------------------
	hr.StatsDelayedOps = 1
	hr.StatsMemory = 1
	hr.StatsCS = 1 (To use you will need to define DBG_CS as 2 in crCritical.h)
	hr.StatsCSType = 1
	hr.StatsParticles = 1
	hr.StatsTerrain = 1
	hr.StatsPools = 1
	hr.StatsShadows = 1
--]]-----------------------------------------------------

--[[ Extra Statistics settings --------------------------
	hr.StatsDumpToOutput = 1
	hr.StatsInterval = 500
	hr.StatsTextFont = "courier new"
	hr.StatsTextSize = 12
--]]-----------------------------------------------------

const.Camera3pRealTime = true
const.CameraControlRotationSpeed = 60

config.TileSizeTerrainBrushStep = false
config.MaxTerrainBrushStrength = 300
config.MinTerrainBrushStrength = 10
config.MaxTerrainBrushSize = 300 			--in meters
config.MinTerrainBrushSize = 10 			--in centimeters
config.MaxTerrainBrushHeightChange = 100	--in meters
config.MinTerrainBrushHeightChange = 100	--in meters
config.SmoothBrushInfluenceMin = 7
config.SmoothBrushInfluenceMax = 100
const.SelectionEnumRadius = 2000

hr.ShowSurfacesRange = 1000
hr.PreciseSelectionWidth = 9

config.EnableVoiceChat = true

config.DeprecatedParticleNames = {"_old", "test_"}

-- used by Compress() in luaNetSerialize.cpp;
-- Decompress() always supports all
config.SerializeCompressAlgo = "zstd"

config.WalkablesEnumExtend = 120

config.LoadAutoAttachData = true

config.AllowInvites = true
config.VideoPresetAutodetect = {
	{
		preset = "SteamDeck", 
		{
			"amd.*vangogh", -- steam deck
			"amd.*0405", -- steam deck
		},
	},
	{
		preset = "High", 
		{
			-- former Ultra, now High
			"geforce.*4%d[789]%d", -- e.g. geforce RTX 4070 - 4090
			"geforce.*3%d[89]%d", -- e.g. geforce RTX 3080 - 3090
			"radeon.*rx.*[67][89]%d%d", -- e.g. radeon rx 6800 - 6950
			-- former High, now also High
			"titan",
			"vega.*[456]%d",
			"vii",
			"geforce.*4%d[56]%d", -- e.g. geforce RTX 4050 - 4060
			"geforce.*3%d[567]%d", -- e.g. geforce RTX 3050 - 3070
			"geforce.*2%d[6789]%d", -- e.g. geforce RTX 2060 - 2090
			"geforce.*1%d[789]%d", -- e.g. geforce 1070 - 1090
			"radeon.*rx.*[567][67]%d%d", -- e.g. radeon rx 5600 - 7700
			"radeon.*rx.*5[89]%d", -- e.g. radeon rx 580 - 590
			"intel.*arc.*7%d%d", -- e.g. intel arc 770
		},
	},
	{
		preset = "Medium", 
		{
			"geforce.*[12]%d[56]%d", -- e.g. geforce GTX 1050
			"geforce.*9[78]%d", -- e.g. geforce GTX 980
			"radeon.*rx.*6%d%d%d", -- e.g. radeon rx 6400 - 6500
			"radeon.*rx.*5%d%d%d", -- e.g. radeon rx 5500
			"radeon.*rx.*[45][567]%d", -- e.g. radeon rx 570
			"radeon.*rx.*4[678]%d", -- e.g. radeon rx 460 - 480
			"intel.*arc.*3%d%d", -- e.g. intel arc 380
		},
	},
	{
		preset = "Low", 
		{
			"intel",
			"vega",
			"geforce.*%d%d%d", -- e.g. geforce GTX 750
			"radeon.*r9", -- e.g. radeon R9 200 series
			"radeon.*r7", -- e.g. radeon R7 200 series
			"radeon.*hd", -- e.g. radeon HD 6800
		},
	},
}

config.TextureMemoryThresholds = {
	{ threshold = 1500, value = "Low"},
	{ threshold = 3000, value = "Medium"},
}

config.PasswordMinLen = 6
config.PasswordMaxLen = 128
config.PasswordHasMixedDigits = false
config.PasswordAllowCommon = true

-- limit/block forward compatibility:
-- this goes in savegame metadata as required_lua_revision, and game can't be loaded if current LuaRevision is less than it
-- If -1 is set, then the required_lua_revision will be the current LuaRevision when the save is made. (i.e. no forward compatibility)
config.SavegameRequiredLuaRevision = 332662

-- savegame backward compatibility
config.SupportedSavegameLuaRevision = 315737

config.InferParticleShaders = true -- particle shader lists only include actually used particle shader combinations (set to false for _all_ particle shader combinations, for the purposes of modded-in particles)

config.InitialInGameInterfaceMode = "IModeExploration"

config.DeveloperGrids = { "square_grid" }
config.DeveloperGridDefaultProperties = {
	GridLineThickness = 75,
	GridSquareSize = 1200,
	GridBoxMinX = 0,
	GridBoxMinY = 0,
	GridBoxMaxX = 10000000,
	GridBoxMaxY = 10000000,
}

config.TerrainHeightSlabOffset = MulDivRound(guim, -5, 100)
config.DefaultTerrainHeight = const.SlabSizeZ * 10 + config.TerrainHeightSlabOffset

config.MapSavedGameFlags = {
	const.gofMirrored,
	const.gofOnRoof,
	const.gofDontHideWithRoom,
	const.gofWarped,
	const.gofTerrainColorization,
	const.gofDetailClass0,
	const.gofDetailClass1,
	const.gofLowerLOD,
	const.gofGameSpecific2,
	const.gofGameSpecific3
}

config.MapSavedEnumFlags = {
	const.efWalkable,
	const.efApplyToGrids,
	const.efCollision,
	const.efVisible,
	const.efCameraMakeTransparent,
	const.efCameraRepulse,
	const.efSunShadow,
	const.efShadow,
}

config.FloatingTextClass = "ZuluFloatingText"
 
LoadPersistFlagTables()

config.AutoTestSaveMap = "H-2 - Town of Erny"
config.VideoSettingsMap = "I-1 - Flag Hill"
config.RenderingTestsMap = "_RenderingTests"

--Cover System params
-- TODO: move covers constants to collision.
hr.VoxelCoverRaysLengthPercents = 110
hr.VoxelCoverRaysHiThreshold = 30
hr.VoxelCoverRaysLoThreshold = 30

config.ParticleDynamicParams = true

config.PDASatelliteMercsDragAndDrop = false

GameColors = {
	["DarkA"] = RGB(52, 55, 61), -- (A)
	["DarkB"] = RGB(32, 35, 47), -- (B)
	["Light"] = RGB(230, 222, 202), -- Cream (C)
	["Grey"] = RGB(130, 128, 120), -- (D)
	["LightLighter"] = RGB(249, 249, 219), -- (E)
	["LightDarker"] = RGB(195, 189, 172), -- (F)
	["Enemy"] = RGB(191, 67, 77), -- Red (I)
	["EnemyLighter"] = RGB(232, 121, 128), -- (I1)
	["Player"] = RGB(61, 122, 153), -- Blue (J)
	["PlayerLighter"] = RGB(92, 163, 185), -- (J1)
	["Sand"] = RGB(196, 175, 117), -- (K)
	["Yellow"] = RGB(215, 159, 80), -- (L)
	["LightGreen"] = RGB(124, 130, 96), -- (G)
	["DarkGreen"] = RGB(88, 92, 68), -- (H)
	["Hyperlink"] = RGB(76,62,255), -- blue
	["HyperlinkClicked"] = RGB(127,65,195)-- purple
}

const.WindModifierMaskFlags = {
	"Bush", -- const.WindModifierMaskBush
	"Corn", -- const.WindModifierMaskCorn
	"Grass", -- const.WindModifierMaskGrass
}

const.HyperlinkColors = {IMP = RGB(127,65,195)}

GameColors.A = GameColors.DarkA
GameColors.B = GameColors.DarkB
GameColors.C = GameColors.Light
GameColors.D = GameColors.Grey
GameColors.E = GameColors.LightLighter
GameColors.F = GameColors.LightDarker
GameColors.G = GameColors.LightGreen
GameColors.H = GameColors.DarkGreen
GameColors.I = GameColors.Enemy
GameColors.I1 = GameColors.EnemyLighter
GameColors.J = GameColors.Player
GameColors.J1 = GameColors.PlayerLighter
GameColors.K = GameColors.Sand
GameColors.L = GameColors.Yellow
GameColors.M = RGB(222, 60, 75) -- Referenced in 184340 as R and K
GameColors.N = RGB(81, 45, 57)

function GetColorWithAlpha(color, alpha)
	local r, g, b = GetRGB(color)
	return RGBA(r, g, b, alpha)
end

const.DefaultSharpness = "High"

const.MaxRoomVoxelSizeX = 52
const.MaxRoomVoxelSizeY = 52
const.MaxRoomVoxelSizeZ = 52

const.ControllerUIScale = 100

if Platform.trailer then
	config.AutoControllerHandling = false
	config.AutoControllerHandlingType = false
	if rawget(_G, "SwitchControls") then
		CreateRealTimeThread(SwitchControls, false)
	end
else
	config.AutoControllerHandling = true
	config.AutoControllerHandlingType = "auto"
end

config.IdleAimingDelay = 500

config.DebugReplayDesync = true

config.PhotoMode_DisablePhotoFilter = true
config.PhotoMode_DisableBloomStrength = true
config.PhotoMode_DisableDOF = true