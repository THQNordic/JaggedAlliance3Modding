-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

rawset(_G, 'ExtrasGenPrgs', rawget(_G, 'ExtrasGenPrgs') or {})
ExtrasGenPrgs.LayRust_02 = function(seed, initial_selection)
	local li = { id = "LayRust_02" }
	initial_selection = initial_selection or editor.GetSel()
	local rand = BraidRandomCreate(seed or AsyncRand())
	prgdbg(li, 1, 1) sprocall(LayDecalsAlongGuide.Exec, LayDecalsAlongGuide, rand, initial_selection, nil, {PlaceObj('PlaceObjectDataDecal', {EditorClass = "DecWallRust_02",FlipVertically = true,MoveDownPercent = 13,ScaleAfterPlace = 110,}),}, false)
end