DefineClass.DisplacerCircle =
{
	__parents = { "ParticleBehavior" },

	EditorName = "Displacer: Circle",
	EditorSubmenu = "Displacers",
	
	properties = {
		{ id = "position", name = "Position", editor = "point", scale = guim, dynamic = true },
		{ id = "normal", name = "Normal", editor = "point", scale = guim, dynamic = true },
		{ id = "inner_radius", name = "Inner radius (m)", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "outer_radius", name = "Outer radius (m)", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "secondary_radius", name = "Secondary radius (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "distribution", name = "Distribution", editor = "number", min = 1, max = 400, dynamic = true, help = "How the particles are spread accross the circle surface. Greater numbers will move more particles to the center. 50 is the uniform spread." },
	},
	
	position = point30,
	normal = point(0, 0, guim),
	inner_radius = 2000,
	outer_radius = 32000,
	secondary_radius = -1000,
	distribution = 100,
}

DefineClass.DisplacerCircleRegular =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: Circle (Regular)",
	EditorSubmenu = "Displacers",
	
	properties =
	{
		{ id = "position", name = "Position", editor = "point", scale = guim, dynamic = true },
		{ id = "normal", name = "Normal", editor = "point", scale = guim, dynamic = true, help = "The circle is going to face this direction." },
		{ id = "normal_rotation", name = "Rotation", editor = "number", min = 0, scale = 10, max = 3600, dynamic = true, help = "The angle of rotation around the specified normal." },
		{ id = "radius", name = "radius (m)", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "segments", name = "Segments", editor = "number", dynamic = true },
	},
	
	position = point30,
	normal = point(0, 0, 1),
	normal_rotation = 0,
	radius = 2000,
	segments = 10,
}

DefineClass.DisplacerSphere =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: Sphere",
	EditorSubmenu = "Displacers",
	
	properties =
	{
		{ id = "position", name = "Position", editor = "point", scale = guim },
		{ id = "inner_radius", name = "Inner radius (m)", editor = "number", min = 1, scale = 1000 },
		{ id = "outer_radius", name = "Outer radius (m)", editor = "number", min = 1, scale = 1000 },
		{ id = "distribution", name = "Distribution", editor = "number", min = 1, max = 400, dynamic = true, help = "How the particles are spread inside the sphere. Greater numbers will move more particles to the center. 33 is the uniform spread." },		
	},
	
	position = point30,
	inner_radius = 2000,
	outer_radius = 32000,
	distribution = 100,
}

DefineClass.DisplacerLine =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: Line",
	EditorSubmenu = "Displacers",
	
	properties =
	{
		{ id = "position1", name = "Start", editor = "point", scale = guim },
		{ id = "position2", name = "End", editor = "point", scale = guim },
		{ id = "spread", name = "Spread type", editor = "combo", items = { "Random", "Cycle", "Ping-pong" }, dynamic = true, help = "The method to spawn particles along the line" },
		{ id = "speed", name = "Speed(m/sec)", editor = "number", dynamic = true, scale = 1000, help = "The speed of the movement along the line for the Cycle/Ping-pong spread types" },
	},
	
	position1 = point30,
	position2 = point(1000, 0, 0),
	spread = "Random",
	speed = 1,	
}

DefineClass.DisplacerRect =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: Rect",
	EditorSubmenu = "Displacers",
	
	properties =
	{
		{ id = "position1", name = "Start", editor = "point", scale = guim },
		{ id = "position2", name = "End", editor = "point", scale = guim },
		{ id = "spread", name = "Spread type", editor = "combo", items = { "Random", "Cycle", "Ping-pong" }, dynamic = true, help = "The method to spawn particles along the line" },
		{ id = "speed", name = "Speed(m/sec)", editor = "number", dynamic = true, scale = 1000, help = "The speed of the movement along the line for the Cycle/Ping-pong spread types" },
	},
	
	position1 = point30,
	position2 = point(1000, 0, 0),
	spread = "Random",
	speed = 1,	
}

