function OnMsg.Autorun()
	InGameInterface.InitialMode = config.InitialInGameInterfaceMode or config.InGameSelectionMode
end

DefineClass.InGameInterface = {
	__parents = { "XDialog" }, 
	mode = false,
	mode_dialog = false,
	Dock = "box",
}

function InGameInterface:Open(...)
	XDialog.Open(self, ...)
	self:SetFocus()
	ShowMouseCursor("InGameInterface")
	Msg("InGameInterfaceCreated", self)
end

function InGameInterface:Close(...)
	XDialog.Close(self, ...)
	HideMouseCursor("InGameInterface")
end

function InGameInterface:OnXButtonDown(button, controller_id)
	if self.desktop:GetModalWindow() == self.desktop and self.mode_dialog then
		return self.mode_dialog:OnXButtonDown(button, controller_id)
	end
end

function InGameInterface:OnXButtonUp(button, controller_id)
	if self.desktop:GetModalWindow() == self.desktop and self.mode_dialog then
		return self.mode_dialog:OnXButtonUp(button, controller_id)
	end
end

function InGameInterface:OnShortcut(shortcut, source, ...)
	local desktop = self.desktop
	if desktop:GetModalWindow() == desktop and self.mode_dialog and self.mode_dialog:GetVisible() and desktop.keyboard_focus and not desktop.keyboard_focus:IsWithin(self.mode_dialog) then
		return self.mode_dialog:OnShortcut(shortcut, source, ...)
	end
end

function InGameInterface:SetMode(mode_or_dialog, context)
	if self.mode_dialog then
		self.mode_dialog:Close()
	end
	local mode = mode_or_dialog
	if type(mode) == "string" then
		local class = mode and g_Classes[mode]
		assert(class)
		self.mode_dialog = class and OpenDialog(mode, self, context)
	else
		assert(IsKindOf(mode, "XDialog"))
		mode:SetParent(self)
		mode:SetContext(context)
		mode:Open()
		self.mode_dialog = mode
		mode = mode_or_dialog.class
	end
	Msg("IGIModeChanging", self.Mode, mode)
	self.mode_log[#self.mode_log + 1] = { self.Mode, self.mode_param }
	self.Mode = mode
	self.mode_param = context
	Msg("IGIModeChanged", mode)
	self:CallOnModeChange()
end

function GetInGameInterface()
	return GetDialog("InGameInterface")
end

function GetTopInGameInterfaceParent()
	return GetInGameInterface()
end

function GetInGameInterfaceMode()
	return GetDialogMode("InGameInterface")
end

function SyncCheck_InGameInterfaceMode()
	if config.IgnoreSyncCheckErrors then
		return true
	end
	return IsAsyncCode()
end

function SetInGameInterfaceMode(mode, context)
	assert(SyncCheck_InGameInterfaceMode())
	SetDialogMode("InGameInterface", mode, context)
end

function GetInGameInterfaceModeDlg(mode)
	local igi = GetInGameInterface()
	if igi and (not mode or mode == igi:GetMode()) then
		return igi.mode_dialog
	end
end

function ShowInGameInterface(bShow, instant, context)
	if not mapdata.GameLogic and not GetInGameInterface() then
		return
	end
	if not bShow and not GetInGameInterface() then 
		return
	end
	local dlg = OpenDialog("InGameInterface", nil, context)
	dlg:SetVisible(bShow, instant)
	dlg.desktop:RestoreFocus()
end

-- deactivate mode dialog and set it to select
function CloseInGameInterfaceMode(mode)
	local igi = GetInGameInterface()
	if igi and (not mode or (igi:GetMode() == mode and igi.mode_dialog.window_state ~= "destroying")) then
		if igi:GetMode() ~= igi.InitialMode then
			igi:SetMode(igi.InitialMode)
		end
	end
end

function OnMsg.GameEnterEditor()
	ShowInGameInterface(false)
	ShowPauseDialog(false, "force")
end

function OnMsg.GameExitEditor()
	if GetInGameInterface() then
		ShowInGameInterface(true)
	end
	if GetTimeFactor() == 0 then
		ShowPauseDialog(true)
	end
end

function OnMsg.StoreSaveGame(storing)
	local igi = GetInGameInterface()
	if not igi or not XTemplates["LoadingAnim"] then return end
	if storing then
		OpenDialog("LoadingAnim", igi:ResolveId("idLoadingContainer") or igi, nil, "StoreSaveGame")
	else
		CloseDialog("LoadingAnim", nil, "StoreSaveGame")
	end
end

local highlight_thread, highlight_obj, highlight_oldcolor
function ViewAndHighlightObject(obj)
	if highlight_obj then
		highlight_obj:SetColorModifier(highlight_oldcolor)
		DeleteThread(highlight_thread)
	end
	highlight_obj = obj
	highlight_oldcolor = obj:GetColorModifier()
	highlight_thread = CreateRealTimeThread(function()
		if IsValid(obj) then
			ViewObject(obj)
			Sleep(200)
			for i = 1, 5 do
				if not IsValid(obj) then break end
				obj:SetColorModifier(RGB(255, 255, 255))
				Sleep(75)
				if not IsValid(obj) then break end
				obj:SetColorModifier(highlight_oldcolor)
				Sleep(75)
			end
		end
		highlight_obj = nil
		highlight_thread = nil
		highlight_oldcolor = nil
	end)
end

function OnMsg.ChangeMapDone()
	HideMouseCursor("system")
	if Platform.developer and not mapdata.GameLogic then
		ShowMouseCursor("system")
	end
end