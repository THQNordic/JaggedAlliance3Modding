-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.BeastIntro_Legion_Actors2_Walking = function(seed, state, TriggerUnits)
	local li = { id = "BeastIntro_Legion_Actors2_Walking" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	local _, SP_Beast_LActor1Port
	prgdbg(li, 1, 1) _, SP_Beast_LActor1Port = sprocall(SetpieceTeleport.Exec, SetpieceTeleport, state, TriggerUnits, "SP_Beast_LActor2Port_01", true)
	prgdbg(li, 1, 2) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 700)
	local _, SP_Beast_LActor1_GoTo
	prgdbg(li, 1, 3) _, SP_Beast_LActor1_GoTo = sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, false, "", TriggerUnits, "SP_Beast_LActor2_GoTo_01", true, false, false, "Standing", true, false, "", 1000)
	prgdbg(li, 1, 4) sprocall(SetpieceSleep.Exec, SetpieceSleep, state, rand, true, "", 3000)
	local _
	prgdbg(li, 1, 5) _, SP_Beast_LActor1_GoTo = sprocall(SetpieceGotoPosition.Exec, SetpieceGotoPosition, state, rand, true, "", TriggerUnits, "SP_Beast_LActor2_GoTo", true, false, false, "Standing", true, false, "", 1000)
end