DefineClass.DisplacerLineRegular =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: Line (Regular)",
	EditorSubmenu = "Displacers",
	
	properties =
	{
		{ id = "position", name = "Position", editor = "point", scale = guim, dynamic = true },
		{ id = "direction", name = "Direction", editor = "point", scale = guim, dynamic = true, help = "The direction of the line" },
		{ id = "length", name = "length (m)", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "segments", name = "Segments", editor = "number", dynamic = true },
	},
	
	position = point30,
	direction = point(guim, 0, 0),
	length = 2000,
	segments = 10,
}

DefineClass.DisplacerRectArea =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: RectArea",
	EditorSubmenu = "Displacers",
	
	properties =
	{
		{ id = "length_x", name = "length x (m)", editor = "number", min = 1, scale = 1000, dynamic = true },
		{ id = "length_y", name = "length y (m)", editor = "number", min = 1, scale = 1000, dynamic = true },
	},
	
	length_x = 1000,
	length_y = 1000,
}

DefineClass.DisplacerPolyLine =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Displacer: Polyline",
	EditorSubmenu = "Displacers",
	
	properties = 
	{
		{ id = "emit_start", name = "Emit Start", editor = "number", scale = 10000, dynamic = true, help = "Distance along the polyline [0..10000], where emitting starts" },
		{ id = "emit_end", name = "Emit End", editor = "number", scale = 10000, dynamic = true, help = "Distance along the polyline [0..10000], where emitting ends" },
	},
	
	emit_start = 0,
	emit_end = 10000,
}

DefineClass.Emanate =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Emanate",
	
	properties =
	{
		{ id = "copy_pos", name = "Copy Position", editor = "bool" },
		{ id = "copy_rot", name = "Copy Rotation", editor = "bool" },
		{ id = "copy_size", name = "Copy Size", editor = "bool" },
		{ id = "copy_vel", name = "Copy Velocity", editor = "bool" },
		{ id = "copy_rot_vel", name = "Copy Rotation Velocity", editor = "bool" },
		{ id = "copy_color", name = "Copy Color", editor = "bool" },
		{ id = "copy_alpha", name = "Copy Alpha", editor = "bool" },
		{ id = "copy_orientation", name = "Copy Orientation", editor = "bool" },
		{ id = "target_bins", name = "Target Bins", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" } },
	},
	
	copy_pos = true,
	copy_rot = true,
	copy_size = false,
	copy_vel = false,
	copy_rot_vel = false,
	copy_color = false,
	copy_alpha = false,
	copy_orientation = false,
	target_bins = set(),
}

DefineClass.Displacer =
{
	__parents = { "ParticleBehavior" },
	
	properties =
	{
		{ id = "range_min", name = "Min Range (m)", editor = "number", scale = 1000 },
		{ id = "range_max", name = "Max Range (m)", editor = "number", scale = 1000 },
		{ id = "kill_out_of_range", name = "Kill Far Displaced Particles", editor = "bool", no_edit = function(o) return string.match(o.class, "Birth$") end },
	},
	
	range_min = 0,
	range_max = 0,
	kill_out_of_range = false,
}

DefineClass.DisplacerTerrainBirth =
{
	__parents = { "Displacer" },

	EditorName = "Displacer: Terrain (Birth)",
	EditorSubmenu = "Displacers",
}

DefineClass.DisplacerSurfaceBirth =
{
	__parents = { "Displacer" },
	EditorName = "Displacer: Surface (Birth)",
	EditorSubmenu = "Displacers",
}

DefineClass.DisplacerWaterBirth =
{
	__parents = { "Displacer" },
	EditorName = "Displacer: Water (Birth)",
	EditorSubmenu = "Displacers",
}


DefineClass.DisplacerTerrain =
{
	__parents = { "Displacer" },
	EditorName = "Displacer: Terrain",
	EditorSubmenu = "Displacers",
}

DefineClass.DisplacerSurface =
{
	__parents = { "Displacer" },
	EditorName = "Displacer: Surface",
	EditorSubmenu = "Displacers",
}

DefineClass.DisplacerWater =
{
	__parents = { "Displacer" },
	EditorName = "Displacer: Water",
	EditorSubmenu = "Displacers",
}

DefineClass.TerrainGradientVelocity =
{
	__parents = { "ParticleBehavior" },
	
	properties =
	{
		{ id = "prev_speed", name = "Prev Speed", editor = "number", scale = 1000 },
		{ id = "grad_speed", name = "Grad Speed", editor = "number", scale = 1000 },
	},
	
	prev_speed = 1000,
	grad_speed = 0,
}

