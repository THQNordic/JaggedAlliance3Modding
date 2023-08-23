local function lVoiceContext()
	return function(obj, prop_meta, parent)
		local obj_field = obj["Character"]
		return string.format("voice:%s", obj_field)
	end
end

DefineClass.TalkingHeadLine = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "Character", name = "Character", editor = "combo", default = "<default>", items = GetConversationCharactersCombo, },
		{ id = "Text", editor = "text", default = "", translate = true, context = lVoiceContext() },
	}
}

DefineClass.TalkingHeadNotificationBase = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "Lines", editor = "nested_list", default = false, base_class = "TalkingHeadLine", inclusive = true, auto_expand = true, },
	},
	
	xTemplate = "TalkingHeadUI",
	CustomLogic = false,
	NoSound = false,
	TimeOnScreen = false,
	
	cancelled = false
}

function TalkingHeadNotificationBase:Stop()
	self.cancelled = true
	Msg(self)
	Msg("TalkingHeadEnded", self)
end

DefineClass.TalkingHeadNotification = {
	__parents = {"Preset", "TalkingHeadNotificationBase"},
	GlobalMap = "TalkingHeadNotifications",
	GedEditor = false
}

DefineClass.TalkingHeadContainer = {
	__parents = { "XDialog" },
	ZOrder = 10,
	FocusOnOpen = ""
}

function TalkingHeadContainer:OnDelete()
	for i, th in ipairs(g_TalkingHeadQueue) do
		th:Stop()
	end
end

if FirstLoad then
g_TalkingHeadQueue = {}
g_TalkingHeadThread = false
end

table.insert(BlacklistedDialogClasses, "TalkingHeadContainer")
local function lEnsureTalkingHeadDialog()
	if not GetDialog("TalkingHeadContainer") then
		OpenDialog("TalkingHeadContainer", GetInGameInterface())
	end
end

GameVar("gv_PortraitOverrides", function() return {} end)

function GetTHPortraitForCharacter(characterId)
	if gv_PortraitOverrides and gv_PortraitOverrides[characterId] then
		characterId = gv_PortraitOverrides[characterId]
	end

	local unitTemplate = UnitDataDefs[characterId]
	if not unitTemplate then return "UI/MercsPortraits/unknown" end
	if not unitTemplate.Portrait then return "UI/MercsPortraits/unknown" end
	
	return unitTemplate.Portrait
end

local function lPlayLine(ui, line, obj)
	local unitTemplate = line.Character and (gv_UnitData[line.Character] or UnitDataDefs[line.Character]) or false
	local portraitWindow = ui and ui:ResolveId("idPortrait")
	if portraitWindow then
		portraitWindow:SetImage(GetTHPortraitForCharacter(line.Character))
	end
	
	local name
	local nameIsSystem = false
	if unitTemplate then
		name = unitTemplate.Nick or unitTemplate.Name
	else
		name = T(493254148013, "System")
		nameIsSystem = true
	end

	local nameWindow = ui and ui:ResolveId("idName")
	if nameWindow then
		nameWindow:SetVisible(not not name)
		nameWindow:SetText(name)
	end
	
	local text = ui and ui:ResolveId("idText")
	if text then
		text:SetText(line.Text, unitTemplate, name)
	end
	
	if not obj.DontLog then CombatLog(not nameIsSystem and name or "short", line.Text) end
	
	local voiceFile = GetVoiceFilename(line.Text)
	local duration, handle
	if voiceFile then
		duration = GetSoundDuration(voiceFile)
		if not obj.NoSound then handle = PlaySound(voiceFile, "Voiceover") end
	end
	if not duration then
		duration = obj.TimeOnScreen or ReadDurationFromText(_InternalTranslate(line.Text))
	end
	return duration, handle
end

