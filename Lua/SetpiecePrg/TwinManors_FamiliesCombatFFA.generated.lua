-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.TwinManors_FamiliesCombatFFA = function(seed, state, TriggerUnits)
	local li = { id = "TwinManors_FamiliesCombatFFA" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(SetpieceFadeIn.Exec, SetpieceFadeIn, state, rand, false, "", 400, 700)
	local _, Abraham
	prgdbg(li, 1, 2) _, Abraham = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, Abraham, "", "Abraham", "Object", false)
	local _, Caroline
	prgdbg(li, 1, 3) _, Caroline = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, Caroline, "", "Caroline", "Object", false)
	local _, DrLEnfer
	prgdbg(li, 1, 4) _, DrLEnfer = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, DrLEnfer, "", "DrLEnfer", "Object", false)
	local _, VanTasselActorFemale
	prgdbg(li, 1, 5) _, VanTasselActorFemale = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, VanTasselActorFemale, "", "VanTasselActorFemale", "Object", false)
	local _, VanTasselActorMale
	prgdbg(li, 1, 6) _, VanTasselActorMale = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, VanTasselActorMale, "", "VanTasselActorMale", "Object", false)
	local _, LeDomasActorFemale
	prgdbg(li, 1, 7) _, LeDomasActorFemale = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, LeDomasActorFemale, "", "LeDomasActorFemale", "Object", false)
	local _, LeDomasActorMale
	prgdbg(li, 1, 8) _, LeDomasActorMale = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, LeDomasActorMale, "", "LeDomasActorMale", "Object", false)
	prgdbg(li, 1, 9) sprocall(SetpieceCamera.Exec, SetpieceCamera, state, rand, true, "", "Max", "", "", "linear", 0, false, false, point(152848, 176158, 10306), point(152930, 178861, 11605), false, false, 4406, 2000, false, 0, 0, 0, 0, 0, 0, "Default", 100)
	prgdbg(li, 1, 10) sprocall(PrgPlayEffect.Exec, PrgPlayEffect, state, rand, true, "", {PlaceObj('PlayBanterEffect', {Banters = {"TwinManorsFinale_FamiliesCombatFFA",},searchInMap = true,searchInMarker = false,}),})
	prgdbg(li, 1, 11) sprocall(SetpieceFadeOut.Exec, SetpieceFadeOut, state, rand, true, "", 700)
end