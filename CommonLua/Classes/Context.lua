--- An object which can resolve a key to a value.
-- Context objects can be nested to create a complex value resolution structure.
-- The global function ResolveValue allows resolving a tuple to a value in an arbitrary context.

DefineClass.Context = {
	__parents = {},
	__hierarchy_cache = true,	
}

function Context:new(obj)
	return setmetatable(obj or {}, self)
end

function Context:ResolveValue(key)
	local value = rawget(self, key)
	if value ~= nil then return value end
	for _, sub_context in ipairs(self) do
		value = ResolveValue(sub_context, key)
		if value ~= nil then return value end
	end
end

-- change __index method to allow full member resolution without warning
function OnMsg.ClassesBuilt()
	local context_class = g_Classes.Context
	context_class.__index = function (self, key)
		if type(key) == "string" then
			return rawget(context_class, key) or context_class.ResolveValue(self, key)
		end
	end
end

function Context:IsKindOf(class)
	if IsKindOf(self, class) then return true end
	for _, sub_context in ipairs(self) do
		if IsKindOf(sub_context, "Context") and sub_context:IsKindOf(class) or IsKindOf(sub_context, class) then
			return true
		end
	end
end

function Context:IsKindOfClasses(...)
	if IsKindOfClasses(self, ...) then return true end
	for _, sub_context in ipairs(self) do
		if IsKindOf(sub_context, "Context") and sub_context:IsKindOfClasses(...) or IsKindOfClasses(sub_context, ...) then
			return true
		end
	end
end

function ForEachObjInContext(context, f, ...)
	if not context then return end
	if IsKindOf(context, "Context") then
		for _, sub_context in ipairs(context) do
			ForEachObjInContext(sub_context, f, ...)
		end
	else
		f(context, ...)
	end
end

function SubContext(context, t)
	assert(not IsKindOf(t, "PropertyObject"))
	t = t or {}
	if IsKindOf(context, "PropertyObject") or type(context) ~= "table" then
		t[#t + 1] = context
	elseif type(context) == "table" then
		for _, obj in ipairs(context) do
			t[#t + 1] = obj
		end
		for k, v in pairs(context) do
			if rawget(t, k) == nil then
				t[k] = v
			end
		end
	end
	return Context:new(t)
end

function ResolveValue(context, key, ...)
	if key == nil then return context end
	if type(context) == "table" then
		if IsKindOfClasses(context, "Context", "PropertyObject") then
			return ResolveValue(context:ResolveValue(key), ...)
		end
		return ResolveValue(rawget(context, key), ...)
	end
end

function ResolveFunc(context, key)
	if key == nil then return end
	if type(context) == "table" then
		if IsKindOf(context, "Context") then
			local f = rawget(context, key)
			if type(f) == "function" then
				return f
			end
			for _, sub_context in ipairs(context) do
				local f, obj = ResolveFunc(sub_context, key)
				if f ~= nil then return f, obj end
			end
			return
		end
		if IsKindOf(context, "PropertyObject") and context:HasMember(key) then
			local f = context[key]
			if type(f) == "function" then return f, context end
		else
			local f = rawget(context, key)
			if f == false or type(f) == "function" then return f end
		end
	end
end

function ResolvePropObj(context)
	if IsKindOf(context, "PropertyObject") then
		return context
	end
	if IsKindOf(context, "Context") then
		for _, sub_context in ipairs(context) do
			local obj = ResolvePropObj(sub_context)
			if obj then return obj end
		end
	end
end