local function lPlayCustomTalkingHeadUI(obj)
	local suppressAll = obj.SuppressAll
	while g_ActiveBanters and #g_ActiveBanters > 0 and suppressAll do
		Sleep(100)
	end
	
	ObjModified("attached_talking_head")
	
	local ui = obj.CustomLogic
	if not obj.cancelled then
		for i, line in ipairs(obj.Lines) do -- All lines are expected to use the same actor in this case. So UI doesn't need to move.
			if obj.CustomLogic == "FloatingText" then
				ui = false
			else
				ui:SetVisible(true)
			end
		
			local duration, soundHandle = lPlayLine(ui, line, obj)
			if suppressAll and obj.ResetTimePlayed then
				g_LastVRPlayed.playedAtGameTime = GameTime()
			end
			
			if obj.CustomLogic == "FloatingText" then
				ui = ShowBanterFloatingText(line.object, line.Text, duration)
			end
			
			local ok = WaitMsg(obj, duration + 500)
			if ok then -- Cancel message fired
				if soundHandle then SetSoundVolume(soundHandle, -1, 300) end -- Fade out voice
				break -- Stop running lines
			end
		end
	end

	if IsKindOf(ui, "XWindow") and ui.window_state ~= "destroying" then
		ui:delete("thn-over")
	end
end

local function lTalkingHeadPlayLoop(obj)
	if obj.cancelled then return end

	WaitAllPopupNotifications()
	while g_ActiveBanters and #g_ActiveBanters > 0 and obj.SuppressAll do
		Sleep(100)
	end
	ObjModified("attached_talking_head")
	local container = GetDialog("TalkingHeadContainer")
	local ui = obj.UI
	if not ui then
		ui = XTemplateSpawn(obj.xTemplate, container)
		ui.XTemplate = obj.xTemplate
		ui.thn_instance = obj
		ui:Open()
	end
	obj.UI = ui
	
	-- customAnimationUI is only false in synthesized string notifications (PlayTalkingHeadString) 
	-- such as "Combat Started" etc. They use the old talking head logic and animation.
	local customAnimationUI = IsKindOf(ui, "CombatLogAnchorAnimationWindow")
	if customAnimationUI then
		if obj.xTemplate == "TalkingHeadUI" then -- Only this type of notification (Snype Banters, etc) suppress the combat log.
			ui:SuppressCombatLog()
		end
	else
		while ui.window_state ~= "destroying" and ui.box == empty_box do
			WaitNextFrame(1)
		end
	end
	
	local b = ui.box
	local _, slide = ScaleXY(ui.scale, 0, 40)
	local fastFadeTime = ui.FadeInTime / 2
	for i, line in ipairs(obj.Lines) do
		if not line.Text then
			print(obj.id, "line", tostring(i), "has no text.")
			goto continue
		end

		local duration, soundHandle = lPlayLine(ui, line, obj)
		local cancel = false
		
		if not customAnimationUI then
			-- The in-transition is here because we need the UI to be populated with
			-- the data from the first line
			if not ui.visible then
				ui:AddInterpolation{
					id = "slide-in",
					type = const.intRect,
					duration = ui.FadeInTime,
					originalRect = b,
					targetRect = sizebox(b:minx(), b:miny() + slide, b:sizex(), b:sizey()),
				}
				ui:SetVisible(true)
				cancel = WaitMsg(obj, ui.FadeInTime)
			end
			if ui:FindModifier("fade-fast") then
				ui:AddInterpolation{
					id = "fade-fast",
					type = const.intAlpha,
					startValue = 0,
					endValue = 255,
					duration = fastFadeTime,
					autoremove = true
				}
				cancel = WaitMsg(obj, fastFadeTime)
			end
		end
		if not cancel then
			cancel = WaitMsg(obj, duration + 300)
		end
		
		if not customAnimationUI and not cancel then
			-- Transition between lines
			if i ~= #obj.Lines then
				ui:AddInterpolation{
					id = "fade-fast",
					type = const.intAlpha,
					startValue = 255,
					endValue = 0,
					duration = fastFadeTime,
				}
				cancel = WaitMsg(obj, fastFadeTime)
			end
		end
		
		if cancel then
			if soundHandle then SetSoundVolume(soundHandle, -1, 300) end
			break
		end

		::continue::
	end
	
	if customAnimationUI and ui then
		if ui.window_state ~= "destroying" then
			if ui:IsVisible() then
				ui:AnimatedClose()
			else
				ui:delete("thn-over")
			end
		end
	elseif ui then
		assert(true) -- old thn animation used, where?!
		
		ui:AddInterpolation{
			id = "slide-in",
			type = const.intRect,
			duration = ui.FadeOutTime,
			originalRect = b,
			targetRect = sizebox(b:minx(), b:miny() + slide, b:sizex(), b:sizey()),
			flags = const.intfInverse,
			autoremove = true
		}
		ui:SetVisible(false)
		Sleep(ui.FadeOutTime)

		if ui.window_state ~= "destroying" then
			ui:delete("thn-over")
		end
	end
