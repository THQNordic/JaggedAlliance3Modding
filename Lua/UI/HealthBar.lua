DefineClass.HealthBar = {
	__parents = {"XFrame", "XContextControl"},
	properties = {
		{ category = "Progress", id = "MaxValueProperty", name = "Max Value Property", editor = "text", default = "MaxHitPoints", },
		{ category = "Progress", id = "Progress", name = "Progress values", editor = "number_list", default = {}, item_default = 0, invalidate = "measure" },
		{ category = "Progress", id = "MaxProgress", name = "Max progress", editor = "number", default = const.Combat.HealthPointsCap, invalidate = true, },
		{ category = "Progress", id = "MinProgressSize", name = "Size at progress 0", editor = "number", default = 0 },
		{ category = "Progress", id = "DisplayTempHp", name = "Display Temporary HitPoints", editor = "bool", default = false },
		{ category = "Progress", id = "FitSegments", name = "Fit Segments", help = "Fit segments in the max width", editor = "bool", default = false },
		
		{ category = "Icons", id = "ShowIcons", name = "Show Prediction Icons", editor = "bool", default = false, },

		{ category = "Icons", id = "PotentialDeathIcon", name = "Potential Death Icon", editor = "ui_image", default = "UI/Hud/death_blow", },
		{ category = "Icons", id = "CoverIcon", name = "Cover Icon", editor = "ui_image", default = "UI/Hud/cover", },
		{ category = "Icons", id = "CoverExposeIcon", name = "Cover Icon", editor = "ui_image", default = "UI/Hud/enemy_broken_cover", },
		{ category = "Icons", id = "ObstructedIcon", name = "Obstructured Icon", editor = "ui_image", default = "UI/Hud/obstructedHit", },
	},
	FrameBox = box(2, 0, 2, 0),
	ProgressFrameBox = box(2, 0, 2, 0),
	BindTo = {
		"HitPoints",
		"PotentialDamage",
		"PotentialDamageConditional",
		"PotentialSecondaryConditional"
	},
	SecondaryBarsAlignment = {
		"right",
		"relative",
		"relative"
	},
	
	SqueezeY = false,
	prop_metas = false,
	MaxWidth = 100,

	barBox = false,
	bgBox = false,
	tempHPBgBox = false,
	primaryBarBox = false,
	primaryBarClipBox = false,
	tempHPBarBox = false,
	tempHPBarClipBox = false,
	
	otherBarBoxes = false,
	maxHpChangedBox = false,
	maxHpChangedBoxBg = false,
	maxHpChangedBgColor = false,
	
	predictionIconSrc = false,

	LayoutMethod = "Box",
	HPColor = false,
	TempHPColor = false,
	PotentialDamageColor = false,
	ConditionalDamageColor = false,
	
	secondary_bar_modifiers = false,
	idText = false,
	max_width_textless = false,
	max_height_textless = false,
	
	-- Hp loss anim
	hp_loss_amount = false,
	hp_loss_rect = false,
	hp_loss_interp = false,
	hp_loss_healing = false,
}

function HealthBar:SetMaxWidth(val)
	self.max_width_textless = val
	XWindow.SetMaxWidth(self, self.idText and 9999 or val)
end

function HealthBar:SetMaxHeight(val)
	self.max_height_textless = val
	XWindow.SetMaxHeight(self, self.idText and 9999 or val)
end

