local UIL = UIL

DefineClass.XParticle = {
	__parents = { "XControl" },

	properties = {
		{ category = "Particle", id = "ParticleSystem", editor = "text", default = "", help="Particle system asset", },
		{ category = "Particle", id = "ParticleAngle",  editor = "number", default = 0, min = 0, max = 360*60 - 1, slider = true, scale = "deg", invalidate = true, },
		{ category = "Particle", id = "ParticlePosition", editor = "point", default = point(0, 0, 0), help = "Position of the particle system", },
	},
	
	particle_id = -1,
}

function XParticle:SetParticleSystem(particle)
	local old_particle_system = self.ParticleSystem
	if old_particle_system == (particle or "") then return end
	
	if self.particle_id >= 0 then
		UIL.DeleteUIParticles(particle_id)
	end
	
	if particle and particle ~= "" then
		self.particle_id = UIL.PlaceUIParticles(particle)
	end

	self.ParticleSystem = particle or nil
end

function XParticle:Done(parent, context)
	if self.particle_id >= 0 then
		UIL.DeleteUIParticles(self.particle_id)
	end
end

function XParticle:DrawContent()
	if DataLoaded then
		UIL.DrawParticles(self.particle_id, self.ParticlePosition, self.scale:x(), self.scale:y(), self.ParticleAngle)
	end
end
