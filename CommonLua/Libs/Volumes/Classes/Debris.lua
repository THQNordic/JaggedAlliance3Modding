g_DefaultMinDebris = 5
g_DefaultMaxDebris = 20

function dbgTestSP()
	Setpieces["FlagHillExplosion"]:Test()
end

DefineClass.Debris = {
	__parents = {"Object"},
	flags = { efCollision = false, efApplyToGrids = false },
	-- no persist required
	thread = false,
	time_fade_away_start = 0,
	
	-- persist required
	opacity = 100,
	time_disappear = 0,
	time_fade_away = 0,
	spawning_obj = false,
}

function Debris:Done()
	self:DestroyThread()
end

function Debris:DestroyThread()
	if self.thread ~= CurrentThread() then
		DeleteThread(self.thread)
	end
end

function Debris:StartPhase(phase, ...)
	self:DestroyThread()
	self.thread = CreateGameTimeThread(function(...)
		self[phase](...)
	end, self, ...)
end

function Debris.enum_obj(obj, x, y, z, nx, ny, nz)
	if IsKindOfClasses(obj, "Object") then
		return true
	end
end

local saneBox = box(-const.SanePosMaxXY, -const.SanePosMaxXY, const.SanePosMaxXY - 1, const.SanePosMaxXY - 1)
local saneZ = const.SanePosMaxZ

function MakeDebrisPosSane(pos)
	return ClampPoint(pos, saneBox):SetZ(Clamp(pos:z(), -saneZ + 1, saneZ - 1))
end

local hundredSeventy = 170*60

function Debris:RotatingTravel(pos, time, rpm)
	if not rpm then
		local rpm_min, rpm_max = 20, 80
		rpm = rpm_min * 360 + self:Random(rpm_max * 360)
	end
	local angle = MulDivTrunc(rpm, time, 1000)
	local clamped_pos = MakeDebrisPosSane(pos)
	self:SetPos(clamped_pos, time)
	
	local ticks = 1 + angle / hundredSeventy
	local dt = time / ticks
	local tt = 0
	while tt < time do
		local dtt = Min(dt, time - tt)
		self:SetAngle(self:GetAngle() + angle * dtt / time, dtt)
		tt = tt + dt
		Sleep(dtt)
	end
	
	return rpm
end

local s_ExplodeDeviationSin = sin(const.DebrisExplodeDeviationAngle / 2)
local s_ExplodeDeviationCos = cos(const.DebrisExplodeDeviationAngle / 2)
local s_AxisX, s_AxisY, s_AxisZ = point(4096, 0, 0), point(0, 4096, 0), point(0, 0, 4096)
local s_SlabSizeZ = const.SlabSizeZ
local s_MinRadius = 5 * guic

function Debris:GetRandomDirInCone(dir, radius)
	local cone_height = dir:Len()
	local cone_radius = MulDivTrunc(cone_height, s_ExplodeDeviationSin, s_ExplodeDeviationCos)
	local cone_base_len = Max(self:Random(cone_radius), s_MinRadius)
	local cone_base_pt = Rotate(point(cone_base_len, 0), self:Random(360 * 60)):SetZ(0)
	local dx, dy, dz = dir:xyz()
	if dx == 0 and dx == 0 and dz ~= 0 then
		cone_base_pt = (dz < 0) and -cone_base_pt or cone_base_pt
	else
		local axis = Cross(dir, s_AxisX)
		local angle = CalcAngleBetween(dir, s_AxisX)
		cone_base_pt = RotateAxis(cone_base_pt, axis, angle)
	end
	
	return SetLen(dir + cone_base_pt, Max(self:Random(radius), s_MinRadius))
end

local min_vec_len = 500
function Debris:GetRandomInSphere(radius)
	local axis_z_rotated = RotateAxis(point(4096, 0, 0), s_AxisZ, self:Random(360 * 60))
	local axis_y_rotated = RotateAxis(axis_z_rotated, s_AxisY, self:Random(360 * 60))
	local axis_x_rotated = RotateAxis(axis_y_rotated, s_AxisY, self:Random(360 * 60))
	local min = Min(min_vec_len, radius)
	return SetLen(axis_x_rotated, self:Random(radius - min) + min)
end

local explode_z_offset = const.SlabSizeZ / 2
local flags_enum = const.efVisible
local flags_game_ignore = const.gofSolidShadow
local slab_delay = const.DebrisExplodeSlabDelay

function Debris:Explode(slab_pos, radius, origin_of_destruction)
	origin_of_destruction = origin_of_destruction or slab_pos
	
	local z_offset = -explode_z_offset + self:Random(2 * explode_z_offset)
	local has_origin = origin_of_destruction and slab_pos ~= origin_of_destruction
	local explode_dir = has_origin and SetLen(slab_pos - origin_of_destruction, 4096) or axis_z
	local cone_dir = has_origin and self:GetRandomDirInCone(explode_dir, radius) or self:GetRandomInSphere(radius)
	local fly_dir = origin_of_destruction and cone_dir or SetLen(cone_dir, Max(cone_dir:Len() + z_offset, s_MinRadius))

	local slabs_dist = has_origin and origin_of_destruction:Dist(slab_pos) / s_SlabSizeZ or 0
	if slabs_dist > 0 then
		local delay = (slabs_dist - 1) * slab_delay + self:Random(slab_delay)
		Sleep(delay)
	end
	
	local pos = slab_pos + fly_dir
	local time_explode = 20 + self:Random(200) + 100 * fly_dir:Len() / guim
	self:SetPos(slab_pos)
	local rpm = self:RotatingTravel(pos, time_explode)
	self:StartPhase("FallDown", rpm)