function HealthBar:SetColorPreset(presetName)
	if presetName == "enemy" then
		self.HPColor = GameColors.Enemy
		self.TempHPColor = GameColors.EnemyLighter
		self.PotentialDamageColor = RGB(218, 156, 8)
		self.ConditionalDamageColor = RGB(255, 211, 106)
	elseif presetName == "disabled" then
		self.HPColor = GameColors.D
		self.TempHPColor = GameColors.PlayerLighter
		self.PotentialDamageColor = RGB(152, 249, 255)
		self.ConditionalDamageColor = RGB(255, 211, 106)
	elseif presetName == "desaturated" then
		self.HPColor = GameColors.K--GetColorWithAlpha(, 120)
		self.TempHPColor = GetColorWithAlpha(GameColors.K, 200)
		self.PotentialDamageColor = RGB(152, 249, 255)
		self.ConditionalDamageColor = RGB(255, 211, 106)
	else
		self.HPColor = GameColors.Player
		self.TempHPColor = GameColors.PlayerLighter
		self.PotentialDamageColor = RGB(152, 249, 255)
		self.ConditionalDamageColor = RGB(255, 211, 106)
	end
	
	local shouldHaveText = presetName == "enemy" and not CthVisible()
	local hasText = self.idText
	if shouldHaveText and not hasText then
		local text = XTemplateSpawn("XText", self) 
		text:SetId("idText")
		text:SetTranslate(true)
		text:SetTextStyle("BadgeName")
		text:SetClip(false)
		text:SetUseClipBox(false)
		text:SetDrawOnTop(true)
		text:SetTextVAlign("center")
		text:SetHandleMouse(false)
		text:SetWordWrap(false)
		text:SetPadding(box(2, -3, 2, -3))
		text:SetText(self.context:HasMember("GetHealthAsText") and self.context:GetHealthAsText() or "")
		if self.window_state == "open" then text:Open() end
		
		self:SetMaxWidth(self.max_width_textless)
		self:SetMaxHeight(self.max_height_textless)
		self:SetHAlign("stretch")
	elseif not shouldHaveText and hasText then
		self.idText:Close()
		self.idText = false
		
		self:SetMaxWidth(self.max_width_textless)
		self:SetMaxHeight(self.max_height_textless)
		self:SetHAlign("left")
	end
end

function HealthBar:Init()
	self.predictionIconSrc = {}
	self:SetColorPreset("default")
end

function HealthBar:OnXTemplateSetProperty(prop_id, old_value)
	if prop_id ~= "BindTo" then return end
	-- make sure the Progress property is a table of the same size
	local progress = self.Progress
	local progress_count = #progress
	local bind_count = #self.BindTo
	if bind_count ~= progress_count then
		local progress_meta = self:GetPropertyMetadata("Progress")
		--remove not needed Progress values
		for i = progress_count, bind_count + 1, -1 do
			progress[i] = nil
		end
		--add missing Progress values
		for i = progress_count + 1, bind_count do
			progress[i] = progress_meta.item_default or 0
		end
		self.Progress = progress
	end
end

function HealthBar:GetCurrentProgress()
	local current = 0
	for _, value in ipairs(self.Progress) do
		current = Max(current, value)
	end
	return Clamp(current, 0, self.MaxProgress)
end

function HealthBar:MeasureSizeAdjust(max_width, max_height)
	local progress = self:GetCurrentProgress()
	local min = ScaleXY(self.scale, self.MinProgressSize)
	if progress == 0 then return max_width, max_height end
	max_width = min + (max_width - min) * progress / self.MaxProgress
	return max_width, max_height
end

function HealthBar:SetBox(x, y, width, height, move_children)
	XFrame.SetBox(self, x, y, width, height, move_children)
	self:UpdateBars()
end

local baseHpSegment = 20
local margins = 1
local distanceBetweenSegments = 1

