----- ModulePreset

DefineClass.ModulePreset = {
	__parents = { "ModifiersPreset", },
	properties = {
		{ category = "Stack Limit", id = "StackLimit", name = "Stack limit", help = "When the Stack limit count is reached, OnStackLimitReached() is called.", 
			editor = "number", default = 0, 
			no_edit = function (self) return not self.HasStackLimit end, min = 0, },
		{ category = "Stack Limit", id = "StackLimitCounter", 
			editor = "expression", default = function (self) return self.id end, 
			no_edit = function(self) return not self.OnStackLimitCounterProp or self.StackLimit == 0 end,
			dont_save = function(self) return not self.OnStackLimitCounterProp or self.StackLimit == 0 end, },
		{ category = "Stack Limit", id = "OnStackLimitReached", 
			editor = "func", params = "self, owner, ...", 
			no_edit = function(self) return not self.OnStackLimitReachedProp or self.StackLimit == 0 end,
			dont_save = function(self) return not self.OnStackLimitReachedProp or self.StackLimit == 0 end, },

		{ category = "Expiration", id = "Expiration", name = "Auto expire", editor = "bool", default = false, 
			no_edit = function(self) return not self.HasExpiration end, dont_save = function(self) return not self.HasExpiration end, },
		{ category = "Expiration", id = "ExpirationTime", name = "Expiration time", editor = "number", default = 480000, scale = "h", min = 0,
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end, },
		{ category = "Expiration", id = "ExpirationRandom", name = "Expiration random", editor = "number", default = 0, scale = "h", min = 0,
			no_edit = function(self) return not self.Expiration end, dont_save = function(self) return not self.Expiration end,
			help = "Expiration time + random(Expiration random)" },
		{ category = "Expiration", id = "OnExpire", editor = "func", params = "self, owner",
			no_edit = function(self) return not self.Expiration or not self.OnExpireProp end, 
			dont_save = function(self) return not self.Expiration or not self.OnExpireProp end, },
	},
	StoreAsTable = true,
	PersistAsReference = true,

	HasStackLimit = false,
	OnStackLimitCounterProp = false,
	OnStackLimitReachedProp = false,

	HasExpiration = false,
	OnExpireProp = false,

	expiration_time = false,
}

function ModulePreset:PostLoad()
	self.__index = self
	ModifiersPreset.PostLoad(self)
end

function ModulePreset:CanAdd(owner, ...)
	return self
end

function ModulePreset:OnAdd(owner, ...)
	self:ApplyModifiers(owner)
end

function ModulePreset:OnRemove(owner, ...)
	self:UnapplyModifiers(owner)
end

function ModulePreset:OnStackLimitReached(owner, ...)
end

function ModulePreset:OnExpire(owner)
end


----- ModuleDef

ModuleDefStackLimits = {
	{ value = -1, text = "Not supported" }, 
	{ value = 0, text = "Editable per instance" },
	{ value = 1, text = "Fixed to 1" }, 
}

DefineClass.ModuleDef = {
	__parents = { "PresetDef" },
	properties = {
		{ category = "Module", id = "DefOwnerMember", name = "Member array in owner", editor = "text", default = "", help = "Where the modules attached to an owner are held."},
		{ category = "Module", id = "DefAlwaysAddInstances", name = "Always add instances",
			editor = "bool", default = false, },
		{ category = "Module", id = "DefStackLimit", name = "Stack limit", editor = "choice", default = -1, 
			items = ModuleDefStackLimits, help = "Is there a limit on the number of modules that can be added to the owner?" },
		{ category = "Module", id = "DefOnStackLimitCounterProp", name = "OnStackLimitCounter() property", editor = "bool", default = false,
			no_edit = function(self) return self.DefStackLimit == -1 end, },
		{ category = "Module", id = "DefOnStackLimitReachedProp", name = "OnStackLimitReached() property", editor = "bool", default = false,
			no_edit = function(self) return self.DefStackLimit == -1 end, },
		{ category = "Module", id = "DefHasExpiration", name = "Has expiration", editor = "bool", default = false },
		{ category = "Module", id = "DefOnExpireProp", name = "OnExpire() property", editor = "bool", default = false,
			no_edit = function(self) return not self.DefHasExpiration end, },
	},
	group = "ModuleDefs",
	DefParentClassList = { "ModulePreset" },
	GlobalMap = "ModuleDefs",
	EditorViewPresetPrefix = "<color 75 105 198>[Module]</color> ",
}

