----- OldTerminalTarget

DefineClass.OldTerminalTarget = {
	__parents = { "TerminalTarget" },
}

function OldTerminalTarget:OnMouseButtonDown(pt, button)
	if button == "L" then
		return self:OnLButtonDown(pt)
	elseif button == "R" then
		return self:OnRButtonDown(pt)
	elseif button == "M" then
		return self:OnMButtonDown(pt)
	elseif button == "X1" then
		return self:OnXButton1Down(pt)
	elseif button == "X2" then
		return self:OnXButton2Down(pt)
	end
end

function OldTerminalTarget:OnMouseButtonUp(pt, button)
	if button == "L" then
		return self:OnLButtonUp(pt)
	elseif button == "R" then
		return self:OnRButtonUp(pt)
	elseif button == "M" then
		return self:OnMButtonUp(pt)
	elseif button == "X1" then
		return self:OnXButton1Up(pt)
	elseif button == "X2" then
		return self:OnXButton2Up(pt)
	end
end

function OldTerminalTarget:OnMouseButtonDoubleClick(pt, button)
	if button == "L" then
		return self:OnLButtonDoubleClick(pt)
	elseif button == "R" then
		return self:OnRButtonDoubleClick(pt)
	elseif button == "M" then
		return self:OnMButtonDoubleClick(pt)
	elseif button == "X1" then
		return self:OnXButton1DoubleClick(pt)
	elseif button == "X2" then
		return self:OnXButton2DoubleClick(pt)
	end
end

----- mouse event handlers
local function stub() end
OldTerminalTarget.OnLButtonDown = stub
OldTerminalTarget.OnLButtonUp = stub
OldTerminalTarget.OnLButtonDoubleClick = stub
OldTerminalTarget.OnRButtonDown = stub
OldTerminalTarget.OnRButtonUp = stub
OldTerminalTarget.OnRButtonDoubleClick = stub
OldTerminalTarget.OnMButtonDown = stub
OldTerminalTarget.OnMButtonUp = stub
OldTerminalTarget.OnMButtonDoubleClick = stub
OldTerminalTarget.OnXButton1Down = stub
OldTerminalTarget.OnXButton1Up = stub
OldTerminalTarget.OnXButton1DoubleClick = stub
OldTerminalTarget.OnXButton2Down = stub
OldTerminalTarget.OnXButton2Up = stub
OldTerminalTarget.OnXButton2DoubleClick = stub