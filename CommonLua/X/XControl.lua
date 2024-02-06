DefineClass.XControl = {
	__parents = { "XWindow", "FXObject" },

	properties = {
		{ category = "Interaction", id = "Enabled", editor = "bool", default = true, },
		{ category = "Interaction", id = "Target", editor = "text", default = "", },
		{ category = "FX", id = "FXMouseIn", editor = "text", default = "", },
		{ category = "FX", id = "FXPress", editor = "text", default = "", },
		{ category = "FX", id = "FXPressDisabled", editor = "text", default = "", },
		{ category = "Visual", id = "FocusedBorderColor", name = "Focused border color", editor = "color", default = RGB(0, 0, 0), },
		{ category = "Visual", id = "FocusedBackground", name = "Focused background", editor = "color", default = RGBA(0, 0, 0, 0), },
		{ category = "Visual", id = "DisabledBorderColor", name = "Disabled border color", editor = "color", default = RGB(0, 0, 0), },
		{ category = "Visual", id = "DisabledBackground", name = "Disabled background", editor = "color", default = RGBA(0, 0, 0, 0), },
		-- read only
		{ category = "FX", id = "Particles", read_only = true, editor = "string_list", default = false, }
	},
	enabled = true,
	IdNode = true,
	HandleMouse = true,
	particles = false,
}

------ BEGIN PARTICLES CODE

DefineClass.UIParticleInstance = {
	__parents = {"PropertyObject"},
	
	id = false,
	parsys_name = false,
	foreground = true,
	lifetime = -1,
	transfer_to_parent = false,
	stop_on_transfer = true,
	offset = point(0, 0),
	owner = false,
	delete_owner = false,
	halign = "middle",
	valign = "middle",
	keep_alive = false,
	polyline = false,
	params = false,
	dynamic_params = false,
}

local function align_position(alignment, rstart, rend)
	if alignment == "begin" then
		return rstart
	elseif alignment == "end" then
		return rend
	elseif alignment == "middle" then
		return (rstart + rend) / 2
	else
		assert("Invalid alignment")
		return rstart
	end
end

local function calc_particle_origin(control, particle)
	local box = control.content_box
	local posx = align_position(particle.halign, box:minx(), box:maxx())
	local posy = align_position(particle.valign, box:miny(), box:maxy())
	return posx, posy
end

function UIParticleInstance:ApplyDynamicParams()
	local proto = self.parsys_name
	local dynamic_params = ParGetDynamicParams(proto)
	if not next(dynamic_params) then
		self.dynamic_params = nil
		return
	end
	self.dynamic_params = dynamic_params
	local set_value = self.SetParamDef
	for k, v in pairs(dynamic_params) do
		set_value(self, v, v.default_value)
	end
end 

local UIParticleSetDynamicDataString = UIL.UIParticleSetDynamicDataString
function UIParticleInstance:SetPointsAsPolyline(pts)
	self.polyline = pstr("")
	for _, pt in ipairs(pts or empty_table) do
		self.polyline:AppendVertex(pt)
	end
	UIParticleSetDynamicDataString(self.id, 0, self.polyline)
end


function UIParticleInstance:SetParam(param, value)
	local dynamic_params = self.dynamic_params
	local def = dynamic_params and rawget(dynamic_params, param)
	if def then
		self:SetParamDef(def, value)
	end
end

function UIParticleInstance:SetParamDef(def, value)
	local ptype = def.type
	if ptype == "number" then
		UIParticleSetDynamicDataString(self.id, def.index, value)
	elseif ptype == "color" then
		UIParticleSetDynamicDataString(self.id, def.index, value)
	elseif ptype == "point" then
		local x, y, z = value:xyz()
		local idx = def.index
		UIParticleSetDynamicDataString(self.id, idx, x)
		UIParticleSetDynamicDataString(self.id, idx + 1, y)
		UIParticleSetDynamicDataString(self.id, idx + 2, z or 0)
	elseif ptype == "bool" then
		UIParticleSetDynamicDataString(self.id, def.index, value and 1 or 0)
	end
end

function UIParticleInstance:UpdateBordersPolyline()
	local bbox = self.owner.box
	local pts = {
		point(bbox:minx(), bbox:miny()),
		point(bbox:maxx(), bbox:miny()),
		point(bbox:maxx(), bbox:maxy()),
		point(bbox:minx(), bbox:maxy()),
	}

	local x, y = calc_particle_origin(self.owner, self)
	local origin = point(x, y)
	for idx, _ in ipairs(pts) do
		local diff = (pts[idx] - origin)
		pts[idx] = point(diff:x() * guim, diff:y() * -guim)
	end

	self:SetPointsAsPolyline(pts)

	self:SetParam("width", bbox:sizex() * 1000)
	self:SetParam("height", bbox:sizey() * 1000)	
end

local HasUIParticles = UIL.HasUIParticles
local StopUIParticlesEmitter = UIL.StopUIParticlesEmitter
local function ParticleLifetimeFunc(particle, lifetime)
	if lifetime >= 0 then
		Sleep(lifetime)
		StopUIParticlesEmitter(particle.id)
	end

	local last_tick_had_particles = true
	Sleep(1000)
	while true do
		local has_particles = HasUIParticles(particle.id) or particle.keep_alive
		if not has_particles and not last_tick_had_particles then
			break
		end
		last_tick_had_particles = has_particles
		Sleep(1000)
	end

	assert(particle.owner)
	particle.owner:KillParSystem(particle.id, "leave_lifetimethread")
end

function XControl:OnBoxChanged()
	for _, particle in ipairs(self.particles) do
		particle:UpdateBordersPolyline()
	end
end

function XControl:AddParSystem(id, name, instance)
	self.particles = self.particles or {}
	instance = instance or UIParticleInstance:new({})
	
	assert(name)
	if not id then
		id = UIL.PlaceUIParticles(name)
	end
	assert(id)
	assert(instance.owner == false)
	instance.id = id
	instance.parsys_name = name
	instance.owner = self
	instance:ApplyDynamicParams()

	instance.lifetime_thread = CreateRealTimeThread(ParticleLifetimeFunc, instance, instance.lifetime)
	table.insert(self.particles, instance)

	self:Invalidate()
	instance:UpdateBordersPolyline()
	return id