function ModuleDef:GenerateConsts(code)
	PresetDef.GenerateConsts(self, code)
	if self.DefStackLimit == 0 then
		code:append("\tHasStackLimit = true,\n")
	end
	if self.DefStackLimit == 1 then
		code:append("\tStackLimit = 1,\n")
	end
	if self.DefStackLimit ~= -1 and self.DefOnStackLimitCounterProp then
		code:append("\tOnStackLimitCounterProp = true,\n")
	end
	if self.DefStackLimit ~= -1 and self.DefOnStackLimitReachedProp then
		code:append("\tOnStackLimitReachedProp = true,\n")
	end
	if self.DefHasExpiration then
		code:append("\tHasExpiration = true,\n")
		if self.DefOnExpireProp then
			code:append("\tOnExpireProp = true,\n")
		end
	end
end

local function append(pstr, subs, code)
	code = code:gsub("%$%((.-)%)", subs)
	pstr:append(code)
end

function ModuleDef:GetError()
	local id = self.id
	if id == id:lower() then
		return "Id should have at least one capital letter"
	end
	if self.DefOwnerMember == "" then
		return "Member array in owner is required"
	end
	if self.DefOwnerMember == id or self.DefOwnerMember == id:lower() then
		return "Member array should be different than Id and lowercase Id"
	end
end

