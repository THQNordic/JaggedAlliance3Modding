-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	CameraMode = "Show all",
	Map = "K-11U - Cryolabor",
	RecordFPS = 60,
	TakePlayerControl = false,
	group = "DLC1 Trailer",
	hidden_actors = false,
	id = "NewMapShotsK11U_04",
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
		LookAt1 = point(179299, 166590, 13982),
		LookAt2 = point(164220, 153596, 13982),
		Movement = "linear",
		Pos1 = point(182402, 169264, 16850),
		Pos2 = point(167323, 156269, 16850),
		Wait = false,
	}),
	PlaceObj('SetpieceFadeIn', {
		Wait = false,
	}),
})

