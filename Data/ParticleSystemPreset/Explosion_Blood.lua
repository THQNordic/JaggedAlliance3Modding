-- ========== GENERATED BY ParticleSystemPreset Editor DO NOT EDIT MANUALLY! ==========

PlaceObj('ParticleSystemPreset', {
	game_time_animated = true,
	group = "Impact",
	id = "Explosion_Blood",
	speed_up = 1200,
	PlaceObj('ParticleBehaviorColorize', {
		'bins', set( "A", "C", "D", "G", "H" ),
		'start_color_min', RGBA(175, 17, 17, 255),
		'type', "Start color only",
		'middle_pos', 429,
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', {
		'bins', set( "A", "B", "D", "E" ),
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Spray_Back",
		'time_stop', 200,
		'emit_detail_level', 100,
		'max_live_count', 24,
		'parts_per_sec', 100000,
		'lifetime_min', 600,
		'lifetime_max', 800,
		'position', point(0, 0, 500),
		'size_min', 200,
		'size_max', 500,
		'texture', "Textures/Particles/BloodSplashes_Directional_2x2.tga",
		'normalmap', "Textures/Particles/BloodSplashes_Directional_2x2.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'mat_roughness', 40,
		'mat_metallic', 60,
		'softness', 20,
		'alpha', range(155, 255),
		'drawing_order', 1,
		'outlines', {
			{
				point(344, 1596),
				point(1184, 2012),
				point(1404, 632),
				point(1100, 152),
			},
			{
				point(2244, 1268),
				point(2972, 1988),
				point(3692, 1096),
				point(2828, 96),
			},
			{
				point(308, 3108),
				point(912, 3936),
				point(1636, 3072),
				point(1160, 2120),
			},
			{
				point(3064, 2236),
				point(2520, 2756),
				point(3152, 3832),
				point(3816, 2104),
			},
		},
		'texture_hash', -8422212582589676985,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 1000, 1000),
			point(318, 978, 978),
			point(768, 782, 782),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'direction', point(0, 0, -1000),
		'acceleration', 100,
		'max_vel', 500,
	}, nil, nil),
	PlaceObj('FaceAlongMovement', {
		'bins', set( "A", "B" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'spread_angle', 36000,
		'vel_min', 2000,
		'vel_max', 6000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 849, 849),
			point(79, 896, 896),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'max_size', 2400,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 100, 100),
			point(125, 96, 96),
			point(722, 747, 747),
			point(1000, 1000, 1000),
		},
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 96, 96),
			point(156, 92, 92),
			point(666, 694, 694),
			point(1000, 808, 808),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorDissolve', {
		'end_alpha_test', 100,
		'middle_pos', 200,
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Spray_Mist_Back",
		'bins', set( "B" ),
		'time_stop', 400,
		'emit_detail_level', 100,
		'max_live_count', 12,
		'parts_per_sec', 100000,
		'lifetime_max', 2000,
		'position', point(0, 0, 500),
		'size_min', 200,
		'size_max', 500,
		'texture', "Textures/Particles/mist.tga",
		'normalmap', "Textures/Particles/mist.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'softness', 20,
		'alpha', range(155, 255),
		'outlines', {
			{
				point(32, 32),
				point(32, 2016),
				point(2016, 2016),
				point(2016, 32),
			},
			{
				point(2080, 2016),
				point(3968, 2016),
				point(4064, 32),
				point(2080, 32),
			},
			{
				point(32, 4032),
				point(2016, 4032),
				point(2016, 2080),
				point(32, 2080),
			},
			{
				point(2080, 4032),
				point(4064, 4032),
				point(4064, 2080),
				point(2080, 2080),
			},
		},
		'texture_hash', 6609993512092536490,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'bins', set( "B" ),
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 797, 797),
			point(342, 905, 905),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorColorize', {
		'bins', set( "B", "E" ),
		'start_color_min', RGBA(120, 14, 14, 255),
		'type', "Start color only",
		'middle_pos', 429,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "B" ),
		'max_size', 2000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 236, 236),
			point(295, 419, 419),
			point(746, 782, 782),
			point(1000, 1000, 1000),
		},
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 747, 747),
			point(305, 747, 747),
			point(893, 755, 755),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "B" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 83, 83),
			point(76, 485, 485),
			point(742, 157, 157),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "B" ),
		'spread_angle', 36000,
		'vel_min', 1400,
		'vel_max', 6000,
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Ground Splash",
		'bins', set( "C" ),
		'time_stop', 1000,
		'emit_detail_level', 100,
		'max_live_count', 12,
		'parts_per_sec', 100000,
		'lifetime_min', 12000,
		'lifetime_max', 18000,
		'angle', range(0, 360),
		'size_min', 250,
		'size_max', 1400,
		'geometry_building', "Decal",
		'decal_depth', 2000,
		'decal_group', "TerrainOnly",
		'texture', "Textures/Particles/BloodSplashes_Directional_2x2.tga",
		'normalmap', "Textures/Particles/BloodSplashes_Directional_2x2.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'mat_roughness', 20,
		'mat_metallic', 60,
		'alpha_test', 58,
		'drawing_order', 10,
		'outlines', {
			{
				point(348, 1588),
				point(1180, 2000),
				point(1400, 632),
				point(1100, 160),
			},
			{
				point(2524, 1252),
				point(3012, 1928),
				point(3640, 1164),
				point(2808, 8),
			},
			{
				point(308, 3104),
				point(908, 3924),
				point(1632, 3076),
				point(1164, 2136),
			},
			{
				point(3068, 2240),
				point(2528, 2756),
				point(3152, 3812),
				point(3812, 2104),
			},
		},
		'texture_hash', -8422212582589676985,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "C" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 328, 328),
			point(12, 1000, 1000),
			point(880, 734, 734),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', {
		'bins', set( "C" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "C" ),
		'max_size', 3000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 236, 236),
			point(14, 620, 620),
			point(738, 616, 616),
			point(1000, 616, 616),
		},
		'non_square_size', true,
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 0, 0),
			point(14, 751, 751),
			point(216, 747, 747),
			point(1000, 747, 747),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorDissolve', {
		'bins', set( "C" ),
		'start_alpha_test_min', 10,
		'start_alpha_test_max', 20,
		'mid_alpha_test', 45,
		'end_alpha_test', 100,
	}, nil, nil),
	PlaceObj('DisplacerSphere', {
		'bins', set( "C" ),
		'inner_radius', 100,
		'outer_radius', 200,
	}, nil, nil),
	PlaceObj('FaceDirection', {
		'bins', set( "C" ),
	}, nil, nil),
	PlaceObj('DisplacerTerrainBirth', {
		'bins', set( "C" ),
		'range_min', 400,
		'range_max', 1000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "C" ),
		'spread_angle', 36000,
		'vel_min', 600,
		'vel_max', 1200,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'bins', set( "C" ),
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 825, 825),
			point(254, 907, 907),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Spray_Front",
		'bins', set( "D" ),
		'time_stop', 100,
		'emit_detail_level', 100,
		'max_live_count', 30,
		'parts_per_sec', 200000,
		'lifetime_min', 800,
		'lifetime_max', 1200,
		'size_min', 400,
		'size_max', 800,
		'texture', "Textures/Particles/BloodSplashesAtmos_2x2.tga",
		'normalmap', "Textures/Particles/BloodSplashes_2x2.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'mat_roughness', 40,
		'mat_metallic', 60,
		'alpha', range(155, 255),
		'drawing_order', 1,
		'outlines', {
			{
				point(456, 1408),
				point(1496, 1888),
				point(1552, 624),
				point(552, 8),
			},
			{
				point(2320, 296),
				point(2576, 1928),
				point(3488, 1888),
				point(3648, 160),
			},
			{
				point(152, 2176),
				point(152, 3768),
				point(1592, 3768),
				point(1728, 2120),
			},
			{
				point(2432, 2984),
				point(2952, 3992),
				point(3792, 3432),
				point(3104, 2168),
			},
		},
		'texture_hash', -7050120831119995156,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'bins', set( "D" ),
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 734, 734),
			point(342, 905, 905),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "D" ),
		'spread_angle', 6000,
		'vel_min', 6000,
		'vel_max', 10000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'bins', set( "D" ),
		'direction', point(0, 0, -1000),
		'acceleration', 4000,
		'max_vel', 6000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorDissolve', {
		'bins', set( "D" ),
		'start_alpha_test_max', 4,
		'mid_alpha_test', 76,
		'end_alpha_test', 100,
		'type', "Interpolate through mid",
		'middle_pos', 267,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "D" ),
		'max_size', 1200,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 253, 253),
			point(339, 677, 677),
			point(663, 843, 843),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Spray_Mist_Front",
		'bins', set( "E" ),
		'time_stop', 200,
		'emit_detail_level', 100,
		'max_live_count', 2,
		'parts_per_sec', 100000,
		'lifetime_min', 400,
		'lifetime_max', 800,
		'size_min', 200,
		'size_max', 500,
		'texture', "Textures/Particles/mist.tga",
		'normalmap', "Textures/Particles/mist.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'softness', 20,
		'alpha', range(155, 255),
		'outlines', {
			{
				point(32, 32),
				point(32, 2016),
				point(2016, 2016),
				point(2016, 32),
			},
			{
				point(2080, 2016),
				point(3968, 2016),
				point(4064, 32),
				point(2080, 32),
			},
			{
				point(32, 4032),
				point(2016, 4032),
				point(2016, 2080),
				point(32, 2080),
			},
			{
				point(2080, 4032),
				point(4064, 4032),
				point(4064, 2080),
				point(2080, 2080),
			},
		},
		'texture_hash', 6609993512092536490,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFriction', {
		'bins', set( "E" ),
		'friction', {
			range_y = 10,
			scale = 1000,
			point(0, 663, 663),
			point(342, 905, 905),
			point(667, 900, 900),
			point(1000, 900, 900),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "E" ),
		'spread_angle', 6000,
		'vel_min', 4000,
		'vel_max', 6000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "E" ),
		'max_size', 1000,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 236, 236),
			point(344, 498, 498),
			point(746, 782, 782),
			point(1000, 1000, 1000),
		},
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 747, 747),
			point(305, 747, 747),
			point(893, 755, 755),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "E" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 336, 336),
			point(353, 581, 581),
			point(801, 341, 341),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Splash_Back",
		'bins', set( "G" ),
		'time_stop', 400,
		'emit_detail_level', 100,
		'max_live_count', 24,
		'parts_per_sec', 100000,
		'lifetime_min', 600,
		'lifetime_max', 1000,
		'angle', range(0, 360),
		'size_min', 200,
		'size_max', 500,
		'texture', "Textures/Particles/BloodSplashesAtmos_2x2.tga",
		'normalmap', "Textures/Particles/BloodSplashes_2x2.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'mat_roughness', 40,
		'mat_metallic', 60,
		'softness', 20,
		'alpha', range(155, 255),
		'drawing_order', 1,
		'outlines', {
			{
				point(456, 1408),
				point(1496, 1888),
				point(1552, 624),
				point(552, 8),
			},
			{
				point(2320, 296),
				point(2576, 1928),
				point(3488, 1888),
				point(3648, 160),
			},
			{
				point(152, 2176),
				point(152, 3768),
				point(1592, 3768),
				point(1728, 2120),
			},
			{
				point(2432, 2984),
				point(2952, 3992),
				point(3792, 3432),
				point(3104, 2168),
			},
		},
		'texture_hash', -7050120831119995156,
	}, nil, nil),
	PlaceObj('ParticleEmitter', {
		'label', "Splash_Back",
		'bins', set( "H" ),
		'time_stop', 400,
		'emit_detail_level', 100,
		'max_live_count', 24,
		'parts_per_sec', 100000,
		'lifetime_min', 600,
		'lifetime_max', 1000,
		'position', point(0, 0, 500),
		'angle', range(0, 360),
		'size_min', 200,
		'size_max', 500,
		'texture', "Textures/Particles/BloodSplashesAtmos_2x2.tga",
		'normalmap', "Textures/Particles/BloodSplashes_2x2.norm.tga",
		'frames', point(2, 2),
		'light_softness', 1000,
		'mat_roughness', 40,
		'mat_metallic', 60,
		'softness', 20,
		'alpha', range(155, 255),
		'drawing_order', 1,
		'outlines', {
			{
				point(456, 1408),
				point(1496, 1888),
				point(1552, 624),
				point(552, 8),
			},
			{
				point(2320, 296),
				point(2576, 1928),
				point(3488, 1888),
				point(3648, 160),
			},
			{
				point(152, 2176),
				point(152, 3768),
				point(1592, 3768),
				point(1728, 2120),
			},
			{
				point(2432, 2984),
				point(2952, 3992),
				point(3792, 3432),
				point(3104, 2168),
			},
		},
		'texture_hash', -7050120831119995156,
	}, nil, nil),
	PlaceObj('ParticleBehaviorFadeInOut', {
		'bins', set( "G", "H" ),
		'fade_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 57, 57),
			point(62, 1000, 1000),
			point(768, 782, 782),
			point(1000, 0, 0),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorPickFrame', {
		'bins', set( "G", "H" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorGravityWind', {
		'bins', set( "G", "H" ),
		'direction', point(0, 0, -1000),
		'acceleration', 4000,
	}, nil, nil),
	PlaceObj('FaceAlongMovement', {
		'bins', set( "G", "H" ),
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "G" ),
		'spread_angle', 6000,
		'vel_min', 1400,
		'vel_max', 4000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorRandomSpeedSpray', {
		'bins', set( "H" ),
		'direction', point(0, 0, -1000),
		'spread_angle', 12000,
		'vel_min', 1400,
		'vel_max', 4000,
	}, nil, nil),
	PlaceObj('ParticleBehaviorResizeCurve', {
		'bins', set( "G", "H" ),
		'max_size', 1200,
		'size_curve', {
			range_y = 10,
			scale = 1000,
			point(0, 100, 100),
			point(68, 367, 367),
			point(517, 686, 686),
			point(1000, 1000, 1000),
		},
		'non_square_size', true,
		'size_curve_2', {
			range_y = 10,
			scale = 1000,
			point(0, 157, 157),
			point(108, 686, 686),
			point(519, 1000, 1000),
			point(1000, 1000, 1000),
		},
	}, nil, nil),
	PlaceObj('ParticleBehaviorDissolve', {
		'bins', set( "G", "H" ),
		'end_alpha_test', 100,
		'middle_pos', 200,
	}, nil, nil),
})