end

local function lPlayTalkingHeadThread(obj)
	if not obj then return end
	
	-- Custom play loop.
	if obj.CustomLogic then
		lPlayCustomTalkingHeadUI(obj)
	else
	-- Generic play loop
		lTalkingHeadPlayLoop(obj)
	end
	
	table.remove_value(g_TalkingHeadQueue, obj)
	if not obj.cancelled then
		Msg("TalkingHeadEnded", obj)
	end

	local nextInQueue = #g_TalkingHeadQueue > 0 and g_TalkingHeadQueue[1]
	if nextInQueue then
		lPlayTalkingHeadThread(nextInQueue)
	end
end

function PlayTalkingHeadString(text, id, templateOverride)
	local synthLine = PlaceObj("TalkingHeadLine")
	synthLine.Character = "<default>"
	synthLine.Text = text

	local synthNotification = PlaceObj("TalkingHeadNotificationBase")
	synthNotification.id = id or "Custom" .. xxhash(_InternalTranslate(text))
	synthNotification.Lines = {
		synthLine
	}
	if templateOverride then
		synthNotification.xTemplate = templateOverride
	end
	PlayTalkingHead(synthNotification)
end

function PlayTalkingHeadById(preset_id)
	PlayTalkingHead(TalkingHeadNotifications[preset_id])
end

function PlayTalkingHead(obj)
	if CheatEnabled("CombatUIHidden") then return end

	lEnsureTalkingHeadDialog()
	if #g_TalkingHeadQueue ~= 0 then
		if not table.find_value(g_TalkingHeadQueue, "id", obj.id) or obj.CustomLogic then 
			-- If a talking head is playing, only one more can be queued (the newest added)
			local currentTHInQueue = g_TalkingHeadQueue[2]
			if currentTHInQueue then
				-- make sure to update the duration of the last played when replacing the one in the queue
				if g_LastVRPlayed and g_LastVRPlayed.duration then
					g_LastVRPlayed.duration = (g_LastVRPlayed.duration or 0) - (currentTHInQueue.duration or 0)
				end
				currentTHInQueue:Stop()
			end
	
			g_TalkingHeadQueue[2] = obj
		end
		
		-- Revive thread if crashed - this shouldn't happen but if it does it will cause the queue to stall.
		if not IsValidThread(g_TalkingHeadThread) then
			g_TalkingHeadThread = CreateRealTimeThread(lPlayTalkingHeadThread, g_TalkingHeadQueue[1])
		end
		return
	end
	table.insert(g_TalkingHeadQueue, obj)
	g_TalkingHeadThread = CreateRealTimeThread(lPlayTalkingHeadThread, obj)
end

function GetCurrentTalkingHead()
	local dlg = GetDialog("TalkingHeadContainer")
	if dlg then
		for i, d in ipairs(dlg) do
			if d.window_state ~= "destroying" then
				return d
			end
		end
	end
	for i, th in ipairs(g_TalkingHeadQueue) do
		if th.CustomLogic and th.CustomLogic ~= "FloatingText" then
			return th.CustomLogic
		end
	end
	return false
end