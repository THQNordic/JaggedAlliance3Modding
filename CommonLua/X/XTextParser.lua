local FindNextLineBreakCandidate = utf8.FindNextLineBreakCandidate
local GetLineBreakInfo = utf8.GetLineBreakInfo

local function SetFont(font, scale)
	local text_style = TextStyles[font]
	if not text_style then
		assert(false, string.format("Invalid text style '%s'", font))
		return 0, 0, 0
	end
	local font_id, height, baseline = text_style:GetFontIdHeightBaseline(scale:y())
	if not font_id or font_id < 0 then
		assert(false, string.format("Invalid font in text style '%s'", font))
		return 0, 0, 0
	end
	return font_id, height, baseline
end

 ------------ Layouting -----------
DefineClass.XTextBlock = {
	__parents = { "PropertyObject" },

	exec = false, -- for command blocks

	total_width = false, -- if this were to be placed on a single line, how long would it be?
	total_height = false,
	min_start_width = false, -- minimum required space to start the token.
	new_line_forbidden = false, -- should be started after the last token on the same line.
	end_line_forbidden = false,
	is_content = false, -- if the word wrapper should layout this.
}

tag_processors.newline = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout.left_margin = (tonumber(args[1]) or 0) * state.scale:x() / 1000
		layout:NewLine(false)
	end)
end

tag_processors.vspace = function(state, args)
	local vspace = tonumber(args[1])
	if not vspace then
		state:PrintErr("Vspace should be a number")
		return
	end
	state:MakeFuncBlock(function(layout)
		layout:SetVSpace(vspace)
		layout:NewLine(false)
	end)
end

tag_processors.zwnbsp = function(state, args)
	state:MakeBlock({
		total_width = 0,
		total_height = 0,
		min_start_width = 0,
		new_line_forbidden = true,
		end_line_forbidden = true,
		text = "",
	})
end

tag_processors.linespace = function(state, args)
	local linespace = tonumber(args[1])
	if not linespace then
		state:PrintErr("Linespace should be a number")
		return
	end
	state:MakeFuncBlock(function(layout)
		layout.font_linespace = linespace
	end)
end

tag_processors.valign = function(state, args)
	local alignment = args[1]
	assert(alignment == "top" or alignment == "center" or alignment == "bottom")
	state.valign = args[1]
	state.y_offset = MulDivTrunc(args[2] or 0, state.scale:x(), 1000)
end

tag_processors.hide = function(state, args, tok_idx_start)
	local tokens = state.tokens
	local hide_counter = 1
	local tok_idx = tok_idx_start + 1
	while tok_idx < #tokens do
		local token = tokens[tok_idx]
		tok_idx = tok_idx + 1
		if token.type == "hide" then
			hide_counter = hide_counter + 1
		elseif token.type == "/hide" then
			hide_counter = hide_counter - 1
			if hide_counter == 0 then
				break
			end
		end
	end
	return tok_idx - tok_idx_start
end

tag_processors["/hide"] = function(state, args)
	-- do nothing but still interpret this as a tag
end

tag_processors.background = function(state, args)
	if args[1] == "none" then
		state:PushStackFrame("background").background = RGBA(0,0,0,0)
		return
	end

	if #args == 1 then
		local color = tonumber(args[1])
		if not color then
			local style = TextStyles[GetTextStyleInMode(args[1], GetDarkModeSetting()) or args[1]]
			if not style then
				state:PrintErr("TextStyle could not be found (" .. args[1] .. ")")
				color = RGB(255, 255, 255)
			else
				color = style.TextColor
			end
		end
		assert(type(color) == "number")
		state:PushStackFrame("background").background_color = color
	else
		local num1 = tonumber(args[1]) or 255
		local num2 = tonumber(args[2]) or 255
		local num3 = tonumber(args[3]) or 255
		local num4 = tonumber(args[4]) or 255
		state:PushStackFrame("background").background_color = RGBA(num1, num2, num3, num4)
	end
end

tag_processors["/background"] = function(state, args)
	state:PopStackFrame("background")
end

tag_processors.hyperlink = function(state, args) -- check for "underline" as the last argument
	if     args[1] == "underline" then args[1], state.hl_underline = "", true
	elseif args[6] == "underline" then args[6], state.hl_underline = "", true
	elseif args[5] == "underline" then args[5], state.hl_underline = "", true
	elseif args[4] == "underline" then args[4], state.hl_underline = "", true
	elseif args[3] == "underline" then args[3], state.hl_underline = "", true
	end

	-- decode arguments
	if args[5] and args[5] ~= "" then -- <h function argument r g b [underline]>
		state.hl_argument = args[2]
		state.hl_hovercolor = RGB(tonumber(args[3]) or 255, tonumber(args[4]) or 255, tonumber(args[5]) or 255)
	elseif args[4] and args[4]~= "" then -- <h function r g b [underline]>
		state.hl_hovercolor = RGB(tonumber(args[2]) or 255, tonumber(args[3]) or 255, tonumber(args[4]) or 255)
	elseif args[3] and args[3]~= ""then -- <h function argument color [underline]>
		state.hl_argument = args[2]
		state.hl_hovercolor = const.HyperlinkColors[args[3]]
	else -- <h function color [underline]>
		state.hl_hovercolor = const.HyperlinkColors[args[2]]
	end

	state.hl_internalid = state.hl_internalid + 1
	state.hl_function = args[1]
	if state.hl_argument == "true" then
		state.hl_argument = true
	elseif state.hl_argument == "false" then
		state.hl_argument = false
	elseif tonumber(state.hl_argument) then
		state.hl_argument = tonumber(state.hl_argument)
	end
