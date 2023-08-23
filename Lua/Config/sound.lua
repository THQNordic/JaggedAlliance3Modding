config.Music = 1
config.Sound = 1
config.Voice = 1

config.SoundGroups = {"Sound", "Music", "Voice", "UI", "Ambience"}
config.SoundOptionGroups = {
	Sound = {"Sound"},
	UI = {"UI"},
	Ambience = {"Ambience"},
	Music = {"Music"},
	Voice = {"Voice"}
}
config.SoundVoiceReduce = {"Ambience", "AmbientLife", "Music"} -- these are preset groups, not options groups - the "Group" property from sound presets, not what you see in the options
config.SoundVoiceReduceVolume = 500
config.SoundVoiceReduceTime = 500

DefaultMusicSilenceDuration = 20*1000

listener = {
	UpdateTime = 16,
	ViewListenMask = 1,
	ViewFollowMask = 1,
	MainView = 0,
	
--[[
                  *  camera
                 /
                /    DistanceFromCamera, 0.0 means at camera, 1.0 means at point CameraTacVerticalOffset above the current camera floor
               /
              ^
              |      CameraTacVerticalOffset, in meters, above the
        ____________ current camera floor
]]

	CameraTacVerticalOffset = "1.0", -- Tactical Camera only, see diagram above
	DistanceFromCamera = "0.8", -- in Tactical Camera, see diagram above
	
	SoundPosZFactor = "1", -- used to modulate the sound position elevation (both for sounds and listener)
	
	Radius = "150", -- defines a radius (meters) around the lestener position, where objects are processed.
	HeightRadiusIncrease = "0", -- change in the listener radius (meters) when the listener is elevated at HighHeight above the terrain.
	LowHeight = "2",
	HighHeight = "20",
	
	PlayThreshold = "8", -- multiplier for the sound's 'loud_distance' value, forming the maximum hearing distance for a sound
	StopHysteresis = "2", -- increase in PlayThreshold when checking if a sound has exited its hearing distance
	LeavingSoundsFadeOutTime = 2500, -- used to fade out the sound volume when stopping a sound outside its hearing distance (ms)
	EnteringSoundsFadeInTime = 0, -- minimum time to fade in an already playing sound entering the listener radius (ms)
	
	DebugVolumeVectorOffset = 3, -- volume vector offset (meters) above ground
	DebugVolumeVectorLength = 5, -- volume vector length (meters) at 100% volume
}

SetupVarTable(listener, "listener.")

config.UseReverb = Platform.developer
config.DopplerFactor = "1"

const.MusicMaxVolume = 480
const.MusicDefaultVolume = 400
const.MasterMaxVolume = 1000
const.MasterDefaultVolume = 1000
const.VoiceMaxVolume = 1200
const.VoiceDefaultVolume = 1000
const.SoundMaxVolume = 1200
const.SoundDefaultVolume = 1000
const.UIMaxVolume = 1200
const.UIDefaultVolume = 1000
const.AmbienceMaxVolume = 1200
const.AmbienceDefaultVolume = 1000