function ModuleDef:GenerateGlobalCode(code)
	local subs = {
		class = self.id,
		var = self.id:lower(),
		member_array = self.DefOwnerMember,
		global_map = self.DefGlobalMap,
	}
	assert(subs.class ~= subs.var)
	local reactions
	for _, parent in ipairs(self.DefParentClassList) do
		if parent:ends_with("ReactionsPreset") then
			local class = g_Classes[parent]
			if class and (class.ReactionTarget or "") ~= "" and (class.ReactionsMember or "") ~= "" then
				reactions = reactions or {}
				reactions[#reactions + 1] = class.ReactionsMember
			end
		end
	end
	subs.reactions_parent = reactions and ', "ReactionObject"' or ""
	-- owner class definition
	append(code, subs, [[

----- $(class)Owner

DefineClass.$(class)Owner = {
	__parents = { "Modifiable"$(reactions_parent) },
	$(member_array) = false,
	can_remove_$(member_array) = true,
}

local find = table.find
local find_value = table.find_value
local remove_value = table.remove_value
local type = type

]])

	append(code, subs, [[
function $(class)Owner:Add$(class)($(var), ...)
]])
	if self.DefGlobalMap ~= "" then
		append(code, subs, [[
	if type($(var)) == "string" then
		$(var) = $(global_map)[$(var)]
	end
]])
	end
	if self.DefAlwaysAddInstances then
		append(code, subs, [[
	if $(var) and $(var).__index == $(var) then -- $(var) is not an instance
		$(var) = setmetatable({}, $(var)) -- make an instance
	end
]])
	end
	append(code, subs, [[
	$(var) = $(var):CanAdd(self, ...)
	if type($(var)) ~= "table" then return end
	local $(member_array) = self.$(member_array)
	if not $(member_array) then
		$(member_array) = {}
		self.$(member_array) = $(member_array)
	end
	
]])
	
	if self.DefStackLimit == 0 then
		append(code, subs, [[
	local limit = $(var).StackLimit
	if limit > 0 then
		local counter = $(var):StackLimitCounter() or false
		assert(type(counter) ~= "number")
		local count = $(member_array)[counter] or 0
		if limit == 1 then -- for a modal $(class) (StackLimit == 1) keep a reference to the $(class) itself
			if count ~= 0 then
				return $(var):OnStackLimitReached(self, ...)
			end
			$(member_array)[counter] = $(var)
		else
			if count >= limit then
				return $(var):OnStackLimitReached(self, ...)
			end
			$(member_array)[counter] = count + 1
		end
	end
]])
	elseif self.DefStackLimit == 1 then
		append(code, subs, [[
	local counter = $(var):StackLimitCounter() or false
	if $(member_array)[counter] then
		return $(var):OnStackLimitReached(self, ...)
	end
	$(member_array)[counter] = $(var)
]])
	end
	
	if self.DefHasExpiration then
		append(code, subs, [[
	if $(var).Expiration then
		assert(not rawget($(var), "__index")) -- a $(class) with expiration has to be instanced
		$(var).expiration_time = GameTime() + $(var).ExpirationTime + self:Random($(var).ExpirationRandom, "Add$(class)")
	end
]])
	end
	for _, member in ipairs(reactions) do
		subs.reactions_member = member
		append(code, subs, [[
	self:AddReactions($(var), $(var).$(reactions_member))
]])
	end
	append(code, subs, [[
	$(member_array)[#$(member_array) + 1] = $(var)
	PostMsg("$(class)Added", self, $(var))
	return $(var):OnAdd(self, ...)
end

]])
	append(code, subs, [[
function $(class)Owner:Remove$(class)($(var), ...)
	assert(self.can_remove_$(member_array))
]])
	if self.DefGlobalMap ~= "" then
		append(code, subs, [[
	if type($(var)) == "string" then
		$(var) = $(global_map)[$(var)]
	end
]])
	end
	append(code, subs, [[
	local $(member_array) = self.$(member_array)
	local n = remove_value($(member_array), $(var))
	assert(n) -- removing a $(class) that was not added
	if not n then return end

]])
	
	if self.DefStackLimit == 0 then
		append(code, subs, [[
	local limit = $(var).StackLimit
	if limit > 0 then
		local counter = $(var):StackLimitCounter() or false
		local count = $(member_array)[counter] or 1
		if limit == 1 or count == 1 then
			$(member_array)[counter] = nil
		else
			$(member_array)[counter] = count - 1
		end
	end
]])
	elseif self.DefStackLimit == 1 then
		append(code, subs, [[
	local counter = $(var):StackLimitCounter() or false
	$(member_array)[counter] = nil
]])
	end
	if reactions then
		append(code, subs, [[
	self:RemoveReactions($(var))
]])
	end
	append(code, subs, [[
	PostMsg("$(class)Removed", self, $(var))
	return $(var):OnRemove(self, ...)
end

]])

	if self.DefStackLimit == 0 then
		append(code, subs, [[
-- A modal $(class) has StackLimit == 1
function $(class)Owner:GetModal$(class)(counter)
]])
	elseif self.DefStackLimit == 1 then
		append(code, subs, [[
function $(class)Owner:Get$(class)(counter)
]])
	end
	if self.DefStackLimit == 0 or self.DefStackLimit == 1 then
		append(code, subs, [[
	local $(member_array) = self.$(member_array)
	assert(type(counter) ~= "number")
	local $(var) = $(member_array) and $(member_array)[counter or false]
	assert(not $(var) or type($(var)) == "table" and IsKindOf($(var), "$(class)"))
	return $(var)
end

]])
	end
	append(code, subs, [[
function $(class)Owner:ForEach$(class)(func, ...)
	local can_remove = self.can_remove_$(member_array)
	self.can_remove_$(member_array) = false
	local res
	for _, $(var) in ipairs(self.$(member_array)) do
		res = func($(var), ...)
		if res then break end
	end
	if can_remove then
		self.can_remove_$(member_array) = nil
	end
	return res
end

]])

	if self.DefStackLimit ~= -1 then
		append(code, subs, [[
function $(class)Owner:First$(class)ByCounter(counter)
	local $(member_array) = self.$(member_array)
	local $(var) = $(member_array) and $(member_array)[counter or false]
	if type($(var)) == "table" then
		assert($(var):StackLimitCounter() == counter)
		return $(var)
	end
]])
		if self.DefStackLimit == 0 then
			append(code, subs, [[
	for _, $(var) in ipairs($(member_array)) do
		if $(var).StackLimit ~= 1 and $(var):StackLimitCounter() == counter then
			return $(var)
		end
	end
]])
		end
		append(code, subs, [[
end

]])
	end

	if self.DefHasExpiration then
	append(code, subs, [[
function $(class)Owner:Expire$(class)(time)
	time = time or GameTime()
	local $(member_array) = self.$(member_array)
	local expired
	for _, $(var) in ipairs($(member_array)) do
		if ($(var).expiration_time or time) - time < 0 then
			expired = expired or {}
			expired[#expired + 1] = $(var)
		end
	end
	for i, $(var) in ipairs(expired) do
		if i == 1 or find($(member_array), $(var)) then
			if not $(var):OnExpire(self) then
				self:Remove$(class)($(var))
			end
			$(var).expiration_time = nil
		end
	end
end

]])
	end
	
	append(code, subs, [[
function $(class)Owner:First$(class)ById(id)
	return find_value(self.$(member_array), "id", id or false)
end

function $(class)Owner:First$(class)ByGroup(group)
	return find_value(self.$(member_array), "group", group or false)
end

]])
	PresetDef.GenerateGlobalCode(self, code)
end