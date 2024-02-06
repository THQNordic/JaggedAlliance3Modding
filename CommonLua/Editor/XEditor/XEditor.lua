SetupVarTable(editor, "editor.")

if FirstLoad then
	XEditorHideTexts = false
	XEditorOriginalHandleRand = HandleRand
end

XEditorHRSettings = { 
	ResolutionPercent = 100,
	EnablePreciseSelection = 1,
	ObjectCounter = 1,
	VerticesCounter = 1,
	TR_MaxChunksPerFrame=100000,
}

-- function for generating random handles (used by undo / map patches / map modding)
local handle_seed = AsyncRand()
function XEditorNewHandleRand(rand) rand, handle_seed = BraidRandom(handle_seed, rand) return rand end
function XEditorGetHandleSeed(seed) return handle_seed end
function XEditorSetHandleSeed(seed) handle_seed = seed end

function IsEditorActive()
	return editor.Active
end

function EditorActivate()
	if Platform.editor and not editor.Active and GetMap() ~= "" then
		editor.Active = true
		NetPauseUpdateHash("Editor")
		local executeBeforeEnter = {}
		Msg("GameEnteringEditor", executeBeforeEnter)
		for _, fn in ipairs(executeBeforeEnter) do
			fn()
		end
		OpenDialog("XEditor")
		HandleRand = XEditorNewHandleRand
		Msg("GameEnterEditor")
		SuspendDesyncErrors("Editor")
	end
end

function EditorDeactivate()
	if editor.Active then
		editor.Active = false
		local executeBeforeExit = {}
		Msg("GameExitEditor", executeBeforeExit)
		for _, fn in ipairs(executeBeforeExit) do
			fn()
		end
		HandleRand = XEditorOriginalHandleRand
		CloseDialog("XEditor")
		NetResumeUpdateHash("Editor")
		ResumeDesyncErrors("Editor")
	end
end

function OnMsg.ChangeMap(map)
	if map == "" then
		EditorDeactivate()
	end
end

if FirstLoad then
	CameraMaxZoomSpeed     = tonumber(hr.CameraMaxZoomSpeed)
	CameraMaxZoomSpeedSlow = tonumber(hr.CameraMaxZoomSpeedSlow)
	CameraMaxZoomSpeedFast = tonumber(hr.CameraMaxZoomSpeedFast)
end

function OnMsg.ChangeMapDone(map)
	if map == "" then return end
	
	local small_map_size = 1024 * guim
	local map_size = Max(terrain.GetMapSize())
	local coef = Max(map_size * 1.0 / small_map_size, 1.0)
	hr.CameraMaxZoomSpeed     = tostring(CameraMaxZoomSpeed     * coef)
	hr.CameraMaxZoomSpeedSlow = tostring(CameraMaxZoomSpeedSlow * coef)
	hr.CameraMaxZoomSpeedFast = tostring(CameraMaxZoomSpeedFast * coef)
end


----- XEditor (the main fullscreen transparent dialog for the map editor)
--
-- This dialog's mode is the name of the XEditorTool currently active and created as a child dialog

DefineClass.XEditor = {
	__parents = { "XDialog" },
	Dock = "box",
	InitialMode = "XEditorTool",
	ZOrder = -1,
	
	mode = false,
	mode_dialog = false,
	play_box = false,
	toolbar_context = false,
	help_popup = false,
}

