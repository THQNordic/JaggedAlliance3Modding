if not const.cmtVisible then return end

if FirstLoad then
	C_CCMT = false
end

function SetC_CCMT(val)
	if C_CCMT == val then
		return
	end
	C_CCMT_Reset()
	C_CCMT = val
end

function OnMsg.ChangeMap()
	C_CCMT_Reset()
end

MapVar("CMT_ToHide", {})
MapVar("CMT_ToUnhide", {})
MapVar("CMT_Hidden", {})

CMT_Time = 300
CMT_OpacitySleep = 10
CMT_OpacityStep = Max(1, MulDivRound(CMT_OpacitySleep, 100, CMT_Time))

if FirstLoad then
	g_CMTPaused = false
	g_CMTPauseReasons = {}
end

function CMT_SetPause(s, reason)
	if s then
		g_CMTPauseReasons[reason] = true
		g_CMTPaused = true
	else
		g_CMTPauseReasons[reason] = nil
		if not next(g_CMTPauseReasons) then
			g_CMTPaused = false
		end
	end
end

MapRealTimeRepeat( "CMT_V2_Thread", 0, function()
	Sleep(CMT_OpacitySleep)
	if g_CMTPaused then return end
	--local startTs = GetPreciseTicks(1000)
	
	if C_CCMT then
		C_CCMT_Thread_Func(CMT_OpacityStep)
	else	
		local opacity_step = CMT_OpacityStep
		
		for k,v in next, CMT_ToHide do
			if not IsValid(k) then
				CMT_ToHide[k] = nil
			else
				local next_opacity = k:GetOpacity() - opacity_step
				if next_opacity > 0 then
					k:SetOpacity(next_opacity)
				else
					k:SetOpacity(0)
					CMT_ToHide[k] = nil
					CMT_Hidden[k] = true
				end
			end
		end
		for k,v in next, CMT_ToUnhide do
			if not IsValid(k) then
				CMT_ToUnhide[k] = nil
			else
				local next_opacity = k:GetOpacity() + opacity_step
				if next_opacity < 100 then
					k:SetOpacity(next_opacity)
				else
					k:SetOpacity(100)
					k:ClearHierarchyGameFlags(const.gofSolidShadow + const.gofContourInner)
					CMT_ToUnhide[k] = nil
				end
			end
		end
	end
	--local endTs = GetPreciseTicks(1000)
	--print("CMT_V2_Thread time", endTs - startTs)
end)

function IsContourObject(obj)
	return const.SlabSizeX and IsKindOf(obj, "Slab")
end

function CMT(obj, b)
	if C_CCMT then
		C_CCMT_Hide(obj, not not b)
		return
	end
	
	if b then
		if CMT_ToHide[obj] or CMT_Hidden[obj] then return end
		if CMT_ToUnhide[obj] then
			CMT_ToUnhide[obj] = nil
		end
		CMT_ToHide[obj] = true
		obj:SetHierarchyGameFlags(const.gofSolidShadow)
		if IsContourObject(obj) then
			obj:SetHierarchyGameFlags(const.gofContourInner)
		end
	else
		if CMT_ToUnhide[obj] or not CMT_ToHide[obj] and not CMT_Hidden[obj] then return end
		if CMT_ToHide[obj] then
			CMT_ToHide[obj] = nil
		end
		if IsEditorActive() then
			obj:SetOpacity(100)
			obj:ClearHierarchyGameFlags(const.gofSolidShadow + const.gofContourInner) 
		else
			CMT_ToUnhide[obj] = true
		end
		if CMT_Hidden[obj] then
			CMT_Hidden[obj] = nil
		end
	end
end

local function ShowAllKeyObjectsAndClearTable(table)
	for obj, _ in pairs(table) do
		if IsValid(obj) then
			obj:SetOpacity(100)
			obj:ClearHierarchyGameFlags(const.gofSolidShadow + const.gofContourInner)
		end
		table[obj] = nil
	end
end

function OnMsg.ChangeMapDone(map)
	if string.find(map, "MainMenu") then
		CMT_SetPause(true, "MainMenu")
	else
		CMT_SetPause(false, "MainMenu")
	end
end

function OnMsg.GameEnterEditor()
	C_CCMT_ShowAllAndReset()
	ShowAllKeyObjectsAndClearTable(CMT_ToHide)
	ShowAllKeyObjectsAndClearTable(CMT_ToUnhide)
	ShowAllKeyObjectsAndClearTable(CMT_Hidden)
end

function CMT_IsObjVisible(o)
	if not C_CCMT then
		return o:GetGameFlags(const.gofSolidShadow) == 0 or CMT_ToUnhide[o]
	else
		return C_CCMT_GetObjCMTState(o) < const.cmtHidden
	end
end
