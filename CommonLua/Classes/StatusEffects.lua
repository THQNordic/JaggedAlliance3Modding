----- Status effects exclusivity

if FirstLoad then
	ExclusiveStatusEffects, RemoveStatusEffects = {}, {}
end

local exclusive_status_effects, remove_status_effects = ExclusiveStatusEffects, RemoveStatusEffects
function BuildStatusEffectExclusivityMaps()
	ExclusiveStatusEffects, RemoveStatusEffects = {}, {}
	exclusive_status_effects, remove_status_effects = ExclusiveStatusEffects, RemoveStatusEffects
	for name, class in pairs(ClassDescendants("StatusEffect")) do
		local exclusive = exclusive_status_effects[name] or {}
		local remove = remove_status_effects[name] or {}
		ForEachPreset(name, function(preset)
			local id1 = preset.id
			for _, id2 in ipairs(preset.Incompatible) do
				exclusive[id1] = table.create_add_set(exclusive[id1], id2)
				exclusive[id2] = table.create_add_set(exclusive[id2], id1)
			end
			for _, id2 in ipairs(preset.RemoveStatusEffects) do
				remove[id1] = table.create_add_set(remove[id1], id2)
				local back_referenced = table.get(remove, id2, id1)
				if back_referenced then
					exclusive[id1] = nil
				else
					exclusive[id2] = table.create_add_set(exclusive[id2], id1)
				end
			end
		end)
		exclusive_status_effects[name] = exclusive
		remove_status_effects[name] = remove
	end
end

OnMsg.ModsReloaded = BuildStatusEffectExclusivityMaps
OnMsg.DataLoaded = BuildStatusEffectExclusivityMaps

----- StatusEffect

DefineClass.StatusEffect = {
	__parents = { "PropertyObject" },
	properties = {
		{ category = "Status Effect", id = "IsCompatible", editor = "expression", params = "self, owner, ..." },
		{ category = "Status Effect", id = "Incompatible", name = "Incompatible", help = "Defines mutually exclusive status effects that cannot coexist. A status effect cannot be added if there are exclusive ones already present. The relationship is symmetric.", 
			editor = "preset_id_list", default = {}, preset_class = function(obj) return obj.class end, item_default = "", },
		{ category = "Status Effect", id = "RemoveStatusEffects", name = "Remove", help = "Status effects to be removed when this one is added. A removed status effect cannot be added later if the current status effect is present, unless they are set to remove each other.", 
			editor = "preset_id_list", default = {}, preset_class = function(obj) return obj.class end, item_default = "", },
		{ category = "Status Effect", id = "ExclusiveResults", name = "Exclusive To",
			editor = "text", default = false, dont_save = true, read_only = true, max_lines = 2, },
		{ category = "Status Effect", id = "OnAdd", editor = "func", params = "self, owner, ..." },
		{ category = "Status Effect", id = "OnRemove", editor = "func", params = "self, owner, ..." },
		{ category = "Status Effect Limit", id = "StackLimit", name = "Stack limit", editor = "number", default = 0, min = 0,
			no_edit = function(self) return not self.HasLimit end, dont_save = function(self) return not self.HasLimit end,
			help = "When the Stack limit count is reached, OnStackLimitReached() is called" },
		{ category = "Status Effect Limit", id = "StackLimitCounter", name = "Stack limit counter", editor = "expression",
			default = function (self, owner) return self.id end,
			no_edit = function(self) return self.StackLimit == 0 end, dont_save = function(self) return self.StackLimit == 0 end,
			help = "Returns the name of the limit counter used to count the StatusEffects. For example different StatusEffects can share the same counter."},
		{ category = "Status Effect Limit", id = "OnStackLimitReached", editor = "func", params = "self, owner, ...",
			no_edit = function(self) return self.StackLimit == 0 end, dont_save = function(self) return self.StackLimit == 0 end, },
		{ category = "Status Effect Expiration", id = "Expiration", name = "Auto expire", editor = "bool", default = false, 
			no_edit = function(self) return not self.HasExpiration end, dont_save = function(self) return not self.HasExpiration end, },
		{ category = "Status Effect Expiration", id = "ExpirationTime", name = "Expiration time", editor = "number", default = 480000, scale = "h", min = 0,
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end, },
		{ category = "Status Effect Expiration", id = "ExpirationRandom", name = "Expiration random", editor = "number", default = 0, scale = "h", min = 0,
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end,
			help = "Expiration time + random(Expiration random)" },
		{ category = "Status Effect Expiration", id = "ExpirationLimits", name = "Expiration Limits (ms)", editor = "range", default = false,
			no_edit = function(self) return not self.Expiration end, dont_save = true, read_only = true },
		{ category = "Status Effect Expiration", id = "OnExpire", editor = "func", params = "self, owner",
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end, },
	},
	StoreAsTable = true,

	HasLimit = true,
	HasExpiration = true,

	Instance = false,
	expiration_time = false,
}

