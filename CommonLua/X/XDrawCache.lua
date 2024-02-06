DefineClass.XDrawCache = {
	__parents = { "XWindow" },
	draw_stream_start = false,
	draw_stream_end = false,
	draw_last_frame = false
}

function XDrawCache:Invalidate()
	self.draw_stream_start = false
	XWindow.Invalidate(self)
end

local UIL = UIL
function XDrawCache:DrawWindow(clip_box)
	local last_frame, sstart, send = UIL.CopyDrawStream(self.draw_last_frame, self.draw_stream_start, self.draw_stream_end)
	self.draw_last_frame = last_frame
	if sstart then -- if the copy was successful, keep the indexes as we will need them the next frame.
		self.draw_stream_start = sstart
		self.draw_stream_end = send
		return
	end
	self.draw_stream_start = UIL.GetDrawStreamOffset()
	XWindow.DrawWindow(self, clip_box)
	self.draw_stream_end = UIL.GetDrawStreamOffset()
end

DefineClass.XDrawCacheDialog = {
	__parents = { "XDialog", "XDrawCache" },
}

DefineClass.XDrawCacheContextWindow = {
	__parents = { "XContextWindow", "XDrawCache" },
}