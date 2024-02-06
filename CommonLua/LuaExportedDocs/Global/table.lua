--- Search an array for a given value
-- Returns the index of the value in the array or nil
-- @cstyle int table.find(table array, string field, auto value)
-- @param array; table to search in
-- @param field; optional parameter, field to search with
-- @param value; value to search for)
-- @return index

function table.find(array, field, value)
--[[
	if not array then return end
	if value == nil then
		value = field
		for i = 1, #array do
			if value == array[i] then return i end
		end
	else
		for i = 1, #array do
			if type(array[i]) ~= "boolean" and value == array[i][field] then return i end
		end
	end
--]]
end

--- Search an array of arrays for a value that starts with the values provided as extra parameters
-- Returns the sub_array and the index of the sub_array in the array or nil
-- @cstyle int table.ifind(table array, ...)
-- @param array; table to search in
-- @param ...; values to search for
-- @return sub_array, index

function table.ifind(array, ...)
--[[
	for i, sub_array in ipairs(array) do
		local found = true
		for j = 1, select("#", ...) do
			if sub_array[j] ~= select(j, ...) then
				found = false
				break
			end
		end
		if found then return sub_array, i end
	end
--]]
end

--- Search an array for the first element that matches a condition
-- Returns the index of the first matching element or nil
-- @param array; table to search in
-- @param predicate; function that return true for matching elements, getting (idx, value, ...) as parameters
-- @cstyle int table.findfirst(table array, function predicate, ...)
function table.findfirst(array, predicate, ...)
end

--- Count the elements into a table
-- See table.find for parameter details
-- As the second parameter, you may provide a predicate function to count key/value pairs that satisfy a condition
-- This function receives parameters (key, value, ...) where ... are all the rest of the table.count parameters
function table.count(array, field_or_fn, value)
end

--- Count the elements in an array
-- See table.find for parameter details
-- As the second parameter, you may provide a predicate function to count key/value pairs that satisfy a condition
-- This function receives parameters (key, value, ...) where ... are all the rest of the table.count parameters
function table.icount(array, field_or_fn, value)
end

--- Sort the elements of a table (acscending) according to a member value (a.field < b.field)
function table.sortby_field(array, field)
end

--- Sort the elements of a table (descending) according to a member value (a.field > b.field)
function table.sortby_field_descending(array, field)
end

--- Sort a table of points / objects (acscending) according to the distаnce to a position
function table.sortby_dist(array, pos)
end

--- Sort a table of points / objects (acscending) according to the 2D distаnce to a position
function table.sortby_dist2D(array, pos)
end

--- Get the closest pos / object from a table of points / objects according to the distаnce to another pos / object
function table.closest(array, pos)
end

--- Get the closest pos / object from a table of points / objects according to the 2D distаnce to a another pos / object
function table.closest2D(array, pos)
end

--- Get the farthest pos / object from a table of points / objects according to the distаnce to another pos / object
function table.farthest(array, pos)
end

--- Get the farthest pos / object from a table of points / objects according to the 2D distаnce to a another pos / object
function table.farthest2D(array, pos)
end

--- Set table[param1][param2]..[paramN-1] = paramN
function table.set(t, param1, param2, ...)
end

--- Returns table[param1][param2]..[paramN]
function table.get(t, key, ...)
end

--- Same as table.get but also supports calling methods
-- examples:
-- table.fget(obj, "GetParam")                            is obj.GetParam
-- table.fget(obj, "GetParam", "()")                      is obj:GetParam()
-- table.fget(obj, "GetParam", "()", param2)              is obj:GetParam()[param2]
-- table.fget(obj, "GetParam", "(",  param2, ")")         is obj:GetParam(param2)
-- table.fget(obj, "GetParam", "(",  param2, ")", param3) is obj:GetParam(param2)[param3]
-- table.fget(obj, "GetParam", "(",  ...)                 is obj:GetParam(...)
function table.fget(t, key, call, ...)
end

function table.clear(t, keep_reserved_memory)
--[[
	if t then
		for member in pairs(t) do
			t[member] = nil
		end
	end
	return t
--]]
end

