-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	CameraMode = "Show all",
	Map = "G-12U - Waffenlabor",
	RecordFPS = 60,
	TakePlayerControl = false,
	group = "DLC1 Trailer",
	hidden_actors = false,
	id = "NewMapShotsG12U_04",
	PlaceObj('SetpieceFadeOut', {
		Wait = false,
	}),
	PlaceObj('SetpieceSleep', {
		Time = 100,
	}),
	PlaceObj('SetpieceCamera', {
		Duration = 10000,
		Easing = 0,
		FovX = 4406,
		LookAt1 = point(172946, 140628, 16382),
		LookAt2 = point(154295, 160244, 16371),
		Movement = "linear",
		Pos1 = point(175768, 137659, 19250),
		Pos2 = point(157117, 157276, 19239),
		Wait = false,
	}),
	PlaceObj('SetpieceFadeIn', {
		Wait = false,
	}),
})

