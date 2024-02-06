----- XFadeWordsText

DefineClass.XFadeWordsText = {
	__parents = { "XTranslateText" },
	
	properties = {
		{ category = "General", id = "DelayFromDlg", editor = "bool", default = false, },
		{ category = "General", id = "DelayToDlg", editor = "bool", default = false, },
		{ category = "General", id = "InitialDelay", editor = "number", default = 0, scale = "sec", },
		{ category = "General", id = "WordFadeDuration", editor = "number", default = 600, scale = "sec", },
		{ category = "General", id = "WordShowDelay", editor = "number", default = 300, scale = "sec", },
		{ category = "General", id = "CommaDelay", editor = "number", default = 500, scale = "sec", },
		{ category = "General", id = "ExtraDelay", editor = "number", default = 0, scale = "sec", },
	},
	LayoutMethod = "HWrap",
}

function XFadeWordsText:Open(...)
	local time = 0
	if self.DelayFromDlg then
		time = rawget(GetDialog(self), "delay") or 0
	end
	time = self:ShowTextWithDelay(self.text, time)
	if self.DelayToDlg then
		rawset(GetDialog(self), "delay", time)
	end
	XTranslateText.Open(self, ...)
end

local function ProcessHideTags(text)
	local hide_after
	repeat
		hide_after = text:find("<hide>")
		if hide_after then
			local hide_before = text:find("</hide>", hide_after)
			text = text:sub(1, hide_after - 1) .. text:sub(hide_before + 7)
		end
	until not hide_after
	text = text:gsub("</hide>", "")
	return text
end

local nbsp = string.char(194,160)
function XFadeWordsText:ShowTextWithDelay(text, time)
	self.time = (time or 0) + self.InitialDelay
	if (text or "") ~= "" then
		text = ProcessHideTags(text)
		text = text:gsub(nbsp, " ")
	end
	local color_stack = {}
	XTextTokenize(text, function(self, ttype, args, text)
		if ttype == "text" and text ~= "" then
			local leading_spaces = text:match("^(%s*)")
			for word in string.gmatch(text, "[^%s]+%s*") do
				if leading_spaces and leading_spaces ~= "" then
					word = leading_spaces .. word
					leading_spaces = false
				end
				local control = XLabel:new(nil, self, self.context)
				control:SetPadding(empty_box)
				control:SetTextStyle(self.TextStyle)
				control:SetTranslate(false)
				if #color_stack > 0 then
					control:SetTextColor(color_stack[#color_stack])
				end
				control:SetText(word)
				control:AddInterpolation{
					id = "transparency",
					type = const.intAlpha,
					startValue = 0,
					endValue = 255,
					duration = self.WordFadeDuration,
					start = GetPreciseTicks() + self.time,
				}
				self.time = self.time + self.WordShowDelay
				if word:find(",") then
					self.time = self.time + self.CommaDelay
				end
			end
		elseif ttype == "color" then
			local color_style = TextStyles[args[1] or false]
			color_stack[#color_stack + 1] = color_style and color_style.TextColor or RGB(255,255,255)
		elseif ttype == "/color" then
			color_stack[#color_stack] = nil
		end
	end, self)

	return self.time + self.WordFadeDuration + self.ExtraDelay
end
