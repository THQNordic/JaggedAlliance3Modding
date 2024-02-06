local default_curve = PackCurveParams(point(0, 0), point(64000, 0), point(192000, 0), point(255000, 0), 10)

DefineClass.ParticleBehaviorResize = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Resize",
	EditorSubmenu = "Visual",
	
	properties = {
		{ id = "start_size_min", name = "Start size min (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "start_size_max", name = "Start size max (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "mid_size", name = "Middle size min (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "end_size", name = "End size min (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "mid_point", name = "Middle point", editor = "number", scale = 1000, help = "Specify negative number to disable" },
		{ id = "size_curve", name = "Size curve", editor = "packedcurve", display_scale_y = function(obj) return MulDivRound(255, 1000, obj.start_size_max) end, default = default_curve, max_amplitude = 1000, },
		{ id = "distance", name = "End Distance (m)", editor = "number", scale = 1000, help = "When the number is greater than 0, it enables distance-based resize. The values are interpolated based on the distance from the emitter and the borderline specified in this parameter." },
		{ id = "non_square_size", name = "Non-square size", editor = "bool" },
		{ id = "start_size2_min", name = "Start size min (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "start_size2_max", name = "Start size max (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "mid_size2", name = "Middle size min (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "end_size2", name = "End size min (m)", editor = "number", scale = 1000, dynamic = true },
		{ id = "mid_point2", name = "Middle point", editor = "number", scale = 1000, help = "Specify negative number to disable" },
		{ id = "size_curve2", name = "Size curve", editor = "packedcurve", display_scale_y = function(obj) return MulDivRound(255, 1000, obj.start_size2_max) end, default = default_curve, max_amplitude = 1000, },
		{ id = "distance2", name = "End Distance (m)", editor = "number", scale = 1000, help = "When the number is greater than 0, it enables distance-based resize. The values are interpolated based on the distance from the emitter and the borderline specified in this parameter." }
	},
	
	start_size_min = 500,
	start_size_max = 500,
	mid_size = 500,
	end_size = 500,
	mid_point = -1000,
	non_square_size = false,
	start_size2_min = 500,
	start_size2_max = 500,
	mid_size2 = 500,
	end_size2 = 500,
	mid_point2 = -1000,
	distance = -1000,
	distance2 = -1000
}


DefineClass.ParticleBehaviorResizeCurve = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Resize By Curve",
	EditorSubmenu = "Visual",
	
	properties = {
		{ id = "max_size", name = "Max size in graph(m)", editor = "number", scale = 1000, dynamic = true},
		{ id = "resize_type", name = "Resize Type", editor = "choice", items = {"lifetime_percent", "lifetime_absolute", "velocity"}},
		{ id = "max_velocity", editor = "number", scale = 1000, no_edit = function(o) return o.resize_type ~= "velocity" end },
		{ id = "max_time", editor = "number", scale = 1000, no_edit = function(o) return o.resize_type ~= "lifetime_absolute" end },
		{ id = "size_curve", name = function(obj) return obj.non_square_size and "Width curve" or "Size curve" end, editor = "curve4", max = 1000, scale = 1000, },
		{ id = "non_square_size", name = "Non-square size", editor = "bool" },
		{ id = "max_size_2", name = "Max size in graph(m)", editor = "number", scale = 1000, dynamic = true, no_edit = function(obj) return not obj.non_square_size end },
		{ id = "size_curve_2", name = "Height curve", editor = "curve4", max = 1000, scale = 1000, no_edit = function(obj) return not obj.non_square_size end },
	},
	resize_type = "lifetime_percent",
	max_velocity = 2000,
	max_time = 5000,
	max_size = 500,
	max_size_2 = 0,
	size_curve = MakeLine(0, 1000),
	non_square_size = false,
	size_curve_2 = MakeLine(0, 1000),
}

DefineClass.ParticleBehaviorColorize = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Colorize",
	EditorSubmenu = "Visual",

	start_color_min = RGB(0, 0, 0),
	start_color_max = RGB(0, 0, 0),
	mid_color = RGB(0, 0, 0),
	end_color = RGB(0, 0, 0),
	type = "Interpolate to end",
	middle_pos = 500,
}

function ParticleBehaviorColorize:ResolveColor(id, ged)
	local value = self[id]
	if type( value ) == "string" then
		local parsys = GetParentTableOfKind(self, "ParticleSystemPreset")
		local param = parsys:DynamicParams()[value]
		value = param and param.default_value
	end
	if type( value ) ~= "number" then
		value = RGB(255, 255, 255)
	end
	return value
end

ParticleBehaviorColorize.properties = {
	{ id = "start_color_min", name = function(self) return (not self:IsKindOf("ParticleBehaviorColorize") or self.type == "One of four") and "Color 1" or "Start color min" end, editor = "color", dynamic = true },
	{ id = "start_intensity_min", name = "Intensity", editor = "number", read_only = true, scale = 1000, help = "Min start color intensity multiplier", default = 1000, min = 1000, max = 20000, slider = true },
	{ id = "start_color_max", name = function(self) return (not self:IsKindOf("ParticleBehaviorColorize") or self.type == "One of four") and "Color 2" or "Start color max" end, editor = "color", dynamic = true },
	{ id = "start_intensity_max", name = "Intensity", editor = "number", read_only = true, scale = 1000, help = "Max start color intensity multiplier", default = 1000, min = 1000, max = 20000, slider = true },				
	{ id = "mid_color", name = function(self) return (not self:IsKindOf("ParticleBehaviorColorize") or self.type == "One of four") and "Color 3" or "Middle color" end, editor = "color", dynamic = true },
	{ id = "mid_intensity", name = "Intensity", editor = "number", read_only = true, scale = 1000, help = "Mid color intensity multiplier", default = 1000, min = 1000, max = 20000, slider = true },
	{ id = "end_color", name = function(self) return (not self:IsKindOf("ParticleBehaviorColorize") or self.type == "One of four") and "Color 4" or "End color" end, editor = "color", dynamic = true },
	{ id = "end_intensity", name = "Intensity", editor = "number", read_only = true, scale = 1000, help = "End color intensity multiplier", default = 1000, min = 1000, max = 20000, slider = true },
	{ id = "type", name = "Type", editor = "combo", items = { "Start color only", "Start color range", "Interpolate to end", "Interpolate through mid", "One of four", "InterpolateByCurve" }, },
	{ id = "middle_pos", name = "Middle pos", editor = "number", scale = 1000, help = "The middle point in the particle lifetime [0..1]", min = 0, max = 1000, slider = true },
	{ id = "color_curve", name = "Color curve", editor = "curve4", scale = 1000, max = 2000, default = MakeLine(0, 2000), color_args = function(obj)
		return { obj:ResolveColor("start_color_min"), obj:ResolveColor("mid_color"), obj:ResolveColor("end_color")}	
	end},
}

DefineClass.ParticleBehaviorEmissive = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Emissive",
	EditorSubmenu = "Visual",
	
	properties = {
		{ id = "emissive_curve", name = "Emissive Curve", editor = "curve4", max_x = 1000, scale = 1000, max = 1000, },
	},
	emissive_curve = MakeLine(0, 0)
}



