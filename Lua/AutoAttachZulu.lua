function AutoAttachObject:OnDestroy()
	if self:GetAutoAttachMode("OFF") ~= "" then
		self:SetAutoAttachMode("OFF")
	end
end

function AutoAttachObject:SetState(state, flags, crossfade, speed)
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	
	-- Call original SetState
	if speed == nil and flags == nil and crossfade == nil then
		g_CObjectFuncs.SetState(self, state)
	elseif speed == nil and crossfade == nil then
		g_CObjectFuncs.SetState(self, state, flags)
	elseif crossfade == nil then
		g_CObjectFuncs.SetState(self, state, flags, crossfade)
	else
		g_CObjectFuncs.SetState(self, state, flags, crossfade, speed)
	end
	
	local mode = (state ~= "broken") and self:GetAutoAttachMode() or false
	self:SetAutoAttachMode(mode)
end

function AutoAttachObject:SetAutoAttachMode(value)
	if self.auto_attach_mode ~= value and value == "OFF" and self:IsKindOf("DecorStateFXObject") then
		PlayFX("DecorState", "end", self, self:GetStateText())
	end
	
	local parent = self:GetParent()
	local floatingDummy = GetTopmostParent(self)
	
	if not IsKindOf(floatingDummy, "FloatingDummy") then
		floatingDummy = false
	end
	if floatingDummy then
		self:ForEachAttach("FloatingDummyCollision", RestoreFloatingDummyAttach)
		MapForEach(self:GetPos(), guim * 10, "FloatingDummyCollision", function(o)
			if o.clone_of == self then
				RestoreFloatingDummyAttach(o)
			end
		end)
	end
	
	self.auto_attach_mode = value
	self:DestroyAutoAttaches()
	self:ClearAttachMembers()
	self:AutoAttachObjects()
	
	if floatingDummy then
		AttachObjectToFloatingDummy(self, floatingDummy, parent ~= floatingDummy and parent or nil)
	end
end
