-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "GedTextPanel",
	group = "GedApps",
	id = "GedStatusBar",
	save_in = "Ged",
	PlaceObj('XTemplateWindow', {
		'comment', "see Preset:GetPresetStatusText",
		'__context', function (parent, context) return "SelectedObject" end,
		'__class', "GedTextPanel",
		'Id', "idStatusBar",
		'Margins', box(2, 2, 2, 0),
		'Padding', box(2, 0, 1, 0),
		'Dock', "bottom",
		'FoldWhenHidden', true,
		'Title', "",
		'DisplayWarnings', false,
		'FormatFunc', "GedPresetStatusText",
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XToggleButton",
			'Id', "idViewErrorsOnly",
			'Margins', box(2, 2, 2, 2),
			'BorderWidth', 1,
			'Padding', box(2, 0, 2, 0),
			'Dock', "right",
			'VAlign', "center",
			'LayoutMethod', "VList",
			'FoldWhenHidden', true,
			'BorderColor', RGBA(0, 0, 0, 0),
			'OnPress', function (self, gamepad)
				XToggleButton.OnPress(self, gamepad)
				local root_panel = GetParentOfKind(self, "GedTreePanel")
				local mode = not root_panel.view_errors_only
				root_panel:SetViewErrorsOnly(mode)
			end,
			'PressedBackground', RGBA(160, 160, 160, 255),
			'TextStyle', "GedError",
			'Text', "Errors only",
			'ToggledBackground', RGBA(40, 43, 48, 255),
			'ToggledBorderColor', RGBA(240, 0, 0, 255),
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XToggleButton",
			'Id', "idViewWarningsOnly",
			'Margins', box(2, 2, 2, 2),
			'BorderWidth', 1,
			'Padding', box(2, 0, 2, 0),
			'Dock', "right",
			'VAlign', "center",
			'LayoutMethod', "VList",
			'FoldWhenHidden', true,
			'BorderColor', RGBA(0, 0, 0, 0),
			'OnPress', function (self, gamepad)
				XToggleButton.OnPress(self, gamepad)
				local root_panel = GetParentOfKind(self, "GedTreePanel")
				local mode = not root_panel.view_warnings_only
				root_panel:SetViewWarningsOnly(mode)
			end,
			'PressedBackground', RGBA(160, 160, 160, 255),
			'TextStyle', "GedWarning",
			'Text', "Warnings only",
			'ToggledBackground', RGBA(40, 43, 48, 255),
			'ToggledBorderColor', RGBA(255, 140, 0, 255),
		}),
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "SelectedObject" end,
			'__class', "GedBindView",
			'Id', "idBindView",
			'BindView', "warning_error_count",
			'BindFunc', "GedPresetWarningsErrors",
			'OnViewChanged', function (self, value, control)
				local errsButton = self:ResolveId("idViewErrorsOnly")
				if errsButton then
					errsButton:SetVisible(value ~= 0)
				end
				local warnsButton = self:ResolveId("idViewWarningsOnly")
				if warnsButton then
					warnsButton:SetVisible(value ~= 0)
				end
				if value == 0 then
					local treeParent = GetParentOfKind(self, "GedTreePanel")
					treeParent:SetViewWarningsOnly(false)
					treeParent:SetViewErrorsOnly(false)
				end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "Open(self,...)",
			'func', function (self,...)
				if self.FormatFunc == "GedPresetStatusText" then
					self:ResolveId("idBindView").BindFunc = "GedPresetWarningsErrors"
				elseif self.FormatFunc == "GedModStatusText" then
					self:ResolveId("idBindView").BindFunc =  "GedModWarningsErrors"
				else
					self:ResolveId("idBindView").BindFunc = "GedPresetWarningsErrors"
				end
				GedTextPanel.Open(self,...)
			end,
		}),
		}),
})

