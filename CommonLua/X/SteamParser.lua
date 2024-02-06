--[[
	see https://steamcommunity.com/comment/Guide/formattinghelp
	
	- Tables are not processed, but their tags are removed.
	- "noparse" and "code" ignore tags inside it, but support nesting
	- leading whitespaces are removed after the first parsing and tag substitution is applied (except for "code" blocks which preserve spaces)
	- tabs are no supported beyond single level on bullet point (see <faketab>)
		it should be easy to support them on a per-tag basis, by adding "tab_increase" variable to the tag property (in all_tags) and keep track in the state_stack;
		doesn't seem like the engine supports tabs across multiple lines, so I did not implement it
	- I am assuming tabs need to be closed in proper order (for the stateful tags, at least, like code, noparse)
		=> [code][noparse][/code][/parse] and similar situations may fail
	
	- URLs are a bit iffy, especially if they end with a steam tag (because [/tag] can be a valid part of a url;
		all such occurrences are removed from valid expected tags.
	- if AllowURL is false, we display the inside of URL tags without a hyperlink;
		URLs found in the text are also removed
	- if Allow URL is true, we make the text inside the url tags a hyperlink to the link of the url tag itself;
		URLs found in the text are made into an hyperlink to itself (even if they are already inside another hyperlink; thus, displaying one url and opening
		a different page isn't supported (but surrounding text could link to a different page))
	- URLs inside "noparse" and "code" blocks are never made into hyperlinks
	- everything inside img tags is ignored (often, urls triggered by images, then, will never appear, when AllowURL is set to true)
	
	- horizontal lines used in [hr] and quotes aren't very good, especially when they need to be scaled with imagescale, which depends on the specific image
		used and the part of the UI where it is displayed; consider adding an additional control for the imagescale
--]]

DefineClass.SteamParser = {
	__parents = { "PropertyObject" },
	
	properties = {
		{ id = "AllowUrl", editor = "bool", default = false },
		{ id = "HyperlinkTextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		
		{ id = "QuoteTextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		
		{ id = "HorizontalLineThickness", editor = "number", default = 1 },
		{ id = "HorizontalLineMargin", editor = "number", default = 0 },
		{ id = "HorizontalLineSpaceAbove", editor = "number", default = 5 },
		{ id = "HorizontalLineSpaceBelow", editor = "number", default = 5 },
		
		{ id = "NormalTextStyle", editor = "preset_id", default = "GedDefault", invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "BoldTextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "ItalicTextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "Heading1TextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "Heading2TextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "Heading3TextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "CodeTextStyle", editor = "preset_id", default = false, invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
	},
	
	all_patterns = {
		noparse = { pattern = "noparse", tag = "noparse", open_style = "", close_style = "" },
		bold = { pattern = "b", tag = "bold", open_style = "<style %s>", close_style = "</style>", style = "BoldTextStyle" },
		italic = { pattern = "i", tag = "italic", open_style = "<style %s>", close_style = "</style>", style = "ItalicTextStyle",},
		underline = { pattern = "u", tag = "underline", open_style = "<underline>", close_style = "</underline>"},
		
		h1 = { pattern = "h1", tag = "h1", open_style = "<style %s>", close_style = "</style>", style = "Heading1TextStyle" },
		h2 = { pattern = "h2", tag = "h2", open_style = "<style %s>", close_style = "</style>", style = "Heading2TextStyle" },
		h3 = { pattern = "h3", tag = "h3", open_style = "<style %s>", close_style = "</style>", style = "Heading3TextStyle" },
		
		code = { pattern = "code", tag = "code", open_style = "<style %s codestart>", close_style = "</style codeend>", style = "CodeTextStyle" },
		
		list = { pattern = "list", tag = "list", open_style = "", close_style = "", style = "" },
		olist = { pattern = "olist", tag = "olist", open_style = "", close_style = "", style = "" },
		list_elem = { pattern = "*", tag = "list_elem", open_style = "", close_style = "", style = "" },
		
		-- hides the tag but displays inner content
		strike = { pattern = "strike", tag = "strike", open_style = "", close_style = "" },
		table = { pattern = "table", tag = "table", open_style = "", close_style = "", style = "" },
		tr = { pattern = "tr", tag = "tr", open_style = "", close_style = "", style = "" },
		th = { pattern = "th", tag = "th", open_style = "", close_style = "", style = "" },
		td = { pattern = "td", tag = "td", open_style = "", close_style = "", style = "" },
		
		-- hides tag and inner content
		img = { pattern = "img", tag = "img", open_style = "", close_style = "", style = "" },
		
		-- hardcoded specific patterns with capture or additional parameters that must be added to tag
		quote = { pattern = "quote", tag = "quote" },
		url = { pattern = "url", tag = "url" },
		hr = { pattern = "hr", tag = "hr" },
	},
	
	simple_patterns = {
		"noparse","bold","italic","underline","strike","h1","h2","h3","code","list","olist","table","tr","th","td","img",
	},
}

function SteamParser:CheckMode(mode)
	local state = self.state_stack
	return state and state[#state] and state[#state].mode == mode
end

function SteamParser:CheckModes(mode_table)
	for _, mode in ipairs(mode_table) do 
		if self:CheckMode(mode) then return true end
	end
	return false
end

function SteamParser:CheckTag(text, index)
	for _, tag in pairs(self.simple_patterns) do
		local properties = self.all_patterns[tag]
		local start_index, end_index = string.find(text, "^%[" .. properties.pattern .. "]", index) 
		if start_index then return "start_" .. properties.tag, start_index, end_index end
		
		local start_index, end_index = string.find(text, "^%[/" .. properties.pattern .. "]", index) 
		if start_index then return "end_" .. properties.tag, start_index, end_index end
	end
	
	local start_index, end_index = string.find(text, "^%[%*]", index)
	if start_index then return "list_elem", start_index, end_index end
	
	for _, tag in pairs({"quote", "url"}) do
		local properties = self.all_patterns[tag]
		local start_index, end_index, capture = string.find(text, "^%[" .. properties.pattern .. "=(.-)]", index) 
		if start_index then
			return "start_" .. properties.tag, start_index, end_index, capture 
		end
		
		local start_index, end_index = string.find(text, "^%[/" .. properties.pattern .. "]", index) 
		if start_index then return "end_" .. properties.tag, start_index, end_index end
	end
	
	local start_index, end_index = string.find(text, "^%[hr]", index)
	if start_index then return "start_horizontal_line", start_index, end_index end
	local start_index, end_index = string.find(text, "^%[/hr]", index)
	if start_index then return "end_horizontal_line", start_index, end_index end
end

function SteamParser:CheckAndProcessURL(text, index)
	local prefix = text:sub(index,index) == "h" and "https://" or "www."
	local start_index, end_index = string.find(text, "^"..prefix.."[%w%%-%._~:/%?#%[%]@!$&'()$*%+,;=]*", index)
	local url = false
	if start_index then 
		url = text:sub(start_index, end_index)
		while url:sub(#url, #url) do
			local found_tag = false
			for _, pat in ipairs({"quote", "url", table.unpack(self.simple_patterns)}) do
				local pattern = "%[/".. self.all_patterns[pat].pattern .."]$"
				local s_i, e_i = string.find(url, pattern)
				if s_i then
					url = url:sub(1, s_i-1)
					found_tag = true
				end
			end
			if not found_tag then break end
		end
		local length = #url
		if self.AllowUrl then
			if self:CheckModes({"img", "code", "noparse"}) then
				url = url
			else
				url = string.format("<h %s><style %s>%s</style></h>", url, self.HyperlinkTextStyle or self.NormalTextStyle, url)
			end
		else
			url = "" -- consider adding a "url removed" message?
		end
		return start_index, start_index + length - 1, url
	end
end

function SteamParser:ProcessTag(full_tag, capture)
	for _, mode in ipairs({"img", "noparse", "code"}) do
		if self:CheckMode(mode) then
			if full_tag == "start_" .. mode then
				table.insert(self.state_stack, { mode = mode })
				return false
			elseif full_tag == "end_" .. mode then
				self.state_stack[#self.state_stack] = nil
				if not self:CheckMode(mode) then return string.format(self.all_patterns[mode].close_style) end
				return false
			end
			return false
		end
	end
	
	if self:CheckMode("olist") then
		if full_tag == "list_elem" then
			self.state_stack[#self.state_stack].count = self.state_stack[#self.state_stack].count + 1
			return "<faketab>" .. tostring(self.state_stack[#self.state_stack].count - 1) .. ". "
		elseif full_tag == "end_olist" then
			self.state_stack[#self.state_stack] = nil
		end
	end
	
	if self:CheckMode("list") then
		-- if full_tag == "list_elem" then
		--	 return "<faketab> •  "
		if full_tag == "end_list" then
			self.state_stack[#self.state_stack] = nil
		end
	end
	
	-- apparently, steam treats isolated [*] as bullet points, see Beyond Stranded mod
	if full_tag == "list_elem" then
		return "<faketab> •  "
	end
	
	for _, mode in ipairs({"img", "olist", "list", "noparse", "code"}) do
		if full_tag == "start_" .. mode then
			table.insert(self.state_stack, { mode = mode, count = 1 })
		end
	end
	
	if full_tag == "start_quote" then
		return string.format("\nOriginally written by %s:<horizontal_line %d %d %d %d><style %s>", capture,
					self.HorizontalLineThickness,
					self.HorizontalLineMargin,
					self.HorizontalLineSpaceAbove,
					self.HorizontalLineSpaceBelow,
					self.QuoteTextStyle or self.NormalTextStyle)
	elseif full_tag == "end_quote" then
		return string.format("</style><horizontal_line %d %d %d %d>", 
					self.HorizontalLineThickness,
					self.HorizontalLineMargin,
					self.HorizontalLineSpaceAbove,
					self.HorizontalLineSpaceBelow)
	elseif full_tag == "start_url" then
		return self.AllowUrl and string.format("<h %s><style %s>", capture, self.HyperlinkTextStyle or self.NormalTextStyle) or ""
	elseif full_tag == "end_url" then
		return self.AllowUrl and "</style></h>" or ""
	elseif full_tag == "start_horizontal_line" then
		return string.format("<horizontal_line %d %d %d %d>", 
					self.HorizontalLineThickness,
					self.HorizontalLineMargin,
					self.HorizontalLineSpaceAbove,
					self.HorizontalLineSpaceBelow)
	elseif full_tag == "end_horizontal_line" then 
		return ""
	end
	
	if string.match(full_tag, "start_") then
		local tag = string.sub(full_tag, 7)
		return string.format(self.all_patterns[tag].open_style, self[self.all_patterns[tag].style or self.NormalTextStyle])
	elseif string.match(full_tag, "end_") then
		local tag = string.sub(full_tag, 5)
		return string.format(self.all_patterns[tag].close_style)
	end
end

function SteamParser:ParseStatefulText(text)
	local output_text = ""
	local i = 1
	while i <= #text do
		local char = text:sub(i,i)
		local ignore_char = false
		if char == "[" then
			local tag_type, start_index, end_index, capture = self:CheckTag(text, i)
			if tag_type then
				local tag_append = self:ProcessTag(tag_type, capture)
				if tag_append then
					output_text = output_text .. tag_append
					ignore_char = true
					i = i + end_index - start_index + 1
				end
			end
		elseif not self:CheckMode("img") and (char == "h" or char == "w")  then
			local start_index, end_index, append = self:CheckAndProcessURL(text, i)
			if append then
				output_text = output_text .. append
				ignore_char = true
				i = i + end_index - start_index + 1
			end
		end
		if not ignore_char then 
			if not self:CheckMode("img") then output_text = output_text .. char end
			i = i + 1
		end
	end
	return output_text
end

-- clears all leading spaces except in lines within a "code" block
-- inserts a tab before list elements (planted in the earlier parsing)
function SteamParser:CleanLeadingWhitespaces(input)
	local function ltrim(s)
	  return s:match'^%s*(.*)'
	end
	local output = ""
	local code_depth = 0
	for s in input:gmatch("[^\r\n]+") do
		if code_depth == 0 then s = ltrim(s) end
		local _, count = string.gsub(s, "codestart>", "")
		code_depth = code_depth + count
		local _, count = string.gsub(s, "codeend>", "")
		code_depth = Max(0, code_depth - count)
		if s ~= "" or true then
			output = output .. "\n" .. s
		end
	end
	output = string.gsub(output, "<faketab>", "\t")
	return output
end

function SteamParser:ConvertText(input)
	local output = input
	output = string.gsub(output, "<", "<literal 1><") -- because one lovely modder broke things with <3
	self.state_stack = {}
	output = self:ParseStatefulText(output)
	self.state_stack = {}
	return self:CleanLeadingWhitespaces(output)
end

function ParseSteam(input, properties)
	properties = properties and table.copy(properties) or {}
	local parser = SteamParser:new(properties)
	local output = parser:ConvertText(input)
	return output
end