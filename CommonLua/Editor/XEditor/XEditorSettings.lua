----- Local coordinate system setting for MoveGizmo, RotateGizmo

if FirstLoad then
	LocalStorage.LocalCS = LocalStorage.LocalCS or {}
end

function GetLocalCS()
	local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
	local helper = dialog and g_Classes[dialog.helper_class]
	if helper and helper.HasLocalCSSetting then return LocalStorage.LocalCS[helper.class] end
end

function SetLocalCS(localCS)
	local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
	local helper = dialog and g_Classes[dialog.helper_class]
	if helper and helper.HasLocalCSSetting then
		LocalStorage.LocalCS[helper.class] = localCS
		dialog:UpdatePlacementHelper()
		SaveLocalStorage()
	end
end


----- Snap modes

local snap_modes = {
	{ id = "20cm/15°",    description = "Fine snapping", xy = 20*guic, angle = 15 * 60 },
	{ id = "1m/90°",      description = "Meter snapping", xy = guim, angle = 90 * 60 },
	{ id = "Passability", description = "Snap to passability grid", xy = const.PassTileSize },
	{ id = "Custom",      description = "Custom snapping",  },
}
if const.SlabSizeX then
	table.insert(snap_modes, { id = "Voxels", description = "Snap to voxels/slabs", xy = const.SlabSizeX, z = const.SlabSizeZ, angle = 90 * 60, center = true })
end
if const.HexWidth then
	table.insert(snap_modes, { id = "HexGrid", description = "Snap to hex grid", angle = 60 * 60 })
end
if const.BuildLevelHeight then
	table.insert(snap_modes, { id = "BuildLevel", description = "Snap to build levels", z = const.BuildLevelHeight })
end
for i, item in ipairs(snap_modes) do
	item.shortcut = i == 1 and "Alt-~" or "Alt-" .. string.char(48 + i - 1)
end


----- XEditorSettings (stores global editor settings in LocalStorage, see XEditorToolSettings)
-- 
-- Edited via Ged with shortcut Ctrl-F3 in editor mode

function OnMsg.Autorun()
	EditorSettings = XEditorSettings:new()
	EditorSettingsGedThread = false
end

local rightclick_items = {
	{ id = "ContextMenu", name = "Open context menu" },
	{ id = "ObjectProps", name = "Open object properties" },
}

DefineClass.XEditorSettings = {
	__parents = { "XEditorToolSettings" },
	properties = {
		persisted_setting = true, auto_select_all = true,
		{ category = "General", id = "AutosaveTime", name = "Autosave time (min)", editor = "number", default = 0, min = 0, max = 30, slider = true, help = "Set to zero to disable map autosaves.",
			no_edit = config.ModdingToolsInUserMode, -- auto-saving won't work for game original maps or map patches
		},
		{ category = "General", id = "ShowPlayArea", name = "Show play area", editor = "bool", default = true },
		{ category = "General", id = "CloudShadows", name = "Show cloud shadows", editor = "bool", default = false },
		{ category = "General", id = "TestParticlesOnChange", name = "Replay particles on edit", editor = "bool", default = false },
		{ category = "General", id = "TestParticlesOnChangeHelp", editor = "help", help = "(replay with Shift-E or Z, Alt-E toggles this)" },
		{ category = "UI", id = "AutoFocusMenuSearch",  editor = "bool", name = "Auto focus ~ menu search", default = true },
		{ category = "UI", id = "SmartSelection", name = "Smart selection", editor = "bool", default = true, help = "If no object is found at the precise position of the cursor, search for one by bounding box too." },
		{ category = "UI", id = "HighlightOnHover", name = "Highlight on hover", editor = "bool", default = true },
		{ category = "UI", id = "FilterHighlight", name = "Highlight on filter hover", editor = "bool", default = true },
		{ category = "UI", id = "RightClickOpens", name = "RightClick", editor = "combo", default = "ContextMenu", items = rightclick_items },
		{ category = "UI", id = "CtrlRightClickOpens", name = "Ctrl-RightClick", editor = "combo", default = "ObjectProps", items = rightclick_items, read_only = true, persisted_setting = false },
		{ category = "UI", id = "EditorToolbar", name = "Editor toolbar", editor = "bool", default = true },
		{ category = "UI", id = "DarkMode", name = "Dark mode", editor = "choice", default = "Follow system", items = { "Follow system", "Dark", "Light" } },
		{ category = "UI", id = "MessageBoxFont", name = "Message box font", editor = "choice", default = "Tahoma", items = { { name = "Tahoma (clasic)", value = "Tahoma" }, { name = "Consolas (monospace)", value = "Consolas" } },
			no_edit = config.ModdingToolsInUserMode,
		},
		{ category = "Ged (external editor windows)", id = "GedUIScale", name = "UI scale", editor = "number", min = 75, max = 200, slider = true, default = 100, step = 1 },
		{ category = "Ged (external editor windows)", id = "ColorPickerScale", name = "Color picker scale", editor = "number", min = 100, max = 200, slider = true, default = 100, step = 1 },
		{ category = "Ged (external editor windows)", id = "LimitObjectEditorItems", name = "Limit items in Object editor", editor = "bool", default = true, help = "Only the first 500 objects in the selection will be visible and editable in the Object editor for better performance." },
		{ category = "Gizmos", id = "GizmoThickness", name = "Thickness", editor = "number", min = 25, max = 100, slider = true, default = 75, step = 1 },
		{ category = "Gizmos", id = "GizmoOpacity", name = "Opacity", editor = "number", min = 32, max = 255, slider = true, default = 110, step = 1 },
		{ category = "Gizmos", id = "GizmoScale", name = "Scale", editor = "number", min = 25, max = 100, slider = true, default = 85, step = 1 },
		{ category = "Gizmos", id = "GizmoSensitivity", name = "Active area size", editor = "number", min = 50, max = 200, slider = true, default = 100, step = 1, help = "Adjusts the size of the area where you can grab a gizmo control element, e.g. axis." },
		{ category = "Gizmos", id = "GizmoRotateSnapping", name = "Snap angle in Rotate Gizmo", editor = "bool", default = true, },
		
		-- uneditable properties, used for storing data in LocalStorage only
		{ id = "SnapEnabled", editor = "bool", default = false, no_edit = true },
		{ id = "SnapMode",    editor = "choice", items = snap_modes, default = "", no_edit = true, },
		{ id = "SnapXY",      editor = "number", default = 0, no_edit = true, },
		{ id = "SnapZ",       editor = "number", default = 0, no_edit = true, },
		{ id = "SnapAngle",   editor = "number", default = 0, no_edit = true, },
	},
	ged = false,
	should_open = false,
}