end

function XControl:StopParticle(particle, force)
	if type(particle) ~= "table" then
		particle = table.find_value(self.particles, "id", particle)
		if not particle then return end
	end
	particle.keep_alive = false
	if force then
		self:KillParSystem(particle.id)
	else
		DeleteThread(particle.lifetime_thread)
		particle.lifetime_thread = CreateRealTimeThread(ParticleLifetimeFunc, particle, 0)
	end
end

function XControl:KillParticlesWithName(name)
	if not self.particles then return end
	for _, particle in ipairs(self.particles) do
		if particle.parsys_name == name then
			self:KillParSystem(particle.id)
		end
	end
end

function XControl:GetParticleName(id)
	if not self.particles then return end
	local particle = table.find_value(self.particles, "id", id)
	if not particle then return end
	return particle.parsys_name
end

function XControl:TransferParticleUp(particle)
	assert(table.find(self.particles, particle))
	local parent = self.parent
	local top_level_end_of_life_window = self
	while parent and (parent.window_state ~= "open" or IsKindOf(parent, "XContentTemplate")) do
		top_level_end_of_life_window = parent
		parent = parent.parent
	end

	if not parent then return end
	-- TODO: Insert the child at the right position in the parent and figure out why it results in asserts on main menu

	--print("Transferting to ", parent.Id, parent.class, top_level_end_of_life_window.Id, top_level_end_of_life_window.class)
	--local child_index = table.find(parent, top_level_end_of_life_window)
	--assert(child_index)

	local particle_holder = XControl:new({}, parent)
	--table.remove_value(parent, particle_holder)
	--table.insert(parent, child_index, particle_holder)

	particle_holder.particles = {}
	table.insert(particle_holder.particles, particle)
	particle.offset = particle.owner.content_box:min() - point(calc_particle_origin(particle_holder, particle)) + particle.offset
	particle.owner = particle_holder
	particle.delete_owner = true
	particle.foreground = true
	table.remove_value(self.particles, particle)
	if #self.particles == 0 then
		self.particles = false
	end
end

function XControl:KillParSystem(id, leave_lifetimethread)
	if not self.particles then return end

	local idx = table.find(self.particles, "id", id)
	assert(idx)
	local particle = self.particles[idx]
	assert(particle.owner == self)
	if not leave_lifetimethread then
		DeleteThread(particle.lifetime_thread)
	end
	UIL.DeleteUIParticles(particle.id)
	table.remove(self.particles, idx)
	if #self.particles == 0 then
		self.particles = false
	end
	if particle.delete_owner then
		self:delete()
	end
	particle.keep_alive = false
	self:Invalidate()
end
 
function XControl:HasParticle(id)
	if not self.particles then return false end
	if not table.find(self.particles, "id", id) then return false end
	return true
end

if Platform.developer then
	function XControl:DbgPlayFX(...)
		local index = self.particles and #(self.particles) or 1
		self:PlayFX(...)
		if not self.particles then
			return
		end
		for i = index, #self.particles do
			local particle = self.particles[i]
			if particle.lifetime == -1 then
				particle.keep_alive = true
			end
		end
	end
end

function XControl:ParticlesOnDone()
	local particles = self.particles
	if particles then
		for i = #particles, 1, -1 do
			local particle = particles[i]
			if particle.transfer_to_parent and UIL.ShouldWaitForHasUIParticles(particle.id) then
				if particle.stop_on_transfer then
					self:StopParticle(particle)
				end
				self:TransferParticleUp(particle)
			else
				self:KillParSystem(particle.id)
			end
		end
	end
end

function XControl:Done()
	self:ParticlesOnDone()
end

function GetUIParticleAlignmentItems(horizontal)
	return {
		{ value = "begin", text = horizontal and "left" or "top" },
		{ value = "middle", text = "center" },
		{ value = "end", text = horizontal and "right" or "bottom" },
	}
end

function XControl:DrawParticles(foreground)
	for key, particle in ipairs(self.particles) do
		if particle.foreground == foreground then
			local scale = self.scale:x()
			UIL.DrawParticles(particle.id, point(calc_particle_origin(self, particle)) + particle.offset, scale, scale, 0)
		end
	end
end

function XControl:DrawBackground()
	XWindow.DrawBackground(self)
	self:DrawParticles(false)
end

function XControl:DrawChildren(clip_box)
	XWindow.DrawChildren(self, clip_box)
	self:DrawParticles(true)
end

function XControl:GetParticles()
	return self.particles and table.map(self.particles, "parsys_name")
end

------ END OF PARTICLES CODE

function XControl:SetEnabled(enabled, force)
	local old = self.enabled
	self.enabled = enabled and true or false
	if self.enabled == old and not force then return end
	for _, win in ipairs(self) do
		if win:IsKindOf("XControl") then
			win:SetEnabled(enabled)
		end
	end
	self:Invalidate()
end

function XControl:GetEnabled()
	return self.enabled
end

function XControl:PlayFX(fx, moment, pos)
	if fx and fx ~= "" then
		PlayFX(fx, moment or "start", self, self.Id, pos)	
	end
end

function XControl:OnSetFocus(focus)
	self:Invalidate()
	XWindow.OnSetFocus(self, focus)
end

function XControl:OnKillFocus()
	self:Invalidate()
	XWindow.OnKillFocus(self)
end

function XControl:CalcBackground()
	if not self.enabled then return self.DisabledBackground end
	local FocusedBackground, Background = self.FocusedBackground, self.Background
	if FocusedBackground == Background then return Background end
	return self:IsFocused() and FocusedBackground or Background
end

function XControl:CalcBorderColor()
	if not self.enabled then return self.DisabledBorderColor end
	local FocusedBorderColor, BorderColor = self.FocusedBorderColor, self.BorderColor
	if FocusedBorderColor == BorderColor then return BorderColor end
	return self:IsFocused() and FocusedBorderColor or BorderColor
end

function XControl:OnSetRollover(rollover)
	XWindow.OnSetRollover(self, rollover)
	self:PlayHoverFX(rollover)
end

if FirstLoad then
	LastUIFXPos = false
end

