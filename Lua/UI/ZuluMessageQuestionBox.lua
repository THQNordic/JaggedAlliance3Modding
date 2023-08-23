----- ZuluMessageDialog
DefineClass.ZuluMessageDialog = {
	__parents = { "ZuluModalDialog" },
	HandleKeyboard = true,
	--DrawOnTop = true,
	template = "ZuluMessageDialogTemplate",
	ZOrder = 1000
}

function ZuluMessageDialog:Init()
	XTemplateSpawn(self.template, self, self.context)
end

function ZuluMessageDialog:Open(...)
	ZuluModalDialog.Open(self, ...)

	self:SetFocus()

	g_OpenMessageBoxes[self] = true
	self.idMain.idText:SetText(self.context.text)
	self.idMain.idTitle:SetText(self.context.title)
end

function ZuluMessageDialog:Close(...)
	g_OpenMessageBoxes[self] = nil
	ZuluModalDialog.Close(self, ...)
end

function ZuluMessageDialog:PreventClose()
	local actionButtons = self.idMain.idActionBar
	if actionButtons then
		actionButtons.RebuildActions = empty_func
		actionButtons = actionButtons[1]
	end
	for i, a in ipairs(actionButtons) do
		if IsKindOf(a, "XTextButton") then
			a:SetEnabled(false)
		end
	end
	self.OnShortcut = empty_func
end

function ZuluMessageDialog:OnMouseButtonDown()
	return "break"
end

function ZuluMessageDialog:OnMouseButtonUp()
	return "break"
end

function ZuluMessageDialog:OnMouseWheelForward()
	return "break"
end

function ZuluMessageDialog:OnMouseWheelBack()
	return "break"
end

function CreateMessageBox(parent, caption, text, ok_text, obj)
	parent = parent or terminal.desktop
	
	-- This happens rarely when an account storage error pops up.
	if not parent.ChildrenHandleMouse then
		parent:SetChildrenHandleMouse(true)
		print("Message box in non-mouse handling parent")
	end
	
	local context = {
		title = caption,
		text = text,
		obj = obj
	}
	
	local actions = {}
	actions[#actions + 1] = XAction:new({
		ActionId = "idOk",
		ActionName = ok_text or T(6877, "OK"),
		ActionShortcut = "Escape",
		ActionShortcut2 = "Enter",
		ActionGamepad = "ButtonA",
		ActionToolbar = "ActionBar",
		OnActionEffect = "close",
		OnActionParam = "ok",
	})
	
	local msg = ZuluMessageDialog:new({actions = actions}, parent, context)
	msg.OnShortcut = function(self, shortcut, source, ...)
		if shortcut == "ButtonB" or shortcut == "1" then
			self:Close("ok")
			return "break"
		end
		return ZuluModalDialog.OnShortcut(self, shortcut, source, ...)
	end
	msg:Open()
	return msg
end

-- Zulu's CreateQuestionBox/CreateMessageBox uses the ZuluMessageDialog class which inherits ZuluModalDialog
-- ZuluModalDialog doesn't use XWindow:SetModal but instead stretches over the whole parent (usually the whole screen)
-- and captures all input below it. This means that any windows outside of the parent will still be clickable (and undimmed).
-- If spawning the question box in tactical view use the default terminal.desktop or InGameInterface() or whatever you use
-- normally. When spawning it in the PDADialog use GetDialog("PDADialog"):ResolveId("idDisplayPopupHost") which will cause
-- it to spawn inside the screen (logically and visually). The PDA frame buttons which are outside the screen will
-- not allow input while the popup is open via additional logic.

-- added sync_close -> try and close the box on all remote clients on input
function NetEvents.SyncMsgBoxClosed(text, title, btn)
	for msg_box, _ in pairs(g_OpenMessageBoxes) do
		if msg_box.window_state ~= "destroying" and
			msg_box:HasMember("idMain") and --any assert here will lead to msg box blocking client forever...
			msg_box.idMain:HasMember("idText") and
			_InternalTranslate(msg_box.idMain.idText:GetText()) == text and
			msg_box.idMain:HasMember("idTitle") and
			_InternalTranslate(msg_box.idMain.idTitle:GetText()) == title then
			msg_box:Close("remote")
		end
	end
end