function XEditorSettings:GetCtrlRightClickOpens()
	return self:GetRightClickOpens() == "ContextMenu" and "ObjectProps" or "ContextMenu"
end

function XEditorSettings:GetSnapModes()
	return snap_modes
end

function XEditorSettings:PosSnap(pos, by_slabs)
	local snap_mode = table.find_value(snap_modes, "id", self:GetSnapMode())
	
	if not by_slabs then
		if not self:GetSnapEnabled() or not snap_mode then
			return pos
		end
		if snap_mode.id == "Voxels" then
			return SnapToVoxel(pos + point(0, 0, const.SlabSizeZ / 2))
		end
		if snap_mode.id == "HexGrid" then
			return HexGetNearestCenter(pos)
		end
	end
	
	local center
	local x, y, z = pos:xyz()
	local sx, sy, sz = self:GetSnapXY(), self:GetSnapXY(), self:GetSnapZ()
	if by_slabs then
		sx, sy, sz = const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ
	else
		center = snap_mode.center
	end
	if sx > 0 and sy > 0 then
		if center then x, y = x - sx / 2, y - sy / 2 end
		x = (x + sx / 2) / sx * sx
		y = (y + sy / 2) / sy * sy
		if center then x, y = x + sx / 2, y + sy / 2 end
	end
	if sz > 0 then
		z = z or terrain.GetHeight(pos)
		z = (z + sz / 2) / sz * sz
	end
	return point(x, y, z)
end

function XEditorSettings:AngleSnap(angle, by_slabs)
	local sa = by_slabs and 90 * 60 or self:GetSnapEnabled() and self:GetSnapAngle() or 0
	if sa ~= 0 then
		angle = (angle + sa / 2) / sa * sa
	end
	return angle
end

function XEditorSettings:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "AutosaveTime" then
		EditorAutosaveNextTime = now() + self:GetAutosaveTime() * 60 * 1000
		EditorCreateAutosaveThread()
	elseif prop_id == "CloudShadows" then
		hr.EnableCloudsShadow = self:GetCloudShadows() and 1 or 0
	elseif prop_id == "EditorToolbar" and GetDialog("XEditorToolbar") then
		GetDialog("XEditorToolbar"):SetVisible(self:GetEditorToolbar())
	elseif prop_id == "DarkMode" then
		for id, dlg in pairs(Dialogs) do 
			if IsKindOf(dlg, "XDarkModeAwareDialog") then 
				dlg:SetDarkMode(GetDarkModeSetting())
			end
		end
		for id, socket in pairs(GedConnections) do
			socket:Send("rfnApp", "SetDarkMode", GetDarkModeSetting())
		end
		ReloadShortcuts()
	elseif prop_id == "MessageBoxFont" then
		config.MessageBoxFont = self:GetProperty(prop_id)
	elseif prop_id == "SnapMode" then
		local mode = self:GetSnapMode()
		if mode ~= "Custom" and mode ~= "" then
			local mode = table.find_value(snap_modes, "id", mode)
			self:SetSnapXY(mode.xy)
			self:SetSnapZ(mode.z)
			self:SetSnapAngle(mode.angle)
		end
		self:SetSnapEnabled(true)
		local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
		if dialog then dialog:UpdatePlacementHelper() end
		XEditorUpdateToolbars()
	end
	Msg("EditorSettingChanged", prop_id, self:GetProperty(prop_id))
end

function XEditorSettings:OnShortcut(shortcut, source, ...)
	local dialog = GetDialog("XSelectObjectsTool") or GetDialog("XPlaceObjectTool")
	local helper = dialog and g_Classes[dialog.helper_class]
	if shortcut == "X" and helper and helper.HasSnapSetting then
		XEditorSettings:SetSnapEnabled(not XEditorSettings:GetSnapEnabled())
		XEditorUpdateToolbars()
		return "break"
	end
	for _, mode in ipairs(snap_modes) do
		if shortcut == mode.shortcut and helper and helper.HasSnapSetting then
			XEditorSettings:SetSnapMode(mode.id)
			XEditorSettings:OnEditorSetProperty("SnapMode")
			XEditorUpdateToolbars()
			return "break"
		end
	end
	return XEditorTool.OnShortcut(self, shortcut, source, ...)
end

function XEditorSettings:ToggleGedEditor()
	self.should_open = not self.should_open
	
	if not IsValidThread(EditorSettingsGedThread) then
		EditorSettingsGedThread = CreateRealTimeThread(function()
			while true do
				if not self.ged and self.should_open then
					self.ged = OpenGedApp("XEditorSettings", EditorSettings, nil, "XEditorSettings", true)
				elseif self.ged and not self.should_open then
					CloseGedApp(self.ged, "wait")
					self.ged = false
				end
				Sleep(100)
			end
		end)
	end
end
