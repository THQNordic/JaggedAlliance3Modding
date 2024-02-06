if not Platform.developer then
	EditedMapVariation = false
	return
end

----- Notes about the map variation editing internal state
--
-- 1. The *loaded* map variation is stored in CurrentMapVariation; see MapVariationPreset
-- 2. The *edited* map variation is in EditedMapVariation (either false or equal to CurrentMapVariation)
-- 3. The user can hide the *edited map variation*; in this state:
--    a) the user is editing the *base map*, using a different undo queue
--    b) EditedMapVariation becomes false; and HiddenMapVariationUndoIndex stores the last index in the
--       "map variation undo queue"; we rewind to this index when we go back to the *edited map variation*
--    c) the "save map" action saves the *base map*

local function reset_edited_variation()
	EditedMapVariation = false
	EditedMapVariationUndoQueue = false
	OriginalEditorUndoQueue = false
	HiddenMapVariationUndoIndex = false
end

if FirstLoad then
	reset_edited_variation()
end
OnMsg.ChangeMap = reset_edited_variation

local function start_editing_loaded_variation()
	assert(CurrentMapVariation and not EditedMapVariation)
	EditedMapVariationUndoQueue = XEditorUndo
	OriginalEditorUndoQueue = XEditorUndoQueue:new()
	HiddenMapVariationUndoIndex = false
	
	EditedMapVariation = CurrentMapVariation
	XEditorUpdateStatusText()
end

function OnMsg.GameEnterEditor()
	-- initiate editing of the current map variation
	if CurrentMapVariation and not EditedMapVariation and not HiddenMapVariationUndoIndex then
		start_editing_loaded_variation()
	end
end

local function drop_edited_variation_changes()
	assert(CurrentMapVariation and EditedMapVariation and not HiddenMapVariationUndoIndex)
	
	-- reverse everything from the currently edited variation
	HiddenMapVariationUndoIndex = XEditorUndo.undo_index
	while XEditorUndo.undo_index ~= 0 do
		XEditorUndo:UndoRedo("undo")
	end
	EditedMapVariation = false
	EditorMapDirty = false
	XEditorUpdateStatusText()
	
	-- switch back to the "base map editing" undo queue
	XEditorUndo = OriginalEditorUndoQueue
	XEditorUpdateToolbars()
end

local function restore_edited_variation_changes()
	assert(CurrentMapVariation and not EditedMapVariation and HiddenMapVariationUndoIndex)
	
	-- switch to the "map variation editing" undo queue
	XEditorUndo = EditedMapVariationUndoQueue
	XEditorUpdateToolbars()
	
	-- restore map variation changes
	while XEditorUndo.undo_index ~= HiddenMapVariationUndoIndex do
		XEditorUndo:UndoRedo("redo")
	end
	HiddenMapVariationUndoIndex = false
	EditedMapVariation = CurrentMapVariation
	EditorMapDirty = false
	XEditorUpdateStatusText()
end

local function ask_save_and_drop_variation()
	assert(CurrentMapVariation)
	local save_map =
		WaitQuestion(nil, Untranslated("Save changes?"),
			Untranslated(string.format("This will remove any changes made by the current map variation '%s'.\nSave it?", MapVariationNameText(CurrentMapVariation))),
			Untranslated("Yes"), Untranslated("No")) == "ok"
	if HiddenMapVariationUndoIndex then
		restore_edited_variation_changes()
	end
	if save_map then
		SaveMap()
	end
	drop_edited_variation_changes()
end

local function ensure_map_saved(drop_variation)
	if drop_variation and CurrentMapVariation then
		ask_save_and_drop_variation()
	elseif EditorMapDirty then
		if WaitQuestion(nil, Untranslated("Map Not Saved"), Untranslated("The map must be saved before creating/editing a variation.")) ~= "ok" then
			return false
		end
		SaveMap()
	end
	return true
end

function IsMapVariationEdited(preset)
	return EditedMapVariation == preset or CurrentMapVariation == preset and HiddenMapVariationUndoIndex
end

function StopEditingCurrentMapVariation(keep_changes)
	if not keep_changes and not HiddenMapVariationUndoIndex then
		drop_edited_variation_changes()
	end
	CurrentMapVariation = false
	EditedMapVariation = false
	EditedMapVariationUndoQueue = false
	HiddenMapVariationUndoIndex = false
	XEditorUndo = OriginalEditorUndoQueue
	OriginalEditorUndoQueue = false
	XEditorUpdateStatusText()
end


----- UI actions

