--- Plays the specified sound. If sound is a file name (without extension) then type must be specified.
-- @cstyle int PlaySound(string sound, [string type,] int volume -1, int fade_time = 0, bool looping = false, point/object source, int loud_distance).
-- @param sound string; either a sound file name or a sound bank.
-- @param type string; sound type. used if sound is a file name. if sound is a sound bank it can be omitted.
-- @param volume int; specifying the volume of the sound between 0 and const.MaxVolume (default is used the sound bank volume).
-- @param fade_time int; the cross-fade time if changing the sound state.
-- @param looping bool; specifies if the sound should be looping. (Use the sound bank flag by default).
-- @param source point/object; specifies the sound source (if any) which can be a point or an object.
-- @param loud_distance int; if playing a file name with source specifies the radius where the sound is at maximum volume.
-- @return handle, err.

function PlaySound(sound, _type, volume, fade_time, looping, point_or_object, loud_distance, time_offset, loop_start, loop_end)
end

--- Stops a sound.
-- @cstyle void StopSound(int handle)
-- @param handle; handle of the sound.
-- @return void.
function StopSound(handle)
end

--- Returns true if a sound is valid and playing.
-- @cstyle bool IsSoundPlaying(int handle)
-- @param handle; handle of the sound.
-- @return bool.
function IsSoundPlaying(handle)
end

--- Returns true if a sound, a sound bank or an object sound is looping.
-- @cstyle bool IsSoundLooping(int handle/object/sound-bank)
-- @param handle; handle of the sound.
-- @return bool.
function IsSoundLooping(handle_obj_bank)
end

--- Returns the duration of a sound handle, sound sample, sound bank or an object sound.
-- @cstyle int GetSoundDuration(int handle/sample/sound-bank/object)
-- @param handle; handle of the sound.
-- @return int.
function GetSoundDuration(handle_sample_obj)
end

--- Changes the volume of a sound.
-- @cstyle void SetSoundVolume(int handle, int volume, int time = 0).
-- @param handle; handle of the sound.
-- @param volume int; volume between -1 and 1000. -1 means destroy.
-- @param time int; interpolation time, 0 by default.
-- @return void.
function SetSoundVolume(handle, volume, time)
end

--- Returns the current volume of a sound handle from 0 to 1000.
-- @cstyle int GetSoundVolume(int handle, int volume, int time = 0).
-- @param handle; handle of the sound.
-- @return int.
function GetSoundVolume(handle)
end

-- XAudio params: https://msdn.microsoft.com/en-us/library/windows/desktop/microsoft.directx_sdk.xaudio2.xaudio2fx_reverb_parameters(v=vs.85).aspx

--- Sets the sound reverberation parameters to be interpolated.
-- Supported parameters:
-- DryLevel: Mix level of dry signal in output in mB.  Ranges from -10000 to 0.  Default is 0. 
-- Room: Room effect level at low frequencies in mB.  Ranges from -10000 to 0.  Default is 0. 
-- RoomHF: Room effect high-frequency level re. low frequency level in mB.  Ranges from -10000 to 0.  Default is 0. 
-- RoomRolloffFactor: Like DS3D flRolloffFactor but for room effect.  Ranges from 0 to 1000. Default is 1000 
-- DecayTime: Reverberation decay time at low-frequencies in milliseconds.  Ranges from 100 to 20000. Default is 1000. 
-- DecayHFRatio : High-frequency to low-frequency decay time ratio.  Ranges from 10 to 200. Default is 50. 
-- ReflectionsLevel : Early reflections level relative to room effect in mB.  Ranges from -10000 to 1000.  Default is -10000. 
-- ReflectionsDelay : Delay time of first reflection in milliseconds.  Ranges from 0 to 300.  Default is 20. 
-- ReverbLevel: Late reverberation level relative to room effect in mB.  Ranges from -10000 to 2000.  Default is 0. 
-- ReverbDelay: Late reverberation delay time relative to first reflection in milliseconds.  Ranges from 0 to 100.  Default is 40. 
-- Diffusion: Reverberation diffusion (echo density) in percent.  Ranges from 0 to 100.  Default is 100. 
-- Density: Reverberation density (modal density) in percent.  Ranges from 0 to 100.  Default is 100. 
-- HFReference: Reference high frequency in Hz.  Ranges from 20 to 20000. Default is 5000. 
-- RoomLF: Room effect low-frequency level in mB.  Ranges from -10000 to 0.  Default is 0. 
-- LFReference: Reference low-frequency in Hz.  Ranges from 20 to 1000. Default is 250. 
-- @cstyle void SetReverbParameters(table params, int time)
-- @param params; A string=int table with the above parameters.
-- @param time; A time over which the parameters will be linearly interpolated from their current values to the ones specified, in ms. 
function SetReverbParameters(params, time)
end

--- Retrieves the sound reverberation parameters valid at the moment
-- @cstyle table GetReverbParameters()
-- @return table; a string=int table with the current reverb params - see SetReverbParameters for a list.
function GetReverbParameters()
end

--- Append PCM samples to a stream, or create a new one if not existing
-- @cstyle string, int AppendStream(int handle, pstr pstr, string sound_type = "", int samples_per_sec = 48000, int bits_per_sample = 16, int channels = 1, int max_silence = 0, int fade_time = 0, int volume = 1000).
-- @param handle int; handle of the sound.
-- @param pstr pstr; PCM samples in pstr format.
-- @param sound_type string; sound type name.
-- @param samples_per_sec int; samples per second (default 48000).
-- @param bits_per_sample int; bits per sample (default 16).
-- @param channels int; channels count (default 1).
-- @param max_silence int; maximum silence time in ms before the sound is auto stoped (default 0, means "keep always alive").
-- @param fade_time int; time in ms to establish the specified volume (default 0).
-- @param volume int; volume between 0 and 1000 (default 1000, means max volume).
-- @return err string, handle int; error and sound handle
function AppendStream(handle, pstr, sound_type, samples_per_sec, bits_per_sample, channels, max_silence, fade_time, volume)
end