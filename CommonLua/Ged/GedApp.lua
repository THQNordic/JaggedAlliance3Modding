function OnMsg.SystemActivate()
	if rawget(_G, "g_GedApp") and Platform.ged then
		g_GedApp.connection:Send("rfnGedActivated", false)
	end
end

GedDisabledOp = "(disabled)"
GedCommonOps = {
	{ Id = "MoveUp",    Name = "Move up",   Icon = "CommonAssets/UI/Ged/up.tga",        Shortcut = "Alt-Up", },
	{ Id = "MoveDown",  Name = "Move down", Icon = "CommonAssets/UI/Ged/down.tga",      Shortcut = "Alt-Down", },
	{ Id = "MoveOut",   Name = "Move out",  Icon = "CommonAssets/UI/Ged/left.tga",      Shortcut = "Alt-Left", },
	{ Id = "MoveIn",    Name = "Move in",   Icon = "CommonAssets/UI/Ged/right.tga",     Shortcut = "Alt-Right", },
	{ Id = "Delete",    Name = "Delete",    Icon = "CommonAssets/UI/Ged/delete.tga",    Shortcut = "Delete", Split = true, },
	{ Id = "Cut",       Name = "Cut",       Icon = "CommonAssets/UI/Ged/cut.tga",       Shortcut = "Ctrl-X", },
	{ Id = "Copy",      Name = "Copy",      Icon = "CommonAssets/UI/Ged/copy.tga",      Shortcut = "Ctrl-C", },
	{ Id = "Paste",     Name = "Paste",     Icon = "CommonAssets/UI/Ged/paste.tga",     Shortcut = "Ctrl-V", },
	{ Id = "Duplicate", Name = "Duplicate", Icon = "CommonAssets/UI/Ged/duplicate.tga", Shortcut = "Ctrl-D", Split = true, },
	{ Id = "DiscardEditorChanges", Name = "Discard editor changes", Icon = "CommonAssets/UI/Ged/cleaning_brush.png", Shortcut = "Ctrl-Alt-D", },
	{ Id = "Undo",      Name = "Undo",      Icon = "CommonAssets/UI/Ged/undo.tga",      Shortcut = "Ctrl-Z", },
	{ Id = "Redo",      Name = "Redo",      Icon = "CommonAssets/UI/Ged/redo.tga",      Shortcut = "Ctrl-Y", Split = true, },
}

DefineClass.GedApp = {
	__parents = { "XActionsHost", "XDarkModeAwareDialog" },
	properties = {
		{ category = "GedApp", id = "HasTitle", editor = "bool", default = true, },
		{ category = "GedApp", id = "Title", editor = "text", default = "", no_edit = function(obj) return not obj:GetProperty("HasTitle") end },
		{ category = "GedApp", id = "AppId", editor = "text", default = "", },
		{ category = "GedApp", id = "ToolbarTemplate", editor = "choice", default = "GedToolBar", items = XTemplateCombo("XToolBar"), },
		{ category = "GedApp", id = "MenubarTemplate", editor = "choice", default = "GedMenuBar", items = XTemplateCombo("XMenuBar"), },
		{ category = "GedApp", id = "CommonActionsInMenubar", editor = "bool", default = true, },
		{ category = "GedApp", id = "CommonActionsInToolbar", editor = "bool", default = true, },
		{ category = "GedApp", id = "InitialWidth", editor = "number", default = 1600, },
		{ category = "GedApp", id = "InitialHeight", editor = "number", default = 900, },
		{ category = "GedApp", id = "DiscardChangesAction", editor = "bool", default = true, },
	},
	LayoutMethod = "HPanel",
	LayoutHSpacing = 0,
	IdNode = true,
	Background = RGB(160, 160, 160),
	connection = false,
	in_game = false,
	settings = false,
	first_update = true, -- used by GedListPanel/GedTreePanel
	all_panels = false,
	interactive_panels = false, -- mapping context => panel
	actions_toggled = false, -- mapping actionid => toggled (only for Toggled actions)
	ui_status = false,
	ui_update_time = 0,
	ui_questions = false,
	ui_status_delay_time = 0,
	ui_status_delay_thread = false,
	last_focused_panel = false,
	last_focused_tree_or_list_panel = false,
	blink_thread = false, -- see GedOpError
	blink_border_color = RGBA(0, 0, 0, 0),
	progress_text = false,
	progress_bar = false,
	
	-- support for next/previous match when a search with "Search in properties and sub-objects" is active
	search_value_filter_text = false,
	search_value_results = false,
	search_value_panel = false,
	search_result_idx = 1,
	display_search_result = false,
}

function GedApp:Init(parent, context)
	if Platform.ged then rawset(_G, "g_GedApp", self) end
	
	for k, v in pairs(context) do
		rawset(self, k, v)
	end
	if Platform.ged and self.connection then
		self.connection:Send("rfnGedActivated", true)
	end
	
	self.connection.app = self
	self.actions_toggled = {}
	self.ui_status = {}
	self:SetHasTitle(true)
	if not self.in_game then
		self.HAlign = "stretch"
		self.VAlign = "stretch"
		if self.ui_scale then
			self:SetScaleModifier(point(self.ui_scale * 10, self.ui_scale * 10))
		end
	end
	hr.MaxFps = Min(60, self.max_fps)
	ShowMouseCursor("GedApp")
	
	XAction:new({
		ActionId = "idSearch",
		ActionToolbar = false,
		ActionShortcut = "Ctrl-F",
		ActionContexts = {},
		ActionMenubar = false,
		ActionName = "Search",
		ActionTranslate = false,
		OnAction = function(action, ged_app, src)
			local panel = ged_app.last_focused_panel
			if panel and IsKindOf(panel, "GedPanel") then
				panel:OpenSearch()
			end
		end
	}, self)
	
	XAction:new({
		ActionId = "idExpandCollapseNode",
		ActionToolbar = false,
		ActionShortcut = "Alt-C",
		ActionContexts = {},
		ActionMenubar = false,
		ActionName = "Expand/collapse selected node's children",
		ActionTranslate = false,
		OnAction = function(action, ged_app, src)
			local panel = ged_app.last_focused_panel
			if panel and IsKindOf(panel, "GedTreePanel") then
				panel.idContainer:ExpandNodeByPath(panel.idContainer:GetFocusedNodePath() or empty_table)
				panel.idContainer:ExpandCollapseChildren(panel.idContainer:GetFocusedNodePath() or empty_table, not "recursive", "user_initiated")				
			end
		end
	}, self)
	XAction:new({
		ActionId = "idExpandCollapseTree",
		ActionToolbar = false,
		ActionShortcut = "Shift-C",
		ActionContexts = {},
		ActionMenubar = false,
		ActionName = "Expand/collapse tree",
		ActionTranslate = false,
		OnAction = function(action, ged_app, src)
			local panel = ged_app.last_focused_panel
			if IsKindOf(panel, "GedTreePanel") then
				panel.idContainer:ExpandCollapseChildren({}, "recursive", "user_initiated")
			elseif IsKindOf(panel, "GedPropPanel") then
				panel:ExpandCollapseCategories()
			end
		end
	}, self)
	
	if self.MenubarTemplate ~= "" then XTemplateSpawn(self.MenubarTemplate, self) end
	if self.ToolbarTemplate ~= "" then XTemplateSpawn(self.ToolbarTemplate, self) end
	
	if not self.in_game then
		self.status_ui = StdStatusDialog:new({}, self.desktop, { dark_mode = self.dark_mode })
		self.status_ui:SetVisible(false)
		self.status_ui:Open()
	end
	
	self:SetContext("root")