function HealthBar:UpdateBars()
	if not IsKindOfClasses(self.context, "CombatObject", "UnitData") then return end
	
	if self.idText then
		self.idText:SetText(self.context:HasMember("GetHealthAsText") and self.context:GetHealthAsText() or "")
	end
	
	local b = self.box
	local minx = b:minx()
	local miny = b:miny()
	local width = b:sizex()
	local height = b:sizey()
	if width == 0 then return end -- Wait for layout
	self.barBox = b
	
	-- Margins
	minx = minx + margins
	width = width - margins * 2
	height = height - margins * 2
	miny = miny + margins
	
	local frameBoxX = 0--(--self.ProgressFrameBox:minx() / 2) + 2
	local frameBoxWidth = 0--(self.ProgressFrameBox:maxx() / 2) + 2
	local horizontalFrameBoxSize = frameBoxX + frameBoxWidth
	
	local unitCurrentHp = self.context.HitPoints
	local unitMaxHP
	if self.context:HasMember("GetModifiedMaxHitPoints") then
		local _, positive_modifier_max = self.context:GetModifiedMaxHitPoints()
		unitMaxHP = positive_modifier_max
	else
		unitMaxHP = self.context.MaxHitPoints
	end
	
	-- if unit has wounds
	local unitCurrentMaxHP = self.context.MaxHitPoints
	if unitCurrentMaxHP > unitMaxHP then 
		unitMaxHP = unitCurrentMaxHP
	end
	
	-- The segments are (baseHpSegment) large
	local primarySegments = Max((unitMaxHP - 1), 1) / baseHpSegment + 1
	
	-- TempHp Segment count
	local unitTempHp = self.context.TempHitPoints or 0
	local unitCombinedMaxHp = unitMaxHP
	local tempHpSegments = 0
	if unitTempHp and unitTempHp > 0 then
		tempHpSegments = Max((unitTempHp - 1), 1) / baseHpSegment + 1
		unitCombinedMaxHp = self.FitSegments and unitMaxHP + unitTempHp or unitMaxHP
	end
	
	self:SetMaxProgress(unitCombinedMaxHp)

	-- all segments
	local segments = self.FitSegments and primarySegments + tempHpSegments or primarySegments
	local segmentSpacing = segments > 1 and segments * distanceBetweenSegments or 0
	local extraHpAmount = unitCombinedMaxHp - baseHpSegment * segments
	if extraHpAmount > 0 then segmentSpacing = segmentSpacing + distanceBetweenSegments end
	local effectiveSize = width - segmentSpacing
	
	-- segmentSizeMod changes when you want to fit all the segments in the width
	local segmentSizeMod
	if self.FitSegments then
		if unitCurrentHp + unitTempHp >= unitMaxHP then
			segmentSizeMod = unitCurrentHp + unitTempHp
		else
			segmentSizeMod = unitMaxHP
		end
	else
		segmentSizeMod = unitCombinedMaxHp
	end	
	
	local segmentPixelSize = Max(DivCeil(effectiveSize * baseHpSegment, segmentSizeMod), 1)
	
	-- The primary bar extends from the left in segments.
	local push = 0
	self.primaryBarBox = {}
	for i = 1, primarySegments do
		self.primaryBarBox[i] = sizebox(minx + push, miny, segmentPixelSize, height)
		push = push + segmentPixelSize + distanceBetweenSegments
	end
	
	-- Clip segments to current hp
	local primary = self.Progress[1]
	local primaryBarWidth = primary > 0 and MulDivRound(width, primary, segmentSizeMod) or 0
	self.primaryBarClipBox = sizebox(minx, miny, primaryBarWidth, height)
	
	local border = self.BorderWidth
	self.bgBox = sizebox(minx - border, miny - border, width + border * 2, height + border * 2)
	
	-- TempHp segments go here
	self.tempHPBarBox = {}
	self.tempHPBarClipBox = false
	self.tempHPBgBox = false
	local tempBarWidth = 0
	if unitTempHp and unitTempHp > 0 then
		-- tempHP segments are a bit bigger
		local tempHpSegmentXpos = minx + primaryBarWidth
		local tempHpSegmentYpos = self.FitSegments and miny or (miny - 1)
		local tempHpSegmentHeight = self.FitSegments and height or (height + 2)
		
		push = distanceBetweenSegments
		
		for i = 1, tempHpSegments do
			self.tempHPBarBox[i] = sizebox(tempHpSegmentXpos + push, tempHpSegmentYpos, segmentPixelSize, tempHpSegmentHeight)
			push = push + segmentPixelSize + distanceBetweenSegments
		end
		
		-- clip temp hp
		tempBarWidth = MulDivRound(width, unitTempHp, segmentSizeMod) or 0
		
		if self.FitSegments and tempHpSegmentXpos + tempBarWidth > minx + width then
			tempBarWidth = minx + width - tempHpSegmentXpos
		end
		
		self.tempHPBarClipBox = sizebox(tempHpSegmentXpos, tempHpSegmentYpos, tempBarWidth, tempHpSegmentHeight)
		self.tempHPBgBox = sizebox(tempHpSegmentXpos, tempHpSegmentYpos, tempBarWidth, tempHpSegmentHeight)
	end
	
	-- If the unit's current max HP is less than the initial, display another bar on the right side.
	-- The bar background is equal to the initial maximum.
	local currentMax = self.context.MaxHitPoints
	if unitMaxHP == currentMax then
		self.maxHpChangedBox = false
	else
		local lostMaxHp = unitMaxHP - currentMax
		local barSize = MulDivRound(width, lostMaxHp, segmentSizeMod)
		barSize = Min(barSize, width) -- Dont overflow
		local fullRightSide = minx + width - barSize
		
		if self.FitSegments then
			barSize = barSize + margins
		end
		
		local _, padding = ScaleXY(self.scale, 0, 2)
		self.maxHpChangedBox = sizebox(fullRightSide, miny + padding, barSize, height - padding * 2)
		
		if self.FitSegments then
			self.maxHpChangedBoxBg = sizebox(fullRightSide, miny + padding / 2, barSize, height)
			self.bgBox = box(self.bgBox:minx(), self.bgBox:miny(), self.bgBox:maxx() - barSize, self.bgBox:maxy())
		else
			self.maxHpChangedBoxBg = false
		end
	end
	
	-- Hp loss
	if self.hp_loss_amount then
		local isHealing = self.hp_loss_healing
		if isHealing then
			local gainInWidth = self.hp_loss_amount < 0 and MulDivRound(width, -self.hp_loss_amount, segmentSizeMod) or self.hp_loss_amount
			self.hp_loss_rect = sizebox(self.primaryBarClipBox:maxx() - gainInWidth, self.bgBox:miny(), gainInWidth, self.bgBox:sizey())
		else
			local lossInWidth = self.hp_loss_amount > 0 and MulDivRound(width, self.hp_loss_amount, segmentSizeMod) or self.hp_loss_amount
			self.hp_loss_rect = sizebox(self.primaryBarClipBox:maxx(), self.bgBox:miny(), lossInWidth, self.bgBox:sizey())
		end
	end
	
	-- Other bars anchored right on the primary (and tempHp if any), minus missing.
	local rightSide = minx + primaryBarWidth
	if unitTempHp and unitTempHp > 0 then rightSide = rightSide + tempBarWidth end
	
	if not self.otherBarBoxes then self.otherBarBoxes = {} end
	for i=2, #self.Progress do
		local value = self.Progress[i]
		local alignment = self.SecondaryBarsAlignment[i - 1]
		if alignment == "relative" and not self.otherBarBoxes[i - 1] then alignment = "right" end
		local barWidth = 0
		local barHeight = height
		if value > 0 then
			if self.BindTo[i] == "PotentialSecondaryConditional" then
				local modifiedHeight = MulDivRound(barHeight, 600, 1000)
				miny = miny + (barHeight - modifiedHeight) / 2
				barHeight = modifiedHeight
			end
		
			barWidth = MulDivRound(width, value, unitCombinedMaxHp)
			barWidth = Max(barWidth, horizontalFrameBoxSize) -- We want to show at least one pixel.
			if alignment == "right" then
				barWidth = Min(barWidth, primaryBarWidth)
				self.otherBarBoxes[i] = sizebox(rightSide - barWidth, miny, barWidth, barHeight)
			elseif alignment == "relative" then
				local start = self.otherBarBoxes[i - 1]:minx()
				local endR = self.otherBarBoxes[i - 1]:sizex()
				barWidth = Min(endR + barWidth, primaryBarWidth - endR)
				self.otherBarBoxes[i] = sizebox(start - barWidth, miny, barWidth + frameBoxWidth, barHeight)
			end
		else
			self.otherBarBoxes[i] = false
		end
	end
