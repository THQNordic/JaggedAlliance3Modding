-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	group = "Environment",
	id = "Env_Camera_Atmosphere",
	presim_time = 5000,
	PlaceObj('ParticleEmitter', {
		'label', "Dust Particles",
		'world_space', true,
		'emit_detail_level', 40,
		'max_live_count', 100,
		'parts_per_sec', 1000,
		'lifetime_min', 6000,
		'lifetime_max', 12000,
		'size_min', 20,
		'size_max', 40,
		'texture', "Textures/Particles/DustSpeckles.tga",
		'normalmap', "Textures/Particles/mist.norm.tga",
		'frames', point(2, 2),
		'softness', 100,
		'outlines', {
			{
				point(64, 1984),
				point(1984, 1984),
				point(1984, 64),
				point(64, 64),
			},
			{
				point(2112, 1984),
				point(4032, 1984),
				point(4032, 64),
				point(2112, 64),
			},
			{
				point(64, 4032),
				point(1984, 4032),
				point(1984, 2112),
				point(64, 2112),
			},
			{
				point(2112, 4032),
				point(4032, 4032),
				point(4032, 2112),
				point(2112, 2112),
			},
		},
		'texture_hash', -5392099339823456629,
	}, nil, nil),
	PlaceObj('DisplacerSphere', {
		'inner_radius', 8000,
		'outer_radius', 12000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'spread_angle', 36000,
		'vel_min', 200,
		'vel_max', 600,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', nil, nil, nil),
	PlaceObj('ParticleBehaviorWind', {
		'multiplier', 100,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(275, 293, 293),
			point(676, 179, 179),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'max_size', 60,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 674, 674),
			point(323, 738, 738),
			point(714, 873, 873),
			point(1000, 1000, 1000),
		},
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 326, 326),
			point(344, 661, 661),
			point(700, 932, 932),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorRotate', {
		'rpm_curve', {
			range_y = 10,
			scale = 10,
			point(0, 2, 2),
			point(356, 5, 5),
			point(676, 5, 5),
			point(1000, 5, 5),
		},
		'rpm_curve_range', range(-5, 5),
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'start_color_min', RGBA(255, 221, 177, 255),
		'start_color_max', RGBA(255, 208, 153, 255),
		'mid_color', RGBA(179, 152, 124, 255),
		'end_color', RGBA(128, 108, 89, 255),
	}, nil, nil),
})