DefineClass.ParticleBehaviorDissolve = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Dissolve",
	EditorSubmenu = "Visual",
	
	properties = {
		{ id = "start_alpha_test_min", name = function(self) return self.type == "One of four" and "Alpha test 1" or "Start alpha test min" end, editor = "number", min = 0, max = 100, slider = true, dynamic = true },
		{ id = "start_alpha_test_max", name = function(self) return self.type == "One of four" and "Alpha test 2" or "Start alpha test max" end, editor = "number", min = 0, max = 100, slider = true, dynamic = true },
		{ id = "mid_alpha_test", name = function(self) return self.type == "One of four" and "Alpha test 3" or "Middle alpha test" end, editor = "number", min = 0, max = 100, slider = true, dynamic = true },
		{ id = "end_alpha_test", name = function(self) return self.type == "One of four" and "Alpha test 4" or "End alpha test" end, editor = "number", min = 0, max = 100, slider = true, dynamic = true },
		{ id = "type", name = "Type", editor = "combo", items = { "Start color only", "Interpolate to end", "Interpolate through mid", "One of four" }, },
		{ id = "middle_pos", name = "Middle pos", editor = "number", scale = 1000, help = "The middle point in the particle lifetime [0..1]", min = 0, max = 1000, slider = true },
	},
	
	start_alpha_test_min = 0,
	start_alpha_test_max = 0,
	mid_alpha_test = 0,
	end_alpha_test = 0,
	type = "Interpolate to end",
	middle_pos = 500,
}


DefineClass.ParticleBehaviorFadeInOut = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Fade In/Out",
	EditorSubmenu = "Visual",

	properties = {
		{ id = "fade_curve", name = "Fade out alpha", editor = "curve4", default = MakeLine(1000), max_x = 1000, scale = 1000, max = 1000, },
	},
}

DefineClass.ParticleBehaviorRotate = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Visual: Rotate",
	EditorSubmenu = "Visual",

	properties = {
		{ id = "rpm_curve", name = "RPM", editor = "curve4", scale = 10, max_x = 1000, max = function(obj) return obj.rpm_curve_range.to end, min = function(obj) return obj.rpm_curve_range.from end, },
		{ id = "rpm_curve_range", name = "RPM Range", editor = "range", scale = 10, default = range(-1200, 1200), slider = true, min = -3000, max = 3000, },
	},

	rpm_curve = MakeLine(0, 0),
}

DefineClass.ParticleBehaviorPickFrame = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Texture: Pick frame",
	EditorSubmenu = "Visual",

	properties = {
		{ id = "anim_type", name = "Pick frame by", editor = "combo", items = { "Random", "Cycle", "Ping-Pong", "Fixed Frame" } },
		{ id = "fixed_frame", name = "Fixed frame", dynamic = true, editor = "point", no_edit = function(self) return self.anim_type ~= "Fixed Frame" end, default = point(1, 1) },
	},

	anim_type = "Random",
}

DefineClass.ParticleBehaviorAnimate = {
	__parents = { "ParticleBehavior" },
	
	EditorName = "Texture: Animation",
	EditorSubmenu = "Visual",

	properties = {
		{ id = "anim_type", name = "Pick frame by", editor = "combo", items = { "Random", "Cycle", "Cycle Once", "Ping-Pong" } },
		{ id = "fps", name = "Frames per second", editor = "number" },
		{ id = "sequence_time_remap", name = "Sequence time", editor = "curve4", scale = 1000, max = 1000, default = MakeLine(0, 1000), },
	},

	anim_type = "Random",
	fps = 5,
}
