-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XDialog",
	group = "Zulu PDA",
	id = "PDABrowserAskThieves",
	PlaceObj('XTemplateWindow', {
		'comment', "Full page",
		'__class', "XDialog",
		'Id', "PDABrowserAskThieves",
		'LayoutMethod', "VList",
		'MouseCursor', "UI/Cursors/Pda_Cursor.tga",
	}, {
		PlaceObj('XTemplateFunc', {
			'name', "Open",
			'func', function (self, ...)
				AddPageToBrowserHistory("banner_page", "PDABrowserAskThieves")
				PDABrowserTabState["banner_page"].mode_param = "PDABrowserAskThieves"
				
				XDialog.Open(self,...)
				if not GetUIStyleGamepad() then
					local textEditor = self:ResolveId("PageContent"):ResolveId("WriteAQuestion")
					textEditor:SetFocus(true)
				end
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "Background",
			'__class', "XImage",
			'Dock', "box",
			'Image', "UI/PDA/browser_panel",
			'ImageFit', "largest",
		}),
		PlaceObj('XTemplateTemplate', {
			'__condition', function (parent, context) return not InitialConflictNotStarted() end,
			'__template', "PDAStartButton",
			'Dock', "box",
			'VAlign', "bottom",
			'MinWidth', 200,
		}, {
			PlaceObj('XTemplateFunc', {
				'name', "SetOutsideScale(self, scale)",
				'func', function (self, scale)
					local dlg = GetDialog("PDADialog")
					local screen = dlg.idPDAScreen
					XWindow.SetOutsideScale(self, screen.scale)
				end,
			}),
			}),
		PlaceObj('XTemplateTemplate', {
			'__template', "PDABrowserBanners",
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "PageSpecific",
			'Dock', "box",
			'HAlign', "center",
			'VAlign', "center",
			'MinWidth', 1076,
			'MaxWidth', 1076,
			'LayoutMethod', "VList",
		}, {
			PlaceObj('XTemplateWindow', {
				'comment', "PageContent",
				'__class', "XImage",
				'Id', "PageContent",
				'HAlign', "center",
				'VAlign', "center",
				'MinWidth', 1112,
				'MaxWidth', 1112,
				'MaxHeight', 690,
				'Background', RGBA(177, 22, 14, 0),
				'Image', "UI/PDA/WEBSites/ask_thieves_site",
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "Title",
					'Margins', box(300, -400, 0, 0),
					'HAlign', "center",
					'VAlign', "center",
					'MinWidth', 487,
					'MinHeight', 75,
					'MaxWidth', 487,
					'MaxHeight', 75,
					'LayoutHSpacing', 125,
					'Background', RGBA(0, 72, 130, 0),
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesTitle",
					'Translate', true,
					'Text', T(124840777951, --[[XTemplate PDABrowserAskThieves Text]] "HAVE A QUESTION?\nJUST TYPE AND CLICK ASK!"),
					'TextHAlign', "center",
					'TextVAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XButton",
					'Id', "AskButton",
					'IdNode', false,
					'Margins', box(0, 189, 70, 0),
					'HAlign', "right",
					'VAlign', "top",
					'Background', RGBA(255, 255, 255, 0),
					'MouseCursor', "UI/Cursors/Pda_Hand.tga",
					'OnPress', function (self, gamepad)
						local textEditor = self:ResolveId("WriteAQuestion")
						local currentTable = textEditor:GetTranslatedText() ~= "" and ask_thieves_texts_answers or ask_thieves_texts_answers_empty
						self:ResolveId("AnswerContent"):SetText(table.rand(currentTable))
						textEditor:SetFocus(false)
					end,
					'RolloverBackground', RGBA(255, 255, 255, 0),
					'PressedBackground', RGBA(255, 255, 255, 0),
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XImage",
						'Image', "UI/PDA/WEBSites/ask_thieves_button",
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "Write a question",
					'__class', "XTextEditor",
					'Id', "WriteAQuestion",
					'Margins', box(444, 196, 0, 0),
					'Padding', box(0, 0, 0, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 487,
					'MinHeight', 40,
					'MaxWidth', 487,
					'MaxHeight', 40,
					'BorderColor', RGBA(128, 128, 128, 0),
					'Background', RGBA(255, 255, 255, 0),
					'MouseCursor', "UI/Cursors/Pda_Hand.tga",
					'FocusedBorderColor', RGBA(0, 0, 0, 0),
					'FocusedBackground', RGBA(255, 255, 255, 0),
					'DisabledBorderColor', RGBA(128, 128, 128, 0),
					'TextStyle', "PDABrowserThievesQuestionTyping",
					'Translate', true,
					'Multiline', false,
					'WordWrap', false,
					'AutoSelectAll', true,
					'NewLine', "",
					'Hint', T(809328630187, --[[XTemplate PDABrowserAskThieves Hint]] "Write a question"),
					'HintColor', RGBA(195, 189, 172, 255),
					'HintVAlign', "top",
				}, {
					PlaceObj('XTemplateFunc', {
						'name', "OnTextChanged(self)",
						'func', function (self)
							PlayFX("Typing", "start")
						end,
					}),
					PlaceObj('XTemplateFunc', {
						'name', "OnSetFocus(self, old_focus)",
						'func', function (self, old_focus)
							if GetUIStyleGamepad() then
								self:OpenControllerTextInput()
								self:SetFocus(false)
							else
								XTextEditor.OnSetFocus(self, old_focus)
							end
						end,
					}),
					PlaceObj('XTemplateFunc', {
						'name', "OnMouseButtonDoubleClick(self, pos, button)",
						'func', function (self, pos, button)
							if GetUIStyleGamepad() then return "break" end
						end,
					}),
					PlaceObj('XTemplateFunc', {
						'name', "OnShortcut(self, shortcut, source, ...)",
						'func', function (self, shortcut, source, ...)
							if GetUIStyleGamepad() then return "break" end
							if shortcut == "Enter" then
								self:SetFocus(false)
								self:ResolveId("AskButton"):OnPress()
								return "break"
							else
								return XTextEditor.OnShortcut(self, shortcut, source)
							end
						end,
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "AnswerPrompt",
					'Margins', box(440, 240, 0, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 498,
					'MinHeight', 20,
					'MaxWidth', 498,
					'LayoutHSpacing', 125,
					'Background', RGBA(0, 72, 130, 0),
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesAnswerPrompt",
					'Translate', true,
					'Text', T(178201377576, --[[XTemplate PDABrowserAskThieves Text]] "Get an answer!"),
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "AnswerContent",
					'Margins', box(445, 276, 0, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 487,
					'MinHeight', 117,
					'MaxWidth', 487,
					'LayoutHSpacing', 125,
					'Background', RGBA(0, 72, 130, 0),
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesQuestionDefault",
					'Translate', true,
				}),
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'Id', "Box title",
					'Margins', box(445, 440, 0, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 487,
					'MinHeight', 20,
					'MaxWidth', 487,
					'LayoutHSpacing', 125,
					'Background', RGBA(0, 72, 130, 0),
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesBox",
					'Translate', true,
					'Text', T(572561425367, --[[XTemplate PDABrowserAskThieves Text]] "Explore more <style PDABrowserThievesBoxBold>areas of interest</style>?"),
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "Areas of interest content",
					'Margins', box(450, 475, 0, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 475,
					'MinHeight', 98,
					'LayoutMethod', "HList",
					'LayoutHSpacing', 6,
					'Background', RGBA(0, 72, 130, 0),
				}, {
					PlaceObj('XTemplateWindow', {
						'MinWidth', 235,
						'LayoutMethod', "VPanel",
						'Background', RGBA(220, 140, 28, 0),
					}, {
						PlaceObj('XTemplateWindow', {
							'__class', "XText",
							'Margins', box(0, 3, 0, 0),
							'HAlign', "left",
							'VAlign', "top",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'TextStyle', "PDABrowserThievesBoxLinksDisabled",
							'Translate', true,
							'Text', T(180356529226, --[[XTemplate PDABrowserAskThieves Text]] "<underline>Business</underline> (896)"),
						}),
						PlaceObj('XTemplateTemplate', {
							'__context', function (parent, context)
								return context
							end,
							'__template', "PDABrowserAskThievesBoxLink",
							'HyperlinkLinkId', "ThievesComputersLink",
							'HyperlinkText', T(605713314989, --[[XTemplate PDABrowserAskThieves HyperlinkText]] "<underline>Computers</underline> <style PDABrowserThievesBoxLinksSuffix>(3096)</style>"),
						}),
						PlaceObj('XTemplateTemplate', {
							'__context', function (parent, context)
								return context
							end,
							'__template', "PDABrowserAskThievesBoxLink",
							'HyperlinkLinkId', "ThievesGamesLink",
							'HyperlinkText', T(502538049457, --[[XTemplate PDABrowserAskThieves HyperlinkText]] "<underline>Games</underline> <style PDABrowserThievesBoxLinksSuffix>(108)</style>"),
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XText",
							'Margins', box(0, 3, 0, 0),
							'HAlign', "left",
							'VAlign', "top",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'TextStyle', "PDABrowserThievesBoxLinksDisabled",
							'Translate', true,
							'Text', T(995076551536, --[[XTemplate PDABrowserAskThieves Text]] "<underline>Work</underline> (340)"),
						}),
						}),
					PlaceObj('XTemplateWindow', {
						'MinWidth', 235,
						'LayoutMethod', "VList",
						'Background', RGBA(120, 200, 43, 0),
					}, {
						PlaceObj('XTemplateWindow', {
							'__class', "XText",
							'Margins', box(0, 3, 0, 0),
							'HAlign', "left",
							'VAlign', "top",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'TextStyle', "PDABrowserThievesBoxLinksDisabled",
							'Translate', true,
							'Text', T(415824612147, --[[XTemplate PDABrowserAskThieves Text]] "<underline>Health</underline> (670)"),
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XText",
							'Margins', box(0, 3, 0, 0),
							'HAlign', "left",
							'VAlign', "top",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'TextStyle', "PDABrowserThievesBoxLinksDisabled",
							'Translate', true,
							'Text', T(491335398252, --[[XTemplate PDABrowserAskThieves Text]] "<underline>Sports</underline> (95)"),
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XText",
							'Margins', box(0, 3, 0, 0),
							'HAlign', "left",
							'VAlign', "top",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'TextStyle', "PDABrowserThievesBoxLinksDisabled",
							'Translate', true,
							'Text', T(383338167256, --[[XTemplate PDABrowserAskThieves Text]] "<underline>Travels</underline> (310)"),
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XText",
							'Margins', box(0, 3, 0, 0),
							'HAlign', "left",
							'VAlign', "top",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'TextStyle', "PDABrowserThievesBoxLinksDisabled",
							'Translate', true,
							'Text', T(388108940821, --[[XTemplate PDABrowserAskThieves Text]] "<underline>World</underline> (1405)"),
						}),
						}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "Ranking text",
					'__class', "XText",
					'Margins', box(270, 0, 0, 65),
					'HAlign', "left",
					'VAlign', "bottom",
					'MinWidth', 200,
					'MinHeight', 50,
					'MaxWidth', 165,
					'LayoutHSpacing', 125,
					'Background', RGBA(0, 130, 26, 0),
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesRanking",
					'Translate', true,
					'Text', T(425163038375, --[[XTemplate PDABrowserAskThieves Text]] "Featuring ranking \nby popularity"),
					'TextVAlign', "bottom",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "ActiveTab",
					'__class', "XText",
					'Margins', box(7, 0, 0, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 292,
					'MinHeight', 22,
					'Background', RGBA(120, 200, 43, 0),
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesHeaderMain",
					'Translate', true,
					'Text', T(885670955046, --[[XTemplate PDABrowserAskThieves Text]] "ASK THIEVES HOME"),
					'TextHAlign', "center",
					'TextVAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "OtherTabs",
					'Margins', box(306, 0, 0, 0),
					'Padding', box(30, 0, 30, 0),
					'HAlign', "left",
					'VAlign', "top",
					'MinWidth', 763,
					'MinHeight', 21,
					'LayoutMethod', "HOverlappingList",
					'FillOverlappingSpace', true,
					'HandleKeyboard', false,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'Background', RGBA(120, 200, 43, 0),
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesHeaderOther",
						'Translate', true,
						'Text', T(257431971244, --[[XTemplate PDABrowserAskThieves Text]] "PERSONAL SEARCH"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesHeaderOther",
						'Translate', true,
						'Text', T(905625686566, --[[XTemplate PDABrowserAskThieves Text]] "SHOPPING"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesHeaderOther",
						'Translate', true,
						'Text', T(548159556523, --[[XTemplate PDABrowserAskThieves Text]] "TESTS"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesHeaderOther",
						'Translate', true,
						'Text', T(191297597823, --[[XTemplate PDABrowserAskThieves Text]] "QUESTIONS"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'Background', RGBA(120, 200, 43, 0),
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesHeaderOther",
						'Translate', true,
						'Text', T(235721423846, --[[XTemplate PDABrowserAskThieves Text]] "HELP"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "Footer",
					'Margins', box(8, 0, 0, 2),
					'Padding', box(50, 0, 50, 0),
					'HAlign', "left",
					'VAlign', "bottom",
					'MinWidth', 1061,
					'MinHeight', 25,
					'MaxWidth', 1061,
					'LayoutMethod', "HOverlappingList",
					'FillOverlappingSpace', true,
					'Background', RGBA(220, 140, 28, 0),
					'HandleKeyboard', false,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'Background', RGBA(120, 200, 43, 0),
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesFooter",
						'Translate', true,
						'Text', T(526573597364, --[[XTemplate PDABrowserAskThieves Text]] "MORE THIEVES"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesFooter",
						'Translate', true,
						'Text', T(599365095640, --[[XTemplate PDABrowserAskThieves Text]] "BUSINESS SOLUTIONS"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesFooter",
						'Translate', true,
						'Text', T(159694528507, --[[XTemplate PDABrowserAskThieves Text]] "ADVERTISING"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesFooter",
						'Translate', true,
						'Text', T(765921811814, --[[XTemplate PDABrowserAskThieves Text]] "INVESTOR RELATIONS"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'VAlign', "center",
						'Background', RGBA(120, 200, 43, 0),
						'HandleKeyboard', false,
						'HandleMouse', false,
						'TextStyle', "PDABrowserThievesFooter",
						'Translate', true,
						'Text', T(457627058079, --[[XTemplate PDABrowserAskThieves Text]] "ABOUT"),
						'TextHAlign', "center",
						'TextVAlign', "center",
					}),
					}),
				}),
			PlaceObj('XTemplateWindow', {
				'comment', "PagePrivacyLinks",
				'Margins', box(0, 10, 0, 0),
				'VAlign', "center",
				'LayoutMethod', "VList",
				'HandleKeyboard', false,
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABrowserThievesCopyright",
					'Translate', true,
					'Text', T(433250920776, --[[XTemplate PDABrowserAskThieves Text]] "Additional Guidelines for Answers\nPrivacy Statement\n1992-2001 Ask Thieves, Inc.\nASK THIEVES, ASK.ORG and the THIEVES DESIGN are services of Ask Thieves, Inc.\nAll other brands are property of their respective owners."),
				}),
				}),
			}),
		}),
})

