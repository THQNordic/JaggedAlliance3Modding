local FlightTile = const.FlightTile
if not FlightTile then
	return -- flight logic not supported
end

FlightDbgResults = empty_func
FlightDbgMark = empty_func
FlightDbgBreak = empty_func

local efResting = const.efResting

local pfFinished = const.pfFinished
local pfFailed = const.pfFailed
local pfTunnel = const.pfTunnel
local pfDestLocked = const.pfDestLocked
local pfSmartDestlockDist = const.pfSmartDestlockDist

local tfrPassClass = const.tfrPassClass
local tfrLimitDist = const.tfrLimitDist
local tfrCanDestlock = const.tfrCanDestlock
local tfrLuaFilter = const.tfrLuaFilter

local Min, Max, Clamp, AngleDiff = Min, Max, Clamp, AngleDiff
local IsValid, IsValidPos = IsValid, IsValidPos
local ResolveZ = ResolveZ

local InvalidZ = const.InvalidZ
local anim_min_time = 100
local time_ahead = 10
local tplCheck = const.tplCheck
local step_search_dist = 2*FlightTile
local dest_search_dist = 4*FlightTile
local max_search_dist = 10*FlightTile
local max_takeoff_dist = 64*guim

local flight_default_flags = const.ffpSplines | const.ffpPhysics | const.ffpSmooth
local ffpAdjustTarget = const.ffpAdjustTarget

local flight_flags_values = {
	Splines = const.ffpSplines,
	Physics = const.ffpPhysics,
	Smooth = const.ffpSmooth,
	AdjustTarget = const.ffpAdjustTarget,
	Debug = const.ffpDebug,
}
local flight_flags_names = table.keys(flight_flags_values, true)
local function FlightFlagsToSet(flags)
	local fset = {}
	for name, flag in pairs(flight_flags_values) do
		if (flags & flag) ~= 0 then
			fset[name] = true
		end
	end
	return fset
end
local function FlightSetToFlags(fset)
	local flags = 0
	for name in pairs(fset) do
		flags = flags | flight_flags_values[name]
	end
	return flags
end
local path_errors = {
	invalid = const.fpsInvalid,
	max_iters = const.fpsMaxIters,
	max_steps = const.fpsMaxSteps,
	max_loops = const.fpsMaxLoops,
	max_stops = const.fpsMaxStops,
}
function FlightGetErrors(status)
	status = status or 0
	local errors
	for name, value in pairs(path_errors) do
		if status & value ~= 0 then
			errors = table.create_add(errors, name)
		end
	end
	if errors then
		table.sort(errors)
		return errors
	end
end

function FlightInitVars()
	FlightMap = false
	FlightEnergy = false
	FlightFrom = false
	FlightTo = false
	FlightFlags = 0
	FlightDestRange = 0
	FlightMarkFrom = false
	FlightMarkTo = false
	FlightMarkBorder = 0
	FlightMarkMinHeight = 0
	FlightMarkObjRadius = 0
	FlightMarkIdx = 0
	FlightArea = false
	FlightEnergyMin = false
	FlightSlopePenalty = 0
	FlightSmoothDist = 0
	FlightGrowObstacles = false
	FlightTimestamp = 0
	FlightPassVersion = false
end

if FirstLoad then
	FlightInitVars()
end

function OnMsg.DoneMap()
	if FlightMap then
		FlightMap:free()
	end
	if FlightEnergy then
		FlightEnergy:free()
	end
	FlightInitVars()
end

local StayAboveMapItems = {
	{ value = const.FlightRestrictNone,          text = "None",             help = "The object is allowed to fall under the flight map" },
	{ value = const.FlightRestrictAboveTerrain,  text = "Above Terrain",    help = "The object is allowed to fall under the flight map, but not under the terrain" },
	{ value = const.FlightRestrictAboveWalkable, text = "Above Walkable",   help = "The object is allowed to fall under the flight map, but not under a walkable surface (inlcuding the terrain)" },
	{ value = const.FlightRestrictAboveMap,      text = "Above Flight Map", help = "The object is not allowed to fall under the flight map" },
}

----

MapVar("FlyingObjs", function() return sync_set() end)