function XEditorCreateNewVariation()
	if not ensure_map_saved("drop_variation") then
		return
	end
	
	local name = WaitInputText(nil, "Map Variation", "Enter variation name...")
	if not name then return end
	
	local save_in = WaitListChoice(nil, DlcComboItems(), "Save In")
	if not save_in then return end
	save_in = save_in.value
	
	if FindMapVariation(name, save_in) then
		local message = string.format("The map variation '%s' already exists%s.\n\nOverwrite?",
			name, save_in =="" and "" or string.format(" in DLC '%s'", save_in), save_in)
		if WaitQuestion(nil, Untranslated("Error"), Untranslated(message)) ~= "ok" then
			return
		end
	end
	
	XEditorUndo = XEditorUndoQueue:new() -- start on an empty undo queue
	CreateMapVariation(name, save_in)
	start_editing_loaded_variation()
end

function XEditorEditVariation(variation)
	assert(variation and CurrentMapVariation ~= variation)
	if CurrentMapVariation == variation then return end
	
	if not ensure_map_saved("drop_variation") then
		return
	end
	
	-- replace the undo queue with one for editing the map variation
	OriginalEditorUndoQueue = XEditorUndo
	EditedMapVariationUndoQueue = XEditorUndoQueue:new()
	HiddenMapVariationUndoIndex = false
	XEditorUndo = EditedMapVariationUndoQueue
	XEditorUpdateToolbars() -- update undo queue combo
	
	-- apply the patch in this new undo queue for editing
	XEditorApplyMapPatch(variation:GetMapPatchPath())
	CurrentMapVariation = variation
	EditedMapVariation = variation
	XEditorUpdateStatusText() -- update edited map variation, variations button
end

function XEditorHideShowVariation(variation)
	assert(variation == CurrentMapVariation)
	if HiddenMapVariationUndoIndex then
		if not ensure_map_saved() then
			return
		end
		restore_edited_variation_changes()
	else
		drop_edited_variation_changes()
	end
end

function XEditorDeleteVariation(variation)
	if WaitQuestion(nil, Untranslated("Confirmation"),
		Untranslated(string.format("Delete map variation %s?", MapVariationNameText(variation)))) == "ok"
	then
		if variation == CurrentMapVariation then
			StopEditingCurrentMapVariation()
		end
		variation:OnEditorDelete()
		variation:delete()
	end
end

function XEditorMergeVariation(variation)
	assert(variation == CurrentMapVariation)
	if WaitQuestion(nil, Untranslated("Confirmation"),
		Untranslated(string.format("Merge map variation %s into the original map and delete the variation?", MapVariationNameText(variation)))) == "ok"
	then
		if HiddenMapVariationUndoIndex then
			restore_edited_variation_changes()
		end
		StopEditingCurrentMapVariation("keep_changes")
		variation:OnEditorDelete()
		variation:delete()
		XEditorSaveMap()
	end
end


----- Map variations popup UI

DefineClass("XDarkModeAwarePopupList", "XPopupList", "XDarkModeAwareDialog")

function XDarkModeAwarePopupList:Open(...)
	XPopupList.Open(self, ...)
	self:SetDarkMode(GetDarkModeSetting())
end

function XDarkModeAwarePopupList:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" or shortcut == "ButtonB" then
		self:Close()
		return "break"
	end
end

