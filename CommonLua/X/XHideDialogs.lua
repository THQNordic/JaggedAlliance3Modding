DefineClass.XHideDialogs = {
	__parents = { "XWindow" },
	
	properties = {
		{ id = "LeaveDialogIds", category = "General", editor = "string_list", default = {}, items = ListAllDialogs },
	},
	
	Dock = "ignore",
	HandleMouse = false,
	visible_states = false,
	ZOrder = 2000000000, -- above everything else, so it gets destroyed first and unhides the dialogs it hides
}

BlacklistedDialogClasses = {
	"InGameMenu",
	"XLoadingScreenClass",
	"DeveloperInterface",
}

if FirstLoad then
	xhd_open = false
end

function XHideDialogs:Open(...)
	XWindow.Open(self, ...)
	
	local leave_dlgs = {}
	local parent = self.parent
	
	while parent do
		leave_dlgs[parent] = true
		parent = parent.parent
	end
	
	for _, id in ipairs(self.LeaveDialogIds) do
		leave_dlgs[GetDialog(id) or false] = true
	end
	
	local previousXHideDialog = xhd_open and xhd_open[#xhd_open]

	self.visible_states = {}
	for dlg_id, dialog in pairs(Dialogs or empty_table) do
		if type(dlg_id) == "string" and not leave_dlgs[dialog] and
			not table.find(BlacklistedDialogClasses, dialog.class)
			and not table.find(BlacklistedDialogClasses, dialog.XTemplate)
			and dialog.window_state ~= "closing" and dialog.window_state ~= "destroying" 
		then
			if previousXHideDialog and previousXHideDialog.visible_states[dialog] ~= nil then
				self.visible_states[dialog] = previousXHideDialog.visible_states[dialog]
			else
				self.visible_states[dialog] = dialog:GetVisible()
			end
			dialog:SetVisible(false, "instant")
		end
	end

	if not xhd_open then xhd_open = {} end
	xhd_open[#xhd_open + 1] = self
end

function XHideDialogs:Done()
	local idx = xhd_open and table.find(xhd_open, self)
	local previousXHideDialog = idx and idx > 1 and xhd_open[idx - 1]
	local nextXHideDialog = idx and idx < #xhd_open and xhd_open[idx + 1]

	for dialog, visible in pairs(self.visible_states or empty_table) do
		if dialog.window_state ~= "destroying" then
			local notHiddenByNext = not nextXHideDialog or nextXHideDialog.visible_states[dialog] == nil
			local notHiddenByPrev = not previousXHideDialog or previousXHideDialog.visible_states[dialog] == nil
			if notHiddenByNext and notHiddenByPrev then
				dialog:SetVisible(visible, "instant")
			end
		end
	end
	self.visible_states = nil
	table.remove_value(xhd_open, self)
	terminal.desktop:RestoreFocus()
end