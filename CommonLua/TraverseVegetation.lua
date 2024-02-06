DefineClass.TraverseVegetation = {
	__parents = { "CObject" },
}

DefineClass.VegetationTraverseEvent= {
	__parents = { "CObject" },
	
	life_duration = 1000,
}

function VegetationTraverseEvent:SetActors(unit, bushes)
	CreateGameTimeThread(function(self, unit, bushes)
		local pos = self:GetPos()
		PlayFX("Bush", "traverse", self, unit, pos)
		for _, bush in ipairs(bushes) do
			PlayFX("Bush", "traverse", self, bush, pos)
		end
		Sleep(self.life_duration)
		self.life_thread = false
		DoneObject(self)
	end, self, unit, bushes)
end