end

function HealthBar:OnPropUpdate(context, idx, value)
	assert(type(value) == "number")
	if type(value) == "number" then
		local progress = self.Progress
		progress[idx] = value
		self:InvalidateMeasure()
	end
end

function HealthBar:SetBindTo(prop_ids)
	self.prop_metas = self.prop_metas or {}
	self.BindTo = prop_ids
	for i, prop_id in ipairs(prop_ids) do
		local prop_meta
		ForEachObjInContext(self.context, function(obj, self, prop_id)
			prop_meta = prop_meta or IsKindOf(obj, "PropertyObject") and obj:GetPropertyMetadata(prop_id)
		end, self, prop_id)
		self.prop_metas[i] = prop_meta
	end
end

function HealthBar:OnContextUpdate(context)
	XContextControl.OnContextUpdate(self, context)

	local prop_ids = self.BindTo
	local values = {}
	for i, prop_id in ipairs(prop_ids) do
		if context then
			local value = ResolveValue(context, prop_id) or 0
			values[i] = value
			if value ~= rawget(self.Progress, i) then
				self:OnPropUpdate(context, i, value)
			end
		end
	end

	self:UpdateBars()
end

local function lSecondaryBarAnimation(self, mod)
	local setting_name = "ConditionalDamage"
	local fade_in, fade_out

	fade_in = {
		id = "conditional_damage_in",
		type = const.intAlpha,
		startValue = 0,
		endValue = 255,
		duration = const.Healthbar[setting_name .. "FadeInTime"],
		flags = const.intfRealTime,
		on_complete = function()
			Sleep(const.Healthbar[setting_name .. "TimeOn"])
			self.secondary_bar_modifiers = lSecondaryBarAnimation(self, fade_out)
		end
	}

	fade_out = {
		id = "conditional_damage_out",
		type = const.intAlpha,
		startValue = 255,
		endValue = 0,
		duration = const.Healthbar[setting_name .. "FadeOutTime"],
		flags = const.intfRealTime,
		on_complete = function()
			Sleep(const.Healthbar[setting_name .. "TimeOff"])
			self.secondary_bar_modifiers = lSecondaryBarAnimation(self, fade_in)
		end
	}

	local int = mod or fade_out
	int.modifier_type = const.modInterpolation
	local time = GetPreciseTicks()
	int.start = time
	if int.autoremove or int.on_complete then
		assert(not IsFlagSet(int.flags or 0, const.intfGameTime))
		local time_to_end = int.start + int.duration - time
		CreateRealTimeThread(function(self, int, time_to_end)
			Sleep(time_to_end)
			if self.window_state == "destroying" then return end
			int.on_complete(self, int)
		end, self, int, time_to_end)
	end
	self:Invalidate()
	
	return int
