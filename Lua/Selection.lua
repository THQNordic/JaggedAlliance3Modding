---- Multiselect wrapper extensions

function ResolveField(array, field)
	--check children classes
	for i,subobj in ipairs(array) do
		--quicky and dirty "has member" check
		local value = rawget(subobj, field) or rawget(g_Classes[subobj.class], field)
		if value then
			self[field] = value
			break
		end
	end
end

function Broadcast(array, method, ...)
	if type(method) == "string" then
		for i,subobj in ipairs(array) do
			subobj[method](subobj, ...)
		end
	else
		for i,subobj in ipairs(array) do
			method(subobj, ...)
		end
	end
end

function CheckAll(array, method, ...)
	for i,subobj in ipairs(array) do
		if not subobj[method](subobj, ...) then
			return false
		end
	end
	return true
end

function CheckAllProperty(array, property)
	for i,subobj in ipairs(array) do
		if not subobj[property] then
			return false
		end
	end
	return true
end

function CheckAny(array, method, ...)
	for i,subobj in ipairs(array) do
		local result, r2, r3, r4, r5 = subobj[method](subobj, ...)
		if result then return result, r2, r3, r4, r5 end
	end
	return false
end

function CheckAnyProperty(array, property)
	for i,subobj in ipairs(array) do
		local value = subobj[property]
		if value then
			return value
		end
	end
	return false
end

function Union(array, method, comparison_key, ...)
	local values = { }
	for i,subobj in ipairs(array) do
		local result = subobj[method](subobj, ...)
		if result then
			for i,v in ipairs(result) do
				if comparison_key then
					if not find(values, comparison_key, v[comparison_key]) then
						table.insert(values, v)
					end
				else
					--optimized when there is no comparison key
					values[v] = true
				end
			end
		end
	end
	
	return comparison_key and values or table.keys(values)
end

--CombatAction Helpers

function ChooseClosestObject(array, target, condition, ...)
	local closest
	for _, obj in ipairs(array) do
		if not closest or IsCloser(target, obj, closest) then
			if not condition or condition(obj, target, ...) then
				closest = obj
			end
		end
	end
	return closest
end

--Combat Unit Methods

function SetCommand(array, command, ...)
	--not all objs will have the command so this is a quick optimization for using the heavy `HasMember`
	local has_member_cache = { }
	
	for i,subobj in ipairs(array) do
		local cache = has_member_cache[subobj.class]
		if cache == nil and subobj:HasMember(command) or cache then
			subobj:SetCommand(command, ...)
			has_member_cache[subobj.class] = true
		end
	end
end

function CanBeControlled(units, ...)
	return CheckAny(units, "CanBeControlled", ...)
end

function GetStanceToStanceAP(units, ...)
	local result = -1
	for i,subobj in ipairs(units) do
		local value = subobj:GetStanceToStanceAP(...)
		if value and value > result then
			result = value
		end
	end
	return result
end

function IsNPC(units, ...)
	return CheckAll(units, "IsNPC", ...)
end

function GetActiveWeapons(units, ...)
	return Union(units, "GetActiveWeapons", ...)
end

function GetItemInSlot(units, ...)
	return CheckAny(units, "GetItemInSlot", ...)
end

function UIHasAP(units, ...)
	return CheckAny(units, "UIHasAP", ...)
end

function HasAP(units, ...)
	return CheckAny(units, "HasAP", ...)
end

function GetVisibleEnemies(units, ...)
	return Union(units, "GetVisibleEnemies", false, ...)
end

function GetUIScaledAPMax(units, ...)
	return CheckAny(units, "GetUIScaledAPMax", ...)
end

function GetUIScaledAP(units, ...)
	return CheckAny(units, "GetUIScaledAP", ...)
end

function GetAvailableAmmos(units, ...)
	return CheckAny(units, "GetAvailableAmmos", ...)
end

function GetAttackAPCost(units, ...)
	return CheckAny(units, "GetAttackAPCost", ...)
end

function GetReachableObjects(units, ...)
	return Union(units, "GetReachableObjects", false, ...)
end

---- Helpers

function MultiTargetExecute(behavior, array, func, target, ...)
	if #array == 0 then
		return
	end
	
	if behavior == "hidden" and #array == 1 then
		behavior = "first"
	end

	if behavior == "nearest" then
		local closest = ChooseClosestObject(array, target)
		func(closest, ...)
	elseif behavior == "all" then
		Broadcast(array, func, ...)
	elseif behavior == "first" then
		local obj = array[1]
		func(obj, ...)
	end
end

local table_find = table.find

function OnMsg.ObjModified(obj)
	if not table_find(Selection, obj) then return end
	ObjModified(Selection)
end

function SelectionMouseObj()
	-- assert(IsAsyncCode()) -- game time threads can use SelectionMouseObj in Zulu, we do not persist them -> this will not cause a desync
	local solid, transparent = GetPreciseCursorObj()
	return SelectionPropagate(transparent or solid or SelectFromTerrainPoint(GetTerrainCursor()) or GetTerrainCursorObjSel())
end

GameVar("gv_Selection", false)

function OnMsg.GatherSessionData()
	gv_Selection = {}
	for i, unit in ipairs(Selection) do
		gv_Selection[i] = unit:GetHandle()
	end
end

function OnMsg.LoadSessionData()
	if not gv_Selection or #gv_Selection == 0 then
		EnsureCurrentSquad()
		return
	end
	local list = {}
	for _, handle in ipairs(gv_Selection) do
		local obj = HandleToObject[handle]
		if IsKindOf(obj, "Unit") then
			list[#list + 1] = obj
		end
	end
	SelectionSet(list)
end