function XControl:TryMarkUIFX(event)
	-- mark LastUIFXPos only if there is an actual event
	if event and event ~= "" then
		local pt = terminal.GetMousePos()
		if self:MouseInWindow(pt) and pt == LastUIFXPos then
			return
		end
		LastUIFXPos = pt
	end
	return true
end

function XControl:PlayActionFX(forced)
	local event = (self.enabled or forced) and self.FXPress or self.FXPressDisabled
	self:TryMarkUIFX(event)
	self:PlayFX(event)
	return true
end

function XControl:PlayHoverFX(rollover)
	if not self.enabled or rollover and not self:TryMarkUIFX(self.FXMouseIn) then
		return false -- avoid playing hover FX right after other FX
	end
	self:PlayFX(self.FXMouseIn, rollover and "start" or "end")
	return true
end

function XControl:OnMouseButtonDown(pos, button)
	if button == "L" then
		self:PlayActionFX()
	end
end


----- XContextControl

DefineClass.XContextControl = {
	__parents = { "XContextWindow", "XControl", },
	ContextUpdateOnOpen = true,
}


----- XFontControl

DefineClass.XFontControl = {
	__parents = { "XControl" },
	
	properties = {
		category = "Visual",
		{ id = "TextStyle", editor = "preset_id", default = "GedDefault", invalidate = "measure", preset_class = "TextStyle", editor_preview = true, },
		{ id = "TextFont", editor = "text", default = "", invalidate = "measure", no_edit = true, },
		{ id = "TextColor", editor = "color", default = RGB(32, 32, 32), invalidate = "measure", no_edit = true, },
		{ id = "RolloverTextColor", editor = "color", default = RGB(0, 0, 0), invalidate = "measure", no_edit = true, },
		{ id = "DisabledTextColor", editor = "color", default = RGBA(32, 32, 32, 128), invalidate = "measure", no_edit = true, },
		{ id = "DisabledRolloverTextColor", editor = "color", default = RGBA(40, 40, 40, 128), invalidate = "measure", no_edit = true, },
		{ id = "ShadowType", editor = "choice", default = "shadow", items = {"shadow", "extrude", "outline"}, invalidate = "measure", no_edit = true, },
		{ id = "ShadowSize", editor = "number", default = 0, invalidate = "measure", no_edit = true, },
		{ id = "ShadowColor", editor = "color", default = RGBA(0, 0, 0, 48), invalidate = "measure", no_edit = true, },
		{ id = "ShadowDir", editor = "point", default = point(1,1), invalidate = "measure", no_edit = true, },
		
		{ id = "DisabledShadowColor", editor = "color", default = RGBA(0, 0, 0, 48), invalidate = "measure", no_edit = true, },
	},

	font_id = false,
	font_height = 10,
	font_linespace = 0,
	font_baseline = 8,
}

function XFontControl:Init()
	self:SetTextStyle(self.TextStyle)
end

function XFontControl:SetTextStyle(style, force)
	self.TextStyle = style ~= "" and style or nil
	local text_style = TextStyles[style]
	if style == "" or not text_style then return end
	self:SetTextFont(style, force)
	self:SetTextColor(text_style.TextColor)
	self:SetRolloverTextColor(text_style.RolloverTextColor)
	self:SetDisabledTextColor(text_style.DisabledTextColor)
	self:SetShadowType(text_style.ShadowType)
	self:SetShadowSize(text_style.ShadowSize)
	self:SetShadowColor(text_style.ShadowColor)
	self:SetShadowDir(text_style.ShadowDir)
	self:SetDisabledShadowColor(text_style.DisabledShadowColor)
	self:SetDisabledRolloverTextColor(text_style.DisabledRolloverTextColor)
end

function XFontControl:SetTextFont(font, force)
	if self.TextFont == font and not force then return end
	self.TextFont = font
	self.font_id = false
	self:InvalidateMeasure()
	self:Invalidate()
end

function XFontControl:OnScaleChanged(scale)
	self.font_id = false
end

function XFontControl:CalcTextColor()
	return self.enabled and 
		(self.rollover and self.RolloverTextColor or self.TextColor) or
		(self.rollover and self.DisabledRolloverTextColor or self.DisabledTextColor)
end

function XFontControl:OnSetRollover(rollover)
	local invalidate
	if self.enabled then
		invalidate = self.RolloverTextColor ~= self.TextColor
	else
		invalidate = self.DisabledRolloverTextColor ~= self.DisabledTextColor
	end
	if invalidate then
		self:Invalidate()
	end
	
	XControl.OnSetRollover(self, rollover)
end

function XFontControl:GetFontId()
	local font_id = self.font_id
	if not font_id then
		local text_style = TextStyles[self:GetTextStyle()]
		if not text_style then
			assert(false, string.format("Invalid text style '%s'", self:GetTextStyle()))
			return
		end
		font_id, self.font_height, self.font_baseline = text_style:GetFontIdHeightBaseline(self.scale:y())
		self.font_id = font_id
	end
	return font_id
end

function XFontControl:GetFontHeight()
	self:GetFontId()
	return self.font_height
end

function XFontControl:SetFontProps(font_control)
	local style = font_control:GetTextStyle()
	if style ~= "" and TextStyles[style] then
		self:SetTextStyle(style)
		return
	end
	self:SetTextFont(font_control:GetTextFont())
	self:SetTextColor(font_control:GetTextColor())
	self:SetRolloverTextColor(font_control:GetRolloverTextColor())
	self:SetDisabledTextColor(font_control:GetDisabledTextColor())
	self:SetShadowType(font_control:GetShadowType())
	self:SetShadowSize(font_control:GetShadowSize())
	self:SetShadowColor(font_control:GetShadowColor())
	self:SetShadowDir(font_control:GetShadowDir())
	self:SetDisabledShadowColor(font_control:GetDisabledShadowColor())
	self:SetDisabledRolloverTextColor(font_control:GetDisabledRolloverTextColor())
end


----- XTranslateText

DefineClass.XTranslateText = {
	__parents = { "XFontControl", "XContextControl" },
	
	properties = {
		{ category = "General", id = "Translate", editor = "bool", default = false, },
		{ category = "General", id = "Text", editor = "text", default = "", translate = function (obj) return obj:GetProperty("Translate") end, },
		{ category = "General", id = "UpdateTimeLimit", name = "Update limit", editor = "number", default = 0, },
	},
	ContextUpdateOnOpen = false,
	text = "",
	last_update_time = 0,
}

