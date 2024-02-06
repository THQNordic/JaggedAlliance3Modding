function XEditorGetMapButton(id)
	local buttons = XShortcutsTarget.idMapButtons
	return buttons and buttons[id]
end

function XEditorDeleteMapButtons()
	local buttons = XShortcutsTarget.idMapButtons
	if buttons then
		buttons:delete()
	end
end

function XEditorCreateMapButtons()
	XEditorDeleteMapButtons()
	
	local button_parent = XWindow:new({ IdNode = true, Id = "idMapButtons", Dock = "left" }, XShortcutsTarget.idStatusBox)
	
	-- Open map button
	local button = XTemplateSpawn("XEditorMapButton", button_parent)
	button:SetRolloverText("Open Map (F5)")
	button:SetIcon("CommonAssets/UI/Editor/Tools/ChangeMap")
	button.OnPress = function() XEditorChooseAndChangeMap() end
	
	-- Edit map data button
	local button = XTemplateSpawn("XEditorMapButton", button_parent)
	button:SetRolloverText("Edit Map Data")
	button:SetIcon("CommonAssets/UI/Editor/Tools/EditMapData")
	button.OnPress = function() mapdata:OpenEditor() end
	
	-- Map variations button
	if not config.ModdingToolsInUserMode then
		local button = XTemplateSpawn("XEditorMapButton", button_parent)
		button:SetId("idMapVariationsButton")
		button:SetRolloverAnchor("right")
		button:SetRolloverText("Map variations...")
		button:SetImage("CommonAssets/UI/Editor/ManageMapVariationButton")
		button:SetRows(2)
		button:SetRow(EditedMapVariation and 1 or 2)
		button:SetColumnsUse("abba")
		button:SetBackground(nil)
		button:SetRolloverBackground(nil)
		button:SetPressedBackground(nil)
		button.OnPress = function() XEditorOpenMapVariationsPopup() end
	end
	
	Msg("XWindowRecreated", button_parent)
end
