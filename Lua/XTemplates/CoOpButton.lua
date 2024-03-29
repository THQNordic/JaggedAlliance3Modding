-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XContentTemplate",
	group = "Zulu",
	id = "CoOpButton",
	PlaceObj('XTemplateWindow', {
		'__context', function (parent, context) return "coop button" end,
		'__class', "XContentTemplate",
		'HAlign', "right",
	}, {
		PlaceObj('XTemplateTemplate', {
			'__condition', function (parent, context) return netInGame end,
			'__template', "GenericHUDButtonFrame",
			'Id', "idMPMercsFrame",
			'IdNode', false,
			'FoldWhenHidden', true,
		}, {
			PlaceObj('XTemplateWindow', {
				'__condition', function (parent, context) return #netGamePlayers<2 or not NetIsHost() end,
				'__class', "HUDButton",
				'RolloverTemplate', "SmallRolloverGeneric",
				'RolloverAnchor', "center-top",
				'Id', "idLobbyButton",
				'Padding', box(5, 0, 5, 0),
				'MinWidth', 170,
				'MaxWidth', 9999,
				'MaxHeight', 150,
				'LayoutMethod', "HList",
				'ContextUpdateOnOpen', true,
				'OnPressEffect', "action",
				'OnPressParam', "actionCoOpSetup",
			}, {
				PlaceObj('XTemplateWindow', {
					'Dock', "box",
					'VAlign', "center",
					'LayoutMethod', "VList",
					'LayoutVSpacing', 5,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Id', "idLargeText",
						'Margins', box(0, 0, 3, 0),
						'HAlign', "center",
						'VAlign', "center",
						'TextStyle', "HUDHeaderBig",
						'Translate', true,
						'Text', T(507624704706, --[[XTemplate CoOpButton Text]] "CO-OP"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__condition', function (parent, context) return netGameInfo and netGameInfo.visible_to == "public" and #netGamePlayers<2 end,
						'__class', "XText",
						'Margins', box(0, 0, 3, 0),
						'VAlign', "center",
						'FoldWhenHidden', true,
						'TextStyle', "PDASectorInfo_SectionItem",
						'Translate', true,
						'Text', T(239857228353, --[[XTemplate CoOpButton Text]] "Game is listed"),
						'HideOnEmpty', true,
						'TextHAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__condition', function (parent, context) return netGameInfo and netGameInfo.visible_to == "private" and #netGamePlayers<2 end,
						'__class', "XText",
						'Margins', box(0, 0, 3, 0),
						'VAlign', "center",
						'FoldWhenHidden', true,
						'TextStyle', "PDASectorInfo_SectionItem",
						'Translate', true,
						'Text', T(941622899988, --[[XTemplate CoOpButton Text]] "Invite Partner"),
						'HideOnEmpty', true,
						'TextHAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'comment', "controller hint",
						'__context', function (parent, context) return "GamepadUIStyleChanged" end,
						'__class', "XText",
						'Margins', box(5, 0, 0, 0),
						'HAlign', "left",
						'VAlign', "bottom",
						'ScaleModifier', point(700, 700),
						'FoldWhenHidden', true,
						'TextStyle', "HUDHeaderBig",
						'ContextUpdateOnOpen', true,
						'OnContextUpdate', function (self, context, ...)
							self:SetVisible(GetUIStyleGamepad())
							XText.OnContextUpdate(self, context, ...)
						end,
						'Translate', true,
						'Text', T(930288884930, --[[XTemplate CoOpButton Text]] "<ShortcutButton('actionCoOpSetup')>"),
					}),
					}),
				PlaceObj('XTemplateFunc', {
					'name', "OnSetRollover(self, rollover)",
					'func', function (self, rollover)
						self.idLargeText:SetTextStyle(rollover and "HUDHeaderBigLight" or "HUDHeaderBig")
						XButton.OnSetRollover(self, rollover)
					end,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__condition', function (parent, context) return #netGamePlayers>=2 and NetIsHost() end,
				'__class', "HUDButton",
				'RolloverTemplate', "SmallRolloverGeneric",
				'RolloverAnchor', "center-top",
				'Id', "idMPMercs",
				'Padding', box(5, 0, 5, 0),
				'MinWidth', 170,
				'MaxWidth', 9999,
				'MaxHeight', 150,
				'LayoutMethod', "HList",
				'ContextUpdateOnOpen', true,
				'OnPressEffect', "action",
				'OnPressParam', "actionCoOpInGame",
			}, {
				PlaceObj('XTemplateWindow', {
					'Dock', "box",
					'VAlign', "center",
					'LayoutMethod', "VList",
					'LayoutVSpacing', 5,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Id', "idLargeText",
						'HAlign', "center",
						'VAlign', "center",
						'TextStyle', "HUDHeaderBig",
						'Translate', true,
						'Text', T(507624704706, --[[XTemplate CoOpButton Text]] "CO-OP"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__condition', function (parent, context) return CountCoopUnits(2)<=0 end,
						'__class', "XText",
						'Id', "idPartnerText",
						'VAlign', "center",
						'MaxWidth', 160,
						'FoldWhenHidden', true,
						'TextStyle', "PDASectorInfo_SectionItemRed",
						'Translate', true,
						'Text', T(844121551822, --[[XTemplate CoOpButton Text]] "Partner has no mercs"),
						'HideOnEmpty', true,
						'TextHAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'comment', "controller hint",
						'__context', function (parent, context) return "GamepadUIStyleChanged" end,
						'__class', "XText",
						'Margins', box(5, 0, 0, 0),
						'HAlign', "left",
						'VAlign', "bottom",
						'ScaleModifier', point(700, 700),
						'FoldWhenHidden', true,
						'TextStyle', "HUDHeaderBig",
						'ContextUpdateOnOpen', true,
						'OnContextUpdate', function (self, context, ...)
							self:SetVisible(GetUIStyleGamepad())
							XText.OnContextUpdate(self, context, ...)
						end,
						'Translate', true,
						'Text', T(463030639704, --[[XTemplate CoOpButton Text]] "<ShortcutButton('actionCoOpInGame')>"),
					}),
					}),
				PlaceObj('XTemplateFunc', {
					'name', "OnSetRollover(self, rollover)",
					'func', function (self, rollover)
						self.idLargeText:SetTextStyle(rollover and "HUDHeaderBigLight" or "HUDHeaderBig")
						XButton.OnSetRollover(self, rollover)
					end,
				}),
				}),
			}),
		}),
})

