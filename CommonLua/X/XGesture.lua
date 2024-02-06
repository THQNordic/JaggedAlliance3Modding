if not Platform.switch then return end

DefineClass.XGestureWindow = {
	__parents = { "XWindow" },
	gesture_time = 300,
	tap_dist = 20*20, -- square of the tap max tap offset
	taps = false,
	last_gesture = false,
	swipe_dist = 50,
}

-- recognised gestures

-- tap - fast press and release without moving
-- swipe - fast move to left, right, top or bottom
-- drag - continuous move

-- parallel tap - tap simultaneously with two fingers
-- pinch/rotation/pan - pres two fingers to zoom, rotate and move

function XGestureWindow:Init()
	self.taps = {}
end

function XGestureWindow:TapCount(pos)
	local time = RealTime() - self.gesture_time
	for i = #self.taps, 1, -1 do
		local tap = self.taps[i]
		if tap.time - time < 0 then
			table.remove(self.taps[i])
		else
			if pos:Dist2D2(tap.pos) < self.tap_dist then
				table.remove(self.taps, i)
				return tap.count
			end
		end
	end
	return 0
end

function XGestureWindow:RegisterTap(pos, count)
	self.taps[#self.taps + 1] = { pos = pos, time = RealTime(), count = count }
end

function XGestureWindow:OnTouchBegan(id, pos, touch)
	touch.start_pos = pos
	touch.start_time = RealTime()
	local gesture = self.last_gesture
	if not gesture or gesture.done or #gesture == 2 or RealTime() - gesture.start_time > self.gesture_time then
		-- new gesture
		gesture = { start_time = RealTime(), start_pos = pos, taps = self:TapCount(pos) + 1 }
		self.last_gesture = gesture
		CreateRealTimeThread(function()
			Sleep(self.gesture_time)
			if not gesture.done then
				self:GestureTime(gesture)
			end
		end)
	end
	touch.gesture = gesture
	gesture[#gesture + 1] = touch
	self:GestureTouch(gesture, touch)
	return "break"
end

function XGestureWindow:OnTouchMoved(id, pos, touch)
	local gesture = touch.gesture
	if gesture then
		self:GestureMove(gesture, touch)
	end
	return "break"
end

function XGestureWindow:OnTouchEnded(id, pos, touch)
	local gesture = touch.gesture
	if gesture then
		self:GestureRelease(gesture, touch)
	end
	return "break"
end

function XGestureWindow:OnTouchCancelled(id, pos, touch)
	local gesture = touch.gesture
	if gesture then
		self:GestureRelease(gesture, touch)
	end
	return "break"
end

function XGestureWindow:GestureTouch(gesture, touch)
	if #gesture == 2 then
		if gesture.type == "drag" then
			self:OnDragStop(gesture[1].start_pos, gesture)
			gesture.type = "pinch"
			self:OnPinchStart((gesture[1].start_pos + gesture[2].start_pos) / 2, gesture)
			self:UpdatePinch(gesture)
		end
	end
end

function XGestureWindow:GestureTime(gesture)
	if #gesture == 1 and not gesture.type then
		gesture.type = "drag"
		self:OnDragStart(gesture[1].start_pos, gesture)
	end
end

function XGestureWindow:GestureMove(gesture, touch)
	local tap = touch.start_pos:Dist2D2(touch.pos) < self.tap_dist
	if #gesture == 1 then
		if gesture.type == "drag" then
			self:OnDragMove(touch.pos, gesture)
		elseif not tap and not gesture.type then
			gesture.type = "drag"
			self:OnDragStart(gesture.start_pos, gesture)
		end
	elseif #gesture == 2 and not tap then
		if gesture.type ~= "pinch" then
			gesture.type = "pinch"
			self:OnPinchStart((gesture[1].start_pos + gesture[2].start_pos) / 2, gesture)
		end
		self:UpdatePinch(gesture)
	end
end

function XGestureWindow:GestureRelease(gesture, touch)
	local tap = touch.start_pos:Dist2D2(touch.pos) < self.tap_dist
	gesture.done = true
	if #gesture == 1 then
		if gesture.type == "drag" then
			self:OnDragEnd(touch.pos, gesture)
			return
		end
		assert(RealTime() - gesture.start_time < self.gesture_time and tap)
		self:RegisterTap(touch.pos, gesture.taps)
		self:OnTap(touch.pos, gesture)
	elseif #gesture == 2 then
		if gesture.type == "pinch" then
			self:UpdatePinch(gesture)
			self:OnPinchEnd(gesture)
		end
		if RealTime() - gesture.start_time < self.gesture_time and tap then
			self:OnParallelTap(gesture)
		end
	end
end

function XGestureWindow:UpdatePinch(gesture)
	-- offset
	self:OnPinchMove((gesture[1].pos - gesture[1].start_pos + gesture[2].pos - gesture[2].start_pos) / 2, gesture)
	-- zoom
	gesture.start_dist = gesture.start_dist or (gesture[1].start_pos:Dist2D(gesture[2].start_pos))
	self:OnPinchZoom(gesture[1].pos:Dist2D(gesture[2].pos) * 1000 / gesture.start_dist, gesture)
	-- rotate
	self:OnPinchRotate(CalcAngleBetween2D(
		gesture[1].start_pos - gesture[2].start_pos,
		gesture[1].pos - gesture[2].pos
	), gesture)
end


function XGestureWindow:OnTap(pos, gesture)
	print("tap", pos, gesture.taps)
end

function XGestureWindow:OnDragStart(pos, gesture)
end

function XGestureWindow:OnDragMove(pos, gesture)
	local offset = pos - gesture[1].start_pos
	if gesture.swipe then
		if gesture.swipe == "h" then
			self:OnHSwipeUpdate(offset:x(), gesture)
		end
		if gesture.swipe == "v" then
			self:OnVSwipeUpdate(offset:y(), gesture)
		end
	else
		if abs(offset:x()) > self.swipe_dist then
			gesture.swipe = "h"
			self:OnHSwipeStart(offset:x(), gesture)
		elseif abs(offset:y()) > self.swipe_dist then
			gesture.swipe = "v"
			self:OnVSwipeStart(offset:y(), gesture)
		end
	end
end

function XGestureWindow:OnDragEnd(pos, gesture)
	local offset = pos - gesture[1].start_pos
	if gesture.swipe then
		if gesture.swipe == "h" then
			self:OnHSwipeEnd(offset:x(), gesture, offset:x() * 1000 / (RealTime() - gesture.start_time + 1))
		end
		if gesture.swipe == "v" then
			self:OnVSwipeEnd(offset:y(), gesture, offset:y() * 1000 / (RealTime() - gesture.start_time + 1))
		end
	end
end

function XGestureWindow:OnHSwipeStart(offs, gesture)
end

function XGestureWindow:OnHSwipeUpdate(offs, gesture)
end

function XGestureWindow:OnHSwipeEnd(offs, gesture)
end

function XGestureWindow:OnVSwipeStart(offs, gesture)
end

function XGestureWindow:OnVSwipeUpdate(offs, gesture)
end

function XGestureWindow:OnVSwipeEnd(offs, gesture)
end

function XGestureWindow:OnParallelTap(gesture)
	print("parallel tap", gesture[1].pos)
end

function XGestureWindow:OnPinchStart(gesture)
	print("pinch start")
end

function XGestureWindow:OnPinchMove(offset, gesture)
	print("move", offset)
end

function XGestureWindow:OnPinchZoom(zoom, gesture)
	print("zoom", zoom)
end

function XGestureWindow:OnPinchRotate(angle, gesture)
	print("rotate", angle)
end

function XGestureWindow:OnPinchEnd(gesture)
	print("pinch end")
end

--[[
function OnMsg.DesktopCreated()
	local win = XGestureWindow:new(terminal.desktop)
	win:SetPos(point20)
	win:SetSize(terminal.desktop:GetSize())
end
--]]
