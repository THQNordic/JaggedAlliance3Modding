DefineClass.ParticleBehaviorGravityWind =
{
	__parents = { "ParticleBehavior" },
	EditorName = "Gravity Wind",
	
	properties =
	{
		{ id = "direction", name = "Direction", editor = "point", scale = guim, dynamic = true },
		{ id = "start_vel", name = "Initial velocity (m/s)", editor = "number", scale = 1000, dynamic = true },
		{ id = "acceleration", name = "Acceleration (m/ss)", editor = "number", scale = 1000, dynamic = true },
		{ id = "max_vel", name = "Max velocity (m/s)", editor = "number", scale = 1000, dynamic = true },
		{ id = "world_space", name = "World space", editor = "bool" }
	},
	
	direction = point(0, 0, guim),
	start_vel = 0,
	acceleration = 900,
	max_vel = 10000,
	world_space = false,
}

DefineClass.ParticleBehaviorGravityWell = {
	__parents = { "ParticleBehavior" },
	EditorName = "Gravity Well",

	properties =
	{
		{ id = "position", name = "Position", editor = "point", scale = guim },
		{ id = "start_vel", name = "Initial velocity (m/s)", editor = "number", scale = 1000 },
		{ id = "acceleration", name = "Acceleration (m/ss)", editor = "number", scale = 1000 },
		{ id = "max_vel", name = "Max velocity (m/s)", editor = "number", scale = 1000 },
	},
	
	position = point30,
	start_vel = 0,
	acceleration = 900,
	max_vel = 10000,
}

DefineClass.ParticleBehaviorRandomSpeedSphere = {
	__parents = { "ParticleBehavior" },
	EditorName = "Random Speed: Sphere",
	properties = {
		{ id = "vel_min", name = "Min velocity (m/s)", editor = "number", scale = 1000 },
		{ id = "vel_max", name = "Max velocity (m/s)", editor = "number", scale = 1000 },
	},
	vel_min = 1000,
	vel_max = 1500,
}

DefineClass.ParticleBehaviorRandomSpeedSpray = {
	__parents = { "ParticleBehavior" },
	EditorName = "Random Speed: Spray",
	properties = {
		{ id = "direction", name = "Direction", editor = "point", scale = guim },
		{ id = "spread_angle_min", name = "Min spread angle (degrees)", editor = "number", scale = 100 },
		{ id = "spread_angle", name = "Max spread angle (degrees)", editor = "number", scale = 100 },
		{ id = "vel_min", name = "Min velocity (m/s)", editor = "number", scale = 1000, dynamic = true },
		{ id = "vel_max", name = "Max velocity (m/s)", editor = "number", scale = 1000, dynamic = true },
	},
	direction = point(0, 0, guim),
	spread_angle_min = 0,
	spread_angle = 3000,
	vel_min = 1000,
	vel_max = 1500,
}


DefineClass.ParticleBehaviorFriction = {
	__parents = { "ParticleBehavior" },
	EditorName = "Friction",
	properties = {
		{ id = "friction", name = "Friction multiplier", editor = "curve4", help = "Speed multiplier, 1.0 = no change",
			min = 600, max = 1200, scale = 1000, scale_x = 1000, max_x = 1000, },
	},
	
	friction = MakeLine(900, 900, 1000),
}

DefineClass.ParticleBehaviorTornado = {
	__parents = { "ParticleBehavior" },
	EditorName = "Tornado",
	properties = {
		{ id = "position", name = "Position", editor = "point", scale = guim },
		{ id = "direction", name = "Direction", editor = "point", scale = guim },
		{ id = "start_rpm", name = "Start rpm", editor = "number", scale = 100 },
		{ id = "mid_rpm", name = "Middle rpm", editor = "number", scale = 100 },
		{ id = "end_rpm", name = "End rpm", editor = "number", scale = 100 },
		{ id = "mid_point", name = "Middle point", editor = "number", scale = 1000 },
		{ id = "centrifugal", name = "Centrifugal", editor = "number", scale = 1000, min = -50, max = 50, slider = true },
		{ id = "max_friction", name = "Max Friction", editor = "number", scale = 1000, min = 100, max = 100000 },
		{ id = "max_distance", name = "Max Distance", editor = "number", scale = 1000, min = 100, max = 50000 },
		{ id = "friction_by_distance", name = "Friction", editor = "curve4", scale = 1000, scale_x = 1000, min = 0, max = function(o) return o.max_friction end, max_x = function(o) return o.max_distance end, },
	},
	position = point30,
	direction = point(0, 0, guim),
	start_rpm = 2000,
	mid_rpm = 2000,
	end_rpm = 2000,
	mid_point = 500,
	centrifugal = 0,
	max_friction = 100000,
	max_distance = 2000,
	friction_by_distance = MakeLine(100000, 100000, 2000),
}

