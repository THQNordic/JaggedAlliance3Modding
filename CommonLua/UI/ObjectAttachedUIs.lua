local find = table.find
local find_value = table.find_value
local remove = table.remove

if FirstLoad then
	ObjectUIAttachData = {}
	AttachedUIDisplayMode = "Gameplay"
	g_DesktopBox = false
	g_ObjectToAttachedWin = false
	g_ObjectToAttachedData = false
end

local function InitAttachedUITables()
	ObjectUIAttachData = {}
	g_ObjectToAttachedWin = {}
	g_ObjectToAttachedData = {}
end

OnMsg.ChangeMap = InitAttachedUITables
OnMsg.LoadGame = InitAttachedUITables

local function RecalcDesktopBox(pt)
	pt = pt or UIL.GetScreenSize()
	local offset = 200
	g_DesktopBox = sizebox(-offset, -offset, pt:x() + 2 * offset, pt:y() + 2 * offset)
end

function OnMsg.SystemSize(pt)
	RecalcDesktopBox(pt)
end

DefineClass.ObjectsUIAttachDialog = {
	__parents = { "XDrawCacheDialog" },
	FocusOnOpen = "",
	ZOrder = 0,
	UseClipBox = false,
}

function ObjectsUIAttachDialog:Init()
	local cursor_text = XText:new({
		Id = "idCursorText",
		HAlign = "left",
		VAlign = "top",
		ZOrder = 10,
		Margins = box(30,30,0,0),
		Clip = false,
		TextStyle = "UIAttachCursorText",
		Translate = true,
		HideOnEmpty = true,
		UseClipBox = false,
	}, self)
	cursor_text:SetVisible(false)
end

function ObjectsUIAttachDialog:Open(...)
	XDrawCacheDialog.Open(self, ...)
	self:StartVisibilityThread()
end

local function IsVisibleInAttachedUIDisplayMode(data)
	-- if there is no data, we can not say whether this should be hidden
	if not data then return true end
	local current_mode = AttachedUIDisplayMode
	local mode = data.attach_ui_mode or "Gameplay"
	if type(mode) == "table" then
		return find(mode, current_mode)
	else
		return mode == current_mode
	end
end

function ObjectsUIAttachDialog:StartVisibilityThread()
	self:DeleteThread("visibility_thread")
	self:CreateThread("visibility_thread", function()
		while true do
			Sleep(100)
			local overview = GetInGameInterfaceMode() == config.InGameOverviewMode
			local cam_pos = camera.GetPos()
			local object_to_data = g_ObjectToAttachedData
			local presets = Presets.AttachedUIPreset.Default
			for obj, win in pairs(g_ObjectToAttachedWin) do
				local data = object_to_data[obj]
				local visible = data.visible and not overview and IsVisibleInAttachedUIDisplayMode(data)
				local valid = IsValidPos(obj)
				if visible and valid then
					if obj.hide_attached_ui_when_transparent then
						visible = obj:GetOpacity() ~= 0
					end
					if visible then
						local spot = data and data.spot
						spot = spot and obj:HasSpot(spot) and spot or "Origin"
						local x, y, z = obj:GetSpotPosXYZ(obj:GetSpotBeginIndex(spot))
						if z then
							local front, sx, sy = GameToScreenXY(x, y, z)
							visible = front and g_DesktopBox:Point2DInside(sx, sy)
						end
						if visible and cam_pos:IsValid() then
							local modifier = find_value(win.modifiers, "id", "attached_ui")
							local dist = modifier and modifier.max_cam_dist_m
							local cam_dist = cam_pos:Dist(x, y, z)
							visible = not dist or dist*guim >= cam_dist
							win.ZOrder = -cam_dist -- skip window invalidation by setting this directly instead of calling :SetZOrder
						end
					end
				end
				win:SetVisible(visible)
				if visible and valid and PropObjHasMember(obj, "SetInViewUIInteractionBox") then
					local preset = presets[data.template]
					obj:SetInViewUIInteractionBox(win, data.spot, preset and preset.zoom)
				end
			end
			self:SortChildren()
			if overview then
				WaitMsg("CameraTransitionEnd")
			end
		end
	end)
end

function ObjectsUIAttachDialog:UpdateMeasure(max_width, max_height)
	-- skip some logic we don't need; the general logic called InvalidateLayout, triggering XTexts:UpdateMeasure which is slow
	self.last_max_width = max_width
	self.last_max_height = max_height
	if not self.measure_update then return end
	
	self.measure_update = false
	for _, win in ipairs(self) do
		win:UpdateMeasure(max_width, max_height)
	end
	self.measure_width = max_width
	self.measure_height = max_height
end

function SetAttachedUIDisplayMode(mode)
	AttachedUIDisplayMode = mode
end

