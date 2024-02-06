if FirstLoad then
	SetupVarTable(const, "const.")
end

----- track const use before definition
--[[
const_read = {}
AllowConstRead = true
function OnMsg.ReloadLua()
	AllowConstRead = false
end
if FirstLoad then
	local function get_caller_info()
		local info = debug.getinfo(3, "Sl")
		if info.short_src == "CommonLua/Core/ConstDef.lua" then -- DefineConst function
			info = debug.getinfo(4, "Sl")
		end
		return string.format("%s(%d)", info.short_src or "???", info.currentline or 0)
	end
	local function const_eq(c1, c2)
		if type(c2) ~= "table" then
			return c1 == c2
		end
		local s1, s2 = pstr("", 1024), pstr("", 1024)
		s1:appendv(c1)
		s2:appendv(c2)
		return s1 == s2 or s1 == "nil" and s2 == "{}"
	end

	local org_const = const
	local engine_const = { SlabSizeX = true, SlabSizeY = true, SlabSizeZ = true }
	const = setmetatable({}, {
		__index = function (_, key)
			const_read[key] = get_caller_info()
			if not AllowConstRead and not engine_const[key] then
				print("Const read before consts are ready", const_read[key])
			end
			return org_const[key]
		end,
		__newindex = function (_, key, value)
			if const_read[key] then
				local info = get_caller_info()
				if const_read[key] == info then
					-- print("Read-write of const", key, info)
					const_read[key] = nil -- remove the read, this was a read-write (default value)
				elseif not const_eq(org_const[key], value) then
					print("const", key, "last used at", const_read[key], "changed at", info)
				end
			end
			org_const[key] = value
		end
	})
end
--]]

const.FallbackSize = 64

if Platform.cmdline then return end

const.Scale = {
	m = guim,
	cm = guic,
	voxelSizeX = const.SlabSizeX,
	deg = 60,
	sec = 1000,
	["%"] = 1,
	["‰"] = 1,
}

const.GameObjectMaxCollectionIndex = 0x0fff
const.GameObjectMaxRadius = 60*guim

const.DefaultMouseCursor = "CommonAssets/UI/cursor.tga"

red = RGB(255, 0, 0)
green = RGB(0, 255, 0)
blue = RGB(0, 0, 255)
black = RGB(0, 0, 0)
white = RGB(255, 255, 255)
yellow = RGB(255, 255, 0)
purple = RGB(128, 0, 128)
magenta = RGB(255, 0, 255)
orange = RGB(255, 165, 0)
cyan = RGB(0, 255, 255)

const.HyperlinkColors = {}

const.PredefinedSceneActors = {}

const.CameraEditorDefaultSharpness = 10

const.InterfaceAnimDuration = 100

-- cutscene light model overrides
const.CutsceneNearZ = 20

-- Camera Shake System
const.CameraClipExtendRadius = 20*guic
const.CameraShakeFOV = 120*60
const.ShakeRadiusInSight = 30*guim    -- the max dist the camera would shake if the shake origin is visible(in front of camera)
const.ShakeRadiusOutOfSight = 10*guim -- the max dist the camera would shake if the shake origin is not visible(behind the camera)
const.MaxShakeOffset = 3*guic         -- the shake offset at max power
const.MaxShakeRoll = 15               -- the shake roll at max power
const.MaxShakeDuration = 700          -- the duration of the shake effect at max power
const.MinShakeDuration = 300          -- the duration of the shake effect at min power
const.ShakeTick = 25                  -- the frequency of the shake waves, in ms
const.MaxShakePower = 1000

const.ParticleHandlesToggleRadius = 10		-- in meters

const.AnimMomentsToolObjDistToNearPlane = 8	-- in meters

const.DefaultTimeFactor = 1000
const.MinTimeFactor = 10
const.MaxTimeFactor = 1000000
const.MaxSaneTimeFactor = 100000

-- in ms * 0.001
const.CameraControllerStateUpdateTime = "0.5"
const.mouse_rotates_camera = false

const.VendorIds = {
	Intel = 8086,
	AMD = 1002,
	NVidia = 4318,
}

const.InvalidZ = 2147483647

const.clrBlack      = RGB(0, 0, 0)
const.clrWhite      = RGB(255, 255, 255)
const.clrRed        = RGB(255,   0, 0)
const.clrGreen      = RGB(0,   255, 0)
const.clrCyan       = RGB(0,   255, 255)
const.clrBlue       = RGB(0,     0, 255)
const.clrPaleBlue   = RGB(127, 159, 255)
const.clrPink       = RGB(255, 127, 127)
const.clrYellow     = RGB(255, 255, 0)
const.clrPaleYellow = RGB(255, 255, 127)
const.clrGray       = RGB(190, 190, 190)
const.clrStoneGray  = RGB(191, 191, 207)
const.clrSilverGray = RGB(192, 192, 192)
const.clrDarkGray   = RGB(169, 169, 169)
const.clrNoModifier = RGB(100, 100, 100)
const.clrOrange     = RGB(255, 165, 0)
const.clrMagenta    = RGB(255,   0, 255)

const.RolloverTime = 150
const.RolloverDestroyTime = const.RolloverTime

