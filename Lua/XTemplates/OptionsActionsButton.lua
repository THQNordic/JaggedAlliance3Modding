-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XWindow",
	group = "Zulu",
	id = "OptionsActionsButton",
	PlaceObj('XTemplateWindow', {
		'MinWidth', 150,
		'MinHeight', 60,
		'MaxHeight', 60,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XFrame",
			'Margins', box(5, 5, 5, 5),
			'Dock', "box",
			'Transparency', 179,
			'HandleKeyboard', false,
			'Image', "UI/Common/screen_effect",
			'TileFrame', true,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XFrame",
			'Dock', "box",
			'Transparency', 64,
			'HandleKeyboard', false,
			'Image', "UI/Common/mm_panel",
			'FrameBox', box(10, 10, 10, 10),
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XFrame",
			'UIEffectModifierId', "MainMenuHighlight",
			'Dock', "box",
			'Transparency', 255,
			'HandleKeyboard', false,
			'Image', "UI/Common/mm_panel_selected",
			'FrameBox', box(10, 10, 10, 10),
		}),
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "action-button-mm" end,
			'__class', "XTextButton",
			'Id', "idTextButton",
			'Padding', box(15, 0, 15, 0),
			'HAlign', "center",
			'VAlign', "center",
			'LayoutMethod', "Box",
			'LayoutHSpacing', 0,
			'BorderColor', RGBA(0, 0, 0, 0),
			'Background', RGBA(255, 255, 255, 0),
			'OnContextUpdate', function (self, context, ...)
				local ogText = rawget(self, "ogText")
				if not ogText then
					rawset(self, "ogText", self.Text)
					ogText = self.Text
				end
				
				local function FillText(style, shortcutText, ogText)
					local text = {}
					table.insert(text, Untranslated("<style " .. style .. ">"))
					if not GetUIStyleGamepad() then
						table.insert(text, T{775518317251, "[<name>]", name = shortcutText or ""})
					else
						table.insert(text, shortcutText)
					end
					table.insert(text, Untranslated(" </style>"))
					table.insert(text, T{629765447024, "<name>", name = ogText})
					return table.concat(text)
				end
				
				local text = ""
				local shortcutText = GetShortcutButtonT(self.action)
				
				if self.enabled then
					if self.rollover then
						text = FillText("OptionsActionButtonRollover", shortcutText, ogText)
					else
						text = FillText("OptionsActionShortcut", shortcutText, ogText)
					end
				else
					text = FillText("OptionsActionShortcutOff", shortcutText, ogText)
				end
				self:SetText(text)
			end,
			'FXMouseIn', "buttonRollover",
			'FXPress', "buttonPressGeneric",
			'FXPressDisabled', "IactDisabled",
			'FocusedBorderColor', RGBA(0, 0, 0, 0),
			'FocusedBackground', RGBA(255, 255, 255, 0),
			'DisabledBorderColor', RGBA(0, 0, 0, 0),
			'OnPress', function (self, gamepad)
				local effect = self.OnPressEffect
				if effect == "close" then
					local win = self.parent
					while win and not win:IsKindOf("XDialog") do
						win = win.parent
					end
					if win then
						win:Close(self.OnPressParam ~= "" and self.OnPressParam or nil)
					end
				elseif self.action then
					local host = GetActionsHost(self, true)
					if host then
						self:OnSetRollover(false)
						host:OnAction(self.action, self, gamepad)
					end
				end
			end,
			'RolloverBackground', RGBA(255, 255, 255, 0),
			'PressedBackground', RGBA(255, 255, 255, 0),
			'TextStyle', "OptionsActionButton",
			'Translate', true,
			'UseXTextControl', true,
		}, {
			PlaceObj('XTemplateFunc', {
				'name', "OnSetRollover(self, rollover)",
				'func', function (self, rollover)
					if self.enabled then
						if rollover then 
							PlayFX("MainMenuButtonRollover") 
							self.parent[3]:SetTransparency(0, 150)
							self.idLabel:SetRollover(rollover)
						else
							self.parent[3]:SetTransparency(255, 150)
						end
						self:OnContextUpdate(self.context)
					end
				end,
			}),
			}),
		}),
})