end

function Debris:FallDown(rpm)
	local src = self:GetPos()
	local dest = src:SetZ(terrain.GetHeight(src)) - axis_z
	local obj, pos, norm = GetClosestRayObj(src, dest, flags_enum, flags_game_ignore, Debris.enum_obj)
	if not pos then
		DoneObject(self)
		return
	end
	
	self:SetGravity()
	
	while true do
		local fall_time = self:GetGravityFallTime(pos)
		if CalcAngleBetween(norm, axis_z) > 30 * 60 and -norm ~= self:GetAxis() then -- -norm == self:GetAxis() makes setaxis assert
			-- too steep - orient to lay on the surface
			self:SetAxis(norm, fall_time)
		end
		self:RotatingTravel(pos, fall_time, rpm)
		
		local new_pos
		obj, new_pos, norm = GetClosestRayObj(pos, dest, flags_enum, flags_game_ignore, Debris.enum_obj)
		if not new_pos then
			DoneObject(self)
			return
		end
		if new_pos:Dist(pos) < s_SlabSizeZ / 2 then
			break
		end

		pos = new_pos
	end
	
	self:SetGravity(0)
	PlayFX("Debris", "hit", self)
	
	local disappear_time = const.DebrisDisappearTime
	local fade_away_time = const.DebrisFadeAwayTime- disappear_time + self:Random(2 * disappear_time)
	self:StartPhase("FadeAway", fade_away_time, disappear_time)
end

function Debris:ShouldBeVisibileWhileFading()
	return true
end

function Debris:FadeAway(time_fade_away, time_disappear)
	if not self:ShouldBeVisibileWhileFading() then
		DoneObject(self)
		return
	end
	
	self.time_fade_away = time_fade_away
	self.time_disappear = time_disappear
	self.time_fade_away_start = GameTime()
	self:SetOpacity(self.opacity)
	Sleep(self.time_fade_away)
	
	self:SetOpacity(0, self.time_disappear)
	Sleep(self.time_disappear)
	DoneObject(self)
end

function Debris:IsFadingAway()
	return self.time_fade_away ~= 0 or self.time_disappear ~= 0
end

DefineClass.DebrisWeight = {
	__parents = {"PropertyObject"},

	properties = {
		{id = "DebrisClass", name = "Debris Class", editor = "choice", items = ClassDescendantsCombo("Debris"), default = "" },
		{id = "Weight", name = "Weight", editor = "number", default = 10 },
	},
	
	EditorView = Untranslated("<DebrisClass> (Weight: <Weight>)"),
}

local s_DebrisInfoCache = {}

function GetDebrisInfo(entity)
	local cached = s_DebrisInfoCache[entity]
	if cached then
		return cached.classes, cached.debris_min, cached.debris_max
	end
	
	local entity_data = EntityData[entity]
	if not entity_data then
		return
	end
	
	local entity_data = entity_data.entity
	local classes = entity_data.debris_classes
	if classes then
		local new_classes, total_weight = {}, 0
		for idx, entry in ipairs(classes) do
			total_weight = total_weight + entry.Weight
			new_classes[idx] = {class = entry.DebrisClass, weight = total_weight}
		end	
		classes = new_classes
		classes.total_weight = total_weight
	end
	local min, max = entity_data.debris_min, entity_data.debris_max
	min = entity_data.debris_min or g_DefaultMinDebris
	max = entity_data.debris_max or g_DefaultMaxDebris
	
	-- store to the cache
	s_DebrisInfoCache[entity] = {classes = classes, debris_min = min, debris_max = max}

	return classes, min, max
end

if Platform.developer and Platform.pc and config.RunUnpacked and not Platform.ged then

AppendClass.EntitySpecProperties = {
	properties = {
		-- Debris
		{ category = "Debris", id = "debris_min", name = "Debris min" , editor = "number", default = g_DefaultMinDebris, min = 0, max = 20,
			no_edit = function(self) return not self.debris_classes or #self.debris_classes == 0 end, entitydata = true,  
		},
		{ category = "Debris", id = "debris_max", name = "Debris max" , editor = "number", default = g_DefaultMaxDebris, min = 0, max = 50,
			no_edit = function(self) return not self.debris_classes or #self.debris_classes == 0 end, entitydata = true,  
		},
		{ category = "Debris", id = "debris_list", name = "Debris list" , editor = "dropdownlist", default = "",
			items = PresetGroupCombo("DebrisList", "Default"),
		},
		{ category = "Debris", id = "debris_classes", name = "Debris classes", editor = "nested_list", default = false, 
			base_class = "DebrisWeight",
			entitydata = function(prop_meta, self)
				return table.map(self.debris_classes, function(entry) 
					return { DebrisClass = entry.DebrisClass, Weight = entry.Weight } 
				end)
			end,
		},
	},
}

end
