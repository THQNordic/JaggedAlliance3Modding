----- XPauseLayer

DefineClass.XPauseLayer = {
	__parents = { "XLayer" },
	properties = {
		{ category = "General", id = "keep_sounds", name = "Keep Sounds", editor = "bool", default = false },
		{ category = "General", id = "togglePauseDialog", name = "Toggle Pause Dialog", editor = "bool", default = true },
	},
	Dock = "ignore",
	HandleMouse = false,
}

function XPauseLayer:Init()
	CreateRealTimeThread(function(self)
		if self.window_state ~= "destroying" then
			SetPauseLayerPause(true, self, self.keep_sounds)
			if self.togglePauseDialog then
				ShowPauseDialog(true)
			end
			ShowMouseCursor(self)
		end
	end, self)
end

function XPauseLayer:Done()
	SetPauseLayerPause(false, self, self.keep_sounds)
	if self.togglePauseDialog then
		ShowPauseDialog(false)
	end
	HideMouseCursor(self)
end

--override in project specific file
function SetPauseLayerPause(pause, layer, keep_sounds)
	if pause then
		Pause(layer, keep_sounds)
	else
		Resume(layer)
	end
end

function ShowPauseDialog(bShow)
	--implement in project specific file
end

----- XSuppressInputLayer

DefineClass.XSuppressInputLayer = {
	__parents = { "XLayer" },
	properties = {
		{ id = "SuppressTemporarily", editor = "bool", default = true, help = "If true, will suppress any input only for a short time" },
	},
	target = false,
	Dock = "ignore",
	HandleMouse = false,
}

local passthrough_events = {
	OnSystemSize = true,
	OnSystemActivate = true,
	OnSystemInactivate = true,
	OnSystemMinimize = true,
}

function XSuppressInputLayer:Init()
	local function stub_break(target, event)
		if not IsValidThread(SwitchControlQuestionThread) and not passthrough_events[event] then
			return "break"
		end
	end
	self.target = TerminalTarget:new{
		MouseEvent = stub_break,
		KeyboardEvent = stub_break,
		SysEvent = stub_break,
		XEvent = stub_break,
		terminal_target_priority = 10000000,
	}
	terminal.AddTarget(self.target)
end

function XSuppressInputLayer:Open(...)
	XLayer.Open(self, ...)
	if self.SuppressTemporarily then
		self:CreateThread(function()
			Sleep(self:ResolveValue("SuppressTime") or 200)
			self:delete()
		end)
	end
end

function XSuppressInputLayer:Done()
	terminal.RemoveTarget(self.target)
end


DefineClass.XShowMouseCursorLayer = {
	__parents = { "XLayer" },
	Dock = "ignore",
	HandleMouse = false,
}


function XShowMouseCursorLayer:Open(...)
	ShowMouseCursor("XShowMouseCursorLayer")
	return XLayer.Open(self, ...)
end

function XShowMouseCursorLayer:Done()
	HideMouseCursor("XShowMouseCursorLayer")
end

----- XHideInGameInterfaceLayer

DefineClass.XHideInGameInterfaceLayer = { 
	__parents = { "XLayer" },
	Dock = "ignore",
	HandleMouse = false,
}

function XHideInGameInterfaceLayer:Init()
	ShowInGameInterface(false)
end

function XHideInGameInterfaceLayer:Done()
	if GetInGameInterface() then
		ShowInGameInterface(true)
	end
end


----- XCameraLockLayer

DefineClass.XCameraLockLayer = { 
	__parents = { "XLayer" },
	properties = {
		{ category = "General", id = "lock_id", name = "LockId", editor = "text", default = false },
	},
	Dock = "ignore",
	HandleMouse = false,
}

function XCameraLockLayer:Open()
	LockCamera(self.lock_id or self)
	XLayer.Open(self)
end

function XCameraLockLayer:Done()
	UnlockCamera(self.lock_id or self)
end


----- XChangeCameraTypeLayer

local cameraTypes = { "cameraRTS", "cameraFly", "camera3p", "cameraMax", "cameraTac" }

DefineClass.XChangeCameraTypeLayer = {
	__parents = { "XLayer" },
	properties = {
		{ id = "CameraType", editor = "choice", default = "cameraMax", items = cameraTypes },
		{ id = "CameraClampZ",  editor = "number", default = 0,  },
		{ id = "CameraClampXY", editor = "number", default = 0,  },
	},
	Dock = "ignore",
	HandleMouse = false,
	
	old_camera = false,
	old_limits = false,
}

function XChangeCameraTypeLayer:Init()
	self.old_camera = pack_params(GetCamera())
	self.old_limits = {}
	if self.CameraClampZ ~= 0 then
		self.old_limits.CameraMaxClampZ = hr.CameraMaxClampZ
		hr.CameraMaxClampZ = self.CameraClampZ
	end
	if self.CameraClampXY ~= 0 then
		self.old_limits.CameraMaxClampXY = hr.CameraMaxClampXY
		hr.CameraMaxClampXY = self.CameraClampXY
	end
	ForceUnlockCameraStart(self)
	_G[self.CameraType].Activate(1)
end

function XChangeCameraTypeLayer:Done()
	SetCamera(unpack_params(self.old_camera))
	ForceUnlockCameraEnd(self)
	for key, val in pairs(self.old_limits or empty_table) do
		hr[key] = val
	end
end


-- XMuteSounds

DefineClass.XMuteSounds = {
	__parents = { "XLayer" },
	Dock = "ignore",
	HandleMouse = false,
	properties = {
		{ id = "MuteAll", editor = "bool", default = false },
		{ id = "FadeTime", editor = "number", default = 500 },
		{ id = "AudioGroups", editor = "set", default = set(), items = PresetGroupsCombo("SoundTypePreset"), no_edit = PropGetter("MuteAll") },
	},
}

function XMuteSounds:ApplyMute(apply, time)
	local groups = self.MuteAll and PresetGroupNames("SoundTypePreset") or table.keys(self.AudioGroups, true)
	for _, group in ipairs(groups) do
		SetGroupVolumeReason(self, group, apply and 0, self.FadeTime)
	end
end

function XMuteSounds:Open()
	self:ApplyMute(true)
	XLayer.Open(self)
end

function XMuteSounds:Done()
	self:ApplyMute(false)
end


----- XHROption

DefineClass.XHROption = {
	__parents = { "XWindow" },
	Dock = "ignore",
	properties = {
		{ category = "General", id = "Option", editor = "choice", default = "", items = function () return table.keys2(EnumEngineVars("hr."), true, "") end },
		{ category = "General", id = "Value", editor = function(self)
			return type(GetEngineVar("hr.", self.Option or "")) == "number" and "number" or "bool"
		end, default = false, scale = 1000 },
	},
}

function XHROption:Open()
	self:SetVisible(false)
	if self.Option ~= "" then
		if type(GetEngineVar("hr.", self.Option or "")) == "number" then 
			table.change(hr, self, { [self.Option] = (self.Value or 0) / 1000.0 })
		else
			table.change(hr, self, { [self.Option] = self.Value })
		end
	end
	XWindow.Open(self)
end

function XHROption:Done()
	table.restore(hr, self, true)
end