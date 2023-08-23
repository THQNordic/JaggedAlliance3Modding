DefineClass.XZuluToolBarList = {
	__parents = { "XToolBarList" },
	properties = {
		{ category = "Actions", id = "ButtonTemplate", editor = "choice", default = "XTextButton", items = XTemplateCombo("XWindow"), },
	},
}

function XZuluToolBarList:RebuildActions(host)
	local parent = self:GetButtonParent()
	parent:DeleteChildren()
	local context = host.context
	local sections = {}
	local focus_on_click = self.FocusOnClick
	local actions = host:GetToolbarActions(self.Toolbar)
	for i, action in ipairs(actions) do
		if host:FilterAction(action) then
			local container = parent
			if action.ActionToolbarSection ~= "" then 
				local section = action.ActionToolbarSection
				if not sections[section] then 
					sections[section] = XTemplateSpawn(self.ToolbarSectionTemplate, container, context)
					sections[section]:Open()
					sections[section]:SetName(section)
				end	
				container = sections[section]:GetContainer()
			end
			local window = XTemplateSpawn("OptionsActionsButton", container, context)
			local button = window:ResolveId("idTextButton")
			local on_press = button.OnPress
			button.OnPress = function(self, ...)
				if focus_on_click then
					self:SetFocus()
				end
				on_press(self, ...)
				if focus_on_click then
					self:SetFocus(false)
				end
			end
			if action.ActionToggle then
				button:SetToggled(action:ActionToggled(host))
			end
			button.action = action
			if self.Show ~= "icon" then
				button:SetTranslate(action.ActionTranslate)
				if action.ActionTranslate then
					button:SetText(action.ActionName ~= "" and action.ActionName or Untranslated(action.ActionId))
				else
					button:SetText(action.ActionName ~= "" and action.ActionName or action.ActionId)
				end
			end
			if action.FXMouseIn ~= "" then
				button:SetFXMouseIn(action.FXMouseIn)
			end
			if action.FXPress ~= "" then
				button:SetFXPress(action.FXPress)
			end
			if action.FXPressDisabled ~= "" then
				button:SetFXPressDisabled(action.FXPressDisabled)
			end
			if self.Show ~= "text" then
				button:SetIcon(action.ActionIcon)
			end
			button.GetRolloverText = function(self)
				local enabled = self:GetEnabled()
				return not enabled and action.RolloverDisabledText ~= "" and action.RolloverDisabledText
						or action.RolloverText ~= "" and action.RolloverText
						or action.ActionName
			end
			button.GetRolloverAnchor = function(self) return self.parent and self.parent:GetRolloverAnchor() end
			button:SetId("id" .. action.ActionId)
			button:Open()
			
			if action.ActionToolbarSplit and i ~= #actions then
				self:AddToolbarSplit()
			end
		end
	end
	if self.AutoHide then
		self:SetVisibleInstant(#self > 0)
	end
	
	
	self.list:SetInitialSelection()
end