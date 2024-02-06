--[[@@@
@class XAction
Defines a UI action, which can be bound to buttons or used on its own.
Always initialize it with a parent or if that is not possible, call RegisterInHost afterwards with the correct XActionsHost
]]
DefineClass.XAction = {
	__parents = { "XRollover" },
	properties = {
		{ category = "Action", id = "ActionId", editor = "text", default = "" },
		{ category = "Action", id = "ActionMode", editor = "text", default = "" },
		{ category = "Action", id = "InheritedActionModes", editor = "text", default = "", read_only = true, help = "ActionModes inherited from parent if ActionMode is empty", dont_save = true },
		{ category = "Action", id = "ActionSortKey", editor = "text", default = "",
		  buttons = { { name = "Rebuild", func = "RebuildSortKeys" } },
		},
		{ category = "Action", id = "ActionTranslate", editor = "bool", default = true, },
		{ category = "Action", id = "ActionName", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, },
		{ category = "Action", id = "ActionDescription", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, },
		{ category = "Action", id = "ActionIcon", editor = "ui_image", default = "", },
		{ category = "Action", id = "ActionMenubar", editor = "text", default = "", },
		{ category = "Action", id = "ActionToolbar", editor = "text", default = "" },
		{ category = "Action", id = "ActionToolbarSplit", editor = "bool", default = false },
		{ category = "Action", id = "ActionToolbarSection", editor = "text", default = "" },
		{ category = "Action", id = "ActionUIStyle", editor = "choice", default = "auto", items = {"auto", "gamepad", "keyboard"}, }, 
		{ category = "Action", id = "ActionShortcut", editor = "shortcut", default = "" },
		{ category = "Action", id = "ActionShortcut2", editor = "shortcut", default = "" },
		{ category = "Action", id = "ActionGamepad", editor = "shortcut", shortcut_type = "gamepad", default = "" },
		{ category = "Action", id = "ActionGamepadHold", editor = "bool", default = false },
		{ category = "Action", id = "ActionBindable", editor = "bool", default = false },
		{ category = "Action", id = "ActionMouseBindable", editor = "bool", default = true },
		{ category = "Action", id = "ActionBindSingleKey", editor = "bool", default = false },
		{ category = "Action", id = "BindingsMenuCategory", editor = "text", default = "Default" },
		{ category = "Action", id = "ActionButtonTemplate", editor = "choice", default = false, items = function() return XTemplateCombo("XButton") end, },
		{ category = "Action", id = "ActionToggle", editor = "bool", default = false },
		{ category = "Action", id = "ActionToggled", editor = "func", params = "self, host", read_only = function(self) return not self:GetProperty("ActionToggle") end, },
		{ category = "Action", id = "ActionToggledIcon", editor = "ui_image", default = "", read_only = function(self) return not self:GetProperty("ActionToggle") end, },
		{ category = "Action", id = "ActionState", editor = "func", params = "self, host" },
		{ category = "Action", id = "OnActionEffect", editor = "choice", default = "", items = {"", "popup", "back", "close", "mode"}, },
		{ category = "Action", id = "OnActionParam", editor = "text", default = "" },
		{ category = "Action", id = "OnAction", editor = "func", params = "self, host, source, ...", },
		{ category = "Action", id = "OnShortcutUp", editor = "func", params = "self, host, source, ...", default = false },
		{ category = "Action", id = "OnAltAction", editor = "func", params = "self, host, source, ...", default = false},
		{ category = "Action", id = "IgnoreRepeated", editor = "bool", default = false },
		{ category = "Action", id = "ActionContexts", editor = "string_list", default = false }, 
		
		{ category = "FX", id = "FXMouseIn", editor = "text", default = "", },
		{ category = "FX", id = "FXPress", editor = "text", default = "", },
		{ category = "FX", id = "FXPressDisabled", editor = "text", default = "", },
		
		-- properties of XRollover should regard ActionTranslate
		{ category = "Rollover", id = "RolloverTranslate", editor = false },
		{ category = "Rollover", id = "RolloverAnchor", editor = false },
		{ category = "Rollover", id = "RolloverText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, lines = 3, },
		{ category = "Rollover", id = "RolloverDisabledText", editor = "text", default = "", translate = function(obj) return obj:GetProperty("ActionTranslate") end, lines = 3, },
	},
	
	-- the default values are needed when saving and loading from AccountStorage
	default_ActionShortcut = false,
	default_ActionShortcut2 = false,
	default_ActionGamepad = false,
	
	shortcut_up_thread = false,
	host = false,
	
	multi_mode_cache = false
}

function XAction:RegisterInHost(host, replace_matching_id)
	self.host = host
	if host then host:_InternalAddAction(self, replace_matching_id) end
	self:BindShortcuts()
	
	if self.OnShortcutUp and host and self.OnAction ~= XAction.OnAction then
		local oldAction = self.OnAction
		self.OnAction = function(self, ...)
			oldAction(self, ...)
			
			local keyOne = self.ActionShortcut and VKStrNamesInverse[self.ActionShortcut]
			local keyTwo = self.ActionShortcut2 and VKStrNamesInverse[self.ActionShortcut2]
			local downKey = (keyOne and terminal.IsKeyPressed(keyOne) and keyOne) or (keyTwo and terminal.IsKeyPressed(keyTwo) and keyTwo)
			
			if IsValidThread(self.shortcut_up_thread) then
				DeleteThread(self.shortcut_up_thread)
			end
			self.shortcut_up_thread = CreateRealTimeThread(function(self, ...)
				while downKey and terminal.IsKeyPressed(downKey) and not terminal.desktop.inactive do
					Sleep(16)
				end
				self.OnShortcutUp(self, ...)
			end, self, ...)
		end
	end
end

function XAction:Init(parent, context, replace_matching_id)
	self:RegisterInHost(GetActionsHost(parent), replace_matching_id)
end

function XAction:BindShortcuts()
	self.default_ActionShortcut = self.ActionShortcut
	self.default_ActionShortcut2 = self.ActionShortcut2
	self.default_ActionGamepad = self.ActionGamepad
	if self.ActionBindable then
		local bindings = AccountStorage and AccountStorage.Shortcuts[self.ActionId]
		if bindings then
			self:SetActionShortcuts(bindings[1] or self.ActionShortcut, bindings[2] or self.ActionShortcut2, bindings[3] or self.ActionGamepad)
		end
	end
end

local function RemoveShortcut(action, name, shortcut)
	shortcut = shortcut or ""
	local old_shortcut = action[name]
	if shortcut == old_shortcut then
		-- no change
		return
	end
	
	action[name] = nil
	local host = action.host
	if not host then return end
	
	-- unregister old shortcut
	host:CallHostParents("RemoveShortcutToAction", action, old_shortcut)
end

local function AddShortcut(action, name, shortcut)
	shortcut = shortcut or ""
	local old_shortcut = action[name]
	if shortcut == old_shortcut then
		-- no change
		return
	end
	
	action[name] = shortcut
	local host = action.host
	if not host then return end
	
	-- register new one
	host:CallHostParents("AddShortcutToAction", action, shortcut)
end

function XAction:SetActionShortcuts(shortcut, shortcut2, shortcut_gamepad)
	-- remove old shortcuts before adding any of the new ones
	RemoveShortcut(self, "ActionShortcut", shortcut)
	RemoveShortcut(self, "ActionShortcut2", shortcut2)
	RemoveShortcut(self, "ActionGamepad", shortcut_gamepad)
	-- add new shortcuts
	AddShortcut(self, "ActionShortcut", shortcut)
	AddShortcut(self, "ActionShortcut2", shortcut2)
	AddShortcut(self, "ActionGamepad", shortcut_gamepad)
end

function XAction:SetActionMenubar(menubar)
	local host = self.host
	if host and self.ActionMenubar ~= menubar then
		host:CallHostParents("RemoveMenubarAction", self)
	end
	self.ActionMenubar = menubar
	if not host then return end
	host:CallHostParents("AddMenubarAction", self)
end

function XAction:SetActionToolbar(toolbar)
	local host = self.host
	if host and self.ActionToolbar ~= toolbar then
		host:CallHostParents("RemoveToolbarAction", self)
	end
	self.ActionToolbar = toolbar
	if not host then return end
	host:CallHostParents("AddToolbarAction", self)
end

function XAction:SetActionSortKey(sort_key)
	self.ActionSortKey = sort_key
	if not self.host then return end
	self.host:InvalidateActionSortKey(self)
end

function XAction:ActionState(host)
end

function XAction:ActionToggled(host)
end

function XAction:OnAction(host, source, ...)
	local effect = self.OnActionEffect
	local param = self.OnActionParam
	if effect == "close" and host and host.window_state ~= "destroying" then
		host:Close(param ~= "" and param or nil, source, ...)
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
end

function XAction:OnXTemplateSetProperty(prop_id, old_value)
	-- toggle text properties between Ts and strings when ActionTranslate is edited
	if prop_id == "ActionTranslate" then
		self:UpdateLocalizedProperty("ActionName", self.ActionTranslate)
		self:UpdateLocalizedProperty("RolloverText", self.ActionTranslate)
		self:UpdateLocalizedProperty("RolloverDisabledText", self.ActionTranslate)
		ObjModified(self)
	end
	if prop_id == "ActionSortKey" and self.ActionSortKey ~= "" then
		local preset = GetParentTableOfKind(self, "XTemplate")
		preset.RequireActionSortKeys = true
	end
end

function XAction:EnabledInMode(mode)
	local myMode = self.ActionMode
	if myMode == "" then return true end
	if mode == myMode then return true end

	if not self.multi_mode_cache or self.multi_mode_cache.strsrc ~= myMode then
		local modeCache = { strsrc = myMode }
		for str in string.gmatch(myMode, "([%w%-_]+)") do
			modeCache[str] = true
		end
		self.multi_mode_cache = modeCache
	end
	return self.multi_mode_cache[mode]
end

local function assign_sortkeys(node, sortkey)
	if node:IsKindOf("XTemplateAction") and node.ActionId ~= "" then
		if node.ActionSortKey ~= "" then
			print("Overwriting SortKey of", node.ActionId, "to", node.ActionSortKey)
		end
		node:SetActionSortKey(tostring(sortkey * 10))
		sortkey = sortkey + 1
	end
	for _, item in ipairs(node) do
		sortkey = assign_sortkeys(item, sortkey)
	end
	return sortkey
end

function XAction:RebuildSortKeys(root, prop_id, ged, btn_param)
	if ged:WaitQuestion("Rebuild SortKeys", "This will assign SortKeys to each Action in the current file, in the order\nthey appear, overwriting existing ones.\n\nContinue?", "OK", "Cancel") ~= "ok" then
		return
	end
	assign_sortkeys(root, 100) -- start from 100 so that alphabetical order and numerical order coincide
	root.RequireActionSortKeys = true
	ObjModified(self)
	ObjModified(root)
end

----- XActionsHost

DefineClass.XActionsHost = {
	__parents = { "XContextWindow", "XHoldButton" },
	properties = {
		{ category = "Actions", id = "ActionsMode", editor = "text", default = "", },
		{ category = "Actions", id = "Translate", editor = "bool", default = false, },
		{ category = "Actions", id = "HostInParent", editor = "bool", default = false, },
	},
	actions = false,
	shortcut_to_actions = false,
	menubar_actions = false,
	toolbar_actions = false,
	action_hold_buttons = false,
	
	dirty_actions_order = false,
	dirty_menubars = false,
	dirty_toolbars = false,
	dirty_shortcuts = false,
}

function XActionsHost:Init()
	self.actions = self.actions or {}
	self.shortcut_to_actions = {}
	self.menubar_actions = {}
	self.toolbar_actions = {}
	self.dirty_menubars = {}
	self.dirty_toolbars = {}
	self.dirty_shortcuts = {}
	-- register already created actions in the host
	for _, action in ipairs(self.actions) do
		action:RegisterInHost(self)
	end
end

function XActionsHost:ClearActions()
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			for _, action in ipairs(host and self.actions) do
				host:RemoveAction(action)
			end
		end
	end
	table.clear(self.actions)
	table.clear(self.shortcut_to_actions)
	table.clear(self.menubar_actions)
	table.clear(self.toolbar_actions)
end

function XActionsHost:Done()
	self:ClearActions()
end

function XActionsHost:ActionsUpdated()
	if not self:GetThread("UpdateActionViews") then
		self:CreateThread("UpdateActionViews", self.UpdateActionViews, self, self)
	end
end

function XActionsHost:SetActionsMode(mode)
	if self.ActionsMode ~= mode then
		self.ActionsMode = mode
		self:ActionsUpdated()
	end
end

function XActionsHost:InvalidateActionSortKey(action)
	self.dirty_actions_order = true
	if action.ActionMenubar ~= "" then
		self.dirty_menubars[action.ActionMenubar] = true
	end
	if action.ActionToolbar ~= "" then
		self.dirty_toolbars[action.ActionToolbar] = true
	end
	if action.ActionShortcut ~= "" then
		self.dirty_shortcuts[action.ActionShortcut] = true
	end
	if action.ActionShortcut2 ~= "" then
		self.dirty_shortcuts[action.ActionShortcut2] = true
	end
	if action.ActionGamepad ~= "" then
		self.dirty_shortcuts[action.ActionGamepad] = true
	end
end

local function sort_actions(actions)
	table.stable_sort(actions, function(a,b)
		return a.ActionSortKey < b.ActionSortKey
	end)
end

function XActionsHost:GetActions()
	if self.dirty_actions_order then
		sort_actions(self.actions)
		self.dirty_actions_order = nil
	end
	return self.actions
end

function XActionsHost:GetMenubarActions(menubar)
	if self.dirty_menubars[menubar] then
		sort_actions(self.menubar_actions[menubar])
		self.dirty_menubars[menubar] = nil
	end
	return self.menubar_actions[menubar]
end

function XActionsHost:GetToolbarActions(toolbar)
	if self.dirty_toolbars[toolbar] then
		sort_actions(self.toolbar_actions[toolbar])
		self.dirty_toolbars[toolbar] = nil
	end
	return self.toolbar_actions[toolbar]
end

function XActionsHost:GetShortcutActions(shortcut)
	if self.dirty_shortcuts[shortcut] then
		sort_actions(self.shortcut_to_actions[shortcut])
		self.dirty_shortcuts[shortcut] = nil
	end
	return self.shortcut_to_actions[shortcut]
end

function XActionsHost:CallHostParents(func, ...)
	self[func](self, ...)
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			host:CallHostParents(func, ...)
			return
		end
	end
end

local function add_sorted(actions, action)
	actions = actions or {}
	local i = 1
	local key = action.ActionSortKey
	local skip_add
	while i <= #actions and actions[i].ActionSortKey <= key do
		if actions[i] == action then
			-- don't duplicate actions
			skip_add = true
			break
		end
		i = i + 1
	end
	if not skip_add then
		table.insert(actions, i, action)
	end
	return actions
end

function XActionsHost:AddShortcutToAction(action, shortcut)
	if (shortcut or "") == "" then return end
	-- insert in list based on ActionSortKey
	self.shortcut_to_actions[shortcut] = add_sorted(self.shortcut_to_actions[shortcut], action)
end

function XActionsHost:RemoveShortcutToAction(action, shortcut)
	if (shortcut or "") == "" then return end
	local actions = self.shortcut_to_actions[shortcut]
	if not actions then return end
	table.remove_value(actions, action)
end

function XActionsHost:AddMenubarAction(action)
	local menubar = action.ActionMenubar
	if (menubar or "") == "" then return end
	self.menubar_actions[menubar] = add_sorted(self.menubar_actions[menubar], action)
end

function XActionsHost:RemoveMenubarAction(action)
	table.remove_entry(self.menubar_actions[action.ActionMenubar], action)
end

function XActionsHost:AddToolbarAction(action)
	local toolbar = action.ActionToolbar
	if (toolbar or "") == "" then return end
	self.toolbar_actions[toolbar] = add_sorted(self.toolbar_actions[toolbar], action)
end

function XActionsHost:RemoveToolbarAction(action)
	table.remove_entry(self.toolbar_actions[action.ActionToolbar], action)
end

function XActionsHost:_InternalAddAction(action, replace_matching_id)
	local actions = self.actions
	local key = action.ActionSortKey
	local old_idx = replace_matching_id and self:RemoveAction(self:ActionById(action.ActionId))
	-- is the new action still on a correct place at the old index?
	if old_idx and (old_idx == 1 or actions[old_idx - 1].ActionSortKey <= key) and
	  (old_idx > #actions or actions[old_idx].ActionSortKey >= key) then
		table.insert(actions, old_idx, action)
	else
		-- insert in list based on ActionSortKey
		add_sorted(actions, action)
	end
	
	-- add action to menubar and toolbar mappings
	self:AddMenubarAction(action)
	self:AddToolbarAction(action)
	
	-- add action to shortcuts mapping
	self:AddShortcutToAction(action, action.ActionShortcut)
	self:AddShortcutToAction(action, action.ActionShortcut2)
	self:AddShortcutToAction(action, action.ActionGamepad)
	
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			host:_InternalAddAction(action, replace_matching_id)
			return
		end
	end
	self:ActionsUpdated()
	--assert(action.ActionName == "" or (IsT(action.ActionName) or false) == self.Translate)
end

function XActionsHost:RemoveAction(action)
	if not action then return end
	local actions = self.actions
	local idx = table.remove_entry(self.actions, action)
	
	-- remove action from menubar and toolbar mappings
	self:RemoveMenubarAction(action)
	self:RemoveToolbarAction(action)
	
	-- remove action from shortcuts mapping
	self:RemoveShortcutToAction(action, action.ActionShortcut)
	self:RemoveShortcutToAction(action, action.ActionShortcut2)
	self:RemoveShortcutToAction(action, action.ActionGamepad)
	
	if self.HostInParent then
		local host = GetActionsHost(self.parent)
		if host then
			host:RemoveAction(action)
			return
		end
	end
	self:ActionsUpdated()
	return idx
end

function XActionsHost:SetHostInParent(host_in_parent)
	if self.HostInParent == host_in_parent then return end
	self.HostInParent = host_in_parent
	local host = GetActionsHost(self.parent)
	if host then
		for _, action in ipairs(self.actions) do
			if host_in_parent then
				host:_InternalAddAction(action)
			else
				host:RemoveAction(action)
			end
		end
	end
end

function XActionsHost:ActionsSanityCheck()
	--[[local ids, shortcuts = {}, {}
	for _, action in ipairs(self.actions) do
		if action.ActionId ~= "" then
			assert(not ids[action.ActionId], string.format("Conflicting action Id %s", action.ActionId))
			ids[action.ActionId] = action
		end
		
		local mode = action.ActionMode
		if not shortcuts[mode] then
			shortcuts[mode] = {}
		end
		local mode_actions = shortcuts[mode]
		if action.ActionShortcut ~= "" then
			local other = mode_actions[action.ActionShortcut]
			assert(not other, string.format("Conflicting shortcut %s (between actions %s & %s)", action.ActionShortcut, other and other.ActionId or "", action.ActionId))
			mode_actions[action.ActionShortcut] = action
		end
		if action.ActionShortcut2 ~= "" then
			local other = mode_actions[action.ActionShortcut2]
			assert(not other, string.format("Conflicting shortcut %s (between actions %s & %s)", action.ActionShortcut2, other and other.ActionId or "", action.ActionId))
			mode_actions[action.ActionShortcut2] = action
		end
	end]]
end

function XActionsHost:UpdateActionViews(win)
	if Platform.developer then
		self:ActionsSanityCheck()
	end
	for _, win in ipairs(win) do
		if IsKindOf(win, "XActionsView") then
			win:OnUpdateActions()
		end
		if not IsKindOf(win, "XActionsHost") or win.HostInParent then
			self:UpdateActionViews(win)
		end
	end
end

function XActionsHost:ShowActionBar(bShow)
	local action_bar = self:HasMember("idActionBar") and self.idActionBar
	if action_bar then
		action_bar:SetVisible(bShow)
	end
end

function XActionsHost:FilterAction(action, action_context)
	if not action_context then
		return action:EnabledInMode(self.ActionsMode) and self:ActionState(action) ~= "hidden"
	end
	
	for _, context in ipairs(action.ActionContexts) do
		if context == action_context and self:ActionState(action) ~= "hidden" then
			return true
		end
	end
	return false
end

function XActionsHost:ActionState(action)
	local action_id = action.ActionId
	if action.OnActionEffect == "popup" and action.OnAction == XAction.OnAction and
	   not self:HasMenubarActions(action_id) and not self:HasToolbarActions(action_id) then
	   return "hidden" -- hide menu entries with no children actions, that would result in an empty popup
	end
	return action:ActionState(self)
end

function XActionsHost:HasMenubarActions(action_id)
	return next(self.menubar_actions[action_id])
end

function XActionsHost:HasToolbarActions(action_id)
	return next(self.toolbar_actions[action_id])
end

function XActionsHost:OnAction(action, ctrl, ...)
	local hasFx = ctrl and ctrl.FXPress
	local ret = action:OnAction(self, ctrl, ...)
	if #(action.FXPress or "") ~= 0 and not hasFx then PlayFX(action.FXPress, "start", action) end
	if action.ActionToggle then
		self:ActionsUpdated()
	end
	Msg("XActionActivated", self, action, ctrl, ...)
	return ret
end

function XActionsHost:ActionById(id)
	return table.find_value(self.actions, "ActionId", id)
end

function XActionsHost:IsActionShortcut(id, shortcut)
	local action = self:ActionById(id)
	if not action then return end
	return action.ActionShortcut == shortcut or action.ActionShortcut2 == shortcut or action.ActionGamepad == shortcut
end

function XActionsHost:ActionByShortcut(shortcut, input, controller_id, repeated, ...)
	local found
	for _, action in ipairs(self:GetShortcutActions(shortcut)) do
		if (not action.IgnoreRepeated or not repeated) then
			if self:FilterAction(action) then
				local state = action:ActionState(self)
				if state ~= "disabled" and state ~= "hidden" then
					found = action
					break
				end
			end
		end
	end
	
	return found
end

function XActionsHost:GamepadHoldActionByShortcut(shortcut)
	local found
	for _, action in ipairs(self:GetShortcutActions(shortcut)) do
		if action.ActionGamepadHold and self:FilterAction(action) then
			local state = action:ActionState(self)
			if state ~= "disabled" and state ~= "hidden" then
				found = action
				break
			end
		end
	end
	return found
end

if FirstLoad then
	KbdShortcutToRelation = {
		["Tab"] = "next",
		["Shift-Tab"] = "prev",
		["Up"] = "up",
		["Down"] = "down",
		["Left"] = "left",
		["Right"] = "right",
	}

	XShortcutToRelation = {
		["LeftThumbLeft"] = "left", ["LeftThumbDownLeft"] = "left", ["LeftThumbUpLeft"] = "left",
		["LeftThumbRight"] = "right", ["LeftThumbDownRight"] = "right", ["LeftThumbUpRight"] = "right",
		["LeftThumbUp"] = "up",
		["LeftThumbDown"] = "down",
		["DPadLeft"] = "left",
		["DPadRight"] = "right",
		["DPadUp"] = "up",
		["DPadDown"] = "down",
	}
end

function XActionsHost:OnHoldDown(pt, button)
	local action = self:GamepadHoldActionByShortcut(button)
	action:OnAction(self,button)
end

function XActionsHost:OnHoldButtonTick(i, shortcut)	
	local action = self:GamepadHoldActionByShortcut(shortcut)
	if not action then
		return 
	end	
	local ctrl = self.action_hold_buttons and self.action_hold_buttons[action.ActionId]
	if ctrl and ctrl:HasMember("OnHoldButtonTick") then
		ctrl:OnHoldButtonTick(i)
	else
		 XHoldButton.OnHoldButtonTick(self, i, shortcut)	
	end
end

function XActionsHost:OnXButtonRepeat(shortcut, controller_id,...)
	if self.HostInParent then return end
	if not RepeatableXButtons[shortcut] then
		local found = self:GamepadHoldActionByShortcut(shortcut)
		if found then
			XHoldButton.OnHoldButtonRepeat(self,shortcut, controller_id)
			return "break"
		end	
	end
end

function XActionsHost:OnShortcut(shortcut, source, controller_id, ...)
	if self.HostInParent then return end
	local found
	if source=="gamepad" then
		if shortcut:starts_with("-") then
			local org_shortcut = shortcut:gsub("-", "")
			found = self:GamepadHoldActionByShortcut(org_shortcut)
			if found then
				found =  XHoldButton.OnHoldButtonUp(self, org_shortcut, controller_id) 
				if found then
					return "break"
				end
			end	
		elseif shortcut:starts_with("+") then
			local org_shortcut = shortcut:gsub("+", "")
			found = self:GamepadHoldActionByShortcut(org_shortcut)
			if found then
				XHoldButton.OnHoldButtonDown(self,org_shortcut, controller_id)
			end	
		else
			found = self:GamepadHoldActionByShortcut(shortcut)
			if found then
				XHoldButton.OnHoldButtonRepeat(self,shortcut, controller_id)
			end
		end	
	end	
	local action = not found and self:ActionByShortcut(shortcut, source, controller_id, ...)
	if action then
		self:OnAction(action, source, controller_id, ...)
		return "break"
	end
	if source ~= "mouse" then
		local relation = (source == "keyboard") and KbdShortcutToRelation[shortcut] or XShortcutToRelation[shortcut]
		if relation then
			local focus = self.desktop and self.desktop.keyboard_focus
			local order = focus and focus:IsWithin(self) and focus:GetFocusOrder() or point(0, 0)
			focus = self:GetRelativeFocus(order, relation)
			if focus then
				-- the thread prevents Tab keys to be processed in OnKbdChar of the new focus
				CreateRealTimeThread(function()
					if focus.window_state ~= "destroying" then
						focus:SetFocus()
						if source == "gamepad" and RolloverControl ~= focus then
							XCreateRolloverWindow(focus, true)
						end
					end
				end)
				return "break"
			end
		end
	end
end

function XActionsHost:OpenContextMenu(action_context, anchor_pt)
	if not action_context or not anchor_pt or action_context == "" then return end
	local menu = XPopupMenu:new({
		ActionContextEntries = action_context,
		Anchor = anchor_pt,
		AnchorType = "mouse",
		MaxItems = 12,
		GetActionsHost = function() return self end,
		popup_parent = self,
	}, terminal.desktop)
	menu:Open()
	return menu
end

function XActionsHost:OpenPopupMenu(menubar_id, anchor_pt)
	local menu = XPopupMenu:new({
		MenuEntries = menubar_id,
		Anchor = anchor_pt,
		AnchorType = "mouse",
		MaxItems = 12,
		GetActionsHost = function() return self end,
		popup_parent = self,
	}, terminal.desktop)
	menu:Open()
	return menu
end


----- XActionsView

DefineClass.XActionsView = {
	__parents = { "XContextWindow" },
	properties = {
		{ category = "General", id = "HideWithoutActions", name = "Hide without actions", editor = "bool", default = false },
	}
}

function XActionsView:GetActionsHost()
	return GetActionsHost(self, true)
end

function XActionsView:Open(...)
	XContextWindow.Open(self, ...)
	self:OnUpdateActions()
end

function XActionsView:PopupAction(action_id, host, source)
	assert(false)
end

function XActionsView:OnUpdateActions()
	local host = self:GetActionsHost()
	if not host or self.window_state == "new" then return end
	self:RebuildActions(host)
	if self.HideWithoutActions then
		self:SetVisible(#self > 0)
	end
	Msg("XWindowRecreated", self)
end

function XActionsView:RebuildActions(host)
end


----- globals

function GetActionsHost(win, final)
	while win and (not win:IsKindOf("XActionsHost") or win.HostInParent and final) do
		win = win.parent
		if final and win and win:IsKindOf("XActionsView") then
			return win:GetActionsHost()
		end
	end
	return win
end

function EnabledInModes(givenModes, modes)
	if givenModes == "" or modes == "" or modes == givenModes then return true end

	for givenMode in string.gmatch(givenModes, "([%w%-_]+)") do
		for mode in string.gmatch(modes, "([%w%-_]+)") do
			if givenMode == mode or givenMode == "ForwardToC" or mode == "ForwardToC" then
				return true
			end
		end
	end
	
	return false
end
