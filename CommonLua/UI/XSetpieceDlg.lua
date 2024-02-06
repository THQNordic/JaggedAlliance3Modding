DefineClass.XSetpieceDlg = {
	__parents = { "XDialog" }, 
	ZOrder = 99,
	HandleMouse = true,
	
	skippable = true,
	openedAt = false,
	skipDelay = 250,
	
	setpiece = false,
	setpiece_seed = 0,
	testMode = false,
	triggerUnits = false,
	extra_params = false,
	setpieceInstance = false,
	
	fadeDlg = false,
	lifecycle_thread = false,
	skipping_setpiece = false,
}

function XSetpieceDlg:Init(parent, context)
	self.setpiece     = context and context.setpiece or "MoveTest"
	self.testMode     = context and context.testMode
	self.triggerUnits = context and context.triggerUnits
	self.extra_params = context and context.extra_params or empty_table
	assert(Setpieces[self.setpiece].TakePlayerControl) -- setpieces that don't take control from the player should be run directly via StartSetpiece in a game time thread
	--this is only semi sync when called from entersector rtt..
	NetUpdateHash("SetpieceStateStart")
	ChangeGameState("setpiece_playing", true)
end

function XSetpieceDlg:Open(...)
	XDialog.Open(self, ...)
	self.openedAt = GameTime()
	
	if rawget(self, "idSkipHint") then
		if GetUIStyleGamepad(nil, self) then
			self.idSkipHint:SetText(T(576896503712, "<ButtonB> Skip"))
		else
			self.idSkipHint:SetText(T(696052205292, "<style SkipHint>Escape: Skip</style>")) -- no icon for Esc button
		end
	end
	
	self.lifecycle_thread = CreateGameTimeThread(XSetpieceDlg.Lifecycle, self)
end

DefineClass.XMovieBlackBars = {
	__parents = {"XDialog"},
	top = false,
	bottom = false
}

function XMovieBlackBars:Open()
	XDialog.Open(self)
	self:CreateBlackBarControls()
end

function XMovieBlackBars:CreateBlackBarControls()
	local top = XTemplateSpawn("XWindow", self)
	top:SetDock("top")
	top:SetBackground(RGBA(0, 0, 0, 255))
	top:Open()
	top.scale = point(1000, 1000)
	top.SetOutsideScale = empty_func
	self.top = top
	
	local bottom = XTemplateSpawn("XWindow", self)
	bottom:SetDock("bottom")
	bottom:SetBackground(RGBA(0, 0, 0, 255))
	bottom:Open()
	bottom.scale = point(1000, 1000)
	bottom.SetOutsideScale = empty_func
	self.bottom = bottom
	
	local left = XTemplateSpawn("XWindow", self)
	left:SetDock("left")
	left:SetBackground(RGBA(0, 0, 0, 255))
	left:Open()
	left.scale = point(1000, 1000)
	left.SetOutsideScale = empty_func
	self.left = left
	
	local right = XTemplateSpawn("XWindow", self)
	right:SetDock("right")
	right:SetBackground(RGBA(0, 0, 0, 255))
	right:Open()
	right.scale = point(1000, 1000)
	right.SetOutsideScale = empty_func
	self.right = right
end

function XMovieBlackBars:SetBarsOnSides()
	self.left:SetDock("left")
	self.right:SetDock("right")
	self.top:SetDock(false)
	self.bottom:SetDock(false)
	self.top:SetVisible(false)
	self.bottom:SetVisible(false)
	self.left:SetVisible(true)
	self.right:SetVisible(true)
end

function XMovieBlackBars:SetBarsTopBottom()
	self.left:SetDock(false)
	self.right:SetDock(false)
	self.top:SetDock("top")
	self.bottom:SetDock("bottom")
	self.left:SetVisible(false)
	self.right:SetVisible(false)
	self.top:SetVisible(true)
	self.bottom:SetVisible(true)
end