function XEditor:Open(...)
	local size = terrain.GetMapSize()
	XChangeCameraTypeLayer:new({ CameraType = "cameraMax", CameraClampXY = size, CameraClampZ = 2 * size }, self)
	XPauseLayer:new({ togglePauseDialog = false, keep_sounds = true }, self)
	
	-- editor mode init
	XShortcutsSetMode("Editor", function() EditorDeactivate() end)
	XEditorHRSettings.EnableCloudsShadow = EditorSettings:GetCloudShadows() and 1 or 0
	table.change(hr, "Editor", XEditorHRSettings)
	SetSplitScreenEnabled(false, "Editor")
	ShowMouseCursor("Editor")
	
	self.toolbar_context = {
		filter_buttons = LocalStorage.FilteredCategories,
		roof_visuals_enabled = LocalStorage.FilteredCategories["Roofs"],
	}
	OpenDialog("XEditorToolbar", XShortcutsTarget, self.toolbar_context):SetVisible(EditorSettings:GetEditorToolbar())
	OpenDialog("XEditorStatusbar", XShortcutsTarget, self.toolbar_context)
	
	if EditorSettings:GetShowPlayArea() then
		self.play_box = PlaceTerrainBox(GetPlayBox(), nil, nil, nil, nil, "depth test")
	end
	
	-- open editor
	XDialog.Open(self, ...)
	CreateRealTimeThread(XEditorUpdateHiddenTexts)
	self:NotifyEditorObjects("EditorEnter")
	ShowConsole(false)
	
	if IsKindOf(XShortcutsTarget, "XDarkModeAwareDialog") then
		XShortcutsTarget:SetDarkMode(GetDarkModeSetting())
	end
	
	-- set up default tool
	self:SetMode("XSelectObjectsTool")
	editor.SetSel(SelectedObj and { SelectedObj } or Selection)
	
	-- open help the first time
	if not LocalStorage.editor_help_shown then
		self:ShowHelpText()
		LocalStorage.editor_help_shown = true
		SaveLocalStorage()
	end
end

function XEditor:Close(...)
	-- editor mode deinit
	XShortcutsSetMode("Game")
	table.restore(hr, "Editor")
	SetSplitScreenEnabled(true, "Editor")
	HideMouseCursor("Editor")
	CloseDialog("XEditorToolbar")
	CloseDialog("XEditorStatusbar")
	CloseDialog("XEditorRoomTools")
	editor.ClearSel()
	XShortcutsTarget:SetStatusTextLeft("")
	XShortcutsTarget:SetStatusTextRight("")
	XEditorDeleteMapButtons()
	if self.help_popup and self.help_popup.window_state == "open" then
		self.help_popup:Close()
	end
	
	if IsValid(self.play_box) then
		DoneObject(self.play_box)
	end
	
	-- close editor
	self:NotifyEditorObjects("EditorExit")
	XDialog.Close(self, ...)
end

function XEditor:NotifyEditorObjects(method)
	SuspendPassEdits("Editor")
	MapForEach(true, "EditorObject", function(obj)
		if not EditorCursorObjs[obj] then
			obj[method](obj)
		end
	end)
	ResumePassEdits("Editor")
end

function XEditor:SetMode(mode, context)
	if mode == self.Mode and (context or false) == self.mode_param then return end
	if self.mode_dialog then
		self.mode_dialog:Close()
		XPopupMenu.ClosePopupMenus()
	end
	
	self:UpdateStatusText()
	
	assert(IsKindOf(g_Classes[mode], "XEditorTool"))
	self.mode_dialog = OpenDialog(mode, self, context)
	self.mode_param = context
	self.Mode = mode
	self:ActionsUpdated()
	GetDialog("XEditorToolbar"):ActionsUpdated()
	GetDialog("XEditorStatusbar"):ActionsUpdated()
	XEditorUpdateToolbars()
	if not self.mode_dialog.ToolKeepSelection then
		editor.ClearSel()
	end
	self.mode_dialog:SetFocus()
	
	Msg("EditorToolChanged", mode, IsKindOf(self.mode_dialog, "XEditorPlacementHelperHost") and self.mode_dialog.helper_class)
end

function XEditor:UpdateStatusText()
	local left_status = mapdata.ModMapPath and _InternalTranslate(mapdata.DisplayName, nil, false) or mapdata.id
	if config.ModdingToolsInUserMode then
		local extra_row =
			(not mapdata.ModMapPath and not editor.ModItem) and "<color 255 60 60>Original map - saving disabled!" or
			not editor.IsModdingEditor() and "<color 255 60 60>Editor not opened from a mod item - saving disabled!" or
			editor.ModItem:IsPacked() and "<color 255 60 60>The map's mod is not unpacked for editing - saving disabled!" or
				string.format("%s%s", editor.ModItem:GetEditorMessage(), Literal(editor.ModItem.mod.title)) -- a saveable mod map
		left_status = string.format("%s\n%s", left_status, extra_row)
	else
		left_status = left_status .. (mapdata.group ~= "Default" and " (" .. mapdata.group .. ")" or "")
		if EditedMapVariation then
			left_status = string.format("%s\n<style EditorMapVariation>Variation: %s", left_status, EditedMapVariation.id)
			if EditedMapVariation.save_in ~= "" then
				left_status = left_status .. string.format(" (%s)", EditedMapVariation.save_in)
			end
		end
	end	
	
	XShortcutsTarget:SetStatusTextLeft(left_status)
	XShortcutsTarget:SetStatusTextRight(string.format("Object details: %s (Ctrl-Alt-/)", EngineOptions.ObjectDetail))
	XEditorCreateMapButtons()
