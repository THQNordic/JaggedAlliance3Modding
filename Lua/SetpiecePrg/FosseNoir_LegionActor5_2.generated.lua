-- ========== GENERATED BY SetpiecePrg Editor (Ctrl-Alt-S) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'SetpiecePrgs', rawget(_G, 'SetpiecePrgs') or {})
SetpiecePrgs.FosseNoir_LegionActor5_2 = function(seed, state, MainActor, TargetActor)
	local li = { id = "FosseNoir_LegionActor5_2" }
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(SetpieceSetStance.Exec, SetpieceSetStance, state, rand, true, "", MainActor, "Standing", "Current Weapon", true)
	prgdbg(li, 1, 2) sprocall(SetpieceShoot.Exec, SetpieceShoot, state, rand, true, "", MainActor, "Unit", TargetActor, "Torso", "", 2, 700, 1150, 100, 0, 1)
	prgdbg(li, 1, 3) sprocall(SetpieceDeath.Exec, SetpieceDeath, state, rand, true, "", MainActor, "civ_DeathOnSpot_B")
end