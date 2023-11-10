-- ========== GENERATED BY XTemplate Editor (Alt-F3) DO NOT EDIT MANUALLY! ==========

PlaceObj('XTemplate', {
	__is_kind_of = "XWindow",
	group = "Zulu",
	id = "PGMainActions",
	PlaceObj('XTemplateWindow', nil, {
		PlaceObj('XTemplateAction', {
			'ActionId', "idContinue",
			'ActionName', T(621514059338, --[[XTemplate PGMainActions ActionName]] "CONTINUE"),
			'ActionToolbar', "mainmenu",
			'ActionState', function (self, host)
				return g_LatestSave and "enabled" or "disabled"
			end,
			'OnAction', function (self, host, source, ...)
				if self:ActionState() == "enabled" then
					local saveLoadObj = g_SaveGameObj or SaveLoadObjectCreateAndLoad()
					saveLoadObj:Load(host, g_LatestSave, Platform.developer)
				end
			end,
		}),
		PlaceObj('XTemplateForEach', {
			'array', function (parent, context) return GameStartTypes end,
			'condition', function (parent, context, item, i) return item.id ~= "QuickStart" and item.id ~= "Satellite" end,
			'run_after', function (child, context, item, i, n, last)
				child.ActionId = item.id
				child.ActionName = item.Name
				child.OnAction = function(...)
					if Platform.developer then
						g_AutoClickLoadingScreenStart =  false
					end
					item.func()
				end
			end,
		}, {
			PlaceObj('XTemplateAction', {
				'ActionToolbar', "mainmenu",
				'OnActionEffect', "close",
				'OnAction', function (self, host, source, ...)
					local effect = self.OnActionEffect
					local param = self.OnActionParam
					if effect == "close" and host and host.window_state ~= "destroying" then
						host:Close(param ~= "" and param or nil)
					elseif effect == "mode" and host then
						assert(IsKindOf(host, "XDialog"))
						host:SetMode(param)
					elseif effect == "back" and host then
						assert(IsKindOf(host, "XDialog"))
						SetBackDialogMode(host)
					elseif effect == "popup" then
						local actions_view = GetParentOfKind(source, "XActionsView")
						if actions_view then
							actions_view:PopupAction(self.ActionId, host, source)
						else
							XShortcutsTarget:OpenPopupMenu(self.ActionId, terminal.GetMousePos())
						end
					else
						--print(self.ActionId, "activated")
					end
				end,
			}),
			}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idMultiplayer",
			'ActionName', T(787666103448, --[[XTemplate PGMainActions ActionName]] "MULTIPLAYER"),
			'ActionToolbar', "mainmenu",
			'OnAction', function (self, host, source, ...)
				if Platform.developer then
					g_AutoClickLoadingScreenStart =  false
				end
				MultiplayerLobbySetUI("multiplayer")
			end,
			'__condition', function (parent, context) return not Platform.demo and not Game end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idLoad",
			'ActionName', T(222566664371, --[[XTemplate PGMainActions ActionName]] "LOAD GAME"),
			'ActionToolbar', "mainmenu",
			'OnActionEffect', "mode",
			'OnActionParam', "LoadWIP",
			'OnAction', function (self, host, source, ...)
				local effect = self.OnActionEffect
				local param = self.OnActionParam
				if effect == "close" and host and host.window_state ~= "destroying" then
					host:Close(param ~= "" and param or nil)
				elseif effect == "mode" and host then
					assert(IsKindOf(host, "XDialog"))
					host:SetMode(param)
					CreateRealTimeThread(function()
						LoadingScreenOpen("idLoadingScreen", "save load")
						local saves = g_SaveGameObj or SaveLoadObjectCreateAndLoad()
						saves:WaitGetSaveItems()
						LoadingScreenClose("idLoadingScreen", "save load")
						Sleep(5)		
						g_SelectedSave = false			
						host:ResolveId("idSubContent"):SetMode("loadgame", saves)
						host:ResolveId("idSubMenuTittle"):SetText(self.ActionName)
					end)
				elseif effect == "back" and host then
					assert(IsKindOf(host, "XDialog"))
					SetBackDialogMode(host)
				elseif effect == "popup" then
					local actions_view = GetParentOfKind(source, "XActionsView")
					if actions_view then
						actions_view:PopupAction(self.ActionId, host, source)
					else
						XShortcutsTarget:OpenPopupMenu(self.ActionId, terminal.GetMousePos())
					end
				else
					--print(self.ActionId, "activated")
				end
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idOptions",
			'ActionName', T(670984943483, --[[XTemplate PGMainActions ActionName]] "OPTIONS"),
			'ActionToolbar', "mainmenu",
			'OnActionEffect', "mode",
			'OnActionParam', "Options",
			'OnAction', function (self, host, source, ...)
				local effect = self.OnActionEffect
				local param = self.OnActionParam
				if effect == "close" and host and host.window_state ~= "destroying" then
					host:Close(param ~= "" and param or nil)
				elseif effect == "mode" and host then
					assert(IsKindOf(host, "XDialog"))
					host:SetMode(param)
					local firstEnabledCategory
					for i, category in ipairs(OptionsCategories) do
						if not category.no_edit then
							firstEnabledCategory = category
							break
						end
					end
					host:ResolveId("idSubContent"):SetMode("options", {optObj = firstEnabledCategory})
					host:ResolveId("idSubSubContent"):SetMode("empty")
					host:ResolveId("idSubMenuTittle"):SetText(firstEnabledCategory.display_name)
					host:ResolveId("idList")[1].idBtnText:SetTextStyle("MMButtonTextSelected")
					host:ResolveId("idList")[1].focused = true
					host:ResolveId("idList")[1].enabled = false
				elseif effect == "back" and host then
					assert(IsKindOf(host, "XDialog"))
					SetBackDialogMode(host)
				elseif effect == "popup" then
					local actions_view = GetParentOfKind(source, "XActionsView")
					if actions_view then
						actions_view:PopupAction(self.ActionId, host, source)
					else
						XShortcutsTarget:OpenPopupMenu(self.ActionId, terminal.GetMousePos())
					end
				else
					--print(self.ActionId, "activated")
				end
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idCredits",
			'ActionName', T(854488533674, --[[XTemplate PGMainActions ActionName]] "CREDITS"),
			'ActionToolbar', "mainmenu",
			'OnAction', function (self, host, source, ...)
				OpenDialog("Credits")
			end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idUpdate",
			'ActionName', T(570518612409, --[[XTemplate PGMainActions ActionName]] "Update"),
			'ActionToolbar', "mainmenu",
			'OnAction', function (self, host, source, ...)
				OpenGameUpdatesPopup(false, "force")
			end,
			'__condition', function (parent, context) return not Platform.console end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idMods",
			'ActionName', T(405038833124, --[[XTemplate PGMainActions ActionName]] "Mod Manager"),
			'ActionToolbar', "mainmenu",
			'OnActionEffect', "mode",
			'OnActionParam', "ModManager",
			'OnAction', function (self, host, source, ...)
				local effect = self.OnActionEffect
				local param = self.OnActionParam
				if effect == "close" and host and host.window_state ~= "destroying" then
					host:Close(param ~= "" and param or nil)
				elseif effect == "mode" and host then
					CreateRealTimeThread(function()
						LoadingScreenOpen("idLoadingScreen", "load mods")	
						ModsUIObjectCreateAndLoad()
						g_ModsUIContextObj:SetInstalledSortMethod("enabled_desc")
						g_ModsUIContextObj.cant_load_on_top = true
						LoadingScreenClose("idLoadingScreen", "load mods")
						Sleep(1)
						host:SetMode(param)
						UpdateModsCount(host)
						host:ResolveId("idSubContent"):SetMode("installedmods")
						host:ResolveId("idSubMenuTittle"):SetText(self.ActionName)
					end)
				elseif effect == "back" and host then
					assert(IsKindOf(host, "XDialog"))
					SetBackDialogMode(host)
				elseif effect == "popup" then
					local actions_view = GetParentOfKind(source, "XActionsView")
					if actions_view then
						actions_view:PopupAction(self.ActionId, host, source)
					else
						XShortcutsTarget:OpenPopupMenu(self.ActionId, terminal.GetMousePos())
					end
				end
			end,
			'__condition', function (parent, context) return Platform.desktop and not Platform.demo end,
		}),
		PlaceObj('XTemplateAction', {
			'ActionId', "idQuit",
			'ActionName', T(747351508877, --[[XTemplate PGMainActions ActionName]] "QUIT"),
			'ActionToolbar', "mainmenu",
			'ActionShortcut', "Escape",
			'ActionGamepad', "ButtonB",
			'OnAction', function (self, host, source, ...)
				if not GetLoadingScreenDialog("noAccStorage") then
					QuitGame(host)
				end
			end,
			'__condition', function (parent, context) return not Platform.console end,
		}),
		}),
})

