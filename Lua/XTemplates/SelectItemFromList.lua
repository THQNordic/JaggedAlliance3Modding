-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	group = "Zulu",
	id = "SelectItemFromList",
	PlaceObj('XTemplateWindow', {
		'__class', "XDialog",
		'Margins', box(0, 10, 0, 0),
		'HAlign', "left",
		'VAlign', "top",
	}, {
		PlaceObj('XTemplateFunc', {
			'name', "Open",
			'func', function (self, ...)
				XDialog.Open(self, ...)
				self:SetModal(true)
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XContextWindow",
			'LayoutMethod', "VList",
			'LayoutVSpacing', 10,
			'Background', RGBA(0, 0, 0, 100),
		}, {
			PlaceObj('XTemplateForEach', {
				'item_in_context', "item_id",
				'run_after', function (child, context, item, i, n, last)
					child:SetContext(context[i])
					child.idLabel:SetContext(context[i])
				end,
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XTextButton",
					'BorderWidth', 1,
					'OnPress', function (self, gamepad)
						self:ResolveId("node"):delete(self.context.id)
					end,
					'RolloverBackground', RGBA(38, 11, 241, 185),
					'RolloverBorderColor', RGBA(9, 8, 8, 249),
					'PressedBackground', RGBA(38, 11, 241, 185),
					'PressedBorderColor', RGBA(9, 8, 8, 249),
					'Translate', true,
					'Text', T(655829085654, --[[XTemplate SelectItemFromList Text]] "<display_name>"),
				}),
				}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "exit",
			'ActionId', "Close",
			'ActionName', T(314387364203, --[[XTemplate SelectItemFromList ActionName]] "Close"),
			'ActionShortcut', "Escape",
			'OnActionEffect', "close",
		}),
		}),
})
