-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.CirclesChickenMove3 = function(seed, state, TriggerUnits)
	local li = { id = "CirclesChickenMove3" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	local _, Schliemann
	prgdbg(li, 1, 1) _, Schliemann = sprocall(SetpieceAssignFromGroup.Exec, SetpieceAssignFromGroup, state, rand, Schliemann, "", "chicken", "Object", false)
	prgdbg(li, 1, 2) sprocall(PrgPlaySetpiece.Exec, PrgPlaySetpiece, state, rand, false, "", "", "CirclesChickenMove3_Schliemann", nil)
end