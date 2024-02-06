DefineClass.MarkdownParser = {
	__parents = { "PropertyObject" },
	
	properties = {
		{ category = "General", id = "TextColor", editor = "color", default = RGB(80, 80, 80) },
		{ category = "General", id = "BoldColor", editor = "color", default = RGB(0, 0, 0) },
		{ category = "General", id = "ItalicColor", editor = "color", default = RGB(45, 45, 45) },
		{ category = "General", id = "HyperlinkColor", editor = "color", default = RGB(0, 0, 238) },
		
		{ category = "General", id = "HeadingFont1", editor = "text", default = "Heading1" },
		{ category = "General", id = "HeadingFont2", editor = "text", default = "Heading2" },
		{ category = "General", id = "HeadingFont3", editor = "text", default = "Heading3" },
		{ category = "General", id = "HeadingFont4", editor = "text", default = "Heading4" },
	},
	
	text = "",
	
	output = "",
	paragraph = "",
	empty_lines = 0,
	numbered_entries = 0,
}

local function md_match_and_replace(text, pattern, fn)
	while true do
		local idx1, idx2 = text:find(pattern)
		if not idx1 or not idx2 then
			break
		end
		text = text:sub(1, idx1-1) .. fn(text:match(pattern, idx1)) .. text:sub(idx2+1)
	end
	return text
end

function MarkdownParser:ParseParagraph(text)
	text = md_match_and_replace(text, "%*%*([^%*]+)%*%*", function(bold)
		local r, g, b, a = GetRGBA(self.BoldColor)
		return string.format("<color %s %s %s %s>", r, g, b, a) .. self:ParseParagraph(bold) .. "</color>"
	end)
	
	text = md_match_and_replace(text, "%*([^%*]+)%*", function(italic)
		local r, g, b, a = GetRGBA(self.ItalicColor)
		return string.format("<color %s %s %s %s>", r, g, b, a) .. self:ParseParagraph(italic) .. "</color>"
	end)

	-- [link text](href)
	text = md_match_and_replace(text, "%[([^%]]+)%]%(([^%)]+)%)", function(link_text, link_ref)
		local r, g, b, a = GetRGBA(self.HyperlinkColor)
		return string.format("<color %s %s %s><h OpenUrl %s %s %s %s underline>", r, g, b, link_ref:gsub(" ", "+"), r, g, b) .. link_text .. "</h></color>"
	end)
	
	return text
end

function MarkdownParser:ParseLine(line)
	local level, text = line:match("^ ?(#+) ([^\n]+)")
	if level and text then
		level = #level
		if not level or level > 4 then
			return
		end

		local fontstyle = self["HeadingFont" .. level]
		local r, g, b, a = GetRGBA(self.BoldColor)
		return string.format("<style %s><color %s %s %s %s>", fontstyle, r, g, b, a) .. self:ParseParagraph(text) .. "</color></style>\n"
	end
	
	local bullet_text = line:match(" %* (.+)") or line:match("%+ (.+)")
	if bullet_text then
		return "    • " .. self:ParseParagraph(bullet_text) .. "\n"
	end
	
	local num_text = line:match(" %d+%. (.+)")
	if num_text then
		self.numbered_entries = self.numbered_entries + 1
		return "    " .. self.numbered_entries .. ". " .. self:ParseParagraph(num_text) .. "\n", "do_not_clear_counter"
	end
	
end

function MarkdownParser:ApplyParagraph()
	self.output = self.output .. self:ParseParagraph(self.paragraph)
	self.paragraph = ""
end

function MarkdownParser:ParseTopLevelLine(line)
	if not line then
		self:ApplyParagraph()
		return
	end
	
	if line:trim_spaces() == "" then
		self.empty_lines = self.empty_lines + 1
		return
	end
	
	if self.empty_lines > 1 then
		self.empty_lines = 0
		self:ApplyParagraph()
		self.output = self.output .. "\n"
	end

	local line_parsed, do_not_clear_counter = self:ParseLine(line)
	if not do_not_clear_counter then
		self.numbered_entries = 0
	end
	if line_parsed then
		self:ApplyParagraph()
		self.output = self.output .. line_parsed
		return
	end
	
	self.paragraph = self.paragraph .. line .. "\n"
end

function MarkdownParser:ConvertText(input)
	local r, g, b, a = GetRGBA(self.TextColor)
	self.output = string.format("<color %s %s %s %s>", r, g, b, a)
	local current_idx = 1
	while current_idx < #input do
		local idx = input:find("\n", current_idx) or #input + 1
		local line = input:sub(current_idx, idx-1)
		current_idx = idx + 1
		
		self:ParseTopLevelLine(line)
	end
	self:ParseTopLevelLine(nil)
	self.output = self.output .. "</color>"
	return self.output
end

function ParseMarkdown(input, properties)
	properties = properties and table.copy(properties) or {}
	local parser = MarkdownParser:new(properties)
	return parser:ConvertText(input)
end