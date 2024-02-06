
----- ResolveByDefId - serialize/unserialize object by position and matching def_id

DefineClass.ResolveByDefId = {
	__parents = { "CObject" }
}

function ResolveByDefId.__serialize(obj)
	assert(IsValid(obj))
	if not IsValid(obj) then
		return
	end
	local pos, def_id = obj:GetPos(), obj:GetDefId()
	return "ResolveByDefId", { pos, def_id }
end

function ResolveByDefId.__unserialize(data)
	local pos, def_id = data[1], data[2]
	local obj = MapGetFirst(pos, 0, "ResolveByDefId", function(obj, def_id)
		return obj:GetDefId() == def_id
	end, def_id)
	assert(obj)
	return obj
end

function ResolveByDefId:GetDefId()
	assert(false)
end


----- ResolveByClassPos - serialize/unserialize object by position and class name

DefineClass.ResolveByClassPos = {
	__parents = { "CObject" }
}

function ResolveByClassPos.__serialize(obj)
	assert(IsValid(obj))
	if not IsValid(obj) then
		return
	end
	return "ResolveByClassPos", { obj:GetPos(), obj.class }
end

function ResolveByClassPos.__unserialize(data)
	local pos, class = data[1], data[2]
	local obj = MapGetFirst(pos, 0, class)
	assert(obj)
	return obj
end


----- ResolveByCopy - serialize/unserialize object by creating a copy of it

DefineClass.ResolveByCopy = {
	__parents = { "PropertyObject" }
}

-- needed for the prefab serialization
function ResolveByCopy.__serialize(obj)
	local data = { obj.class }
	local n = 1
	local prop_eval = prop_eval
	local GetProperty = obj.GetProperty
	for i, prop in ipairs(obj:GetProperties()) do
		if not prop_eval(prop.dont_save, obj, prop) and prop.editor then
			local id = prop.id
			local value = GetProperty(obj, id)
			if not obj:IsDefaultPropertyValue(id, prop, value) then
				data[n + 1] = id
				data[n + 2] = value
				n = n + 2
			end
		end
	end
	return "ResolveByCopy", data
end

function ResolveByCopy.__unserialize(data)
	local class = data[1]
	local classdef = g_Classes[class]
	assert(classdef)
	if not classdef then
		return
	end
	local obj = classdef:new()
	local SetPropFunc = obj.SetProperty
	for i = 2, #data, 2 do
		local id, value = data[i], data[i + 1]
		SetPropFunc(obj, id, value)
	end
	return obj
end