end

function HealthBar:DrawBackground(clip_box)
	return
end

local UIL = UIL
local irOutside = const.irOutside
function HealthBar:DrawContent(clip_box)
	if not self.barBox then return end
	
	if self.UseClipBox and self.box:Intersect2D(clip_box) == 0 then return end
 	
	if self.UseClipBox then
		UIL.PushClipRect(self.box)
	end
	
	local desaturation = UIL.GetDesaturation()
	UIL.SetDesaturation(self.Desaturation)
	
	if self.idText then 
		-- draw hp to text with prediction icons
		self:DrawBGBox()
		XWindow.DrawChildren(self, clip_box)
		self:DrawPredictionIcons()
	else
		-- draw hp bar with prediction icons
		if self:DrawBGBox() then
			-- TempHp border background
			if self.DisplayTempHp and self.tempHPBgBox then
				UIL.DrawSolidRect(self.tempHPBgBox, self:CalcBackground())
			end
		end
		self:DrawHpBar(clip_box)
		
		-- Draw HP loss animation (used for DamageNotification)
		if self.hp_loss_rect then
			local isHealing = self.hp_loss_healing
		
			local prev_top_mod
			if self.hp_loss_interp then
				if self.hp_loss_interp.applied_box ~= self.hp_loss_rect then
					local rectOffset = isHealing and self.hp_loss_rect:max() or self.hp_loss_rect:min()
				
					local ogRect = self.hp_loss_interp.originalRect
					local tarRect = self.hp_loss_interp.targetRect
					self.hp_loss_interp.originalRect = Offset(ogRect, rectOffset - ogRect:min())
					self.hp_loss_interp.targetRect = Offset(tarRect, rectOffset - tarRect:min())
					self.hp_loss_interp.applied_box = self.hp_loss_rect
				end
			
				prev_top_mod = UIL.ModifiersGetTop()
				UIL.PushModifier(self.hp_loss_interp)
			end

			UIL.PushClipRect(self.hp_loss_rect)
			UIL.DrawSolidRect(self.box, isHealing and RGB(78, 164, 200) or GameColors.M)
			for i, s in ipairs(self.primaryBarBox) do
				UIL.DrawSolidRect(s, isHealing and GameColors.C or GameColors.C)
			end
			UIL.PopClipRect(self.hp_loss_rect)
			
			if prev_top_mod then UIL.ModifiersSetTop(prev_top_mod) end
		end
	end
	
	UIL.SetDesaturation(desaturation)
	
	if self.UseClipBox then
		UIL.PopClipRect()
	end
