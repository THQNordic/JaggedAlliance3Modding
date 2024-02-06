-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "GedApp",
	group = "GedApps",
	id = "GedMapVariationsEditor",
	save_in = "Ged",
	PlaceObj('XTemplateWindow', {
		'__class', "GedApp",
		'Title', "Map Variations",
		'CommonActionsInMenubar', false,
		'DiscardChangesAction', false,
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
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "root" end,
			'__class', "GedTreePanel",
			'Id', "idPresets",
			'Title', "Map Variations",
			'TitleFormatFunc', "GedFormatPresets",
			'SearchHistory', 20,
			'SearchValuesAvailable', true,
			'PersistentSearch', true,
			'ActionsClass', "Preset",
			'Delete', "GedOpPresetDelete",
			'Duplicate', "GedOpPresetDuplicate",
			'ActionContext', "PresetsPanelAction",
			'SearchActionContexts', {
				"PresetsPanelAction",
				"PresetsChildAction",
			},
			'FormatFunc', "GedPresetTree",
			'Format', "<EditorView>",
			'SelectionBind', "SelectedObject",
			'MultipleSelection', true,
			'ItemClass', function (gedapp) return gedapp.PresetClass end,
			'RootActionContext', "PresetsPanelAction",
			'ChildActionContext', "PresetsChildAction",
		}, {
			PlaceObj('XTemplateTemplate', {
				'__template', "GedStatusBar",
			}),
			}),
		PlaceObj('XTemplateWindow', {
			'__class', "XPanelSizer",
		}),
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "SelectedObject" end,
			'__class', "GedPropPanel",
			'Id', "idProps",
			'Title', "Properties",
			'EnableSearch', false,
			'ActionContext', "PropPanelAction",
			'SearchActionContexts', {
				"PropPanelAction",
				"PropAction",
			},
			'EnableShowInternalNames', false,
			'EnableCollapseCategories', false,
			'HideFirstCategory', true,
			'PropActionContext', "PropAction",
		}),
		PlaceObj('XTemplateCode', {
			'comment', "-- Setup preset filter, alt format",
			'run', function (self, parent, context)
				parent.idPresets.FilterClass = parent.FilterClass
				parent.idPresets.AltFormat = parent.AltFormat
			end,
		}),
		}),
})