local find = table.find
local find_value = table.find_value
local remove_value = table.remove_value

function StatusEffect:GetExpirationLimits()
	return range(self.ExpirationTime, self.ExpirationTime + self.ExpirationRandom)
end

function StatusEffect:IsCompatible(owner)
	return true
end

function StatusEffect:OnAdd(owner)
end

function StatusEffect:OnRemove(owner)
end

function StatusEffect:OnStackLimitReached(owner, ...)
end

function StatusEffect:OnExpire(owner)
	owner:RemoveStatusEffect(self, "expire")
end

function StatusEffect:RemoveFromOwner(owner, reason)
	owner:RemoveStatusEffect(self, reason)
end

function StatusEffect:PostLoad()
	self.__index = self -- fix for instances in saved games
end

function StatusEffect:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Incompatible" or prop_id == "RemoveStatusEffects" then
		BuildStatusEffectExclusivityMaps()
	end
	return Preset.OnEditorSetProperty(self, prop_id, old_value, ged)
end

function StatusEffect:GetExclusiveResults()
	return table.concat(table.keys(table.get(ExclusiveStatusEffects, self.class, self.id), true), ", ")
end

----- StatusEffectsObject

DefineClass.StatusEffectsObject = {
	__parents = { "Object" },
	status_effects = false,
	status_effects_can_remove = true,
	status_effects_limits = false,
}

local table = table
local empty_table = empty_table

