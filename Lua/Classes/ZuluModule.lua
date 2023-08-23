DefineClass.ZuluModuleDef = {
	__parents = { "ModuleDef" },
}

local function append(pstr, subs, code)
	code = code:gsub("%$%((.-)%)", subs)
	pstr:append(code)
end

function ZuluModuleDef:GenerateGlobalCode(code)
	ModuleDef.GenerateGlobalCode(self, code)
	local subs = {
		class = self.id,
		var = self.id:lower(),
		member_array = self.DefOwnerMember,
		global_map = self.DefGlobalMap,
	}
	assert(subs.class ~= subs.var)
	
	append(code, subs, [[
function $(class)Owner:GetDynamicData(data)
	for i, $(var) in ipairs(self.$(member_array)) do
		if $(var).ShouldSave == nil or $(var):ShouldSave() then
			data.$(member_array) = data.$(member_array) or {}
			data.$(member_array)[#data.$(member_array)+1] = data.$(member_array)[#data.$(member_array)+1] or {}
			data.$(member_array)[#data.$(member_array)].id = $(var).id
			if type($(var).GetDynamicData) == "function" then
				$(var):GetDynamicData(data.$(member_array)[#data.$(member_array)])
			end
		end
	end
end

function $(class)Owner:SetDynamicData(data)
	for i, $(var) in ipairs(data.$(member_array)) do
		local obj = $(global_map)[$(var).id]:new()
		if type(obj.SetDynamicData) == "function" then
			obj:SetDynamicData($(var))
		end
		self:Add$(class)(obj)
	end
end

]])
end