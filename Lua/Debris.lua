AppendClass.Debris = {
	__parents = { "GameDynamicSpawnObject" },
}

function Debris:GetDynamicData(data)
	data.opacity = self.opacity
	local fade_time = GameTime() - self.time_fade_away_start
	data.time_fade_away = (fade_time > self.time_fade_away) and 0 or (self.time_fade_away - fade_time)
	data.time_disappear = self.time_disappear
	
	local p = self.spawning_obj
	if p then
		data.parent_handle = p.handle
	end
end

function Debris:SetDynamicData(data)
	self.opacity = data.opacity
	self:StartPhase("FadeAway", data.time_fade_away, data.time_disappear)
	
	local ph = data.parent_handle
	if ph then
		local p = HandleToObject[ph]
		self.spawning_obj = p
		self:SetColorization(p)
	end
end

--[[
--return in case of floating debris
function Debris:ShouldBeVisibileWhileFading()
	return not not GetPassSlab(self)
end
]]

local prev_func = Debris.enum_obj
function Debris.enum_obj(obj, ...)
	if prev_func(obj, ...) and not IsKindOf(obj, "TreeTop") then
		return true
	end
end