function StatusEffectsObject:AddStatusEffect(effect, ...)
	if not effect:IsCompatible(self, ...) then return end
	local class = effect.class
	for _, id in ipairs(exclusive_status_effects[class][effect.id]) do
		if self:FirstEffectByIdClass(id, class) then
			return
		end
	end
	local limit = effect.StackLimit
	if limit > 0 then
		local status_effects_limits = self.status_effects_limits
		if not status_effects_limits then
			status_effects_limits = {}
			self.status_effects_limits = status_effects_limits
		end
		local counter = effect:StackLimitCounter() or false
		local count = status_effects_limits[counter] or 0
		if limit == 1 then -- for Modal effects (StackLimit == 1) keep a reference to the effect itself in the limits table
			if count ~= 0 then
				return effect:OnStackLimitReached(self, ...)
			end
			status_effects_limits[counter] = effect
		else
			if count >= limit then
				return effect:OnStackLimitReached(self, ...)
			end
			status_effects_limits[counter] = count + 1
		end
	end
	self:RefreshExpiration(effect)
	local status_effects = self.status_effects
	if not status_effects then
		status_effects = {}
		self.status_effects = status_effects
	end
	for _, id in ipairs(remove_status_effects[class][effect.id]) do
		local effect
		repeat
			effect = self:FirstEffectByIdClass(id, class)
			if effect then
				effect:RemoveFromOwner(self, "exclusivity")
			end
		until not effect
	end
	status_effects[#status_effects + 1] = effect
	effect:OnAdd(self, ...)
	return effect
end

function StatusEffectsObject:RefreshExpiration(effect)
	if effect.Expiration then
		assert(effect.Instance) -- effects with expiration have to be instanced
		effect.expiration_time = GameTime() + effect.ExpirationTime + InteractionRand(effect.ExpirationRandom, "status_effect", self)
	end
end

function StatusEffectsObject:RemoveStatusEffect(effect, ...)
	assert(self.status_effects_can_remove)
	local n = remove_value(self.status_effects, effect)
	assert(n) -- removing an effect that is not added
	if not n then return end
	local limit = effect.StackLimit
	if limit > 0 then
		local status_effects_limits = self.status_effects_limits
		local counter = effect:StackLimitCounter() or false
		if status_effects_limits then
			local count = status_effects_limits[counter] or 1
			if limit == 1 or count == 1 then
				status_effects_limits[counter] = nil
			else
				status_effects_limits[counter] = count - 1
			end
		end
	end
	effect:OnRemove(self, ...)
end

-- Modal effects are the ones with StackLimit == 1
function StatusEffectsObject:GetModalStatusEffect(counter)
	local status_effects_limits = self.status_effects_limits
	local effect = status_effects_limits and status_effects_limits[counter or false] or false
	assert(not effect or type(effect) == "table")
	return effect
end

function StatusEffectsObject:FirstEffectByCounter(counter)
	local status_effects_limits = self.status_effects_limits
	local effect = status_effects_limits and status_effects_limits[counter or false] or false
	if not effect then return end
	if type(effect) == "table" then
		assert(effect:StackLimitCounter() == counter)
		return effect
	end
	for _, effect in ipairs(self.status_effects or empty_table) do
		if effect.StackLimit > 1 and effect:StackLimitCounter() == counter then
			return effect
		end
	end
end

function StatusEffectsObject:ExpireStatusEffects(time)
	time = time or GameTime()
	local expired_effects
	local status_effects = self.status_effects or empty_table
	for _, effect in ipairs(status_effects) do
		assert(effect)
		if effect and (effect.expiration_time or time) - time < 0 then
			expired_effects = expired_effects or {}
			expired_effects[#expired_effects + 1] = effect
		end
	end
	if not expired_effects then return end
	for i, effect in ipairs(expired_effects) do
		if i == 1 or find(status_effects, effect) then
			effect:OnExpire(self)
			effect.expiration_time = nil
		end
	end
end

function StatusEffectsObject:FirstEffectById(id)
	return find_value(self.status_effects, "id", id)
end

function StatusEffectsObject:FirstEffectByGroup(group)
	return group and find_value(self.status_effects, "group", group)
end

function StatusEffectsObject:FirstEffectByIdClass(id, class)
	for i, effect in ipairs(self.status_effects) do
		if effect.id == id and IsKindOf(effect, class) then
			return effect, i
		end
	end
end

function StatusEffectsObject:ForEachEffectByClass(class, func, ...)
	local can_remove = self.status_effects_can_remove
	self.status_effects_can_remove = false
	local res
	for _, effect in ipairs(self.status_effects or empty_table) do
		if IsKindOf(effect, class) then
			res = func(effect, ...)
			if res then break end
		end
	end
	if can_remove then
		self.status_effects_can_remove = nil
	end
	return res
end

function StatusEffectsObject:ChooseStatusEffect(none_chance, list, templates)
	if not list or #list == 0 or none_chance > 0 and InteractionRand(100, "status_effect", self) < none_chance then
		return
	end
	local cons = list[1]
	if type(cons) == "string" then
		if #list == 1 then
			if not templates or templates[cons] then
				return cons
			end
		else
			local weight = 0
			for _, cons in ipairs(list) do
				if not templates or templates[cons] then
					weight = weight + 1
				end
			end
			weight = InteractionRand(weight, "status_effect", self)
			for _, cons in ipairs(list) do
				if not templates or templates[cons] then
					weight = weight - 1
					if weight < 0 then
						return cons
					end
				end
			end
		end
	else
		assert(type(cons) == "table")
		if #list == 1 then
			if not templates or templates[cons.effect] then
				return cons.effect
			end
		else
			local weight = 0
			for _, cons in ipairs(list) do
				if not templates or templates[cons.effect] then
					weight = weight + cons.weight
				end
			end
			weight = InteractionRand(weight, "status_effect", self)
			for _, cons in ipairs(list) do
				if not templates or templates[cons.effect] then
					weight = weight - cons.weight
					if weight < 0 then
						return cons.effect
					end
				end
			end
		end
	end
end