end

function GedApp:AddCommonActions()
	if not self.interactive_panels then return end
	
	if self.CommonActionsInMenubar then
		if not self:ActionById("File") then
			XAction:new({
				ActionId = "File",
				ActionName = "File",
				ActionMenubar = "main",
				ActionTranslate = false,
				ActionSortKey = "1",
				OnActionEffect = "popup",
			}, self)
		end
		if not self:ActionById("Edit") then
			XAction:new({
				ActionId = "Edit",
				ActionName = "Edit",
				ActionMenubar = "main",
				ActionTranslate = false,
				ActionSortKey = "1",
				OnActionEffect = "popup",
			}, self)
		end
	end
	
	local has_undo = false -- if at least one panel with ActionsClass set
	for _, panel in pairs(self.interactive_panels) do
		has_undo = has_undo or panel.ActionsClass ~= "None"
	end
	
	local needs_separator = false
	for _, data in ipairs(GedCommonOps) do
		local id = data.Id
		local is_undo = id == "Undo" or id == "Redo" or id == "DiscardEditorChanges"
		local contexts = {}
		for _, panel in pairs(self.interactive_panels) do
			if not is_undo and panel[id] ~= "" and panel[id] ~= GedDisabledOp then
				if panel:IsKindOf("GedListPanel") then
					table.insert(contexts, panel.ItemActionContext)
				elseif panel:IsKindOf("GedTreePanel") then
					if panel.EnableForRootLevelItems or id == "Paste" then
						table.insert(contexts, panel.RootActionContext)
					end
					table.insert(contexts, panel.ChildActionContext)
				elseif panel:IsKindOf("GedPropPanel") then
					table.insert(contexts, panel.PropActionContext)
				end
			end
		end
		
		if is_undo and has_undo or next(contexts) then
			XAction:new({
				ActionId = id,
				ActionMenubar = self.CommonActionsInMenubar and "Edit",
				ActionToolbar = self.CommonActionsInToolbar and "main",
				ActionToolbarSplit = data.Split,
				ActionTranslate = false,
				ActionName = data.Name,
				ActionIcon = data.Icon,
				ActionShortcut = data.Shortcut,
				ActionSortKey = "1",
				ActionContexts = contexts,
				ActionState = function(self, host) return host:CommonActionState(self.ActionId) end,
				OnAction = function(self, host, source) host:CommonAction(self.ActionId) end,
			}, self)
			needs_separator = true
		end
		
		if data.Split and needs_separator then
			XAction:new({
				ActionMenubar = "Edit",
				ActionName = "-----",
				ActionTranslate = false,
				ActionSortKey = "1",
			}, self)
			needs_separator = false
		end
	end
end

function GedApp:FindPropPanelForPropertyPaste(panel)
	-- look for a GedPropPanel where the object from the current panel is displayed (and it supports paste)
	-- allow pasting properties in this case even if the current panel has no ops
	if panel and panel:HasMember("SelectionBind") then
		local panel_bindings = panel.SelectionBind:split(",")
		for _, prop_panel in pairs(self.interactive_panels) do
			if prop_panel:IsKindOf("GedPropPanel") and prop_panel.Paste ~= "" and prop_panel.Paste ~= GedDisabledOp and
			   table.find(panel_bindings, prop_panel.context) then
				return prop_panel
			end
		end
	end
end

local reCommaList = "([%w_]+)%s*,%s*"
function GedApp:CommonActionState(id)
	if id == "DiscardEditorChanges" then
		return (not rawget(self, "PresetClass") or not self.DiscardChangesAction or config.ModdingToolsInUserMode) and "hidden"
	elseif id ~= "Undo" and id ~= "Redo" then
		local panel = self:GetLastFocusedPanel()
		if IsKindOf(panel, "GedTreePanel") and not panel.EnableForRootLevelItems then
			local selection = panel:GetSelection()
			if selection and #selection == 1 and id ~= "Paste" then
				return "disabled"
			end
		end
		
		-- Disable most common operations for read-only presets/objects
		if panel then
			-- Check if selection obj is read-only
			local sel_read_only
			if panel.SelectionBind then
				for bind in string.gmatch(panel.SelectionBind .. ",", reCommaList) do
					sel_read_only = sel_read_only or self.connection:Obj(bind .. "|read_only")
					if sel_read_only then
						break
					end
				end
			else
				sel_read_only = self.connection:Obj(panel.context .. "|read_only")
			end
			
			-- "sel_read_only == nil" means the binding object is changing, so actions should be disabled
			if sel_read_only == nil then
				sel_read_only = true
			end
			
			-- Panel context IS NOT read-only but the selection bind IS read-only (ex. Leftmost preset tree panel)
			if not panel.read_only and sel_read_only then
				-- Disable all operations when Modding, otherwise leave only Copy and Paste
				if (id ~= "Copy" and id ~= "Paste") or config.ModdingToolsInUserMode then
					return "disabled"
				end
			-- Panel context IS read-only but the selection bind IS read-only (ex. Middle preset panel (container items panel))
			elseif panel.read_only and sel_read_only then
				-- Disable all operations except Copy
				if id ~= "Copy" then
					return "disabled"
				end
			end
		end
		
		if not panel or not IsKindOf(panel, "GedPanel") or panel[id] == "" or panel[id] == GedDisabledOp then
			if id ~= "Paste" or not self:FindPropPanelForPropertyPaste(panel) then
				return "disabled"
			end
		end
	end
end

function GedApp:CommonAction(id)
	if id == "Undo" then
		self:Undo()
	elseif id == "Redo" then
		self:Redo()
	elseif id == "DiscardEditorChanges" then
		self:DiscardEditorChanges()
	else
		local panel = self:GetLastFocusedPanel()
		local op = panel[id]
		if panel:IsKindOf("GedPropPanel") then
			if id == "Copy" then
				self:Op(op, panel.context, panel:GetSelectedProperties(), panel.context)
			elseif id == "Paste" then
				self:Op(op, panel.context, panel:GetSelectedProperties(), panel.context)
			else
				assert(false, "Unknown common action " .. id .. "; prop panels only have Copy & Paste common actions")
			end
		elseif id == "MoveUp" or id == "MoveDown" or id == "MoveIn" or id == "MoveOut" or id == "Delete" then
			self:Op(op, panel.context, panel:GetMultiSelection())
		elseif id == "Cut" or id == "Copy" or id == "Paste" or id == "Duplicate" then
			if id == "Paste" and (op == "" or op == GedDisabledOp) then
				panel = self:FindPropPanelForPropertyPaste(panel)
				self:Op(panel[id], panel.context)
			else
				self:Op(op, panel.context, panel:GetMultiSelection(), panel.ItemClass(self))
			end
		else
			assert(false, "Unknown common action " .. id)
		end
	end
end