function XTranslateText:OnTextChanged(text)
end

function XTranslateText:SetText(text)
	if type(text) == "number" then text = tostring(text) end
	self.Text = text or nil
	text = text or ""
	assert(self.Translate or type(text) == "string") -- passing a T value with Translate == false?
	assert(not self.Translate or IsT(text)) -- passing a text value with Translate == true?
	if text ~= "" and (self.Translate or IsT(text)) then
		text = _InternalTranslate(text, self.context)
	end
	if self.text ~= text then
		self:OnTextChanged(text)
		self.text = text
		self.last_update_time = RealTime()
		self:InvalidateMeasure()
		self:Invalidate()
	end
end

function XTranslateText:OnContextUpdate(context)
	local limit = self.UpdateTimeLimit
	if limit == 0 or (RealTime() - self.last_update_time) >= limit then
		self:SetText(self.Text)
	elseif not self:GetThread("ContextUpdate") then
		self:CreateThread("ContextUpdate", function(self)
			Sleep(self.last_update_time + self.UpdateTimeLimit - RealTime())
			self:OnContextUpdate()
		end, self)
	end
end

function XTranslateText:OnXTemplateSetProperty(prop_id, old_value)
	-- toggle text properties between Ts and strings when Translate is edited
	if prop_id == "Translate" then
		self:UpdateLocalizedProperty("Text", self.Translate)
		ObjModified(self)
	end
end

function RecursiveUpdateTTexts(root)
	if IsKindOf(root, "XTranslateText") and root.Translate and IsT(root:GetText()) then
		root:SetText(root:GetText())
		root:SetTextStyle(root:GetTextStyle(), "force")
	end
	for i = 1, #root do
		RecursiveUpdateTTexts(root[i])
	end
end

function OnMsg.TranslationChanged()
	ClearTextStyleCache()
	RecursiveUpdateTTexts(terminal.desktop)
end

----- XEditableText

DefineClass.XEditableText = {
	__parents = { "XFontControl", "XContextControl" },
	
	properties = {
		{ category = "General", id = "Translate", name = "Translated text", editor = "bool", default = false,
			help = "Enabled for texts that the developers enter and that need to go into the translation tables.\n\nGetText will return a T value with a localization ID.",
		},
		{ category = "General", id = "UserText", name = "User text", editor = "bool", default = false,
			help = "Enable for user-entered texts that need to be filtered for profanity.\n\nGetText will return a special T value with extra data such as source user ID, language, etc.",
		},
		{ category = "General", id = "UserTextType", editor = "choice", default = "unknown", items = {"name", "chat", "game_content", "unknown"}, no_edit = function(obj) return not obj.UserText end,
			help = "The user text is filtered in a different way, depending on this value; supported by Steam only.",
		},
		{ category = "General", id = "Text", editor = "text", translate = function(self) return self.Translate end, default = "", },
		{ category = "General", id = "OnTextChanged", editor = "func", params = "self"},
	},
	
	text = "",
	text_translation_id = false,
}

function XEditableText:SetText(text)
	if self.Translate then
		assert(IsT(text))
		self.text_translation_id = TGetID(text) or nil
		text = type(text) == "string" and text or TDevModeGetEnglishText(text, "deep", "no_assert")
	elseif self.UserText then
		assert(IsUserText(text))
		text = type(text) == "string" and text or TDevModeGetEnglishText(text, "deep", "no_assert")
	end
	self:SetTranslatedText(text)
end

function XEditableText:SetTranslatedText(text, notify)
	if self.text ~= text then
		assert(type(text) == "string")
		self.text = IsT(text) and TDevModeGetEnglishText(text) or text
		if notify ~= false then
			self:OnTextChanged()
		end
		self:InvalidateMeasure()
		self:Invalidate()
	end
end

function XEditableText:GetText()
	local text = self.text
	if text == "" or (not self.Translate and not self.UserText) then
		return text
	elseif self.UserText then
		return CreateUserText(self.text, self.UserTextType)
	end
	local id = self.text_translation_id or RandomLocId()
	self.text_translation_id = id
	text = text:gsub("\r?\n", "\n")
	return T{id, text}
end

function XEditableText:GetTranslatedText()
	return self.text
end

function XEditableText:OnTextChanged()
end


----- XPopup

xpopup_anchor_types = {"none", "custom", "drop", "drop-right", "smart", "left", "right", "top", "bottom", "center-top", "center-bottom", "bottom-right", "bottom-left", "top-left", "top-right", "right-center", "left-center" , "mouse", "live-mouse"}
DefineClass.XPopup = {
	__parents = { "XControl" },
	properties = {
		{ category = "General", id = "Anchor", editor = "rect", default = box(0, 0, 0, 0), },
		{ category = "General", id = "AnchorType", editor = "choice", default = "none", items = xpopup_anchor_types },
	},
	LayoutMethod = "VList",
	Dock = "ignore",
	Background = RGB(240, 240, 240),
	FocusedBackground = RGB(240, 240, 240),
	BorderWidth = 1,
	BorderColor = RGB(128, 128, 128),
	FocusedBorderColor = RGB(128, 128, 128),
	
	popup_parent = false,
}

function XPopup:GetSafeAreaBox()
	return GetSafeAreaBox()
end

function XPopup:GetCustomAnchor(x, y, width, height, anchor)
	return anchor:minx(), anchor:miny(), width, height
end

