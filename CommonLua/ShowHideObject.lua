if FirstLoad then
	OriginalInGameSolidShadow = {}
	OriginalInGameOpacities = {}
	OriginalInGameVisible = {}
end

function OnMsg.ChangeMapDone()
	OriginalInGameSolidShadow = {}
	OriginalInGameOpacities = {}
	OriginalInGameVisible = {}
end

local function use_setvisible_for_object(obj)
	return obj:IsKindOfClasses("Light", "ParSystem", "EditorVisibleObject", "Decal")
end

----- Functions for showing/hiding objects for use by the game tools, e.g. the map editor

function GameToolsShowObject(obj, opacity)
	if not IsValid(obj) then return end
	if obj:GetEnumFlags(const.efVisible) ~= 0 and obj:GetOpacity() ~= 0 then return end
	
	if use_setvisible_for_object(obj) then
		OriginalInGameVisible[obj] = OriginalInGameVisible[obj] or obj:GetEnumFlags(const.efVisible)
		obj:SetEnumFlags(const.efVisible)
		if obj:HasMember("OnXFilterSetVisible") then
			obj:OnXFilterSetVisible(true)
		end
	else
		local t = rawget(obj, "hidden_reasons") -- bacon-specific
		if t and next(t) then
			return -- hidden by game!
		end
		
		local orig_opacity = OriginalInGameOpacities[obj]
		OriginalInGameSolidShadow[obj] = OriginalInGameSolidShadow[obj] or obj:GetGameFlags(const.gofSolidShadow)
		OriginalInGameOpacities[obj] = OriginalInGameOpacities[obj] or obj:GetOpacity()
		obj:ClearHierarchyGameFlags(const.gofSolidShadow)
		obj:SetOpacity(orig_opacity and orig_opacity >= 25 and orig_opacity or 100)
		
		if const.cmtVisible then
			CMT_ToHide[obj] = nil
			CMT_Hidden[obj] = nil
		end
		rawset(obj, "hidden_reasons", false) -- bacon-specific
	end
end

function GameToolsHideObject(obj)
	if not IsValid(obj) then return end
	if obj:GetEnumFlags(const.efVisible) == 0 or obj:GetOpacity() == 0 then return end
	
	if use_setvisible_for_object(obj) then
		OriginalInGameVisible[obj] = OriginalInGameVisible[obj] or obj:GetEnumFlags(const.efVisible)
		obj:ClearEnumFlags(const.efVisible)
		if obj:HasMember("OnXFilterSetVisible") then
			obj:OnXFilterSetVisible(false)
		end
	else
		OriginalInGameSolidShadow[obj] = OriginalInGameSolidShadow[obj] or obj:GetGameFlags(const.gofSolidShadow)
		OriginalInGameOpacities[obj] = OriginalInGameOpacities[obj] or obj:GetOpacity()
		obj:SetHierarchyGameFlags(const.gofSolidShadow)
		obj:SetOpacity(0)
	end
end

function GameToolsRestoreObjectsVisibility()
	SuspendPassEdits("GameToolsRestoreObjectsVisibility")
	for obj, opacity in pairs(table.validate_map(OriginalInGameOpacities)) do
		obj:SetOpacity(opacity)
	end
	for obj, flag in pairs(table.validate_map(OriginalInGameSolidShadow)) do
		if flag == 0 then
			obj:ClearHierarchyGameFlags(const.gofSolidShadow)
		else
			obj:SetHierarchyGameFlags(const.gofSolidShadow)
		end
	end
	for obj, flag in pairs(table.validate_map(OriginalInGameVisible)) do
		if not IsKindOf(obj, "EditorVisibleObject") then -- manage in-game visibility themselves
			if flag == 0 then
				GameToolsHideObject(obj)
			else
				GameToolsShowObject(obj)
			end
		end
	end
	ResumePassEdits("GameToolsRestoreObjectsVisibility")
end