DefineClass.ParticleBehaviorTurbulence = {
	__parents = { "ParticleBehavior" },
	EditorName = "Turbulence",
	properties = {
		{ id = "friction", name = "Friction multiplier", editor = "number", scale = 1000, help = "Speed multiplier, 1.0 = no change" },
	},
	
	friction = 900,
}

DefineClass.ParticleBehaviorWind = {
	__parents = { "ParticleBehavior" },
	EditorName = "Wind",
	properties = {
		{ id = "wind_mode", name = "Wind Mode", editor = "choice", items = { "windfield_per_obj", "windfield_per_particle" }, },
		{ id = "multiplier", name = "Multiplier", editor = "number", scale = 1000, help = "Controls Max Wind Speed" },
		{ id = "friction", name = "Friction", editor = "number", scale = 1000, max = 10000, min = 0, help = "Percent of velocity to transfer in 1 second. Use 0 to disable relative wind speed." },
	},
	wind_mode = "windfield_per_obj",
	multiplier = 1000,
	friction = 0,
}


DefineClass.ParticleBehaviorCollision = {
	__parents = { "ParticleBehavior" },
	EditorName = "Collision",
	
	properties = {
		{ id = "_", editor = "help", default = false, help =
[[Quality levels:
	Perfect - Every particle performs a full test with the collision system. High performance cost - keep particle count low.
	High/Low - Every tick a local cache(VGrid, scales with parsys' box) is prepared and particles are tested against it. If a particle is close to a surface, full test is performed. Scales well with particle count. Keep area low - see max_distance_from_system.
	Terrain - Particles are tested against the terrain only.
Use hr.DebugRenderParticleCollisions to see particle collision status & VGrids:
	Red - Full test
	Green - Terrain test
	Blue - Freezed particle (can't move & doesn't do any tests)
	Black - VGrid test, no collision test]]},
		{ id = "quality", name = "Quality", editor = "choice", items = {"perfect", "high", "medium", "terrain"}, default = "medium" },
		{ id = "friction", name = "Friction multiplier", editor = "number", scale = 1000, help = "Speed multiplier, 1.0 = no change", default = 900 },
		{ id = "xorbins", name = "Change Bins on collision", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" }, default = set() },
		{ id = "clearbins", name = "Clear Bins on collision", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" }, default = set() },
		{ id = "setbins", name = "Set Bins on collision", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" }, default = set() },
		{ id = "radius", name = "Radius (m)", editor = "number", scale = 1000, max = 1000, min = 0, default = 0 },
		{ id = "rest_velocity_treshold", name = "Rest Velocity Treshold", editor="number", min = 0, max = 10000, scale = 1000, default = 1000, help = "In meters/sec. Freezes particle position." },
		{ id = "max_distance_from_system", name = "Max distance from system (m)", editor="number", min = 0, max = 75000, scale = 1000, default = 10000, help = "Control Particle-Env collision. Particle-Terrain collision is always performed" },
	},
}

DefineClass.ParticleBehaviorSurfaceCollision = {
	__parents = { "ParticleBehavior" },
	EditorName = "SurfaceCollision",
	
	properties = {
		{ id = "xorbins", name = "Change Bins on collision", editor = "set", items = { "A", "B", "C", "D", "E", "F", "G", "H" }, default = set() },
		{ id = "walkable_surface", name = "Walkable", editor = "bool", help = "Whether collision is triggered when the particle is under walkable surface" },
		{ id = "terrain_surface", name = "Terrain", editor = "bool", help = "Whether collision is triggered when the particle is under terrain" },
		{ id = "kill", name = "Kill", editor = "bool", help = "Whether upon collision the particle is going to die" },
		{ id = "offset", name = "Offset from surface", editor = "number", scale = "m", help = "At what distance this behavior should get triggered" },
	}, 
	kill = false,
	offset = 0,
	walkable_surface = false,
	terrain_surface = false,
}