-- ========== GENERATED BY ExtrasGen Editor (Ctrl-Alt-G) DO NOT EDIT MANUALLY! ==========

PlaceObj('ExtrasGen', {
	RequiresClass = "EditorLineGuide",
	Shortcut = "Ctrl-Down",
	Shortcut2 = "Ctrl-Shift-Down",
	ToolbarSection = "Guide Operations",
	group = "ModifyGuides",
	id = "LengthDown",
	PlaceObj('MoveSizeGuides', {
		GuidesVar = "initial_selection",
		ShiftForHalfStep = true,
		SizeChange = -1,
		SizeChangeScale = 1,
	}),
})
