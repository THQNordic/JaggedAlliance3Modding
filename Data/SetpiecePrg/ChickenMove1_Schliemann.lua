-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Map = "H-7 - Ruins Mine",
	StopMercMovement = false,
	TakePlayerControl = false,
	group = "Savanna",
	id = "ChickenMove1_Schliemann",
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "Schliemann",
		Group = "chicken",
	}),
	PlaceObj('SetpieceSleep', {
		Time = 2000,
	}),
	PlaceObj('SetpieceGotoPosition', {
		Actors = "Schliemann",
		Marker = "Waypoint1",
		RandomizePhase = true,
		Wait = false,
	}),
})