end

--override func  and call XWindow.DrawChildren before DrawPredictionIcons so that they are drawn on top of text
function HealthBar:DrawChildren()
end

function HealthBar:DrawBGBox()
	local border = self.BorderWidth
	local borderColor = self:CalcBorderColor()
	local background = self:CalcBackground()
	if border ~= 0 and background ~= 0 then
		if background == borderColor then
			UIL.DrawSolidRect(self.bgBox, background)
		else
			UIL.DrawBorderRect(self.bgBox, border, border, borderColor, background)
		end
		return true
	end
end

function HealthBar:DrawHpBar(clip_box)
	local border = self.BorderWidth
	local background = self:CalcBackground()
	local primary = self.Progress[1]
	
	-- Bar Background
--[[	local scaleX, scaleY = ScaleXY(self.scale, self.ImageScale:xy())
		UIL.DrawFrame(self.Image, self.barBox, self.Rows, self.Columns, self:GetRow(), self:GetColumn(),
			self.FrameBox, not self.TileFrame, self.TransparentCenter, scaleX, scaleY, self.FlipX, self.FlipY)
			
		if not primary then 
			UIL.SetDesaturation(desaturation)
			return
		end
		]]
		
	-- HP bar segments
	if self.primaryBarClipBox then UIL.PushClipRect(self.primaryBarClipBox) end
	if self.primaryBarBox then
		for i, s in ipairs(self.primaryBarBox) do
			UIL.DrawSolidRect(s, self.HPColor)
		end
	end
	if self.primaryBarClipBox then UIL.PopClipRect() end
	
	-- Missing max hp
	if self.maxHpChangedBox then
		if border ~= 0 and background ~= 0 and self.maxHpChangedBoxBg then
			UIL.DrawSolidRect(self.maxHpChangedBoxBg, self.maxHpChangedBgColor or background)
			UIL.DrawBorderRect(self.maxHpChangedBox, border + 3, border + 3, self:CalcBorderColor(), background)
		end
		UIL.PushClipRect(self.maxHpChangedBox)
		for i, s in ipairs(self.primaryBarBox) do
			UIL.DrawSolidRect(s, RGB(91, 91, 91))
		end
		UIL.PopClipRect()
	end
	
	-- TempHp
	if self.DisplayTempHp then
		if self.tempHPBarClipBox then UIL.PushClipRect(self.tempHPBarClipBox) end
		if self.tempHPBarBox then
			for i, s in ipairs(self.tempHPBarBox) do
				UIL.DrawSolidRect(s, self.TempHPColor)
			end
		end
		if self.tempHPBarClipBox then UIL.PopClipRect() end
	end
	
	-- Other bars (used for damage prediction currently)
	if self.otherBarBoxes then
		for i = 2, #self.Progress do
			if self.otherBarBoxes[i] then
				if not self.secondary_bar_modifiers then
					self.secondary_bar_modifiers = lSecondaryBarAnimation(self)
				end
				local prev_top_mod = UIL.ModifiersGetTop()
				UIL.PushModifier(self.secondary_bar_modifiers)
				
				local color = i == 2 and self.PotentialDamageColor or self.ConditionalDamageColor
				UIL.DrawSolidRect(self.otherBarBoxes[i], color)
		
				if prev_top_mod then
					UIL.ModifiersSetTop(prev_top_mod)
				end
			end
		end
	end

	XWindow.DrawChildren(self, clip_box)
	self:DrawPredictionIcons()
