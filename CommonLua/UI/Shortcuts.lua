if FirstLoad then
	MouseButtonImagesInText = {
		-- Add project specific images
		--[[["MouseL"] = "UI/Infopanel/left_click.tga",
		["MouseR"] = "UI/Infopanel/right_click.tga",
		["MouseM"] = "UI/Infopanel/middle_click.tga",
		["MouseX1"] = "UI/Infopanel/button_4.tga",
		["MouseX2"] = "UI/Infopanel/button_5.tga",
		["MouseWheelFwd"] = "UI/Infopanel/scroll_up.tga",
		["MouseWheelBack"] = "UI/Infopanel/scroll_down.tga",]]
	}

	MouseButtonNames = {
		MouseL = T(344793107847, "Left Mouse Button"),
		MouseR = T(620781110653, "Right Mouse Button"),
		MouseM = T(814937893055, "Middle Mouse Button"),
		MouseX1 = T(404129049676, "Mouse Button 4"),
		MouseX2 = T(640322216255, "Mouse Button 5"),
		MouseWheelFwd = T(286518835802, "Mouse Wheel Forward"),
		MouseWheelBack = T(889465032724, "Mouse Wheel Back"),
	}
	
	ForbiddenShortcutKeys = {
		Lwin = true,
		Rwin = true,
		Menu = true,
		MouseL = true,
		MouseR = true,
		MouseM = true,
		Enter = true,
	}
	
	NonBindableKeys = {}
end

function GatherNonBindableKeys()
	local nonBindableKeys = {}
	for _, action in ipairs(XShortcutsTarget:GetActions()) do
		if action.ActionMode ~= "Editor" and not action.ActionBindable then
			table.insert(nonBindableKeys, action)
		end
	end
	return nonBindableKeys
end

TFormat.GamepadShortcutName = function(context_obj, shortcut)
	if not shortcut or shortcut == "" then
		return T(879415238341, "<negative>Unassigned</negative>")
	end
	local buttons = SplitShortcut(shortcut)
	for i, button in ipairs(buttons) do
		buttons[i] = const.TagLookupTable[button] or GetPlatformSpecificImageTag(button) or "?"
	end
	return Untranslated(table.concat(buttons))
end

EmShortcutNames = false
ShortcutIconScale = " 1000"

