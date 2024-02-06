DefineClass.XHistogram = {
	__parents = {"XWindow"},

	type = "L",
	color = RGB(128, 128, 128),
	Background = RGB(255, 255, 255),
	value = false,
}

function XHistogram:SetValue(v) 
	if self.value ~= v then
		UIL.Invalidate()
	end
	self.value = v
end

function XHistogram:DrawContent()
	if self.value then
		DrawHistogram(self.value, self.content_box, self.color)
	end
end


DefineClass.HistogramPropertyObj = {
	__parents = {"PropertyObject"},

	properties = {
		{id = "lum", editor = "histogram", default = false,},
		{id = "lum_mean", editor = "number", default = 0, read_only = true, scale = 255, },
		{id = "pixels", editor = "number", default = 0, read_only = true, },
		{id = "r", editor = "histogram", default = false,},
		{id = "g", editor = "histogram", default = false,},
		{id = "b", editor = "histogram", default = false,},
	},
	update_thread = false,
	update_interval = 1000,
}

function HistogramPropertyObj:Getlum_mean()
	return self.lum and self.lum.mean or 0
end

function HistogramPropertyObj:Getpixels()
	return self.lum and self.lum.pixels or 0
end

if FirstLoad then
	g_HistogramEnabled = false
end

function GedToggleHistogram()
	ToggleHistogram()
end
function ToggleHistogram()
	if not g_HistogramEnabled then
		g_HistogramEnabled = HistogramPropertyObj:new({})
		g_HistogramEnabled.update_thread = CreateRealTimeThread(function()
			local self = g_HistogramEnabled
			while true do
				if GedObjects[self] then
					self.r, self.g, self.b, self.lum = AsyncBuildHistogram()
					ObjModified(self)
					Sleep(self.update_interval)
				else
					Sleep(2000)
				end
			end
		end)
	end
	GedProperties(g_HistogramEnabled)
end