DefineClass.Oscillate = 
{
	__parents = { "Displacer" },
	EditorName = "Oscillate",
	
	properties =
	{
		{ id = "x_period", name = "X period", editor = "number", min = 0, scale = 1000 },
		{ id = "x_strength", name = "X strength", editor = "range", slider = true, min = 0, max = 10000, scale = 1000 },
		{ id = "y_period", name = "Y period", editor = "number", min = 0, scale = 1000 },
		{ id = "y_strength", name = "Y strength", editor = "range", slider = true, min = 0, max = 10000, scale = 1000 },
		{ id = "z_period", name = "Z period", editor = "number", min = 0, scale = 1000 },
		{ id = "z_strength", name = "Z strength", editor = "range", slider = true, min = 0, max = 10000, scale = 1000 },
		{ id = "size_period", name = "Size period", editor = "number", min = 0, scale = 1000 },
		{ id = "size_scale", name = "Size scale", editor = "number", min = 0, max = 100, slider = true },
		{ id = "alpha_period", name = "Alpha period", editor = "number", min = 0, scale = 1000 },
		{ id = "alpha_scale", name = "Alpha scale", editor = "number", min = 0, max = 100, slider = true },
	},
	
	x_period = 1000,
	x_strength = range( 10, 10 ),
	y_period = 1000,
	y_strength = range( 10, 10 ),
	z_period = 1000,
	z_strength = range( 10, 10 ),
	size_period = 1000,
	size_scale = 0,
	alpha_period = 1000,
	alpha_scale = 0,
}
--------------------------------------------------------------------------------------------------
local max_animated_trajectory_anim_channels = 8 

local trajectory_anim_types = {
	--enum AnimatedTrajectoryAnimType
	{text = "Pentagram(poly)", value = 0 },
	{text = "Diamond(poly)", value = 1 },
	{text = "Square(poly)", value = 2 },
	{text = "Hexagon(poly)", value = 3 },
	{text = "Triangle(poly)", value = 4 },
	{text = "Circle(poly)", value = 5 },
	{text = "LineVertical(line)", value = 6 },
	{text = "LineHorizontal X(line)", value = 7 },
	{text = "LineHorizontal Y(line)", value = 8 },
	{text = "UseInputArrayOfPointsFromCode", value = 9 },
}

 local AnimatedTrajectoryAnimLoopType = {
	{text = "Repeat", value = 0,},
	{text = "PingPong", value = 1,},
	{text = "Once", value = 2,},
	{text = "Repeat(AnimateRadiusValues)", value = 3,},
}

local function no_edit_bh(self)
	return self.AnimsCount == 0
end

local function no_edit_bh_advanced(self)
	return self.AnimsCount == 0 or not self.ShowAdvanced
end

