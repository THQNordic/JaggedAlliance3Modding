DefineClass.XCreditsWindow = {
	__parents = { "XScrollArea" },
	paused = false,
	time_step = 100, 
	Clip = "self",
	Background = RGBA(0, 0, 0, 0),
	Margins = box(0, -400, 0, -200),
	ChildrenHandleMouse =  false,
	VScroll =  "idScrollCredits",
}

function XCreditsWindow:Init()
	XText:new({
		Id = "idCredits",
		HAlign = "center",
		ChildrenHandleMouse = false,
		TextStyle = "CreditsTitle",
		TextHAlign = "center",
	}, self)
	XScroll:new({
		Id = "idScrollCredits",
	}, self)
	self:SetTextData()
	self:SetFocus()
end

function XCreditsWindow:SetTextData()
	local texts = {}
	local lang = GetLanguage()
	local voice_lang = GetVoiceLanguage()
	for i = 1, #CreditContents do
		local section = CreditContents[i]
		
		if (not section.platform or Platform[section.platform])
			and (not section.language or section.language == lang)
			and (not section.voice_language or section.voice_language == voice_lang)
		then
			if section.company_logo then
				texts[#texts + 1] = _InternalTranslate(section.company_logo)
				texts[#texts + 1] = "\n\n\n\n\n\n\n\n"
			elseif section.company_name then
				texts[#texts + 1] = _InternalTranslate("<style PGMenuMainSubTitle>" .. section.company_name .. "</style>")
				texts[#texts + 1] = "\n\n\n\n\n\n\n\n\n\n\n\n\n"
			end
			for _, text in ipairs(section) do
				local translated = _InternalTranslate(text)
				if translated and translated ~= "" and translated ~= "-" then
					texts[#texts + 1] = translated
					texts[#texts + 1] = "\n\n\n\n\n\n\n\n\n\n\n\n\n"
				end
			end
			if section.footer then
				texts[#texts + 1] = _InternalTranslate(section.footer)
				texts[#texts + 1] = "\n\n\n\n\n\n\n\n\n\n\n\n\n"
			end
			texts[#texts + 1] = "\n\n\n\n\n\n\n\n"
		end
	end
	local margin_y = MulDivRound(UIL.GetScreenSize():y(), 1000, self.scale:y())
	self.idCredits:SetMargins(box(0, margin_y, 0, 0))
	self.idCredits:SetText(table.concat(texts))
end

function XCreditsWindow:MoveThread()
	if self:GetThread("scroll") then return end
	
	self:CreateThread("scroll", function()
		local text_ctrl = self.idCredits
		local height = text_ctrl.text_height
		local tStart = GetPreciseTicks()
		local screeny = UIL.GetScreenSize():y()
		local per_second = screeny * 60 / 1000
		local pos = 0
		while pos < height do
			if self.paused then
				while self.paused do
					Sleep(self.time_step)
					tStart = tStart + self.time_step
				end
				tStart = tStart - self.time_step
			end
			pos = MulDivRound(GetPreciseTicks() - tStart, per_second, 1000)
			self:ScrollTo(0, pos)
			text_ctrl:AddInterpolation{
				id = "pos",
				type = const.intRect,
				duration = 2*self.time_step,
				originalRect = text_ctrl.box,
				targetRect = Offset(text_ctrl.box, point(0, -per_second *2*self.time_step / 1000)),
			}
			Sleep(self.time_step)
		end
		local dialog = GetDialog(self)
		if dialog then dialog:Close() end
	end)
end

function XCreditsWindow:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.paused = not self.paused
		return "break"
	end
	if button == "R" then
		local dialog = GetDialog(self)
		if dialog then dialog:Close() end
		return "break"
	end
end
--[[
function XCreditsWindow:OnMouseWheelForward()
	local val = self.paused
	self.paused = true
	self:SetMouseScroll(true)
	XScrollArea.OnMouseWheelForward(self)
--	self.paused = val
	--self:SetMouseScroll(false)
end

function XCreditsWindow:OnMouseWheelBack()
	local val = self.paused
	self.paused = true
	self:SetMouseScroll(true)
	XScrollArea.OnMouseWheelBack(self)
	--self.paused = val
	--self:SetMouseScroll(false)
end
--]]
function XCreditsWindow:OnShortcut(shortcut, source, ...)
	if shortcut == "Space" or shortcut == "ButtonA" then
		self.paused = not self.paused
		return "break"
	end
end

const.TagLookupTable["crp"]      = "<style CreditsPosition>"
const.TagLookupTable["/crp"]     = "</style>"
const.TagLookupTable["crn"]      = "<style CreditsNames>"
const.TagLookupTable["/crn"]     = "</style>"
const.TagLookupTable["cmn"]      = "<style CreditsMultiNames>"
const.TagLookupTable["/cmn"]     = "</style>"
const.TagLookupTable["crt"]      = "<style CreditsTitle>"
const.TagLookupTable["/crt"]     = "</style>"