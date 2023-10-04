-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

PlaceObj('SetpiecePrg', {
	Comment = "Main Setpiece",
	Map = "D-8 - Pantagruel Downtown",
	Params = {},
	RestoreCamera = true,
	group = "Pantagruel",
	hidden_actors = false,
	id = "PantagruelDowntownFirstEnter",
	PlaceObj('SetpieceFadeOut', {
		FadeOutTime = 0,
	}),
	PlaceObj('PrgPlayEffect', {
		Effects = {
			PlaceObj('ConditionalEffect', {
				'Conditions', {
					PlaceObj('SetpieceIsTestMode', {}),
				},
				'Effects', {
					PlaceObj('UnitsDespawnAmbientLife', {}),
				},
			}),
		},
		Wait = false,
	}),
	PlaceObj('PrgPlayEffect', {
		Effects = {
			PlaceObj('MusicSetTrack', {
				Playlist = "Scripted",
				Track = "Music/The Stage is set",
			}),
		},
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "Chimurenga",
		Group = "Chimurenga",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "RebelActorRoof",
		Group = "RebelActorRoof",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "RebelActor1",
		Group = "RebelActor1",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "RebelActor2",
		Group = "RebelActor2",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionActor3",
		Group = "LegionFrontActor3",
		Marker = "LegionActor3",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionActor2",
		Group = "LegionFrontActor2",
		Marker = "LegionActor2",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionActor1",
		Group = "LegionFrontActor1",
		Marker = "LegionActor1",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionSideActor1",
		Group = "LegionSideActor1",
		Marker = "LegionSideActor1",
	}),
	PlaceObj('SetpieceAssignFromGroup', {
		AssignTo = "LegionSideActor2",
		Group = "LegionSideActor2",
		Marker = "LegionSideActor2",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "Chimurenga",
		AssignTo = "LegionActor3Start",
		Marker = "ChimurengaPort",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "RebelActorRoof",
		AssignTo = "LegionActor3Start",
		Marker = "RebelActorRoofPort",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "RebelActor1",
		AssignTo = "LegionActor3Start",
		Marker = "RebelActor1Port",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "RebelActor2",
		AssignTo = "LegionActor3Start",
		Marker = "RebelActor2Port",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "LegionActor1",
		AssignTo = "LegionActor3Start",
		Marker = "LegionActor1StartRun",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "LegionActor2",
		AssignTo = "LegionActor3Start",
		Marker = "LegionActor2StartRun",
	}),
	PlaceObj('SetpieceTeleport', {
		Actors = "LegionActor3",
		AssignTo = "LegionActor3Start",
		Marker = "LegionActor3StartRun",
	}),
	PlaceObj('SetpieceCamera', {
		Duration = 0,
		LookAt1 = point(174140, 177423, 8676),
		Pos1 = point(177034, 178208, 8763),
	}),
	PlaceObj('SetpieceSleep', {
		Time = 100,
	}),
	PlaceObj('SetpieceGotoPosition', {
		Actors = "LegionActor1",
		AssignTo = "LegionActor3MoveTo",
		Marker = "LegionActor1Run",
		Stance = "Standing",
		Wait = false,
	}),
	PlaceObj('SetpieceGotoPosition', {
		Actors = "LegionActor2",
		AssignTo = "LegionActor3MoveTo",
		Marker = "LegionActor2Run",
		Stance = "Standing",
		Wait = false,
	}),
	PlaceObj('SetpieceGotoPosition', {
		Actors = "LegionActor3",
		AssignTo = "LegionActor3MoveTo",
		Marker = "LegionActor3Run",
		Stance = "Standing",
		Wait = false,
	}),
	PlaceObj('SetpieceSleep', {
		Time = 1000,
	}),
	PlaceObj('SetpieceFadeIn', {}),
	PlaceObj('SetpieceSleep', {
		Time = 5000,
	}),
	PlaceObj('SetpieceFadeOut', {}),
	PlaceObj('SetpieceCamera', {
		CamType = "Tac",
		Duration = 500,
		LookAt1 = point(159945, 141103, 6950),
		Pos1 = point(147118, 155933, 17950),
	}),
	PlaceObj('SetpieceSleep', {
		Time = 100,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return Chimurenga end,
		Prg = "DowntownFirstEnter_Chimurenga",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return LegionActor3 end,
		TargetActor2 = function (self) return LegionActor2 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return RebelActor1 end,
		Prg = "DowntownFirstEnter_RebelActor1",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return LegionActor2 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return RebelActor2 end,
		Prg = "DowntownFirstEnter_RebelActor2",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return LegionActor1 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionActor3 end,
		Prg = "DowntownFirstEnter_LegionActor3",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return Chimurenga end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionActor2 end,
		Prg = "DowntownFirstEnter_LegionActor2",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return RebelActor1 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionActor1 end,
		Prg = "DowntownFirstEnter_LegionActor1",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return RebelActor1 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionSideActor1 end,
		Prg = "DowntownFirstEnter_LegionSideActor1",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return RebelActor2 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return LegionSideActor2 end,
		Prg = "DowntownFirstEnter_LegionSideActor2",
		PrgClass = "SetpiecePrg",
		TargetActor = function (self) return RebelActor1 end,
		Wait = false,
	}),
	PlaceObj('PrgPlaySetpiece', {
		MainActor = function (self) return RebelActorRoof end,
		Prg = "DowntownFirstEnter_RebelActorRoof",
		PrgClass = "SetpiecePrg",
		Wait = false,
	}),
	PlaceObj('SetpieceCamera', {
		Duration = 6000,
		LookAt1 = point(150695, 151795, 18813),
		Pos1 = point(148189, 154692, 22027),
		Wait = false,
		Zoom = 1300,
	}),
	PlaceObj('SetpieceFadeIn', {
		FadeInDelay = 0,
		FadeInTime = 500,
		Wait = false,
	}),
	PlaceObj('PrgPlayEffect', {
		Checkpoint = "PantagruelFirstEnter_BanterDone",
		Effects = {
			PlaceObj('PlayBanterEffect', {
				Banters = {
					"PantagruelChimurenga_Setpiece",
				},
				searchInMap = true,
				searchInMarker = false,
			}),
		},
		Wait = false,
	}),
	PlaceObj('SetpieceSleep', {
		Disable = true,
		Time = 5000,
	}),
	PlaceObj('SetpieceWaitCheckpoint', {
		Disable = true,
		WaitCheckpoint = "PantagruelFirstEnter_SynPoint",
	}),
	PlaceObj('SetpieceWaitCheckpoint', {
		WaitCheckpoint = "PantagruelFirstEnter_BanterDone",
	}),
	PlaceObj('SetpieceSleep', {
		Time = 100,
	}),
	PlaceObj('SetpieceFadeOut', {}),
	PlaceObj('PrgForceStopSetpiece', {}),
})