function GedApp:SetHasTitle(has_title)
	self.HasTitle = has_title
	
	if self.in_game and self.HasTitle then
		if not self:HasMember("idTitleContainer") then
			XMoveControl:new({
				Id = "idTitleContainer",
				Dock = "top",
			}, self)
			XLabel:new({
				Id = "idTitle",
				Dock = "left",
				Margins = box(4, 2, 4, 2),
				TextStyle = "GedTitle",
			}, self.idTitleContainer)
			XTextButton:new({
				Dock = "right",
				OnPress = function(n) 
					self:Exit() 
				end,
				Text = "X",
				LayoutHSpacing = 0,
				Padding = box(1, 1, 1, 1),
				Background = RGBA(0, 0, 0, 0),
				RolloverBackground = RGB(204, 232, 255),
				PressedBackground = RGB(121, 189, 241),
				VAlign = "center",
				TextStyle = "GedTitle",
			}, self.idTitleContainer)
		end
	elseif self:HasMember("idTitleContainer") then
		self.idTitleContainer:Done()
	end
end

function GedApp:UpdateUiStatus(force)
	if self.in_game then return end

	if not force and now() - self.ui_update_time < 250 then
		CreateRealTimeThread(function()
			Sleep(now() - self.ui_update_time)
			self:UpdateUiStatus(true)
		end)
		return
	end
	self.ui_update_time = now()

	if #self.ui_status == 0 then
		self.status_ui:SetVisible(false)
		return
	end
	
	local texts = {}
	for _, status in ipairs(self.ui_status) do
		texts[#texts + 1] = status.text
	end
	self.status_ui.idText:SetText(table.concat(texts, "\n"))
	self.status_ui:SetVisible(true)
end

function GedApp:Open(...)
	self:CreateProgressStatusText()
	
	XActionsHost.Open(self, ...)
	self:AddCommonActions()
	if self.AppId ~= "" then
		self:ApplySavedSettings()
	end
	self:SetDarkMode(GetDarkModeSetting())
	self:OnContextUpdate(self.context, nil)
end

function GedApp:CreateProgressStatusText()
	if not self.interactive_panels then return end
	
	-- find first interactive panel, add the progress status text on its bottom
	for _, panel in ipairs(self.all_panels) do
		if self.interactive_panels[panel.context or false] then
			local parent = XWindow:new({
				Dock = "bottom",
				FoldWhenHidden = true,
				Margins = box(2, 1, 2, 1),
			}, panel)
			self.progress_bar = XWindow:new({
				DrawContent = function(self, clip_box)
					local bbox = self.content_box
					local sizex = MulDivRound(bbox:sizex(), self.progress, self.total_progress)
					UIL.DrawSolidRect(sizebox(bbox:min(), bbox:size():SetX(sizex)), RGBA(128, 128, 128, 128))
				end,
			}, parent)
			self.progress_text = XText:new({
				Background = RGBA(0, 0, 0, 0),
				TextStyle = "GedDefault",
				TextHAlign = "center",
			}, parent)
			parent:SetVisible(false)
			break
		end
	end
end

function GedApp:SetProgressStatus(text, progress, total_progress)
	if not self.progress_text then return end
	if not text then
		self.progress_text.parent:SetVisible(false)
		return
	end
	rawset(self.progress_bar, "progress", progress)
	rawset(self.progress_bar, "total_progress", total_progress)
	self.progress_bar:Invalidate()
	self.progress_text:SetText(text)
	self.progress_text.parent:SetVisible(true)
end

function GedApp:GedDefaultBox()
	local ret = sizebox(20, 20, self.InitialWidth, self.InitialHeight)
	return ret + (self.in_game and GetDevUIViewport().box:min() or point(30, 30))
end

function GedApp:ApplySavedSettings()
	self.settings = io.exists(self:SettingsPath()) and LoadLuaTableFromDisk(self:SettingsPath()) or {}
	self:SetWindowBox(self.settings.box or self:GedDefaultBox())
	if self.settings.resizable_panel_sizes then
		self:SetSizeOfResizablePanels()
	end
	
	local search_values = self.settings.search_in_props
	if search_values then
		for context, panel in pairs(self.interactive_panels) do
			local setting_value = search_values[context]
			if panel.SearchValuesAvailable and setting_value ~= nil and panel.search_values ~= setting_value then
				panel:ToggleSearchValues("no_settings_update")
			end
		end
	end
	
	local collapsed_categories = self.settings.collapsed_categories or empty_table
	for context, panel in pairs(self.interactive_panels) do
		panel.collapsed_categories = collapsed_categories[context] or {}
	end
end

function GedApp:SetWindowBox(box)
	if self.in_game then
		local viewport = GetDevUIViewport().box:grow(-20)
		if viewport:Intersect2D(box) ~= const.irInside then
			box = self:GedDefaultBox()
		end
		self:SetDock("ignore")
		self:SetBox(box:minx(), box:miny(), box:sizex(), box:sizey())
	else
		terminal.OverrideOSWindowPos(box:min())
		ChangeVideoMode(box:sizex(), box:sizey(), 0, true, false)
	end
end

function GedApp:SetSizeOfResizablePanels()
	if not self.settings.resizable_panel_sizes then return end
	for id, data in pairs(self.settings.resizable_panel_sizes) do
		local panel = self:ResolveId(id)
		if panel then 
			panel:SetMaxWidth(data.MaxWidth)
			panel:SetMaxHeight(data.MaxHeight)
		end
	end
end

function GedApp:Exit()
	self.connection:delete()
end

function GedApp:Close(...)
	self:SaveSettings()
	XActionsHost.Close(self, ...)
end

function GedApp:SettingsPath()
	local subcategory = ""
	if rawget(self, "PresetClass") then subcategory = "-" .. self.PresetClass end
	local filename = string.format("AppData/Ged/%s%s%s.settings", self.in_game and "ig_" or "", self.AppId, subcategory)
	return filename
end

function GedApp:SaveSettings()
	if not self.settings then return end
	self.settings.box = self:GetWindowBox()
	self:SavePanelSize()

	local filename = self:SettingsPath()
	local path = SplitPath(filename)
	AsyncCreatePath(path)
	return SaveLuaTableToDisk(self.settings, filename)
end

function GedApp:SavePanelSize()
	if not self.settings["resizable_panel_sizes"] then
		self.settings["resizable_panel_sizes"] = {}
	end

	for _, child in ipairs(self) do
		if not child:IsKindOf("XPanelSizer") and not child.Dock then
			self.settings.resizable_panel_sizes[child.Id] = {
				MaxHeight = child.MaxHeight,
				MaxWidth = child.MaxWidth
			}
		end
	end
end

function GedApp:Activate(context)
	for k, v in pairs(context) do
		rawset(self, k, v)
	end
	if rawget(terminal, "BringToTop") then
		return terminal.BringToTop()
	end
	return false
end

function GedApp:GetWindowBox()
	if self.in_game then
		return self.box
	end
	return sizebox(terminal.GetOSWindowPos(), self.box:size())
end

function GedApp:OnContextUpdate(context, view)
	if not view then
		if self.HasTitle then
			local title = self.Title
			title = _InternalTranslate(IsT(title) and title or T{title}, self, false)
			if self.in_game then
				self.idTitle:SetText(title)
			else
				terminal.SetOSWindowTitle(title)
			end
		end
		
		-- fetch global data, as needed
		if self.WarningsUpdateRoot then
			self.connection:BindObj("root|warnings_cache", "root", "GedGetCachedDiagnosticMessages")
		end
		if #GetChildrenOfKind(self, "GedPropPanel") > 0 then
			self.connection:BindObj("root|categories", "root", "GedGlobalPropertyCategories")
		end
		if self.PresetClass then
			self.connection:BindObj("root|prop_stats", "root", "GedPresetPropertyUsageStats", self.PresetClass)
		end
		if self.PresetClass or self.AppId == "ModEditor" then
			self.connection:BindObj("root|dirty_objects", "root", "GedGetDirtyObjects")
		end
	end
	if view == "prop_stats" then
		for _, panel in ipairs(self.all_panels) do
			if panel.context and IsKindOf(panel, "GedPropPanel") then
				panel:UpdatePropertyNames(panel.ShowInternalNames)
			end
		end
	end
	self:CheckUpdateItemTexts(view)
end

function GedApp:CheckUpdateItemTexts(view)
	if view == "warnings_cache" or view == "dirty_objects" then
		for _, panel in ipairs(self.all_panels) do
			if panel.context then -- cached detached panels as property editors get recreated by GedPropPanel:RebuildControls
				panel:UpdateItemTexts()
			end
		end
	end
end

function GedApp:SetTitle(title)
	self.Title = title
	self:OnContextUpdate(self.context, nil)
end

function GedApp:AddPanel(context, panel)
	self.all_panels = self.all_panels or {}
	self.all_panels[#self.all_panels + 1] = panel
	
	if panel.Interactive and not panel.Embedded then
		self.interactive_panels = self.interactive_panels or {}
		if not self.interactive_panels[context] then
			local focus_column = 1
			for _, panel in pairs(self.interactive_panels) do
				focus_column = Max(focus_column, panel.focus_column + 1000)
			end
			panel.focus_column = focus_column
			self.interactive_panels[context] = panel
		end
	end
end

function GedApp:RemovePanel(panel)
	table.remove_value(self.all_panels, panel)
	for id, obj in pairs(self.interactive_panels or empty_table) do
		if obj == panel then
			self.interactive_panels[id] = nil
			return
		end
	end
end

function GedApp:SetSelection(panel_context, selection, multiple_selection, notify, restoring_state, focus)
	local panel = self.interactive_panels[panel_context]
	if not panel then return end
	if selection and (notify or restoring_state) then
		panel:CancelSearch("dont_select")
	end
	panel:SetSelection(selection, multiple_selection, notify, restoring_state)
	if not restoring_state then
		panel:SetPanelFocused()
	end
	if focus then
		self.last_focused_panel = panel -- will suppress GedPanelBase:OnSetFocus() which binds the object, selected in the panel
		self.last_focused_tree_or_list_panel = panel
		self:ActionsUpdated()
		panel.idContainer:SetFocus()
	end
end

function GedApp:SetSearchString(panel_context, search_string)
	local panel = self.interactive_panels[panel_context]
	if not panel then return end
	
	if not search_string then
		panel:CancelSearch()
		return
	end
	if panel.idSearchEdit then
		panel.idSearchEdit:SetText(search_string)
		panel:UpdateFilter()
	end
end

function GedApp:SelectSiblingsInFocusedPanel(selection, selected)
	local panel = self.last_focused_panel
	if panel then
		local first_selected, all_selected = panel:GetSelection()
		for _, idx in ipairs(selection) do
			if selected then
				table.insert_unique(all_selected, idx)
			else
				table.remove_value(all_selected, idx)
			end
		end
		panel:SetSelection(first_selected, all_selected, not "notify")
	end
end

function GedApp:SetPropSelection(context, prop_list) -- list with id's to select
	if not context or not self.interactive_panels[context] then return end
	self.interactive_panels[context]:SetSelection(prop_list)
end

function GedApp:SetLastFocusedPanel(panel)
	if self.last_focused_panel ~= panel then
		self.last_focused_panel = panel
		if IsKindOfClasses(panel, "GedTreePanel", "GedListPanel") then
			self.last_focused_tree_or_list_panel = panel
		end
		self:ActionsUpdated()
		return true
	end
end

function GedApp:GetLastFocusedPanel()
	return self.last_focused_panel
end

function GedApp:GetState()
	local state = {}
	if self.interactive_panels and self.window_state ~= "destroying" then
		for context, panel in pairs(self.interactive_panels) do
			state[context] = panel:GetState()
		end
	end
	state.focused_panel = self.last_focused_tree_or_list_panel and self.last_focused_tree_or_list_panel.context
	return state
end

function GedApp:OnMouseButtonDown(pt, button)
	if button == "L" then
		if self.last_focused_panel then
			self.last_focused_panel:SetPanelFocused()
		end
		return "break"
	end
end

function GedApp:OnMouseWheelForward()
	return "break"
end

function GedApp:OnMouseWheelBack()
	return "break"
end

function GedApp:SetActionToggled(action_id, toggled)
	self.actions_toggled[action_id] = toggled
	self:ActionsUpdated()
end

function GedApp:Op(op_name, obj, ...)
	self.connection:Send("rfnOp", self:GetState(), op_name, obj, ...)
end

function GedApp:OnSaving()
	local focus = self.desktop.keyboard_focus
	if focus then
		local prop_editor = GetParentOfKind(focus, "GedPropEditor")
		if prop_editor and not prop_editor.prop_meta.read_only then
			prop_editor:SendValueToGame()
		end
	end
end

function GedApp:Send(rfunc_name, ...) -- for calls that don't modify objects
	self.connection:Send("rfnRunGlobal", rfunc_name, ...)
end

function GedApp:Call(rfunc_name, ...) -- for calls that return a value
	return self.connection:Call("rfnRunGlobal", rfunc_name, ...)
end

function GedApp:InvokeMethod(obj_name, func_name, ...)
	self.connection:Send("rfnInvokeMethod", obj_name, func_name, ...)
end

function GedApp:InvokeMethodReturn(obj_name, func_name, ...) -- for calls that return a value
	return self.connection:Call("rfnInvokeMethod", obj_name, func_name, ...)
end

function GedApp:Undo()
	self.connection:Send("rfnUndo")
end

function GedApp:Redo()
	self.connection:Send("rfnRedo")
end

function GedApp:StoreAppState()
	self.connection:Send("rfnStoreAppState", self:GetState())
end

function GedApp:SelectAndBindObj(name, obj_address, func_name, ...)
	self.connection:Send("rfnSelectAndBindObj", name, obj_address, func_name, ...)
end

function GedApp:SelectAndBindMultiObj(name, obj_address, all_indexes, func_name, ...)
	self.connection:Send("rfnSelectAndBindMultiObj", name, obj_address, all_indexes, func_name, ...)
end

function GedApp:DiscardEditorChanges()
	self:Send("GedDiscardEditorChanges")
end

function GedApp:GetGameError()
	local error_text, error_time = self.connection:Call("rfnGetLastError")
	return error_text, error_time and (error_time - self.game_real_time)
end

function GedApp:ShowMessage(title, text)
	StdMessageDialog:new({}, self.desktop, { title = title, text = text, dark_mode = self.dark_mode }):Open()
end

function GedApp:WaitQuestion(title, text, ok_text, cancel_text)
	local dialog = StdMessageDialog:new({}, self.desktop, {
		title = title or "",
		text = text or "",
		ok_text = ok_text ~= "" and ok_text,
		cancel_text = cancel_text ~= "" and cancel_text,
		translate = false,
		question = true,
		dark_mode = self.dark_mode,
	})
	dialog:Open()
	
	self.ui_questions = self.ui_questions or {}
	table.insert(self.ui_questions, dialog)
	
	local result, win = dialog:Wait()
	if self.ui_questions then
		table.remove_value(self.ui_questions, dialog)
	end
	return result
end

function GedApp:DeleteQuestion() -- cancel is already taken as the default "answer"
	local question = self.ui_questions and self.ui_questions[1]
	if question then
		question:Close("delete") -- the waiting thread should remove it form the list
	end
end

function GedApp:WaitUserInput(title, default, items)
	local dialog = StdInputDialog:new({}, self.desktop, { title = title, default = default, items = items, dark_mode = self.dark_mode })
	dialog:Open()
	local result, win = dialog:Wait()
	return result
end

function GedApp:WaitListChoice(items, caption, start_selection, lines)
	local dialog = StdInputDialog:new({}, terminal.desktop, { title = caption, default = start_selection, items = items, lines = lines } )
	dialog:Open()
	local result, win = dialog:Wait()
	return result
end

function GedApp:SetUiStatus(id, text, delay)
	local idx = table.find(self.ui_status, "id", id) or (#self.ui_status + 1)
	if not text then
		table.remove(self.ui_status, idx)
	else
		self.ui_status[idx] = { id = id, text = text }
	end
	self:UpdateUiStatus()
	if delay then
		self.ui_status_delay_time = RealTime() + delay
		if not self.ui_status_delay_thread then
			self.ui_status_delay_thread = CreateRealTimeThread(function()
				while self.ui_status_delay_time - RealTime() > 0 do
					Sleep(self.ui_status_delay_time - RealTime())
				end
				self:SetUiStatus(id)
				self.ui_status_delay_thread = nil
			end)
		end
	end
end

function GedApp:WaitBrowseDialog(folder, filter, create, multiple)
	return OpenBrowseDialog(folder, filter or "", not not create, not not multiple)
end

function GedApp:GedOpError(error_message)
	if not self.blink_thread then
		self.blink_thread = CreateRealTimeThread(function()
			for i = 1, 3 do
				self.blink_border_color = RGB(220, 0, 0)
				self:Invalidate()
				Sleep(50)
				self.blink_border_color = RGBA(0, 0, 0, 0)
				self:Invalidate()
				Sleep(50)
			end
			self.blink_border_color = nil
			self.blink_thread = nil
			self:Invalidate()
		end)
	end
	if type(error_message) == "string" and error_message ~= "error" and error_message ~= "" then
		self:ShowMessage("Error", error_message)
	end
end

function GedApp:DrawChildren(clip_box)
	XActionsHost.DrawChildren(self, clip_box)
	if self.blink_border_color ~= RGBA(0, 0, 0, 0) then
		local box = (self:GetLastFocusedPanel() or self).box
		UIL.DrawBorderRect(box, 2, 2, self.blink_border_color, RGBA(0, 0, 0, 0))
	end
end

function GedApp:GetDisplayedSearchResultData()
	return self.display_search_result and self.search_value_results and self.search_value_results[self.search_result_idx]
end

function GedApp:TryHighlightSearchMatchInChildPanels(parent_panel)
	if not parent_panel.SelectionBind then return end
	for bind in string.gmatch(parent_panel.SelectionBind .. ",", reCommaList) do
		local bind_dot = bind .. "."
		for _, panel in ipairs(self.all_panels) do
			local context = panel.context
			if panel.window_state ~= "destroying" and context and (context == bind or context:starts_with(bind_dot)) then
				panel:TryHighlightSearchMatch()
			end
		end
	end	
end

function GedApp:FocusProperty(panel_id, prop_id)
	local panel = self.interactive_panels[panel_id]
	local prop_editor = panel and panel:LocateEditorById(prop_id)
	if prop_editor then
		local focus = prop_editor:GetRelativeFocus(point(0, 0), "next") or prop_editor
		focus:SetFocus()
	end
end

function GedApp:OpenContextMenu(action_context, anchor_pt)
	if not action_context or not anchor_pt or action_context == "" then return end
	local menu = XPopupMenu:new({
		ActionContextEntries = action_context,
		Anchor = anchor_pt,
		AnchorType = "mouse",
		MaxItems = 12,
		GetActionsHost = function() return self end,
		popup_parent = self,
		RebuildActions = function(menu, host)
			XPopupMenu.RebuildActions(menu, host)
			for _, entry in ipairs(menu.idContainer) do
				if entry.action.OnActionEffect == "popup" then
					XLabel:new({
						Dock = "right",
						ZOrder = -1,
						Margins = box(5, 0, 0, 0),
					}, entry):SetText(">")
				end
			end
		end,
	}, terminal.desktop)
	menu:Open()
	return menu
end

----- Dark Mode support

function GetDarkModeSetting()
	local setting = rawget(_G, "g_GedApp") and g_GedApp.dark_mode
	if setting == "Follow system" then
		return GetSystemDarkModeSetting()
	else
		return setting and setting ~= "Light"
	end
end

local menubar = RGB(64, 64, 64)
local l_menubar = RGB(255, 255, 255) 

local menu_selection = RGB(100, 100, 100)
local l_menu_selection = RGB(204, 232, 255)

local toolbar = RGB(64, 64, 64)
local l_toolbar = RGB(255, 255, 255)

local panel = RGB(42, 41, 41)
local panel_title = RGB(64, 64, 64)
local panel_background_tab = RGB(96, 96, 96)
local panel_rollovered_tab = RGB(110, 110, 110)
local panel_child = RGBA(0, 0, 0, 0)
local panel_focused_border = RGB(100, 100, 100)

local l_panel = RGB(255, 255, 255)
local l_panel_title = RGB(220, 220, 220)
local l_panel_background_tab = RGB(196, 196, 196)
local l_panel_rollovered_tab = RGB(240, 240, 240)
local l_panel_child = RGBA(0, 0, 0, 0)
local l_panel_focused_border = RGB(0, 0, 0)

local l_prop_button_focused =  RGB(24, 123, 197)
local l_prop_button_rollover = RGB(24, 123, 197)
local l_prop_button_pressed =  RGB(38, 146, 227)
local l_prop_button_disabled = RGB(128, 128, 128)
local l_prop_button_background = RGB(38, 146, 227)

local prop_button_focused =  RGB(193, 193, 193)
local prop_button_rollover = RGB(100, 100, 100)
local prop_button_pressed =  RGB(105, 105, 105)
local prop_button_disabled = RGB(93, 93, 93)
local prop_button_background = RGB(105, 105, 105)

local scroll = RGB(131, 131, 131)
local scroll_pressed = RGB(211, 211, 211)
local scroll_rollover = RGB(170, 170, 170)
local scroll_background = RGB(64, 64, 64)
local button_divider = RGB(100, 100, 100)

local l_scroll = RGB(169, 169, 169)
local l_scroll_pressed = RGB(100, 100, 100)
local l_scroll_rollover = RGB(128, 128, 128)
local l_scroll_background = RGB(240, 240, 240)
local l_button_divider = RGB(169, 169, 169)

local edit_box = RGB(54, 54, 54)
local edit_box_border = RGB(130, 130, 130)
local edit_box_focused = RGB(42, 41, 41)

local l_edit_box = RGB(240, 240, 240)
local l_edit_box_border = RGB(128, 128, 128)
local l_edit_box_focused = RGB(255, 255, 255)

local propitem_selection = RGB(20, 109, 171)
local subobject_selection = RGB(40, 50, 70)
local panel_item_selection = RGB(70, 70, 70)

local l_propitem_selection = RGB(121, 189, 241)
local l_subobject_selection = RGB(204, 232, 255)
local l_panel_item_selection = RGB(204, 232, 255)

local button_border = RGB(130, 130, 130)
local button_pressed_background = RGB(191, 191, 191)
local button_toggled_background = RGB(150, 150, 150)
local button_rollover = RGB(70, 70, 70)

local l_button_border = RGB(240, 240, 240)
local l_button_pressed_background = RGB(121, 189, 241)
local l_button_toggled_background = RGB(35, 97, 171)
local l_button_rollover = RGB(204, 232, 255)

local checkbox_color = RGB(128, 128, 128)
local checkbox_disabled_color = RGBA(128, 128, 128, 128)

function GedApp:UpdateChildrenDarkMode(win)
	if win.window_state ~= "destroying" then
		self:UpdateControlDarkMode(win)
		if not IsKindOfClasses(win, "XMenuBar", "XToolBar", "GedPanelBase", "GedPropSet") then
			for _, child in ipairs(win or self) do
				self:UpdateChildrenDarkMode(child)
			end
		end
	end
end

local function SetUpTextStyle(control, dark_mode)
	local new_style = GetTextStyleInMode(rawget(control, "TextStyle"), dark_mode)
	if new_style then
		control:SetTextStyle(new_style)
	elseif control.TextStyle:starts_with("GedDefault") then
		control:SetTextStyle(dark_mode and "GedDefaultDark" or "GedDefault")
	elseif control.TextStyle:starts_with("GedSmall") then
		control:SetTextStyle(dark_mode and "GedSmallDark" or "GedSmall")
	end
end

local function SetUpDarkModeButton(button, dark_mode)
	SetUpTextStyle(button, dark_mode)
	button:SetBackground(dark_mode and prop_button_background or l_prop_button_background)
	button:SetFocusedBackground(dark_mode and prop_button_focused or l_prop_button_focused)
	button:SetRolloverBackground(dark_mode and prop_button_rollover or l_prop_button_rollover)
	button:SetPressedBackground(dark_mode and prop_button_pressed or l_prop_button_pressed)
	button:SetDisabledBackground(dark_mode and prop_button_disabled or l_prop_button_disabled)
end

local function SetUpDarkModeSetItem(button, dark_mode)
	SetUpTextStyle(button, dark_mode)
	button:SetBackground(RGBA(0, 0, 0, 0))
	if dark_mode and not button:GetEnabled() then
		button:SetToggledBackground(dark_mode and prop_button_disabled or l_propitem_selection)
		button:SetDisabledBackground(dark_mode and RGBA(0, 0, 0, 0) or l_prop_button_disabled)
	else
		button:SetFocusedBackground(dark_mode and prop_button_focused or l_prop_button_focused)
		button:SetPressedBackground(dark_mode and propitem_selection or l_propitem_selection)
		button:SetToggledBackground(dark_mode and propitem_selection or l_propitem_selection)
		button:SetDisabledBackground(dark_mode and prop_button_disabled or l_prop_button_disabled)
	end
end

local function SetUpIconButton(button, dark_mode)
	button.idIcon:SetImageColor(dark_mode and RGB(210, 210, 210) or button.parent.Id == "idNumberEditor" and RGB(0, 0, 0) or nil)
	button:SetBackground(RGBA(0, 0, 0, 1)) -- 1 is used as alpha because we don't touch control with color == 0
	if IsKindOf(button, "XCheckButton") then
		button:SetBorderColor(RGBA(0, 0, 0, 0))
		button:SetIconColor(dark_mode and checkbox_color or RGB(0, 0, 0))
		button:SetDisabledIconColor(checkbox_disabled_color)
	else
		button:SetRolloverBorderColor(dark_mode and button_border or l_button_border)
		button:SetRolloverBackground(dark_mode and button_rollover or l_button_rollover)
		button:SetPressedBackground(dark_mode and button_pressed_background or l_button_pressed_background)
		
		if IsKindOf(button, "XToggleButton") and button:GetToggledBackground() == button:GetDefaultPropertyValue("ToggledBackground") then
			button:SetToggledBackground(dark_mode and button_toggled_background or l_button_toggled_background)
		end
		
		-- Set border color if it hasn't been manually set
		local border_color = button:GetBorderColor()
		local other_mode_border_color = not dark_mode and button_border or l_button_border
		if border_color == button:GetDefaultPropertyValue("BorderColor") or border_color == other_mode_border_color then
			button:SetBorderColor(dark_mode and button_border or l_button_border)
		end
	end
end

function GedApp:UpdateControlDarkMode(control)
	local dark_mode = self.dark_mode
	local new_style = GetTextStyleInMode(rawget(control, "TextStyle"), dark_mode)
	
	if IsKindOf(control, "XRolloverWindow") and IsKindOf(control[1], "XText") then
		control[1].invert_colors = true
	end
	if control.Id == "idPopupBackground" then
		control:SetBackground(dark_mode and RGB(54, 54, 54) or RGB(240, 240, 240))
	end
	if IsKindOf(control, "GedApp") then
		control:SetBackground(dark_mode and button_divider or nil)
	end
	if IsKindOf(control, "GedPropEditor") then
		control.SelectionBackground = dark_mode and panel_item_selection or l_panel_item_selection
	end
	if IsKindOf(control, "XList") then
		control:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		control:SetFocusedBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		control:SetBackground(dark_mode and panel or l_panel)
		control:SetFocusedBackground(dark_mode and panel or l_panel)
	end
	if IsKindOf(control, "XListItem") then
		local prop_editor = GetParentOfKind(control, "GedPropEditor")
		if prop_editor and not IsKindOfClasses(prop_editor, "GedPropPrimitiveList", "GedPropEmbeddedObject") then
			control:SetSelectionBackground(dark_mode and propitem_selection or l_propitem_selection)
		else
			control:SetSelectionBackground(dark_mode and panel_item_selection or l_panel_item_selection)
		end
		control:SetFocusedBorderColor(dark_mode and panel_focused_border or l_panel_focused_border)
	end
	
	if IsKindOf(control, "XMenuBar") then
		control:SetBackground(dark_mode and menubar or l_menubar)
		for _, menu_item in ipairs(control) do
			SetUpTextStyle(menu_item.idLabel, dark_mode)
			menu_item:SetRolloverBackground(dark_mode and menu_selection or l_menu_selection)
			menu_item:SetPressedBackground(dark_mode and menu_selection or l_menu_selection)
		end
		return
	end
	if IsKindOf(control, "ShortcutEditor") then
		control:SetBackground(dark_mode and menubar or l_menubar)
		control:SetFocusedBackground(dark_mode and menubar or l_menubar)
		for _, win in ipairs(control.idContainer.idModifiers) do
			if IsKindOf(win, "XToggleButton") then
				SetUpDarkModeSetItem(win, dark_mode)
			end
		end
		return
	end
	if IsKindOf(control, "XPopup") then
		control:SetBackground(dark_mode and menubar or l_menubar)
		control:SetFocusedBackground(dark_mode and menubar or l_menubar)
		for _, entry in ipairs(control.idContainer) do
			if entry:IsKindOf("XButton") then
				entry:SetRolloverBackground(dark_mode and menu_selection or l_menu_selection)
			end
		end
		return
	end 
	if IsKindOf(control, "XToolBar") then
		control:SetBackground(dark_mode and toolbar or l_toolbar)
		for _, toolbar_item in ipairs(control) do
			-- divider line betweeen action buttons
			if not IsKindOf(toolbar_item, "XTextButton") and not IsKindOf(toolbar_item, "XToggleButton") then
				toolbar_item:SetBackground(dark_mode and button_divider or l_button_divider)
			else
				SetUpIconButton(toolbar_item, dark_mode)
			end
		end
		return
	end
	if IsKindOf(control, "GedPropSet") then
		self:UpdateChildrenDarkMode(control.idLabelHost)
		control.idContainer:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		for _, win in ipairs(control.idContainer) do
			if IsKindOf(win, "XToggleButton") then
				SetUpDarkModeSetItem(win, dark_mode)
			else 
				self:UpdateChildrenDarkMode(win)
			end
		end
		return
	end
	if IsKindOf(control, "GedPropScript") then
		control.idEditHost:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		return
	end
	if IsKindOf(control, "XCurveEditor") then
		control:SetCurveColor(dark_mode and l_scroll or nil)
		control:SetControlPointColor(dark_mode and l_scroll or nil)
		control:SetControlPointHoverColor(dark_mode and button_divider or nil)
		control:SetControlPointCaptureColor(dark_mode and scroll_background or nil)
		control:SetGridColor(dark_mode and scroll_background or nil)
		return
	end
	if IsKindOf(control, "GedPanelBase") then
		if control.Id == "idStatusBar" then
			control:SetBackground(dark_mode and panel_title or l_panel_title)
		else
			control:SetBackground(dark_mode and panel or l_panel)
		end
		if control:ResolveId("idTitleContainer") then
			control.idTitleContainer:SetBackground(dark_mode and panel_title or l_panel_title)
			control.idTitleContainer:ResolveId("idTitle"):SetTextStyle(new_style or GetTextStyleInMode(control.Embedded and "GedDefault" or "GedTitleSmall", dark_mode))
		end
		if control:ResolveId("idSearchResultsText") then
			control:ResolveId("idSearchResultsText"):SetTextStyle(GetTextStyleInMode("GedDefault", dark_mode))
		end
		for _, child_control in ipairs(control) do 
			if	child_control.Id == "idContainer" then
				if child_control:HasMember("TextStyle") then
					SetUpTextStyle(child_control, dark_mode)
				end
				if child_control:HasMember("FocusedBackground") then
					child_control:SetFocusedBackground(dark_mode and panel_child or l_panel_child)
				end
				if child_control:HasMember("SelectionBackground") then
					child_control:SetSelectionBackground(dark_mode and panel_item_selection or l_panel_item_selection)
					child_control:SetFocusedBorderColor(dark_mode and panel_focused_border or l_panel_focused_border)
				end
				child_control:SetBackground(dark_mode and panel_child or l_panel_child)
				
				if IsKindOfClasses(control, "GedPropPanel", "GedTreePanel") then
					local noProps = control.idContainer:ResolveId("idNoPropsToShow")
					if noProps then
						SetUpTextStyle(noProps, dark_mode)
					else
						control:SetFocusedBackground(dark_mode and panel or l_panel)
						local container = control.idContainer
						for _, prop_win in ipairs(container) do
							for _, prop_child in ipairs(prop_win) do
								if IsKindOf(prop_child, "XTextButton") then
									SetUpDarkModeButton(prop_child, dark_mode)
								else
									self:UpdateChildrenDarkMode(prop_child)
								end
							end
						end
						for _, control in ipairs(control.idTitleContainer) do
							if IsKindOf(control, "XTextButton") then
								SetUpIconButton(control, dark_mode)
							end
						end
					end
				elseif IsKindOf(control, "GedBreadcrumbPanel") then
					local container = control.idContainer
					for _, win in ipairs(container) do
						if IsKindOf(win, "XButton") then
							win:SetRolloverBackground(dark_mode and RGB(72, 72, 72) or l_button_rollover)
							SetUpTextStyle(win[1], dark_mode)
						end
					end
				elseif IsKindOf(control, "GedTextPanel") then
					control.idContainer:SetTextStyle(new_style or GetTextStyleInMode("GedTextPanel", dark_mode))
				else
					self:UpdateChildrenDarkMode(child_control)
				end	
			elseif child_control.Id == "idTitleContainer" then
				local search = control:ResolveId("idSearchContainer")
				search:SetBackground(RGBA(0, 0, 0, 0))
				search:SetBorderColor(dark_mode and panel_focused_border or l_panel_focused_border)
				
				local edit = control:ResolveId("idSearchEdit")
				self:UpdateEditControlDarkMode(edit, dark_mode)
				edit:SetTextStyle(new_style or GetTextStyleInMode("GedDefault", dark_mode))
				edit:SetBackground(dark_mode and edit_box_focused or l_edit_box_focused)
				edit:SetHintColor(dark_mode and RGBA(210, 210, 210, 128) or nil)
				
				SetUpIconButton(control:ResolveId("idToggleSearch"), dark_mode)
				SetUpIconButton(control:ResolveId("idCancelSearch"), dark_mode)
				SetUpDarkModeButton(control:ResolveId("idSearchHistory"), dark_mode)
				
				for _, tab_button in ipairs(control.idTabContainer) do
					tab_button:SetToggledBackground(dark_mode and panel or l_panel)
					tab_button:SetToggledBorderColor(dark_mode and panel or l_panel)
					tab_button:SetBackground(dark_mode and panel_background_tab or l_panel_background_tab)
					tab_button:SetPressedBackground(dark_mode and panel_rollovered_tab or l_panel_rollovered_tab)
					tab_button:SetRolloverBackground(dark_mode and panel_rollovered_tab or l_panel_rollovered_tab)
					tab_button:SetBorderColor(dark_mode and panel_title or l_panel_title)
					tab_button:SetRolloverBorderColor(dark_mode and panel_title or l_panel_title)
					tab_button:SetTextStyle(dark_mode and "GedButton" or "GedDefault")
				end
			elseif IsKindOf(child_control, "XSleekScroll") then
				child_control.idThumb:SetBackground(dark_mode and scroll or l_scroll)
				child_control:SetBackground(dark_mode and scroll_background or l_scroll_background)
			elseif child_control.Id ~= "idViewErrors" and child_control.Id ~= "idPauseResume" then
				self:UpdateChildrenDarkMode(child_control)
			end
		end
		return
	end

	if control.Id == "idPanelDockedButtons" then
		control:SetBackground(dark_mode and panel_title or l_panel_title)
		return
	end
	
	if IsKindOf(control, "XRangeScroll") then
		control:SetThumbBackground(dark_mode and scroll or l_scroll)
		control:SetThumbRolloverBackground(dark_mode and scroll_rollover or l_scroll_rollover)
		control:SetThumbPressedBackground(dark_mode and scroll_pressed or l_scroll_pressed)
		control.idThumbLeft:SetBackground(dark_mode and scroll or l_scroll)
		control.idThumbRight:SetBackground(dark_mode and scroll or l_scroll)
		control:SetScrollColor(dark_mode and scroll or l_scroll)
		control:SetBackground(dark_mode and scroll_background or l_scroll_background)
	end

	if IsKindOf(control, "XTextButton") then
		SetUpIconButton(control, dark_mode)
	end
	if IsKindOf(control, "XFontControl") then
		if control.Id == "idWarningText" then
			return
		end
		SetUpTextStyle(control, dark_mode)
	end	
	if IsKindOf(control, "XCombo") or IsKindOf(control, "XCheckButtonCombo") then
		control:SetBackground(dark_mode and edit_box or l_edit_box)
		control:SetFocusedBackground(dark_mode and edit_box or l_edit_box)
		control:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		control:SetFocusedBorderColor(dark_mode and edit_box_border or l_edit_box_border)
		if IsKindOf(control, "XCombo") and (control:GetListItemTemplate() == "XComboListItemDark" or control:GetListItemTemplate() == "XComboListItemLight") then
			control:SetListItemTemplate(dark_mode and "XComboListItemDark" or "XComboListItemLight")
			control.PopupBackground = dark_mode and panel or l_panel
		end
	end	
	if IsKindOf(control, "XComboButton") then
		SetUpDarkModeButton(control, dark_mode)
	end	
	if IsKindOf(control, "XScrollArea") and not IsKindOf(control, "XMultiLineEdit") and not IsKindOf(control, "XList") then
		control:SetBackground(dark_mode and panel or l_panel)
	end
	if IsKindOf(control, "XMultiLineEdit") then
		if GetParentOfKind(control, "GedMultiLinePanel") then
			control:SetTextStyle(new_style or GetTextStyleInMode("GedMultiLine", dark_mode))
		else
			control:SetTextStyle(new_style or GetTextStyleInMode("GedDefault", dark_mode))
			if control.parent.Id == "idEditHost" then
				control.parent:SetBorderColor(dark_mode and edit_box_border or l_edit_box_border)
			end
		end
		self:UpdateEditControlDarkMode(control, dark_mode)
	end
	if IsKindOf(control, "XEdit") then
		control:SetTextStyle(new_style or GetTextStyleInMode("GedDefault", dark_mode))
		self:UpdateEditControlDarkMode(control, dark_mode)
	end
	if IsKindOf(control, "XTextEditor") then
		control:SetHintColor(dark_mode and RGBA(210, 210, 210, 128) or nil)
	end
	if IsKindOf(control, "XSleekScroll") then
		control.idThumb:SetBackground(dark_mode and scroll or l_scroll)
		control:SetBackground(dark_mode and scroll_background or l_scroll_background)
	end
	if IsKindOf(control, "XToggleButton") and control.Id == "idInputListener" then
		control:SetPressedBackground(dark_mode and propitem_selection or l_propitem_selection)
		control:SetToggledBackground(dark_mode and propitem_selection or l_propitem_selection)
	end
end

function OnMsg.GedPropertyUpdated(property)
	if IsKindOf(property, "GedPropSet") then
		GetParentOfKind(property, "GedApp"):UpdateChildrenDarkMode(property)
	end
end


----- GedBindView

DefineClass.GedBindView = {
	__parents = { "XContextWindow" },
	Dock = "ignore",
	visible = false,
	properties = {
		{ category = "General", id = "BindView", editor = "text", default = "", },
		{ category = "General", id = "BindRoot", editor = "text", default = "", },
		{ category = "General", id = "BindField", editor = "text", default = "", },
		{ category = "General", id = "BindFunc", editor = "text", default = "", },
		{ category = "General", id = "ControlId", editor = "text", default = "", },
		{ category = "General", id = "GetBindParams", editor = "expression", params = "self, control", },
		{ category = "General", id = "OnViewChanged", editor = "func", params = "self, value, control", },
	},
	MinWidth = 0,
	MinHeight = 0,
}

function GedBindView:Open(...)
	XContextWindow.Open(self, ...)
	self.app = GetParentOfKind(self.parent, "GedApp")
end

function GedBindView:Done()
	local connection = self.app and self.app.connection
	if connection then
		connection:UnbindObj(self.context .. "|" .. self.BindView)
	end
end

function GedBindView:GetBindParams(control)
end

function GedBindView:OnContextUpdate(context, view)
	self.app = self.app or GetParentOfKind(self.parent, "GedApp")
	local connection = self.app and self.app.connection
	if not connection then return end
	if not view and self.BindView ~= "" then -- obj changed
		local path = self.BindRoot == "" and context or self.BindRoot
		if self.BindField ~= "" then
			path = {path, self.BindField}
		end
		connection:BindObj(context .. "|" .. self.BindView, path, self.BindFunc ~= "" and self.BindFunc, self:GetBindParams(self:ResolveId(self.ControlId)))
	end
	if view == self.BindView or (self.BindView == "") then -- view changed
		local name = self.BindView ~= "" and context .. "|" .. self.BindView or context
		local value = connection.bound_objects[name]
		self:OnViewChanged(value, self:ResolveId(self.ControlId))
	end
end

function GedBindView:OnViewChanged(value, control)
end

function RebuildSubItemsActions(panel, actions_def, default_submenu, toolbar, menubar)
	local host = GetActionsHost(panel)
	local actions = host:GetActions()
	for i = #(actions or ""), 1, -1 do
		local action = actions[i]
		if action.ActionId:starts_with("NewItemEntry_") or action.ActionId:starts_with("NewSubitemMenu_") then
			host:RemoveAction(action)
		end
	end
	
	if type(actions_def) == "table" and #actions_def > 0 then
		local submenus = {}
		for _, def in ipairs(actions_def) do
			local submenu = def.EditorSubmenu or default_submenu
			if submenu ~= "" then
				submenus[submenu] = true
				XAction:new({
					ActionId = "NewItemEntry_" .. def.Class,
					ActionMenubar = "NewSubitemMenu_" .. submenu,
					ActionToolbar = def.EditorIcon and toolbar,
					ActionIcon = def.EditorIcon,
					ActionName = def.EditorName or def.Class,
					ActionTranslate = false,
					ActionShortcut = def.EditorShortcut,
					OnActionParam = def.Class,
					OnAction = function(self, host, source)
						if panel:IsKindOf("GedTreePanel") then
							host:Op("GedOpTreeNewItemInContainer", panel.context, panel:GetSelection(), self.OnActionParam)
						else
							host:Op("GedOpListNewItem", panel.context, panel:GetSelection(), self.OnActionParam)
						end
					end,
				}, host)
			end
		end
		
		for submenu in sorted_pairs(submenus) do
			XAction:new({
				ActionId = "NewSubitemMenu_" .. submenu,
				ActionMenubar = menubar,
				ActionName = submenu,
				ActionTranslate = false,
				ActionSortKey = "2",
				OnActionEffect = "popup",
				ActionContexts = { "ContentPanelAction", "ContentRootPanelAction", "ContentChildPanelAction" },
			}, host)
		end
	end
end