const.RolloverRefreshDistance = 75
const.RolloverWidth = 300
const.alignLeft = 1
const.alignRight = 2
const.alignTop = 3
const.alignBottom = 4

-- terrain type/biome brush
const.VerticalTextureZThreshold = "0.7"
const.BiomeSlopeAngleThreshold = 5 * 60

const.KbdAutoRepeatInterval = 400
const.RepeatButtonStart = 300
const.RepeatButtonInterval = 250

--Generic unit states; these represent logical behaviour states, and are only loosely connected to the animation states
--	Currently applied only for heroes.
const.gsIdle = 1
const.gsWalk = 2
const.gsRun = 3
const.gsAttack = 4
const.gsDeflect = 5
const.gsDeflectIdle = 6 
const.gsDie = 7

-- Console history max size
const.nConsoleHistoryMaxSize = 20

const.MaxDestsAroundObject = 16			-- the maximum destlocks around target object

const.TracksFadeOutDist = 3 * guim

-- Obstacle collision surface hit type
const.surfNoCollision = 0
const.surfImpassableVolume = 1
const.surfImpassableTerrain = 2
const.surfWalkableSurface = 3
const.surfPassableTerrain = 4

const.WalkableMaxRadius = 30 * guim

const.SequenceDefaultLoopDelay = 1573

const.CustomGameColors = 
{
	[const.clrBlack] = "black",
	[const.clrWhite] = "white",
	[const.clrRed] = "red",
	[const.clrCyan] = "cyan",
	[const.clrGreen] = "green",
	[const.clrBlue] = "blue",
	[const.clrPaleBlue] = "pale blue",
	[const.clrPink] = "pink",
	[const.clrYellow] = "yellow",
	[const.clrOrange] = "orange",
	[const.clrPaleYellow] = "pale yellow",
	[const.clrStoneGray] = "stone gray",
}
const.ColorList = {
	const.clrGreen,
	const.clrBlue,
	const.clrRed,
	const.clrWhite,
	const.clrCyan,
	const.clrYellow,
	const.clrPink,
	const.clrOrange,
	const.clrPaleBlue,
	const.clrPaleYellow,
	const.clrStoneGray,
	const.clrBlack,
}

if Platform.editor then
	const.ebtNull			 		= 20
	
	const.ErodeIterations = 3
	const.ErodeAmount = 50
	const.ErodePersist = 5
	const.ErodeThreshold = 50
	const.ErodeCoefDiag = 500
	const.ErodeCoefRect = 1000

	-- move gizmo constants
	const.RenderGizmoScreenDist	= "20.0"	-- use predefined metrics as if the gizmo is that many units from the camera

	const.AxisCylinderRadius = "0.10"
	const.AxisCylinderHeight = "4.0"
	const.AxisCylinderSlices = 10

	const.AxisConusRadius = "0.45"
	const.AxisConusHeight = "1.0"
	const.AxisConusSlices = 10

	const.PlaneLineRadius = "0.05"
	const.PlaneLineHeight = "2.5"
	const.PlaneLineSlices = 10

	const.XAxisColor = RGB(192, 0, 0)
	const.YAxisColor = RGB(0, 192, 0)
	const.ZAxisColor = RGB(0, 0, 192)
	const.XAxisColorSelected = RGB(255, 255, 0)
	const.YAxisColorSelected = RGB(255, 255, 0)
	const.ZAxisColorSelected = RGB(255, 255, 0)

	const.PlaneColor = RGBA(255, 255, 0, 200)

	-- scale gizmo constants
	const.MaxSingleScale = "3.0"		-- what is the max scale for a single operation

	const.PyramidSize = "1.5"
	const.PyramidSideRadius = "0.10"
	const.PyramidSideSlices = 10

	const.PyramidColor = RGB(0, 192, 192)
	const.SelectedSideColor = RGBA(255, 255, 0, 200)

	-- rotate gizmo constants
	const.MapDirections = 8

	const.AxisRadius = "0.05"
	const.AxisLength = "1.5"
	const.AxisSlices = 5

	const.TorusRadius1 = "2.30"
	const.TorusRadius2 = "0.15"
	const.TorusRings = 15
	const.TorusSlices = 10

	const.TangentRadius = "0.1"
	const.TangentLength = "2.5"
	const.TangentSlices = 5
	const.TangentColor = RGB(255, 0, 255)
	const.TangentConusHeight = "0.50"
	const.TangentConusRadius = "0.30"
	const.BigTorusColor = RGB(0, 192, 192)
	const.BigTorusColorSelected = RGB(255, 255, 0)
	const.SphereColor = RGBA(128, 128, 128, 100)

	const.SphereRings = 15
	const.SphereSlices = 15
	const.BigTorusRadius = "3.5"
	const.BigTorusRadius2 = "0.15"
	const.BigTorusRings = 15
	const.BigTorusSlices = 10

	-- snapping parameters
	const.SnapRadius = 20 -- in meters
	const.SnapBoxSize = "0.1"
	const.SnapDistXYTolerance = 10
	const.SnapDistZTolerance = 2
	const.SnapScaleTolerance = 200
	const.SnapAngleTolerance = 720
	-- let dDistXY, dDistZ, dAngle, dScale and dAxisAngle are the differences between params for two snap spots and
	-- differences above the specified tollerances ignores matching of the two snap spots
	-- let dNorm = SnapDistXYCoef + SnapDistZCoef + SnapAngleCoef + SnapScaleCoef
	-- fitness function for the two spots is 
	-- (dDist * SnapDistCoef + dAngle * SnapAngleCoef + dScale * SnapScaleCoef) / dNorm
	-- The snap spots with smallest fitness function are taken as matching snap spots
	const.SnapDistXYCoef = 1
	const.SnapDistZCoef = 3
	const.SnapAngleCoef = 3
	const.SnapScaleCoef = 2
	const.SnapDrawWarningFitnessTreshold = 4000 -- warning which only draws line segment between the closest snap spots

	const.MinBrushDensity = 30
	const.MaxBrushDensity = 97