end

function XEditor:ShowHelpText()
	self.help_popup = CreateMessageBox(XShortcutsTarget,
		Untranslated("Welcome to the Map Editor!"),
		Untranslated([[Here are some short tips to get you started.

Camera controls:
  • <mouse_wheel_up> - zoom in/out
  • hold <middle_click> - pan the camera
  • hold Ctrl - faster movement
  • hold Alt - look around
  • hold Ctrl+Alt - rotate camera

Look through the editor tools on the left - for example, press N to place objects.

Use <right_click> to access object properties and actions.]]))
end


----- UI

function OnMsg.ShortcutsReloaded()
	XShortcutsTarget:ActionById("E_EditorSettings"):SetActionSortKey("999998")
	XShortcutsTarget:ActionById("E_EditorHelpText"):SetActionSortKey("999999")
end

function OnMsg.EditorSelectionChanged()
	local xeditor = GetDialog("XEditor")
	if xeditor then
		ObjModified(xeditor.toolbar_context)
	end
end

function OnMsg.DevMenuVisible(visible)
	local toolbar = GetDialog("XEditorToolbar")
	if toolbar then
		toolbar:SetVisible(visible and EditorSettings:GetEditorToolbar())
	end
end

function OnMsg.ChangeMapDone()
	if IsEditorActive() then
		local dlg = GetDialog("XEditor")
		dlg:NotifyEditorObjects("EditorEnter")
		dlg:UpdateStatusText()
		if not cameraMax.IsActive() then
			cameraMax.Activate()
		end
	end
end


----- Toggle code renderables on when a tool needs them

function OnMsg.EditorToolChanged(mode, helper_class)
	if g_Classes[mode].UsesCodeRenderables or helper_class and g_Classes[helper_class].UsesCodeRenderables then
		if hr.RenderCodeRenderables == 0 then
			hr.RenderCodeRenderables = 1
			local statusbar = GetDialog("XEditorStatusbar")
			if statusbar then
				statusbar:ActionsUpdated()
			end
			ExecuteWithStatusUI("Code renderables turned ON!", function() Sleep(2000) end)
		end
	end
	XEditorSettingsJustOpened = XEditorGetCurrentTool().FocusPropertyInSettings
end

function OnMsg.EditorSelectionChanged(sel)
	if hr.RenderCodeRenderables == 0 and #sel > 0 then
		ExecuteWithStatusUI("Code renderables are OFF!\n\nPress Alt-Shift-R to show selection.", function() Sleep(1000) end)
	end
end


----- Context menu

if FirstLoad then
	XEditorContextMenu = false
end

function XEditorOpenContextMenu(context, pos)
	XEditorContextMenu = XShortcutsTarget:OpenContextMenu(context, pos)
end

function XEditorIsContextMenuOpen()
	return XEditorContextMenu and XEditorContextMenu.window_state == "open"
end


----- Autosave

if FirstLoad then
	EditorAutosaveThread = false
	EditorAutosaveNextTime = false
end

function EditorCreateAutosaveThread()
	EditorDeleteAutosaveThread()
	EditorAutosaveThread = CreateRealTimeThread(function()
		if EditorSettings:GetAutosaveTime() == 0 or config.ModdingToolsInUserMode then return end
		EditorAutosaveNextTime = EditorAutosaveNextTime or now() + EditorSettings:GetAutosaveTime() * 60 * 1000
		while true do
			if EditorAutosaveNextTime > now() then
				Sleep(EditorAutosaveNextTime - now())
			end
			XEditorSaveMap()
			EditorAutosaveNextTime = now() + EditorSettings:GetAutosaveTime() * 60 * 1000
		end
	end)
end

function EditorDeleteAutosaveThread()
	DeleteThread(EditorAutosaveThread)
end

OnMsg.GameEnterEditor = EditorCreateAutosaveThread
OnMsg.GameExitEditor = EditorDeleteAutosaveThread


