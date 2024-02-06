if not Platform.developer and not Platform.debug then
	return
end

if FirstLoad then
	PlayingSoundsTextsThread = false
	PlayingSoundsTextsMap = false
	ListenerText = false
end

function OnMsg.ChangeMap()
	DeleteThread(PlayingSoundsTextsThread)
	PlayingSoundsTextsMap = false
end

local function SetRenderStatistics(s)
	if hr.RenderStatistics ~= nil then
		hr.RenderStatistics = s
	end
end

function ToggleSoundDebug()
	local debug = listener and listener.Debug
	if not debug then return end
	listener.Debug = debug < 4 and ((debug + 1) % (listener.MaxDebug + 1)) or 1
	hr.AudioVolumeDebug = listener.Debug ~= 0 
	
	UpdateSoundDebug()
	local info
	if listener.Debug == 0 then
		info = "disabled"
	elseif listener.Debug == 1 then
		info = "listener circle + vector to playing objects"
	elseif listener.Debug == 2 then
		info = " + loud distance circle + volume visualization"
	elseif listener.Debug == 3 then
		info = " + sound texts for all map sound"
	end
	printf("Sound debug %d/%d: %s.", listener.Debug, listener.MaxDebug, info)
end

function UpdateSoundDebug()
	local debug = listener and listener.Debug
	if not debug then
		return
	end
	if debug == 0 then
		SetRenderStatistics(0)
	else
		SetRenderStatistics(1<<8 | 1<<9)
	end
	if GetMap() == "" then
		return
	end
	MapForEach("map", "SoundSource", SoundSource.UpdateMesh)
end

OnMsg.NewMapLoaded = UpdateSoundDebug

function OnMsg.GameExitEditor()
	MapForEach("map", "SoundSource", function(sound) 
		if sound.editor_interrupted then
			sound.editor_interrupted = false
			sound:ReplaySound(sound.FadeTime) 
		end
	end)
end

function ToggleListenerUpdate()
	if not listener then return end
	local disable = listener.DebugDisableUpdate == 0
	listener.DebugDisableUpdate = disable and 1 or 0
	printf("Listener update", disable and "disabled" or "enabled")
end