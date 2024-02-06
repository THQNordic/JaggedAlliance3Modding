if FirstLoad then
UILParamUsage = {}
for i = 0, const.MaxUILParams do
	UILParamUsage[i] = false
end

-- Used by XMap
UILParamUsage[0] = true
UILParamUsage[1] = true

-- Used by Timeline
UILParamUsage[2] = true
UILParamUsage[3] = true
end

function GetUILParam()
	for i, used in ipairs(UILParamUsage) do
		if not used then
			UILParamUsage[i] = true
			return i
		end
	end
	assert(false) -- No free UIL params! Increase MAX_UIL_PARAMS in C
	return -1
end

function FreeUILParam(idx)
	assert(UILParamUsage[idx])
	UILParamUsage[idx] = false
end
-------

DefineClass.SmoothBar = {
	__parents = {"XContextWindow"},
	properties = {
		{ category = "Progress", id = "BindTo", name = "BindTo", editor = "text", default = "", },
		{ category = "Progress", id = "MaxValue", name = "MaxValue", editor = "number", default = 1, },
		{ category = "Progress", id = "InterpolationTime", name = "InterpolationTime", editor = "number", default = 100 },
		{ category = "Progress", id = "UpdateTime", name = "UpdateTime", editor = "number", default = 20 },
		{ category = "Progress", id = "FillColor", name = "FillColor", editor = "color", default = "", },
		{ category = "Progress", id = "HideWhenEmpty", name = "HideWhenEmpty", editor = "bool", default = true },
	},

	progress = 0,
	uilParamIdx = -1,

	MaxWidth = 100,
	LayoutMethod = "Box",
	FoldWhenHidden = true,
	
	enabled = "unset"
}

function SmoothBar:Open()
	XContextWindow.Open(self)
	if self.HideWhenEmpty then
		self:SetVisible(false)
	end
	self:SetEnabled(true)
end

function SmoothBar:EnsureUILParam()
	if self.uilParamIdx == -1 then
		self.uilParamIdx = GetUILParam()
	end
end

function SmoothBar:FreeUILParam()
	if self.uilParamIdx ~= -1 then
		FreeUILParam(self.uilParamIdx)
		self.uilParamIdx = -1
	end
end

function SmoothBar:OnDelete()
	self:FreeUILParam()
end

function SmoothBar:GetBoundPropValue()
	local context = self.context
	if not context or not context:HasMember(self.BindTo) then return end
	return context[self.BindTo]
end

function SmoothBar:UpdateVisual(value, first)
	self.progress = value or self:GetBoundPropValue() or 0
	self.progress = Min(self.progress, self.MaxValue)
	UIL.SetParam(self.uilParamIdx, MulDivRound(self.progress, 1000, self.MaxValue), 1000, first and 0 or self.InterpolationTime)

	local shouldBeVisible = self.progress ~= 0 or not self.HideWhenEmpty
	local combatActionInProgress = HasCombatActionInProgress(self.context) and not self.context:IsInterruptableMovement()
	
	shouldBeVisible = shouldBeVisible and not combatActionInProgress

	self:DeleteThread("hide")
	if not shouldBeVisible then
		if combatActionInProgress then
			self:SetVisible(false)
			return
		end
	
		self:CreateThread("hide", function()
			Sleep(self.InterpolationTime)
			self:SetVisible(false)
		end)
	else
		self:SetVisible(true)
	end
end

function SmoothBar:SetEnabled(enabled)
	if enabled == self.enabled then
		return
	end

	self.enabled = enabled
	self:DeleteThread("UpdateBar")
	if not enabled then
		self:SetVisible(false)
		self:FreeUILParam()
		return
	end

	self:EnsureUILParam()
	if enabled then
		self:AddInterpolation{
			id = "progress",
			type = const.intParamRect,
			translationConstant = self.box:min(),
			scaleParam = self.uilParamIdx,
			OnLayoutComplete = function(modifier, window)
				modifier.translationConstant = window.box:min()
			end
		}
		UIL.SetParam(self.uilParamIdx, 0, 1000, 0)
		local propVal = self:GetBoundPropValue()
		self:UpdateVisual(propVal, true)
		
		self:CreateThread("UpdateBar", function()
			local propVal = self:GetBoundPropValue()
			self:UpdateVisual(propVal)

			while self.window_state ~= "destroying" do
				local propVal = self:GetBoundPropValue() or 0
				if propVal ~= self.progress then
					self:UpdateVisual(propVal)
				end
				WaitFramesOrSleepAtLeast(1, 10)
			end
		end)
	end
end

local UIL = UIL
local irOutside = const.irOutside
function SmoothBar:DrawWindow(clip_box)
	local myBox = self.box
	if myBox:sizex() == 0 then return end
	
	local border = self.BorderWidth
	local background = self:CalcBackground()
	if background ~= 0 then
		UIL.DrawBorderRect(myBox, self.BorderWidth, self.BorderWidth, self:CalcBorderColor(), background)
	end

	XContextWindow.DrawWindow(self, clip_box)
end

function SmoothBar:DrawContent()
	UIL.DrawSolidRect(self.box, self.FillColor)
end