function XPopup:UpdateLayout()
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local anchor = self:GetAnchor()
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	local x, y = self.box:minxyz()
	local width, height = self.measure_width - margins_x1 - margins_x2, self.measure_height - margins_y1 - margins_y2
	local a_type = self.AnchorType
	if a_type == "smart" then
		local space = anchor:minx() - safe_area_x1 - width - margins_x2
		a_type = "left"
		if space < safe_area_x2 - anchor:maxx() - width - margins_x1 then
			space = safe_area_x2 - anchor:maxx() - width - margins_x1
			a_type = "right"
		end
		if space < anchor:miny() - safe_area_y1 - height - margins_y2 then
			space = anchor:miny() - safe_area_y1 - height - margins_y2
			a_type = "top"
		end
		if space < safe_area_y2 - anchor:maxy() - height - margins_y1 then
			space = safe_area_y2 - anchor:maxy() - height - margins_y1
			a_type = "bottom"
		end
	end
	if a_type == "live-mouse" then
		local pos = terminal.GetMousePos()
		anchor = sizebox(pos, UIL.MeasureImage(GetMouseCursor()))
		a_type = "bottom"
	end
	if a_type == "mouse" then
		x, y = anchor:x(), anchor:y()
	elseif a_type == "left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny() - margins_y1
	elseif a_type == "right" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny() - margins_y1
	elseif a_type == "top" then
		x = anchor:minx() - margins_x1
		y = anchor:miny() - height - margins_y2
	elseif a_type == "bottom" then
		x = anchor:minx() - margins_x1
		y = anchor:maxy() + margins_y2
	end
	if a_type == "center-top" then
		x = anchor:minx() + ((anchor:maxx() - anchor:minx())  -  width)/2
		y = anchor:miny() - height - margins_y2
	end
	if a_type == "center-bottom" then
		x = anchor:minx() + ((anchor:maxx() - anchor:minx())  -  width)/2
		y = anchor:maxy() + margins_y2
	end
	if a_type == "bottom-right" then
		x = anchor:maxx() + margins_x1
		y = anchor:maxy() - height - margins_y2
	end	
	if a_type == "bottom-left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:maxy() - height - margins_y2
	end	
	if a_type == "right-center" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny() + ((anchor:maxy() - anchor:miny())  -  height)/2
	end
	if a_type == "left-center" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny() + ((anchor:maxy() - anchor:miny())  -  height)/2
	end
	if a_type == "top-right" then
		x = anchor:maxx() + margins_x1
		y = anchor:miny()- margins_y1
	end
	if a_type == "top-left" then
		x = anchor:minx() - width - margins_x2
		y = anchor:miny()- margins_y1
	end
	if a_type == "drop" then
		x, y = anchor:minx(), anchor:maxy()
		width = Max(anchor:sizex(), width)
	end
	if a_type == "drop-right" then
		x, y = anchor:minx() + anchor:sizex() - width, anchor:maxy()
		width = Max(anchor:sizex(), width)
	end
	if a_type == "custom" then
		x, y, width, height = self:GetCustomAnchor(x, y, width, height, anchor)
	end
	-- fit window to safe area
	if x + width + margins_x2 > safe_area_x2 then
		x = safe_area_x2 - width - margins_x2
	elseif x < safe_area_x1 then
		x = safe_area_x1
	end
	if y + height + margins_y2 > safe_area_y2 then
		y = safe_area_y2 - height - margins_y2
	elseif y < safe_area_y1 then
		y = safe_area_y1
	end
	-- layout
	self:SetBox(x, y, width, height)
	return XControl.UpdateLayout(self)
end

function XPopup:OnKillFocus(new_focus)
	if self.window_state ~= "open" then 
		XWindow.OnKillFocus(self)
		return
	end
	-- close all popups up to the common parent in the popup chain
	local popup = self
	while IsKindOf(popup, "XPopup") and not (new_focus and popup:IsWithinPopupChain(new_focus)) do
		popup:Close()
		popup = popup.popup_parent
	end
	XWindow.OnKillFocus(self)
end

function XPopup:IsWithinPopupChain(child)
	local popup = child:IsKindOf("XPopup") and child or GetParentOfKind(child, "XPopup")
	while popup do
		if popup == self then return true end
		popup = GetParentOfKind(popup.popup_parent, "XPopup")
	end
end

function XPopup:OnMouseButtonDown(pt, button)
	if button == "L" then
		self:SetFocus()
		return "break"
	end
end


----- XPopupList

DefineClass.XPopupList = {
	__parents = { "XPopup" },
	properties = {
		{ category = "General", id = "MinItems", editor = "number", default = 5, },
		{ category = "General", id = "MaxItems", editor = "number", default = 25, },
		{ category = "General", id = "AutoFocus", editor = "bool", default = true, },
	},
	IdNode = true,
}

function XPopupList:Init()
	XSleekScroll:new({
		Id = "idScroll",
		Target = "idContainer",
		Dock = "right",
		Margins = box(1, 1, 1, 1),
		AutoHide = true,
		MinThumbSize = 30,
	}, self)
	XScrollArea:new({
		Id = "idContainer",
		Dock = "box",
		LayoutMethod = "VList",
		VScroll = "idScroll",
	}, self)
	self.idContainer.EnumFocusChildren = function(this, f)
		for _, win in ipairs(this) do
			local order = win:GetFocusOrder()
			if order then
				f(win, order:xy())
			else
				win:EnumFocusChildren(f)
			end
		end
	end
end

function XPopupList:Open(...)
	if self.AutoFocus then
		self.idContainer:SetFocus()
	end
	XPopup.Open(self, ...)
end

