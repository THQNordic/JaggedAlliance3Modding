DefineClass.CooldownDef = {
	__parents = { "Preset", },
	properties = {
		{ category = "General", id = "DisplayName", name = "Display Name", 
			editor = "text", default = false, translate = true, },
		{ category = "General", id = "TimeScale", name = "Time Scale", 
			editor = "choice", default = "sec", items = function (self) return GetTimeScalesCombo() end, },
		{ category = "General", id = "TimeMin", name = "Default min", help = "Defaut cooldown time.", 
			editor = "number", default = 1000, 
			scale = function(obj) return obj.TimeScale end, },
		{ category = "General", id = "TimeMax", name = "Default max", 
			editor = "number", default = false, 
			scale = function(obj) return obj.TimeScale end, },
		{ category = "General", id = "MaxTime", name = "Max time", help = "The maximum time the cooldown can accumulate to.", 
			editor = "number", default = false, 
			scale = function(obj) return obj.TimeScale end, },
		{ category = "General", id = "ExpireMsg", name = "Send CooldownExpired message", 
			editor = "bool", default = false },
		{ category = "General", id = "OnExpire", name = "OnExpire", 
			editor = "script", default = false, params = "cooldown_obj, cooldown_def" },
	},
	GlobalMap = "CooldownDefs",
	EditorMenubarName = "Cooldowns",
	EditorMenubar = "Editors.Lists",
	EditorIcon = "CommonAssets/UI/Icons/cooldown.png",
}

DefineClass.CooldownObj = {
	__parents = { "InitDone" },
	cooldowns = false,
	cooldowns_thread = false,
}

function CooldownObj:Init()
	self.cooldowns = {}
end

function CooldownObj:Done()
	self.cooldowns = nil
	DeleteThread(self.cooldowns_thread)
	self.cooldowns_thread = nil
end

function CooldownObj:GetCooldown(cooldown_id)
	local cooldowns = self.cooldowns
	local time = cooldowns and cooldowns[cooldown_id]
	if not time or time == true then return time end
	time = time - GameTime()
	if time >= 0 then
		return time
	end
	cooldowns[cooldown_id] = nil
end

function CooldownObj:GetCooldowns()
	for id in pairs(self.cooldowns) do
		self:GetCooldown(id)
	end
	return self.cooldowns
end

function CooldownObj:OnCooldownExpire(cooldown_id)
	local def = CooldownDefs[cooldown_id]
	assert(def)
	if def.ExpireMsg then
		Msg("CooldownExpired", self, cooldown_id, def)
	end
	local OnExpire = def.OnExpire
	if OnExpire then
		return OnExpire(self, def)
	end
end

function CooldownObj:DefaultCooldownTime(cooldown_id, def)
	def = def or CooldownDefs[cooldown_id]
	local min, max = def.TimeMin, def.TimeMax
	if not max or min > max then
		return min
	end
	return InteractionRandRange(min, max, cooldown_id)
end

function CooldownObj:SetCooldown(cooldown_id, time, max)
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	local def = CooldownDefs[cooldown_id]
	assert(def)
	if not def then return end
	time = time or self:DefaultCooldownTime(cooldown_id, def)
	local prev_time = cooldowns[cooldown_id]
	local now = GameTime()
	if time == true then
		cooldowns[cooldown_id] = true
	else
		if max then
			if prev_time == true or prev_time and prev_time - now >= time then
				return
			end
		end
		time = Min(time, def.MaxTime)
		cooldowns[cooldown_id] = now + time
		if def.OnExpire or def.ExpireMsg then
			if IsValidThread(self.cooldowns_thread) then
				Wakeup(self.cooldowns_thread)
			else
				self.cooldowns_thread = CreateGameTimeThread(function(self)
					while self:UpdateCooldowns() do end
				end, self)
			end
		end
	end
	if not prev_time or prev_time ~= true and prev_time - now < 0 then
		Msg("CooldownSet", self, cooldown_id, def)
	end
end

function CooldownObj:ModifyCooldown(cooldown_id, delta_time)
	local cooldowns = self.cooldowns
	if not cooldowns or (delta_time or 0) == 0 then return end
	local def = CooldownDefs[cooldown_id]
	assert(def)
	local time = cooldowns[cooldown_id]
	if not time or time == true then
		return
	end
	local now = GameTime()
	if time - now < 0 then
		assert(not (def.OnExpire or def.ExpireMsg)) -- messages with expiration effects should be removed by now
		cooldowns[cooldown_id] = nil
		return
	end
	cooldowns[cooldown_id] = now + Min(time + delta_time - now, def.MaxTime)
	if delta_time < 0 and (def.OnExpire or def.ExpireMsg) then
		Wakeup(self.cooldowns_thread)
	end
	return true