end

function HealthBar:DrawPredictionIcons()
	-- Additional prediction icons
	local predictionIconSmall = rawget(self.context, "SmallPotentialDamageIcon")
	if predictionIconSmall == "InRange" then predictionIconSmall = false end
	local predictionIconLarge = rawget(self.context, "LargePotentialDamageIcon")
	if (predictionIconSmall or predictionIconLarge) and self.ShowIcons then
		local iconImageSmall = predictionIconSmall and self:GetProperty(predictionIconSmall) or predictionIconSmall
		local iconImageLarge = predictionIconLarge and self:GetProperty(predictionIconLarge) or predictionIconLarge

		local function lDrawIcon(iconImage, smallIcon)
			if UIL.IsImageReady(iconImage) then
				-- Get image size if we don't have it
				local src = self.predictionIconSrc[iconImage]
				if not src then
					local w, h = UIL.MeasureImage(iconImage)
					src = sizebox(0, 0, w, h)
					self.predictionIconSrc[iconImage] = src
				end
				local width, height = ScaleXY(self.scale, src:sizexyz())
				local b = self.barBox
				local xPos = (b:minx() + b:sizex() / 2) - width / 2
				-- Small icons are positioned after the back, large icons are in the middle of the bar.
				if smallIcon then
					xPos = b:maxx()
				end
				local iconDst = sizebox(xPos, (b:miny() + b:sizey() / 2) - height / 2, width, height)
				UIL.DrawFrame(iconImage, iconDst, 1, 1, 1, 1, empty_box, true, false, self.scale:x(), self.scale:y())
			else
				UIL.RequestImage(iconImage)
			end
		end
		if iconImageSmall then lDrawIcon(iconImageSmall, true) end
		if iconImageLarge then lDrawIcon(iconImageLarge) end
	end
end

-- HP loss animation

function HealthBar:PrepareAnimateHPLoss(amount)
	self.hp_loss_amount = (self.hp_loss_amount or 0) + amount
	self:DeleteThread("animateHpLoss")
	self.hp_loss_rect = false
	self.hp_loss_interp = false
	self.hp_loss_healing = self.hp_loss_amount < 0
	return self.hp_loss_amount
end

function HealthBar:AnimateHPLoss(time)
	self:DeleteThread("animateHpLoss")
	self.hp_loss_interp = {
		interpolate_clip = const.interpolateClipOnly,
		id = "hp_loss_interp",
		type = const.intRect,
		modifier_type = const.modInterpolation,
		start = GetPreciseTicks(),
		duration = time,
		targetRect = box(0, 0, 0, 1000),
		originalRect = box(0, 0, 1000, 1000),
		flags = band(const.intfInverse, const.intfRealTime)
	}
	
	self:CreateThread("animateHpLoss", function()
		Sleep(time)
		self.hp_loss_rect = false
		self.hp_loss_amount = false
		self.hp_loss_interp = false
	end)
	
	self:Invalidate()
end