end
tag_processors.h = tag_processors.hyperlink

tag_processors["/hyperlink"] = function(state, args)
	state.hl_function = nil
	state.hl_argument = nil
	state.hl_hovercolor = nil
	state.hl_underline = nil
end
tag_processors["/h"] = tag_processors["/hyperlink"]

tag_processors.shadowcolor = function(state, args)
	local effect_color
	if args[1] == "none" then
		effect_color = RGBA(0, 0, 0, 0)
	else
		if not (args[1] ~= "" and args[2] ~= "" and args[3] ~= "") then
			state:PrintErr("found tag 'shadowcolor' without 3 value for RGB :", text, n)
		end
		effect_color = RGB(tonumber(args[1]) or 255, tonumber(args[2]) or 255, tonumber(args[3]) or 255)
	end
	local frame = state:PushStackFrame("effect")
	frame.effect_color = effect_color
end

tag_processors["/shadowcolor"] = function(state, args)
	state:PopStackFrame("effect")
end

local effect_types = {
	shadow = "shadow",
	glow = "glow",
	outline = "outline",
	extrude = "extrude",
	["false"] = false,
	["none"] = false,
}

tag_processors["effect"] = function(state, args)
	local effect_type = "shadow"
	local effect_color = RGB(64, 64, 64)
	local effect_size = 2
	local effect_dir = point(1,1)

	local effect_type = effect_types[args[1]]
	if effect_type == nil then
		state:PrintErr("tag effect with invalid type", args[1])
		effect_type = false
	end
	effect_size = tonumber(args[2]) or 2
	effect_color = RGB(tonumber(args[3]) or 255, tonumber(args[4]) or 255, tonumber(args[5]) or 255)
	effect_dir = point(tonumber(args[6]) or 1, tonumber(args[7]) or 1)

	local frame = state:PushStackFrame("effect")
	frame.effect_color = effect_color
	frame.effect_size = effect_size
	frame.effect_type = effect_type
	frame.effect_dir = effect_dir
end

tag_processors["/effect"] = function(state, args)
	state:PopStackFrame("effect")
end

local function remove_after(tbl, idx)
	while tbl[idx] do
		table.remove(tbl, #tbl)
	end
end

tag_processors.reset = function(state, args)
	remove_after(state.stackable_state, 2)
end

tag_processors.text = function(state, text)
	-- handles \n and word_wrap
	local lines = {}
	local pos_bytes = 1
	local text_bytes = #text
	while pos_bytes <= text_bytes do
		local new_line_start_idx, new_line_end_idx = string.find(text, "\r?\n", pos_bytes)
		if not new_line_start_idx then
			new_line_start_idx = text_bytes + 1
			new_line_end_idx = text_bytes + 1
		end
		local line = string.sub(text, pos_bytes, new_line_start_idx - 1)
		table.insert(lines, line)
		
		pos_bytes = new_line_end_idx + 1
	end
	if string.sub(text, text_bytes) == "\n" then
		table.insert(lines, "")
	end

	for idx, line in ipairs(lines) do
		if idx > 1 then
			state:MakeFuncBlock(function(layout)
				layout:NewLine(false)
			end)
		end

		local line_byte_idx = 1
		while true do
			local istart, iend = string.find(line, "\t", line_byte_idx, true)
			local part = string.sub(line, line_byte_idx, (istart or 0) - 1)
			
			state:MakeTextBlock(part)

			if istart then
				local width, height = UIL.MeasureText("    ", state:fontId())
				state:MakeBlock({
					total_width = width,
					total_height = height,
					min_start_width = width,
					new_line_forbidden = false,
					end_line_forbidden = false,
					text = false,
				})
			else
				break
			end
			
			line_byte_idx = iend + 1
		end
	end
end

tag_processors.image = function(state, args)
	local image = args[1]

	local image_size_org_x, image_size_org_y = UIL.MeasureImage(image)
	local current_image_scale_x, current_image_scale_y
	local arg2_scale = tonumber(args[2])
	if arg2_scale then
		current_image_scale_x = MulDivTrunc(arg2_scale * state.default_image_scale, state.scale:x(), 1000 * 1000)
		current_image_scale_y = MulDivTrunc(arg2_scale * state.default_image_scale, state.scale:y(), 1000 * 1000)
	else
		current_image_scale_x, current_image_scale_y = state.image_scale:xy()
	end
	
	local num1 = tonumber(args[3]) or 255
	local num2 = tonumber(args[4]) or 255
	local num3 = tonumber(args[5]) or 255
	local image_color = RGB(num1, num2, num3)
	
	if image_size_org_x == 0 and image_size_org_y == 0 then
		state:PrintErr("image not found in tag :", image)
	else
		local image_size_x = MulDivTrunc(image_size_org_x, current_image_scale_x, 1000)
		local image_size_y = MulDivTrunc(image_size_org_y, current_image_scale_y, 1000)
		local base_color_map = args[3] == "rgb" or args[6] == "rgb" -- if 3-d arg is the color then try 6-th
	
		state:MakeBlock({
			total_width = image_size_x,
			total_height = image_size_y,
			min_start_width = image_size_x,
			image_size_org_x = image_size_org_x,
			image_size_org_y = image_size_org_y,
			image = image,
			base_color_map = base_color_map,
			image_color = image_color,
			new_line_forbidden = true,
		})
	end
end


tag_processors.color = function(state, args)
	local color
	if #args == 1 then
		color = tonumber(args[1])
		if not color then
			local style = TextStyles[GetTextStyleInMode(args[1], GetDarkModeSetting()) or args[1]]
			if not style then
				state:PrintErr("TextStyle could not be found (" .. args[1] .. ")")
				color = RGB(255, 255, 255)
			else
				color = style.TextColor
			end
		end
		assert(type(color) == "number")
	else
		local num1 = tonumber(args[1]) or 255
		local num2 = tonumber(args[2]) or 255
		local num3 = tonumber(args[3]) or 255
		local num4 = tonumber(args[4]) or 255
		color = RGBA(num1, num2, num3, num4)
	end
	-- used for Ged help rollovers in dark mode
	if state.invert_colors then
		local r, g, b, a = GetRGBA(color)
		if r == g and g == b then
			local v = Max(240 - r, 0)
			color = RGBA(v, v, v, a)
		end
	end
	state:PushStackFrame("color").color = color
end

tag_processors.alpha = function(state, args)
	local alpha = tonumber(args[1])
	local top = state:GetStackTop()
	local r, g, b = GetRGB(top.color or top.start_color)
	state:PushStackFrame("color").color = RGBA(r, g, b, alpha)
end

tag_processors["/color"] = function(state, args)
	state:PopStackFrame("color")
end
tag_processors["/alpha"] = tag_processors["/color"]

tag_processors.scale = function(state, args)
	local scale_num = tonumber(args[1] or 1000)
	if not scale_num then
		state:PrintErr("Bad scale ", args[1])
		return
	end
	state.scale = state.original_scale * Max(1, scale_num) / 1000
	state.imagescale = state.scale
	local top = state:GetStackTop()
	local next_id, height = SetFont(top.font_name, state.scale)
	local frame = state:PushStackFrame("scale")
	frame.font_id = next_id
	frame.font_height = height
end

tag_processors.imagescale = function(state, args)
	local scale_num = tonumber(args[1] or state.default_image_scale)
	if not scale_num then
		state:PrintErr("Bad scale ", args[1])
		return
	end

	state.image_scale = state.original_scale * Max(1, scale_num) / 1000
end

tag_processors.style = function(state, args)
	local style = TextStyles[GetTextStyleInMode(args[1], GetDarkModeSetting()) or args[1]]
	if style then
		local next_id, height = SetFont(args[1], state.scale)
		local frame = state:PushStackFrame("style")
		frame.font_id = next_id
		frame.font_height = height
		frame.font_name = args[1]
		frame.color = style.TextColor
		frame.effect_color = style.ShadowColor
		frame.effect_size = style.ShadowSize
		frame.effect_type = style.ShadowType
		frame.effect_dir = style.ShadowDir
	else
		state:PrintErr("Invalid style", args[1])
	end
end

tag_processors["/style"] = function(state, args)
	state:PopStackFrame("style")
end

tag_processors.wordwrap = function(state, args)
	local word_wrap = args[1]
	if word_wrap == "on" or word_wrap == "off" then
		state:PrintErr("WordWrap should be on or off")
		return
	end

	state:MakeFuncBlock(function(layout)
		layout.word_wrap = word_wrap == "on"
	end)
end

tag_processors.right = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout:SetAlignment("right")
	end)
