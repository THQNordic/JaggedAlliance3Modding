DefineClass.HTMLParser = {
	__parents = { "PropertyObject" },
	
	properties = {
		{ category = "General", id = "TextColor", editor = "color", default = RGB(80, 80, 80) },
		{ category = "General", id = "BoldColor", editor = "color", default = RGB(0, 0, 0) },
		{ category = "General", id = "HyperlinkColor", editor = "color", default = RGB(0, 0, 238) },
		
		{ category = "General", id = "HeadingFont1", editor = "text", default = "Heading1" },
		{ category = "General", id = "HeadingFont2", editor = "text", default = "Heading2" },
		{ category = "General", id = "HeadingFont3", editor = "text", default = "Heading3" },
		{ category = "General", id = "HeadingFont4", editor = "text", default = "Heading4" },
	},
	
	numbered_entries = 0,
	errors = false,
}

function HTMLParser:MakeListItem(content)
	if #content > 0 then return "\n" .. content .. "\n" end
	return ""
end

function HTMLParser:HandleText(text)
	--handle escaped HTML characters in the form &#1234;
	local text_pieces = { }
	while #text > 0 do
		local first, last, content = string.find(text, "&([#%w%d]+);")
		if not first or not last or #content == 0 then
			table.insert(text_pieces, text)
			break
		end
		
		if string.starts_with(content, '#') then
			--allow only a visible ASCII characters
			local codepoint = tonumber(string.sub(content, 2))
			if codepoint and 31 < codepoint and codepoint < 127 then
				table.insert(text_pieces, string.sub(text, 1, first - 1))
				table.insert(text_pieces, string.char(codepoint))
			else
				table.insert(text_pieces, string.sub(text, first, last))
			end
		else
			local char
			if content == "lt" then char = '<' end
			if content == "gt" then char = '>' end
			if content == "amp" then char = '&' end
			if content == "nbsp" then char = ' ' end --special nbsp character in the apostrophes
			
			if char then
				table.insert(text_pieces, string.sub(text, 1, first - 1))
				table.insert(text_pieces, char)
			else
				table.insert(text_pieces, string.sub(text, first, last))
			end
		end
		
		text = string.sub(text, last + 1)
	end
	text = table.concat(text_pieces, "")
	
	--sequences of whitespaces collapse into a single space
	text = text:gsub("%s+", " ")
	
	return text
end

function HTMLParser:BeginTag(tag, attributes, state)
	if tag == "UL" then
		local old_state = {self.MakeListItem}
		self.MakeListItem = function(self, content) return "\n•" .. content end
		return old_state
	end
	if tag == "OL" then
		local old_state = {self.MakeListItem, self.numbered_entries}
		self.MakeListItem = function(self, content)
			self.numbered_entries = self.numbered_entries + 1
			return string.format("\n%s. %s", self.numbered_entries, content)
		end
		return old_state
	end
end

function HTMLParser:EndTag(tag, attributes, state, original_inner_html, processed_html)
	local level = string.match(tag, "H(%d+)")
	if level then
		level = tonumber(level)
		if not level or level < 1 or level > 4 then level = 1 end
		
		local fontstyle = self["HeadingFont" .. level]
		local r, g, b, a = GetRGBA(self.BoldColor)
		return string.format("\n<style %s><color %s %s %s %s>", fontstyle, r, g, b, a) .. processed_html .. "</color></style>\n"
	end
	
	if tag == "P" then
		return "\n" .. processed_html:gsub("\n", "") .. "\n"
	end

	if tag == "BR" then
		return "</br>" -- keep BRs as they will be replaced much later to new lines.
	end
	
	if tag == "STRONG" or tag == "B" then
		local r, g, b, a = GetRGBA(self.BoldColor)
		return string.format("<color %s %s %s %s>", r, g, b, a) .. processed_html .. "</color>"
	end

	if tag == "A" then
		local r, g, b, a = GetRGBA(self.HyperlinkColor)
		local link_ref = attributes.href
		if not link_ref then return "" end
		link_ref = link_ref:gsub(" ", "+")
		if (processed_html or "") ~= "" then
			return string.format("%s [%s]", processed_html, link_ref)
		else
			return link_ref
		end
		--return string.format("<color %s %s %s><h OpenUrl %s %s %s %s underline>", r, g, b, link_ref, r, g, b) .. processed_html .. "</h></color>"
	end
	
	if tag == "UL" then
		processed_html = processed_html:gsub("\n", "\n    ")
		self.MakeListItem = state[1]
		return "\n" .. processed_html .. "\n"
	end

	if tag == "OL" then
		processed_html = processed_html:gsub("\n", "\n    ")
		self.MakeListItem = state[1]
		self.numbered_entries = state[2]
		return "\n" .. processed_html .. "\n"
	end

	if tag == "LI" then
		return self:MakeListItem(processed_html)
	end

	return ""
