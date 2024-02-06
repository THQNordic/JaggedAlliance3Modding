if FirstLoad then
	l_player_to_voice = false
	l_voice_received_time = 0
	l_voice_monitor_thread = false
end

function OnMsg.NetGameJoined()
	-- RecordVoice(true)
end

function OnMsg.NetGameLeft()
	-- RecordVoice(false)
end

function OnMsg.NetDisconnect()
	-- RecordVoice(false)
end

function ProcessReceivedVoice(player_id, data, optimal_sample_rate)
	if not data or #data == 0 then
		return
	end
	
	if Platform.xbox then
		Xbox.OnIncomingChatPacket(netGamePlayers[player_id].name, data)
		return
	end

	l_player_to_voice = l_player_to_voice or {}
	
	local voice_handle = l_player_to_voice[player_id]
	local voice_sound_type = const.VoiceChatSoundType
	local voice_forced_rate = const.VoiceChatForcedSampleRate or optimal_sample_rate
	local voice_max_silence = const.VoiceChatMaxSilence
	local voice_fade_time = const.VoiceChatFadeTime
	
	local err, voice_handle = AppendVoice(data, voice_handle, voice_sound_type, voice_forced_rate, voice_max_silence, voice_fade_time)
		
	if err then
		DebugPrint(string.format("Voice stream error: %s\n", err))
		return
	end
	l_player_to_voice[player_id] = voice_handle
	
	l_voice_received_time = RealTime()
	if not IsValidThread(l_voice_monitor_thread) then
		l_voice_monitor_thread = CreateRealTimeThread(function()
			while true do
				local sleep = l_voice_received_time + voice_max_silence - RealTime()
				if sleep <= 0 then
					break
				end
				Sleep(sleep)
			end
			l_player_to_voice = false
		end)
	end

	return voice_handle
end