function XMovieBlackBars:SetLayoutSpace(x, y, width, height)
	local targetRatio = MulDivRound(16, 100, 9) -- 16:9
	local aspectWidth = width
	local aspectHeight = MulDivRound(width, 100, targetRatio)
	if aspectHeight > height then
		-- wider than 16:9 - strips on the sides
		aspectWidth = MulDivRound(height, targetRatio, 100)
		local blackBarWidth = (width - aspectWidth) / 2
		local blackBarWidth = Max(blackBarWidth, 100)
		self.left:SetMinWidth(blackBarWidth)
		self.right:SetMinWidth(blackBarWidth)
		self.left:SetMinHeight(height)
		self.right:SetMinHeight(height)
		self:SetBarsOnSides()
	else
		-- narrower than 16:9 - strips on top/bottom
		aspectWidth = MulDivRound(height, targetRatio, 100)
		aspectHeight = MulDivRound(aspectWidth, 100, targetRatio)
		local blackBarHeight = (height - aspectHeight) / 2
		blackBarHeight = Max(blackBarHeight, 100)
		self.top:SetMinWidth(width)
		self.bottom:SetMinWidth(width)
		self.top:SetMinHeight(blackBarHeight)
		self.bottom:SetMinHeight(blackBarHeight)
		self:SetBarsTopBottom()
	end
	
	return XWindow.SetLayoutSpace(self, x, y, width, height)
end


function OnMsg.Autorun()
	NetSyncEvents.SetPieceDoneWaitingLS = SetPieceDoneWaitingLS
end

function SetPieceDoneWaitingLS()
	Msg("SetPieceDoneWaitingLS")
end

function CloseLoadGameLoadingScreen()
	-- zulu specific code moved to zulu
end

function XSetpieceDlg:Lifecycle()
	CloseLoadGameLoadingScreen()
	
	local setpiece = Setpieces[self.setpiece]
	Msg("SetpieceStarting", setpiece)
	OnSetpieceStarted(setpiece)
	local camera = { GetCamera() }
	
	-- Hide UI, black bars, lock camera
	XTemplateSpawn("XCameraLockLayer", self):Open()
	XHideDialogs:new({Id = "idHideDialogs", LeaveDialogIds = self:HasMember("LeaveDialogsOpen") and self.LeaveDialogsOpen or false}, self):Open()
	local blackbars = XTemplateSpawn("XMovieBlackBars", self)
	blackbars:SetId("BlackBars")
	blackbars:Open()

	if not netInGame or table.count(netGamePlayers) <= 1 then
		WaitLoadingScreenClose()
	else
		if NetIsHost() then
			local dlg = GetLoadingScreenDialog()
			if dlg then
				WaitLoadingScreenClose()
			end
			
			NetSyncEvent("SetPieceDoneWaitingLS")
		end
		WaitMsg("SetPieceDoneWaitingLS", 60000)
	end
	NetUpdateHash("XSetpieceDlg:Lifecycle_Starting")

	-- Interface spawned by the setpiece should be in this child, which is
	-- below the letterboxing window.
	local uiChildren = XTemplateSpawn("XWindow", self)
	uiChildren:SetId("idSetpieceUI")
	uiChildren:Open()
	uiChildren:SetZOrder(0)
	
	self.setpieceInstance = StartSetpiece(self.setpiece, self.testMode, self.setpiece_seed, self.triggerUnits, unpack_params(self.extra_params))
	Msg("SetpieceStarted", setpiece)
	
	self:WaitSetpieceCompletion()
	Msg("SetpieceEnding", setpiece)
	
	local skipHint = rawget(self, "idSkipHint")
	if skipHint then skipHint:Close() end
	
	if setpiece.RestoreCamera then
		SetCamera(unpack_params(camera))
	else
		SetupInitialCamera()
	end

	NetUpdateHash("SetpieceStateDone")
	ChangeGameState("setpiece_playing", false)
	sprocall(EndSetpiece, self.setpiece)
	Msg("SetpieceEnded", setpiece) -- this releases control when executing sequential effects, any sleeps in gametimes after this are prone to never exiting due to game getting paused
	
	-- some deinitialization (e.g. restoring Ambient Life unit positions) is done at SetpieceEnded
	-- wait several frames to make sure nothing from that is seen on screen
	WaitNextFrame(7)
	self:Close() -- must be before EndSetpiece and the Msg, so IsSetpiecePlaying returns false during their execution
