-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	group = "GedApps",
	id = "GedMapDataEditor",
	save_in = "Ged",
	PlaceObj('XTemplateTemplate', {
		'__template', "PresetEditor",
	}, {
		PlaceObj('XTemplateFunc', {
			'comment', "Enable double clicking",
			'name', "Open",
			'func', function (self, ...)
				GedApp.Open(self, ...)
				
				self.idPresets.idContainer.OnDoubleClickedItem = function(tree, selection)
					self:Send("GedMapDataOpenMap")
					return "break"
				end
			end,
		}),
		}),
})