----- Globals

function XEditorGetCurrentTool()
	return GetDialog("XEditor") and GetDialog("XEditor").mode_dialog
end

function XEditorIsDefaultTool()
	return GetDialogMode("XEditor") == "XSelectObjectsTool"
end

function XEditorSetDefaultTool(helper_class, properties)
	XEditorShowCustomFilters = false
	if XEditorIsDefaultTool() then
		ObjModified(XEditorGetCurrentTool())
		XEditorUpdateToolbars()
	end
	SetDialogMode("XEditor", "XSelectObjectsTool")
	if helper_class then
		GetDialog("XEditor").mode_dialog:SetHelperClass(helper_class, properties)
	end
end

function XEditorRemoveFocusFromToolbars()
	local focused_ctrl = terminal.desktop:GetKeyboardFocus()
	if focused_ctrl and (GetDialog(focused_ctrl) == GetDialog("XEditorToolbar") or GetDialog(focused_ctrl) == GetDialog("XEditorStatusbar")) then
		terminal.desktop:RemoveKeyboardFocus(focused_ctrl, true)
	end
end

function XEditorUpdateToolbars()
	local editor = GetDialog("XEditor")
	if editor then -- make sure toolbars aren't updated "too often", e.g. with quick mouse clicks
		editor:DeleteThread("toolbar_update")
		editor:CreateThread("toolbar_update", function()
			Sleep(200)
			ObjModified(editor.toolbar_context)
		end)
	end
end

function XEditorUpdateStatusText() -- above the status bar
	local editor = GetDialog("XEditor")
	if editor then
		editor:UpdateStatusText()
	end
end

function XEditorSaveMap(skipBackup, force)
	WaitChangeMapDone()
	ExecuteWithStatusUI(
		EditedMapVariation and "Saving map variation..." or "Saving map...",
		function() SaveMap(skipBackup, force) end,
		"wait")
end

function XEditorGetVisibleObjects(filter_func)
	local frame = (GetFrameMark() / 1024 - 1) * 1024
	filter_func = filter_func or function() return true end
	return MapGet("map", "attached", false, nil, const.efVisible, function(x) return x:GetFrameMark() - frame > 0 and filter_func(x) end) or empty_table
end

local function ApproxDisplayColor(color)
	local r, g, b = GetRGB(color)
	local upper_bound = Max(100, Max(r, Max(g, b)))
	r = MulDivRound(r, 255, upper_bound)
	g = MulDivRound(g, 255, upper_bound)
	b = MulDivRound(b, 255, upper_bound)
	return RGB(r, g, b)
end

function GetTerrainTexturesItems()
	local items = {}	
	for _, descr in pairs(TerrainTextures) do
		local image = GetTerrainImage(descr.basecolor)
		items[#items + 1] = {
			text = descr.id,
			value = descr.id,
			color = ApproxDisplayColor(descr.color_modifier),
			image = image,
		}
	end
	table.sortby_field(items, "value")
	return items
end

function GetDarkModeSetting()
	local setting = XEditorSettings:GetDarkMode()
	if setting == "Follow system" then
		return GetSystemDarkModeSetting()
	else
		return setting and setting ~= "Light"
	end
end

function CanSelect(obj)
	if not obj or not editor.CanSelect(obj) then
		if not const.SlabSizeX or not IsKindOf(obj, "EditorLineGuide") then
			return false
		end
	end
	if XEditorShowCustomFilters then
		local filter_mode = XSelectObjectsTool:GetFilterMode()
		local objects = XSelectObjectsTool:GetFilterObjects() or empty_table
		local filtered = objects[XEditorPlaceId(obj)]
		if filter_mode == "On" and not filtered or filter_mode == "Negate" and filtered then
			return false
		end
	end
	return XEditorFilters:CanSelect(obj)
end

-- WARNING: This function should be kept VERY fast, it is called on every frame and mouse move in editor mode!
function GetObjectAtCursor()
	-- return already selected Decals/WaterObjs with priority to allow editing them
	local sel = GetNextObjectAtScreenPos(function(o) return IsKindOfClasses(o, "Decal", "WaterObj") and editor.IsSelected(o) end, "topmost")
	if sel then return sel end
	
	local solid, transparent = GetPreciseCursorObj()
	local obj = (CanSelect(transparent) and transparent) or (CanSelect(solid) and solid)
	obj = obj or XEditorSettings:GetSmartSelection() and GetNextObjectAtScreenPos(CanSelect, "topmost")
	-- GetPreciseCursorObj never returns Decals/WaterObj; select those objects with lower priority if no other object was found
	return obj or GetNextObjectAtScreenPos(function(o) return IsKindOfClasses(o, "Decal", "WaterObj") and CanSelect(o) end, "topmost")
