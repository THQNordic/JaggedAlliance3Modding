local max_o = 100
local function oname(n)
	return string.format("o%d", n)
end

DefineClass.DevDockPinsButton = {
	__parents = { "XTextButton" },
	IdNode = true,
	ChildrenHandleMouse = true,
	BorderWidth = 1,
	BorderColor = const.clrBlack,
	RolloverBorderColor = const.clrBlack,
	RolloverTemplate = "GedToolbarRollover",
	Translate = false,
	AltPress = true,
	
	plugin = false,
	selected = false,
}

function DevDockPinsButton:Init(parent, context)
	local o_label = XLabel:new({
		Id = "idOLabel",
		HAlign = "right",
		VAlign = "bottom",
		ScaleModifier = point(500, 500),
		Translate = false,
	}, self, self.context)
	function o_label:OnContextUpdate(context, update)
		local main_btn = self.parent
		local idx = main_btn:GetPinIndex(context)
		if idx then
			self:SetVisible(true)
			self:SetText(oname(idx))
		else
			self:SetVisible(false)
		end
	end
	
	local name = self.plugin:GetDisplayName(self.context)
	--find other buttons before me
	local n = 0
	for i,btn in ipairs(self.parent) do
		if btn == self then break end
		if btn.context.class == self.context.class then
			n = n + 1
		end
	end
	if n > 0 then
		name = string.format("%s %d", name, n + 1)
	end
	self:SetText(name)
end

function DevDockPinsButton:OnPress(gamepad)
	SelectObj(self.context)
end

function DevDockPinsButton:OnMouseButtonDoubleClick(button)
	ViewObject(self.context)
	return "break"
end

function DevDockPinsButton:OnAltPress(gamepad)
	self.plugin:SetPinned(self.context, not self:IsPinned())
end

function DevDockPinsButton:OnContextUpdate(context, update)
	if not IsValid(context) or (update ~= "open" and not self.selected and not self:IsPinned()) then
		self:Close()
	end
end

function DevDockPinsButton:HasOLabel()
	return self:ResolveId("idOLabel"):GetVisible()
end

function DevDockPinsButton:GetPinIndex()
	return self.plugin:GetPinIndex(self.context)
end

function DevDockPinsButton:IsPinned()
	return not not self:GetPinIndex()
end

function DevDockPinsButton:SetSelected(selected)
	self.selected = selected
	if not selected and not self:IsPinned() then
		self:Close()
	else
		self:SetHighlighted(selected)
	end
end

function DevDockPinsButton:SetHighlighted(highlighted)
	local color = highlighted and RGB(120,120,255) or const.clrBlack
	self:SetBorderColor(color)
	self:SetRolloverBorderColor(color)
end

----

DefineClass.DevDockPinsPlugin = {
	__parents = { "DevDockPlugin" },
	LayoutMethod = "HList",
	my_pins = false, --list of indices pinned by the dlg
}

function DevDockPinsPlugin.IsValid()
	return GetInGameInterface()
end

function DevDockPinsPlugin:Init()
	self.my_pins = {}
    self:CreateThread("o_thread", self.OThreadProc, self)
end

function DevDockPinsPlugin:OnDelete(result, ...)
	for idx in pairs(self.my_pins) do
		local varname = oname(idx)
		rawset(_G, varname, nil)
	end
end

function DevDockPinsPlugin:GetDisplayName(obj)
	if IsKindOf(obj, "Human") then
		return _InternalTranslate(obj.FirstName)
	else
		return obj.class
	end
end

function DevDockPinsPlugin:GetPinIndex(obj)
	return OPinsGetIndex(obj)
end

function DevDockPinsPlugin:GetNextPinIndex()
	return OPinsGetNextIndex()
end

function DevDockPinsPlugin:SetPinned(obj, pinned)
	local idx = OPinsSet(obj, pinned)
	if pinned then
		self.my_pins[idx] = true
	else
		self.my_pins[idx] = nil
	end
end

function DevDockPinsPlugin:TogglePinned(obj)
	local idx = self:GetPinIndex(obj)
	local is_pinned = not not idx
	self:SetPinned(obj, not is_pinned)
end

function DevDockPinsPlugin:AddButton(obj)
    local btn = self:FindButton(obj)
    if not btn then
        btn = DevDockPinsButton:new({ plugin = self }, self, obj)
		btn:Open()
    end
    return btn
end

function DevDockPinsPlugin:RemoveButton(obj)
	local btn = self:FindButton(obj)
	if btn then
		btn:Close()
	end
end

function DevDockPinsPlugin:FindButton(obj)
    for i,btn in ipairs(self) do
        if btn.context == obj then
            return btn
        end
    end
end

function DevDockPinsPlugin:SelectionAdded(obj)
    local btn = self:FindButton(obj)
    if not btn then
        btn = self:AddButton(obj)
    end
    btn:SetSelected(true)
end

function DevDockPinsPlugin:SelectionRemoved(obj)
    local btn = self:FindButton(obj)
    if not btn then return end
    btn:SetSelected(false)
end

function DevDockPinsPlugin:OThreadProc()
	while self.window_state ~= "destroying" do
		for i,btn in ipairs(self) do
			if btn:HasOLabel() then
				ObjModified(btn.context)
			end
		end
		for idx=1,max_o do
			local obj = rawget(_G, oname(idx))
			if IsValid(obj) then
				self:AddButton(obj)
				ObjModified(obj)
			end
		end
		Sleep(1000)
	end
end

function OPinsGetIndex(obj)
	for idx=1,max_o do
		local value = rawget(_G, oname(idx))
		if value == obj then return idx end
	end
end

function OPinsGetNextIndex()
	for idx=1,max_o do
		local value = rawget(_G, oname(idx))
		if value == nil then return idx end
	end
end

function OPinsSet(obj, pinned)
	local idx = OPinsGetIndex(obj)
	if pinned then
		if not idx then
			idx = OPinsGetNextIndex()
			rawset(_G, oname(idx), obj)
			ObjModified(obj)
		end
	else
		if idx then
			rawset(_G, oname(idx), nil)
			ObjModified(obj)
		end
	end
	
	return idx
end

function OPinsClear()
	for idx=1,max_o do
		rawset(_G, oname(idx), nil)
	end
end

function OnMsg.LoadGame(metadata, version)
	OPinsClear()
end

function OnMsg.NewGame()
	OPinsClear()
end

function OnMsg.SelectionAdded(obj)
	local plugin = GetDevDockPlugin("DevDockPinsPlugin")
	if not plugin then return end
	plugin:SelectionAdded(obj)
end

function OnMsg.SelectionRemoved(obj)
	local plugin = GetDevDockPlugin("DevDockPinsPlugin")
	if not plugin then return end
	plugin:SelectionRemoved(obj)
end