function XEditorOpenMapVariationsPopup()
	local popup = XDarkModeAwarePopupList:new({
		Id = "idMapVariationsPopup",
		Margins = box(0, 2, 0, 2),
		Padding = box(3, 0, 3, 5),
		MinWidth = 360,
		LayoutMethod = "VList",
		DrawOnTop = true,
		HandleMouse = true,
		OnMouseButtonUp = function(self, pt, button)
			if button == "L" then
				if not self:MouseInWindow(pt) then
					self:Close()
				end
				return "break"
			elseif button == "R" then
				self:Close()
				return "break"
			end
		end,
	}, terminal.desktop)
	
	-- header
	local title = XText:new({ TextStyle = "GedTitle", TextHAlign = "center", }, popup)
	title:SetText("Map Variations")
	XWindow:new({ Background = RGB(0, 0, 0), Margins = box(10, 1, 10, 1), MinHeight = 1 }, popup) -- separator
	
	-- footer
	local button_holder = XWindow:new({ Dock = "bottom", HAlign = "center", LayoutMethod = "HList" }, popup)
	XTextButton:new({
		BorderWidth = 1,
		Margins = box(2, 2, 2, 2),
		VAlign = "center",
		Text = "Create new variation",
		FocusedBorderColor = RGB(128, 128, 128),
		DisabledBorderColor = RGB(128, 128, 128),
		RolloverBorderColor = RGB(128, 128, 128),
		PressedBorderColor = RGB(128, 128, 128),
		OnPress = function(button) XEditorCloseVariationsPopup() CreateRealTimeThread(XEditorCreateNewVariation) end,
	}, button_holder)
	if Presets.MapVariationPreset then
		XTextButton:new({
			BorderWidth = 1,
			Margins = box(2, 2, 2, 2),
			VAlign = "center",
			Text = "Manage",
			FocusedBorderColor = RGB(128, 128, 128),
			DisabledBorderColor = RGB(128, 128, 128),
			RolloverBorderColor = RGB(128, 128, 128),
			PressedBorderColor = RGB(128, 128, 128),
			OnPress = function(button)
				if CurrentMapVariation then
					CurrentMapVariation:OpenEditor()
				else
					OpenPresetEditor("MapVariationPreset")
				end
			end,
		}, button_holder)
	end
	local help_text = XText:new({ Dock = "bottom", TextHAlign = "center" }, popup)
	help_text:SetText("<color 128 128 128>Map variations are saved as patches over the base map.\nThis allows editing the base map and the variation changes separately.")
	
	for idx, item in ipairs(MapVariationItems(CurrentMap)) do
		local entry = XContextWindow:new({
			IdNode = true,
			Margins = box(3, 2, 3, 2),
			OnSetRollover = function(self, rollover)
				self:SetBackground(rollover and RGBA(128, 128, 128, 40) or 0)
				self.idHintText:SetVisible(rollover and CurrentMapVariation ~= self.context.value)
			end
		}, popup, item)
		
		-- delete button
		XTextButton:new({
			Dock = "left",
			VAlign = "center",
			Text = "x",
			MaxWidth = 20,
			MaxHeight = 16,
			LayoutHSpacing = 0,
			Padding = box(1, 1, 0, 1),
			Background = RGBA(0, 0, 0, 0),
			RolloverBackground = RGB(204, 232, 255),
			PressedBackground = RGB(121, 189, 241),
			OnPress = function(button) XEditorCloseVariationsPopup() CreateRealTimeThread(XEditorDeleteVariation, item.value) end,
		}, entry)
		
		-- show/hide button
		local showhide_button = XTextButton:new({
			Id = "idShowHideButton",
			Dock = "right",
			FoldWhenHidden = true,
			Margins = box(0, 0, 3, 0),
			BorderWidth = 1,
			VAlign = "center",
			Text = HiddenMapVariationUndoIndex and "Show" or "Hide",
			FocusedBorderColor = RGB(128, 128, 128),
			DisabledBorderColor = RGB(128, 128, 128),
			RolloverBorderColor = RGB(128, 128, 128),
			PressedBorderColor = RGB(128, 128, 128),
			OnPress = function(button) XEditorCloseVariationsPopup() CreateRealTimeThread(XEditorHideShowVariation, item.value) end,
		}, entry)
		showhide_button:SetVisible(CurrentMapVariation == item.value)
		
		-- merge button
		local merge_button = XTextButton:new({
			Id = "idMergeButton",
			Dock = "right",
			FoldWhenHidden = true,
			Margins = box(5, 0, 5, 0),
			BorderWidth = 1,
			VAlign = "center",
			Text = "Merge",
			FocusedBorderColor = RGB(128, 128, 128),
			DisabledBorderColor = RGB(128, 128, 128),
			RolloverBorderColor = RGB(128, 128, 128),
			PressedBorderColor = RGB(128, 128, 128),
			OnPress = function(button) XEditorCloseVariationsPopup() CreateRealTimeThread(XEditorMergeVariation, item.value) end,
		}, entry)
		merge_button:SetVisible(CurrentMapVariation == item.value)
		
		-- edit hint
		local hint_text = XText:new({ Id = "idHintText", Dock = "right", HandleMouse = false, }, entry)
		hint_text:SetText("(click to edit)")
		hint_text:SetVisible(false)
		
		-- variation name
		local name = XText:new({ Dock = "box", Padding = box(0, 2, 2, 2), }, entry)
		name:SetText(item.text)
		name:SetTextStyle(CurrentMapVariation == item.value and "GedHighlight" or "GedDefault")
		name.OnMouseButtonDown = function(win, pt, button)
			XEditorCloseVariationsPopup()
			if CurrentMapVariation ~= item.value then
				CreateRealTimeThread(XEditorEditVariation, item.value)
			end
			return "break"
		end
	end
	
	popup.idContainer:SetBackground(RGB(255, 255, 255))
	popup:SetAnchor(XEditorGetMapButton("idMapVariationsButton").parent.box)
	popup:SetAnchorType("top")
	popup:Open()
	popup:SetModal()
	popup:SetFocus()
	popup.popup_parent = GetDialog("XEditor")
	Msg("XWindowRecreated", popup)
end

function XEditorCloseVariationsPopup()
	local popup = rawget(terminal.desktop, "idMapVariationsPopup")
	if popup then
		popup:Close()
	end
end

OnMsg.GameExitEditor = XEditorCloseVariationsPopup
