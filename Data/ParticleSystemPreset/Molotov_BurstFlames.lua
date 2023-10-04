-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	game_time_animated = true,
	group = "Grenade_Molotov_Cocktail",
	id = "Molotov_BurstFlames",
	particles_scale_with_object = true,
	rand_start_time = 2000,
	stable_cam_distance = true,
	PlaceObj('ParticleEmitter', {
		'label', "Fire",
		'time_stop', 1600,
		'world_space', true,
		'emit_detail_level', 100,
		'max_live_count', 100,
		'parts_per_sec', 3000,
		'lifetime_min', 1200,
		'lifetime_max', 1400,
		'position', point(0, 0, -200),
		'angle', range(0, 360),
		'shader', "Add",
		'texture', "Textures/Particles/fire2x2_Round.tga",
		'frames', point(2, 2),
		'self_illum', 30,
		'softness', 60,
		'outlines', {
			{
				point(360, 1760),
				point(1696, 1992),
				point(1528, 72),
				point(576, 72),
			},
			{
				point(2608, 1960),
				point(3928, 1960),
				point(3944, 8),
				point(2144, 8),
			},
			{
				point(88, 3984),
				point(2040, 3984),
				point(2040, 2104),
				point(88, 2104),
			},
			{
				point(2056, 2200),
				point(2056, 4088),
				point(4088, 4088),
				point(4088, 2200),
			},
		},
		'texture_hash', 4350824070843168559,
	}, nil, nil),
	PlaceObj('ParticleBehaviorEmissive', {
		'emissive_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 104, 104),
			point(298, 665, 665),
			point(778, 434, 434),
			point(1000, 267, 267),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'max_size', 3000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 205, 205),
			point(344, 297, 297),
			point(657, 397, 397),
			point(1000, 0, 0),
		},
		'non_square_size', true,
		'max_size_2', 3000,
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 100, 100),
			point(126, 406, 406),
			point(761, 590, 590),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorTornado', {
		'start_rpm', 5000,
		'mid_rpm', 4000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'probability', 40,
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 1011, 1011),
			point(348, 938, 938),
			point(658, 904, 904),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('DisplacerCircle', {
		'inner_radius', 2,
		'outer_radius', 600,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(142, 642, 642),
			point(549, 367, 367),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'start_vel', 2000,
		'acceleration', 2000,
		'max_vel', 20000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', nil, nil, nil),
	PlaceObj('FaceAlongMovement', nil, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'start_color_min', RGBA(167, 73, 4, 255),
		'start_intensity_min', 2000,
		'start_color_max', RGBA(167, 73, 4, 255),
		'start_intensity_max', 3000,
		'mid_color', RGBA(255, 143, 44, 255),
		'mid_intensity', 2000,
		'end_color', RGBA(60, 23, 0, 255),
		'end_intensity', 2000,
		'middle_pos', 20,
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Ground Flame",
		'bins', set( "B" ),
		'time_stop', 2000,
		'randomize_period', 50,
		'world_space', true,
		'emit_detail_level', 100,
		'max_live_count', 20,
		'parts_per_sec', 2000,
		'lifetime_min', 1200,
		'lifetime_max', 1400,
		'position', point(0, 0, -300),
		'angle', range(0, 360),
		'shader', "Add",
		'texture', "Textures/Particles/fire2x2.tga",
		'frames', point(2, 2),
		'self_illum', 30,
		'softness', 60,
		'outlines', {
			{
				point(544, 2016),
				point(1488, 2016),
				point(1680, 8),
				point(544, 8),
			},
			{
				point(2600, 1960),
				point(4080, 1960),
				point(4080, 8),
				point(2144, 8),
			},
			{
				point(88, 3984),
				point(2040, 3984),
				point(2040, 2112),
				point(88, 2112),
			},
			{
				point(2056, 2112),
				point(2056, 4088),
				point(4088, 4088),
				point(4088, 2112),
			},
		},
		'texture_hash', 7496109197729400096,
	}, nil, nil),
	PlaceObj('ParticleBehaviorWind', {
		'bins', set( "B" ),
		'probability', 80,
		'multiplier', 10000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorEmissive', {
		'bins', set( "B" ),
		'emissive_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 104, 104),
			point(298, 665, 665),
			point(742, 205, 205),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWell', {
		'bins', set( "B" ),
		'position', point(0, 0, 1400),
		'acceleration', 3000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "B" ),
		'max_size', 3000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 205, 205),
			point(344, 297, 297),
			point(657, 397, 397),
			point(1000, 511, 511),
		},
		'non_square_size', true,
		'max_size_2', 4000,
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 214, 214),
			point(395, 310, 310),
			point(764, 489, 489),
			point(1000, 725, 725),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'bins', set( "B" ),
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 865, 865),
			point(352, 899, 899),
			point(663, 988, 988),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('DisplacerCircle', {
		'bins', set( "B" ),
		'inner_radius', 2,
		'outer_radius', 400,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "B" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(298, 729, 729),
			point(565, 563, 563),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'bins', set( "B" ),
		'probability', 40,
		'start_vel', 400,
		'acceleration', 2000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', {
		'bins', set( "B" ),
	}, nil, nil),
	PlaceObj('FaceAlongMovement', {
		'bins', set( "B" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'bins', set( "B" ),
		'start_color_min', RGBA(167, 73, 4, 255),
		'start_intensity_min', 2000,
		'start_color_max', RGBA(167, 73, 4, 255),
		'start_intensity_max', 3000,
		'mid_color', RGBA(255, 143, 44, 255),
		'mid_intensity', 2000,
		'end_color', RGBA(60, 23, 0, 255),
		'end_intensity', 2000,
		'middle_pos', 20,
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Small Embers",
		'bins', set( "C" ),
		'time_stop', 1600,
		'world_space', true,
		'emit_detail_level', 40,
		'max_live_count', 20,
		'parts_per_sec', 1000,
		'lifetime_min', 2000,
		'size_min', 20,
		'size_max', 40,
		'shader', "Add",
		'texture', "Textures/Particles/white.tga",
		'self_illum', 100,
		'outlines', {
			{
				point(248, 3832),
				point(3832, 3832),
				point(3832, 248),
				point(248, 248),
			},
		},
		'texture_hash', 2617278910886611064,
	}, nil, nil),
	PlaceObj('ParticleBehaviorWind', {
		'bins', set( "C" ),
		'probability', 60,
		'multiplier', 2000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'bins', set( "C" ),
		'probability', 60,
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 1011, 1011),
			point(348, 938, 938),
			point(658, 904, 904),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorTornado', {
		'bins', set( "C" ),
		'start_rpm', 5000,
		'mid_rpm', 4000,
	}, nil, nil),
	PlaceObj('DisplacerCircle', {
		'bins', set( "C" ),
		'inner_radius', 2,
		'outer_radius', 600,
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'bins', set( "C" ),
		'acceleration', 2000,
		'max_vel', 20000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "C" ),
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(333, 39, 39),
			point(741, 61, 61),
			point(1000, 0, 0),
		},
		'non_square_size', true,
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 63, 63),
			point(275, 91, 91),
			point(624, 301, 301),
			point(1000, 23, 23),
		},
	}, nil, nil),
	PlaceObj('FaceAlongMovement', {
		'bins', set( "C" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorEmissive', {
		'bins', set( "C" ),
		'emissive_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(311, 965, 965),
			point(731, 245, 245),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'bins', set( "C" ),
		'start_color_min', RGBA(250, 158, 51, 255),
		'start_intensity_min', 2000,
		'start_color_max', RGBA(250, 158, 51, 255),
		'start_intensity_max', 2000,
		'mid_color', RGBA(241, 114, 45, 255),
		'end_color', RGBA(233, 84, 39, 255),
		'middle_pos', 20,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "C" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(360, 914, 914),
			point(696, 651, 651),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Heat Haze",
		'bins', set( "D" ),
		'time_stop', 1600,
		'world_space', true,
		'emit_detail_level', 40,
		'max_live_count', 14,
		'parts_per_sec', 200,
		'lifetime_max', 2000,
		'position', point(0, 0, 600),
		'angle', range(0, 360),
		'size_min', 2000,
		'shader', "Distortion",
		'texture', "Textures/Particles/white.tga",
		'normal_as_flow_map', true,
		'normalmap', "Textures/Particles/test2.norm.tga",
		'softness', 200,
		'alpha', range(175, 255),
		'normal_to_distortion', true,
		'distortion_mode', "Ping-Pong",
		'distortion_scale', 3,
		'distortion_scale_max', 10,
		'drawing_order', -3,
		'outlines', {},
		'texture_hash', 2617278910886611064,
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "D" ),
		'vel_max', 2000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "D" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 326, 326),
			point(267, 112, 808),
			point(653, 232, 860),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "D" ),
		'max_size', 2000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 367, 367),
			point(313, 620, 620),
			point(669, 847, 847),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
})