function table.iclear(t, from)
--[[
	if t then
		from = from or 1
		for i=#t,from,-1 do
			t[i] = nil
		end
	end
	return t
--]]
end

function table.iequal(t1, t2)
--[[
	if #t1 ~= #t2 then
		return
	end
	for i=1,#t1 do
		if t1[i] ~= t2[i] then
			return
		end
	end
	return true
--]]
end

--- Performs a weighted random on the table elements
-- Returns random element, its index and the used seed
-- @cstyle int table.weighted_rand(table tbl, function calc_weight, int seed)
-- @param tbl; table to rand
-- @param calc_weight; weight compute function or member name
-- @param seed; optional random seed parameter. A random value by default.
-- @return tbl[idx], idx, new_seed

function table.weighted_rand(tbl, calc_weight, seed)
--[[
	seed = seed or AsyncRand()
	local accum_weight = 0
	for i=1,#tbl do
		accum_weight = accum_weight + calc_weight(tbl[i])
	end
	if accum_weight == 0 then
		return nil, nil, seed
	end
	local idx = #tbl
	if #tbl > 1 then
		local target_weight
		target_weight, seed = BraidRandom(seed, accum_weight)
		accum_weight = 0
		for i=1,#tbl-1 do
			accum_weight = accum_weight + calc_weight(tbl[i])
			if accum_weight > target_weight then
				idx = i
				break
			end
		end
	end
	return tbl[idx], idx, seed
--]]
end

--- Copy the array part of a table
-- @cstyle table table.icopy(table t, bool deep = true)
function table.icopy(t, deep)
--[[
	local copy = {}
	for i = 1, #t do
		local v = t[i]
		if deep and type(v) == "table" then v = table.icopy(v, deep) end
		copy[i] = v
	end
	return copy
--]]
end

--- Extracts the keys of a table into an array
-- @cstyle table table.keys(table t, bool sorted = false)
function table.keys(t, sorted)
--[[
	local res = {}
	if t and next(t) then
		for k in pairs(t) do
			res[#res+1] = k
		end
		if sorted then
			table.sort(res)
		end
	end
	return res
--]]
end

--- Inverts a table
-- @cstyle table table.invert(table t)
function table.invert(t)
--[[
	local t2 = {}
	for k, v in pairs(t) do
		t2[v] = k
	end
	return t2
--]]
end

--- Compare the values in two tables (deep)
-- @cstyle bool table.equal_values(table t1, table t2)
function table.equal_values(t1, t2)
end

--- Append the key-value pairs from t2 in t1
-- @cstyle void table.append(table t1, table t2, bool forced)
function table.append(t1, t2, forced)
--[[
	for key, value in pairs(t2 or empty_table) do
		if forced or t1[key] == nil then
			t1[key] = value
		end
	end
	return t1
end
--]]
end

--- Overwrites the key-value pairs from t2 in t1
-- @cstyle void table.overwrite(table t1, table t2)
function table.overwrite(t1, t2)
--[[
	for key, value in pairs(t2 or empty_table) do
		t1[key] = value
	end
	return t1
end
--]]
end

--- Set the specified key-value pairs from src in dest
-- @cstyle void table.set_values(table dest, table src, string key1, string key2, ...)
function table.set_values(raw, dest, src, key1, key2, ...)
--[[
	for _, key in ipairs{key1, key2, ...} do
		dest[key] = src[key]
	end
end
--]]
end

--- Set the specified key-value pairs from src in dest using raw access without metamethods
-- @cstyle void table.rawset_values(table dest, table src, string key1, string key2, ...)
function table.rawset_values(dest, src, key1, key2, ...)
--[[
	for _, key in ipairs{key1, key2, ...} do
		rawset(dest, key, rawget(src, key))
	end
end
--]]
end

-- Removes all invalid objects from an array
function table.validate(t)
--[[
	for i = #(t or ""), 1, -1 do
		if not IsValid(t[i]) then
			remove(t, i)
		end
	end
	return t
--]]
end

