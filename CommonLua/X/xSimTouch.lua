-- mouse based touch simulation used for testing on pc

if true then return end 

mouseTouch = false

local old_mouseEvent = XDesktop.MouseEvent
function XDesktop:MouseEvent(event, pt, button, time)
	if event == "OnMousePos" then
		if mouseTouch then
			self:TouchEvent("OnTouchMoved", mouseTouch, pt)
			HideMouseCursor()
		else
			ShowMouseCursor()
		end
		return "break"
	elseif event == "OnMouseButtonDown" then
		if button == "L" then
			mouseTouch = AsyncRand()
			return self:TouchEvent("OnTouchBegan", mouseTouch, pt)
		elseif button == "R" then
			self:TouchEvent("OnTouchCancelled", mouseTouch, pt)
			mouseTouch = false
			return "break"
		end
	elseif event == "OnMouseButtonUp" then
		if button == "L" then
			local result = self:TouchEvent("OnTouchEnded", mouseTouch, pt)
			mouseTouch = false
			return result
		elseif button == "R" then
			return "break"
		end
	elseif event == "OnMouseButtonDoubleClick" then
		if button == "L" then
			return XDesktop:OnMouseButtonDown(pt, button)
		elseif button == "R" then
			return "break"
		end
	end
	return old_mouseEvent(self, event, pt, button, time)
end