DefineClass.FlyingObj = {
	__parents = { "Object" },
	flags = { cofComponentInterpolation = true, cofComponentCurvature = true },
	properties = {
		{ category = "Flight", id = "FlightMinPitch",        name = "Pitch Min",                editor = "number", default = -2700,    scale = "deg", template = true },
		{ category = "Flight", id = "FlightMaxPitch",        name = "Pitch Max",                editor = "number", default = 2700,    scale = "deg", template = true },
		{ category = "Flight", id = "FlightPitchSmooth",     name = "Pitch Smooth",             editor = "number", default = 100,     min = 0, max = 500, scale = 100, slider = true, template = true, help = "Smooth the pitch angular speed changes" },
		{ category = "Flight", id = "FlightMaxPitchSpeed",   name = "Pitch Speed Limit (deg/s)",editor = "number", default = 90*60,   scale = 60, template = true, help = "Smooth the pitch angular speed changes" },
		{ category = "Flight", id = "FlightSpeedToPitch",    name = "Speed to Pitch",           editor = "number", default = 100,     min = 0, max = 100, scale = "%", slider = true, template = true, help = "How much the flight speed affects the pitch angle" },
		{ category = "Flight", id = "FlightMaxRoll",         name = "Roll Max",                 editor = "number", default = 2700,    min = 0, max = 180*60, scale = "deg", slider = true, template = true },
		{ category = "Flight", id = "FlightMaxRollSpeed",    name = "Roll Speed Limit (deg/s)", editor = "number", default = 90*60,   scale = 60, template = true, help = "Smooth the row angular speed changes" },
		{ category = "Flight", id = "FlightRollSmooth",      name = "Roll Smooth",              editor = "number", default = 100,     min = 0, max = 500, scale = 100, slider = true, template = true, help = "Smooth the row angular speed changes" },
		{ category = "Flight", id = "FlightSpeedToRoll",     name = "Speed to Roll",            editor = "number", default = 0,       min = 0, max = 100, scale = "%", slider = true, template = true, help = "How much the flight speed affects the roll angle" },
		{ category = "Flight", id = "FlightYawSmooth",       name = "Yaw Smooth",               editor = "number", default = 100,     min = 0, max = 500, scale = 100, slider = true, template = true, help = "Smooth the yaw angular speed changes" },
		{ category = "Flight", id = "FlightMaxYawSpeed",     name = "Yaw Speed Limit (deg/s)",  editor = "number", default = 360*60,  scale = 60, template = true, help = "Smooth the yaw angular speed changes" },
		{ category = "Flight", id = "FlightYawRotToRoll",    name = "Yaw Rot to Roll",          editor = "number", default = 100,     min = 0, max = 300, scale = "%", slider = true, template = true, help = "Links the row angle to the yaw rotation speed" },
		{ category = "Flight", id = "FlightYawRotFriction",  name = "Yaw Rot Friction",         editor = "number", default = 100,     min = 0, max = 1000, scale = "%", slider = true, template = true, help = "Friction caused by 90 deg/s yaw rotation speed" },
		{ category = "Flight", id = "FlightSpeedStop",       name = "Speed Stop (m/s)",         editor = "number", default = false,       scale = guim, template = true, help = "Will use the min speed if not specified. Stopping is possible only if the deceleration distance is not zero" },
		{ category = "Flight", id = "FlightSpeedMin",        name = "Speed Min (m/s)",          editor = "number", default = 6 * guim,    scale = guim, template = true },
		{ category = "Flight", id = "FlightSpeedMax",        name = "Speed Max (m/s)",          editor = "number", default = 15 * guim,   scale = guim, template = true },
		{ category = "Flight", id = "FlightFriction",        name = "Friction",                 editor = "number", default = 30, min = 0, max = 300, slider = true, scale = "%", template = true, help = "Friction coefitient, affects the max achievable speed. Should be adjusted so that both the max speed and the achievable one are matching." },
		{ category = "Flight", id = "FlightAccelMax",        name = "Accel Max (m/s^2)",        editor = "number", default = 10*guim, scale = guim, template = true },
		{ category = "Flight", id = "FlightDecelMax",        name = "Decel Max (m/s^2)",        editor = "number", default = 20*guim, scale = guim, template = true },
		{ category = "Flight", id = "FlightAccelDist",       name = "Accel Dist",               editor = "number", default = 20*guim, scale = "m", template = true },
		{ category = "Flight", id = "FlightDecelDist",       name = "Decel Dist",               editor = "number", default = 20*guim, scale = "m", template = true },
		{ category = "Flight", id = "FlightStopDist",        name = "Force Stop Dist",          editor = "number", default = 1*guim, scale = "m", template = true, help = "Critical distance where to dorce a stop animation even if the conditions for such are not met" },
		{ category = "Flight", id = "FlightStopMinTime",     name = "Min Stop Time",            editor = "number", default = 50, min = 0, template = true, help = "Try to play stop anim only if enough time is available" },
		{ category = "Flight", id = "FlightPathStepMax",     name = "Path Step Max",            editor = "number", default = 2*guim,  scale = "m", template = true, help = "Step dist at max speed" },
		{ category = "Flight", id = "FlightPathStepMin",     name = "Path Step Min",            editor = "number", default = guim,  scale = "m", template = true, help = "Step dist at min speed" },
		{ category = "Flight", id = "FlightAnimStart",       name = "Anim Fly Start",           editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnim",            name = "Anim Fly",                 editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnimDecel",       name = "Anim Fly Decel",           editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnimStop",        name = "Anim Fly Stop",            editor = "text",   default = false, template = true },
		
		{ category = "Flight", id = "FlightAnimIdle",        name = "Anim Fly Idle",            editor = "text",   default = false, template = true },
		{ category = "Flight", id = "FlightAnimSpeedMin",    name = "Anim Speed Min",           editor = "number", default = 1000, min = 0, max = 1000, scale = 1000, slider = true, template = true },
		{ category = "Flight", id = "FlightAnimSpeedMax",    name = "Anim Speed Max",           editor = "number", default = 1000, min = 1000, max = 3000, scale = 1000, slider = true, template = true },
		{ category = "Flight", id = "FlightAnimStopFOV",     name = "Anim Fly Stop FoV",        editor = "number", default = 90*60, min = 0, max = 360*60, scale = "deg", slider = true, template = true, help = "Required FoV towards the target in order to switch to anim_stop/landing anim" },
		
		{ category = "Flight Path", id = "FlightSimHeightMin",      name = "Min Height",           editor = "number", default = 3*guim, min = guim, max = 50*guim, slider = true, scale = "m", template = true, sim = true, help = "Min flight height. If below, the flying obj will try to go up (lift)." },
		{ category = "Flight Path", id = "FlightSimHeightMax",      name = "Max Height",           editor = "number", default = 5*guim, min = guim, max = 50*guim, slider = true, scale = "m", template = true, sim = true, help = "Max flight height. If above, the flying obj will try to go down (weight)." },
		{ category = "Flight Path", id = "FlightSimHeightRestrict", name = "Height Restriction",   editor = "choice", default = const.FlightRestrictNone, template = true, sim = true, items = StayAboveMapItems, help = "Avoid entering the height map. As the height map is not precise, this could lead to strange visual behavior." },
		{ category = "Flight Path", id = "FlightSimSpeedLimit",     name = "Speed Limit (m/s)",    editor = "number", default = 10*guim, min = 1, max = 50*guim, slider = true, scale = guim, template = true, sim = true, help = "Max speed during simulation. Should be limited to ensure precision." },
		{ category = "Flight Path", id = "FlightSimInertia",        name = "Inertia",              editor = "number", default = 100, min = 10, max = 1000, slider = true, exponent = 2, scale = 100, template = true, sim = true, help = "How inert is the object." },
		{ category = "Flight Path", id = "FlightSimFrictionXY",     name = "Friction XY",          editor = "number", default = 20, min = 1, max = 300, slider = true, scale = "%", template = true, sim = true, help = "Horizontal friction min coefitient." },
		{ category = "Flight Path", id = "FlightSimFrictionZ",      name = "Friction Z",           editor = "number", default = 50, min = 1, max = 300, slider = true, scale = "%", template = true, sim = true, help = "Vertical friction coefitient." },
		{ category = "Flight Path", id = "FlightSimFrictionStop",   name = "Friction Stop",        editor = "number", default = 80, min = 1, max = 300, slider = true, scale = "%", template = true, sim = true, help = "Horizontal friction max coefitient." },
		{ category = "Flight Path", id = "FlightSimAttract",        name = "Attract",              editor = "number", default = guim, min = 0, max = 30*guim, slider = true, scale = 1000, template = true, sim = true, help = "Attraction force per energy unit difference. The force pushing the unit towards its final destination." },
		{ category = "Flight Path", id = "FlightSimLift",           name = "Lift",                 editor = "number", default = guim/3, min = 0, max = 30*guim, slider = true, scale = 1000, template = true, sim = true, help = "Lift force per meter. The force trying to bring back UP the unit at its best height level." },
		{ category = "Flight Path", id = "FlightSimMaxLift",        name = "Max Lift",             editor = "number", default = 10*guim, min = 0, max = 30*guim, slider = true, scale = 1000, template = true, sim = true, help = "Max lift force." },
		{ category = "Flight Path", id = "FlightSimWeight",         name = "Weight",               editor = "number", default = guim/3, min = 0, max = 20*guim, slider = true, scale = 1000, template = true, sim = true, help = "Weight force per meter. The force trying to bring back DOWN the unit at its best height level." },
		{ category = "Flight Path", id = "FlightSimMaxWeight",      name = "Max Weight",           editor = "number", default = 3*guim, min = 0, max = 20*guim, slider = true, scale = 1000, template = true, sim = true, help = "Max weight force." },
		{ category = "Flight Path", id = "FlightSimMaxThrust",      name = "Max Thrust",           editor = "number", default = 10*guim, min = 0, max = 50*guim, slider = true, scale = 1000, template = true, sim = true, help = "Max cummulative thrust." },
		{ category = "Flight Path", id = "FlightSimInterval",       name = "Update Interval (ms)", editor = "number", default = 50, min = 1, max = 1000, slider = true, template = true, sim = true, help = "Simulation update interval. Lower values ensure better precision, but makes the sim more expensive" },
		{ category = "Flight Path", id = "FlightSimMinStep",        name = "Min Path Step",        editor = "number", default = FlightTile, min = 0, max = 100*guim, scale = "m", slider = true, template = true, sim = true, help = "Min path step (approx)." },
		{ category = "Flight Path", id = "FlightSimMaxStep",        name = "Max Path Step",        editor = "number", default = 8*FlightTile, min = 0, max = 100*guim, scale = "m", slider = true, template = true, sim = true, help = "Max path step (approx)." },
		{ category = "Flight Path", id = "FlightSimDecelDist",      name = "Decel Dist",           editor = "number", default = 10*guim, min = 1, max = 300*guim, slider = true, scale = "m", template = true, sim = true, help = "At that distance to the target, the movement will try to go towards the target ignoring most considerations." },
		{ category = "Flight Path", id = "FlightSimLookAhead",      name = "Look Ahead",           editor = "number", default = 4000, min = 0, max = 10000, scale = "sec", slider = true, template = true, sim = true, help = "Give some time to adjust the flight height before reaching a too high obstacle." },
		{ category = "Flight Path", id = "FlightSimSplineAlpha",    name = "Spline Alpha",         editor = "number", default = 1365, min = 0, max = 4096, scale = 4096, slider = true, template = true, sim = true, help = "Defines the spline smoothness." },
		{ category = "Flight Path", id = "FlightSimSplineErr",      name = "Spline Tolerance",     editor = "number", default = FlightTile/4, min = 0, max = FlightTile, scale = "m", slider = true, template = true, sim = true, help = "Max spline deviation form the precise trajectory. Lower values imply more path steps as the longer splines deviate stronger." },
		{ category = "Flight Path", id = "FlightSimMaxIters",       name = "Max Compute Iters",    editor = "number", default = 16 * 1024, template = true, sim = true, help = "Max number of compute iterations. Used for a sanity check against infinite loops." },
		
		{ category = "Flight Path", id = "FlightSlopePenalty",      name = "Slope Penalty",        editor = "number", default = 300, scale = "%", template = true, sim = true, min = 10, max = 1000, slider = true, exponent = 2, help = "How difficult it is to flight over against going around obstacles." },
		{ category = "Flight Path", id = "FlightSmoothDist",        name = "Smooth Obstacles Dist",editor = "number", default = 0, template = true, sim = true, help = "Better obstacle avoidance withing that distance at the expense of more processing." },
		{ category = "Flight Path", id = "FlightMinObstacleHeight", name = "Min Obstacle Height",  editor = "number", default = 0, scale = "m", template = true, sim = true, step = const.FlightScale, help = "Ignored obstacle height." },
		{ category = "Flight Path", id = "FlightObjRadius",         name = "Object Radius",        editor = "number", default = 0, scale = "m", template = true, sim = true, help = "To consider when avoiding obstacles." },
		
		{ category = "Flight Path", id = "FlightFlags",             name = "Flight Flags",         editor = "set",    default = function(self) return FlightFlagsToSet(flight_default_flags) end, items = flight_flags_names },
		{ category = "Flight Path", id = "FlightPathErrors",        name = "Path Errors",          editor = "set",    default = set(), items = table.keys(path_errors, true), read_only = true, dont_save = true },
		{ category = "Flight Path", id = "FlightPathSplines",       name = "Path Splines",         editor = "number", default = 0, read_only = true, dont_save = true },
		{ category = "Flight Path", id = "flight_path_iters",       name = "Path Iters",           editor = "number", default = 0, read_only = true, dont_save = true },

	},
	flight_target = false,
	flight_target_range = 0,
	flight_path = false,
	flight_path_status = 0,
	flight_path_flags = false,
	flight_path_collision = false,
	flight_spline_idx = 0,
	flight_spline_dist = 0,
	flight_spline_len = 0,
	flight_spline_time = 0,
	flight_stop_on_passable = false, -- in order to achieve landing
	flight_flags = flight_default_flags,
	
	ResolveFlightTarget = pf.ResolveGotoTargetXYZ,
	CanFlyTo = return_true,
}

function FlyingObj:Init()
	FlyingObjs:insert(self)
end

function FlyingObj:Done()
	FlyingObjs:remove(self)
	self:UnlockFlightDest()
end

function FlyingObj:GetFlightPathErrors()
	return table.invert(FlightGetErrors(self.flight_path_status))
end

function FlyingObj:GetFlightPathSplines()
	return #(self.flight_path or "")
end

function FlyingObj:SetFlightFlag(flag, enable)
	enable = enable or false
	local flight_flags = self.flight_flags
	local enabled = (flight_flags & flag) ~= 0
	if enable == enabled then
		return
	end
	if enable then
		self.flight_flags = flight_flags | flag
	else
		self.flight_flags = flight_flags & ~flag
	end
	return true
end

function FlyingObj:GetFlightFlag(flag)
	return (self.flight_flags & flag) ~= 0
end

function FlyingObj:SetFlightFlags(fset)
	self.flight_flags = FlightSetToFlags(fset)
end

function FlyingObj:GetFlightFlags()
	return FlightFlagsToSet(self.flight_flags)
end

function FlyingObj:SetAdjustFlightTarget(enable)
	return self:SetFlightFlag(ffpAdjustTarget, enable)
end

function FlyingObj:GetAdjustFlightTarget()
	return self:GetFlightFlag(ffpAdjustTarget)
end

function FlyingObj:FlightStop()
	if self:TimeToPosInterpolationEnd() == 0 then
		return
	end
	local a = -self.FlightDecelMax
	local x, y, z, dt0 = self:GetFinalPosAndTime(0, a)
	if not x then
		return
	end
	self:SetPos(x, y, z, dt0)
	self:SetAcceleration(a)
	return dt0
end

function FlyingObj:FindFlightPath(target, range, flight_flags, debug_iter)
	if not IsValidPos(target) then
		return
	end
	flight_flags = flight_flags or self.flight_flags
	local path, error_status, collision_pos, iters = FlightCalcPathBetween(
		self, target, flight_flags,
		self.FlightMinObstacleHeight, self.FlightObjRadius, self.FlightSlopePenalty, self.FlightSmoothDist,
		range, debug_iter)
	self.flight_path = path
	self.flight_path_status = error_status
	self.flight_path_iters = iters
	self.flight_path_flags = flight_flags
	self.flight_path_collision = collision_pos
	self.flight_target = target
	self.flight_target_range = range or nil
	self.flight_spline_idx = nil
	self.flight_spline_dist = nil
	self.flight_spline_len = nil
	self.flight_spline_time = nil
	dbg(FlightDbgResults(self))
	return path, error_status, collision_pos
end

function FlyingObj:RecalcFlightPath()
	return self:FindFlightPath(self.flight_target, self.flight_target_range, self.flight_path_flags)
end

function FlyingObj:MarkFlightArea(target)
	return FlightMarkBetween(self, target or self, self.FlightMinObstacleHeight, self.FlightObjRadius)
end

function FlyingObj:MarkFlightAround(target, border)
	target = target or self
	return FlightMarkBetween(target, target, self.FlightMinObstacleHeight, self.FlightObjRadius, border)
end

function FlyingObj:LockFlightDest(x, y, z)
	return x, y, z
end
FlyingObj.UnlockFlightDest = empty_func

function FlyingObj:GetPathHash(seed)
	local flight_path = self.flight_path
	if not flight_path or #flight_path == 0 then return end
	local start_idx = self.flight_spline_idx
	local spline = flight_path[start_idx]
	local hash = xxhash(seed, spline[1], spline[2], spline[3], spline[4])
	for i=start_idx + 1,#flight_path do
		spline = flight_path[i]
		hash = xxhash(hash, spline[2], spline[3], spline[4])
	end
	return hash
end

function FlyingObj:Step(pt, ...)
	-- TODO: implement in C
	local fx, fy, fz, range = self:ResolveFlightTarget(pt, ...)
	local tx, ty, tz = self:LockFlightDest(fx, fy, fz)
	if not tx then
		return pfFailed 
	end
	local visual_z = ResolveZ(tx, ty, tz)
	if self:IsCloser(tx, ty, visual_z, range + 1) then
		if range == 0 then
			self:SetPos(tx, ty, tz)
			self:SetAcceleration(0)
		end
		fz = fz or InvalidZ
		tz = tz or InvalidZ
		if fx ~= tx or fy ~= ty or fz ~= tz then
			return pfDestLocked 
		end
		return pfFinished
	end
	local v0 = self:GetVelocity()
	local path = self.flight_path
	local flight_target = self.flight_target
	local prev_range = self.flight_target_range
	local prev_flags = self.flight_path_flags
	local find_path = not path or not flight_target or prev_flags ~= self.flight_flags
	local time_now = GameTime()
	local spline_idx, spline_dist, spline_len
	local same_target = prev_range == range and flight_target and flight_target:Equal(tx, ty, tz)
	if not find_path and not same_target then
		-- recompute path only if the new target is far enough from the old target
		local error_dist = flight_target:Dist(tx, ty, tz)
		local retarget_offset_pct = 30
		local threshold_dist = error_dist * 100 / retarget_offset_pct
		if v0 > 0 then
			local min_retarget_time = 3000
			threshold_dist = Min(threshold_dist, v0 * min_retarget_time / 1000)
		end
		local x, y, z = ResolveVisualPosXYZ(flight_target)
		find_path = self:IsCloser(x, y, z, 1 + threshold_dist)
	end
	local step_finished
	if find_path then
		flight_target = point(tx, ty, tz)
		path = self:FindFlightPath(flight_target, range)
		if not path or #path == 0 then
			return pfFailed
		end
		assert(flight_target == self.flight_target)
		spline_idx = 0
		spline_dist = 0
		spline_len = 0
		step_finished = true
		same_target = true
	else
		spline_idx = self.flight_spline_idx
		spline_dist = self.flight_spline_dist
		spline_len = self.flight_spline_len
		step_finished = time_now - self.flight_spline_time >= 0
	end
	local spline
	local last_step
	local BS3_GetSplineLength3D = BS3_GetSplineLength3D
	if spline_dist < spline_len or not step_finished then
		spline = path[spline_idx]
	else
		while spline_dist >= spline_len do
			spline_idx = spline_idx + 1
			spline = path[spline_idx]
			if not spline then
				return pfFailed
			end
			spline_dist = 0
			spline_len = BS3_GetSplineLength3D(spline)
		end
		self.flight_spline_idx = spline_idx
		self.flight_spline_len = spline_len
	end
	assert(spline)
	if not spline then
		return pfFailed
	end
	local last_spline = path[#path]
	local flight_dest = last_spline[4]
	tx, ty, tz = flight_dest:xyz()
	local speed_min, speed_max, speed_stop = self.FlightSpeedMin, self.FlightSpeedMax, self.FlightSpeedStop
	if step_finished then
		local min_step, max_step = self.FlightPathStepMin, self.FlightPathStepMax
		assert(speed_min == speed_max and min_step == max_step or speed_min < speed_max and min_step < max_step)
		local spline_step
		if v0 <= speed_min then
			spline_step = min_step
		elseif v0 >= speed_max then
			spline_step = max_step
		else
			spline_step = min_step + (max_step - min_step) * (v0 - speed_min) / (speed_max - speed_min)
		end
		spline_step = Min(spline_step, spline_len)
		spline_dist = spline_dist + spline_step
		if spline_dist + spline_step / 2 > spline_len then
			spline_dist = spline_len
			last_step = spline_idx == #path
		end
		self.flight_spline_dist = spline_dist
	end
	
	speed_stop = speed_stop or speed_min
	local max_roll, roll_max_speed = self.FlightMaxRoll, self.FlightMaxRollSpeed
	local pitch_min, pitch_max = self.FlightMinPitch, self.FlightMaxPitch
	local yaw_max_speed, pitch_max_speed = self.FlightMaxYawSpeed, self.FlightMaxPitchSpeed
	local decel_dist = self.FlightDecelDist
	local remaining_len = spline_len - spline_dist
	local anim_stop
	local fly_anim = self.FlightAnim
	local x0, y0, z0 = self:GetVisualPosXYZ()
	local speed_lim = speed_max
	local x, y, z, dirx, diry, dirz, curvex, curvey, curvez
	local roll, pitch, yaw, accel, v, dt
	local max_dt = max_int
	if decel_dist > 0 and self:IsCloser(flight_dest, decel_dist) and (not self.flight_stop_on_passable or terrain.FindPassableZ(flight_dest, self, 0, 0)) then
		local total_remaining_len = remaining_len
		local deceleration = true
		for i = spline_idx + 1, #path do
			if total_remaining_len >= decel_dist then
				deceleration = false
				break
			end
			total_remaining_len = total_remaining_len + BS3_GetSplineLength3D(path[i])
		end
		if deceleration then
			speed_lim = speed_stop + (speed_max - speed_stop) * total_remaining_len / decel_dist
		end
		fly_anim = self.FlightAnimDecel or fly_anim
		
		local use_velocity_fov = true
		local tz1 = tz + 50 -- make LOS work for positions on a floor
		local critical_stop = deceleration and total_remaining_len < self.FlightStopDist
		local fly_anim_stop = self.FlightAnimStop
		if fly_anim and fly_anim_stop and deceleration
		and (critical_stop or self:HasFov(tx, ty, tz1, self.FlightAnimStopFOV, 0, use_velocity_fov) and TestPointsLOS(tx, ty, tz1, self, tplCheck)) then
			dt = GetAnimDuration(self:GetEntity(), fly_anim_stop) -- as the anim speed may varry
			dbg(ReportZeroAnimDuration(self, fly_anim_stop, dt))
			if dt == 0 then
				dt = 1000
			end
			x, y, z, dirx, diry, dirz = BS3_GetSplinePosDir(last_spline, 4096)
			accel, v = self:GetAccelerationAndFinalSpeed(x, y, z, dt)
			local speed_stop = Max(v0, speed_min)
			if v <= speed_stop then
				anim_stop = true
				local anim_speed = 1000
				if v < 0 then
					local stop_time
					accel, stop_time = self:GetAccelerationAndTime(x, y, z, speed_stop)
					if stop_time > self.FlightStopMinTime then
						anim_speed = 1000 * dt / stop_time
					else
						anim_stop = false
					end
				end
				if anim_stop then
					if dirx == 0 and diry == 0 then
						dirx, diry = x - x0, y - y0
					end
					yaw = atan(diry, dirx)
					roll, pitch = 0, 0
					self:SetState(fly_anim_stop)
					self:SetAnimSpeed(1, anim_speed)
					self.flight_spline_dist = spline_len
					last_step = true
				end
			end
		end
	end
	if not anim_stop then
		local roll0, pitch0, yaw0 = self:GetRollPitchYaw()
		x, y, z, dirx, diry, dirz, curvex, curvey, curvez = BS3_GetSplinePosDirCurve(spline, spline_dist, spline_len)
		if dirx == 0 and diry == 0 and dirz == 0 then
			dirx, diry, dirz = x - x0, y - y0, z - z0
		end
		
		pitch, yaw = GetPitchYaw(dirx, diry, dirz)
		pitch, yaw = pitch or pitch0, yaw or yaw0

		local step_len = self:GetVisualDist(x, y, z)
		local friction = self.FlightFriction
		local dyaw = AngleDiff(yaw, yaw0) * 100 / (100 + self.FlightYawSmooth)
		dt = v0 > 0 and MulDivRound(1000, step_len, v0) or 0 -- step time estimate
		local yaw_rot_est = dt == 0 and 0 or Clamp(1000 * dyaw / dt, -yaw_max_speed, yaw_max_speed)
		if yaw_rot_est ~= 0 then
			friction = friction + MulDivRound(self.FlightYawRotFriction, abs(yaw_rot_est), 90 * 60)
		end
		local speed_to_roll, speed_to_pitch = self.FlightSpeedToRoll, self.FlightSpeedToPitch
		local accel_max = self.FlightAccelMax
		local accel0 = accel_max - v0 * friction / 100
		v, dt = self:GetFinalSpeedAndTime(x, y, z, accel0, v0)
		v = v or speed_min
		v = Min(v, speed_lim)
		v = Max(v, Min(speed_min, v0))
		local at_max_speed = v == speed_max
		accel, dt = self:GetAccelerationAndTime(x, y, z, v)
		if not at_max_speed and speed_to_pitch > 0 then
			local mod_pitch = pitch * v / speed_max
			if speed_to_pitch == 100 then
				pitch = mod_pitch
			else
				pitch = pitch + (mod_pitch - pitch) * speed_to_pitch / 100
			end
		end
		pitch = Clamp(pitch, pitch_min, pitch_max)
		local dpitch = AngleDiff(pitch, pitch0) * 100 / (100 + self.FlightPitchSmooth)
		local pitch_rot = dt > 0 and Clamp(1000 * dpitch / dt, -pitch_max_speed, pitch_max_speed) or 0
		local yaw_rot = dt > 0 and Clamp(1000 * dyaw / dt, -yaw_max_speed, yaw_max_speed) or 0
		roll = -yaw_rot * self.FlightYawRotToRoll / 100
		if not at_max_speed and speed_to_roll > 0 then
			local mod_roll = roll * v / speed_max
			if speed_to_roll == 100 then
				roll = mod_roll
			else
				roll = roll + (mod_roll - roll) * speed_to_roll / 100
			end
		end
		roll = Clamp(roll, -max_roll, max_roll)
		local droll = AngleDiff(roll, roll0) * 100 / (100 + self.FlightRollSmooth)
		local roll_rot = dt > 0 and Clamp(1000 * droll / dt, -roll_max_speed, roll_max_speed) or 0
		if dt > 0 then
			-- limit the rotation speed
			droll = roll_rot * dt / 1000
			dyaw = yaw_rot * dt / 1000
			dpitch = pitch_rot * dt / 1000
		end
		roll = roll0 + droll
		yaw = yaw0 + dyaw
		pitch = pitch0 + dpitch
		if fly_anim then
			local anim = GetStateName(self)
			if anim ~= fly_anim then
				local fly_anim_start = self.FlightAnimStart
				if anim ~= fly_anim_start then
					self:SetState(fly_anim_start)
				else
					local remaining_time = self:TimeToAnimEnd()
					if remaining_time > anim_min_time then
						max_dt = remaining_time
					else
						self:SetState(fly_anim)
					end
				end
			else
				local min_anim_speed, max_anim_speed = self.FlightAnimSpeedMin, self.FlightAnimSpeedMax
				if dt > 0 and min_anim_speed < max_anim_speed then
					local curve = Max(GetLen(curvex, curvey, curvez), 1)
					local coef = 1024 + 1024 * curvez / curve + 1024 * abs(accel0) / accel_max
					local anim_speed = min_anim_speed + (max_anim_speed - min_anim_speed) * Clamp(coef, 0, 2048) / 2048
					self:SetAnimSpeed(1, anim_speed)
				end
			end
		end
	end

	self:SetRollPitchYaw(roll, pitch, yaw, dt)
	self:SetPos(x, y, z, dt)
	self:SetAcceleration(accel)
	
	--if self == SelectedObj then DbgSetText(self, print_format("v", v, "t", abs(rotation_speed)/60, "r", roll/60, "dt", dt)) else DbgSetText(self) end
	if not last_step and not anim_stop and dt > time_ahead then
		dt = dt - time_ahead -- fix the possibility of rendering the object immobile at the end of the interpolation
	end
	self.flight_spline_time = time_now + dt
	local sleep = Min(dt, max_dt)
	return sleep
end

function FlyingObj:ClearFlightPath()
	self.flight_path = nil
	self.flight_path_status = nil
	self.flight_path_iters = nil
	self.flight_path_flags = nil
	self.flight_path_collision = nil
	self.flight_target = nil
	self.flight_spline_idx = nil
	self.flight_flags = nil
	self.flight_stop_on_passable = nil
	self:UnlockFlightDest()
end

FlyingObj.ClearPath = FlyingObj.ClearFlightPath

function FlyingObj:ResetOrientation(time)
	local _, _, yaw = self:GetRollPitchYaw()
	self:SetRollPitchYaw(0, 0, yaw, time)
end

function FlyingObj:Face(target, time)
	local pitch, yaw = GetPitchYaw(self, target)
	self:SetRollPitchYaw(0, pitch, yaw, time)
end

function FlyingObj:GetFlightDest()
	local path = self.flight_path
	local last_spline = path and path[#path]
	return last_spline and last_spline[4]
end

function FlyingObj:GetFinalFlightDirXYZ()
	local path = self.flight_path
	local last_spline = path and path[#path]
	if not last_spline then
		return self:GetVelocityVectorXYZ()
	end
	return BS3_GetSplineDir(last_spline, 4096, 4096)
end

function FlyingObj:IsFlightAreaMarked(flight_target, mark_border)
	flight_target = flight_target or self.flight_target
	if not flight_target
	or GameTime() ~= FlightTimestamp
	or not FlightArea or not FlightMap
	or FlightPassVersion ~= PassVersion
	or FlightMarkMinHeight ~= self.FlightMinObstacleHeight
	or FlightMarkObjRadius ~= self.FlightObjRadius then
		return
	end
	return FlightIsMarked(FlightArea, FlightMarkFrom, FlightMarkTo, FlightMarkBorder, self, flight_target, mark_border)
end

function FlightGetHeightAt(...)
	return FlightGetHeight(FlightMap, FlightArea, ...)
end

----

DefineClass("FlyingMovableAutoResolve")

DefineClass.FlyingMovable = {
	__parents = { "FlyingObj", "Movable", "FlyingMovableAutoResolve" },
	properties = {
		{ category = "Flight", id = "FlightPlanning",        name = "Flight Planning",          editor = "bool",   default = false, template = true, help = "Complex flight planning" },
		{ category = "Flight", id = "FlightMaxFailures",     name = "Flight Plan Max Failures", editor = "number", default = 5, template = true, help = "How many times the flight plan can fail before giving up", no_edit = PropChecker("FlightPlanning", false) },
		{ category = "Flight", id = "FlightFailureCooldown", name = "Flight Failure Cooldown",  editor = "number", default = 333, template = true, scale = "sec", help = "How often the flight plan can fail before giving up", no_edit = PropChecker("FlightPlanning", false) },
		{ category = "Flight", id = "FlightMaxWalkDist",     name = "Max Walk Dist",            editor = "number", default = 32 * guim, scale = "m", template = true, help = "Defines the max area where to use walking"},
		{ category = "Flight", id = "FlightMinDist",         name = "Min Flight Dist",          editor = "number", default = 16 * guim, scale = "m", template = true, help = "Defines the min distance to use flying"},
		{ category = "Flight", id = "FlightWalkExcess",      name = "Walk To Fly Excess",       editor = "number", default = 30, scale = "%", min = 0, template = true, help = "How much longer should be the walk path to prefer flying", },
		{ category = "Flight", id = "FlightIsHovering",      name = "Is Hovering",              editor = "bool",   default = false, template = true, help = "Is the walking above the ground" },
	},
	flying = false,
	flight_stop_on_passable = true,
	
	flight_pf_ready = false, -- pf path found
	flight_landed = false,
	flight_land_pos = false, -- land pos found
	flight_land_retry = -1,
	flight_land_target_pos = false,
	flight_takeoff_pos = false, -- take-off pos found
	flight_takeoff_retry = -1,
	flight_start_velocity = false,
	
	flight_plan_failed = 0,
	flight_plan_failures = 0,
	flight_plan_force_land = true,
	
	FlightSimHeightRestrict = const.FlightRestrictAboveWalkable,
	
	OnFlyingChanged = empty_func,
	CanTakeOff = return_true,
}

function FlyingMovable:IsOnPassable()
	return terrain.FindPassableZ(self, 0, 0)
end

function FlyingMovable:OnMoved()
	if self.flying and terrain.FindPassableZ(self, 0, 0) then
		self:SetFlying(false)
	end
end

function FlyingMovable:SetFlying(flying)
	flying = flying or false
	if self.flying == flying then
		return
	end
	self:SetAnimSpeed(1, 1000)
	if not flying then
		self:ClearFlightPath()
		self:SetAcceleration(0)
		self:ResetOrientation(0)
		self:UnlockFlightDest()
		self:SetEnumFlags(efResting)
	else
		pf.ClearPath(self)
		assert(self:GetPathPointCount() == 0)
		self:SetGravity(0)
		self:SetCurvature(false)
		self:ClearEnumFlags(efResting)
		local start_velocity = self.flight_start_velocity
		if start_velocity then
			if start_velocity == point30 then
				self:StopInterpolation()
			else
				self:SetPos(self:GetVisualPos() + start_velocity, 1000)
			end
			self.flight_start_velocity = nil
		end
	end
	self.flying = flying
	self:OnFlyingChanged(flying)
end

FlyingMovable.OnFlyingChanged = empty_func

function FlyingMovableAutoResolve:OnStopMoving(pf_status)
	if self.flying then
		if pf_status and IsExactlyOnPassableLevel(self) then
			-- fix flying status after landing for not planned paths
			self:SetFlying(false)
		else
			self:ClearFlightPath()
		end
	end
	self.flight_pf_ready = nil
	self.flight_landed = nil
	self.flight_land_pos = nil
	self.flight_land_target_pos = nil
	self.flight_takeoff_pos = nil
	self.flight_start_velocity = nil
	self.flight_takeoff_retry = nil
	self.flight_land_retry = nil
	self.FlightPlanning = nil
end

local function CanFlyToFilter(x, y, z, self)
	return self:CanFlyTo(x, y, z)
end

function FlyingMovable:FindLandingPos(flight_dests)
	if not next(flight_dests) then
		return
	end
	self:MarkFlightArea(flight_dests[#flight_dests])
	local count = Min(4, #flight_dests)
	for i=1,count do
		local land_pos = FlightFindLandingAround(flight_dests[i], self, dest_search_dist)
		if land_pos then
			assert(IsPosOutside(land_pos))
			return land_pos
		end
	end
	local land_pos = FlightFindReachableLanding(flight_dests, self)
	if land_pos then
		return land_pos
	end
	local has_passable
	for _, pt in ipairs(flight_dests) do
		if self:CheckPassable(pt) then
			if self:CanFlyTo(pt) then
				return pt
			end
			has_passable = true
		end
	end
	if not has_passable then
		return
	end
	for _, pt in ipairs(flight_dests) do
		local land_pos = terrain.FindReachable(pt,
			tfrPassClass, self,
			tfrCanDestlock, self,
			tfrLimitDist, max_search_dist, 0,
			tfrLuaFilter, CanFlyToFilter, self)
		if land_pos then
			return land_pos
		end
	end
end

function FlyingMovable:FindTakeoffPos()
	self:MarkFlightAround(self, max_takeoff_dist)
	--DbgClear(true) DbgAddCircle(self, max_takeoff_dist) FlightDbgShow{ show_flight_map = true }
	
	local takeoff_pos, takeoff_reached = FlightFindLandingAround(self, self, max_search_dist)
	if not takeoff_pos then
		takeoff_pos, takeoff_reached = FlightFindReachableLanding(self, self, "takeoff", max_takeoff_dist)
		if not takeoff_pos and self:CanTakeOff() then
			takeoff_pos, takeoff_reached = self, true
		end
	end
	assert(IsPosOutside(takeoff_pos))
	return takeoff_pos, takeoff_reached
end
		
function FlyingMovable:IsShortPath(walk_excess, max_walk_dist, min_flight_dist)
	if self:IsPathPartial() then
		return
	end
	local last = self:GetPathPointCount() > 0 and self:GetPathPoint(1)
	if not last then
		return true
	end
	local dist = pf.GetLinearDist(self, last)
	if max_walk_dist and dist > max_walk_dist then
		return
	end
	local short_path_len = Max(min_flight_dist or 0, Min(max_walk_dist or max_int, dist * (100 + (walk_excess or 0)) / 100))
	local ignore_tunnels = true
	local path_len = self:GetPathLen(1, short_path_len, ignore_tunnels)
	return path_len <= short_path_len
end

function FlyingMovable:Step(dest, ...)
	local flight_planning = self.FlightPlanning
	if self.flying then
		if not flight_planning or self.flight_land_retry > GameTime() then
			return FlyingObj.Step(self, dest, ...)
		end
		local moving_target = IsValid(dest) and dest:TimeToPosInterpolationEnd() > 0
		if moving_target and self:CanFlyTo(dest) then
			self.flight_land_pos = nil
			return FlyingObj.Step(self, dest, ...)
		end
		local land_pos = self.flight_land_pos
		if land_pos and moving_target then
			local prev_target_pos = self.flight_land_target_pos
			if not prev_target_pos or not dest:IsCloser(prev_target_pos, self.FlightMaxWalkDist / 2) then
				land_pos = false
			end
		end
		if not land_pos then
			local dests = pf.ResolveGotoDests(self, dest, ...)
			if not dests then
				return pfFailed
			end
			land_pos = self:FindLandingPos(dests)
			if not land_pos then
				if self.flight_plan_force_land then
					return pfFailed
				end
				self:SetAdjustFlightTarget(true)
				self.flight_land_retry = GameTime() + 10000 -- try continue walking
				return FlyingObj.Step(self, dest, ...)
			end
			self.flight_land_pos = land_pos
			self.flight_land_retry = nil
			self.flight_land_target_pos = moving_target and dest:GetVisualPos()
			--DbgAddVector(land_pos, 10*guim, blue) DbgAddSegment(land_pos, self, blue)
		end
		local status = FlyingObj.Step(self, land_pos)
		if status == pfFinished then
			self.flight_land_pos = nil
			self.flight_landed = true
			self:SetFlying(false)
			return self:Step(dest, ...)
		end
		return status
	end
	local walk_excess = self.FlightWalkExcess
	if not walk_excess then
		return Movable.Step(self, dest, ...)
	end
	local tx, ty, tz, max_range, min_range, dist, sl = self:ResolveFlightTarget(dest, ...)
	if sl then
		return Movable.Step(self, dest, ...)
	end
	if not tx then
		return pfFailed
	end
	local max_walk_dist, min_flight_dist = self.FlightMaxWalkDist, self.FlightMinDist
	if not self.FlightPlanning then
		local flight_pf_ready = self.flight_pf_ready
		local can_fly_to = self:CanFlyTo(tx, ty, tz)
		if not flight_pf_ready and max_walk_dist and can_fly_to then
			-- no flight planning: restrict the pf to find a path only if close enough
			if dist > max_walk_dist then
				self:SetFlying(true)
				return self:Step(dest, ...)
			end
			self:RestrictArea(max_walk_dist) -- if the pf fails then force flying
		end
		self.flight_pf_ready = true
		local status, new_path = Movable.Step(self, dest, ...)
		if status == pfFinished or not can_fly_to or (status >= 0 or status == pfTunnel) and self:IsShortPath(walk_excess, max_walk_dist, min_flight_dist) then
			return status
		end
		self:SetFlying(true)
		return self:Step(dest, ...)
	end
	if self.flight_landed or self.flight_takeoff_retry > GameTime() then
		return Movable.Step(self, dest, ...)
	end
	self.flight_start_velocity = self:GetVelocityVector(-1)
	local takeoff_pos = self.flight_takeoff_pos
	local takeoff_reached
	if not takeoff_pos then
		local pf_step = true
		local flight_pf_ready = self.flight_pf_ready
		if self:CheckPassable() then
			if not flight_pf_ready then
				pf_step = max_range == 0 and ConnectivityCheck(self, dest, ...)
			else
				pf_step = self:IsShortPath(walk_excess, max_walk_dist, min_flight_dist)
			end
		end
		if pf_step then
			self.flight_pf_ready = true
			return Movable.Step(self, dest, ...)
		end
		takeoff_pos, takeoff_reached = self:FindTakeoffPos()
		if not takeoff_pos then
			self.flight_takeoff_retry = GameTime() + 10000 -- stop searching takeoff location and continue walking
			--DbgDrawPath(self, yellow)
			return self:Step(dest, ...)
		elseif not takeoff_reached then
			-- TODO: if the takeoff path + landing path is not quite shorter than the pf path ignore the flight
			self.flight_pf_ready = nil
			self.flight_takeoff_pos = takeoff_pos
			--DbgAddVector(takeoff_pos, 10*guim, green) DbgAddSegment(takeoff_pos, self, green)
		end
	end
	if not takeoff_reached then
		local status = Movable.Step(self, takeoff_pos)
		if status ~= pfFinished then
			return status
		end
	end
	self.flight_takeoff_pos = nil
	if not terrain.IsPassable(tx, ty, tz, 0) then
		-- the destination cannot be reached by walking
		if not self:CanFlyTo(tx, ty, tz) then
			return pfFailed
		end
		self:SetFlying(true) 
	else
		local dests = pf.ResolveGotoDests(self, dest, ...)
		local land_pos = self:FindLandingPos(dests)
		if not land_pos or self:IsCloserWalkDist(land_pos, min_flight_dist) then
			self.flight_takeoff_retry = GameTime() + 10000 -- try continue walking
		else
			self.flight_land_pos = land_pos
			self:SetFlying(true)
		end
	end
	return self:Step(dest, ...)
end

function FlyingMovable:TryContinueMove(status, ...)
	if status == pfFinished then
		return
	end
	if not self.FlightPlanning then
		return Movable.TryContinueMove(self, status, ...)
	end
	local success = Movable.TryContinueMove(self, status, ...)
	if success then
		return true
	end
	local take_off
	if self.flying then
		if not self.flight_land_pos then
			return 
		end
		self.flight_land_pos = nil -- try finding another land pos?
	elseif self.flight_landed then
		self.flight_landed = nil -- try to take-off again
	elseif self.flight_takeoff_pos then
		self.flight_takeoff_pos = nil -- try to find a new take-off position
	elseif self:CanTakeOff() and (status ~= pfDestLocked or pf.GetLinearDist(self, ...) >= FlightTile) then
		take_off = true
	else
		return
	end
	local time = GameTime()
	if time - self.flight_plan_failed > self.FlightFailureCooldown then
		self.flight_plan_failures = nil
	elseif self.flight_plan_failures < self.FlightMaxFailures then
		self.flight_plan_failures = self.flight_plan_failures + 1
	else
		return -- give up
	end
	self.flight_plan_failed = time
	if take_off then
		self:TakeOff()
	end
	return true
end

function FlyingMovable:ClearPath()
	if self.flying then
		return self:ClearFlightPath()
	end
	return Movable.ClearPath(self)
end

function FlyingMovable:GetPathHash(seed)
	if self.flying then
		return FlyingObj.GetPathHash(self, seed)
	end
	return Movable.GetPathHash(self, seed)
end

function FlyingMovable:LockFlightDest(x, y, z)
	local visual_z = ResolveZ(x, y, z)
	if not visual_z then
		return
	end
	-- TODO: fying destlocks
	if self.outside_pathfinder
	or not self:IsCloser(x, y, visual_z, pfSmartDestlockDist)
	or not self:CheckPassable(x, y, z)
	or PlaceDestlock(self, x, y, z) then
		return x, y, z
	end
	local flight_target = self.flight_target
	if not flight_target or flight_target:Equal(x, y, z) or not PlaceDestlock(self, flight_target) then
		-- previous target cannot be destlocked as well
		flight_target = terrain.FindReachable(x, y, z,
			tfrPassClass, self,
			tfrCanDestlock, self)
		if not flight_target then
			return
		end
		local destlocked = PlaceDestlock(self, flight_target)
		assert(destlocked)
	end
	return flight_target:xyz()
end

function FlyingMovable:UnlockFlightDest()
	if IsValid(self) then
		return self:RemoveDestlock()
	end
end
	
function FlyingMovable:TryLand()
	if not self.flying then
		return
	end
	local z = terrain.FindPassableZ(self, 32*guim) -- TODO: should go to a suitable height first
	if not z then
		return
	end
	self:ClearPath()
	local visual_z = z == InvalidZ and terrain.GetHeight(self) or z
	local x, y, z0 = self:GetVisualPosXYZ()
	local anim = self.FlightAnimStop
	local dt = anim and self:GetAnimDuration(anim) or 0
	if dt > 0 then
		self:SetState(anim)
	else
		dt = 1000
	end
	self:SetPos(x, y, visual_z, dt)
	self:SetAcceleration(0)
	self:ResetOrientation(dt)
	self:SetAnimSpeed(1, 1000)
	self:SetFlying(false)
end

function FlyingMovable:TryTakeOff()
	self:TakeOff()
	return true
end

function FlyingMovable:TakeOff()
	if self.flying then
		return
	end
	self:ClearPath()
	local x, y, z0 = self:GetVisualPosXYZ()
	local z = z0 + self.FlightSimHeightMin
	local anim = self.FlightAnimStart
	local dt = anim and self:GetAnimDuration(anim) or 0
	if dt > 0 then
		self:SetState(anim)
	else
		dt = 1000
	end
	self:SetPos(x, y, z, dt)
	self:SetAcceleration(0)
	self:SetFlying(true)
	return dt
end

function FlyingMovable:Face(target, time)
	if self.flying then
		return FlyingObj.Face(self, target, time)
	end
	return Movable.Face(self, target, time)
end

----

local efFlightObstacle = const.efFlightObstacle

DefineClass.FlightObstacle = {
	__parents = { "CObject" },
	flags = { cofComponentFlightObstacle = true, efFlightObstacle = true },
	FlightInitObstacle = FlightInitBox,
}

function FlightObstacle:InitElementConstruction()
	self:ClearEnumFlags(efFlightObstacle)
end

function FlightObstacle:CompleteElementConstruction()
	if self:GetComponentFlags(const.cofComponentFlightObstacle) == 0 then
		return
	end
	self:SetEnumFlags(efFlightObstacle)
	self:FlightInitObstacle()
end

function FlightObstacle:OnMoved()
	self:FlightInitObstacle()
end

----

function FlightInitGrids()
	local flight_map, energy_map = FlightMap, FlightEnergy
	if not flight_map then
		flight_map, energy_map = FlightCreateGrids(mapdata.PassBorder)
		FlightMap, FlightEnergy = flight_map, energy_map
	end
	return flight_map, energy_map
end

local test_box = box()

function FlightMarkBetween(ptFrom, ptTo, min_height, obj_radius, mark_border)
	min_height = min_height or 0
	obj_radius = obj_radius or 0
	local marked
	local flight_area = FlightArea
	local now = GameTime()
	
	if now ~= FlightTimestamp
	or not flight_area
	or FlightPassVersion ~= PassVersion
	or FlightMarkMinHeight ~= min_height
	or FlightMarkObjRadius ~= obj_radius
	or not FlightIsMarked(flight_area, FlightMarkFrom, FlightMarkTo, FlightMarkBorder, ptFrom, ptTo, mark_border) then
		local flight_border
		local flight_map = FlightInitGrids()
		--local st = GetPreciseTicks()
		flight_area, flight_border = FlightMarkObstacles(flight_map, ptFrom, ptTo, min_height, obj_radius, mark_border)
		if not flight_area then
			return
		end
		--print("FlightMarkObstacles", GetPreciseTicks() - st)
		FlightEnergyMin = false -- mark the energy map as invalid
		FlightMarkMinHeight, FlightMarkObjRadius = min_height, obj_radius
		FlightMarkFrom, FlightMarkTo = ResolveVisualPos(ptFrom), ResolveVisualPos(ptTo) 
		FlightArea = flight_area or false
		FlightTimestamp = now
		FlightPassVersion = PassVersion
		FlightMarkBorder = flight_border
		marked = true
	end
	--dbg(FlightDbgMark(ptFrom, ptTo))
	return flight_area, marked
end

function FlightCalcEnergyTo(ptTo, flight_area, slope_penalty, grow_obstacles)
	flight_area = flight_area or FlightArea
	slope_penalty = slope_penalty or 0
	grow_obstacles = grow_obstacles or false
	if not FlightEnergyMin
	or FlightArea ~= flight_area
	or FlightSlopePenalty ~= slope_penalty
	or FlightGrowObstacles ~= grow_obstacles
	or not FlightEnergyMin:Equal2D(GameToFlight(ptTo)) then
		--local st = GetPreciseTicks()
		FlightEnergyMin = FlightCalcEnergy(FlightMap, FlightEnergy, ptTo, flight_area, slope_penalty, grow_obstacles) or false
		FlightSlopePenalty = slope_penalty
		FlightGrowObstacles = grow_obstacles
		--print("FlightCalcEnergy", GetPreciseTicks() - st)
		if not FlightEnergyMin then
			return
		end
	end
	return FlightEnergyMin
end

function FlightCalcPathBetween(ptFrom, ptTo, flags, min_height, obj_radius, slope_penalty, smooth_dist, range, debug_iter)
	assert(ptTo and terrain.IsPointInBounds(ptTo, mapdata.PassBorder))
	--local st = GetPreciseTicks()
	local flight_area, marked = FlightMarkBetween(ptFrom, ptTo, min_height, obj_radius)
	if not flight_area then
		return
	end
	local grow_obstacles = smooth_dist and IsCloser2D(ptFrom, ptTo, smooth_dist)
	if not FlightCalcEnergyTo(ptTo, flight_area, slope_penalty, grow_obstacles) then
		return
	end
	flags = flags or flight_default_flags
	range = range or 0
	assert(flags ~= 0)
	FlightFrom, FlightTo, FlightFlags, FlightSmoothDist, FlightDestRange = ptFrom, ptTo, flags, smooth_dist, range
	return FlightFindPath(ptFrom, ptTo, FlightMap, FlightEnergy, flight_area, flags, range, debug_iter)
end

----

function FlightInitObstacles()
	local _, max_surf_radius = GetMapMaxObjRadius()
	local ebox = GetPlayBox():grow(max_surf_radius)
	MapForEach(ebox, efFlightObstacle, function(obj)
		return obj:FlightInitObstacle()
	end)
end

function FlightInitObstaclesList(objs)
	local GetEnumFlags = CObject.GetEnumFlags
	for _, obj in ipairs(objs) do
		if GetEnumFlags(obj, efFlightObstacle) ~= 0 then
			obj:FlightInitObstacle(obj)
		end
	end
end

function OnMsg.NewMap()
	SuspendProcessing("FlightInitObstacle", "MapLoading", true)
end

function OnMsg.PostNewMapLoaded()
	ResumeProcessing("FlightInitObstacle", "MapLoading", true)
	if not mapdata.GameLogic then
		return
	end
	FlightInitObstacles()
end

function OnMsg.PrefabPlaced(name, objs)
	if not mapdata.GameLogic or IsProcessingSuspended("FlightInitObstacle") then
		return
	end
	FlightInitObstaclesList(objs)
end

function FlightInvalidatePaths(box)
	local CheckPassable = pf.CheckPassable
	local IsPosOutside = IsPosOutside or return_true
	local Point2DInside = box and box.Point2DInside or return_true
	local FlightPathIntersectEst = FlightPathIntersectEst
	for _, obj in ipairs(FlyingObjs) do
		local flight_path = obj.flight_path
		if flight_path and #flight_path > 0 and (not box or FlightPathIntersectEst(flight_path, box, obj.flight_spline_idx)) then
			obj.flight_path = nil
		end
		local flight_land_pos = obj.flight_land_pos
		if flight_land_pos and Point2DInside(box, flight_land_pos) then
			if not CheckPassable(obj, flight_land_pos) or not IsPosOutside(flight_land_pos) then
				obj.flight_land_pos = nil
			end
		end
		local flight_takeoff_pos = obj.flight_takeoff_pos
		if flight_takeoff_pos and Point2DInside(box, flight_takeoff_pos) then
			if not CheckPassable(obj, flight_takeoff_pos) or not IsPosOutside(flight_takeoff_pos) then
				obj.flight_takeoff_pos = nil
			end
		end
	end
end

OnMsg.OnPassabilityChanged = FlightInvalidatePaths

----

function GetSplineParams(start_pos, start_speed, end_pos, end_speed)
	local v0 = start_speed:Len()
	local v1 = end_speed:Len()
	local dist = start_pos:Dist(end_pos)
	assert((v0 > 0 or v1 > 0) and (v0 >= 0 and v1 >= 0))
	assert(dist >= 3)
	local pa = (dist >= 3 and v0 > 0) and (start_pos + SetLen(start_speed, dist / 3)) or start_pos
	local pb = (dist >= 3 and v1 > 0) and (end_pos - SetLen(end_speed, dist / 3)) or end_pos
	local spline = { start_pos, pa, pb, end_pos }
	local len = Max(BS3_GetSplineLength3D(spline), 1)
	local time_est = MulDivRound(1000, 2 * len, v1 + v0)
	return spline, len, v0, v1, time_est
end

function WaitFollowSpline(obj, spline, len, v0, v1, step_time, min_step, max_step, orient, yaw_to_roll_pct)
	if not IsValid(obj) then
		return
	end
	len = len or S3_GetSplineLength3D(spline)
	v0 = v0 or obj:GetVelocityVector()
	v1 = v1 or v0
	step_time = step_time or 50
	min_step = min_step or Max(1, len/100)
	max_step = max_step or Max(min_step, len/10)
	local roll, pitch, yaw, yaw0 = 0
	if orient and (yaw_to_roll_pct or 0) ~= 0 then
		roll, pitch, yaw0 = obj:GetRollPitchYaw()
	end
	local v = v0
	local dist = 0
	while true do
		local step = Clamp(step_time * v / 1000, min_step, max_step)
		dist = dist + step
		if dist > len - step / 2 then
			dist = len
		end
		local x, y, z, dirx, diry, dirz = BS3_GetSplinePosDir(spline, dist, len)
		v = v0 + (v1 - v0) * dist / len
		local accel, dt = obj:GetAccelerationAndTime(x, y, z, v)
		if orient then
			pitch, yaw = GetPitchYaw(dirx, diry, dirz)
			if yaw0 then
				roll = 10 * AngleDiff(yaw, yaw0) * yaw_to_roll_pct / dt
				yaw0 = yaw
			end
			obj:SetRollPitchYaw(roll, pitch, yaw, dt)
		end
		obj:SetPos(x, y, z, dt)
		obj:SetAcceleration(accel)
		if dist == len then
			Sleep(dt)
			break
		end
		Sleep(dt - dt/10)
	end
	if IsValid(obj) then
		obj:SetAcceleration(0)
	end
end

local tfpLanding = const.tfpPassClass | const.tfpCanDestlock | const.tfpLimitDist | const.tfpLuaFilter

function FlightFindLandingAround(pos, unit, max_radius, min_radius)
	local flight_map, flight_area = FlightMap, FlightArea
	local landing, valid = FlightIsLandingPos(pos, flight_map, flight_area)
	if not valid then
		return
	end
	max_radius = max_radius or max_search_dist
	min_radius = min_radius or 0
	if not unit:CheckPassable(pos) then
		return terrain.FindPassableTile(pos, tfpLanding, max_radius, min_radius, unit, unit, FlightIsLandingPos, flight_map, flight_area)
	end
	if min_radius <= 0 and landing then
		if not unit or unit:CheckPassable(pos, true) then
			return pos, true
		end
	end
	--DbgAddCircle(pt, FlightTile, red) DbgAddVector(pt, guim, red)
	return terrain.FindReachable(pos,
		tfrPassClass, unit,
		tfrCanDestlock, unit,
		tfrLimitDist, max_radius, min_radius,
		tfrLuaFilter, FlightIsLandingPos, flight_map, flight_area)
end

function FlightFindReachableLanding(target, unit, takeoff, radius)
	local flight_map = FlightMap
	if not flight_map then
		return
	end
	local pfclass = unit and unit:GetPfClass() or 0
	local max_dist, min_dist = radius or max_int, 0
	local x, y, z, reached = FlightFindLanding(flight_map, target, max_dist, min_dist, unit, ConnectivityCheck, target, pfclass, 0, takeoff)
	if not x then
		return
	end
	assert(IsPosOutside(x, y, z))
	local landing = point(x, y, z)
	if reached then
		return landing, true
	end
	local src, dst
	if takeoff then
		src, dst = target, landing
	else
		src, dst = landing, target
	end
	local path, has_path = pf.GetPosPath(src, dst, pfclass)
	if not path or not has_path then
		return
	end
	local i1, i2, di
	if takeoff then
		i1, i2, di = #path - 1, 2, -1
	else
		i1, i2, di = 2, #path - 1, 1
	end
	local last_pt
	for i=i1,i2,di do
		local pt = path[i]
		if not pt then break end
		if IsValidPos(pt) then
			local found = FlightFindLandingAround(pt, unit, step_search_dist)
			--DbgAddVector(pt, guim, found and green or red) DbgAddCircle(pt, step_search_dist, found and green or red) DbgAddSegment(pt, last_pt or pt) DbgAddSegment(pt, found or pt, green)
			if found then
				assert(IsPosOutside(found))
				landing = found
				break
			end
			last_pt = pt
		end
	end
	return landing
end

----

function FlyingObj:CheatRecalcPath()
	self:RecalcFlightPath()
end