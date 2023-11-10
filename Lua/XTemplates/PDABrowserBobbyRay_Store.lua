-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XDialog",
	group = "BobbyRayGunsShop",
	id = "PDABrowserBobbyRay_Store",
	PlaceObj('XTemplateWindow', {
		'comment', "Full page",
		'__context', function (parent, context)
			return context
		end,
		'__class', "XDialog",
		'Id', "PDABrowserBobbyRay_Store",
		'LayoutMethod', "VList",
		'HandleMouse', true,
		'MouseCursor', "UI/Cursors/Pda_Cursor.tga",
	}, {
		PlaceObj('XTemplateFunc', {
			'name', "Open(self,...)",
			'func', function (self,...)
				PDABrowserTabState["bobby_ray_shop"].mode_param = "store"
				PauseCampaignTime(GetUICampaignPauseReason("PDABrowserBobbyRay_Store"))
				g_BobbyRayShopOpen = true
				
				XDialog.Open(self,...)
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "OnDelete",
			'func', function (self, ...)
				BobbyRayCheckClearEmptyCartEntries()
				ResumeCampaignTime(GetUICampaignPauseReason("PDABrowserBobbyRay_Store"))
				g_BobbyRayShopOpen = false
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "SetCategory(self, category, subcategory)",
			'func', function (self, category, subcategory)
				BobbyRayShopSetCategory(category and category.id or nil, subcategory and subcategory.id or nil)
				self:ResolveId("idCategory"):OnContextUpdate({category = category, subcategory = subcategory})
				ObjModified(g_BobbyRayStore)
				ObjModified("pda_url")
			end,
		}),
		PlaceObj('XTemplateFunc', {
			'name', "CycleCategory(self, next_or_prev)",
			'func', function (self, next_or_prev)
				local categoryId, subcategoryId = BobbyRayShopGetActiveCategoryPair()
				local category = BobbyRayShopGetCategory(categoryId)
				local subcategory = BobbyRayShopGetSubCategory(subcategoryId)
				local categories = Presets["BobbyRayShopCategory"].Default
				for index, cat in ipairs(categories) do
					if category == cat then
						local nextIndex = (index) 
						if next_or_prev == "next" then 
							nextIndex = nextIndex % #categories +1
						elseif next_or_prev == "prev" then
							nextIndex = (nextIndex - 1 + #categories - 1) % #categories + 1
						end
						self:SetCategory(categories[nextIndex])
					end
				end
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idActionOrder",
			'ActionGamepad', "RightShoulder",
			'OnAction', function (self, host, source, ...)
				GetPDABrowserDialog():SetMode("bobby_ray_shop", "cart")
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idNextCategory",
			'ActionGamepad', "DPadRight",
			'OnAction', function (self, host, source, ...)
				host.CycleCategory(host, "next")
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idPrevCategory",
			'ActionGamepad', "DPadLeft",
			'OnAction', function (self, host, source, ...)
				host.CycleCategory(host, "prev")
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "Background",
			'__class', "XImage",
			'Dock', "box",
			'Image', "UI/PDA/WEBSites/bobby_rays_background",
			'ImageFit', "stretch",
		}),
		PlaceObj('XTemplateWindow', {
			'comment', "PageSpecific",
			'__class', "XImage",
			'IdNode', false,
			'Dock', "box",
			'HAlign', "center",
			'VAlign', "center",
			'Image', "UI/PDA/WEBSites/Bobby Rays/shop_background",
			'ImageScale', point(1015, 1015),
		}, {
			PlaceObj('XTemplateWindow', {
				'HAlign', "center",
				'VAlign', "top",
				'MinWidth', 1035,
				'MaxWidth', 1045,
				'Background', RGBA(187, 0, 255, 0),
			}, {
				PlaceObj('XTemplateWindow', {
					'comment', "Top",
					'Margins', box(0, 25, 0, 0),
					'Padding', box(0, 1, 0, 1),
					'Dock', "top",
					'VAlign', "top",
					'MinHeight', 25,
					'Background', RGBA(61, 255, 0, 0),
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XImage",
						'Dock', "left",
						'HandleMouse', true,
						'FXMouseIn', "buttonRollover",
						'FXPress', "buttonPress",
						'Image', "UI/PDA/WEBSites/Bobby Rays/logo_small",
					}, {
						PlaceObj('XTemplateFunc', {
							'name', "OnMouseButtonDown(self, pos, button)",
							'func', function (self, pos, button)
								if button == "L" then
									GetPDABrowserDialog():SetMode("bobby_ray_shop", "front")
									PlayFX("buttonPress", "start")
								end
							end,
						}),
						}),
					PlaceObj('XTemplateWindow', {
						'__class', "XText",
						'Id', "idCategory",
						'Margins', box(10, 0, 0, 5),
						'Padding', box(0, 0, 0, 0),
						'HAlign', "left",
						'MinWidth', 300,
						'MaxWidth', 350,
						'Clip', false,
						'TextStyle', "PDABobbyStore_HG24E_Glow",
						'ContextUpdateOnOpen', true,
						'OnContextUpdate', function (self, context, ...)
							local categoryId, subcategoryId = BobbyRayShopGetActiveCategoryPair()
							local category = BobbyRayShopGetCategory(categoryId)
							local subcategory = BobbyRayShopGetSubCategory(subcategoryId)
							
							local txt = category.DisplayName .. (subcategory and " - " .. subcategory.DisplayName or "")
							self:SetText(txt)
							XText.OnContextUpdate(self, context, ...)
						end,
						'Translate', true,
						'Shorten', true,
						'TextVAlign', "bottom",
					}),
					PlaceObj('XTemplateWindow', {
						'__context', function (parent, context) return "GamepadUIStyleChanged" end,
						'__class', "XText",
						'Id', "idHelp",
						'Margins', box(0, 0, 20, 7),
						'Padding', box(0, 0, 0, 0),
						'HAlign', "right",
						'MinWidth', 475,
						'MaxWidth', 475,
						'MaxHeight', 20,
						'Clip', false,
						'TextStyle', "PDABobbyStore_HG16E_Glow",
						'ContextUpdateOnOpen', true,
						'OnContextUpdate', function (self, context, ...)
							self:SetText(GetUIStyleGamepad() and T(523505290332, "<GamepadShortcutName('ButtonA')>/<GamepadShortcutName('ButtonX')> Add/remove items\t<GamepadShortcutName('DPadLeft')>/<GamepadShortcutName('DPadRight')> Change category") or T(161204556213, "Click to add an item, right-click to remove it."))
						end,
						'Translate', true,
						'Shorten', true,
						'TextHAlign', "right",
						'TextVAlign', "bottom",
					}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "PageContent",
					'__context', function (parent, context) return g_BobbyRayStore end,
					'VAlign', "top",
					'MinHeight', 728,
					'MaxHeight', 728,
					'OnLayoutComplete', function (self)  end,
					'Background', RGBA(255, 0, 0, 0),
					'HandleKeyboard', false,
				}, {
					PlaceObj('XTemplateWindow', nil, {
						PlaceObj('XTemplateWindow', {
							'comment', "left content",
							'__context', function (parent, context) return g_BobbyRayStore end,
							'__class', "SnappingScrollArea",
							'Id', "idSectorList",
							'BorderWidth', 0,
							'Padding', box(0, 0, 0, 0),
							'MinHeight', 728,
							'MaxHeight', 728,
							'OnLayoutComplete', function (self)
								local bbox = box()
								for idx = 1, 7 do
									local child = self[idx]
									bbox:InplaceExtend(child.box)
								end
								local x, y = self.parent.box:minxyz()
								local w, h = bbox:sizexyz()
								self.InvalidateLayout = empty_func
								self:SetBox(x, y, w, h, "dont-move")
								self.InvalidateLayout = SnappingScrollArea.InvalidateLayout
								
								local scroll = self:ResolveId("idSectorScroll")
								local x, y = scroll.box:minxyz()
								local w, h = scroll.box:sizexyz()
								scroll.InvalidateLayout = empty_func
								scroll:SetBox(x, y, w, bbox:sizey(), "dont-move")
								scroll.InvalidateLayout = MessengerScrollbar_Gold.InvalidateLayout
								scroll.layout_update = true
								scroll:UpdateLayout()
								
								--fixup frames
								local x, y = self.parent.box:minxyz()
								local w, h = bbox:sizexyz()
								self:ResolveId("idFixupFrameRight"):SetBox(x,y,w,h)
								self:ResolveId("idFixupFrameTop"):SetBox(x,y,w,h)
								
								local cur_w, cur_h = GetResolution()
								if self.prev_w ~= cur_w or self.prev_h ~= cur_h then
									scroll:ScrollTo(0)
								end
								self.prev_w, self.prev_h = GetResolution()
								
								SnappingScrollArea.OnLayoutComplete(self)
							end,
							'LayoutVSpacing', -7,
							'Clip', false,
							'VScroll', "idSectorScroll",
							'OnContextUpdate', function (self, context, ...)
								if self.RespawnOnContext then
									if self.window_state == "open" then
										self:RespawnContent()
									end
								else
									local respawn_value = self:RespawnExpression(context)
									if rawget(self, "respawn_value") ~= respawn_value then
										self.respawn_value = respawn_value
										if self.window_state == "open" then
											self:RespawnContent()
										end
									end
								end
							end,
						}, {
							PlaceObj('XTemplateForEach', {
								'array', function (parent, context) return BobbyRayStoreToArray(BobbyRayShopGetActiveCategoryPair()) end,
								'item_in_context', "store_entry",
								'__context', function (parent, context, item, i, n) return item end,
								'run_after', function (child, context, item, i, n, last)
									
								end,
							}, {
								PlaceObj('XTemplateTemplate', {
									'__template', "PDABrowserBobbyRay_StoreEntry",
									'MinHeight', 110,
									'MaxHeight', 110,
								}),
								}),
							}),
						PlaceObj('XTemplateWindow', {
							'__class', "MessengerScrollbar_Gold",
							'Id', "idSectorScroll",
							'Dock', "right",
							'MinWidth', 14,
							'FoldWhenHidden', false,
							'Background', RGBA(55, 49, 33, 255),
							'Target', "idSectorList",
							'AutoHide', true,
							'UnscaledWidth', 16,
						}),
						PlaceObj('XTemplateWindow', {
							'comment', "overlay on the right to get around visual artifacts",
							'__class', "XFrame",
							'Id', "idFixupFrameRight",
							'ZOrder', 5,
							'UseClipBox', false,
							'Image', "UI/PDA/WEBSites/Bobby Rays/frame_right_line.png",
							'FrameBox', box(0, 7, 7, 7),
						}),
						PlaceObj('XTemplateWindow', {
							'comment', "overlay at the top to get around visual artifacts",
							'__class', "XFrame",
							'Id', "idFixupFrameTop",
							'ZOrder', 5,
							'Image', "UI/PDA/WEBSites/Bobby Rays/frame_top_line.png",
							'FrameBox', box(7, 7, 7, 0),
						}),
						}),
					}),
				PlaceObj('XTemplateWindow', {
					'comment', "Bottom",
					'Padding', box(0, 9, 0, 0),
					'Dock', "bottom",
					'Background', RGBA(255, 107, 0, 0),
					'HandleMouse', true,
				}, {
					PlaceObj('XTemplateWindow', {
						'__context', function (parent, context) return "Weapons" end,
						'__class', "PDABobbyRayPopupButtonClass",
						'Id', "idButtonGuns",
						'Margins', box(0, 0, 20, 0),
						'Dock', "left",
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 144,
						'LayoutMethod', "Box",
						'DisabledBackground', RGBA(255, 255, 255, 223),
						'Image', "UI/PDA/WEBSites/Bobby Rays/shop_button.png",
						'FrameBox', box(9, 9, 9, 9),
						'Columns', 4,
						'SqueezeY', true,
						'TextStyle', "PDABobbyStore_SCP_16MB_Shadow",
						'Translate', true,
						'Text', T(781021562120, --[[XTemplate PDABrowserBobbyRay_Store Text]] "Weapons"),
						'ColumnsUse', "abccd",
					}),
					PlaceObj('XTemplateWindow', {
						'__context', function (parent, context) return "Ammo" end,
						'__class', "PDABobbyRayPopupButtonClass",
						'Id', "idButtonAmmo",
						'Margins', box(0, 0, 20, 0),
						'Dock', "left",
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 144,
						'LayoutMethod', "Box",
						'DisabledBackground', RGBA(255, 255, 255, 223),
						'Image', "UI/PDA/WEBSites/Bobby Rays/shop_button.png",
						'FrameBox', box(9, 9, 9, 9),
						'Columns', 4,
						'SqueezeY', true,
						'TextStyle', "PDABobbyStore_SCP_16MB_Shadow",
						'Translate', true,
						'Text', T(214569962652, --[[XTemplate PDABrowserBobbyRay_Store Text]] "Ammo"),
						'ColumnsUse', "abccd",
					}),
					PlaceObj('XTemplateWindow', {
						'__context', function (parent, context) return "Armor" end,
						'__class', "PDABobbyRayPopupButtonClass",
						'Id', "idButtonArmor",
						'Margins', box(0, 0, 20, 0),
						'Dock', "left",
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 144,
						'LayoutMethod', "Box",
						'DisabledBackground', RGBA(255, 255, 255, 223),
						'Image', "UI/PDA/WEBSites/Bobby Rays/shop_button.png",
						'FrameBox', box(9, 9, 9, 9),
						'Columns', 4,
						'SqueezeY', true,
						'TextStyle', "PDABobbyStore_SCP_16MB_Shadow",
						'Translate', true,
						'Text', T(828595945164, --[[XTemplate PDABrowserBobbyRay_Store Text]] "Armor"),
						'ColumnsUse', "abccd",
					}),
					PlaceObj('XTemplateWindow', {
						'__context', function (parent, context) return "Other" end,
						'__class', "PDABobbyRayPopupButtonClass",
						'Id', "idButtonOther",
						'Margins', box(0, 0, 20, 0),
						'Dock', "left",
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 144,
						'LayoutMethod', "Box",
						'DisabledBackground', RGBA(255, 255, 255, 223),
						'Image', "UI/PDA/WEBSites/Bobby Rays/shop_button.png",
						'FrameBox', box(9, 9, 9, 9),
						'Columns', 4,
						'SqueezeY', true,
						'TextStyle', "PDABobbyStore_SCP_16MB_Shadow",
						'Translate', true,
						'Text', T(653962679020, --[[XTemplate PDABrowserBobbyRay_Store Text]] "Other"),
						'ColumnsUse', "abccd",
					}),
					PlaceObj('XTemplateWindow', {
						'__class', "PDACommonButtonClass",
						'Id', "idButtonOrder",
						'Margins', box(0, 0, 20, 0),
						'Dock', "right",
						'HAlign', "center",
						'VAlign', "center",
						'MinWidth', 144,
						'MinHeight', 32,
						'MaxHeight', 32,
						'LayoutMethod', "Box",
						'DisabledBackground', RGBA(255, 255, 255, 223),
						'OnPressEffect', "action",
						'OnPressParam', "idActionOrder",
						'Image', "UI/PDA/WEBSites/Bobby Rays/shop_button.png",
						'FrameBox', box(9, 9, 9, 9),
						'Columns', 4,
						'SqueezeY', true,
						'TextStyle', "PDABobbyStore_SCP_18MB",
						'Translate', true,
						'Text', T(959495600025, --[[XTemplate PDABrowserBobbyRay_Store Text]] "ORDER FORM"),
						'ColumnsUse', "abccd",
					}, {
						PlaceObj('XTemplateCode', {
							'run', function (self, parent, context)
								local host = GetActionsHost(parent, true)
								if parent.OnPressEffect == "action" then
									local value = parent.OnPressParam
									parent.action = host and host:ActionById(value) or nil
									if not parent.action then
										parent.action = XShortcutsTarget:ActionById(value) or nil
									end
								end
							end,
						}),
						}),
					PlaceObj('XTemplateWindow', {
						'__context', function (parent, context) return g_BobbyRayCart end,
						'__class', "XText",
						'Id', "idTextCart",
						'ZOrder', 5,
						'Margins', box(0, 0, 10, 0),
						'Dock', "right",
						'MinWidth', 10,
						'MinHeight', 10,
						'Clip', false,
						'FoldWhenHidden', true,
						'TextStyle', "PDABobbyStore_HG18E",
						'OnContextUpdate', function (self, context, ...)
							local cart_count, cart_cost = BobbyRayCartGetAggregate()
							local delivery_cost = BobbyRayCartGetDeliveryOption().Price
							local units_cost = cart_cost - delivery_cost
							self:SetText(T{506356054484, "CART: <Amount> / <money(Cost)>", Amount = cart_count, Cost = cart_cost})
							XText.OnContextUpdate(self, context, ...)
						end,
						'Translate', true,
					}),
					}),
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
				'HAlign', "center",
				'LayoutMethod', "HList",
				'LayoutHSpacing', 10,
			}, {
				PlaceObj('XTemplateWindow', {
					'__context', function (parent, context) return "g_BobbyRayShop_UnlockedTier" end,
					'__class', "XTextButton",
					'HAlign', "left",
					'MinWidth', 25,
					'MinHeight', 25,
					'MaxWidth', 25,
					'MaxHeight', 25,
					'OnContextUpdate', function (self, context, ...)
						self:SetEnabled(BobbyRayShopGetUnlockedTier()  > 1)
					end,
					'DisabledBackground', RGBA(185, 185, 185, 205),
					'OnPress', function (self, gamepad)
						NetSyncEvent("Cheat_BobbyRaySetTier", Max(1, BobbyRayShopGetUnlockedTier() - 1))
					end,
					'Image', "UI/PDA/os_system_buttons_yellow.png",
					'FrameBox', box(8, 8, 8, 8),
					'Columns', 3,
					'Text', "-",
					'ColumnsUse', "abcca",
				}),
				PlaceObj('XTemplateWindow', {
					'__context', function (parent, context) return "g_BobbyRayShop_UnlockedTier" end,
					'__class', "XText",
					'TextStyle', "PDABobbyStore_HG16E",
					'ContextUpdateOnOpen', true,
					'OnContextUpdate', function (self, context, ...)
						self:SetText("Tier: " .. BobbyRayShopGetUnlockedTier())
						XText.OnContextUpdate(self, context, ...)
					end,
					'TextHAlign', "center",
					'TextVAlign', "center",
				}),
				PlaceObj('XTemplateWindow', {
					'__context', function (parent, context) return "g_BobbyRayShop_UnlockedTier" end,
					'__class', "XTextButton",
					'HAlign', "right",
					'MinWidth', 25,
					'MinHeight', 25,
					'MaxWidth', 25,
					'MaxHeight', 25,
					'OnContextUpdate', function (self, context, ...)
						self:SetEnabled(BobbyRayShopGetUnlockedTier()  < 3)
					end,
					'DisabledBackground', RGBA(185, 185, 185, 205),
					'OnPress', function (self, gamepad)
						NetSyncEvent("Cheat_BobbyRaySetTier", Min(3, BobbyRayShopGetUnlockedTier() +1))
					end,
					'Image', "UI/PDA/os_system_buttons_yellow.png",
					'FrameBox', box(8, 8, 8, 8),
					'Columns', 3,
					'Text', "+",
					'ColumnsUse', "abcca",
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XTextButton",
				'Id', "idDevRestockShopButton",
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
				'Text', "Restock Shop (R)",
				'ColumnsUse', "abcca",
			}, {
				PlaceObj('XTemplateAction', {
					'comment', "restock shop",
					'ActionId', "actionRestock",
					'ActionShortcut', "R",
					'OnAction', function (self, host, source, ...)
						-- BobbyRayStoreRestock()
						-- ObjModified(g_BobbyRayStore)
						NetSyncEvent("CreateTimerBeforeAction", "restock")
					end,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XTextButton",
				'Id', "idDevConsumeShopButton",
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
				'Text', "Consume random stock (C)",
				'ColumnsUse', "abcca",
			}, {
				PlaceObj('XTemplateAction', {
					'comment', "consume random stock",
					'ActionId', "actionConsume",
					'ActionShortcut', "C",
					'OnAction', function (self, host, source, ...)
						-- BobbyRayStoreConsumeRandomStock()
						-- ObjModified(g_BobbyRayStore)
						NetSyncEvent("CreateTimerBeforeAction", "consume-stock")
					end,
				}),
				}),
			PlaceObj('XTemplateWindow', {
				'__class', "XTextButton",
				'Id', "idDevClearShopButton",
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
				'Text', "Clear Shop (D)",
				'ColumnsUse', "abcca",
			}, {
				PlaceObj('XTemplateAction', {
					'comment', "clear shop",
					'ActionId', "actionClear",
					'ActionShortcut', "D",
					'OnAction', function (self, host, source, ...)
						NetSyncEvent("CreateTimerBeforeAction", "clear-store")
					end,
				}),
				}),
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
		PlaceObj('XTemplateAction', {
			'ActionId', "idScrollUp",
			'ActionGamepad', "RightThumbUp",
			'OnAction', function (self, host, source, ...)
				local scrollbar = host:ResolveId("idSectorList")
				if not scrollbar then return end
				scrollbar:ScrollUp()
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idScrollDown",
			'ActionGamepad', "RightThumbDown",
			'OnAction', function (self, host, source, ...)
				local scrollbar = host:ResolveId("idSectorList")
				if not scrollbar then return end
				scrollbar:ScrollDown()
			end,
		}),
		}),
})