end

-- Camera obstruct view params
const.ObstructOpacity = 0              -- transparency of objects that obstruct the view
const.ObstructOpacityFadeOutTime = 300  -- time to blend to transparent mode for objects obstructing the view
const.ObstructOpacityFadeInTime = 300  -- time to blend to normal mode for objects obstructing the view
const.ObstructViewRefreshTime = 50          -- time for refreshing the obstructing objects
const.ObstructOpacityRefreshTime = 20   -- time for refreshing the translucency of the fading objects
const.ObstructViewMaxObjectSize = 9000      -- enum distance

-- easing types

function GetEasingCombo(def_value, def_text)
	def_value = def_value or false
	def_text = def_text or ""
	local combo = {{ value = def_value, text = def_text }}
	for i, name in ipairs(GetEasingNames()) do
		combo[#combo + 1] = { value = i - 1, text = name }
	end
	return combo
end

-- the string values below are used in C, the reference below prevent the values to be constantly created and then garbage collected
const.__string_reference = { 
	-- Interpolation
	"type", "easing", "flags", "start", "duration", "originalRect", "targetRect", "startValue", "endValue", "center", "startAngle", "endAngle",
	-- Collections
	"child", "sub", 
	-- luaLib
	"n",
	-- luaQuery
	"hex", "rand", "detached", "map", "attached", "object_circles", "CObject", "collected", "collection", "shuffle",
	-- luaXInput
	"DPadLeft", "DPadRight", "DPadUp", "DPadDown", "ButtonA", "ButtonB", "ButtonX", "ButtonY", "LeftThumbClick", "RightThumbClick", "Start", "Back", "LeftShoulder", "RightShoulder", "LeftTrigger", "RightTrigger", "LeftThumb", "RightThumb", "TouchPadClick",
}

const.VoiceChatForcedSampleRate = 11025
const.VoiceChatSoundType = "VoiceChat"
const.VoiceChatMaxSilence = 10000
const.VoiceChatFadeTime = 300

-------- UI Scale constants
const.MinUserUIScale = 65
const.MaxUserUIScaleLowRes = 110
const.MaxUserUIScaleHighRes = 135
const.ControllerUIScale = const.ControllerUIScale or 111 -- additional scale applied when using gamepad/controller

-------- Display Area Margin constants
const.MinDisplayAreaMargin = 0
const.MaxDisplayAreaMargin = 10

const.UIScaleDAMDependant = false

--[[
-- The following code measures the resolving of constants between two sequential calls to dump_const_use().
-- Sample use - CreateGameTimeThread(function () dump_const_use() Sleep(10000) dump_const_use() end)

local org_const = const
const = {}
const_access_count = 0
const_access = {}
setmetatable(const, {
	__index = function (t, k)
		const_access_count = const_access_count + 1
		const_access[k] = (const_access[k] or 0) + 1
		return org_const[k]
	end,
	__newindex = function (t, k, v)
		org_const[k] = v
	end,
})
function dump_const_use()
	print("")
	print("total const access count " .. const_access_count)
	local t = {}
	for k,v in pairs(const_access) do
		table.insert(t, {key = k, value = v})
	end
	table.sort(t, function (a, b) return a.value > b.value end)
	for i = 1, #t do
		print(t[i].key .. " " .. t[i].value)
	end
	const_access = {}
	const_access_count = 0
end
--]]

-- Destroyable
const.EntityVolumeSmall = guim * guim * guim
const.EntityVolumeMedium = 3 * const.EntityVolumeSmall

-- Wind
const.WindMaxStrength = 4096
const.WindMarkerMaxRange = 50 * guim
const.WindMarkerAttenuationRange = 80 * guim
const.StrongWindThreshold = 100 -- percent of max wind
const.WindModifierMaskComboItems = {
	{ text = "None", value = 0 },
	{ text = "All", value = -1 },
}

-- Water
const.FXWaterMinOffsetZ = - guim / 10
const.FXWaterMaxOffsetZ = guim / 10
const.FXDecalMinOffsetZ = - guim / 10
const.FXDecalMaxOffsetZ = guim / 10
const.FXShallowWaterOffsetZ = 0

--------------------------------------------------------------------------------------------------------------------