function XPopupList:UpdateLayout()
	local a_type = self.AnchorType
	if a_type ~= "drop" and a_type ~= "drop-right" then
		return XPopup.UpdateLayout(self)
	end

	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local anchor = self.Anchor
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = GetSafeAreaBox()
	local width, height =  Max(anchor:sizex(),self.measure_width - margins_x1 - margins_x2), self.measure_height - margins_y1 - margins_y2
	
	local x, y = anchor:minx(), anchor:maxy()	
	
	if a_type == "drop-right" then
		x = anchor:minx() + anchor:sizex() - width
	end
	
	-- fit window to safe area
	if x + width + margins_x2 > safe_area_x2 then
		x = safe_area_x2 - width - margins_x2
	elseif x < safe_area_x1 then
		x = safe_area_x1
	end
	
	local items = self.idContainer
	local popup_max_y = y + height + margins_y2 
	local space_y = safe_area_y2 - y
	local fail = false
	if (safe_area_y2 - popup_max_y)<0 then
		-- try to reduce items count
		local vspace = self.idContainer.LayoutVSpacing
		y = anchor:maxy()		
		local size = margins_y1 + margins_y2 - vspace
		for i = 1, Min(#items, self.MaxItems) do
			local newsize = size + vspace + items[i].measure_height
			if newsize > space_y then
				fail = i<=self.MinItems 
				break
			end	
			size = newsize
		end
		if not fail then
			height = size
		end
		
		-- try to place over the control
		if fail then
			y = anchor:miny()
			local popup_min_y = y - height - margins_y1 
			local space_y = y - safe_area_y1
			if (popup_min_y - safe_area_y1)<0 then			
				-- try to reduce items count
				fail = false
				size = margins_y1 + margins_y2 + items[1].measure_height
				for i = 2, Min(#items, self.MaxItems) do
					local newsize = size + vspace + items[i].measure_height
					if newsize > space_y then
						fail = i<=self.MinItems
						break
					end	
					size = newsize
				end
				height = size
			end
			y = y - height
		end
	end
	-- layout	
	if fail then
		if y + height + margins_y2 > safe_area_y2 then
			y = safe_area_y2 - height - margins_y2
		elseif y < safe_area_y1 then
			y = safe_area_y1
		end
	end
	self:SetBox(x, y, width, height)
	return XControl.UpdateLayout(self)
end

function XPopupList:Measure(preferred_width, preferred_height)
	local width, height = XPopup.Measure(self, preferred_width, preferred_height)
	local items = self.idContainer
	if #items > self.MaxItems then
		local item_height = (self.MaxItems - 1) * self.idContainer.LayoutVSpacing
		for i = 1, self.MaxItems do
			item_height = item_height + items[i].measure_height
		end
		self.idContainer.MouseWheelStep = items[1].measure_height * 2
		return width, Min(height, item_height)
	end
	return width, height
end

function XPopupList:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" or shortcut == "ButtonB" then
		self:Close()
		return "break"
	end
	local relation = XShortcutToRelation[shortcut]
	if shortcut == "Down" or shortcut == "Up" or relation == "down" or relation == "up" then
		local focus = self.desktop.keyboard_focus
		local order = focus and focus:GetFocusOrder()
		if shortcut == "Down" or relation == "down" then
			focus = self.idContainer:GetRelativeFocus(order or point(0, 0), "next")
		else
			focus = self.idContainer:GetRelativeFocus(order or point(1000000000, 1000000000), "prev")
		end
		if focus then
			self.idContainer:ScrollIntoView(focus)
			focus:SetFocus()
		end
		return "break"
	end
end


----- XPropControl

DefineClass.XPropControl = {
	__parents = { "XContextControl" },
	properties = {
		{ category = "Scroll", id = "BindTo", name = "Bind to property", editor = "text", default = "", },
		
	},
	prop_meta = false,
	value = false,
}

function XPropControl:Init(parent, context)
	self.prop_meta = ResolveValue(context, "prop_meta")
end

function XPropControl:SetBindTo(prop_id, prop_meta)
	self.BindTo = prop_id
	if not prop_meta then
		ForEachObjInContext(self.context, function(obj, self, prop_id)
			prop_meta = prop_meta or IsKindOf(obj, "PropertyObject") and obj:GetPropertyMetadata(prop_id)
		end, self, prop_id)
	end
	self.prop_meta = prop_meta
end

function XPropControl:OnPropUpdate(context, prop_meta, value)
end

function XPropControl:GetPropName()
	local prop_meta = self.prop_meta
	return prop_meta and prop_meta.name or ""
end

function XPropControl:UpdatePropertyNames(prop_meta)
	local name = self:ResolveId("idName")
	if name then
		name:SetText(prop_meta.name or prop_meta.id)
	end
	if prop_meta.help and editor ~= "help" then
		self:SetRolloverText(prop_meta.help)
	end
end

function XPropControl:OnContextUpdate(context)
	local prop_id = self.BindTo
	local prop_meta = self.prop_meta
	if context and (prop_id ~= "" or prop_meta) then
		if prop_meta then
			prop_id = prop_meta.id
			self:UpdatePropertyNames(prop_meta)
		end
		local value = ResolveValue(context, prop_id)
		if value ~= rawget(self, "value") then
			self.value = value
			self:OnPropUpdate(context, prop_meta, value)
		end
	end
	XContextControl.OnContextUpdate(self, context)
end


----- XProgress

DefineClass.XProgress = {
	__parents = { "XPropControl" },
	
	properties = {
		{ category = "Progress", id = "Horizontal", name = "Horizontal", editor = "bool", default = true },
		{ category = "Progress", id = "Progress", name = "Progress", editor = "number", default = 0 },
		{ category = "Progress", id = "MaxProgress", name = "Max progress", editor = "number", default = 100, invalidate = "measure", },
		{ category = "Progress", id = "MinProgressSize", name = "Size at progress 0", editor = "number", default = 0 },
		{ category = "Progress", id = "ProgressClip", name = "Clip window", editor = "bool", default = false, invalidate = true, },
	},
}

function XProgress:OnPropUpdate(context, prop_meta, value)
	assert(type(value) == "number")
	if type(value) == "number" then
		if prop_meta then
			local scale = prop_meta.scale
			scale = type(scale) == "string" and const.Scale[scale] or scale or 1
			local min = prop_eval(prop_meta.min, context, prop_meta) or 0
			local max = prop_eval(prop_meta.max, context, prop_meta)
			self:SetMaxProgress(max and (max - min) / scale or self.MaxProgress)
			self:SetProgress((value - min) / scale)
		else
			self:SetProgress(value)
		end
	end
end

function XProgress:SetProgress(value)
	if self.Progress == value then return end
	self.Progress = value
	if self.ProgressClip then
		self:Invalidate()
	else
		self:InvalidateMeasure()
	end
end

function XProgress:MeasureSizeAdjust(max_width, max_height)
	local old_width = max_width

	local docked_x, docked_y = 0, 0
	for _, win in ipairs(self) do
		local dock = win.Dock
		if dock then
			win:UpdateMeasure(max_width, max_height)
			if dock == "left" or dock == "right"  then
				docked_x =  docked_x + win.measure_width
			elseif dock == "top" or dock == "bottom" then
				docked_y = docked_y + win.measure_height
			end
		end
	end
	
	local max = Max(1, self.MaxProgress)
	local progress = self.ProgressClip and max or Clamp(self.Progress, 0, max)
	if self.Horizontal then
		max_width = max_width - docked_x
		local min = ScaleXY(self.scale, self.MinProgressSize)
		max_width = min + (max_width - min) * progress / max
		max_width = max_width + docked_x
	else
		max_height = max_height - docked_y
		local _, min = ScaleXY(self.scale, 0, self.MinProgressSize)
		max_height = min + (max_height - min) * progress / max
		max_height = max_height + docked_y
	end
	
	return max_width, max_height
end

----- XAspectWindow

DefineClass.XAspectWindow = {
	__parents = { "XWindow" },
	properties = {
		{ category = "General", id = "Aspect", name = "Aspect", editor = "combo", default = point(16, 9), items = {
			{ name = "21:9 movie (64:27)", value = point(64, 27)}, 
			{ name = "2:1 Univisium", value = point(2, 1)}, 
			{ name = "16:9 HD", value = point(16, 9)}, 
			{ name = "5:3", value = point(5, 3)}, 
			{ name = "1.618:1 golden ratio", value = point(1618, 1000)}, 
			{ name = "3:2 35mm film", value = point(3, 2)}, 
			{ name = "4:3 legacy TV/monitor", value = point(4, 3)}, 
			{ name = "1:1", value = point(1, 1)}, 
			{ name = "1:2", value = point(1, 2)}, 
			{ name = "1:3", value = point(1, 3)}, 
			{ name = "1:4", value = point(1, 4)}, 
			{ name = "1:5", value = point(1, 5)}, 
		}},
		{ category = "General", id = "UseAllSpace", name = "Use available space", editor = "bool", default = true, },
		{ category = "General", id = "Fit", name = "Fit", editor = "choice", default = "smallest", items = {"none", "width", "height", "smallest", "largest"}, },
	}
}

local box0 = box(0, 0, 0, 0)
function XAspectWindow:SetLayoutSpace(x, y, width, height)
	local fit = self.Fit
	if fit ~= "none" then
		assert(self.Margins == box0)
		assert(self.Padding == box0)
		local aspect_x, aspect_y = self.Aspect:xy()
		local h_align = self.HAlign
		if fit == "smallest" or fit == "largest" then
			local space_is_wider = width * aspect_y >= height * aspect_x
			fit = space_is_wider == (fit == "largest") and "width" or "height"
		end
		if fit == "width" then
			local h = width * aspect_y / aspect_x
			local v_align = self.VAlign
			if v_align == "top" then
			elseif v_align == "center" or v_align == "stretch" then
				y = y + (height - h) / 2
			elseif v_align == "bottom" then
				y = y + (height - h)
			end
			height = h
		elseif fit == "height" then
			local w = height * aspect_x / aspect_y
			local h_align = self.HAlign
			if h_align == "left" then
			elseif h_align == "center" or h_align == "stretch" then
				x = x + (width - w) / 2
			elseif h_align == "right" then
				x = x + (width - w)
			end
			width = w
		end
		self:SetBox(x, y, width, height)
		return
	end
	XWindow.SetLayoutSpace(self, x, y, width, height)
end

function XAspectWindow:Measure(max_width, max_height)
	local aspect_x, aspect_y = self.Aspect:xy()
	local m_width = Min(max_width, max_height * aspect_x / aspect_y)
	local m_height = Min(max_height, max_width * aspect_y / aspect_x)
	local width, height = XWindow.Measure(self, m_width, m_height)
	local min_width = Max(width, height * aspect_x / aspect_y)
	local min_height = Max(height, width * aspect_y / aspect_x)
	if self.UseAllSpace then
		return Max(min_width, m_width), Max(min_height, m_height)
	end
	return min_width, min_height
end


----- XVirtualContent
--
-- Use to embed in XList; does not spawn the controls from its XTemplate until it is visible,
-- thus making lists with 1000s elements perform decently.

function NewXVirtualContent(parent, context, xtemplate, width, height, refresh_interval, min_width, min_height)
	local obj = {
		MinWidth = min_width or width or 10,
		MaxWidth = width or 1000000,
		MinHeight = min_height or height or 10,
		MaxHeight = height or 1000000,
		desktop = false,
		parent = false,
		children = false,
		window_state = false,
		box = empty_box,
		content_box = empty_box,
		scale = XWindow.scale,
		xtemplate = xtemplate,
		context = context or false,
		measure_update = true,
		layout_update = true,
		outside_parent = true,
		RefreshInterval = refresh_interval,
	}
	return XVirtualContent:new(obj, parent, context)
end

DefineClass.XVirtualContent = {
	__parents = { "XControl" },
	xtemplate = false,
	spawned = false,
	selected = false,
	RefreshInterval = false,
}

local function UpdateContext(win)
	for _, child in ipairs(win) do
		if IsKindOf(child, "XContextWindow") then
			child:OnContextUpdate(child.context)
		end
		UpdateContext(child)
	end
end

function XVirtualContent:SpawnChildren()
	XTemplateSpawn(self.xtemplate, self, self.context)
	if self.RefreshInterval then
		self:CreateThread("UpdateContext", function(self)
			while true do
				Sleep(self.RefreshInterval)
				UpdateContext(self)
			end
		end, self)
	end
end

function XVirtualContent:UpdateMeasure(max_width, max_height)
	-- once measured, don't update measure if the control goes outside the parent (it would be measured wrong without child controls anyway)
	if not self.spawned and (self.measure_width ~= 0 or self.measure_height ~= 0) then
		self.measure_update = false
		return
	end
	XControl.UpdateMeasure(self, max_width, max_height)
end

function XVirtualContent:SetOutsideParent(outside_parent)
	XWindow.SetOutsideParent(self, outside_parent)
	self:SetSpawned(not outside_parent)
end

function XVirtualContent:SetSpawned(spawn)
	if self.spawned == spawn then return end
	if not spawn and self.parent.force_keep_items_spawned then return end
	self.spawned = spawn
	
	self.Invalidate = empty_func
	self:DeleteChildren()
	if spawn then
		self:SpawnChildren()
		for _, win in ipairs(self) do
			win:Open()
		end
		self:UpdateMeasure(self.parent.content_box:size():xy())
		self:UpdateLayout()
	else
		self:DeleteThread("UpdateContext")
	end
	self.Invalidate = nil
	if spawn then
		local scrollarea = GetParentOfKind(self, "XScrollArea")
		if scrollarea then
			scrollarea:InvalidateMeasure()
		end
		self:SetChildSelected()
		Msg("XWindowRecreated", self)
	end
	if self.desktop:GetKeyboardFocus() == self then
		self:SetFocus()
	end
end

function XVirtualContent:SetSelected(selected)
	self.selected = selected
	self:SetChildSelected()
end

function XVirtualContent:SetChildSelected()
	local child = self[1]
	if child then
		child:ResolveRelativeFocusOrder(self.FocusOrder)
		if child:HasMember("SetSelected") then
			child:SetSelected(self.selected)
		end
	end
end

function XVirtualContent:SetFocus()
	XControl.SetFocus(self[1] or self)
end


----- XSizeConstrainedWindow

--XSizeConstrainedWindows are XWindows that will scale down,
--if they would otherwise exceed their maximum space when measuring.
--Note: avoid assigning margins, as they get scaled as well.
DefineClass.XSizeConstrainedWindow = {
	__parents = { "XWindow" },
}

local one = point(1000, 1000)
function XSizeConstrainedWindow:UpdateMeasure(max_width, max_height)
	if not self.measure_update then return end
	
	--Normal measure (allow the content to fit within the max space)
	XWindow.UpdateMeasure(self, max_width, max_height)
	
	--If the window has exceeded any of it's maximum space contraints
	if self.measure_width > max_width or self.measure_height > max_height then
		--Before measuring again, the scale must be cleared
		local scale_x, scale_y = self.scale:xy()
		local scale_ratio = MulDivRound(scale_y, 1000, scale_x)
		self:SetScaleModifier(one)
		XWindow.UpdateMeasure(self, max_width, max_height)
		
		--Figure out which side should be contrained (width or height)
		local space_ratio = MulDivRound(max_height, 1000, max_width)
		local measure_ratio = MulDivRound(self.measure_height, 1000, self.measure_width)
		local width_contrained = measure_ratio < space_ratio
		
		--Determine a new scale, such that the contrained side will be as big as the max space in that dimension
		local content_width, content_height = ScaleXY(self.parent.scale, self.measure_width, self.measure_height)
		if width_contrained then
			scale_x = MulDivRound(self.parent.scale:x(), max_width, content_width)
			scale_y = MulDivRound(scale_x, scale_ratio, 1000)
		else
			scale_y = MulDivRound(self.parent.scale:y(), max_height, content_height)
			scale_x = MulDivRound(scale_y, 1000, scale_ratio)
		end
		
		self:SetScaleModifier(point(scale_x, scale_y))
		XWindow.UpdateMeasure(self, max_width, max_height)
	end
end

function CreateNumberEditor(parent, id, up_pressed, down_pressed, no_buttons)
	local panel = XWindow:new({ Dock = "box" }, parent)
	local button_panel = XWindow:new({
		Id = "idNumberEditor",
		Dock = "right",
	}, panel)
	local function get_button_multiplier()
		if terminal.IsKeyPressed(const.vkControl) then
			return 10
		elseif terminal.IsKeyPressed(const.vkShift) then
			return 100
		else
			return 1
		end
	end
	local button_rollover_text = "Use LMB, Ctrl+LMB, or Shift+LMB to change the value."
	local top_btn = not no_buttons and XTextButton:new({
		Dock = "top",
		OnPress = function(button) up_pressed(get_button_multiplier()) end,
		Padding = box(1, 2, 1, 1),
		Icon = "CommonAssets/UI/arrowup-40.tga",
		IconScale = point(500, 500),
		IconColor = RGB(0, 0, 0),
		FoldWhenHidden = true,
		DisabledIconColor = RGBA(0, 0, 0, 128),
		Background = RGBA(0, 0, 0, 0),
		DisabledBackground = RGBA(0, 0, 0, 0),
		RolloverBackground = RGB(204, 232, 255),
		PressedBackground = RGB(121, 189, 241),
		RolloverTemplate = "GedPropRollover",
		RolloverText = button_rollover_text,
		RolloverAnchor = "center-top",
	}, button_panel)
	
	local bottom_btn = not no_buttons and XTextButton:new({
		Dock = "bottom",
		OnPress = function(button) down_pressed(get_button_multiplier()) end,
		Padding = box(1, 1, 1, 2),
		Icon = "CommonAssets/UI/arrowdown-40.tga",
		IconScale = point(500, 500),
		IconColor = RGB(0, 0, 0),
		FoldWhenHidden = true,
		DisabledIconColor = RGBA(0, 0, 0, 128),
		Background = RGBA(0, 0, 0, 0),
		DisabledBackground = RGBA(0, 0, 0, 0),
		RolloverBackground = RGB(204, 232, 255),
		PressedBackground = RGB(121, 189, 241),
		RolloverTemplate = "GedPropRollover",
		RolloverText = button_rollover_text,
		RolloverAnchor = "center-bottom",
	}, button_panel)

	local edit = XNumberEdit:new({
		Id = id,
		Dock = "box",
		OnShortcut = function(control, shortcut, ...)
			if shortcut == "Up" then
				up_pressed(1)
			elseif shortcut == "Down" then
				down_pressed(1)
			elseif shortcut == "Ctrl-Up" then
				up_pressed(10)
			elseif shortcut == "Ctrl-Down" then
				down_pressed(10)
			elseif shortcut == "Ctrl-Left" then
				up_pressed(100)
			elseif shortcut == "Ctrl-Right" then
				down_pressed(100)
			else
				return XNumberEdit.OnShortcut(control, shortcut, ...)
			end
			return "break"
		end,
		top_btn = top_btn or nil,
		bottom_btn = bottom_btn or nil,
		OnMouseWheelForward = function() if terminal.IsKeyPressed(const.vkControl) then   up_pressed(1) return "break" end end,
		OnMouseWheelBack    = function() if terminal.IsKeyPressed(const.vkControl) then down_pressed(1) return "break" end end,
		RolloverTemplate = "GedPropRollover",
		RolloverText = "Use arrow keys, Ctrl+arrows, or Ctrl+MouseWheel to change the value.",
	}, panel)
	
	return edit, top_btn, bottom_btn
end