end

tag_processors.left = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout:SetAlignment("left")
	end)
end

tag_processors.center = function(state, args)
	state:MakeFuncBlock(function(layout)
		layout:SetAlignment("center")
	end)
end

tag_processors.tab = function(state, args)
	state:MakeFuncBlock(function(layout)
		--assert(not layout.word_wrap) -- tabs do not work with word wrap
		local tab_pos = tonumber(args[1]) * state.scale:x() / 1000
		if not tab_pos then
			layout:PrintErr("Bad tab pos", args[1])
			return
		end
		layout:SetTab(tab_pos, args[2])
	end)
end

tag_processors.underline = function(state, args)
	if args[1] and (args[2] and args[3] or TextStyles[args[1]] or tonumber(args[1])) then
		if args[2] and args[3] then
			state.underline_color = RGB(tonumber(args[1]) or 255, tonumber(args[2]) or 255, tonumber(args[3]) or 255)
		else
			state.underline_color = TextStyles[args[1]] and TextStyles[args[1]].TextColor or tonumber(args[1])
		end
	else
		state.underline_color = false
	end
	state.underline = true
end

tag_processors.horizontal_line = function(state, args)
	local thickness = args[1] or 1
	local margin = args[2] or 0
	local space_above = args[3] or 5
	local space_below = args[4] or 50
	local stack = state:GetStackTop()
	local color = stack.color
	local scale = Max(stack.font_height and MulDivRound(1000, stack.font_height, 20) or 0, 1000)
	state:MakeBlock({
		min_start_width = 9999999, 
		total_width = 9999999,
		total_height = MulDivRound(scale, space_above + space_below + thickness, 1000),
		space_above = space_above,
		space_below = space_below,
		horizontal_line = true,
		thickness = thickness,
		margin = margin,
		color = color,
		scale = scale,
	})
end

tag_processors["/underline"] = function(state, args)
	state.underline = false
	state.underline_color = false
end

DefineClass.BlockBuilder = {
	__parents = {"InitDone"},

	IsEnabled = false,
	first_error = false,

	line_height = 0,
	valign = "center",
	y_offset = 0,
	stackable_state = false,
	underline = false,
	underline_color = RGBA(0, 0, 0, 0),
	scale = point(1000, 1000),
	original_scale = point(1000, 1000),
	default_image_scale = 1000,
	image_scale = point(1000, 1000),

	hl_internalid = 0,
	hl_function = false,
	hl_argument = false,
	hl_hovercolor = false,
	hl_underline = false,

	blocks = false,
}