end

function CooldownObj:ModifyCooldowns(delta_time, filter)
	local cooldowns = self.cooldowns
	if not cooldowns or (delta_time or 0) == 0 then
		return
	end
	if delta_time <= 0 then
		Wakeup(self.cooldowns_thread)
	end
	local now = GameTime()
	for cooldown_id, time in sorted_pairs(cooldowns) do
		if time ~= true and time - now >= 0 or (not filter or filter(cooldown_id, time)) then
			cooldowns[id] = now + Min(time + delta_time - now, def.MaxTime)
		end
	end
end

function CooldownObj:RemoveCooldown(cooldown_id)
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	local def = CooldownDefs[cooldown_id]
	assert(def)
	local time = cooldowns[cooldown_id]
	if time then
		cooldowns[cooldown_id] = nil
		if time == true or time - GameTime() >= 0 then
			self:OnCooldownExpire(cooldown_id)
		end
	end
end

function CooldownObj:RemoveCooldowns(filter)
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	local removed
	local now = GameTime()
	for cooldown_id, time in sorted_pairs(cooldowns) do
		if not filter or filter(cooldown_id) then
			cooldowns[id] = nil
			if time == true or time - now >= 0 then
				removed = removed or {}
				removed[#removed + 1] = id
			end
		end
	end
	for _, id in ipairs(removed) do
		self:OnCooldownExpire(id)
	end
end

function CooldownObj:UpdateCooldowns()
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	local now = GameTime()
	local next_time
	local CooldownDefs = CooldownDefs
	while true do
		local expired, more_expired
		for cooldown_id, time in pairs(cooldowns) do
			if time ~= true then
				local def = CooldownDefs[cooldown_id]
				time = time - now
				if time <= 0 then
					if def.OnExpire or def.ExpireMsg then
						if expired then
							more_expired = true
							if expired > cooldown_id then
								expired = cooldown_id
							end
						else
							expired = cooldown_id
						end
					else
						cooldowns[cooldown_id] = nil
					end
				else
					if def.OnExpire or def.ExpireMsg then
						next_time = Min(next_time, time)
					end
				end
			end	
		end
		if expired then
			cooldowns[expired] = nil
			self:OnCooldownExpire(expired)
		end
		if not more_expired then break end
	end
	if next_time then
		WaitWakeup(next_time)
		return true -- get called again
	end
	self.cooldowns_thread = nil
end

function CooldownObj:GetDynamicData(data)
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	local now = GameTime()
	for cooldown_id, time in pairs(cooldowns) do
		if time ~= true and time - now < 0 then
			cooldowns[cooldown_id] = nil
		end
	end
	data.cooldowns = next(cooldowns) and cooldowns or nil
end

function CooldownObj:SetDynamicData(data)
	local cooldowns = data.cooldowns
	if not cooldowns then
		self.cooldowns = {}
		DeleteThread(self.cooldowns_thread)
		self.cooldowns_thread = nil
		return
	end
	self.cooldowns = cooldowns
	local CooldownDefs = CooldownDefs
	for cooldown_id, time in pairs(cooldowns) do
		local def = CooldownDefs[def]
		if not def then
			cooldowns[cooldown_id] = nil
		elseif time ~= true then
			if def.OnExpire or def.ExpireMsg then
				if IsValidThread(self.cooldowns_thread) then
					Wakeup(self.cooldowns_thread)
				else
					self.cooldowns_thread = CreateGameTimeThread(function(self)
						while self:UpdateCooldowns() do end
					end, self)
				end
				return
			end
		end
	end
	DeleteThread(self.cooldowns_thread)
	self.cooldowns_thread = nil
end

function CooldownObj:CheatClearCooldowns()
	local cooldowns = self.cooldowns
	if not cooldowns then return end
	for cooldown_id in pairs(cooldowns) do
		cooldowns[cooldown_id] = nil
		self:OnCooldownExpire(cooldown_id)
	end
	self.cooldowns_thread = nil
	ObjModified(self)
end
