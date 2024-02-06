ColorModifierReasons = {
	--override this in your project
	--{id = "reason_name", weight = default reason weight number, color = default reason color},
}

MapVar("ColorModifierReasonsData", false)
local table_find = table.find
local SetColorModifier = CObject.SetColorModifier
local GetColorModifier = CObject.GetColorModifier
local clrNoModifier = const.clrNoModifier
local default_color_modifier = RGBA(100, 100, 100, 0)

function SetColorModifierReason(obj, reason, color, weight, blend, skip_attaches)
	assert(reason)
	if not reason then
		return
	end
	local color_value = color
	
	if obj:GetRadius() > 0 then
		local data = ColorModifierReasonsData
		if not data then
			data = {}
			ColorModifierReasonsData = data 
		end
		local mrt = data[obj]
		local orig_color
		if not mrt then
			orig_color = GetColorModifier(obj)
			mrt = { orig_color = orig_color }
			data[obj] = mrt
		end
		
		local rt = ColorModifierReasons
		local idx = table_find(rt, "id", reason)
		local rdata = idx and rt[idx] or false
		
		color = color or rdata and rdata.color or nil
		if not color then
			printf("[WARNING] SetColorModifierReason no color! reason %s, color %s, weight %s", reason, tostring(color), tostring(weight))
			return
		end
		weight = weight or rdata and rdata.weight or const.DefaultColorModWeight
		if not weight then
			printf("[WARNING] SetColorModifierReason no weight! reason %s, color %s, weight %s", reason, tostring(color), tostring(weight))
			return
		end
		
		if blend then
			orig_color = orig_color or mrt.orig_color
			if orig_color ~= clrNoModifier then
				color = InterpolateRGB(orig_color, color, blend, 100)
			end
		end
		local idx = table_find(mrt, "reason", reason)
		local entry = idx and mrt[idx]
		if entry then
			entry.weight = weight
			entry.color = color
		else
			entry = { reason = reason, weight = weight, color = color }
			table.insert(mrt, entry)
		end
		table.stable_sort(mrt, function(a, b)
			return a.weight < b.weight
		end)
		SetColorModifier(obj, mrt[#mrt].color)
	end
	if skip_attaches then
		return
	end
	obj:ForEachAttach(SetColorModifierReason, reason, color_value, weight, blend)
end

function SetOrigColorModifier(obj, color, skip_attaches)
	local data = ColorModifierReasonsData
	local mrt = data and data[obj]
	if not mrt then
		SetColorModifier(obj, color)
	else
		mrt.orig_color = color
	end
	if skip_attaches then return end
	obj:ForEachAttach(SetOrigColorModifier, color)
end

function GetOrigColorModifier(obj)
	local modifier = GetColorModifier(obj)
	return modifier == default_color_modifier and table.get(ColorModifierReasonsData, obj, "orig_color") or modifier
end

function ValidateColorReasons()
	table.validate_map(ColorModifierReasonsData)
end

function ClearColorModifierReason(obj, reason, skip_color_change, skip_attaches)	
	assert(reason)
	if not reason then
		return
	end
	local data = ColorModifierReasonsData
	local mrt = data and data[obj]
	if mrt then
		if not IsValid(obj) then
			data[obj] = nil
			return
		end
		local idx = table_find(mrt, "reason", reason)
		if not idx then
			return
		end
		local update = idx == #mrt
		table.remove(mrt, idx)
		if #mrt == 0 then
			data[obj] = nil
			DelayedCall(1000, ValidateColorReasons)
			if not next(data) then
				ColorModifierReasonsData = false
			end
		end
		if update and not skip_color_change then
			local active = mrt[#mrt]
			local color = active and active.color or mrt.orig_color or const.clrNoModifier
			SetColorModifier(obj, color)
		end
	end
	if skip_attaches then
		return
	end
	obj:ForEachAttach(ClearColorModifierReason, reason, skip_color_change)
end

function ClearColorModifierReasons(obj)
	local data = ColorModifierReasonsData
	local mrt = data and data[obj]
	if not mrt then
		return
	end
	if IsValid(obj) then
		SetColorModifier(obj, mrt.orig_color or const.clrNoModifier)
		obj:ForEachAttach(ClearColorModifierReasons)
	end
	data[obj] = nil
end

OnMsg.StartSaveGame = ValidateColorReasons
	
----

MapVar("InvisibleReasons", {}, weak_keys_meta)

local efVisible = const.efVisible

function SetInvisibleReason(obj, reason)
	local invisible_reasons = InvisibleReasons
	local obj_reasons = invisible_reasons[obj]
	if obj_reasons then
		obj_reasons[reason] = true
		return
	end
	invisible_reasons[obj] = { [reason] = true }
	obj:ClearHierarchyEnumFlags(efVisible)
end

function ClearInvisibleReason(obj, reason)
	local invisible_reasons = InvisibleReasons
	local obj_reasons = invisible_reasons[obj]
	if not obj_reasons or not obj_reasons[reason] then
		return
	end
	obj_reasons[reason] = nil
	if next(obj_reasons) then
		return
	end
	invisible_reasons[obj] = nil
	obj:SetHierarchyEnumFlags(efVisible)
end

function ClearInvisibleReasons(obj)
	local invisible_reasons = InvisibleReasons
	if not invisible_reasons[obj] then
		return
	end
	invisible_reasons[obj] = nil
	obj:SetHierarchyEnumFlags(efVisible)
end

----