function CreateQuestionBox(parent, caption, text, ok_text, cancel_text, obj, ok_state_fn, cancel_state_fn, template, sync_close)
	parent = parent or terminal.desktop
	local context = {
		title = caption,
		text = text,
		obj = obj
	}
	local actions = {}
	local on_close = empty_func
	if netInGame and sync_close then
		on_close = function(action, host, btn)
			NetEvent("SyncMsgBoxClosed", _InternalTranslate(text), _InternalTranslate(caption), btn)
		end
	end
	
	actions[#actions + 1] = XAction:new({
		ActionId = "idOk",
		ActionName = ok_text or T(6878, "OK"),
		ActionShortcut = "Enter",
		ActionShortcut2 = "1",
		ActionGamepad = "ButtonA",
		ActionToolbar = "ActionBar",
		ActionState = function(self, host)
			return ok_state_fn and ok_state_fn(obj) or "enabled"
		end,
		OnAction = function(self, host, source)
			on_close(self, host, "ok")
			host:Close("ok")
			return "break"
		end
	})
	actions[#actions + 1] = XAction:new({
		ActionId = "idCancel",
		ActionName = cancel_text or T(6879, "Cancel"),
		ActionShortcut = "Escape",
		ActionShortcut2 = "2",
		ActionGamepad = "ButtonB",
		ActionToolbar = "ActionBar",
		ActionState = function(self, host)
			return cancel_state_fn and cancel_state_fn(obj) or "enabled"
		end,
		OnAction = function(self, host, source)
			on_close(self, host, "cancel")
			host:Close("cancel")
			return "break"
		end
	})
	
	local initArgs = { actions = actions }
	if template then
		initArgs.template = template
	end
	local msg = ZuluMessageDialog:new(initArgs, parent, context)
	msg:Open()
	return msg
end

function LoadAnyway(err, alt_option)
	DebugPrint("\nLoad anyway", ":", _InternalTranslate(err), "\n\n")
	local default_load_anyway = config.DefaultLoadAnywayAnswer
	if default_load_anyway ~= nil then
		return default_load_anyway
	end
	local parent = GetLoadingScreenDialog() or terminal.desktop
	local dialog = CreateQuestionBox(parent, T(1000599, "Warning"), err, T(3686, "Load anyway"), T(1000246, "Cancel"))
	local result, dataset, xInputStateAtClose = dialog:Wait() 
	return result == "ok", dataset, xInputStateAtClose
end

----- ZuluChoiceDialog
DefineClass.ZuluChoiceDialog = {
	__parents = {"ZuluMessageDialog"},
}

function ZuluChoiceDialog:Init()
	SetCampaignSpeed(0, GetUICampaignPauseReason("ZuluChoiceDialog"))
	XCameraLockLayer:new({}, self)
	XPauseLayer:new({}, self)
end

function ZuluChoiceDialog:Done()
	SetCampaignSpeed(nil, GetUICampaignPauseReason("ZuluChoiceDialog"))
end

function NetEvents.ZuluChoiceDialogClosed(idx)
	local dlg = terminal.desktop:GetModalWindow()
	if dlg and dlg.parent and IsKindOf(dlg.parent, "ZuluChoiceDialog") then
		dlg.parent:Close("remote")
	end
end

local lGamepadShortcutToKeyboard = {
	["ButtonB"] = "Escape",
}

function CreateZuluPopupChoice(parent, context)
	local actions = {}
	
	context.title = context.title or T(387054111386, "Choice")
	local on_close = empty_func
	if netInGame and context.sync_close then
		on_close = function(action, host, idx)
			NetEvent("ZuluChoiceDialogClosed", idx)
		end
	end
	
	local maxChoiceIdx = 1
	local totalKeys = table.keys(context)
	for i = 1, #totalKeys do
		if context["choice" .. i] then
			maxChoiceIdx = i
		end
	end
	
	for i = 1, maxChoiceIdx do
		local choice = context["choice" .. i]
		if not choice and i == 1 then
			choice = T(325411474155, "OK")
		end
		if not choice then goto continue end
		
		local idx = i
		local gamePadShortcut = context["choice" .. idx .. "_gamepad_shortcut"]
		
		actions[#actions + 1] = XAction:new({
			ActionId = "idChoice" .. i,
			ActionName = choice,
			ActionToolbar = "ActionBar",
			OnAction = function(self, host, source)
				on_close(self, host, idx)
				host:Close(idx)
			end,
			ActionState = function(self, host, source)
				local f = context["choice" .. idx .. "_state_func"]
				return f and f() or "enabled"
			end,
			ActionShortcut = lGamepadShortcutToKeyboard[gamePadShortcut],
			ActionGamepad = gamePadShortcut
		})
		
		::continue::
	end

	return ZuluChoiceDialog:new({actions = actions}, parent or terminal.desktop, context)
end

function WaitPopupChoice(parent, context)
	local dialog = CreateZuluPopupChoice(parent, context)
	dialog:Open()
	return dialog:Wait()
end