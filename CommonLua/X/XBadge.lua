-- Badges are used to display a UI or entity above an object or position.
-- They also allow you to request for an arrow to appear when your object or position
-- is off screen, pointing towards it.

MapVar("g_Badges", {}, weak_keys_meta)
PersistableGlobals.g_Badges = false

function OnMsg.DoneMap()
	if not g_Badges then return end
	for i, t in pairs(g_Badges) do
		for ii, b in ipairs(t) do
			b:CleanOwnedResources()
		end
	end
end

DefineClass.BadgeHolderDialog = {
	__parents = { "XDrawCacheDialog" },
	ZOrder = 0,
	FocusOnOpen = ""
}

DefineClass.XBadge = {
	__parents = { "InitDone" },
	target = false, -- Can be a position or an entity
	targetIsEntity = false,
	targetSpot = false, -- Can be a position or a entity spot
	zoom = false,
	arrowUI = false,
	worldObj = false,
	ui = false,
	visible = true,
	visible_user = true,
	uiHandleMouse = false,
	
	preset = false,
	done = false,
	
	-- If enabled the badge's visibility won't be handled automatically.
	-- This allows for multiple badges on one target.
	custom_visibility = false
}

DefineClass.XBadgeArrow = {
	__parents = { "XImage" },
	UseClipBox = false,
	Clip = false,
	HAlign = "left",
	VAlign = "top"
}

DefineClass.XBadgeEntity = {
	__parents = { "Object", "CameraFacingObject" },
	entity = false
}

function XBadgeEntity:Init()
	self:SetCameraFacing(true)
end

