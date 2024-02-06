-- this class is used for creating sound dummy objects that only play sounds

DefineClass.SoundDummy = {
	__parents = { "ComponentAttach", "ComponentSound", "FXObject" },
	flags = { efVisible = false, efWalkable = false, efCollision = false, efApplyToGrids = false },
	entity = ""
}

DefineClass.SoundDummyOwner = {
	__parents = { "Object", "ComponentAttach" },
	snd_dummy = false,
}

function SoundDummyOwner:PlayDummySound(id, fade_time)
	if not self.snd_dummy then
		self.snd_dummy = PlaceObject("SoundDummy")
		self:Attach(self.snd_dummy, self:GetSpotBeginIndex("Origin"))
	end
	self.snd_dummy:SetSound(id, 1000, fade_time)
end

function SoundDummyOwner:StopDummySound(fade_time)
	if IsValid(self.snd_dummy) then
		self.snd_dummy:StopSound(fade_time)
	end
end