function BlockBuilder:Init()
	self.stackable_state = {
		{
			font_id = 0,
			font_name = "Console", -- needs to be an existing TextStyle; this one's in Common
			color = false,
			font_height = 32,
			effect_color = 0,
			effect_size = 0,
			effect_type = false,
			effect_dir = point(1,1),
			start_color = 0,
		}
	}

	self.blocks = {}
end

function BlockBuilder:ProcessTokens(tokens, src_text)
	self.tokens = tokens
	self.src_text = src_text

	local token_idx = 1
	while token_idx <= #tokens do
		self.token_idx = token_idx
		local token = tokens[token_idx]
		local handler = tag_processors[token.type]
		local offset
		if handler then 
			offset = handler(self, token.args or token.text, token_idx) or 1
		else
			self:PrintErr("Encountered invalid token", token.type)
			offset = 1
		end
		token_idx = token_idx + offset
	end
end

function BlockBuilder:GetStackTop()
	return self.stackable_state[#self.stackable_state]
end

function BlockBuilder:PushStackFrame(tag)
	assert(tag and type(tag) == "string")
	local stack = self.stackable_state
	assert(#stack >= 1)
	local new_frame = table.copy(stack[#stack])
	new_frame.tag = tag
	stack[#stack + 1] = new_frame
	return new_frame
end

function BlockBuilder:PopStackFrame(tag)
	assert(tag and type(tag) == "string")
	local stack = self.stackable_state
	local top = stack[#stack]
	if #stack == 1 then
		self:PrintErr("Tag", tag, "has no more frames to pop.")
		return top
	end
	if top.tag ~= tag then
		self:PrintErr("Tag \"" .. top.tag .. "\" was closed with tag \"" .. tag .. "\"")
	end
	table.remove(stack)
	return top
end

DefineClass.XTextParserError = {
	__parents = {"PropertyObject"},
	src_text = "",

	__eq = function(self, other)
		if not IsKindOf(self, "XTextParserError") or not IsKindOf(other, "XTextParserError") then return false end
		return self.src_text == other.src_text
	end,
}

function BlockBuilder:PrintErr(...)
	local err = self:FormatErr(...)
	local token_list = {}
	for i = 1, #self.tokens do
		local token = self.tokens[i]
		local str = ""
		if token.type == "text" then
			str = token.text
		else
			str = "<color 40 160 40><literal " .. (#token.text + 2) .. "><" .. token.text .. "></color>"
		end
		table.insert(token_list, str)
		if self.token_idx == i then
			table.insert(token_list, "<color 160 40 40><literal 8><<<ERROR</color>")
		end
	end

	if not self.first_error then
		err = string.format("<color 160 40 40>XText Parse Error: </color><literal %s>%s\n%s", #err, err, table.concat(token_list, "<color 40 40 140> || </color>"))
		self.first_error = err
		StoreErrorSource(XTextParserError:new({src_text = self.src_text}), err)
	end
end

function BlockBuilder:FormatErr(...)
	local err = ""
	for _, arg in ipairs(table.pack(...)) do
		err = err .. tostring(arg) .. " "
	end
	return err
end

function BlockBuilder:fontId()
	return self:GetStackTop().font_id
end

function BlockBuilder:MakeBlock(cmd)
	local top = self:GetStackTop()
	cmd.height = top.font_height
	cmd.font = cmd.font or top.font_id
	cmd.color = top.color
	cmd.effect_color = top.effect_color
	cmd.effect_type = top.effect_type
	cmd.effect_size = top.effect_size
	cmd.effect_dir = top.effect_dir
	cmd.line_height = Max(self.line_height, top.font_height)
	cmd.y_offset = self.y_offset
	cmd.background_color = top.background_color
	
	cmd.underline = self.underline
	cmd.underline_color = self.underline and self.underline_color or false

	cmd.hl_function = self.hl_function
	cmd.hl_argument = self.hl_argument
	cmd.hl_underline = self.hl_underline
	cmd.hl_hovercolor = self.hl_hovercolor
	cmd.hl_internalid = self.hl_internalid


	if not IsKindOf(cmd, "XTextBlock") then
		cmd = XTextBlock:new(cmd)
	end
	
	table.insert(self.blocks, cmd)
end

function BlockBuilder:MakeTextBlock(text)
	local width, height = UIL.MeasureText(text, self:fontId())
	local break_candidate = FindNextLineBreakCandidate(text, 1)
	local min_width = width
	if break_candidate and break_candidate < #text then
		min_width = UIL.MeasureText(text, self:fontId(), 1, break_candidate - 1)
	end
	local cannot_start_line, cannot_end_line = GetLineBreakInfo(text)
	self:MakeBlock({
		text = text,
		valign = self.valign,
		total_width = width,
		total_height = height,
		min_start_width = min_width,
		new_line_forbidden = cannot_start_line,
		end_line_forbidden = cannot_end_line,
	})
end

function BlockBuilder:MakeFuncBlock(func)
	table.insert(self.blocks, XTextBlock:new({ exec = func }))
end

DefineClass.BlockLayouter = {
	__parents = {"PropertyObject"},

	tokens = false,
	blocks = false,
	draw_cache = false,

	pos_x = 0,
	left_margin = 0,
	line_position_y = 0,
	last_font_height = 0,
	line_height = 0,
	font_linespace = 0,

	word_wrap = true,
	shorten = true,
	shorten_string = false,
	max_width = 1000000,
	max_height = 1000000,

	--tab support
	alignment = "left",
	tab_x = 0,
	draw_cache_start_idx_current_line = 1,
	
	line_content_width = 0,
	line_was_word_wrapped = false,
	measure_width = 0,
	suppress_drawing_until = false,

	contains_wordwrapped_content = false,
}

local MeasureText = UIL.MeasureText
local Advance = utf8.Advance
local function FindTextThatFitsIn(line, start_idx, font_id, max_width, required_leftover_space, line_max_width)
	local pixels_reached = 0
	local byte_idx = start_idx
	local line_bytes = #line
	
	while byte_idx <= line_bytes do
		local next_break_idx = FindNextLineBreakCandidate(line, byte_idx)
		if not next_break_idx then
			break
		end

		--local wrapped_chunk = string.sub(line, byte_idx, next_break_idx - 1)
		local chunk_size = MeasureText(line, font_id, byte_idx, next_break_idx - 1)
		if next_break_idx >= line_bytes then
			chunk_size = chunk_size + required_leftover_space
		end
		if chunk_size + pixels_reached > max_width then
			-- can't fit even one word in the line? => split the text
			local split_text = max_width == line_max_width and pixels_reached == 0
			if not split_text then
				-- the next word wouldn't fit alone on the next line (without the leading space)? => split the text
				local idx = byte_idx
				if string.byte(line, idx) == 32 then -- eat empty space at the beginning
					idx = idx + 1
				end
				if MeasureText(line, font_id, idx, next_break_idx - 1) > line_max_width then
					split_text = true
				end
			end
			if split_text then
				local curr_break_idx = byte_idx
				while curr_break_idx < next_break_idx do
					local next_idx = Advance(line, curr_break_idx, 1)
					chunk_size = MeasureText(line, font_id, byte_idx, next_idx - 1)
					if chunk_size > max_width - pixels_reached then break end
					curr_break_idx = next_idx
				end
				byte_idx = curr_break_idx
				return string.sub(line, start_idx, byte_idx - 1), byte_idx - start_idx
			end
			break
		end
		pixels_reached = pixels_reached + chunk_size
		byte_idx = next_break_idx
	end

	if pixels_reached == 0 then
		return "", 0, 0
	end

	return string.sub(line, start_idx, byte_idx - 1), byte_idx - start_idx
end

function BlockLayouter:FinalizeLine()
	self:FinishTab()
	
	if not self.draw_cache then self.draw_cache = {} end
	local draw_cache_line = self.draw_cache[self.line_position_y]
	if draw_cache_line then
		self.measure_width = Max(self.measure_width, self.line_content_width)
		for _, item in ipairs(draw_cache_line) do
			item.line_height = self.line_height
			
			if item.valign == "top" then
				item.y_offset = item.y_offset + 0
			elseif item.valign == "center" then
				item.y_offset = item.y_offset + (item.line_height - item.height) / 2
			elseif item.valign == "bottom" then
				item.y_offset = item.y_offset + item.line_height - item.height
			else
				assert(false)
			end
		end
	end
	self.line_content_width = 0
	self.line_was_word_wrapped = false
end

function BlockLayouter:NewLine(word_wrapped)
	self:FinalizeLine()

	self.line_position_y = self.line_position_y + Max(self.last_font_height / 2, self.line_height + self.font_linespace)
	self.line_height = 0
	self.pos_x = self.left_margin
	assert(word_wrapped == true or word_wrapped == false)
	self.line_was_word_wrapped = word_wrapped

	self.draw_cache_start_idx_current_line = 1

	if self.suppress_drawing_until == "new_line" then
		self.suppress_drawing_until = false
	end
end

function BlockLayouter:SetAlignment(align)
	if self.alignment ~= align then
		self:FinishTab()
		self.alignment = align

		if self.alignment ~= "left" then
			self.tab_x = 0
		end
	end
end

function BlockLayouter:SetTab(tab, alignment)
	if self.alignment ~= (alignment or "left") then
		self:SetAlignment(alignment or "left")
	else
		self:FinishTab()
	end
	self.tab_x = tab
end

function BlockLayouter:FinishTab()
	if not self.draw_cache then self.draw_cache = {} end
	local draw_cache_line = self.draw_cache[self.line_position_y]
	if not draw_cache_line then return end
	
	local draw_cache_start_idx = self.draw_cache_start_idx_current_line
	local used_width = 0
	for idx = draw_cache_start_idx, #draw_cache_line do
		local item = draw_cache_line[idx]
		used_width = Max(used_width, item.x + item.width)
	end

	local shift, alignment = 0, self.alignment
	if alignment == "center" then
		shift = -used_width / 2
	elseif alignment == "right" then
		shift = -used_width
	end

	shift = shift + self.tab_x

	for idx = draw_cache_start_idx, #draw_cache_line do
		local item = draw_cache_line[idx]
		item.x = item.x + shift
		if alignment == "center" then
			item.control_wide_center = true
		end
	end

	self.line_content_width = Max(self.line_content_width + used_width, used_width + self.tab_x)
	self.tab_x = 0
	self.draw_cache_start_idx_current_line = #draw_cache_line + 1
	self.pos_x = self.left_margin
end

function BlockLayouter:AvailableWidth()
	return Max(0, self.max_width - self.pos_x)
end

function BlockLayouter:PrintErr(...)
	print("DrawCache err", ...)
end

function BlockLayouter:SetVSpace(space)
	self.line_height = Max(self.line_height, space)
end

-- this function considers requirements imposed by the text from adjacent blocks,
-- e.g. if the next block starts with a , it can't go onto the next line
local function CalcRequiredLeftoverSpace(blocks, idx)
	local pixels = 0
	while idx <= #blocks do
		local block = blocks[idx]
		if block.exec then
			break
		end
		
		local prev_block = blocks[idx - 1]
		if (prev_block and prev_block.end_line_forbidden) or block.new_line_forbidden then
			pixels = pixels + block.min_start_width
			if block.min_start_width < block.total_width then
				break
			end
		else
			break
		end

		idx = idx + 1
	end

	return pixels
end

function BlockLayouter:LayoutWordWrappedText(block, required_leftover_space)
	assert(self.word_wrap)
	local line = block.text
	
	local byte_idx = 1
	local line_bytes = #line
	while byte_idx <= line_bytes do
		local has_just_word_wrapped = self.pos_x == self.left_margin and self.line_was_word_wrapped
		if has_just_word_wrapped then
			self.contains_wordwrapped_content = true
			if string.byte(line, byte_idx) == 32 then -- eat empty space at the beginning
				byte_idx = byte_idx + 1
				if byte_idx > line_bytes then
					break
				end
			end
		end
		
		local wrapped_text, advance_bytes =
			FindTextThatFitsIn(line, byte_idx, block.font, self:AvailableWidth(), required_leftover_space, self.max_width - self.left_margin)
		if #wrapped_text == 0 then
			if self.pos_x ~= self.left_margin then
				self:TryCreateNewLine()
			else -- this should only happen if even a single letter can't fit in the total width
				local next_pos = utf8.Advance(line, byte_idx, 1) - 1
				assert(UIL.MeasureText(line, block.font, byte_idx, next_pos) > self.max_width - self.left_margin)
				-- put the entire text on the current line
				wrapped_text = string.sub(line, byte_idx)
				advance_bytes = #wrapped_text
			end
		end
		
		self:DrawTextOnLine(block, wrapped_text)
		byte_idx = byte_idx + advance_bytes
	end
end

function BlockLayouter:DrawTextOnLine(block, text)
	text = text or block.text
	if text == "" then
		return
	end
	local text_width, text_height = UIL.MeasureText(text, block.font)
	if self.shorten and not self.word_wrap then
		local available = self:AvailableWidth()
		if text_width > available then
			text = UIL.TrimText(text, block.font, available, 0, self.shorten_string)
			text_width, text_height = UIL.MeasureText(text, block.font)
			self.suppress_drawing_until = "new_line"
			self.has_word_wrapped = true
		end
	end
	self:DrawOnLine({
		text = text,
		width = text_width,
		height = block.height,
		font = block.font,
		effect_color = block.effect_color or false,
		effect_type = block.effect_type or false,
		effect_size = block.effect_size or false,
		effect_dir = block.effect_dir or false,
		color = block.color,
		line_height = block.line_height,
		valign = block.valign,
		y_offset = block.y_offset,
		background_color = block.background_color,

		underline = block.underline,
		underline_color = block.underline_color,
		hl_function = block.hl_function,
		hl_argument = block.hl_argument,
		hl_underline = block.hl_underline,
		hl_hovercolor = block.hl_hovercolor or block.color,
		hl_internalid = block.hl_function and block.hl_internalid,
	})
end

function BlockLayouter:LayoutBlock(block, required_leftover_space)
	if rawget(block, "text") then
		if block.text == "" then
			return
		end

		if self.word_wrap then
			self:LayoutWordWrappedText(block, required_leftover_space)
		else
			self:DrawTextOnLine(block)
		end
	elseif rawget(block, "image") then
		-- create image
		self:DrawOnLine({
			image = block.image,
			base_color_map = block.base_color_map,
			width = block.total_width,
			height = block.total_height,
			line_height = block.total_height,
			image_size_org = box(0, 0, block.image_size_org_x, block.image_size_org_y),
			valign = "center",
			y_offset = block.y_offset,
			image_color = block.image_color,
		})
	elseif rawget(block, "horizontal_line") then
		self:DrawOnLine({
			width = block.total_width,
			height = block.total_height,
			line_height = block.total_height,
			horizontal_line = block.horizontal_line,
			thickness = block.thickness,
			space_above = block.space_above,
			space_below = block.space_below,
			margin = block.margin,
			valign = "center",
			y_offset = 0,
			color = block.color,
			scale = block.scale,
		})
	else
		-- just take the space without doing anyting
		self:DrawOnLine({
			width = block.total_width,
			height = block.total_height,
			line_height = block.total_height,
		})
	end
end

function BlockLayouter:TryCreateNewLine()
	if self.word_wrap then
		self:NewLine(true)
		return true
	end
	return false
end

function BlockLayouter:ShortenDrawCacheElement(elem, space_available)
	if rawget(elem, "text") then
		local text = elem.text
		local byte_idx = #text + 1
		while byte_idx > 0 do
			local test_text = text:sub(1, byte_idx - 1) .. (self.shorten_string or "...")
			local x_reached = elem.x + UIL.MeasureText(test_text, elem.font)
			if x_reached <= space_available then
				elem.text = test_text
				return true
			end

			byte_idx = utf8.Retreat(text, byte_idx, 1)
		end
	end
	return false
end

--[===[
	This is an extremly simple shortening for the most common case. Finds the last completely visible line and tries adding "..." at the end.
	Removes the rest of the content after that. Should be OKish for paragraphs of text.
	Why this is not perfect:
	- You can't really measure "..." as those symbols vary based on previous letter. We have subpixel rendering (per word). So measure_width("...") != measure_width("lastword...") - measure_width("lastword")
	- We support images/icons. What happens when an icon happens to be at the end of the line? Remove the icon, potentially replace it with "...". If "..." can't fit we might need to merge it with the last words and remove a few letters from there as well.
	- If "..." happens to be after an icon, what font should be used?
	- We support "empty" lines of variable heights. See <vspace 80> tag. See also <tab> tag and right/center aligned text.
	- We don't know the height of the current line until it is *completely* done. All of the content should be processed before shortening can happen.
	And non-technical questions:
	- Is appending ... ok for all languages we support? After which letters is it OK to do that?
]===]

function BlockLayouter:IsDrawCacheMultiline(draw_cache)
	local line_counter = 0
	for _, val in pairs(draw_cache) do
		line_counter = line_counter + 1
		if line_counter >= 2 then
			return true
		end
	end
	return false
end

function BlockLayouter:ShortenDrawCache()
	local draw_cache = self.draw_cache

	if not self:IsDrawCacheMultiline(draw_cache) then
		return
	end

	local last_line_that_fit = 0
	local excess_lines = 0
	for y, data in sorted_pairs(draw_cache) do
		local max_y = y + data[1].line_height
		if max_y <= self.max_height then
			last_line_that_fit = y
		else
			excess_lines = excess_lines + 1
		end
	end

	if excess_lines == 0 then
		return
	end

	self.draw_cache_text_shortened = false
	local line = draw_cache[last_line_that_fit]
	for i = #line, 1, -1 do
		local item = line[i]
		if self:ShortenDrawCacheElement(item, self.max_width) then
			self.draw_cache_text_shortened = true
			break
		else
			line[i] = nil
		end
	end

	for _, y in ipairs(table.keys(draw_cache)) do
		if y > last_line_that_fit then
			draw_cache[y] = nil
		end
	end
end

function BlockLayouter:LayoutBlocks()
	local blocks = self.blocks
	assert(blocks)
	local draw_cache = {}
	self.draw_cache = draw_cache
	
	-- blocks are a list of visual content (images/texts + )
	local block_idx = 1
	local last_block_with_content = false
	while block_idx <= #blocks do
		local block = blocks[block_idx]
		-- layout stuff and write to draw_cache
		if block.exec then
			block.exec(self)
		elseif not self.suppress_drawing_until then
			-- do layouting
			local required_leftover_space = 0
			if self.word_wrap then
				local new_line_allowed = not last_block_with_content or (not last_block_with_content.end_line_forbidden and not block.new_line_forbidden)
				if new_line_allowed and block.min_start_width > self:AvailableWidth() then
					self:TryCreateNewLine()
				end
				-- calculate space required by next block(s), e.g. if their initial character can't begin a new line
				required_leftover_space = CalcRequiredLeftoverSpace(blocks, block_idx + 1)
			end
			self:LayoutBlock(block, required_leftover_space)
			last_block_with_content = block
		end

		block_idx = block_idx + 1
	end
	self:FinalizeLine()

	if self.shorten and self.word_wrap and self.max_height < BlockLayouter.max_height then
		self:ShortenDrawCache()
	end

	return draw_cache, self.measure_width, self.line_position_y + self.line_height
end


function BlockLayouter:DrawOnLine(cmd)
	assert(cmd.width > 0)
    -- Note that we DO not create a new line here. Let LayoutBlocks or the TextWordWrap to do it if they decide to.
	cmd.x = self.pos_x
	
	self.pos_x = self.pos_x + cmd.width
	self.line_height = Max(Max(self.line_height, cmd.line_height), cmd.total_height)
	self.last_font_height = self.line_height

	if cmd.image or cmd.text or cmd.horizontal_line then
		if not self.draw_cache then self.draw_cache = { } end
		if not self.draw_cache[self.line_position_y] then
			self.draw_cache[self.line_position_y] = { }
		end
		
		table.insert(self.draw_cache[self.line_position_y], cmd)
	end
end

function XTextCompileText(text)
	local tokens = XTextTokenize(text)
	if #tokens == 0 then
		return false
	end

	local draw_state = BlockBuilder:new( {
		first_error = false,
		PrintErr = function(self, ...)
			if not self.first_error then
				local err = self:FormatErr(...)
				self.first_error = err
			end
		end
	})
	draw_state:ProcessTokens(tokens, text)
	return draw_state.first_error
end

function XTextMakeDrawCache(text, properties)
	local tokens = XTextTokenize(text)
	if #tokens == 0 then
		return {}
	end
	local start_font_id, start_font_height = SetFont(properties.start_font_name, properties.scale)
	
	local draw_state = BlockBuilder:new( {
		IsEnabled = properties.IsEnabled,
		
		scale = properties.scale or point(1000, 1000),
		original_scale = properties.scale or point(1000, 1000),
		default_image_scale = properties.default_image_scale or 500,
		image_scale = MulDivTrunc(properties.scale, properties.default_image_scale, 1000),
		invert_colors = properties.invert_colors,
	})
	local top = draw_state.stackable_state[1]
	top.font_id = start_font_id or top.font_id
	top.font_name = properties.start_font_name or top.font_name
	top.color = false
	top.font_height = start_font_height or top.font_height
	top.effect_color = properties.IsEnabled and properties.EffectColor or properties.DisabledEffectColor
	top.effect_size = properties.effect_size
	top.effect_type = properties.effect_type
	top.effect_dir = properties.effect_dir
	top.start_color = properties.start_color
	top.background_color = 0

	draw_state:ProcessTokens(tokens, text)

	assert(draw_state.blocks)
	local block_layouter = BlockLayouter:new({
		blocks = draw_state.blocks,
		max_width = properties.max_width,
		max_height = properties.max_height,
		word_wrap = properties.word_wrap,
		shorten = properties.shorten,
		shorten_string = properties.shorten_string,
	})
	block_layouter:SetAlignment(properties.alignment or "left")

	local draw_cache, width, height = block_layouter:LayoutBlocks()
	return draw_cache or {}, block_layouter.contains_wordwrapped_content, Clamp(width, 0, properties.max_width), height, block_layouter.draw_cache_text_shortened
end

if Platform.developer then
local test_string = 
	[===[<underline> Underlined text. </underline>
<color 120 20 120>Color is 120 20 120</color>.
<color GedError>Color from TextStyle GedError</color>
Tags off: <tags off><color 255 0 0>Should not be red.</color><tags on>
<left>Left aligned text
<right>Right aligned text
<center>Center aligned text
<left>Left...<right>.. and right on the same line.
<left>Image: <image CommonAssets/UI/Ged/left>
Tab commands set the current "X" position to a certain value. Use carefully as elements may overlap. Tab is <tags off><left><tags on> with offset.
<tab 40>Tab to 40<tab 240>Tab to 240<newline>
Forced newline:<newline><tags off><newline><tags on> tag is always guaranteed to work(newlines might be trimmed by UI)
<style GedError>A new TextStyle by id GedError.</style>
<style GedDefault>GedDefault style in dark mode</style>
VSpace 80 following...<newline>
<vspace 80>...to here.
Word wrapping that works even when mixing with CJK languages. Note that the font might not have glyphs: 你知道我是谁吗？我可是玉皇大。
<effect glow 15 255 0 255>Shadows support...
<shadowcolor 0 255 0>With another color& legacy tag</shadowcolor>no stack, so default color</effect>
<scale 1800>Scaling support.<scale 1000>
<imagescale 3000><image CommonAssets/UI/HandCursor>
<hyperlink abc 255 0 0 underline>This is a hyperlink with ID abc and color 255 0 0</hyperlink>
The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
]===]

	function RunXTextParserTest(test)
		local game_question = StdMessageDialog:new({}, terminal.desktop, { question = true, title = "ABC", text = "" })
		game_question.MaxWidth = 10000
		game_question.idContainer.MaxWidth = 100000
		game_question.idContainer.Background = RGB(95, 83, 222)

		
		local effect_size = 2

		local text_ctrl = XText:new({
			MaxWidth = 412,
			MaxHeight = 800,
			
			ShadowSize = effect_size,
			WordWrap = true,
			Shorten = true,
		}, game_question.idContainer)
		text_ctrl:SetText(test_string)
		text_ctrl:SetOutsideScale(point(1000, 1000))
		game_question:Open()

		-- test core C methods
		local test_case = "AB C EF在茂。密"
		assert(#test_case == 19)
		assert(FindNextLineBreakCandidate(test_case, 1) == 3)
		assert(FindNextLineBreakCandidate(test_case, 3) == 5)
		assert(FindNextLineBreakCandidate(test_case, 5) == 8)
		assert(FindNextLineBreakCandidate(test_case, 8) == 11)
		assert(FindNextLineBreakCandidate(test_case, 11) == 17)
		assert(FindNextLineBreakCandidate(test_case, 17) == 20)
		assert(FindNextLineBreakCandidate(test_case, 20) == nil)
	end
end

local default_forbidden_sof = [[.-
!%), .:; ? ]}¢°·’†‡›℃∶、。〃〆〕〗〞﹚﹜！＂％＇），．：；？！］｝～
)]｝〕〉》」』】〙〗〟’｠»
ヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎゕゖㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻
‐゠–〜
? !‼⁇⁈⁉
・、 : ; ,
。.
!%), .:; ? ]}¢°’†‡℃〆〈《「『〕！％），．：；？］]]

local default_forbidden_eol = [[
$(£¥·‘〈《「『【〔〖〝﹙﹛＄（．［｛￡￥
([｛〔〈《「『【〘〖〝‘｟«
$([\\{£¥‘々〇〉》」〔＄（［｛｠￥￦#
]]

DefineClass.BreakCandidateRange = {
	__parents = {"PropertyObject"},
	properties = {
		{id = "Begin", editor = "number", default = 0,},
		{id = "End", editor = "number", default = 0,},
		{id = "Comment", editor = "text", default = "", },
		{id = "Enabled", editor = "bool", default = true, }
	},
}

function BreakCandidateRange:OnEditorSetProperty(prop_id, old_value, ged)
	local parent = GetParentTableOfKind(self, "XTextParserVars")
	parent:Apply()
end

function BreakCandidateRange:GetEditorView()
	return string.format("%x-%x %s", self.Begin, self.End, self.Comment)
end

DefineClass.XTextParserVars = {
	__parents = {"PersistedRenderVars"},

	properties = {
		{text_style = "Console", id = "ForbiddenSOL", help = "Characters that should not start lines", lines = 5, max_lines = 25, word_wrap = true, editor = "text", default = default_forbidden_sof},
		{text_style = "Console", id = "ForbiddenEOL", help = "Characters that should not end lines", lines = 5, max_lines = 25, word_wrap = true, editor = "text", default = default_forbidden_eol},
		{id = "BreakCandidates", help = "UTF8 Ranges that allow breaking before them. Space character is always included even if not in the list.", editor = "nested_list", default = false, base_class = "BreakCandidateRange", inclusive = true, },
		
	}
}

function XTextParserVars:Apply()
	const.LineBreak_ForbiddenSOL = string.gsub(self.ForbiddenSOL, " ", "")
	const.LineBreak_ForbiddenEOL = string.gsub(self.ForbiddenEOL, " ", "")
	local tbl = {}
	for idx, pair in ipairs(self.BreakCandidates or empty_table) do
		if pair.Enabled then
			tbl[#tbl+1] = pair.Begin
			tbl[#tbl+1] = pair.End
		end
	end
	utf8.SetLineBreakCandidates(tbl)
end