local box0 = box(0, 0, 0, 0)
local function AttachUIToObject(obj, params)
	if (not IsValid(obj) and obj ~= "mouse" and obj ~= "gamepad") or not params.template then return end
	local win_parent = params.win_parent or GetDialog("ObjectsUIAttachDialog")
	local spot = params.spot
	spot = spot and IsValid(obj) and obj:HasSpot(spot) and spot or "Origin"
	local win = XTemplateSpawn(params.template, win_parent, params.context)
	win:SetVisible(false)
	g_ObjectToAttachedWin[obj] = win
	g_ObjectToAttachedData[obj] = params
	local old_OnLayoutComplete = win.OnLayoutComplete
	win.OnLayoutComplete = function(self)
		old_OnLayoutComplete(self)
		if self.box ~= box0 then
			if (IsValid(obj) or obj == "mouse" or obj == "gamepad") and ObjectUIAttachData[obj] then
				self:SetMargins(box(0, MulDivRound(-self.content_box:sizey(), 1000, self.scale:y()), 0, 0))
			elseif self.window_state ~= "destroying" then
				ObjectUIAttachData[obj] = nil
				g_ObjectToAttachedWin[obj] = nil
				g_ObjectToAttachedData[obj] = nil
				self:delete()
			end
		end
	end
	local preset = Presets.AttachedUIPreset.Default[params.template]
	win:AddDynamicPosModifier({
		id = "attached_ui",
		target = obj,
		spot_type = IsValid(obj) and EntitySpots[spot],
		zoom = preset and preset.zoom,
		max_cam_dist_m = preset and preset.max_cam_dist_m,
		visible = ShouldAttachedUIToObjectBeVisible(obj, params.template),
	})
	win:Open()
	return win
end

local function AttachUIResolvePriority(obj)
	local data = ObjectUIAttachData[obj] or empty_table
	local max_priority
	local params
	for _, row in ipairs(data) do
		if (row.priority or 0) > (max_priority or 0) then
			max_priority = row.priority
			params = row
		end
	end
	if g_ObjectToAttachedData[obj] ~= params then
		local win = g_ObjectToAttachedWin[obj]
		if win then
			if win.window_state ~= "destroying" then
				win:delete()
			end
			g_ObjectToAttachedWin[obj] = nil
			g_ObjectToAttachedData[obj] = nil
		end
		if params then
			AttachUIToObject(obj, params)
		end
	end
end

function GetAttachedUIToObject(obj)
	return g_ObjectToAttachedWin[obj]
end

ShouldAttachedUIToObjectBeVisible = return_true

function AddAttachedUIToObject(obj, template, spot, context, win_parent)
	local preset = Presets.AttachedUIPreset.Default[template]
	local priority = preset and preset.SortKey
	assert(priority, string.format("Template %s has no corresponding entry with priority in AttachedUIPreset.Default", template))
	local data = ObjectUIAttachData[obj] or {}
	if find(data, "template", template) then return end -- can't attach same template twice
	data[#data + 1] = {
		template = template,
		spot = spot,
		priority = priority,
		context = context,
		win_parent = win_parent,
		attach_ui_mode = preset and preset.attach_ui_modes,
		visible = ShouldAttachedUIToObjectBeVisible(obj, template),
	}
	ObjectUIAttachData[obj] = data
	AttachUIResolvePriority(obj)
end

function RemoveAttachedUIToObject(obj, template)
	local data = ObjectUIAttachData[obj]
	if not data then return end
	local idx = find(data, "template", template)
	if idx then
		remove(ObjectUIAttachData[obj], idx)
		if #ObjectUIAttachData[obj] == 0 then
			ObjectUIAttachData[obj] = nil
		end
		AttachUIResolvePriority(obj)
	end
end

function RemoveAllAttachedUIsToObject(obj)
	local win = g_ObjectToAttachedWin[obj]
	if win and win.window_state ~= "destroying" then
		win:delete()
	end
	g_ObjectToAttachedWin[obj] = nil
	g_ObjectToAttachedData[obj] = nil
	ObjectUIAttachData[obj] = nil
end

function SetAttachedUITemplatesVisible(visible, templates_set)
	for obj, wins in pairs(ObjectUIAttachData) do
		for _, win in ipairs(wins) do
			if templates_set[win.template] then
				win.visible = visible
			end
		end
	end
	for obj, data in pairs(g_ObjectToAttachedData) do
		if templates_set[data.template] then
			data.visible = visible
		end
	end
end

function InitObjectsUIAttachDialog()
	if not mapdata.GameLogic then return end
	
	OpenDialog("ObjectsUIAttachDialog", GetInGameInterface())
	for obj, data in pairs(ObjectUIAttachData) do
		AttachUIResolvePriority(obj)
	end
	
	Msg("InitObjectsUIAttach")
end

if Platform.developer then

function GetAttachedUIsFor(obj)
	local result
	for _, win in ipairs(GetDialog("ObjectsUIAttachDialog")) do
		if ResolvePropObj(win.context) == obj then
			result = table.create_add(result, win)
		end
	end
	return result, #(result or "")
end

end