end

function HasAlignedObjs(objs)
	for _, obj in ipairs(objs) do
		if obj:IsKindOf("AlignedObj") then
			return true
		end
	end
end

function XEditorSnapPos(obj, initial_pos, delta, by_slabs)
	if obj:IsKindOf("AlignedObj") then
		if obj.AlignObj ~= AlignedObj.AlignObj then -- editor should not assert when placing object that didn't implement AlignObj
			obj:AlignObj(initial_pos + delta)
		end
	elseif by_slabs then
		obj:SetPos(initial_pos + XEditorSettings:PosSnap(delta, "by_slabs")) -- snap the delta by slab to preserve relative object distances
	else
		obj:SetPos(XEditorSettings:PosSnap(initial_pos + delta))
	end
end

function XEditorSetPosAxisAngle(obj, pos, axis, angle)
	if obj:IsKindOf("AlignedObj") then
		obj:AlignObj(pos, angle, axis)
	else
		obj:SetPos(pos)
		if axis and angle then
			obj:SetAxisAngle(axis, angle)
		end
	end
end

local suspend_id = 1

function SuspendPassEditsForEditOp(objs)
	NetPauseUpdateHash("EditOp")
	table.change(config, "XEditor"..suspend_id, {
		PartialPassEdits = #(objs or editor.GetSel()) < 500,
	})
	SuspendPassEdits("XEditor"..suspend_id)
	suspend_id = suspend_id + 1
end

function ResumePassEditsForEditOp()
	suspend_id = suspend_id - 1
	ResumePassEdits("XEditor"..suspend_id, true)
	table.restore(config, "XEditor"..suspend_id, true)
	NetResumeUpdateHash("EditOp")
	assert(suspend_id >= 1)
end

function ArePassEditsForEditOpSuspended()
	return suspend_id > 1
end

function XEditorGroupsComboItems(objects)
	local items = {}
	local read_only = #objects == 0
	local group_names = table.keys2(Groups or empty_table, "sorted")
	for _, name in ipairs(group_names) do
		local group = Groups[name]
		if next(group) then
			local in_group_count = #table.intersection(group, objects)
			items[#items + 1] = {
				id = name,
				value = not read_only and in_group_count == #objects and true or in_group_count > 0 and Undefined() or false,
				read_only = read_only,
			}
		end
	end
	return items
end

local cam_pos, cam_lookat, stored_sel

function XEditorShowObjects(objs, show)
	if show == "select_permanently" then
		editor.ClearSel("dont_notify")
		editor.SetSel(objs)
		ViewObjects(objs)
		cam_pos, cam_lookat, stored_sel = nil, nil, nil
	elseif show then
		cam_pos, cam_lookat = GetCamera()
		stored_sel = editor.GetSel()
		editor.SetSel(objs, "dont_notify")
		ViewObjects(objs)
	elseif cam_pos then
		SetCamera(cam_pos, cam_lookat)
		editor.SetSel(stored_sel, "dont_notify")
	end
end

function XEditorUpdateHiddenTexts()
	for _, obj in ipairs(MapGet("map", "Text")) do
		if obj.hide_in_editor then
			obj:SetVisible(not XEditorHideTexts)
		end
	end
end

function XEditorChooseAndChangeMap()
	if IsMessageBoxOpen("XEditorChooseAndChangeMap") then return end
	CreateRealTimeThread(function()
		local caption = "Choose map:"
		local maps = table.ifilter(ListMaps(), function(idx, map) return not IsOldMap(map) end)
		table.insert(maps, 1, "")
		local parent_container = XWindow:new({}, terminal.desktop)
		parent_container:SetScaleModifier(point(1250, 1250))
		
		local map = WaitListChoice(parent_container, maps, caption, GetMapName(), nil, nil, "XEditorChooseAndChangeMap")
		if not map then return end
		
		DeveloperChangeMap(map)
	end)
end