end

function XSetpieceDlg:GetFadeWin()
	if not self.fadeDlg then
		local fadeWin = XWindow:new({
			Visible = false,
			Background = RGBA(0, 0, 0, 255),
			AddInterpolation = function(self, int, idx)
				if not int then return end
				int.flags = (int.flags or 0) | const.intfGameTime
				return XWindow.AddInterpolation(self, int, idx)
			end,
		}, self)
		fadeWin:Open()
		self.fadeDlg = fadeWin
	end
	return self.fadeDlg
end

function XSetpieceDlg:FadeOut(fadeOutTime)
	if self.skipping_setpiece then return end -- don't mess up the fade out screen created by the skipping logic
	
	local fade_win = self:GetFadeWin()
	local fade_time = fadeOutTime
	if fade_time > 0 then
		if fade_win:GetVisible() then return end -- game is already faded out, nothing to do
		fade_win.FadeInTime = fade_time
		fade_win:SetVisible(true)
		Sleep(fade_time)
	else
		fade_win:SetVisible(true, "instant")
	end
end

function XSetpieceDlg:FadeIn(fadeInDelay, fadeInTime)
	if self.skipping_setpiece then return end -- don't mess up the fade out screen created by the skipping logic
	
	local fade_win = self:GetFadeWin()
	fade_win.FadeOutTime = fadeInTime
	fade_win:SetVisible(true, "instant")
	Sleep(fadeInDelay or self.fadeOutDelay)
	fade_win:SetVisible(false)
	Sleep(fade_win.FadeOutTime)
end

function XSetpieceDlg:WaitSetpieceCompletion()
	while not self.setpieceInstance do
		WaitMsg("SetpieceStarted", 300)
	end
	self.setpieceInstance:WaitCompletion()
end

function SkipSetpiece(setpieceInstance)
	setpieceInstance:Skip()
end

function XSetpieceDlg:OnShortcut(shortcut, source, ...)
	if GameTime() - self.openedAt < self.skipDelay then return "break" end
	if RealTime() - terminal.activate_time < self.skipDelay then return "break" end
	if rawget(self, "skip_input_done") then return end
	
	if rawget(self, "idSkipHint") and not self.idSkipHint:GetVisible() then
		self.idSkipHint:SetVisible(true)
		return "break"
	end
	if shortcut ~= "Escape" and shortcut ~= "ButtonB" and shortcut ~= "MouseL" then return end
	if self.skippable and self.setpieceInstance and (not IsRecording() or shortcut == "Escape") then
		local skipHint = rawget(self, "idSkipHint")
		if skipHint then 
			skipHint:SetVisible(false)
		end
		rawset(self, "skip_input_done", true)
		SkipSetpiece(self.setpieceInstance)
		return "break"
	end
end

function SkipAnySetpieces()
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		if dlg.setpieceInstance then
			dlg.setpieceInstance:Skip()
			dlg:WaitSetpieceCompletion()
			while GameState.setpiece_playing do
				WaitMsg("SetpieceEnded", 100)
			end
		end
	end
end

function IsSetpiecePlaying()
	return GameState.setpiece_playing
end

function IsSetpieceTestMode()
	local dlg = GetDialog("XSetpieceDlg")
	return dlg and dlg.testMode
end

function WaitPlayingSetpiece()
	local dlg = GetDialog("XSetpieceDlg")
	if dlg then
		dlg:Wait()
	end
end

function OnMsg.SetpieceStarted()
	ObjModified("setpiece_observe")
end

function OnMsg.SetpieceDialogClosed()
	ObjModified("setpiece_observe")
end

function MovieRecordSetpiece(id, duration, quality, shutter)
	quality = quality or 64
	shutter = shutter or 0
	OpenDialog("XSetpieceDlg", false, {setpiece = id }) 
	RecordMovie(id .. ".tga", 0, 60, duration, quality, shutter, function() return not IsSetpiecePlaying() end)
end