-- Set the badge target. This can either be an entity (with a spot) or a world position.
function XBadge:Setup(target, spot, zoom)
	self.target = target
	self.targetSpot = spot
	self.zoom = zoom
	self.targetIsEntity = IsValid(self.target)
	
	local targetBadges = g_Badges[target]
	if targetBadges then
		targetBadges[#targetBadges + 1] = self
	else
		g_Badges[target] = {self}
	end
end

function XBadge:GetUIAttachArgs()
	local target, targetSpot, zoom = self.target, self.targetSpot, self.zoom
	if IsPoint(target) then
		return {
			id = "attached_ui",
			target = target,
			zoom = zoom,
		}
	elseif targetSpot then
		if IsPoint(targetSpot) then
			return {
				id = "attached_ui",
				target = targetSpot,
				zoom = zoom,
			}
		elseif not IsValidEntity(target:GetEntity())  then
			return {
				id = "attached_ui",
				target = target,
				spot_type = EntitySpots["Origin"],
			}
		else
			if not target:HasSpot(targetSpot) then
				-- if there is no spot of the given type, dynamic pos modifier attaches the UI to spot with index 0
				targetSpot = target:GetSpotName(0)
			end
			return {
				id = "attached_ui",
				target = target,
				spot_type = EntitySpots[targetSpot],
				zoom = zoom,
			}
		end
	else
		return {
			id = "attached_ui",
			target = target,
			zoom = zoom,
		}
	end
end

-- Add an arrow to the badge. This is an UI element, visible when the target is off screen, displayed along the
-- screen's boundaries relative to the direction to the target.
function XBadge:SetupArrow(template, settings)
	EnsureDialog("BadgeHolderDialog")

	if type(template) ~= "string" then template = false end
	local arrowUI = XTemplateSpawn(template or "XBadgeArrow", GetDialog("BadgeHolderDialog"), settings and settings.context)
	
	local mode = const.badgeOn
	if settings and settings.no_rotate then
		mode = const.badgeNoRotate
	end
	local attachArgs = self:GetUIAttachArgs()
	if attachArgs then
		attachArgs.faceTargetOffScreen = mode
		arrowUI:AddDynamicPosModifier(attachArgs)
	end
	arrowUI:Open()
	self.arrowUI = arrowUI
end

-- Badges can be an object in the world.
function XBadge:SetupEntity(entity, attachOffset)
	-- It's possible for the badge entity to be entirely custom.
	local customEntity = g_Classes[entity] and PlaceObject(entity)
	local badgeObj = customEntity or PlaceObject("XBadgeEntity")
	if not badgeObj:ChangeEntity(entity) then
		badgeObj:ChangeEntity(entity)
	end
	
	if customEntity and IsKindOf(badgeObj, "CameraFacingSign") then
		self.targetSpot = badgeObj.attach_spot or self.targetSpot
		attachOffset = attachOffset or badgeObj.attach_offset
	end
	
	-- The target can also be a point.
	if self.targetIsEntity then
		if self.targetSpot then
			if IsPoint(self.targetSpot) then
				self.target:Attach(self.targetSpot)
			else
				self.target:Attach(badgeObj, self.target:GetSpotBeginIndex(self.targetSpot))
			end
		else
			self.target:Attach(badgeObj)
		end
		if attachOffset then badgeObj:SetAttachOffset(attachOffset) end
	else
		local pos = self.target
		if attachOffset then pos = pos + attachOffset end
		badgeObj:SetPos(pos)
	end
	badgeObj:SetGameFlags(const.gofNoDepthTest)
	self.worldObj = badgeObj
end

-- Badges can also display as attached UI
function XBadge:SetupBadgeUI(uiElement, dlgOverride)
	EnsureDialog("BadgeHolderDialog")
	self.ui = uiElement
	rawset(uiElement, "xbadge-instance", self)

	local attachArgs = self:GetUIAttachArgs()
	if attachArgs then uiElement:AddDynamicPosModifier(attachArgs) end
	local oldDestroy = uiElement.OnDelete
	uiElement.OnDelete = function()
		oldDestroy(uiElement)
		if not self.done then
			self:Done()
		end
	end
	uiElement:SetParent(dlgOverride or GetDialog("BadgeHolderDialog"))
	uiElement:Open()
	return uiElement
end

function XBadge:CleanOwnedResources()
	self.done = true
	if self.arrowUI and self.arrowUI.window_state ~= "destroying" then 
		self.arrowUI:Close()
		self.arrowUI = false
	end
	if self.ui and self.ui.window_state ~= "destroying" then
		self.ui:Close()
		self.ui = false
	end
	if self.worldObj then
		DoneObject(self.worldObj)
		self.worldObj = false
	end
end

function XBadge:Done()
	self:CleanOwnedResources()

	local targetBadges = g_Badges[self.target]
	local idx = table.find(targetBadges, self)
	if targetBadges and idx then table.remove(targetBadges, idx) end
	
	self:UpdateVisibilityForMyTarget()
	self.target = false
end

function XBadge:SetVisible(visible)
	if self.visible_user == visible then return end
	self.visible_user = visible
	self:UpdateVisibilityForMyTarget()
end

-- Override this to make your badge visible under specific conditions.
function XBadge:IsBadgeVisibleUserLogic()
	return self.visible_user
end

function XBadge:SetVisibleInternal(visible)
	self.visible = visible
	if self.arrowUI then self.arrowUI:SetVisible(visible) end
	if self.ui then self.ui:SetVisible(visible) end
	if self.worldObj then 
		if visible then
			self.worldObj:SetEnumFlags(const.efVisible)
		else
			self.worldObj:ClearEnumFlags(const.efVisible)
		end
	end
end

function XBadge:UpdateVisibilityForMyTarget()
	local target = self.target
	local badges = g_Badges[target]
	if not badges then return end
	local foundVisible = false
	for i = #badges, 1, -1 do
		local current = badges[i]
		-- Only one badge may be visible per target, unless it is custom_visibility
		if not current.custom_visibility then
			if not foundVisible and current:IsBadgeVisibleUserLogic() then
				foundVisible = true
				current:SetVisibleInternal(true)
			else
				current:SetVisibleInternal(false)
			end
		else
			current:SetVisibleInternal(current:IsBadgeVisibleUserLogic())
		end
	end
	
	Msg("BadgeVisibilityUpdated")
end

-- Spawn a badge with just an arrow.
function SpawnBadge(badgeClass, targetArgs, hasArrow, arrowSettings)
	if not targetArgs then return false end
	local badge = _G[badgeClass or "XBadge"]:new()

	if not targetArgs["class"] and type(targetArgs) == "table" then
		local target = targetArgs["target"]
		local spot = targetArgs["spot"]
		local zoom = targetArgs["zoom"]
		badge:Setup(target, spot, zoom)
	else
		badge:Setup(targetArgs)
	end
	
	if hasArrow then badge:SetupArrow(hasArrow, arrowSettings) end
	return badge
end

-- Create a custom badge with an UI element.
function SpawnBadgeUI(badgeClass, targetArgs, hasArrow, uiTemplate, context)
	if not targetArgs then return false end
	local badge = SpawnBadge(badgeClass, targetArgs, hasArrow)
	if uiTemplate then badge:SetupBadgeUI(XTemplateSpawn(uiTemplate, nil, context)) end
	badge:UpdateVisibilityForMyTarget()
	return badge
end

-- Create a custom badge with a world entity.
function SpawnBadgeEntity(badgeClass, targetArgs, hasArrow, badgeEntity, attachOffset)
	if not targetArgs then return false end
	local badge = SpawnBadge(badgeClass, targetArgs, hasArrow)
	if badgeEntity then 
		badge:SetupEntity(badgeEntity, attachOffset)
		assert(badge.worldObj)
	end
	badge:UpdateVisibilityForMyTarget()
	return badge
end

function CreateBadgeFromPreset(presetName, target, uiContext, dlgOverride)
	local preset = BadgePresetDefs[presetName]
	if not preset then return false end
	
	local targetArgs = target
	if preset.AttachSpotName or preset.ZoomUI then
		targetArgs = { target = target, spot = preset.AttachSpotName, zoom = preset.ZoomUI }
	end

	local badge = SpawnBadge(false, targetArgs, preset.ArrowTemplate, { no_rotate = preset.noRotate, context = uiContext })
	badge.preset = presetName	
	if preset.noHide then badge.custom_visibility = true end
	local ui
	if preset.UITemplate then
		ui = badge:SetupBadgeUI(XTemplateSpawn(preset.UITemplate, nil, uiContext), dlgOverride)
		if ui and preset.handleMouse then
			badge:SetHandleMouse(true)
		end
	end
	if preset.EntityName then
		badge:SetupEntity(preset.EntityName, preset.attachOffset)
	end
	
	-- Sort by priority
	table.sort(g_Badges[badge.target] or empty_table, function(a, b)
		local presetA = a.preset
		local presetB = b.preset
		if not presetA or not presetB then return end
		presetA = BadgePresetDefs[presetA]
		presetB = BadgePresetDefs[presetB]
		return (presetA.BadgePriority or 0) < (presetB.BadgePriority or 0)
	end)
	
	badge:UpdateVisibilityForMyTarget()
	return badge, ui
end

function XBadge:SetHandleMouse(on)
	local ui = self.ui
	self.uiHandleMouse = on

	ui:DeleteThread("badgeMouseThread")
	ui.interaction_box = false
	ui:SetHandleMouse(on)
	if not on then return end

	local attachArgs = self:GetUIAttachArgs()
	ui:CreateThread("badgeMouseThread", function(ctrl, uiTarget, uiSpotType, zoom)
		local targetIsPos = IsPoint(uiTarget)
		local uiSpotIdx = not targetIsPos and uiSpotType and uiTarget:HasSpot(uiSpotType) and uiTarget:GetSpotBeginIndex(uiSpotType)
		local full_scale = point(1000, 1000)
		local last_x, last_y, last_scale
		while ctrl.window_state ~= "destroying" and (targetIsPos or IsValid(uiTarget)) do
			if ctrl.visible then
				local pos_x, pos_y, pos_z
				if targetIsPos then
					pos_x = uiTarget
				elseif uiTarget:IsValidPos() then
					if uiSpotIdx then
						pos_x, pos_y, pos_z = uiTarget:GetSpotLocPosXYZ(uiSpotIdx)
					else
						pos_x, pos_y, pos_z = uiTarget:GetVisualPosXYZ()
					end
				end
				local front, screen_x, screen_y
				if pos_x then
					front, screen_x, screen_y = GameToScreenXY(pos_x, pos_y, pos_z)
				end
				if front then
					local x, y = screen_x, screen_y
					if not ctrl.DontAddBoxToInteractionBox then
						x = x + ctrl.box:minx()
						y = y + ctrl.box:miny()
					end
					local scale = full_scale
					if zoom then
						scale = UIL.GetDynamicPosZoomScale(point(pos_x, pos_y, pos_z))
						scale = point(scale, scale)
					end
					if x ~= last_x or y ~= last_y or scale ~= last_scale then
						ctrl:InvalidateInteractionBox()
						ctrl:SetInteractionBox(x, y, scale, true)
						last_x, last_y, last_scale = x, y, scale
					end
				else
					ctrl:InvalidateInteractionBox()
					ctrl.interaction_box = empty_box
					last_x, last_y, last_scale = nil, nil, nil
				end
			end
			Sleep(50)
		end
	end, ui, attachArgs.target, attachArgs.spot_type, attachArgs.zoom)
end

-- Delete all badges attached to a specific target. Used when an object is destroyed.
function DeleteBadgesFromTarget(target)
	local t = g_Badges[target]
	if not t then return end
	
	for i, b in pairs(t) do
		b:CleanOwnedResources()
	end
	
	g_Badges[target] = nil
end

function TargetHasBadgeOfPreset(preset, target)
	local t = g_Badges[target]
	if not t then return false end
	for i = #t, 1, -1 do
		if t[i].preset == preset then
			return t[i]
		end
	end
end

-- Delete all badges attached to a target of the specified preset.
function DeleteBadgesFromTargetOfPreset(preset, target)
	local t = g_Badges[target]
	if not t then return end
	for i = #t, 1, -1 do
		if t[i].preset == preset then
			t[i]:Done()
		end
	end
end