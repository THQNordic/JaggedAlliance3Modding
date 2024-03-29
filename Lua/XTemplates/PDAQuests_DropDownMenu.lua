-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	group = "Zulu PDA",
	id = "PDAQuests_DropDownMenu",
	PlaceObj('XTemplateWindow', {
		'__class', "XPopup",
		'BorderWidth', 0,
		'HAlign', "left",
		'VAlign', "top",
		'BorderColor', RGBA(0, 0, 0, 0),
		'Background', RGBA(0, 0, 0, 0),
		'MouseCursor', "UI/Cursors/Pda_Hand.tga",
		'FocusedBorderColor', RGBA(0, 0, 0, 0),
		'FocusedBackground', RGBA(0, 0, 0, 0),
		'DisabledBorderColor', RGBA(0, 0, 0, 0),
		'AnchorType', "bottom",
	}, {
		PlaceObj('XTemplateWindow', {
			'Dock', "left",
			'MinWidth', 140,
			'MaxWidth', 140,
		}, {
			PlaceObj('XTemplateWindow', {
				'__class', "XFrame",
				'Dock', "box",
				'Image', "UI/PDA/os_background",
				'FrameBox', box(5, 5, 5, 5),
			}),
			PlaceObj('XTemplateWindow', {
				'Margins', box(15, 15, 15, 15),
				'LayoutMethod', "VList",
			}, {
				PlaceObj('XTemplateWindow', {
					'LayoutMethod', "VList",
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Transparency', 163,
						'HandleMouse', false,
						'TextStyle', "PDAQuests_MenuItem",
						'Translate', true,
						'Text', T(871704585246, --[[XTemplate PDAQuests_DropDownMenu Text]] "New..."),
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Transparency', 163,
						'HandleMouse', false,
						'TextStyle', "PDAQuests_MenuItem",
						'Translate', true,
						'Text', T(682791759393, --[[XTemplate PDAQuests_DropDownMenu Text]] "Open..."),
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Transparency', 163,
						'HandleMouse', false,
						'TextStyle', "PDAQuests_MenuItem",
						'Translate', true,
						'Text', T(434705272551, --[[XTemplate PDAQuests_DropDownMenu Text]] "Save As"),
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Transparency', 163,
						'HandleMouse', false,
						'TextStyle', "PDAQuests_MenuItem",
						'Translate', true,
						'Text', T(263883108911, --[[XTemplate PDAQuests_DropDownMenu Text]] "Export"),
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "vertical sep",
					'__class', "XFrame",
					'Margins', box(0, 10, 0, 10),
					'Image', "UI/PDA/separate_line_vertical",
					'FrameBox', box(3, 3, 3, 3),
					'SqueezeY', false,
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XTextButton",
					'Background', RGBA(0, 0, 0, 0),
					'MouseCursor', "UI/Cursors/Pda_Hand.tga",
					'FocusedBorderColor', RGBA(0, 0, 0, 0),
					'FocusedBackground', RGBA(0, 0, 0, 0),
					'DisabledBorderColor', RGBA(0, 0, 0, 0),
					'OnPress', function (self, gamepad)
						InvokeShortcutAction(self, "PDACloseOrBackTab", GetActionsHost(self, true))
					end,
					'RolloverBackground', RGBA(0, 0, 0, 0),
					'PressedBackground', RGBA(0, 0, 0, 0),
					'TextStyle', "PDAQuests_MenuItem",
					'Translate', true,
					'Text', T(922133949816, --[[XTemplate PDAQuests_DropDownMenu Text]] "Exit"),
				}),
				}),
			}),
		PlaceObj('XTemplateFunc', {
			'name', "OnMouseButtonDown(self, pos, button)",
			'func', function (self, pos, button)
				if not self:PointInWindow(pos) then
					self:Close()
				end
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnCaptureLost(self)",
			'func', function (self)
				if true then return end
				
				if self.window_state ~= "destroying" then
					self:Close()
				end
			end,
		}),
		}),
})