end

local function closest_find(str, patterns)
	local results = {}
	for key, value in ipairs(patterns) do
		table.insert(results, table.pack(string.find(str, value)))
	end
	
	table.sort(results, function(a,b) return (a[1] or 10000) < (b[1] or 100000) end)
	return table.unpack(results[1])
end

function HTMLParser:ExtractAttributes(tag)
	-- "a href='qwert'" => {href = "qwert"}
	local name, rest = string.match(tag, "(%w+)%s+(.+)")
	if not name then return string.upper(tag), {} end
	
	local attributes = {}
	while #rest > 0 do
		local start_idx, end_idx, key, value =  closest_find(rest, {"(%w+)%s*=%s*\"([^\"]*)\"", "(%w+)%s*=%s*\'([^\']*)\'", "(%w+)%s*=%s*([^%s]+)"})

		if start_idx then
			attributes[key] = value
			rest = rest:sub(end_idx + 1)
		else
			break
		end
	end
	return string.upper(name), attributes
end

function HTMLParser:Error(err)
	self.errors = self.errors or {}
	table.insert(self.errors, err)
end

function HTMLParser:CloseHTMLTag(tag_to_close, attributes, rest_of_text)
	local pos = 0
	local buffer = ""
	local state = self:BeginTag(tag_to_close, attributes)
	while pos < #rest_of_text do
		local next_tag_start, next_tag_end = string.find(rest_of_text, "<[^>]+>", pos)
		if not next_tag_start then
			buffer = buffer .. self:HandleText(rest_of_text:sub(pos))
			break
		end
		local tag = rest_of_text:sub(next_tag_start + 1, next_tag_end - 1)
		local slashed, tag_str = string.match(tag, "^(/?)%s*(%w+).*$")
		tag_str = tag_str and string.upper(tag_str)
		
		buffer = buffer .. self:HandleText(rest_of_text:sub(pos, next_tag_start - 1))
		if (slashed and #slashed > 0) or tag_str == "BR" then
			if tag_str == tag_to_close then
				buffer = self:EndTag(tag_str, attributes, state, rest_of_text:sub(1, next_tag_start-1), buffer)
				pos = next_tag_end + 1
				break
			elseif tag_str == "BR" then
				buffer = buffer .. self:EndTag(tag_str, {}, false, rest_of_text:sub(next_tag_start-1), "")
				pos = next_tag_end + 1
			else
				self:Error("Expected " .. tag_to_close .. " found " .. tag)
				pos = next_tag_end + 1
			end
		else
			local new_tag_str, attributes = self:ExtractAttributes(tag)
			local processed_html, next_pos = self:CloseHTMLTag(new_tag_str, attributes, rest_of_text:sub(next_tag_end + 1))
			pos = next_pos + next_tag_end
			buffer = buffer .. processed_html
		end

	end
	return buffer, pos
end

function HTMLParser:ConvertText(input)
	local r, g, b, a = GetRGBA(self.TextColor)
	local text, reached_pos =  self:CloseHTMLTag(nil, {}, input)
	local final_text = string.format("<color %s %s %s %s>", r, g, b, a) .. text .. "</color>"
	return final_text:gsub("[%s]*[\n]+", "\n"):gsub("</?br%s*/?>", "\n")
end

function ParseHTML(input, properties)
	properties = properties and table.copy(properties) or {}
	local parser = HTMLParser:new(properties)
	return parser:ConvertText(input), parser.errors
end