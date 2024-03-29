-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	group = "Shooting",
	id = "Bullet_Ricochet",
	PlaceObj('ParticleEmitter', {
		'label', "Front Flash",
		'time_stop', 80,
		'emit_detail_level', 40,
		'max_live_count', 1,
		'parts_per_sec', 10000,
		'lifetime_min', 80,
		'lifetime_max', 80,
		'position', point(100, 0, 0),
		'angle', range(0, 360),
		'size_min', 750,
		'size_max', 1000,
		'shader', "Add",
		'texture', "Textures/Particles/Assault_muzzle_01_front.tga",
		'self_illum', 200,
		'light_softness', 1000,
		'softness', 10,
		'outlines', {
			{
				point(1400, 3180),
				point(3456, 3204),
				point(3028, 1048),
				point(928, 952),
			},
		},
		'texture_hash', 7227825963616667996,
	}, nil, nil),
	PlaceObj('ParticleBehaviorEmissive', {
		'emissive_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 882, 882),
			point(318, 624, 624),
			point(702, 210, 210),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'start_color_min', RGBA(248, 204, 136, 255),
		'start_color_max', RGBA(248, 204, 136, 255),
		'mid_color', RGBA(255, 124, 59, 255),
		'end_color', RGBA(255, 76, 21, 255),
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 789, 1000),
			point(344, 568, 886),
			point(687, 402, 655),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 891, 891),
			point(173, 909, 909),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'max_size', 600,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 216, 216),
			point(209, 621, 915),
			point(673, 663, 1000),
			point(1000, 345, 533),
		},
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Bullet",
		'bins', set( "B" ),
		'time_stop', 100,
		'emit_detail_level', 100,
		'enabled', false,
		'max_live_count', 1,
		'parts_per_sec', 50000,
		'lifetime_min', 100,
		'lifetime_max', 200,
		'size_min', 5000,
		'size_max', 5000,
		'shader', "Add",
		'texture', "Textures/Particles/Bullet.tga",
		'outlines', {
			{
				point(1904, 2080),
				point(1712, 3776),
				point(2384, 3776),
				point(2144, 2016),
			},
		},
		'texture_hash', -487854556171420195,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResize', {
		'bins', set( "B" ),
		'start_size_min', 600,
		'start_size_max', 600,
		'mid_size', 400,
		'end_size', 400,
		'non_square_size', true,
		'start_size2_min', 1000,
		'start_size2_max', 1000,
		'mid_size2', 4000,
		'end_size2', 6000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'bins', set( "B" ),
		'start_color_min', RGBA(254, 165, 61, 255),
		'start_color_max', RGBA(255, 169, 58, 255),
		'type', "Start color only",
	}, nil, nil),
	PlaceObj('FaceAlongMovement', {
		'bins', set( "B" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "B" ),
		'direction', point(-1000, 0, 0),
		'spread_angle_min', 6000,
		'spread_angle', 18000,
		'vel_min', 30000,
		'vel_max', 40000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "B" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 1000, 1000),
			point(285, 1000, 1000),
			point(752, 332, 332),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorEmissive', {
		'bins', set( "B" ),
		'emissive_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 279, 279),
			point(333, 0, 0),
			point(667, 0, 0),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'bins', set( "B" ),
		'probability', 25,
		'start_vel', 1000,
		'acceleration', 100000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'bins', set(),
		'probability', 50,
		'direction', point(0, 0, -1000),
		'start_vel', 1000,
		'acceleration', 100000,
	}, nil, nil),
})