TFormat.KeyboardAndMouseShortcutName = function(context_obj, shortcut, scale, unassigned_str)
	if not shortcut or shortcut == "" then
		return unassigned_str or T(879415238341, "<negative>Unassigned</negative>")
	end
	local keys = SplitShortcut(shortcut)
	scale = scale or ShortcutIconScale
	local texts = {}
	for _, key in ipairs(keys) do
		local img = MouseButtonImagesInText[key]
		if img then
			texts[#texts + 1] = Untranslated("<image " .. img .. scale .. ">")
			goto continue
		end
		local text = MouseButtonNames[key] or KeyNames[VKStrNamesInverse[key]]
		assert(text, "Unknown mouse button name")
		if not text then
			goto continue
		end
		if EmShortcutNames then
			texts[#texts + 1] = T{399372771879, "<em><name></em>", name = text}
		else
			texts[#texts + 1] = T{629765447024, "<name>", name = text}
		end
		::continue::
    end
	return table.concat(texts, "-")
end

TFormat.ShortcutName = function(context_obj, action_id, source, scale)
	local shortcuts = GetShortcuts(action_id)
	if GetUIStyleGamepad() and (not source or source == "gamepad") then
		return TFormat.GamepadShortcutName(context_obj, shortcuts and shortcuts[3])
	else
		return TFormat.KeyboardAndMouseShortcutName(context_obj, shortcuts and shortcuts[1], scale)
	end
end

TwinShortcuts = {
	DPadUp = { DPadDown = "DPadUpDown" },
	DPadDown = { DPadUp = "DPadUpDown" },
	DPadLeft = { DPadRight = "DPadLeftRight" },
	DPadRight = { DPadLeft = "DPadLeftRight" },
}

local function GetTwinShortcutIcon(shortcut1, shortcut2)
	if not shortcut1 or shortcut1 == "" then return end
	if not shortcut2 or shortcut2 == "" then return end
	local buttons1 = SplitShortcut(shortcut1)
	local buttons2 = SplitShortcut(shortcut2)
	local button_cnt = #buttons1
	if button_cnt ~= #buttons2 then return end
	for i = 1, button_cnt - 1 do
		if buttons1[i] ~= buttons2[i] then return end
	end
	local twin_button = table.get(TwinShortcuts[buttons1[button_cnt]], buttons2[button_cnt])
	if not twin_button then return end
	local twin_shortcut_icon = const.TagLookupTable[twin_button] or GetPlatformSpecificImageTag(twin_button)
	return twin_shortcut_icon, buttons1
end

TwinShortcutSeparator = T(522258393731, " / ")

--- Combines two related shortcuts into one
-- If RT+DPadUp and RT+DPadDown are passed then the return value will be RT+DPadUpDown.
-- Shortcut relations are specified in the TwinShortcuts table.
-- If two unrelated shortcuts are passed then the return value will be those shortcuts concatenated with TwinShortcutSeparator.
TFormat.TwinShortcutNames = function(context_obj, action1_id, action2_id, source, separator)
	local shortcuts1 = GetShortcuts(action1_id)
	local shortcuts2 = GetShortcuts(action2_id)
	local shortcut1, shortcut2, shortcut_name_func
	if GetUIStyleGamepad() and (not source or source == "gamepad") then
		shortcut1 = shortcuts1 and shortcuts1[3]
		shortcut2 = shortcuts2 and shortcuts2[3]
		shortcut_name_func = TFormat.GamepadShortcutName
	else
		shortcut1 = shortcuts1 and shortcuts1[1]
		shortcut2 = shortcuts2 and shortcuts2[1]
		shortcut_name_func = TFormat.KeyboardAndMouseShortcutName
	end
	local twin_shortcut_icon, buttons = GetTwinShortcutIcon(shortcut1, shortcut2)
	if twin_shortcut_icon then
		local button_cnt = #buttons
		for i = 1, button_cnt - 1 do
			local button = buttons[i]
			buttons[i] = const.TagLookupTable[button] or GetPlatformSpecificImageTag(button) or "?"
		end
		buttons[button_cnt] = twin_shortcut_icon
		return Untranslated(table.concat(buttons))
	else
		return Untranslated(table.concat({
			shortcut_name_func(context_obj, shortcut1),
			shortcut_name_func(context_obj, shortcut2)
		}, separator or TwinShortcutSeparator))
	end
end

function ShortcutKeysToText(keys)
	local texts = {}
	for k, v in ipairs(keys) do
		texts[k] = MouseButtonNames[v] or KeyNames[VKStrNamesInverse[v]]
	end
	return table.concat(texts, "-")
end

EmptyKeyImageInText = false
KeybindingImageScale = " 1100"
function KeybindingName(shortcut)
	local empty_key = EmptyKeyImageInText and Untranslated("<image " .. EmptyKeyImageInText .. KeybindingImageScale .. ">") or ""
	return TFormat.KeyboardAndMouseShortcutName(nil, shortcut, KeybindingImageScale, empty_key)
end

function RebindKeys(idx, prop_ctrl)
	CreateRealTimeThread(function(idx, prop_ctrl)
		local obj = ResolvePropObj(prop_ctrl.context)
		local prop_meta = prop_ctrl.prop_meta
		local prop_id = prop_meta.id
		local prop_name = prop_meta.name
		local dlg = CreateMessageBox(terminal.desktop, T(""), T{529975158495, "Press a key to assign to <action>...\nPress Esc to cancel.", action = prop_name})
		dlg:PreventClose()
		local shortcut, keys, last_key
		repeat
			shortcut = WaitShortcut()
			if prop_ctrl.window_state == "destroying" then
				dlg:Close()
				return
			end
			if shortcut then
				keys = SplitShortcut(shortcut)
				last_key = keys[#keys]
				if shortcut ~= "Escape" then
					Msg("OptionsChanged")
				end
			end
		until shortcut and not ForbiddenShortcutKeys[last_key] and not (prop_meta.single_key and (last_key == "Ctrl" or last_key == "Shift"))
		if prop_meta.single_key then
			shortcut = last_key
			keys = {last_key}
		end
		shortcut = last_key ~= "Escape" and shortcut
		if MouseButtonNames[last_key] and not prop_meta.mouse_bindable then
			local parent = dlg.parent
			dlg:Close()
			CreateMessageBox(parent, T(207596731516, "Conflicting controls"),
				T{301773001578, "<key> cannot be used for <action>.",
				key = MouseButtonNames[last_key] or T{last_key}, action = prop_name},
				T(325411474155, "OK"))
			return
		end
		local nonRebindableAction = table.find_value(NonBindableKeys, "ActionShortcut", last_key)
		if shortcut and nonRebindableAction and EnabledInModes(nonRebindableAction.ActionMode, prop_meta.mode) then
			local parent = dlg.parent
			dlg:Close()
			CreateMessageBox(parent, T(207596731516, "Conflicting controls"),
				T{163533339775, "<newKey> is already used by a non rebindable action <nonRebindableKey>",
				newKey = KeybindingName(last_key) or T{last_key}, nonRebindableKey = nonRebindableAction.ActionTranslate and nonRebindableAction.ActionName or ""},
				T(325411474155, "OK"))
			return
		end
		if shortcut then
			for _, ctrl in ipairs(prop_ctrl.parent) do
				local ctrl_meta = ctrl.prop_meta
				if not ctrl_meta then goto continue end
				local bindings = obj[ctrl_meta.id]
				if bindings and EnabledInModes(ctrl_meta.mode, prop_meta.mode) then
					for i = 1, #bindings do 
						if ctrl_meta.id ~= prop_id and bindings[i] == shortcut then
							local old_action = ctrl_meta.name
							local new_action = prop_name
							if dlg.window_state == "open" then
								dlg:Close()
							end
							
							local res = WaitQuestion(terminal.desktop,
								T(207596731516, "Conflicting controls"),
								T{905663676426, "Do you want to rebind <key> from <old_action> to <new_action>?",
									key = ShortcutKeysToText(keys),
									old_action = old_action,
									new_action = new_action
								},
								T(689884995409, "Yes"),
								T(782927325160, "No")
							)
							if res == "ok" then
								-- clear binding
								bindings = table.copy(bindings) --don't overwrite the default values
								bindings[1] = i ~= 1 and bindings[1] or bindings[2] or ""
								bindings[2] = ""
								obj:SetProperty(ctrl_meta.id, bindings)
								ctrl.value = bindings
								ctrl:OnPropUpdate(ctrl.context, ctrl_meta, bindings)
								break
							else
								return
							end
						end
					end
				end
				::continue::
			end
			local bindings = obj[prop_meta.id]
			bindings = bindings and table.copy(bindings) or {} --don't overwrite the default values
			idx = bindings[1] and idx or 1
			bindings[idx] = shortcut
			if #bindings > 1 and bindings[1] == bindings[2] then
				bindings[2] = ""
			end
			obj:SetProperty(prop_meta.id, bindings)
			prop_ctrl.value = bindings
			prop_ctrl:OnPropUpdate(prop_ctrl.context, prop_meta, bindings)
		end
		if dlg and dlg.window_state ~= "destroying" then
			dlg:Close()
		end
	end, idx, prop_ctrl)
end

ShouldAttachSelectionShortcutWork = return_true
ShouldBlackPlanesShortcutWork = return_true