DefineClass.AnimatedTrajectory = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Displacer: Animated Trajectory",
	EditorSubmenu = "Displacers",
	
	properties = {
		{ id = "AnimsCount", name = "Number Of Animations", editor = "number", default = 0, min = 0, max = max_animated_trajectory_anim_channels, },
		{ id = "FaceAlongAnim", name = "Face along anim movement", editor = "bool", default = true, no_edit = no_edit_bh, },
		{ id = "ShowAdvanced", name = "Show advanced options", editor = "bool", default = false, no_edit = no_edit_bh, dont_save = true,},		
		{ id = "FaceCamera", name = "Face Camera", editor = "bool", default = false, help = "Rotates the final animation so that it's z axis faces the camera.", no_edit = no_edit_bh},
		
		{ id = "AddToEmitterVelo", name = "Add anim velo to emitter ws velo", editor = "number", default = 0, min = -10000, max = 10000, help = "If different from zero, will add anim velo to emitter ws velocity. This number acts as a multiplier and is divided by 100. So setting this to 100 will add the exact anim velo to the emitter velo. This will make the emitter emit particles per meter even if the obj is not in motion.", no_edit = no_edit_bh_advanced, },
		{ id = "AddToParticleVelo", name = "Add anim velo to particle velo", editor = "number", default = 0, min = -10000, max = 10000, help = "If different from zero, will add anim velo to particle velo @ birth. This number acts as a multiplier and is divided by 100. So setting this to 100 will add the exact anim velo to each particle velo.", no_edit = no_edit_bh_advanced, },
		{ id = "OverwriteParticleVelo", name = "Overwrite particle velo with anim velo", editor = "number", default = 0, min = -10000, max = 10000, help = "If different from zero, will overwrite particle velo with anim velo @ birth. This number acts as a multiplier and is divided by 100. So setting this to 100 will set the exact anim velo as each particle's velo. This option is executed after adding, so it basically negates adding velo.", no_edit = no_edit_bh_advanced, },
		{ id = "AttemptToGetGoodFutureDisp", name = "Get Good Future Positions", editor = "bool", default = false, help = "Will look harder when trying to determine future positions, fixes particle orientation glitches when using easing.", no_edit = no_edit_bh_advanced, },
		{ id = "SmoothOutZeroVecLenAngles", name = "Smooth Out Zero Vec Len Angles", editor = "bool", default = true, help = "Will use average angle growth + last angle for birth cycles that get zero length animation motion vectors.", no_edit = no_edit_bh_advanced, },
		{ id = "DisperseAlongMotion", name = "Disperse Along Motion", editor = "bool", default = true, help = "Will disperse new particles along the animation motion vector for better trails. This option automatically disables affected emitters' ws velocity dispersion.", no_edit = no_edit_bh_advanced, },
		{ id = "LockPredictionsOnPolyEdge", name = "Lock Predictions Within Edge", editor = "bool", default = true, help = "Locks point predictions to lie within the same poly edge. Clears bad orientation on poly vertexes. Unaplicable for circle and lines (it will be ignored for such anims).", no_edit = no_edit_bh_advanced, },		
	},
}

