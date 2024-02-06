-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	group = "GedApps",
	id = "ModEditor",
	save_in = "Ged",
	PlaceObj('XTemplateWindow', {
		'__class', "GedApp",
		'Translate', true,
		'Title', "Mod Editor",
		'AppId', "ModEditor",
		'InitialWidth', 1100,
	}, {
		PlaceObj('XTemplateFunc', {
			'name', "Open(self, ...)",
			'func', function (self, ...)
				MountFolder(self.mod_content_path, self.mod_os_path)
				return GedApp.Open(self, ...)
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "File",
			'ActionName', T(174683227646, --[[XTemplate ModEditor ActionName]] "File"),
			'ActionMenubar', "main",
			'OnActionEffect', "popup",
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "Save",
				'ActionName', T(280146583573, --[[XTemplate ModEditor ActionName]] "Save"),
				'ActionIcon', "CommonAssets/UI/Ged/save.tga",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-S",
				'OnAction', function (self, host, source, ...)
					host:Send("GedSaveMod")
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "OpenFolder",
				'ActionName', T(595712252411, --[[XTemplate ModEditor ActionName]] "Open Folder"),
				'ActionIcon', "CommonAssets/UI/Ged/explorer.tga",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-O",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpOpenModFolder", "root")
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "GenTransTbl",
				'ActionName', T(727097690549, --[[XTemplate ModEditor ActionName]] "Export Translation Table"),
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpGenTTableMod", "root")
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "PackMod",
				'ActionName', T(906167416126, --[[XTemplate ModEditor ActionName]] "Pack Mod"),
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpPackMod", "root")
				end,
			}),
			PlaceObj('XTemplateCode', {
				'run', function (self, parent, context)
					if XTemplates.ModEditorPlatformActions then
						XTemplates.ModEditorPlatformActions:Eval(parent, context)
					end
				end,
			}),
			PlaceObj('XTemplateGroup', {
				'__condition', function (parent, context) return Platform.steam end,
			}, {
				PlaceObj('XTemplateAction', {
					'RolloverText', T(966025188900, --[[XTemplate ModEditor RolloverText]] "Upload to Steam"),
					'RolloverDisabledText', T(131688119141, --[[XTemplate ModEditor RolloverDisabledText]] "Uploading to Steam is unavailable"),
					'ActionId', "SteamUpload",
					'ActionName', T(740063077677, --[[XTemplate ModEditor ActionName]] "Upload to Steam"),
					'ActionIcon', "CommonAssets/UI/Ged/steam.tga",
					'ActionToolbar', "main",
					'ActionToolbarSplit', true,
					'ActionState', function (self, host)
						return not host.steam_login and "disabled"
					end,
					'OnAction', function (self, host, source, ...)
						host:Op("GedOpUploadModToSteam", "root")
					end,
				}),
				}),
			PlaceObj('XTemplateGroup', {
				'__condition', function (parent, context) return Platform.epic end,
			}, {
				PlaceObj('XTemplateAction', {
					'RolloverText', T(602897019334, --[[XTemplate ModEditor RolloverText]] "Upload to Epic Games"),
					'RolloverDisabledText', T(584040368360, --[[XTemplate ModEditor RolloverDisabledText]] "Uploading to Epic Games is unavailable"),
					'ActionId', "EpicUpload",
					'ActionName', T(848185994514, --[[XTemplate ModEditor ActionName]] "Upload to Epic Games"),
					'ActionIcon', "CommonAssets/UI/Ged/epic_up",
					'ActionToolbar', "main",
					'ActionToolbarSplit', true,
					'ActionState', function (self, host)
						
					end,
					'OnAction', function (self, host, source, ...)
						host:Op("GedOpUploadModToEpic", "root")
					end,
				}),
				}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Edit",
			'ActionName', T(786174819535, --[[XTemplate ModEditor ActionName]] "Edit"),
			'ActionMenubar', "main",
			'OnActionEffect', "popup",
		}, {
			PlaceObj('XTemplateAction', {
				'ActionId', "Cut",
				'ActionName', T(718930329684, --[[XTemplate ModEditor ActionName]] "Cut"),
				'ActionIcon', "CommonAssets/UI/Ged/cut.tga",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-X",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpCutModItem", panel.context, panel:GetMultiSelection())
					end
				end,
				'ActionContexts', {
					"ContentRootPanelAction",
					"ContentChildPanelAction",
					"PresetsChildAction",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Copy",
				'ActionName', T(191389011800, --[[XTemplate ModEditor ActionName]] "Copy"),
				'ActionIcon', "CommonAssets/UI/Ged/copy.tga",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-C",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpCopyModItem", panel.context, panel:GetMultiSelection())
					elseif panel == host.idItemProperties then
						host:Op("GedOpPropertyCopy", panel.context, panel:GetSelectedProperties(), panel.context)
					end
				end,
				'ActionContexts', {
					"PresetsChildAction",
					"ContentRootPanelAction",
					"ContentChildPanelAction",
					"PropAction",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Paste",
				'ActionName', T(749315791356, --[[XTemplate ModEditor ActionName]] "Paste"),
				'ActionIcon', "CommonAssets/UI/Ged/paste.tga",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-V",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpPasteModItem", panel.context, panel:GetMultiSelection())
					elseif panel:IsKindOf("GedPropPanel") then
						host:Op("GedOpPropertyPaste", panel.context)
					end
				end,
				'ActionContexts', {
					"PresetsChildAction",
					"ContentRootPanelAction",
					"ContentChildPanelAction",
					"PropAction",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Duplicate",
				'ActionName', T(284844710474, --[[XTemplate ModEditor ActionName]] "Duplicate"),
				'ActionIcon', "CommonAssets/UI/Ged/duplicate.tga",
				'ActionToolbar', "main",
				'ActionToolbarSplit', true,
				'ActionShortcut', "Ctrl-D",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpDuplicateModItem", panel.context, panel:GetMultiSelection())
					end
				end,
				'ActionContexts', {
					"PresetsChildAction",
					"ContentRootPanelAction",
					"ContentChildPanelAction",
				},
				'replace_matching_id', true,
			}),
			PlaceObj('XTemplateAction', {
				'ActionName', T(930594708322, --[[XTemplate ModEditor ActionName]] "-----"),
				'ActionMenubar', "Edit",
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "MoveOutwards",
				'ActionName', T(556803322410, --[[XTemplate ModEditor ActionName]] "Move Out"),
				'ActionIcon', "CommonAssets/UI/Ged/left.tga",
				'ActionMenubar', "Edit",
				'ActionToolbar', "main",
				'ActionShortcut', "Alt-Left",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpTreeMoveItemOutwards", panel.context, panel:GetMultiSelection())
					end
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "MoveInwards",
				'ActionName', T(384052770742, --[[XTemplate ModEditor ActionName]] "Move In"),
				'ActionIcon', "CommonAssets/UI/Ged/right.tga",
				'ActionMenubar', "Edit",
				'ActionToolbar', "main",
				'ActionShortcut', "Alt-Right",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpTreeMoveItemInwards", panel.context, panel:GetMultiSelection())
					end
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "MoveUp",
				'ActionName', T(459268168316, --[[XTemplate ModEditor ActionName]] "Move Up"),
				'ActionIcon', "CommonAssets/UI/Ged/up.tga",
				'ActionMenubar', "Edit",
				'ActionToolbar', "main",
				'ActionShortcut', "Alt-Up",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpTreeMoveItemUp", panel.context, panel:GetMultiSelection())
					end
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "MoveDown",
				'ActionName', T(203305089151, --[[XTemplate ModEditor ActionName]] "Move Down"),
				'ActionIcon', "CommonAssets/UI/Ged/down.tga",
				'ActionMenubar', "Edit",
				'ActionToolbar', "main",
				'ActionShortcut', "Alt-Down",
				'OnAction', function (self, host, source, ...)
					local panel = host:GetLastFocusedPanel()
					if panel == host.idItems then
						host:Op("GedOpTreeMoveItemDown", panel.context, panel:GetMultiSelection())
					end
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "DeleteItem",
				'ActionName', T(931048354633, --[[XTemplate ModEditor ActionName]] "Delete Item"),
				'ActionIcon', "CommonAssets/UI/Ged/delete.tga",
				'ActionToolbar', "main",
				'ActionToolbarSplit', true,
				'ActionShortcut', "Delete",
				'OnAction', function (self, host, source, ...)
					host:Op("GedOpDeleteModItem", "root", host.idItems:GetMultiSelection())
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionName', T(298776341838, --[[XTemplate ModEditor ActionName]] "-----"),
				'ActionMenubar', "Edit",
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Undo",
				'ActionName', T(704182154993, --[[XTemplate ModEditor ActionName]] "Undo"),
				'ActionIcon', "CommonAssets/UI/Ged/undo.tga",
				'ActionToolbar', "main",
				'ActionShortcut', "Ctrl-Z",
				'OnAction', function (self, host, source, ...)
					host:Undo()
				end,
			}),
			PlaceObj('XTemplateAction', {
				'ActionId', "Redo",
				'ActionName', T(825249904824, --[[XTemplate ModEditor ActionName]] "Redo"),
				'ActionIcon', "CommonAssets/UI/Ged/redo.tga",
				'ActionToolbar', "main",
				'ActionToolbarSplit', true,
				'ActionShortcut', "Ctrl-Y",
				'OnAction', function (self, host, source, ...)
					host:Redo()
				end,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'comment', "in file menu",
			'ActionName', T(649145838532, --[[XTemplate ModEditor ActionName]] "-----"),
			'ActionMenubar', "File",
		}),
		PlaceObj('XTemplateAction', {
			'comment', "in file menu",
			'ActionId', "BugReport",
			'ActionName', T(972701350134, --[[XTemplate ModEditor ActionName]] "Report a bug"),
			'ActionIcon', "CommonAssets/UI/Ged/warning_button.png",
			'ActionMenubar', "File",
			'ActionToolbar', "main",
			'ActionShortcut', "Ctrl-F1",
			'OnAction', function (self, host, source, ...)
				CreateRealTimeThread(GedCreateXBugReportDlg)
			end,
			'replace_matching_id', true,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "in file menu",
			'ActionId', "Help",
			'ActionName', T(124350738980, --[[XTemplate ModEditor ActionName]] "Help"),
			'ActionIcon', "CommonAssets/UI/Ged/help.tga",
			'ActionMenubar', "File",
			'ActionToolbar', "main",
			'ActionShortcut', "Ctrl-H",
			'OnAction', function (self, host, source, ...)
				host:Op("GedOpModItemHelp", "root", host.idItems:GetSelection())
			end,
		}),
		PlaceObj('XTemplateAction', {
			'comment', "in file menu",
			'ActionName', T(650063819060, --[[XTemplate ModEditor ActionName]] "-----"),
			'ActionMenubar', "File",
		}),
		PlaceObj('XTemplateAction', {
			'comment', "in file menu",
			'ActionId', "Exit",
			'ActionName', T(874097506037, --[[XTemplate ModEditor ActionName]] "Exit"),
			'ActionMenubar', "File",
			'OnAction', function (self, host, source, ...)
				host:Exit()
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "Cheats",
			'ActionName', T(501723542931, --[[XTemplate ModEditor ActionName]] "Cheats"),
			'ActionMenubar', "main",
			'OnActionEffect', "popup",
		}, {
			PlaceObj('XTemplateTemplate', {
				'__template', "ModEditorCheats",
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "NewItem",
			'ActionName', T(727038768556, --[[XTemplate ModEditor ActionName]] "New"),
			'ActionMenubar', "main",
			'OnActionEffect', "popup",
			'ActionContexts', {
				"ItemModPanelAction",
			},
		}, {
			PlaceObj('XTemplateCode', {
				'run', function (self, parent, context)
					local submenus = { }
					local standalone_entries = {}
					for i, item in ipairs(context.mod_items) do
						local submenu = item.EditorSubmenu
						if not submenu or submenu == "" then
							table.insert(standalone_entries, item)
							goto continue
						end
						if not submenus[submenu] then
							local items = { item }
							submenus[submenu] = items
							table.insert(submenus, submenu)
						else
							table.insert(submenus[submenu], item)
						end
						::continue::
					end
					table.sort(submenus)
					table.sort(standalone_entries, function (a, b) return a.Class:lower() < b.Class:lower() end)
					table.remove_entry(submenus, "Other")
					table.insert(submenus, "Other")
					for i, item in ipairs(standalone_entries) do
						local action = {
							ActionId = "new" .. item.Class,
							ActionName = Untranslated(item.EditorName or item.Class),
							ActionIcon = item.EditorIcon,
							ActionShortcut = item.EditorShortcut,
							ActionMenubar = "NewItem",
							OnAction = function(self, host, source)
								host:Op("GedOpNewModItem", "root", host.idItems:GetSelection(), item.Class)
							end,
						}
						XAction:new(action, parent, context, true)
					end
					for i, submenu in ipairs(submenus) do
						local items = submenus[submenu]
						local submenu_id = "new" .. submenu .. "Menu"
						local submenu_action = {
							ActionId = submenu_id,
							ActionName = Untranslated(submenu) .. "...",
							OnActionEffect = "popup",
							ActionMenubar = "NewItem",
						}
						XAction:new(submenu_action, parent, context, true)
						
						for i, item in ipairs(items) do
							local action = {
								ActionId = "new" .. item.Class,
								ActionName = Untranslated(item.EditorName or item.Class),
								ActionIcon = item.EditorIcon,
								ActionShortcut = item.EditorShortcut,
								ActionMenubar = submenu_id,
								OnAction = function(self, host, source)
									host:Op("GedOpNewModItem", "root", host.idItems:GetSelection(), item.Class)
								end,
							}
							XAction:new(action, parent, context, true)
						end
					end
				end,
			}),
			}),
		PlaceObj('XTemplateWindow', nil, {
			PlaceObj('XTemplateWindow', {
				'__context', function (parent, context) return "root" end,
				'__class', "GedTreePanel",
				'Id', "idItems",
				'Title', "Mod Items",
				'ActionContext', "ItemModPanelAction",
				'Format', "<EditorView>",
				'SelectionBind', "SelectedItem, SelectedObject",
				'OnSelectionChanged', function (self, selection)  end,
				'OnCtrlClick', function (self, selection)  end,
				'OnAltClick', function (self, selection)
					local gedApp = GetDialog(self)
					if not gedApp.mod_folder_supported then return end
					gedApp:Op("GedOpRelocateModItemToFolder", "root", selection, self:GetSelection())
				end,
				'OnDoubleClick', function (self, selection)  end,
				'DragAndDrop', true,
				'ChildActionContext', "ItemModPanelAction",
			}, {
				PlaceObj('XTemplateWindow', {
					'__condition', function (parent, context) return true end,
					'Id', "idBottomButtons",
					'ZOrder', 2,
					'Margins', box(7, 7, 7, 7),
					'HAlign', "right",
					'VAlign', "bottom",
					'LayoutMethod', "HList",
					'LayoutHSpacing', 7,
				}, {
					PlaceObj('XTemplateWindow', {
						'__class', "XButton",
						'RolloverTemplate', "GedToolbarRollover",
						'RolloverAnchor', "top",
						'RolloverText', T(149723581950, --[[XTemplate ModEditor RolloverText]] "Create new Mod Item"),
						'Id', "idNewModItem",
						'ZOrder', 2,
						'HAlign', "right",
						'VAlign', "center",
						'MinWidth', 45,
						'MinHeight', 45,
						'Background', RGBA(255, 255, 255, 0),
						'FocusedBackground', RGBA(255, 255, 255, 0),
						'RolloverBackground', RGBA(255, 255, 255, 0),
						'PressedBackground', RGBA(255, 255, 255, 0),
					}, {
						PlaceObj('XTemplateFunc', {
							'name', "OnSetRollover(self, rollover)",
							'func', function (self, rollover)
								XButton.OnSetRollover(self, rollover)
								if rollover then
									self[1]:SetBackground(RGB(128, 128, 128))
								else
									self[1]:SetBackground(RGB(105, 105, 105))
								end
							end,
						}),
						PlaceObj('XTemplateFunc', {
							'name', "OnPress(self)",
							'func', function (self)
								local items = {}
								local mod_items = GetDialog(self).mod_items
								for _, entry in ipairs(mod_items) do
									table.insert(items, {
										category = entry.EditorSubmenu or "",
										text = entry.EditorName,
										value = entry.Class,
										documentation = entry.Documentation,
									})
								end
								
								CreateRealTimeThread(function()
									GedOpenCreateItemPopup(g_GedApp.idItems, "New Mod Item", items, self, function(class)
										if self.window_state == "destroying" then return end
										g_GedApp:Op("GedOpNewModItem", "root", g_GedApp.idItems:GetSelection(), class)
									end)
								end)
							end,
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XFrame",
							'Background', RGBA(105, 105, 105, 255),
							'Image', "CommonAssets/UI/round-frame-20",
							'FrameBox', box(9, 9, 9, 9),
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XImage",
							'Image', "CommonAssets/UI/Ged/Plus",
						}),
						}),
					PlaceObj('XTemplateWindow', {
						'__condition', function (parent, context) return GetDialog(parent).mod_folder_supported end,
						'__class', "XButton",
						'RolloverTemplate', "GedToolbarRollover",
						'RolloverAnchor', "top",
						'RolloverText', T(976724333601, --[[XTemplate ModEditor RolloverText]] "Add selected items to New Folder"),
						'Id', "idNewModFolder",
						'ZOrder', 2,
						'HAlign', "right",
						'VAlign', "center",
						'MinWidth', 45,
						'MinHeight', 45,
						'Background', RGBA(255, 255, 255, 0),
						'FocusedBackground', RGBA(255, 255, 255, 0),
						'RolloverBackground', RGBA(255, 255, 255, 0),
						'PressedBackground', RGBA(255, 255, 255, 0),
					}, {
						PlaceObj('XTemplateFunc', {
							'name', "OnSetRollover(self, rollover)",
							'func', function (self, rollover)
								XButton.OnSetRollover(self, rollover)
								if rollover then
									self[1]:SetBackground(RGB(128, 128, 128))
								else
									self[1]:SetBackground(RGB(105, 105, 105))
								end
							end,
						}),
						PlaceObj('XTemplateFunc', {
							'name', "OnPress(self)",
							'func', function (self)
								CreateRealTimeThread(function()
									local panel = g_GedApp.idItems
									g_GedApp:Op("GedOpAddModItemsToFolder", panel.context, panel:GetMultiSelection())
								end)
							end,
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XFrame",
							'Background', RGBA(105, 105, 105, 255),
							'Image', "CommonAssets/UI/round-frame-20",
							'FrameBox', box(9, 9, 9, 9),
						}),
						PlaceObj('XTemplateWindow', {
							'__class', "XImage",
							'Image', "CommonAssets/UI/Ged/NewFolder",
						}),
						}),
					}),
				PlaceObj('XTemplateTemplate', {
					'__template', "GedStatusBar",
					'Background', RGBA(255, 0, 0, 255),
					'FormatFunc', "GedModStatusText",
				}),
				}),
			}),
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "SelectedItem" end,
			'__class', "GedBindView",
			'BindView', "SubItems",
			'BindRoot', "root",
			'BindFunc', "GedDynamicItemsMenu",
			'ControlId', "idItems",
			'GetBindParams', function (self, control) return "ModItem", control:GetSelection() end,
			'OnViewChanged', function (self, value, control)
				RebuildSubItemsActions(control, value, "New Element", "main", "main")
			end,
		}),
		PlaceObj('XTemplateWindow', {
			'__class', "XPanelSizer",
		}),
		PlaceObj('XTemplateWindow', {
			'__context', function (parent, context) return "SelectedObject" end,
			'__class', "GedPropPanel",
			'Id', "idItemProperties",
			'MinWidth', 300,
			'Title', "Item Properties",
			'HideFirstCategory', true,
			'RootObjectBindName', "SelectedItem",
		}, {
			PlaceObj('XTemplateWindow', {
				'__context', function (parent, context) return "SelectedItem" end,
				'__class', "GedBindView",
				'BindView', "PresetEditor",
				'BindRoot', "SelectedItem",
				'BindFunc', "GedGetModItemDockedActions",
				'ControlId', "idPanelDockedButtons",
				'OnViewChanged', function (self, value, control)
					if not control then return end
					local visible = not not next(value)
					control:SetVisible(visible)
					local list = self:ResolveId("idList")
					list:SetContext(value, true)
				end,
			}),
			PlaceObj('XTemplateWindow', {
				'Id', "idPanelDockedButtons",
				'ZOrder', 2,
				'Margins', box(0, 3, 0, 0),
				'Dock', "bottom",
				'FoldWhenHidden', true,
			}, {
				PlaceObj('XTemplateWindow', {
					'__context', function (parent, context)
						return context
					end,
					'__class', "XContentTemplate",
					'Id', "idList",
					'ZOrder', 2,
					'Padding', box(15, 15, 15, 15),
					'HAlign', "center",
					'VAlign', "center",
					'LayoutMethod', "HWrap",
					'LayoutHSpacing', 15,
					'LayoutVSpacing', 15,
					'FoldWhenHidden', true,
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
						'array', function (parent, context)
							if type(context) ~= "table" then return context end
							local result = {}
							for id, data in pairs(context) do
								table.insert(result, { 
									id = id, name = data.name, 
									rolloverText = data.rolloverText, 
									op = data.op 
								})
							end
							return result
						end,
						'map', function (parent, context, array, i)
							return array and array[i]
						end,
						'__context', function (parent, context, item, i, n)
							return context
						end,
						'run_before', function (parent, context, item, i, n, last)
							
						end,
						'run_after', function (child, context, item, i, n, last)
							child:SetText(item.name)
							child:SetRolloverText(item.rolloverText)
							child:SetOnPress(function(child)
								local app = GetParentOfKind(child, "GedApp")
								local panel = app:ResolveId("idItems")
								if panel then
									app:Op(item.op, "SelectedItem")
								end
							end)
						end,
					}, {
						PlaceObj('XTemplateWindow', {
							'__class', "XTextButton",
							'RolloverTemplate', "GedToolbarRollover",
							'RolloverAnchor', "top",
							'Id', "idOpenInPresetEditorButton",
							'BorderWidth', 2,
							'Padding', box(2, 2, 2, 2),
							'HAlign', "center",
						}),
						}),
					}),
				}),
			}),
		}),
})
