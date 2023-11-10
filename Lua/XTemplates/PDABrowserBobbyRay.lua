-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XDialog",
	group = "BobbyRayGunsShop",
	id = "PDABrowserBobbyRay",
	PlaceObj('XTemplateWindow', {
		'comment', "Full page",
		'__class', "XDialog",
		'Id', "PDABrowserBobbyRay",
		'LayoutMethod', "VList",
		'MouseCursor', "UI/Cursors/Pda_Cursor.tga",
	}, {
		PlaceObj('XTemplateFunc', {
			'name', "Open",
			'func', function (self, ...)
				XDialog.Open(self, ...)
				
				AddPageToBrowserHistory("bobby_ray_shop")
				DockBrowserTab("bobby_ray_shop")
				PDABrowserTabState["bobby_ray_shop"].mode_param = "front"
				ObjModified("pda browser tabs")
				
				PauseCampaignTime(GetUICampaignPauseReason("PDABrowserBobbyRay"))
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnDelete",
			'func', function (self, ...)
				ResumeCampaignTime(GetUICampaignPauseReason("PDABrowserBobbyRay"))
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "Background",
			'__class', "XImage",
			'Dock', "box",
			'Image', "UI/PDA/WEBSites/bobby_rays_background",
			'ImageFit', "stretch",
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
				'IdNode', false,
				'HAlign', "center",
				'VAlign', "center",
				'MinWidth', 1112,
				'MaxWidth', 1112,
				'MaxHeight', 690,
				'UseClipBox', false,
				'HandleKeyboard', false,
				'Image', "UI/PDA/WEBSites/Bobby Rays/main_page_background",
			}, {
				PlaceObj('XTemplateWindow', {
					'comment', "Shop Slogan",
					'__class', "XText",
					'Margins', box(90, 282, 90, 0),
					'Padding', box(10, 10, 10, 10),
					'HAlign', "center",
					'VAlign', "top",
					'Clip', false,
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABobbyHighlight_Glow",
					'Translate', true,
					'Text', T(160762313504, --[[XTemplate PDABrowserBobbyRay Text]] "IF WE DON'T SELL IT, YOU CAN'T GET IT!"),
					'TextHAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "Shop Buttons",
					'Padding', box(33, 0, 0, 155),
					'VAlign', "bottom",
					'LayoutMethod', "HList",
					'LayoutHSpacing', 38,
					'UniformColumnWidth', true,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XTextButton",
						'HAlign', "left",
						'VAlign', "center",
						'MinWidth', 225,
						'MinHeight', 100,
						'MaxWidth', 225,
						'MaxHeight', 100,
						'LayoutMethod', "Box",
						'Background', RGBA(255, 255, 255, 0),
						'MouseCursor', "UI/Cursors/Pda_Hand.tga",
						'FXMouseIn', "buttonRollover",
						'FXPress', "buttonPress",
						'OnPress', function (self, gamepad)
							if not BobbyRayShopIsUnlocked() then 
								self:ResolveId("PDABrowserBobbyPopUp").visible = true
								return
							end
							BobbyRayShopSetCategory("Weapons")
							GetPDABrowserDialog():SetMode("bobby_ray_shop", "store")
						end,
						'RolloverBackground', RGBA(255, 255, 255, 0),
						'PressedBackground', RGBA(255, 255, 255, 0),
						'TextStyle', "PDABobbyButton",
						'Translate', true,
						'Text', T(570706532380, --[[XTemplate PDABrowserBobbyRay Text]] "Weapons"),
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XTextButton",
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 225,
						'MinHeight', 100,
						'MaxWidth', 225,
						'MaxHeight', 100,
						'LayoutMethod', "Box",
						'Background', RGBA(255, 255, 255, 0),
						'MouseCursor', "UI/Cursors/Pda_Hand.tga",
						'FXMouseIn', "buttonRollover",
						'FXPress', "buttonPress",
						'OnPress', function (self, gamepad)
							if not BobbyRayShopIsUnlocked() then 
								self:ResolveId("PDABrowserBobbyPopUp").visible = true
								return
							end
							BobbyRayShopSetCategory("Ammo")
							GetPDABrowserDialog():SetMode("bobby_ray_shop", "store")
						end,
						'RolloverBackground', RGBA(255, 255, 255, 0),
						'PressedBackground', RGBA(255, 255, 255, 0),
						'TextStyle', "PDABobbyButton",
						'Translate', true,
						'Text', T(571005091452, --[[XTemplate PDABrowserBobbyRay Text]] "AMMUNITION"),
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XTextButton",
						'HAlign', "right",
						'VAlign', "center",
						'MinWidth', 225,
						'MinHeight', 100,
						'MaxWidth', 225,
						'MaxHeight', 100,
						'LayoutMethod', "Box",
						'Background', RGBA(255, 255, 255, 0),
						'MouseCursor', "UI/Cursors/Pda_Hand.tga",
						'FXMouseIn', "buttonRollover",
						'FXPress', "buttonPress",
						'OnPress', function (self, gamepad)
							if not BobbyRayShopIsUnlocked() then 
								self:ResolveId("PDABrowserBobbyPopUp").visible = true
								return
							end
							BobbyRayShopSetCategory("Armor")
							GetPDABrowserDialog():SetMode("bobby_ray_shop", "store")
						end,
						'RolloverBackground', RGBA(255, 255, 255, 0),
						'PressedBackground', RGBA(255, 255, 255, 0),
						'TextStyle', "PDABobbyButton",
						'Translate', true,
						'Text', T(115464219882, --[[XTemplate PDABrowserBobbyRay Text]] "ARMOR"),
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "XTextButton",
						'HAlign', "right",
						'VAlign', "center",
						'MinWidth', 225,
						'MinHeight', 100,
						'MaxWidth', 225,
						'MaxHeight', 100,
						'LayoutMethod', "Box",
						'Background', RGBA(255, 255, 255, 0),
						'MouseCursor', "UI/Cursors/Pda_Hand.tga",
						'FXMouseIn', "buttonRollover",
						'FXPress', "buttonPress",
						'OnPress', function (self, gamepad)
							if not BobbyRayShopIsUnlocked() then 
								self:ResolveId("PDABrowserBobbyPopUp").visible = true
								return
							end
							BobbyRayShopSetCategory("Other")
							GetPDABrowserDialog():SetMode("bobby_ray_shop", "store")
						end,
						'RolloverBackground', RGBA(255, 255, 255, 0),
						'PressedBackground', RGBA(255, 255, 255, 0),
						'TextStyle', "PDABobbyButton",
						'Translate', true,
						'Text', T(253906787355, --[[XTemplate PDABrowserBobbyRay Text]] "OTHER"),
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "Order Text",
					'__context', function (parent, context) return "g_BobbyRayShop_UnlockedTier" end,
					'__class', "XText",
					'Margins', box(0, 0, 0, 55),
					'Padding', box(10, 10, 10, 10),
					'HAlign', "center",
					'VAlign', "bottom",
					'Clip', false,
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABobbyHighlight_Glow_Small",
					'ContextUpdateOnOpen', true,
					'OnContextUpdate', function (self, context, ...)
						if not BobbyRayShopIsUnlocked() then self:SetText("") return end
						local shipment = GetClosestShipment()
						self:SetText(shipment and T{678326606878, "Your order arrives in <GetShopTime(time)>", time = shipment.due_time - Game.CampaignTime} or T(333581904892, "No pending shipments"))
					end,
					'Translate', true,
					'TextHAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'comment', "Restock Text",
					'__context', function (parent, context) return "g_BobbyRayShop_UnlockedTier" end,
					'__condition', function (parent, context)
						return true
					end,
					'__class', "XText",
					'Margins', box(0, 0, 0, 5),
					'Padding', box(10, 10, 10, 10),
					'HAlign', "center",
					'VAlign', "bottom",
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABobbyHighlight_Glow_Small",
					'ContextUpdateOnOpen', true,
					'OnContextUpdate', function (self, context, ...)
						if BobbyRayShopIsUnlocked() and BobbyRayShopGetRestockTime() <= Game.CampaignTime then
							self:SetText(Untranslated("(DEV)No restock scheduled."))
							return
						end
						self:SetText(BobbyRayShopIsUnlocked() and T{448259107376, "Next restock in <GetShopTime(time)>", time = BobbyRayShopGetRestockTime() - Game.CampaignTime} or "")
					end,
					'Translate', true,
					'TextHAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'Id', "PDABrowserBobbyPopUp",
					'IdNode', true,
					'HAlign', "center",
					'VAlign', "center",
					'MinWidth', 1000000,
					'MinHeight', 1000000,
					'Visible', false,
					'Background', RGBA(221, 54, 54, 0),
					'HandleKeyboard', false,
					'HandleMouse', true,
				}, {
					PlaceObj('XTemplateWindow', {
						'comment', "Pop-up",
						'Padding', box(15, 15, 15, 15),
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 800,
						'MaxWidth', 800,
						'LayoutMethod', "VList",
						'Background', RGBA(0, 0, 0, 216),
						'HandleKeyboard', false,
					}, {
						PlaceObj('XTemplateWindow', {
							'comment', "Title",
							'__class', "XText",
							'HAlign', "center",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'TextStyle', "PDAActivityDescription",
							'Translate', true,
							'Text', T(150193893244, --[[XTemplate PDABrowserBobbyRay Text]] "Woah there, partner."),
							'TextHAlign', "center",
							'TextVAlign', "center",
						}),
						PlaceObj('XTemplateWindow', {
							'comment', "Body",
							'__class', "XText",
							'HandleKeyboard', false,
							'HandleMouse', false,
							'TextStyle', "PDAActivityDescription",
							'Translate', true,
							'Text', T(774539469443, --[[XTemplate PDABrowserBobbyRay Text]] "Your IP address tells us you're trying to access this website within the territory of Grand Chien. Unfortunately, this country is not yet on the list of eligible countries where we can officially conduct our business. We're still negotiating the terms and conditions with the government so that our sweet products can come to your door in the most legal way possible. We're sorry for the inconvenience, but we can't risk getting into trouble until we get all these matters sorted out."),
							'TextHAlign', "center",
							'TextVAlign', "center",
						}),
						PlaceObj('XTemplateWindow', {
							'comment', "Button",
							'__class', "XButton",
							'Id', "PDABrowserBobbyPopUpOK",
							'Background', RGBA(255, 255, 255, 0),
							'MouseCursor', "UI/Cursors/Pda_Hand.tga",
							'FXMouseIn', "buttonRollover",
							'FXPress', "buttonPress",
							'FocusedBackground', RGBA(255, 255, 255, 0),
							'OnPress', function (self, gamepad)
								self:ResolveId("node").visible = false
							end,
							'RolloverBackground', RGBA(255, 255, 255, 0),
							'PressedBackground', RGBA(255, 255, 255, 0),
						}, {
							PlaceObj('XTemplateWindow', {
								'__class', "XText",
								'TextStyle', "PDABobbyHighlight",
								'Translate', true,
								'Text', T(815940361938, --[[XTemplate PDABrowserBobbyRay Text]] "OK"),
								'TextHAlign', "center",
								'TextVAlign', "center",
							}),
							}),
						}),
					}),
				}),
			PlaceObj('XTemplateWindow', {
				'comment', "PagePrivacyLinks",
				'VAlign', "center",
				'LayoutMethod', "VList",
				'HandleKeyboard', false,
			}, {
				PlaceObj('XTemplateWindow', {
					'__class', "XText",
					'HAlign', "center",
					'HandleKeyboard', false,
					'HandleMouse', false,
					'TextStyle', "PDABobbyPrivacyLinks",
					'Translate', true,
					'Text', T(431929521689, --[[XTemplate PDABrowserBobbyRay Text]] "Privacy Policy | Copyright Bobby Ray's Guns 2001"),
					'TextHAlign', "center",
				}),
				}),
			}),
		}),
	PlaceObj('XTemplateWindow', {
		'__context', function (parent, context) return "BobbyRayShopFinishPurchaseUI" end,
		'__class', "XContextWindow",
		'Id', "idFinishOrder",
		'Dock', "box",
		'Visible', false,
		'FoldWhenHidden', true,
		'Background', RGBA(0, 0, 0, 160),
		'HandleMouse', true,
		'OnContextUpdate', function (self, context, ...)
			self:SetVisible(true)
			PlayFX("BobbyRayFinishPurchase", "start")
		end,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XImage",
			'Image', "UI/PDA/WEBSites/Bobby Rays/order_finish.png",
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnMouseButtonDown(self, pos, button)",
			'func', function (self, pos, button)
				self:SetVisible(false)
			end,
		}),
		}),
	PlaceObj('XTemplateWindow', {
		'__condition', function (parent, context) return Platform.cheats end,
		'Margins', box(50, 50, 50, 50),
		'Padding', box(25, 25, 25, 25),
		'HAlign', "left",
		'VAlign', "top",
		'MinWidth', 250,
		'LayoutMethod', "VList",
		'LayoutVSpacing', 10,
		'Background', RGBA(255, 0, 0, 118),
		'HandleMouse', true,
	}, {
		PlaceObj('XTemplateWindow', {
			'__class', "XText",
			'TextStyle', "PDABobbyHighlight",
			'Text', "Dev Actions",
			'TextHAlign', "center",
			'TextVAlign', "center",
		}),
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "g_BobbyRayShop_UnlockedTier" end,
			'__class', "XTextButton",
			'Id', "idDevLockShopButton",
			'OnContextUpdate', function (self, context, ...)
				self:SetText((BobbyRayShopIsUnlocked() and "Lock shop" or "Unlock shop"))
			end,
			'OnPressEffect', "action",
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
						host:OnAction(self.action, self, gamepad)
					end
				end
			end,
			'Image', "UI/PDA/os_system_buttons_yellow.png",
			'FrameBox', box(8, 8, 8, 8),
			'Columns', 3,
			'ColumnsUse', "abcca",
		}, {
			PlaceObj('XTemplateAction', {
				'comment', "un/lock shop",
				'ActionId', "actionLock",
				'OnAction', function (self, host, source, ...)
					NetSyncEvent("Cheat_BobbyRayToggleLock")
				end,
			}),
			}),
		}),
})