function AnimatedTrajectory:SetAnimsCount(new_value)
	if new_value < self.AnimsCount then
		local cats_to_erase = {}
		for i = self.AnimsCount, new_value + 1, -1 do
			cats_to_erase[#cats_to_erase + 1] = "Animation " .. i
		end
		
		local props = self:GetProperties()
		for i = 1, #props do
			local prop = props[i]
			if table.find(cats_to_erase, prop.category or "") then
				self[prop.id] = nil
			end
		end
	end
	
	self.AnimsCount = new_value
end

for i = 1, max_animated_trajectory_anim_channels do
	local no_edit_func = function(self)
									return i > self.AnimsCount
								end
	local no_edit_func_advanced_option = function(self)
													return no_edit_func(self) or not self.ShowAdvanced
												end
								
	local cat = "Animation " .. i
	--anim name
	table.insert(AnimatedTrajectory.properties, {
		id = "Anim" .. i,
		name = "Animation Type " .. i,
		editor = "dropdownlist",
		default = 0,
		items = trajectory_anim_types,
		help = "The name of the anim to play on channel " .. tostring(i),
		no_edit = no_edit_func,
		category = cat,
	})
	
	--anim duration
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimDuration" .. i,
		name = "Anim Duration " .. i,
		editor = "number",
		default = 5000,
		min = 1,
		max = 100000,
		help = "The amount of time it takes for the full anim in ms. For poly anims this is the amount of time to traverse all edges.",
		no_edit = no_edit_func,
		category = cat,
	})
	--anim weight
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimWeight" .. i,
		name = "Anim Weight " .. i,
		editor = "number",
		default = 100,
		min = 0,
		max = 100000,
		help = "The weight of the anim on channel " .. tostring(i),
		no_edit = no_edit_func,
		category = cat,
	})
	--anim radius
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimRadius" .. i,
		name = "Anim Radius " .. i,
		editor = "number",
		default = 5000,
		scale = guim,
		min = 0,
		max = 1000000,
		help = "The radius of the animation in m. For poly anims this is the radius of the circle that fully encompases the polygon (all poly vertexes lie on this circle). For line animations this is the lenght of the line.",
		no_edit = no_edit_func,
		category = cat,
	})
	--keep these 2 values the same if show advanced options is off.
	AnimatedTrajectory["SetAnimRadius"..i] = function(self, val)
		self["AnimRadius"..i] = val
		if not self.ShowAdvanced then
			self["AnimRadiusEnd"..i] = val
		end
	end
	--anim end radius, for radius animation.
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimRadiusEnd" .. i,
		name = "Anim End Radius " .. i,
		editor = "number",
		default = 5000,
		scale = guim,
		min = 0,
		max = 1000000,
		help = "If defferent then the animation radius, will provoke a radius animation where this value is reached @ the animation end.",
		no_edit = no_edit_func_advanced_option,
		category = cat,
	})
	--Scale duration when animatin radius?
	table.insert(AnimatedTrajectory.properties, {
		id = "ScaleDurWithRad" .. i,
		name = "Scale Duration With Radius Animation" .. i,
		editor = "bool",
		default = false,
		help = "When animating the anim radius, and this is true, the anim druation will get scaled according to the radius translation. This will produce a spiral effect.",
		no_edit = no_edit_func_advanced_option,
		category = cat,
	})
	--anim easeing n stuff
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimEase" .. i,
		name = "Anim Easing Type " .. i,
		editor = "dropdownlist",
		default = -1,
		items = function() return GetEasingCombo(-1, "none") end,
		help = "Ease type of the animation.",
		no_edit = no_edit_func,
		category = cat,
	})
	--anim loop type
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimLoopType" .. i,
		name = "Anim Loop Type " .. i,
		editor = "dropdownlist",
		default = 0,
		items = AnimatedTrajectoryAnimLoopType,
		help = "Loop type of the animation.",
		no_edit = no_edit_func,
		category = cat,
	})
	--anim direction
	table.insert(AnimatedTrajectory.properties, {
		id = "ReverseAnimDirection" .. i,
		name = "Reverse anim direction " .. i,
		editor = "bool",
		default = false,
		help = "Self explanatory.",
		no_edit = no_edit_func_advanced_option,
		category = cat,
	})
	--anim keep within anim
	table.insert(AnimatedTrajectory.properties, {
		id = "KeepWithinSameAnim" .. i,
		name = "Keep T Within Anim " .. i,
		editor = "bool",
		default = false,
		help = "Will lock anim time within a single animation when predictions are made. This is useful when anim end pos is dramatically different from anim start pos, which leads to weird interpolation results. Keep in mind that ease calculations come after this, so elastic easing will still go outside of anim time bounds.",
		no_edit = no_edit_func_advanced_option,
		category = cat,
	})
	--anim scale
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimScale" .. i,
		name = "Anim Scale " .. i,
		editor = "number",
		default = 100,
		min = -10000,
		max = 10000,
		help = "Scales (multiplies) the animation time by this number/100. This is done before easing.",
		no_edit = no_edit_func_advanced_option,
		category = cat,
	})
	--anim offset
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimOffset" .. i,
		name = "Anim Offset From Duration " .. i,
		editor = "number",
		default = 0,
		min = -10000,
		max = 10000,
		help = "Will offset this animation's start time by this number(ms). This is done before easing.",
		no_edit = no_edit_func_advanced_option,
		category = cat,
	})
	--anim normal
	table.insert(AnimatedTrajectory.properties, {
		id = "AnimNormal" .. i,
		name = "Animation Normal " .. i,
		editor = "point",
		default = point(0, 0, guim),
		scale = guim,
		help = "Rotates anim to face in the direction of the provided vector.",
		no_edit = no_edit_func,
		category = cat,
	})
end



DefineClass.DisplacerPlaneBase =
{
	__parents = { "ParticleBehavior" },
	
	properties =
	{
		{ id = "normal", name = "Normal", editor = "point", scale = 4096 },
		{ id = "distance", name = "Distance (m)", editor = "number", scale = 1000 },
	},
	
	normal = point(0, 0, 4096),
	distance = 0,
}

DefineClass.DisplacerPlaneBirth =
{
	__parents = { "DisplacerPlaneBase" },

	EditorName = "Displacer: Plane (Birth)",
	EditorSubmenu = "Displacers",
}

DefineClass.DisplacerPlane =
{
	__parents = { "DisplacerPlaneBase" },

	EditorName = "Displacer: Plane",
	EditorSubmenu = "Displacers",
}